-- =====================================================================
--  On sert hükümet önlemi. Çabuk sonuç, sonra oy kaybı.
--  Yetki: Cumhurbaşkanı, İçişleri Bakanı veya o ilin valisi.
--  Bedel İçişleri kasasından. Açılış 50.000 TL ise katlar aşağıdadır.
--  Küfür süzgeci ve sicil kaydı mevcut meydan düzenine bağlanır.
--  Canlı veritabanına bu dosya elle uygulanır.
-- =====================================================================

create table if not exists oyun.sokak_sert(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 tur text not null check(tur in ('safak','elebasi','mali','kapatma','ohal','propaganda','bol','kusatma','ihale','sanal')),
 yapan uuid not null references oyun.profiller,
 gerekce text not null check(char_length(gerekce) between 20 and 500),
 bedel numeric not null check(bedel>=0),
 durum text not null default 'aktif' check(durum in ('aktif','bitti','basarisiz','onay','red','aykiri','uygun')),
 zaman timestamptz not null, bitis timestamptz not null,
 etki jsonb not null default '{}'::jsonb
);
create index if not exists sokak_sert_eylem on oyun.sokak_sert(eylem_id,zaman desc);
create table if not exists oyun.sokak_nobet_rota(
 eylem_id bigint not null, user_id uuid not null, gun date not null, zaman timestamptz not null,
 primary key(eylem_id,user_id,gun)
);
create table if not exists oyun.sokak_disari(
 eylem_id bigint not null, user_id uuid not null, tur text not null, bitis timestamptz not null,
 primary key(eylem_id,user_id,tur)
);
create table if not exists oyun.sokak_lider_oy(
 eylem_id bigint not null, veren uuid not null, aday uuid not null, primary key(eylem_id,veren)
);
create table if not exists oyun.sokak_fraksiyon(
 eylem_id bigint not null, user_id uuid not null, taraf text not null check(taraf in ('kabul','direnis')),
 primary key(eylem_id,user_id)
);
create table if not exists oyun.sokak_birlik_oy(
 eylem_id bigint not null, user_id uuid not null, primary key(eylem_id,user_id)
);
create table if not exists oyun.sokak_ziyaret(
 eylem_id bigint not null, user_id uuid not null, zaman timestamptz not null, primary key(eylem_id,user_id)
);
create table if not exists oyun.sokak_ohal(
 id bigint generated always as identity primary key,
 il_id integer not null, eylem_id bigint, yapan uuid not null,
 durum text not null check(durum in ('onay','yururluk','red')),
 zaman timestamptz not null, bitis timestamptz not null
);
create table if not exists oyun.sokak_ohal_oy(
 ohal_id bigint not null references oyun.sokak_ohal, user_id uuid not null, oy text not null,
 primary key(ohal_id,user_id)
);
create table if not exists oyun.sokak_yargi_oy(
 sert_id bigint not null references oyun.sokak_sert, user_id uuid not null, oy text not null,
 primary key(sert_id,user_id)
);
create table if not exists oyun.sokak_ihale_aski(
 sirket_id bigint not null, eylem_id bigint not null, onceki timestamptz, bitis timestamptz not null,
 primary key(sirket_id,eylem_id)
);
alter table oyun.sokak_sert enable row level security;
alter table oyun.sokak_nobet_rota enable row level security;
alter table oyun.sokak_disari enable row level security;
alter table oyun.sokak_lider_oy enable row level security;
alter table oyun.sokak_fraksiyon enable row level security;
alter table oyun.sokak_birlik_oy enable row level security;
alter table oyun.sokak_ziyaret enable row level security;
alter table oyun.sokak_ohal enable row level security;
alter table oyun.sokak_ohal_oy enable row level security;
alter table oyun.sokak_yargi_oy enable row level security;
alter table oyun.sokak_ihale_aski enable row level security;
revoke all on oyun.sokak_sert,oyun.sokak_nobet_rota,oyun.sokak_disari,oyun.sokak_lider_oy,oyun.sokak_fraksiyon,oyun.sokak_birlik_oy,oyun.sokak_ziyaret,oyun.sokak_ohal,oyun.sokak_ohal_oy,oyun.sokak_yargi_oy,oyun.sokak_ihale_aski from public,anon,authenticated;

create or replace function oyun.sokak_sert_yetkili(u uuid, il integer) returns boolean
language sql stable set search_path='' as $$
 select oyun.sokak_yonetebilir(u)
  or exists(select 1 from oyun.icisleri_atama a where a.hedef=u and a.tur='vali' and a.il_id=il and a.durum='aktif' and (a.bitis is null or a.bitis>oyun.simdi()))
$$;
create or replace function oyun.sokak_ohal_aktif(il integer) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_ohal where il_id=il and durum='yururluk' and bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_giris_kapali(e bigint) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_sert s where s.eylem_id=e and s.tur='kusatma' and s.durum='aktif' and s.bitis>oyun.simdi())
  or exists(select 1 from oyun.sokak_eylem x where x.id=e and oyun.sokak_ohal_aktif(x.il_id))
$$;
create or replace function oyun.sokak_fon_kapali(e bigint) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_sert s where s.eylem_id=e and s.tur='mali' and s.durum='aktif' and s.bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_cift_bedel(e bigint) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_sert s where s.eylem_id=e and s.tur='kapatma' and s.durum='aktif' and s.bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_disarida(u uuid, e bigint) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_disari d where d.user_id=u and d.eylem_id=e and d.bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_sesi_kapali(u uuid, e bigint) returns boolean
language sql stable set search_path='' as $$
 select exists(select 1 from oyun.sokak_disari d where d.user_id=u and d.eylem_id=e and d.tur='sanal' and d.bitis>oyun.simdi())
