-- 26.11.2026 · (1) Bedelsiz hisse devri, (2) Olağanüstü kurultay imza kuralları "yalnız büyük itiraz"
-- Canlı migration'lar: sirket_devir_bedelsiz_izin, olaganustu_kurultay_buyuk_itiraz_kurallari,
--   olaganustu_kurultay_10gun_yeni_parti_14gun, olaganustu_kurultay_yeni_parti_kurali_duzelt (26.11 akşam)
--
-- (1) Şirket Ortaklık Merkezi bedelsiz (0 ₺) devre izin veriyordu, ama ticaret_devir_kayit'taki vergi tetikleyicisi
--     bedel <= 0'ı "Devir kimlikleri ve bedeli geçersiz" diye reddediyordu. Artık yalnız eksik kimlik / negatif bedel reddedilir;
--     bedelsiz devirde damga vergisi 0'dır. İcra haczi ve konkordato korumaları aynen durur.
-- (2) Ercan: "Yenilenler sürekli kurultay için imza topluyor; sadece büyük itiraz varsa kurultay olsun."
--     - Eşik: hesabı en az 3 günlük üyelerin YARIDAN FAZLASI (CHP tüzüğündeki seçimli olağanüstü kurultay mantığı).
--     - Kurultaydan sonraki 10 gün kampanya açılamaz; henüz kurultay yapmamış yeni partide kuruluştan itibaren 14 gün.
--     - Olağan kurultaya 7 günden az kaldıysa imza alınmaz (açık kampanyada da).
--     - Süresi dolan (başarısız) kampanyadan sonra 14 gün yeni kampanya açılamaz.
--     - Kampanyayı ancak en az 7 gündür partide olan üye açar; partiden ayrılanın imzası sayılmaz.
--     - Kampanya süresi 72 saat, imza için hesap en az 3 günlük (26.11 sabah kuralı) aynen.
--     - Yönetimin kapattığı kampanyalar 'iptal' durumuna alınır (başarısız sayılmaz, soğuma başlatmaz).

-- (1) Bedelsiz hisse devri
CREATE OR REPLACE FUNCTION oyun.tg_sirket_devir_kayit_vergi()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_oran numeric; v_vergi numeric; v_pay numeric;
begin
 if new.tur not in ('sirket_tam','sirket_hisse') then return new; end if;
 -- Bedelsiz (0 ₺) devir geçerlidir; yalnız eksik kimlik veya negatif bedel reddedilir.
 if new.satici is null or new.alici is null or new.bedel is null or new.bedel<0 then
   raise exception 'Devir kimlikleri ve bedeli gecersiz';
 end if;
 if exists(select 1 from oyun.icra_haciz_yeni h where h.varlik_id=new.varlik_id
     and h.tur in ('sirket','sirket_hisse','sirket_pay','hisse')
     and h.durum not in ('satildi','kaldirildi','iptal','tamamlandi','kapandi')) or
    exists(select 1 from oyun.oyb_icra_haciz h where h.varlik_id=new.varlik_id
     and h.tur in ('sirket','sirket_hisse','sirket_pay','hisse')
     and h.durum not in ('satildi','kaldirildi','iptal','tamamlandi','kapandi')) then
   raise exception 'İcra haczi bulunan şirket/hisse normal satışla devredilemez';
 end if;
 if exists(select 1 from oyun.sirket_konkordato where sirket_id=new.varlik_id
    and durum='aktif' and bit>now()) then
    raise exception 'Aktif konkordato korumasındaki şirket devredilemez';
 end if;
 v_oran:=greatest(0,coalesce(oyun.eko_vergi_oran('damga'),1));
 v_vergi:=round(new.bedel*v_oran/100,2);
 if v_vergi>0 then
   perform oyun.para_islem(new.satici,-v_vergi,'sirket',
      format('Şirket #%s devir işlemi vergisi (%%%s)',new.varlik_id,v_oran),new.zaman,v_vergi);
   update oyun.ulke set hazine=hazine+v_vergi/oyun.pazar_tl_milyar() where id=1;
   insert into oyun.eko_vergi_hareket(sirket_id,oyuncu,kod,matrah,oran,tutar,kaynak,kaynak_id,zaman)
    values(new.varlik_id,new.satici,'damga',new.bedel,v_oran,v_vergi,'sirket_devir',new.id,new.zaman);
 end if;
 insert into oyun.sirket_devir_vergi(devir_id,sirket_id,satici,alici,bedel,oran,vergi,zaman)
  values(new.id,new.varlik_id,new.satici,new.alici,new.bedel,v_oran,v_vergi,new.zaman)
  on conflict (devir_id) do nothing;
 if new.tur='sirket_tam' then
   update oyun.sirketler set yonetici=new.alici where id=new.varlik_id;
   update oyun.sirket_hisse_ilanlari set durum='iptal',kapanis=new.zaman
   where sirket_id=new.varlik_id and durum='acik';
 elsif (select yonetici from oyun.sirketler where id=new.varlik_id)=new.satici and
    not exists (select 1 from oyun.sirket_ortaklari where sirket_id=new.varlik_id and user_id=new.satici and pay>0)
 then
   update oyun.sirketler set yonetici=oyun.sirket_sahibi(new.varlik_id) where id=new.varlik_id;
 end if;
 return new;
