begin;
-- =====================================================================
--  Halk Hareketleri 5.2 · Doruk Anı ve Bireysel Yaptırımlar (13.11.2026)
--
--  İstek (Ercan): Eylem %100'e ulaştığında bir sonucu olsun. Hükümet de
--  eylemi bitirmek için eyleme katılan GERÇEK oyuncuları etkileyen daha
--  sert yaptırımlar uygulayabilsin. Fikirler Claude'a bırakıldı.
--
--  A) DORUK ANI
--   • Güç ≥ 95 ve kırmızı seviyede → "Doruk": hükümete 6 saatlik ültimatom.
--     Eylemin süresi ültimatomdan önce bitecekse ültimatom sonuna uzar.
--     Hükümet memnuniyeti hemen −1.
--   • Ültimatom sonunda:
--     – güç ≥ 85 ve meydan ayakta  → HALKIN ZAFERİ
--     – uzlaşma sözü kabul edilmişse → UZLAŞMA
--     – güç 85'in altına indirilmişse ya da meydan yatıştırılmışsa → BASTIRILDI
--     – süre/erken seçim ile bittiyse → DAĞILDI
--   • Halkın Zaferi: meydan zaferle dağılır; her gerçek katılımcıya +3 kıdem,
--     +10 meydan itibarı, eylem rozeti; bu eylemdeki bireysel yaptırımlar
--     kalkar, bloke paralar hemen iade edilir; memnuniyet −3, büyüme −0,3;
--     ulusal kriz (erken seçim) sayacı 12 saat öne çekilir; o ilde 48 saat
--     "meşruiyet krizi" (bireysel yaptırım uygulanamaz).
--     Cumhurbaşkanı 24 saat içinde karar verir:
--       istifa  → İçişleri Bakanı görevden alınır, memnuniyet +2
--       talep   → talep kamuoyu önünde kabul edilir, memnuniyet +1,5
--       diren   → memnuniyet −1, kriz sayacı 6 saat daha öne
--     Karar verilmezse "diren" sayılır.
--
--  B) BİREYSEL YAPTIRIMLAR (CB, İçişleri Bakanı, ilin valisi)
--   • Önce polis ihtarı: 30 dakika sonra uygulanır; o anda meydanda kalan
--     gerçek katılımcıların hepsi etkilenir, ayrılan kurtulur (meydan güç
--     kaybeder — hükümetin asıl hedefi bu).
--   • gozalti (Gözaltı Dalgası): meydandakilerin %20'si (en az 1, en çok 6;
--     önce eylemi başlatan) 6 saat gözaltı; bir meydanda 6 saatte bir;
--     MV, zaten gözaltında olan ve son 12 saatte çıkan alınmaz. 3/gün
--     sınırına sayılmaz. Mevcut gözaltı/avukat/baro düzeni aynen işler.
--   • Türler: idari_ceza (cüzdanın %3'ü, 2.500–150.000 ₺ → Hazine),
--     seyahat (48 saat il değiştiremez), teminat (cüzdanın %15'i en çok
--     500.000 ₺, 72 saat bloke, sonra iade), erisim (12 saat Kürsü'ye
--     yazamaz; meydan sohbeti açık), disiplin (makam sahibi kamu görevlisi
--     katılımcılar −5 kıdem; MV ve CB hariç).
--   • Sınırlar: aynı meydanda aynı tür 12 saatte bir, 24 saatte en çok 3;
--     bir ihtar beklerken ikincisi verilemez; görevdeki CB etkilenmez.
--     Bedel İçişleri kasasından (OHAL'de yarı); her uygulama memnuniyeti
--     −0,2 düşürür. İhtarı veren 30 dakika içinde geri çekebilir.
--
--  Oyuncu verisine dokunmaz: yalnız yeni tablolar, yeni fonksiyonlar,
--  il_tasinma_engeli'ne bir kontrol, Kürsü'ye (oyun.akis) bir tetikleyici,
--  bir cron işi. Tekrar çalıştırmak güvenlidir.
-- =====================================================================

create table if not exists oyun.sokak_doruk(
 eylem_id bigint primary key references oyun.sokak_eylem,
 baslangic timestamptz not null,
 ultimatom timestamptz not null,
 durum text not null default 'ultimatom' check (durum in ('ultimatom','zafer','bastirildi','uzlasma','dagildi')),
 tepe numeric not null default 0,
 sonuc_zaman timestamptz,
 sonuc jsonb not null default '{}'::jsonb,
 cb_karar text check (cb_karar in ('istifa','talep','diren','sure_doldu')),
 cb_karar_zaman timestamptz,
 cb_karar_son timestamptz,
 cb_gerekce text,
 mesruiyet_bitis timestamptz
);
create table if not exists oyun.sokak_bireysel(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 tur text not null,
 yapan uuid not null references oyun.profiller,
 gerekce text not null check (char_length(gerekce) between 20 and 500),
 bedel numeric not null default 0,
 durum text not null default 'ihtar' check (durum in ('ihtar','uygulandi','geri','bos')),
 zaman timestamptz not null,
 uygulama timestamptz not null,
 bitis timestamptz,
 etkilenen integer not null default 0,
 toplam numeric not null default 0
);
create index if not exists sokak_bireysel_eylem on oyun.sokak_bireysel(eylem_id, zaman desc);
alter table oyun.sokak_bireysel drop constraint if exists sokak_bireysel_tur_check;
alter table oyun.sokak_bireysel add constraint sokak_bireysel_tur_check check (tur in ('idari_ceza','seyahat','teminat','erisim','disiplin','gozalti'));
create table if not exists oyun.sokak_bireysel_hedef(
 yaptirim_id bigint not null references oyun.sokak_bireysel,
 user_id uuid not null references oyun.profiller,
 tur text not null,
 tutar numeric not null default 0,
 bitis timestamptz,
 iade_zaman timestamptz,
 iade_durum text check (iade_durum in ('bekliyor','iade')),
 primary key (yaptirim_id, user_id)
);
create index if not exists sokak_bireysel_hedef_kisi on oyun.sokak_bireysel_hedef(user_id, tur, bitis);
alter table oyun.sokak_doruk enable row level security;
alter table oyun.sokak_bireysel enable row level security;
alter table oyun.sokak_bireysel_hedef enable row level security;

-- ---------------------------------------------------------------------
-- Katalog
-- ---------------------------------------------------------------------
create or replace function oyun.sokak_bireysel_katalog() returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_array(
  jsonb_build_object('tur','gozalti','ad','Gözaltı Dalgası','ikon','🚓','kat',2,'saat',6,
   'aciklama','İhtar saatinde meydanda kalanların %20''si (en az 1, en çok 6 kişi; önce eylemi başlatan) 6 saat gözaltına alınır. Bir meydanda 6 saatte bir uygulanabilir. Milletvekilleri (dokunulmazlık), zaten gözaltında olanlar ve son 12 saatte gözaltından çıkanlar alınmaz. Gözaltındakiler meydan gücüne sayılmaz; baro avukat gönderebilir, erken tahliye yalnız CB ya da İçişleri Bakanı.'),
  jsonb_build_object('tur','idari_ceza','ad','İdari Para Cezası','ikon','🧾','kat',1,'saat',0,
   'aciklama','2911 sayılı Toplantı ve Gösteri Yürüyüşleri Kanunu''na aykırılıktan, ihtar saatinde meydanda kalan her katılımcının cüzdanından %3 (en az 2.500 ₺, en çok 150.000 ₺) kesilir ve Hazine''ye gelir yazılır.'),
  jsonb_build_object('tur','seyahat','ad','İl Dışına Çıkış Yasağı','ikon','🛂','kat',1,'saat',48,
   'aciklama','İhtar saatinde meydanda kalan katılımcılar 48 saat il değiştiremez.'),
  jsonb_build_object('tur','teminat','ad','Mal Varlığına İhtiyati Tedbir','ikon','🏦','kat',2,'saat',72,
   'aciklama','Katılımcıların cüzdanındaki paranın %15''i (en çok 500.000 ₺) 72 saat bloke edilir; süre sonunda kendiliğinden iade edilir. Halk kazanırsa hemen iade.'),
  jsonb_build_object('tur','erisim','ad','Erişim Engeli','ikon','📵','kat',1.5,'saat',12,
   'aciklama','Katılımcılar 12 saat Kürsü''de paylaşım yapamaz. Meydan sohbeti açık kalır.'),
  jsonb_build_object('tur','disiplin','ad','Disiplin Soruşturması','ikon','📁','kat',1,'saat',0,
   'aciklama','Katılımcılar arasındaki kamu görevlileri (bakan, belediye başkanı, CB yardımcısı, vali, emniyet müdürü; milletvekili ve Cumhurbaşkanı hariç) 5 kıdem kaybeder; Cumhurbaşkanına rapor gider.')
 )
$$;
create or replace function oyun.sokak_bireysel_ad(k text) returns text
language sql immutable set search_path='' as $$
 select coalesce((select e->>'ad' from jsonb_array_elements(oyun.sokak_bireysel_katalog()) e where e->>'tur'=k), k)
$$;
create or replace function oyun.sokak_bireysel_bedel(k text, il integer) returns numeric
language sql stable set search_path='' as $$
 select round(coalesce((select (e->>'kat')::numeric from jsonb_array_elements(oyun.sokak_bireysel_katalog()) e where e->>'tur'=k),0)
  * a.baslatma_bedeli * case when oyun.sokak_ohal_aktif(il) then 0.5 else 1 end)
 from oyun.sokak_eylem_ayar a where a.id=1
$$;
-- Meydanda şu an kalan gerçek katılımcılar (görevdeki CB hariç)
create or replace function oyun.sokak_meydandakiler(e bigint) returns setof uuid
language sql stable set search_path='' as $$
 select distinct d.temsilci from oyun.sokak_eylem_destek d join oyun.profiller p on p.id=d.temsilci
 where d.eylem_id=e and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and not p.yasakli
   and not exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null and m.tur='cb')
$$;
create or replace function oyun.sokak_gozaltilabilir(e bigint) returns setof uuid
language sql stable set search_path='' as $$
 select m from oyun.sokak_meydandakiler(e) m
 where not exists(select 1 from oyun.makamlar k where k.user_id=m and k.bit is null and k.tur in ('mv','tbmm','grup_bskv'))
   and not exists(select 1 from oyun.sokak_gozalti g where g.hedef=m and g.bitis>oyun.simdi()-interval '12 hours' and g.baslangic<=oyun.simdi())
   and not oyun.icisleri_gozaltinda_v2(m)
   and not exists(select 1 from oyun.yonetim_tutuklama y where y.hedef=m and y.durum='aktif' and y.bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_unvan(u uuid, il integer) returns text
language sql stable set search_path='' as $$
 select case
  when exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb') then 'Cumhurbaşkanlığı'
  when exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='bakan' and bakanlik='icisleri') then 'İçişleri Bakanlığı'
  else coalesce((select ad from oyun.iller where id=il),'')||' Valiliği' end
$$;
create or replace function oyun.sokak_mesruiyet_bitis(il integer) returns timestamptz
language sql stable set search_path='' as $$
 select max(d.mesruiyet_bitis) from oyun.sokak_doruk d join oyun.sokak_eylem e on e.id=d.eylem_id
 where e.il_id=il and d.mesruiyet_bitis>oyun.simdi()
$$;
-- Kullanılabilirlik: null = kullanılabilir, değilse neden
create or replace function oyun.sokak_bireysel_engel(u uuid, e bigint, k text) returns text
language plpgsql stable set search_path='' as $$
declare x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); m timestamptz; n integer;
begin
 select * into x from oyun.sokak_eylem where id=e;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then return 'Eylem aktif değil.'; end if;
 if not oyun.sokak_sert_yetkili(u,x.il_id) then return 'Yalnız Cumhurbaşkanı, İçişleri Bakanı ya da ilin valisi uygulayabilir.'; end if;
 m:=oyun.sokak_mesruiyet_bitis(x.il_id);
 if m is not null then return 'Halkın zaferinden sonra meşruiyet krizi sürüyor: '||to_char(m at time zone 'Europe/Istanbul','DD.MM HH24:MI')||' saatine kadar bu ilde bireysel yaptırım uygulanamaz.'; end if;
 if exists(select 1 from oyun.sokak_bireysel b where b.eylem_id=e and b.durum='ihtar') then return 'Bu meydanda bekleyen bir ihtar var; önce o uygulanmalı ya da geri çekilmeli.'; end if;
 if k='gozalti' then
  if exists(select 1 from oyun.sokak_bireysel b where b.eylem_id=e and b.tur='gozalti' and b.durum in ('ihtar','uygulandi') and b.uygulama>t-interval '6 hours') then return 'Gözaltı dalgası bir meydanda 6 saatte bir uygulanabilir.'; end if;
  if not exists(select 1 from oyun.sokak_gozaltilabilir(e)) then return 'Meydanda gözaltına alınabilecek kimse yok (milletvekilleri, zaten gözaltında olanlar ve son 12 saatte çıkanlar alınmaz).'; end if;
 else
  if exists(select 1 from oyun.sokak_bireysel b where b.eylem_id=e and b.tur=k and b.durum in ('ihtar','uygulandi') and b.zaman>t-interval '12 hours') then return 'Aynı yaptırım bu meydanda 12 saatte bir uygulanabilir.'; end if;
  select count(*) into n from oyun.sokak_bireysel b where b.eylem_id=e and b.tur<>'gozalti' and b.durum in ('ihtar','uygulandi') and b.zaman>t-interval '24 hours';
  if n>=3 then return 'Bir meydanda 24 saatte en çok 3 bireysel yaptırım uygulanabilir (gözaltı dalgası hariç).'; end if;
 end if;
 if not exists(select 1 from oyun.sokak_meydandakiler(e)) then return 'Meydanda yaptırım uygulanacak katılımcı yok.'; end if;
 return null;
