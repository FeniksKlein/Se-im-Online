-- Merkez ilini isletme kurulumu, insaat tetikleyicisi ve ruhsat tahsilatina tasima
CREATE OR REPLACE FUNCTION oyun.bel_genel_sirket_ruhsati()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); r oyun.bel_yatirim_ruhsat; il smallint; harc numeric;
begin
 -- Şirket kurulumunun diğer yatırım türlerinin alt adımı olması halinde,
 -- ruhsatı ilgili yatırımın INSERT tetikleyicisi kontrol eder; iki kez tahsil edilmez.
 if not exists(select 1 from oyun.sirketler where id=new.id) or new.sektor='banka' or u is null then return null;end if;
 if exists(select 1 from oyun.eko_isletmeler where sirket_id=new.id)
 or exists(select 1 from oyun.pazar_sirket where sirket_id=new.id) then return null;end if;
 if new.kurucu is distinct from u then raise exception 'Şirket kuruluşunda oturum sahibi eşleşmiyor.';end if;
 select coalesce((select il_id from oyun.sirket_merkezleri where sirket_id=new.id), (select il_id from oyun.profiller where id=u), 1) into il;
 perform oyun.bel_kurulus_otomatik_hazirla(u,new,il,'kur_sirket');
 select * into r from oyun.bel_yatirim_ruhsat br where br.oyuncu=u and br.il_id=il and br.tur='kur_sirket'
 and br.durum='onay' and br.sirket_adi=new.ad and br.sektor=new.sektor
 and br.karar_zamani>now()-interval '72 hours'
 order by br.id limit 1 for update;
 if r.id is null then raise exception 'Genel şirket kuruluşu için seçtiğin ilin belediyesinden onaylı ruhsat al. Ekonomi merkezindeki Yatırım Ruhsat Merkezi üzerinden başvur.';end if;
 harc:=oyun.bel_ruhsat_tutar(r.onay_oran,r.onay_taban,new.sermaye);
 update oyun.sirketler set kasa=kasa-harc where id=new.id and kasa>=harc;
 if not found then raise exception 'Şirket kasasında ruhsat harcını ödeyecek % TL bulunmuyor.',harc;end if;
 update oyun.il_durum set kasa=kasa+harc/nullif(oyun.pazar_tl_milyar(),0) where il_id=il;
 update oyun.bel_yatirim_ruhsat set durum='kullanildi',odenen_tl=harc,kullanma=now() where id=r.id;
 insert into oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama,zaman)
 values(il,'ruhsat_geliri',harc/nullif(oyun.pazar_tl_milyar(),0),format('Genel şirket kurma ruhsatı (#%s) - %s TL',r.id,harc),oyun.simdi());
 return null;
end $function$
;

CREATE OR REPLACE FUNCTION oyun.eko_insaat_sirket_tanit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  -- ON CONFLICT DO NOTHING tek basina yeterli degil: BEFORE INSERT
  -- ruhsat kapisi, cakisacak satir icin bile yeniden harc arar.
  if new.sektor = 'insaat' and new.aktif
    and not exists (
      select 1 from oyun.eko_isletmeler where sirket_id = new.id
    ) then
    insert into oyun.eko_isletmeler
      (sirket_id, tur, il_id, urun, uretim_fiyat, perakende_fiyat)
    values
      (new.id, 'insaat',
       coalesce((select il_id from oyun.sirket_merkezleri where sirket_id = new.id), (select il_id from oyun.profiller where id = new.kurucu), 1),
       null, 0, 0)
    on conflict (sirket_id) do nothing;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.eko_ticaret_islem(p_eylem text, p_veri jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 u uuid:=auth.uid();t timestamptz:=oyun.simdi();
 sid bigint:=nullif(p_veri->>'sirket','')::bigint;
 hedef bigint:=nullif(p_veri->>'hedef','')::bigint;
 ur text:=p_veri->>'urun';v_kategori text:=p_veri->>'kategori';
 miktar int:=coalesce(nullif(p_veri->>'adet','')::integer,0);
 esik int:=coalesce(nullif(p_veri->>'esik','')::integer,0);
 v numeric:=coalesce(nullif(p_veri->>'tutar','')::numeric,0);
 ciro numeric:=coalesce(nullif(p_veri->>'ciro','')::numeric,0);
 kar numeric:=coalesce(nullif(p_veri->>'kar','')::numeric,0);
 s oyun.sirketler; e oyun.eko_isletmeler; k oyun.eko_urun_katalog; x oyun.eko_urun_stok;
 marka oyun.eko_markalar; z bigint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris yapmalisin.';end if;
 if p_veri is null or jsonb_typeof(p_veri)<>'object' then raise exception 'Gecersiz veri.';end if;
 if sid is null then raise exception 'Sirket secilmedi.';end if;
 select * into s from oyun.sirketler where id=sid for update;
 select * into e from oyun.eko_isletmeler where sirket_id=sid;
 if s.id is null or not s.aktif or not oyun.sirket_yonetici_mi(sid,u)
 then raise exception 'Bu sirketi yonetmeye yetkin yok.';end if;
 
 if p_eylem='bagla' then
  if e.sirket_id is not null then raise exception 'Bu sirket zaten yeni ekonomiye bagli.';end if;
  if coalesce((select pay from oyun.sirket_ortaklari where sirket_id=sid and user_id=u),0)<>100
    or s.halka_acik then raise exception 'Yalnizca yuzde yuz sahip oldugun halka kapali sirket baglanabilir.';end if;
  if s.sektor in ('ticaret','market') then
   insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat,magaza_kategori)
   values(sid,'magaza',coalesce((select il_id from oyun.sirket_merkezleri where sirket_id=sid), (select il_id from oyun.profiller where id=u), 1),null,0,9500,'market');
   return jsonb_build_object('tur','magaza','sirket',sid);
  elsif s.sektor in ('tarim','sanayi','teknoloji') then
   if s.sektor='tarim' and ur<>'gida' or s.sektor='teknoloji' and ur<>'teknoloji'
     or s.sektor='sanayi' and ur not in ('gida','teknoloji','malzeme')
   then raise exception 'Fabrika uretim grubu sirket sektorune uygun degil.';end if;
   insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat)
   values(sid,'fabrika',coalesce((select il_id from oyun.sirket_merkezleri where sirket_id=sid), (select il_id from oyun.profiller where id=u), 1),ur,0,0);
   return jsonb_build_object('tur','fabrika','sirket',sid);
  end if;
  raise exception 'Bu sektor uretim veya magazacilik icin uygun degil.';
 end if;
