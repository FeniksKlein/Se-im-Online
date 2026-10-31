-- 154 (31.10.2026) — SİYASET ARENASI: oyuncuyu canlı tutan katman
-- İstek (Ercan): online süreyi artıran önerilerin hepsi. Zaten olanlar (seçim gecesi yayını, canlı miting, ülke kriz merkezi,
-- ittifak teklifleri, röportaj/düello) korunur; eksikler eklenir:
--   1) Her akşam 21:00–22:00 canlı Genel Kurul oturumu: vekil yoklaması (+1 kıdem), açık oylamalar, katılmayanlar herkese açık.
--   2) Bekleyen işlerim: oyuncunun cevabını bekleyen her şey tek listede (oylama, ödenek talebi, kurucu daveti, ittifak teklifi…).
--   3) Haftalık parti hedefleri (takım görevi) + parti kasasına ödül; ayın en aktif üyesi.
--   4) Aylık sezon sıralamaları ve ödüller (Ayın Siyasetçisi, Vekili, İş İnsanı, Kalemi); Haftanın Kalemi (Kürsü).
--   5) Unvanlar: Kıdemli Vekil, Üç Dönem Başkan, Gölge Bakan + kazanılan ödüller oyuncu kartındaki rozetlerde.
--   6) Akıllı bildirimler: oylama bitmeden oy vermemiş vekile, rakip fiyat kırınca, parti hedefi bitmek üzereyken.
--   7) Gölge kabine: ana muhalefet partisi her bakanlığa gölge bakan atar, denetim raporu yayımlar.
-- Oyuncu verisini dönüştürmez.

-- ===================== TABLOLAR =====================
create table if not exists oyun.meclis_yoklama (gun date not null, user_id uuid not null, zaman timestamptz not null default now(), primary key (gun, user_id));
create table if not exists oyun.arena_odul (
  id bigserial primary key, user_id uuid not null, kod text not null, ad text not null, aciklama text, donem text not null, zaman timestamptz not null default now(),
  unique (user_id, kod, donem));
create table if not exists oyun.parti_hedef (
  parti_id bigint not null, hafta date not null, kod text not null, ad text not null, hedef int not null, odul numeric not null default 0,
  tamam_at timestamptz, primary key (parti_id, hafta, kod));
create table if not exists oyun.golge_kabine (parti_id bigint not null, bakanlik text not null, user_id uuid not null, atama timestamptz not null default now(), primary key (parti_id, bakanlik));
create table if not exists oyun.golge_gecmis (user_id uuid not null, bakanlik text not null, parti_id bigint, bas timestamptz not null default now(), primary key (user_id, bakanlik, bas));
create table if not exists oyun.golge_rapor (id bigserial primary key, parti_id bigint, bakanlik text not null, yazar uuid not null, baslik text not null, metin text not null, zaman timestamptz not null default now());
create index if not exists golge_rapor_zaman_ix on oyun.golge_rapor(zaman desc);
create table if not exists oyun.akilli_bildirim (user_id uuid not null, anahtar text not null, zaman timestamptz not null default now(), primary key (user_id, anahtar));
do $$ declare s text; begin
  foreach s in array array['meclis_yoklama','arena_odul','parti_hedef','golge_kabine','golge_gecmis','golge_rapor','akilli_bildirim'] loop
    execute format('alter table oyun.%I enable row level security', s);
    execute format('revoke all on oyun.%I from public, anon, authenticated', s);
  end loop;
end $$;

insert into oyun.kidem_kaynak(kod, ad, puan, gunluk_tavan, sira) values
  ('meclis_yoklama', 'Akşam Genel Kurul oturumuna katılmak', 1, 1, 22),
  ('parti_hedef',    'Partinin haftalık hedefine katkı',     1, 3, 34),
  ('golge_rapor',    'Gölge bakan denetim raporu',           1, 1, 35)
on conflict (kod) do update set ad = excluded.ad, sira = excluded.sira;

-- Tek seferlik bildirim (aynı anahtar bir kez)
create or replace function oyun.akilli_bildir(u uuid, p_anahtar text, p_metin text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if u is null then return false; end if;
  insert into oyun.akilli_bildirim(user_id, anahtar, zaman) values (u, p_anahtar, oyun.simdi()) on conflict do nothing;
  if not found then return false; end if;
  perform oyun.bildir(u, p_metin, oyun.simdi());
  return true;
end $$;

create or replace function oyun.arena_odul_ver(u uuid, p_kod text, p_ad text, p_aciklama text, p_donem text, p_kidem numeric) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if u is null then return false; end if;
  insert into oyun.arena_odul(user_id, kod, ad, aciklama, donem) values (u, p_kod, p_ad, p_aciklama, p_donem) on conflict do nothing;
  if not found then return false; end if;
  if coalesce(p_kidem, 0) > 0 then perform oyun.kidem_ekle(u, p_kidem); end if;
  perform oyun.bildir(u, format('Tebrikler! "%s" ödülünü kazandın (%s)%s. Rozet oyuncu kartında görünür.', p_ad, p_donem,
    case when coalesce(p_kidem, 0) > 0 then format(', +%s kıdem', p_kidem) else '' end), oyun.simdi());
  return true;
end $$;

-- ===================== 1) CANLI GENEL KURUL (21:00–22:00) =====================
create or replace function oyun.meclis_oturum_durum(t timestamptz) returns jsonb
language sql stable set search_path = '' as $$
  with z as (select (t at time zone 'Europe/Istanbul') yerel),
  g as (select (yerel::date + time '21:00') at time zone 'Europe/Istanbul' as o_bas, (yerel::date + time '22:00') at time zone 'Europe/Istanbul' as o_bit, yerel::date as gun from z)
  select jsonb_build_object('gun', g.gun, 'bas', g.o_bas, 'bit', g.o_bit, 'acik', t >= g.o_bas and t < g.o_bit,
    'sonraki', case when t < g.o_bas then g.o_bas else g.o_bas + interval '1 day' end) from g