end $$;

-- ---------------------------------------------------------------------
-- İhtar ver / geri çek
-- ---------------------------------------------------------------------
create or replace function public.sokak_bireysel_ihtar(p_eylem bigint, p_tur text, p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=oyun.ben(); t timestamptz:=oyun.simdi(); x oyun.sokak_eylem; engel text; bedel numeric; sa numeric; g text; ad text; v_id bigint; uyg timestamptz;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 if p_tur not in ('idari_ceza','seyahat','teminat','erisim','disiplin','gozalti') then raise exception 'Geçersiz yaptırım türü.'; end if;
 g:=btrim(coalesce(p_gerekce,''));
 if char_length(g)<20 or char_length(g)>500 then raise exception 'Gerekçe 20–500 karakter olmalı.'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 engel:=oyun.sokak_bireysel_engel(u,p_eylem,p_tur);
 if engel is not null then raise exception '%',engel; end if;
 bedel:=oyun.sokak_bireysel_bedel(p_tur,x.il_id);
 ad:=oyun.sokak_bireysel_ad(p_tur);
 perform oyun.bm_kasa_harca('icisleri',bedel/oyun.pazar_tl_milyar(),'gider',ad||' ihtarı · eylem #'||x.id);
 select (e->>'saat')::numeric into sa from jsonb_array_elements(oyun.sokak_bireysel_katalog()) e where e->>'tur'=p_tur;
 uyg:=t+interval '30 minutes';
 insert into oyun.sokak_bireysel(eylem_id,tur,yapan,gerekce,bedel,zaman,uygulama,bitis)
 values(x.id,p_tur,u,g,bedel,t,uyg,case when sa>0 then uyg+make_interval(hours=>sa::int) end) returning id into v_id;
 perform oyun.sokak_sicil_yaz(u,x.id,'bireysel',ad);
 perform oyun.sokak_duyur(x.id,format('⚠️ Polis ihtarı · %s: %s saat %s''da uygulanacak. O saatte meydanda kalan her katılımcı etkilenir; o saate kadar eylemden ayrılanlar etkilenmez. Gerekçe: %s',
  oyun.sokak_unvan(u,x.il_id), ad, to_char(uyg at time zone 'Europe/Istanbul','HH24:MI'), g));
 return public.sokak_doruk_panel(x.id);
end $$;

create or replace function public.sokak_bireysel_geri(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=oyun.ben(); b oyun.sokak_bireysel; x oyun.sokak_eylem;
begin
 select * into b from oyun.sokak_bireysel where id=p_id for update;
 if b.id is null or b.durum<>'ihtar' then raise exception 'Geri çekilecek bekleyen ihtar yok.'; end if;
 select * into x from oyun.sokak_eylem where id=b.eylem_id;
 if u<>b.yapan and not oyun.sokak_yonetebilir(u) then raise exception 'İhtarı yalnız veren makam, Cumhurbaşkanı ya da İçişleri Bakanı geri çekebilir.'; end if;
 update oyun.sokak_bireysel set durum='geri' where id=b.id;
 perform oyun.sokak_duyur(b.eylem_id,format('🕊️ %s, "%s" ihtarını geri çekti. Meydandakiler için yaptırım uygulanmayacak.',oyun.sokak_unvan(u,x.il_id),oyun.sokak_bireysel_ad(b.tur)));
 return public.sokak_doruk_panel(b.eylem_id);
end $$;

-- ---------------------------------------------------------------------
-- İhtar süresi dolunca uygula
-- ---------------------------------------------------------------------
create or replace function oyun.sokak_bireysel_uygula(p_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare b oyun.sokak_bireysel; x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); u uuid; para numeric; tut numeric; n integer:=0; top numeric:=0; ad text; il_ad text; atla boolean;
begin
 select * into b from oyun.sokak_bireysel where id=p_id for update;
 if b.id is null or b.durum<>'ihtar' then return; end if;
 select * into x from oyun.sokak_eylem where id=b.eylem_id;
 ad:=oyun.sokak_bireysel_ad(b.tur); il_ad:=(select i.ad from oyun.iller i where i.id=x.il_id);
 if x.durum<>'aktif' then
  update oyun.sokak_bireysel set durum='bos' where id=b.id; return;
 end if;
 if b.tur='gozalti' then
  perform oyun.sokak_gozalti_dalgasi(b.id);
  return;
 end if;
 for u in select * from oyun.sokak_meydandakiler(b.eylem_id) loop
  tut:=0; atla:=false;
  perform oyun.cuzdanim(u);
  select c.para into para from oyun.cuzdan c where c.user_id=u for update;
  para:=greatest(coalesce(para,0),0);
  if b.tur='idari_ceza' then
   tut:=least(round(greatest(2500,para*0.03)),150000,floor(para));
   if tut>0 then
    perform oyun.para_islem(u,-tut,'ceza',format('İdari para cezası · %s meydanı (eylem #%s)',il_ad,x.id),t);
    perform oyun.hazine_kaydet('idari_ceza',tut/oyun.pazar_tl_milyar(),format('Halk Hareketleri #%s: idari para cezası',x.id));
   end if;
  elsif b.tur='teminat' then
   tut:=least(round(para*0.15),500000);
   if tut>0 then perform oyun.para_islem(u,-tut,'teminat',format('İhtiyati tedbir: 72 saat bloke · %s meydanı (eylem #%s)',il_ad,x.id),t); end if;
  elsif b.tur='disiplin' then
   if exists(select 1 from oyun.makamlar m where m.user_id=u and m.bit is null and m.tur in ('bakan','bel','cb_yardimcisi'))
      or exists(select 1 from oyun.icisleri_atama a where a.hedef=u and a.durum='aktif' and (a.bitis is null or a.bitis>t)) then
    perform oyun.kidem_ekle(u,-5::numeric);
   else atla:=true; end if;
  end if;
  if atla then continue; end if;
  insert into oyun.sokak_bireysel_hedef(yaptirim_id,user_id,tur,tutar,bitis,iade_zaman,iade_durum)
  values(b.id,u,b.tur,tut,b.bitis,case when b.tur='teminat' and tut>0 then b.bitis end,case when b.tur='teminat' and tut>0 then 'bekliyor' end)
  on conflict do nothing;
  insert into oyun.bildirimler(user_id,zaman,metin) values(u,t,
   case b.tur
    when 'idari_ceza' then format('🧾 %s meydanında kaldığın için %s ₺ idari para cezası kesildi.',il_ad,oyun.tl(tut))
    when 'seyahat' then format('🛂 İl dışına çıkış yasağı: %s saatine kadar il değiştiremezsin.',to_char(b.bitis at time zone 'Europe/Istanbul','DD.MM HH24:MI'))
    when 'teminat' then format('🏦 İhtiyati tedbir: %s ₺ 72 saat bloke edildi; %s saatinde iade edilecek.',oyun.tl(tut),to_char(b.bitis at time zone 'Europe/Istanbul','DD.MM HH24:MI'))
    when 'erisim' then format('📵 Erişim engeli: %s saatine kadar Kürsü''de paylaşım yapamazsın. Meydan sohbeti açık.',to_char(b.bitis at time zone 'Europe/Istanbul','DD.MM HH24:MI'))
    else '📁 Hakkında disiplin soruşturması açıldı: 5 kıdem kaybettin. Rapor Cumhurbaşkanına gitti.' end);
  n:=n+1; top:=top+tut;
 end loop;
 if n=0 then
  update oyun.sokak_bireysel set durum='bos' where id=b.id;
  perform oyun.sokak_duyur(x.id,format('%s ihtarının saati geldi ama etkilenecek kimse kalmadı.',ad));
  return;
 end if;
 update oyun.sokak_bireysel set durum='uygulandi',etkilenen=n,toplam=top where id=b.id;
 update oyun.ulke set memnuniyet=greatest(0,memnuniyet-0.2) where id=1;
 perform oyun.sokak_duyur(x.id,format('⛓️ %s uygulandı: meydanda kalan %s katılımcı etkilendi%s. Sert yaptırım kamuoyunda tepki çekti (hükümet memnuniyeti −0,2).',
  ad,n,case when top>0 then ' (toplam '||oyun.tl(top)||' ₺)' else '' end));
 if b.tur='disiplin' then
  insert into oyun.bildirimler(user_id,zaman,metin)
  select m.user_id,t,format('📁 Disiplin raporu: %s meydanındaki eyleme katılan %s kamu görevlisi hakkında soruşturma açıldı.',il_ad,n)
  from oyun.makamlar m where m.bit is null and m.tur='cb';
 end if;
end $$;

-- ---------------------------------------------------------------------
-- Doruk sonuçları
-- ---------------------------------------------------------------------
create or replace function oyun.sokak_gozalti_dalgasi(p_id bigint)
returns void language plpgsql security definer set search_path='' as $$
declare b oyun.sokak_bireysel; x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); toplam integer; hedef integer; pid bigint; u uuid; n integer:=0; il_ad text; adlar text:='';
begin
 select * into b from oyun.sokak_bireysel where id=p_id for update;
 if b.id is null or b.durum<>'ihtar' then return; end if;
 select * into x from oyun.sokak_eylem where id=b.eylem_id;
 il_ad:=(select ad from oyun.iller where id=x.il_id);
 select count(*) into toplam from oyun.sokak_meydandakiler(x.id);
 hedef:=least(6,greatest(1,ceil(toplam*0.20)::int));
 if not exists(select 1 from oyun.sokak_gozaltilabilir(x.id)) then
  update oyun.sokak_bireysel set durum='bos' where id=b.id;
  perform oyun.sokak_duyur(x.id,'🚓 Gözaltı dalgasının saati geldi ama meydanda gözaltına alınabilecek kimse kalmadı.');
  return;
 end if;
 insert into oyun.sokak_polis(eylem_id,yapan,seviye,gerekce,bedel,hedef_sayi,zaman,tepki,gorevli_sayi)
 values(x.id,b.yapan,'yuksek',b.gerekce,0,hedef,t,0,0) returning id into pid;
 for u in select g from oyun.sokak_gozaltilabilir(x.id) g order by (g=x.baslatan) desc, random() limit hedef loop
  insert into oyun.sokak_gozalti(polis_id,eylem_id,hedef,baslangic,bitis) values(pid,x.id,u,t,b.bitis);
  insert into oyun.sokak_bireysel_hedef(yaptirim_id,user_id,tur,tutar,bitis) values(b.id,u,'gozalti',0,b.bitis) on conflict do nothing;
  insert into oyun.bildirimler(user_id,zaman,metin) values(u,t,format('🚓 %s meydanındaki gözaltı dalgasında 6 saatliğine gözaltına alındın (bitiş %s). Avukat çağırabilir ya da barodan müdafi isteyebilirsin; sohbetlere yalnız avukatınla yazabilirsin.',
   il_ad,to_char(b.bitis at time zone 'Europe/Istanbul','DD.MM HH24:MI')));
  adlar:=adlar||case when n>0 then ', ' else '' end||'@'||coalesce(oyun.kad(u),'?');
  n:=n+1;
 end loop;
 update oyun.sokak_polis set alinan_sayi=n where id=pid;
 update oyun.sokak_bireysel set durum='uygulandi',etkilenen=n where id=b.id;
 update oyun.ulke set memnuniyet=greatest(0,memnuniyet-0.2) where id=1;
 perform oyun.sokak_duyur(x.id,format('🚓 Gözaltı dalgası: %s meydanında kalan %s kişiden %s''i 6 saatliğine gözaltına alındı (%s). Gözaltındakiler meydan gücüne sayılmaz. Sert müdahale kamuoyunda tepki çekti (hükümet memnuniyeti −0,2).',
  il_ad,toplam,n,adlar));
 perform oyun.sokak_yenile(x.id);
end $$;

create or replace function oyun.sokak_itibar_ekle(u uuid, p integer) returns void
language sql set search_path='' as $$
 insert into oyun.sokak_itibar(user_id,puan) values(u,p) on conflict(user_id) do update set puan=oyun.sokak_itibar.puan+excluded.puan
$$;

create or replace function oyun.sokak_doruk_sonuc(e bigint, p_sonuc text)
returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); u uuid; n integer:=0; il_ad text; d oyun.sokak_doruk;
begin
 select * into d from oyun.sokak_doruk where eylem_id=e for update;
 if d.eylem_id is null or d.durum<>'ultimatom' then return; end if;
 il_ad:=(select i.ad from oyun.iller i join oyun.sokak_eylem x on x.il_id=i.id where x.id=e);
 if p_sonuc in ('uzlasma','bastirildi') then
  for u in select * from oyun.sokak_meydandakiler(e) loop
   perform oyun.sokak_itibar_ekle(u,case when p_sonuc='uzlasma' then 5 else 3 end); n:=n+1;
  end loop;
 end if;
 if p_sonuc='uzlasma' then
  update oyun.ulke set memnuniyet=least(100,memnuniyet+0.5) where id=1;
  perform oyun.sokak_duyur(e,format('🤝 Doruk noktasındaki %s meydanı uzlaşmayla sonuçlandı. Hükümet sözünü verdi, meydan masaya oturdu. Katılımcılara +5 meydan itibarı.',il_ad));
 elsif p_sonuc='bastirildi' then
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-0.5) where id=1;
  perform oyun.sokak_duyur(e,format('🛡️ Hükümet ültimatomu atlattı: %s meydanı doruk gücünü koruyamadı. Sert bastırma tartışması sürüyor (hükümet memnuniyeti −0,5). Direnenlere +3 meydan itibarı.',il_ad));
 else
  perform oyun.sokak_duyur(e,format('%s meydanı ültimatom bitmeden dağıldı.',il_ad));
 end if;
 update oyun.sokak_doruk set durum=p_sonuc, sonuc_zaman=t, sonuc=jsonb_build_object('odullu',n) where eylem_id=e;
