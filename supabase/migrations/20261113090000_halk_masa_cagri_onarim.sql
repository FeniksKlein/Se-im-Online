-- =====================================================================
--  13.11.2026 · Halk Hareketleri onarımı: zamanlayıcı, çağrı imzası, Masa paneli
--
--  Ercan'ın bildirdiği sorunlar:
--   1) Hükümetin önerdiği tavizler, halk jürisi vb. eylemcilere görünmüyor;
--      eylemciler yanıt veremiyor.
--   2) Kişi sınırı yüzünden kendi organize ettiği eyleme katılamıyor; bazı
--      şehirlerde kimse olmadığı için hiç eylem açılamıyor.
--
--  Kök nedenler ve çözümler:
--   a) oyun.sokak_tick 09.11.2026 08:50'den beri her 5 dakikada bir
--      sokak_meydan_tick içindeki belirsiz "bas" sütunu yüzünden çöküyordu:
--      jüri aşamaları, söz (uzlaşma) takibi, süre bitişleri, seviyeler
--      ilerlemiyordu. plpgsql_check ile bütün sokak_* fonksiyonları tarandı;
--      aynı türden 7 hata daha düzeltildi (muhbir yanıtı, işgal pazarlığı oyu,
--      kapı kapı bildirimi, sızıntı şüphesi, muhbir ödülü, boykot açıklaması,
--      il güvenlik tedbiri onayı). Çapalı yama; veri değişmez.
--   b) Eylem çağrısı imzası: çağrıyı açanın kendi imzası artık sayılır ve
--      imza Türkiye'nin her ilinden verilebilir (il sakini şartı kalktı).
--      Varsayılan: açan dahil 3 imza, 12 saat.
--   c) public.sokak_masa_panel(p_eylem): eylemcinin yanıt verebileceği her
--      şey tek yerde (uzlaşma sözü oylaması, hükümet kararları, kırmızı hat,
--      halk jürisi, işgal pazarlığı, arabulucu heyeti). Arayüzde "🤝 Masa"
--      sekmesi ve bekleyen yanıt şeridi.
-- =====================================================================

