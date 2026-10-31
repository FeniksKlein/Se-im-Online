-- 155 (31.10.2026) — YARGI DÜZENİ: üst mahkeme (istinaf jürisi) ve Yüksek Mahkeme heyeti işlemez hale gelmesin
-- İstek (Ercan): itiraz edilen davalarda üst mahkeme üyeleri atandığını bilmiyor ya da oy kullanmıyor, dava sonuçlanmıyor.
--  1) Tarafsızlık: davanın taraflarının (davacı, davalı, ek taraflar, davacı/davalı parti) partilerinden kimse jüriye seçilmez;
--     Yüksek Mahkeme heyetinde de taraf partilerin üyesi olan yargıç o davaya bakmaz. Son çare kura da aynı filtreden geçer.
--  2) Seçim: önce son 24 saatte, sonra 72 saatte, sonra 7 günde oyunda görülenler; aynı anda en çok 2 açık jüri görevi;
--     son 14 günde jüri görevini ihmal eden seçilmez. 3 asıl + 3 yedek.
--  3) Bildirim: "⚖️ JÜRİ GÖREVİ" bildirimi taraflar ve süreyle; Siyaset Arenası › Bekleyen işler ve Gündem kartında en üstte.
--     Oy veren jüri üyesi +1 kıdem.
--  4) Erken değişim: atandıktan sonra 8 saat oyuna hiç girmeyen üyenin yerine hemen yedek (yedek yoksa yeni kura) geçer.
--  5) Süre sonu: 24 saatte çoğunluk yoksa oy vermeyenler değişir + 24 saat ek süre; ek süre de dolarsa VERİLEN oylara göre
--     karar çıkar (en az 2 oy verilmiş ve bozma çoğunluktaysa bozulur; eşitlik, tek oy ya da oy yok → ilk derece kararı onanır).
--     Oy vermeyen 14 gün jüriye seçilmez.
--  6) Yüksek Mahkeme: ek süre dahil oy kullanmayan yargıca ve atayan makama bildirim; tarafsız yargıç 7 gün bulunamazsa
--     dava düşer, harç iade edilir.
--  7) Seçim itirazı: 72 saatte karar verilmezse itiraz reddedilmiş sayılır (sonuç zaten geçerli).
-- Oyuncu verisini dönüştürmez.

alter table oyun.adliye_juri add column if not exists atama timestamptz;
create table if not exists oyun.juri_ihmal (user_id uuid not null, dava_id bigint not null, zaman timestamptz not null default now(), primary key (user_id, dava_id));
alter table oyun.juri_ihmal enable row level security;
revoke all on oyun.juri_ihmal from public, anon, authenticated;
create index if not exists juri_ihmal_zaman_ix on oyun.juri_ihmal(user_id, zaman desc);

insert into oyun.kidem_kaynak(kod, ad, puan, gunluk_tavan, sira) values ('juri_oy', 'İstinaf jürisinde oy kullanmak', 1, 2, 24)
on conflict (kod) do update set ad = excluded.ad, sira = excluded.sira;

-- Davanın taraf partileri
create or replace function oyun.dava_taraf_partileri(d oyun.adliye_davalar) returns bigint[]
language sql stable set search_path = '' as $$
  select coalesce(array_agg(distinct q.x) filter (where q.x is not null), '{}'::bigint[]) from (
    select d.davaci_parti x union all select d.davali_parti
    union all select pr.parti_id from oyun.profiller pr where pr.id in (d.davaci, d.davali)
    union all select pr.parti_id from oyun.adliye_ek_taraf et join oyun.profiller pr on pr.id = et.user_id where et.dava_id = d.id
    union all select case when d.davali_kurum_tur = 'parti' and d.davali_kurum_id ~ '^[0-9]+$' then d.davali_kurum_id::bigint end
  ) q
$$;