end $$;

create or replace function oyun.sokak_doruk_zafer(e bigint)
returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); x oyun.sokak_eylem; u uuid; n integer:=0; h record; il_ad text; iade numeric:=0;
begin
 select * into x from oyun.sokak_eylem where id=e for update;
 if x.id is null then return; end if;
 if not exists(select 1 from oyun.sokak_doruk where eylem_id=e and durum='ultimatom') then return; end if;
 il_ad:=(select ad from oyun.iller where id=x.il_id);
 for u in select * from oyun.sokak_meydandakiler(e) loop
  perform oyun.kidem_ekle(u,3::numeric);
  perform oyun.sokak_itibar_ekle(u,10);
  insert into oyun.sokak_rozet(user_id,eylem_id) values(u,e) on conflict do nothing;
  insert into oyun.bildirimler(user_id,zaman,metin) values(u,t,format('🏆 Halkın Zaferi! %s meydanı hükümetin ültimatomunu aştı. +3 kıdem, +10 meydan itibarı ve zafer rozeti kazandın.',il_ad));
  n:=n+1;
 end loop;
 -- bu eylemdeki bireysel yaptırımlar kalkar
 for h in select hd.* from oyun.sokak_bireysel_hedef hd join oyun.sokak_bireysel b on b.id=hd.yaptirim_id
   where b.eylem_id=e and hd.iade_durum='bekliyor' for update of hd loop
  perform oyun.para_islem(h.user_id,h.tutar,'teminat',format('Halkın zaferi: %s meydanındaki ihtiyati tedbir kaldırıldı, bloke para iade edildi',il_ad),t);
  update oyun.sokak_bireysel_hedef set iade_durum='iade',iade_zaman=t where yaptirim_id=h.yaptirim_id and user_id=h.user_id;
  iade:=iade+h.tutar;
 end loop;
 update oyun.sokak_bireysel_hedef hd set bitis=t from oyun.sokak_bireysel b
  where b.id=hd.yaptirim_id and b.eylem_id=e and hd.tur in ('seyahat','erisim') and hd.bitis>t;
 update oyun.sokak_bireysel set durum='geri' where eylem_id=e and durum='ihtar';
 -- ülke
 update oyun.ulke set memnuniyet=greatest(0,memnuniyet-3), buyume=greatest(-20,buyume-0.3) where id=1;
 update oyun.sokak_kriz set
  kirmizi_baslangic=case when kirmizi_baslangic is not null then kirmizi_baslangic-interval '12 hours' end,
  ivme_saat=case when kirmizi_baslangic is null then least(48,coalesce(ivme_saat,0)+12) else ivme_saat end
 where id=1;
 -- meydan zaferle dağılır
 update oyun.sokak_eylem set durum='bitti',kapandi=t,kirmizi_baslangic=null,seviye=0,kapanma_nedeni='halk_zaferi' where id=e;
 update oyun.sokak_gorevli set ayrilma=t where eylem_id=e and ayrilma is null;
 update oyun.sokak_doruk set durum='zafer',sonuc_zaman=t,mesruiyet_bitis=t+interval '48 hours',cb_karar_son=t+interval '24 hours',
  sonuc=jsonb_build_object('odullu',n,'iade',iade) where eylem_id=e;
 perform oyun.sokak_duyur(e,format('🏆 HALKIN ZAFERİ · %s meydanı 6 saatlik ültimatomu aştı ve zaferle dağıldı. Hükümet memnuniyeti −3, büyüme −0,3; erken seçim sayacı 12 saat öne çekildi. %s ilinde 48 saat bireysel yaptırım uygulanamaz. Cumhurbaşkanının kararı bekleniyor (24 saat).',il_ad,il_ad));
 perform oyun.olay('siyaset',format('SON DAKİKA · %s''da halk kazandı: meydan hükümetin ültimatomunu aştı. Gözler Cumhurbaşkanında.',il_ad),x.il_id,x.parti_id);
 insert into oyun.bildirimler(user_id,zaman,metin)
 select m.user_id,t,format('🏆 %s meydanında halk kazandı. 24 saat içinde Halk Hareketleri ekranından kararını ver: İçişleri Bakanını görevden almak, talebi kabul etmek ya da direnmek. Karar vermezsen "direniş" sayılır.',il_ad)
 from oyun.makamlar m where m.bit is null and m.tur='cb';
 perform oyun.sokak_kriz_kontrol();
