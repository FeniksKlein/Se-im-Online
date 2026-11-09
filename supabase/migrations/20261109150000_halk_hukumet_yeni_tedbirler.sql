-- =====================================================================
--  Halk hareketleri: 12 yeni hükümet aracı.
--  Her aracın bedeli, riski ve eylemcilerin karşı hamlesi vardır.
--  Yetki: oyun.sokak_yonetebilir (Cumhurbaşkanı veya İçişleri Bakanı).
--  Kapı kapı, vekil, avukat, basın, şirket ve dernek hamleleri
--  ilgili gerçek oyuncuya açıktır.
--
--  Bedeller açılış bedelinin (varsayılan 50.000 TL) katıdır.
--  İçişleri kasasından oyun.bm_kasa_harca ile düşer.
--  Sosyal kart kişi başı 4.000 TL, en çok 15 kişi.
--  Kapı kapı üye adımı parti kasasından 8.000 TL, oyuncu başı 3 saat.
--
--  Canlı veritabanına bu dosya elle uygulanır. Bu değişiklik
--  uygulanırken üretim kasasına yazılmaz; dosya yalnız şemadır.
-- =====================================================================

alter table oyun.sokak_kriz add column if not exists ivme_saat integer not null default 0;

create table if not exists oyun.sokak_tedbir(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 tur text not null check(tur in ('hizmet','vergi_tatil','istihdam','brifing','sosyal_kart','guzergah','komisyon','gozlemci','kapi','gece','iletisim','festival')),
 yapan uuid not null references oyun.profiller,
 gerekce text not null check(length(gerekce) between 20 and 500),
 bedel numeric not null check(bedel>=0),
 zaman timestamptz not null,
 bitis timestamptz not null,
 kontrol timestamptz,
 durum text not null default 'aktif' check(durum in ('aktif','yetersiz','kabul','ret','dayatma','lehe','aleyhe','bos','tutuldu','tutulmadi','bozuldu')),
 etki jsonb not null default '{}'::jsonb,
 ceza boolean not null default false
);
create index if not exists sokak_tedbir_eylem on oyun.sokak_tedbir(eylem_id,zaman desc);
create index if not exists sokak_tedbir_tur on oyun.sokak_tedbir(tur,zaman desc);

create table if not exists oyun.sokak_tedbir_hamle(
 id bigint generated always as identity primary key,
 tedbir_id bigint not null references oyun.sokak_tedbir,
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 tur text not null check(tur in (
  'yetersiz','slogan','ikna_olmadim','kart','kart_iade','kart_cagri',
  'guzergah_kabul','guzergah_ret','dayat',
  'komisyon_iktidar','komisyon_muhalefet','komisyon_devral',
  'gozlemci','gozlemci_ret',
  'kapi_iktidar','kapi_muhalefet',
  'istihdam_soz','istihdam_grev',
  'basin_hukumet','basin_karsi',
  'otobus','dernek_davet','sahne','festival','kisit_itiraz')),
 metin text,
 sayi numeric not null default 1,
 zaman timestamptz not null,
 bitis timestamptz
);
create index if not exists sokak_tedbir_hamle_t on oyun.sokak_tedbir_hamle(tedbir_id,tur);
create unique index if not exists sokak_tedbir_hamle_tek
 on oyun.sokak_tedbir_hamle(tedbir_id,user_id,tur)
 where tur not in ('kapi_iktidar','kapi_muhalefet');

alter table oyun.sokak_tedbir enable row level security;
alter table oyun.sokak_tedbir_hamle enable row level security;
revoke all on oyun.sokak_tedbir,oyun.sokak_tedbir_hamle from public,anon,authenticated;

-- ───────────── adlar, bedel, kapılar ─────────────
create or replace function oyun.sokak_tedbir_ad(k text) returns text language sql immutable set search_path='' as $$
 select case k
  when 'hizmet' then 'Acil Hizmet Seferberliği'
  when 'vergi_tatil' then 'Bölgesel Vergi Tatili'
  when 'istihdam' then 'İstihdam Taahhüt Paketi'
  when 'brifing' then 'Resmi Basın Brifingi'
  when 'sosyal_kart' then 'Acil Sosyal Destek Kartı'
  when 'guzergah' then 'Güvenli Alan / Güzergâh'
  when 'komisyon' then 'Meclis Araştırma Komisyonu'
  when 'gozlemci' then 'Bağımsız Gözlemci'
  when 'kapi' then 'İktidar Kapı Kapı'
  when 'gece' then 'Gece Toplanma Kısıtı'
  when 'iletisim' then 'İletişim Yavaşlatma'
  when 'festival' then 'Kültür-Festival'
  else k end
$$;

create or replace function oyun.sokak_tedbir_bedel(e bigint,k text) returns numeric language sql stable set search_path='' as $$
 select round(case k
  when 'hizmet' then a.baslatma_bedeli*5
  when 'vergi_tatil' then a.baslatma_bedeli*6
  when 'istihdam' then a.baslatma_bedeli*4
  when 'brifing' then a.baslatma_bedeli*2
  when 'sosyal_kart' then 4000
  when 'guzergah' then a.baslatma_bedeli*2
  when 'komisyon' then a.baslatma_bedeli*2
  when 'gozlemci' then a.baslatma_bedeli
  when 'kapi' then a.baslatma_bedeli*2
  when 'gece' then a.baslatma_bedeli*2
  when 'iletisim' then a.baslatma_bedeli*3
  when 'festival' then a.baslatma_bedeli*3
  end,2)
 from oyun.sokak_eylem_ayar a where a.id=1
$$;

create or replace function oyun.sokak_gece_kapali(e bigint) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_tedbir where eylem_id=e and tur='gece' and durum='aktif' and bitis>oyun.simdi())
  and (extract(hour from oyun.simdi() at time zone 'Europe/Istanbul')::int>=22
    or extract(hour from oyun.simdi() at time zone 'Europe/Istanbul')::int<6)
$$;
create or replace function oyun.sokak_iletisim_kapali(e bigint) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_tedbir where eylem_id=e and tur='iletisim' and durum='aktif' and bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_gozlemci_aktif(e bigint) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e and td.tur='gozlemci' and td.durum='aktif' and td.bitis>oyun.simdi()
  and exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='gozlemci'))
$$;
create or replace function oyun.sokak_kirmizi_engel(e bigint) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_tedbir where eylem_id=e and tur='komisyon' and durum='aktif' and bitis>oyun.simdi())
$$;

create or replace function oyun.sokak_gazeteci(u uuid) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.oyuncu_gazeteleri where sahip=u and aktif)
  or exists(select 1 from oyun.gazete_yazarlar y join oyun.oyuncu_gazeteleri g on g.id=y.gazete_id and g.aktif where y.user_id=u and y.aktif)
$$;
create or replace function oyun.sokak_vekil(u uuid) returns text language sql stable set search_path='' as $$
 select case when exists(select 1 from oyun.makamlar m where m.user_id=u and m.bit is null and m.tur='mv')
  then case when oyun.sokak_iktidar(u) then 'iktidar' else 'muhalefet' end end
$$;

-- İlin şirketleri: sahip olunan, ilde merkezi / pazarı / işletmesi / şubesi olanlar.
create or replace function oyun.sokak_il_sirketleri(p_il integer,p_user uuid) returns jsonb language plpgsql stable set search_path='' as $$
declare q text; j jsonb;
begin
 if to_regclass('oyun.sirketler') is null or to_regclass('oyun.sirket_ortaklari') is null then return '[]'::jsonb; end if;
 q:='select coalesce(jsonb_agg(jsonb_build_object(''id'',s.id,''ad'',s.ad) order by s.ad),''[]''::jsonb) from oyun.sirketler s where s.aktif and oyun.sirket_sahibi(s.id)=$2 and (false';
 if to_regclass('oyun.sirket_merkezleri') is not null then q:=q||' or exists(select 1 from oyun.sirket_merkezleri m where m.sirket_id=s.id and m.il_id=$1)'; end if;
 if to_regclass('oyun.pazar_sirket') is not null then q:=q||' or exists(select 1 from oyun.pazar_sirket p where p.sirket_id=s.id and p.il_id=$1)'; end if;
 if to_regclass('oyun.eko_isletmeler') is not null then q:=q||' or exists(select 1 from oyun.eko_isletmeler e where e.sirket_id=s.id and e.il_id=$1)'; end if;
 if to_regclass('oyun.sirket_il_subeleri') is not null then q:=q||' or exists(select 1 from oyun.sirket_il_subeleri b where b.sirket_id=s.id and b.il_id=$1)'; end if;
 q:=q||')';
 execute q into j using p_il,p_user;
 return coalesce(j,'[]'::jsonb);
end $$;

create or replace function oyun.sokak_basina_yaz(e bigint,metin text) returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi();
begin
 insert into oyun.bildirimler(user_id,zaman,metin)
 select distinct q.u,t,left(metin,500) from (
  select g.sahip as u from oyun.oyuncu_gazeteleri g where g.aktif
  union
  select y.user_id from oyun.gazete_yazarlar y join oyun.oyuncu_gazeteleri g on g.id=y.gazete_id and g.aktif where y.aktif
 ) q join oyun.profiller p on p.id=q.u
 where not p.yasakli and p.son_gorulme>t-interval '7 days'
 limit 40;
 perform oyun.olay('siyaset',left(metin,240),(select il_id from oyun.sokak_eylem where id=e),(select parti_id from oyun.sokak_eylem where id=e));
end $$;

