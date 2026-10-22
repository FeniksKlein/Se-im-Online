-- 2026-10-19: Altı rekabetçi şirket sektörü ve süreli ek iş sistemi.
-- Yalnızca katalog genişler; mevcut şirket, hesap, para ve seçim verileri değişmez.

insert into oyun.pazar_sektor
  (kod, ad, bakanlik, taban, esneklik, dis, sabit, kapasite, personel, min_sermaye, sira, aciklama)
values
 ('turizm','Turizm ve Otelcilik','ulastirma',155000,1.5,0.80,0.045,0.27,1.15,200000,12,
  'Otel, pansiyon ve tur işletmeciliği. Talep ilin büyüklüğüne, hizmet kalitesine ve rakiplere bağlıdır.'),
 ('lojistik','Kargo ve Lojistik','ulastirma',140000,1.6,0.65,0.043,0.28,1.00,180000,13,
  'Depo, kargo ve taşımacılık hizmetleri. Fiyat, kapasite ve personel giderlerini dengede tut.'),
 ('oto_servis','Oto Servis ve Bakım','sanayi',105000,1.8,0.60,0.040,0.26,0.85,125000,14,
  'Araç bakım, tamir ve ekspertiz hizmetleri. Uygun fiyat müşteri çeker, kalite marka kazandırır.'),
 ('danismanlik','Danışmanlık Ofisi','ticaret',110000,0.85,1.10,0.030,0.22,1.10,100000,15,
  'Mali, yönetim ve iş danışmanlığı. Kaliteli ekip ve güvenilir marka yüksek ücretleri destekler.'),
 ('e_ticaret','E-Ticaret Şirketi','ticaret',125000,2.1,0.80,0.045,0.28,0.90,140000,16,
  'İnternetten ürün satışı ve pazarlama. Fiyat rekabeti güçlüdür, yüksek reklam gideri kârı azaltabilir.'),
 ('geri_donusum','Geri Dönüşüm Tesisi','sanayi',118000,1.25,0.90,0.045,0.27,1.00,170000,17,
  'Atık toplama ve geri kazanım. Kapasite, enerji giderleri ve bölgesel taleple büyür.')
on conflict (kod) do update set ad=excluded.ad, bakanlik=excluded.bakanlik,
 taban=excluded.taban, esneklik=excluded.esneklik, dis=excluded.dis,
 sabit=excluded.sabit, kapasite=excluded.kapasite, personel=excluded.personel,
 min_sermaye=excluded.min_sermaye, sira=excluded.sira, aciklama=excluded.aciklama;

insert into oyun.sektor_yetki(sektor,bakanlik,ad) values
 ('turizm','ulastirma','Turizm ve Otelcilik'),
 ('lojistik','ulastirma','Kargo ve Lojistik'),
 ('oto_servis','sanayi','Oto Servis ve Bakım'),
 ('danismanlik','ticaret','Danışmanlık Ofisi'),
 ('e_ticaret','ticaret','E-Ticaret Şirketi'),
 ('geri_donusum','sanayi','Geri Dönüşüm Tesisi')
on conflict (sektor) do update set bakanlik=excluded.bakanlik, ad=excluded.ad;

-- Eski sektörleri, ajansı ve mevcut şirketleri koruyarak yalnızca izin listesini genişlet.
alter table oyun.sirketler drop constraint if exists sirketler_sektor_check;
alter table oyun.sirketler add constraint sirketler_sektor_check check (sektor in
 ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka',
  'ozel_okul','ozel_hastane','market','ulasim','enerji','ajans',
  'turizm','lojistik','oto_servis','danismanlik','e_ticaret','geri_donusum',
  -- 22.10.2026: NPC stoklu ticaret işletmeleri (117_belediye_npc_devir) listeye eklenmedigi icin kurulamiyordu.
  'akaryakit','yapi_market','elektronik_magaza','tekstil_magaza','mobilya_magaza','oto_galeri'));

create table if not exists oyun.ek_is_katalog(
 kod text primary key,
 ad text not null,
 simge text not null,
 aciklama text not null,
 sure_dakika integer not null check(sure_dakika between 15 and 480),
 asgari_ucret integer not null check(asgari_ucret > 0),
 azami_ucret integer not null check(azami_ucret >= asgari_ucret),
 sira smallint not null,
 aktif boolean not null default true
);
insert into oyun.ek_is_katalog(kod,ad,simge,aciklama,sure_dakika,asgari_ucret,azami_ucret,sira) values
 ('kurye','Paket Kuryeliği','🚲','Teslimat yap, iş bitince ücretini cüzdanına al.',45,550,850,1),
 ('taksi','Taksi Şoförlüğü','🚕','Şehir içinde yolcu taşı ve sefer ücretini kazan.',75,800,1200,2),
 ('ozel_ders','Özel Ders','📚','Bir öğrenciye ders ver, ders sonunda ödeme al.',90,1050,1550,3),
 ('tasarim','Serbest Tasarım','🎨','Bir işletme için afiş ve tasarım işi tamamla.',120,1250,1850,4),
 ('tamirat','Ev ve Cihaz Tamiri','🛠️','Küçük bakım ve onarım işini bitir.',90,950,1450,5),
 ('fotograf','Etkinlik Fotoğrafçılığı','📷','Bir etkinliğin çekimini tamamla ve ücret kazan.',60,650,1050,6)
on conflict (kod) do update set ad=excluded.ad, simge=excluded.simge,
 aciklama=excluded.aciklama, sure_dakika=excluded.sure_dakika,
 asgari_ucret=excluded.asgari_ucret, azami_ucret=excluded.azami_ucret,
 sira=excluded.sira;

