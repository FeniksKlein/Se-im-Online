-- 2026-10-09 · İl dışı parti mitingi (GB + yetkili GBY) ve bağımsız adayın partiye katılması. Kaynak: gelistirici/sql/50_parti_miting_bagimsiz.sql
begin;
-- =====================================================================
--  50 · İL DIŞI PARTİ MİTİNGİ + BAĞIMSIZ ADAYIN PARTİYE KATILMASI
--
--  1) Parti mitingi
--    • Genel başkan 81 ilin herhangi birinde parti adına miting düzenler.
--    • Genel başkan yardımcıları, genel başkan "miting yetkisi" verirse aynı hakka sahip olur.
--      Yetki her an geri alınabilir; geri alınınca başlamamış mitingler iptal olur, para iade edilir.
--    • Bedel ilin büyüklüğüne göredir (aday mitinginin bedeliyle aynı); parti kasası ya da
--      düzenleyenin kendi cebi öder.
--    • Her yetkili günde en fazla 1 parti mitingi; aynı partiden aynı ilde 3 gün içinde ikinci
--      parti mitingi olmaz; genel / belediye / cumhurbaşkanlığı seçimlerinin oy verme saatlerinde
--      parti mitingi yapılamaz.
--    • Miting başlayınca o ildeki herkese ve partinin tüm üyelerine bildirim gider. Kürsü, tepki,
--      slogan ve coşku canlı miting meydanının (46) aynısıdır; tepkiyi yalnız o ilde yaşayanlar verir.
--    • Aday mitingleri (39/46) değişmeden çalışır.
--
--  2) Bağımsız aday partiye katılabilir
--    • Oy verme başlamadan önce partiye katılan (ya da parti kuran) bağımsız adayın adaylığı
--      kendiliğinden düşer; başvuru harcı iade edilmez.
--    • Oy verme sürerken pusula kilitlidir; sandık kapanınca katılabilir.
--    • Seçimi kazanmış bağımsız vekil partiye katılabilir; Meclis grubu üyeliğe göre sayıldığı
--      için sandalyesi yeni partisine geçer.
--  Mevcut mitingler, adaylıklar ve oyuncu verisi aynen korunur.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Şema (yalnız ekleme)
-- ---------------------------------------------------------------------
alter table oyun.mitingler alter column secim_id drop not null;      -- parti mitingi bir seçime bağlı değildir
alter table oyun.mitingler add column if not exists tur text not null default 'aday';
alter table oyun.mitingler add column if not exists odeyen text not null default 'kisi';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'mitingler_tur_chk') then
    alter table oyun.mitingler add constraint mitingler_tur_chk check (tur in ('aday','parti'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'mitingler_odeyen_chk') then
    alter table oyun.mitingler add constraint mitingler_odeyen_chk check (odeyen in ('kisi','parti'));
  end if;
end $$;
create index if not exists mitingler_parti on oyun.mitingler(parti_id, il_id, bas) where tur = 'parti';

alter table oyun.parti_gby add column if not exists miting_yetkisi boolean not null default false;

-- ---------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------
-- Oyuncunun parti mitingi yetkisi: 'gb', 'gby' ya da null
create or replace function oyun.parti_miting_yetki(u uuid) returns text language sql stable set search_path = '' as $$
  select case
    when exists (select 1 from oyun.profiller p join oyun.partiler pa on pa.id = p.parti_id
                 where p.id = u and pa.gb = u and not pa.kapali) then 'gb'
    when exists (select 1 from oyun.profiller p join oyun.parti_gby g on g.parti_id = p.parti_id and g.user_id = u
                 join oyun.partiler pa on pa.id = p.parti_id
                 where p.id = u and g.miting_yetkisi and not pa.kapali) then 'gby'
  end
$$;

-- [p_bas, p_bit) aralığı bir genel / belediye / CB seçiminin oy verme saatlerine değiyor mu?
create or replace function oyun.miting_secim_yasagi(p_bas timestamptz, p_bit timestamptz) returns text
language sql stable set search_path = '' as $$
  select case s.tur when 'mv' then 'genel seçim' when 'bel' then 'belediye seçimi' else 'cumhurbaşkanlığı seçimi' end
  from oyun.secimler s
  where s.tur in ('mv','bel','cb','cb2') and s.durum = 'bekliyor'
    and s.oy_bas < p_bit and s.oy_bit > p_bas
  order by s.oy_bas limit 1
$$;

-- Başlamamış bir parti mitingini iptal eder; parayı ödeyene geri verir
create or replace function oyun.parti_miting_iptal(p_id bigint, p_neden text, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare m oyun.mitingler; ilad text;
begin
  delete from oyun.mitingler where id = p_id and tur = 'parti' and bas > t returning * into m;
  if m.id is null then return; end if;
  select ad into ilad from oyun.iller where id = m.il_id;
  if m.bedel > 0 then
    if m.odeyen = 'parti' and exists (select 1 from oyun.partiler where id = m.parti_id) then
      update oyun.partiler set kasa = kasa + m.bedel where id = m.parti_id;
      insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
        values (m.parti_id, t, m.bedel, format('%s mitingi iptal edildi, bedel iade', ilad), 'miting');
    else
      perform oyun.para_islem(m.user_id, m.bedel, 'miting', format('%s mitingi iptal edildi, bedel iade', ilad), t);
    end if;
  end if;
  perform oyun.bildir(m.user_id, format('%s mitingin iptal edildi: %s. Bedeli iade edildi.', ilad, p_neden), t);
end $$;

-- Yetkisini kaybedenin (yetki geri alındı, görev bitti, partiden ayrıldı) başlamamış mitingleri düşer
create or replace function oyun.parti_miting_temizle(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare r record;
begin
  for r in select m.id, m.user_id, m.parti_id from oyun.mitingler m
           where m.tur = 'parti' and m.bas > t loop
    if (select parti_id from oyun.profiller where id = r.user_id) is distinct from r.parti_id
       or oyun.parti_miting_yetki(r.user_id) is null then
      perform oyun.parti_miting_iptal(r.id, 'parti adına miting yetkin kalmadı', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Parti mitingi düzenle
-- ---------------------------------------------------------------------
create or replace function public.parti_miting_duzenle(p_il int, p_bas timestamptz, p_baslik text, p_kasadan boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; yetki text;
        ilad text; b text; bedel numeric; yasak text; mid bigint; gun date;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Parti mitingi için bir partiye üye olmalısın.'; end if;
  yetki := oyun.parti_miting_yetki(p.id);
  if yetki is null then
    raise exception 'Parti adına miting yalnız genel başkan ve miting yetkisi verilmiş genel başkan yardımcıları tarafından düzenlenebilir.';
  end if;
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  if p_bas is null or p_bas < t + interval '15 minutes' then raise exception 'Mitingi en erken 15 dakika sonrasına koyabilirsin.'; end if;
  if p_bas > t + interval '3 days' then raise exception 'Mitingi en fazla 3 gün sonrasına planlayabilirsin.'; end if;
  yasak := oyun.miting_secim_yasagi(p_bas, p_bas + interval '1 hour');
  if yasak is not null then raise exception 'Seçim yasağı: % oy verme saatlerinde miting yapılamaz. Başka bir saat seç.', yasak; end if;
  b := oyun.metin_temizle(p_baslik, 80);
  if length(b) < 3 then raise exception 'Miting başlığı en az 3 karakter olmalı.'; end if;
  gun := (p_bas at time zone 'Europe/Istanbul')::date;
  if exists (select 1 from oyun.mitingler m where m.user_id = p.id and m.tur = 'parti'
             and (m.bas at time zone 'Europe/Istanbul')::date = gun) then
    raise exception 'Aynı gün için zaten bir parti mitingi düzenledin. Günde en fazla 1 parti mitingi yapılabilir.';
  end if;
  if exists (select 1 from oyun.mitingler m where m.parti_id = pa.id and m.tur = 'parti' and m.il_id = p_il
             and m.bas > p_bas - interval '3 days' and m.bas < p_bas + interval '3 days') then
    raise exception 'Partin % ilinde 3 gün içinde zaten miting yapıyor ya da yaptı. Aynı ilde iki parti mitingi arasında en az 3 gün olmalı.', ilad;
  end if;
  if exists (select 1 from oyun.mitingler m where m.il_id = p_il and m.bas < p_bas + interval '1 hour' and m.bit > p_bas) then
    raise exception 'Bu saatte % meydanında başka bir miting var. Başka bir saat seç.', ilad;
  end if;
  bedel := oyun.miting_bedel(p_il::smallint);
  if coalesce(p_kasadan, true) then
    if pa.kasa < bedel then
      raise exception '% mitingi için parti kasasında % ₺ olmalı (kasada % ₺ var). Bedeli kendi cebinden de ödeyebilirsin.',
        ilad, oyun.tl(bedel), oyun.tl(pa.kasa);
    end if;
    update oyun.partiler set kasa = kasa - bedel where id = pa.id;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
      values (pa.id, t, -bedel, format('%s mitingi (sahne, ses, ulaşım) · %s', ilad, p.kad), 'miting');
  else
    perform oyun.para_islem(p.id, -bedel, 'miting', format('%s parti mitingi (sahne, ses, ulaşım)', ilad), t);
  end if;
  insert into oyun.mitingler(user_id, secim_id, il_id, parti_id, baslik, bas, bit, bedel, tur, odeyen)
    values (p.id, null, p_il, pa.id, b, p_bas, p_bas + interval '1 hour', bedel, 'parti',
            case when coalesce(p_kasadan, true) then 'parti' else 'kisi' end)
    returning id into mid;
  perform oyun.olay('parti', format('%s %s %s, %s mitingi düzenleyecek: “%s” (%s).', pa.kisa,
      case yetki when 'gb' then 'Genel Başkanı' else 'Genel Başkan Yardımcısı' end, p.kad, ilad, b,
      to_char(p_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), p_il::smallint, pa.id, t);
  return jsonb_build_object('id', mid, 'bedel', bedel, 'il', ilad, 'odeyen', case when coalesce(p_kasadan, true) then 'parti' else 'kisi' end);
end $$;

-- Parti ekranı için: yetkim, kasa, il bedelleri, yaklaşan parti mitingleri, GB ise yardımcıların yetkileri
create or replace function public.parti_miting_bilgi() returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; yetki text;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.id is null then return jsonb_build_object('yetki', null); end if;
  yetki := oyun.parti_miting_yetki(p.id);
  return jsonb_build_object(
    'yetki', yetki,
    'kasa', round(pa.kasa),
    'cuzdan', (select round(para) from oyun.cuzdan where user_id = p.id),
    'il_id', p.il_id,
    'iller', case when yetki is not null then (select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad, 'bedel', oyun.miting_bedel(i.id)) order by i.ad)
                                               from oyun.iller i) end,
    'yaklasan', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'kad', x.kad, 'il', i.ad, 'baslik', m.baslik, 'bas', m.bas, 'bit', m.bit,
                    'odeyen', m.odeyen, 'bedel', m.bedel) order by m.bas), '[]'::jsonb)
                 from oyun.mitingler m join oyun.profiller x on x.id = m.user_id join oyun.iller i on i.id = m.il_id
                 where m.tur = 'parti' and m.parti_id = pa.id and m.bit > oyun.simdi()),
    'yardimcilar', case when yetki = 'gb' then (select coalesce(jsonb_agg(jsonb_build_object('sira', g.sira, 'kad', x.kad, 'yetki', g.miting_yetkisi) order by g.sira), '[]'::jsonb)
                   from oyun.parti_gby g join oyun.profiller x on x.id = g.user_id where g.parti_id = pa.id) end
  );
