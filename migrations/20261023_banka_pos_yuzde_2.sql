
-- 2026-10-23: Sirket POS cihazlari ve banka %2 komisyonu. Taksit yok.
-- Mevcut kredi karti, hesap, POS ve ticaret kayitlari korunur.
create table if not exists oyun.pos_banka_ayar (
  banka_id bigint primary key references oyun.sirketler(id),
  otomatik_onay boolean not null default false,
  komisyon_oran numeric(5,2) not null default 2.00 check (komisyon_oran=2.00),
  guncelleme timestamptz not null default now()
);
create table if not exists oyun.sirket_pos (
  id bigint generated always as identity primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  banka_id bigint not null references oyun.sirketler(id),
  basvuran uuid not null references oyun.profiller(id),
  durum text not null default 'bekliyor'
    check (durum in ('bekliyor','aktif','red','kapali')),
  basvuru timestamptz not null default now(),
  karar_at timestamptz,
  unique(sirket_id,banka_id)
);
create index if not exists pos_sirket_sorgu on oyun.sirket_pos(sirket_id,durum);
create index if not exists pos_banka_sorgu on oyun.sirket_pos(banka_id,durum);
alter table oyun.pos_banka_ayar enable row level security;
alter table oyun.sirket_pos enable row level security;
revoke all on oyun.pos_banka_ayar,oyun.sirket_pos from public,anon,authenticated;
alter table oyun.kart_pos_talepleri add column if not exists pos_id bigint references oyun.sirket_pos(id);
alter table oyun.kart_pos_talepleri add column if not exists komisyon_tl numeric(18,2) not null default 0;
alter table oyun.kart_pos_talepleri add column if not exists net_tutar numeric(18,2);

create or replace function public.pos_banka_panel()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); j jsonb;
begin
 if u is null then raise exception 'Oturum acilmasi gerekiyor'; end if;
 select jsonb_build_object(
 'bankalar',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'ad',b.ad,
 'otomatik',coalesce(a.otomatik_onay,false),'komisyon',2) order by b.id)
 from oyun.sirketler b left join oyun.pos_banka_ayar a on a.banka_id=b.id
 where b.sektor='banka' and b.aktif),'[]'::jsonb),
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,
 'sektor',s.sektor) order by s.id)
 from oyun.sirketler s where s.aktif and s.sektor<>'banka' and
 (s.yonetici=u or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50))),'[]'::jsonb),
 'poslar',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'sirket_id',p.sirket_id,
 'sirket',s.ad,'banka_id',p.banka_id,'banka',b.ad,'durum',p.durum,'basvuru',p.basvuru,
 'komisyon',2,'hacim',coalesce((select sum(t.tutar) from oyun.kart_pos_talepleri t
   where t.pos_id=p.id and t.durum='odendi'),0),
 'kesilen_komisyon',coalesce((select sum(t.komisyon_tl) from oyun.kart_pos_talepleri t
   where t.pos_id=p.id and t.durum='odendi'),0)) order by p.id desc)
 from oyun.sirket_pos p join oyun.sirketler s on s.id=p.sirket_id
 join oyun.sirketler b on b.id=p.banka_id where
 (s.yonetici=u or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50))
 ),'[]'::jsonb),
 'yonetilen_bankalar',coalesce((select jsonb_agg(jsonb_build_object(
 'id',b.id,'ad',b.ad,'kasa',b.kasa,'otomatik',coalesce(a.otomatik_onay,false),
 'komisyon',2,'toplam_komisyon',coalesce((select sum(t.komisyon_tl) from oyun.kart_pos_talepleri t
 join oyun.sirket_pos p on p.id=t.pos_id
 where p.banka_id=b.id and t.durum='odendi'),0),
 'satis_hacmi',coalesce((select sum(t.tutar) from oyun.kart_pos_talepleri t
 join oyun.sirket_pos p on p.id=t.pos_id
 where p.banka_id=b.id and t.durum='odendi'),0),
 'basvurular',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'sirket_id',s.id,
 'sirket',s.ad,'durum',p.durum,'basvuru',p.basvuru) order by p.id desc)
 from oyun.sirket_pos p join oyun.sirketler s on s.id=p.sirket_id
 where p.banka_id=b.id),'[]'::jsonb)
 ) order by b.id) from oyun.sirketler b
 left join oyun.pos_banka_ayar a on a.banka_id=b.id
 where b.sektor='banka' and b.aktif and
 (b.yonetici=u or exists(select 1 from oyun.sirket_ortaklari o
 where o.sirket_id=b.id and o.user_id=u and o.pay>=50))),'[]'::jsonb)
 ) into j;
 return j;
