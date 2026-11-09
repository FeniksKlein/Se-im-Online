-- =====================================================================
--  180 · HALK HAREKETLERİ 3.0 — YALNIZ GERÇEK OYUNCU, SAHA DİNAMİKLERİ,
--        İSTEDİĞİN AN AYRIL
--
--  ERCAN (09.11.2026):
--   "Eylemlere katılımda ve müdahalede sadece gerçek insanlar olsun,
--    NPC'ler olmasın. Eyleme katılan oyuncu istediği zaman eylemden
--    ayrılabilsin." + tek kişilik oyundaki yaratıcı eylem sisteminin
--    (İçişleri/CB araçları, eylemci dinamikleri) NPC'siz online uyarlaması.
--
--  KÖK NEDEN (canlı ölçüm 09.11): eylem gücünün çoğu paraydı (fon tek başına
--  60 puan; gerçek katılımcı en çok 28). İl memnuniyetsizliği sanal kalabalık
--  gibi puan ekliyordu. Polis sevki ve bütçeli müdahale sahada tek oyuncu
--  olmadan yalnız bütçeyle çalışıyordu. Katılımcının ayrılma yolu yoktu.
--
--  İLKE: Eylemi büyüten de durduran da yalnız gerçek oyuncunun yaptığı bir
--  şeydir. Her etki "Güç dökümü"nde satır satır görünür.
--
--  1) GÜÇ = gerçek katılımcı (34·ln(1+n)), n=0 ise 0. Para güç yazmaz;
--     fon yalnız süreyi uzatır (eskisi gibi).
--     Çarpan = 0,80 + memnuniyetsizlik·0,0015 + KAMUOYU·0,004 (0,80–1,35).
--     KAMUOYU NABZI: eyleme taraf olmayan her gerçek oyuncu "destekliyorum /
--     karşıyım" der; sempati bu oylardan çıkar, sertleşme onu aşındırır.
--  2) EYLEMCİ TAKTİKLERİ (her katılımcı, eylem başına 3 saatte bir):
--     ⛺ nöbet +2 (6 sa, en çok +10) · ✍️ pankart: kendi sloganını yazar
--     +1 (12 sa, en çok +6) · 🧍 duran insan +3 (6 sa, en çok +9; sertleşme
--     40 altındaysa) · 🧱 barikat +4 ama sertleşme +20 (6 sa, en çok +12) ·
--     📣 çağrı: ildeki/partisindeki 8 gerçek oyuncuya davet bildirimi
--     (doğrudan puan yok) · 🛑 greve katıl +1,5 (organizatör genel grev
--     çağrısı yaptıysa; 12 sa, en çok +15; her katılan ekonomiden yer).
--  3) DEVLETİN GERÇEK-KİŞİ ARAÇLARI:
--     🛡️ sahaya görevli olarak çık (CB, İçişleri Bakanı, aktif vali /
--     emniyet müdürü): her görevli −3 (en çok −15). Polis sevki ve bütçeli
--     müdahale sahada görevli ister; emri veren CB/Bakan sahaya kendiliğinden
--     çıkmış sayılır (mağazadaki eski uygulama da çalışsın). Her görevli en
--     çok 1 gözaltı; polis etkisi görevli sayısıyla büyür, bütçeyle değil.
--     🚧 valilik gösteri yasağı (ilin valisi ya da İçişleri/CB): 6 saat yeni
--     katılım kapalı; kalanlar inatlaşır (+3). 🕊️ gözaltı jesti: eylemdeki
--     tüm gözaltılar serbest, 6 saat −5. 🧓 arabulucu heyeti: CB 3'e kadar
--     gerçek oyuncuyu davet eder; kabul eden rapor yazar (12 sa −8).
--     📺 ulusa sesleniş: CB konuşur, oyuncular "ikna oldum / olmadım" der;
--     etki gerçek tepkilere göre ±12 (geri tepebilir). 🚩 karşı miting çağrısı:
--     CB ya da iktidar partisi GB'si üyeleri çağırır; karşı tarafta duran
--     her gerçek oyuncu −2 (en çok −14).
--  4) ŞAŞIRTICI AN: sahadaki vali / emniyet müdürü "kalkanı bırakır" —
--     görevden çıkıp eyleme katılır (kamuoyunda büyük ses; bakana bildirim).
--  5) AYRILMA: katılımcı (iki taraf da) ve görevli istediği an ayrılır.
--     Oy vermediği uzlaşma oylamasından da düşer; gözaltı (hukuk) sürer.
--     Aynı eyleme yeniden girmek için 1 saat beklenir.
--
--  Eski kayıtlar: geçmiş polis/bütçe satırları eski formülle sayılır
--  (gorevli_sayi boş). Oyuncu verisi silinmez; yalnız oyuncunun kendi
--  isteğiyle kendi katılım satırı kaldırılır ve günlüğe yazılır.
--  Kapatma: update oyun.sokak_eylem_ayar set aktif=false (tüm sistem).
-- =====================================================================

-- ───────────── tablolar ─────────────
create table if not exists oyun.sokak_gorevli(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 unvan text not null, katilma timestamptz not null, ayrilma timestamptz,
 otomatik boolean not null default false
);
create unique index if not exists sokak_gorevli_aktif on oyun.sokak_gorevli(eylem_id,user_id) where ayrilma is null;
create index if not exists sokak_gorevli_eylem on oyun.sokak_gorevli(eylem_id) where ayrilma is null;

create table if not exists oyun.sokak_ayrilma(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 rol text not null check(rol in ('katilimci','gorevli','karsi')),
 zaman timestamptz not null
);
create index if not exists sokak_ayrilma_kisi on oyun.sokak_ayrilma(eylem_id,user_id,zaman desc);

create table if not exists oyun.sokak_taktik(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 tur text not null check(tur in ('nobet','pankart','duran','barikat','cagri','grev')),
 metin text, zaman timestamptz not null, bitis timestamptz not null
);
create index if not exists sokak_taktik_eylem on oyun.sokak_taktik(eylem_id,bitis desc);
create index if not exists sokak_taktik_kisi on oyun.sokak_taktik(eylem_id,user_id,zaman desc);

create table if not exists oyun.sokak_nabiz(
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 tavir smallint not null check(tavir in (-1,1)),
 zaman timestamptz not null,
 primary key(eylem_id,user_id)
);

create table if not exists oyun.sokak_seslenis(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 yapan uuid not null references oyun.profiller,
 metin text not null, zaman timestamptz not null, bitis timestamptz not null
);
create index if not exists sokak_seslenis_eylem on oyun.sokak_seslenis(eylem_id,zaman desc);
create table if not exists oyun.sokak_seslenis_tepki(
 seslenis_id bigint not null references oyun.sokak_seslenis,
 user_id uuid not null references oyun.profiller,
 ikna boolean not null, zaman timestamptz not null,
 primary key(seslenis_id,user_id)
);

create table if not exists oyun.sokak_heyet(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 davet_eden uuid not null references oyun.profiller,
 user_id uuid not null references oyun.profiller,
 durum text not null default 'davet' check(durum in ('davet','kabul','ret')),
 rapor text, rapor_zaman timestamptz, zaman timestamptz not null,
 unique(eylem_id,user_id)
);

create table if not exists oyun.sokak_yasak(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 yapan uuid not null references oyun.profiller,
 unvan text not null, gerekce text not null, zaman timestamptz not null, bitis timestamptz not null
);
create table if not exists oyun.sokak_jest(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 yapan uuid not null references oyun.profiller,
 gerekce text not null, serbest integer not null default 0, zaman timestamptz not null, bitis timestamptz not null
);
create table if not exists oyun.sokak_kalkan(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 user_id uuid not null references oyun.profiller,
 unvan text not null, zaman timestamptz not null
);
create table if not exists oyun.sokak_cagri_log(
 eylem_id bigint not null references oyun.sokak_eylem,
 hedef uuid not null references oyun.profiller,
 cagiran uuid not null references oyun.profiller,
 zaman timestamptz not null
);
create index if not exists sokak_cagri_log_i on oyun.sokak_cagri_log(eylem_id,hedef,zaman desc);