end $$;

create or replace function oyun.sokak_doruk_karar_uygula(e bigint, p_karar text, u uuid, p_gerekce text)
returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); d oyun.sokak_doruk; m record; il_ad text; x oyun.sokak_eylem; msg text;
begin
 select * into d from oyun.sokak_doruk where eylem_id=e for update;
 if d.eylem_id is null or d.durum<>'zafer' or d.cb_karar is not null then raise exception 'Bu meydan için karar beklenmiyor.'; end if;
 select * into x from oyun.sokak_eylem where id=e;
 il_ad:=(select ad from oyun.iller where id=x.il_id);
 if p_karar='istifa' then
  if not exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik='icisleri' and bit is null) then raise exception 'İçişleri Bakanlığı zaten boş.'; end if;
  for m in select id,user_id from oyun.makamlar where tur='bakan' and bakanlik='icisleri' and bit is null loop
   perform oyun.makam_bitir(m.id,t,'gorevden_alindi');
   insert into oyun.bildirimler(user_id,zaman,metin) values(m.user_id,t,format('Cumhurbaşkanı, %s meydanındaki halk zaferinin ardından seni İçişleri Bakanlığı görevinden aldı.',il_ad));
   msg:=format('🏛️ Cumhurbaşkanı, %s meydanındaki halk zaferinin ardından İçişleri Bakanı %s''i görevden aldı. Hükümet memnuniyeti +2.',il_ad,oyun.kad(m.user_id));
  end loop;
  update oyun.ulke set memnuniyet=least(100,memnuniyet+2) where id=1;
 elsif p_karar='talep' then
  update oyun.ulke set memnuniyet=least(100,memnuniyet+1.5) where id=1;
  msg:=format('🕊️ Cumhurbaşkanı %s meydanının talebini kamuoyu önünde kabul etti. Hükümet memnuniyeti +1,5.',il_ad);
 elsif p_karar in ('diren','sure_doldu') then
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
  update oyun.sokak_kriz set
   kirmizi_baslangic=case when kirmizi_baslangic is not null then kirmizi_baslangic-interval '6 hours' end,
   ivme_saat=case when kirmizi_baslangic is null then least(48,coalesce(ivme_saat,0)+6) else ivme_saat end where id=1;
  msg:=case when p_karar='diren' then format('✊ Cumhurbaşkanı %s meydanına geri adım atmadı. Tepki büyüyor: hükümet memnuniyeti −1, erken seçim sayacı 6 saat daha öne çekildi.',il_ad)
       else format('⌛ Cumhurbaşkanı %s meydanının zaferine 24 saat yanıt vermedi; sessizlik direniş sayıldı. Hükümet memnuniyeti −1, erken seçim sayacı 6 saat daha öne çekildi.',il_ad) end;
 else raise exception 'Geçersiz karar.'; end if;
 if p_gerekce is not null and btrim(p_gerekce)<>'' then msg:=msg||' Açıklama: '||btrim(p_gerekce); end if;
 update oyun.sokak_doruk set cb_karar=p_karar,cb_karar_zaman=t,cb_gerekce=nullif(btrim(coalesce(p_gerekce,'')),'') where eylem_id=e;
 perform oyun.sokak_duyur(e,msg);
