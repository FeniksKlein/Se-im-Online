-- =====================================================================
-- 27.11.2026 · PARTİ GENEL MERKEZLERİ (sürüm 2026.11.27-9)
-- İstek (Ercan): "Satın almaya bağlı olmayan genel merkezler ekle oyuna ama satın alınca daha şık, daha imtiyazlı dursun.
--                 Ondan hariç her türlü de şık bir genel merkez paneli görünüşü hazırla."
-- Kural:
--   • Her partinin bir genel merkezi vardır. BİNANIN BÜYÜKLÜĞÜ (kademe 1–4) satın alınmaz; partinin o günkü örgüt gücünden
--     hesaplanır: son 14 günde aktif üye + il teşkilatı sayısı + görevdeki il başkanı sayısı (üçü birden; oyun.gm_kademe).
--     (İlk sürümde her okumada hesaplanıyordu; dosyanın ikinci bölümünde kademe parti kasasından inşa edilen kalıcı kayda döndü.)
--   • Genel Merkez Kampanyası (mağaza, m2_gm_katki) yalnız GÖRÜNÜMÜ süsler: Bronz / Gümüş / Altın donanım (prestij 1–3).
--     Oy, makam, seçim gücü ya da kademe vermez.
--   • genel_merkez_panel: tek çağrıda bina, yönetim katı, sayılar, pano ve bütün partilerin genel merkezleri. Yazma yapmaz.
-- Mağaza Paketi 2'den (m2_*) SONRA çalışmalıdır. Tekrar çalıştırmak güvenlidir.
-- =====================================================================

create table if not exists oyun.gm_kademe (
  kademe smallint primary key check (kademe between 1 and 4),
  ad text not null,
  uye integer not null check (uye >= 0),
  il integer not null check (il >= 0),
  il_baskani integer not null check (il_baskani >= 0),
  aciklama text not null default ''
);
alter table oyun.gm_kademe enable row level security;
revoke all on table oyun.gm_kademe from public, anon, authenticated;

insert into oyun.gm_kademe(kademe, ad, uye, il, il_baskani, aciklama) values
  (1, 'Kuruluş Bürosu', 0, 0, 0, 'Partinin ilk çalışma ofisi.'),
  (2, 'Genel Merkez Binası', 50, 15, 5, 'Müstakil genel merkez binası.'),
  (3, 'Genel Merkez Yerleşkesi', 150, 40, 20, 'Ana bina ve iki kanat.'),
  (4, 'Büyük Genel Merkez', 350, 70, 50, 'Kuleli ana bina, kanatlar ve tören alanı.')
on conflict (kademe) do update set ad = excluded.ad, uye = excluded.uye, il = excluded.il, il_baskani = excluded.il_baskani, aciklama = excluded.aciklama;

-- Bütün açık partilerin ölçüleri ve kademesi (tek geçiş; parti sayısı onlar mertebesinde)
create or replace function oyun.gm_olculer(t timestamptz)
returns table (parti_id bigint, uye integer, aktif integer, il integer, il_baskani integer, kademe integer)
language sql stable set search_path to '' as $$
  with o as (
    select pa.id,
           coalesce(u.uye, 0)::integer uye, coalesce(u.aktif, 0)::integer aktif,
           coalesce(ts.n, 0)::integer il, coalesce(ib.n, 0)::integer ilb
      from oyun.partiler pa
      left join (select x.parti_id, count(*) uye, count(*) filter (where x.son_gorulme > t - interval '14 days') aktif
                   from oyun.profiller x where x.parti_id is not null and not coalesce(x.yasakli, false) group by x.parti_id) u on u.parti_id = pa.id
      left join (select q.parti_id, count(*) n from oyun.parti_teskilat q group by q.parti_id) ts on ts.parti_id = pa.id
      left join (select b.parti_id, count(*) n from oyun.il_baskanlik b where b.aktif group by b.parti_id) ib on ib.parti_id = pa.id
     where not pa.kapali)
  select o.id, o.uye, o.aktif, o.il, o.ilb,
         coalesce((select max(k.kademe) from oyun.gm_kademe k where o.aktif >= k.uye and o.il >= k.il and o.ilb >= k.il_baskani), 1)::integer
    from o
$$;

create or replace function public.genel_merkez_panel(p_parti bigint default null)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pid bigint := coalesce(p_parti, p.parti_id);
  pa oyun.partiler; o record; k oyun.gm_kademe; sk oyun.gm_kademe; a oyun.m2_ayar; n bigint; s integer; uyeyim boolean; rol text;
