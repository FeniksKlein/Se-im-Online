-- Fonksiyonlarin hedeflenenden farkli surumlerle ezilmesini engelle.
DO $sha$
BEGIN
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='para_gonder') IS DISTINCT FROM '74a48203b756aca8605b1e9097ac3397' THEN
 RAISE EXCEPTION 'Surum catismasi: public.para_gonder'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='sirket_parti_bagis') IS DISTINCT FROM 'ae59b90f4d22a1a1aac280076a87dd2b' THEN
 RAISE EXCEPTION 'Surum catismasi: public.sirket_parti_bagis'; END IF;
END $sha$;

-- 17.11.2026: Finansal cift-harcama koruma, mevcut bakiye ve islem satirlarina dokunmaz.
-- ONCE test ortaminda iki eszamanli havale ve sirket bagisi yarisi ile dogrulanmali.
-- 1) Bakiye kontrolu ile eksiltme ayni atomik UPDATE kosulunda.
CREATE OR REPLACE FUNCTION public.para_gonder(p_kad text, p_miktar numeric, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); h oyun.profiller; m numeric:=round(coalesce(p_miktar,0));
  ack text; bugun numeric; tavan numeric; gm oyun.banka_musteri; am oyun.banka_musteri; tid bigint;
begin
  perform oyun.banka_acik_mi();
  h:=oyun.profil_bul(p_kad);
  if h.id=p.id then raise exception 'Kendine para gönderemezsin.'; end if;
  if h.yasakli then raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
  if m<100 then raise exception 'En az 100 ₺ gönderebilirsin.'; end if;
  if oyun.uyari(p,t) is not null then raise exception 'Para göndermek için seçmen kartın hazır olmalı: %',oyun.uyari(p,t); end if;
  if (select coklu_kontrol from oyun.ayarlar where id=1)
     and exists(select 1 from oyun.bagli_hesaplar(p.id) b where b=h.id) then
    raise exception 'Aynı cihazda açılmış hesaplar arasında banka transferi yapılamaz.';
  end if;
  if exists(select 1 from oyun.servet_vergi_borc b where b.user_id=p.id and b.borc>0) then
    raise exception 'Servet vergisi borcun ödenmeden başka oyuncuya para aktaramazsın.';
  end if;
  if oyun.engelli(h.id,p.id) then raise exception 'Bu oyuncu seni engellediği için ona para gönderemezsin.'; end if;
  perform oyun.takip_engel(p.id,'banka transferi yapamazsın');
  perform oyun.teminat_engel(p.id,m); /*202*/
  bugun:=oyun.gunluk_aktarim(p.id,t);
  tavan:=round((select asgari from oyun.ulke where id=1)*(select havale_sinir from oyun.ayarlar where id=1));
  if bugun+m>tavan then
    raise exception 'Günlük para aktarma sınırı % ₺ (bugün havale ve hediyeyle % ₺ gönderdin).',oyun.tl(tavan),oyun.tl(bugun);
  end if;
  if nullif(btrim(coalesce(p_aciklama,'')),'') is not null then ack:=oyun.metin_temizle(p_aciklama,100); end if;
  gm:=oyun.vadesiz_isle(p.id,t);
  am:=oyun.vadesiz_isle(h.id,t);
  if gm.vadesiz<m then
    raise exception 'Transfer için vadesiz hesabında yeterli para yok. Bakiye: % ₺.',oyun.tl(gm.vadesiz);
  end if;
  if oyun.mevduat_toplam(h.id)+m>oyun.banka_tavani() then
    raise exception 'Alıcının banka mevduatı üst sınıra çok yakın. Bu transfer alıcının mevduat tavanını aşar.';
  end if;
  update oyun.banka_musteri set vadesiz=vadesiz-m where user_id=p.id AND vadesiz>=m;
  IF NOT FOUND THEN RAISE EXCEPTION 'Eşzamanlı işlem sırasında bakiye değişti, gönderim yapılmadı.'; END IF;
  update oyun.banka_musteri set vadesiz=vadesiz+m where user_id=h.id;
  insert into oyun.banka_transfer(gonderen,alici,tutar,aciklama,zaman) values(p.id,h.id,m,ack,t) returning id into tid;
  perform oyun.banka_kayit(p.id,'vadesiz',-m,format('%s adlı oyuncuya banka transferi%s',h.kad,coalesce(': '||ack,'')),t);
  perform oyun.banka_kayit(h.id,'vadesiz',m,format('%s adlı oyuncudan banka transferi%s',p.kad,coalesce(': '||ack,'')),t);
  perform oyun.bildir(h.id,format('%s sana banka yoluyla %s ₺ gönderdi.%s',p.kad,oyun.tl(m),coalesce(' Not: “'||ack||'”','')),t);
  return jsonb_build_object('tamam',true,'transfer_id',tid,'alici',h.kad,'miktar',m,
    'bakiye',(select vadesiz from oyun.banka_musteri where user_id=p.id),'bugun',bugun+m,'tavan',tavan);