end $$;

-- Genel başkan bir yardımcısına miting yetkisi verir / geri alır
create or replace function public.gby_miting_yetkisi(p_kad text, p_ver boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; h oyun.profiller; r record;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Miting yetkisini yalnız genel başkan verebilir.'; end if;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(p_kad));
  if h.id is null or not exists (select 1 from oyun.parti_gby where parti_id = pa.id and user_id = h.id) then
    raise exception 'Bu oyuncu partinin genel başkan yardımcısı değil.';
  end if;
  update oyun.parti_gby set miting_yetkisi = coalesce(p_ver, false) where parti_id = pa.id and user_id = h.id;
  if coalesce(p_ver, false) then
    perform oyun.bildir(h.id, format('Genel Başkan %s sana parti adına miting yetkisi verdi: artık 81 ilin herhangi birinde %s mitingi düzenleyebilirsin.', p.kad, pa.kisa), t);
  else
    for r in select id from oyun.mitingler where user_id = h.id and tur = 'parti' and bas > t loop
      perform oyun.parti_miting_iptal(r.id, 'genel başkan miting yetkini geri aldı', t);
    end loop;
    perform oyun.bildir(h.id, format('Genel Başkan %s parti adına miting yetkini geri aldı.', p.kad), t);
  end if;
  return public.parti_miting_bilgi();
end $$;

-- ---------------------------------------------------------------------
-- Liste: parti mitingi işareti
-- ---------------------------------------------------------------------
create or replace function public.mitingler() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'kad', p.kad, 'parti', oyun.parti_json(m.parti_id), 'il_id', m.il_id,
      'il', (select ad from oyun.iller where id = m.il_id), 'baslik', m.baslik, 'bas', m.bas, 'bit', m.bit,
      'katilim', (select count(*) from oyun.miting_katilim c where c.miting_id = m.id),
      'katildim', exists (select 1 from oyun.miting_katilim c where c.miting_id = m.id and c.user_id = auth.uid()),
      'benim_ilim', m.il_id = (select il_id from oyun.profiller where id = auth.uid()),
      'benim', m.user_id = auth.uid(),
      'tur', m.tur,
      'partim', m.parti_id is not null and m.parti_id = (select parti_id from oyun.profiller where id = auth.uid()),
      'konusma', (select count(*) from oyun.miting_konusma k where k.miting_id = m.id and not k.silindi),
      'cosku', coalesce(m.cosku, case when m.bas <= oyun.simdi() then oyun.miting_cosku(m.id) end),
      'secim_tur', (select tur from oyun.secimler where id = m.secim_id)) order by m.bas), '[]'::jsonb)
  from oyun.mitingler m join oyun.profiller p on p.id = m.user_id
  where m.bit > oyun.simdi() - interval '6 hours' and m.bas < oyun.simdi() + interval '3 days'
