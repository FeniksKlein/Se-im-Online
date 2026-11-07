-- 2026-11-07: Eyleme Türkiye'nin her yerinden katilim. Il veya ikamet suresi aranmaz.
-- Mevcut hesap-yasi ve yaptirim guvenlik sinirlari korunur.

-- oyun.sokak_tick
CREATE OR REPLACE FUNCTION oyun.sokak_tick()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t timestamptz:=oyun.simdi(); x record; k oyun.sokak_kriz; a oyun.sokak_eylem_ayar; n integer; kisi integer; aktif integer; dm text;
begin
 if not pg_try_advisory_xact_lock(781231,1) then return; end if;
 select * into a from oyun.sokak_eylem_ayar where id=1;
 if not a.aktif then return; end if;
 perform oyun.sokak_soz_tick(); for x in select id from oyun.sokak_eylem where durum='aktif' order by id loop perform oyun.sokak_yenile(x.id); end loop;
 select count(*) into n from oyun.sokak_eylem where durum='aktif' and kirmizi_baslangic is not null and bitis>t;
 select * into k from oyun.sokak_kriz where id=1 for update;
 -- Etki zaman başına bir kere, tüm ülke için sınırlandırılır. Kesinti sonrası geçmiş günler topluca işlenmez.
 if n>0 and (k.son_etki is null or k.son_etki<=t-interval '24 hours') then
  update oyun.ulke set memnuniyet=greatest(0,memnuniyet-least(2,n*0.3)),buyume=greatest(-20,buyume-least(0.6,n*0.1)),enflasyon=least(200,enflasyon+least(0.3,n*0.05)) where id=1;
  update oyun.sokak_kriz set son_etki=t where id=1;
  perform oyun.olay('ekonomi',format('%s ilde kırmızı protesto: büyüme ve hükümet memnuniyeti geriledi; piyasalarda belirsizlik arttı.',n));
 end if;
 select count(distinct d.temsilci) into kisi from oyun.sokak_eylem_destek d join oyun.sokak_eylem e on e.id=d.eylem_id join oyun.profiller p on p.id=d.temsilci where e.durum='aktif' and e.kirmizi_baslangic is not null and e.bitis>t and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet' and not oyun.sokak_yaptirimli(p.id,e.id) and not p.yasakli and p.son_gorulme>t-interval '14 days';
 select count(*) into aktif from oyun.profiller where not yasakli and olusturma<t-interval '3 days' and son_gorulme>t-interval '14 days';
 if n>=3 and kisi>=greatest(15,ceil(aktif*0.20)) then
  update oyun.sokak_kriz set kirmizi_baslangic=coalesce(kirmizi_baslangic,t) where id=1 returning * into k;
 else update oyun.sokak_kriz set kirmizi_baslangic=null where id=1; return; end if;
 if k.kirmizi_baslangic<=t-interval '72 hours' and (k.son_secim is null or k.son_secim<t-interval '14 days') and not exists(select 1 from oyun.secimler where tur in ('mv','cb','cb2') and (oy_bas<=t and (goreve_bas>t or durum<>'tamam') or durum='bekliyor' and oy_bas>t and oy_bas<t+interval '7 days')) and not exists(select 1 from oyun.makamlar where tur='cb' and bit is null and bas>t-interval '7 days') then
  dm:=oyun.erken_genel_secim_olustur(t,0::bigint);
  update oyun.sokak_kriz set son_secim=t,secim_donem=dm,kirmizi_baslangic=null where id=1;
  perform oyun.sokak_soz_tick(); for x in select id from oyun.sokak_eylem where durum='aktif' loop
   update oyun.sokak_eylem set durum='bitti',kapandi=t,kirmizi_baslangic=null,erken_secim_uyarisi=true where id=x.id;
   perform oyun.sokak_duyur(x.id,'72 saatlik ulusal kriz koşulları sağlandı: erken seçim takvimi devreye girdi. Mevcut yönetim devir gününe kadar görevde.');
  end loop;
 end if;
end $function$
;

