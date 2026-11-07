
-- 2026-11-07: Halk hareketlerinde artan fon, artan müdahale bütçesi, azalan marjinal getiri.
-- Mevcut eylemler/partiler/oyuncu paraları değiştirilmez. Bütçe yalnız yetkili RPC ile harcanır.
create table if not exists oyun.sokak_butce_mudahale(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem(id),
 yapan uuid not null references oyun.profiller(id),
 bedel numeric not null check(bedel>0),
 gerekce text not null check(length(gerekce) between 25 and 500),
 etki numeric not null check(etki>=0),
 tepki numeric not null check(tepki>=0),
 zaman timestamptz not null default now(),
 bitis timestamptz not null
);
create index if not exists sokak_butce_eylem_zaman on oyun.sokak_butce_mudahale(eylem_id,zaman desc);
alter table oyun.sokak_butce_mudahale enable row level security;
revoke all on oyun.sokak_butce_mudahale from public,anon,authenticated;

-- Parasal müdahale gücü bütçe arttıkça yükselir; sınırsız çarpan yoktur.
create or replace function oyun.sokak_butce_etkisi(p_tutar numeric,p_protesto numeric)
returns numeric language sql stable set search_path='' as $f$
 select round(least(40,12*ln(1+greatest(0,p_tutar)/greatest(1,(select baslatma_bedeli from oyun.sokak_eylem_ayar where id=1))))
 *(0.75+0.25*least(1,greatest(0,p_tutar)/greatest(1,p_protesto))),2)
$f$;
create or replace function oyun.sokak_butce_tepki(p_tutar numeric)
returns numeric language sql stable set search_path='' as $f$
 select round(least(12,greatest(0,3*ln(1+greatest(0,p_tutar)/greatest(1,(select baslatma_bedeli from oyun.sokak_eylem_ayar where id=1)))-4)),2)
$f$;

-- Mevcut polis sevkleri de harcadıkları paraya göre daha güçlüdür. Aşırı harcama kamuoyu tepkisini doğurur.
create or replace function oyun.sokak_karar_etki(e bigint) returns numeric
language sql stable set search_path='' as $f$
 select
 coalesce((select sum(case when k.tur='yonlendirme' and k.bitis>oyun.simdi() then -10
 when k.tur='uyari' and k.bitis>oyun.simdi() then -8
 when k.tur='uyari' and k.bitis+interval '18 hours'>oyun.simdi() then 6
 else 0 end) from oyun.sokak_karar k where k.eylem_id=e),0)
 +coalesce((select sum(case
 when p.geri_cekildi is not null and p.zaman+interval '24 hours'>oyun.simdi() then p.tepki/2
 when p.geri_cekildi is not null then 0
 when p.zaman+interval '3 hours'>oyun.simdi() then -least(25,7*ln(1+p.bedel/greatest(1,a.baslatma_bedeli)))
 when p.zaman+interval '24 hours'>oyun.simdi() then p.tepki else 0 end)
 from oyun.sokak_polis p cross join oyun.sokak_eylem_ayar a where a.id=1 and p.eylem_id=e),0)
 +coalesce((select sum(case
 when m.bitis>oyun.simdi() then -m.etki
 when m.bitis+interval '12 hours'>oyun.simdi() then m.tepki
 else 0 end)
 from oyun.sokak_butce_mudahale m where m.eylem_id=e),0)
$f$;

-- Protesto bütçesinin puanı: 50k->~13; 250k->~34; 500k->~45; 1m->57.
-- Katılım hâlâ önemli. Eylem başlangıcında aktif oyuncu/memnuniyetsizlik ön şartı yok.
create or replace function oyun.sokak_yenile(p_id bigint) returns void
language plpgsql set search_path='' as $f$
declare
 x oyun.sokak_eylem; a oyun.sokak_eylem_ayar; t timestamptz:=oyun.simdi();
 n integer; puan numeric; kirmizi boolean;
