-- Magaza satislari: sinirli sehir talebi, kafe/fastfood mutfak uretimi ve sanal alici raporu.
-- Eski sirket/kasa/stok kayitlari degistirilmez. Tum tahsilatlar mevcut vergi motorundan gecer.
begin;
alter table oyun.eko_uretim_emir add column if not exists kaynak text not null default 'fabrika';
alter table oyun.eko_npc_satis add column if not exists musteri_kesimi text not null default 'Yerel müşteriler';

create table if not exists oyun.eko_sehir_musteri_limiti(
 il_id smallint not null references oyun.iller(id),
 kategori text not null check(kategori in ('market','fastfood','kahve')),
 gun date not null,
 ust_sinir integer not null check(ust_sinir>0),
 satilan integer not null default 0 check(satilan>=0),
 primary key(il_id,kategori,gun),
 check (satilan<=ust_sinir)
);
create index if not exists eko_sehir_musteri_limiti_gun_idx on oyun.eko_sehir_musteri_limiti(gun);
revoke all on oyun.eko_sehir_musteri_limiti from public,anon,authenticated;

create or replace function public.eko_magaza_hazirla(p_sirket bigint,p_urun text,p_adet integer)
returns jsonb language plpgsql security definer set search_path to '' as $func$
declare v_user uuid:=auth.uid(); v_now timestamptz:=oyun.simdi();
 v_s oyun.sirketler; v_e oyun.eko_isletmeler; v_k oyun.eko_urun_katalog;
 v_limit integer; v_bedel numeric; v_dakika integer; v_id bigint;
begin
 if v_user is null or not exists(select 1 from oyun.profiller
   where id=v_user and not yasakli) then raise exception 'Giriş yapmalısın.';end if;
 select * into v_s from oyun.sirketler where id=p_sirket for update;
 select * into v_e from oyun.eko_isletmeler where sirket_id=p_sirket;
 select * into v_k from oyun.eko_urun_katalog where kod=p_urun and aktif;
 if v_s.id is null or not v_s.aktif or not oyun.sirket_yonetici_mi(p_sirket,v_user)
 then raise exception 'Bu işletmeyi yönetme yetkin yok.';end if;
 if v_e.tur is distinct from 'magaza' or v_e.magaza_kategori not in ('fastfood','kahve')
 then raise exception 'Yalnızca fast-food ve kahveciler ürün hazırlayabilir.';end if;
 if v_k.kod is null or v_k.kullanim<>v_e.magaza_kategori
 then raise exception 'Bu ürün işletmenin menüsüne uygun değil.';end if;
 v_limit:=least(v_k.parti_ust,250);
 if p_adet is null or p_adet not between 1 and v_limit
 then raise exception 'Bir hazırlama emrinde en fazla % adet üretilebilir.',v_limit;end if;
 if (select count(*) from oyun.eko_uretim_emir where sirket_id=p_sirket
   and kaynak='mutfak' and tamamlandi is null)>=2
 then raise exception 'Aynı anda en fazla iki mutfak hazırlama emri olabilir.';end if;
 v_bedel:=round(v_k.maliyet*p_adet);
 v_dakika:=greatest(10,ceil(v_k.uretim_dakika*0.5)::integer);
 update oyun.sirketler set kasa=kasa-v_bedel where id=p_sirket and kasa>=v_bedel;
 if not found then raise exception 'Malzeme ve hazırlama bedeli için işletme kasası yetersiz.';end if;
 insert into oyun.eko_uretim_emir(sirket_id,urun,adet,toplam_maliyet,baslangic,hazir,kaynak)
 values(p_sirket,p_urun,p_adet,v_bedel,v_now,v_now+make_interval(mins=>v_dakika),'mutfak')
 returning id into v_id;
 insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
 values(p_sirket,v_user,'mutfak_hazirlama',-v_bedel,
   format('%s adet %s mutfak hazırlama maliyeti',p_adet,v_k.ad));
 return jsonb_build_object('emir',v_id,'adet',p_adet,'maliyet',v_bedel,
   'hazir',v_now+make_interval(mins=>v_dakika),'dakika',v_dakika,
   'raf_fiyati',v_k.onerilen_satis);