-- ---------- a) belirsiz sütun onarımları (canlıya 13.11'de uygulandı; yeniden çalıştırılabilir) ----------
create or replace function oyun.sokak_yama_uygula(p_fn regprocedure, p_eski text, p_yeni text)
returns void language plpgsql set search_path to '' as $$
declare d text:=pg_get_functiondef(p_fn); e text;
begin
 if position(p_yeni in d)>0 then return; end if;
 e:=replace(d,p_eski,p_yeni);
 if e=d then raise exception 'çapa bulunamadı: % · %', p_fn, left(p_eski,60); end if;
 execute e;
end $$;
revoke all on function oyun.sokak_yama_uygula(regprocedure,text,text) from public, anon, authenticated;

select oyun.sokak_yama_uygula('oyun.sokak_meydan_tick()',
 'update oyun.sokak_son_gece set durum=''canli'' where durum=''hazir'' and bas<=t and bit>t;',
 'update oyun.sokak_son_gece sg set durum=''canli'' where sg.durum=''hazir'' and sg.bas<=t and sg.bit>t;');
select oyun.sokak_yama_uygula('oyun.sokak_meydan_tick()',
 'o ilin parti liderinin kararıdır.'',r.hedef_il,null);',
 'o ilin parti liderinin kararıdır.'',r.hedef_il::smallint,null);');
select oyun.sokak_yama_uygula('oyun.sokak_meydan_tick()',
 'for r in select * from oyun.sokak_hafiza where anma=gun and ad is not null loop',
 'for r in select * from oyun.sokak_hafiza hz where hz.anma=gun and hz.ad is not null loop');
select oyun.sokak_yama_uygula('public.sokak_eylem_merkezi_islem(bigint,text,jsonb)',
 'select id into mid from oyun.sokak_muzakere q join oyun.sokak_isgal i on i.id=q.isgal_id',
 'select q.id into mid from oyun.sokak_muzakere q join oyun.sokak_isgal i on i.id=q.isgal_id');
select oyun.sokak_yama_uygula('public.sokak_meydan_islem(bigint,text,jsonb)',
 'update oyun.sokak_muhbir set durum=case when coalesce((p_veri->>''kabul'')::boolean,false) then ''kabul''',
 'update oyun.sokak_muhbir mb set durum=case when coalesce((p_veri->>''kabul'')::boolean,false) then ''kabul''');
select oyun.sokak_yama_uygula('public.sokak_meydan_islem(bigint,text,jsonb)',
 'returning id, para, makam_sozu, kuran into mid, para, mtext, h;',
 'returning mb.id, mb.para, mb.makam_sozu, mb.kuran into mid, para, mtext, h;');
select oyun.sokak_yama_uygula('public.sokak_meydan_islem(bigint,text,jsonb)',
 ' h uuid; mtext text; para numeric; n integer;',
 ' h uuid; mtext text; para numeric; v_para numeric; n integer;');
select oyun.sokak_yama_uygula('public.sokak_meydan_islem(bigint,text,jsonb)',
 'update oyun.sokak_muhbir set suphe=para where id=mid;',
 'v_para:=para; update oyun.sokak_muhbir set suphe=v_para where id=mid;');
select oyun.sokak_yama_uygula('public.sokak_meydan_islem(bigint,text,jsonb)',
 'update oyun.cuzdan set para=para+10000 where user_id=h;',
 'update oyun.cuzdan cz set para=cz.para+10000 where cz.user_id=h;');
select oyun.sokak_yama_uygula('public.sokak_meydan_islem(bigint,text,jsonb)',
 '''Şirket sahibi açıkladı: ''||p_veri->>''taraf''||''.''',
 '''Şirket sahibi açıkladı: ''||(p_veri->>''taraf'')||''.''');
select oyun.sokak_yama_uygula('public.sokak_tedbir_hamle(bigint,text,text)',
 'select gb into gb from oyun.partiler where id=me.parti_id;',
 'select pp.gb into gb from oyun.partiler pp where pp.id=me.parti_id;');
select oyun.sokak_yama_uygula('public.icisleri_kriz_karar(bigint,boolean,text)',
 'maliyet=CASE WHEN p_kabul THEN maliyet ELSE 0 END WHERE id=x.id;',
 'maliyet=CASE WHEN p_kabul THEN x.maliyet ELSE 0 END WHERE id=x.id;');

-- ---------- b) eylem çağrısı: açanın imzası sayılır, imza her ilden ----------
select oyun.sokak_yama_uygula('public.sokak_cagri_imza(bigint)',
 ' if u=c.acan then raise exception ''Çağrıyı açan kişi imza sayılmaz''; end if;
',
 ' -- 13.11.2026: çağrıyı açanın imzası açılışta otomatik sayılır.
');
select oyun.sokak_yama_uygula('public.sokak_cagri_imza(bigint)',
 ' if p.il_id is distinct from c.il_id then raise exception ''İmza için bu ilde yaşıyor olmalısın''; end if;
',
 ' -- 13.11.2026: imza Türkiye''nin her ilinden verilebilir (boş illerde eylem açılamıyordu).
');
select oyun.sokak_yama_uygula('public.sokak_cagri_ac(integer,text,text,text,bigint)',
 'cid bigint; txt text;',
 'cid bigint; txt text; cc oyun.sokak_cagri; vv jsonb;');
select oyun.sokak_yama_uygula('public.sokak_cagri_ac(integer,text,text,text,bigint)',
 'returning id into cid;
 return jsonb_build_object(''tamam'',true,''cagri_id'',cid,',
 'returning id into cid;
 insert into oyun.sokak_cagri_imza(cagri_id,user_id,zaman) values(cid,u,t) on conflict do nothing;
 if a.imza_sayisi<=1 then
  update oyun.sokak_cagri set durum=''hazir'' where id=cid and durum=''imza'';
  select * into cc from oyun.sokak_cagri where id=cid;
  begin vv:=oyun.sokak_cagri_baslat(cc); exception when others then update oyun.sokak_cagri set hata=sqlerrm where id=cid; end;
 end if;
 return jsonb_build_object(''tamam'',true,''imza_var'',1,''cagri_id'',cid,');

update oyun.sokak_denge_ayar set imza_sayisi=3, imza_saat=12 where id=1 and imza_sayisi=4 and imza_saat=6;

-- ---------- c) Masa paneli: eylemcinin yanıt verebileceği her şey ----------
create or replace function public.sokak_masa_panel(p_eylem bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); s oyun.sokak_soz; j oyun.sokak_juri; kh oyun.sokak_kirmizi_hat;
 kat boolean; yon boolean; yargi boolean; aktif boolean; bek int:=0; soz jsonb; kararlar jsonb; juri jsonb; kirmizi jsonb; muz jsonb; heyet jsonb;
 talep text; mz record; olcum numeric; ad_talep jsonb:='{"hizmet":"İl hizmet memnuniyeti +5 puan","issizlik":"İşsizlik −0,5 puan","vergi":"Vergi −1 puan","genel":"Genel talep"}';
 ad_karar jsonb:='{"masa":"Uzlaşma masası","yonlendirme":"Bilgilendirme ve yönlendirme","uyari":"Sert siyasi uyarı","dagitma":"Ek bütçeyle dağıtma","yaptirim":"6 saatlik eylem yaptırımı"}';
 ad_kh jsonb:='{"bakanlik":"Bakanlık sözü","yatirim":"İle yatırım","af":"Af"}';
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if x.id is null then raise exception 'Eylem bulunamadı'; end if;
 aktif:=x.durum='aktif' and x.bitis>t;
 kat:=oyun.sokak_katilimci_mi(x.id,u,'muhalefet');
 yon:=oyun.sokak_yonetebilir(u);
 yargi:=exists(select 1 from oyun.adliye_makam where hakim=u) and not yon;
 select tur into talep from oyun.sokak_talep where eylem_id=x.id;

 -- uzlaşma sözü (hükümetin somut taviz teklifi) ve katılımcı oylaması
 select * into s from oyun.sokak_soz where eylem_id=x.id;
 if s.eylem_id is not null then
  begin olcum:=oyun.sokak_olcum(x.id,s.tur); exception when others then olcum:=null; end;
  soz:=jsonb_build_object('durum',s.durum,'tur',s.tur,'talep',ad_talep->>s.tur,'baslangic',s.baslangic,'hedef',s.hedef,'olcum',olcum,
   'oy_sonu',s.oy_sonu,'son_tarih',s.son_tarih,
   'evet',(select count(*) from oyun.sokak_soz_oy where eylem_id=x.id and oy),
   'hayir',(select count(*) from oyun.sokak_soz_oy where eylem_id=x.id and not oy),
   'secmen',(select count(*) from oyun.sokak_soz_oy where eylem_id=x.id),
   'oyum',(select oy from oyun.sokak_soz_oy where eylem_id=x.id and user_id=u),
   'secmenim',exists(select 1 from oyun.sokak_soz_oy where eylem_id=x.id and user_id=u),
   'oy_hakki',aktif and s.durum='oylama' and s.oy_sonu>t and exists(select 1 from oyun.sokak_soz_oy where eylem_id=x.id and user_id=u and oy is null),
   'metin',(select k.gerekce from oyun.sokak_karar k where k.id=s.karar_id),
   'yapan',(select oyun.kad(k.yapan) from oyun.sokak_karar k where k.id=s.karar_id));
  if (soz->>'oy_hakki')::boolean then bek:=bek+1; end if;
 end if;

 -- hükümet kararları ve bana açık yanıtlar
 select coalesce(jsonb_agg(z order by (z->>'zaman') desc),'[]'::jsonb) into kararlar from (
  select jsonb_build_object('id',k.id,'tur',k.tur,'ad',coalesce(ad_karar->>k.tur,k.tur),'durum',k.durum,'gerekce',k.gerekce,
   'yapan',oyun.kad(k.yapan),'unvan',oyun.sokak_bedel_unvan(k.yapan,x.il_id),'zaman',k.zaman,'bitis',k.bitis,'suresi_doldu',k.bitis<=t,
   'cevap',k.cevap,'hedef',oyun.kad(k.hedef),'soz',exists(select 1 from oyun.sokak_soz ss where ss.karar_id=k.id),
   'secenekler',case when not aktif or k.bitis<=t or exists(select 1 from oyun.sokak_soz ss where ss.karar_id=k.id) then '[]'::jsonb
     when k.tur='masa' and k.durum='aktif' and u=x.baslatan then '[{"k":"kabul","ad":"Uzlaşmayı kabul et ve eylemi bitir"},{"k":"ret","ad":"Teklifi reddet"}]'::jsonb
     when k.tur='yaptirim' and k.durum='aktif' and u=k.hedef then '[{"k":"itiraz","ad":"Yaptırıma itiraz et (uygulama durur)"}]'::jsonb
     when k.tur='yaptirim' and k.durum='itiraz' and yargi and u<>k.yapan and u is distinct from k.hedef then '[{"k":"kaldirildi","ad":"Yargı: yaptırımı kaldır"},{"k":"onandi","ad":"Yargı: yaptırımı onayla"}]'::jsonb
     else '[]'::jsonb end) z
  from oyun.sokak_karar k where k.eylem_id=x.id order by k.zaman desc limit 12) q;
 select bek+count(*) into bek from jsonb_array_elements(kararlar) z where jsonb_array_length(z->'secenekler')>0;

 -- kırmızı hat: gizli teklif yalnız organizatöre; ifşa edileni herkes görür
 select * into kh from oyun.sokak_kirmizi_hat where eylem_id=x.id and (durum='bekliyor' and u=x.baslatan or durum='ifsa') order by id desc limit 1;
 if kh.id is not null then
  kirmizi:=jsonb_build_object('durum',kh.durum,'teklif',kh.teklif,'teklif_ad',coalesce(ad_kh->>kh.teklif,kh.teklif),'metin',kh.metin,'zaman',kh.zaman,
   'yanit_hakki',aktif and kh.durum='bekliyor' and u=x.baslatan);
  if (kirmizi->>'yanit_hakki')::boolean then bek:=bek+1; end if;
 end if;

 -- halk jürisi
 select * into j from oyun.sokak_juri where eylem_id=x.id;
 if j.eylem_id is not null then
  juri:=jsonb_build_object('durum',j.durum,'bitis',j.bitis,'sonuc',j.sonuc,
   'uye',(select count(*) from oyun.sokak_juri_uye where eylem_id=x.id),
   'oy_veren',(select count(*) from oyun.sokak_juri_uye where eylem_id=x.id and oy is not null),
   'uyeyim',exists(select 1 from oyun.sokak_juri_uye where eylem_id=x.id and user_id=u),
   'oyum',(select oy from oyun.sokak_juri_uye where eylem_id=x.id and user_id=u),
   'sozler',coalesce((select jsonb_agg(jsonb_build_object('taraf',z.taraf,'metin',z.metin,'zaman',z.zaman) order by z.zaman) from oyun.sokak_juri_soz z where z.eylem_id=x.id),'[]'::jsonb),
   'savunma_taraf',case when j.durum='savunma' and aktif then case when yon then 'hukumet' when u=x.baslatan then 'meydan' end end,
   'kalan_soz',case when yon then 3-(select count(*) from oyun.sokak_juri_soz where eylem_id=x.id and taraf='hukumet')
                    when u=x.baslatan then 3-(select count(*) from oyun.sokak_juri_soz where eylem_id=x.id and taraf='meydan') end);
  if aktif and (juri->>'uyeyim')::boolean and juri->>'oyum' is null and j.durum<>'bitti' then bek:=bek+1; end if;
  if juri->>'savunma_taraf' is not null and coalesce((juri->>'kalan_soz')::int,0)>0 then bek:=bek+1; end if;
 end if;

 -- işgal pazarlığı (hükümetin işgalcilere teklifi)
 select q.id, q.metin, q.bedel, q.durum, q.bitis,
  (select count(*) from oyun.sokak_muzakere_oy o where o.muzakere_id=q.id and o.oy='evet') evet,
  (select count(*) from oyun.sokak_muzakere_oy o where o.muzakere_id=q.id and o.oy='hayir') hayir,
  (select o.oy from oyun.sokak_muzakere_oy o where o.muzakere_id=q.id and o.user_id=u) oyum
  into mz
 from oyun.sokak_muzakere q join oyun.sokak_isgal i on i.id=q.isgal_id where i.eylem_id=x.id order by q.id desc limit 1;
 if mz.id is not null then
  muz:=jsonb_build_object('id',mz.id,'metin',mz.metin,'bedel',mz.bedel,'durum',mz.durum,'bitis',mz.bitis,'evet',mz.evet,'hayir',mz.hayir,'oyum',mz.oyum,
   'oy_hakki',aktif and mz.durum='oy' and mz.bitis>t and kat and mz.oyum is null);
  if (muz->>'oy_hakki')::boolean then bek:=bek+1; end if;
 end if;

 -- arabulucu heyeti
 select coalesce(jsonb_agg(jsonb_build_object('kim',oyun.kad(h.user_id),'durum',h.durum,'ben',h.user_id=u,'rapor',h.rapor,'rapor_zaman',h.rapor_zaman,
   'davet_eden',oyun.kad(h.davet_eden),'zaman',h.zaman) order by h.zaman desc),'[]'::jsonb) into heyet
 from oyun.sokak_heyet h where h.eylem_id=x.id;
 select bek+count(*) into bek from jsonb_array_elements(heyet) z where (z->>'ben')::boolean and z->>'durum'='davet' and aktif;

 return jsonb_build_object('eylem_id',x.id,'aktif',aktif,'simdi',t,'bekleyen',bek,
  'rol',jsonb_build_object('katilimci',kat,'organizator',u=x.baslatan,'hukumet',yon,'yargi',yargi),
  'talep',talep,'talep_ad',ad_talep->>talep,
  'soz',soz,'kararlar',kararlar,'kirmizi',kirmizi,'juri',juri,'muzakere',muz,'heyet',heyet,
  'hukumet_yaniti',x.hukumet_yaniti,'yanit_zamani',x.yanit_zamani);
end $$;
revoke all on function public.sokak_masa_panel(bigint) from public, anon;
grant execute on function public.sokak_masa_panel(bigint) to authenticated;
