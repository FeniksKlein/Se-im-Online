
-- Internet bankaciligi: mevcut hesaplari, kredi ve kart gecmisini koruyan ek moduller.
create table if not exists oyun.ib_vadesiz (
  banka_id bigint not null references oyun.sirketler(id),
  user_id uuid not null references oyun.profiller(id),
  bakiye numeric(18,2) not null default 0 check(bakiye>=0),
  guncelleme timestamptz not null default now(),
  primary key(banka_id,user_id)
);
create table if not exists oyun.ib_hareket (
  id bigint generated always as identity primary key,
  banka_id bigint not null references oyun.sirketler(id),
  user_id uuid not null references oyun.profiller(id),
  tutar numeric(18,2) not null,
  aciklama text not null,
  zaman timestamptz not null default now()
);
create index if not exists ib_hareket_user_idx on oyun.ib_hareket(user_id,banka_id,zaman desc);
alter table oyun.ib_vadesiz enable row level security;
alter table oyun.ib_hareket enable row level security;
revoke all on oyun.ib_vadesiz,oyun.ib_hareket from public,anon,authenticated;

create or replace function oyun.ib_hesap_kosulu() returns trigger
language plpgsql security definer set search_path='' as $$
declare b bigint; u uuid;
begin
  if TG_TABLE_NAME='kart_basvurular' then b:=NEW.banka_id; u:=NEW.user_id;
  elsif TG_TABLE_NAME='sirket_pos' then b:=NEW.banka_id; u:=NEW.basvuran;
  elsif TG_TABLE_NAME='oyb_kredi' then b:=NEW.banka_id; u:=NEW.borclu;
  elsif TG_TABLE_NAME='oyb_kredi_teklifi' then b:=NEW.banka_id; u:=NEW.user_id;
  elsif TG_TABLE_NAME='banka_mevduat' then b:=NEW.banka_id; u:=NEW.user_id;
  else return NEW;end if;
  if b is not null and (u is null or not oyun.oyb_hesap_acik(b,u)) then
     raise exception 'Bu oyuncu bankasinda islem yapmak icin once hesap acmalisin.';
  end if;
  return NEW;
end $$;
revoke all on function oyun.ib_hesap_kosulu() from public,anon,authenticated;
drop trigger if exists ib_kart_basvuru_kontrol on oyun.kart_basvurular;
create trigger ib_kart_basvuru_kontrol before insert on oyun.kart_basvurular
 for each row execute function oyun.ib_hesap_kosulu();
drop trigger if exists ib_pos_kontrol on oyun.sirket_pos;
create trigger ib_pos_kontrol before insert or update of banka_id,durum on oyun.sirket_pos
 for each row execute function oyun.ib_hesap_kosulu();
drop trigger if exists ib_kredi_kontrol on oyun.oyb_kredi;
create trigger ib_kredi_kontrol before insert on oyun.oyb_kredi
 for each row execute function oyun.ib_hesap_kosulu();
drop trigger if exists ib_kredi_teklif_kontrol on oyun.oyb_kredi_teklifi;
create trigger ib_kredi_teklif_kontrol before insert on oyun.oyb_kredi_teklifi
 for each row execute function oyun.ib_hesap_kosulu();
drop trigger if exists ib_mevduat_kontrol on oyun.banka_mevduat;
create trigger ib_mevduat_kontrol before insert on oyun.banka_mevduat
 for each row execute function oyun.ib_hesap_kosulu();

create or replace function oyun.ib_hesap_kapanis_kontrol() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if OLD.kapanis is null and NEW.kapanis is not null then
    if exists(select 1 from oyun.ib_vadesiz where banka_id=OLD.banka_id and user_id=OLD.user_id and bakiye>0) then
      raise exception 'Hesabi kapatmadan once vadesiz bakiyeni cekmelisin.';
    end if;
    if exists(select 1 from oyun.kredi_kartlari where banka_id=OLD.banka_id and user_id=OLD.user_id and (borc>0 or durum='aktif')) then
      raise exception 'Acik veya borclu kredi kartini kapatmadan banka hesabini kapatamazsin.';
    end if;
  end if;
  return NEW;