end $$;

create or replace function public.sokak_doruk_karar(p_eylem bigint, p_karar text, p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=oyun.ben(); g text:=btrim(coalesce(p_gerekce,''));
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 if not exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb') then raise exception 'Bu kararı yalnız Cumhurbaşkanı verebilir.'; end if;
 if p_karar not in ('istifa','talep','diren') then raise exception 'Geçersiz karar.'; end if;
 if char_length(g)>500 then raise exception 'Açıklama en çok 500 karakter olabilir.'; end if;
 perform oyun.sokak_doruk_karar_uygula(p_eylem,p_karar,u,g);
 return public.sokak_doruk_panel(p_eylem);
end $$;

-- ---------------------------------------------------------------------
-- Zamanlayıcı
-- ---------------------------------------------------------------------
create or replace function oyun.sokak_doruk_tick()
returns void language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); r record; x oyun.sokak_eylem; d oyun.sokak_doruk; il_ad text;
begin
 if not pg_try_advisory_xact_lock(781231,7) then return; end if;
 if not coalesce((select aktif from oyun.sokak_eylem_ayar where id=1),false) then return; end if;
 -- 1) süresi gelen ihtarlar
 for r in select id from oyun.sokak_bireysel where durum='ihtar' and uygulama<=t order by id loop
  perform oyun.sokak_bireysel_uygula(r.id);
 end loop;
 -- 2) teminat iadeleri
 for r in select h.* from oyun.sokak_bireysel_hedef h where h.iade_durum='bekliyor' and h.iade_zaman<=t loop
  perform oyun.para_islem(r.user_id,r.tutar,'teminat','İhtiyati tedbir sona erdi: bloke para iade edildi',t);
  update oyun.sokak_bireysel_hedef set iade_durum='iade' where yaptirim_id=r.yaptirim_id and user_id=r.user_id;
  insert into oyun.bildirimler(user_id,zaman,metin) values(r.user_id,t,format('🏦 İhtiyati tedbir sona erdi: %s ₺ cüzdanına iade edildi.',oyun.tl(r.tutar)));
 end loop;
 -- 3) yeni doruklar
 for x in select * from oyun.sokak_eylem e where e.durum='aktif' and e.kirmizi_baslangic is not null and e.seviye>=95 and e.bitis>t
   and not exists(select 1 from oyun.sokak_doruk k where k.eylem_id=e.id) order by e.id loop
  insert into oyun.sokak_doruk(eylem_id,baslangic,ultimatom,tepe) values(x.id,t,t+interval '6 hours',x.seviye) on conflict do nothing;
  if x.bitis<t+interval '6 hours 10 minutes' then update oyun.sokak_eylem set bitis=t+interval '6 hours 10 minutes' where id=x.id; end if;
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
  il_ad:=(select ad from oyun.iller where id=x.il_id);
  perform oyun.sokak_duyur(x.id,format('🔥 DORUK ANI · %s meydanı tam güce ulaştı. Hükümete 6 saatlik ültimatom: %s saatine kadar güç 85''in altına indirilemez ya da uzlaşma sağlanamazsa HALKIN ZAFERİ ilan edilecek. Hükümet memnuniyeti −1.',
   il_ad,to_char((t+interval '6 hours') at time zone 'Europe/Istanbul','HH24:MI')));
  perform oyun.olay('siyaset',format('SON DAKİKA · %s meydanı doruğa ulaştı: hükümete 6 saatlik ültimatom.',il_ad),x.il_id,x.parti_id);
  insert into oyun.bildirimler(user_id,zaman,metin)
  select distinct a.hedef,t,format('🔥 %s meydanı doruğa ulaştı: 6 saatlik ültimatom başladı.',il_ad)
  from oyun.icisleri_atama a where a.il_id=x.il_id and a.tur='vali' and a.durum='aktif' and (a.bitis is null or a.bitis>t);
 end loop;
 -- 4) ültimatomlar
 for d in select * from oyun.sokak_doruk where durum='ultimatom' order by eylem_id loop
  select * into x from oyun.sokak_eylem where id=d.eylem_id;
  update oyun.sokak_doruk set tepe=greatest(tepe,coalesce(x.seviye,0)) where eylem_id=d.eylem_id;
  if x.durum='aktif' and d.ultimatom>t then continue; end if;
  if exists(select 1 from oyun.sokak_soz s where s.eylem_id=x.id and s.durum in ('takip','tutuldu')) then
   perform oyun.sokak_doruk_sonuc(x.id,'uzlasma');
  elsif x.durum='aktif' then
   if x.seviye>=85 then perform oyun.sokak_doruk_zafer(x.id); else perform oyun.sokak_doruk_sonuc(x.id,'bastirildi'); end if;
  elsif x.durum='yatisti' then
   perform oyun.sokak_doruk_sonuc(x.id,'bastirildi');
  else
   perform oyun.sokak_doruk_sonuc(x.id,'dagildi');
  end if;
 end loop;
 -- 5) Cumhurbaşkanı süresinde karar vermediyse
 for d in select * from oyun.sokak_doruk where durum='zafer' and cb_karar is null and cb_karar_son<=t loop
  perform oyun.sokak_doruk_karar_uygula(d.eylem_id,'sure_doldu',null,null);
 end loop;
