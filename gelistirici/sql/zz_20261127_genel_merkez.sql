-- =====================================================================
-- 27.11.2026 · PARTİ GENEL MERKEZLERİ (sürüm 2026.11.27-9)
-- İstek (Ercan): "Satın almaya bağlı olmayan genel merkezler ekle oyuna ama satın alınca daha şık, daha imtiyazlı dursun.
--                 Ondan hariç her türlü de şık bir genel merkez paneli görünüşü hazırla."
-- Kural:
--   • Her partinin bir genel merkezi vardır. BİNANIN BÜYÜKLÜĞÜ (kademe 1–4) satın alınmaz; partinin o günkü örgüt gücünden
--     hesaplanır: son 14 günde aktif üye + il teşkilatı sayısı + görevdeki il başkanı sayısı (üçü birden; oyun.gm_kademe).
--     Kayıt tutulmaz, her okumada hesaplanır; parti küçülürse bina da küçülür.
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
