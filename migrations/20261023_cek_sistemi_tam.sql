-- 23 Ekim 2026 • Seçim Online canlı çek sistemi (kaydedilmiş kaynak)
-- Bu dosya canlı Supabase'de kurulmuş tabloların ve RPC fonksiyonlarının tekrar üretilebilir kopyasıdır.
-- Ön gereksinimler: mevcut oyun.profiller, oyun.sirketler, oyun.banka_musteri vb. taban tablolar.
create table if not exists oyun.cek_hesaplari(
 id bigint generated always as identity primary key,
 sahip uuid not null references oyun.profiller(id),
 sirket_id bigint references oyun.sirketler(id),
 yaprak integer not null default 10 check(yaprak between 0 and 50),
 olusturma timestamptz not null default now(),
 unique nulls not distinct(sahip,sirket_id)
);
create table if not exists oyun.cekler(
 id bigint generated always as identity primary key,
 hesap_id bigint not null references oyun.cek_hesaplari(id),
 duzenleyen uuid not null references oyun.profiller(id),
 borclu_sirket bigint references oyun.sirketler(id),
 ilk_lehtar uuid references oyun.profiller(id),
 ilk_lehtar_sirket bigint references oyun.sirketler(id),
 hamil uuid references oyun.profiller(id),
 hamil_sirket bigint references oyun.sirketler(id),
 tutar numeric(18,2) not null check(tutar between 100 and 1000000000),
 odenen numeric(18,2) not null default 0 check(odenen>=0 and odenen<=tutar),
 tarih date not null,
 keside_at timestamptz not null default now(),
 durum text not null default 'aktif' check(durum in ('aktif','karsiliksiz','odendi','iade')),
 aciklama text not null default '',
 ibraz_at timestamptz,karsiliksiz_at timestamptz,takip_at timestamptz,
 check((hamil is not null)::int+(hamil_sirket is not null)::int=1),
 check((ilk_lehtar is not null)::int+(ilk_lehtar_sirket is not null)::int=1)
);
create index if not exists ix_cek_hamil on oyun.cekler(hamil,durum,tarih);
create index if not exists ix_cek_hamil_sirket on oyun.cekler(hamil_sirket,durum,tarih);
create index if not exists ix_cek_duzenleyen on oyun.cekler(duzenleyen,durum,tarih);
create table if not exists oyun.cek_cirolar(
 id bigint generated always as identity primary key,
 cek_id bigint not null references oyun.cekler(id),
 eski_hamil uuid,eski_sirket bigint,yeni_hamil uuid,yeni_sirket bigint,
 tarih timestamptz not null default now(),islem text not null default 'ciro'
);
create table if not exists oyun.cek_tahsilat(
 id bigint generated always as identity primary key,
 cek_id bigint not null references oyun.cekler(id),
 tutar numeric(18,2) not null check(tutar>0),
 zaman timestamptz not null default now(),
 kaynak text not null check(kaynak in('erken','ibraz','kapatma'))
);
create table if not exists oyun.cek_takip(
 id bigint generated always as identity primary key,
 cek_id bigint not null unique references oyun.cekler(id),
 basvuran uuid not null references oyun.profiller(id),
 acilis timestamptz not null default now(),
 durum text not null default 'baslatildi' check(durum in('baslatildi','odendi','kapatildi')),
 tazminat_kalan numeric(18,2) not null default 0 check(tazminat_kalan>=0)
);
alter table oyun.cek_takip add column if not exists tazminat_kalan numeric(18,2) not null default 0;
create table if not exists oyun.cek_iskonto_teklif(
 id bigint generated always as identity primary key,
 cek_id bigint not null references oyun.cekler(id),
 banka_id bigint not null references oyun.sirketler(id),
 basvuran uuid not null references oyun.profiller(id),
 teklif_tutar numeric(18,2) not null check(teklif_tutar>0),
 oran numeric(8,5) not null check(oran>=0 and oran<1),
 durum text not null default 'bekliyor' check(durum in('bekliyor','kabul','red','iptal','gecersiz')),
 acilis timestamptz not null default now(),karar_at timestamptz
);
create unique index if not exists ix_cek_iskonto_bekleyen on oyun.cek_iskonto_teklif(cek_id,banka_id) where durum='bekliyor';
create table if not exists oyun.cek_toptan_teklif(
 id bigint generated always as identity primary key,
 magaza_id bigint not null references oyun.sirketler(id),
 uretici_id bigint not null references oyun.sirketler(id),
 alici_yetkili uuid not null references oyun.profiller(id),
 cek_hesap_id bigint not null references oyun.cek_hesaplari(id),
 urun text not null,
 adet integer not null check(adet between 1 and 500),
 birim_fiyat numeric(18,2) not null check(birim_fiyat>0),
 toplam numeric(18,2) not null check(toplam>0),
 cek_tarih date not null,
 durum text not null default 'bekliyor' check(durum in('bekliyor','kabul','red','iptal','gecersiz')),
 cek_id bigint unique references oyun.cekler(id),
 acilis timestamptz not null default now(),
 karar_at timestamptz,
 check(magaza_id<>uretici_id)
);
create index if not exists ix_cek_toptan_teklif_durum on oyun.cek_toptan_teklif(durum,magaza_id,uretici_id);
alter table oyun.cek_hesaplari enable row level security;
alter table oyun.cekler enable row level security;
alter table oyun.cek_cirolar enable row level security;
alter table oyun.cek_tahsilat enable row level security;
alter table oyun.cek_takip enable row level security;
alter table oyun.cek_iskonto_teklif enable row level security;
alter table oyun.cek_toptan_teklif enable row level security;
revoke all on oyun.cek_hesaplari,oyun.cekler,oyun.cek_cirolar,oyun.cek_tahsilat,
 oyun.cek_takip,oyun.cek_iskonto_teklif,oyun.cek_toptan_teklif from public,anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.cek_yetkili(p_user uuid, p_sirket bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select case when p_sirket is null then p_user=auth.uid()
 else p_user is null and oyun.sirket_yonetici_mi(p_sirket,auth.uid()) end
$function$;

CREATE OR REPLACE FUNCTION oyun.cek_takip_tazminat()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare c oyun.cekler;
begin
 if tg_op='INSERT' then
  select * into c from oyun.cekler where id=new.cek_id;
  new.tazminat_kalan:=round(greatest(0,c.tutar-c.odenen)*0.10,2);
 elsif new.durum='odendi' and new.tazminat_kalan>0 then
  new.durum:='baslatildi';
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION oyun.cek_odeme_aktar(p_id bigint, p_miktar numeric, p_kaynak text)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c oyun.cekler; v_bakiye numeric; v_odenecek numeric; v_an timestamptz:=oyun.simdi(); v_kalan numeric;
begin
 select * into c from oyun.cekler where id=p_id for update;
 if c.id is null or c.durum='iade' or c.durum='odendi' then raise exception 'Aktif çek bulunamadı.';end if;
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
end $function$;

CREATE OR REPLACE FUNCTION public.cek_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); t date:=(oyun.simdi() at time zone 'Europe/Istanbul')::date;
begin
 if u is null then raise exception 'Önce giriş yap.';end if;
 return jsonb_build_object(
  'bugun',t,
  'vadesiz',coalesce((select vadesiz from oyun.banka_musteri where user_id=u),0),
  'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa))
    from oyun.sirketler s where s.aktif and oyun.sirket_yonetici_mi(s.id,u)),'[]'::jsonb),
  'hesaplar',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'sirket',h.sirket_id,'yaprak',h.yaprak))
    from oyun.cek_hesaplari h where h.sahip=u and
      (h.sirket_id is null or oyun.sirket_yonetici_mi(h.sirket_id,u))),'[]'::jsonb),
  'bende',coalesce((select jsonb_agg(to_jsonb(z))
   from (select c.id,c.tutar,c.odenen,c.tarih,c.durum,c.aciklama,c.borclu_sirket,
      c.hamil_sirket,c.hamil,c.karsiliksiz_at,c.ibraz_at,oyun.kad(c.duzenleyen) as duzenleyen_ad,
      coalesce((select s.ad from oyun.sirketler s where s.id=c.borclu_sirket),'') as borclu_ad,
      (select exists(select 1 from oyun.cek_takip k where k.cek_id=c.id)) as takip,
      case when c.hamil_sirket is not null then (select ad from oyun.sirketler where id=c.hamil_sirket) else oyun.kad(c.hamil) end as hamil_ad
    from oyun.cekler c where c.hamil=u or (c.hamil_sirket is not null and oyun.sirket_yonetici_mi(c.hamil_sirket,u))
    order by c.id desc limit 100) z),'[]'::jsonb),
  'verdiklerim',coalesce((select jsonb_agg(to_jsonb(z))
   from (select c.id,c.tutar,c.odenen,c.tarih,c.durum,c.aciklama,c.borclu_sirket,
      c.hamil,c.hamil_sirket,c.karsiliksiz_at,
      case when c.hamil_sirket is not null then (select ad from oyun.sirketler where id=c.hamil_sirket) else oyun.kad(c.hamil) end as hamil_ad
    from oyun.cekler c where c.duzenleyen=u or (c.borclu_sirket is not null and oyun.sirket_yonetici_mi(c.borclu_sirket,u))
    order by c.id desc limit 100) z),'[]'::jsonb)
 );
