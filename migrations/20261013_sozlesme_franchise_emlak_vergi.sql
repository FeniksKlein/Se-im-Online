-- Sozlesme, franchise isim hakki ve muteahhit daire satislarini vergi/kazanc defterine bagla.
do $patch$
declare src text;
begin
 select pg_get_functiondef('oyun.eko_kar_yaz(bigint,text,bigint,numeric,numeric,numeric,timestamp with time zone)'::regprocedure) into src;
 src:=replace(src,'''sozlesme'')','''sozlesme'',''franchise_fee'',''emlak'')');
 execute src;
end $patch$;
create or replace function oyun.eko_sozlesme_vergisi()
returns trigger language plpgsql security definer set search_path to '' as $$
declare stamp numeric; vat numeric; kurumlar numeric; matrah numeric;
begin
 if new.durum='aktif' and old.durum='teklif' then
   stamp:=oyun.eko_vergi_hesap('sozlesme',new.bedel);
   if stamp>0 then
     update oyun.sirketler set kasa=kasa-stamp
      where id=new.alici and kasa>=stamp;
     if not found then raise exception 'Sozlesme damga vergisi icin sirket kasasi yetersiz.';end if;
     perform oyun.eko_vergi_tahsil(new.alici,'sozlesme',new.bedel,'sozlesme_imza',new.id);
   end if;
 elsif new.durum='tamam' and old.durum='teslim' then
   vat:=oyun.eko_vergi_hesap('satis',new.bedel);
   matrah:=greatest(0,new.bedel-vat);
   kurumlar:=oyun.eko_vergi_hesap('kar',matrah);
   update oyun.sirketler set kasa=kasa-vat-kurumlar
    where id=new.satici and kasa>=vat+kurumlar;
   if not found then raise exception 'Sozlesme vergileri icin satici kasasi yetersiz.';end if;
   perform oyun.eko_vergi_tahsil(new.satici,'satis',new.bedel,'sozlesme_satis',new.id);
   perform oyun.eko_vergi_tahsil(new.satici,'kar',matrah,'sozlesme_kurumlar',new.id);
   perform oyun.eko_kar_yaz(new.satici,'sozlesme',new.id,new.bedel,vat+kurumlar,
    new.bedel-vat-kurumlar,oyun.simdi());
 end if;
 return new;
end $$;
drop trigger if exists eko_sozlesme_vergisi on oyun.eko_sozlesmeler;
create trigger eko_sozlesme_vergisi after update of durum on oyun.eko_sozlesmeler
for each row execute function oyun.eko_sozlesme_vergisi();

create or replace function oyun.eko_franchise_vergisi()
returns trigger language plpgsql security definer set search_path to '' as $$
declare v_stamp numeric;v_kurumlar numeric;matrah numeric;
begin
 v_stamp:=oyun.eko_vergi_hesap('sozlesme',new.isim_hakki);
 v_kurumlar:=oyun.eko_vergi_hesap('kar',new.isim_hakki);
 if v_stamp>0 then
  update oyun.sirketler set kasa=kasa-v_stamp where id=new.sube and kasa>=v_stamp;
  if not found then raise exception 'Franchise sozlesme vergisi icin sube kasasi yetersiz.';end if;
  perform oyun.eko_vergi_tahsil(new.sube,'sozlesme',new.isim_hakki,'franchise_sozlesme',new.id);
 end if;
 if v_kurumlar>0 then
  update oyun.sirketler set kasa=kasa-v_kurumlar where id=new.marka and kasa>=v_kurumlar;
  if not found then raise exception 'Franchise lisans vergisi icin marka kasasi yetersiz.';end if;
  perform oyun.eko_vergi_tahsil(new.marka,'kar',new.isim_hakki,'franchise_lisans',new.id);
 end if;
 perform oyun.eko_kar_yaz(new.marka,'franchise_fee',new.id,new.isim_hakki,
  v_kurumlar,new.isim_hakki-v_kurumlar,oyun.simdi());
 return new;
end $$;
drop trigger if exists eko_franchise_vergisi on oyun.eko_franchise;
create trigger eko_franchise_vergisi after insert on oyun.eko_franchise
for each row execute function oyun.eko_franchise_vergisi();

create or replace function oyun.eko_yapi_satis_vergisi()
returns trigger language plpgsql security definer set search_path to '' as $$
declare p oyun.eko_yapilar;ar oyun.eko_arsalar;vat numeric;corp numeric;
 maliyet numeric; kar numeric;toplam integer;
begin
 if old.sahibi is not null or new.sahibi is null then return new;end if;
 select * into p from oyun.eko_yapilar where id=new.yapi_id;
 if p.id is null then return new;end if;
 select * into ar from oyun.eko_arsalar where id=p.arsa_id;
 toplam:=greatest(1,p.daire_sayisi+p.dukkan_sayisi);
 maliyet:=round((p.maliyet+coalesce(ar.fiyat,0))/toplam,2);
 vat:=oyun.eko_vergi_hesap('satis',new.satis_fiyati);
 kar:=new.satis_fiyati-maliyet-vat;
 corp:=oyun.eko_vergi_hesap('kar',greatest(0,kar));
 update oyun.sirketler set kasa=kasa-vat-corp
 where id=p.sirket_id and kasa>=vat+corp;
 if not found then raise exception 'Muteahhit firma vergi icin yeterli kasaya sahip degil.';end if;
 perform oyun.eko_vergi_tahsil(p.sirket_id,'satis',new.satis_fiyati,'yapi_satis',new.id);
 perform oyun.eko_vergi_tahsil(p.sirket_id,'kar',greatest(0,kar),'yapi_kurumlar',new.id);
 perform oyun.eko_kar_yaz(p.sirket_id,'emlak',new.id,new.satis_fiyati,
 vat+corp,kar-corp,oyun.simdi());
 return new;
end $$;
drop trigger if exists eko_yapi_satis_vergisi on oyun.eko_bolumler;
create trigger eko_yapi_satis_vergisi after update of sahibi on oyun.eko_bolumler
for each row execute function oyun.eko_yapi_satis_vergisi();
