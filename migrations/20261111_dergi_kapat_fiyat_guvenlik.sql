-- 194 / 2026-11-11: Kapatma hakki, 1000 TL azami sayi ucreti, kazanc cekme engeli.
-- Mevcut dergi/sayi/satin alma kayitlari korunur. Kapatilan derginin eski alicilari okumaya devam eder.
-- Sadece dergi tablolarinin yeni limitini ve dergi RPC'lerini degistirir.
ALTER TABLE oyun.karikatur_sayi DROP CONSTRAINT IF EXISTS karikatur_sayi_fiyat_check;
ALTER TABLE oyun.karikatur_sayi ADD CONSTRAINT karikatur_sayi_fiyat_check CHECK (fiyat BETWEEN 1 AND 1000 AND fiyat=trunc(fiyat));

create or replace function public.dergi_raf()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); sonuc jsonb;
begin
 if u is null then raise exception 'Oturum acman gerekiyor.'; end if;
 select jsonb_build_object(
  'kurulus_ucreti', oyun.gazete_kur_ucreti(),
  'azami_sayi_fiyat', 1000,
  'benim', (select jsonb_build_object('id',d.id,'ad',d.ad,'slogan',d.slogan,'kasa',d.kasa,
    'toplam_satis',(select coalesce(sum(s.satis),0) from oyun.karikatur_sayi s where s.dergi_id=d.id))
    from oyun.karikatur_dergi d where d.sahip=u and d.aktif limit 1),
  'dergiler', coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'ad',d.ad,'slogan',d.slogan,
    'sahip',coalesce(p.kad,'Oyuncu'),
    'sayi_sayisi',(select count(*) from oyun.karikatur_sayi s where s.dergi_id=d.id),
    'son_sayi',(select max(no) from oyun.karikatur_sayi s where s.dergi_id=d.id))
    order by d.kurulus desc) from oyun.karikatur_dergi d
    left join oyun.profiller p on p.id=d.sahip where d.aktif or d.sahip=u or exists(select 1 from oyun.karikatur_satin_alma own where own.sayi_id=s.id and own.user_id=u)),'[]'::jsonb),
  'sayilar', coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'dergi_id',d.id,'dergi',d.ad,'no',s.no,'baslik',s.baslik,'fiyat',s.fiyat,
    'sablon',s.sayfalar->0->>'sablon',
    'sayfa_sayisi',jsonb_array_length(s.sayfalar),'yayin',s.yayin,'satis',s.satis,
    'sahibim',d.sahip=u,'satin_aldim',exists(select 1 from oyun.karikatur_satin_alma x where x.sayi_id=s.id and x.user_id=u)
    ) order by s.yayin desc)
    from oyun.karikatur_sayi s join oyun.karikatur_dergi d on d.id=s.dergi_id where d.aktif),'[]'::jsonb)
 ) into sonuc;
 return sonuc;
end; $f$;

create or replace function public.dergi_sayi_yayinla(p_dergi bigint,p_baslik text,p_fiyat numeric,p_sayfalar jsonb)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare
  u uuid := auth.uid();
  d oyun.karikatur_dergi;
  item jsonb;
  n integer;
  sid bigint;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into d from oyun.karikatur_dergi where id=p_dergi and aktif for update;
  if d.id is null or d.sahip is distinct from u then raise exception 'Bu dergiyi yayinlama yetkin yok.'; end if;
  p_baslik := btrim(coalesce(p_baslik,''));
  if length(p_baslik)<4 or length(p_baslik)>90 then raise exception 'Sayi basligi 4-90 karakter olmali.'; end if;
  if p_fiyat is null or p_fiyat<>trunc(p_fiyat) or p_fiyat<1 or p_fiyat>1000 then
    raise exception 'Sayi fiyati 1-1000 TL arasinda tam sayi olmali.';
  end if;
  if p_sayfalar is null or jsonb_typeof(p_sayfalar) <> 'array' then
    raise exception 'Gecerli sayfalar gerekli.';
  end if;
  if jsonb_array_length(p_sayfalar)<1 or jsonb_array_length(p_sayfalar)>4 or length(p_sayfalar::text)>9000 then
    raise exception 'Bir sayida 1-4 karikatur olabilir.';
  end if;
  for item in select value from jsonb_array_elements(p_sayfalar) loop
    if jsonb_typeof(item) <> 'object' then raise exception 'Sayfa yapisi gecersiz.'; end if;
    if coalesce(item->>'sablon','') not in ('meclis','tv','eylem','adliye','kapak') then
      raise exception 'Gecerli bir sablon sec.';
    end if;
    if length(coalesce(item->>'baslik',''))>90
      or length(coalesce(item->>'sol',''))>200
      or length(coalesce(item->>'sag',''))>200
      or length(coalesce(item->>'orta',''))>200
      or length(coalesce(item->>'karakter1',''))>45
      or length(coalesce(item->>'karakter2',''))>45
      or length(coalesce(item->>'karakter3',''))>45 then
      raise exception 'Karikatur metinleri cok uzun.';
    end if;
  end loop;
  select coalesce(max(no),0)+1 into n from oyun.karikatur_sayi where dergi_id=d.id;
  insert into oyun.karikatur_sayi(dergi_id,no,baslik,fiyat,sayfalar,yayin)
    values(d.id,n,p_baslik,p_fiyat,p_sayfalar,oyun.simdi()) returning id into sid;
  return jsonb_build_object('id',sid,'no',n,'dergi',d.ad,'fiyat',p_fiyat);