$$;

-- ---------------------------------------------------------------------
-- Dakikalık motor: parti mitingi başlayınca partinin başka illerdeki üyelerine de haber gider
-- ---------------------------------------------------------------------
create or replace function oyun.miting_tick(t timestamptz) returns void language plpgsql set search_path = '' as $$
declare m record; n int; c int; enIyi text; konusma int;
begin
  perform oyun.parti_miting_temizle(t);
  for m in select x.*, p.kad, i.ad il_ad, pa.kisa parti_kisa from oyun.mitingler x join oyun.profiller p on p.id = x.user_id join oyun.iller i on i.id = x.il_id
           left join oyun.partiler pa on pa.id = x.parti_id
           where not x.duyuruldu and x.bas <= t and x.bit > t loop
    update oyun.mitingler set duyuruldu = true where id = m.id;
    insert into oyun.bildirimler(user_id, zaman, metin)
      select pr.id, t, format('%s şu an %s meydanında: “%s”. Bir saat içinde Gündem''den mitinge katılıp konuşmaları dinleyebilir, tepki verebilirsin.', m.kad, m.il_ad, m.baslik)
      from oyun.profiller pr where pr.il_id = m.il_id and pr.id <> m.user_id and not pr.yasakli;
    if m.tur = 'parti' then
      insert into oyun.bildirimler(user_id, zaman, metin)
        select pr.id, t, format('%s mitingi başladı: %s, %s meydanında “%s”. Gündem''den canlı izleyebilirsin.', m.parti_kisa, m.kad, m.il_ad, m.baslik)
        from oyun.profiller pr where pr.parti_id = m.parti_id and pr.il_id <> m.il_id and pr.id <> m.user_id and not pr.yasakli;
    end if;
    perform oyun.bildir(m.user_id, format('%s mitingin başladı. Meydan seni bekliyor: Gündem''den mitingine girip kürsüden konuş.', m.il_ad), t);
    if oyun.push_acik() then
      perform oyun.push_konuya('s_il_' || m.il_id, null, format('%s meydanda!', m.kad),
        format('%s mitingi başladı: “%s”. Katılmak için dokun.', m.il_ad, m.baslik), jsonb_build_object('ekran', 'gundem'));
    end if;
  end loop;
  for m in select x.*, p.kad, i.ad il_ad from oyun.mitingler x join oyun.profiller p on p.id = x.user_id join oyun.iller i on i.id = x.il_id
           where not x.sonuc_yazildi and x.bit <= t loop
    select count(*) into n from oyun.miting_katilim where miting_id = m.id and user_id <> m.user_id;
    select count(*) into konusma from oyun.miting_konusma where miting_id = m.id and not silindi;
    c := oyun.miting_cosku(m.id);
    select left(k.metin, 120) into enIyi from oyun.miting_konusma k
      where k.miting_id = m.id and not k.silindi
        and exists (select 1 from oyun.miting_tepki r where r.konusma_id = k.id and oyun.miting_tepki_puan(r.tur) > 0)
      order by (select sum(oyun.miting_tepki_puan(r.tur)) from oyun.miting_tepki r where r.konusma_id = k.id) desc, k.id limit 1;
    update oyun.mitingler set sonuc_yazildi = true, duyuruldu = true, cosku = c where id = m.id;
    if konusma = 0 then
      perform oyun.olay('secim', format('%s, %s meydanında %s kişiyi topladı ama kürsüye hiç çıkmadı: “%s”.', m.kad, m.il_ad, n, m.baslik), m.il_id, m.parti_id, t);
    else
      perform oyun.olay('secim', format('%s %s mitingi: %s kişi, coşku %s/100 (%s).%s', m.kad, m.il_ad, n, c, lower(oyun.miting_cosku_ad(c)),
        case when enIyi is not null then format(' En çok alkışlanan söz: “%s”', enIyi) else '' end), m.il_id, m.parti_id, t);
    end if;
    perform oyun.bildir(m.user_id, format('%s mitingin sona erdi: %s kişi katıldı, %s kez kürsüye çıktın, meydanın coşkusu %s/100.', m.il_ad, n, konusma, c), t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2) Bağımsız aday partiye katılır: adaylık düşer (eskiden katılım engelleniyordu)
