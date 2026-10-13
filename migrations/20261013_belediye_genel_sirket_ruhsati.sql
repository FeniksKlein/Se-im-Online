-- Genel şirket kuruluşlarını da ruhsat sistemine bağlar; eski şirketlere dokunmaz.
begin;
alter table oyun.bel_yatirim_tarife drop constraint if exists bel_yatirim_tarife_tur_check;
alter table oyun.bel_yatirim_tarife add constraint bel_yatirim_tarife_tur_check
 check(tur in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','kur_sirket','arsa_insaat','yeni_proje','sube'));
alter table oyun.bel_yatirim_ruhsat drop constraint if exists bel_yatirim_ruhsat_tur_check;
alter table oyun.bel_yatirim_ruhsat add constraint bel_yatirim_ruhsat_tur_check
 check(tur in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','kur_sirket','arsa_insaat','yeni_proje','sube'));
CREATE OR REPLACE FUNCTION public.bel_ruhsat_merkezi()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); v_il smallint; baskan_il smallint; 
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oturum açmalısın.';end if;
 select il_id into baskan_il from oyun.makamlar where user_id=u and tur='bel' and bit is null order by id desc limit 1;
 return jsonb_build_object(
 'baskan_il',baskan_il,
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad) order by ad) from oyun.iller),'[]'::jsonb),
 'tarifeler',coalesce((select jsonb_agg(jsonb_build_object('tur',x.tur,'oran',oyun.bel_ruhsat_oran(baskan_il,x.tur),
   'taban_tl',oyun.bel_ruhsat_taban(baskan_il,x.tur),
   'degisim',(select degisim from oyun.bel_yatirim_tarife where il_id=baskan_il and tur=x.tur)) order by x.tur)
   from (values ('kur_fabrika'),('kur_magaza'),('kur_insaat'),('kur_sigorta'),('kur_pazar'),('kur_sirket'),('arsa_insaat'),('yeni_proje'),('sube')) x(tur)
   where baskan_il is not null),'[]'::jsonb),
 'bekleyen',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'tur',r.tur,'il_id',r.il_id,'oyuncu',p.kad,
 'sirket',coalesce(s.ad,r.sirket_adi),'hedef',r.hedef_id,'yatirim',r.tahmini_yatirim,
 'harc_tahmini',oyun.bel_ruhsat_tutar(oyun.bel_ruhsat_oran(r.il_id,r.tur),oyun.bel_ruhsat_taban(r.il_id,r.tur),r.tahmini_yatirim),
 'basvuru',r.basvuru) order by r.id desc)
 from oyun.bel_yatirim_ruhsat r join oyun.profiller p on p.id=r.oyuncu
 left join oyun.sirketler s on s.id=r.sirket_id
 where r.il_id=baskan_il and r.durum='bekliyor'),'[]'::jsonb),
 'benim',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'tur',r.tur,'il_id',r.il_id,'durum',r.durum,
 'sirket',coalesce(s.ad,r.sirket_adi),'hedef',r.hedef_id,'gerekce',r.gerekce,'odenmis',r.odenen_tl,
 'oran',r.onay_oran,'taban',r.onay_taban,'tahmini',r.tahmini_yatirim,'tarih',r.basvuru,
 'karar_zamani',r.karar_zamani) order by r.id desc)
 from (select * from oyun.bel_yatirim_ruhsat where oyuncu=u order by id desc limit 50) r
 left join oyun.sirketler s on s.id=r.sirket_id),'[]'::jsonb),
 'mali',case when baskan_il is null then null else oyun.bel_mali_rapor(baskan_il) end);