create or replace function oyun.sokak_talep_kismi(e bigint) returns text language plpgsql set search_path='' as $$
declare k text;
begin
 select tur into k from oyun.sokak_talep where eylem_id=e;
 if k='hizmet' then
  update oyun.il_durum i set memnuniyet=least(100,i.memnuniyet+3) from oyun.sokak_eylem x where x.id=e and i.il_id=x.il_id;
  return 'il hizmet memnuniyeti +3';
 elsif k='issizlik' then
  update oyun.ulke set issizlik=least(40,greatest(2,issizlik-0.25)) where id=1;
  return 'işsizlik −0,25';
 elsif k='vergi' then
  update oyun.ulke set vergi=greatest(vergi_alt,vergi-0.5) where id=1;
  return 'vergi −0,5';
 else
  update oyun.ulke set memnuniyet=least(100,memnuniyet+1) where id=1;
  return 'ülke memnuniyeti +1';
 end if;
end $$;

create or replace function oyun.sokak_gozlemci_ceza(e bigint,u uuid,neden text) returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); idb bigint; x oyun.sokak_eylem;
begin
 select td.id into idb from oyun.sokak_tedbir td
  where td.eylem_id=e and td.tur='gozlemci' and td.durum='aktif' and td.bitis>t and not td.ceza
   and exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='gozlemci')
  order by td.zaman desc limit 1;
 if idb is null then return; end if;
 select * into x from oyun.sokak_eylem where id=e;
 update oyun.sokak_tedbir set ceza=true,bitis=greatest(bitis,t+interval '12 hours') where id=idb;
 update oyun.ulke set memnuniyet=greatest(0,memnuniyet-4) where id=1;
 update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-3) where il_id=x.il_id;
 perform oyun.sokak_basina_yaz(e,'Gözlemci protokolü çiğnendi ('||neden||'), eylem #'||e||'. Ülke memnuniyeti −4, il −3.');
 perform oyun.sokak_duyur(e,'Bağımsız gözlemciler varken sert müdahale ('||neden||'): ülke memnuniyeti −4, il memnuniyeti −3. Basın yazdı.');
end $$;

-- Güç dökümüne ek: düz puan ve nabız ağırlığı. Para yazmaz.
create or replace function oyun.sokak_tedbir_agirlik(e bigint) returns jsonb language plpgsql stable set search_path='' as $$
declare t timestamptz:=oyun.simdi(); r record; puan numeric:=0; destek integer:=0; karsi integer:=0; satir jsonb:='[]'::jsonb;
 saat integer; n integer; tilt integer; bh integer; bk integer; ikna integer; soz integer; grev boolean; kart integer; iade integer; kat integer; sahne integer; oto integer; der integer; itiraz integer; kip integer; kim integer;
begin
 saat:=extract(hour from t at time zone 'Europe/Istanbul')::int;
 for r in select * from oyun.sokak_tedbir where eylem_id=e and (bitis>t or (jsonb_exists(etki,'tepki_bitis') and (etki->>'tepki_bitis')::timestamptz>t)) loop
  if r.tur='hizmet' and r.durum='aktif' and r.bitis>t then
   puan:=puan-8; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Acil hizmet seferberliği','puan',-8));
  elsif r.tur='vergi_tatil' and r.bitis>t and r.durum in ('aktif','yetersiz') then
   if r.durum='aktif' then puan:=puan-6; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Bölgesel vergi tatili','puan',-6)); end if;
   puan:=puan+4; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Diğer illerin özel muamele tepkisi','puan',4));
  elsif r.tur='istihdam' and r.bitis>t and r.durum='aktif' then
   select count(*) into soz from oyun.sokak_tedbir_hamle where tedbir_id=r.id and tur='istihdam_soz';
   grev:=exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=r.id and tur='istihdam_grev');
   if grev then puan:=puan+4; satir:=satir||jsonb_build_array(jsonb_build_object('ad','İstihdam paketine grev','puan',4));
   elsif soz>=1 then puan:=puan-6; satir:=satir||jsonb_build_array(jsonb_build_object('ad','İstihdam taahhüdü ('||soz||' şirket)','puan',-6)); end if;
  elsif r.tur='istihdam' and r.durum='bozuldu' and jsonb_exists(r.etki,'tepki_bitis') and (r.etki->>'tepki_bitis')::timestamptz>t then
   puan:=puan+6; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Tutulmayan istihdam sözü','puan',6));
  elsif r.tur='brifing' and r.durum='aktif' and r.bitis>t then
   select count(*) filter(where tur='basin_hukumet'),count(*) filter(where tur='basin_karsi'),count(*) filter(where tur='ikna_olmadim')
    into bh,bk,ikna from oyun.sokak_tedbir_hamle where tedbir_id=r.id;
   tilt:=3+least(6,2*bh);
   if bk>0 then tilt:=-(3+least(6,2*bk)); end if;
   if tilt>0 then karsi:=karsi+tilt; else destek:=destek+abs(tilt); end if;
   destek:=destek+least(8,ikna);
   satir:=satir||jsonb_build_array(jsonb_build_object('ad','Basın brifingi nabız ağırlığı '||case when tilt>0 then '+'||tilt||' karşı' else abs(tilt)||' destek' end||case when ikna>0 then ', ikna olmadım '||least(8,ikna) else '' end,'puan',0));
  elsif r.tur='sosyal_kart' and r.durum='aktif' and r.bitis>t then
   select count(*) filter(where tur='kart'),count(*) filter(where tur='kart_iade') into kart,iade from oyun.sokak_tedbir_hamle where tedbir_id=r.id;
   puan:=puan+5; if kart>0 and iade*2>=kart then puan:=puan+5; end if;
   satir:=satir||jsonb_build_array(jsonb_build_object('ad','Sosyal kart: oy satın alma şüphesi ('||iade||'/'||kart||' iade)','puan',case when kart>0 and iade*2>=kart then 10 else 5 end));
  elsif r.tur='guzergah' and r.bitis>t and r.durum='ret' then
   puan:=puan+5; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Güzergâh reddedildi, inat','puan',5));
  elsif r.tur='guzergah' and r.bitis>t and r.durum='dayatma' then
   puan:=puan+8; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Güzergâh dayatıldı, inat','puan',8));
  elsif r.tur='guzergah' and r.bitis>t and r.durum='kabul' then
   satir:=satir||jsonb_build_array(jsonb_build_object('ad','Düzen +5, güzergâh kabul (güç aynı, ekonomi kalkanı)','puan',0));
  elsif r.tur='komisyon' and r.durum='aktif' and r.bitis>t then
   satir:=satir||jsonb_build_array(jsonb_build_object('ad','Meclis komisyonu: yeni kırmızı yok','puan',0));
  elsif r.tur='komisyon' and r.durum='lehe' and r.bitis>t then
   puan:=puan-8; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Komisyon hükümet lehine','puan',-8));
  elsif r.tur='komisyon' and r.durum in ('aleyhe','bos') and r.bitis>t then
   puan:=puan+4; satir:=satir||jsonb_build_array(jsonb_build_object('ad',case when r.durum='aleyhe' then 'Komisyon hükümet aleyhine' else 'Boş komisyon' end,'puan',4));
  elsif r.tur='gozlemci' and r.ceza and r.bitis>t then
   puan:=puan+10; satir:=satir||jsonb_build_array(jsonb_build_object('ad','Gözlemci protokolü çiğnendi','puan',10));
  elsif r.tur='kapi' and r.durum='aktif' and r.bitis>t then
   select count(*) filter(where tur='kapi_iktidar' and bitis>t),count(*) filter(where tur='kapi_muhalefet' and bitis>t) into kip,kim from oyun.sokak_tedbir_hamle where tedbir_id=r.id;
   karsi:=karsi+least(8,kip); destek:=destek+least(8,kim);
   if kip+kim>0 then satir:=satir||jsonb_build_array(jsonb_build_object('ad','Kapı kapı ağırlığı: '||least(8,kip)||' karşı, '||least(8,kim)||' destek','puan',0)); end if;
  elsif r.tur='gece' and r.durum='aktif' and r.bitis>t and saat>=6 and saat<22 then
   select count(*) into itiraz from oyun.sokak_tedbir_hamle where tedbir_id=r.id and tur='kisit_itiraz';
   puan:=puan+case when itiraz>=3 then 4 else 2 end;
   satir:=satir||jsonb_build_array(jsonb_build_object('ad','Gece kısıtına gündüz inatı','puan',case when itiraz>=3 then 4 else 2 end));
  elsif r.tur='iletisim' and r.durum='aktif' and r.bitis>t then
   select count(*) filter(where tur='otobus'),count(*) filter(where tur='dernek_davet') into oto,der from oyun.sokak_tedbir_hamle where tedbir_id=r.id;
   puan:=puan+6+least(8,2*oto)+least(6,2*der);
   satir:=satir||jsonb_build_array(jsonb_build_object('ad','İletişim yavaşlatma skandalı','puan',6));
   if oto>0 then satir:=satir||jsonb_build_array(jsonb_build_object('ad','Miting otobüsü','puan',least(8,2*oto))); end if;
   if der>0 then satir:=satir||jsonb_build_array(jsonb_build_object('ad','Dernek daveti','puan',least(6,2*der))); end if;
  elsif r.tur='festival' and r.durum='aktif' and r.bitis>t then
   select count(*) filter(where tur='festival' and (bitis is null or bitis>t)),count(*) filter(where tur='sahne') into kat,sahne from oyun.sokak_tedbir_hamle where tedbir_id=r.id;
   karsi:=karsi+least(12,kat); puan:=puan+5+least(12,4*sahne);
   satir:=satir||jsonb_build_array(jsonb_build_object('ad','Ekmek yok oyun var','puan',5));
   if kat>0 then satir:=satir||jsonb_build_array(jsonb_build_object('ad','Festivale giden tarafsız ağırlığı '||least(12,kat),'puan',0)); end if;
   if sahne>0 then satir:=satir||jsonb_build_array(jsonb_build_object('ad','Sahne işgali pankartı','puan',least(12,4*sahne))); end if;
  end if;
 end loop;
 return jsonb_build_object('puan',puan,'destek',destek,'karsi',karsi,'satirlar',satir);