end $function$;

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
   if c.durum<>'aktif' or c.odenen>0 then raise exception 'Ödeme görmüş çek iade edilemez.';end if;
   if not oyun.cek_yetkili(c.hamil,c.hamil_sirket) then raise exception 'Yalnızca hamil çeki iade edebilir.';end if;
   update oyun.cekler set durum='iade' where id=c.id;
   return jsonb_build_object('tamam',true);
 elsif p_eylem='erken' then
   if not ((c.borclu_sirket is null and c.duzenleyen=u) or (c.borclu_sirket is not null and oyun.sirket_yonetici_mi(c.borclu_sirket,u))) then raise exception 'Yalnızca çeki düzenleyen ödeme yapabilir.';end if;
   v_tutar:=coalesce(nullif(p_veri->>'tutar','')::numeric,c.tutar-c.odenen);
   if v_tutar<=0 or v_tutar<>round(v_tutar,2) or v_tutar>c.tutar-c.odenen then raise exception 'Ödeme tutarı geçersiz.';end if;
   v_odenen:=oyun.cek_odeme_aktar(c.id,v_tutar,'erken');
   if v_odenen<v_tutar then raise exception 'Vadesinden önce gönüllü ödemede hesapta tutarın tamamı bulunmalı.';end if;
   return jsonb_build_object('odenen',v_odenen);
 elsif p_eylem='ibraz' then
   if not oyun.cek_yetkili(c.hamil,c.hamil_sirket) then raise exception 'Yalnızca mevcut hamil bankaya ibraz edebilir.';end if;
   if c.durum='iade' or c.durum='odendi' then raise exception 'Çek zaten kapanmış.';end if;
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
end $function$;