end $function$
;
CREATE OR REPLACE FUNCTION public.bel_ruhsat_basvur(p_tur text, p_il integer, p_sirket bigint DEFAULT NULL::bigint, p_hedef bigint DEFAULT NULL::bigint, p_ad text DEFAULT NULL::text, p_sektor text DEFAULT NULL::text, p_yatirim numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); v_id bigint; v_il smallint:=p_il::smallint; owner_sirket oyun.sirketler; v_baskan uuid; gercek_il smallint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oturum açmalısın.';end if;
 if p_tur not in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','kur_sirket','arsa_insaat','yeni_proje','sube') then raise exception 'Ruhsat türü geçersiz.';end if;
 if p_il is null or p_il<1 or p_il>81 or not exists(select 1 from oyun.iller where id=v_il) then raise exception 'İl geçersiz.';end if;
 if p_yatirim is null or p_yatirim<0 or p_yatirim>1000000000 then raise exception 'Yatırım bedeli geçersiz.';end if;
 if p_sirket is not null then
  select * into owner_sirket from oyun.sirketler where id=p_sirket and aktif;
  if owner_sirket.id is null or not oyun.sirket_yonetici_mi(p_sirket,u) then raise exception 'Bu şirketi yönetme yetkin yok.';end if;
 end if;
 if p_tur in ('arsa_insaat','yeni_proje','sube') and p_sirket is null then raise exception 'Mevcut şirket seçmelisin.';end if;
 if p_tur='arsa_insaat' then
  if p_hedef is null or not exists(select 1 from oyun.eko_arsalar a where a.id=p_hedef and a.il_id=v_il and a.sahibi_sirket=p_sirket and a.durum='satildi') then raise exception 'Bu ilde şirkete ait bir arsa seç.';end if;
 elsif p_tur='sube' then
  select y.il_id into gercek_il from oyun.eko_bolumler b join oyun.eko_yapilar y on y.id=b.yapi_id where b.id=p_hedef and b.tur='dukkan';
  if gercek_il is distinct from v_il then raise exception 'Şube dükkânı seçilen ilde değil.';end if;
 elsif p_tur like 'kur_%' and p_sirket is null then
  if char_length(btrim(coalesce(p_ad,''))) not between 3 and 50 then raise exception 'Şirket adını 3-50 karakter yaz.';end if;
  if p_tur='kur_sirket' and p_sektor not in ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka') then raise exception 'Geçerli şirket sektörü seç.';end if;
  if p_tur='kur_pazar' and (p_sektor is null or not exists(select 1 from oyun.pazar_sektor where kod=p_sektor)) then raise exception 'Geçerli pazar sektörünü seç.';end if;
 end if;
 if exists(select 1 from oyun.bel_yatirim_ruhsat r where r.oyuncu=u and r.il_id=v_il and r.tur=p_tur and r.durum in ('bekliyor','onay')
   and r.sirket_id is not distinct from p_sirket and r.hedef_id is not distinct from p_hedef
   and r.sirket_adi is not distinct from nullif(btrim(p_ad),'') and r.sektor is not distinct from p_sektor
   and (r.durum='bekliyor' or r.karar_zamani>now()-interval '72 hours')) then
  raise exception 'Bu yatırım için bekleyen veya kullanılmamış onaylı ruhsatın zaten var.';end if;
 insert into oyun.bel_yatirim_ruhsat(il_id,tur,oyuncu,sirket_id,hedef_id,sirket_adi,sektor,tahmini_yatirim)
 values(v_il,p_tur,u,p_sirket,p_hedef,nullif(btrim(p_ad),''),nullif(btrim(p_sektor),''),p_yatirim) returning id into v_id;
 select user_id into v_baskan from oyun.makamlar where tur='bel' and il_id=v_il and bit is null order by id desc limit 1;
 if v_baskan is not null then
   perform oyun.bildir(v_baskan,format('Yeni yatırım ruhsatı başvurusu #%s: %s. Ruhsat Merkezi ekranında onay veya ret ver.',v_id,p_tur),oyun.simdi());
 end if;
 return jsonb_build_object('id',v_id,'durum','bekliyor','baskan_var',v_baskan is not null,
 'tahmini_harc',oyun.bel_ruhsat_tutar(oyun.bel_ruhsat_oran(v_il,p_tur),oyun.bel_ruhsat_taban(v_il,p_tur),p_yatirim));