create or replace function oyun.dava_taraf_metni(d oyun.adliye_davalar) returns text
language sql stable set search_path = '' as $$
  select format('davacı %s, davalı %s',
    coalesce((select pa.ad from oyun.partiler pa where pa.id = d.davaci_parti), oyun.kad(d.davaci), '—'),
    coalesce(oyun.kad(d.davali), (select pa.ad from oyun.partiler pa where pa.id = d.davali_parti), d.davali_kurum_ad, '—'))
$$;

-- Bir oyuncu bu davada jüri olabilir mi (yedekten asıla geçiş için de kullanılır)
create or replace function oyun.juri_aday_uygun(d oyun.adliye_davalar, u uuid, t timestamptz) returns boolean
language sql stable set search_path = '' as $$
  select oyun.adliye_juri_uygun(d, u)
    and exists(select 1 from oyun.profiller p where p.id = u and not p.yasakli
               and (p.parti_id is null or not (p.parti_id = any(oyun.dava_taraf_partileri(d)))))
    and not exists(select 1 from oyun.juri_ihmal i where i.user_id = u and i.zaman > t - interval '14 days')
$$;

-- Kura: en aktiflerden başlayarak tarafsız p_n kişi
create or replace function oyun.juri_cek(d oyun.adliye_davalar, t timestamptz, p_n int) returns uuid[]
language sql volatile set search_path = '' as $$
  select coalesce(array_agg(q.id order by q.kat, q.rnd), '{}'::uuid[]) from (
    select pr.id, case when pr.son_gorulme > t - interval '24 hours' then 0 when pr.son_gorulme > t - interval '72 hours' then 1
                       when pr.son_gorulme > t - interval '7 days' then 2 else 3 end kat, random() rnd
    from oyun.profiller pr
    where pr.son_gorulme > t - interval '30 days'
      and not exists(select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = pr.id)
      and not exists(select 1 from oyun.adliye_juri_yedek y where y.dava_id = d.id and y.user_id = pr.id)
      and (select count(*) from oyun.adliye_juri j join oyun.adliye_istinaf s on s.dava_id = j.dava_id
            where j.user_id = pr.id and s.durum = 'acik' and j.oy is null) < 2
      and oyun.juri_aday_uygun(d, pr.id, t)
    order by kat, rnd limit p_n) q
$$;

create or replace function oyun.adliye_juri_kur(p_dava bigint, t timestamptz) returns integer
language plpgsql set search_path = '' as $$
declare d oyun.adliye_davalar; secilen uuid[]; u uuid; k int := 0; asil int := 0; taraf text;
begin
  select * into d from oyun.adliye_davalar where id = p_dava;
  if d.id is null then return 0; end if;
  secilen := oyun.juri_cek(d, t, 6);
  taraf := oyun.dava_taraf_metni(d);
  foreach u in array secilen loop
    k := k + 1;
    if k <= 3 then
      insert into oyun.adliye_juri(dava_id, user_id, atama) values (d.id, u, t) on conflict do nothing;
      asil := asil + 1;
      perform oyun.bildir(u, format('⚖️ JÜRİ GÖREVİ: Kura ile Adliye #%s istinaf jürisine ASIL üye seçildin (%s). 24 saat içinde Adliye › Dosya #%s ekranından kararı onayla ya da boz; oy verirsen +1 kıdem. 8 saat içinde oyuna girmezsen yerine yedek geçer ve 14 gün jüriye seçilmezsin.', d.id, taraf, d.id), t);
    else
      insert into oyun.adliye_juri_yedek(dava_id, user_id, sira) values (d.id, u, k - 3) on conflict do nothing;
      perform oyun.bildir(u, format('Kura ile Adliye #%s istinaf jürisine %s. YEDEK üye seçildin (%s). Asıl üyelerden biri görevini yapmazsa yerine geçersin; o zaman ayrıca bildirim alırsın.', d.id, k - 3, taraf), t);
    end if;
  end loop;
  return asil;
end $$;