alter table oyun.sokak_polis add column if not exists gorevli_sayi integer;
alter table oyun.sokak_butce_mudahale add column if not exists gorevli_sayi integer;
alter table oyun.sokak_eylem add column if not exists grev_bitis timestamptz;
alter table oyun.sokak_eylem add column if not exists karsi_cagri timestamptz;

do $$ declare tb text; begin
 foreach tb in array array['sokak_gorevli','sokak_ayrilma','sokak_taktik','sokak_nabiz','sokak_seslenis','sokak_seslenis_tepki','sokak_heyet','sokak_yasak','sokak_jest','sokak_kalkan','sokak_cagri_log'] loop
  execute format('alter table oyun.%I enable row level security',tb);
  execute format('revoke all on oyun.%I from public,anon,authenticated',tb);
 end loop;
end $$;

-- ───────────── yardımcılar ─────────────
create or replace function oyun.sokak_gorev_unvan(u uuid) returns text language sql stable set search_path='' as $$
 select coalesce(
  (select case when m.tur='cb' then 'Cumhurbaşkanı' else 'İçişleri Bakanı' end from oyun.makamlar m
    where m.user_id=u and m.bit is null and (m.tur='cb' or m.tur='bakan' and m.bakanlik='icisleri')
    order by (m.tur='cb') desc limit 1),
  (select case when a.tur='vali' then (select ad from oyun.iller where id=a.il_id)||' Valisi'
               else (select ad from oyun.iller where id=a.il_id)||' Emniyet Müdürü' end
    from oyun.icisleri_atama a where a.hedef=u and a.durum='aktif' and (a.bitis is null or a.bitis>oyun.simdi()) limit 1))
$$;
create or replace function oyun.sokak_gorevli_sayi(e bigint) returns integer language sql stable set search_path='' as $$
 select count(*)::integer from oyun.sokak_gorevli g join oyun.profiller p on p.id=g.user_id
 where g.eylem_id=e and g.ayrilma is null and not p.yasakli and oyun.sokak_gorev_unvan(g.user_id) is not null
$$;
create or replace function oyun.sokak_yeniden_giris(e bigint,u uuid) returns timestamptz language sql stable set search_path='' as $$
 select max(zaman)+interval '1 hour' from oyun.sokak_ayrilma where eylem_id=e and user_id=u having max(zaman)+interval '1 hour'>oyun.simdi()
$$;
create or replace function oyun.sokak_katilimci_mi(e bigint,u uuid,p_taraf text default 'muhalefet') returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_eylem_destek where eylem_id=e and destekci_tur='oyuncu' and destekci_id=u::text and destek_turu='katilim' and taraf=p_taraf)
$$;
-- Emri veren CB / İçişleri Bakanı sahaya kendiliğinden çıkar (gerçek kişi; eski uygulama uyumu)
create or replace function oyun.sokak_gorevli_ekle(e bigint,u uuid,p_oto boolean) returns void language plpgsql set search_path='' as $$
declare un text:=oyun.sokak_gorev_unvan(u);
begin
 if un is null or oyun.sokak_katilimci_mi(e,u,'muhalefet') or oyun.sokak_katilimci_mi(e,u,'iktidar') then return; end if;
 insert into oyun.sokak_gorevli(eylem_id,user_id,unvan,katilma,otomatik) values(e,u,un,oyun.simdi(),p_oto) on conflict do nothing;
end $$;

-- GÜÇ DÖKÜMÜ: her satır gerçek bir oyuncu eyleminden gelir
create or replace function oyun.sokak_saha_dokum(e bigint) returns jsonb language plpgsql stable set search_path='' as $$
declare x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
 n integer; karsi integer; g integer; d integer; k integer; s numeric; mem numeric; sert numeric; carpan numeric; temel numeric;
 nobet integer; pankart integer; duran integer; barikat integer; grev integer;
 p_taktik numeric; p_karsi numeric; p_gorevli numeric; p_karar numeric; p_seslenis numeric:=0; p_heyet numeric:=0; p_yasak numeric:=0; p_jest numeric:=0;
 ss oyun.sokak_seslenis; v_ikna integer:=0; v_olmadi integer:=0; toplam numeric;
begin
 select * into x from oyun.sokak_eylem where id=e;
 if x.id is null then return null; end if;
 select count(distinct p.id) into n from oyun.sokak_eylem_destek dd join oyun.profiller p on p.id=dd.temsilci
  where dd.eylem_id=e and dd.destekci_tur='oyuncu' and dd.destek_turu='katilim' and dd.taraf='muhalefet'
  and not oyun.sokak_yaptirimli(p.id,e) and not p.yasakli and p.olusturma<t-interval '3 days' and p.son_gorulme>t-interval '14 days';
 select count(distinct p.id) into karsi from oyun.sokak_eylem_destek dd join oyun.profiller p on p.id=dd.temsilci
  where dd.eylem_id=e and dd.destekci_tur='oyuncu' and dd.destek_turu='katilim' and dd.taraf='iktidar'
  and not p.yasakli and p.olusturma<t-interval '3 days' and p.son_gorulme>t-interval '14 days';
 g:=oyun.sokak_gorevli_sayi(e);
 select count(*) filter(where tavir=1),count(*) filter(where tavir=-1) into d,k
  from oyun.sokak_nabiz nb join oyun.profiller p on p.id=nb.user_id where nb.eylem_id=e and not p.yasakli;
 select count(distinct user_id) filter(where tur='nobet'),count(distinct user_id) filter(where tur='pankart'),
        count(distinct user_id) filter(where tur='duran'),count(distinct user_id) filter(where tur='barikat'),
        count(distinct user_id) filter(where tur='grev')
   into nobet,pankart,duran,barikat,grev
  from oyun.sokak_taktik where eylem_id=e and bitis>t;
 sert:=least(100,20*barikat);
 s:=least(100,greatest(0,50+50*(d-k)::numeric/(d+k+4)-sert/4));
 mem:=least(100,greatest(0,oyun.sokak_memnuniyetsizlik(x.il_id)));
 carpan:=round(0.80+mem*0.0015+s*0.004,3);
 temel:=case when n=0 then 0 else least(95,34*ln(1+n)) end;
 p_taktik:=least(10,2*nobet)+least(6,pankart)+case when sert<40 then least(9,3*duran) else 0 end+least(12,4*barikat)
           +case when x.grev_bitis>t then least(15,1.5*grev) else 0 end;
 p_karsi:=-least(14,2*karsi);
 p_gorevli:=-least(15,3*g);
 p_karar:=oyun.sokak_karar_etki(e);
 select * into ss from oyun.sokak_seslenis where eylem_id=e and bitis>t order by zaman desc limit 1;
 if ss.id is not null then
  select count(*) filter(where q.ikna),count(*) filter(where not q.ikna) into v_ikna,v_olmadi from oyun.sokak_seslenis_tepki q where q.seslenis_id=ss.id;
  p_seslenis:=-least(12,greatest(-12,(v_ikna-v_olmadi)*1.5));
 end if;
 if exists(select 1 from oyun.sokak_heyet where eylem_id=e and durum='kabul' and rapor_zaman>t-interval '12 hours') then p_heyet:=-8; end if;
 if exists(select 1 from oyun.sokak_yasak where eylem_id=e and bitis>t) then p_yasak:=3; end if;
 if exists(select 1 from oyun.sokak_jest where eylem_id=e and bitis>t) then p_jest:=-5; end if;
 toplam:=case when n=0 then 0 else least(100,greatest(0,temel*carpan+p_taktik+p_karsi+p_gorevli+p_karar+p_seslenis+p_heyet+p_yasak+p_jest)) end;
 return jsonb_build_object(
  'katilimci',n,'karsi',karsi,'gorevli',g,'destek',d,'karsi_nabiz',k,'sempati',round(s,1),'sertlesme',sert,
  'memnuniyetsizlik',mem,'carpan',carpan,'temel',round(temel,1),
  'nobet',nobet,'pankart',pankart,'duran',duran,'barikat',barikat,'grev',grev,
  'satirlar',jsonb_build_array(
    jsonb_build_object('ad','Gerçek katılımcı ('||n||' kişi) × kamuoyu çarpanı '||carpan,'puan',round(temel*carpan,1)),
    jsonb_build_object('ad','Eylemci taktikleri (nöbet, pankart, duran insan, barikat, grev)','puan',round(p_taktik,1)),
    jsonb_build_object('ad','Karşı tarafta duran oyuncular ('||karsi||')','puan',round(p_karsi,1)),
    jsonb_build_object('ad','Sahadaki görevliler ('||g||')','puan',round(p_gorevli,1)),
    jsonb_build_object('ad','Hükümet kararları ve polis','puan',round(p_karar,1)),
    jsonb_build_object('ad','Ulusa sesleniş tepkisi ('||v_ikna||' ikna · '||v_olmadi||' olmadı)','puan',round(p_seslenis,1)),
    jsonb_build_object('ad','Arabulucu heyeti raporu','puan',p_heyet),
    jsonb_build_object('ad','Valilik yasağına rağmen inat','puan',p_yasak),
    jsonb_build_object('ad','Gözaltı jesti','puan',p_jest)),
  'toplam',round(toplam,1));
