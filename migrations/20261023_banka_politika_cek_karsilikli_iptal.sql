-- Seçim Online | 23.10.2026
-- Karşılıklı çek iptali + tüm oyuncu bankalarında açıklayıcı politika doğrulaması.
-- Canlı Supabase'teki doğrulanmış fonksiyonların kalıcı kaynak kopyası.
-- Mevcut çek, para, kredi, şirket ve oyuncu kayıtlarını değiştirmez.
-- Ön koşul: 20261023_cek_sistemi_tam.sql ve oyuncu banka yönetim tabloları kurulmuş olmalıdır.
create table if not exists oyun.cek_iptal_talepleri(
 cek_id bigint primary key references oyun.cekler(id),
 talep_eden uuid not null references oyun.profiller(id),
 hamil uuid, hamil_sirket bigint,
 veren_onay boolean not null default false, hamil_onay boolean not null default false,
 durum text not null default 'bekliyor' check(durum in ('bekliyor','onaylandi','reddedildi','vazgecildi')),
 olusturma timestamptz not null default now(), guncelleme timestamptz not null default now()
);
alter table oyun.cek_iptal_talepleri enable row level security;
revoke all on oyun.cek_iptal_talepleri from public,anon,authenticated;
alter table oyun.cekler drop constraint if exists cekler_durum_check;
alter table oyun.cekler add constraint cekler_durum_check
 check(durum in ('aktif','karsiliksiz','odendi','iade','iptal'));

CREATE OR REPLACE FUNCTION public.banka_yonetim_ayar_kaydet(p_banka bigint, p_pos boolean, p_kart boolean, p_kredi boolean, p_min_not integer DEFAULT 850, p_kart_max numeric DEFAULT 500000, p_kredi_max numeric DEFAULT 500000)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); b oyun.sirketler; cid bigint; lid bigint;
begin
 if u is null then raise exception 'Giriş gerekli'; end if;
 select * into b from oyun.sirketler where id=p_banka and sektor='banka' and aktif;
 if b.id is null or not (coalesce(b.yonetici=u,false) or exists(select 1 from oyun.sirket_ortaklari x where x.sirket_id=b.id and x.user_id=u and x.pay>=50)) then
 raise exception 'Bu bankanın yönetim yetkisi sende değil'; end if;
 if p_pos is null or p_kart is null or p_kredi is null then
 raise exception 'POS, kredi kartı ve kredi için manuel veya otomatik karar seçiniz.'; end if;
 if p_min_not is null or p_min_not not between 650 and 1900 then
 raise exception 'Asgari kredi notu 650 ile 1.900 arasında olmalı. Girdiğiniz: %',coalesce(p_min_not::text,'boş'); end if;
 if p_kart_max is null or p_kart_max not between 1000 and 50000000 then
 raise exception 'Otomatik azami kart limiti 1.000–50.000.000 TL arasında olmalı. Girdiğiniz: %',coalesce(p_kart_max::text,'boş'); end if;
 if p_kredi_max is null or p_kredi_max not between 1000 and 50000000 then
 raise exception 'Otomatik azami kredi 1.000–50.000.000 TL arasında olmalı. Girdiğiniz: %',coalesce(p_kredi_max::text,'boş'); end if;
 insert into oyun.banka_yonetim_ayar(banka_id,kart_otomatik,kredi_otomatik,asgari_not,kart_azami,kredi_azami)
 values(p_banka,p_kart,p_kredi,p_min_not,p_kart_max,p_kredi_max)
 on conflict(banka_id) do update set kart_otomatik=excluded.kart_otomatik,
 kredi_otomatik=excluded.kredi_otomatik,asgari_not=excluded.asgari_not,
 kart_azami=excluded.kart_azami,kredi_azami=excluded.kredi_azami,guncelleme=now();
 perform public.pos_banka_otomatik(p_banka,p_pos);
 if p_kart then
  for cid in select id from oyun.kart_basvurular
   where banka_id=p_banka and durum='bekliyor' and izin ? 'kredi_notu' order by id loop
    begin
     perform oyun.banka_otokart_isle(cid);
    exception when others then null;
    end;
  end loop;
 end if;
 if p_kredi then
  for lid in select id from oyun.oyb_kredi
   where banka_id=p_banka and durum='basvuru' order by id loop
    begin
     perform oyun.banka_otokredi_isle(lid);
    exception when others then null;
    end;
  end loop;
 end if;
 return jsonb_build_object('ok',true);