-- Oy vermeyen jüri üyesinin yerine yedek (yoksa yeni kura) geçirir; yeni üyeyi döner
create or replace function oyun.juri_degistir(p_dava bigint, p_eski uuid, t timestamptz, p_neden text) returns uuid
language plpgsql set search_path = '' as $$
declare d oyun.adliye_davalar; i oyun.adliye_istinaf; yeni uuid; kalan int;
begin
  if not exists(select 1 from oyun.adliye_juri where dava_id = p_dava and user_id = p_eski and oy is null) then return null; end if;
  select * into d from oyun.adliye_davalar where id = p_dava;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  select yy.user_id into yeni from oyun.adliye_juri_yedek yy join oyun.profiller pr on pr.id = yy.user_id
   where yy.dava_id = p_dava and not yy.kullanildi and oyun.juri_aday_uygun(d, yy.user_id, t)
     and not exists(select 1 from oyun.adliye_juri j where j.dava_id = p_dava and j.user_id = yy.user_id)
   order by (pr.son_gorulme > t - interval '24 hours') desc, yy.sira limit 1;
  if yeni is not null then
    update oyun.adliye_juri_yedek set kullanildi = true where dava_id = p_dava and user_id = yeni;
  else
    yeni := (oyun.juri_cek(d, t, 1))[1];
  end if;
  if yeni is null then return null; end if;  -- yerine geçecek tarafsız kimse yoksa üye görevde kalır
  insert into oyun.juri_ihmal(user_id, dava_id, zaman) values (p_eski, p_dava, t) on conflict do nothing;
  perform oyun.bildir(p_eski, format('Adliye #%s istinaf jürisinde %s; yerine başka üye geçti. 14 gün boyunca jüriye seçilmeyeceksin.', p_dava, p_neden), t);
  update oyun.adliye_juri set user_id = yeni, atama = t, gerekce = null where dava_id = p_dava and user_id = p_eski and oy is null;
  kalan := greatest(1, ceil(extract(epoch from (coalesce(i.bit, t + interval '24 hours') - t)) / 3600))::int;
  perform oyun.bildir(yeni, format('⚖️ JÜRİ GÖREVİ: Adliye #%s istinaf jürisine ASIL üye olarak geçtin (%s). Oylamanın bitmesine yaklaşık %s saat var; Adliye › Dosya #%s ekranından kararı onayla ya da boz (+1 kıdem).', p_dava, oyun.dava_taraf_metni(d), kalan, p_dava), t);
  return yeni;
end $$;