begin
  if pid is null then raise exception 'Bir partiye üye değilsin. Görmek istediğin genel merkezi Partiler ekranından seç.'; end if;
  select * into pa from oyun.partiler where id = pid;
  if pa.id is null or pa.kapali then raise exception 'Parti bulunamadı.'; end if;
  select * into o from oyun.gm_olculer(t) x where x.parti_id = pid;
  select * into k from oyun.gm_kademe where kademe = o.kademe;
  select * into sk from oyun.gm_kademe where kademe = o.kademe + 1;
  select * into a from oyun.m2_ayar where id = 1;
  select count(*) into n from oyun.m2_gm_katki where parti_id = pid;
  s := oyun.m2_gm_seviye_hesap(n, a.gm_esik);
  uyeyim := coalesce(p.parti_id = pid, false);
  rol := case when not uyeyim then null when pa.gb = p.id then 'gb'
              when exists (select 1 from oyun.parti_gby g where g.parti_id = pid and g.user_id = p.id) then 'gby' else 'uye' end;
  return jsonb_build_object(
    'simdi', t,
    'parti', jsonb_build_object('id', pa.id, 'ad', pa.ad, 'kisa', pa.kisa, 'renk', pa.renk, 'amblem', pa.amblem, 'kurulus', pa.kurulus),
    'uyeyim', uyeyim, 'rol', rol, 'gm', uyeyim and oyun.teskilat_yonetici(p.id, pid),
    'sehir', (select jsonb_build_object('id', i.id, 'ad', i.ad) from oyun.parti_teskilat q join oyun.iller i on i.id = q.il_id
               where q.parti_id = pid and q.genel_merkez order by q.kurulus limit 1),
    'kademe', jsonb_build_object('no', o.kademe, 'ad', k.ad, 'aciklama', k.aciklama,
       'olcu', jsonb_build_object('uye', o.aktif, 'il', o.il, 'il_baskani', o.il_baskani),
       'sonraki', case when sk.kademe is null then null else
          jsonb_build_object('no', sk.kademe, 'ad', sk.ad, 'uye', sk.uye, 'il', sk.il, 'il_baskani', sk.il_baskani) end,
       'liste', (select jsonb_agg(jsonb_build_object('no', g.kademe, 'ad', g.ad, 'uye', g.uye, 'il', g.il, 'il_baskani', g.il_baskani) order by g.kademe) from oyun.gm_kademe g)),
    'prestij', jsonb_build_object('seviye', s, 'ad', oyun.m2_gm_ad(s), 'katki', n, 'esik', to_jsonb(a.gm_esik),
       'sonraki', case when s < coalesce(array_length(a.gm_esik, 1), 0) then a.gm_esik[s + 1] end,
       'sonraki_ad', case when s < coalesce(array_length(a.gm_esik, 1), 0) then oyun.m2_gm_ad(s + 1) end,
       'tutar', a.gm_tutar, 'hesap_gun', a.gm_hesap_gun,
       'urun_acik', exists (select 1 from oyun.paketler pk where pk.urun_id = 'secimonline.hq_campaign' and pk.aktif),
       'katki_verebilir', uyeyim and p.olusturma <= t - make_interval(days => a.gm_hesap_gun),
       'liste', (select coalesce(jsonb_agg(z.x order by z.adet desc, z.son), '[]'::jsonb) from (
                   select jsonb_build_object('kad', pr.kad, 'ad', oyun.m2_ad(pr.id), 'adet', count(*)) x, count(*) adet, max(c.id) son
                     from oyun.m2_gm_katki c join oyun.profiller pr on pr.id = c.user_id where c.parti_id = pid
                    group by pr.id, pr.kad order by count(*) desc, max(c.id) limit 10) z)),
    'yonetim', jsonb_build_object(
       'gb', case when pa.gb is null then null else jsonb_build_object('kad', oyun.kad(pa.gb), 'ad', oyun.m2_ad(pa.gb)) end,
       'vekil', case when pa.gb_vekil is null then null else jsonb_build_object('kad', oyun.kad(pa.gb_vekil), 'ad', oyun.m2_ad(pa.gb_vekil)) end,
       'gby', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(g.user_id), 'ad', oyun.m2_ad(g.user_id), 'gorev', g.gorev,
                   'alanlar', coalesce((select jsonb_agg(distinct y.yetki) from oyun.parti_gby_yetki y where y.parti_id = pid and y.user_id = g.user_id and y.aktif), '[]'::jsonb)) order by g.sira)
                 from oyun.parti_gby g where g.parti_id = pid), '[]'::jsonb),
       'disiplin', (select count(*) from oyun.pdk_uye d where d.parti_id = pid and d.tur = 'asil' and d.bit is null)),
    'sayilar', jsonb_build_object('uye', o.uye, 'aktif_14g', o.aktif,
       'aktif_24s', (select count(*) from oyun.profiller x where x.parti_id = pid and not coalesce(x.yasakli, false) and x.son_gorulme > t - interval '24 hours'),
       'yeni_7g', (select count(*) from oyun.profiller x where x.parti_id = pid and not coalesce(x.yasakli, false) and coalesce(x.parti_at, x.olusturma) > t - interval '7 days'),
       'il', o.il, 'il_baskani', o.il_baskani,
       'il_baskani_secilmis', (select count(*) from oyun.il_baskanlik b where b.parti_id = pid and b.aktif and b.statu = 'secilmis'),
       'mv', (select count(*) from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.parti_id = pid),
       'belediye', (select count(*) from oyun.makamlar m where m.tur = 'bel' and m.bit is null and m.parti_id = pid)),
    'mitingler', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'baslik', m.baslik, 'bas', m.bas, 'bit', m.bit, 'il', (select i.ad from oyun.iller i where i.id = m.il_id),
                    'il_orgut', coalesce(m.il_orgut, false), 'canli', t >= m.bas and t < m.bit) order by m.bas)
                  from (select * from oyun.mitingler m where m.parti_id = pid and m.tur = 'parti' and m.bit > t order by m.bas limit 4) m), '[]'::jsonb),
    'aciklamalar', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'baslik', c.baslik, 'il_id', c.il_id, 'il', (select i.ad from oyun.iller i where i.id = c.il_id), 'zaman', c.zaman) order by c.id desc)
                  from (select * from oyun.il_aciklama c where c.parti_id = pid and c.kamu and not c.silindi order by c.id desc limit 4) c), '[]'::jsonb),
    'partiler', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'kisa', q.kisa, 'ad', q.ad, 'renk', q.renk, 'kademe', x.kademe, 'uye', x.aktif,
                    'prestij', oyun.m2_gm_seviye_hesap(coalesce(c.n, 0), a.gm_esik)) order by x.kademe desc, x.aktif desc, q.id), '[]'::jsonb)
                   from oyun.gm_olculer(t) x join oyun.partiler q on q.id = x.parti_id
                   left join (select parti_id, count(*) n from oyun.m2_gm_katki group by parti_id) c on c.parti_id = q.id));