$$;
create or replace function oyun.sokak_sert_ad(k text) returns text
language sql immutable set search_path='' as $$
 select case k
  when 'safak' then 'Şafak Operasyonu' when 'elebasi' then 'Elebaşı Gözaltısı'
  when 'mali' then 'Mali Kuşatma' when 'kapatma' then 'Kapatma Davası Tehdidi'
  when 'ohal' then 'OHAL' when 'propaganda' then 'Kara Propaganda'
  when 'bol' then 'Böl ve Yönet' when 'kusatma' then 'Kuşatma Çemberi'
  when 'ihale' then 'İhale ve Lisans Kılıcı' when 'sanal' then 'Toplu Sanal Gözaltı' else k end
$$;
create or replace function oyun.sokak_sert_bedel(k text, il integer) returns numeric
language sql stable set search_path='' as $$
 select round((case k
  when 'safak' then 4 when 'elebasi' then 3 when 'mali' then 5 when 'kapatma' then 2
  when 'ohal' then 6 when 'propaganda' then 2 when 'bol' then 3 when 'kusatma' then 4
  when 'ihale' then 3 when 'sanal' then 8 else 0 end) * a.baslatma_bedeli
  * case when oyun.sokak_ohal_aktif(il) and k<>'ohal' then 0.5 else 1 end, 2)
 from oyun.sokak_eylem_ayar a where a.id=1
$$;

create or replace function oyun.sokak_eylemi_kapat(e bigint, neden text) returns void
language plpgsql set search_path='' as $$
declare t timestamptz:=oyun.simdi();
begin
 update oyun.sokak_eylem set durum='yatisti', kapandi=t, kirmizi_baslangic=null, seviye=0 where id=e and durum='aktif';
 update oyun.sokak_gorevli set ayrilma=t where eylem_id=e and ayrilma is null;
 perform oyun.sokak_duyur(e, neden);
 perform oyun.sokak_yenile(e);
 perform oyun.sokak_kriz_kontrol();
end $$;

