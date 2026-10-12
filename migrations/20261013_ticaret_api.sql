-- Yeni urun bazli gercek ticaret islem sunucusu. Var olan RPC'leri bozmaz.
create or replace function oyun.eko_urun_toptan(
 p_magaza bigint,p_uretici bigint,p_urun text,p_adet integer,p_islemci uuid default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare st oyun.sirketler; fa oyun.sirketler; stok oyun.eko_urun_stok; m oyun.eko_isletmeler;
 tutar numeric; fiyat numeric;
begin
 if p_adet not between 1 and 500 or p_magaza=p_uretici then raise exception 'Gecersiz toptan siparis.';end if;
 -- Sirali sirket kilidi cift satista cakismayi onler.
 perform 1 from oyun.sirketler where id in (p_magaza,p_uretici) order by id for update;
 select * into st from oyun.sirketler where id=p_magaza;
 select * into fa from oyun.sirketler where id=p_uretici;
 select * into m from oyun.eko_isletmeler where sirket_id=p_magaza;
 if st.id is null or fa.id is null or not st.aktif or not fa.aktif or m.tur<>'magaza'
  or not exists(select 1 from oyun.eko_isletmeler where sirket_id=p_uretici and tur='fabrika')
 then raise exception 'Magaza veya uretici uygun degil.';end if;
 select * into stok from oyun.eko_urun_stok where sirket_id=p_uretici and urun=p_urun for update;
 if stok.sirket_id is null or stok.adet<p_adet then raise exception 'Tedarikcide yeterli hazir stok yok.';end if;
 fiyat:=stok.satis_fiyati;
 if fiyat<=0 then raise exception 'Toptan satis fiyati belirlenmemis.';end if;
 tutar:=round(fiyat*p_adet);
 update oyun.sirketler set kasa=kasa-tutar where id=p_magaza and kasa>=tutar;
 if not found then raise exception 'Magaza kasasi yetersiz.';end if;
 update oyun.eko_urun_stok set adet=adet-p_adet,guncelleme=now() where sirket_id=p_uretici and urun=p_urun;
 update oyun.sirketler set kasa=kasa+tutar where id=p_uretici;
 insert into oyun.eko_urun_stok(sirket_id,urun,adet,maliyet_birim,satis_fiyati)
 values(p_magaza,p_urun,p_adet,fiyat,
  greatest(round(fiyat*1.4),coalesce((select onerilen_satis from oyun.eko_urun_katalog where kod=p_urun),round(fiyat*1.5))))
 on conflict(sirket_id,urun) do update set
 maliyet_birim=case when oyun.eko_urun_stok.adet+excluded.adet=0 then excluded.maliyet_birim
 else round((oyun.eko_urun_stok.maliyet_birim*oyun.eko_urun_stok.adet
 +excluded.maliyet_birim*excluded.adet)/(oyun.eko_urun_stok.adet+excluded.adet),2) end,
 adet=oyun.eko_urun_stok.adet+excluded.adet,
 guncelleme=now();
 insert into oyun.eko_islem_kayit(sirket_id,diger_sirket,oyuncu,tur,tutar,aciklama)
 values(p_magaza,p_uretici,p_islemci,'urun_tedarik',-tutar,format('%s x %s toptan alimi',p_adet,p_urun));
 return jsonb_build_object('miktar',p_adet,'toplam',tutar,'birim',fiyat);
end $$;
revoke all on function oyun.eko_urun_toptan(bigint,bigint,text,integer,uuid) from public,anon,authenticated;

create or replace function public.eko_ticaret_panel()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then
 raise exception 'Giris yapmalisin.';end if;
 return jsonb_build_object(
 'urunler',coalesce((select jsonb_agg(jsonb_build_object('kod',kod,'ad',ad,'grup',grup,'kategori',kullanim,'maliyet',maliyet,
 'parti',parti_ust,'dakika',uretim_dakika,'satis',onerilen_satis,'talep',talep) order by maliyet) from oyun.eko_urun_katalog where aktif),'[]'::jsonb),
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object(
 'id',s.id,'ad',s.ad,'sektor',s.sektor,'tur',e.tur,'grup',e.urun,'kategori',e.magaza_kategori,
 'il',e.il_id,'kasa',s.kasa,'sermaye',s.sermaye,'yonetici',oyun.sirket_yonetici_mi(s.id,u),
 'marka',case when mk.sirket_id is not null then jsonb_build_object('kategori',mk.kategori,'bedel',mk.isim_hakki,
 'ciro_payi',mk.komisyon,'kar_payi',mk.kar_payi) else null end,
 'bayilik',case when fr.id is not null then jsonb_build_object('marka',fr.marka,'ciro_payi',fr.komisyon,'kar_payi',fr.kar_payi) else null end
 ) order by s.id) from oyun.sirketler s
 join oyun.sirket_ortaklari o on o.sirket_id=s.id and o.user_id=u
 left join oyun.eko_isletmeler e on e.sirket_id=s.id
 left join oyun.eko_markalar mk on mk.sirket_id=s.id
 left join oyun.eko_franchise fr on fr.sube=s.id
 where s.aktif),'[]'::jsonb),
 'stok',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'urun',x.urun,'adet',x.adet,
 'maliyet',x.maliyet_birim,'fiyat',x.satis_fiyati))
 from oyun.eko_urun_stok x where x.sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u)),'[]'::jsonb),
 'tedarikciler',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'ad',s.ad,'urun',x.urun,'adet',x.adet,
 'fiyat',x.satis_fiyati,'il',e.il_id))
 from oyun.eko_urun_stok x join oyun.sirketler s on s.id=x.sirket_id
 join oyun.eko_isletmeler e on e.sirket_id=s.id and e.tur='fabrika'
 where x.adet>0 and s.aktif),'[]'::jsonb),
 'uretim',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'sirket',x.sirket_id,'urun',x.urun,'adet',x.adet,
 'maliyet',x.toplam_maliyet,'hazir',x.hazir,'tamam',x.tamamlandi) order by x.id desc)
 from (select * from oyun.eko_uretim_emir where sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u) order by id desc limit 60) x),'[]'::jsonb),
 'oto',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'urun',x.urun,
 'esik',x.esik,'miktar',x.miktar,'ust',x.azami_birim_fiyat,'bitis',x.bitis,'aktif',x.aktif))
 from oyun.eko_otomatik_tedarik x where x.sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u)),'[]'::jsonb),
 'satislar',coalesce((select jsonb_agg(jsonb_build_object('sirket',x.sirket_id,'urun',x.urun,'adet',x.adet,'ciro',x.ciro,
 'maliyet',x.mal_maliyeti,'gider',x.personel_gideri,'vergi',x.vergi,'royalty',x.isim_hakki,
 'kar_payi',x.kar_paylasim,'kar',x.net_kar,'zaman',x.zaman))
 from (select * from oyun.eko_npc_satis where sirket_id in
 (select sirket_id from oyun.sirket_ortaklari where user_id=u) order by id desc limit 70)x),'[]'::jsonb),
 'markalar',coalesce((select jsonb_agg(jsonb_build_object('id',m.sirket_id,'ad',s.ad,
 'kategori',m.kategori,'bedel',m.isim_hakki,'ciro_payi',m.komisyon,'kar_payi',m.kar_payi))
 from oyun.eko_markalar m join oyun.sirketler s on s.id=m.sirket_id where s.aktif),'[]'::jsonb)
 );