-- ---------------------------------------------------------------------
create or replace function oyun.bagimsiz_parti_kilidi()
returns trigger language plpgsql set search_path = '' as $$
declare t timestamptz := oyun.simdi(); r record; gorev text;
begin
  if old.parti_id is null and new.parti_id is not null then
    if exists (select 1 from oyun.adaylar a join oyun.secimler s on s.id = a.secim_id
               where a.user_id = new.id and a.parti_id is null and s.tur in ('mv','bel','cb','cb2')
                 and s.durum = 'bekliyor' and t >= s.oy_bas and t < s.oy_bit) then
      raise exception 'Oy verme sürüyor; bağımsız adaylığın pusulada. Sandık kapandıktan sonra partiye katılabilirsin.';
    end if;
    for r in delete from oyun.adaylar a using oyun.secimler s
             where a.secim_id = s.id and a.user_id = new.id and a.parti_id is null
               and s.tur in ('mv','bel','cb','cb2') and s.durum = 'bekliyor' and t < s.oy_bas
             returning a.il_id, s.tur loop
      gorev := case r.tur when 'mv' then 'milletvekili' when 'bel' then 'belediye başkanı' else 'cumhurbaşkanı' end;
      perform oyun.olay('secim', format('%s, bağımsız %s adaylığından çekilip partiye katıldı.', new.kad, gorev), r.il_id, new.parti_id, t);
      perform oyun.bildir(new.id, format('Partiye katıldığın için bağımsız %s adaylığın düştü. Başvuru harcı iade edilmez.', gorev), t);
    end loop;
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
revoke all on function public.parti_miting_duzenle(int, timestamptz, text, boolean), public.parti_miting_bilgi(),
  public.gby_miting_yetkisi(text, boolean) from public, anon;
grant execute on function public.parti_miting_duzenle(int, timestamptz, text, boolean), public.parti_miting_bilgi(),
  public.gby_miting_yetkisi(text, boolean) to authenticated;
revoke all on function oyun.parti_miting_iptal(bigint, text, timestamptz), oyun.parti_miting_temizle(timestamptz),
  oyun.miting_tick(timestamptz) from public, anon, authenticated;
commit;