end $func$;
revoke all on function public.eko_magaza_hazirla(bigint,text,integer) from public,anon;
grant execute on function public.eko_magaza_hazirla(bigint,text,integer) to authenticated;

-- Mevcut vergi, kar payi, franchise ve zamanlayici altyapisini koruyarak yalnizca
-- musteri talebi / mutfak stok kurallari parcalarini ekle.
do $patch$
declare src text; old text; neu text;
begin
 select pg_get_functiondef('oyun.eko_ticaret_tick()'::regprocedure) into src;
 old:='sale_id bigint; corp_branch numeric;';
 neu:='v_musteri text; v_saat integer; v_saat_kalan integer; v_sehir_kalan integer; v_saat_carpan numeric; v_sehir_ust integer;'||E'\n '||old;
 if position(old in src)=0 then raise exception 'tick degisken noktasi bulunamadi';end if;
 src:=replace(src,old,neu);

 old:='values(prod.sirket_id,prod.urun,prod.adet,prod.birim,'||E'\n       greatest(round(prod.birim*1.2),round(prod.onerilen_satis*.72)))';
 neu:='values(prod.sirket_id,prod.urun,prod.adet,prod.birim,'||E'\n       case when prod.kaynak=''mutfak'' then round(prod.onerilen_satis)'||E'\n       else greatest(round(prod.birim*1.2),round(prod.onerilen_satis*.72)) end)';
 if position(old in src)=0 then raise exception 'mutfak stok fiyat noktasi bulunamadi';end if;
 src:=replace(src,old,neu);

 old:='order by ei.sirket_id limit 250';
 neu:='order by md5(ei.sirket_id::text||((t at time zone ''Europe/Istanbul'')::date)::text) limit 250';
 if position(old in src)=0 then raise exception 'magaza dongusu sirasi bulunamadi';end if;
 src:=replace(src,old,neu);

 old:='if not found then continue;end if;'||E'\n  select count(*) into rakip';
 neu:='if not found then continue;end if;'||E'\n  v_saat:=extract(hour from (t at time zone ''Europe/Istanbul''))::integer;'||E'\n'||
 '  v_saat_carpan:=case when v_saat between 1 and 5 then 0.18'||E'\n'||
 '    when v_saat between 6 and 9 then 0.75'||E'\n'||
 '    when v_saat between 10 and 15 then 1.15'||E'\n'||
 '    when v_saat between 16 and 22 then 1.0 else 0.55 end;'||E'\n'||
 '  v_saat_kalan:=case mag.magaza_kategori when ''market'' then 18 when ''fastfood'' then 22 else 16 end;'||E'\n'||
 '  v_sehir_ust:=greatest(100,round((case mag.magaza_kategori when ''market'' then 450'||E'\n'||
 '    when ''fastfood'' then 340 else 280 end)+greatest(0,mag.gelisim)*5)::integer);'||E'\n'||
 '  insert into oyun.eko_sehir_musteri_limiti(il_id,kategori,gun,ust_sinir)'||E'\n'||
 '  values(mag.il_id,mag.magaza_kategori,(t at time zone ''Europe/Istanbul'')::date,v_sehir_ust)'||E'\n'||
 '  on conflict(il_id,kategori,gun) do nothing;'||E'\n'||
 '  select greatest(0,ust_sinir-satilan) into v_sehir_kalan'||E'\n'||
 '  from oyun.eko_sehir_musteri_limiti where il_id=mag.il_id'||E'\n'||
 '    and kategori=mag.magaza_kategori and gun=(t at time zone ''Europe/Istanbul'')::date for update;'||E'\n'||
 '  if v_sehir_kalan<=0 then continue;end if;'||E'\n'||
 '  v_musteri:=case mag.magaza_kategori'||E'\n'||
 '    when ''fastfood'' then case when v_saat between 11 and 15 then ''Öğle yemeği müşterileri'' else ''Çalışanlar, öğrenciler ve aileler'' end'||E'\n'||
 '    when ''kahve'' then case when v_saat between 7 and 11 then ''Sabah kahvesi müşterileri'' else ''Öğrenciler ve ofis çalışanları'' end'||E'\n'||
 '    else ''Mahalle sakinleri ve aileler'' end;'||E'\n'||
 '  select count(*) into rakip';
 if position(old in src)=0 then raise exception 'sehir talep noktasi bulunamadi';end if;
 src:=replace(src,old,neu);

 old:='if mag.magaza_kategori<>''market'' and mag.magaza_kategori<>item.kullanim then faktor:=faktor*.22;end if;';
 neu:='if mag.magaza_kategori<>''market'' and mag.magaza_kategori<>item.kullanim then faktor:=faktor*.22;end if;'||E'\n'||
 '    faktor:=faktor*v_saat_carpan;';
 if position(old in src)=0 then raise exception 'saat talebi bulunamadi';end if;
 src:=replace(src,old,neu);

 old:='siparis:=least(item.adet,talep);';
 neu:='siparis:=least(item.adet,talep,v_saat_kalan,v_sehir_kalan);';
 if position(old in src)=0 then raise exception 'satis kotasi noktasi bulunamadi';end if;
 src:=replace(src,old,neu);

 old:='vergi,isim_hakki,kar_paylasim,net_kar)'||E'\n       values(mag.sirket_id,item.urun,v_donem,siparis,ciro,maliyet,personel,v_vergi+corp_branch,royalty,karpayi,net)';
 neu:='vergi,isim_hakki,kar_paylasim,net_kar,musteri_kesimi)'||E'\n       values(mag.sirket_id,item.urun,v_donem,siparis,ciro,maliyet,personel,v_vergi+corp_branch,royalty,karpayi,net,v_musteri)';
 if position(old in src)=0 then raise exception 'satis musteri tipi noktasi bulunamadi';end if;
 src:=replace(src,old,neu);

 old:='satilan:=satilan+siparis;';
 neu:='update oyun.eko_sehir_musteri_limiti set satilan=satilan+siparis'||E'\n'||
 '    where il_id=mag.il_id and kategori=mag.magaza_kategori'||E'\n'||
 '    and gun=(t at time zone ''Europe/Istanbul'')::date and satilan+siparis<=ust_sinir;'||E'\n'||
 '    if not found then raise exception ''Şehir talep limiti değişti, satış tekrar denenmeli.'';end if;'||E'\n'||
 '    v_sehir_kalan:=v_sehir_kalan-siparis;'||E'\n'||
 '    v_saat_kalan:=v_saat_kalan-siparis;'||E'\n'||
 '    satilan:=satilan+siparis;';
 if position(old in src)=0 then raise exception 'satis kota tahsil noktasi bulunamadi';end if;
 src:=replace(src,old,neu);
 execute src;

 select pg_get_functiondef('public.eko_ticaret_panel()'::regprocedure) into src;
 old:='''il'',e.il_id,''kasa'',s.kasa';
 neu:='''il'',e.il_id,''sonraki_satis'',e.son_perakende+interval ''1 hour'',''kasa'',s.kasa';
 if position(old in src)=0 then raise exception 'panel sonraki satis noktasi bulunamadi';end if;
 src:=replace(src,old,neu);
 old:='''kar_payi'',x.kar_paylasim,''kar'',x.net_kar,''zaman'',x.zaman';
 neu:='''kar_payi'',x.kar_paylasim,''kar'',x.net_kar,''musteri'',x.musteri_kesimi,''zaman'',x.zaman';
 if position(old in src)=0 then raise exception 'panel musteri tipi noktasi bulunamadi';end if;
 src:=replace(src,old,neu);
 execute src;
end $patch$;

-- Son 30 gunde stoklandigi belli olmayan eski raporlar silinmez; sadece kota tablosu zamanla temizlenir.
commit;