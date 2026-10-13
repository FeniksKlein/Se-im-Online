-- Perakende tahakkuku: KDV dahil satis, kardan kurumlar vergisi, franchising, gunluk ortak haklari.
do $patch$
declare source text;
begin
 select pg_get_functiondef('oyun.eko_ticaret_tick()'::regprocedure) into source;
 if position('npc_branch' in source)>0 then return;end if;
 if position('v_vergi:=round(ciro*.05);' in source)=0 then raise exception 'NPC vergi kaynak kodu degismis.';end if;
 source:=replace(source,'f oyun.eko_franchise; m oyun.eko_markalar;',
 'sale_id bigint; corp_branch numeric; corp_brand numeric; branch_taxbase numeric; brandgross numeric;
 f oyun.eko_franchise; m oyun.eko_markalar;');
 source:=replace(source,'v_vergi:=round(ciro*.05);',
   'v_vergi:=oyun.eko_vergi_hesap(''satis'',ciro);');
 source:=replace(source,'net:=ciro-maliyet-personel-v_vergi-royalty-karpayi;',
   'branch_taxbase:=greatest(0,ciro-maliyet-personel-v_vergi-royalty-karpayi);
    corp_branch:=oyun.eko_vergi_hesap(''kar'',branch_taxbase);
    brandgross:=royalty+karpayi;
    corp_brand:=case when f.id is not null then oyun.eko_vergi_hesap(''kar'',brandgross) else 0 end;
    net:=ciro-maliyet-personel-v_vergi-royalty-karpayi-corp_branch;');
 source:=replace(source,'personel,v_vergi,royalty,karpayi,net)',
 'personel,v_vergi+corp_branch,royalty,karpayi,net)');
 source:=replace(source,'on conflict(sirket_id,urun,donem) do nothing;',
 'on conflict(sirket_id,urun,donem) do nothing returning id into sale_id;');
 source:=replace(source,
  'if not found then continue;end if;
    update oyun.eko_urun_stok set adet=adet-siparis',
  'if not found then continue;end if;
    if oyun.eko_vergi_tahsil(mag.sirket_id,''satis'',ciro,''npc_sale'',sale_id)<>v_vergi
      then raise exception ''Perakende satis vergisi uyusmuyor.'';end if;
    if oyun.eko_vergi_tahsil(mag.sirket_id,''kar'',branch_taxbase,''npc_branch'',sale_id)<>corp_branch
      then raise exception ''Magaza kurumlar vergisi uyusmuyor.'';end if;
    if f.id is not null and corp_brand>0 then
      if oyun.eko_vergi_tahsil(f.marka,''kar'',brandgross,''npc_brand'',sale_id)<>corp_brand
       then raise exception ''Franchise kurumlar vergisi uyusmuyor.'';end if;
    end if;
    update oyun.eko_urun_stok set adet=adet-siparis');
 source:=replace(source,
 'kasa=kasa+ciro-personel-v_vergi-royalty-karpayi',
 'kasa=kasa+ciro-personel-v_vergi-royalty-karpayi-corp_branch');
 source:=replace(source,
 'kasa=kasa+royalty+karpayi where id=f.marka',
 'kasa=kasa+royalty+karpayi-corp_brand where id=f.marka');
 source:=replace(source,
 'update oyun.ulke set hazine=hazine+v_vergi where id=1;
    satilan:=satilan+siparis;',
 'perform oyun.eko_kar_yaz(mag.sirket_id,''magaza'',sale_id,ciro,
      v_vergi+corp_branch,net,t);
    if f.id is not null and brandgross>0 then
      perform oyun.eko_kar_yaz(f.marka,''franchise'',sale_id,brandgross,
      corp_brand,brandgross-corp_brand,t);
    end if;
    satilan:=satilan+siparis;');
 execute source;
end $patch$;