-- ───────────── açılış ve karşı hamle ─────────────
create or replace function public.sokak_sert_islem(p_eylem bigint, p_islem text, p_veri jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi();
 txt text; tut numeric; saat int; n int; nobet int; gerek int; nobet_gun date; h uuid; sid bigint;
 rec record; yari int; evet int; hayir int; oid bigint; aday uuid;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(781231,1);
 if p_eylem is not null then select * into x from oyun.sokak_eylem where id=p_eylem for update; end if;
 txt:=nullif(btrim(coalesce(p_veri->>'metin','')),'');

 if p_islem='ac' then
  if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli'; end if;
  if not oyun.sokak_sert_yetkili(u, x.il_id) then raise exception 'Bunu Cumhurbaşkanı, İçişleri Bakanı veya ilin valisi kullanır'; end if;
  if coalesce(p_veri->>'tur','') not in ('safak','elebasi','mali','kapatma','ohal','propaganda','bol','kusatma','ihale','sanal') then raise exception 'Geçersiz sert önlem'; end if;
  if exists(select 1 from oyun.sokak_soz where eylem_id=x.id and durum='takip') then raise exception 'Uzlaşma takibinde sert önlem yok'; end if;
  txt:=oyun.sokak_temiz(coalesce(p_veri->>'gerekce',''),500);
  if char_length(txt)<20 then raise exception 'Gerekçe 20–500 karakter olmalı'; end if;
  if exists(select 1 from oyun.sokak_sert where eylem_id=x.id and tur=p_veri->>'tur' and durum in ('aktif','onay','yururluk') and bitis>t) then raise exception 'Bu önlem sürüyor'; end if;
  if exists(select 1 from oyun.sokak_sert where eylem_id=x.id and tur=p_veri->>'tur') and p_veri->>'tur'<>'safak' then raise exception 'Bu önlem bu eylemde bir kez kullanılır'; end if;
  if (select count(*) from oyun.sokak_sert where eylem_id=x.id and zaman>t-interval '12 hours')>=2 then raise exception '12 saatte en çok 2 sert önlem'; end if;
  if exists(select 1 from oyun.sokak_sert where eylem_id=x.id and zaman>t-interval '3 hours') then raise exception 'Sert önlemler arasında 3 saat gerekir'; end if;
  tut:=oyun.sokak_sert_bedel(p_veri->>'tur', x.il_id);
  perform oyun.bm_kasa_harca('icisleri',tut/oyun.pazar_tl_milyar(),'gider',oyun.sokak_sert_ad(p_veri->>'tur')||' eylem #'||x.id);
  perform oyun.sokak_sicil_yaz(u,x.id,'sert',oyun.sokak_sert_ad(p_veri->>'tur'));

  if p_veri->>'tur'='safak' then
   saat:=extract(hour from t at time zone 'Europe/Istanbul')::int;
   if saat<4 or saat>=6 then raise exception 'Şafak operasyonu yalnız 04.00–06.00 arasında kullanılır'; end if;
   nobet_gun:=(t at time zone 'Europe/Istanbul')::date;
   select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=x.id and d.taraf='muhalefet' and d.destek_turu='katilim' and d.destekci_tur='oyuncu';
   select count(distinct q.user_id) into nobet from (
     select user_id from oyun.sokak_taktik where eylem_id=x.id and tur='nobet' and bitis>t
     union
     select r.user_id from oyun.sokak_nobet_rota r where r.eylem_id=x.id and r.gun=nobet_gun
   ) q join oyun.sokak_eylem_destek d on d.eylem_id=x.id and d.temsilci=q.user_id and d.taraf='muhalefet' and d.destek_turu='katilim';
   gerek:=greatest(2, ceil(n*0.3));
   if nobet<gerek then
    insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'safak',u,txt,tut,'bitti',t,t);
    perform oyun.sokak_eylemi_kapat(x.id,'Şafak operasyonu eylemi kapattı. Nöbette '||nobet||' kişi vardı, gerek '||gerek||'.');
    perform oyun.sokak_manset_yaz('Şafak operasyonu bir eylemi kapattı');
   else
    insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'safak',u,txt,tut,'basarisiz',t,t+interval '12 hours');
    insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'safak',12,t+interval '12 hours');
    update oyun.ulke set memnuniyet=greatest(0,memnuniyet-1) where id=1;
    perform oyun.sokak_duyur(x.id,'Şafak operasyonu tutmadı. Nöbette '||nobet||' kişi vardı. Meydan güçlendi.');
   end if;
   perform oyun.sokak_log(x.id,u,'safak',null,'nobet='||nobet);

  elsif p_veri->>'tur'='elebasi' then
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'elebasi',u,txt,tut,'aktif',t,t+interval '12 hours') returning id into sid;
   insert into oyun.sokak_disari(eylem_id,user_id,tur,bitis) values(x.id,x.baslatan,'elebasi',t+interval '12 hours')
    on conflict(eylem_id,user_id,tur) do update set bitis=excluded.bitis;
   delete from oyun.sokak_eylem_destek where eylem_id=x.id and temsilci=x.baslatan and destek_turu='katilim';
   for rec in select d.temsilci from oyun.sokak_eylem_destek d
     left join lateral (select count(*) c from oyun.sokak_taktik k where k.eylem_id=x.id and k.user_id=d.temsilci) t2 on true
     where d.eylem_id=x.id and d.taraf='muhalefet' and d.destek_turu='katilim' and d.destekci_tur='oyuncu' and d.temsilci<>x.baslatan
     order by t2.c desc nulls last limit 2 loop
    insert into oyun.sokak_disari(eylem_id,user_id,tur,bitis) values(x.id,rec.temsilci,'elebasi',t+interval '12 hours')
     on conflict(eylem_id,user_id,tur) do update set bitis=excluded.bitis;
    delete from oyun.sokak_eylem_destek where eylem_id=x.id and temsilci=rec.temsilci and destek_turu='katilim';
   end loop;
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1;
   perform oyun.sokak_duyur(x.id,'Elebaşı gözaltısı: organizatör ve en hareketli iki kişi 12 saat dışarıda. Kalanlar yeni sözcü seçer.');
   perform oyun.sokak_yenile(x.id);

  elsif p_veri->>'tur'='mali' then
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'mali',u,txt,tut,'aktif',t,t+interval '48 hours');
   begin
    perform public.adliye_dava_ac('parti',x.parti_id::text,'diger',txt,'Mali kuşatma. Parti ve dernek fonu 48 saat kapalı. Hukuka aykırı bulunursa tazminat ödenir.');
   exception when others then
    perform oyun.sokak_log(x.id,u,'adliye',null,'Mali kuşatma dosyası Adliye formuna yazılamadı; Yüksek Mahkeme oyu bu ekranda.');
   end;
   perform oyun.sokak_duyur(x.id,'Mali kuşatma: parti ve dernek kasasıyla süre uzatılamaz. Yüksek Mahkeme hukuka aykırı derse tazminat ödenir.');

  elsif p_veri->>'tur'='kapatma' then
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'kapatma',u,txt,tut,'aktif',t,t+interval '48 hours');
   begin
    perform public.adliye_dava_ac('parti',x.parti_id::text,'diger',txt,'Kapatma davası tehdidi. Eylem harcaması iki kat. Yüksek Mahkeme bu ekrandan da oy kullanır.');
   exception when others then
    perform oyun.sokak_log(x.id,u,'adliye',null,'Kapatma dosyası Adliye formuna yazılamadı; Yüksek Mahkeme oyu bu ekranda.');
   end;
   perform oyun.sokak_duyur(x.id,'Kapatma davası tehdidi: bu partinin eylem harcaması iki kat. Mahkeme reddederse hükümet prestij kaybeder.');

  elsif p_veri->>'tur'='ohal' then
   if exists(select 1 from oyun.sokak_ohal where il_id=x.il_id and durum in ('onay','yururluk') and bitis>t) then raise exception 'Bu ilde OHAL süreci var'; end if;
   insert into oyun.sokak_ohal(il_id,eylem_id,yapan,durum,zaman,bitis) values(x.il_id,x.id,u,'onay',t,t+interval '6 hours') returning id into oid;
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis,etki) values(x.id,'ohal',u,txt,tut,'onay',t,t+interval '6 hours',jsonb_build_object('ohal',oid));
   perform oyun.sokak_duyur(x.id,'OHAL teklifi Meclis onayına sunuldu. 6 saatte salt çoğunluk gerekir.');

  elsif p_veri->>'tur'='propaganda' then
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'propaganda',u,txt,tut,'aktif',t,t+interval '2 hours');
   perform oyun.sokak_duyur(x.id,'Kara propaganda hazır. İktidar yanlısı bir gazeteci manşeti yazarsa tarafsızlar soğur.');

  elsif p_veri->>'tur'='bol' then
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'bol',u,txt,tut,'aktif',t,t+interval '24 hours');
   yari:=0;
   for rec in select temsilci from oyun.sokak_eylem_destek where eylem_id=x.id and taraf='muhalefet' and destek_turu='katilim' and destekci_tur='oyuncu' order by temsilci loop
    yari:=yari+1;
    insert into oyun.sokak_fraksiyon(eylem_id,user_id,taraf) values(x.id,rec.temsilci,case when yari%2=0 then 'kabul' else 'direnis' end) on conflict do nothing;
    perform oyun.bildir(rec.temsilci,case when yari%2=0 then 'Sana ayrı bir taviz paketi önerildi (kabul fraksiyonu).' else 'Direniş fraksiyonundasın. Birlik oyu bölünmeyi bozar.' end);
   end loop;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'bol',-8,t+interval '24 hours');
   perform oyun.sokak_duyur(x.id,'Böl ve yönet: katılımcılar kabul ve direniş diye ikiye ayrıldı.');

  elsif p_veri->>'tur'='kusatma' then
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis,etki) values(x.id,'kusatma',u,txt,tut,'aktif',t,t+interval '24 hours',jsonb_build_object('darbe',0));
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'kusatma',-5,t+interval '6 hours');
   update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=x.il_id;
   perform oyun.sokak_duyur(x.id,'Kuşatma çemberi: yeni katılım yok. İçeridekiler 6 saatte bir güç kaybeder. Dışarıdan dayanışma ziyareti çemberi bozar.');

  elsif p_veri->>'tur'='ihale' then
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'ihale',u,txt,tut,'aktif',t,t+interval '48 hours');
   n:=0;
   for rec in select distinct s.id as sid from oyun.sokak_eylem_destek d
     join oyun.sirketler s on s.aktif and oyun.sirket_sahibi(s.id)=d.temsilci
     where d.eylem_id=x.id and d.taraf='muhalefet' and d.destek_turu='katilim' loop
    insert into oyun.sokak_ihale_aski(sirket_id,eylem_id,onceki,bitis)
     select rec.sid,x.id,(select yasak_bit from oyun.sirket_deneyim where sirket_id=rec.sid),t+interval '48 hours'
     on conflict(sirket_id,eylem_id) do nothing;
    insert into oyun.sirket_deneyim(sirket_id,yasak_bit) values(rec.sid,t+interval '48 hours')
     on conflict(sirket_id) do update set yasak_bit=greatest(coalesce(oyun.sirket_deneyim.yasak_bit,excluded.yasak_bit),excluded.yasak_bit);
    n:=n+1;
   end loop;
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-least(3,greatest(n,1))) where id=1;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'ihale',least(12,3*greatest(n,1)),t+interval '48 hours');
   perform oyun.sokak_duyur(x.id,'İhale kılıcı: eylemi destekleyen '||n||' şirketin kamu ihalesi 48 saat askıda. İş dünyası tepkili.');

  elsif p_veri->>'tur'='sanal' then
   select count(*) into n from oyun.sokak_eylem_destek where eylem_id=x.id and taraf='muhalefet' and destek_turu='katilim' and destekci_tur='oyuncu';
   if n<4 then raise exception 'Toplu sanal gözaltı için en az 4 katılımcı gerekir'; end if;
   gerek:=least(5,n-1);
   for rec in select temsilci from oyun.sokak_eylem_destek where eylem_id=x.id and taraf='muhalefet' and destek_turu='katilim' and destekci_tur='oyuncu' order by random() limit gerek loop
    insert into oyun.sokak_disari(eylem_id,user_id,tur,bitis) values(x.id,rec.temsilci,'sanal',t+interval '6 hours')
     on conflict(eylem_id,user_id,tur) do update set bitis=excluded.bitis;
    perform oyun.bildir(rec.temsilci,'6 saat sanal gözaltındasın: bu eylemde oy ve sohbet kapalı. Başka hakların durmaz.');
   end loop;
   insert into oyun.sokak_sert(eylem_id,tur,yapan,gerekce,bedel,durum,zaman,bitis) values(x.id,'sanal',u,txt,tut,'aktif',t,t+interval '6 hours');
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-5) where id=1;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'sanal',12,t+interval '12 hours');
   perform oyun.sokak_manset_yaz('Toplu sanal gözaltı: basın skandalı');
   perform oyun.sokak_duyur(x.id,'Toplu sanal gözaltı: '||gerek||' kişi 6 saat oy ve sohbet kullanamaz. Ülke memnuniyeti sert düştü.');
  end if;
  perform oyun.sokak_log(x.id,u,'sert',null,p_veri->>'tur');
  return jsonb_build_object('tamam',true,'tur',p_veri->>'tur','bedel',tut);

 elsif p_islem='nobet' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Nöbet listesine katılımcı yazılır'; end if;
  saat:=extract(hour from t at time zone 'Europe/Istanbul')::int;
  nobet_gun:=(t at time zone 'Europe/Istanbul')::date + case when saat>=6 then 1 else 0 end;
  insert into oyun.sokak_nobet_rota(eylem_id,user_id,gun,zaman) values(x.id,u,nobet_gun,t)
   on conflict do nothing;
  return jsonb_build_object('tamam',true,'gun',nobet_gun);

 elsif p_islem='lider_oy' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Sözcü oyu katılımcıya açık'; end if;
  if oyun.sokak_sesi_kapali(u,x.id) then raise exception 'Sanal gözaltında oy yok'; end if;
  aday:=oyun.sokak_kad_bul(p_veri->>'kad');
  if aday is null or not oyun.sokak_katilimci(x.id,aday) then raise exception 'Aday hâlâ eylemin içinde olmalı'; end if;
  insert into oyun.sokak_lider_oy(eylem_id,veren,aday) values(x.id,u,aday) on conflict(eylem_id,veren) do update set aday=excluded.aday;
  select count(*) into n from oyun.sokak_eylem_destek where eylem_id=x.id and taraf='muhalefet' and destek_turu='katilim';
  select o.aday, count(*)::int into h, evet from oyun.sokak_lider_oy o where o.eylem_id=x.id group by o.aday order by count(*) desc limit 1;
  if evet*2>n and evet>=2 then
   update oyun.sokak_eylem set baslatan=h where id=x.id;
   perform oyun.sokak_duyur(x.id,'Yeni sözcü: '||oyun.kad(h)||'.');
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='avukat' then
  if not exists(select 1 from oyun.avukat_ruhsat where user_id=u and durum='aktif') then raise exception 'İtirazı ruhsatlı avukat yapar'; end if;
  update oyun.sokak_sert set etki=etki||jsonb_build_object('itiraz',true)
   where eylem_id=x.id and tur='elebasi' and durum='aktif' and bitis>t and not (etki ? 'itiraz');
  if not found then raise exception 'Kısaltılacak elebaşı süresi yok ya da itiraz kullanıldı'; end if;
  update oyun.sokak_disari set bitis=t+((bitis-t)/2) where eylem_id=x.id and tur='elebasi' and bitis>t;
  perform oyun.sokak_duyur(x.id,'Avukat itirazı elebaşı süresini yarıya indirdi.');
  perform oyun.sokak_log(x.id,u,'avukat_itiraz',null,null);
  return jsonb_build_object('tamam',true);

 elsif p_islem='yargi' then
  if not exists(select 1 from oyun.mahkeme_uye where user_id=u) then raise exception 'Bu oyu Yüksek Mahkeme üyesi kullanır'; end if;
  sid:=(p_veri->>'id')::bigint;
  if coalesce(p_veri->>'oy','') not in ('aykiri','uygun') then raise exception 'Oy aykırı ya da uygun'; end if;
  insert into oyun.sokak_yargi_oy(sert_id,user_id,oy) values(sid,u,p_veri->>'oy');
  select count(*) filter(where oy='aykiri'), count(*) filter(where oy='uygun'), count(*) into evet, hayir, n from oyun.sokak_yargi_oy where sert_id=sid;
   if evet+hayir>=1 and evet>hayir then
   update oyun.sokak_sert s set durum='aykiri', bitis=t where s.id=sid and s.durum='aktif' returning s.tur, s.eylem_id, s.yapan into txt, p_eylem, h;
   if txt='mali' then
    update oyun.partiler set kasa=kasa+100000 where id=(select parti_id from oyun.sokak_eylem where id=p_eylem);
    update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1;
    perform oyun.sokak_duyur(p_eylem,'Mali kuşatma hukuka aykırı bulundu. Partiye 100.000 TL tazminat.');
   elsif txt='kapatma' then
    update oyun.ulke set memnuniyet=greatest(0,memnuniyet-4) where id=1;
    insert into oyun.sokak_itibar(user_id,puan) values(h,-15) on conflict(user_id) do update set puan=oyun.sokak_itibar.puan-15;
    perform oyun.sokak_manset_yaz('Kapatma davası düştü');
    perform oyun.sokak_duyur(p_eylem,'Kapatma davası reddedildi. Hükümet prestij ve memnuniyet kaybetti.');
   end if;
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='ohal_oy' then
  if not exists(select 1 from oyun.makamlar where user_id=u and tur='mv' and bit is null) then raise exception 'OHAL oyunu milletvekili kullanır'; end if;
  oid:=(p_veri->>'id')::bigint;
  if coalesce(p_veri->>'oy','') not in ('evet','hayir') then raise exception 'Oy evet ya da hayır'; end if;
  insert into oyun.sokak_ohal_oy(ohal_id,user_id,oy) values(oid,u,p_veri->>'oy');
  select count(*) filter(where oy='evet'), count(*) filter(where oy='hayir') into evet, hayir from oyun.sokak_ohal_oy where ohal_id=oid;
  if evet>=oyun.salt_cogunluk() then
   update oyun.sokak_ohal set durum='yururluk', bitis=t+interval '72 hours' where id=oid and durum='onay' returning il_id, eylem_id into n, p_eylem;
   update oyun.sokak_sert set durum='aktif', bitis=t+interval '72 hours' where tur='ohal' and durum='onay' and (etki->>'ohal')::bigint=oid;
   update oyun.ulke set memnuniyet=greatest(0,memnuniyet-4) where id=1;
   update oyun.sokak_kriz set
    kirmizi_baslangic=case when kirmizi_baslangic is not null then kirmizi_baslangic-interval '12 hours' else kirmizi_baslangic end,
    ivme_saat=case when kirmizi_baslangic is null then least(24,ivme_saat+12) else ivme_saat end
    where id=1;
   perform oyun.sokak_manset_yaz('OHAL onaylandı');
   perform oyun.sokak_duyur(p_eylem,'Meclis OHAL''i onayladı. 72 saat bu ilde yeni katılım yok. Ülke memnuniyeti düştü, erken seçim riski arttı.');
  elsif hayir>=oyun.salt_cogunluk() then
   update oyun.sokak_ohal set durum='red' where id=oid;
   update oyun.sokak_sert set durum='red' where tur='ohal' and (etki->>'ohal')::bigint=oid;
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='manset' then
  if not (oyun.sokak_gazeteci(u) and oyun.sokak_iktidar(u)) then raise exception 'Manşeti iktidar yanlısı gazeteci yazar'; end if;
   update oyun.sokak_sert set bitis=t+interval '12 hours', etki=etki||jsonb_build_object('manset',true) where eylem_id=x.id and tur='propaganda' and durum='aktif' and not (etki ? 'manset');
  if not found then raise exception 'Yazılacak propaganda yok'; end if;
  insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'propaganda',-8,t+interval '12 hours');
  perform oyun.sokak_duyur(x.id,'MANŞET: yabancı destek iddiası. Tarafsızlar soğuyor. Avukat ya da muhalif gazeteci çürütebilir.');
  return jsonb_build_object('tamam',true);

 elsif p_islem='curut' then
  if not ((oyun.sokak_gazeteci(u) and not oyun.sokak_iktidar(u)) or exists(select 1 from oyun.avukat_ruhsat where user_id=u and durum='aktif')) then
   raise exception 'Çürütmeyi muhalif gazeteci ya da avukat yapar'; end if;
  txt:=oyun.sokak_temiz(coalesce(p_veri->>'metin','Kanıt sunuldu'),400);
  update oyun.sokak_sert set durum='basarisiz', bitis=t where eylem_id=x.id and tur='propaganda' and durum='aktif' and (etki ? 'manset');
  if not found then raise exception 'Çürütülecek manşet yok'; end if;
  delete from oyun.sokak_meydan_etki where eylem_id=x.id and tur='propaganda' and bitis>t;
  insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'propaganda_skandal',10,t+interval '12 hours');
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-2) where id=1;
  perform oyun.sokak_manset_yaz('Kara propaganda çürütüldü');
  perform oyun.sokak_duyur(x.id,'Çürütme: '||left(txt,180)||' Propaganda skandala döndü.');
  return jsonb_build_object('tamam',true);

 elsif p_islem='birlik' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Birlik oyu katılımcıya açık'; end if;
  if oyun.sokak_sesi_kapali(u,x.id) then raise exception 'Sanal gözaltında oy yok'; end if;
  insert into oyun.sokak_birlik_oy(eylem_id,user_id) values(x.id,u);
  select count(*) into n from oyun.sokak_eylem_destek where eylem_id=x.id and taraf='muhalefet' and destek_turu='katilim';
  select count(*) into evet from oyun.sokak_birlik_oy where eylem_id=x.id;
  if evet*2>n and evet>=2 then
   delete from oyun.sokak_fraksiyon where eylem_id=x.id;
   update oyun.sokak_sert set durum='basarisiz', bitis=t where eylem_id=x.id and tur='bol' and durum='aktif';
   delete from oyun.sokak_meydan_etki where eylem_id=x.id and tur='bol';
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'birlik',6,t+interval '12 hours');
   perform oyun.sokak_duyur(x.id,'Birlik oylaması bölünmeyi bozdu.');
  end if;
  return jsonb_build_object('tamam',true);

 elsif p_islem='ziyaret' then
  if oyun.sokak_katilimci(x.id,u) or oyun.sokak_sert_yetkili(u,x.il_id) then raise exception 'Dayanışma ziyaretini eylemin ve hükümetin dışındaki biri yapar'; end if;
  if not exists(select 1 from oyun.sokak_sert where eylem_id=x.id and tur='kusatma' and durum='aktif' and bitis>t) then raise exception 'Kuşatma yok'; end if;
  insert into oyun.sokak_ziyaret(eylem_id,user_id,zaman) values(x.id,u,t);
  select count(*) into n from oyun.sokak_ziyaret where eylem_id=x.id;
  select count(*) into gerek from oyun.sokak_eylem_destek where eylem_id=x.id and taraf='muhalefet' and destek_turu='katilim';
  if n>=greatest(2, ceil(gerek/5.0)) then
   update oyun.sokak_sert set durum='basarisiz', bitis=t where eylem_id=x.id and tur='kusatma' and durum='aktif';
   perform oyun.sokak_duyur(x.id,'Dayanışma ziyaretleri kuşatma çemberini bozdu.');
  end if;
  return jsonb_build_object('tamam',true,'ziyaret',n);

 elsif p_islem='cek' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Çekilmek için eylemde olmalısın'; end if;
  delete from oyun.sokak_eylem_destek where eylem_id=x.id and temsilci=u and destek_turu='katilim';
  for rec in select * from oyun.sokak_ihale_aski where eylem_id=x.id and sirket_id in (select s.id from oyun.sirketler s where oyun.sirket_sahibi(s.id)=u) loop
   update oyun.sirket_deneyim set yasak_bit=rec.onceki where sirket_id=rec.sirket_id and yasak_bit=rec.bitis;
   delete from oyun.sokak_ihale_aski where sirket_id=rec.sirket_id and eylem_id=x.id;
  end loop;
  perform oyun.sokak_yenile(x.id);
  return jsonb_build_object('tamam',true);

 else raise exception 'Bilinmeyen sert işlem'; end if;