$$;

create or replace function public.meclis_oturum() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d jsonb := oyun.meclis_oturum_durum(oyun.simdi()); g date;
begin
  g := (d ->> 'gun')::date;
  return d || jsonb_build_object(
    'vekil', exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null),
    'yoklamada', exists(select 1 from oyun.meclis_yoklama y where y.gun = g and y.user_id = p.id),
    'vekil_sayisi', (select count(distinct m.user_id) from oyun.makamlar m where m.tur = 'mv' and m.bit is null),
    'katilan', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', pa.kisa, 'renk', pa.renk) order by y.zaman)
       from oyun.meclis_yoklama y join oyun.profiller pr on pr.id = y.user_id left join oyun.partiler pa on pa.id = pr.parti_id where y.gun = g), '[]'::jsonb),
    'katilmayan', case when (d ->> 'acik')::boolean or t >= (d ->> 'bit')::timestamptz then coalesce((select jsonb_agg(distinct pr.kad)
       from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id where m.tur = 'mv' and m.bit is null
         and not exists(select 1 from oyun.meclis_yoklama y where y.gun = g and y.user_id = m.user_id)), '[]'::jsonb) else '[]'::jsonb end,
    'oylamalar', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'no', k.no, 'baslik', k.baslik, 'bit', k.oy_bit, 'tur', k.tur,
        'kabul', (select count(*) from oyun.kanun_oylari o where o.kanun_id = k.id and o.oy = 'kabul'),
        'ret', (select count(*) from oyun.kanun_oylari o where o.kanun_id = k.id and o.oy = 'ret'),
        'cekimser', (select count(*) from oyun.kanun_oylari o where o.kanun_id = k.id and o.oy = 'cekimser'),
        'oyum', (select o.oy from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = p.id order by o.zaman desc limit 1)) order by k.oy_bit)
      from oyun.kanunlar k where k.durum = 'oylamada' and coalesce(k.oy_bit, t + interval '1 hour') > t), '[]'::jsonb));
end $$;

create or replace function public.meclis_yoklama() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d jsonb := oyun.meclis_oturum_durum(oyun.simdi()); ek numeric := 0;
begin
  if not exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null) then
    raise exception 'Yoklamaya yalnız milletvekilleri katılır.'; end if;
  if not (d ->> 'acik')::boolean then
    raise exception 'Genel Kurul her akşam 21:00–22:00 arasında toplanır.'; end if;
  insert into oyun.meclis_yoklama(gun, user_id, zaman) values ((d ->> 'gun')::date, p.id, t) on conflict do nothing;
  if found then ek := oyun.kidem_ekle(p.id, 'meclis_yoklama'); end if;
  return jsonb_build_object('tamam', true, 'kidem', ek);
end $$;

-- ===================== 2) BEKLEYEN İŞLERİM =====================
create or replace function public.bekleyen_islerim() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); l jsonb := '[]'::jsonb; cb boolean; v_gb bigint;
begin
  if p.id is null then return l; end if;
  cb := exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null);
  select pa.id into v_gb from oyun.partiler pa where pa.gb = p.id and not pa.kapali limit 1;
  -- Vekil: oy vermediği açık kanun oylamaları
  if exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null) then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'oylama', 'oncelik', 1, 'baslik', 'Kanun oylaması: ' || k.baslik,
        'alt', 'Oyunu henüz kullanmadın', 'bit', k.oy_bit, 'id', k.id, 'git', 'meclis') order by k.oy_bit)
      from oyun.kanunlar k where k.durum = 'oylamada' and coalesce(k.oy_bit, t + interval '1 hour') > t
        and not exists(select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = p.id)), '[]'::jsonb);
  end if;
  -- Cumhurbaşkanı: bakanlıkların ek ödenek talepleri
  if cb then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'odenek', 'oncelik', 1, 'baslik', 'Ek ödenek talebi: ' || o.kod,
        'alt', format('%s milyar ₺ · %s', o.tutar, left(coalesce(o.gerekce, ''), 60)), 'bit', o.bitis, 'id', o.id, 'git', 'butce'))
      from oyun.bakanlik_odenek_talep o where o.durum = 'bekliyor' and coalesce(o.bitis, t + interval '1 day') > t), '[]'::jsonb);
  end if;
  -- Kurucu davetleri
  l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'kurucu', 'oncelik', 2, 'baslik', 'Kurucu daveti: ' || b.ad,
      'alt', 'Kurucular kuruluna çağrıldın', 'bit', b.bit, 'id', b.id, 'git', 'kurucu'))
    from oyun.kurucu_davet d join oyun.kurucu_basvuru b on b.id = d.basvuru_id
    where d.user_id = p.id and d.durum = 'bekliyor' and b.durum = 'bekliyor' and b.bit > t), '[]'::jsonb);
  -- Genel başkan: yanıt bekleyen ittifak ortak aday teklifleri, eksik gölge kabine
  if v_gb is not null then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'ittifak', 'oncelik', 2, 'baslik', 'İttifak ortak aday teklifi',
        'alt', 'Partin adına yanıt ver', 'bit', null, 'id', x.id, 'git', 'parti'))
      from oyun.ittifak_ortak_teklif x join oyun.ittifak_uyeler iu on iu.ittifak_id = x.ittifak_id and iu.parti_id = v_gb
      where coalesce(x.durum, 'bekliyor') = 'bekliyor' and x.teklif_eden is distinct from v_gb
        and not exists(select 1 from oyun.ittifak_ortak_yanit y where y.teklif_id = x.id and y.parti_id = v_gb)), '[]'::jsonb);
    if oyun.ana_muhalefet() = v_gb and (select count(*) from oyun.golge_kabine g where g.parti_id = v_gb) < (select count(*) from oyun.bakanlik_kasa) then
      l := l || jsonb_build_array(jsonb_build_object('tur', 'golge', 'oncelik', 3, 'baslik', 'Gölge kabineni tamamla',
        'alt', format('%s/%s bakanlığa gölge bakan atandı', (select count(*) from oyun.golge_kabine g where g.parti_id = v_gb), (select count(*) from oyun.bakanlik_kasa)), 'git', 'golge'));
    end if;
  end if;
  -- Parti hedefi son 24 saat
  if p.parti_id is not null then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'hedef', 'oncelik', 3, 'baslik', 'Parti hedefi: ' || h.ad,
        'alt', format('%s / %s', oyun.parti_hedef_ilerleme(h.parti_id, h.hafta, h.kod), h.hedef), 'bit', h.hafta + 7, 'git', 'hedef'))
      from oyun.parti_hedef h where h.parti_id = p.parti_id and h.hafta = oyun.arena_hafta(t) and h.tamam_at is null
        and t > ((h.hafta + 6)::timestamp at time zone 'Europe/Istanbul')), '[]'::jsonb);
  end if;
  return l;