end $$;

-- ---------------------------------------------------------------------
-- Paneller
-- ---------------------------------------------------------------------
create or replace function public.sokak_doruk_panel(p_eylem bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=oyun.ben(); t timestamptz:=oyun.simdi(); x oyun.sokak_eylem; d oyun.sokak_doruk; yet boolean; cb boolean; kat boolean;
 kat_j jsonb; liste jsonb; benim jsonb; ihtar jsonb;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if x.id is null then raise exception 'Eylem bulunamadı.'; end if;
 select * into d from oyun.sokak_doruk where eylem_id=p_eylem;
 yet:=oyun.sokak_sert_yetkili(u,x.il_id);
 cb:=exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb');
 kat:=exists(select 1 from oyun.sokak_meydandakiler(p_eylem) m where m=u);
 select coalesce(jsonb_agg(e || jsonb_build_object('bedel',oyun.sokak_bireysel_bedel(e->>'tur',x.il_id),
   'engel',case when yet then oyun.sokak_bireysel_engel(u,p_eylem,e->>'tur') else 'yetki' end)),'[]'::jsonb)
  into kat_j from jsonb_array_elements(oyun.sokak_bireysel_katalog()) e;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'tur',b.tur,'ad',oyun.sokak_bireysel_ad(b.tur),'yapan',oyun.sokak_unvan(b.yapan,x.il_id),
   'gerekce',b.gerekce,'durum',b.durum,'zaman',b.zaman,'uygulama',b.uygulama,'bitis',b.bitis,'etkilenen',b.etkilenen,'toplam',b.toplam,
   'geri_cekebilir',(b.durum='ihtar' and (b.yapan=u or oyun.sokak_yonetebilir(u)))) order by b.zaman desc),'[]'::jsonb)
  into liste from (select * from oyun.sokak_bireysel where eylem_id=p_eylem order by zaman desc limit 20) b;
 select to_jsonb(q) into ihtar from (select b.id,b.tur,oyun.sokak_bireysel_ad(b.tur) ad,b.uygulama,b.gerekce from oyun.sokak_bireysel b where b.eylem_id=p_eylem and b.durum='ihtar' order by b.id limit 1) q;
 select coalesce(jsonb_agg(jsonb_build_object('tur',h.tur,'ad',oyun.sokak_bireysel_ad(h.tur),'tutar',h.tutar,'bitis',h.bitis,'iade_zaman',h.iade_zaman,'iade_durum',h.iade_durum,'eylem_id',b.eylem_id)),'[]'::jsonb)
  into benim from oyun.sokak_bireysel_hedef h join oyun.sokak_bireysel b on b.id=h.yaptirim_id
  where h.user_id=u and (h.bitis>t or h.iade_durum='bekliyor' or b.zaman>t-interval '24 hours');
 return jsonb_build_object('eylem_id',x.id,'simdi',t,'aktif',x.durum='aktif','seviye',x.seviye,'kirmizi',x.kirmizi_baslangic is not null,
  'il',(select ad from oyun.iller where id=x.il_id),
  'kosul',jsonb_build_object('doruk',95,'zafer',85,'ultimatom_saat',6,'ihtar_dk',30),
  'doruk',case when d.eylem_id is null then null else jsonb_build_object('durum',d.durum,'baslangic',d.baslangic,'ultimatom',d.ultimatom,'tepe',d.tepe,
    'sonuc_zaman',d.sonuc_zaman,'sonuc',d.sonuc,'cb_karar',d.cb_karar,'cb_karar_zaman',d.cb_karar_zaman,'cb_karar_son',d.cb_karar_son,'cb_gerekce',d.cb_gerekce,'mesruiyet_bitis',d.mesruiyet_bitis) end,
  'rol',jsonb_build_object('yetkili',yet,'cb',cb,'katilimci',kat),
  'icisleri_dolu',exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik='icisleri' and bit is null),
  'mesruiyet_bitis',oyun.sokak_mesruiyet_bitis(x.il_id),
  'katalog',kat_j,'yaptirimlar',liste,'ihtar',ihtar,'benim',benim);