end $$;

-- ───────────── süre dolunca söz, vergi, komisyon ─────────────
create or replace function oyun.sokak_tedbir_tick() returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); r record; v numeric; soz integer; grev boolean; dusen numeric; geri numeric; kalan numeric; opp integer; ikt integer; yazi text; il smallint;
begin
 for r in select * from oyun.sokak_tedbir where durum in ('aktif','yetersiz') and (bitis<=t or (kontrol is not null and kontrol<=t and not jsonb_exists(etki,'olculdu'))) for update loop
  select il_id into il from oyun.sokak_eylem where id=r.eylem_id;
  if r.tur='hizmet' and r.kontrol is not null and r.kontrol<=t and not jsonb_exists(r.etki,'olculdu') then
   v:=(select memnuniyet from oyun.il_durum where il_id=il);
   if coalesce(v,0)<coalesce((r.etki->>'hedef')::numeric,0) then
    update oyun.ulke set memnuniyet=greatest(0,memnuniyet-3) where id=1;
    update oyun.sokak_tedbir set durum='tutulmadi',etki=etki||jsonb_build_object('olculdu',true,'olcum',v) where id=r.id;
    perform oyun.sokak_duyur(r.eylem_id,'Hizmet seferberliğinin sözü tutulmadı. Ülke memnuniyeti −3. Ölçülen: '||coalesce(v::text,'yok')||', hedef: '||(r.etki->>'hedef'));
   else
    update oyun.sokak_tedbir set durum='tutuldu',etki=etki||jsonb_build_object('olculdu',true,'olcum',v) where id=r.id;
    perform oyun.sokak_duyur(r.eylem_id,'Hizmet seferberliğinin sözü duruyor. İl memnuniyeti hedefte: '||coalesce(v::text,'yok'));
   end if;
  elsif r.tur='vergi_tatil' and r.bitis<=t and not jsonb_exists(r.etki,'bitti') then
   update oyun.il_durum set kent_vergisi=coalesce((r.etki->>'eski')::numeric,kent_vergisi) where il_id=il and kent_vergisi=coalesce((r.etki->>'yeni')::numeric,kent_vergisi);
   update oyun.sokak_tedbir set etki=etki||jsonb_build_object('bitti',true),durum=case when durum='yetersiz' then 'yetersiz' else 'tutuldu' end where id=r.id;
  elsif r.tur='istihdam' and r.durum='aktif' and r.bitis<=t then
   select count(*) into soz from oyun.sokak_tedbir_hamle where tedbir_id=r.id and tur='istihdam_soz';
   grev:=exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=r.id and tur='istihdam_grev');
   dusen:=coalesce((r.etki->>'dusen')::numeric,0); geri:=coalesce((r.etki->>'geri')::numeric,0); kalan:=greatest(0,dusen-geri);
   if soz<1 then
    update oyun.ulke set issizlik=least(40,issizlik+kalan),memnuniyet=greatest(0,memnuniyet-2) where id=1;
    update oyun.sokak_tedbir set durum='bozuldu',etki=etki||jsonb_build_object('tepki_bitis',t+interval '12 hours','bitti',true) where id=r.id;
    perform oyun.sokak_duyur(r.eylem_id,'İstihdam taahhüdünü şirketler tutmadı. İşsizlik indirimi geri geldi, hükümet memnuniyeti −2.');
   else
    update oyun.sokak_tedbir set durum=case when grev then 'bozuldu' else 'tutuldu' end,etki=etki||jsonb_build_object('bitti',true) where id=r.id;
   end if;
  elsif r.tur='komisyon' and r.durum='aktif' and r.bitis<=t then
   select count(*) filter(where tur='komisyon_muhalefet'),count(*) filter(where tur='komisyon_iktidar') into opp,ikt from oyun.sokak_tedbir_hamle where tedbir_id=r.id;
   if opp>ikt and opp>=1 then
    yazi:=oyun.sokak_talep_kismi(r.eylem_id);
    update oyun.sokak_tedbir set durum='aleyhe',bitis=t+interval '6 hours' where id=r.id;
    perform oyun.sokak_duyur(r.eylem_id,'Komisyon hükümet aleyhine kapandı. Talep kısmen uygulandı: '||yazi||'.');
   elsif ikt>=1 then
    update oyun.sokak_tedbir set durum='lehe',bitis=t+interval '6 hours' where id=r.id;
    perform oyun.sokak_duyur(r.eylem_id,'Komisyon hükümet lehine kapandı. Eylem 6 saat sakinler.');
   else
    update oyun.sokak_tedbir set durum='bos',bitis=t+interval '6 hours' where id=r.id;
    perform oyun.sokak_duyur(r.eylem_id,'Komisyona vekil katılmadı. Boş komisyon tepki topladı.');
   end if;
  elsif r.tur='gozlemci' and r.durum='aktif' and r.bitis<=t then
   if exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=r.id and tur='gozlemci') then
    update oyun.sokak_tedbir set durum='tutuldu' where id=r.id;
   else
    update oyun.sokak_tedbir set durum='bos' where id=r.id;
    perform oyun.sokak_duyur(r.eylem_id,'Gözlemci protokolüne avukat katılmadı. Yasak başlamadan düştü; harcanan bütçe geri gelmez.');
   end if;
  end if;
 end loop;
end $$;