end $$;
revoke all on function public.eko_ticaret_panel() from public,anon;
grant execute on function public.eko_ticaret_panel() to authenticated;

create or replace function public.eko_ticaret_islem(p_eylem text,p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
 u uuid:=auth.uid();t timestamptz:=oyun.simdi();
 sid bigint:=nullif(p_veri->>'sirket','')::bigint;
 hedef bigint:=nullif(p_veri->>'hedef','')::bigint;
 ur text:=p_veri->>'urun';kategori text:=p_veri->>'kategori';
 miktar int:=coalesce(nullif(p_veri->>'adet','')::integer,0);
 esik int:=coalesce(nullif(p_veri->>'esik','')::integer,0);
 v numeric:=coalesce(nullif(p_veri->>'tutar','')::numeric,0);
 ciro numeric:=coalesce(nullif(p_veri->>'ciro','')::numeric,0);
 kar numeric:=coalesce(nullif(p_veri->>'kar','')::numeric,0);
 s oyun.sirketler; e oyun.eko_isletmeler; k oyun.eko_urun_katalog; x oyun.eko_urun_stok;
 marka oyun.eko_markalar; z bigint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris yapmalisin.';end if;
 if p_veri is null or jsonb_typeof(p_veri)<>'object' then raise exception 'Gecersiz veri.';end if;
 if sid is null then raise exception 'Sirket secilmedi.';end if;
 select * into s from oyun.sirketler where id=sid for update;
 select * into e from oyun.eko_isletmeler where sirket_id=sid;
 if s.id is null or not s.aktif or not oyun.sirket_yonetici_mi(sid,u)
 then raise exception 'Bu sirketi yonetmeye yetkin yok.';end if;
 if p_eylem='uret' then
  select * into k from oyun.eko_urun_katalog where kod=ur and aktif;
  if e.tur<>'fabrika' or k.kod is null or k.grup<>e.urun or miktar<1 or miktar>k.parti_ust then
   raise exception 'Urun bu fabrikada uretilemez veya parti kapasitesi asildi.';end if;
  v:=round(k.maliyet*miktar);
  update oyun.sirketler set kasa=kasa-v where id=sid and kasa>=v;
  if not found then raise exception 'Uretim icin kasa yetersiz.';end if;
  insert into oyun.eko_uretim_emir(sirket_id,urun,adet,toplam_maliyet,baslangic,hazir)
  values(sid,ur,miktar,v,t,t+make_interval(mins=>k.uretim_dakika)) returning id into z;
  insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
  values(sid,u,'urun_uretim',-v,format('%s adet %s uretim emri',miktar,k.ad));
  return jsonb_build_object('emir',z,'maliyet',v,'bitis',t+make_interval(mins=>k.uretim_dakika));
 elsif p_eylem='toptan' then
  if e.tur<>'magaza' then raise exception 'Bir magaza sec.';end if;
  return oyun.eko_urun_toptan(sid,hedef,ur,miktar,u);
 elsif p_eylem='fiyat' then
  select * into x from oyun.eko_urun_stok where sirket_id=sid and urun=ur for update;
  select * into k from oyun.eko_urun_katalog where kod=ur and aktif;
  if x.sirket_id is null or k.kod is null or v<>round(v) then raise exception 'Urun veya fiyat gecersiz.';end if;
  if e.tur='fabrika' then
   if v<round(k.maliyet*1.05) or v>round(k.onerilen_satis*1.2)
   then raise exception 'Toptan fiyat uretim maliyeti ve piyasa araliginda olmali.';end if;
  elsif e.tur='magaza' then
   if v<round(x.maliyet_birim*1.05) or v>round(k.onerilen_satis*3)
   then raise exception 'Perakende fiyati maliyetin ustunde ve piyasa araliginda olmali.';end if;
  else raise exception 'Yalnizca fabrika veya magaza urununu fiyatlayabilir.';end if;
  update oyun.eko_urun_stok set satis_fiyati=v,guncelleme=t where sirket_id=sid and urun=ur;
  return jsonb_build_object('fiyat',v);
 elsif p_eylem='magaza_tur' then
  if e.tur<>'magaza' or kategori not in ('market','fastfood','kahve') then
   raise exception 'Market, fast food veya kahve kategorisi sec.';end if;
  if exists(select 1 from oyun.eko_franchise f join oyun.eko_markalar m on m.sirket_id=f.marka
  where f.sube=sid and m.kategori<>kategori) then raise exception 'Bayilik markasinin kategorisi degistirilemez.';end if;
  if exists(select 1 from oyun.eko_markalar where sirket_id=sid) then
    raise exception 'Markali magazanin kategorisi degistirilemez.';end if;
  update oyun.eko_isletmeler set magaza_kategori=kategori where sirket_id=sid;
  return jsonb_build_object('kategori',kategori);
 elsif p_eylem='oto' then
  if e.tur<>'magaza' then raise exception 'Otomatik tedarik sadece magazalar icindir.';end if;
  select * into k from oyun.eko_urun_katalog where kod=ur and aktif;
  if k.kod is null then raise exception 'Urun bulunamadi.';end if;
  if coalesce((p_veri->>'aktif')::boolean,true)=false then
   update oyun.eko_otomatik_tedarik set aktif=false where sirket_id=sid and urun=ur;
   return jsonb_build_object('aktif',false);
  end if;
  if esik not between 0 and 300 or miktar not between 1 and 500 or v<k.maliyet or v>k.onerilen_satis*3
  then raise exception 'Stok esigi, miktar veya azami fiyat gecersiz.';end if;
  -- Her 7 gunluk oyun otomasyonu 12.000 TL. Aktif suresi bitmeden yeniden abonelik tahsil edilmez.
  if not exists(select 1 from oyun.eko_otomatik_tedarik
    where sirket_id=sid and urun=ur and aktif and bitis>t) then
   update oyun.sirketler set kasa=kasa-12000 where id=sid and kasa>=12000;
   if not found then raise exception 'Otomasyon bedeli icin 12.000 TL gerekli.';end if;
   update oyun.ulke set hazine=hazine+12000 where id=1;
  end if;
  insert into oyun.eko_otomatik_tedarik(sirket_id,urun,esik,miktar,azami_birim_fiyat,bitis,aktif)
  values(sid,ur,esik,miktar,v,t+interval '7 days',true)
  on conflict(sirket_id,urun) do update set esik=excluded.esik,miktar=excluded.miktar,
    azami_birim_fiyat=excluded.azami_birim_fiyat,bitis=greatest(oyun.eko_otomatik_tedarik.bitis,excluded.bitis),aktif=true;
  return jsonb_build_object('aktif',true,'bitis',(select bitis from oyun.eko_otomatik_tedarik where sirket_id=sid and urun=ur));
 elsif p_eylem='marka' then
  if e.tur<>'magaza' or kategori not in ('market','fastfood','kahve')
    or v<>round(v) or v<1000 or v>10000000 or ciro<1 or ciro>15 or kar<0 or kar>20
  then raise exception 'Marka, ucret veya pay oranlari gecersiz.';end if;
  if exists(select 1 from oyun.eko_franchise where sube=sid) then raise exception 'Baska markanin bayisi kendi markasini kuramaz.';end if;
  if not exists(select 1 from oyun.eko_markalar where sirket_id=sid) then
   perform public.eko_islem('marka_ac',jsonb_build_object('sirket',sid,'tutar',v,'adet',ciro));
  end if;
  update oyun.eko_markalar set kategori=kategori,isim_hakki=v,komisyon=ciro,kar_payi=kar,guncelleme=t where sirket_id=sid;
  update oyun.eko_isletmeler set magaza_kategori=kategori where sirket_id=sid;
  return jsonb_build_object('marka',sid,'kategori',kategori);
 elsif p_eylem='bayilik' then
  if e.tur<>'magaza' then raise exception 'Bayilik icin bir magaza gerekli.';end if;
  select * into marka from oyun.eko_markalar where sirket_id=hedef;
  if marka.sirket_id is null then raise exception 'Marka bulunamadi.';end if;
  perform public.eko_islem('franchise_al',jsonb_build_object('sirket',sid,'hedef',hedef));
  update oyun.eko_isletmeler set magaza_kategori=marka.kategori where sirket_id=sid;
  return jsonb_build_object('marka',hedef,'ciro',marka.komisyon,'kar',marka.kar_payi);
 else
  raise exception 'Bilinmeyen ticaret islemi.';
 end if;
end $$;
revoke all on function public.eko_ticaret_islem(text,jsonb) from public,anon;
grant execute on function public.eko_ticaret_islem(text,jsonb) to authenticated;