end $$;

-- Ana ekran: süren doruklar, son 48 saatteki zaferler ve bana uygulanan yaptırımlar
create or replace function public.sokak_doruk_ozet()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=oyun.ben(); t timestamptz:=oyun.simdi(); L jsonb; benim jsonb; cb boolean;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 cb:=exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur='cb');
 select coalesce(jsonb_agg(jsonb_build_object('eylem_id',d.eylem_id,'il',i.ad,'durum',d.durum,'ultimatom',d.ultimatom,'seviye',e.seviye,'tepe',d.tepe,
   'sonuc_zaman',d.sonuc_zaman,'cb_karar',d.cb_karar,'cb_karar_son',d.cb_karar_son,'cb_gerekce',d.cb_gerekce,'mesruiyet_bitis',d.mesruiyet_bitis,'sonuc',d.sonuc) order by d.baslangic desc),'[]'::jsonb)
  into L from oyun.sokak_doruk d join oyun.sokak_eylem e on e.id=d.eylem_id join oyun.iller i on i.id=e.il_id
  where d.durum='ultimatom' or d.sonuc_zaman>t-interval '48 hours';
 select coalesce(jsonb_agg(jsonb_build_object('tur',h.tur,'ad',oyun.sokak_bireysel_ad(h.tur),'tutar',h.tutar,'bitis',h.bitis,'iade_zaman',h.iade_zaman,'iade_durum',h.iade_durum,'eylem_id',b.eylem_id)),'[]'::jsonb)
  into benim from oyun.sokak_bireysel_hedef h join oyun.sokak_bireysel b on b.id=h.yaptirim_id
  where h.user_id=u and (h.bitis>t or h.iade_durum='bekliyor');
 return jsonb_build_object('simdi',t,'cb',cb,'icisleri_dolu',exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik='icisleri' and bit is null),'doruklar',L,'benim',benim);
