
-- Dernek bütçesi: yedi günlük programlar, etki puanı ve gönüllü katılımı.
-- Yalnızca eklemeli değişiklikler: mevcut dernek kasalarına/bağışlarına dokunulmaz.
create table if not exists oyun.dernek_programlar (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 il_id smallint not null references oyun.iller(id),
 tur text not null check(tur in ('asevi','etut','afet','hayvanbakim','kulturmerkezi','meslek','saglik')),
 paket integer not null check (paket between 1 and 3),
 ucret numeric not null check (ucret > 0),
 hedef integer not null check (hedef > 0),
 bas timestamptz not null,
 bit timestamptz not null,
 baslatan uuid references oyun.profiller(id)
);
create index if not exists dernek_programlar_il on oyun.dernek_programlar(dernek_id,il_id,bit desc);
create table if not exists oyun.dernek_program_katilim (
 program_id bigint not null references oyun.dernek_programlar(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id),
 zaman timestamptz not null default now(),
 primary key(program_id,user_id)
);
create table if not exists oyun.dernek_etki_ozet (
 dernek_id bigint primary key references oyun.dernekler(id) on delete cascade,
 puan numeric not null default 0,
 toplam_harcama numeric not null default 0,
 erisim integer not null default 0,
 faaliyet_sayisi integer not null default 0,
 gonullu_sayisi integer not null default 0
);
create table if not exists oyun.dernek_etki_kayit (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
 il_id smallint not null references oyun.iller(id),
 kaynak text not null check (kaynak in ('proje','program')),
 kaynak_id bigint not null,
 tur text not null,
 tutar numeric not null,
 erisim integer not null,
 gelisim_etki numeric not null default 0,
 memnuniyet_etki numeric not null default 0,
 puan numeric not null default 0,
 zaman timestamptz not null default now(),
 unique(kaynak,kaynak_id)
);
create index if not exists dernek_etki_kayit_dernek on oyun.dernek_etki_kayit(dernek_id,zaman desc);
do $block$ declare n text; begin
 foreach n in array array['dernek_programlar','dernek_program_katilim','dernek_etki_ozet','dernek_etki_kayit'] loop
  execute format('alter table oyun.%I enable row level security',n);
  execute format('revoke all on oyun.%I from public, anon, authenticated',n);
 end loop;
end $block$;

-- Program fiyatı oyun ekonomisi endeksine göre sunucuda hesaplanır.
create or replace function public.dernek_program_katalog()
returns jsonb language sql stable security definer set search_path='' as $$
 with secenek(tur,ad,aciklama,temel,kisi,gel,mem) as (
 values
 ('asevi','Aşevi ve sıcak yemek','Yedi gün sıcak yemek ve gıda dağıtımı.',8000::numeric,45,0.05::numeric,0.18::numeric),
 ('etut','Ücretsiz etüt merkezi','Öğrencilere etüt, kitap ve eğitim desteği.',9000,25,0.16,0.09),
 ('afet','Afet hazırlık merkezi','Gönüllü eğitimi, stok ve afet hazırlığı.',12000,30,0.12,0.10),
 ('hayvanbakim','Hayvan bakım noktası','Sokak hayvanları için mama ve bakım.',7000,40,0.07,0.13),
 ('kulturmerkezi','Kültür ve sanat atölyesi','Halka açık sanat ve kültür etkinlikleri.',6500,35,0.10,0.12),
 ('meslek','Meslek edindirme kursu','İşsiz ve genç NPC nüfusuna meslek eğitimi.',11000,20,0.20,0.07),
 ('saglik','Koruyucu sağlık etkinliği','Temel tarama ve sağlık farkındalığı.',10000,35,0.09,0.15)
 )
 select coalesce(jsonb_agg(jsonb_build_object(
 'tur', s.tur, 'ad',s.ad,'aciklama',s.aciklama,'paket',g.paket,
 'ucret',greatest(100,round(s.temel*g.carpan * greatest(0.5,least(3,coalesce((select endeks from oyun.ulke where id=1),1))) / 100)*100),
 'hedef',round(s.kisi*g.carpan)::int,'gelisim',round(s.gel*g.carpan,3),'memnuniyet',round(s.mem*g.carpan,3)
 ) order by s.tur,g.paket),'[]'::jsonb)
 from secenek s cross join (values (1,1::numeric),(2,2.5::numeric),(3,5::numeric)) g(paket,carpan)
$$;