end $function$;

-- (2) Olağanüstü kurultay imza kuralları
alter table oyun.sos_parti_imza drop constraint if exists sos_parti_imza_durum_check;
alter table oyun.sos_parti_imza add constraint sos_parti_imza_durum_check check (durum = any (array['acik','basarili','sure_doldu','iptal']));

create or replace function oyun.pkd_imza_kilit(p_parti bigint, p_t timestamptz, p_acma boolean)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare v_son timestamptz; v_olagan timestamptz; v_bas timestamptz; v_kur timestamptz;
begin
 select max(goreve_bas) into v_son from oyun.secimler
  where tur='kurultay' and durum='tamam' and goreve_bas<=p_t and (hedef_parti_id=p_parti or hedef_parti_id is null);
 select kurulus into v_kur from oyun.partiler where id=p_parti;
 select min(oy_bas) into v_olagan from oyun.secimler
  where tur='kurultay' and not ara and durum<>'tamam' and oy_bas>p_t;
 if v_olagan is not null and v_olagan-interval '7 days'<=p_t then
   return jsonb_build_object('neden','Olağan kurultaya 7 günden az kaldığı için olağanüstü kurultay imzası alınmıyor.','bit',v_olagan);
 end if;
 if p_acma then
   -- Henüz kurultay yapmamış yeni partide kuruluştan itibaren 14 gün
   if v_son is null and v_kur is not null and v_kur+interval '14 days'>p_t then
     return jsonb_build_object('neden','Yeni kurulan partide ilk 14 gün olağanüstü kurultay imza kampanyası açılamaz.','bit',v_kur+interval '14 days');
   end if;
   if v_son is not null and v_son+interval '10 days'>p_t then
     return jsonb_build_object('neden','Son kurultaydan sonraki 10 gün içinde olağanüstü kurultay imza kampanyası açılamaz.','bit',v_son+interval '10 days');
   end if;
   select max(bit) into v_bas from oyun.sos_parti_imza where parti_id=p_parti and durum='sure_doldu';
   if v_bas is not null and v_bas+interval '14 days'>p_t then
     return jsonb_build_object('neden','Son imza kampanyası yeterli desteğe ulaşamadığı için 14 gün yeni kampanya açılamaz.','bit',v_bas+interval '14 days');
   end if;
 end if;
 return null;
end $$;

create or replace function oyun.pkd_gecerli_imza(p_kampanya bigint, p_parti bigint)
returns int language sql stable security definer set search_path to '' as $$
 select count(*)::int from oyun.sos_parti_imzaci i join oyun.profiller pr on pr.id=i.user_id
 where i.kampanya_id=p_kampanya and pr.parti_id=p_parti;
$$;

