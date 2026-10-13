-- Dernek faaliyetleri | mevcut oyuncu ve kasa kayıtlarına dokunulmaz.
create table if not exists oyun.dernek_kampanyalar (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 tur text not null check(tur in ('agac','gida','burs','hayvan','temizlik','kultur')),
 baslik text not null check(char_length(baslik) between 5 and 100),
 aciklama text not null check(char_length(aciklama) between 10 and 1000),
 hedef numeric not null check(hedef between 1000 and 100000000),
 toplanan numeric not null default 0 check(toplanan >= 0),
 harcanan numeric not null default 0 check(harcanan >= 0 and harcanan <= toplanan),
 baslama timestamptz not null default now(), bitis timestamptz not null,
 acan uuid references oyun.profiller(id), check(toplanan <= hedef)
);
create index if not exists dernek_kampanya_dernek_idx on oyun.dernek_kampanyalar(dernek_id,baslama desc);
create table if not exists oyun.dernek_kampanya_bagislar (
 id bigint generated always as identity primary key,
 kampanya_id bigint not null references oyun.dernek_kampanyalar(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 tutar numeric not null check(tutar >= 100),
 zaman timestamptz not null default now()
);
create index if not exists dernek_kampanya_bagislar_idx on oyun.dernek_kampanya_bagislar(kampanya_id,zaman desc);
create table if not exists oyun.dernek_projeler (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 tur text not null check(tur in ('agac','gida','burs','hayvan','temizlik','kultur')),
 baslik text not null,
 il_id smallint not null references oyun.iller(id),
 adet integer not null check(adet between 1 and 5000),
 birim_fiyat numeric not null check(birim_fiyat > 0),
 tutar numeric not null check(tutar > 0),
 kampanya_id bigint references oyun.dernek_kampanyalar(id),
 yapan uuid references oyun.profiller(id),
 zaman timestamptz not null default now()
);
create index if not exists dernek_proje_dernek_idx on oyun.dernek_projeler(dernek_id,zaman desc);
create table if not exists oyun.dernek_etkinlikler (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 tur text not null check(tur in ('fidan','temizlik','gida','egitim','hayvan','kultur')),
 baslik text not null check(char_length(baslik) between 5 and 100),
 aciklama text not null check(char_length(aciklama) between 10 and 1000),
 il_id smallint not null references oyun.iller(id),
 bas timestamptz not null,
 bit timestamptz not null,
 acan uuid references oyun.profiller(id),
 zaman timestamptz not null default now()
);
create index if not exists dernek_etkinlik_idx on oyun.dernek_etkinlikler(dernek_id,bas desc);
create table if not exists oyun.dernek_gonulluler (
 etkinlik_id bigint not null references oyun.dernek_etkinlikler(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 zaman timestamptz not null default now(),
 primary key(etkinlik_id,user_id)
);
create table if not exists oyun.dernek_parti_ziyaretler (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 parti_id bigint not null references oyun.partiler(id),
 konu text not null check(char_length(konu) between 10 and 600),
 tarih timestamptz not null,
 durum text not null default 'bekliyor' check(durum in ('bekliyor','kabul','red','tamam')),
 acan uuid references oyun.profiller(id),
 yanitlayan uuid references oyun.profiller(id),
 teklif_zaman timestamptz not null default now(), yanit_zaman timestamptz, tamam_zaman timestamptz
);
create index if not exists dernek_parti_ziyaret_idx on oyun.dernek_parti_ziyaretler(dernek_id,tarih desc);
create index if not exists dernek_parti_gb_idx on oyun.dernek_parti_ziyaretler(parti_id,durum);
do $$
declare n text;
begin
 foreach n in array array['dernek_kampanyalar','dernek_kampanya_bagislar','dernek_projeler','dernek_etkinlikler','dernek_gonulluler','dernek_parti_ziyaretler'] loop
  execute format('alter table oyun.%I enable row level security',n);
  execute format('revoke all on oyun.%I from public, anon, authenticated',n);
 end loop;
end $$;

-- Amaca tahsisli bağışlar, şube veya başka bir faaliyete harcanamaz.
create or replace function oyun.dernek_serbest_kasa(p_dernek bigint)
returns numeric language sql stable set search_path = '' as $$
 select greatest(0, coalesce((select kasa from oyun.dernekler where id=p_dernek),0) -
   coalesce((select sum(toplanan-harcanan) from oyun.dernek_kampanyalar where dernek_id=p_dernek),0))
$$;
create or replace function oyun.dernek_kasa_rezerv_koru() returns trigger
language plpgsql set search_path = '' as $$
declare rezerv numeric;
begin
 select coalesce(sum(toplanan-harcanan),0) into rezerv from oyun.dernek_kampanyalar where dernek_id=new.id;
 if new.kasa < rezerv then raise exception 'Kampanya bağışları amacına tahsis edildi. Serbest kasa yetersiz.'; end if;
 return new;
end $$;
drop trigger if exists dernek_kasa_rezerv_koru on oyun.dernekler;
create trigger dernek_kasa_rezerv_koru before update of kasa on oyun.dernekler
for each row execute function oyun.dernek_kasa_rezerv_koru();

create or replace function public.dernek_kampanya_ac(p_dernek bigint,p_tur text,p_baslik text,p_aciklama text,p_hedef numeric,p_gun integer default 7)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; k bigint;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 d := oyun.dernek_yetkili(p_dernek,p.id);
 if p_tur not in ('agac','gida','burs','hayvan','temizlik','kultur') then raise exception 'Faaliyet türü geçersiz.'; end if;
 if p_gun not between 1 and 30 then raise exception 'Kampanya 1-30 gün sürebilir.'; end if;
 if coalesce(p_hedef,0) < 1000 or p_hedef > 100000000 or p_hedef <> trunc(p_hedef) then raise exception 'Hedef 1.000 - 100.000.000 TL arasında tam sayı olmalı.'; end if;
 if (select count(*) from oyun.dernek_kampanyalar where dernek_id=d.id and bitis>t and toplanan<hedef) >= 4 then
  raise exception 'Bir derneğin en fazla 4 açık kampanyası olabilir.';
 end if;
 insert into oyun.dernek_kampanyalar(dernek_id,tur,baslik,aciklama,hedef,baslama,bitis,acan)
 values(d.id,p_tur,oyun.metin_temizle(p_baslik,100),oyun.metin_temizle(p_aciklama,1000),p_hedef,t,t+make_interval(days=>p_gun),p.id)
 returning id into k;
 perform oyun.olay('dernek',format('%s yeni bir yardım kampanyası başlattı: %s (%s TL hedef).',d.ad,left(p_baslik,100),oyun.tl(p_hedef)),d.merkez_il,null,t);
 return jsonb_build_object('id',k,'tamam',true);
end $$;

create or replace function public.dernek_kampanya_bagis(p_kampanya bigint,p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.dernek_kampanyalar; d oyun.dernekler; tutar numeric := round(p_tutar);
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 if p_tutar is null or p_tutar <> trunc(p_tutar) or tutar < 100 or tutar > 100000000 then raise exception 'Bağış en az 100 TL olmalı.'; end if;
 select * into k from oyun.dernek_kampanyalar where id=p_kampanya;
 if k.id is null then raise exception 'Kampanya bulunamadı.'; end if;
 select * into d from oyun.dernekler where id=k.dernek_id and not kapali for update;
 select * into k from oyun.dernek_kampanyalar where id=p_kampanya for update;
 if d.id is null or t >= k.bitis or k.toplanan>=k.hedef then raise exception 'Kampanya artık bağış kabul etmiyor.'; end if;
 if tutar > k.hedef-k.toplanan then raise exception 'Hedefe kalan tutar % TL. Daha düşük tutar bağışla.',oyun.tl(k.hedef-k.toplanan); end if;
 perform oyun.para_islem(p.id,-tutar,'dernek',format('%s · %s kampanya bağışı',d.ad,k.baslik),t);
 update oyun.dernekler set kasa=kasa+tutar where id=d.id;
 update oyun.dernek_kampanyalar set toplanan=toplanan+tutar where id=k.id;
 insert into oyun.dernek_kampanya_bagislar(kampanya_id,user_id,tutar,zaman) values(k.id,p.id,tutar,t);
 insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id)
 values(d.id,t,tutar,'kampanya_bagis',format('%s · %s bağış yaptı (tahsisli)',k.baslik,p.kad),p.id);
 if d.baskan is not null and d.baskan<>p.id then perform oyun.bildir(d.baskan,format('%s kampanyasına %s TL bağış geldi.',k.baslik,oyun.tl(tutar)),t); end if;
 return jsonb_build_object('tamam',true,'toplanan',k.toplanan+tutar);
end $$;

-- Ormanlar sanal oyun projesidir: gerçek dünyada dikilmiş fidan iddiası değildir.
create or replace function public.dernek_proje_yap(p_dernek bigint,p_tur text,p_il integer,p_adet integer,p_baslik text,p_kampanya bigint default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler;
 k oyun.dernek_kampanyalar; il_ad text; birim numeric; toplam numeric; fidan integer := 0; yeni bigint;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 d := oyun.dernek_yetkili(p_dernek,p.id);
 -- Diğer kasa işlemleri ile aynı kilit sırası: dernek, sonra kampanya
 select * into d from oyun.dernekler where id=d.id and not kapali for update;
 select ad into il_ad from oyun.iller where id=p_il;
 if il_ad is null or not exists(select 1 from oyun.dernek_sube where dernek_id=d.id and il_id=p_il) then raise exception 'Faaliyet için o ilde dernek şubesi olmalı.'; end if;
 if p_tur not in ('agac','gida','burs','hayvan','temizlik','kultur') then raise exception 'Faaliyet türü geçersiz.'; end if;
 if p_adet is null or p_adet < 1 or p_adet > 5000 then raise exception 'Adet 1-5000 olmalı.'; end if;
 if p_tur='agac' and p_adet<50 then raise exception 'Ağaçlandırma için en az 50 fidan seç.'; end if;
 birim := greatest(100,round((case p_tur when 'agac' then 250 when 'gida' then 650 when 'burs' then 2500 when 'hayvan' then 450 when 'temizlik' then 1200 else 1800 end)
       * coalesce((select endeks from oyun.ulke where id=1),1) / 100)*100);
 toplam := birim * p_adet;
 if p_kampanya is not null then
   select * into k from oyun.dernek_kampanyalar where id=p_kampanya and dernek_id=d.id for update;
   if k.id is null or k.tur<>p_tur then raise exception 'Kampanya bu faaliyet türüne ait değil.'; end if;
   if k.toplanan-k.harcanan < toplam then raise exception 'Kampanyada henüz % TL harcanabilir bakiye var.',oyun.tl(k.toplanan-k.harcanan); end if;
   update oyun.dernek_kampanyalar set harcanan=harcanan+toplam where id=k.id;
 elsif oyun.dernek_serbest_kasa(d.id)<toplam then
   raise exception 'Serbest dernek kasasında % TL var, gereken % TL.',oyun.tl(oyun.dernek_serbest_kasa(d.id)),oyun.tl(toplam);
 end if;
 update oyun.dernekler set kasa=kasa-toplam where id=d.id and kasa>=toplam;
 if not found then raise exception 'Dernek kasasında yeterli para yok.'; end if;
 insert into oyun.dernek_projeler(dernek_id,tur,baslik,il_id,adet,birim_fiyat,tutar,kampanya_id,yapan,zaman)
 values(d.id,p_tur,coalesce(nullif(oyun.metin_temizle(p_baslik,100),''),d.ad||' sosyal projesi'),p_il,p_adet,birim,toplam,p_kampanya,p.id,t)
 returning id into yeni;
 insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id)
 values(d.id,t,-toplam,'sosyal_proje',format('%s · %s adet · %s',p_tur,p_adet,il_ad),p.id);
 perform oyun.olay('dernek',format('%s, %s ilinde %s projesi gerçekleştirdi: %s adet, %s TL.',d.ad,il_ad,
    case p_tur when 'agac' then case when p_adet>=500 then 'hatıra ormanı' else 'ağaçlandırma' end
      when 'gida' then 'gıda yardımı' when 'burs' then 'öğrenci bursu' when 'hayvan' then 'sokak hayvanları desteği'
      when 'temizlik' then 'çevre temizliği' else 'kültür etkinliği' end,p_adet,oyun.tl(toplam)),p_il::smallint,null,t);
 return jsonb_build_object('id',yeni,'tutar',toplam,'birim',birim,'adet',p_adet,'orman',p_tur='agac' and p_adet>=500);
end $$;

create or replace function public.dernek_etkinlik_ac(p_dernek bigint,p_tur text,p_baslik text,p_aciklama text,p_il integer,p_bas timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; yeni bigint;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 d := oyun.dernek_yetkili(p_dernek,p.id);
 if p_tur not in ('fidan','temizlik','gida','egitim','hayvan','kultur') then raise exception 'Geçersiz etkinlik türü.'; end if;
 if not exists(select 1 from oyun.dernek_sube where dernek_id=d.id and il_id=p_il) then raise exception 'Etkinlik için o ilde şube olmalı.'; end if;
 if p_bas is null or p_bas<t+interval '1 hour' or p_bas>t+interval '14 days' then raise exception 'Etkinlik 1 saat - 14 gün sonrasına planlanmalı.'; end if;
 if (select count(*) from oyun.dernek_etkinlikler where dernek_id=d.id and bit>t) >= 4 then raise exception 'En fazla 4 yaklaşan gönüllü etkinliği olabilir.'; end if;
 insert into oyun.dernek_etkinlikler(dernek_id,tur,baslik,aciklama,il_id,bas,bit,acan,zaman)
 values(d.id,p_tur,oyun.metin_temizle(p_baslik,100),oyun.metin_temizle(p_aciklama,1000),p_il,p_bas,p_bas+interval '2 hours',p.id,t)
 returning id into yeni;
 perform oyun.olay('dernek',format('%s gönüllü çağrısı yaptı: %s.',d.ad,left(p_baslik,100)),p_il::smallint,null,t);
 return jsonb_build_object('id',yeni,'tamam',true);
end $$;
create or replace function public.dernek_gonullu_katil(p_etkinlik bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); x oyun.dernek_etkinlikler; n integer;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 select * into x from oyun.dernek_etkinlikler where id=p_etkinlik;
 if x.id is null or x.bit<=t then raise exception 'Etkinlik sona erdi.'; end if;
 if p.il_id is distinct from x.il_id then raise exception 'Bu etkinliğe yalnız aynı ilde yaşayanlar katılabilir.'; end if;
 insert into oyun.dernek_gonulluler(etkinlik_id,user_id,zaman) values(x.id,p.id,t) on conflict do nothing;
 select count(*) into n from oyun.dernek_gonulluler where etkinlik_id=x.id;
 return jsonb_build_object('tamam',true,'gonullu',n);
end $$;
create or replace function public.dernek_ziyaret_teklif(p_dernek bigint,p_parti bigint,p_konu text,p_tarih timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; pa oyun.partiler; yeni bigint;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 d := oyun.dernek_yetkili(p_dernek,p.id);
 select * into pa from oyun.partiler where id=p_parti and not kapali;
 if pa.id is null or pa.gb is null then raise exception 'Bu partinin görüşme talebini yanıtlayacak bir genel başkanı yok.'; end if;
 if p_tarih is null or p_tarih<t+interval '1 hour' or p_tarih>t+interval '7 days' then raise exception 'Ziyaret 1 saat - 7 gün sonrasına planlanmalı.'; end if;
 if exists(select 1 from oyun.dernek_parti_ziyaretler where dernek_id=d.id and parti_id=pa.id and durum='bekliyor' and teklif_zaman>t-interval '7 days')
 then raise exception 'Bu partiye bekleyen bir ziyaret teklifi var.'; end if;
 insert into oyun.dernek_parti_ziyaretler(dernek_id,parti_id,konu,tarih,durum,acan,teklif_zaman)
 values(d.id,pa.id,oyun.metin_temizle(p_konu,600),p_tarih,'bekliyor',p.id,t) returning id into yeni;
 perform oyun.bildir(pa.gb,format('%s derneği, partine ziyaret talebinde bulundu. Dernekler > Ziyaret talepleri ekranından yanıtla.',d.ad),t);
 return jsonb_build_object('id',yeni,'tamam',true);
end $$;
create or replace function public.dernek_ziyaret_yanit(p_ziyaret bigint,p_kabul boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); z oyun.dernek_parti_ziyaretler; d oyun.dernekler; pa oyun.partiler;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 select * into z from oyun.dernek_parti_ziyaretler where id=p_ziyaret for update;
 if z.id is null or z.durum<>'bekliyor' then raise exception 'Yanıt bekleyen teklif bulunamadı.'; end if;
 select * into pa from oyun.partiler where id=z.parti_id and not kapali;
 if pa.gb is distinct from p.id then raise exception 'Ziyaret talebine yalnız partinin genel başkanı yanıt verir.'; end if;
 if t>z.tarih then raise exception 'Geçmiş tarihli ziyaret talebi yanıtlanamaz.'; end if;
 select * into d from oyun.dernekler where id=z.dernek_id;
 update oyun.dernek_parti_ziyaretler set durum=case when p_kabul then 'kabul' else 'red' end,yanitlayan=p.id,yanit_zaman=t where id=z.id;
 if d.baskan is not null then perform oyun.bildir(d.baskan,format('%s partisi %s derneğinin ziyaret talebini %s.',pa.ad,d.ad,case when p_kabul then 'kabul etti' else 'reddetti' end),t); end if;
 if p_kabul then perform oyun.olay('dernek',format('%s ile %s arasında ziyaret planlandı.',d.ad,pa.ad),d.merkez_il,pa.id,t); end if;
 return jsonb_build_object('tamam',true,'durum',case when p_kabul then 'kabul' else 'red' end);
end $$;
create or replace function public.dernek_ziyaret_tamamla(p_ziyaret bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); z oyun.dernek_parti_ziyaretler; d oyun.dernekler; pa oyun.partiler;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 select * into z from oyun.dernek_parti_ziyaretler where id=p_ziyaret for update;
 if z.id is null or z.durum<>'kabul' then raise exception 'Kabul edilmiş bir ziyaret bulunamadı.'; end if;
 if t<z.tarih or t>z.tarih+interval '48 hours' then raise exception 'Görüşme planlanan saatten itibaren 48 saat içinde tamamlanabilir.'; end if;
 select * into pa from oyun.partiler where id=z.parti_id;
 select * into d from oyun.dernekler where id=z.dernek_id;
 if pa.gb is distinct from p.id and not exists(select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=p.id and rol in ('baskan','yonetim'))
 then raise exception 'Görüşmeyi yalnız dernek yönetimi veya parti genel başkanı tamamlayabilir.'; end if;
 update oyun.dernek_parti_ziyaretler set durum='tamam',tamam_zaman=t where id=z.id;
 perform oyun.olay('dernek',format('%s derneği %s partisini ziyaret etti. Görüşme konusu: %s.',d.ad,pa.ad,z.konu),d.merkez_il,pa.id,t);
 if d.baskan is not null and d.baskan<>p.id then perform oyun.bildir(d.baskan,'Parti ziyareti tamamlandı.',t); end if;
 if pa.gb is not null and pa.gb<>p.id then perform oyun.bildir(pa.gb,'Dernek ziyareti tamamlandı.',t); end if;
 return jsonb_build_object('tamam',true);
end $$;

create or replace function public.dernek_faaliyetler(p_dernek bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare d oyun.dernekler; u uuid := auth.uid(); t timestamptz := oyun.simdi();
begin
 select * into d from oyun.dernekler where id=p_dernek;
 if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
 return jsonb_build_object(
 'id',d.id,'ad',d.ad,'kasa',d.kasa,'serbest',oyun.dernek_serbest_kasa(d.id),
 'yetkili',exists(select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=u and rol in ('baskan','yonetim')) and not d.kapali,
 'subeler',coalesce((select jsonb_agg(jsonb_build_object('id',s.il_id,'ad',i.ad) order by i.ad) from oyun.dernek_sube s join oyun.iller i on i.id=s.il_id where s.dernek_id=d.id),'[]'::jsonb),
 'kampanyalar',coalesce((select jsonb_agg(jsonb_build_object('id',k.id,'tur',k.tur,'baslik',k.baslik,'aciklama',k.aciklama,
 'hedef',k.hedef,'toplanan',k.toplanan,'harcanan',k.harcanan,'bitis',k.bitis,'acik',k.bitis>t and k.toplanan<k.hedef) order by k.baslama desc)
 from oyun.dernek_kampanyalar k where k.dernek_id=d.id),'[]'::jsonb),
 'projeler',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'tur',x.tur,'baslik',x.baslik,'il',i.ad,'adet',x.adet,
 'tutar',x.tutar,'kampanya',x.kampanya_id,'zaman',x.zaman,'orman',x.tur='agac' and x.adet>=500) order by x.zaman desc)
 from (select * from oyun.dernek_projeler where dernek_id=d.id order by zaman desc limit 30) x join oyun.iller i on i.id=x.il_id),'[]'::jsonb),
 'etkinlikler',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'tur',x.tur,'baslik',x.baslik,'aciklama',x.aciklama,
 'il',i.ad,'il_id',x.il_id,'bas',x.bas,'bit',x.bit,'katilim',(select count(*) from oyun.dernek_gonulluler g where g.etkinlik_id=x.id),
 'katildim',exists(select 1 from oyun.dernek_gonulluler g where g.etkinlik_id=x.id and g.user_id=u),
 'benim_ilim',exists(select 1 from oyun.profiller pr where pr.id=u and pr.il_id=x.il_id)) order by x.bas desc)
 from (select * from oyun.dernek_etkinlikler where dernek_id=d.id order by bas desc limit 25) x join oyun.iller i on i.id=x.il_id),'[]'::jsonb),
 'ziyaretler',coalesce((select jsonb_agg(jsonb_build_object('id',z.id,'parti',pa.ad,'parti_id',pa.id,'konu',z.konu,'tarih',z.tarih,
 'durum',z.durum,'yanitlayabilirim',pa.gb=u) order by z.teklif_zaman desc)
 from (select * from oyun.dernek_parti_ziyaretler where dernek_id=d.id and
 (durum<>'bekliyor' or exists(select 1 from oyun.dernek_uyeler du where du.dernek_id=d.id and du.user_id=u and du.rol in ('baskan','yonetim')) or exists(select 1 from oyun.partiler xx where xx.id=parti_id and xx.gb=u))
 order by teklif_zaman desc limit 30) z join oyun.partiler pa on pa.id=z.parti_id),'[]'::jsonb)
 );
