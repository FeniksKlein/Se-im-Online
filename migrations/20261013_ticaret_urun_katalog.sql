-- Kapsamli ticaret: ürün kataloğu ve iş emirleri, mevcut şirket/verilere dokunmadan.
create table if not exists oyun.eko_urun_katalog(
 kod text primary key, ad text not null, grup text not null check(grup in ('gida','teknoloji','malzeme')),
 kullanim text not null check(kullanim in ('market','kahve','fastfood')),
 maliyet numeric not null check(maliyet>0), parti_ust integer not null check(parti_ust>0),
 uretim_dakika integer not null check(uretim_dakika>=15),
 onerilen_satis numeric not null check(onerilen_satis>maliyet),
 talep integer not null check(talep between 1 and 50), aktif boolean not null default true
);
insert into oyun.eko_urun_katalog(kod,ad,grup,kullanim,maliyet,parti_ust,uretim_dakika,onerilen_satis,talep)
values
('ekmek','Ekmek','gida','market',65,350,30,135,34),
('su','Şişe su','gida','market',25,500,20,60,45),
('sut','Süt','gida','market',120,200,45,260,27),
('makarna','Makarna','gida','market',85,350,40,195,35),
('cikolata','Çikolata','gida','market',170,175,50,385,20),
('icecek','Gazlı içecek','gida','market',140,250,45,320,28),
('burger_ekmegi','Burger ekmeği','gida','fastfood',110,225,45,290,30),
('burger_eti','Burger köftesi','gida','fastfood',400,95,80,950,18),
('pizza_hamuru','Pizza hamuru','gida','fastfood',220,160,65,510,21),
('tavuk','Paket tavuk','gida','fastfood',310,140,70,740,24),
('patates','Patates ürünleri','gida','fastfood',75,350,35,190,37),
('kahve_cekirdegi','Kahve çekirdeği','gida','kahve',475,145,90,1190,24),
('filtre_kahve','Filtre kahve','gida','kahve',380,160,70,920,30),
('kapsul_kahve','Kapsül kahve','gida','kahve',780,80,135,1850,15),
('premium_kahve','Özel seri kahve','gida','kahve',2600,22,240,6500,3),
('organik_cay','Özel harman çay','gida','kahve',1100,35,190,2850,7),
('kulaklik','Bluetooth kulaklık','teknoloji','market',1850,32,145,4600,8),
('akilli_saat','Akıllı saat','teknoloji','market',4300,15,210,9800,5),
('telefon','Akıllı telefon','teknoloji','market',9500,9,260,20200,3),
('konsol','Oyun konsolu','teknoloji','market',22500,5,350,48000,2),
('bilgisayar','Oyun bilgisayarı','teknoloji','market',34000,3,420,73000,1),
('cimento','Çimento','malzeme','market',235,320,40,530,27),
('seramik','Seramik','malzeme','market',490,135,75,1090,18),
('yalitim','Isı yalıtımı','malzeme','market',1275,65,155,2900,11),
('mermer','Özel mermer','malzeme','market',6600,12,320,15500,3),
('panel','Akıllı yapı paneli','malzeme','market',13600,7,395,32500,2)
on conflict(kod) do update set ad=excluded.ad,grup=excluded.grup,kullanim=excluded.kullanim,
 maliyet=excluded.maliyet,parti_ust=excluded.parti_ust,uretim_dakika=excluded.uretim_dakika,
 onerilen_satis=excluded.onerilen_satis,talep=excluded.talep;

create table if not exists oyun.eko_urun_stok(
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.eko_urun_katalog(kod),
 adet integer not null default 0 check(adet>=0),
 maliyet_birim numeric not null default 0 check(maliyet_birim>=0),
 satis_fiyati numeric not null default 0 check(satis_fiyati>=0),
 guncelleme timestamptz not null default now(),
 primary key (sirket_id,urun)
);
create table if not exists oyun.eko_uretim_emir(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.eko_urun_katalog(kod),
 adet integer not null check(adet>0), toplam_maliyet numeric not null,
 baslangic timestamptz not null default now(), hazir timestamptz not null,
 tamamlandi timestamptz
);
create index if not exists eko_uretim_hazir_idx on oyun.eko_uretim_emir(hazir) where tamamlandi is null;
create table if not exists oyun.eko_otomatik_tedarik(
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.eko_urun_katalog(kod),
 esik integer not null check(esik>=0), miktar integer not null check(miktar between 1 and 500),
 azami_birim_fiyat numeric not null check(azami_birim_fiyat>0),
 bitis timestamptz not null,
 aktif boolean not null default true,
 olusturma timestamptz not null default now(),
 primary key (sirket_id,urun)
);
create table if not exists oyun.eko_npc_satis(
 id bigint generated always as identity primary key,
 sirket_id bigint not null references oyun.sirketler(id),
 urun text not null references oyun.eko_urun_katalog(kod),
 donem timestamptz not null,
 adet integer not null check(adet>0), ciro numeric not null,
 mal_maliyeti numeric not null, personel_gideri numeric not null,
 vergi numeric not null, isim_hakki numeric not null,
 kar_paylasim numeric not null, net_kar numeric not null,
 zaman timestamptz not null default now(),
 unique(sirket_id,urun,donem)
);
create index if not exists eko_npc_satis_idx on oyun.eko_npc_satis(sirket_id,zaman desc);
alter table oyun.eko_markalar add column if not exists kategori text not null default 'market';
alter table oyun.eko_markalar add column if not exists kar_payi numeric not null default 0;
alter table oyun.eko_franchise add column if not exists kar_payi numeric not null default 0;
alter table oyun.eko_urun_katalog enable row level security;
alter table oyun.eko_urun_stok enable row level security;
alter table oyun.eko_uretim_emir enable row level security;
alter table oyun.eko_otomatik_tedarik enable row level security;
alter table oyun.eko_npc_satis enable row level security;
create or replace function oyun.eko_franchise_kopyala_pay()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
 new.kar_payi:=coalesce((select m.kar_payi from oyun.eko_markalar m where m.sirket_id=new.marka),0);
 return new;
end $$;
drop trigger if exists eko_franchise_kopyala_pay on oyun.eko_franchise;
create trigger eko_franchise_kopyala_pay before insert on oyun.eko_franchise
for each row execute function oyun.eko_franchise_kopyala_pay();
