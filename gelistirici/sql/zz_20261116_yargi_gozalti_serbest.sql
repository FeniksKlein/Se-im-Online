-- Anayasa madde 19 ve 138. Hukuka aykiri gozaltinda mahkeme karari gercekci modda derhal uygulanir.
-- Canlida dogrulanan iki RPC fonksiyonunun tam tanimlari. Mevcut oyuncu kayitlarini silmez.
CREATE OR REPLACE FUNCTION public.sokak_gozalti_hakim_incele(p_gozalti bigint, p_karar text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 u uuid:=auth.uid(); g oyun.sokak_gozalti; t timestamptz:=oyun.simdi(); k text; cb uuid;
begin
 if u is null or not exists(select 1 from oyun.adliye_makam where hakim=u)
 then raise exception 'Yalnız görevli hâkim inceleme yapabilir';end if;
 k:=case when p_karar in ('serbest','aykiri') then 'aykiri' when p_karar='devam' then 'devam' end;
 if k is null or length(btrim(coalesce(p_gerekce,''))) not between 25 and 2000 then
 raise exception 'Karar türü ve 25–2000 karakter gerekçe gereklidir';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.durum<>'aktif' or g.bitis<=t
 then raise exception 'Hâkim ön incelemesine uygun aktif gözaltı yok';end if;
 if g.on_inceleme_karari is not null then raise exception 'Bu dosyada ön inceleme kararı verilmiş';end if;
 if u=g.hedef or u is not distinct from g.avukat or
 exists(select 1 from oyun.sokak_polis where id=g.polis_id and yapan=u)
 then raise exception 'Çıkar çatışması: bu hâkim dosyayı inceleyemez';end if;
 update oyun.sokak_gozalti set
  on_inceleme_karari=k,on_inceleme_hakim=u,
  on_inceleme_gerekce=btrim(p_gerekce),on_inceleme_zaman=t
 where id=g.id;
 if k='aykiri' and oyun.gercekci_siyaset() then
   update oyun.sokak_gozalti set durum='serbest', bitis=t where id=g.id and durum='aktif';
 end if;
 perform oyun.bildir(g.hedef,'Gözaltı #'||g.id||' hâkim ön incelemesi: '||
  case when k='aykiri' then case when oyun.gercekci_siyaset() then 'Gözaltı hukuka aykırı bulundu; hâkim kararıyla derhal serbest bırakıldın. ' else 'Gözaltı hukuka aykırı bulundu; tahliye yetkisi Cumhurbaşkanındadır, dosya Cumhurbaşkanlığına iletildi. ' end
  else 'Gözaltı süresinin devamı uygun bulundu. ' end||left(btrim(p_gerekce),400));
 if k='aykiri' and not oyun.gercekci_siyaset() then
  cb:=oyun.cb_kim();
  if cb is not null then perform oyun.bildir(cb,'Hâkim, gözaltı #'||g.id||' ('||oyun.kad(g.hedef)||') için hukuka aykırılık tespit etti. Tahliye kararı sizde: Halk Hareketleri › Hukuk.');end if;
 end if;
 perform oyun.sokak_duyur(g.eylem_id,'Hâkim gözaltı #'||g.id||' ön incelemesinde '||
  case when k='aykiri' then case when oyun.gercekci_siyaset() then 'hukuka aykırılık tespit etti; gözaltı hâkim kararıyla sona erdi' else 'hukuka aykırılık tespit etti (tahliye Cumhurbaşkanı kararına bağlı)' end else 'gözaltının devamını uygun buldu' end||'.');
 return jsonb_build_object('tamam',true,'karar',k,'itiraz_hakki',true,'tahliye',case when oyun.gercekci_siyaset() then 'hakim_karari_derhal' else 'yalniz_cumhurbaskani' end);
end $function$;

CREATE OR REPLACE FUNCTION public.sokak_gozalti_mahkeme(p_gozalti bigint, p_karar text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti; x oyun.sokak_eylem;
 a oyun.sokak_eylem_ayar; t numeric:=0; o numeric:=0; cb uuid;
begin
 if u is null or not exists(select 1 from oyun.adliye_makam where hakim=u) then raise exception 'Yalnız görevli hâkim karar verebilir';end if;
 perform pg_advisory_xact_lock(781231,1);
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.id is null or g.itiraz is null or g.karar is not null then raise exception 'Karar bekleyen geçerli itiraz yok';end if;
 if u=g.hedef or u=g.avukat or exists(select 1 from oyun.sokak_polis where id=g.polis_id and yapan=u) then raise exception 'Çıkar çatışması: bu dosyada karar veremezsiniz';end if;
 if p_karar not in ('haksiz','uygun') or length(btrim(coalesce(p_gerekce,''))) not between 25 and 2000 then raise exception 'Karar ve en az 25 karakter gerekçe gerekli';end if;
 select * into x from oyun.sokak_eylem where id=g.eylem_id;
 select * into a from oyun.sokak_eylem_ayar where id=1;
 if p_karar='haksiz' then
   t:=a.baslatma_bedeli/2*case when g.avukat_durum='kabul' then 1.5 else 1 end;
   begin
    perform oyun.bm_kasa_harca('icisleri',t/oyun.pazar_tl_milyar(),'gider','Haksız gözaltı #'||g.id||' tazminatı');
    update oyun.cuzdan set para=para+t where user_id=g.hedef;
    if not found then raise exception 'Cüzdan bulunamadı';end if;
    insert into oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) values(g.hedef,oyun.simdi(),t,'gelir','Haksız gözaltı #'||g.id||' tazminatı');
    o:=t;
   exception when others then
    o:=0;
   end;
 end if;
 update oyun.sokak_gozalti set karar=p_karar,karar_gerekce=btrim(p_gerekce),hakim=u,
 karar_at=oyun.simdi(),tazminat=t,tazminat_odendi=o where id=g.id;
 if p_karar='haksiz' and oyun.gercekci_siyaset() and g.durum='aktif' and g.bitis>oyun.simdi() then
   update oyun.sokak_gozalti set durum='serbest', bitis=oyun.simdi() where id=g.id and durum='aktif';
 end if;
 perform oyun.bildir(g.hedef,'Gözaltı #'||g.id||' mahkeme kararı: '||p_karar||'. Tazminat: '||t||' TL, ödenen: '||o||' TL.'||
  case when p_karar='haksiz' and g.durum='aktif' and g.bitis>oyun.simdi() then case when oyun.gercekci_siyaset() then ' Mahkeme kararıyla derhal serbest bırakıldın.' else ' Tahliye yetkisi Cumhurbaşkanındadır.' end else '' end||' Gerekçe: '||left(p_gerekce,400));
 if p_karar='haksiz' and not oyun.gercekci_siyaset() and g.durum='aktif' and g.bitis>oyun.simdi() then
  cb:=oyun.cb_kim();
  if cb is not null then perform oyun.bildir(cb,'Mahkeme gözaltı #'||g.id||' ('||oyun.kad(g.hedef)||') için haksız gözaltı kararı verdi. Tahliye kararı sizde: Halk Hareketleri › Hukuk.');end if;
 end if;
 perform oyun.sokak_duyur(g.eylem_id,'Mahkeme gözaltı #'||g.id||' hakkında '||p_karar||' kararı verdi. Tazminat: '||t||' TL. '||left(p_gerekce,400));
 if p_karar='haksiz' then
 update oyun.ulke set memnuniyet=greatest(0,memnuniyet-.5) where id=1;
 update oyun.il_durum set memnuniyet=greatest(0,memnuniyet-1) where il_id=x.il_id;
 end if;
 return jsonb_build_object('tamam',true,'karar',p_karar,'tazminat',t,'odenen',o);
end $function$;