end $$;

create or replace function public.sokak_sert_panel() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); arr jsonb;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',e.id,'il_id',e.il_id,
  'yetkili',oyun.sokak_sert_yetkili(u,e.il_id),
  'katilimci',oyun.sokak_katilimci(e.id,u),
  'avukat',exists(select 1 from oyun.avukat_ruhsat r where r.user_id=u and r.durum='aktif'),
  'gazeteci',oyun.sokak_gazeteci(u),'iktidar',oyun.sokak_iktidar(u),
  'vekil',exists(select 1 from oyun.makamlar m where m.user_id=u and m.tur='mv' and m.bit is null),
  'yargi',exists(select 1 from oyun.mahkeme_uye m where m.user_id=u),
  'bedeller',(select jsonb_object_agg(k,oyun.sokak_sert_bedel(k,e.il_id)) from unnest(array['safak','elebasi','mali','kapatma','ohal','propaganda','bol','kusatma','ihale','sanal']) k),
  'saat',extract(hour from t at time zone 'Europe/Istanbul')::int,
  'onlemler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'tur',s.tur,'ad',oyun.sokak_sert_ad(s.tur),'durum',s.durum,'bitis',s.bitis,'bedel',s.bedel,'gerekce',s.gerekce) order by s.zaman desc)
    from oyun.sokak_sert s where s.eylem_id=e.id and (s.bitis>t or s.zaman>t-interval '6 hours')),'[]'::jsonb),
  'ohal',(select jsonb_build_object('id',o.id,'durum',o.durum,'bitis',o.bitis,'evet',(select count(*) from oyun.sokak_ohal_oy y where y.ohal_id=o.id and y.oy='evet'),'hayir',(select count(*) from oyun.sokak_ohal_oy y where y.ohal_id=o.id and y.oy='hayir'))
    from oyun.sokak_ohal o where o.il_id=e.il_id and o.bitis>t order by o.zaman desc limit 1),
  'fraksiyon',(select taraf from oyun.sokak_fraksiyon f where f.eylem_id=e.id and f.user_id=u)
 )),'[]'::jsonb) into arr from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>t;
 return jsonb_build_object('tamam',true,'eylemler',arr);
