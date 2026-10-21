-- Kesinlesmis mahkeme musaderelerinde yatirim portfoyunden de tahsilat;
-- Hazine olcek duzeltmesi, degistirilemez tahsilat izi ve dava #19 kayit uyumu.
-- Canli sistemde daha once uygulandi. Tekrarlanabilir kurulum kaynak dosyasidir.

create table if not exists oyun.adliye_musadere_varlik (
 id bigint generated always as identity primary key,
 dava_id bigint not null references oyun.adliye_davalar(id),
 sorumlu uuid not null references oyun.profiller(id),
 kod text not null references oyun.piyasa_varlik(kod),
 miktar numeric not null check (miktar > 0),
 fiyat numeric not null check (fiyat > 0),
 tahsil_tl numeric not null check (tahsil_tl > 0),
 zaman timestamptz not null default now()
);
create index if not exists adliye_musadere_varlik_dava_idx on oyun.adliye_musadere_varlik(dava_id);
alter table oyun.adliye_musadere_varlik enable row level security;
revoke all on oyun.adliye_musadere_varlik from public, anon, authenticated;

create table if not exists oyun.adliye_karar_duzeltme (
 id bigint generated always as identity primary key,
 dava_id bigint not null references oyun.adliye_davalar(id),
 onceki_karar text not null,
 yeni_karar text not null,
 aciklama text not null,
 zaman timestamptz not null default now()
);
alter table oyun.adliye_karar_duzeltme enable row level security;
revoke all on oyun.adliye_karar_duzeltme from public, anon, authenticated;

CREATE OR REPLACE FUNCTION oyun.adliye_musadere_tahsil(p_dava bigint, t timestamp with time zone)
 RETURNS numeric
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
 a oyun.adliye_musadere; d oyun.adliye_davalar;
 kalan numeric; mevcut numeric; al numeric; toplam numeric := 0;
 r record; adet numeric;