end $$;

-- ===================== 3) HAFTALIK PARTİ HEDEFLERİ =====================
create or replace function oyun.arena_hafta(t timestamptz) returns date language sql immutable as $$
  select date_trunc('week', (t at time zone 'Europe/Istanbul'))::date
$$;

create or replace function oyun.parti_hedef_ilerleme(p_parti bigint, p_hafta date, p_kod text) returns int
language sql stable set search_path = '' as $$
  with a as (select (p_hafta::timestamp at time zone 'Europe/Istanbul') as a_bas, ((p_hafta + 7)::timestamp at time zone 'Europe/Istanbul') as a_bit)
  select (case p_kod
    when 'miting' then (select count(*) from oyun.mitingler m, a where m.parti_id = p_parti and m.bas >= a.a_bas and m.bas < a.a_bit)
    when 'meclis_oy' then (select count(*) from oyun.kanun_oylari o, a where o.parti_id = p_parti and o.zaman >= a.a_bas and o.zaman < a.a_bit)
    when 'kursu' then (select count(*) from oyun.akis k join oyun.profiller pr on pr.id = k.user_id, a where pr.parti_id = p_parti and k.zaman >= a.a_bas and k.zaman < a.a_bit and k.yanit_id is null)
    when 'stant' then (select count(*) from oyun.stant s, a where s.parti_id = p_parti and s.bas >= a.a_bas and s.bas < a.a_bit)
    when 'yoklama' then (select count(*) from oyun.meclis_yoklama y join oyun.profiller pr on pr.id = y.user_id, a
                         where pr.parti_id = p_parti and y.zaman >= a.a_bas and y.zaman < a.a_bit)
    else 0 end)::int
$$;

create or replace function oyun.parti_hedef_olustur(t timestamptz) returns int
language plpgsql security definer set search_path = '' as $$
declare h date := oyun.arena_hafta(t); r record; n int := 0; mv int; v_odul numeric := round(25000 * coalesce((select endeks from oyun.ulke where id = 1), 1) / 100) * 100;
begin
  for r in select pa.id, (select count(*) from oyun.profiller p where p.parti_id = pa.id and not p.yasakli and p.son_gorulme > t - interval '14 days') uye
           from oyun.partiler pa where not pa.kapali loop
    if r.uye < 2 or exists(select 1 from oyun.parti_hedef where parti_id = r.id and hafta = h) then continue; end if;
    select count(distinct m.user_id) into mv from oyun.makamlar m join oyun.profiller p on p.id = m.user_id where m.tur = 'mv' and m.bit is null and p.parti_id = r.id;
    insert into oyun.parti_hedef(parti_id, hafta, kod, ad, hedef, odul) values
      (r.id, h, 'miting', 'Hafta içinde miting düzenleyin', greatest(2, ceil(r.uye / 2.0))::int, v_odul),
      (r.id, h, 'kursu', 'Kürsü''de partiyi duyurun (gönderi)', greatest(10, r.uye * 5)::int, v_odul),
      (r.id, h, case when mv > 0 then 'yoklama' else 'stant' end,
                case when mv > 0 then 'Akşam Genel Kurul yoklamasına katılın' else 'Parti stantı açın' end,
                case when mv > 0 then greatest(3, mv * 3) else 2 end, v_odul)
    on conflict do nothing;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function oyun.parti_hedef_kontrol(t timestamptz) returns int