CREATE OR REPLACE FUNCTION public.cek_hedef_ara(p_ara text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare q text:=trim(coalesce(p_ara,'')); u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli.';end if;
 if length(q)<2 or length(q)>60 then raise exception 'En az 2, en fazla 60 karakter yaz.';end if;
 return jsonb_build_object(
  'oyuncular',coalesce((select jsonb_agg(jsonb_build_object('ad',v.kad,'id',v.id))
   from (select id,kad from oyun.profiller where kad ilike '%'||replace(replace(q,'%','\%'),'_','\_')||'%' order by kad limit 12)v),'[]'::jsonb),
  'sirketler',coalesce((select jsonb_agg(jsonb_build_object('ad',v.ad,'id',v.id))
   from (select id,ad from oyun.sirketler where aktif and ad ilike '%'||replace(replace(q,'%','\%'),'_','\_')||'%' order by ad limit 12)v),'[]'::jsonb)
 );
end $function$;

CREATE OR REPLACE FUNCTION public.cek_ek_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli.';end if;
 return jsonb_build_object(
 'bankalar',coalesce((select jsonb_agg(to_jsonb(z)) from
   (select b.id,b.ad,greatest(0,b.kasa-greatest(b.sermaye*.10,50000)-
      coalesce((select sum(round(m.anapara*(1+m.faiz/100),2))
       from oyun.banka_mevduat m where m.banka_id=b.id and not m.kapandi),0)) as kullanilabilir
    from oyun.sirketler b where b.aktif and b.sektor='banka') z),'[]'::jsonb),
 'tazminatlar',coalesce((select jsonb_agg(jsonb_build_object('cek_id',k.cek_id,'kalan',k.tazminat_kalan))
    from oyun.cek_takip k join oyun.cekler c on c.id=k.cek_id
    where k.tazminat_kalan>0 and (c.duzenleyen=u or c.hamil=u or
     (c.borclu_sirket is not null and oyun.sirket_yonetici_mi(c.borclu_sirket,u)) or
     (c.hamil_sirket is not null and oyun.sirket_yonetici_mi(c.hamil_sirket,u)))),'[]'::jsonb),
 'basvurular',coalesce((select jsonb_agg(to_jsonb(z) order by z.id desc) from
    (select b.id,b.cek_id,s.ad as banka,b.banka_id,b.teklif_tutar as tutar,b.oran,
     b.durum,b.basvuran=u as benim,oyun.sirket_yonetici_mi(b.banka_id,u) as banka_yonetici,
     oyun.kad(c.duzenleyen) as kesideci,c.tutar as cek_tutari,c.tarih
     from oyun.cek_iskonto_teklif b join oyun.cekler c on c.id=b.cek_id
     join oyun.sirketler s on s.id=b.banka_id
     where b.durum='bekliyor' and (b.basvuran=u or oyun.sirket_yonetici_mi(b.banka_id,u))) z),'[]'::jsonb)
 );
end $function$;

CREATE OR REPLACE FUNCTION public.cek_tazminat_ode(p_cek bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c oyun.cekler; tak oyun.cek_takip; u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.';end if;
 select * into c from oyun.cekler where id=p_cek for update;
 if c.id is null or not((c.borclu_sirket is null and c.duzenleyen=u) or (c.borclu_sirket is not null and oyun.sirket_yonetici_mi(c.borclu_sirket,u)))
  then raise exception 'Çeki düzenleyen veya şirket yöneticisi olmalısın.';end if;
 select * into tak from oyun.cek_takip where cek_id=c.id for update;
 if tak.id is null then raise exception 'Ödenmemiş çek için tazminat talebi yok.';end if;
 if p_tutar is null or p_tutar<=0 or p_tutar>tak.tazminat_kalan or p_tutar<>round(p_tutar,2) then
  raise exception 'Tazminat ödeme tutarı geçersiz.';end if;
 if c.borclu_sirket is null then
  update oyun.banka_musteri set vadesiz=vadesiz-p_tutar where user_id=c.duzenleyen and vadesiz>=p_tutar;
  if not found then raise exception 'Vadesiz banka bakiyesi yetersiz.';end if;
  perform oyun.banka_kayit(c.duzenleyen,'vadesiz',-p_tutar,'Çek # '||c.id||' %10 tazminat ödemesi',t);
 else
  update oyun.sirketler set kasa=kasa-p_tutar where id=c.borclu_sirket and kasa>=p_tutar;
  if not found then raise exception 'Şirket kasası yetersiz.';end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama) values(c.borclu_sirket,t,-p_tutar,'Çek # '||c.id||' tazminat ödemesi');
 end if;
 if c.hamil_sirket is null then
  insert into oyun.banka_musteri(user_id,son_faiz) values(c.hamil,t) on conflict(user_id) do nothing;
  update oyun.banka_musteri set vadesiz=vadesiz+p_tutar where user_id=c.hamil;
  perform oyun.banka_kayit(c.hamil,'vadesiz',p_tutar,'Çek # '||c.id||' tazminat tahsilatı',t);
 else
  update oyun.sirketler set kasa=kasa+p_tutar where id=c.hamil_sirket;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama) values(c.hamil_sirket,t,p_tutar,'Çek # '||c.id||' tazminat tahsilatı');
 end if;
 update oyun.cek_takip set tazminat_kalan=tazminat_kalan-p_tutar,
  durum=case when tazminat_kalan-p_tutar<=0 and c.tutar<=c.odenen then 'odendi' else 'baslatildi' end
  where id=tak.id;
 return jsonb_build_object('odenen',p_tutar,'kalan',tak.tazminat_kalan-p_tutar);