end $function$
;
CREATE OR REPLACE FUNCTION public.bel_ruhsat_tarife_ayarla(p_tur text, p_oran numeric, p_taban numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); il smallint; eski timestamptz;
begin
 select il_id into il from oyun.makamlar where tur='bel' and user_id=u and bit is null order by id desc limit 1;
 if il is null then raise exception 'Harçları yalnızca belediye başkanı belirler.';end if;
 if p_tur not in ('kur_fabrika','kur_magaza','kur_insaat','kur_sigorta','kur_pazar','kur_sirket','arsa_insaat','yeni_proje','sube') then raise exception 'Tür geçersiz.';end if;
 if p_oran is null or p_oran<0 or p_oran>8 or p_oran<>round(p_oran,2)
 or p_taban is null or p_taban<0 or p_taban>500000 or p_taban<>round(p_taban) then raise exception 'Oran %%0-8, sabit harç 0-500.000 TL ve tam sayı olmalı.';end if;
 perform pg_advisory_xact_lock(93115,il::integer);
 select degisim into eski from oyun.bel_yatirim_tarife where il_id=il and tur=p_tur;
 if eski>now()-interval '24 hours' then raise exception 'Aynı harç tarifesi 24 saatte bir değiştirilebilir.';end if;
 insert into oyun.bel_yatirim_tarife(il_id,tur,oran,taban_tl,degistiren,degisim) values(il,p_tur,p_oran,p_taban,u,now())
 on conflict(il_id,tur) do update set oran=excluded.oran,taban_tl=excluded.taban_tl,degistiren=excluded.degistiren,degisim=excluded.degisim;
 perform oyun.olay('belediye',format('%s belediyesi %s yatırım harcını %% %s + %s TL taban olarak belirledi.',(select ad from oyun.iller where id=il),p_tur,p_oran,p_taban),il,null,oyun.simdi());
 return jsonb_build_object('tur',p_tur,'oran',p_oran,'taban_tl',p_taban);
end $function$
;

create or replace function oyun.bel_genel_sirket_ruhsati()
returns trigger language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); r oyun.bel_yatirim_ruhsat; il smallint; harc numeric;
begin
 -- Şirket kurulumunun diğer yatırım türlerinin alt adımı olması halinde,
 -- ruhsatı ilgili yatırımın INSERT tetikleyicisi kontrol eder; iki kez tahsil edilmez.
 if not exists(select 1 from oyun.sirketler where id=new.id) or new.sektor='banka' or u is null then return null;end if;
 if exists(select 1 from oyun.eko_isletmeler where sirket_id=new.id)
 or exists(select 1 from oyun.pazar_sirket where sirket_id=new.id) then return null;end if;
 if new.kurucu is distinct from u then raise exception 'Şirket kuruluşunda oturum sahibi eşleşmiyor.';end if;
 select il_id into il from oyun.profiller where id=u;
 select * into r from oyun.bel_yatirim_ruhsat br where br.oyuncu=u and br.il_id=il and br.tur='kur_sirket'
 and br.durum='onay' and br.sirket_adi=new.ad and br.sektor=new.sektor
 and br.karar_zamani>now()-interval '72 hours'
 order by br.id limit 1 for update;
 if r.id is null then raise exception 'Genel şirket kuruluşu için ikamet ilinin belediyesinden onaylı ruhsat al. Ekonomi merkezindeki Yatırım Ruhsat Merkezi üzerinden başvur.';end if;
 harc:=oyun.bel_ruhsat_tutar(r.onay_oran,r.onay_taban,new.sermaye);
 update oyun.sirketler set kasa=kasa-harc where id=new.id and kasa>=harc;
 if not found then raise exception 'Şirket kasasında ruhsat harcını ödeyecek % TL bulunmuyor.',harc;end if;
 update oyun.il_durum set kasa=kasa+harc/nullif(oyun.pazar_tl_milyar(),0) where il_id=il;
 update oyun.bel_yatirim_ruhsat set durum='kullanildi',odenen_tl=harc,kullanma=now() where id=r.id;
 insert into oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama,zaman)
 values(il,'ruhsat_geliri',harc/nullif(oyun.pazar_tl_milyar(),0),format('Genel şirket kurma ruhsatı (#%s) - %s TL',r.id,harc),oyun.simdi());
 return null;
end $f$;
revoke all on function oyun.bel_genel_sirket_ruhsati() from public,anon,authenticated;
drop trigger if exists tr_bel_genel_sirket_ruhsati on oyun.sirketler;
create constraint trigger tr_bel_genel_sirket_ruhsati
 after insert on oyun.sirketler deferrable initially deferred for each row
 execute function oyun.bel_genel_sirket_ruhsati();
commit;