end $$;

create or replace function oyun.sokak_sert_tick() returns void
language plpgsql set search_path='' as $$
declare t timestamptz:=oyun.simdi(); r record; n int;
begin
 for r in select * from oyun.sokak_sert where tur='kusatma' and durum='aktif' and bitis>t loop
  n:=coalesce((r.etki->>'darbe')::int,0);
  if n<3 and r.zaman+((n+1)*interval '6 hours')<=t then
   update oyun.sokak_sert set etki=jsonb_set(etki,'{darbe}',to_jsonb(n+1)) where id=r.id;
   insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(r.eylem_id,'kusatma',-5,t+interval '6 hours');
  end if;
 end loop;
 update oyun.sokak_sert set durum='basarisiz' where tur='propaganda' and durum='aktif' and bitis<=t and not (etki ? 'manset');
 update oyun.sokak_sert set durum='bitti' where tur='propaganda' and durum='aktif' and bitis<=t and (etki ? 'manset');
 update oyun.sokak_ohal set durum='red' where durum='onay' and bitis<=t;
 update oyun.sokak_sert set durum='red' where tur='ohal' and durum='onay' and bitis<=t;
end $$;

-- Bağlantılar: katılım, fon, sohbet. İhale yasağı sirket_deneyim.yasak_bit ile işler.
do $$
declare s text;
begin
 s:=pg_get_functiondef('public.sokak_destek(bigint,text,text,bigint,numeric)'::regprocedure);
 if position('sokak_giris_kapali' in s)=0 then
  if position('Gece toplanma kısıtı: 22.00–06.00 arasında yeni katılım kapalı' in s)=0 then raise exception 'Katılım çapası bulunamadı'; end if;
  s:=replace(s,'if oyun.sokak_gece_kapali(x.id) then raise exception ''Gece toplanma kısıtı: 22.00–06.00 arasında yeni katılım kapalı''; end if;',
   'if oyun.sokak_gece_kapali(x.id) then raise exception ''Gece toplanma kısıtı: 22.00–06.00 arasında yeni katılım kapalı''; end if;
  if p_taraf=''muhalefet'' and oyun.sokak_giris_kapali(x.id) then raise exception ''Kuşatma veya OHAL: yeni katılım kapalı''; end if;
  if oyun.sokak_disarida(u,x.id) and p_tutar=0 then raise exception ''Bu eylemde süren dışarı alma var''; end if;');
  if position('if p_tutar<1000 then raise exception ''En az 1.000 TL fonlanabilir''; end if;' in s)=0 then raise exception 'Fon çapası bulunamadı'; end if;
  s:=replace(s,'if p_tutar<1000 then raise exception ''En az 1.000 TL fonlanabilir''; end if;',
   'if p_taraf=''muhalefet'' and p_kaynak in (''parti'',''dernek'') and oyun.sokak_fon_kapali(x.id) then raise exception ''Mali kuşatma: parti ve dernek fonu kapalı''; end if;
  if p_tutar<1000 then raise exception ''En az 1.000 TL fonlanabilir''; end if;');
  if position('update oyun.partiler set kasa=kasa-p_tutar where id=p_kaynak_id and kasa>=p_tutar;' in s)=0 then raise exception 'Parti kasa çapası bulunamadı'; end if;
  s:=replace(s,'update oyun.partiler set kasa=kasa-p_tutar where id=p_kaynak_id and kasa>=p_tutar;',
   'update oyun.partiler set kasa=kasa-p_tutar*(case when oyun.sokak_cift_bedel(x.id) and p_taraf=''muhalefet'' then 2 else 1 end) where id=p_kaynak_id and kasa>=p_tutar*(case when oyun.sokak_cift_bedel(x.id) and p_taraf=''muhalefet'' then 2 else 1 end);');
  s:=replace(s,'elsif p_kaynak=''parti'' then insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(p_kaynak_id,t,-p_tutar,''gider'',''Halk hareketi #''||x.id||'' / ''||p_taraf);',
   'elsif p_kaynak=''parti'' then insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(p_kaynak_id,t,-p_tutar*(case when oyun.sokak_cift_bedel(x.id) and p_taraf=''muhalefet'' then 2 else 1 end),''gider'',''Halk hareketi #''||x.id||'' / ''||p_taraf);');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_sohbet_yaz(bigint,text)'::regprocedure);
 if position('sokak_sesi_kapali' in s)=0 then
  if position('Gözaltındayken eylem sohbetine yazamazsın' in s)=0 then raise exception 'Sohbet çapası bulunamadı'; end if;
  s:=replace(s,'raise exception ''Gözaltındayken eylem sohbetine yazamazsın''; end if;',
   'raise exception ''Gözaltındayken eylem sohbetine yazamazsın''; end if;
 if oyun.sokak_sesi_kapali(u,p_eylem) then raise exception ''Sanal gözaltı süresince sohbet kapalı''; end if;');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_taktik_yap(bigint,text,text)'::regprocedure);
 if position('sokak_disarida' in s)=0 then
  if position('Gece toplanma kısıtı: 22.00–06.00 arasında taktik uygulanamaz' in s)=0 then raise exception 'Taktik çapası bulunamadı'; end if;
  s:=replace(s,'if oyun.sokak_gece_kapali(x.id) then raise exception ''Gece toplanma kısıtı: 22.00–06.00 arasında taktik uygulanamaz''; end if;',
   'if oyun.sokak_gece_kapali(x.id) then raise exception ''Gece toplanma kısıtı: 22.00–06.00 arasında taktik uygulanamaz''; end if;
 if oyun.sokak_disarida(u,x.id) then raise exception ''Dışarıda olduğun sürece taktik uygulayamazsın''; end if;');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_meydan_islem(bigint,text,jsonb)'::regprocedure);
 if position('sokak_sesi_kapali' in s)=0 then
  if position('Hesabın kısıtlı' in s)=0 then raise exception 'Meydan işlem çapası bulunamadı'; end if;
  s:=replace(s,'if me.yasakli then raise exception ''Hesabın kısıtlı''; end if;',
   'if me.yasakli then raise exception ''Hesabın kısıtlı''; end if;
 if p_eylem is not null and oyun.sokak_sesi_kapali(u,p_eylem) and p_islem in (''muhbir_oy'',''kirmizi_yanit'',''juri_oy'',''hafiza_oy'') then raise exception ''Sanal gözaltı süresince oy yok''; end if;');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_meydan_panel()'::regprocedure);
 if position('''sert''' in s)=0 then
  if position('''muhbir'',count(*) filter(where tur=''muhbir'')' in s)=0 then raise exception 'Pusula çapası bulunamadı'; end if;
  s:=replace(s,'''muhbir'',count(*) filter(where tur=''muhbir'')',
   '''muhbir'',count(*) filter(where tur=''muhbir''),''sert'',count(*) filter(where tur=''sert'')');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_eylem_baslat(integer,text)'::regprocedure);
 if position('sokak_ohal_aktif' in s)=0 then
  if position('Sokak hareketleri kapalı' in s)=0 then raise exception 'Eylem açılış çapası bulunamadı'; end if;
  s:=replace(s,'raise exception ''Sokak hareketleri kapalı''; end if;',
   'raise exception ''Sokak hareketleri kapalı''; end if;
 if oyun.sokak_ohal_aktif(p_il) then raise exception ''Bu ilde OHAL var; yeni eylem açılamaz''; end if;');
  execute s;
 end if;
 s:=pg_get_functiondef('oyun.sokak_tick()'::regprocedure);
 if position('sokak_sert_tick' in s)=0 then
  if position('perform oyun.sokak_meydan_tick();' in s)=0 then raise exception 'Sokak tick çapası bulunamadı'; end if;
  s:=replace(s,'perform oyun.sokak_meydan_tick();','perform oyun.sokak_sert_tick(); perform oyun.sokak_meydan_tick();');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_tedbir_ac(bigint,text,text)'::regprocedure);
 if position('sokak_ohal_aktif' in s)=0 then
  if position('oyun.sokak_tedbir_ad(p_tur)||'' / ''||tut||'' TL'');' in s)=0 then raise exception 'Tedbir kasa çapası bulunamadı'; end if;
  s:=replace(s,'perform oyun.bm_kasa_harca(''icisleri'',tut/oyun.pazar_tl_milyar(),''gider'',''Halk hareketi #''||x.id||'' / ''||oyun.sokak_tedbir_ad(p_tur)||'' / ''||tut||'' TL'');',
   'if oyun.sokak_ohal_aktif(x.il_id) then tut:=round(tut*0.5,2); end if;
 perform oyun.bm_kasa_harca(''icisleri'',tut/oyun.pazar_tl_milyar(),''gider'',''Halk hareketi #''||x.id||'' / ''||oyun.sokak_tedbir_ad(p_tur)||'' / ''||tut||'' TL'');');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_hukumet_karar(bigint,text,text,uuid)'::regprocedure);
 if position('sokak_ohal_aktif' in s)=0 then
  if position('''Halk hareketi #''||x.id||'' / ''||p_tur||'' / ''||tut||'' TL'');' in s)=0 then raise exception 'Karar kasa çapası bulunamadı'; end if;
  s:=replace(s,'perform oyun.bm_kasa_harca(''icisleri'',tut/oyun.pazar_tl_milyar(),''gider'',''Halk hareketi #''||x.id||'' / ''||p_tur||'' / ''||tut||'' TL'');',
   'if oyun.sokak_ohal_aktif(x.il_id) then tut:=round(tut*0.5,2); end if;
 perform oyun.bm_kasa_harca(''icisleri'',tut/oyun.pazar_tl_milyar(),''gider'',''Halk hareketi #''||x.id||'' / ''||p_tur||'' / ''||tut||'' TL'');');
  execute s;
 end if;
end $$;

revoke all on function oyun.sokak_sert_yetkili(uuid,integer),oyun.sokak_ohal_aktif(integer),oyun.sokak_giris_kapali(bigint),
 oyun.sokak_fon_kapali(bigint),oyun.sokak_cift_bedel(bigint),oyun.sokak_disarida(uuid,bigint),oyun.sokak_sesi_kapali(uuid,bigint),
 oyun.sokak_sert_ad(text),oyun.sokak_sert_bedel(text,integer),oyun.sokak_eylemi_kapat(bigint,text),oyun.sokak_sert_tick(),
 public.sokak_sert_islem(bigint,text,jsonb),public.sokak_sert_panel()
 from public,anon,authenticated;
grant execute on function public.sokak_sert_islem(bigint,text,jsonb),public.sokak_sert_panel() to authenticated;