end $$;
revoke all on function public.pos_banka_panel() from public,anon;
grant execute on function public.pos_banka_panel() to authenticated;

CREATE OR REPLACE FUNCTION public.pos_banka_otomatik(p_banka bigint, p_otomatik boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); adet integer;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if not exists(select 1 from oyun.sirketler b where b.id=p_banka and b.sektor='banka' and b.aktif
 and (b.yonetici=u or exists(select 1 from oyun.sirket_ortaklari o
 where o.sirket_id=b.id and o.user_id=u and o.pay>=50))) then
 raise exception 'Banka yonetim yetkin bulunmuyor';end if;
 insert into oyun.pos_banka_ayar(banka_id,otomatik_onay)
 values(p_banka,coalesce(p_otomatik,false))
 on conflict(banka_id) do update set otomatik_onay=excluded.otomatik_onay,guncelleme=now();
 adet:=0;
 if coalesce(p_otomatik,false) then
   with approved as (
    update oyun.sirket_pos set durum='aktif',karar_at=oyun.simdi()
    where banka_id=p_banka and durum='bekliyor'
    returning basvuran
   )
   insert into oyun.bildirimler(user_id,metin)
   select basvuran,'🏦 POS başvurun otomatik olarak onaylandı; kartlı satış yapabilirsin.'
   from approved;
   get diagnostics adet=row_count;
 end if;
 return jsonb_build_object('ok',true,'otomatik',coalesce(p_otomatik,false),'otomatik_onaylanan',adet);
end $function$;
revoke all on function public.pos_banka_otomatik(bigint,boolean) from public,anon;
grant execute on function public.pos_banka_otomatik(bigint,boolean) to authenticated;

CREATE OR REPLACE FUNCTION public.pos_basvur(p_sirket bigint, p_banka bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); b oyun.sirketler; s oyun.sirketler;
 otomatik boolean; kim bigint; d text;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into s from oyun.sirketler where id=p_sirket and aktif and sektor<>'banka' for update;
 if not found then raise exception 'Aktif sirket bulunamadi';end if;
 if s.yonetici is distinct from u and
 not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50)
 then raise exception 'Sirkette islem yetkin yok';end if;
 select * into b from oyun.sirketler where id=p_banka and sektor='banka' and aktif;
 if not found then raise exception 'Banka bulunamadi';end if;
 select coalesce(a.otomatik_onay,false) into otomatik
 from oyun.sirketler bs left join oyun.pos_banka_ayar a on a.banka_id=bs.id where bs.id=p_banka;
 d:=case when otomatik then 'aktif' else 'bekliyor' end;
 insert into oyun.sirket_pos(sirket_id,banka_id,basvuran,durum,karar_at)
 values(p_sirket,p_banka,u,d,case when otomatik then oyun.simdi() else null end)
 on conflict(sirket_id,banka_id) do update set
 durum=excluded.durum,basvuran=excluded.basvuran,basvuru=oyun.simdi(),karar_at=excluded.karar_at
 where oyun.sirket_pos.durum in ('red','kapali')
 returning id into kim;
 if kim is null then raise exception 'Bu bankada mevcut veya bekleyen POS basvurun var';end if;
 if otomatik then
  insert into oyun.bildirimler(user_id,metin)
  values(u,'✅ POS başvurun otomatik onaylandı: '||b.ad||' · komisyon %2, taksit yok.');
 else
  if b.yonetici is not null then
    insert into oyun.bildirimler(user_id,metin)
    values(b.yonetici,'🏦 '||s.ad||' şirketi POS cihazı başvurusu yaptı. Banka POS Yönetimi ekranından karar ver.');
  end if;
  insert into oyun.bildirimler(user_id,metin)
  select o.user_id,'🏦 '||s.ad||' şirketi POS cihazı başvurusu yaptı. Banka POS Yönetimi ekranından karar ver.'
  from oyun.sirket_ortaklari o where o.sirket_id=b.id and o.pay>=50
  and o.user_id is distinct from b.yonetici;
 end if;
 return jsonb_build_object('id',kim,'durum',d,'komisyon',2);