end $function$
;

CREATE OR REPLACE FUNCTION public.cek_iptal_islem(p_cek bigint, p_eylem text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); c oyun.cekler; r oyun.cek_iptal_talepleri;
 v_borclu boolean;v_hamil boolean;v_veren_onay boolean;v_hamil_onay boolean;v_an timestamptz:=oyun.simdi(); v_son text;
begin
 if u is null then raise exception 'İptal talebi için giriş yapmalısın.';end if;
 if p_eylem not in ('talep','onay','reddet','vazgec') then raise exception 'Tanımsız çek iptal işlemi.';end if;
 select * into c from oyun.cekler where id=p_cek for update;
 if not found then raise exception 'Çek bulunamadı: %',p_cek;end if;
 v_borclu:=(c.borclu_sirket is null and c.duzenleyen=u)
    or (c.borclu_sirket is not null and oyun.sirket_yonetici_mi(c.borclu_sirket,u));
 v_hamil:=(c.hamil_sirket is null and c.hamil=u)
    or (c.hamil_sirket is not null and oyun.sirket_yonetici_mi(c.hamil_sirket,u));
 if not (v_borclu or v_hamil) then raise exception 'Çeki veren veya mevcut hamil olmadığın için iptal onayı veremezsin.';end if;
 if c.durum<>'aktif' then raise exception 'Sadece dolaşımdaki aktif çek iptal edilebilir. Çek durumu: %',c.durum;end if;
 if c.odenen>0 or exists(select 1 from oyun.cek_tahsilat where cek_id=c.id) then
  raise exception 'Çek kısmen/tamamen ödenmiş. Tahsilat yapıldığı için karşılıklı iptal yapılamaz.';end if;
 if exists(select 1 from oyun.cek_takip where cek_id=c.id) then raise exception 'Bu çekte icra takibi var; iptal edilmez.';end if;
 select * into r from oyun.cek_iptal_talepleri where cek_id=c.id for update;
 if r.cek_id is not null and (r.hamil is distinct from c.hamil or r.hamil_sirket is distinct from c.hamil_sirket) then
  update oyun.cek_iptal_talepleri set durum='vazgecildi',veren_onay=false,hamil_onay=false,guncelleme=v_an where cek_id=c.id;
  r.cek_id:=null;
 end if;
 if p_eylem='vazgec' then
  if r.cek_id is null or r.durum<>'bekliyor' or r.talep_eden<>u then
   raise exception 'Geri alabileceğin, kendi gönderdiğin bekleyen iptal talebi yok.';end if;
  update oyun.cek_iptal_talepleri set durum='vazgecildi',guncelleme=v_an where cek_id=c.id;
  return jsonb_build_object('durum','vazgecildi','cek_id',c.id);
 end if;
 if p_eylem='reddet' then
  if r.cek_id is null or r.durum<>'bekliyor' then raise exception 'Reddedilecek bekleyen iptal talebi yok.';end if;
  if (v_borclu and r.veren_onay) or (v_hamil and r.hamil_onay) then
   raise exception 'Bu taraf zaten onayladı; talebi sen başlattıysan Geri Al seçeneğini kullan.';end if;
  update oyun.cek_iptal_talepleri set durum='reddedildi',guncelleme=v_an where cek_id=c.id;
  insert into oyun.bildirimler(user_id,zaman,metin)
   select distinct uid,v_an,'❌ Çek #'||c.id||' iptal isteği reddedildi.'
   from (values (c.duzenleyen),(c.hamil)) q(uid) where uid is not null and uid<>u;
  return jsonb_build_object('durum','reddedildi','cek_id',c.id);
 end if;
 if p_eylem='onay' and (r.cek_id is null or r.durum<>'bekliyor') then
  raise exception 'Karşı tarafın onaylayacağı bekleyen bir talep yok.';end if;
 if p_eylem='talep' and (r.cek_id is null or r.durum<>'bekliyor') then
  v_veren_onay:=v_borclu;
  v_hamil_onay:=v_hamil and not v_borclu;
  insert into oyun.cek_iptal_talepleri(cek_id,talep_eden,hamil,hamil_sirket,veren_onay,hamil_onay,durum,olusturma,guncelleme)
   values(c.id,u,c.hamil,c.hamil_sirket,v_veren_onay,v_hamil_onay,'bekliyor',v_an,v_an)
   on conflict(cek_id) do update set talep_eden=excluded.talep_eden,hamil=excluded.hamil,hamil_sirket=excluded.hamil_sirket,
    veren_onay=excluded.veren_onay,hamil_onay=excluded.hamil_onay,durum='bekliyor',olusturma=v_an,guncelleme=v_an;
 else
  if (v_borclu and r.veren_onay and not (v_hamil and not r.hamil_onay))
   or (v_hamil and r.hamil_onay and not (v_borclu and not r.veren_onay)) then
   raise exception 'Senin tarafın zaten onayladı; diğer tarafın onayını bekle.';end if;
  update oyun.cek_iptal_talepleri set
   veren_onay=(veren_onay or (v_borclu and not (v_hamil and not hamil_onay))),
   hamil_onay=(hamil_onay or (v_hamil and not (v_borclu and not veren_onay))),
   guncelleme=v_an where cek_id=c.id;
 end if;
 select * into r from oyun.cek_iptal_talepleri where cek_id=c.id;
 if r.veren_onay and r.hamil_onay then
   update oyun.cekler set durum='iptal' where id=c.id and durum='aktif' and odenen=0;
   if not found then raise exception 'Çek durumu değişti, iptal edilemedi. Tekrar deneyin.';end if;
   update oyun.cek_iptal_talepleri set durum='onaylandi',guncelleme=v_an where cek_id=c.id;
   v_son:='onaylandi';
 else v_son:='bekliyor';end if;
 insert into oyun.bildirimler(user_id,zaman,metin)
  select distinct uid,v_an,case when v_son='onaylandi'
    then '✅ Çek #'||c.id||' iki tarafın onayıyla iptal edildi ve geçersiz.'
    else '📝 Çek #'||c.id||' iptal talebi var. Çek Merkezi bölümünden onaylayabilir veya reddedebilirsin.' end
  from (select c.duzenleyen as uid union select c.hamil
        union select yonetici from oyun.sirketler where id=c.borclu_sirket
        union select yonetici from oyun.sirketler where id=c.hamil_sirket) people
  where uid is not null and (v_son='onaylandi' or uid<>u);
 return jsonb_build_object('durum',v_son,'cek_id',c.id,'veren_onay',r.veren_onay,'hamil_onay',r.hamil_onay);