end $$;

revoke all on function oyun.gm_olculer(timestamptz) from public, anon, authenticated;
revoke all on function public.genel_merkez_panel(bigint) from public, anon;
grant execute on function public.genel_merkez_panel(bigint) to authenticated;

-- =====================================================================
-- 27.11.2026 · GENEL MERKEZ İNŞAATI VE KADEME AVANTAJLARI (sürüm 2026.11.27-10)
-- İstek (Ercan): "Genel merkez büyüdükçe avantajları da olsun; örneğin genel merkez binası olunca 6 GBY, yerleşke olunca 8,
--                 büyük genel merkez olunca 10. Parası da ucuz olmasın, diğer şartlar gibi. Sayıları sen hesapla, mantıklı başka avantaj ekle."
-- Kural:
--   • Kademe artık kendiliğinden gelmez: örgüt şartları (aktif üye + il teşkilatı + il başkanı) tutunca GENEL BAŞKAN parti kasasından
--     inşaat bedelini ödeyerek büyütür (genel_merkez_yukselt). İnşa edilen kademe kalıcıdır (oyun.gm_bina); parti küçülse de geri alınmaz.
--   • Avantajlar (oyun.gm_kademe): genel başkan yardımcısı kontenjanı 4/6/8/10, il yönetim kurulu kontenjanı 5/7/9/11,
--     il başına günlük seçim standı 1/1/2/3. Tüzük bu sınırların üstüne çıkamaz (oyun.parti_tuzuk etkin değeri kısar).
--   • Müktesep hak: görevdeki yardımcılar ve kurul üyeleri görevden alınmaz; dolu koltuklar korunur, kademe sınırının üstünde
--     boşalan koltuk kapanır.
-- =====================================================================
alter table oyun.gm_kademe add column if not exists bedel numeric not null default 0 check (bedel >= 0);
alter table oyun.gm_kademe add column if not exists gby smallint not null default 6 check (gby between 1 and 20);
alter table oyun.gm_kademe add column if not exists il_yk smallint not null default 7 check (il_yk between 3 and 25);
alter table oyun.gm_kademe add column if not exists stant smallint not null default 1 check (stant between 1 and 10);
update oyun.gm_kademe k set bedel = v.bedel, gby = v.gby, il_yk = v.il_yk, stant = v.stant, aciklama = v.aciklama
  from (values (1, 0::numeric, 4, 5, 1, 'Partinin ilk çalışma ofisi.'),
               (2, 3000000, 6, 7, 1, 'Müstakil genel merkez binası.'),
               (3, 12000000, 8, 9, 2, 'Ana bina ve iki kanat.'),
               (4, 40000000, 10, 11, 3, 'Kuleli ana bina, kanatlar ve tören alanı.')) v(kademe, bedel, gby, il_yk, stant, aciklama)
 where k.kademe = v.kademe;

