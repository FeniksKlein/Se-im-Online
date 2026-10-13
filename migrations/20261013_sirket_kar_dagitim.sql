-- Vergi matrahi ve gunluk temettu: uyumlu, cift kesintisiz ve yetkiye bagli.
create unique index if not exists eko_vergi_unique_sirket
on oyun.eko_vergi_hareket(kod,kaynak,kaynak_id,sirket_id)
where oyuncu is null and kaynak_id is not null;
create unique index if not exists eko_vergi_unique_oyuncu
on oyun.eko_vergi_hareket(kod,kaynak,kaynak_id,sirket_id,oyuncu)
where oyuncu is not null and kaynak_id is not null;

create or replace function oyun.eko_vergi_hesap(p_matrah text,p_tutar numeric)
returns numeric language sql stable security definer set search_path to '' as $$
 select coalesce(sum(round(case when v.kod='kdv' and p_matrah='satis'
 then greatest(0,p_tutar)*v.oran/(100+v.oran)
 else greatest(0,p_tutar)*v.oran/100 end)),0)
 from oyun.eko_vergi_turleri v where v.aktif and v.matrah=p_matrah;
$$;
revoke all on function oyun.eko_vergi_hesap(text,numeric) from public,anon,authenticated;

-- Tüm aktif matrah vergilerini tek seferlik kaydeder ve hazineye yatırır.
create or replace function oyun.eko_vergi_tahsil(p_sirket bigint,p_matrah text,p_baza numeric,
 p_kaynak text,p_kaynak_id bigint,p_oyuncu uuid default null)
returns numeric language plpgsql security definer set search_path to '' as $$
declare v record; odenen numeric:=0; x numeric;
begin
 if p_sirket is null or p_kaynak_id is null or p_matrah not in ('satis','kar','dagitim','sozlesme')
 then raise exception 'Vergi matrahi veya kaynak kimligi gecersiz.';end if;
 for v in select kod,oran from oyun.eko_vergi_turleri
 where matrah=p_matrah and aktif and oran>0 order by kod
 loop
   x:=round(case when v.kod='kdv' and p_matrah='satis'
   then greatest(0,p_baza)*v.oran/(100+v.oran)
   else greatest(0,p_baza)*v.oran/100 end);
   if x<=0 then continue;end if;
   insert into oyun.eko_vergi_hareket(sirket_id,oyuncu,kod,matrah,oran,tutar,kaynak,kaynak_id)
   values(p_sirket,p_oyuncu,v.kod,greatest(0,p_baza),v.oran,x,p_kaynak,p_kaynak_id)
   on conflict do nothing;
   if found then
      update oyun.ulke set hazine=hazine+x where id=1;
      odenen:=odenen+x;
   end if;
 end loop;
 return odenen;
end $$;
revoke all on function oyun.eko_vergi_tahsil(bigint,text,numeric,text,bigint,uuid) from public,anon,authenticated;

create or replace function public.eko_gunluk_kar_cek(p_sirket bigint,p_tutar numeric default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
 u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); bugun date:=(t at time zone 'Europe/Istanbul')::date;
 s oyun.sirketler; hisse numeric; toplam_hak numeric; net_alinabilir numeric;
 odeme numeric; kalan numeric; harc numeric; net numeric; id_yeni bigint; m record;
 diger_borc numeric; x numeric; eski_cek numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli)
 then raise exception 'Aktif oyuncu oturumu gerekli.';end if;
 select * into s from oyun.sirketler where id=p_sirket and aktif for update;
 if s.id is null then raise exception 'Aktif sirket bulunamadi.';end if;
 select pay into hisse from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=u;
 if hisse is null then raise exception 'Bu sirketin ortagi degilsin.';end if;
 if not exists(select 1 from oyun.eko_isletmeler where sirket_id=p_sirket)
 then raise exception 'Gunluk temettu yeni ticaret isletmeleri icindir.';end if;
 select coalesce(sum(hak-cekilen),0) into toplam_hak
 from oyun.eko_ortak_gunluk_hak where sirket_id=p_sirket and user_id=u and gun<bugun;
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0) into diger_borc
 from oyun.banka_mevduat m where m.banka_id=p_sirket and not m.kapandi;
 net_alinabilir:=least(greatest(0,toplam_hak),
   greatest(0,s.kasa-s.sermaye-diger_borc));
 if net_alinabilir<1 then raise exception 'Onceki gunlerden nakit olarak cekilebilir net karin yok.';end if;
 odeme:=coalesce(p_tutar,floor(net_alinabilir));
 if odeme<>round(odeme) or odeme<1 or odeme>floor(net_alinabilir)
 then raise exception 'Cekilebilecek en yuksek tutar % TL.',floor(net_alinabilir);end if;
 -- Stopaj ve kanunla eklenen dagitim vergileri bruto paydan kesilir.
 harc:=oyun.eko_vergi_hesap('dagitim',odeme);
 if harc>odeme then raise exception 'Vergi kesintisi brut odemeyi asiyor.';end if;
 net:=odeme-harc;
 update oyun.sirketler set kasa=kasa-odeme where id=p_sirket
   and kasa>=s.sermaye+diger_borc+odeme;
 if not found then raise exception 'Sermaye ve borc rezervi korunmali.';end if;
 kalan:=odeme;
 for m in select gun,hak,cekilen from oyun.eko_ortak_gunluk_hak
  where sirket_id=p_sirket and user_id=u and gun<bugun and hak>cekilen
  order by gun for update
 loop
   x:=least(kalan,m.hak-m.cekilen);
   update oyun.eko_ortak_gunluk_hak set cekilen=cekilen+x
   where sirket_id=p_sirket and user_id=u and gun=m.gun;
   kalan:=kalan-x;
   if kalan<=0 then exit;end if;
 end loop;
 if kalan>0 then raise exception 'Ortak kazanc haklari uyusmuyor.';end if;
 insert into oyun.eko_kar_odeme(sirket_id,user_id,gun,brut,stopaj,net,zaman)
 values(p_sirket,u,bugun,odeme,harc,net,t) returning id into id_yeni;
 x:=oyun.eko_vergi_tahsil(p_sirket,'dagitim',odeme,'gunluk_kar',id_yeni,u);
 if x<>harc then raise exception 'Stopaj tutari dogrulanamadi.';end if;
 perform oyun.para_islem(u,net,'sirket','Gunluk ticaret net kar payi',t,harc);
 insert into oyun.eko_islem_kayit(sirket_id,oyuncu,tur,tutar,aciklama)
 values(p_sirket,u,'gunluk_temettu',-odeme,format('Net %s, stopaj %s',net,harc));
 return jsonb_build_object('brut',odeme,'stopaj',harc,'net',net,'odeme',id_yeni);
end $$;
revoke all on function public.eko_gunluk_kar_cek(bigint,numeric) from public,anon;
grant execute on function public.eko_gunluk_kar_cek(bigint,numeric) to authenticated;

-- Eski toplu dagitim hak edilmis gunluk ortak paylarini eritmesin.
do $patch$
declare src text;
begin
 select pg_get_functiondef('public.sirket_kar_payi(bigint,numeric)'::regprocedure) into src;
 if position('Gunluk ticaret kar payi' in src)=0 then
  src:=replace(src, 'perform oyun.sirket_hesapla(p_sirket);',
  'if exists(select 1 from oyun.eko_isletmeler where sirket_id=p_sirket) then raise exception ''Gunluk ticaret kar payi icin Ekonomi > Vergi ve Temettu ekranini kullan.'';end if; perform oyun.sirket_hesapla(p_sirket);');
  execute src;
 end if;
end $patch$;