end $$;
revoke all on function oyun.ib_hesap_kapanis_kontrol() from public,anon,authenticated;
drop trigger if exists ib_hesap_kapanis_kontrol on oyun.oyb_hesap;
create trigger ib_hesap_kapanis_kontrol before update of kapanis on oyun.oyb_hesap
 for each row execute function oyun.ib_hesap_kapanis_kontrol();

create or replace function public.ib_hesap_ozet() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum acmalisin';end if;
 return jsonb_build_object(
 'bankalar',coalesce((select jsonb_agg(jsonb_build_object(
   'id',s.id,'ad',s.ad,'kasa',s.kasa,
   'hesabim',oyun.oyb_hesap_acik(s.id,u),
   'vadesiz',coalesce((select v.bakiye from oyun.ib_vadesiz v where v.user_id=u and v.banka_id=s.id),0),
   'mevduat',coalesce((select sum(m.anapara) from oyun.banka_mevduat m where m.banka_id=s.id and m.user_id=u and not m.kapandi),0),
   'kredi_borcu',coalesce((select sum(k.kalan) from oyun.oyb_kredi k where k.banka_id=s.id and k.borclu=u and k.durum in ('aktif','gecikmis')),0),
   'kart_borcu',coalesce((select sum(k.borc) from oyun.kredi_kartlari k where k.banka_id=s.id and k.user_id=u),0),
   'kart_sayisi',(select count(*) from oyun.kredi_kartlari k where k.banka_id=s.id and k.user_id=u),
   'hareketler',coalesce((select jsonb_agg(jsonb_build_object('tutar',z.tutar,'aciklama',z.aciklama,'zaman',z.zaman) order by z.zaman desc)
      from (select tutar,aciklama,zaman from oyun.ib_hareket where banka_id=s.id and user_id=u order by zaman desc limit 15) z),'[]'::jsonb)
 ) order by s.ad) from oyun.sirketler s where s.sektor='banka' and s.aktif),'[]'::jsonb),
 'devlet',jsonb_build_object(
   'hesabim',true,
   'vadesiz',coalesce((select vadesiz from oyun.banka_musteri where user_id=u),0),
   'kart_borcu',coalesce((select sum(borc) from oyun.kredi_kartlari where user_id=u and banka_id is null),0),
   'kredi_borcu',coalesce((select sum(kalan) from oyun.krediler where user_id=u and durum='aktif'),0)),
 'cuzdan',(select coalesce(cuzdan,0) from oyun.cuzdan where user_id=u)
 );
end $$;
revoke all on function public.ib_hesap_ozet() from public,anon;
grant execute on function public.ib_hesap_ozet() to authenticated;

create or replace function public.ib_vadesiz_islem(p_banka bigint,p_tutar numeric,p_islem text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); b oyun.sirketler; v numeric; t numeric:=round(p_tutar,2); tm timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if t is null or t<1 or t>10000000 then raise exception 'Islem tutari 1 - 10.000.000 TL olmali';end if;
 if p_islem not in ('yatir','cek') then raise exception 'Gecersiz islem';end if;
 select * into b from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if not found then raise exception 'Aktif banka bulunamadi';end if;
 if not oyun.oyb_hesap_acik(p_banka,u) then raise exception 'Once bu bankada hesap acmalisin';end if;
 insert into oyun.ib_vadesiz(banka_id,user_id) values(p_banka,u) on conflict do nothing;
 select bakiye into v from oyun.ib_vadesiz where banka_id=p_banka and user_id=u for update;
 if p_islem='yatir' then
   perform oyun.para_islem(u,-t,'banka','Vadesiz hesap yatirma: '||b.ad,tm);
   update oyun.sirketler set kasa=kasa+t where id=p_banka;
   update oyun.ib_vadesiz set bakiye=bakiye+t,guncelleme=tm where banka_id=p_banka and user_id=u;
   insert into oyun.ib_hareket(banka_id,user_id,tutar,aciklama,zaman) values(p_banka,u,t,'Cuzdandan vadesiz hesaba yatirma',tm);
 else
   if v<t then raise exception 'Vadesiz hesap bakiyen yetersiz';end if;
   update oyun.sirketler set kasa=kasa-t where id=p_banka and kasa>=t;
   if not found then raise exception 'Banka kasasi odemeyi karsilayamiyor';end if;
   update oyun.ib_vadesiz set bakiye=bakiye-t,guncelleme=tm where banka_id=p_banka and user_id=u;
   perform oyun.para_islem(u,t,'banka','Vadesiz hesap cekme: '||b.ad,tm);
   insert into oyun.ib_hareket(banka_id,user_id,tutar,aciklama,zaman) values(p_banka,u,-t,'Vadesiz hesaptan cuzdanima cekim',tm);
 end if;
 return jsonb_build_object('tamam',true,'bakiye',case when p_islem='yatir' then v+t else v-t end);