create table if not exists oyun.gm_bina (
  parti_id bigint primary key references oyun.partiler(id),
  kademe smallint not null default 1 check (kademe between 1 and 4),
  zaman timestamptz not null,
  yapan uuid,
  harcama numeric not null default 0
);
alter table oyun.gm_bina enable row level security;
revoke all on table oyun.gm_bina from public, anon, authenticated;

create or replace function oyun.gm_kademe_no(p_parti bigint) returns integer language sql stable set search_path to '' as $$
  select coalesce((select b.kademe::integer from oyun.gm_bina b where b.parti_id = p_parti), 1)
$$;

-- Ölçüler aynı; kademe artık inşa edilmiş kademedir
create or replace function oyun.gm_olculer(t timestamptz)
returns table (parti_id bigint, uye integer, aktif integer, il integer, il_baskani integer, kademe integer)
language sql stable set search_path to '' as $$
  select pa.id, coalesce(u.uye, 0)::integer, coalesce(u.aktif, 0)::integer, coalesce(ts.n, 0)::integer, coalesce(ib.n, 0)::integer, coalesce(gb.kademe, 1)::integer
    from oyun.partiler pa
    left join (select x.parti_id, count(*) uye, count(*) filter (where x.son_gorulme > t - interval '14 days') aktif
                 from oyun.profiller x where x.parti_id is not null and not coalesce(x.yasakli, false) group by x.parti_id) u on u.parti_id = pa.id
    left join (select q.parti_id, count(*) n from oyun.parti_teskilat q group by q.parti_id) ts on ts.parti_id = pa.id
    left join (select b.parti_id, count(*) n from oyun.il_baskanlik b where b.aktif group by b.parti_id) ib on ib.parti_id = pa.id
    left join oyun.gm_bina gb on gb.parti_id = pa.id
   where not pa.kapali
$$;

-- Tüzüğün ETKİN değeri: kademe kontenjanını aşamaz; dolu koltuklar (müktesep hak) görünür kalır
create or replace function oyun.parti_tuzuk(p_parti bigint)
returns oyun.parti_tuzuk_ayar language plpgsql stable set search_path to '' as $$
declare r oyun.parti_tuzuk_ayar; k oyun.gm_kademe; dolu integer;
begin
  select * into r from oyun.parti_tuzuk_ayar t where t.parti_id = p_parti;
  if r.parti_id is null then r := row(p_parti, 6::smallint, 60, 24, 24, 14, 7::smallint, now(), null::uuid)::oyun.parti_tuzuk_ayar; end if;
  select g.* into k from oyun.gm_kademe g where g.kademe = oyun.gm_kademe_no(p_parti);
  if k.kademe is not null then
    select coalesce(max(g.sira), 0) into dolu from oyun.parti_gby g where g.parti_id = p_parti;
    r.gby_azami := least(r.gby_azami, greatest(k.gby, dolu))::smallint;
    r.il_yk_azami := least(r.il_yk_azami, k.il_yk)::smallint;
  end if;
  return r;
end $$;