language plpgsql security definer set search_path = '' as $$
declare h date := oyun.arena_hafta(t); r record; n int := 0; u uuid;
begin
  for r in select * from oyun.parti_hedef where hafta = h and tamam_at is null loop
    if oyun.parti_hedef_ilerleme(r.parti_id, r.hafta, r.kod) >= r.hedef then
      update oyun.parti_hedef set tamam_at = t where parti_id = r.parti_id and hafta = r.hafta and kod = r.kod;
      update oyun.partiler set kasa = coalesce(kasa, 0) + r.odul where id = r.parti_id;
      insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (r.parti_id, t, r.odul, 'Haftalık parti hedefi ödülü: ' || r.ad, 'hedef');
      for u in select p.id from oyun.profiller p where p.parti_id = r.parti_id and not p.yasakli and p.son_gorulme > (r.hafta::timestamp at time zone 'Europe/Istanbul') loop
        perform oyun.kidem_ekle(u, 'parti_hedef');
        perform oyun.bildir(u, format('Partinin haftalık hedefi tamamlandı: %s. Parti kasasına %s ₺ eklendi, sana +1 kıdem.', r.ad, oyun.tl(r.odul)), t);
      end loop;
      n := n + 1;
    elsif t > (((r.hafta + 6)::timestamp + time '12:00') at time zone 'Europe/Istanbul') then
      for u in select p.id from oyun.profiller p where p.parti_id = r.parti_id and not p.yasakli loop
        perform oyun.akilli_bildir(u, 'hedef_' || r.parti_id || '_' || r.hafta || '_' || r.kod,
          format('Partinin haftalık hedefi bitmek üzere: %s (%s / %s). Hafta pazar gece bitiyor.', r.ad, oyun.parti_hedef_ilerleme(r.parti_id, r.hafta, r.kod), r.hedef));
      end loop;
    end if;
  end loop;
  return n;
end $$;

create or replace function public.parti_hedefleri(p_parti bigint default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); pid bigint := coalesce(p_parti, p.parti_id); h date := oyun.arena_hafta(oyun.simdi());
  ay_bas timestamptz := (date_trunc('month', oyun.simdi() at time zone 'Europe/Istanbul')) at time zone 'Europe/Istanbul';
begin
  if pid is null then return jsonb_build_object('parti', null); end if;
  return jsonb_build_object('parti', (select jsonb_build_object('id', id, 'ad', ad, 'kisa', kisa, 'renk', renk) from oyun.partiler where id = pid),
    'hafta', h, 'bitis', ((h + 7)::timestamp at time zone 'Europe/Istanbul'),
    'hedefler', coalesce((select jsonb_agg(jsonb_build_object('kod', x.kod, 'ad', x.ad, 'hedef', x.hedef, 'odul', x.odul, 'tamam', x.tamam_at is not null,
        'ilerleme', oyun.parti_hedef_ilerleme(x.parti_id, x.hafta, x.kod)) order by x.kod) from oyun.parti_hedef x where x.parti_id = pid and x.hafta = h), '[]'::jsonb),
    'ayin_uyeleri', coalesce((select jsonb_agg(jsonb_build_object('kad', q.kad, 'puan', q.puan) order by q.puan desc) from (
        select pr.kad, oyun.aktiflik_puani(pr.id, ay_bas, ((ay_bas at time zone 'Europe/Istanbul') + interval '1 month') at time zone 'Europe/Istanbul') puan
        from oyun.profiller pr where pr.parti_id = pid and not pr.yasakli) q where q.puan > 0), '[]'::jsonb));
end $$;

-- ===================== 4) SIRALAMALAR ve ÖDÜLLER =====================
-- Aktiflik puanı: dönemdeki kıdem kazanımları + seçimlerde kullanılan her oy için 2
create or replace function oyun.aktiflik_puani(u uuid, p_bas timestamptz, p_bit timestamptz) returns numeric
language sql stable set search_path = '' as $$
  select coalesce((select sum(k.puan) from oyun.kidem_kazanc k where k.user_id = u and k.gun >= (p_bas at time zone 'Europe/Istanbul')::date and k.gun < (p_bit at time zone 'Europe/Istanbul')::date), 0)
       + 2 * (select count(*) from oyun.oylar o where o.secmen = u and o.zaman >= p_bas and o.zaman < p_bit)
$$;

create or replace function oyun.siralama_listesi(p_kod text, p_bas timestamptz, p_bit timestamptz, p_n int) returns jsonb
language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('user_id', x.uid, 'kad', pr.kad, 'parti', pa.kisa, 'renk', pa.renk, 'deger', x.deger, 'not', x.notu) order by x.deger desc), '[]'::jsonb)
  from (
    select q.uid, q.deger, q.notu from (
      select z.uid, sum(z.v) deger, 'aktiflik puanı' notu from (
        select k.user_id uid, k.puan v from oyun.kidem_kazanc k
          where k.gun >= (p_bas at time zone 'Europe/Istanbul')::date and k.gun < (p_bit at time zone 'Europe/Istanbul')::date
        union all select o.secmen, 2 from oyun.oylar o where o.zaman >= p_bas and o.zaman < p_bit) z
      where p_kod = 'siyasetci' group by z.uid
      union all
      select o.vekil, count(*) + coalesce((select count(*) from oyun.meclis_yoklama y where y.user_id = o.vekil and y.zaman >= p_bas and y.zaman < p_bit), 0), 'oy + yoklama'
      from oyun.kanun_oylari o where p_kod = 'vekil' and o.zaman >= p_bas and o.zaman < p_bit group by o.vekil
      union all
      select w.sahip, sum(w.deger), 'şirket değeri (₺)' from (
        select oyun.sirket_sahibi(s.id) sahip, oyun.sirket_deger(s.id) deger from oyun.sirketler s where p_kod = 'is_insani' and s.aktif) w
      where w.sahip is not null group by w.sahip
      union all
      select a.user_id, sum((select count(*) from oyun.akis_begeni b where b.akis_id = a.id) - (select count(*) from oyun.akis_begenmeme b where b.akis_id = a.id)
             + 2 * (select count(*) from oyun.akis y where y.yanit_id = a.id and y.user_id <> a.user_id)), 'beğeni + yanıt'
      from oyun.akis a where p_kod = 'kalem' and a.zaman >= p_bas and a.zaman < p_bit and not coalesce(a.gizli, false) group by a.user_id
    ) q join oyun.profiller pp on pp.id = q.uid where q.deger > 0 and not pp.yasakli order by q.deger desc limit p_n) x
  join oyun.profiller pr on pr.id = x.uid left join oyun.partiler pa on pa.id = pr.parti_id
