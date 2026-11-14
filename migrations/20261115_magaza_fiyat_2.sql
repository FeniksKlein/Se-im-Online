-- 2026.11.15-2 · MAĞAZA fiyat ve ürün düzeni (Ercan onayı, 15 Kasım 2026)
-- Hedef: gelir Siyaset Kartı ve görünüm ürünlerinden gelsin; ₺ paketleri küçük kalsın ki
-- satın almayan oyuncu geride kalmasın. Alım sınırı yoktur (Ercan kararı).
-- 15 Kasım itibarıyla hiç satış yoktu; miktar değişikliği kimseyi etkilemez.
update oyun.paketler set fiyat='₺99,99' where urun_id='siyaset_karti';
update oyun.paketler set miktar=25000,  fiyat='₺29,99',  etiket=null          where urun_id='para_cep';
update oyun.paketler set miktar=60000,  fiyat='₺59,99',  etiket='%20 fazla'   where urun_id='para_kampanya';
update oyun.paketler set miktar=150000, fiyat='₺129,99', etiket='%38 fazla'   where urun_id='para_secim';
update oyun.paketler set miktar=400000, fiyat='₺299,99', etiket='%60 fazla'   where urun_id='para_servet';

insert into oyun.paketler(urun_id, ad, miktar, sira, tur, gun, hak, aciklama, etiket, fiyat) values
  ('kurucu_destekci', 'Kurucu Destekçi Paketi', 50000, 22, 'kalici', 0, 'kurucu',
   'Adının yanında kalıcı Kurucu rozeti ve cüzdanına 50.000 ₺. Yalnız açılış döneminde satılır.', 'Sınırlı süre', '₺249,99'),
  ('altin_cerceve', 'Altın Portre Çerçevesi', 0, 23, 'kalici', 0, 'cerceve',
   'Sohbette, oyuncu kartında ve profilde portrenin çevresinde altın çerçeve. Kalıcıdır.', 'Kalıcı', '₺39,99')
on conflict (urun_id) do update set ad=excluded.ad, miktar=excluded.miktar, sira=excluded.sira, tur=excluded.tur,
  hak=excluded.hak, aciklama=excluded.aciklama, etiket=excluded.etiket, fiyat=excluded.fiyat;

-- Rozet listesi: destekçi, kart, kurucu, çerçeve
create or replace function public.magaza_rozetler() returns jsonb
language sql stable security definer set search_path = oyun, public, pg_temp as $$
  select coalesce(jsonb_object_agg(pr.kad, r.rozet), '{}'::jsonb)
  from (select user_id, string_agg(rozet, ',' order by rozet) rozet from (
          select user_id, hak rozet from oyun.oyuncu_hak where hak in ('destekci', 'kurucu', 'cerceve') and aktif
          union all
          select user_id, 'kart' from oyun.magaza_hesap where kart_bitis > oyun.simdi()) x
        group by user_id) r
  join oyun.profiller pr on pr.id = r.user_id
  where not pr.yasakli
$$;
revoke all on function public.magaza_rozetler() from public, anon;
grant execute on function public.magaza_rozetler() to authenticated;