end $$;

-- GÜÇ: dökümün toplamı (yalnız gerçek oyuncu)
create or replace function oyun.sokak_yenile(p_id bigint) returns void language plpgsql set search_path='' as $$
declare x oyun.sokak_eylem; a oyun.sokak_eylem_ayar; t timestamptz:=oyun.simdi(); dk jsonb; n integer; puan numeric; kirmizi boolean;
begin
 select * into a from oyun.sokak_eylem_ayar where id=1;
 select * into x from oyun.sokak_eylem where id=p_id for update;
 if x.id is null or x.durum<>'aktif' then return;end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=p_id and durum='takip') then return;end if;
 if x.bitis<=t then
  update oyun.sokak_eylem set durum='bitti',kapandi=t,kirmizi_baslangic=null,seviye=0 where id=x.id;
  update oyun.sokak_gorevli set ayrilma=t where eylem_id=x.id and ayrilma is null;
  perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' süresi doldu. İl dinlenme süresine girdi.');return;
 end if;
 if x.iktidar_fonu>=x.muhalefet_fonu*a.sakinlestirme_carpani then
  update oyun.sokak_eylem set durum='yatisti',kapandi=t,kirmizi_baslangic=null,seviye=0 where id=x.id;
  update oyun.sokak_gorevli set ayrilma=t where eylem_id=x.id and ayrilma is null;
  perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' uzlaşma fonuyla yatıştı.');return;
 end if;
 dk:=oyun.sokak_saha_dokum(x.id);
 n:=(dk->>'katilimci')::integer; puan:=(dk->>'toplam')::numeric;
 kirmizi:=puan>=a.kirmizi_esik and n>=3;
 if not kirmizi then puan:=least(puan,a.kirmizi_esik-1);end if;
 update oyun.sokak_eylem set seviye=round(puan,1),
  kirmizi_baslangic=case when kirmizi then coalesce(kirmizi_baslangic,t) else null end where id=x.id;
 if kirmizi and x.kirmizi_baslangic is null then
   perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' kırmızı seviyeye ulaştı. Hükümetin yanıtı bekleniyor.');
 elsif not kirmizi and x.kirmizi_baslangic is not null then
   perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' kırmızı seviyeden çıktı; kriz sayacı sıfırlandı.');
 end if;
end $$;

create or replace function oyun.sokak_kriz_kontrol() returns void language sql set search_path='' as $$
 update oyun.sokak_kriz set kirmizi_baslangic=null where id=1
  and (select count(*) from oyun.sokak_eylem where durum='aktif' and bitis>oyun.simdi() and kirmizi_baslangic is not null)<3
$$;

-- Polis etkisi yeni kayıtlarda görevli sayısıyla; eskiler eski formülle
create or replace function oyun.sokak_karar_etki(e bigint) returns numeric language sql stable set search_path='' as $$
 select
 coalesce((select sum(case when k.tur='yonlendirme' and k.bitis>oyun.simdi() then -10
 when k.tur='uyari' and k.bitis>oyun.simdi() then -8
 when k.tur='uyari' and k.bitis+interval '18 hours'>oyun.simdi() then 6
 else 0 end) from oyun.sokak_karar k where k.eylem_id=e),0)
 +coalesce((select sum(case
 when p.geri_cekildi is not null and p.zaman+interval '24 hours'>oyun.simdi() then p.tepki/2
 when p.geri_cekildi is not null then 0
 when p.zaman+interval '3 hours'>oyun.simdi() then
   case when p.gorevli_sayi is not null then -least(25,6*p.gorevli_sayi)
        else -least(25,7*ln(1+p.bedel/greatest(1,a.baslatma_bedeli))) end
 when p.zaman+interval '24 hours'>oyun.simdi() then p.tepki else 0 end)
 from oyun.sokak_polis p cross join oyun.sokak_eylem_ayar a where a.id=1 and p.eylem_id=e),0)
 +coalesce((select sum(case
 when m.bitis>oyun.simdi() then -m.etki
 when m.bitis+interval '12 hours'>oyun.simdi() then m.tepki
 else 0 end)
 from oyun.sokak_butce_mudahale m where m.eylem_id=e),0)
$$;

-- ───────────── POLİS / BÜTÇE: sahadaki gerçek görevliyle ─────────────
create or replace function public.sokak_polis_gonder(p_eylem bigint, p_seviye text, p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; a oyun.sokak_eylem_ayar; t timestamptz:=oyun.simdi();
 tut numeric; kisi integer; hedef_sayisi integer; alinma integer:=0; rec record; pid bigint; ger numeric; g integer;
begin
 if u is null or not oyun.sokak_yonetebilir(u) then raise exception 'Yalnız Cumhurbaşkanı veya İçişleri Bakanı polis gönderebilir';end if;
 if p_seviye not in ('dusuk','orta','yuksek') then raise exception 'Geçersiz polis seviyesi';end if;
 if length(btrim(coalesce(p_gerekce,''))) not between 25 and 500 then raise exception 'Gerekçe 25-500 karakter olmalı';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into a from oyun.sokak_eylem_ayar where id=1;
 if not a.aktif then raise exception 'Halk hareketleri kapalı';end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif protesto gerekli';end if;
 if oyun.sokak_katilimci_mi(x.id,u,'muhalefet') then raise exception 'Bu eyleme katılımcısın; polis emri veremezsin';end if;
 if exists(select 1 from oyun.sokak_butce_mudahale where eylem_id=x.id and zaman>t-interval '6 hours') or exists(select 1 from oyun.sokak_karar where eylem_id=x.id and zaman>t-interval '6 hours')
 or exists(select 1 from oyun.sokak_polis where eylem_id=x.id and zaman>t-interval '6 hours')
 then raise exception 'Aynı protestoya 6 saat içinde ikinci müdahale yapılamaz';end if;
 if (select count(*) from oyun.sokak_karar where zaman>t-interval '24 hours')+
    (select count(*) from oyun.sokak_polis where zaman>t-interval '24 hours')+(select count(*) from oyun.sokak_butce_mudahale where zaman>t-interval '24 hours')>=4
 then raise exception 'Hükümetin 24 saatlik 4 müdahale hakkı doldu';end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=x.id and durum='takip') then raise exception 'Uzlaşma takibi süresince polis müdahalesi yasak';end if;
 -- Emri veren gerçek kişi sahaya çıkar; etkiyi sahadaki gerçek görevliler belirler.
 perform oyun.sokak_gorevli_ekle(x.id,u,true);
 g:=oyun.sokak_gorevli_sayi(x.id);
 if g<1 then raise exception 'Sahada gerçek görevli yok';end if;
 tut:=a.baslatma_bedeli*case p_seviye when 'dusuk' then 1 when 'orta' then 3 else 8 end;
 select count(*) into kisi from oyun.sokak_eylem_destek d join oyun.profiller p on p.id=d.temsilci
 where d.eylem_id=x.id and d.taraf='muhalefet' and d.destekci_tur='oyuncu' and d.destek_turu='katilim'
 and not p.yasakli and not oyun.sokak_yaptirimli(p.id,x.id);
 hedef_sayisi:=case when p_seviye='dusuk' or kisi<3 then 0
 when p_seviye='orta' then least(2,g,greatest(1,floor(kisi*.15)::integer))
 else least(4,g,greatest(1,floor(kisi*.25)::integer)) end;
 perform oyun.bm_kasa_harca('icisleri',tut/oyun.pazar_tl_milyar(),'gider','Polis sevki: eylem #'||x.id||', '||p_seviye||', '||tut||' TL');
 ger:=case p_seviye when 'dusuk' then 2 when 'orta' then 6 else 11 end;
 -- Duran insan eylemi sürerken müdahalenin kamuoyu bedeli iki katıdır.
 if exists(select 1 from oyun.sokak_taktik where eylem_id=x.id and tur='duran' and bitis>t) then ger:=ger*2; end if;
 insert into oyun.sokak_polis(eylem_id,yapan,seviye,gerekce,bedel,hedef_sayi,zaman,tepki,gorevli_sayi)
 values(x.id,u,p_seviye,btrim(p_gerekce),tut,hedef_sayisi,t,ger,g) returning id into pid;
 if hedef_sayisi>0 then
  for rec in select p.id from oyun.sokak_eylem_destek d
    join oyun.profiller p on p.id=d.temsilci
    where d.eylem_id=x.id and d.taraf='muhalefet' and d.destekci_tur='oyuncu'
      and d.destek_turu='katilim' and not p.yasakli
      and not oyun.sokak_yaptirimli(p.id,x.id)
      and not exists(select 1 from oyun.sokak_gozalti g2 where g2.hedef=p.id and g2.baslangic>t-interval '24 hours')
    order by random() + case when oyun.icisleri_korumali_v2(p.id) then 0.65 else 0 end limit hedef_sayisi
  loop
   insert into oyun.sokak_gozalti(polis_id,eylem_id,hedef,baslangic,bitis)
   values(pid,x.id,rec.id,t,t+interval '1 hour');
   perform oyun.bildir(rec.id,'Eylem #'||x.id||': oyun içi 1 saatlik gözaltına alındınız. Halk Hareketleri panelinde avukat çağırabilir ve mahkemeye itiraz edebilirsiniz. Oy, banka, şirket ve mesajlaşma haklarınız devam ediyor.');
   alinma:=alinma+1;
  end loop;
 end if;
 update oyun.sokak_polis set alinan_sayi=alinma where id=pid;
 update oyun.ulke set memnuniyet=greatest(0,memnuniyet-case p_seviye when 'dusuk' then .2 when 'orta' then .7 else 1.5 end) where id=1;
 update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-case p_seviye when 'dusuk' then .5 when 'orta' then 1.5 else 3 end) where il_id=x.il_id;
 perform oyun.sokak_yenile(x.id);
 perform oyun.sokak_duyur(x.id,'İçişleri polis sevki: '||p_seviye||' düzey, sahada '||g||' gerçek görevli, '||alinma||' kişi 1 saatlik oyun içi gözaltına alındı. Bütçe: '||tut||' TL. Gerekçe: '||left(p_gerekce,350));
 return jsonb_build_object('tamam',true,'polis_id',pid,'gozalti_sayisi',alinma,'katilimci',kisi,'gorevli',g,'bedel',tut);