$$;

create or replace function public.siralamalar(p_donem text default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); v_bas timestamptz; v_bit timestamptz; ad text;
begin
  if p_donem is not null and p_donem ~ '^\d{4}-\d{2}$' then v_bas := (p_donem || '-01')::timestamp at time zone 'Europe/Istanbul';
  else v_bas := date_trunc('month', t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul'; end if;
  v_bit := ((v_bas at time zone 'Europe/Istanbul') + interval '1 month') at time zone 'Europe/Istanbul';
  ad := to_char(v_bas at time zone 'Europe/Istanbul', 'YYYY-MM');
  return jsonb_build_object('donem', ad, 'bas', v_bas, 'bit', v_bit, 'canli', t < v_bit,
    'siyasetci', oyun.siralama_listesi('siyasetci', v_bas, v_bit, 10), 'vekil', oyun.siralama_listesi('vekil', v_bas, v_bit, 10),
    'is_insani', oyun.siralama_listesi('is_insani', v_bas, v_bit, 10), 'kalem', oyun.siralama_listesi('kalem', v_bas, v_bit, 10),
    'haftanin_kalemi', (select jsonb_agg(jsonb_build_object('kad', pr.kad, 'donem', o.donem) order by o.zaman desc) from (select * from oyun.arena_odul where kod = 'haftanin_kalemi' order by zaman desc limit 4) o join oyun.profiller pr on pr.id = o.user_id),
    'odullu', (select jsonb_agg(jsonb_build_object('kad', pr.kad, 'ad', o.ad, 'donem', o.donem) order by o.zaman desc) from (select * from oyun.arena_odul where kod like 'ayin_%' order by zaman desc limit 8) o join oyun.profiller pr on pr.id = o.user_id));
end $$;

-- Ay başında geçen ayın birincilerine ödül; pazartesi geçen haftanın Kürsü kalemine ödül
create or replace function oyun.arena_odul_tick(t timestamptz) returns int
language plpgsql security definer set search_path = '' as $$
declare v_bas timestamptz; v_bit timestamptz; donem text; x jsonb; n int := 0; hb date; hbas timestamptz; hbit timestamptz; k record;
begin
  v_bit := date_trunc('month', t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
  v_bas := ((v_bit at time zone 'Europe/Istanbul') - interval '1 month') at time zone 'Europe/Istanbul';
  donem := to_char(v_bas at time zone 'Europe/Istanbul', 'YYYY-MM');
  if v_bas >= '2026-10-01 00:00+03' and not exists(select 1 from oyun.tek_seferlik where anahtar = 'arena_ay_' || donem) then
    insert into oyun.tek_seferlik(anahtar) values ('arena_ay_' || donem) on conflict do nothing;
    for k in select * from (values ('siyasetci', 'ayin_siyasetcisi', 'Ayın Siyasetçisi'), ('vekil', 'ayin_vekili', 'Ayın Vekili'),
                                   ('is_insani', 'ayin_is_insani', 'Ayın İş İnsanı'), ('kalem', 'ayin_kalemi', 'Ayın Kalemi')) v(liste, kod, ad) loop
      x := oyun.siralama_listesi(k.liste, v_bas, v_bit, 1) -> 0;
      if x is not null and oyun.arena_odul_ver((x ->> 'user_id')::uuid, k.kod, k.ad, format('%s ayının birincisi', donem), donem, 5) then
        perform oyun.gazete_ekle('duyuru', format('%s: %s', k.ad, x ->> 'kad'), format('%s ayının "%s" ödülü %s''e verildi (%s %s).', donem, k.ad, x ->> 'kad', x ->> 'deger', x ->> 'not'), null, t);
        perform oyun.olay('siyaset', format('%s ayında "%s" ödülü %s''in oldu.', donem, k.ad, x ->> 'kad'), null, null, t);
        n := n + 1;
      end if;
    end loop;
  end if;
  hb := oyun.arena_hafta(t) - 7; hbas := hb::timestamp at time zone 'Europe/Istanbul'; hbit := (hb + 7)::timestamp at time zone 'Europe/Istanbul';
  if not exists(select 1 from oyun.tek_seferlik where anahtar = 'arena_kalem_' || hb) then
    insert into oyun.tek_seferlik(anahtar) values ('arena_kalem_' || hb) on conflict do nothing;
    x := oyun.siralama_listesi('kalem', hbas, hbit, 1) -> 0;
    if x is not null and oyun.arena_odul_ver((x ->> 'user_id')::uuid, 'haftanin_kalemi', 'Haftanın Kalemi', 'Kürsü''de haftanın en çok konuşulanı', to_char(hb, 'IYYY-"H"IW'), 2) then
      perform oyun.olay('siyaset', format('Haftanın Kalemi: %s (Kürsü''de %s).', x ->> 'kad', x ->> 'deger' || ' ' || (x ->> 'not')), null, null, t);
      n := n + 1;
    end if;
  end if;
  return n;
end $$;

-- ===================== 5) UNVANLAR ve ROZETLER =====================
create or replace function oyun.rozetler(u uuid)
 returns jsonb language sql stable as $function$
  select coalesce(jsonb_agg(r order by r ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '01', 'ad', 'Cumhurbaşkanı', 'aciklama', 'Cumhurbaşkanlığı yaptı') r where exists (select 1 from oyun.makamlar where user_id = u and tur = 'cb')
    union all select jsonb_build_object('sira', '02', 'ad', 'Bakan', 'aciklama', 'Kabinede görev aldı') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bakan')
    union all select jsonb_build_object('sira', '03', 'ad', 'Genel Başkan', 'aciklama', 'Bir partinin genel başkanı oldu')
      where exists (select 1 from oyun.partiler where gb = u) or exists (select 1 from oyun.kazananlar k join oyun.secimler s on s.id = k.secim_id where k.user_id = u and s.tur = 'kurultay')
    union all select jsonb_build_object('sira', '04', 'ad', 'Milletvekili', 'aciklama', 'Meclis''e girdi') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv')
    union all select jsonb_build_object('sira', '05', 'ad', 'Belediye Başkanı', 'aciklama', 'Bir ili yönetti') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bel')
    union all select jsonb_build_object('sira', '06', 'ad', 'Kanun Yapıcı', 'aciklama', 'Teklifi yasalaştı') where exists (select 1 from oyun.kanunlar where teklif_eden = u and durum = 'yururlukte')
    union all select jsonb_build_object('sira', '07', 'ad', 'Parti Kurucusu', 'aciklama', 'Yeni bir parti kurdu') where exists (select 1 from oyun.partiler where kurucu = u)
    union all select jsonb_build_object('sira', '08', 'ad', 'Hatip', 'aciklama', '10+ propaganda yayını') where (select count(*) from oyun.yayinlar where gonderen = u) >= 10
    union all select jsonb_build_object('sira', '09', 'ad', 'Demokrasi Emektarı', 'aciklama', '20+ seçimde oy kullandı') where (select count(*) from oyun.oylar where secmen = u) >= 20
    union all select jsonb_build_object('sira', '10', 'ad', 'Sandık Neferi', 'aciklama', 'İlk oyunu kullandı') where (select count(*) from oyun.oylar where secmen = u) between 1 and 19
    union all select jsonb_build_object('sira', '11', 'ad', 'Kurucu Vatandaş', 'aciklama', 'Oyunun ilk vatandaşlarından')
      where exists (select 1 from oyun.profiller p, oyun.ayarlar a where p.id = u and a.id = 1 and p.olusturma <= coalesce(a.kurucu_rozet_bitis, '2026-12-31 23:59:59+03'))
    union all select jsonb_build_object('sira', '12', 'ad', 'Sandık Görevlisi', 'aciklama', 'Müşahit olarak sandık başında görev yaptı') where exists (select 1 from oyun.musahit where user_id = u and sandik_at is not null)
    union all select jsonb_build_object('sira', '13', 'ad', 'Yol Arkadaşı', 'aciklama', 'Yeni bir oyuncuya oyunda eşlik etti') where exists (select 1 from oyun.mentor_bag where mentor = u and odul_at is not null)
    -- 154: unvanlar ve kazanılan ödüller
    union all select jsonb_build_object('sira', '14', 'ad', 'Kıdemli Vekil', 'aciklama', 'En az 3 dönem milletvekilliği') where (select count(*) from oyun.makamlar where user_id = u and tur = 'mv') >= 3
    union all select jsonb_build_object('sira', '15', 'ad', 'Üç Dönem Başkan', 'aciklama', 'En az 3 dönem belediye başkanlığı') where (select count(*) from oyun.makamlar where user_id = u and tur = 'bel') >= 3
    union all select jsonb_build_object('sira', '16', 'ad', 'Gölge Bakan', 'aciklama', 'Ana muhalefetin gölge kabinesinde görev aldı') where exists (select 1 from oyun.golge_gecmis where user_id = u)
    union all select jsonb_build_object('sira', '17', 'ad', 'Meclis Müdavimi', 'aciklama', '20+ akşam oturumuna katıldı') where (select count(*) from oyun.meclis_yoklama where user_id = u) >= 20
    union all select jsonb_build_object('sira', '2' || o.kod, 'ad', o.ad || case when o.adet > 1 then ' ×' || o.adet else '' end, 'aciklama', o.aciklama)
      from (select kod, max(ad) ad, max(aciklama) aciklama, count(*) adet from oyun.arena_odul where user_id = u group by kod) o
  ) x
$function$;

-- ===================== 6) AKILLI BİLDİRİMLER =====================
-- Oylamanın bitmesine 3 saatten az kala oy vermemiş vekile bir kez
create or replace function oyun.oylama_hatirlat(t timestamptz) returns int
language plpgsql security definer set search_path = '' as $$
declare k record; u uuid; n int := 0;
begin
  for k in select id, baslik, oy_bit from oyun.kanunlar where durum = 'oylamada' and oy_bit > t and oy_bit < t + interval '3 hours' loop
    for u in select distinct m.user_id from oyun.makamlar m where m.tur = 'mv' and m.bit is null
               and not exists(select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = m.user_id) loop
      if oyun.akilli_bildir(u, 'oylama_' || k.id, format('Partin ve seçmenin oyunu bekliyor: "%s" oylaması %s''de bitiyor, henüz oy kullanmadın.',
           k.baslik, to_char(k.oy_bit at time zone 'Europe/Istanbul', 'HH24:MI'))) then n := n + 1; end if;
    end loop;
  end loop;
  return n;