create table if not exists oyun.ek_is_kayit(
 id bigint generated always as identity primary key,
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 tur text not null references oyun.ek_is_katalog(kod),
 baslama timestamptz not null,
 bitis timestamptz not null check(bitis > baslama),
 gun date not null,
 ucret integer not null check(ucret > 0),
 odendi_at timestamptz
);
create unique index if not exists ek_is_tek_aktif on oyun.ek_is_kayit(user_id) where odendi_at is null;
create index if not exists ek_is_gunluk on oyun.ek_is_kayit(user_id,gun,baslama desc);

alter table oyun.ek_is_katalog enable row level security;
alter table oyun.ek_is_kayit enable row level security;
revoke all on oyun.ek_is_katalog,oyun.ek_is_kayit from public,anon,authenticated;

-- Listeleme yalnız giriş yapmış oyuncuya; başkasının işleri görülemez.
create or replace function public.ek_is_paneli() returns jsonb
language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller := oyun.profilim(); t timestamptz := now();
 g date := (t at time zone 'Europe/Istanbul')::date;
begin
 return jsonb_build_object(
  'gunluk_limit',3,
  'bugun_yapilan',(select count(*) from oyun.ek_is_kayit where user_id=p.id and gun=g),
  'bugun_kazanilan',coalesce((select sum(ucret) from oyun.ek_is_kayit where user_id=p.id and gun=g and odendi_at is not null),0),
  'simdi',t,
  'isler',coalesce((select jsonb_agg(jsonb_build_object(
    'kod',kod,'ad',ad,'simge',simge,'aciklama',aciklama,'sure_dakika',sure_dakika,
    'asgari_ucret',asgari_ucret,'azami_ucret',azami_ucret) order by sira)
    from oyun.ek_is_katalog where aktif),'[]'::jsonb),
  'aktif',(select jsonb_build_object('id',k.id,'tur',k.tur,'ad',c.ad,'simge',c.simge,
    'baslama',k.baslama,'bitis',k.bitis,'ucret',k.ucret)
    from oyun.ek_is_kayit k join oyun.ek_is_katalog c on c.kod=k.tur
    where k.user_id=p.id and k.odendi_at is null limit 1),
  'gecmis',coalesce((select jsonb_agg(to_jsonb(x) order by x.odendi_at desc) from
    (select k.id,c.ad,c.simge,k.ucret,k.odendi_at from oyun.ek_is_kayit k
     join oyun.ek_is_katalog c on c.kod=k.tur
     where k.user_id=p.id and k.odendi_at is not null order by k.odendi_at desc limit 10) x),'[]'::jsonb)
 );
end $fn$;

-- İş başlatma yarış koşullarında bile aynı oyuncunun tek işi ve günde üç hakkı olur.
create or replace function public.ek_is_baslat(p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller := oyun.profilim(); c oyun.ek_is_katalog;
 t timestamptz := now(); g date := (t at time zone 'Europe/Istanbul')::date;
 v_id bigint; v_ucret integer;
begin
 perform 1 from oyun.profiller where id=p.id for update;
 select * into c from oyun.ek_is_katalog where kod=p_tur and aktif;
 if c.kod is null then raise exception 'Bu ek iş mevcut değil.'; end if;
 if exists(select 1 from oyun.ek_is_kayit where user_id=p.id and odendi_at is null) then
  raise exception 'Önce devam eden ek işinin süresinin dolmasını bekleyip ücretini al.';
 end if;
 if (select count(*) from oyun.ek_is_kayit where user_id=p.id and gun=g) >= 3 then
  raise exception 'Bugünkü 3 ek iş hakkını doldurdun. Gece yarısı yeniden deneyebilirsin.';
 end if;
 v_ucret:=c.asgari_ucret+floor(random()*(c.azami_ucret-c.asgari_ucret+1))::int;
 insert into oyun.ek_is_kayit(user_id,tur,baslama,bitis,gun,ucret)
 values(p.id,c.kod,t,t+c.sure_dakika*interval '1 minute',g,v_ucret) returning id into v_id;
 return jsonb_build_object('id',v_id,'tur',c.kod,'bitis',t+c.sure_dakika*interval '1 minute','ucret',v_ucret);
end $fn$;

-- Ödeme yalnız sunucuda, tek transaction ve tek sefer: iki cihaz aynı ücreti alamaz.
create or replace function public.ek_is_ucret_al(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller := oyun.profilim(); k oyun.ek_is_kayit; t timestamptz := now(); ad text;
begin
 perform 1 from oyun.profiller where id=p.id for update;
 select * into k from oyun.ek_is_kayit where id=p_id and user_id=p.id for update;
 if k.id is null then raise exception 'Ek iş kaydı bulunamadı.'; end if;
 if k.odendi_at is not null then raise exception 'Bu ek işin ücreti daha önce ödendi.'; end if;
 if t < k.bitis then raise exception 'İş henüz bitmedi. Bitiş saatini beklemelisin.'; end if;
 update oyun.ek_is_kayit set odendi_at=t where id=k.id;
 select c.ad into ad from oyun.ek_is_katalog c where c.kod=k.tur;
 perform oyun.para_islem(p.id,k.ucret,'ek_is',ad||' ek iş ücreti',t);
 return jsonb_build_object('id',k.id,'ucret',k.ucret,'odendi_at',t);
end $fn$;

revoke all on function public.ek_is_paneli(),public.ek_is_baslat(text),public.ek_is_ucret_al(bigint) from public,anon;
grant execute on function public.ek_is_paneli(),public.ek_is_baslat(text),public.ek_is_ucret_al(bigint) to authenticated;