-- ───────────── açılış ─────────────
create or replace function public.sokak_tedbir_ac(p_eylem bigint,p_tur text,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); tut numeric; kid bigint; talep text; txt text:=btrim(coalesce(p_gerekce,''));
 once numeric; yeni numeric; artis numeric; esk numeric; ids uuid[]; pid uuid; n integer:=0; etki jsonb:='{}'::jsonb; sure interval; kontrol timestamptz;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_tur is null or p_tur not in ('hizmet','vergi_tatil','istihdam','brifing','sosyal_kart','guzergah','komisyon','gozlemci','kapi','gece','iletisim','festival') then raise exception 'Geçersiz hükümet aracı'; end if;
 if length(txt) not between 20 and 500 then raise exception 'Gerekçe 20–500 karakter olmalı'; end if;
 perform pg_advisory_xact_lock(781231,1);
 if not oyun.sokak_yonetebilir(u) then raise exception 'Yalnız Cumhurbaşkanı veya İçişleri Bakanı kullanabilir'; end if;
 if not coalesce((select aktif from oyun.sokak_eylem_ayar where id=1),false) then raise exception 'Halk hareketleri kapalı'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Eylem aktif değil'; end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=x.id and durum='takip') then raise exception 'Uzlaşma takip süresinde yeni müdahale yapılamaz'; end if;
 if oyun.sokak_katilimci_mi(x.id,u,'muhalefet') then raise exception 'Bu eyleme katılımcısın; hükümet aracı kullanamazsın'; end if;
 select tur into talep from oyun.sokak_talep where eylem_id=x.id;
 if p_tur='hizmet' and talep is distinct from 'hizmet' then raise exception 'Acil hizmet seferberliği yalnız hizmet talebinde kullanılır'; end if;
 if p_tur='vergi_tatil' and talep is distinct from 'vergi' then raise exception 'Vergi tatili yalnız vergi talebinde kullanılır'; end if;
 if p_tur='istihdam' and talep is distinct from 'issizlik' then raise exception 'İstihdam paketi yalnız işsizlik talebinde kullanılır'; end if;
 if p_tur in ('hizmet','vergi_tatil','istihdam','sosyal_kart','guzergah','komisyon','gozlemci') and exists(select 1 from oyun.sokak_tedbir where eylem_id=x.id and tur=p_tur) then raise exception 'Bu araç bu eylemde bir kez kullanılır'; end if;
 if p_tur='brifing' and exists(select 1 from oyun.sokak_tedbir where eylem_id=x.id and tur='brifing' and zaman>t-interval '12 hours') then raise exception 'Basın brifingi 12 saatte bir yapılır'; end if;
 if p_tur='kapi' and exists(select 1 from oyun.sokak_tedbir where eylem_id=x.id and tur='kapi' and zaman>t-interval '12 hours') then raise exception 'Kapı kapı seferberliği 12 saatte bir açılır'; end if;
 if p_tur='gece' and exists(select 1 from oyun.sokak_tedbir where eylem_id=x.id and tur='gece' and zaman>t-interval '48 hours') then raise exception 'Gece kısıtı 48 saatte bir konur'; end if;
 if p_tur='iletisim' and exists(select 1 from oyun.sokak_tedbir where eylem_id=x.id and tur='iletisim' and zaman>t-interval '24 hours') then raise exception 'İletişim yavaşlatma 24 saatte bir yapılır'; end if;
 if p_tur='festival' and exists(select 1 from oyun.sokak_tedbir where eylem_id=x.id and tur='festival' and zaman>t-interval '24 hours') then raise exception 'Festival 24 saatte bir düzenlenir'; end if;
 if (select count(*) from oyun.sokak_tedbir where eylem_id=x.id and zaman>t-interval '12 hours')>=3 then raise exception 'Aynı eylemde 12 saatte en çok 3 yeni araç açılır'; end if;
 if exists(select 1 from oyun.sokak_tedbir where eylem_id=x.id and tur=p_tur and durum='aktif' and bitis>t) then raise exception 'Bu araç zaten sürüyor'; end if;

 sure:=case p_tur when 'vergi_tatil' then interval '48 hours' when 'gece' then interval '48 hours' when 'komisyon' then interval '24 hours' when 'hizmet' then interval '12 hours' when 'brifing' then interval '12 hours' when 'istihdam' then interval '12 hours' when 'sosyal_kart' then interval '12 hours' when 'guzergah' then interval '12 hours' when 'kapi' then interval '12 hours' when 'festival' then interval '8 hours' when 'iletisim' then interval '6 hours' when 'gozlemci' then interval '2 hours' else interval '12 hours' end;
 if p_tur='hizmet' then kontrol:=t+interval '24 hours'; end if;

 if p_tur='sosyal_kart' then
  select coalesce(array_agg(s.id),array[]::uuid[]) into ids from (
   select p.id from oyun.profiller p
    where p.il_id=x.il_id and not p.yasakli and p.id<>u and p.olusturma<t-interval '3 days' and p.son_gorulme>t-interval '7 days'
     and exists(select 1 from oyun.cuzdan c where c.user_id=p.id)
     and not oyun.sokak_katilimci_mi(x.id,p.id,'muhalefet') and not oyun.sokak_katilimci_mi(x.id,p.id,'iktidar')
    order by p.son_gorulme desc limit 15) s;
  n:=coalesce(array_length(ids,1),0);
  if n=0 then raise exception 'İlde kart verilecek, cüzdanı olan aktif oyuncu yok'; end if;
  tut:=n*4000;
 else
  tut:=oyun.sokak_tedbir_bedel(x.id,p_tur);
 end if;
 perform oyun.bm_kasa_harca('icisleri',tut/oyun.pazar_tl_milyar(),'gider','Halk hareketi #'||x.id||' / '||oyun.sokak_tedbir_ad(p_tur)||' / '||tut||' TL');

 if p_tur='hizmet' then
  select memnuniyet into once from oyun.il_durum where il_id=x.il_id for update;
  artis:=least(4,greatest(0,100-coalesce(once,50)));
  yeni:=coalesce(once,50)+artis;
  update oyun.il_durum set memnuniyet=yeni where il_id=x.il_id;
  etki:=jsonb_build_object('artis',artis,'hedef',yeni,'oy_sonu',t+interval '12 hours');
 elsif p_tur='vergi_tatil' then
  select kent_vergisi into esk from oyun.il_durum where il_id=x.il_id for update;
  yeni:=greatest(0,coalesce(esk,2)-1);
  update oyun.il_durum set kent_vergisi=yeni where il_id=x.il_id;
  update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-0.5) where il_id<>x.il_id;
  update oyun.ulke set buyume=greatest(-20,buyume-0.2),memnuniyet=greatest(0,memnuniyet-1) where id=1;
  etki:=jsonb_build_object('eski',esk,'yeni',yeni,'oy_sonu',t+interval '12 hours');
 elsif p_tur='istihdam' then
  select issizlik into once from oyun.ulke where id=1 for update;
  yeni:=greatest(2,coalesce(once,9)-0.3);
  update oyun.ulke set issizlik=yeni where id=1;
  etki:=jsonb_build_object('dusen',round(coalesce(once,9)-yeni,2),'geri',0);
 elsif p_tur='gece' then
  perform oyun.sokak_gozlemci_ceza(x.id,u,'gece kısıtı');
  update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=x.il_id;
 elsif p_tur='iletisim' then
  perform oyun.sokak_gozlemci_ceza(x.id,u,'iletişim yavaşlatma');
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1;
  update oyun.sokak_kriz set
   kirmizi_baslangic=case when kirmizi_baslangic is not null then kirmizi_baslangic-interval '6 hours' else kirmizi_baslangic end,
   ivme_saat=case when kirmizi_baslangic is null then least(12,ivme_saat+6) else ivme_saat end
  where id=1;
  perform oyun.sokak_basina_yaz(x.id,'İletişim yavaşlatma: eylem #'||x.id||' ilinde 6 saat çağrı ve nabız durdu. Mesaj ve oy hakları durmadı. Ülke memnuniyeti −2, kriz sayacı 6 saat ilerledi.');
 elsif p_tur='festival' then
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-0.5) where id=1;
 elsif p_tur='gozlemci' and oyun.sokak_gozlemci_aktif(x.id) then
  null;
 end if;

 insert into oyun.sokak_tedbir(eylem_id,tur,yapan,gerekce,bedel,zaman,bitis,kontrol,etki)
  values(x.id,p_tur,u,txt,tut,t,t+sure,kontrol,etki) returning id into kid;

 if p_tur='sosyal_kart' then
  foreach pid in array ids loop
   update oyun.cuzdan set para=para+4000 where user_id=pid;
   if not found then raise exception 'Sosyal kart cüzdana yazılamadı'; end if;
   insert into oyun.hesap_hareket(user_id,zaman,tutar,vergi,tur,aciklama) values(pid,t,4000,0,'gelir','Eylem #'||x.id||' acil sosyal destek kartı');
   insert into oyun.sokak_tedbir_hamle(tedbir_id,eylem_id,user_id,tur,sayi,zaman,bitis) values(kid,x.id,pid,'kart',4000,t,t+sure);
   perform oyun.bildir(pid,'Eylem #'||x.id||' ilinde hükümet 4.000 TL sosyal destek kartı yatırdı. İade etmek istersen 12 saat içinde Halk Hareketleri ekranından kartı geri çevirebilirsin.');
  end loop;
 end if;

 perform oyun.sokak_yenile(x.id);
 perform oyun.sokak_kriz_kontrol();
 perform oyun.sokak_duyur(x.id,'Hükümet eylem #'||x.id||' için '||oyun.sokak_tedbir_ad(p_tur)||' başlattı. Gider: '||tut||' TL. Gerekçe: '||left(txt,280));
 return jsonb_build_object('tamam',true,'tedbir_id',kid,'tur',p_tur,'bedel',tut,'bitis',t+sure,'kisi',n);
end $$;