end $$;

-- Akşam oturumu daveti (20:30–21:00) ve oturum özeti (22:00 sonrası)
create or replace function oyun.meclis_oturum_tick(t timestamptz) returns int
language plpgsql security definer set search_path = '' as $$
declare d jsonb := oyun.meclis_oturum_durum(t); g date := (d ->> 'gun')::date; u uuid; n int := 0; ac int; kat int; top int;
begin
  ac := (select count(*) from oyun.kanunlar where durum = 'oylamada' and coalesce(oy_bit, t + interval '1 hour') > t);
  if t >= (d ->> 'bas')::timestamptz - interval '30 minutes' and t < (d ->> 'bit')::timestamptz then
    for u in select distinct m.user_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id where m.tur = 'mv' and m.bit is null and not p.yasakli
               and not exists(select 1 from oyun.meclis_yoklama y where y.gun = g and y.user_id = m.user_id) loop
      if oyun.akilli_bildir(u, 'meclis_davet_' || g, format('TBMM Genel Kurulu bu akşam 21:00''de toplanıyor%s. Yoklamaya katıl: +1 kıdem. Katılmayanlar herkese açık listelenir.',
           case when ac > 0 then format('; %s kanun oylamada', ac) else '' end)) then n := n + 1; end if;
    end loop;
  end if;
  if t >= (d ->> 'bit')::timestamptz and not exists(select 1 from oyun.tek_seferlik where anahtar = 'meclis_ozet_' || g) then
    insert into oyun.tek_seferlik(anahtar) values ('meclis_ozet_' || g) on conflict do nothing;
    select count(*) into kat from oyun.meclis_yoklama where gun = g;
    select count(distinct user_id) into top from oyun.makamlar where tur = 'mv' and bit is null;
    if top > 0 then
      perform oyun.olay('meclis', format('TBMM Genel Kurulu akşam oturumu: %s vekilden %s''i yoklamada hazır bulundu, %s vekil katılmadı.', top, kat, top - kat), null, null, t);
    end if;
  end if;
  return n;