create or replace function oyun.adliye_istinaf_sonuc(p_dava bigint, t timestamptz) returns void
language plpgsql set search_path = '' as $$
declare i oyun.adliye_istinaf; onay int; boz int; toplam int; d oyun.adliye_davalar; r record; degisen int := 0; mesaj text;
begin
 select * into i from oyun.adliye_istinaf where dava_id = p_dava for update;
 if i.dava_id is null or i.durum <> 'acik' then return; end if;
 select count(*) filter (where oy = 'onay'), count(*) filter (where oy = 'boz'), count(*) into onay, boz, toplam from oyun.adliye_juri where dava_id = p_dava;
 if not (onay >= oyun.cogunluk(toplam) or boz >= oyun.cogunluk(toplam)) then
  if t < i.bit then return; end if;
  if not i.uzatildi then
   for r in select j.user_id from oyun.adliye_juri j where j.dava_id = p_dava and j.oy is null loop
    if oyun.juri_degistir(p_dava, r.user_id, t, '24 saatlik sürede oy kullanmadın') is not null then degisen := degisen + 1; end if;
   end loop;
   update oyun.adliye_istinaf set uzatildi = true, hatirlatildi = false, bit = bit where dava_id = p_dava;
   update oyun.adliye_davalar set istinaf_son = (select x.bit from oyun.adliye_istinaf x where x.dava_id = p_dava) where id = p_dava;
   perform oyun.bildir(j.user_id, format('Adliye #%s istinaf jürisinde çoğunluk oluşmadı; 24 saat ek süre verildi. Ek süre de dolarsa verilen oylara göre karar çıkar.', p_dava), t)
     from oyun.adliye_juri j where j.dava_id = p_dava and j.oy is null and (j.atama is null or j.atama < t);
   perform oyun.olay('adliye', format('Adliye #%s istinaf jürisi süresinde çoğunluk sağlayamadı; %s üye değiştirildi, 24 saat ek süre verildi.', p_dava, degisen), null, null, t);
   return;
  end if;
  -- Ek süre de doldu: oy vermeyenler 14 gün jüriye seçilmez; karar verilen oylardan çıkar
  for r in select j.user_id from oyun.adliye_juri j where j.dava_id = p_dava and j.oy is null loop
   insert into oyun.juri_ihmal(user_id, dava_id, zaman) values (r.user_id, p_dava, t) on conflict do nothing;
   perform oyun.bildir(r.user_id, format('Adliye #%s istinaf jürisinde ek süre dahil oy kullanmadın; karar diğer üyelerin oylarıyla çıktı. 14 gün boyunca jüriye seçilmeyeceksin.', p_dava), t);
  end loop;
 end if;
 select * into d from oyun.adliye_davalar where id = p_dava for update;
 if boz > onay and boz + onay >= 2 then
  update oyun.adliye_istinaf set durum = 'bozuldu' where dava_id = p_dava;
  update oyun.adliye_davalar set karar = case when d.karar = 'beraat' then 'uyari' else 'beraat' end, ceza_bitis = null, tazminat_tutar = null where id = p_dava;
  if d.davali is not null then perform oyun.adliye_susturma_yenile(d.davali, t); end if;
  perform oyun.adliye_duyur((select user_id from oyun.adliye_juri where dava_id = p_dava and oy = 'boz' order by zaman limit 1),
    format('İstinaf jürisi Adliye #%s kararını BOZDU (%s boz / %s onay). #Adliye', p_dava, boz, onay), array['adliye'], t);
 else
  update oyun.adliye_istinaf set durum = 'onaylandi' where dava_id = p_dava;
  mesaj := case
   when onay + boz = 0 then format('Adliye #%s istinaf jürisi ek süre dahil oy kullanmadı; bozma için çoğunluk oluşmadığından ilk derece kararı onandı.', p_dava)
   when onay + boz = 1 then format('Adliye #%s istinafında ek süre dahil yalnız 1 üye oy kullandı; tek oyla karar bozulamayacağından ilk derece kararı onandı.', p_dava)
   when onay = boz then format('Adliye #%s istinafında oylar eşit (%s/%s); bozma için çoğunluk oluşmadığından ilk derece kararı onandı.', p_dava, onay, boz)
   else format('İstinaf jürisi Adliye #%s kararını onayladı (%s onay / %s boz).', p_dava, onay, boz) end;
  perform oyun.olay('adliye', mesaj, null, null, t);
 end if;
 perform oyun.adliye_kesinlestir(p_dava, t);
end $$;