end $$;

create or replace function public.sokak_butce_mudahale(p_eylem bigint, p_tutar numeric, p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; a oyun.sokak_eylem_ayar;
 t timestamptz:=oyun.simdi(); hesap numeric; etki numeric; tepki numeric; kayit bigint; g integer;
begin
 if u is null or not oyun.sokak_yonetebilir(u) then raise exception 'Yalnız Cumhurbaşkanı veya İçişleri Bakanı yetkilidir';end if;
 if p_tutar is null or p_tutar::text in ('NaN','Infinity','-Infinity') or p_tutar<>round(p_tutar,2) or p_tutar<=0
 then raise exception 'Geçerli TL tutarı girin';end if;
 if length(btrim(coalesce(p_gerekce,''))) not between 25 and 500 then raise exception '25-500 karakter somut gerekçe girin';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into a from oyun.sokak_eylem_ayar where id=1;
 if not a.aktif then raise exception 'Halk hareketleri kapalı';end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=x.id and durum='takip') then raise exception 'Uzlaşma sırasında müdahale yapılamaz';end if;
 if oyun.sokak_katilimci_mi(x.id,u,'muhalefet') then raise exception 'Bu eyleme katılımcısın; müdahale edemezsin';end if;
 hesap:=least(2000000,greatest(a.baslatma_bedeli, x.muhalefet_fonu*2, a.baslatma_bedeli*10));
 if p_tutar<a.baslatma_bedeli or p_tutar>hesap then raise exception 'Müdahale bütçesi % – % TL aralığında olmalı',a.baslatma_bedeli,hesap;end if;
 if exists(select 1 from oyun.sokak_karar where eylem_id=x.id and zaman>t-interval '6 hours')
  or exists(select 1 from oyun.sokak_polis where eylem_id=x.id and zaman>t-interval '6 hours')
  or exists(select 1 from oyun.sokak_butce_mudahale where eylem_id=x.id and zaman>t-interval '6 hours')
 then raise exception 'Aynı eylemde müdahaleler arasında 6 saat beklenir';end if;
 if (select count(*) from oyun.sokak_karar where zaman>t-interval '24 hours')
  +(select count(*) from oyun.sokak_polis where zaman>t-interval '24 hours')
  +(select count(*) from oyun.sokak_butce_mudahale where zaman>t-interval '24 hours')>=4
 then raise exception 'Hükümetin ülke çapında günlük 4 müdahale hakkı doldu';end if;
 perform oyun.sokak_gorevli_ekle(x.id,u,true);
 g:=oyun.sokak_gorevli_sayi(x.id);
 if g<1 then raise exception 'Sahada gerçek görevli yok';end if;
 -- Bütçe tek başına etki yazmaz: etki sahadaki görevli sayısıyla ölçeklenir (3 görevli = tam etki).
 etki:=round(oyun.sokak_butce_etkisi(p_tutar,x.muhalefet_fonu)*least(1,g/3.0),2);
 tepki:=oyun.sokak_butce_tepki(p_tutar);
 perform oyun.bm_kasa_harca('icisleri',p_tutar/oyun.pazar_tl_milyar(),'gider','Halk hareketi #'||x.id||' / bütçeli müdahale / '||p_tutar||' TL');
 insert into oyun.sokak_butce_mudahale(eylem_id,yapan,bedel,gerekce,etki,tepki,zaman,bitis,gorevli_sayi)
 values(x.id,u,p_tutar,btrim(p_gerekce),etki,tepki,t,t+interval '12 hours',g) returning id into kayit;
 perform oyun.sokak_yenile(x.id);
 perform oyun.sokak_duyur(x.id,'Hükümet eylem #'||x.id||' için sahadaki '||g||' görevliyle '||p_tutar||' TL bütçeli müdahale başlattı. Etki: -'||etki||' puan, sonraki kamuoyu tepkisi: +'||tepki||' puan. Gerekçe: '||left(p_gerekce,300));
 return jsonb_build_object('tamam',true,'id',kayit,'bedel',p_tutar,'etki',etki,'tepki',tepki,'gorevli',g);
end $$;