if p_eylem='uret' then
  select * into k from oyun.eko_urun_katalog where kod=ur and aktif;
  if e.tur<>'fabrika' or k.kod is null or k.grup<>e.urun or miktar<1 or miktar>ceil(k.parti_ust*coalesce((oyun.eko_fabrika_kapasite(sid)->>'katsayi')::numeric,1)) then
   raise exception 'Urun bu fabrikada uretilemez veya parti kapasitesi asildi.';end if;
  v:=round(k.maliyet*miktar);
  update oyun.sirketler set kasa=kasa-v where id=sid and kasa>=v;
  if not found then raise exception 'Uretim icin kasa yetersiz.';end if;
  insert into oyun.eko_uretim_emir(sirket_id,urun,adet,toplam_maliyet,baslangic,hazir)
  values(sid,ur,miktar,v,t,t+make_interval(mins=>k.uretim_dakika)) returning id into z;
  insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
  values(sid,u,'urun_uretim',-v,format('%s adet %s uretim emri',miktar,k.ad));
  return jsonb_build_object('emir',z,'maliyet',v,'bitis',t+make_interval(mins=>k.uretim_dakika));
 elsif p_eylem='toptan' then
  if e.tur<>'magaza' then raise exception 'Bir magaza sec.';end if;
  return oyun.eko_urun_toptan(sid,hedef,ur,miktar,u);
 elsif p_eylem='fiyat' then
  select * into x from oyun.eko_urun_stok where sirket_id=sid and urun=ur for update;
  select * into k from oyun.eko_urun_katalog where kod=ur and aktif;
  if x.sirket_id is null or k.kod is null or v<>round(v) then raise exception 'Urun veya fiyat gecersiz.';end if;
  if e.tur='fabrika' then
   if v<round(k.maliyet*1.05) or v>round(k.onerilen_satis*1.2)
   then raise exception 'Toptan fiyat uretim maliyeti ve piyasa araliginda olmali.';end if;
  elsif e.tur='magaza' then
   if v<round(x.maliyet_birim*1.05) or v>round(k.onerilen_satis*3)
   then raise exception 'Perakende fiyati maliyetin ustunde ve piyasa araliginda olmali.';end if;
  else raise exception 'Yalnizca fabrika veya magaza urununu fiyatlayabilir.';end if;
  update oyun.eko_urun_stok set satis_fiyati=v,guncelleme=t where sirket_id=sid and urun=ur;
  return jsonb_build_object('fiyat',v);
 elsif p_eylem='magaza_tur' then
  if e.tur<>'magaza' or v_kategori not in ('market','fastfood','kahve') then
   raise exception 'Market, fast food veya kahve kategorisi sec.';end if;
  if exists(select 1 from oyun.eko_franchise f join oyun.eko_markalar m on m.sirket_id=f.marka
  where f.sube=sid and m.kategori<>v_kategori) then raise exception 'Bayilik markasinin kategorisi degistirilemez.';end if;
  if exists(select 1 from oyun.eko_markalar where sirket_id=sid) then
    raise exception 'Markali magazanin kategorisi degistirilemez.';end if;
  update oyun.eko_isletmeler set magaza_kategori=v_kategori where sirket_id=sid;
  return jsonb_build_object('kategori',v_kategori);
 elsif p_eylem='oto' then
  if e.tur<>'magaza' then raise exception 'Otomatik tedarik sadece magazalar icindir.';end if;
  select * into k from oyun.eko_urun_katalog where kod=ur and aktif;
  if k.kod is null then raise exception 'Urun bulunamadi.';end if;
  if coalesce((p_veri->>'aktif')::boolean,true)=false then
   update oyun.eko_otomatik_tedarik set aktif=false where sirket_id=sid and urun=ur;
   return jsonb_build_object('aktif',false);
  end if;
  if esik not between 0 and 300 or miktar not between 1 and 500 or v<k.maliyet or v>k.onerilen_satis*3
  then raise exception 'Stok esigi, miktar veya azami fiyat gecersiz.';end if;
  -- Her 7 gunluk oyun otomasyonu 12.000 TL. Aktif suresi bitmeden yeniden abonelik tahsil edilmez.
  if not exists(select 1 from oyun.eko_otomatik_tedarik
    where sirket_id=sid and urun=ur and aktif and bitis>t) then
   update oyun.sirketler set kasa=kasa-12000 where id=sid and kasa>=12000;
   if not found then raise exception 'Otomasyon bedeli icin 12.000 TL gerekli.';end if;
   update oyun.ulke set hazine=hazine+12000 where id=1;
  end if;
  insert into oyun.eko_otomatik_tedarik(sirket_id,urun,esik,miktar,azami_birim_fiyat,bitis,aktif)
  values(sid,ur,esik,miktar,v,t+interval '7 days',true)
  on conflict(sirket_id,urun) do update set esik=excluded.esik,miktar=excluded.miktar,
    azami_birim_fiyat=excluded.azami_birim_fiyat,bitis=case when oyun.eko_otomatik_tedarik.aktif and oyun.eko_otomatik_tedarik.bitis>t
 then oyun.eko_otomatik_tedarik.bitis else excluded.bitis end,aktif=true;
  return jsonb_build_object('aktif',true,'bitis',(select bitis from oyun.eko_otomatik_tedarik where sirket_id=sid and urun=ur));
 elsif p_eylem='marka' then
  if e.tur<>'magaza' or v_kategori not in ('market','fastfood','kahve')
    or v<>round(v) or v<1000 or v>10000000 or ciro<1 or ciro>15 or kar<0 or kar>20
  then raise exception 'Marka, ucret veya pay oranlari gecersiz.';end if;
  if exists(select 1 from oyun.eko_franchise where sube=sid) then raise exception 'Baska markanin bayisi kendi markasini kuramaz.';end if;
  if not exists(select 1 from oyun.eko_markalar where sirket_id=sid) then
   perform public.eko_islem('marka_ac',jsonb_build_object('sirket',sid,'tutar',v,'adet',ciro));
  end if;
  update oyun.eko_markalar set kategori=v_kategori,isim_hakki=v,komisyon=ciro,kar_payi=kar,guncelleme=t where sirket_id=sid;
  update oyun.eko_isletmeler set magaza_kategori=v_kategori where sirket_id=sid;
  return jsonb_build_object('marka',sid,'kategori',v_kategori);
 elsif p_eylem='bayilik' then
  if e.tur<>'magaza' then raise exception 'Bayilik icin bir magaza gerekli.';end if;
  select * into marka from oyun.eko_markalar where sirket_id=hedef;
  if marka.sirket_id is null then raise exception 'Marka bulunamadi.';end if;
  perform public.eko_islem('franchise_al',jsonb_build_object('sirket',sid,'hedef',hedef));
  update oyun.eko_isletmeler set magaza_kategori=marka.kategori where sirket_id=sid;
  return jsonb_build_object('marka',hedef,'ciro',marka.komisyon,'kar',marka.kar_payi);
 else
  raise exception 'Bilinmeyen ticaret islemi.';
 end if;
end $function$
;


create or replace function public.sirket_kur_aktif_ilde(p_ad text,p_sektor text,p_sermaye numeric,p_urun text,p_il integer)
returns jsonb language plpgsql security definer set search_path to ''
as $$
declare v jsonb; sid bigint; grp text; tur text;
begin
 if auth.uid() is null then raise exception 'Oturum acmalisin.'; end if;
 if p_sektor not in ('tarim','sanayi','teknoloji') then
   raise exception 'Bu tur icin uygun sektor kurulusunu kullan.';end if;
 v:=public.sirket_kur_ilde(p_ad,p_sektor,p_sermaye,p_il);
 sid:=(v->>'id')::bigint;
 grp:=case when p_sektor='tarim' then 'gida'
           when p_sektor='teknoloji' then 'teknoloji'
           else coalesce(nullif(p_urun,''),'malzeme') end;
 if grp not in ('gida','teknoloji','malzeme') then raise exception 'Gecersiz uretim grubu.';end if;
 perform public.eko_ticaret_islem('bagla',jsonb_build_object('sirket',sid,'urun',grp));
 return v||jsonb_build_object('tur','fabrika','grup',grp);
end $$;