begin
 select * into a from oyun.adliye_musadere where dava_id=p_dava for update;
 if a.dava_id is null or a.tahsil >= a.tutar then return 0; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if not d.kesin or d.durum <> 'karar' or d.karar not in ('musadere','uyari') or d.af_at is not null then return 0; end if;
 kalan := a.tutar-a.tahsil;

 if a.sirket_id is not null then
  select greatest(0,coalesce(kasa,0)) into mevcut from oyun.sirketler where id=a.sirket_id for update;
  al := least(kalan,coalesce(mevcut,0));
  if al>0 then
   update oyun.sirketler set kasa=kasa-al where id=a.sirket_id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
    values(a.sirket_id,t,-al,format('Adliye #%s: kesinlesmis musadere, Hazineye iade',p_dava));
   toplam:=toplam+al; kalan:=kalan-al;
  end if;
 end if;
 if kalan>0 then
  perform oyun.cuzdanim(a.sorumlu);
  select greatest(0,coalesce(para,0)) into mevcut from oyun.cuzdan where user_id=a.sorumlu for update;
  al:=least(kalan,coalesce(mevcut,0));
  if al>0 then
   perform oyun.para_islem(a.sorumlu,-al,'adliye',format('Adliye #%s kesinlesmis musadere: Hazineye iade',p_dava),t);
   toplam:=toplam+al; kalan:=kalan-al;
  end if;
 end if;
 if kalan>0 then
  select greatest(0,coalesce(vadesiz,0)) into mevcut from oyun.banka_musteri where user_id=a.sorumlu for update;
  al:=least(kalan,coalesce(mevcut,0));
  if al>0 then
   update oyun.banka_musteri set vadesiz=vadesiz-al where user_id=a.sorumlu;
   insert into oyun.banka_hareket(user_id,zaman,hesap,tutar,aciklama)
    values(a.sorumlu,t,'vadesiz',-al,format('Adliye #%s: Hazineye kesinlesmis musadere',p_dava));
   toplam:=toplam+al; kalan:=kalan-al;
  end if;
 end if;
 -- Bankada/nakitte bulunmayan tutar, sorumlunun yatirim portfoyunden
 -- guncel piyasa fiyatiyla ve komisyonsuz geri alinir.
 if kalan>0 then
  for r in
   select p.kod,p.miktar,p.maliyet,v.fiyat
   from oyun.piyasa_pozisyon p
   join oyun.piyasa_varlik v on v.kod=p.kod
   where p.user_id=a.sorumlu and p.miktar>0 and v.fiyat>0
   order by p.kod
   for update of p
  loop
   exit when kalan<=0;
   adet:=least(r.miktar,ceil(kalan/r.fiyat*100000000)/100000000);
   al:=least(kalan,round(adet*r.fiyat,2));
   if adet<=0 or al<=0 then continue; end if;
   update oyun.piyasa_pozisyon
    set miktar=greatest(0,miktar-adet),
        maliyet=case when miktar-adet<0.00000001 then 0
                     else round(maliyet*(miktar-adet)/miktar,2) end
    where user_id=a.sorumlu and kod=r.kod;
   insert into oyun.piyasa_islem(user_id,kod,yon,miktar,fiyat,brut,komisyon,zaman)
    values(a.sorumlu,r.kod,'sat',adet,r.fiyat,al,0,t);
   insert into oyun.adliye_musadere_varlik(dava_id,sorumlu,kod,miktar,fiyat,tahsil_tl,zaman)
    values(p_dava,a.sorumlu,r.kod,adet,r.fiyat,al,t);
   toplam:=toplam+al; kalan:=kalan-al;
  end loop;
 end if;

 if toplam>0 then
  update oyun.ulke set hazine=hazine+toplam/oyun.pazar_tl_milyar() where id=1;
  if not found then raise exception 'Hazine kaydi bulunamadi; tahsilat geri alindi.'; end if;
  update oyun.adliye_musadere
   set tahsil=tahsil+toplam,son_tahsil_at=t,
       tamam_at=case when tahsil+toplam>=tutar then t else null end
   where dava_id=p_dava;
  perform oyun.bildir(a.sorumlu,
   format('Adliye #%s: %s TL kesinlesmis musadere Hazineye aktarildi. Kalan: %s TL.',
    p_dava,toplam,kalan),t);
 end if;
 return toplam;
end $function$

revoke all on function oyun.adliye_musadere_tahsil(bigint,timestamptz) from public,anon,authenticated;

do $body$
declare onceki text;
begin
 select karar into onceki from oyun.adliye_davalar
 where id=19 and kesin and durum='karar' and tur='yolsuzluk'
   and gerekce ilike '%720.000 TL%' and gerekce ilike '%HAZİNEYE%' for update;
 if onceki='uyari' and exists(
   select 1 from oyun.adliye_musadere where dava_id=19 and tutar=720000
 ) then
  insert into oyun.adliye_karar_duzeltme(dava_id,onceki_karar,yeni_karar,aciklama)
  values(19,'uyari','musadere',
   'Mahkemenin yazili hukmunde bulunan 720.000 TL Hazineye devir kararinin kayit etiketine uyarlanmasi. Orijinal hakim oyu ve ilk karar saklanmistir.');
  update oyun.adliye_davalar set karar='musadere' where id=19;
 end if;
end $body$;

do $body$
begin
 if exists(select 1 from oyun.adliye_musadere where dava_id=19 and tahsil>=61044)
  and exists(select 1 from oyun.hesap_hareket where user_id='61e73679-9cd1-4778-9d12-c17bc8454cbd'
    and tutar=-61044 and aciklama like '%Adliye #19%')
  and not exists(select 1 from oyun.ekonomi3_kayit where kod='adliye_19_hazine_birim_telafi') then
   update oyun.ulke
      set hazine=hazine-61044+61044/oyun.pazar_tl_milyar()
    where id=1 and hazine>=61044;
   if not found then raise exception 'Hazine telafisi gerceklestirilemedi'; end if;
   insert into oyun.ekonomi3_kayit(kod,deger,zaman)
   values('adliye_19_hazine_birim_telafi',61044,now());
 end if;
end $body$;