create or replace function public.adliye_juri_oy(p_dava bigint, p_oy text, p_gerekce text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.adliye_istinaf; ek numeric := 0;
begin
  if p_oy not in ('onay', 'boz') then raise exception 'Onayla ya da boz.'; end if;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  if i.dava_id is null or i.durum <> 'acik' or t >= i.bit then raise exception 'Bu istinaf oylaması açık değil.'; end if;
  update oyun.adliye_juri set oy = p_oy, gerekce = nullif(left(trim(coalesce(p_gerekce, '')), 800), ''), zaman = t
   where dava_id = p_dava and user_id = p.id and oy is null;
  if not found then raise exception 'Bu davanın jürisinde değilsin ya da oyunu zaten verdin.'; end if;
  ek := oyun.kidem_ekle(p.id, 'juri_oy');
  perform oyun.adliye_istinaf_sonuc(p_dava, t);
  return jsonb_build_object('tamam', true, 'kidem', ek);
end $$;

-- Yüksek Mahkeme heyeti: taraf partilerin üyesi olan yargıç o davaya bakmaz
create or replace function oyun.dava_heyeti(d oyun.adliye_davalar) returns uuid[]
language sql stable set search_path = '' as $$
  select coalesce(array_agg(m.user_id order by m.sira), '{}') from oyun.mahkeme_uye m
   where m.user_id is not null and m.user_id is distinct from d.davaci and m.user_id is distinct from d.davali
     and not oyun.adliye_kurum_yetkili(d.davali_kurum_tur, d.davali_kurum_id, m.user_id)
     and not exists (select 1 from oyun.adliye_ek_taraf et where et.dava_id = d.id and et.user_id = m.user_id)
     and not exists (select 1 from oyun.avukat_vekaletleri v where v.dava_id = d.id and v.avukat_id = m.user_id)
     and not exists (select 1 from oyun.partiler pa where pa.id in (d.davaci_parti, d.davali_parti) and pa.gb = m.user_id)
     and not exists (select 1 from oyun.profiller pr where pr.id = m.user_id and pr.parti_id is not null and pr.parti_id = any(oyun.dava_taraf_partileri(d)))
$$;

-- Yüksek Mahkeme: ek süre dahil oy kullanmayan yargıca ve atayan makama bildirim
create or replace function oyun.tg_heyet_ihmal() returns trigger
language plpgsql security definer set search_path = '' as $$
declare mu record; alici uuid; t timestamptz := oyun.simdi();
begin
  if old.durum = 'acik' and new.durum = 'karar' and new.karar_uzatildi then
    for mu in select m.user_id, m.atayan, m.kaynak, m.sira from oyun.mahkeme_uye m
              where m.user_id = any(oyun.dava_heyeti(new))
                and not exists(select 1 from oyun.adliye_karar_oy o where o.dava_id = new.id and o.uye = m.user_id) loop
      perform oyun.bildir(mu.user_id, format('Yüksek Mahkeme: Adliye #%s davasında ek süre dahil oyunu kullanmadın; karar senin oyun olmadan çıktı. Atayan makama bilgi verildi.', new.id), t);
      alici := coalesce(mu.atayan,
        case mu.kaynak when 'meclis' then (select x.user_id from oyun.makamlar x where x.tur = 'tbmm' and x.bit is null limit 1)
                       else (select x.user_id from oyun.makamlar x where x.tur = 'cb' and x.bit is null limit 1) end);
      if alici is not null and alici <> mu.user_id then
        perform oyun.bildir(alici, format('Yüksek Mahkeme %s. üyesi %s, Adliye #%s davasında ek süre dahil oy kullanmadı.', mu.sira, oyun.kad(mu.user_id), new.id), t);
      end if;
    end loop;
  end if;
  return null;
exception when others then return null;
end $$;
create or replace trigger tg_heyet_ihmal after update of durum on oyun.adliye_davalar for each row execute function oyun.tg_heyet_ihmal();

-- Zamanlayıcı: erken jüri değişimi, tarafsız heyet bulunamayan dava, süresi geçen seçim itirazı
create or replace function oyun.yargi_tick() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); r record; dv oyun.adliye_davalar; a int := 0; b int := 0; c int := 0; gb uuid;
begin
  if not pg_try_advisory_xact_lock(hashtext('yargi_tick')) then return null; end if;
  -- 1) Atandıktan sonra 8 saat oyuna girmeyen jüri üyesi değişir (bitişe 2 saatten az kalmadıysa)
  for r in select j.dava_id, j.user_id from oyun.adliye_istinaf i join oyun.adliye_juri j on j.dava_id = i.dava_id join oyun.profiller p on p.id = j.user_id
           where i.durum = 'acik' and j.oy is null and t >= coalesce(j.atama, i.bas) + interval '8 hours' and t < i.bit - interval '2 hours'
             and (coalesce(p.son_gorulme, '-infinity'::timestamptz) < coalesce(j.atama, i.bas) or p.yasakli) loop
    if oyun.juri_degistir(r.dava_id, r.user_id, t, 'atandıktan sonra 8 saat oyuna girmediğin için görevini yapamadın') is not null then a := a + 1; end if;
  end loop;
  -- 2) 7 gündür tarafsız Yüksek Mahkeme heyeti kurulamayan dava düşer
  for dv in select * from oyun.adliye_davalar d where d.durum = 'acik' and d.acilis < t - interval '7 days' and cardinality(oyun.dava_heyeti(d)) = 0 loop
    update oyun.adliye_davalar set durum = 'karar', karar = 'dusme', ilk_karar = 'dusme', karar_at = t, kesin = false,
      gerekce = 'Davaya bakabilecek tarafsız Yüksek Mahkeme üyesi 7 gün içinde bulunamadı; dava düştü, harç iade edildi. Davacı aynı iddiayla yeniden dava açabilir.'
     where id = dv.id;
    perform oyun.adliye_kesinlestir(dv.id, t);
    perform oyun.olay('adliye', format('Adliye #%s: tarafsız yargıç bulunamadığı için dava düştü, harç iade edildi.', dv.id), null, null, t);
    b := b + 1;
  end loop;
  -- 3) 72 saatte karar verilmeyen seçim itirazı reddedilmiş sayılır
  for r in select * from oyun.adliye_secim_itirazlari where durum = 'bekliyor' and zaman < t - interval '72 hours' loop
    update oyun.adliye_secim_itirazlari set durum = 'ret', karar_at = t,
      karar_gerekce = 'Yüksek Yargıç 72 saat içinde karar vermediği için itiraz incelenmeden reddedilmiş sayıldı; açıklanan seçim sonucu geçerlidir.' where id = r.id;
    select pa.gb into gb from oyun.partiler pa where pa.id = r.parti_id;
    if gb is not null then perform oyun.bildir(gb, format('Seçim itirazı #%s: 72 saat içinde karar verilmediği için reddedilmiş sayıldı.', r.id), t); end if;
    c := c + 1;
  end loop;
  return jsonb_build_object('juri_degisim', a, 'dusen_dava', b, 'itiraz_ret', c);