end $$;

-- ---------------------------------------------------------------------
-- Kancalar: il değiştirme yasağı ve Kürsü erişim engeli
-- ---------------------------------------------------------------------
create or replace function oyun.sokak_bireysel_aktif(u uuid, k text) returns timestamptz
language sql stable set search_path='' as $$
 select max(h.bitis) from oyun.sokak_bireysel_hedef h where h.user_id=u and h.tur=k and h.bitis>oyun.simdi()
$$;

create or replace function oyun.il_tasinma_engeli(p oyun.profiller, p_il smallint, t timestamp with time zone)
 returns text
 language plpgsql
 stable
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare
  gun int := oyun.il_bekleme_gun(t);
  kilit text;
  sy timestamptz;
begin
  if not exists (select 1 from oyun.iller where id = p_il) then
    return 'Geçersiz il.';
  end if;
  if p.il_id = p_il then return 'Zaten bu ildesin.'; end if;
  -- 13.11.2026 Halk Hareketleri: il dışına çıkış yasağı
  sy := oyun.sokak_bireysel_aktif(p.id, 'seyahat');
  if sy is not null then
    return format('Halk Hareketleri kapsamında il dışına çıkış yasağın var: %s saatine kadar il değiştiremezsin.',
      to_char(sy at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'));
  end if;
  kilit := oyun.il_kilit_nedeni(t, p.il_id, p_il);
  if kilit is not null then return kilit; end if;
  if p.son_il_degis is not null
     and p.son_il_degis + make_interval(days => gun) > t then
    return format('İl en fazla %s günde bir değiştirilebilir. Bir sonraki: %s',
      gun, to_char(
        (p.son_il_degis + make_interval(days => gun)) at time zone 'Europe/Istanbul',
        'DD.MM.YYYY HH24:MI'));
  end if;
  if exists (
    select 1 from oyun.makamlar
    where user_id = p.id and bit is null and tur in ('mv','bel')
  ) then
    return 'Görevdeki vekil veya belediye başkanı il değiştiremez.';
  end if;
  if oyun.tasinma_ucreti(p.il_id, p_il, t) >
     coalesce((select para from oyun.cuzdan where user_id = p.id), 0) then
    return format('Cüzdanında yeterli para yok. Taşınma ücreti: %s ₺.',
      oyun.tl(oyun.tasinma_ucreti(p.il_id, p_il, t)));
  end if;
  return null;
end $function$;

create or replace function oyun.sokak_erisim_engel_trg() returns trigger
language plpgsql set search_path='' as $$
declare b timestamptz;
begin
 if auth.uid() is null or new.user_id is distinct from auth.uid() then return new; end if;
 b:=oyun.sokak_bireysel_aktif(new.user_id,'erisim');
 if b is not null then
  raise exception 'Halk Hareketleri kapsamında erişim engelin var: % saatine kadar Kürsü''de paylaşım yapamazsın. Meydan sohbeti açık.',
   to_char(b at time zone 'Europe/Istanbul','DD.MM HH24:MI');
 end if;
 return new;
end $$;
do $$ begin
 if not exists(select 1 from pg_trigger where tgname='sokak_erisim_engel' and tgrelid='oyun.akis'::regclass) then
  create trigger sokak_erisim_engel before insert on oyun.akis for each row execute function oyun.sokak_erisim_engel_trg();
 end if;
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler ve zamanlayıcı
-- ---------------------------------------------------------------------
revoke all on function public.sokak_doruk_panel(bigint) from public, anon;
revoke all on function public.sokak_doruk_ozet() from public, anon;
revoke all on function public.sokak_doruk_karar(bigint,text,text) from public, anon;
revoke all on function public.sokak_bireysel_ihtar(bigint,text,text) from public, anon;
revoke all on function public.sokak_bireysel_geri(bigint) from public, anon;
grant execute on function public.sokak_doruk_panel(bigint) to authenticated;
grant execute on function public.sokak_doruk_ozet() to authenticated;
grant execute on function public.sokak_doruk_karar(bigint,text,text) to authenticated;
grant execute on function public.sokak_bireysel_ihtar(bigint,text,text) to authenticated;
grant execute on function public.sokak_bireysel_geri(bigint) to authenticated;
do $$ declare f text; begin
 foreach f in array array['oyun.sokak_bireysel_katalog()','oyun.sokak_bireysel_ad(text)','oyun.sokak_bireysel_bedel(text,integer)',
  'oyun.sokak_meydandakiler(bigint)','oyun.sokak_gozaltilabilir(bigint)','oyun.sokak_gozalti_dalgasi(bigint)','oyun.sokak_unvan(uuid,integer)','oyun.sokak_mesruiyet_bitis(integer)','oyun.sokak_bireysel_engel(uuid,bigint,text)',
  'oyun.sokak_bireysel_uygula(bigint)','oyun.sokak_itibar_ekle(uuid,integer)','oyun.sokak_doruk_sonuc(bigint,text)','oyun.sokak_doruk_zafer(bigint)',
  'oyun.sokak_doruk_karar_uygula(bigint,text,uuid,text)','oyun.sokak_doruk_tick()','oyun.sokak_bireysel_aktif(uuid,text)','oyun.sokak_erisim_engel_trg()'] loop
  execute format('revoke all on function %s from public, anon, authenticated', f);
 end loop;
end $$;

do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
  if exists(select 1 from cron.job where jobname='halk-doruk') then perform cron.unschedule('halk-doruk'); end if;
  perform cron.schedule('halk-doruk','2-59/5 * * * *','select oyun.sokak_doruk_tick()');
 end if;
end $$;
commit;