end $function$;
revoke all on function public.pos_basvur(bigint,bigint) from public,anon;
grant execute on function public.pos_basvur(bigint,bigint) to authenticated;

create or replace function public.pos_basvuru_karar(p_pos bigint,p_onay boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.sirket_pos; yeni text; isim text;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into p from oyun.sirket_pos where id=p_pos for update;
 if not found or p.durum not in ('bekliyor','aktif') then raise exception 'Islem yapilabilecek POS basvurusu bulunamadi';end if;
 if not exists(select 1 from oyun.sirketler b where b.id=p.banka_id and b.sektor='banka'
 and (b.yonetici=u or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=b.id and o.user_id=u and o.pay>=50)))
 then raise exception 'Banka yonetim yetkin yok';end if;
 yeni:=case when p_onay then 'aktif' when p.durum='aktif' then 'kapali' else 'red' end;
 update oyun.sirket_pos set durum=yeni,karar_at=oyun.simdi() where id=p_pos;
 select ad into isim from oyun.sirketler where id=p.banka_id;
 insert into oyun.bildirimler(user_id,metin) values(p.basvuran,
 format('🏦 %s POS basvurusu / cihazi: %s. Kart komisyonu %%2.',isim,yeni));
 return jsonb_build_object('ok',true,'durum',yeni);
end $$;
revoke all on function public.pos_basvuru_karar(bigint,boolean) from public,anon;
grant execute on function public.pos_basvuru_karar(bigint,boolean) to authenticated;

create or replace function public.pos_satis_talep(p_sirket bigint,p_pos bigint,p_oyuncu text,p_tutar numeric,p_aciklama text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); m uuid; s oyun.sirketler; bank oyun.sirketler; pos oyun.sirket_pos; kim bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into s from oyun.sirketler where id=p_sirket and aktif and sektor<>'banka';
 if not found then raise exception 'Aktif satis sirketi bulunamadi';end if;
 if s.yonetici is distinct from u and not exists(select 1 from oyun.sirket_ortaklari o
 where o.sirket_id=p_sirket and o.user_id=u and o.pay>=50)
 then raise exception 'Sirket yetkilisi degilsin';end if;
 select * into pos from oyun.sirket_pos where id=p_pos and sirket_id=p_sirket and durum='aktif';
 if not found then raise exception 'Sirkete ait onayli POS cihazi bulunmuyor';end if;
 select * into bank from oyun.sirketler where id=pos.banka_id and sektor='banka' and aktif;
 if not found then raise exception 'POS bankasi aktif degil';end if;
 select id into m from oyun.profiller where lower(kad)=lower(trim(p_oyuncu)) limit 1;
 if m is null then raise exception 'Musterinin oyuncu adi bulunamadi';end if;
 if m=u or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=p_sirket and o.user_id=m and o.pay>0)
 then raise exception 'Kendi sirketine kartla fon aktaramazsin';end if;
 if p_tutar is null or p_tutar<1 or p_tutar>100000000 then raise exception 'Gecersiz satis tutari';end if;
 if length(trim(coalesce(p_aciklama,'')))<4 then raise exception 'Mal/hizmet aciklamasi gerekli';end if;
 insert into oyun.kart_pos_talepleri(sirket_id,musteri,talep_eden,tutar,aciklama,pos_id)
 values(p_sirket,m,u,round(p_tutar,2),left(p_aciklama,240),pos.id) returning id into kim;
 insert into oyun.bildirimler(user_id,metin)
 values(m,format('💳 %s POS üzerinden %s TL tek çekim ödeme istiyor. Bankacılık > POS ekranından onayla.',s.ad,round(p_tutar,2)));
 return jsonb_build_object('id',kim,'durum','bekliyor','pos_bankasi',bank.ad,'komisyon',2);