-- ───────────── karşı hamle ve katılım ─────────────
create or replace function public.sokak_tedbir_hamle(p_eylem bigint,p_tur text,p_metin text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); me oyun.profiller; x oyun.sokak_eylem; td oyun.sokak_tedbir; t timestamptz:=oyun.simdi(); m text:=nullif(btrim(coalesce(p_metin,'')),'');
 n integer; evet integer; ret integer; bek text; opp integer; ikt integer; yazi text; geri numeric; did bigint; gb uuid; sid bigint; alan text;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_tur is null or p_tur not in ('yetersiz','slogan','ikna_olmadim','kart_iade','kart_cagri','guzergah_kabul','guzergah_ret','dayat','komisyon_iktidar','komisyon_muhalefet','komisyon_devral','gozlemci','gozlemci_ret','kapi_iktidar','kapi_muhalefet','istihdam_soz','istihdam_grev','basin_hukumet','basin_karsi','otobus','dernek_davet','sahne','festival','festival_ayril','kisit_itiraz') then raise exception 'Geçersiz karşı hamle'; end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into me from oyun.profiller where id=u;
 if me.yasakli then raise exception 'Hesabın kısıtlı'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Eylem aktif değil'; end if;
 bek:=case p_tur
  when 'yetersiz' then null
  when 'slogan' then 'brifing' when 'ikna_olmadim' then 'brifing' when 'basin_hukumet' then 'brifing' when 'basin_karsi' then 'brifing'
  when 'kart_iade' then 'sosyal_kart' when 'kart_cagri' then 'sosyal_kart'
  when 'guzergah_kabul' then 'guzergah' when 'guzergah_ret' then 'guzergah' when 'dayat' then 'guzergah'
  when 'komisyon_iktidar' then 'komisyon' when 'komisyon_muhalefet' then 'komisyon' when 'komisyon_devral' then 'komisyon'
  when 'gozlemci' then 'gozlemci' when 'gozlemci_ret' then 'gozlemci'
  when 'kapi_iktidar' then 'kapi' when 'kapi_muhalefet' then 'kapi'
  when 'istihdam_soz' then 'istihdam' when 'istihdam_grev' then 'istihdam'
  when 'otobus' then 'iletisim' when 'dernek_davet' then 'iletisim'
  when 'sahne' then 'festival' when 'festival' then 'festival' when 'festival_ayril' then 'festival'
  when 'kisit_itiraz' then 'gece'
 end;
 if p_tur='yetersiz' then
  select * into td from oyun.sokak_tedbir where eylem_id=x.id and tur in ('hizmet','vergi_tatil') and durum='aktif' and bitis>t
   and (m is null or m not in ('hizmet','vergi_tatil') or tur=m)
   order by case when m is not null and tur=m then 0 else 1 end, zaman desc limit 1 for update;
  if m in ('hizmet','vergi_tatil') then m:=null; end if;
 elsif p_tur='dayat' then
  select * into td from oyun.sokak_tedbir where eylem_id=x.id and tur='guzergah' and durum in ('aktif','ret') and bitis>t order by zaman desc limit 1 for update;
 else
  select * into td from oyun.sokak_tedbir where eylem_id=x.id and tur=bek and durum='aktif' and bitis>t order by zaman desc limit 1 for update;
 end if;
 if td.id is null then raise exception 'Bu hamle için süren bir hükümet aracı yok'; end if;
 if p_tur='dayat' and td.durum not in ('aktif','ret') then raise exception 'Kabul edilmiş güzergâh dayatılamaz'; end if;

 if p_tur in ('yetersiz','slogan','ikna_olmadim','guzergah_kabul','guzergah_ret','otobus','sahne','kisit_itiraz') then
  if not (oyun.sokak_katilimci_mi(x.id,u,'muhalefet') or x.baslatan=u) then raise exception 'Bu hamle eylemdeki oyunculara açık'; end if;
 end if;
 if p_tur in ('guzergah_kabul','guzergah_ret') and exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur in ('guzergah_kabul','guzergah_ret')) then
  raise exception 'Güzergâh için oyun zaten duruyor'; end if;
 if p_tur='yetersiz' and (td.etki->>'oy_sonu')::timestamptz<=t then raise exception 'Yetersiz oylamasının süresi doldu'; end if;
 if p_tur='slogan' or p_tur='sahne' then
  if char_length(coalesce(m,'')) not between 6 and 90 then raise exception 'Slogan 6–90 karakter olmalı'; end if;
 end if;
 if p_tur='basin_karsi' and char_length(coalesce(m,'')) not between 20 and 500 then raise exception 'Karşı brifing 20–500 karakter olmalı'; end if;

 if p_tur='kart_cagri' and x.baslatan is distinct from u then raise exception 'Red çağrısını organizatör yapar'; end if;
 if p_tur='istihdam_grev' and x.baslatan is distinct from u then raise exception 'Grev çağrısını organizatör yapar'; end if;
 if p_tur='gozlemci_ret' and x.baslatan is distinct from u then raise exception 'Protokolü organizatör reddeder'; end if;
 if p_tur='dayat' and not oyun.sokak_yonetebilir(u) then raise exception 'Güzergâhı yalnız Cumhurbaşkanı veya İçişleri dayatır'; end if;
 if p_tur='kart_iade' and not exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=td.id and user_id=u and tur='kart') then raise exception 'Bu kart sana yazılmamış'; end if;
 if p_tur='gozlemci' then
  if not exists(select 1 from oyun.avukat_ruhsat where user_id=u and durum='aktif') then raise exception 'Gözlemci olmak için ruhsatlı avukat olmalısın'; end if;
  if oyun.sokak_katilimci_mi(x.id,u,'muhalefet') or oyun.sokak_katilimci_mi(x.id,u,'iktidar') or oyun.sokak_yonetebilir(u) then raise exception 'Gözlemci eylemde taraf olamaz'; end if;
 end if;
 if p_tur='komisyon_iktidar' and oyun.sokak_vekil(u) is distinct from 'iktidar' then raise exception 'Bu sandalyeye iktidar milletvekili oturur'; end if;
 if p_tur in ('komisyon_muhalefet','komisyon_devral') and oyun.sokak_vekil(u) is distinct from 'muhalefet' then raise exception 'Bu sandalyeye muhalefet milletvekili oturur'; end if;
 if p_tur in ('basin_hukumet','basin_karsi') and not oyun.sokak_gazeteci(u) then raise exception 'Brifinge gazeteciler katılır'; end if;
 if p_tur='basin_karsi' and oyun.sokak_iktidar(u) then raise exception 'Karşı brifingi iktidar dışı basın yazar'; end if;
 if p_tur='basin_hukumet' and oyun.sokak_katilimci_mi(x.id,u,'muhalefet') then raise exception 'Eylemdeyken hükümet brifingine katılamazsın'; end if;
 if p_tur='kapi_iktidar' then
  if not oyun.sokak_iktidar(u) or me.parti_id is null then raise exception 'Kapı kapı için iktidar partisi üyesi olmalısın'; end if;
  if oyun.sokak_iletisim_kapali(x.id) then raise exception 'İletişim yavaşlatma sürerken kapı kapı çağrısı yapılamaz'; end if;
 end if;
 if p_tur='kapi_muhalefet' then
  if oyun.sokak_iktidar(u) or me.parti_id is null then raise exception 'Karşı çağrı muhalefet partisi üyesine açık'; end if;
  if oyun.sokak_iletisim_kapali(x.id) then raise exception 'İletişim yavaşlatma sürerken çağrı yapılamaz; miting otobüsü ve dernek daveti açık'; end if;
 end if;
 if p_tur in ('kapi_iktidar','kapi_muhalefet') and exists(select 1 from oyun.sokak_tedbir_hamle where user_id=u and tur in ('kapi_iktidar','kapi_muhalefet') and zaman>t-interval '3 hours') then
  raise exception 'Kapı kapı için 3 saat beklemen gerekir'; end if;
 if p_tur in ('kapi_iktidar','kapi_muhalefet') and (select count(*) from oyun.sokak_tedbir_hamle where tedbir_id=td.id and tur=p_tur and bitis>t)>=8 then
  raise exception 'Bu tarafta kapı kapı etkisi tavana ulaştı'; end if;
 if p_tur='festival' and (oyun.sokak_katilimci_mi(x.id,u,'muhalefet') or oyun.sokak_katilimci_mi(x.id,u,'iktidar') or exists(select 1 from oyun.sokak_gorevli where eylem_id=x.id and user_id=u and ayrilma is null) or oyun.sokak_yonetebilir(u)) then
  raise exception 'Festivale yalnız eyleme taraf olmayan oyuncular gider'; end if;
 if p_tur='festival_ayril' and not exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=td.id and user_id=u and tur='festival' and (bitis is null or bitis>t)) then raise exception 'Festivalde değilsin'; end if;
 if p_tur='dernek_davet' then
  select d.id into did from oyun.dernekler d where d.baskan=u and not d.kapali and (d.merkez_il=x.il_id or exists(select 1 from oyun.dernek_sube s where s.dernek_id=d.id and s.il_id=x.il_id)) limit 1;
  if did is null then raise exception 'Bu ilde şubesi olan bir derneğin başkanı olmalısın'; end if;
 end if;
 if p_tur='istihdam_soz' then
  if m is null or m!~'^[0-9]+$' then raise exception 'Söz vereceğin şirketi seç'; end if;
  if not exists(select 1 from jsonb_array_elements(oyun.sokak_il_sirketleri(x.il_id,u)) j where j->>'id'=m) then raise exception 'Bu ilde söz verebileceğin şirket yok'; end if;
 end if;

 if p_tur='festival_ayril' then
  update oyun.sokak_tedbir_hamle set bitis=t where tedbir_id=td.id and user_id=u and tur='festival' and (bitis is null or bitis>t);
  perform oyun.sokak_yenile(x.id);
  return jsonb_build_object('tamam',true);
 end if;
 if p_tur='dayat' then
  update oyun.sokak_tedbir set durum='dayatma',bitis=t+interval '12 hours' where id=td.id;
  insert into oyun.sokak_tedbir_hamle(tedbir_id,eylem_id,user_id,tur,zaman,bitis) values(td.id,x.id,u,'dayat',t,t+interval '12 hours');
  perform oyun.sokak_yenile(x.id); perform oyun.sokak_duyur(x.id,'Güzergâh dayatıldı. Eylem gücü düşmez; inat artar. Ekonomi kalkanı yok.');
  return jsonb_build_object('tamam',true);
 end if;
 if p_tur='kart_iade' then
  update oyun.cuzdan set para=para-4000 where user_id=u and para>=4000;
  if not found then raise exception 'Kartı iade etmek için cüzdanda 4.000 TL olmalı'; end if;
  insert into oyun.hesap_hareket(user_id,zaman,tutar,vergi,tur,aciklama) values(u,t,-4000,0,'gider','Sosyal destek kartı iadesi, eylem #'||x.id);
  perform oyun.bm_neden('gelir','Sosyal destek kartı iadesi, eylem #'||x.id);
  update oyun.bakanlik_kasa set kasa=kasa+(4000/oyun.pazar_tl_milyar()) where kod='icisleri';
  perform oyun.bm_neden(null,null);
  insert into oyun.sokak_tedbir_hamle(tedbir_id,eylem_id,user_id,tur,sayi,zaman) values(td.id,x.id,u,'kart_iade',4000,t);
  perform oyun.sokak_yenile(x.id);
  return jsonb_build_object('tamam',true);
 end if;
 if p_tur in ('kapi_iktidar','kapi_muhalefet') then
  update oyun.partiler set kasa=kasa-8000 where id=me.parti_id and kasa>=8000;
  if not found then raise exception 'Parti kasasında 8.000 TL yok'; end if;
  insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(me.parti_id,t,-8000,'gider','Eylem #'||x.id||' kapı kapı');
  select gb into gb from oyun.partiler where id=me.parti_id;
  if gb is not null and gb<>u then perform oyun.bildir(gb,oyun.kad(u)||' eylem #'||x.id||' için parti kasasından 8.000 TL kapı kapı harcadı.'); end if;
 end if;

 insert into oyun.sokak_tedbir_hamle(tedbir_id,eylem_id,user_id,tur,metin,zaman,bitis)
  values(td.id,x.id,u,p_tur,m,t,case when p_tur in ('kapi_iktidar','kapi_muhalefet') then t+interval '6 hours' when p_tur='festival' then td.bitis else td.bitis end);

 if p_tur='yetersiz' then
  select count(distinct p.id) into n from oyun.sokak_eylem_destek d join oyun.profiller p on p.id=d.temsilci
   where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and not p.yasakli;
  if not exists(select 1 from oyun.sokak_eylem_destek where eylem_id=x.id and temsilci=x.baslatan and destekci_tur='oyuncu' and destek_turu='katilim' and taraf='muhalefet') then n:=n+1; end if;
  select count(*) into evet from oyun.sokak_tedbir_hamle where tedbir_id=td.id and tur='yetersiz';
  if evet>n/2 then
   if td.tur='hizmet' then
    update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-coalesce((td.etki->>'artis')::numeric,0)) where il_id=x.il_id;
   end if;
   update oyun.sokak_tedbir set durum='yetersiz' where id=td.id;
   perform oyun.sokak_duyur(x.id,oyun.sokak_tedbir_ad(td.tur)||' yetersiz bulundu. Sakinleşme kalktı'||case when td.tur='hizmet' then '; hizmet artışı geri alındı. Söz 24 saat sonra ölçülür.' else '; vergi indirimi sürer, sakinleşme biter.' end);
  end if;
 elsif p_tur in ('guzergah_kabul','guzergah_ret') then
  select count(distinct p.id) into n from oyun.sokak_eylem_destek d join oyun.profiller p on p.id=d.temsilci
   where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and not p.yasakli;
  if not exists(select 1 from oyun.sokak_eylem_destek where eylem_id=x.id and temsilci=x.baslatan and destekci_tur='oyuncu' and destek_turu='katilim' and taraf='muhalefet') then n:=n+1; end if;
  select count(*) filter(where tur='guzergah_kabul'),count(*) filter(where tur='guzergah_ret') into evet,ret from oyun.sokak_tedbir_hamle where tedbir_id=td.id;
  if evet>n/2 then
   update oyun.sokak_tedbir set durum='kabul',bitis=t+interval '24 hours',etki=etki||jsonb_build_object('duzen',5) where id=td.id;
   perform oyun.sokak_duyur(x.id,'Güzergâh kabul edildi. Eylemin gücü aynı kalır, düzen +5. Bu ilin kırmızı ekonomik hasarı 24 saat sayılmaz.');
  elsif ret>=ceil(n/2.0) then
   update oyun.sokak_tedbir set durum='ret',bitis=t+interval '12 hours' where id=td.id;
   perform oyun.sokak_duyur(x.id,'Güzergâh reddedildi. İnat +5. Hükümet dayatırsa inat +8 olur ve ekonomi kalkanı açılmaz.');
  end if;
 elsif p_tur='gozlemci' and not exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=td.id and tur='gozlemci' and user_id<>u) then
  update oyun.sokak_tedbir set bitis=t+interval '12 hours' where id=td.id;
  perform oyun.sokak_duyur(x.id,'Avukat '||oyun.kad(u)||' gözlemci oldu. 12 saat polis sevki ve barikat kapalı.');
 elsif p_tur='gozlemci_ret' then
  if exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=td.id and tur='gozlemci') then raise exception 'Gözlemciler göreve başladı; protokol artık reddedilemez'; end if;
  update oyun.sokak_tedbir set durum='ret' where id=td.id;
  perform oyun.sokak_duyur(x.id,'Organizatör gözlemci protokolünü reddetti. Polis yasağı başlamadı.');
 elsif p_tur='komisyon_devral' then
  if not exists(select 1 from oyun.sokak_tedbir_hamle where tedbir_id=td.id and user_id=u and tur='komisyon_muhalefet') then raise exception 'Devralmak için önce komisyona katıl'; end if;
  select count(*) filter(where tur='komisyon_muhalefet'),count(*) filter(where tur='komisyon_iktidar') into opp,ikt from oyun.sokak_tedbir_hamle where tedbir_id=td.id;
  if not (opp>ikt and opp>=2) then raise exception 'Devralmak için muhalefet vekili iktidardan çok olmalı ve en az 2 olmalı'; end if;
  yazi:=oyun.sokak_talep_kismi(x.id);
  update oyun.sokak_tedbir set durum='aleyhe',bitis=t+interval '6 hours' where id=td.id;
  perform oyun.sokak_duyur(x.id,'Muhalefet komisyonu devraldı. Talep kısmen uygulandı: '||yazi||'.');
 elsif p_tur='istihdam_grev' then
  geri:=round(coalesce((td.etki->>'dusen')::numeric,0)/2,2);
  update oyun.ulke set issizlik=least(40,issizlik+geri) where id=1;
  update oyun.sokak_tedbir set etki=etki||jsonb_build_object('grev',true,'geri',geri) where id=td.id;
  update oyun.sokak_eylem set grev_bitis=greatest(coalesce(grev_bitis,t),t+interval '12 hours') where id=x.id;
  perform oyun.sokak_duyur(x.id,'Organizatör istihdam paketine karşı grev çağırdı. İşsizlik indiriminin yarısı geri geldi. Katılımcılar greve katılabilir.');
 elsif p_tur='istihdam_soz' then
  perform oyun.sokak_duyur(x.id,oyun.kad(u)||' şirket #'||m||' adına istihdam sözü verdi.');
 elsif p_tur='kart_cagri' then
  insert into oyun.bildirimler(user_id,zaman,metin)
   select h.user_id,t,'Organizatör eylem #'||x.id||' sosyal kartını reddetmeni istiyor. Kartı 12 saat içinde iade edebilirsin; mesaj ve oy hakkın durmaz.'
   from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='kart';
 elsif p_tur='otobus' then
  insert into oyun.bildirimler(user_id,zaman,metin)
   select p.id,t,oyun.kad(u)||' eylem #'||x.id||' için yüz yüze miting otobüsü kaldırdı. İletişim yavaş olsa da meydana gelebilirsin.'
   from oyun.profiller p where p.il_id=x.il_id and p.id<>u and not p.yasakli and p.son_gorulme>t-interval '3 days'
    and not oyun.sokak_katilimci_mi(x.id,p.id,'muhalefet')
   order by p.son_gorulme desc limit 8;
 elsif p_tur='dernek_davet' then
  insert into oyun.bildirimler(user_id,zaman,metin)
   select uy.user_id,t,'Derneğin eylem #'||x.id||' için yüz yüze çağrı yaptı. İletişim yavaşlatma bu daveti kesmez.'
   from oyun.dernek_uyeler uy where uy.dernek_id=did and uy.user_id<>u limit 40;
 elsif p_tur='festival' then
  delete from oyun.sokak_nabiz where eylem_id=x.id and user_id=u;
 elsif p_tur='basin_karsi' then
  perform oyun.sokak_basina_yaz(x.id,'Karşı brifing, eylem #'||x.id||': '||left(m,220));
  perform oyun.sokak_duyur(x.id,'Muhalif basın karşı brifing yazdı. Brifingin nabız etkisi tersine döndü.');
 elsif p_tur='basin_hukumet' then
  perform oyun.sokak_duyur(x.id,'Basından '||oyun.kad(u)||' hükümet brifingine katıldı.');
 end if;

 perform oyun.sokak_yenile(x.id);
 perform oyun.sokak_kriz_kontrol();
 return jsonb_build_object('tamam',true,'tur',p_tur);