revoke all on function oyun.pkd_imza_kilit(bigint,timestamptz,boolean), oyun.pkd_gecerli_imza(bigint,bigint) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.sos_parti_imza_durum(p_parti bigint)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); c oyun.sos_parti_imza; n int; k jsonb;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 update oyun.sos_parti_imza set durum='sure_doldu' where parti_id=p_parti and durum='acik' and bit<=t;
 select * into c from oyun.sos_parti_imza where parti_id=p_parti order by id desc limit 1;
 select count(*) into n from oyun.profiller where parti_id=p_parti and olusturma<=t-interval '3 days';
 k:=oyun.pkd_imza_kilit(p_parti,t,c.id is null or c.durum<>'acik');
 return jsonb_build_object('parti_id',p_parti,'uye_sayisi',n,'esik',greatest(2,floor(n/2)::int+1),
 'uyeyim',exists(select 1 from oyun.profiller where id=u and parti_id=p_parti),
 'imza_hakkim',exists(select 1 from oyun.profiller where id=u and parti_id=p_parti and olusturma<=t-interval '3 days') and k is null,
 'kilit',k,
 'kural','Olağanüstü kurultay için üyelerin yarıdan fazlasının imzası gerekir. Kurultaydan sonraki 10 gün, yeni partilerde ilk 14 gün ve olağan kurultaydan önceki 7 gün imza alınmaz; başarısız kampanyadan sonra 14 gün yeni kampanya açılamaz.',
 'kampanya',case when c.id is null then null else jsonb_build_object('id',c.id,'bas',c.bas,'bit',c.bit,'durum',c.durum,'secim_id',c.secim_id,
 'imza',oyun.pkd_gecerli_imza(c.id,p_parti),
 'imzaladim',exists(select 1 from oyun.sos_parti_imzaci where kampanya_id=c.id and user_id=u)) end);
end $function$;

CREATE OR REPLACE FUNCTION public.sos_parti_imzala(p_parti bigint)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); p oyun.partiler; c oyun.sos_parti_imza; n int; toplam int; o jsonb; k jsonb;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into p from oyun.partiler where id=p_parti and not kapali for update;
 if p.id is null or not exists(select 1 from oyun.profiller where id=u and parti_id=p.id) then raise exception 'Yalnızca bu partinin üyeleri imzalayabilir.'; end if;
 if not exists(select 1 from oyun.profiller where id=u and olusturma<=t-interval '3 days') then raise exception 'Olağanüstü kurultay imzası için hesabının en az 3 günlük olması gerekir.'; end if;
 if exists(select 1 from oyun.secimler where tur='kurultay' and ara and hedef_parti_id=p.id and durum<>'tamam' and goreve_bas>t) then raise exception 'Parti için zaten olağanüstü kurultay var.'; end if;
 update oyun.sos_parti_imza set durum='sure_doldu' where parti_id=p.id and durum='acik' and bit<=t;
 select * into c from oyun.sos_parti_imza where parti_id=p.id and durum='acik' for update;
 k:=oyun.pkd_imza_kilit(p.id,t,c.id is null);
 if k is not null then raise exception '% (% tarihine kadar)', k->>'neden', to_char((k->>'bit')::timestamptz at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI'); end if;
 if c.id is null then
   if not exists(select 1 from oyun.profiller where id=u and parti_id=p.id and coalesce(parti_at,olusturma)<=t-interval '7 days') then
     raise exception 'Olağanüstü kurultay imza kampanyasını en az 7 gündür partide olan bir üye açabilir.';
   end if;
   insert into oyun.sos_parti_imza(parti_id,acan,bas,bit) values(p.id,u,t,t+interval '72 hours') returning * into c;
 end if;
 if not exists(select 1 from oyun.profiller where id=u and parti_id=p.id and coalesce(parti_at,olusturma)<=c.bas) and c.acan<>u then raise exception 'İmza kampanyası açıldıktan sonra katılan üyeler bu kampanyada imza atamaz.'; end if;
 insert into oyun.sos_parti_imzaci(kampanya_id,user_id) values(c.id,u) on conflict do nothing;
 if not found then raise exception 'Bu kampanyayı zaten imzaladın.'; end if;
 n:=oyun.pkd_gecerli_imza(c.id,p.id);
 select count(*) into toplam from oyun.profiller where parti_id=p.id and olusturma<=t-interval '3 days';
 if n>=greatest(2,floor(toplam/2)::int+1)
    and not exists(select 1 from oyun_yonetim.parti_kurultay_kilit kk where kk.parti_id=p.id) then
   o:=oyun.ara_secim_olustur('gb',p.id,null::smallint,t);
   update oyun.secimler set ara_neden='uye_imza_kampanyasi' where id=(o->>'secim_id')::bigint and ara and ara_neden='genel_baskan_istifa';
   update oyun.sos_parti_imza set durum='basarili',secim_id=(o->>'secim_id')::bigint where id=c.id;
   perform oyun.olay('parti',format('%s üyelerinin yarıdan fazlasının imzasıyla olağanüstü kurultay kararı alındı.',p.ad),null,p.id,t);
   if p.gb is not null then perform oyun.bildir(p.gb,format('%s üyelerinin yarıdan fazlası olağanüstü kurultay topladı.',p.ad),t); end if;
 end if;
 return public.sos_parti_imza_durum(p.id);
end $function$;