end $function$
;

CREATE OR REPLACE FUNCTION public.cek_iptal_panel()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select coalesce(jsonb_agg(z.payload order by z.guncelleme desc),'[]'::jsonb)
 from (
  select jsonb_build_object('cek_id',r.cek_id,'durum',r.durum,
    'veren_onay',r.veren_onay,'hamil_onay',r.hamil_onay,'talep_eden_benim',r.talep_eden=auth.uid(),
    'hamil_degisikligi',(r.hamil is distinct from c.hamil or r.hamil_sirket is distinct from c.hamil_sirket)) as payload,
    r.guncelleme
  from oyun.cek_iptal_talepleri r join oyun.cekler c on c.id=r.cek_id
  where auth.uid() is not null and (
   (c.borclu_sirket is null and c.duzenleyen=auth.uid())
   or (c.borclu_sirket is not null and oyun.sirket_yonetici_mi(c.borclu_sirket,auth.uid()))
   or (c.hamil_sirket is null and c.hamil=auth.uid())
   or (c.hamil_sirket is not null and oyun.sirket_yonetici_mi(c.hamil_sirket,auth.uid()))
  ) order by r.guncelleme desc limit 200
 ) z
$function$
;

CREATE OR REPLACE FUNCTION public.cek_islem(p_eylem text, p_id bigint DEFAULT NULL::bigint, p_veri jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); v_an timestamptz:=oyun.simdi(); v_bugun date:=(oyun.simdi() at time zone 'Europe/Istanbul')::date;
h oyun.cek_hesaplari; c oyun.cekler; v_sirket bigint; v_alici uuid; v_alici_sirket bigint;
v_tutar numeric; v_tarih date; v_odenen numeric; v_mevcut numeric; v_limit int;
begin
 if u is null then raise exception 'Önce giriş yap.';end if;
 if p_eylem='defter' then
   v_sirket:=nullif(p_veri->>'sirket','')::bigint;
   if v_sirket is not null and not exists(select 1 from oyun.sirketler s where s.id=v_sirket and s.aktif and oyun.sirket_yonetici_mi(s.id,u))
    then raise exception 'Şirket çeki düzenleme yetkin yok.'; end if;
   if exists(select 1 from oyun.cekler c0 where (c0.duzenleyen=u or (v_sirket is not null and c0.borclu_sirket=v_sirket)) and c0.durum='karsiliksiz')
    then raise exception 'Açık karşılıksız çek nedeniyle yeni çek defteri alınamaz.';end if;
   if v_sirket is null and not exists(select 1 from oyun.banka_musteri where user_id=u)
    then raise exception 'Önce Oyun Bankası vadesiz hesabı aç.';end if;
   perform pg_advisory_xact_lock(101922,pg_catalog.hashtext(u::text||':'||coalesce(v_sirket::text,'kisisel')));
   select * into h from oyun.cek_hesaplari where sahip=u and sirket_id is not distinct from v_sirket for update;
   if h.id is null then
      insert into oyun.cek_hesaplari(sahip,sirket_id,yaprak) values(u,v_sirket,10) returning * into h;
   elsif h.yaprak>2 then
      raise exception 'Yeni defter için mevcut yaprakların en fazla 2 adet kalması gerekir.';
   else update oyun.cek_hesaplari set yaprak=yaprak+10 where id=h.id returning * into h;end if;
   return jsonb_build_object('id',h.id,'yaprak',h.yaprak);
 end if;
 if p_eylem='duzenle' then
   select * into h from oyun.cek_hesaplari where id=nullif(p_veri->>'hesap','')::bigint for update;
   if h.id is null or h.sahip<>u or (h.sirket_id is not null and not oyun.sirket_yonetici_mi(h.sirket_id,u)) then raise exception 'Çek hesabı bulunamadı veya yetkin yok.';end if;
   if h.yaprak<=0 then raise exception 'Çek yaprağın kalmadı.';end if;
   if exists(select 1 from oyun.cekler where (duzenleyen=u or (h.sirket_id is not null and borclu_sirket=h.sirket_id)) and durum='karsiliksiz') then raise exception 'Karşılıksız çek kapatılmadan yenisi yazılamaz.';end if;
   v_tutar:=nullif(p_veri->>'tutar','')::numeric;
   v_tarih:=nullif(p_veri->>'tarih','')::date;
   if v_tutar is null or v_tutar<100 or v_tutar>1000000000 or v_tutar<>round(v_tutar,2) then raise exception '100–1 milyar TL arasında geçerli bir tutar gir.';end if;
   if v_tarih is null or v_tarih<v_bugun or v_tarih>v_bugun+365 then raise exception 'Çek tarihi bugün ile bir yıl sonrası arasında olmalı.';end if;
   v_alici_sirket:=nullif(p_veri->>'alici_sirket','')::bigint;
   if v_alici_sirket is null then
      select id into v_alici from oyun.profiller where lower(kad)=lower(trim(p_veri->>'alici')) limit 1;
      if v_alici is null then raise exception 'Alıcı kullanıcı adı bulunamadı.';end if;
      if v_alici=u and h.sirket_id is null then raise exception 'Kendi kendine kişisel çek kesemezsin.';end if;
   elsif not exists(select 1 from oyun.sirketler where id=v_alici_sirket and aktif) then raise exception 'Lehtar şirket bulunamadı.';end if;
   if h.sirket_id is not null and h.sirket_id=v_alici_sirket then raise exception 'Şirket kendisine çek kesemez.';end if;
   update oyun.cek_hesaplari set yaprak=yaprak-1 where id=h.id;
   insert into oyun.cekler(hesap_id,duzenleyen,borclu_sirket,ilk_lehtar,ilk_lehtar_sirket,hamil,hamil_sirket,tutar,tarih,aciklama,keside_at)
    values(h.id,u,h.sirket_id,v_alici,v_alici_sirket,v_alici,v_alici_sirket,v_tutar,v_tarih,left(coalesce(p_veri->>'aciklama',''),180),v_an)
    returning * into c;
   if v_alici is not null then
     insert into oyun.bildirimler(user_id,zaman,metin) values(v_alici,v_an,'📄 '||oyun.kad(u)||' tarafından '||c.tutar||' TL tutarında çek #'||c.id||' verildi.');
   end if;
   return jsonb_build_object('id',c.id,'durum','aktif');
 end if;
 select * into c from oyun.cekler where id=p_id for update;
 if c.id is null then raise exception 'Çek bulunamadı.';end if;
 if p_eylem='ciro' then
   if c.durum<>'aktif' or c.odenen>0 then raise exception 'Kısmen ödenmiş veya karşılıksız çek ciro edilemez.';end if;
   if not oyun.cek_yetkili(c.hamil,c.hamil_sirket) then raise exception 'Çek hamili değilsin.';end if;
   v_alici_sirket:=nullif(p_veri->>'alici_sirket','')::bigint;
   if v_alici_sirket is null then
    select id into v_alici from oyun.profiller where lower(kad)=lower(trim(p_veri->>'alici')) limit 1;
    if v_alici is null then raise exception 'Devralacak oyuncu bulunamadı.';end if;
   elsif not exists(select 1 from oyun.sirketler where id=v_alici_sirket and aktif) then raise exception 'Devralacak şirket bulunamadı.';end if;
   if (v_alici is not null and v_alici=c.hamil) or (v_alici_sirket is not null and v_alici_sirket=c.hamil_sirket) then raise exception 'Çeki aynı hamile devredemezsin.';end if;
   insert into oyun.cek_cirolar(cek_id,eski_hamil,eski_sirket,yeni_hamil,yeni_sirket,tarih)
    values(c.id,c.hamil,c.hamil_sirket,v_alici,v_alici_sirket,v_an);
   update oyun.cekler set hamil=v_alici,hamil_sirket=v_alici_sirket where id=c.id;
   if v_alici is not null then insert into oyun.bildirimler(user_id,zaman,metin) values(v_alici,v_an,'📄 '||c.tutar||' TL çek #'||c.id||' sana ciro edildi.');end if;
   return jsonb_build_object('tamam',true,'id',c.id);
 elsif p_eylem='iade' then
   return public.cek_iptal_islem(c.id,'talep');
 elsif p_eylem='erken' then
   if not ((c.borclu_sirket is null and c.duzenleyen=u) or (c.borclu_sirket is not null and oyun.sirket_yonetici_mi(c.borclu_sirket,u))) then raise exception 'Yalnızca çeki düzenleyen ödeme yapabilir.';end if;
   v_tutar:=coalesce(nullif(p_veri->>'tutar','')::numeric,c.tutar-c.odenen);
   if v_tutar<=0 or v_tutar<>round(v_tutar,2) or v_tutar>c.tutar-c.odenen then raise exception 'Ödeme tutarı geçersiz.';end if;
   v_odenen:=oyun.cek_odeme_aktar(c.id,v_tutar,'erken');
   if v_odenen<v_tutar then raise exception 'Vadesinden önce gönüllü ödemede hesapta tutarın tamamı bulunmalı.';end if;
   return jsonb_build_object('odenen',v_odenen);
 elsif p_eylem='ibraz' then
   if not oyun.cek_yetkili(c.hamil,c.hamil_sirket) then raise exception 'Yalnızca mevcut hamil bankaya ibraz edebilir.';end if;
   if c.durum in ('iade','odendi','iptal') then raise exception 'Bu çek kapanmış veya iptal edilmiş.';end if;
   if v_bugun<c.tarih then raise exception '2028 sonuna kadar ileri tarihli çek erken ibraz edilemez; düzenleyen gönüllü ödeyebilir.';end if;
   v_odenen:=oyun.cek_odeme_aktar(c.id,c.tutar-c.odenen,'ibraz');
   update oyun.cekler set ibraz_at=v_an where id=c.id;
   if v_odenen<c.tutar-c.odenen then
     update oyun.cekler set durum='karsiliksiz',karsiliksiz_at=coalesce(karsiliksiz_at,v_an) where id=c.id;
     update oyun.banka_musteri set kredi_notu=greatest(300,kredi_notu-160)
      where user_id=c.duzenleyen and c.borclu_sirket is null;
     insert into oyun.bildirimler(user_id,zaman,metin)
      values(c.duzenleyen,v_an,'⚠️ Çek #'||c.id||' kısmen veya tamamen karşılıksız kaldı. Kalan borç, tahsil ve icra riski doğurdu.');
   end if;
   return jsonb_build_object('odenen',v_odenen,'kalan',(select tutar-odenen from oyun.cekler where id=c.id),'durum',(select durum from oyun.cekler where id=c.id));
 elsif p_eylem='takip' then
   if not oyun.cek_yetkili(c.hamil,c.hamil_sirket) then raise exception 'Yalnızca hamil takip talep edebilir.';end if;
   if c.durum<>'karsiliksiz' then raise exception 'Yalnızca ibrazda karşılıksız kalan çek takibe verilebilir.';end if;
   if c.ibraz_at is null then raise exception 'Önce bankaya ibraz et.';end if;
   insert into oyun.cek_takip(cek_id,basvuran,acilis) values(c.id,u,v_an)
   on conflict(cek_id) do nothing;
   update oyun.cekler set takip_at=coalesce(takip_at,v_an) where id=c.id;
   insert into oyun.bildirimler(user_id,zaman,metin) values(c.duzenleyen,v_an,'⚖️ Çek #'||c.id||' için icra takip talebi kaydedildi.');
   return jsonb_build_object('tamam',true,'takip','baslatildi');
 end if;
 raise exception 'Tanımsız çek işlemi.';