end $$;

-- Rakip fiyat kırınca aynı il ve sektördeki diğer şirket sahiplerine (günde bir kez)
create or replace function oyun.tg_rakip_fiyat() returns trigger
language plpgsql security definer set search_path = '' as $$
declare s record; x record; g text := to_char(oyun.simdi() at time zone 'Europe/Istanbul', 'YYYYMMDD'); ilad text;
begin
  if new.fiyat is null or old.fiyat is null or new.fiyat >= old.fiyat then return null; end if;
  select id, ad, sektor into s from oyun.sirketler where id = new.sirket_id;
  select ad into ilad from oyun.iller where id = new.il_id;
  for x in select distinct oyun.sirket_sahibi(s2.id) sahip, s2.id, s2.ad from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
           where p2.il_id = new.il_id and s2.sektor = s.sektor and s2.aktif and s2.id <> s.id loop
    if x.sahip is not null and x.sahip is distinct from oyun.sirket_sahibi(s.id) then
      perform oyun.akilli_bildir(x.sahip, 'fiyat_' || x.id || '_' || g, format('Rakibin %s, %s pazarında fiyat kırdı. %s şirketinin fiyat ve kalitesini gözden geçir.', s.ad, coalesce(ilad, ''), x.ad));
    end if;
  end loop;
  return null;
exception when others then return null;
end $$;
create or replace trigger tg_rakip_fiyat after update of fiyat on oyun.pazar_sirket for each row execute function oyun.tg_rakip_fiyat();

-- ===================== 7) GÖLGE KABİNE =====================
-- Ana muhalefet: cumhurbaşkanının partisi dışında en çok milletvekili olan açık parti
create or replace function oyun.ana_muhalefet() returns bigint
language sql stable set search_path = '' as $$
  select p.parti_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
  where m.tur = 'mv' and m.bit is null and p.parti_id is not null
    and p.parti_id is distinct from (select pc.parti_id from oyun.makamlar mc join oyun.profiller pc on pc.id = mc.user_id where mc.tur = 'cb' and mc.bit is null limit 1)
    and exists(select 1 from oyun.partiler pa where pa.id = p.parti_id and not pa.kapali)
  group by p.parti_id order by count(distinct m.user_id) desc, min(p.parti_id) limit 1
$$;

create or replace function public.golge_kabine() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); am bigint := oyun.ana_muhalefet();
begin
  return jsonb_build_object('parti', (select jsonb_build_object('id', id, 'ad', ad, 'kisa', kisa, 'renk', renk) from oyun.partiler where id = am),
    'gb_benim', exists(select 1 from oyun.partiler where id = am and gb = p.id),
    'uye', p.parti_id is not distinct from am and am is not null,
    'bakanliklar', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', oyun.makam_ad('bakan', null, b.kod),
        'bakan', (select pr.kad from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id where m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null limit 1),
        'golge', (select pr.kad from oyun.golge_kabine g join oyun.profiller pr on pr.id = g.user_id where g.parti_id = am and g.bakanlik = b.kod),
        'golge_benim', exists(select 1 from oyun.golge_kabine g where g.parti_id = am and g.bakanlik = b.kod and g.user_id = p.id)) order by b.kod)
      from oyun.bakanlik_kasa b),
    'raporlar', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'bakanlik', r.bakanlik, 'bakanlik_ad', oyun.makam_ad('bakan', null, r.bakanlik), 'yazar', pr.kad,
        'parti', pa.kisa, 'renk', pa.renk, 'baslik', r.baslik, 'metin', r.metin, 'zaman', r.zaman) order by r.zaman desc)
      from (select * from oyun.golge_rapor order by zaman desc limit 20) r join oyun.profiller pr on pr.id = r.yazar left join oyun.partiler pa on pa.id = r.parti_id), '[]'::jsonb));
end $$;