-- ───────────── katılım kuralları (sokak_destek'e çapalı ek) ─────────────
do $$
declare s text; eski text:=$q$ if p_tutar=0 then
$q$;
begin
 select pg_get_functiondef('public.sokak_destek(bigint,text,text,bigint,numeric)'::regprocedure) into s;
 if position('sokak_yeniden_giris' in s)=0 then
  if position(eski in s)=0 then raise exception '180: sokak_destek çapası bulunamadı'; end if;
  s:=replace(s,eski,$q$ if p_tutar=0 then
  if exists(select 1 from oyun.sokak_gorevli where eylem_id=x.id and user_id=u and ayrilma is null) then raise exception 'Bu eylemde görevlisin; önce görevden ayrılmalısın'; end if;
  if oyun.sokak_yeniden_giris(x.id,u) is not null then raise exception 'Bu eylemden yeni ayrıldın; yeniden katılmak için % saatini bekle',to_char(oyun.sokak_yeniden_giris(x.id,u) at time zone 'Europe/Istanbul','HH24:MI'); end if;
  if p_taraf='muhalefet' and exists(select 1 from oyun.sokak_yasak where eylem_id=x.id and bitis>t) then raise exception 'Valilik gösteri yasağı sürüyor; yasak bitene kadar yeni katılım kapalı'; end if;
$q$);
  execute s;
 end if;
end $$;

-- ───────────── AYRILMA ─────────────
create or replace function public.sokak_eylemden_ayril(p_eylem bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); n integer; oy_n integer; tr text;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null then raise exception 'Eylem bulunamadı';end if;
 select taraf into tr from oyun.sokak_eylem_destek where eylem_id=x.id and destekci_tur='oyuncu' and destekci_id=u::text and destek_turu='katilim' limit 1;
 delete from oyun.sokak_eylem_destek where eylem_id=x.id and destekci_tur='oyuncu' and destekci_id=u::text and destek_turu='katilim';
 get diagnostics n=row_count;
 if n=0 then raise exception 'Bu eyleme katılmıyorsun';end if;
 delete from oyun.sokak_soz_oy where eylem_id=x.id and user_id=u and oy is null;
 get diagnostics oy_n=row_count;
 -- Süren taktikleri sona erer (nöbetten kalkan nöbette sayılmaz)
 update oyun.sokak_taktik set bitis=t where eylem_id=x.id and user_id=u and bitis>t;
 insert into oyun.sokak_ayrilma(eylem_id,user_id,rol,zaman) values(x.id,u,case when tr='iktidar' then 'karsi' else 'katilimci' end,t);
 if x.durum='aktif' and x.bitis>t then perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol(); end if;
 return jsonb_build_object('tamam',true,'eylem_id',x.id,'taraf',tr,'oylamadan_cikti',oy_n>0,
  'yeniden_katilim',t+interval '1 hour',
  'gozalti_suruyor',exists(select 1 from oyun.sokak_gozalti where eylem_id=x.id and hedef=u and durum='aktif' and bitis>t));
end $$;

create or replace function public.sokak_goreve_cik(p_eylem bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); un text; g integer;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 un:=oyun.sokak_gorev_unvan(u);
 if un is null then raise exception 'Görevli olarak çıkmak için Cumhurbaşkanı, İçişleri Bakanı ya da aktif vali / emniyet müdürü olmalısın';end if;
 if (select yasakli from oyun.profiller where id=u) then raise exception 'Hesabın kısıtlı';end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if oyun.sokak_katilimci_mi(x.id,u,'muhalefet') or oyun.sokak_katilimci_mi(x.id,u,'iktidar') then
  raise exception 'Bu eylemde katılımcısın; görevli olmak için önce eylemden ayrılmalısın';end if;
 if exists(select 1 from oyun.sokak_gorevli where eylem_id=x.id and user_id=u and ayrilma is null) then raise exception 'Zaten sahadasın';end if;
 if oyun.sokak_yeniden_giris(x.id,u) is not null then raise exception 'Yeni ayrıldın; yeniden çıkmak için 1 saat bekle';end if;
 insert into oyun.sokak_gorevli(eylem_id,user_id,unvan,katilma) values(x.id,u,un,t);
 perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol();
 g:=oyun.sokak_gorevli_sayi(x.id);
 perform oyun.sokak_duyur(x.id,un||' '||oyun.kad(u)||' eylem #'||x.id||' alanında görev başında. Sahadaki görevli: '||g);
 return jsonb_build_object('tamam',true,'unvan',un,'gorevli',g);
end $$;

create or replace function public.sokak_gorevden_ayril(p_eylem bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); n integer; x oyun.sokak_eylem;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 update oyun.sokak_gorevli set ayrilma=t where eylem_id=p_eylem and user_id=u and ayrilma is null;
 get diagnostics n=row_count;
 if n=0 then raise exception 'Bu eylemde görevli değilsin';end if;
 insert into oyun.sokak_ayrilma(eylem_id,user_id,rol,zaman) values(p_eylem,u,'gorevli',t);
 if x.durum='aktif' and x.bitis>t then perform oyun.sokak_yenile(p_eylem); end if;
 return jsonb_build_object('tamam',true,'gorevli',oyun.sokak_gorevli_sayi(p_eylem));
end $$;

-- Karşı tarafta yer al (sükûnet / karşı miting); ayrılma aynı düğmeyle
create or replace function public.sokak_karsi_katil(p_eylem bigint) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 return public.sokak_destek(p_eylem,'iktidar','oyuncu',null,0);
end $$;

-- ───────────── EYLEMCİ TAKTİKLERİ ─────────────
create or replace function public.sokak_taktik_yap(p_eylem bigint,p_tur text,p_metin text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); son timestamptz; sure interval; m text; n integer:=0; kim record; me oyun.profiller; pay numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tur is null or p_tur not in ('nobet','pankart','duran','barikat','cagri','grev') then raise exception 'Geçersiz taktik';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into me from oyun.profiller where id=u;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if not oyun.sokak_katilimci_mi(x.id,u,'muhalefet') then raise exception 'Taktikleri yalnız eyleme katılan oyuncular uygular';end if;
 if oyun.sokak_yaptirimli(u,x.id) then raise exception 'Bu eylemde geçici yaptırımın var';end if;
 if exists(select 1 from oyun.sokak_gozalti where eylem_id=x.id and hedef=u and durum='aktif' and bitis>t) then raise exception 'Gözaltındayken sahada taktik uygulayamazsın';end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=x.id and durum='takip') then raise exception 'Eylem uzlaşma için askıda';end if;
 select max(zaman) into son from oyun.sokak_taktik where eylem_id=x.id and user_id=u;
 if son>t-interval '3 hours' then raise exception 'Bir sonraki taktik için % saatini bekle',to_char((son+interval '3 hours') at time zone 'Europe/Istanbul','HH24:MI');end if;
 sure:=case p_tur when 'pankart' then interval '12 hours' when 'grev' then interval '12 hours' when 'cagri' then interval '1 minute' else interval '6 hours' end;
 if p_tur='pankart' then
  m:=btrim(regexp_replace(coalesce(p_metin,''),'\s+',' ','g'));
  if char_length(m) not between 6 and 90 then raise exception 'Pankart yazısı 6–90 karakter olmalı';end if;
 end if;
 if p_tur='grev' and coalesce(x.grev_bitis,t-interval '1 second')<=t then raise exception 'Organizatör genel grev çağrısı yapmadan greve katılınamaz';end if;
 if p_tur='cagri' then
  for kim in select p.id from oyun.profiller p
    where p.id<>u and not p.yasakli and p.son_gorulme>t-interval '3 days' and p.olusturma<t-interval '3 days'
      and (p.il_id=x.il_id or (me.parti_id is not null and p.parti_id=me.parti_id))
      and not exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destekci_id=p.id::text and d.destek_turu='katilim')
      and not exists(select 1 from oyun.sokak_gorevli g where g.eylem_id=x.id and g.user_id=p.id and g.ayrilma is null)
      and not exists(select 1 from oyun.sokak_cagri_log c where c.eylem_id=x.id and c.hedef=p.id and c.zaman>t-interval '24 hours')
    order by p.son_gorulme desc limit 8
  loop
   insert into oyun.sokak_cagri_log(eylem_id,hedef,cagiran,zaman) values(x.id,kim.id,u,t);
   perform oyun.bildir(kim.id,oyun.kad(u)||' seni '||(select ad from oyun.iller where id=x.il_id)||' eylemine (#'||x.id||') çağırıyor: '||left(x.gerekce,120)||' — Halk Hareketleri ekranından katılabilirsin.');
   n:=n+1;
  end loop;
  if n=0 then raise exception 'Şu an çağrılabilecek oyuncu yok (ilde ve partinde katılmamış, yakın zamanda çağrılmamış aktif oyuncu bulunamadı)';end if;
 end if;
 insert into oyun.sokak_taktik(eylem_id,user_id,tur,metin,zaman,bitis) values(x.id,u,p_tur,m,t,t+sure);
 if p_tur='grev' then
  -- Gerçek kişinin grevi ekonomiye dokunur: eylem başına toplam en çok 0,3 puan büyüme.
  select coalesce(count(*),0)*0.02 into pay from oyun.sokak_taktik where eylem_id=x.id and tur='grev';
  if pay<=0.3 then update oyun.ulke set buyume=greatest(-20,buyume-0.02) where id=1; end if;
 end if;
 perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol();
 if p_tur in ('barikat','duran') then
  perform oyun.sokak_duyur(x.id,case p_tur when 'barikat' then 'Eylem #'||x.id||': '||oyun.kad(u)||' barikat kurdu. Sertleşme arttı; kamuoyu tepkisi değişebilir.'
    else 'Eylem #'||x.id||': '||oyun.kad(u)||' meydanın ortasında sessizce duruyor. Duran insan sürerken polis müdahalesinin kamuoyu bedeli iki katı.' end);
 end if;
 return jsonb_build_object('tamam',true,'tur',p_tur,'bitis',t+sure,'cagrilan',n,'seviye',(select seviye from oyun.sokak_eylem where id=x.id));
