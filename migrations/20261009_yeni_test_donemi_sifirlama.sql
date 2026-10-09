-- 2026-10-09: Bir defalik yeni test donemi, onceki 13 hesap 1M TL, diger herkes 200K TL.
-- Mevcut 24 saat uzatilmis takvim degismez. Auth e-posta/sifreleri silinmez.
-- Oncelikli bonus, eski hesaplarin AUTH UUID kimligine baglidir; kullanici adi taklidi islemez.
-- Once gelistirici/sql/47_test_baslangic.sql kurulmus olmalidir.
begin;

create temp table _test_onceki13 on commit drop as
select id as user_id, kad
from oyun.profiller
where kad in (
  'ArvenTora','mehmetemincelik','Sui_Generis','ak1n','autopsy_chester',
  'ÖmerSucu','CELAL','akınkelleci','uygarzk','ibrahim_Özkan',
  'norean','TuranRiver','matestappen'
);

do $kontrol$
declare v_adet int;
begin
  if to_regclass('oyun_yonetim.onceki_test_oyuncu') is null
     or to_regprocedure('oyun.test_oncelikli_baslangic()') is null then
    raise exception 'Oncelikli bakiyeyi olusturan SQL modulu henuz kurulmadi.';
  end if;
  select count(*) into v_adet from _test_onceki13;
  if v_adet <> 13 then
    raise exception '13 eski oyuncu bekleniyordu; yalnizca % oyuncu eslesti. Hicbir sey degismedi.',v_adet;
  end if;
  if exists (select 1 from oyun_yonetim.onceki_test_oyuncu) then
    raise exception 'Test oncelik listesi zaten var. Ikinci kez sifirlanmadi.';
  end if;
  if (select count(*) from oyun.secimler
      where id in (2,3,4,5) and ara_neden='test_reset_20261008'
        and ( (id in (2,5) and oy_bas='2026-10-11 05:00:00+00'::timestamptz)
           or (id in (3,4) and oy_bas='2026-10-12 05:00:00+00'::timestamptz))) <> 4 then
    raise exception '24 saat uzatilmis test secim takvimi beklenenden farkli. Sifirlama iptal.';
  end if;
end
$kontrol$;

-- Oyun ilerlemesi temizlenecek; sabit takvim ve oyunun ulke altyapisi tekrar kurulacak.
create temp table _test_secimler on commit drop as table oyun.secimler;
create temp table _test_anayasa on commit drop as table oyun.anayasa;
create temp table _test_il_kalkinma on commit drop as table oyun.il_kalkinma;

create temp table _test_yedek (mesaj text) on commit drop;
insert into _test_yedek select oyun.oyunu_sifirla('OYUNU SIFIRLA');

-- Eski hesaplar auth.users'da korunur, ancak profiller/cuzdanlar ve tum siyasi ilerleme sifirlanir.
insert into oyun_yonetim.onceki_test_oyuncu(user_id,kad)
select user_id,kad from _test_onceki13;

-- Katalog oyun.ayarlar korunmustur. Butun yeni vatandaslara 200 bin TL.
update oyun.ayarlar set baslangic_para=200000 where id=1;

-- 24 saat uzatilmis secimler aynen geri yuklenir, eski adaylar/oylar geri gelmez.
insert into oyun.secimler select * from _test_secimler;
update oyun.secimler set durum='bekliyor', sonuc=null, hatirlatma='{}'::jsonb;
select setval(pg_get_serial_sequence('oyun.secimler','id'),
  coalesce((select max(id) from oyun.secimler),1),true);

-- Yeni dunya: belediyelerin gelisimi/kasasi, devlet hazinesi/bakanliklari baslangica doner.
insert into oyun.il_durum(il_id)
select id from oyun.iller on conflict do nothing;
update oyun.il_durum d
set kasa = 5 * oyun.il_gunluk_gelir(i.mv)
from oyun.iller i where d.il_id=i.id;
insert into oyun.ulke(id) values(1) on conflict do nothing;
insert into oyun.bakanlik_kasa(kod)
select kod from oyun.bakanliklar on conflict do nothing;

-- Anayasal temel, meclis 600; il fiyat kademeleri ve ekonomi kurallari saklanir.
insert into oyun.anayasa select * from _test_anayasa;
update oyun.anayasa set deger=case kod
  when 'hukumet_sistemi' then 0
  when 'secim_baraji' then 7
  when 'cb_gorev_suresi' then 1
  when 'milletvekili_sayisi' then 600
  when 'yerel_yetki' then 100
  when 'erken_secim_esigi' then 60
  when 'kararname_sinir' then 3
  when 'vergi_tavani' then 45
  else deger end;
insert into oyun.il_kalkinma select * from _test_il_kalkinma;

insert into oyun.yasa_ekonomi_ayar(kod,deger) values
('artan_vergi',0),('ilk_konut_muaf',0),('coklu_mulk_vergi',0),('faiz_stopaj',0),
('piyango_stopaj',0),('tahvil_faiz',0),('vergi_affi',0),('yeni_parti_destek',0),
('parti_yardim_carpan',100),('belediye_payi',10);
insert into oyun.makam_ucret_ayar(tur,carpan) values ('mv',1),('cb',1);

-- Borsa, altin ve doviz her oyuncu icin ayni acilis fiyatlariyla tekrar baslar.
insert into oyun.piyasa_varlik(kod,ad,sinif,fiyat,onceki,oynaklik,saat) values
('USD','ABD Doları / TL','doviz',42,42,0.002,date_trunc('hour',now())),
('EUR','Avro / TL','doviz',49,49,0.002,date_trunc('hour',now())),
('ALTIN','Gram Altın / TL','altin',5200,5200,0.003,date_trunc('hour',now())),
('SANAYI','Sanayi Hisseleri','hisse',120,120,0.008,date_trunc('hour',now())),
('TEKNO','Teknoloji Hisseleri','hisse',180,180,0.011,date_trunc('hour',now())),
('BANKA','Banka Hisseleri','hisse',140,140,0.009,date_trunc('hour',now()));
insert into oyun.piyasa_fiyat(kod,saat,fiyat)
select kod,saat,fiyat from oyun.piyasa_varlik;

do $kontrol_son$
begin
  if (select count(*) from oyun.profiller) <> 0
      or (select count(*) from oyun.cuzdan) <> 0
      or (select count(*) from oyun.adaylar) <> 0
      or (select count(*) from oyun.partiler) <> 0
      or (select count(*) from oyun.secimler) <> (select count(*) from _test_secimler)
      or (select count(*) from oyun.il_durum) <> 81
      or (select count(*) from oyun_yonetim.onceki_test_oyuncu) <> 13
      or (select baslangic_para from oyun.ayarlar where id=1) <> 200000 then
    raise exception 'Yeni oyun butunluk kontrolu gecmedi. Her sey geri alinacak.';
  end if;
end
$kontrol_son$;

select (select count(*) from oyun_yonetim.onceki_test_oyuncu) as oncelikli13,
 (select baslangic_para from oyun.ayarlar where id=1) as yeni_baslangic,
 (select count(*) from oyun.profiller) as sifir_profil,
 (select count(*) from oyun.secimler) as ayni_secim_takvimi,
 (select mesaj from _test_yedek) as yedek_bilgisi;
commit;