end $$;
revoke all on function public.pos_satis_talep(bigint,bigint,text,numeric,text) from public,anon;
grant execute on function public.pos_satis_talep(bigint,bigint,text,numeric,text) to authenticated;

-- Eski istemciler ile uyumlu 4 parametreli POS talebi de banka POS cihazina bagli.
create or replace function public.kart_pos_talep(p_sirket bigint,p_oyuncu text,p_tutar numeric,p_aciklama text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cihaz bigint;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli';end if;
 select p.id into cihaz from oyun.sirket_pos p
 join oyun.sirketler b on b.id=p.banka_id
 where p.sirket_id=p_sirket and p.durum='aktif' and b.aktif and b.sektor='banka'
 order by p.id limit 1;
 if cihaz is null then raise exception 'POS cihazı olmadan kartli satis yapilamaz. Sirketin icin bir bankadan POS al.';end if;
 return public.pos_satis_talep(p_sirket,cihaz,p_oyuncu,p_tutar,p_aciklama);
end $$;
revoke all on function public.kart_pos_talep(bigint,text,numeric,text) from public,anon;
grant execute on function public.kart_pos_talep(bigint,text,numeric,text) to authenticated;

CREATE OR REPLACE FUNCTION public.kart_pos_yanit(p_pos bigint, p_kart bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t oyun.kart_pos_talepleri; pos oyun.sirket_pos; res jsonb;
 fee numeric(18,2); net numeric(18,2); durum text;
begin
 if auth.uid() is null then raise exception 'Oturum acilmasi gerekli';end if;
 select * into t from oyun.kart_pos_talepleri where id=p_pos
 and musteri=auth.uid() and durum='bekliyor' for update;
 if not found then raise exception 'Bekleyen POS islemin bulunamadi';end if;
 if p_kart is null then
   update oyun.kart_pos_talepleri set durum='reddedildi' where id=t.id;
   return jsonb_build_object('durum','reddedildi');
 end if;
 select * into pos from oyun.sirket_pos where id=t.pos_id and sirket_id=t.sirket_id and durum='aktif';
 if not found then raise exception 'Satici sirketin bankadan onayli POS cihazi bulunmuyor';end if;
 if not exists(select 1 from oyun.sirketler s where s.id=pos.banka_id and s.aktif and s.sektor='banka')
 then raise exception 'POS bankasi aktif degil';end if;
 -- Atomik tek cekim: kart bankasi brüt bedeli öder, %2 komisyonu POS bankasi alir.
 res:=oyun.kart_harca(p_kart,t.tutar,null,t.sirket_id,'POS #'||t.id||': '||t.aciklama);
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama,faaliyet_gelir)
 values(t.sirket_id,t.tutar,'POS #'||t.id||' kartli satis (tek cekim, brut)',t.tutar);
 fee:=round(t.tutar*0.02,2);
 net:=t.tutar-fee;
 if fee>0 then
   update oyun.sirketler set kasa=kasa-fee where id=t.sirket_id and kasa>=fee;
   if not found then raise exception 'Satici kasa mahsuplastirmasi basarisiz';end if;
   update oyun.sirketler set kasa=kasa+fee where id=pos.banka_id and aktif and sektor='banka';
   if not found then raise exception 'POS bankasi bulunamadi';end if;
   insert into oyun.sirket_hareket(sirket_id,tutar,aciklama,faaliyet_gider)
   values(t.sirket_id,-fee,'POS #'||t.id||' %2 banka komisyonu',fee);
   insert into oyun.sirket_hareket(sirket_id,tutar,aciklama,faaliyet_gelir)
   values(pos.banka_id,fee,'POS #'||t.id||' komisyon geliri (%2)',fee);
 end if;
 update oyun.kart_pos_talepleri set durum='odendi',odendi=oyun.simdi(),
 kart_id=p_kart,komisyon_tl=fee,net_tutar=net where id=t.id;
 insert into oyun.bildirimler(user_id,metin) values(t.talep_eden,
 format('✅ POS #%s tek cekim %s TL tahsil edildi; %s TL POS komisyonu, %s TL sirket kasana gecti.',t.id,t.tutar,fee,net));
 return res||jsonb_build_object('pos',t.id,'brut',t.tutar,'net',net,'komisyon',fee,'pos_banka',pos.banka_id);
end $function$;
revoke all on function public.kart_pos_yanit(bigint,bigint) from public,anon;
grant execute on function public.kart_pos_yanit(bigint,bigint) to authenticated;

CREATE OR REPLACE FUNCTION public.kart_pos_iade(p_pos bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); t oyun.kart_pos_talepleri; k oyun.kredi_kartlari;
 s oyun.sirketler; pos oyun.sirket_pos; fee numeric; gross numeric; karta numeric; wallet numeric;
begin
 if u is null then raise exception 'Oturum acik degil';end if;
 select * into t from oyun.kart_pos_talepleri where id=p_pos and durum='odendi' for update;
 if not found then raise exception 'Iade edilebilecek odenmis POS yok';end if;
 select * into s from oyun.sirketler where id=t.sirket_id and aktif for update;
 if not found or (s.yonetici is distinct from u and
 not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50))
 then raise exception 'Iade icin sirket yetkisi gerekli';end if;
 gross:=t.tutar;fee:=coalesce(t.komisyon_tl,0);
 if t.pos_id is not null then
   select * into pos from oyun.sirket_pos where id=t.pos_id;
 end if;
 if pos.id is not null and fee>0 then
   -- Banka iade sirasinda komisyonu geri verir; sirketten brut tutar cikar.
   update oyun.sirketler set kasa=kasa-fee where id=pos.banka_id and kasa>=fee;
   if not found then raise exception 'POS bankasinin komisyon iadesi icin likiditesi yetersiz';end if;
   update oyun.sirketler set kasa=kasa+fee where id=s.id;
   insert into oyun.sirket_hareket(sirket_id,tutar,aciklama,faaliyet_gider)
    values(pos.banka_id,-fee,'POS #'||t.id||' %2 komisyon iadesi',fee);
   insert into oyun.sirket_hareket(sirket_id,tutar,aciklama,faaliyet_gelir)
    values(s.id,fee,'POS #'||t.id||' komisyon geri alindi',fee);
 end if;
 update oyun.sirketler set kasa=kasa-gross where id=t.sirket_id and kasa>=gross;
 if not found then raise exception 'Satici kasasi iadeyi karsilamiyor';end if;
 select * into k from oyun.kredi_kartlari where id=t.kart_id for update;
 if not found then raise exception 'Kart hesabi bulunamadi';end if;
 karta:=least(k.borc,gross);wallet:=gross-karta;
 if k.banka_id is null then update oyun.ulke set hazine=hazine+karta where id=1;
 else update oyun.sirketler set kasa=kasa+karta where id=k.banka_id;end if;
 if wallet>0 then
   update oyun.cuzdan set para=para+wallet where user_id=k.user_id;
   if not found then raise exception 'Oyuncu cuzdani bulunamadi';end if;
 end if;
 update oyun.kredi_kartlari set borc=borc-karta,
 nakit_avans_bakiye=least(nakit_avans_bakiye,greatest(0,borc-karta)) where id=k.id;
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama,faaliyet_gelir)
 values(s.id,-gross,'POS #'||t.id||' tam kartli satis iadesi',-gross);
 update oyun.kart_pos_talepleri set durum='iade' where id=t.id;
 insert into oyun.kart_hareketler(kart_id,tur,tutar,sirket_id,aciklama)
 values(k.id,'iade',gross,s.id,'POS #'||t.id||' tek cekim satis iadesi');
 insert into oyun.bildirimler(user_id,metin)
 values(k.user_id,format('💳 POS #%s iadesi %s TL. Kart borcuna %s TL, cuzdanina %s TL.',t.id,gross,karta,wallet));
 return jsonb_build_object('ok',true,'iade',gross,'komisyon_iade',fee,'kart_borcu_azaldi',karta,'cuzdana_iade',wallet);
end $function$;
revoke all on function public.kart_pos_iade(bigint) from public,anon;
grant execute on function public.kart_pos_iade(bigint) to authenticated;