end $$;

create or replace function public.sokak_grev_cagri(p_eylem bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); n integer;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if x.baslatan is distinct from u then raise exception 'Genel grev çağrısını yalnız eylemi başlatan yapar';end if;
 if x.grev_bitis is not null then raise exception 'Bu eylemde genel grev çağrısı zaten yapıldı';end if;
 n:=((oyun.sokak_saha_dokum(x.id))->>'katilimci')::integer;
 if n<5 then raise exception 'Genel grev için en az 5 gerçek katılımcı gerekli (şu an %)',n;end if;
 update oyun.sokak_eylem set grev_bitis=t+interval '12 hours' where id=x.id;
 perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' için GENEL GREV çağrısı yapıldı. Katılımcılar 12 saat içinde "Greve katıl" diyebilir; her katılan eylemi güçlendirir ve ekonomiyi yavaşlatır.');
 return jsonb_build_object('tamam',true,'grev_bitis',t+interval '12 hours');
end $$;

-- ───────────── KAMUOYU NABZI ─────────────
create or replace function public.sokak_nabiz_ver(p_eylem bigint,p_tavir integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tavir is null or p_tavir not in (-1,0,1) then raise exception 'Geçersiz tavır';end if;
 select * into p from oyun.profiller where id=u;
 if p.yasakli or p.olusturma>t-interval '3 days' then raise exception 'Kısıtsız ve en az 3 günlük hesap gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if oyun.sokak_katilimci_mi(x.id,u,'muhalefet') or oyun.sokak_katilimci_mi(x.id,u,'iktidar')
  or exists(select 1 from oyun.sokak_gorevli where eylem_id=x.id and user_id=u and ayrilma is null)
 then raise exception 'Eylemde taraf olduğun için kamuoyu nabzına oy veremezsin; bu ses tarafsız oyuncuların';end if;
 if oyun.sokak_yonetebilir(u) then raise exception 'Kamuoyu nabzı tarafsız oyuncuların sesidir; Cumhurbaşkanı ve İçişleri Bakanı oy veremez';end if;
 if p_tavir=0 then delete from oyun.sokak_nabiz where eylem_id=x.id and user_id=u;
 else insert into oyun.sokak_nabiz(eylem_id,user_id,tavir,zaman) values(x.id,u,p_tavir,t)
      on conflict(eylem_id,user_id) do update set tavir=excluded.tavir,zaman=excluded.zaman; end if;
 perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol();
 return jsonb_build_object('tamam',true,'tavir',p_tavir,'sempati',(oyun.sokak_saha_dokum(x.id))->'sempati');
end $$;

-- ───────────── DEVLETİN YENİ ARAÇLARI (hepsi gerçek kişi) ─────────────
create or replace function public.sokak_yasak_koy(p_eylem bigint,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); un text;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if length(btrim(coalesce(p_gerekce,''))) not between 25 and 500 then raise exception 'Yasak gerekçesi 25–500 karakter olmalı';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if oyun.sokak_yonetebilir(u) then un:=oyun.sokak_gorev_unvan(u);
 elsif exists(select 1 from oyun.icisleri_atama where hedef=u and tur='vali' and il_id=x.il_id and durum='aktif' and (bitis is null or bitis>t)) then
  un:=(select ad from oyun.iller where id=x.il_id)||' Valisi';
 else raise exception 'Gösteri yasağını ilin valisi, İçişleri Bakanı ya da Cumhurbaşkanı koyabilir';end if;
 if exists(select 1 from oyun.sokak_yasak where eylem_id=x.id and zaman>t-interval '24 hours') then raise exception 'Aynı eyleme 24 saatte bir yasak konabilir';end if;
 insert into oyun.sokak_yasak(eylem_id,yapan,unvan,gerekce,zaman,bitis) values(x.id,u,un,btrim(p_gerekce),t,t+interval '6 hours');
 update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-0.5) where il_id=x.il_id;
 perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol();
 perform oyun.sokak_duyur(x.id,un||' eylem #'||x.id||' için 6 saatlik gösteri yasağı ilan etti: yeni katılım kapalı, meydandakiler kalabilir. Gerekçe: '||left(p_gerekce,300));
 return jsonb_build_object('tamam',true,'bitis',t+interval '6 hours');
end $$;

create or replace function public.sokak_jest_yap(p_eylem bigint,p_gerekce text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); n integer;
begin
 if u is null or not oyun.sokak_yonetebilir(u) then raise exception 'Yalnız Cumhurbaşkanı veya İçişleri Bakanı';end if;
 if length(btrim(coalesce(p_gerekce,''))) not between 20 and 500 then raise exception 'Gerekçe 20–500 karakter olmalı';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if exists(select 1 from oyun.sokak_jest where eylem_id=x.id and zaman>t-interval '12 hours') then raise exception 'Aynı eyleme 12 saatte bir jest yapılabilir';end if;
 update oyun.sokak_gozalti set durum='serbest' where eylem_id=x.id and durum='aktif';
 get diagnostics n=row_count;
 insert into oyun.sokak_jest(eylem_id,yapan,gerekce,serbest,zaman,bitis) values(x.id,u,btrim(p_gerekce),n,t,t+interval '6 hours');
 perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol();
 perform oyun.sokak_duyur(x.id,'Hükümetten jest: eylem #'||x.id||' kapsamındaki '||n||' gözaltı sona erdi. Gerekçe: '||left(p_gerekce,300));
 return jsonb_build_object('tamam',true,'serbest',n);
end $$;

create or replace function public.sokak_heyet_davet(p_eylem bigint,p_kad text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); h uuid;
begin
 if u is null or not exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb') then raise exception 'Arabulucu heyetini Cumhurbaşkanı kurar';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 select id into h from oyun.profiller where lower(kad)=lower(btrim(coalesce(p_kad,''))) and not yasakli limit 1;
 if h is null then raise exception 'Bu kullanıcı adıyla oyuncu bulunamadı';end if;
 if h=u then raise exception 'Kendini heyete davet edemezsin';end if;
 if oyun.sokak_katilimci_mi(x.id,h,'muhalefet') or oyun.sokak_katilimci_mi(x.id,h,'iktidar')
  or exists(select 1 from oyun.sokak_gorevli where eylem_id=x.id and user_id=h and ayrilma is null)
 then raise exception 'Arabulucu eylemde taraf olmamalı';end if;
 if (select count(*) from oyun.sokak_heyet where eylem_id=x.id)>=3 then raise exception 'Heyete en çok 3 kişi davet edilir';end if;
 insert into oyun.sokak_heyet(eylem_id,davet_eden,user_id,zaman) values(x.id,u,h,t);
 perform oyun.bildir(h,'Cumhurbaşkanı seni eylem #'||x.id||' için arabulucu heyete davet etti. Halk Hareketleri ekranından kabul ya da ret edebilir, kabul edersen rapor yazabilirsin.');
 return jsonb_build_object('tamam',true,'davet',oyun.kad(h));
end $$;