end;
$f$;

create or replace function public.dergi_sayi_detay(p_sayi bigint)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); s oyun.karikatur_sayi; d oyun.karikatur_dergi; var boolean;
begin
 if u is null then raise exception 'Oturum gerekli.';end if;
 select * into s from oyun.karikatur_sayi where id=p_sayi;
 select * into d from oyun.karikatur_dergi where id=s.dergi_id;
 if d.id is null then raise exception 'Dergi sayisi bulunamadi.';end if;
 if not d.aktif and d.sahip is distinct from u and not exists(select 1 from oyun.karikatur_satin_alma x where x.sayi_id=s.id and x.user_id=u) then
  raise exception 'Bu dergi kapatildi. Sadece daha once satin alan oyuncular okuyabilir.';
 end if;
 var:=d.sahip=u or exists(select 1 from oyun.karikatur_satin_alma where sayi_id=s.id and user_id=u);
 return jsonb_build_object('id',s.id,'dergi_id',d.id,'dergi',d.ad,'no',s.no,'baslik',s.baslik,
   'fiyat',s.fiyat,'yayin',s.yayin,'satis',s.satis,'erisim',var,'sahibim',d.sahip=u,
   'sayfa_sayisi',jsonb_array_length(s.sayfalar),'sayfalar',case when var then s.sayfalar else null end);
end; $f$;

create or replace function public.dergi_sayi_satinal(p_sayi bigint)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); s oyun.karikatur_sayi; d oyun.karikatur_dergi; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Oyuncu profili gerekli.';end if;
 select * into s from oyun.karikatur_sayi where id=p_sayi for update;
 select * into d from oyun.karikatur_dergi where id=s.dergi_id and aktif for update;
 if d.id is null then raise exception 'Bu dergi kapatildi; yeni satin alma yapilamaz.';end if;
 if s.fiyat < 1 or s.fiyat > 1000 then raise exception 'Dergi sayi fiyat siniri 1000 TL.';end if;
 if d.sahip=u then return public.dergi_sayi_detay(s.id);end if;
 if exists(select 1 from oyun.karikatur_satin_alma where sayi_id=s.id and user_id=u) then
  return public.dergi_sayi_detay(s.id);
 end if;
 perform oyun.para_islem(u,-s.fiyat,'dergi_satin_al',format('%s - %s. sayi',d.ad,s.no),t);
 insert into oyun.karikatur_satin_alma(sayi_id,user_id,zaman,tutar) values(s.id,u,t,s.fiyat);
 update oyun.karikatur_dergi set kasa=kasa+s.fiyat where id=d.id;
 update oyun.karikatur_sayi set satis=satis+1 where id=s.id;
 return public.dergi_sayi_detay(s.id);
end; $f$;

create or replace function public.dergi_kapat(p_dergi bigint)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare
 u uuid:=auth.uid();
 d oyun.karikatur_dergi;
begin
 if u is null then raise exception 'Oturum acmalisin.';end if;
 select * into d from oyun.karikatur_dergi where id=p_dergi for update;
 if d.id is null then raise exception 'Dergi bulunamadi.';end if;
 if d.sahip is distinct from u then raise exception 'Dergiyi sadece sahibi kapatabilir.';end if;
 if not d.aktif then return jsonb_build_object('kapandi',true,'id',d.id,'zaten_kapali',true);end if;
 update oyun.karikatur_dergi set aktif=false where id=d.id;
 return jsonb_build_object('kapandi',true,'id',d.id,'ad',d.ad);
end; $f$;

-- Onceki istemci RPC'si dogrudan cagrilsa bile tek kurus aktarilmasin.
create or replace function public.dergi_kazanc_cek(p_dergi bigint,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='' as $f$
begin
 raise exception 'Karikatur dergisi satis gelirleri cekilemez veya baska oyuncuya aktarilamaz.';
end; $f$;
revoke all on function public.dergi_kazanc_cek(bigint,numeric) from public,anon,authenticated;
revoke all on function public.dergi_kapat(bigint) from public,anon,authenticated;
grant execute on function public.dergi_kapat(bigint) to authenticated;
