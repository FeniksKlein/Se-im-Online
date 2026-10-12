-- Cron tarafindan 10 dakikada bir: uretim tamamla, abonelikli tedarik, saatlik NPC satis.
create or replace function oyun.eko_ticaret_tick()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
 t timestamptz:=oyun.simdi(); prod record; oto record; mag record; item record;cat oyun.eko_urun_katalog;
 stok_adet integer; sup bigint; siparis int; yapilan int:=0; alim int:=0; satilan int:=0;talep int; rakip int;
 faktor numeric; ucret numeric; maliyet numeric; personel numeric; vergi numeric;
 ciro numeric; royalty numeric; karpayi numeric; kardegeri numeric;net numeric;
 f oyun.eko_franchise; m oyun.eko_markalar;
 donem timestamptz:=date_trunc('hour',now());
begin
 if not pg_try_advisory_xact_lock(424261) then return jsonb_build_object('kilitli',true); end if;
 -- Tamamlanmis uretim emrini bir defa stoklara aktar; maliyet baslangicta odenmistir.
 for prod in
 select q.*,k.maliyet as birim,k.onerilen_satis
 from oyun.eko_uretim_emir q join oyun.eko_urun_katalog k on k.kod=q.urun
 where q.tamamlandi is null and q.hazir<=t order by q.hazir,q.id
 limit 300 for update of q skip locked
 loop
   update oyun.eko_uretim_emir set tamamlandi=t where id=prod.id and tamamlandi is null;
   insert into oyun.eko_urun_stok(sirket_id,urun,adet,maliyet_birim,satis_fiyati)
   values(prod.sirket_id,prod.urun,prod.adet,prod.birim,
       greatest(round(prod.birim*1.2),round(prod.onerilen_satis*.72)))
   on conflict(sirket_id,urun) do update set
     maliyet_birim=case when oyun.eko_urun_stok.adet+excluded.adet=0 then excluded.maliyet_birim
      else round((oyun.eko_urun_stok.maliyet_birim*oyun.eko_urun_stok.adet+
      excluded.maliyet_birim*excluded.adet)/(oyun.eko_urun_stok.adet+excluded.adet),2) end,
     adet=oyun.eko_urun_stok.adet+excluded.adet,
     satis_fiyati=case when oyun.eko_urun_stok.satis_fiyati<=0 then excluded.satis_fiyati else oyun.eko_urun_stok.satis_fiyati end,
     guncelleme=t;
   yapilan:=yapilan+1;
 end loop;

 -- Istege bagli 7 gunluk otomatik stok yenileme: tedarikci stogu ve magaza parasi yoksa satin almaz.
 for oto in select a.* from oyun.eko_otomatik_tedarik a
 join oyun.eko_isletmeler ei on ei.sirket_id=a.sirket_id and ei.tur='magaza'
 join oyun.sirketler s on s.id=a.sirket_id and s.aktif
 where a.aktif and a.bitis>t order by a.sirket_id,a.urun limit 250
 loop
  begin
   select coalesce(adet,0) into stok_adet from oyun.eko_urun_stok
    where sirket_id=oto.sirket_id and urun=oto.urun;
   if coalesce(stok_adet,0)>oto.esik then continue;end if;
   select st.sirket_id into sup
    from oyun.eko_urun_stok st join oyun.eko_isletmeler e
      on e.sirket_id=st.sirket_id and e.tur='fabrika'
    join oyun.sirketler s on s.id=st.sirket_id and s.aktif
    where st.urun=oto.urun and st.adet>0 and st.satis_fiyati<=oto.azami_birim_fiyat
      and st.sirket_id<>oto.sirket_id
    order by st.satis_fiyati,st.sirket_id limit 1;
   if sup is null then continue;end if;
   select least(oto.miktar,adet) into siparis from oyun.eko_urun_stok
     where sirket_id=sup and urun=oto.urun;
   if siparis>0 then
     perform oyun.eko_urun_toptan(oto.sirket_id,sup,oto.urun,siparis,null);
     alim:=alim+1;
   end if;
  exception when others then null; -- tek siparisin basarisizligi digerlerinin satisini engellemez
  end;
 end loop;
 update oyun.eko_otomatik_tedarik set aktif=false where aktif and bitis<=t;

 -- NPC tuketimi: sinirli saatlik talep, sehir gelisimi, piyasa fiyati ve rakip sayisi.
 for mag in select ei.sirket_id,ei.il_id,ei.magaza_kategori,
   s.sermaye,coalesce(d.gelisim,50) as gelisim
   from oyun.eko_isletmeler ei join oyun.sirketler s on s.id=ei.sirket_id and s.aktif
   left join oyun.il_durum d on d.il_id=ei.il_id
   where ei.tur='magaza' and ei.son_perakende<=t-interval '1 hour'
   order by ei.sirket_id limit 250
 loop
  update oyun.eko_isletmeler set son_perakende=t
   where sirket_id=mag.sirket_id and son_perakende<=t-interval '1 hour';
  if not found then continue;end if;
  select count(*) into rakip from oyun.eko_isletmeler ei join oyun.sirketler s
  on s.id=ei.sirket_id and s.aktif where ei.tur='magaza' and ei.il_id=mag.il_id;
  select * into f from oyun.eko_franchise where sube=mag.sirket_id;
  if f.id is not null then select * into m from oyun.eko_markalar where sirket_id=f.marka;end if;
  for item in select st.*,k.kullanim,k.talep,k.onerilen_satis from oyun.eko_urun_stok st
      join oyun.eko_urun_katalog k on k.kod=st.urun and k.aktif
      where st.sirket_id=mag.sirket_id and st.adet>0 and st.satis_fiyati>0
      order by st.urun for update of st skip locked
  loop
    faktor:=greatest(.12,least(1.4,(item.onerilen_satis/greatest(item.satis_fiyati,1))^.8))
      *greatest(.65,least(1.5,.7+mag.gelisim/100))
      /(1+greatest(0,rakip-1)*.1);
    if mag.magaza_kategori<>'market' and mag.magaza_kategori<>item.kullanim then faktor:=faktor*.22;end if;
    if item.talep<=4 then
      talep:=case when (extract(epoch from donem)/3600+mag.sirket_id)::bigint%greatest(2,7-item.talep)=0
        then 1 else 0 end;
    else
      talep:=greatest(0,round((item.talep/8.0)*faktor)::integer);
    end if;
    siparis:=least(item.adet,talep);
    if siparis<=0 then continue;end if;
    ciro:=round(siparis*item.satis_fiyati);
    maliyet:=round(siparis*item.maliyet_birim);
    personel:=round(ciro*.07);
    vergi:=round(ciro*.05);
    royalty:=0;karpayi:=0;
    if f.id is not null then
     royalty:=round(ciro*f.komisyon/100);
     kardegeri:=greatest(0,ciro-maliyet-personel-vergi-royalty);
     karpayi:=round(kardegeri*f.kar_payi/100);
    end if;
    net:=ciro-maliyet-personel-vergi-royalty-karpayi;
    insert into oyun.eko_npc_satis(sirket_id,urun,donem,adet,ciro,mal_maliyeti,personel_gideri,
       vergi,isim_hakki,kar_paylasim,net_kar)
       values(mag.sirket_id,item.urun,donem,siparis,ciro,maliyet,personel,vergi,royalty,karpayi,net)
       on conflict(sirket_id,urun,donem) do nothing;
    if not found then continue;end if;
    update oyun.eko_urun_stok set adet=adet-siparis,guncelleme=t where sirket_id=mag.sirket_id and urun=item.urun;
    update oyun.sirketler set kasa=kasa+ciro-personel-vergi-royalty-karpayi where id=mag.sirket_id;
    if f.id is not null and (royalty+karpayi)>0 then
      update oyun.sirketler set kasa=kasa+royalty+karpayi where id=f.marka and aktif;
    end if;
    update oyun.ulke set hazine=hazine+vergi where id=1;
    satilan:=satilan+siparis;
  end loop;
 end loop;
 return jsonb_build_object('uretimler',yapilan,'oto_alimlar',alim,'satilan_adet',satilan);
end $$;
revoke all on function oyun.eko_ticaret_tick() from public,anon,authenticated;
select cron.schedule('eko-ticaret-periyodik','*/10 * * * *','select oyun.eko_ticaret_tick()');