-- Tek bir otoritatif kayıt yolu: gerçek parayı sonsuz kez puana çevirme engeli, şehir etkisinde azalan verim.
create or replace function oyun.dernek_etki_uygula(p_dernek bigint,p_il smallint,p_kaynak text,p_kaynak_id bigint,
 p_tur text,p_tutar numeric,p_erisim integer,p_gel numeric,p_mem numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t timestamptz := oyun.simdi(); sayi integer; carpan numeric; g numeric; m numeric; skor numeric; rid bigint;
begin
 select count(*) into sayi from oyun.dernek_etki_kayit
 where dernek_id=p_dernek and il_id=p_il and zaman>t-interval '24 hours';
 carpan := 1.0/(1.0+0.5*sayi);
 g := round(least(0.8,greatest(0,coalesce(p_gel,0)))*carpan,3);
 m := round(least(0.8,greatest(0,coalesce(p_mem,0)))*carpan,3);
 skor := least(50, greatest(1,round(p_tutar/2000))) + least(10,greatest(0,round(p_erisim/25.0)));
 insert into oyun.dernek_etki_kayit(dernek_id,il_id,kaynak,kaynak_id,tur,tutar,erisim,gelisim_etki,memnuniyet_etki,puan,zaman)
 values(p_dernek,p_il,p_kaynak,p_kaynak_id,p_tur,p_tutar,p_erisim,g,m,skor,t)
 returning id into rid;
 update oyun.il_durum set gelisim=least(100,coalesce(gelisim,50)+g),
 memnuniyet=least(100,coalesce(memnuniyet,50)+m) where il_id=p_il;
 insert into oyun.dernek_etki_ozet(dernek_id,puan,toplam_harcama,erisim,faaliyet_sayisi)
 values(p_dernek,skor,p_tutar,p_erisim,1)
 on conflict(dernek_id) do update
 set puan=oyun.dernek_etki_ozet.puan+excluded.puan,
 toplam_harcama=oyun.dernek_etki_ozet.toplam_harcama+excluded.toplam_harcama,
 erisim=oyun.dernek_etki_ozet.erisim+excluded.erisim,
 faaliyet_sayisi=oyun.dernek_etki_ozet.faaliyet_sayisi+1;
 return jsonb_build_object('gelisim',g,'memnuniyet',m,'puan',skor,'kayit',rid);
end $$;
revoke execute on function oyun.dernek_etki_uygula(bigint,smallint,text,bigint,text,numeric,integer,numeric,numeric) from public,anon,authenticated;

create or replace function oyun.dernek_proje_sosyal_etki()
returns trigger language plpgsql security definer set search_path='' as $$
declare q jsonb; g numeric; m numeric; n integer;
begin
 n := least(new.adet,500);
 g := case new.tur when 'agac' then 0.0005 when 'burs' then 0.0011 when 'temizlik' then 0.0007
  when 'kultur' then 0.0008 when 'hayvan' then 0.0005 else 0.0002 end * n;
 m := case new.tur when 'gida' then 0.0015 when 'hayvan' then 0.0007 when 'kultur' then 0.0008
  when 'burs' then 0.0006 else 0.0004 end * n;
 q := oyun.dernek_etki_uygula(new.dernek_id,new.il_id,'proje',new.id,new.tur,new.tutar,new.adet,g,m);
 return new;
end $$;
drop trigger if exists dernek_proje_sosyal_etki on oyun.dernek_projeler;
create trigger dernek_proje_sosyal_etki after insert on oyun.dernek_projeler
for each row execute function oyun.dernek_proje_sosyal_etki();

create or replace function public.dernek_program_baslat(p_dernek bigint,p_tur text,p_paket integer,p_il integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
 d oyun.dernekler; f record; yeni bigint; sonuc jsonb; il_ad text;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 perform oyun.dernek_yetkili(p_dernek,p.id);
 select * into d from oyun.dernekler where id=p_dernek and not kapali for update;
 if d.id is null then raise exception 'Dernek kapalı.'; end if;
 select ad into il_ad from oyun.iller where id=p_il;
 if il_ad is null or not exists(select 1 from oyun.dernek_sube where dernek_id=d.id and il_id=p_il) then
  raise exception 'Bu şehirde şube açmadan hizmet programı başlatamazsın.';
 end if;
 select * into f from jsonb_to_recordset(public.dernek_program_katalog())
 as x(tur text,ad text,aciklama text,paket integer,ucret numeric,hedef integer,gelisim numeric,memnuniyet numeric)
 where tur=p_tur and paket=p_paket;
 if not found then raise exception 'Geçersiz hizmet/paket.'; end if;
 if (select count(*) from oyun.dernek_programlar where dernek_id=d.id and bit>t)>=4 then
  raise exception 'Aynı anda en fazla 4 aktif hizmet programı yürütülebilir.';
 end if;
 if exists(select 1 from oyun.dernek_programlar
 where dernek_id=d.id and il_id=p_il and tur=p_tur and bit>t) then
  raise exception 'Bu ilde aynı hizmet programı zaten aktif.';
 end if;
 if oyun.dernek_serbest_kasa(d.id)<f.ucret then
  raise exception 'Serbest kasa % TL, gereken % TL.',oyun.tl(oyun.dernek_serbest_kasa(d.id)),oyun.tl(f.ucret);
 end if;
 update oyun.dernekler set kasa=kasa-f.ucret where id=d.id and kasa>=f.ucret;
 if not found then raise exception 'Dernek kasası yetersiz.'; end if;
 insert into oyun.dernek_programlar(dernek_id,il_id,tur,paket,ucret,hedef,bas,bit,baslatan)
 values(d.id,p_il::smallint,p_tur,p_paket,f.ucret,f.hedef,t,t+interval '7 days',p.id) returning id into yeni;
 insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id)
 values(d.id,t,-f.ucret,'sosyal_program',format('%s · %s · 7 gün',f.ad,il_ad),p.id);
 sonuc := oyun.dernek_etki_uygula(d.id,p_il::smallint,'program',yeni,p_tur,f.ucret,f.hedef,f.gelisim,f.memnuniyet);
 perform oyun.olay('dernek',format('%s, %s ilinde %s hizmetini %s TL ile 7 günlüğüne açtı (hedef: %s kişi).',
 d.ad,il_ad,f.ad,oyun.tl(f.ucret),f.hedef),p_il::smallint,null,t);
 return jsonb_build_object('tamam',true,'id',yeni,'ucret',f.ucret,'hedef',f.hedef,'etki',sonuc);
end $$;

create or replace function public.dernek_program_katil(p_program bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.dernek_programlar; sayi integer;
begin
 if oyun.uyari(p,t) is not null then raise exception 'İşlem kısıtlandı.'; end if;
 select * into k from oyun.dernek_programlar where id=p_program for update;
 if k.id is null or t>=k.bit then raise exception 'Program sona erdi.'; end if;
 if p.il_id is distinct from k.il_id then raise exception 'Bu programa sadece aynı ilde yaşayan oyuncular katılabilir.'; end if;
 if exists (select 1 from oyun.dernek_program_katilim where program_id=k.id and user_id=p.id) then
  raise exception 'Bu programa zaten katıldın.';
 end if;
 if (select count(*) from oyun.dernek_program_katilim where program_id=k.id)>=50 then raise exception 'Gönüllü kontenjanı doldu.'; end if;
 if (select count(*) from oyun.dernek_program_katilim where user_id=p.id and zaman>=t-interval '7 days')>=3 then
  raise exception '7 günde en fazla 3 programa gönüllü katılabilirsin.';
 end if;
 insert into oyun.dernek_program_katilim(program_id,user_id,zaman) values(k.id,p.id,t);
 insert into oyun.dernek_etki_ozet(dernek_id,puan,gonullu_sayisi)
 values(k.dernek_id,1,1)
 on conflict(dernek_id) do update set puan=oyun.dernek_etki_ozet.puan+1,
  gonullu_sayisi=oyun.dernek_etki_ozet.gonullu_sayisi+1;
 select count(*) into sayi from oyun.dernek_program_katilim where program_id=k.id;
 return jsonb_build_object('tamam',true,'gonullu',sayi);
end $$;

create or replace function public.dernek_program_ozet(p_dernek bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d oyun.dernekler; u uuid := auth.uid(); t timestamptz := oyun.simdi();
begin
 select * into d from oyun.dernekler where id=p_dernek;
 if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
 return jsonb_build_object(
 'kasa',d.kasa,'serbest',oyun.dernek_serbest_kasa(d.id),
 'etki',coalesce((select to_jsonb(o) - 'dernek_id' from oyun.dernek_etki_ozet o where o.dernek_id=d.id),
 jsonb_build_object('puan',0,'toplam_harcama',0,'erisim',0,'faaliyet_sayisi',0,'gonullu_sayisi',0)),
 'programlar',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'tur',x.tur,'paket',x.paket,
 'il',i.ad,'ucret',x.ucret,'hedef',x.hedef,'bas',x.bas,'bit',x.bit,'aktif',x.bit>t,
 'gonullu',(select count(*) from oyun.dernek_program_katilim k where k.program_id=x.id),
 'katildim',exists(select 1 from oyun.dernek_program_katilim k where k.program_id=x.id and k.user_id=u),
 'benim_ilim',exists(select 1 from oyun.profiller p where p.id=u and p.il_id=x.il_id))
 order by x.bas desc)
 from (select * from oyun.dernek_programlar where dernek_id=d.id order by bas desc limit 30) x join oyun.iller i on i.id=x.il_id),'[]'::jsonb),
 'etkiler',coalesce((select jsonb_agg(jsonb_build_object('tur',x.tur,'kaynak',x.kaynak,
 'tutar',x.tutar,'il',i.ad,'erisim',x.erisim,'puan',x.puan,'gelisim',x.gelisim_etki,
 'memnuniyet',x.memnuniyet_etki,'zaman',x.zaman) order by x.zaman desc)
 from (select * from oyun.dernek_etki_kayit where dernek_id=d.id order by zaman desc limit 20) x
 join oyun.iller i on i.id=x.il_id),'[]'::jsonb)
 );
end $$;
revoke execute on function public.dernek_program_baslat(bigint,text,integer,integer) from public,anon;
revoke execute on function public.dernek_program_katil(bigint) from public,anon;
revoke execute on function public.dernek_program_katalog() from public,anon;
revoke execute on function public.dernek_program_ozet(bigint) from public,anon;
grant execute on function public.dernek_program_baslat(bigint,text,integer,integer) to authenticated;
grant execute on function public.dernek_program_katil(bigint) to authenticated;
grant execute on function public.dernek_program_katalog() to authenticated;
grant execute on function public.dernek_program_ozet(bigint) to authenticated;
