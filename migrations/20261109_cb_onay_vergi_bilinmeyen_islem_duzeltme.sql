-- Serbest kanunlarin CB onayinda NULL veri yuzunden vergi tetikleyicisine takilmasini onler.
-- Yalnizca sirket vergisi kanunlarinda vergi islemi calisir; mevcut oyuncu kayitlari korunur.
create or replace function oyun.eko_sirket_vergi_kanun_yururluk()
returns trigger language plpgsql security definer set search_path to '' as $$
declare v jsonb; k text; islem text; x numeric; eski numeric; eski_ad text; nowt timestamptz;
begin
 if new.durum<>'yururlukte' or old.durum='yururlukte'
    or (new.veri->>'ozel_tur') IS DISTINCT FROM 'sirket_vergisi'
 then return new;end if;
 v:=new.veri;k:=v->>'kod';islem:=v->>'islem';
 x:=(v->>'oran')::numeric;nowt:=coalesce(new.sonuc_at,oyun.simdi());
 if islem='yeni' then
  if exists(select 1 from oyun.eko_vergi_turleri where kod=k)
  then raise exception 'Vergi kanunu yasalasti ama kod zaten mevcut.';end if;
  insert into oyun.eko_vergi_turleri(kod,ad,matrah,oran,aktif,kaynak_kanun,guncelleme)
  values(k,v->>'ad',v->>'matrah',x,true,new.id,nowt);
 elsif islem in ('oran','kaldir') then
  select oran,ad into eski,eski_ad from oyun.eko_vergi_turleri where kod=k for update;
  if not found then raise exception 'Degistirilecek vergi kayitli degil.';end if;
  update oyun.eko_vergi_turleri
    set oran=case when islem='kaldir' then 0 else x end,
        aktif=case when islem='kaldir' then false else true end,
        kaynak_kanun=new.id,guncelleme=nowt where kod=k;
 else raise exception 'Bilinmeyen vergi kanunu islemi.';end if;
 if k='gelir' and islem='oran' then
  if x>least(45,oyun.anayasa_deger('vergi_tavani')) then
   raise exception 'Yururluge giren oran anayasa tavanini asiyor.';end if;
  update oyun.ulke set vergi=x,vergi_kanun=x,
    vergi_alt=least(vergi_alt,x),vergi_ust=greatest(vergi_ust,x) where id=1;
 end if;
 perform oyun.olay('ekonomi',format('Meclis karari: %s vergisi (%s).',
  coalesce(v->>'ad',eski_ad),islem),null,new.teklif_parti,nowt);
 return new;
end $$;
