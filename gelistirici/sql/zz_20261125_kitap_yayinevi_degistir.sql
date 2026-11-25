-- 25.11.2026 · KİTAP: YAYINEVİ SAHİBİ, İNCELEME SÜRESİ, YAYINEVİ DEĞİŞTİRME (sürüm 2026.11.25-2)
-- İstek (destek talebi #71, Ercan "ekle"): "Yayınevlerinin sahiplerini görmek istiyoruz. Kitabı yayınevine gönderdiğimizde
-- inceleme sürelerini görüp belli şartlarda yayınevi değiştirebilme hakkı olursa iyi olabilir."
--   • uc_kitap_panel › yayinevleri: sahip (payı en yüksek yönetici ortak), bekleyen dosya ve yayımlanan kitap sayısı.
--   • uc_kitap_panel › kitaplar: gonderim (dosyanın bu yayınevine ulaştığı an), degisim_saat (24), yayinevi_sahip.
--   • uc_kitap_islem 'yayinevi_degistir' {yayinevi}: yalnız yazar. Şartlar:
--       - yayımlanmış kitap taşınamaz;
--       - REDDEDİLEN dosya hemen başka yayınevine gönderilebilir;
--       - BEKLEYEN dosya, yayınevine 24 saat inceleme süresi tanındıktan sonra taşınabilir (süre her taşımada yeniden başlar);
--       - en çok 5 bekleyen dosya kuralı reddedilen dosyayı yeniden gönderirken de geçerli;
--       - yönetimce yayını durdurulmuş yayınevine dosya taşınamaz.
-- Oyuncu verisi değişmez: uc_kitap'a boş bir sütun eklenir. Tekrar çalıştırmak güvenlidir. oyun._yama kullanır.
-- Ekran: gelistirici/www/uc_ekonomi_yeni.js ("YAYINEVİ DEĞİŞTİR").

alter table oyun.uc_kitap add column if not exists gonderim timestamptz;

select oyun._yama('public.uc_kitap_panel()',
  $a$jsonb_build_object('id',id,'ad',ad,'kasa',oyun.kasa_goster('sirket',id,kasa))$a$,
  $b$jsonb_build_object('id',id,'ad',ad,'kasa',oyun.kasa_goster('sirket',id,kasa),
    'sahip',(select oyun.kad(so.user_id) from oyun.sirket_ortaklari so where so.sirket_id=sirketler.id and so.pay>=50 order by so.pay desc, so.user_id limit 1),
    'bekleyen',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='teklif'),
    'yayinlanan',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='yayinda'))$b$,
  $c$'sahip',(select oyun.kad$c$, true);
select oyun._yama('public.uc_kitap_panel()',
  $a$'fiyat_son_degisim',k.fiyat_son_degisim$a$,
  $b$'fiyat_son_degisim',k.fiyat_son_degisim,
  'gonderim',coalesce(k.gonderim,k.olusturma),'degisim_saat',24,
  'yayinevi_sahip',(select oyun.kad(so.user_id) from oyun.sirket_ortaklari so where so.sirket_id=k.yayinevi and so.pay>=50 order by so.pay desc, so.user_id limit 1)$b$,
  $c$'degisim_saat',24$c$, true);

select oyun._yama('public.uc_kitap_islem(text,bigint,jsonb)',
  $a$  select * into s from oyun.sirketler
    where id=k.yayinevi and aktif for update;$a$,
  $b$  if p_islem = 'yayinevi_degistir' then
    if k.yazar <> u then raise exception 'Yayınevini yalnızca kitabın yazarı değiştirebilir'; end if;
    if k.durum not in ('teklif','reddedildi') then raise exception 'Yayımlanmış kitabın yayınevi değiştirilemez'; end if;
    if k.durum = 'teklif' and coalesce(k.gonderim, k.olusturma) > t - interval '24 hours' then
      raise exception 'Yayınevinin dosyanı incelemesi için 24 saati var. Kitabını % saatinden sonra başka yayınevine taşıyabilirsin',
        to_char((coalesce(k.gonderim, k.olusturma) + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
    end if;
    bid := case when coalesce(p_veri->>'yayinevi','') ~ '^[0-9]{1,15}$' then (p_veri->>'yayinevi')::bigint end;
    if bid is null or bid = k.yayinevi then raise exception 'Farklı bir yayınevi seç'; end if;
    select * into s from oyun.sirketler where id = bid and sektor = 'medya' and aktif;
    if s.id is null then raise exception 'Yayınevi bulunamadı'; end if;
    if to_regprocedure('oyun.kurum_durdurma_aktif(text,bigint)') is not null then
      execute 'select (oyun.kurum_durdurma_aktif($1, $2)).id' into expense using 'sirket', s.id;
      if expense is not null then raise exception 'Bu yayınevinin yayın ve faaliyetleri oyun yönetimi kararıyla durduruldu; başka bir yayınevi seç'; end if;
    end if;
    if k.durum = 'reddedildi' and (select count(*) from oyun.uc_kitap where yazar=u and durum='teklif') >= 5
    then raise exception 'En fazla 5 bekleyen kitap teklifi olabilir'; end if;
    update oyun.uc_kitap set yayinevi = s.id, durum = 'teklif', gonderim = t where id = k.id;
    return jsonb_build_object('durum','teklif','yayinevi',s.id,'yayinevi_ad',s.ad);
  end if;

  select * into s from oyun.sirketler
    where id=k.yayinevi and aktif for update;$b$,
  $c$p_islem = 'yayinevi_degistir'$c$, true);