end $$;

-- Bekleyen işlerim: yargı görevleri en üstte
create or replace function public.bekleyen_islerim() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); l jsonb := '[]'::jsonb; cb boolean; v_gb bigint;
begin
  if p.id is null then return l; end if;
  -- İstinaf jürisi görevi
  l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'juri', 'oncelik', 1, 'baslik', format('⚖️ Jüri görevi: Adliye #%s istinafı', i.dava_id),
      'alt', 'Kararı onayla ya da boz · ' || oyun.dava_taraf_metni(d), 'bit', i.bit, 'id', i.dava_id, 'git', 'dava') order by i.bit)
    from oyun.adliye_juri j join oyun.adliye_istinaf i on i.dava_id = j.dava_id join oyun.adliye_davalar d on d.id = i.dava_id
    where j.user_id = p.id and j.oy is null and i.durum = 'acik' and i.bit > t), '[]'::jsonb);
  -- Yüksek Mahkeme heyeti
  if exists(select 1 from oyun.mahkeme_uye m where m.user_id = p.id) then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'heyet', 'oncelik', 1, 'baslik', format('Yüksek Mahkeme: Adliye #%s kararı', d.id),
        'alt', 'Gerekçeli oyunu kullan · ' || oyun.dava_taraf_metni(d), 'bit', d.karar_son, 'id', d.id, 'git', 'dava') order by d.karar_son)
      from oyun.adliye_davalar d where d.durum = 'acik' and (d.savunma_geldi or d.savunma_son <= t) and p.id = any(oyun.dava_heyeti(d))
        and not exists(select 1 from oyun.adliye_karar_oy o where o.dava_id = d.id and o.uye = p.id)), '[]'::jsonb);
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'aym', 'oncelik', 1, 'baslik', 'Anayasa denetimi başvurusu #' || b.id,
        'alt', 'Kanun hakkında oyunu kullan', 'bit', b.karar_son, 'id', b.id, 'git', 'adliye'))
      from oyun.aym_basvuru b where b.durum = 'acik' and not exists(select 1 from oyun.aym_oy o where o.basvuru_id = b.id and o.uye = p.id)), '[]'::jsonb);
  end if;
  if exists(select 1 from oyun.adliye_makam am where am.id = 1 and am.hakim = p.id) then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'secim_itiraz', 'oncelik', 1, 'baslik', 'Seçim itirazı #' || s.id,
        'alt', '72 saat içinde karar verilmezse reddedilmiş sayılır', 'bit', s.zaman + interval '72 hours', 'id', s.id, 'git', 'adliye'))
      from oyun.adliye_secim_itirazlari s where s.durum = 'bekliyor'), '[]'::jsonb);
  end if;
  cb := exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null);
  select pa.id into v_gb from oyun.partiler pa where pa.gb = p.id and not pa.kapali limit 1;
  if exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null) then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'oylama', 'oncelik', 1, 'baslik', 'Kanun oylaması: ' || k.baslik,
        'alt', 'Oyunu henüz kullanmadın', 'bit', k.oy_bit, 'id', k.id, 'git', 'meclis') order by k.oy_bit)
      from oyun.kanunlar k where k.durum = 'oylamada' and coalesce(k.oy_bit, t + interval '1 hour') > t
        and not exists(select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = p.id)), '[]'::jsonb);
  end if;
  if cb then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'odenek', 'oncelik', 1, 'baslik', 'Ek ödenek talebi: ' || o.kod,
        'alt', format('%s milyar ₺ · %s', o.tutar, left(coalesce(o.gerekce, ''), 60)), 'bit', o.bitis, 'id', o.id, 'git', 'butce'))
      from oyun.bakanlik_odenek_talep o where o.durum = 'bekliyor' and coalesce(o.bitis, t + interval '1 day') > t), '[]'::jsonb);
  end if;
  l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'kurucu', 'oncelik', 2, 'baslik', 'Kurucu daveti: ' || b.ad,
      'alt', 'Kurucular kuruluna çağrıldın', 'bit', b.bit, 'id', b.id, 'git', 'kurucu'))
    from oyun.kurucu_davet d join oyun.kurucu_basvuru b on b.id = d.basvuru_id
    where d.user_id = p.id and d.durum = 'bekliyor' and b.durum = 'bekliyor' and b.bit > t), '[]'::jsonb);
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
  if p.parti_id is not null then
    l := l || coalesce((select jsonb_agg(jsonb_build_object('tur', 'hedef', 'oncelik', 3, 'baslik', 'Parti hedefi: ' || h.ad,
        'alt', format('%s / %s', oyun.parti_hedef_ilerleme(h.parti_id, h.hafta, h.kod), h.hedef), 'bit', h.hafta + 7, 'git', 'hedef'))
      from oyun.parti_hedef h where h.parti_id = p.parti_id and h.hafta = oyun.arena_hafta(t) and h.tamam_at is null
        and t > ((h.hafta + 6)::timestamp at time zone 'Europe/Istanbul')), '[]'::jsonb);
  end if;
  return l;
end $$;

do $zam$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira)
    select 'yargi_duzeni', 'select oyun.yargi_tick()', 5, 1, 75
     where not exists (select 1 from oyun.zamanlayici_adim z where z.adim = 'yargi_duzeni');
  end if;
end $zam$;

do $$ declare s text; begin
  foreach s in array array['oyun.juri_cek(oyun.adliye_davalar,timestamptz,integer)', 'oyun.juri_degistir(bigint,uuid,timestamptz,text)', 'oyun.yargi_tick()',
    'oyun.adliye_juri_kur(bigint,timestamptz)', 'oyun.adliye_istinaf_sonuc(bigint,timestamptz)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', s);
  end loop;
  revoke all on function public.adliye_juri_oy(bigint,text,text) from public, anon;
  grant execute on function public.adliye_juri_oy(bigint,text,text) to authenticated;
  revoke all on function public.bekleyen_islerim() from public, anon;
  grant execute on function public.bekleyen_islerim() to authenticated;
end $$;