create or replace function public.genel_merkez_yukselt()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; o record; mevcut integer; sk oyun.gm_kademe; r record;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id then raise exception 'Genel merkez inşaatına yalnız genel başkan karar verir.'; end if;
  mevcut := oyun.gm_kademe_no(pa.id);
  select * into sk from oyun.gm_kademe where kademe = mevcut + 1;
  if sk.kademe is null then raise exception 'Genel merkez zaten en büyük kademede.'; end if;
  select * into o from oyun.gm_olculer(t) x where x.parti_id = pa.id;
  if o.aktif < sk.uye then raise exception '% için en az % aktif üye gerekir (şu an %).', sk.ad, sk.uye, o.aktif; end if;
  if o.il < sk.il then raise exception '% için en az % ilde teşkilat gerekir (şu an %).', sk.ad, sk.il, o.il; end if;
  if o.il_baskani < sk.il_baskani then raise exception '% için en az % il başkanı görevde olmalı (şu an %).', sk.ad, sk.il_baskani, o.il_baskani; end if;
  if pa.kasa < sk.bedel then raise exception 'Parti kasası yetersiz: inşaat bedeli % ₺, kasada % ₺ var.', round(sk.bedel)::bigint, round(pa.kasa)::bigint; end if;
  update oyun.partiler set kasa = kasa - sk.bedel where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -sk.bedel, format('Genel merkez inşaatı: %s', sk.ad), 'genel_merkez');
  insert into oyun.gm_bina(parti_id, kademe, zaman, yapan, harcama) values (pa.id, sk.kademe, t, p.id, sk.bedel)
  on conflict (parti_id) do update set kademe = excluded.kademe, zaman = excluded.zaman, yapan = excluded.yapan, harcama = oyun.gm_bina.harcama + excluded.harcama;
  -- Yeni kontenjan hemen kullanılabilsin: tüzükteki sayı yeni kademenin altındaysa yükseltilir
  insert into oyun.parti_tuzuk_ayar(parti_id, gby_azami, il_yk_azami, guncelleme, guncelleyen)
  values (pa.id, greatest(6, sk.gby), greatest(7, sk.il_yk), t, p.id)
  on conflict (parti_id) do update set gby_azami = greatest(oyun.parti_tuzuk_ayar.gby_azami, sk.gby), il_yk_azami = greatest(oyun.parti_tuzuk_ayar.il_yk_azami, sk.il_yk),
    guncelleme = t, guncelleyen = p.id;
  insert into oyun.olaylar(zaman, tur, il_id, parti_id, metin) values (t, 'parti', null, pa.id, format('%s genel merkezini büyüttü: %s', pa.ad, sk.ad));
  for r in select x.id from oyun.profiller x where x.parti_id = pa.id and x.id <> p.id and not coalesce(x.yasakli, false) order by x.son_gorulme desc nulls last limit 3000 loop
    perform oyun.bildir(r.id, format('Partin %s yeni genel merkezine geçti: %s. Genel başkan yardımcısı kontenjanı %s, il yönetim kurulu kontenjanı %s oldu.', pa.kisa, sk.ad, sk.gby, sk.il_yk), t);
  end loop;
  return public.genel_merkez_panel(pa.id);
end $$;
revoke all on function oyun.gm_kademe_no(bigint) from public, anon, authenticated;
revoke all on function public.genel_merkez_yukselt() from public, anon;
grant execute on function public.genel_merkez_yukselt() to authenticated;