end $function$;

CREATE OR REPLACE FUNCTION public.cek_iskonto_islem(p_eylem text, p_id bigint, p_banka bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); c oyun.cekler; o oyun.cek_iskonto_teklif; b oyun.sirketler;
 t timestamptz:=oyun.simdi(); bugun date:=(oyun.simdi() at time zone 'Europe/Istanbul')::date;
 oran numeric; fiyat numeric; mevduat numeric; gerekli numeric;
begin
 if u is null then raise exception 'Giriş yapmalısın.';end if;
 if p_eylem='basvur' then
  select * into c from oyun.cekler where id=p_id for update;
  if c.id is null or c.durum<>'aktif' or c.odenen<>0 or c.tarih<=bugun then
    raise exception 'İskonto için henüz ödeme tarihi gelmemiş aktif ve ödenmemiş çek gerekli.';end if;
  if not oyun.cek_yetkili(c.hamil,c.hamil_sirket) then raise exception 'Çek sahibi değilsin.';end if;
  select * into b from oyun.sirketler where id=p_banka and aktif and sektor='banka';
  if b.id is null or b.id=c.hamil_sirket or b.id=c.borclu_sirket then raise exception 'Geçerli farklı bir banka seç.';end if;
  oran:=least(.18,.025+(c.tarih-bugun)*.00065);
  fiyat:=round(c.tutar*(1-oran),2);
  insert into oyun.cek_iskonto_teklif(cek_id,banka_id,basvuran,teklif_tutar,oran,acilis)
  values(c.id,b.id,u,fiyat,oran,t) returning * into o;
  insert into oyun.bildirimler(user_id,zaman,metin)
   select distinct n.id,t,'🏦 '||b.ad||' bankana, Çek #'||c.id||' için '||fiyat||' TL iskonto talebi geldi.'
   from (select b.yonetici as id union select so.user_id from oyun.sirket_ortaklari so where so.sirket_id=b.id and so.pay>=50)n
   where n.id is not null;
  return jsonb_build_object('id',o.id,'tutar',fiyat,'oran',oran);
 end if;
 select * into o from oyun.cek_iskonto_teklif where id=p_id for update;
 if o.id is null or o.durum<>'bekliyor' then raise exception 'Açık iskonto teklifi bulunamadı.';end if;
 if p_eylem='iptal' then
  if o.basvuran<>u then raise exception 'Sadece başvuran iptal edebilir.';end if;
  update oyun.cek_iskonto_teklif set durum='iptal',karar_at=t where id=o.id;
  return jsonb_build_object('tamam',true,'durum','iptal');
 end if;
 if p_eylem not in ('kabul','red') or not oyun.sirket_yonetici_mi(o.banka_id,u) then
  raise exception 'Teklifi yalnızca banka yöneticisi karara bağlayabilir.';end if;
 if p_eylem='red' then
  update oyun.cek_iskonto_teklif set durum='red',karar_at=t where id=o.id;
  return jsonb_build_object('tamam',true,'durum','red');
 end if;
 select * into c from oyun.cekler where id=o.cek_id for update;
 if c.id is null or c.durum<>'aktif' or c.odenen<>0 or c.tarih<=bugun or
     not(c.hamil=o.basvuran or (c.hamil_sirket is not null and oyun.sirket_yonetici_mi(c.hamil_sirket,o.basvuran))) then
  update oyun.cek_iskonto_teklif set durum='gecersiz',karar_at=t where id=o.id;
  return jsonb_build_object('tamam',false,'durum','gecersiz');
 end if;
 select * into b from oyun.sirketler where id=o.banka_id and aktif and sektor='banka' for update;
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0) into mevduat
  from oyun.banka_mevduat m where m.banka_id=b.id and not m.kapandi;
 gerekli:=o.teklif_tutar+greatest(b.sermaye*.10,50000)+mevduat;
 if b.id is null or b.kasa<gerekli then raise exception 'Banka rezerv ve mevduat yükümlülükleri sonrası nakit yetersiz.';end if;
 update oyun.sirketler set kasa=kasa-o.teklif_tutar where id=b.id;
 insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
  values(b.id,t,-o.teklif_tutar,'Çek # '||c.id||' iskonto satın alma bedeli');
 if c.hamil_sirket is null then
  insert into oyun.banka_musteri(user_id,son_faiz) values(c.hamil,t) on conflict(user_id) do nothing;
  update oyun.banka_musteri set vadesiz=vadesiz+o.teklif_tutar where user_id=c.hamil;
  perform oyun.banka_kayit(c.hamil,'vadesiz',o.teklif_tutar,'Çek # '||c.id||' iskonto nakdi',t);
 else
  update oyun.sirketler set kasa=kasa+o.teklif_tutar where id=c.hamil_sirket;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
   values(c.hamil_sirket,t,o.teklif_tutar,'Çek # '||c.id||' iskonto bedeli');
 end if;
 insert into oyun.cek_cirolar(cek_id,eski_hamil,eski_sirket,yeni_sirket,tarih,islem)
   values(c.id,c.hamil,c.hamil_sirket,b.id,t,'iskonto');
 update oyun.cekler set hamil=null,hamil_sirket=b.id where id=c.id;
 update oyun.cek_iskonto_teklif set durum='kabul',karar_at=t where id=o.id;
 update oyun.cek_iskonto_teklif set durum='gecersiz',karar_at=t
  where cek_id=c.id and id<>o.id and durum='bekliyor';
 insert into oyun.bildirimler(user_id,zaman,metin)
   values(o.basvuran,t,'✅ Çek # '||c.id||' iskonto edildi; '||o.teklif_tutar||' TL hesaba aktarıldı.');
 return jsonb_build_object('tamam',true,'cek',c.id,'nakit',o.teklif_tutar);