end $$;

-- ───────────── panel ─────────────
create or replace function public.sokak_tedbir_panel() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); me oyun.profiller; arr jsonb;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into me from oyun.profiller where id=u;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',e.id,
  'talep',(select tur from oyun.sokak_talep where eylem_id=e.id),
  'yonetebilir',oyun.sokak_yonetebilir(u),
  'katilimci',oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u,
  'organizator',e.baslatan=u,
  'avukat',exists(select 1 from oyun.avukat_ruhsat where user_id=u and durum='aktif'),
  'vekil',oyun.sokak_vekil(u),
  'gazeteci',oyun.sokak_gazeteci(u),
  'iktidar',oyun.sokak_iktidar(u),
  'parti',me.parti_id is not null,
  'dernekci',exists(select 1 from oyun.dernekler d where d.baskan=u and not d.kapali and (d.merkez_il=e.il_id or exists(select 1 from oyun.dernek_sube s where s.dernek_id=d.id and s.il_id=e.il_id))),
  'gorevli',exists(select 1 from oyun.sokak_gorevli g where g.eylem_id=e.id and g.user_id=u and g.ayrilma is null),
  'sirketler',oyun.sokak_il_sirketleri(e.il_id,u),
  'kapi_uye',8000,
  'bedeller',(select jsonb_object_agg(k,oyun.sokak_tedbir_bedel(e.id,k)) from unnest(array['hizmet','vergi_tatil','istihdam','brifing','sosyal_kart','guzergah','komisyon','gozlemci','kapi','gece','iletisim','festival']) k),
  'acabilir',case when oyun.sokak_yonetebilir(u) and not oyun.sokak_katilimci_mi(e.id,u,'muhalefet') and not exists(select 1 from oyun.sokak_soz where eylem_id=e.id and durum='takip') then (
    select coalesce(jsonb_agg(k),'[]'::jsonb) from unnest(array['hizmet','vergi_tatil','istihdam','brifing','sosyal_kart','guzergah','komisyon','gozlemci','kapi','gece','iletisim','festival']) k
    where (k not in ('hizmet','vergi_tatil','istihdam') or (select tur from oyun.sokak_talep where eylem_id=e.id) = case k when 'hizmet' then 'hizmet' when 'vergi_tatil' then 'vergi' else 'issizlik' end)
     and not exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=k and td.durum='aktif' and td.bitis>t)
     and not (k in ('hizmet','vergi_tatil','istihdam','sosyal_kart','guzergah','komisyon','gozlemci') and exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=k))
     and not (k='brifing' and exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=k and td.zaman>t-interval '12 hours'))
     and not (k='kapi' and exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=k and td.zaman>t-interval '12 hours'))
     and not (k='gece' and exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=k and td.zaman>t-interval '48 hours'))
     and not (k='iletisim' and exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=k and td.zaman>t-interval '24 hours'))
     and not (k='festival' and exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=k and td.zaman>t-interval '24 hours'))
     and (select count(*) from oyun.sokak_tedbir td where td.eylem_id=e.id and td.zaman>t-interval '12 hours')<3
  ) else '[]'::jsonb end,
  'tedbirler',coalesce((select jsonb_agg(jsonb_build_object(
    'id',td.id,'tur',td.tur,'ad',oyun.sokak_tedbir_ad(td.tur),'durum',td.durum,'bitis',td.bitis,'bedel',td.bedel,'gerekce',td.gerekce,'ceza',td.ceza,
    'ozet',jsonb_build_object(
     'yetersiz',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='yetersiz'),
     'kabul',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='guzergah_kabul'),
     'ret',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='guzergah_ret'),
     'iktidar_vekil',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='komisyon_iktidar'),
     'muhalefet_vekil',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='komisyon_muhalefet'),
     'gozlemci',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='gozlemci'),
     'soz',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='istihdam_soz'),
     'kart',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='kart'),
     'iade',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='kart_iade'),
     'festival',(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='festival' and (h.bitis is null or h.bitis>t))),
    'karsi',(
     select coalesce(jsonb_agg(h),'[]'::jsonb) from unnest(array[
      case when td.tur in ('hizmet','vergi_tatil') and td.durum='aktif' and (td.etki->>'oy_sonu')::timestamptz>t and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='yetersiz') then 'yetersiz' end,
      case when td.tur='brifing' and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='ikna_olmadim') then 'ikna_olmadim' end,
      case when td.tur='brifing' and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='slogan') then 'slogan' end,
      case when td.tur='brifing' and oyun.sokak_gazeteci(u) and not oyun.sokak_katilimci_mi(e.id,u,'muhalefet') and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='basin_hukumet') then 'basin_hukumet' end,
      case when td.tur='brifing' and oyun.sokak_gazeteci(u) and not oyun.sokak_iktidar(u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='basin_karsi') then 'basin_karsi' end,
      case when td.tur='sosyal_kart' and e.baslatan=u and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='kart_cagri') then 'kart_cagri' end,
      case when td.tur='sosyal_kart' and exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='kart') and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='kart_iade') then 'kart_iade' end,
      case when td.tur='guzergah' and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur in ('guzergah_kabul','guzergah_ret')) then 'guzergah_kabul' end,
      case when td.tur='guzergah' and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur in ('guzergah_kabul','guzergah_ret')) then 'guzergah_ret' end,
      case when td.tur='guzergah' and td.durum in ('aktif','ret') and oyun.sokak_yonetebilir(u) then 'dayat' end,
      case when td.tur='komisyon' and oyun.sokak_vekil(u)='iktidar' and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='komisyon_iktidar') then 'komisyon_iktidar' end,
      case when td.tur='komisyon' and oyun.sokak_vekil(u)='muhalefet' and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='komisyon_muhalefet') then 'komisyon_muhalefet' end,
      case when td.tur='komisyon' and oyun.sokak_vekil(u)='muhalefet' and exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='komisyon_muhalefet')
        and (select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='komisyon_muhalefet')>(select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='komisyon_iktidar')
        and (select count(*) from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='komisyon_muhalefet')>=2 then 'komisyon_devral' end,
      case when td.tur='gozlemci' and exists(select 1 from oyun.avukat_ruhsat r where r.user_id=u and r.durum='aktif') and not oyun.sokak_yonetebilir(u) and not oyun.sokak_katilimci_mi(e.id,u,'muhalefet') and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='gozlemci') then 'gozlemci' end,
      case when td.tur='gozlemci' and e.baslatan=u and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='gozlemci') then 'gozlemci_ret' end,
      case when td.tur='kapi' and oyun.sokak_iktidar(u) and me.parti_id is not null and not oyun.sokak_iletisim_kapali(e.id) then 'kapi_iktidar' end,
      case when td.tur='kapi' and not oyun.sokak_iktidar(u) and me.parti_id is not null and not oyun.sokak_iletisim_kapali(e.id) then 'kapi_muhalefet' end,
      case when td.tur='istihdam' and e.baslatan=u and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.tur='istihdam_grev') then 'istihdam_grev' end,
      case when td.tur='istihdam' and jsonb_array_length(oyun.sokak_il_sirketleri(e.il_id,u))>0 and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='istihdam_soz') then 'istihdam_soz' end,
      case when td.tur='iletisim' and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='otobus') then 'otobus' end,
      case when td.tur='iletisim' and exists(select 1 from oyun.dernekler d where d.baskan=u and not d.kapali and (d.merkez_il=e.il_id or exists(select 1 from oyun.dernek_sube s where s.dernek_id=d.id and s.il_id=e.il_id))) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='dernek_davet') then 'dernek_davet' end,
      case when td.tur='festival' and not oyun.sokak_katilimci_mi(e.id,u,'muhalefet') and not oyun.sokak_katilimci_mi(e.id,u,'iktidar') and not oyun.sokak_yonetebilir(u) and not exists(select 1 from oyun.sokak_gorevli g where g.eylem_id=e.id and g.user_id=u and g.ayrilma is null) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='festival' and (h.bitis is null or h.bitis>t)) then 'festival' end,
      case when td.tur='festival' and exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='festival' and (h.bitis is null or h.bitis>t)) then 'festival_ayril' end,
      case when td.tur='festival' and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='sahne') then 'sahne' end,
      case when td.tur='gece' and (oyun.sokak_katilimci_mi(e.id,u,'muhalefet') or e.baslatan=u) and not exists(select 1 from oyun.sokak_tedbir_hamle h where h.tedbir_id=td.id and h.user_id=u and h.tur='kisit_itiraz') then 'kisit_itiraz' end
     ]) h where h is not null)
   ) order by td.zaman desc)
   from oyun.sokak_tedbir td where td.eylem_id=e.id and (td.bitis>t or td.durum in ('aktif','yetersiz') or td.zaman>t-interval '36 hours')),'[]'::jsonb)
  ) order by e.id), '[]'::jsonb) into arr
 from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t;
 return jsonb_build_object('tamam',true,'yonetebilir',oyun.sokak_yonetebilir(u),
  'kural','On iki araç da bedelli. Sert olanın memnuniyet, basın veya inat bedeli var. Eylemciler her birine karşı hamle yapabilir. Mesajlaşma ve seçim oyu kapanmaz.',
  'eylemler',arr);
