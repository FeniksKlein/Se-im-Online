-- Yeni kurulus ruhsatinda gizli secimden eski sirkete baglanma hatasini engelle.
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
 -- Yeni sirket basvurusu gizli eski sirket secimine baglanamaz.
 if p_tur in ('kur_sirket','kur_pazar') and p_sirket is not null then
   raise exception 'Yeni sirket kurulusu icin mevcut sirket secilemez. Sirket adi ve sektoru gir.';
 end if;
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
  if p_tur='kur_sirket' and p_sektor not in ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka','ajans') then raise exception 'Geçerli şirket sektörü seç.';end if;
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

-- UI icin asil ruhsat sirket/sector bilgilerini raporla.
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
 'sirket',coalesce(s.ad,r.sirket_adi),'sirket_adi',r.sirket_adi,'sirket_id',r.sirket_id,'sektor',r.sektor,'hedef',r.hedef_id,'gerekce',r.gerekce,'odenmis',r.odenen_tl,
 'oran',r.onay_oran,'taban',r.onay_taban,'tahmini',r.tahmini_yatirim,'tarih',r.basvuru,
 'karar_zamani',r.karar_zamani) order by r.id desc)
 from (select * from oyun.bel_yatirim_ruhsat where oyuncu=u order by id desc limit 50) r
 left join oyun.sirketler s on s.id=r.sirket_id),'[]'::jsonb),
 'mali',case when baskan_il is null then null else oyun.bel_mali_rapor(baskan_il) end);
end $function$
;