begin
 select * into a from oyun.sokak_eylem_ayar where id=1;
 select * into x from oyun.sokak_eylem where id=p_id for update;
 if x.id is null or x.durum<>'aktif' then return;end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=p_id and durum='takip') then return;end if;
 if x.bitis<=t then
  update oyun.sokak_eylem set durum='bitti',kapandi=t,kirmizi_baslangic=null,seviye=0 where id=x.id;
  perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' süresi doldu. İl dinlenme süresine girdi.');return;
 end if;
 if x.iktidar_fonu>=x.muhalefet_fonu*a.sakinlestirme_carpani then
  update oyun.sokak_eylem set durum='yatisti',kapandi=t,kirmizi_baslangic=null,seviye=0 where id=x.id;
  perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' uzlaşma fonuyla yatıştı.');return;
 end if;
 select count(distinct p.id) into n
 from oyun.sokak_eylem_destek d join oyun.profiller p on p.id=d.temsilci
 where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet'
 and not oyun.sokak_yaptirimli(p.id,x.id) and p.il_id=x.il_id and p.il_at<t-interval '3 days'
 and not p.yasakli and p.olusturma<t-interval '3 days' and p.son_gorulme>t-interval '14 days';
 puan:=least(100,greatest(0,
  oyun.sokak_karar_etki(x.id)
  +oyun.sokak_memnuniyetsizlik(x.il_id)*0.35
  +least(60,57*ln(1+x.muhalefet_fonu/greatest(1,a.baslatma_bedeli))/ln(21))
  +least(28,n*4)
  -40*least(1,x.iktidar_fonu/greatest(1,x.muhalefet_fonu*a.sakinlestirme_carpani))
 ));
 -- Kırmızı seviye için asgari 3 gerçek yerel katılımcı gerekir; yüksek fon otomatik erken seçim sağlamaz.
 kirmizi:=puan>=a.kirmizi_esik and n>=3;
 if not kirmizi then puan:=least(puan,a.kirmizi_esik-1);end if;
 update oyun.sokak_eylem
 set seviye=round(puan,1),
     kirmizi_baslangic=case when kirmizi then coalesce(kirmizi_baslangic,t) else null end
 where id=x.id;
 if kirmizi and x.kirmizi_baslangic is null then
   perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' kırmızı seviyeye ulaştı. Hükümetin yanıtı bekleniyor.');
 elsif not kirmizi and x.kirmizi_baslangic is not null then
   perform oyun.sokak_duyur(x.id,'Eylem #'||x.id||' kırmızı seviyeden çıktı; kriz sayacı sıfırlandı.');
 end if;
end $f$;

-- Cumhurbaşkanı/İçişleri Bakanı 50k-2m TL arası bütçe seçer; zor kullanma/gözaltı işlemi içermez.
create or replace function public.sokak_butce_mudahale(p_eylem bigint,p_tutar numeric,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare
 u uuid:=auth.uid(); x oyun.sokak_eylem; a oyun.sokak_eylem_ayar;
 t timestamptz:=oyun.simdi(); hesap numeric; etki numeric; tepki numeric; kayit bigint;
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
 etki:=oyun.sokak_butce_etkisi(p_tutar,x.muhalefet_fonu);
 tepki:=oyun.sokak_butce_tepki(p_tutar);
 perform oyun.bm_kasa_harca('icisleri',p_tutar/oyun.pazar_tl_milyar(),'gider',
  'Halk hareketi #'||x.id||' / bütçeli müdahale / '||p_tutar||' TL');
 insert into oyun.sokak_butce_mudahale(eylem_id,yapan,bedel,gerekce,etki,tepki,zaman,bitis)
 values(x.id,u,p_tutar,btrim(p_gerekce),etki,tepki,t,t+interval '12 hours') returning id into kayit;
 perform oyun.sokak_yenile(x.id);
 perform oyun.sokak_duyur(x.id,'Hükümet eylem #'||x.id||' için '||p_tutar||
 ' TL kamu bütçesiyle müdahale kampanyası başlattı. Etki: -'||etki||' puan, sonraki kamuoyu tepkisi: +'||tepki||' puan. Gerekçe: '||left(p_gerekce,300));
 return jsonb_build_object('tamam',true,'id',kayit,'bedel',p_tutar,'etki',etki,'tepki',tepki);
end $f$;

-- Uygulama kartları için kaynakları ve etkileri yayımlayan, salt-okunur API.
create or replace function public.sokak_finans_panel() returns jsonb
language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); a oyun.sokak_eylem_ayar;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into a from oyun.sokak_eylem_ayar where id=1;
 return jsonb_build_object(
  'aktif',a.aktif,'mudahale_yetki',oyun.sokak_yonetebilir(u),'baslatma_bedeli',a.baslatma_bedeli,
  'icisleri_kasa_tl',case when oyun.sokak_yonetebilir(u) then
   (select kasa*oyun.pazar_tl_milyar() from oyun.bakanlik_kasa where kod='icisleri') else null end,
  'eylemler',coalesce((select jsonb_agg(jsonb_build_object(
   'id',e.id,'il',(select ad from oyun.iller where id=e.il_id),
   'kurulus',case when e.org_tur='dernek' then (select ad from oyun.dernekler where id=e.org_id) else (select ad from oyun.partiler where id=e.parti_id) end,
   'durum',e.durum,'bitis',e.bitis,'seviye',e.seviye,
   'muhalefet_fonu',e.muhalefet_fonu,'iktidar_fonu',e.iktidar_fonu,
   'fon_guc_puani',round(least(60,57*ln(1+e.muhalefet_fonu/greatest(1,a.baslatma_bedeli))/ln(21)),1),
   'mudahale_puani',oyun.sokak_karar_etki(e.id),
   'max_butce',least(2000000,greatest(a.baslatma_bedeli,e.muhalefet_fonu*2,a.baslatma_bedeli*10)),
   'harcanan',(select coalesce(sum(m.bedel),0) from oyun.sokak_butce_mudahale m where m.eylem_id=e.id),
   'polis_gider',(select coalesce(sum(p.bedel),0) from oyun.sokak_polis p where p.eylem_id=e.id),
   'karar_gider',(select coalesce(sum(k.bedel),0) from oyun.sokak_karar k where k.eylem_id=e.id),
   'mudahaleler',coalesce((select jsonb_agg(jsonb_build_object('zaman',m.zaman,'bedel',m.bedel,'etki',m.etki,'tepki',m.tepki,
    'durum',case when m.bitis>oyun.simdi() then 'aktif' when m.bitis+interval '12 hours'>oyun.simdi() then 'tepki' else 'bitti' end,
    'gerekce',m.gerekce) order by m.zaman desc) from oyun.sokak_butce_mudahale m where m.eylem_id=e.id),'[]'::jsonb)
  ) order by e.baslangic desc) from (select * from oyun.sokak_eylem order by baslangic desc limit 40)e),'[]'::jsonb)
 );
