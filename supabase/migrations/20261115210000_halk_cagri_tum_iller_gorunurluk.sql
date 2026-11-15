-- 15.11.2026 · Her ildeki oyuncu bütün açık eylem imza çağrılarını görebilir.
-- İmza koşulları değişmedi; canlı çağrıların ve daha önce verilmiş imzaların verisi korunur.
-- Yerel filtre kaldırıldı, sadece 'imza' ve 'hazir' durumları listelenir.
create or replace function public.sokak_denge_panel() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); a oyun.sokak_denge_ayar:=oyun.sokak_denge(); t timestamptz:=oyun.simdi(); p oyun.profiller;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 perform oyun.sokak_cagri_dustur();
 select * into p from oyun.profiller where id=u;
 return jsonb_build_object(
  'ayar',jsonb_build_object('memnuniyet_esik',a.memnuniyet_esik,'memnuniyetsizlik_esik',a.memnuniyetsizlik_esik,'olay_saat',a.olay_saat,'hesap_gun',a.hesap_gun,'depozito',a.depozito,'imza_sayisi',a.imza_sayisi,'imza_saat',a.imza_saat,'il_bekleme_saat',a.il_bekleme_saat,'orgut_bekleme_saat',a.orgut_bekleme_saat,'ulke_tavan',oyun.sokak_ulke_tavan(),'buyuk_ivme',a.buyuk_ivme,'buyuk_katilim',a.buyuk_katilim,'buyuk_nabiz',a.buyuk_nabiz,'saatlik_yuzde',a.saatlik_yuzde),
  'cagrilar',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'il_id',c.il_id,'durum',c.durum,'gerekce',c.gerekce,'depozito',c.depozito,'bitis',c.bitis,'hata',c.hata,'benim',c.acan=u,'imza',(select count(*) from oyun.sokak_cagri_imza i where i.cagri_id=c.id),'gerek',a.imza_sayisi,'imzaladim',exists(select 1 from oyun.sokak_cagri_imza i where i.cagri_id=c.id and i.user_id=u)) order by c.acilis desc)
    from oyun.sokak_cagri c where c.durum in ('imza','hazir') ),'[]'::jsonb),
  'eylemler',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'ivme',round(v.ivme),'yorgunluk',round(v.yorgunluk),'not',v.son_not,'katilim',(select count(*) from oyun.sokak_eylem_destek d where d.eylem_id=e.id and d.destek_turu='katilim' and d.taraf='muhalefet' and d.destekci_tur='oyuncu'),'tavan',oyun.sokak_il_tavan(e.il_id),'nabiz',oyun.sokak_memnuniyetsizlik(e.il_id)))
    from oyun.sokak_eylem e left join oyun.sokak_ivme v on v.eylem_id=e.id where e.durum='aktif' and e.bitis>t),'[]'::jsonb));
end $$;