end $function$;

CREATE OR REPLACE FUNCTION public.sirket_parti_bagis(p_sirket bigint, p_parti bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; pa oyun.partiler; t timestamptz := oyun.simdi(); hafta numeric; sinir numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif then raise exception 'Şirket bulunamadı.'; end if;
  if s.sektor = 'banka' then raise exception 'Bankalar siyasi bağış yapamaz.'; end if;
  if not oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Şirket adına bağışı en büyük ortak yapar.'; end if;
  select * into pa from oyun.partiler where id = p_parti;
  if pa.id is null or pa.kapali then raise exception 'Parti bulunamadı.'; end if;
  if p_tutar is null or p_tutar < 1000 or p_tutar <> round(p_tutar) then raise exception 'Bağış en az 1.000 ₺ ve tam sayı olmalı.'; end if;
  perform pg_advisory_xact_lock(98763, hashtext(s.id::text));
  perform oyun.sirket_hesapla(s.id);
  select * into s from oyun.sirketler where id = p_sirket;
  select coalesce(sum(tutar), 0) into hafta from oyun.sirket_bagis where sirket_id = s.id and zaman > t - interval '7 days';
  sinir := round(s.sermaye * 0.20);
  if hafta + p_tutar > sinir then raise exception 'Bu şirket 7 günde en fazla % ₺ bağış yapabilir (kalan % ₺).', oyun.tl(sinir), oyun.tl(greatest(0, sinir - hafta)); end if;
  if s.kasa < p_tutar then raise exception 'Şirket kasasında yeterli para yok.'; end if;
  update oyun.sirketler set kasa = kasa - p_tutar where id = s.id AND kasa >= p_tutar;
  IF NOT FOUND THEN RAISE EXCEPTION 'Şirket kasası eşzamanlı işlem nedeniyle yetersiz.'; END IF;
  update oyun.partiler set kasa = kasa + p_tutar where id = pa.id;
  insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur) values (pa.id, t, p_tutar, format('%s şirketinden bağış (%s)', s.ad, p.kad), 'bagis');
  insert into oyun.sirket_bagis(sirket_id, parti_id, veren, tutar, zaman) values (s.id, pa.id, p.id, p_tutar, t);
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
    values (s.id, t, -p_tutar, format('Siyasi bağış: %s', pa.ad), 0, p_tutar, 0);
  perform oyun.olay('ekonomi', format('%s şirketi %s''ye %s ₺ bağış yaptı (en büyük ortak: %s).', s.ad, pa.kisa, oyun.tl(p_tutar), p.kad), null, pa.id, t);
  return jsonb_build_object('tamam', true, 'kalan_sinir', sinir - hafta - p_tutar);
end $function$;

-- 2) Yalniz eksi bakiyeyi yasaklar. Borc tablolarina dokunmaz.
DO $kisit$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='oyun.cuzdan'::regclass AND conname='cuzdan_para_ge_sifir') THEN
  ALTER TABLE oyun.cuzdan ADD CONSTRAINT cuzdan_para_ge_sifir CHECK (para>=0) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='oyun.banka_musteri'::regclass AND conname='banka_vadesiz_ge_sifir') THEN
  ALTER TABLE oyun.banka_musteri ADD CONSTRAINT banka_vadesiz_ge_sifir CHECK (vadesiz>=0) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='oyun.partiler'::regclass AND conname='parti_kasa_ge_sifir') THEN
  ALTER TABLE oyun.partiler ADD CONSTRAINT parti_kasa_ge_sifir CHECK (kasa>=0) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='oyun.bakanlik_kasa'::regclass AND conname='bakanlik_kasa_ge_sifir') THEN
  ALTER TABLE oyun.bakanlik_kasa ADD CONSTRAINT bakanlik_kasa_ge_sifir CHECK (kasa>=0) NOT VALID;
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='oyun.sirketler'::regclass AND conname='sirket_kasa_ge_sifir') THEN
  ALTER TABLE oyun.sirketler ADD CONSTRAINT sirket_kasa_ge_sifir CHECK (kasa>=0) NOT VALID;
 END IF;
END $kisit$;
-- Onceki canli okuma testi: 2026-11-17'de bu bes tabloda negatif kasa/bakiye yoktu.
ALTER TABLE oyun.cuzdan VALIDATE CONSTRAINT cuzdan_para_ge_sifir;
ALTER TABLE oyun.banka_musteri VALIDATE CONSTRAINT banka_vadesiz_ge_sifir;
ALTER TABLE oyun.partiler VALIDATE CONSTRAINT parti_kasa_ge_sifir;
ALTER TABLE oyun.bakanlik_kasa VALIDATE CONSTRAINT bakanlik_kasa_ge_sifir;
ALTER TABLE oyun.sirketler VALIDATE CONSTRAINT sirket_kasa_ge_sifir;

-- 3) Oylar tablosunda (secim_id,secmen) benzersiz anahtari zaten vardir.
-- Eski oylar silinmez, mevcut oylar tekrar yazilamaz.