create or replace function public.sokak_heyet_yanit(p_eylem bigint,p_kabul boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or p_kabul is null then raise exception 'Oturum ve yanıt gerekli';end if;
 update oyun.sokak_heyet set durum=case when p_kabul then 'kabul' else 'ret' end where eylem_id=p_eylem and user_id=u and durum='davet';
 if not found then raise exception 'Bekleyen heyet davetin yok';end if;
 perform oyun.sokak_duyur(p_eylem,oyun.kad(u)||' arabulucu heyet davetini '||case when p_kabul then 'kabul etti.' else 'reddetti.' end);
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.sokak_heyet_rapor(p_eylem bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if char_length(btrim(coalesce(p_metin,''))) not between 40 and 1200 then raise exception 'Rapor 40–1200 karakter olmalı';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 update oyun.sokak_heyet set rapor=btrim(p_metin),rapor_zaman=t where eylem_id=x.id and user_id=u and durum='kabul' and rapor is null;
 if not found then raise exception 'Raporu yalnız daveti kabul etmiş ve henüz rapor yazmamış heyet üyesi yazar';end if;
 perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol();
 perform oyun.sokak_duyur(x.id,'Arabulucu heyet üyesi '||oyun.kad(u)||' eylem #'||x.id||' raporunu açıkladı: '||left(btrim(p_metin),280));
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.sokak_seslenis_yap(p_eylem bigint,p_metin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); sid bigint; txt text:=btrim(coalesce(p_metin,''));
begin
 if u is null or not exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb') then raise exception 'Ulusa sesleniş Cumhurbaşkanı yetkisidir';end if;
 if char_length(txt) not between 60 and 1500 then raise exception 'Konuşma metni 60–1500 karakter olmalı';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 if exists(select 1 from oyun.sokak_seslenis where eylem_id=x.id and zaman>t-interval '24 hours') then raise exception 'Aynı eylem için 24 saatte bir ulusa sesleniş yapılır';end if;
 insert into oyun.sokak_seslenis(eylem_id,yapan,metin,zaman,bitis) values(x.id,u,txt,t,t+interval '12 hours') returning id into sid;
 insert into oyun.bildirimler(user_id,zaman,metin)
  select p.id,t,'📺 Ulusa sesleniş: Cumhurbaşkanı eylem #'||x.id||' hakkında konuştu. Halk Hareketleri ekranından dinleyip "ikna oldum / olmadım" diyebilirsin.'
  from oyun.profiller p where not p.yasakli and p.id<>u and p.son_gorulme>t-interval '3 days';
 perform oyun.olay('siyaset','Cumhurbaşkanı ulusa seslendi (eylem #'||x.id||'): '||left(txt,200),x.il_id,x.parti_id);
 return jsonb_build_object('tamam',true,'seslenis_id',sid,'bitis',t+interval '12 hours');
end $$;

create or replace function public.sokak_seslenis_tepki(p_seslenis bigint,p_ikna boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); s oyun.sokak_seslenis; p oyun.profiller; t timestamptz:=oyun.simdi();
begin
 if u is null or p_ikna is null then raise exception 'Oturum ve tepki gerekli';end if;
 select * into p from oyun.profiller where id=u;
 if p.yasakli or p.olusturma>t-interval '3 days' then raise exception 'Kısıtsız ve en az 3 günlük hesap gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into s from oyun.sokak_seslenis where id=p_seslenis;
 if s.id is null or s.bitis<=t then raise exception 'Bu konuşmanın tepki süresi doldu';end if;
 if s.yapan=u then raise exception 'Kendi konuşmana tepki veremezsin';end if;
 insert into oyun.sokak_seslenis_tepki(seslenis_id,user_id,ikna,zaman) values(s.id,u,p_ikna,t)
  on conflict(seslenis_id,user_id) do update set ikna=excluded.ikna,zaman=excluded.zaman;
 perform oyun.sokak_yenile(s.eylem_id); perform oyun.sokak_kriz_kontrol();
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.sokak_karsi_cagri(p_eylem bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); pa bigint; n integer;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 select pr.parti_id into pa from oyun.profiller pr where pr.id=u;
 if not (oyun.sokak_yonetebilir(u) or exists(select 1 from oyun.partiler where id=pa and gb=u and not kapali) and oyun.sokak_iktidar(u)) then
  raise exception 'Karşı miting çağrısını Cumhurbaşkanı, İçişleri Bakanı ya da iktidar partisi genel başkanı yapar';end if;
 if pa is null then raise exception 'Çağrı için bir partiye üye olmalısın';end if;
 if x.karsi_cagri is not null and x.karsi_cagri>t-interval '12 hours' then raise exception 'Bu eylem için 12 saatte bir karşı miting çağrısı yapılır';end if;
 update oyun.sokak_eylem set karsi_cagri=t where id=x.id;
 insert into oyun.bildirimler(user_id,zaman,metin)
  select p.id,t,'🚩 '||oyun.kad(u)||' parti üyelerini eylem #'||x.id||' karşısında "sükûnet ve karşı miting" için sahaya çağırıyor. Halk Hareketleri ekranından karşı tarafta yer alabilirsin.'
  from oyun.profiller p where p.parti_id=pa and p.id<>u and not p.yasakli and p.son_gorulme>t-interval '7 days'
   and not oyun.sokak_katilimci_mi(x.id,p.id,'muhalefet');
 get diagnostics n=row_count;
 perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' karşısında karşı miting çağrısı yapıldı. Karşı tarafta duran her gerçek oyuncu eylemin gücünü azaltır.');
 return jsonb_build_object('tamam',true,'cagrilan',n);
end $$;

-- ŞAŞIRTICI AN: görevli kalkanı bırakır ve eyleme katılır
create or replace function public.sokak_kalkan_birak(p_eylem bigint,p_aciklama text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); un text; bakan uuid;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if char_length(btrim(coalesce(p_aciklama,''))) not between 20 and 400 then raise exception 'Kamuoyuna açıklaman 20–400 karakter olmalı';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli';end if;
 select unvan into un from oyun.sokak_gorevli where eylem_id=x.id and user_id=u and ayrilma is null;
 if un is null then raise exception 'Kalkanı yalnız sahadaki görevli bırakabilir';end if;
 if oyun.sokak_yonetebilir(u) then raise exception 'Cumhurbaşkanı ve İçişleri Bakanı kalkan bırakamaz; görevden ayrılabilir';end if;
 if exists(select 1 from oyun.sokak_kalkan where eylem_id=x.id and user_id=u) then raise exception 'Bu eylemde kalkanı zaten bıraktın';end if;
 update oyun.sokak_gorevli set ayrilma=t where eylem_id=x.id and user_id=u and ayrilma is null;
 insert into oyun.sokak_kalkan(eylem_id,user_id,unvan,zaman) values(x.id,u,un,t);
 insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,taraf,temsilci) values(x.id,'oyuncu',u::text,'muhalefet',u) on conflict do nothing;
 -- Kamuoyu sarsılır: tarafsız bir kalabalık değil, onun cesareti konuşulur — tek seferlik pankart olarak kaydedilir.
 insert into oyun.sokak_taktik(eylem_id,user_id,tur,metin,zaman,bitis) values(x.id,u,'pankart',left('Kalkanımı bıraktım: '||btrim(p_aciklama),90),t,t+interval '12 hours');
 select user_id into bakan from oyun.makamlar where bit is null and tur='bakan' and bakanlik='icisleri' limit 1;
 if bakan is not null then perform oyun.bildir(bakan,un||' '||oyun.kad(u)||' eylem #'||x.id||' alanında kalkanını bırakıp eyleme katıldı. Görev durumunu İçişleri Komuta Merkezi''nden değerlendirebilirsin.'); end if;
 perform oyun.sokak_yenile(x.id); perform oyun.sokak_kriz_kontrol();
 perform oyun.sokak_duyur(x.id,'🫡 SON DAKİKA: '||un||' '||oyun.kad(u)||' eylem #'||x.id||' alanında kalkanını yere bıraktı ve meydana katıldı: "'||left(btrim(p_aciklama),220)||'"');
 perform oyun.olay('siyaset',un||' '||oyun.kad(u)||' kalkanını bırakıp eyleme katıldı (eylem #'||x.id||').',x.il_id,x.parti_id);
 return jsonb_build_object('tamam',true);
end $$;