end $$;
create or replace function public.dernek_ziyaret_taleplerim()
returns jsonb language sql stable security definer set search_path = '' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',z.id,'dernek',d.ad,'dernek_id',d.id,'parti',pa.ad,'parti_id',pa.id,'konu',z.konu,
 'tarih',z.tarih,'durum',z.durum) order by z.teklif_zaman desc),'[]'::jsonb)
 from oyun.dernek_parti_ziyaretler z join oyun.partiler pa on pa.id=z.parti_id join oyun.dernekler d on d.id=z.dernek_id
 where pa.gb=auth.uid() and z.teklif_zaman>oyun.simdi()-interval '30 days'
$$;
create or replace function public.dernek_kampanya_vitrin()
returns jsonb language sql stable security definer set search_path = '' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',k.id,'dernek',d.ad,'dernek_id',d.id,'tur',k.tur,'baslik',k.baslik,
 'hedef',k.hedef,'toplanan',k.toplanan,'bitis',k.bitis) order by k.baslama desc),'[]'::jsonb)
 from (select * from oyun.dernek_kampanyalar where bitis>oyun.simdi() and toplanan<hedef order by baslama desc limit 60) k
 join oyun.dernekler d on d.id=k.dernek_id where not d.kapali
$$;
do $$
declare f text;
begin
 foreach f in array array[
 'dernek_kampanya_ac(bigint,text,text,text,numeric,integer)',
 'dernek_kampanya_bagis(bigint,numeric)',
 'dernek_proje_yap(bigint,text,integer,integer,text,bigint)',
 'dernek_etkinlik_ac(bigint,text,text,text,integer,timestamptz)',
 'dernek_gonullu_katil(bigint)',
 'dernek_ziyaret_teklif(bigint,bigint,text,timestamptz)',
 'dernek_ziyaret_yanit(bigint,boolean)',
 'dernek_ziyaret_tamamla(bigint)',
 'dernek_faaliyetler(bigint)',
 'dernek_ziyaret_taleplerim()',
 'dernek_kampanya_vitrin()'
 ] loop
  execute format('revoke all on function public.%s from public,anon',f);
  execute format('grant execute on function public.%s to authenticated',f);
 end loop;
end $$;
revoke all on function oyun.dernek_serbest_kasa(bigint) from public,anon,authenticated;
revoke all on function oyun.dernek_kasa_rezerv_koru() from public,anon,authenticated;
