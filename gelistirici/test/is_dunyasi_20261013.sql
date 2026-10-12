-- Yedi sistem icin tamamı geri alınan (ROLLBACK) bütünleşik test.
-- Test üretim verilerine hiçbir kalıcı değişiklik yapmaz.
DO $test$
declare
 s1 bigint;s2 bigint;s3 bigint;f bigint;h bigint;i bigint;
 contract_id bigint;project_id bigint;police_id bigint; x jsonb;cash1 numeric;cash2 numeric;
begin
 perform set_config('request.jwt.claim.sub','0e8added-d05d-4842-b872-bbe9133306a2',true);
 update oyun.cuzdan set para=30000000 where user_id in
  ('0e8added-d05d-4842-b872-bbe9133306a2','73356a93-0139-4b9c-b3cc-a69da78c46dc');
 f:=(public.eko_islem('kur',jsonb_build_object('tur','fabrika','urun','gida','ad','TEST FABRIKA','tutar',2000000,'il',48))->>'id')::bigint;
 s1:=(public.eko_islem('kur',jsonb_build_object('tur','magaza','ad','TEST MAGAZA 1','tutar',2000000,'il',48))->>'id')::bigint;
 s2:=(public.eko_islem('kur',jsonb_build_object('tur','magaza','ad','TEST MAGAZA 2','tutar',1000000,'il',48))->>'id')::bigint;
 s3:=(public.eko_islem('kur',jsonb_build_object('tur','magaza','ad','TEST MAGAZA 3','tutar',1000000,'il',48))->>'id')::bigint;
 h:=(public.eko_islem('kur',jsonb_build_object('tur','insaat','ad','TEST INSAAT','tutar',9000000,'il',48))->>'id')::bigint;
 i:=(public.eko_islem('kur',jsonb_build_object('tur','sigorta','ad','TEST SIGORTA','tutar',2000000,'il',48))->>'id')::bigint;
 perform public.eko_islem('uretim',jsonb_build_object('sirket',f,'adet',12));
 perform public.eko_islem('toptan',jsonb_build_object('sirket',s1,'hedef',f,'adet',8));
 perform public.eko_islem('fiyat',jsonb_build_object('sirket',s1,'tutar',9500));
 perform public.eko_islem('satis',jsonb_build_object('sirket',s1,'urun','gida','adet',3));
 if (select adet from oyun.eko_stok where sirket_id=s1 and urun='gida')<>5 then
   raise exception 'Stok mutabakat hatasi'; end if;
 perform public.eko_islem('marka_ac',jsonb_build_object('sirket',s1,'tutar',25000,'adet',5));
 perform public.eko_islem('franchise_al',jsonb_build_object('sirket',s3,'hedef',s1));
 begin
   perform public.eko_islem('birles',jsonb_build_object('sirket',s1,'hedef',s3));
   raise exception 'Franchise taahhudu varken birlesme izinli olmamali';
 exception when others then
   if sqlerrm like '%izinli olmamali%' then raise;end if;
 end;
 contract_id:=(public.eko_islem('sozlesme_teklif',jsonb_build_object('sirket',f,'hedef',s1,'konu','Deneme nakliye anlasmasi','tutar',10000))->>'id')::bigint;
 perform public.eko_islem('sozlesme_kabul',jsonb_build_object('id',contract_id));
 perform public.eko_islem('sozlesme_teslim',jsonb_build_object('id',contract_id));
 perform public.eko_islem('sozlesme_onay',jsonb_build_object('id',contract_id));
 if (select durum from oyun.eko_sozlesmeler where id=contract_id)<>'tamam'
   then raise exception 'Sozlesme mutabakati bozuk'; end if;
 project_id:=(public.eko_islem('proje',jsonb_build_object('sirket',h,'tip','daire','adet',1))->>'id')::bigint;
 update oyun.eko_projeler set hazir=now()-interval '1 hour' where id=project_id;
 perform public.eko_islem('konut_al',jsonb_build_object('proje',project_id));
 if (select kalan from oyun.eko_projeler where id=project_id)<>0
    then raise exception 'Konut teslimi bozuk';end if;
 select kasa into cash1 from oyun.sirketler where id=f;
 perform oyun.sirket_hesapla(f);
 select kasa into cash2 from oyun.sirketler where id=f;
 if cash1<>cash2 then raise exception 'Cifte haftalik kar olustu';end if;
 perform public.eko_islem('birles',jsonb_build_object('sirket',s1,'hedef',s2));
 if (select aktif from oyun.sirketler where id=s2) then raise exception 'Birlesme kaydi bozuk';end if;
 perform set_config('request.jwt.claim.sub','73356a93-0139-4b9c-b3cc-a69da78c46dc',true);
 police_id:=(public.eko_islem('police_al',jsonb_build_object('hedef',i,'tutar',50000))->>'id')::bigint;
 update oyun.eko_policeler set bas=now()-interval '49 hours' where id=police_id;
 perform public.eko_islem('police_kontrol',jsonb_build_object('id',police_id));
 if (select durum from oyun.eko_policeler where id=police_id)='aktif'
   then raise exception 'Sigorta hasar kontrolu bitmedi';end if;
 x:=public.eko_panel();
 if not x?'benim' then raise exception 'Oyuncu paneli yok';end if;
end $test$;