end $function$;

CREATE OR REPLACE FUNCTION public.cek_toptan_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli.';end if;
 return coalesce((select jsonb_agg(to_jsonb(r) order by r.id desc) from (
   select a.id,a.magaza_id,a.uretici_id,a.adet,a.urun,a.toplam,a.birim_fiyat,a.cek_tarih,a.durum,
     m.ad as magaza,pr.ad as uretici,oyun.kad(a.alici_yetkili) as teklif_eden,
     (a.alici_yetkili=u) as teklif_sahibi,
     oyun.sirket_yonetici_mi(a.uretici_id,u) as satici_yetkilisi,
     a.acilis,a.cek_id
   from oyun.cek_toptan_teklif a
   join oyun.sirketler m on m.id=a.magaza_id
   join oyun.sirketler pr on pr.id=a.uretici_id
   where oyun.sirket_yonetici_mi(a.magaza_id,u)
      or oyun.sirket_yonetici_mi(a.uretici_id,u)
   order by a.id desc limit 60) r),'[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION public.cek_toptan_islem(p_eylem text, p_veri jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); d date:=(oyun.simdi() at time zone 'Europe/Istanbul')::date;
  v_id bigint:=nullif(p_veri->>'id','')::bigint;
  v_mag bigint:=nullif(p_veri->>'magaza','')::bigint;
  v_uret bigint:=nullif(p_veri->>'uretici','')::bigint;
  v_hes bigint:=nullif(p_veri->>'hesap','')::bigint;
  v_urun text:=p_veri->>'urun';
  v_adet integer:=coalesce(nullif(p_veri->>'adet','')::integer,0);
  v_tarih date:=nullif(p_veri->>'tarih','')::date;
  x oyun.cek_toptan_teklif; h oyun.cek_hesaplari; stk oyun.eko_urun_stok;
  buyer oyun.sirketler; seller oyun.sirketler; isletme oyun.eko_isletmeler;
  brt numeric; tax numeric; num numeric; entry bigint; checknum bigint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli)
 then raise exception 'Giriş yapmalısın.';end if;
 if p_eylem='teklif' then
  if v_mag is null or v_uret is null or v_mag=v_uret or v_adet not between 1 and 500
    or v_tarih is null or v_tarih<d or v_tarih>d+365
  then raise exception 'Şirket, adet veya çek tarihi geçersiz.';end if;
  select * into h from oyun.cek_hesaplari where id=v_hes;
  if h.id is null or h.sahip<>u or h.sirket_id is distinct from v_mag or h.yaprak<=0
    then raise exception 'Bu mağazaya ait açık çek defterin yok.';end if;
  if not oyun.sirket_yonetici_mi(v_mag,u) then raise exception 'Mağazanın yetkilisi değilsin.';end if;
  if exists(select 1 from oyun.cekler c where c.durum='karsiliksiz'
    and (c.duzenleyen=u or c.borclu_sirket=v_mag)) then
    raise exception 'Açık karşılıksız çek varken çekli sipariş verilemez.';end if;
  perform 1 from oyun.sirketler where id in(v_mag,v_uret) order by id for update;
  select * into buyer from oyun.sirketler where id=v_mag and aktif;
  select * into seller from oyun.sirketler where id=v_uret and aktif;
  select * into isletme from oyun.eko_isletmeler where sirket_id=v_mag;
  if buyer.id is null or seller.id is null or isletme.tur<>'magaza' or
    not exists(select 1 from oyun.eko_isletmeler where sirket_id=v_uret and tur='fabrika')
  then raise exception 'Mağaza veya üretici geçerli değil.';end if;
  select * into stk from oyun.eko_urun_stok where sirket_id=v_uret and urun=v_urun for update;
  if stk.sirket_id is null or stk.adet<v_adet or stk.satis_fiyati<=0
  then raise exception 'Tedarikçinin stok ve satış fiyatı uygun değil.';end if;
  num:=round(stk.satis_fiyati*v_adet);
  if num<=0 or num>1000000000 then raise exception 'İşlem bedeli çek sınırlarını aşıyor.';end if;
  insert into oyun.cek_toptan_teklif(magaza_id,uretici_id,alici_yetkili,cek_hesap_id,
   urun,adet,birim_fiyat,toplam,cek_tarih,acilis)
   values(v_mag,v_uret,u,h.id,v_urun,v_adet,stk.satis_fiyati,num,v_tarih,t)
   returning * into x;
  insert into oyun.bildirimler(user_id,zaman,metin)
    select z.id,t,'📄 '||buyer.ad||' şirketi, '||seller.ad||
     ' şirketine '||num||' TL tutarında çekle toptan mal alımı teklif etti (#'||x.id||').'
    from (select seller.yonetici as id union
      select so.user_id from oyun.sirket_ortaklari so where so.sirket_id=v_uret and so.pay>=50) z
    where z.id is not null;
  return jsonb_build_object('id',x.id,'toplam',num,'durum','bekliyor');
 end if;
 select * into x from oyun.cek_toptan_teklif where id=v_id for update;
 if x.id is null or x.durum<>'bekliyor' then raise exception 'Açık çekli sipariş bulunamadı.';end if;
 if p_eylem='iptal' then
   if x.alici_yetkili<>u and not oyun.sirket_yonetici_mi(x.magaza_id,u)
   then raise exception 'Bu teklifi iptal etmeye yetkin yok.';end if;
   update oyun.cek_toptan_teklif set durum='iptal',karar_at=t where id=x.id;
   return jsonb_build_object('tamam',true,'durum','iptal');
 end if;
 if p_eylem not in ('kabul','red') or not oyun.sirket_yonetici_mi(x.uretici_id,u)
 then raise exception 'Yalnızca satıcı şirketin yöneticisi yanıtlayabilir.';end if;
 if p_eylem='red' then
   update oyun.cek_toptan_teklif set durum='red',karar_at=t where id=x.id;
   insert into oyun.bildirimler(user_id,zaman,metin)
     values(x.alici_yetkili,t,'⚠️ Çekle toptan alım teklifin #'||x.id||' reddedildi.');
   return jsonb_build_object('tamam',true,'durum','red');
 end if;
 if x.acilis<t-interval '48 hours' then
  update oyun.cek_toptan_teklif set durum='gecersiz',karar_at=t where id=x.id;
  return jsonb_build_object('tamam',false,'durum','gecersiz','neden','Teklifin süresi doldu.');
 end if;
 if not oyun.sirket_yonetici_mi(x.magaza_id,x.alici_yetkili)
 then raise exception 'Teklifi veren oyuncu artık mağazanın yöneticisi değil.';end if;
 if x.cek_tarih<d then raise exception 'Çek tarihi geçmiş; alıcı yeni teklif yapmalı.';end if;
 perform 1 from oyun.sirketler where id in(x.magaza_id,x.uretici_id) order by id for update;
 select * into buyer from oyun.sirketler where id=x.magaza_id and aktif;
 select * into seller from oyun.sirketler where id=x.uretici_id and aktif;
 select * into h from oyun.cek_hesaplari where id=x.cek_hesap_id for update;
 if buyer.id is null or seller.id is null or h.id is null or h.yaprak<=0
   or h.sirket_id is distinct from buyer.id or h.sahip<>x.alici_yetkili
 then raise exception 'Alıcı veya satıcı faal değil ya da çek defteri uygun değil.';end if;
 if exists(select 1 from oyun.cekler c where c.durum='karsiliksiz' and
   (c.duzenleyen=x.alici_yetkili or c.borclu_sirket=x.magaza_id))
 then raise exception 'Karşılıksız çek nedeniyle işlem tamamlanamaz.';end if;
 if not exists(select 1 from oyun.eko_isletmeler where sirket_id=buyer.id and tur='magaza')
   or not exists(select 1 from oyun.eko_isletmeler where sirket_id=seller.id and tur='fabrika')
 then raise exception 'Ticaret türü uygun değil.';end if;
 select * into stk from oyun.eko_urun_stok where sirket_id=x.uretici_id and urun=x.urun for update;
 if stk.sirket_id is null or stk.adet<x.adet or stk.satis_fiyati<>x.birim_fiyat
 then raise exception 'Stok veya ürün fiyatı değişti, yeni teklif oluşturulmalı.';end if;
 num:=round(stk.satis_fiyati*x.adet);
 if num<>x.toplam then raise exception 'Sipariş fiyatı uyuşmuyor.';end if;
 brt:=greatest(0,num-round(stk.maliyet_birim*x.adet));
 tax:=oyun.eko_vergi_hesap('kar',brt);
 if seller.kasa<tax then raise exception 'Satıcı şirketin tahakkuk eden vergiyi ödeyecek kasası yok.';end if;
 -- Ürün teslimiyle birlikte yeni çek borcu kurulur, satıcıya anında nakit yazılmaz.
 update oyun.cek_hesaplari set yaprak=yaprak-1 where id=h.id;
 insert into oyun.cekler(hesap_id,duzenleyen,borclu_sirket,ilk_lehtar_sirket,hamil_sirket,
     tutar,tarih,aciklama,keside_at)
 values(h.id,x.alici_yetkili,buyer.id,seller.id,seller.id,num,x.cek_tarih,
   'Toptan mal bedeli · '||x.adet||' x '||left(x.urun,65)||' · sipariş #'||x.id,t)
 returning id into checknum;
 update oyun.eko_urun_stok set adet=adet-x.adet,guncelleme=t
   where sirket_id=seller.id and urun=x.urun;
 insert into oyun.eko_urun_stok(sirket_id,urun,adet,maliyet_birim,satis_fiyati)
 values(buyer.id,x.urun,x.adet,stk.satis_fiyati,
    greatest(round(stk.satis_fiyati*1.4),
      coalesce((select onerilen_satis from oyun.eko_urun_katalog where kod=x.urun),round(stk.satis_fiyati*1.5))))
 on conflict(sirket_id,urun) do update set
  maliyet_birim=round((oyun.eko_urun_stok.maliyet_birim*oyun.eko_urun_stok.adet+
      excluded.maliyet_birim*excluded.adet)/greatest(1,oyun.eko_urun_stok.adet+excluded.adet),2),
  adet=oyun.eko_urun_stok.adet+excluded.adet,
  guncelleme=t;
 update oyun.sirketler set kasa=kasa-tax where id=seller.id and kasa>=tax;
 if not found then raise exception 'Satıcı vergisi için nakit yok.';end if;
 insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama,zaman)
  values(buyer.id,seller.id,x.alici_yetkili,'urun_tedarik',0,
   x.adet||' adet '||x.urun||' çekli ticaret: çek # '||checknum||', borç '||num||' TL',t)
 returning id into entry;
 if oyun.eko_vergi_tahsil(seller.id,'kar',brt,'toptan_kar',entry)<>tax
 then raise exception 'Toptan çekli ticarette vergi uyumsuzluğu.';end if;
 perform oyun.eko_kar_yaz(seller.id,'toptan',entry,num,tax,num-round(stk.maliyet_birim*x.adet)-tax,t);
 insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
 values (buyer.id,t,0,'Çek # '||checknum||' karşılığı '||x.adet||' adet stok alındı. Borç: '||num||' TL.'),
  (seller.id,t,-tax,'Çekli satış # '||checknum||' · tahsil edilmemiş alacak '||num||' TL · ödenen vergi '||tax||' TL.');
 update oyun.cek_toptan_teklif set durum='kabul',karar_at=t,cek_id=checknum where id=x.id;
 insert into oyun.bildirimler(user_id,zaman,metin)
  values(x.alici_yetkili,t,'✅ Çekli toptan alım #'||x.id||' kabul edildi. Çek # '||checknum||
    ' düzenlendi, mallar stokta. '||num||' TL ödemeyi çek tarihinde karşıla.');
 return jsonb_build_object('tamam',true,'cek_id',checknum,'tutar',num,'urun',x.urun,'adet',x.adet);