-- ───────────── SAHA PANELİ (arayüz buradan çizer) ─────────────
create or replace function public.sokak_saha_panel() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); un text; me oyun.profiller; cb boolean; ikt_gb boolean;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into me from oyun.profiller where id=u;
 un:=oyun.sokak_gorev_unvan(u);
 cb:=exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb');
 ikt_gb:=oyun.sokak_yonetebilir(u) or (exists(select 1 from oyun.partiler where id=me.parti_id and gb=u and not kapali) and oyun.sokak_iktidar(u));
 return jsonb_build_object(
  'gorev_unvanim',un,'cb',cb,'yonetebilir',oyun.sokak_yonetebilir(u),'karsi_cagri_yetki',ikt_gb,
  'kural','Eylemin gücü yalnız gerçek oyunculardan gelir: katılımcılar, onların taktikleri, tarafsız oyuncuların kamuoyu nabzı, karşı tarafta duranlar ve sahadaki görevliler. Para yalnız süreyi uzatır. İstediğin an ayrılabilirsin; aynı eyleme 1 saat sonra dönebilirsin.',
  'eylemler',coalesce((select jsonb_agg(jsonb_build_object(
    'id',e.id,'ben_baslattim',e.baslatan=u,
    'taraf',(select d.taraf from oyun.sokak_eylem_destek d where d.eylem_id=e.id and d.destekci_tur='oyuncu' and d.destekci_id=u::text and d.destek_turu='katilim' limit 1),
    'gorevdeyim',exists(select 1 from oyun.sokak_gorevli g where g.eylem_id=e.id and g.user_id=u and g.ayrilma is null),
    'kalkan_hakki',exists(select 1 from oyun.sokak_gorevli g where g.eylem_id=e.id and g.user_id=u and g.ayrilma is null) and not oyun.sokak_yonetebilir(u),
    'yasak_yetki',oyun.sokak_yonetebilir(u) or exists(select 1 from oyun.icisleri_atama a where a.hedef=u and a.tur='vali' and a.il_id=e.il_id and a.durum='aktif' and (a.bitis is null or a.bitis>t)),
    'dokum',oyun.sokak_saha_dokum(e.id),
    'gorevliler',coalesce((select jsonb_agg(jsonb_build_object('ad',oyun.kad(g.user_id),'unvan',g.unvan) order by g.katilma) from oyun.sokak_gorevli g where g.eylem_id=e.id and g.ayrilma is null),'[]'::jsonb),
    'karsidakiler',coalesce((select jsonb_agg(oyun.kad(d.temsilci)) from oyun.sokak_eylem_destek d where d.eylem_id=e.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='iktidar'),'[]'::jsonb),
    'nabzim',(select tavir from oyun.sokak_nabiz where eylem_id=e.id and user_id=u),
    'son_taktigim',(select max(zaman) from oyun.sokak_taktik where eylem_id=e.id and user_id=u),
    'sonraki_taktik',(select max(zaman)+interval '3 hours' from oyun.sokak_taktik where eylem_id=e.id and user_id=u having max(zaman)+interval '3 hours'>t),
    'aktif_taktiklerim',coalesce((select jsonb_agg(jsonb_build_object('tur',k.tur,'bitis',k.bitis)) from oyun.sokak_taktik k where k.eylem_id=e.id and k.user_id=u and k.bitis>t),'[]'::jsonb),
    'pankartlar',coalesce((select jsonb_agg(jsonb_build_object('ad',oyun.kad(k.user_id),'metin',k.metin,'zaman',k.zaman) order by k.zaman desc) from (select * from oyun.sokak_taktik k2 where k2.eylem_id=e.id and k2.tur='pankart' and k2.metin is not null order by k2.zaman desc limit 12) k),'[]'::jsonb),
    'grev_bitis',case when e.grev_bitis>t then e.grev_bitis end,
    'grev_yapildi',e.grev_bitis is not null,
    'yasak',(select jsonb_build_object('unvan',y.unvan,'bitis',y.bitis,'gerekce',y.gerekce) from oyun.sokak_yasak y where y.eylem_id=e.id and y.bitis>t order by y.zaman desc limit 1),
    'jest',(select jsonb_build_object('serbest',j.serbest,'bitis',j.bitis) from oyun.sokak_jest j where j.eylem_id=e.id and j.bitis>t order by j.zaman desc limit 1),
    'heyet',coalesce((select jsonb_agg(jsonb_build_object('ad',oyun.kad(h.user_id),'durum',h.durum,'rapor',h.rapor,'rapor_zaman',h.rapor_zaman,'ben',h.user_id=u) order by h.zaman) from oyun.sokak_heyet h where h.eylem_id=e.id),'[]'::jsonb),
    'seslenis',(select jsonb_build_object('id',s.id,'metin',s.metin,'bitis',s.bitis,'yapan',oyun.kad(s.yapan),
        'ikna',(select count(*) from oyun.sokak_seslenis_tepki q where q.seslenis_id=s.id and q.ikna),
        'olmadi',(select count(*) from oyun.sokak_seslenis_tepki q where q.seslenis_id=s.id and not q.ikna),
        'tepkim',(select q.ikna from oyun.sokak_seslenis_tepki q where q.seslenis_id=s.id and q.user_id=u))
      from oyun.sokak_seslenis s where s.eylem_id=e.id and s.bitis>t order by s.zaman desc limit 1),
    'kalkan_birakanlar',coalesce((select jsonb_agg(jsonb_build_object('ad',oyun.kad(k.user_id),'unvan',k.unvan,'zaman',k.zaman)) from oyun.sokak_kalkan k where k.eylem_id=e.id),'[]'::jsonb),
    'yeniden_katilim',oyun.sokak_yeniden_giris(e.id,u),
    'gozaltindayim',exists(select 1 from oyun.sokak_gozalti z where z.eylem_id=e.id and z.hedef=u and z.durum='aktif' and z.bitis>t)
   ) order by e.id) from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t),'[]'::jsonb));
end $$;

-- ───────────── yetkiler ─────────────
revoke all on function oyun.sokak_gorev_unvan(uuid),oyun.sokak_gorevli_sayi(bigint),oyun.sokak_yeniden_giris(bigint,uuid),
 oyun.sokak_katilimci_mi(bigint,uuid,text),oyun.sokak_gorevli_ekle(bigint,uuid,boolean),oyun.sokak_saha_dokum(bigint),oyun.sokak_kriz_kontrol()
 from public,anon,authenticated;
revoke all on function public.sokak_eylemden_ayril(bigint),public.sokak_goreve_cik(bigint),public.sokak_gorevden_ayril(bigint),
 public.sokak_karsi_katil(bigint),public.sokak_taktik_yap(bigint,text,text),public.sokak_grev_cagri(bigint),public.sokak_nabiz_ver(bigint,integer),
 public.sokak_yasak_koy(bigint,text),public.sokak_jest_yap(bigint,text),public.sokak_heyet_davet(bigint,text),public.sokak_heyet_yanit(bigint,boolean),
 public.sokak_heyet_rapor(bigint,text),public.sokak_seslenis_yap(bigint,text),public.sokak_seslenis_tepki(bigint,boolean),public.sokak_karsi_cagri(bigint),
 public.sokak_kalkan_birak(bigint,text),public.sokak_saha_panel() from public,anon;
grant execute on function public.sokak_eylemden_ayril(bigint),public.sokak_goreve_cik(bigint),public.sokak_gorevden_ayril(bigint),
 public.sokak_karsi_katil(bigint),public.sokak_taktik_yap(bigint,text,text),public.sokak_grev_cagri(bigint),public.sokak_nabiz_ver(bigint,integer),
 public.sokak_yasak_koy(bigint,text),public.sokak_jest_yap(bigint,text),public.sokak_heyet_davet(bigint,text),public.sokak_heyet_yanit(bigint,boolean),
 public.sokak_heyet_rapor(bigint,text),public.sokak_seslenis_yap(bigint,text),public.sokak_seslenis_tepki(bigint,boolean),public.sokak_karsi_cagri(bigint),
 public.sokak_kalkan_birak(bigint,text),public.sokak_saha_panel() to authenticated;

-- Yeni kurala göre aktif eylemlerin gücünü hemen yeniden hesapla
do $$ declare r record; begin
 for r in select id from oyun.sokak_eylem where durum='aktif' loop perform oyun.sokak_yenile(r.id); end loop;
 perform oyun.sokak_kriz_kontrol();
end $$;