end $$;

-- ───────────── mevcut motora bağla ─────────────
do $$
declare s text;
begin
 s:=pg_get_functiondef('oyun.sokak_saha_dokum(bigint)'::regprocedure);
 if position('sokak_tedbir_agirlik' in s)=0 then
  if position('p_jest numeric:=0;' in s)=0 or position('s:=least(100,greatest(0,50+50*(d-k)::numeric/(d+k+4)-sert/4));' in s)=0 then
   raise exception 'Güç dökümü çapası bulunamadı'; end if;
  s:=replace(s,'p_jest numeric:=0;','p_jest numeric:=0; p_tedbir numeric:=0; ag jsonb;');
  s:=replace(s,'s:=least(100,greatest(0,50+50*(d-k)::numeric/(d+k+4)-sert/4));',
   $p$ag:=oyun.sokak_tedbir_agirlik(e); d:=d+coalesce((ag->>'destek')::integer,0); k:=k+coalesce((ag->>'karsi')::integer,0); p_tedbir:=coalesce((ag->>'puan')::numeric,0);
 s:=least(100,greatest(0,50+50*(d-k)::numeric/(d+k+4)-sert/4));$p$);
  s:=replace(s,'p_heyet+p_yasak+p_jest)) end;','p_heyet+p_yasak+p_jest+p_tedbir)) end;');
  s:=replace(s,$j$jsonb_build_object('ad','Gözaltı jesti','puan',p_jest)),$j$,$p$jsonb_build_object('ad','Gözaltı jesti','puan',p_jest)) || coalesce(ag->'satirlar','[]'::jsonb),$p$);
  execute s;
 end if;

 s:=pg_get_functiondef('oyun.sokak_yenile(bigint)'::regprocedure);
 if position('sokak_kirmizi_engel' in s)=0 then
  if position('kirmizi:=puan>=a.kirmizi_esik and n>=3;' in s)=0 then raise exception 'Kırmızı çapası bulunamadı'; end if;
  s:=replace(s,'kirmizi:=puan>=a.kirmizi_esik and n>=3;',
   'kirmizi:=puan>=a.kirmizi_esik and n>=3; if kirmizi and x.kirmizi_baslangic is null and oyun.sokak_kirmizi_engel(x.id) then kirmizi:=false; puan:=least(puan,a.kirmizi_esik-1); end if;');
  execute s;
 end if;

 s:=pg_get_functiondef('oyun.sokak_tick()'::regprocedure);
 if position('sokak_tedbir_tick' in s)=0 then
  if position('perform oyun.sokak_soz_tick();' in s)=0 then raise exception 'Sokak tick çapası bulunamadı'; end if;
  s:=replace(s,'perform oyun.sokak_soz_tick();','perform oyun.sokak_tedbir_tick(); perform oyun.sokak_soz_tick();');
  s:=replace(s,'select count(*) into n from oyun.sokak_eylem where durum=''aktif'' and kirmizi_baslangic is not null and bitis>t;',
   'select count(*) into n from oyun.sokak_eylem e where e.durum=''aktif'' and e.kirmizi_baslangic is not null and e.bitis>t and not exists(select 1 from oyun.sokak_tedbir td where td.eylem_id=e.id and td.tur=''guzergah'' and td.durum=''kabul'' and td.bitis>t);');
  s:=replace(s,'update oyun.sokak_kriz set kirmizi_baslangic=coalesce(kirmizi_baslangic,t) where id=1 returning * into k;',
   'update oyun.sokak_kriz set kirmizi_baslangic=coalesce(kirmizi_baslangic, t - make_interval(hours => ivme_saat)), ivme_saat=case when kirmizi_baslangic is null then 0 else ivme_saat end where id=1 returning * into k;');
  execute s;
 end if;

 s:=pg_get_functiondef('public.sokak_destek(bigint,text,text,bigint,numeric)'::regprocedure);
 if position('sokak_gece_kapali' in s)=0 then
  if position('Valilik gösteri yasağı sürüyor' in s)=0 then raise exception 'Katılım çapası bulunamadı'; end if;
  s:=replace(s,'if p_taraf=''muhalefet'' and exists(select 1 from oyun.sokak_yasak where eylem_id=x.id and bitis>t) then raise exception ''Valilik gösteri yasağı sürüyor; yasak bitene kadar yeni katılım kapalı''; end if;',
   'if p_taraf=''muhalefet'' and exists(select 1 from oyun.sokak_yasak where eylem_id=x.id and bitis>t) then raise exception ''Valilik gösteri yasağı sürüyor; yasak bitene kadar yeni katılım kapalı''; end if;
  if oyun.sokak_gece_kapali(x.id) then raise exception ''Gece toplanma kısıtı: 22.00–06.00 arasında yeni katılım kapalı''; end if;');
  execute s;
 end if;

 s:=pg_get_functiondef('public.sokak_taktik_yap(bigint,text,text)'::regprocedure);
 if position('sokak_gece_kapali' in s)=0 then
  if position('Taktikleri yalnız eyleme katılan oyuncular uygular' in s)=0 then raise exception 'Taktik çapası bulunamadı'; end if;
  s:=replace(s,'if not oyun.sokak_katilimci_mi(x.id,u,''muhalefet'') then raise exception ''Taktikleri yalnız eyleme katılan oyuncular uygular'';end if;',
   $p$if not oyun.sokak_katilimci_mi(x.id,u,'muhalefet') then raise exception 'Taktikleri yalnız eyleme katılan oyuncular uygular';end if;
 if oyun.sokak_gece_kapali(x.id) then raise exception 'Gece toplanma kısıtı: 22.00–06.00 arasında taktik uygulanamaz'; end if;
 if p_tur='cagri' and oyun.sokak_iletisim_kapali(x.id) then raise exception 'İletişim yavaşlatma sürerken çağrı yapılamaz; miting otobüsü ve dernek daveti açık'; end if;
 if p_tur='barikat' and oyun.sokak_gozlemci_aktif(x.id) then raise exception 'Bağımsız gözlemciler varken barikat kurulamaz'; end if;$p$);
  execute s;
 end if;

 s:=pg_get_functiondef('public.sokak_nabiz_ver(bigint,integer)'::regprocedure);
 if position('sokak_iletisim_kapali' in s)=0 then
  if position('Cumhurbaşkanı ve İçişleri Bakanı oy veremez' in s)=0 then raise exception 'Nabız çapası bulunamadı'; end if;
  s:=replace(s,'if oyun.sokak_yonetebilir(u) then raise exception ''Kamuoyu nabzı tarafsız oyuncuların sesidir; Cumhurbaşkanı ve İçişleri Bakanı oy veremez'';end if;',
   $p$if oyun.sokak_yonetebilir(u) then raise exception 'Kamuoyu nabzı tarafsız oyuncuların sesidir; Cumhurbaşkanı ve İçişleri Bakanı oy veremez';end if;
 if oyun.sokak_iletisim_kapali(x.id) then raise exception 'İletişim yavaşlatma sürerken kamuoyu nabzına oy verilemez. Mesaj ve seçim oyunun açık.'; end if;
 if p_tavir=1 and exists(select 1 from oyun.sokak_tedbir_hamle h join oyun.sokak_tedbir td on td.id=h.tedbir_id where td.eylem_id=x.id and td.tur='festival' and td.durum='aktif' and td.bitis>oyun.simdi() and h.user_id=u and h.tur='festival' and (h.bitis is null or h.bitis>oyun.simdi())) then raise exception 'Festivaldeyken eylemi destekleyen oy veremezsin; önce festivalden ayrıl'; end if;$p$);
  execute s;
 end if;

 s:=pg_get_functiondef('public.sokak_polis_gonder(bigint,text,text)'::regprocedure);
 if position('sokak_gozlemci_aktif' in s)=0 then
  if position('Uzlaşma takibi süresince polis müdahalesi yasak' in s)=0 then raise exception 'Polis çapası bulunamadı'; end if;
  s:=replace(s,'if exists(select 1 from oyun.sokak_soz where eylem_id=x.id and durum=''takip'') then raise exception ''Uzlaşma takibi süresince polis müdahalesi yasak'';end if;',
   'if exists(select 1 from oyun.sokak_soz where eylem_id=x.id and durum=''takip'') then raise exception ''Uzlaşma takibi süresince polis müdahalesi yasak'';end if;
 if oyun.sokak_gozlemci_aktif(x.id) then raise exception ''Bağımsız gözlemci protokolü sürerken polis sevki yapılamaz'';end if;');
  execute s;
 end if;

 s:=pg_get_functiondef('public.sokak_butce_mudahale(bigint,numeric,text)'::regprocedure);
 if position('sokak_gozlemci_ceza' in s)=0 then
  if position('bütçeli müdahale' in s)=0 then raise exception 'Bütçe çapası bulunamadı'; end if;
  s:=replace(s,'perform oyun.bm_kasa_harca(''icisleri'',p_tutar/oyun.pazar_tl_milyar(),''gider'',''Halk hareketi #''||x.id||'' / bütçeli müdahale / ''||p_tutar||'' TL'');',
   'perform oyun.sokak_gozlemci_ceza(x.id,u,''bütçeli müdahale'');
 perform oyun.bm_kasa_harca(''icisleri'',p_tutar/oyun.pazar_tl_milyar(),''gider'',''Halk hareketi #''||x.id||'' / bütçeli müdahale / ''||p_tutar||'' TL'');');
  execute s;
 end if;

 s:=pg_get_functiondef('public.sokak_hukumet_karar(bigint,text,text,uuid)'::regprocedure);
 if position('sokak_gozlemci_ceza' in s)=0 then
  if position('tut:=oyun.sokak_karar_bedel' in s)=0 then raise exception 'Karar çapası bulunamadı'; end if;
  s:=replace(s,'tut:=oyun.sokak_karar_bedel','if p_tur in (''uyari'',''dagitma'',''yaptirim'') then perform oyun.sokak_gozlemci_ceza(x.id,u,p_tur); end if;
 tut:=oyun.sokak_karar_bedel');
  execute s;
 end if;

 s:=pg_get_functiondef('public.sokak_karsi_cagri(bigint)'::regprocedure);
 if position('sokak_iletisim_kapali' in s)=0 then
  if position('12 saatte bir karşı miting çağrısı yapılır' in s)=0 then raise exception 'Karşı çağrı çapası bulunamadı'; end if;
  s:=replace(s,'if x.karsi_cagri is not null and x.karsi_cagri>t-interval ''12 hours'' then raise exception ''Bu eylem için 12 saatte bir karşı miting çağrısı yapılır'';end if;',
   'if oyun.sokak_iletisim_kapali(x.id) then raise exception ''İletişim yavaşlatma sürerken karşı miting çağrısı yapılamaz'';end if;
 if x.karsi_cagri is not null and x.karsi_cagri>t-interval ''12 hours'' then raise exception ''Bu eylem için 12 saatte bir karşı miting çağrısı yapılır'';end if;');
  execute s;
 end if;
end $$;

revoke all on function oyun.sokak_tedbir_ad(text),oyun.sokak_tedbir_bedel(bigint,text),oyun.sokak_gece_kapali(bigint),oyun.sokak_iletisim_kapali(bigint),
 oyun.sokak_gozlemci_aktif(bigint),oyun.sokak_kirmizi_engel(bigint),oyun.sokak_gazeteci(uuid),oyun.sokak_vekil(uuid),oyun.sokak_il_sirketleri(integer,uuid),
 oyun.sokak_basina_yaz(bigint,text),oyun.sokak_talep_kismi(bigint),oyun.sokak_gozlemci_ceza(bigint,uuid,text),oyun.sokak_tedbir_agirlik(bigint),oyun.sokak_tedbir_tick(),
 public.sokak_tedbir_ac(bigint,text,text),public.sokak_tedbir_hamle(bigint,text,text),public.sokak_tedbir_panel()
 from public,anon,authenticated;
grant execute on function public.sokak_tedbir_ac(bigint,text,text),public.sokak_tedbir_hamle(bigint,text,text),public.sokak_tedbir_panel() to authenticated;