end $function$
;

CREATE OR REPLACE FUNCTION oyun.cek_odeme_aktar(p_id bigint, p_miktar numeric, p_kaynak text)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c oyun.cekler; v_bakiye numeric; v_odenecek numeric; v_an timestamptz:=oyun.simdi(); v_kalan numeric;
begin
 select * into c from oyun.cekler where id=p_id for update;
 if c.id is null or c.durum in ('iade','odendi','iptal') then raise exception 'Aktif çek bulunamadı.';end if;
 if p_kaynak not in ('erken','ibraz','kapatma') then raise exception 'Geçersiz ödeme türü.'; end if;
 if c.borclu_sirket is null then
  select vadesiz into v_bakiye from oyun.banka_musteri where user_id=c.duzenleyen for update;
 else
  select kasa into v_bakiye from oyun.sirketler where id=c.borclu_sirket and aktif for update;
 end if;
 v_kalan:=c.tutar-c.odenen;
 v_odenecek:=least(v_kalan,greatest(0,coalesce(v_bakiye,0)),p_miktar);
 if v_odenecek>0 then
  if c.borclu_sirket is null then
   update oyun.banka_musteri set vadesiz=vadesiz-v_odenecek where user_id=c.duzenleyen and vadesiz>=v_odenecek;
   if not found then raise exception 'Banka bakiyesi eşzamanlı değişti; tekrar dene.';end if;
   perform oyun.banka_kayit(c.duzenleyen,'vadesiz',-v_odenecek,'Çek # '||c.id||' ödendi',v_an);
  else
   update oyun.sirketler set kasa=kasa-v_odenecek where id=c.borclu_sirket and kasa>=v_odenecek;
   if not found then raise exception 'Şirket kasası eşzamanlı değişti; tekrar dene.';end if;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
    values(c.borclu_sirket,v_an,-v_odenecek,'Çek # '||c.id||' ödemesi');
  end if;
  if c.hamil_sirket is null then
   insert into oyun.banka_musteri(user_id,son_faiz) values(c.hamil,v_an) on conflict(user_id) do nothing;
   update oyun.banka_musteri set vadesiz=vadesiz+v_odenecek where user_id=c.hamil;
   perform oyun.banka_kayit(c.hamil,'vadesiz',v_odenecek,'Çek # '||c.id||' tahsil edildi',v_an);
  else
   update oyun.sirketler set kasa=kasa+v_odenecek where id=c.hamil_sirket;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
    values(c.hamil_sirket,v_an,v_odenecek,'Çek # '||c.id||' tahsilatı');
  end if;
  insert into oyun.cek_tahsilat(cek_id,tutar,zaman,kaynak) values(c.id,v_odenecek,v_an,p_kaynak);
  update oyun.cekler set odenen=odenen+v_odenecek,
   durum=case when odenen+v_odenecek>=tutar then 'odendi' else durum end
   where id=c.id;
  if v_odenecek>=v_kalan then update oyun.cek_takip set durum='odendi' where cek_id=c.id and durum='baslatildi';end if;
 end if;
 return v_odenecek;
end $function$
;

revoke all on function public.cek_iptal_islem(bigint,text) from public,anon;
revoke all on function public.cek_iptal_panel() from public,anon;
grant execute on function public.cek_iptal_islem(bigint,text) to authenticated;
grant execute on function public.cek_iptal_panel() to authenticated;