end $$;
revoke all on function public.ib_vadesiz_islem(bigint,numeric,text) from public,anon;
grant execute on function public.ib_vadesiz_islem(bigint,numeric,text) to authenticated;

create or replace function public.ib_havale(p_banka bigint,p_alici text,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); al uuid; t numeric:=round(p_tutar,2); v numeric; tm timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if t is null or t<1 or t>10000000 then raise exception 'Gecersiz havale tutari';end if;
 select id into al from oyun.profiller where lower(kad)=lower(trim(p_alici));
 if al is null or al=u then raise exception 'Gecerli bir baska alici sec';end if;
 if not oyun.oyb_hesap_acik(p_banka,u) or not oyun.oyb_hesap_acik(p_banka,al) then
   raise exception 'Gonderen ve alicinin ayni bankada acik hesabi olmali';end if;
 perform 1 from oyun.ib_vadesiz where banka_id=p_banka and user_id in (u,al) order by user_id for update;
 insert into oyun.ib_vadesiz(banka_id,user_id) values(p_banka,u),(p_banka,al) on conflict do nothing;
 select bakiye into v from oyun.ib_vadesiz where banka_id=p_banka and user_id=u for update;
 if v<t then raise exception 'Havale icin yeterli paran yok';end if;
 update oyun.ib_vadesiz set bakiye=bakiye-t,guncelleme=tm where banka_id=p_banka and user_id=u;
 update oyun.ib_vadesiz set bakiye=bakiye+t,guncelleme=tm where banka_id=p_banka and user_id=al;
 insert into oyun.ib_hareket(banka_id,user_id,tutar,aciklama,zaman)
 values(p_banka,u,-t,'Havale: '||p_alici,tm),(p_banka,al,t,'Gelen havale: '||oyun.kad(u),tm);
 perform oyun.bildir(al,'Banka hesabina '||oyun.kad(u)||' tarafindan '||t||' TL havale geldi',tm);
 return jsonb_build_object('tamam',true,'tutar',t);
end $$;
revoke all on function public.ib_havale(bigint,text,numeric) from public,anon;
grant execute on function public.ib_havale(bigint,text,numeric) to authenticated;

create or replace function public.ib_pos_nakit_ode(p_talep bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); tal oyun.kart_pos_talepleri; s oyun.sirketler; tm timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into tal from oyun.kart_pos_talepleri where id=p_talep and musteri=u and durum='bekliyor' for update;
 if not found then raise exception 'Onay bekleyen odeme talebin yok';end if;
 select * into s from oyun.sirketler where id=tal.sirket_id and aktif for update;
 if not found then raise exception 'Satici sirket bulunamadi';end if;
 if not exists(select 1 from oyun.sirket_pos where id=tal.pos_id and sirket_id=tal.sirket_id and durum='aktif')
 then raise exception 'Satici POS cihazi artik aktif degil';end if;
 perform oyun.para_islem(u,-tal.tutar,'ticaret','Nakit sirket alisverisi: '||s.ad,tm);
 update oyun.sirketler set kasa=kasa+tal.tutar where id=s.id;
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama,faaliyet_gelir)
 values(s.id,tal.tutar,'POS talebi #'||tal.id||' nakit satis (komisyonsuz)',tal.tutar);
 update oyun.kart_pos_talepleri set durum='odendi',odendi=tm,kart_id=null,komisyon_tl=0,net_tutar=tal.tutar where id=tal.id;
 insert into oyun.bildirimler(user_id,metin) values(tal.talep_eden,
 'Nakit satis tahsil edildi: '||s.ad||' · '||tal.tutar||' TL (POS komisyonu yok)');
 return jsonb_build_object('tamam',true,'brut',tal.tutar,'net',tal.tutar,'komisyon',0);
end $$;
revoke all on function public.ib_pos_nakit_ode(bigint) from public,anon;
grant execute on function public.ib_pos_nakit_ode(bigint) to authenticated;