end $f$;

-- Eski müdahale yollarında da yeni para müdahalesi aynı 6s/24s sınırlamasına tabidir.
do $do$
declare s text; old_count text; new_count text;
begin
 old_count:='(select count(*) from oyun.sokak_polis where zaman>t-interval ''24 hours'')>=4';
 new_count:='(select count(*) from oyun.sokak_polis where zaman>t-interval ''24 hours'')+(select count(*) from oyun.sokak_butce_mudahale where zaman>t-interval ''24 hours'')>=4';
 s:=pg_get_functiondef('public.sokak_hukumet_karar(bigint,text,text,uuid)'::regprocedure);
 if position('sokak_butce_mudahale' in s)=0 then
  if position(old_count in s)=0 then raise exception 'Hükümet günlük sınır noktası bulunamadı';end if;
  s:=replace(s,old_count,new_count);
  s:=replace(s,
   'if exists(select 1 from oyun.sokak_polis where eylem_id=x.id and zaman>t-interval ''6 hours'')',
   'if exists(select 1 from oyun.sokak_butce_mudahale where eylem_id=x.id and zaman>t-interval ''6 hours'') or exists(select 1 from oyun.sokak_polis where eylem_id=x.id and zaman>t-interval ''6 hours'')');
  execute s;
 end if;
 s:=pg_get_functiondef('public.sokak_polis_gonder(bigint,text,text)'::regprocedure);
 if position('sokak_butce_mudahale' in s)=0 then
  if position(old_count in s)=0 then raise exception 'Polis günlük sınır noktası bulunamadı';end if;
  s:=replace(s,old_count,new_count);
  s:=replace(s,'if exists(select 1 from oyun.sokak_karar where eylem_id=x.id and zaman>t-interval ''6 hours'')',
   'if exists(select 1 from oyun.sokak_butce_mudahale where eylem_id=x.id and zaman>t-interval ''6 hours'') or exists(select 1 from oyun.sokak_karar where eylem_id=x.id and zaman>t-interval ''6 hours'')');
  execute s;
 end if;
end $do$;
revoke all on function oyun.sokak_butce_etkisi(numeric,numeric),oyun.sokak_butce_tepki(numeric)
from public,anon,authenticated;
revoke all on function public.sokak_butce_mudahale(bigint,numeric,text),public.sokak_finans_panel()
from public,anon,authenticated;
grant execute on function public.sokak_butce_mudahale(bigint,numeric,text),public.sokak_finans_panel() to authenticated;