create or replace function public.golge_ata(p_bakanlik text, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); am bigint := oyun.ana_muhalefet(); h oyun.profiller; t timestamptz := oyun.simdi();
begin
  if am is null or not exists(select 1 from oyun.partiler where id = am and gb = p.id) then raise exception 'Gölge kabineyi yalnız ana muhalefet partisinin genel başkanı kurar.'; end if;
  if not exists(select 1 from oyun.bakanlik_kasa where kod = p_bakanlik) then raise exception 'Geçersiz bakanlık.'; end if;
  if coalesce(btrim(p_kad), '') = '' then
    raise exception 'Gölge bakan için partinden bir üyenin kullanıcı adını yaz. Değiştirmek için yeni adı yazman yeterli.';
  end if;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(p_kad)) and not yasakli;
  if h.id is null or h.parti_id is distinct from am then raise exception 'Gölge bakan partinin üyesi olmalı.'; end if;
  if exists(select 1 from oyun.golge_kabine where parti_id = am and user_id = h.id and bakanlik <> p_bakanlik) then raise exception '% zaten başka bir bakanlığın gölge bakanı.', h.kad; end if;
  insert into oyun.golge_kabine(parti_id, bakanlik, user_id, atama) values (am, p_bakanlik, h.id, t)
    on conflict (parti_id, bakanlik) do update set user_id = excluded.user_id, atama = excluded.atama;
  insert into oyun.golge_gecmis(user_id, bakanlik, parti_id, bas) values (h.id, p_bakanlik, am, t) on conflict do nothing;
  perform oyun.bildir(h.id, format('%s seni gölge kabinede %s karşısına gölge bakan olarak atadı. Bakanlığı denetle, rapor yayımla: +1 kıdem.', p.kad, oyun.makam_ad('bakan', null, p_bakanlik)), t);
  return jsonb_build_object('tamam', true);
end $$;

create or replace function public.golge_rapor_yaz(p_bakanlik text, p_baslik text, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); am bigint := oyun.ana_muhalefet(); t timestamptz := oyun.simdi(); rid bigint; ek numeric; b text; m text;
begin
  if am is null or p.parti_id is distinct from am then raise exception 'Denetim raporunu ana muhalefetin gölge kabinesi yayımlar.'; end if;
  if not exists(select 1 from oyun.golge_kabine where parti_id = am and bakanlik = p_bakanlik and user_id = p.id)
     and not exists(select 1 from oyun.partiler where id = am and gb = p.id) then
    raise exception 'Bu bakanlığın gölge bakanı değilsin.'; end if;
  b := oyun.metin_temizle(p_baslik, 90); m := oyun.metin_temizle(p_metin, 1200);
  if char_length(coalesce(b, '')) < 5 or char_length(coalesce(m, '')) < 40 then raise exception 'Başlık en az 5, metin en az 40 karakter olmalı.'; end if;
  if exists(select 1 from oyun.golge_rapor where yazar = p.id and zaman > t - interval '6 hours') then raise exception 'Altı saatte bir rapor yayımlayabilirsin.'; end if;
  insert into oyun.golge_rapor(parti_id, bakanlik, yazar, baslik, metin, zaman) values (am, p_bakanlik, p.id, b, m, t) returning id into rid;
  ek := oyun.kidem_ekle(p.id, 'golge_rapor');
  perform oyun.bildir(mb.user_id, format('Gölge bakan %s, bakanlığın hakkında denetim raporu yayımladı: "%s". Siyaset Arenası › Gölge Kabine.', p.kad, b), t)
    from oyun.makamlar mb where mb.tur = 'bakan' and mb.bakanlik = p_bakanlik and mb.bit is null;
  perform oyun.olay('meclis', format('Gölge kabine: %s, %s hakkında rapor yayımladı — %s', p.kad, oyun.makam_ad('bakan', null, p_bakanlik), b), null, am, t);
  return jsonb_build_object('id', rid, 'kidem', ek);
end $$;

-- ===================== ZAMANLAYICI ve YETKİLER =====================
create or replace function oyun.arena_tick() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); a int; b int; c int; d int; e int;
begin
  if not pg_try_advisory_xact_lock(hashtext('arena_tick')) then return null; end if;
  a := oyun.meclis_oturum_tick(t); b := oyun.oylama_hatirlat(t); c := oyun.parti_hedef_olustur(t); d := oyun.parti_hedef_kontrol(t); e := oyun.arena_odul_tick(t);
  return jsonb_build_object('davet', a, 'hatirlat', b, 'hedef_yeni', c, 'hedef_tamam', d, 'odul', e);
end $$;

do $zam$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira)
    select 'siyaset_arenasi', 'select oyun.arena_tick()', 5, 3, 74
     where not exists (select 1 from oyun.zamanlayici_adim z where z.adim = 'siyaset_arenasi');
  end if;
end $zam$;

do $$ declare s text; begin
  foreach s in array array['oyun.akilli_bildir(uuid,text,text)', 'oyun.arena_odul_ver(uuid,text,text,text,text,numeric)', 'oyun.parti_hedef_olustur(timestamptz)',
    'oyun.parti_hedef_kontrol(timestamptz)', 'oyun.arena_odul_tick(timestamptz)', 'oyun.oylama_hatirlat(timestamptz)', 'oyun.meclis_oturum_tick(timestamptz)', 'oyun.arena_tick()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', s);
  end loop;
  foreach s in array array['meclis_oturum()', 'meclis_yoklama()', 'bekleyen_islerim()', 'parti_hedefleri(bigint)', 'siralamalar(text)', 'golge_kabine()',
    'golge_ata(text,text)', 'golge_rapor_yaz(text,text,text)'] loop
    execute format('revoke all on function public.%s from public, anon', s);
    execute format('grant execute on function public.%s to authenticated', s);
  end loop;
end $$;