-- Panel: avantajlar, inşaat bedeli, büyütme hakkı; il standı günlük hakkı kademeden
do $y$
declare d text; e text;
begin
  select pg_get_functiondef('public.genel_merkez_panel(bigint)'::regprocedure) into d;
  if position('''yukseltebilir''' in d) = 0 then
    e := replace(d, '''kademe'', jsonb_build_object(''no'', o.kademe, ''ad'', k.ad, ''aciklama'', k.aciklama,',
      '''kademe'', jsonb_build_object(''no'', o.kademe, ''ad'', k.ad, ''aciklama'', k.aciklama,
       ''avantaj'', jsonb_build_object(''gby'', k.gby, ''il_yk'', k.il_yk, ''stant'', k.stant),
       ''kosul_tamam'', sk.kademe is not null and o.aktif >= sk.uye and o.il >= sk.il and o.il_baskani >= sk.il_baskani,
       ''kasa'', case when rol = ''gb'' then round(pa.kasa) end,
       ''yukseltebilir'', coalesce(rol = ''gb'' and sk.kademe is not null and o.aktif >= sk.uye and o.il >= sk.il and o.il_baskani >= sk.il_baskani and pa.kasa >= sk.bedel, false),');
    e := replace(e, 'jsonb_build_object(''no'', sk.kademe, ''ad'', sk.ad, ''uye'', sk.uye, ''il'', sk.il, ''il_baskani'', sk.il_baskani) end',
      'jsonb_build_object(''no'', sk.kademe, ''ad'', sk.ad, ''uye'', sk.uye, ''il'', sk.il, ''il_baskani'', sk.il_baskani, ''bedel'', sk.bedel, ''gby'', sk.gby, ''il_yk'', sk.il_yk, ''stant'', sk.stant) end');
    e := replace(e, 'jsonb_build_object(''no'', g.kademe, ''ad'', g.ad, ''uye'', g.uye, ''il'', g.il, ''il_baskani'', g.il_baskani) order by g.kademe',
      'jsonb_build_object(''no'', g.kademe, ''ad'', g.ad, ''uye'', g.uye, ''il'', g.il, ''il_baskani'', g.il_baskani, ''bedel'', g.bedel, ''gby'', g.gby, ''il_yk'', g.il_yk, ''stant'', g.stant) order by g.kademe');
    if position('''yukseltebilir''' in e) = 0 or position('''bedel'', sk.bedel' in e) = 0 or position('''bedel'', g.bedel' in e) = 0 then raise exception 'genel_merkez_panel yaması uygulanamadı'; end if;
    execute e;
  end if;

  if to_regprocedure('public.il_stant_ac(text,text)') is not null then
    select pg_get_functiondef('public.il_stant_ac(text,text)'::regprocedure) into d;
    if position('gm_kademe_no' in d) = 0 then
      e := replace(d, 'if exists (select 1 from oyun.stant where parti_id = pa.id and il_id = il and oyun.sm_gun(bas) = oyun.sm_gun(t)) then',
        'if (select count(*) from oyun.stant where parti_id = pa.id and il_id = il and oyun.sm_gun(bas) = oyun.sm_gun(t)) >= (select g.stant from oyun.gm_kademe g where g.kademe = oyun.gm_kademe_no(pa.id)) then');
      e := replace(e, 'Partin bugün bu ilde zaten stant açtı.', 'Partinin bu ildeki günlük stant hakkı doldu (genel merkez kademesine göre).');
      if position('gm_kademe_no' in e) = 0 then raise exception 'il_stant_ac yaması uygulanamadı'; end if;
      execute e;
    end if;
  end if;
  if to_regprocedure('public.il_masa(bigint,integer)') is not null then
    select pg_get_functiondef('public.il_masa(bigint,integer)'::regprocedure) into d;
    if position('gm_kademe_no' in d) = 0 then
      e := replace(d, '''stant_bugun'', exists (select 1 from oyun.stant s where s.parti_id = pa.id and s.il_id = il and oyun.sm_gun(s.bas) = oyun.sm_gun(t)),',
        '''stant_bugun'', (select count(*) from oyun.stant s where s.parti_id = pa.id and s.il_id = il and oyun.sm_gun(s.bas) = oyun.sm_gun(t)) >= (select g.stant from oyun.gm_kademe g where g.kademe = oyun.gm_kademe_no(pa.id)),');
      if position('gm_kademe_no' in e) = 0 then raise exception 'il_masa yaması uygulanamadı'; end if;
      execute e;
    end if;
  end if;
end $y$;

-- =====================================================================
-- 27.11.2026 · GENEL MERKEZ İNŞAAT FONU VE BAĞIŞÇILAR (sürüm 2026.11.27-11)
-- İstek (Ercan): "Oyuncular partiye bağış yapabilsin bina için veya mağazadan satın alıp parayı arttırsınlar ve bağışçılar
--                 listesinde sarıyla gösterilsinler."
-- Kural:
--   • Her partinin bir inşaat fonu vardır (oyun.gm_fon). Fon YALNIZ genel merkez inşaatına harcanır; inşaatta önce fon, eksik
--     kalan parti kasasından ödenir. Fon herkese açık görünür.
--   • genel_merkez_bagis: oyuncu kendi cüzdanından bağışlar (100 ₺ – 10.000.000 ₺; seçmen kartı şartı; bina en büyük kademedeyse kapalı).
--   • Mağazadaki Genel Merkez Kampanyası katkısı (m2_gm_uygula) artık parti kasasına değil bu fona girer (bina tamamlandıysa kasaya).
--   • Bağışçılar listesi toplam tutara göre; mağazadan katkı vermiş olanlar 'magaza' işaretiyle gelir (ekranda sarı).
-- =====================================================================
create table if not exists oyun.gm_fon (
  parti_id bigint primary key references oyun.partiler(id),
  bakiye numeric not null default 0 check (bakiye >= 0),
  toplam numeric not null default 0
);
create table if not exists oyun.gm_bagis (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  user_id uuid not null references oyun.profiller(id),
  tutar numeric not null check (tutar > 0),
  kaynak text not null default 'oyun' check (kaynak in ('oyun', 'magaza')),
  zaman timestamptz not null
);
create index if not exists gm_bagis_parti_idx on oyun.gm_bagis(parti_id, user_id);
alter table oyun.gm_fon enable row level security;
alter table oyun.gm_bagis enable row level security;
revoke all on table oyun.gm_fon, oyun.gm_bagis from public, anon, authenticated;

create or replace function oyun.gm_fon_ekle(p_parti bigint, p_user uuid, p_tutar numeric, p_kaynak text, t timestamptz)
returns void language plpgsql set search_path to '' as $$
begin
  insert into oyun.gm_fon(parti_id, bakiye, toplam) values (p_parti, p_tutar, p_tutar)
  on conflict (parti_id) do update set bakiye = oyun.gm_fon.bakiye + excluded.bakiye, toplam = oyun.gm_fon.toplam + excluded.toplam;
  insert into oyun.gm_bagis(parti_id, user_id, tutar, kaynak, zaman) values (p_parti, p_user, p_tutar, p_kaynak, t);
end $$;

create or replace function oyun.gm_fon_ozet(p_parti bigint, u uuid)
returns jsonb language sql stable set search_path to '' as $$
  select jsonb_build_object(
    'bakiye', coalesce((select round(f.bakiye) from oyun.gm_fon f where f.parti_id = p_parti), 0),
    'toplam', coalesce((select round(f.toplam) from oyun.gm_fon f where f.parti_id = p_parti), 0),
    'bagisci', (select count(distinct b.user_id) from oyun.gm_bagis b where b.parti_id = p_parti),
    'benim', coalesce((select round(sum(b.tutar)) from oyun.gm_bagis b where b.parti_id = p_parti and b.user_id = u), 0),
    'liste', (select coalesce(jsonb_agg(z.x order by z.top desc, z.ilk), '[]'::jsonb) from (
                select jsonb_build_object('kad', pr.kad, 'ad', coalesce(nullif(btrim(pr.ad_soyad), ''), pr.kad), 'tutar', round(sum(b.tutar)),
                         'magaza', bool_or(b.kaynak = 'magaza'), 'magaza_adet', count(*) filter (where b.kaynak = 'magaza')) x, sum(b.tutar) top, min(b.id) ilk
                  from oyun.gm_bagis b join oyun.profiller pr on pr.id = b.user_id where b.parti_id = p_parti
                 group by pr.id, pr.kad, pr.ad_soyad order by sum(b.tutar) desc, min(b.id) limit 30) z))
$$;

create or replace function public.genel_merkez_bagis(p_parti bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; v numeric := round(p_tutar); e text;
begin
  if coalesce(p.yasakli, false) then raise exception 'Hesabın kısıtlı.'; end if;
  e := oyun.uyari(p, t); if e is not null then raise exception 'Bağış için seçmen kartın hazır olmalı: %', e; end if;
  select * into pa from oyun.partiler where id = coalesce(p_parti, p.parti_id) and not kapali for update;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  if v is null or v < 100 or v > 10000000 then raise exception 'Bağış 100 ₺ ile 10.000.000 ₺ arasında olmalı.'; end if;
  if not exists (select 1 from oyun.gm_kademe k where k.kademe = oyun.gm_kademe_no(pa.id) + 1) then
    raise exception '% genel merkezi en büyük kademede; inşaat fonu kapandı. Partiye parti sayfasından bağış yapabilirsin.', pa.kisa; end if;
  perform oyun.para_islem(p.id, -v, 'bagis', format('%s genel merkez inşaat fonuna bağış', pa.kisa), t);
  perform oyun.gm_fon_ekle(pa.id, p.id, v, 'oyun', t);
  if pa.gb is not null and pa.gb <> p.id and v >= 10000 then
    perform oyun.bildir(pa.gb, format('%s, %s genel merkez inşaat fonuna %s ₺ bağış yaptı.', coalesce(nullif(btrim(p.ad_soyad), ''), p.kad), pa.kisa, round(v)::bigint), t);
  end if;
  return public.genel_merkez_panel(pa.id);
end $$;

-- İnşaat: önce fon, eksik kalan parti kasasından
create or replace function public.genel_merkez_yukselt()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; o record; mevcut integer; sk oyun.gm_kademe; r record;
  fon numeric; fondan numeric; kasadan numeric;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;
  if pa.gb is distinct from p.id then raise exception 'Genel merkez inşaatına yalnız genel başkan karar verir.'; end if;
  mevcut := oyun.gm_kademe_no(pa.id);
  select * into sk from oyun.gm_kademe where kademe = mevcut + 1;
  if sk.kademe is null then raise exception 'Genel merkez zaten en büyük kademede.'; end if;
  select * into o from oyun.gm_olculer(t) x where x.parti_id = pa.id;
  if o.aktif < sk.uye then raise exception '% için en az % aktif üye gerekir (şu an %).', sk.ad, sk.uye, o.aktif; end if;
  if o.il < sk.il then raise exception '% için en az % ilde teşkilat gerekir (şu an %).', sk.ad, sk.il, o.il; end if;
  if o.il_baskani < sk.il_baskani then raise exception '% için en az % il başkanı görevde olmalı (şu an %).', sk.ad, sk.il_baskani, o.il_baskani; end if;
  select coalesce((select f.bakiye from oyun.gm_fon f where f.parti_id = pa.id), 0) into fon;
  fondan := least(fon, sk.bedel); kasadan := sk.bedel - fondan;
  if pa.kasa < kasadan then raise exception 'Para yetmiyor: inşaat bedeli % ₺; inşaat fonunda % ₺, parti kasasında % ₺ var.', round(sk.bedel)::bigint, round(fon)::bigint, round(pa.kasa)::bigint; end if;
  if fondan > 0 then update oyun.gm_fon set bakiye = bakiye - fondan where parti_id = pa.id; end if;
  if kasadan > 0 then
    update oyun.partiler set kasa = kasa - kasadan where id = pa.id;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, -kasadan, format('Genel merkez inşaatı: %s', sk.ad), 'genel_merkez');
  end if;
  insert into oyun.gm_bina(parti_id, kademe, zaman, yapan, harcama) values (pa.id, sk.kademe, t, p.id, sk.bedel)
  on conflict (parti_id) do update set kademe = excluded.kademe, zaman = excluded.zaman, yapan = excluded.yapan, harcama = oyun.gm_bina.harcama + excluded.harcama;
  insert into oyun.parti_tuzuk_ayar(parti_id, gby_azami, il_yk_azami, guncelleme, guncelleyen)
  values (pa.id, greatest(6, sk.gby), greatest(7, sk.il_yk), t, p.id)
  on conflict (parti_id) do update set gby_azami = greatest(oyun.parti_tuzuk_ayar.gby_azami, sk.gby), il_yk_azami = greatest(oyun.parti_tuzuk_ayar.il_yk_azami, sk.il_yk),
    guncelleme = t, guncelleyen = p.id;
  insert into oyun.olaylar(zaman, tur, il_id, parti_id, metin) values (t, 'parti', null, pa.id, format('%s genel merkezini büyüttü: %s', pa.ad, sk.ad));
  for r in select x.id from oyun.profiller x where x.parti_id = pa.id and x.id <> p.id and not coalesce(x.yasakli, false) order by x.son_gorulme desc nulls last limit 3000 loop
    perform oyun.bildir(r.id, format('Partin %s yeni genel merkezine geçti: %s. Genel başkan yardımcısı kontenjanı %s, il yönetim kurulu kontenjanı %s oldu.', pa.kisa, sk.ad, sk.gby, sk.il_yk), t);
  end loop;
  return public.genel_merkez_panel(pa.id);
end $$;

revoke all on function oyun.gm_fon_ekle(bigint, uuid, numeric, text, timestamptz) from public, anon, authenticated;
revoke all on function oyun.gm_fon_ozet(bigint, uuid) from public, anon, authenticated;
revoke all on function public.genel_merkez_bagis(bigint, numeric) from public, anon;
grant execute on function public.genel_merkez_bagis(bigint, numeric) to authenticated;

do $y$
declare d text; e text;
begin
  -- Panel: fon ve bağışçılar; büyütme hakkı fon + kasa
  select pg_get_functiondef('public.genel_merkez_panel(bigint)'::regprocedure) into d;
  if position('gm_fon_ozet' in d) = 0 then
    e := replace(d, '''prestij'', jsonb_build_object(''seviye'', s,', '''fon'', oyun.gm_fon_ozet(pid, p.id),
    ''prestij'', jsonb_build_object(''seviye'', s,');
    e := replace(e, 'and o.il_baskani >= sk.il_baskani and pa.kasa >= sk.bedel, false)',
      'and o.il_baskani >= sk.il_baskani and pa.kasa + coalesce((select f.bakiye from oyun.gm_fon f where f.parti_id = pid), 0) >= sk.bedel, false)');
    if position('gm_fon_ozet' in e) = 0 or position('pa.kasa + coalesce' in e) = 0 then raise exception 'genel_merkez_panel fon yaması uygulanamadı'; end if;
    execute e;
  end if;
  -- Mağaza katkısı: parti kasası yerine inşaat fonuna (bina tamamlandıysa kasaya)
  if to_regprocedure('oyun.m2_gm_uygula(uuid,timestamptz)') is not null then
    select pg_get_functiondef('oyun.m2_gm_uygula(uuid, timestamptz)'::regprocedure) into d;
    if position('gm_fon_ekle' in d) = 0 then
      e := replace(d, 'update oyun.partiler set kasa = kasa + a.gm_tutar where id = pa.id;',
        'if exists (select 1 from oyun.gm_kademe gk where gk.kademe = oyun.gm_kademe_no(pa.id) + 1) then perform oyun.gm_fon_ekle(pa.id, u, a.gm_tutar, ''magaza'', t); else
  update oyun.partiler set kasa = kasa + a.gm_tutar where id = pa.id;');
      e := replace(e, 'values (pa.id, t, a.gm_tutar, format(''Genel Merkez Kampanyası katkısı · %s'', ad), ''genel_merkez'');',
        'values (pa.id, t, a.gm_tutar, format(''Genel Merkez Kampanyası katkısı · %s'', ad), ''genel_merkez''); end if;');
      if position('gm_fon_ekle' in e) = 0 or position('''genel_merkez''); end if;' in e) = 0 then raise exception 'm2_gm_uygula fon yaması uygulanamadı'; end if;
      execute e;
    end if;
  end if;
end $y$;