end $function$;

drop trigger if exists tr_cek_takip_tazminat on oyun.cek_takip;
create trigger tr_cek_takip_tazminat before insert or update on oyun.cek_takip
 for each row execute function oyun.cek_takip_tazminat();
revoke all on function oyun.cek_odeme_aktar(bigint,numeric,text) from public,anon,authenticated;
revoke all on function public.cek_panel() from public,anon,authenticated;
revoke all on function public.cek_islem(text,bigint,jsonb) from public,anon,authenticated;
revoke all on function public.cek_hedef_ara(text) from public,anon,authenticated;
revoke all on function public.cek_ek_panel() from public,anon,authenticated;
revoke all on function public.cek_iskonto_islem(text,bigint,bigint) from public,anon,authenticated;
revoke all on function public.cek_tazminat_ode(bigint,numeric) from public,anon,authenticated;
revoke all on function public.cek_toptan_panel() from public,anon,authenticated;
revoke all on function public.cek_toptan_islem(text,jsonb) from public,anon,authenticated;
grant execute on function public.cek_panel() to authenticated;
grant execute on function public.cek_islem(text,bigint,jsonb) to authenticated;
grant execute on function public.cek_hedef_ara(text) to authenticated;
grant execute on function public.cek_ek_panel() to authenticated;
grant execute on function public.cek_iskonto_islem(text,bigint,bigint) to authenticated;
grant execute on function public.cek_tazminat_ode(bigint,numeric) to authenticated;
grant execute on function public.cek_toptan_panel() to authenticated;
grant execute on function public.cek_toptan_islem(text,jsonb) to authenticated;