-- oyun.sokak_yenile
CREATE OR REPLACE FUNCTION oyun.sokak_yenile(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
 and not oyun.sokak_yaptirimli(p.id,x.id)
 and not p.yasakli and p.olusturma<t-interval '3 days' and p.son_gorulme>t-interval '14 days';
 puan:=least(100,greatest(0,
  oyun.sokak_karar_etki(x.id)
  +oyun.sokak_memnuniyetsizlik(x.il_id)*0.35
  +least(60,57*ln(1+x.muhalefet_fonu/greatest(1,a.baslatma_bedeli))/ln(21::numeric))
  +least(28,n*4)
  -40*least(1,x.iktidar_fonu/greatest(1,x.muhalefet_fonu*a.sakinlestirme_carpani))
 ));
 -- Kirmizi seviye icin Turkiye genelinden asgari 3 gercek katilimci gerekir; yalniz para yeterli degildir.
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
end $function$
;

-- public.sokak_destek
CREATE OR REPLACE FUNCTION public.sokak_destek(p_eylem bigint, p_taraf text, p_kaynak text DEFAULT 'oyuncu'::text, p_kaynak_id bigint DEFAULT NULL::bigint, p_tutar numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; x oyun.sokak_eylem; a oyun.sokak_eylem_ayar; t timestamptz:=oyun.simdi(); kid text; toplam numeric; limit_tutar numeric;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform pg_advisory_xact_lock(781231,1);
 p:=oyun.profilim();
 if p.yasakli or p.olusturma>t-interval '3 days' then raise exception 'Kısıtsız ve en az 3 günlük hesap gerekli'; end if;
 select * into a from oyun.sokak_eylem_ayar where id=1;
 if not a.aktif then raise exception 'Sokak hareketleri kapalı'; end if;
 if p_taraf is null or p_taraf not in ('muhalefet','iktidar') or p_kaynak is null or p_kaynak not in ('oyuncu','parti','dernek') or p_tutar is null or p_tutar::text in ('NaN','Infinity','-Infinity') or p_tutar<0 or p_tutar<>round(p_tutar,2) then raise exception 'Geçersiz destek'; end if;
 if oyun.sokak_yaptirimli(u,p_eylem) then raise exception 'Bu eylemde geçici yaptırımınız var; itiraz edebilirsiniz'; end if;
 if exists(select 1 from oyun.sokak_soz where eylem_id=p_eylem and durum='takip') then raise exception 'Eylem uzlaşma için askıda';end if;
 kid:=case when p_kaynak='oyuncu' then u::text else p_kaynak_id::text end;
 if p_kaynak='parti' and not exists(select 1 from oyun.partiler where id=p_kaynak_id and gb=u and not kapali) then raise exception 'Parti kasası için genel başkan yetkisi gerekli'; end if;
 if p_kaynak='dernek' and not exists(select 1 from oyun.dernekler where id=p_kaynak_id and baskan=u and not kapali) then raise exception 'Dernek başkanı yetkisi gerekli'; end if;
 if p_taraf='muhalefet' and false then raise exception 'İktidar üyeleri uzlaşma tarafını destekleyebilir'; end if;
 if p_tutar=0 and p_kaynak<>'oyuncu' then raise exception 'Kurumsal destek fonla verilir'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Eylem aktif değil'; end if;
 if exists(select 1 from oyun.sokak_eylem_destek where eylem_id=x.id and destekci_tur=p_kaynak and destekci_id=kid and taraf<>p_taraf) then raise exception 'Aynı eylemde iki taraf desteklenemez'; end if;
 if not exists(select 1 from oyun.sokak_eylem_destek where eylem_id=x.id and destekci_tur=p_kaynak and destekci_id=kid) and (select count(distinct d.eylem_id) from oyun.sokak_eylem_destek d join oyun.sokak_eylem e on e.id=d.eylem_id where d.destekci_tur=p_kaynak and d.destekci_id=kid and e.durum='aktif' and e.bitis>t)>=a.orgut_es_zamanli_destek_siniri then raise exception 'Aynı anda en fazla 3 eylem desteklenebilir'; end if;
 if p_tutar=0 then
  -- Turkiye'nin her ilinden oyuncu eyleme katilabilir. Hesap yas ve diger yetki kontrolleri korunur.
  insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,taraf,temsilci) values(x.id,'oyuncu',kid,p_taraf,u) on conflict do nothing;
 else
  if p_tutar<1000 then raise exception 'En az 1.000 TL fonlanabilir'; end if;
  limit_tutar:=a.baslatma_bedeli*(case when p_kaynak='oyuncu' then 2 else 5 end)*(case when p_taraf='iktidar' then 3 else 1 end);
  select coalesce(sum(tutar),0) into toplam from oyun.sokak_eylem_fon where kaynak_tur=p_kaynak and kaynak_id=kid and zaman>t-interval '24 hours';
  if toplam+p_tutar>limit_tutar then raise exception 'Kaynağın son 24 saatlik fon limiti aşılıyor: % TL',limit_tutar; end if;
  if p_taraf='muhalefet' and x.muhalefet_fonu+p_tutar>a.baslatma_bedeli*20 then raise exception 'Eylem toplam fon tavanına ulaşıyor'; end if;
  if p_taraf='iktidar' and x.iktidar_fonu+p_tutar>x.muhalefet_fonu*a.sakinlestirme_carpani then raise exception 'Gerekli uzlaşma tutarı: % TL',x.muhalefet_fonu*a.sakinlestirme_carpani-x.iktidar_fonu; end if;
  if p_kaynak='oyuncu' then
   update oyun.cuzdan set para=para-p_tutar where user_id=u and para>=p_tutar;
  elsif p_kaynak='parti' then
   update oyun.partiler set kasa=kasa-p_tutar where id=p_kaynak_id and kasa>=p_tutar;
  else update oyun.dernekler set kasa=kasa-p_tutar where id=p_kaynak_id and kasa>=p_tutar;
  end if;
  if not found then raise exception 'Bakiye yetersiz'; end if;
  if p_kaynak='oyuncu' then insert into oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) values(u,t,-p_tutar,'gider','Halk hareketi #'||x.id||' / '||p_taraf);
  elsif p_kaynak='parti' then insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama) values(p_kaynak_id,t,-p_tutar,'gider','Halk hareketi #'||x.id||' / '||p_taraf);
  else insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id) values(p_kaynak_id,t,-p_tutar,'gider','Halk hareketi #'||x.id||' / '||p_taraf,u); end if;
  insert into oyun.sokak_eylem_fon(eylem_id,oyuncu_id,taraf,tutar,zaman,kaynak_tur,kaynak_id) values(x.id,u,p_taraf,p_tutar,t,p_kaynak,kid);
  insert into oyun.sokak_eylem_destek(eylem_id,destekci_tur,destekci_id,taraf,temsilci,destek_turu,tutar) values(x.id,p_kaynak,kid,p_taraf,u,'fon',p_tutar) on conflict(eylem_id,destekci_tur,destekci_id,taraf,destek_turu) do update set tutar=oyun.sokak_eylem_destek.tutar+excluded.tutar;
  update oyun.sokak_eylem set muhalefet_fonu=muhalefet_fonu+case when p_taraf='muhalefet' then p_tutar else 0 end,iktidar_fonu=iktidar_fonu+case when p_taraf='iktidar' then p_tutar else 0 end,bitis=case when p_taraf='muhalefet' then least(baslangic+make_interval(hours=>a.max_sure_saat),bitis+interval '12 hours'*(p_tutar/a.baslatma_bedeli)) else bitis end where id=x.id;
  perform oyun.olay('siyaset',format('Eylem #%s: %s tarafına %s TL %s desteği.',x.id,p_taraf,p_tutar,p_kaynak),x.il_id,x.parti_id);
 end if;
 perform oyun.sokak_yenile(x.id);
 -- Bir eylem kırmızıdan çıkınca ulusal 72 saatlik sayaç da anında kesilir.
 if (select count(*) from oyun.sokak_eylem where durum='aktif' and bitis>t and kirmizi_baslangic is not null)<3 then update oyun.sokak_kriz set kirmizi_baslangic=null where id=1; end if;
 return jsonb_build_object('tamam',true);
end $function$
;

revoke execute on function public.sokak_destek(bigint,text,text,bigint,numeric) from public,anon;
grant execute on function public.sokak_destek(bigint,text,text,bigint,numeric) to authenticated;
