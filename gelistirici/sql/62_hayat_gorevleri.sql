-- 2026-10-10: Görev kataloğu ve doğrulanmış oyun para ödülleri
-- Görevler yalnızca oyun sunucusundaki kayıtlarla tamamlanabilir.
create table if not exists oyun.gorev_ayar(
 id integer primary key check (id=1),
 baslangic timestamptz not null default now()
);
insert into oyun.gorev_ayar(id) values(1) on conflict(id) do nothing;
create table if not exists oyun.gorev_katalog(
 id bigint generated always as identity primary key,
 kod text not null unique,
 kategori text not null,
 baslik text not null,
 aciklama text not null,
 metrik text not null,
 hedef integer not null check(hedef>0),
 odul integer not null check(odul between 50 and 3000),
 donem text not null check(donem in ('tek','gunluk','haftalik')),
 seviye smallint not null default 0,
 rota text not null,
 aktif boolean not null default true
);
create table if not exists oyun.gorev_oduller(
 id bigint generated always as identity primary key,
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 gorev_id bigint not null references oyun.gorev_katalog(id),
 donem_anahtari text not null,
 odul integer not null check(odul>=0),
 zaman timestamptz not null default now(),
 unique(user_id,gorev_id,donem_anahtari)
);
create index if not exists gorev_oduller_user_zaman on oyun.gorev_oduller(user_id,zaman desc);
do $$ declare n text;begin
 foreach n in array array['gorev_ayar','gorev_katalog','gorev_oduller'] loop
  execute format('alter table oyun.%I enable row level security',n);
  execute format('revoke all on oyun.%I from public,anon,authenticated',n);
 end loop;
end $$;

create or replace function oyun.gorev_istatistik(p_user uuid,p_bas timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object(
  'sohbet_gun', coalesce((select count(distinct (m.zaman at time zone 'Europe/Istanbul')::date) from oyun.mesajlar m where m.user_id=p_user and m.zaman>=p_bas and not m.gizli and m.kanal not like 'dernek:%' and m.kanal not like 'ozel:%' and char_length(m.metin)>=15),0),
  'sohbet_mesaj', coalesce((select count(*) from oyun.mesajlar m where m.user_id=p_user and m.zaman>=p_bas and not m.gizli and m.kanal not like 'dernek:%' and m.kanal not like 'ozel:%' and char_length(m.metin)>=30),0),
  'sohbet_kanal', coalesce((select count(distinct m.kanal) from oyun.mesajlar m where m.user_id=p_user and m.zaman>=p_bas and not m.gizli and m.kanal not like 'dernek:%' and m.kanal not like 'ozel:%' and char_length(m.metin)>=15),0),
  'dernek_sohbet_gun', coalesce((select count(distinct (m.zaman at time zone 'Europe/Istanbul')::date) from oyun.mesajlar m where m.user_id=p_user and m.zaman>=p_bas and not m.gizli and m.kanal like 'dernek:%' and char_length(m.metin)>=15),0),
  'dernek_sohbet_yazi', coalesce((select count(*) from oyun.mesajlar m where m.user_id=p_user and m.zaman>=p_bas and not m.gizli and m.kanal like 'dernek:%' and char_length(m.metin)>=30),0),
  'secim_oy', coalesce((select count(*) from oyun.oylar o where o.secmen=p_user and o.zaman>=p_bas),0),
  'secim_turleri', coalesce((select count(distinct s.tur) from oyun.oylar o join oyun.secimler s on s.id=o.secim_id where o.secmen=p_user and o.zaman>=p_bas),0),
  'aday_ol', coalesce((select count(*) from oyun.adaylar a where a.user_id=p_user and a.basvuru_at>=p_bas),0),
  'miting_katil', coalesce((select count(*) from oyun.miting_katilim x where x.user_id=p_user and x.zaman>=p_bas),0),
  'miting_il', coalesce((select count(distinct m.il_id) from oyun.miting_katilim x join oyun.mitingler m on m.id=x.miting_id where x.user_id=p_user and x.zaman>=p_bas),0),
  'miting_konus', coalesce((select count(*) from oyun.miting_konusma k where k.user_id=p_user and k.zaman>=p_bas and not k.silindi and char_length(k.metin)>=30),0),
  'miting_konus_gun', coalesce((select count(distinct (k.zaman at time zone 'Europe/Istanbul')::date) from oyun.miting_konusma k where k.user_id=p_user and k.zaman>=p_bas and not k.silindi and char_length(k.metin)>=30),0),
  'miting_duzen', coalesce((select count(*) from oyun.mitingler m where m.user_id=p_user and m.olusturma>=p_bas),0),
  'gazete_haber', coalesce((select count(*) from oyun.gazete_yayinlari y where y.yazar=p_user and y.zaman>=p_bas and y.tur='haber' and char_length(y.metin)>=50),0),
  'gazete_kose', coalesce((select count(*) from oyun.gazete_yayinlari y where y.yazar=p_user and y.zaman>=p_bas and y.tur='kose' and char_length(y.metin)>=50),0),
  'gazete_yayin_gun', coalesce((select count(distinct (y.zaman at time zone 'Europe/Istanbul')::date) from oyun.gazete_yayinlari y where y.yazar=p_user and y.zaman>=p_bas and char_length(y.metin)>=50),0),
  'gazete_yorum', coalesce((select count(distinct k.yayin_id) from oyun.gazete_kose_yorum k where k.user_id=p_user and k.zaman>=p_bas and not k.silindi and char_length(k.metin)>=15),0),
  'gazeteler_yayin', coalesce((select count(distinct y.gazete_id) from oyun.gazete_yayinlari y where y.yazar=p_user and y.zaman>=p_bas and char_length(y.metin)>=50),0),
  'roportaj_davet', coalesce((select count(*) from oyun.sos_roportaj r where r.gazeteci=p_user and r.acilis>=p_bas and r.konuk<>p_user),0),
  'roportaj_yayin', coalesce((select count(*) from oyun.sos_roportaj r join oyun.gazete_yayinlari y on y.id=r.yayin_id where r.gazeteci=p_user and r.durum='yayinlandi' and y.zaman>=p_bas),0),
  'roportaj_cevap', coalesce((select count(*) from oyun.sos_roportaj r where r.konuk=p_user and r.yanit_at>=p_bas and r.yanit is not null),0),
  'haber_cevap', coalesce((select count(*) from oyun.sos_haber_cevap h where h.oyuncu_id=p_user and h.zaman>=p_bas and h.metin is not null),0),
  'duello_davet', coalesce((select count(*) from oyun.sos_duello d where d.davet_eden=p_user and d.olusturma>=p_bas),0),
  'duello_konus', coalesce((select count(*) from oyun.sos_duello_soz s where s.konusan=p_user and s.zaman>=p_bas and char_length(s.metin)>=20),0),
  'duello_oy', coalesce((select count(*) from oyun.sos_duello_oy o where o.user_id=p_user and o.zaman>=p_bas),0),
  'duello_tamam', coalesce((select count(*) from oyun.sos_duello d where (d.davet_eden=p_user or d.davet_edilen=p_user) and d.durum='bitti' and d.bitti_at>=p_bas),0),
  'imza_baslat', coalesce((select count(*) from oyun.sos_imza_kamp c where c.acan=p_user and c.bas>=p_bas),0),
  'imza_kat', coalesce((select count(*) from oyun.sos_imza i join oyun.sos_imza_kamp c on c.id=i.kampanya_id where i.user_id=p_user and c.acan<>p_user and i.zaman>=p_bas),0),
  'imza_basari', coalesce((select count(*) from oyun.sos_imza_kamp c where c.acan=p_user and c.durum='basarili' and c.bas>=p_bas),0),
  'dilekce_gonder', coalesce((select count(*) from oyun.sos_dilekce d where d.gonderen=p_user and d.olusturma>=p_bas and d.imza_kamp_id is null),0),
  'dilekce_yanit', coalesce((select count(*) from oyun.sos_dilekce d where d.muhatap=p_user and d.cevap_at>=p_bas and d.cevap is not null),0),
  'dernek_uye', coalesce((select count(distinct x.dernek_id) from oyun.dernek_uyeler x where x.user_id=p_user and x.katilim>=p_bas),0),
  'dernek_eylem', coalesce((select count(*) from oyun.dernek_eylem x where x.yazan=p_user and x.zaman>=p_bas and not x.silindi),0),
  'dernek_eylem_tur', coalesce((select count(distinct x.tur) from oyun.dernek_eylem x where x.yazan=p_user and x.zaman>=p_bas and not x.silindi),0),
  'dernek_protesto_katil', coalesce((select count(*) from oyun.dernek_protesto_katilim x join oyun.dernek_eylem e on e.id=x.eylem_id where x.user_id=p_user and x.zaman>=p_bas and not e.silindi),0),
  'dernek_sube', coalesce((select count(*) from oyun.dernek_sube x where x.kuran=p_user and x.kurulus>=p_bas),0),
  'dernek_secim_oy', coalesce((select count(distinct x.secim_id) from oyun.sos_dernek_oy x join oyun.sos_dernek_secim s on s.id=x.secim_id where x.user_id=p_user and s.bas>=p_bas),0),
  'parti_kurultay_imza', coalesce((select count(*) from oyun.sos_parti_imzaci x join oyun.sos_parti_imza k on k.id=x.kampanya_id where x.user_id=p_user and k.bas>=p_bas),0),
  'sirket_kur', coalesce((select count(*) from oyun.sirketler s where s.kurucu=p_user and s.kurulus>=p_bas),0),
  'sirket_ortak', coalesce((select count(*) from oyun.sirket_ortaklari x where x.user_id=p_user),0),
  'emlak_sahip', coalesce((select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user),0),
  'emlak_il', coalesce((select count(distinct x.il_id) from oyun.yatirim_mulkleri x where x.user_id=p_user),0),
  'kanun_teklif', coalesce((select count(*) from oyun.kanunlar k where k.teklif_eden=p_user and k.teklif_at>=p_bas),0),
  'kanun_oy', coalesce((select count(*) from oyun.kanun_oylari k where k.vekil=p_user and k.zaman>=p_bas),0),
  'bakan_soru', coalesce((select count(*) from oyun.bakan_soru s where s.soran=p_user and s.zaman>=p_bas),0),
  'bakan_yanit', coalesce((select count(*) from oyun.bakan_soru s where s.yanitlayan=p_user and s.yanit_at>=p_bas),0),
  'anket_oy', coalesce((select count(*) from oyun.haftalik_anket_oy a where a.user_id=p_user and a.zaman>=p_bas),0),
  'parti_tuzuk_oy', coalesce((select count(*) from oyun.parti_tuzuk_oylari v where v.user_id=p_user and v.zaman>=p_bas),0),
  'yayin_yap', coalesce((select count(*) from oyun.yayinlar y where y.gonderen=p_user and y.zaman>=p_bas and not y.gizli and char_length(y.metin)>=30),0),
  'gazete_kur', coalesce((select count(*) from oyun.oyuncu_gazeteleri g where g.sahip=p_user and g.kurulus>=p_bas),0)
 );
$$;
revoke all on function oyun.gorev_istatistik(uuid,timestamptz) from public,anon,authenticated;

create or replace function public.gorevlerim()
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
 bas timestamptz; d_bas timestamptz; w_bas timestamptz;
 bir jsonb; gun jsonb; hafta jsonb;
 gun_k text; hafta_k text; toplam numeric;
begin
 select baslangic into bas from oyun.gorev_ayar where id=1;
 d_bas:=date_trunc('day',t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
 w_bas:=date_trunc('week',t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
 gun_k:=to_char(t at time zone 'Europe/Istanbul','YYYY-MM-DD');
 hafta_k:=to_char(t at time zone 'Europe/Istanbul','IYYY-"W"IW');
 bir:=oyun.gorev_istatistik(p.id,bas);
 gun:=oyun.gorev_istatistik(p.id,greatest(d_bas,bas));
 hafta:=oyun.gorev_istatistik(p.id,greatest(w_bas,bas));
 select coalesce(sum(odul),0) into toplam from oyun.gorev_oduller where user_id=p.id and zaman>=d_bas;
 return jsonb_build_object(
  'gunluk_limit',10000,'bugun_kazanilan',toplam,
  'baslangic',bas,
  'gorevler',coalesce((
  select jsonb_agg(jsonb_build_object(
   'id',c.id,'kod',c.kod,'kategori',c.kategori,'baslik',c.baslik,'aciklama',c.aciklama,
   'hedef',c.hedef,'ilerleme',least(c.hedef,greatest(0,coalesce((case c.donem when 'gunluk' then gun when 'haftalik' then hafta else bir end->>c.metrik)::int,0))),
   'odul',c.odul,'donem',c.donem,'seviye',c.seviye,'rota',c.rota,
   'alindi',exists(select 1 from oyun.gorev_oduller o where o.gorev_id=c.id and o.user_id=p.id and o.donem_anahtari=
    case c.donem when 'gunluk' then gun_k when 'haftalik' then hafta_k else 'tek' end)
  ) order by case c.donem when 'gunluk' then 0 when 'haftalik' then 1 else 2 end,c.kategori,c.seviye,c.id)
  from oyun.gorev_katalog c where c.aktif),'[]'::jsonb)
 );
end $$;

create or replace function public.gorev_odul_al(p_gorev bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); c oyun.gorev_katalog; v_bas timestamptz; p_bas timestamptz;
 k text; done integer; toplam numeric; d_bas timestamptz;
begin
 -- Aynı oyuncunun eşzamanlı istekleri arasında çift ödül engeli.
 perform pg_advisory_xact_lock(91720,hashtext(p.id::text));
 select * into c from oyun.gorev_katalog where id=p_gorev and aktif;
 if c.id is null then raise exception 'Görev bulunamadı.'; end if;
 select baslangic into v_bas from oyun.gorev_ayar where id=1;
 d_bas:=date_trunc('day',t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul';
 k:=case c.donem when 'gunluk' then to_char(t at time zone 'Europe/Istanbul','YYYY-MM-DD')
 when 'haftalik' then to_char(t at time zone 'Europe/Istanbul','IYYY-"W"IW') else 'tek' end;
 if exists(select 1 from oyun.gorev_oduller where user_id=p.id and gorev_id=c.id and donem_anahtari=k)
 then raise exception 'Bu görevin ödülünü zaten aldın.'; end if;
 p_bas:=case c.donem when 'gunluk' then greatest(d_bas,v_bas)
 when 'haftalik' then greatest(date_trunc('week',t at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul',v_bas)
 else v_bas end;
 done:=coalesce((oyun.gorev_istatistik(p.id,p_bas)->>c.metrik)::int,0);
 if done<c.hedef then raise exception 'Görev tamamlanmadı: % / % ilerleme.',done,c.hedef; end if;
 select coalesce(sum(odul),0) into toplam from oyun.gorev_oduller where user_id=p.id and zaman>=d_bas;
 if toplam+c.odul>10000 then raise exception 'Günlük görev ödülü limiti 10.000 TL. Yarın tekrar dene.'; end if;
 insert into oyun.gorev_oduller(user_id,gorev_id,donem_anahtari,odul,zaman) values(p.id,c.id,k,c.odul,t);
 perform oyun.para_islem(p.id,c.odul,'gorev',format('Görev ödülü: %s',c.baslik),t);
 return jsonb_build_object('tamam',true,'odul',c.odul,'gorev',c.baslik,'bugun_kazanilan',toplam+c.odul);
end $$;

revoke all on function public.gorevlerim(),public.gorev_odul_al(bigint) from public,anon;
grant execute on function public.gorevlerim(),public.gorev_odul_al(bigint) to authenticated;

-- Aşağıdaki katalog yeni oyuncu verisi oluşturmaz; güncellemeler mevcut ödül geçmişini silmez.

insert into oyun.gorev_katalog(kod,kategori,baslik,aciklama,metrik,hedef,odul,donem,seviye,rota,aktif) values
('sohbet_gun_1','Toplum','Sohbette düzenli bulun I','Farklı günlerde genel sohbetlere anlamlı mesaj yaz. Hedef: 1.','sohbet_gun',1,300,'tek',1,'sohbet',true),
('sohbet_gun_2','Toplum','Sohbette düzenli bulun II','Farklı günlerde genel sohbetlere anlamlı mesaj yaz. Hedef: 3.','sohbet_gun',3,550,'tek',2,'sohbet',true),
('sohbet_gun_3','Toplum','Sohbette düzenli bulun III','Farklı günlerde genel sohbetlere anlamlı mesaj yaz. Hedef: 7.','sohbet_gun',7,850,'tek',3,'sohbet',true),
('sohbet_gun_4','Toplum','Sohbette düzenli bulun IV','Farklı günlerde genel sohbetlere anlamlı mesaj yaz. Hedef: 14.','sohbet_gun',14,1400,'tek',4,'sohbet',true),
('sohbet_gun_5','Toplum','Sohbette düzenli bulun V','Farklı günlerde genel sohbetlere anlamlı mesaj yaz. Hedef: 30.','sohbet_gun',30,2300,'tek',5,'sohbet',true),
('sohbet_mesaj_1','Toplum','Kamusal sohbetlere katıl I','Genel sohbet kanallarında anlamlı mesajlar gönder. Hedef: 1.','sohbet_mesaj',1,300,'tek',1,'sohbet',true),
('sohbet_mesaj_2','Toplum','Kamusal sohbetlere katıl II','Genel sohbet kanallarında anlamlı mesajlar gönder. Hedef: 3.','sohbet_mesaj',3,550,'tek',2,'sohbet',true),
('sohbet_mesaj_3','Toplum','Kamusal sohbetlere katıl III','Genel sohbet kanallarında anlamlı mesajlar gönder. Hedef: 6.','sohbet_mesaj',6,850,'tek',3,'sohbet',true),
('sohbet_mesaj_4','Toplum','Kamusal sohbetlere katıl IV','Genel sohbet kanallarında anlamlı mesajlar gönder. Hedef: 12.','sohbet_mesaj',12,1400,'tek',4,'sohbet',true),
('sohbet_mesaj_5','Toplum','Kamusal sohbetlere katıl V','Genel sohbet kanallarında anlamlı mesajlar gönder. Hedef: 25.','sohbet_mesaj',25,2300,'tek',5,'sohbet',true),
('sohbet_kanal_1','Toplum','Farklı sohbet kanallarını keşfet I','Farklı kamusal sohbet kanallarına katıl. Hedef: 1.','sohbet_kanal',1,400,'tek',1,'sohbet',true),
('sohbet_kanal_2','Toplum','Farklı sohbet kanallarını keşfet II','Farklı kamusal sohbet kanallarına katıl. Hedef: 2.','sohbet_kanal',2,650,'tek',2,'sohbet',true),
('sohbet_kanal_3','Toplum','Farklı sohbet kanallarını keşfet III','Farklı kamusal sohbet kanallarına katıl. Hedef: 3.','sohbet_kanal',3,950,'tek',3,'sohbet',true),
('sohbet_kanal_4','Toplum','Farklı sohbet kanallarını keşfet IV','Farklı kamusal sohbet kanallarına katıl. Hedef: 5.','sohbet_kanal',5,1500,'tek',4,'sohbet',true),
('sohbet_kanal_5','Toplum','Farklı sohbet kanallarını keşfet V','Farklı kamusal sohbet kanallarına katıl. Hedef: 8.','sohbet_kanal',8,2400,'tek',5,'sohbet',true),
('dernek_sohbet_gun_1','Toplum','Dernek sohbetine uğra I','Dernek üyeleriyle farklı günlerde sohbet et. Hedef: 1.','dernek_sohbet_gun',1,300,'tek',1,'sohbet',true),
('dernek_sohbet_gun_2','Toplum','Dernek sohbetine uğra II','Dernek üyeleriyle farklı günlerde sohbet et. Hedef: 3.','dernek_sohbet_gun',3,550,'tek',2,'sohbet',true),
('dernek_sohbet_gun_3','Toplum','Dernek sohbetine uğra III','Dernek üyeleriyle farklı günlerde sohbet et. Hedef: 7.','dernek_sohbet_gun',7,850,'tek',3,'sohbet',true),
('dernek_sohbet_gun_4','Toplum','Dernek sohbetine uğra IV','Dernek üyeleriyle farklı günlerde sohbet et. Hedef: 14.','dernek_sohbet_gun',14,1400,'tek',4,'sohbet',true),
('dernek_sohbet_gun_5','Toplum','Dernek sohbetine uğra V','Dernek üyeleriyle farklı günlerde sohbet et. Hedef: 30.','dernek_sohbet_gun',30,2300,'tek',5,'sohbet',true),
('dernek_sohbet_yazi_1','Toplum','Dernek içinde fikir paylaş I','Dernek sohbet kanallarında anlamlı mesajlar yaz. Hedef: 1.','dernek_sohbet_yazi',1,300,'tek',1,'sohbet',true),
('dernek_sohbet_yazi_2','Toplum','Dernek içinde fikir paylaş II','Dernek sohbet kanallarında anlamlı mesajlar yaz. Hedef: 3.','dernek_sohbet_yazi',3,550,'tek',2,'sohbet',true),
('dernek_sohbet_yazi_3','Toplum','Dernek içinde fikir paylaş III','Dernek sohbet kanallarında anlamlı mesajlar yaz. Hedef: 6.','dernek_sohbet_yazi',6,850,'tek',3,'sohbet',true),
('dernek_sohbet_yazi_4','Toplum','Dernek içinde fikir paylaş IV','Dernek sohbet kanallarında anlamlı mesajlar yaz. Hedef: 12.','dernek_sohbet_yazi',12,1400,'tek',4,'sohbet',true),
('dernek_sohbet_yazi_5','Toplum','Dernek içinde fikir paylaş V','Dernek sohbet kanallarında anlamlı mesajlar yaz. Hedef: 25.','dernek_sohbet_yazi',25,2300,'tek',5,'sohbet',true),
('secim_oy_1','Seçimler','Sandığa git I','Oyundaki seçimlerde oy kullan; belirli bir parti veya aday şartı yok. Hedef: 1.','secim_oy',1,300,'tek',1,'parti',true),
('secim_oy_2','Seçimler','Sandığa git II','Oyundaki seçimlerde oy kullan; belirli bir parti veya aday şartı yok. Hedef: 3.','secim_oy',3,550,'tek',2,'parti',true),
('secim_oy_3','Seçimler','Sandığa git III','Oyundaki seçimlerde oy kullan; belirli bir parti veya aday şartı yok. Hedef: 6.','secim_oy',6,850,'tek',3,'parti',true),
('secim_oy_4','Seçimler','Sandığa git IV','Oyundaki seçimlerde oy kullan; belirli bir parti veya aday şartı yok. Hedef: 12.','secim_oy',12,1400,'tek',4,'parti',true),
('secim_oy_5','Seçimler','Sandığa git V','Oyundaki seçimlerde oy kullan; belirli bir parti veya aday şartı yok. Hedef: 25.','secim_oy',25,2300,'tek',5,'parti',true),
('secim_turleri_1','Seçimler','Farklı seçimleri deneyimle I','Farklı türde seçimlerde oy kullan. Hedef: 1.','secim_turleri',1,400,'tek',1,'parti',true),
('secim_turleri_2','Seçimler','Farklı seçimleri deneyimle II','Farklı türde seçimlerde oy kullan. Hedef: 2.','secim_turleri',2,650,'tek',2,'parti',true),
('secim_turleri_3','Seçimler','Farklı seçimleri deneyimle III','Farklı türde seçimlerde oy kullan. Hedef: 3.','secim_turleri',3,950,'tek',3,'parti',true),
('secim_turleri_4','Seçimler','Farklı seçimleri deneyimle IV','Farklı türde seçimlerde oy kullan. Hedef: 5.','secim_turleri',5,1500,'tek',4,'parti',true),
('secim_turleri_5','Seçimler','Farklı seçimleri deneyimle V','Farklı türde seçimlerde oy kullan. Hedef: 8.','secim_turleri',8,2400,'tek',5,'parti',true),
('aday_ol_1','Seçimler','Aday ol I','Seçimlerde geçerli adaylık başvurusu yap. Hedef: 1.','aday_ol',1,300,'tek',1,'parti',true),
('aday_ol_2','Seçimler','Aday ol II','Seçimlerde geçerli adaylık başvurusu yap. Hedef: 3.','aday_ol',3,550,'tek',2,'parti',true),
('aday_ol_3','Seçimler','Aday ol III','Seçimlerde geçerli adaylık başvurusu yap. Hedef: 6.','aday_ol',6,850,'tek',3,'parti',true),
('aday_ol_4','Seçimler','Aday ol IV','Seçimlerde geçerli adaylık başvurusu yap. Hedef: 12.','aday_ol',12,1400,'tek',4,'parti',true),
('aday_ol_5','Seçimler','Aday ol V','Seçimlerde geçerli adaylık başvurusu yap. Hedef: 25.','aday_ol',25,2300,'tek',5,'parti',true),
('miting_katil_1','Seçimler','Mitinge katıl I','Farklı mitinglerde katılımını kaydettir. Hedef: 1.','miting_katil',1,300,'tek',1,'gundem',true),
('miting_katil_2','Seçimler','Mitinge katıl II','Farklı mitinglerde katılımını kaydettir. Hedef: 3.','miting_katil',3,550,'tek',2,'gundem',true),
('miting_katil_3','Seçimler','Mitinge katıl III','Farklı mitinglerde katılımını kaydettir. Hedef: 6.','miting_katil',6,850,'tek',3,'gundem',true),
('miting_katil_4','Seçimler','Mitinge katıl IV','Farklı mitinglerde katılımını kaydettir. Hedef: 12.','miting_katil',12,1400,'tek',4,'gundem',true),
('miting_katil_5','Seçimler','Mitinge katıl V','Farklı mitinglerde katılımını kaydettir. Hedef: 25.','miting_katil',25,2300,'tek',5,'gundem',true),
('miting_il_1','Seçimler','Farklı illerde miting deneyimle I','Değişik illerdeki mitinglere katıl. Hedef: 1.','miting_il',1,400,'tek',1,'gundem',true),
('miting_il_2','Seçimler','Farklı illerde miting deneyimle II','Değişik illerdeki mitinglere katıl. Hedef: 2.','miting_il',2,650,'tek',2,'gundem',true),
('miting_il_3','Seçimler','Farklı illerde miting deneyimle III','Değişik illerdeki mitinglere katıl. Hedef: 3.','miting_il',3,950,'tek',3,'gundem',true),
('miting_il_4','Seçimler','Farklı illerde miting deneyimle IV','Değişik illerdeki mitinglere katıl. Hedef: 5.','miting_il',5,1500,'tek',4,'gundem',true),
('miting_il_5','Seçimler','Farklı illerde miting deneyimle V','Değişik illerdeki mitinglere katıl. Hedef: 8.','miting_il',8,2400,'tek',5,'gundem',true),
('miting_konus_1','Seçimler','Miting kürsüsüne çık I','Mitinglerde konuşma yap. Hedef: 1.','miting_konus',1,300,'tek',1,'gundem',true),
('miting_konus_2','Seçimler','Miting kürsüsüne çık II','Mitinglerde konuşma yap. Hedef: 3.','miting_konus',3,550,'tek',2,'gundem',true),
('miting_konus_3','Seçimler','Miting kürsüsüne çık III','Mitinglerde konuşma yap. Hedef: 6.','miting_konus',6,850,'tek',3,'gundem',true),
('miting_konus_4','Seçimler','Miting kürsüsüne çık IV','Mitinglerde konuşma yap. Hedef: 12.','miting_konus',12,1400,'tek',4,'gundem',true),
('miting_konus_5','Seçimler','Miting kürsüsüne çık V','Mitinglerde konuşma yap. Hedef: 25.','miting_konus',25,2300,'tek',5,'gundem',true),
('miting_konus_gun_1','Seçimler','Düzenli miting konuş I','Farklı günlerde miting kürsüsünden seslen. Hedef: 1.','miting_konus_gun',1,300,'tek',1,'gundem',true),
('miting_konus_gun_2','Seçimler','Düzenli miting konuş II','Farklı günlerde miting kürsüsünden seslen. Hedef: 3.','miting_konus_gun',3,550,'tek',2,'gundem',true),
('miting_konus_gun_3','Seçimler','Düzenli miting konuş III','Farklı günlerde miting kürsüsünden seslen. Hedef: 7.','miting_konus_gun',7,850,'tek',3,'gundem',true),
('miting_konus_gun_4','Seçimler','Düzenli miting konuş IV','Farklı günlerde miting kürsüsünden seslen. Hedef: 14.','miting_konus_gun',14,1400,'tek',4,'gundem',true),
('miting_konus_gun_5','Seçimler','Düzenli miting konuş V','Farklı günlerde miting kürsüsünden seslen. Hedef: 30.','miting_konus_gun',30,2300,'tek',5,'gundem',true),
('miting_duzen_1','Seçimler','Miting organize et I','Oyunda miting düzenle. Hedef: 1.','miting_duzen',1,400,'tek',1,'parti',true),
('miting_duzen_2','Seçimler','Miting organize et II','Oyunda miting düzenle. Hedef: 2.','miting_duzen',2,650,'tek',2,'parti',true),
('miting_duzen_3','Seçimler','Miting organize et III','Oyunda miting düzenle. Hedef: 3.','miting_duzen',3,950,'tek',3,'parti',true),
('miting_duzen_4','Seçimler','Miting organize et IV','Oyunda miting düzenle. Hedef: 5.','miting_duzen',5,1500,'tek',4,'parti',true),
('miting_duzen_5','Seçimler','Miting organize et V','Oyunda miting düzenle. Hedef: 8.','miting_duzen',8,2400,'tek',5,'parti',true),
('gazete_haber_1','Basın','Haber yayımla I','Oyuncu gazetesinde haber metinleri yayımla. Hedef: 1.','gazete_haber',1,300,'tek',1,'basin',true),
('gazete_haber_2','Basın','Haber yayımla II','Oyuncu gazetesinde haber metinleri yayımla. Hedef: 3.','gazete_haber',3,550,'tek',2,'basin',true),
('gazete_haber_3','Basın','Haber yayımla III','Oyuncu gazetesinde haber metinleri yayımla. Hedef: 6.','gazete_haber',6,850,'tek',3,'basin',true),
('gazete_haber_4','Basın','Haber yayımla IV','Oyuncu gazetesinde haber metinleri yayımla. Hedef: 12.','gazete_haber',12,1400,'tek',4,'basin',true),
('gazete_haber_5','Basın','Haber yayımla V','Oyuncu gazetesinde haber metinleri yayımla. Hedef: 25.','gazete_haber',25,2300,'tek',5,'basin',true),
('gazete_kose_1','Basın','Köşe yazısı yaz I','Oyuncu gazetesinde köşe yazıları yayımla. Hedef: 1.','gazete_kose',1,300,'tek',1,'basin',true),
('gazete_kose_2','Basın','Köşe yazısı yaz II','Oyuncu gazetesinde köşe yazıları yayımla. Hedef: 3.','gazete_kose',3,550,'tek',2,'basin',true),
('gazete_kose_3','Basın','Köşe yazısı yaz III','Oyuncu gazetesinde köşe yazıları yayımla. Hedef: 6.','gazete_kose',6,850,'tek',3,'basin',true),
('gazete_kose_4','Basın','Köşe yazısı yaz IV','Oyuncu gazetesinde köşe yazıları yayımla. Hedef: 12.','gazete_kose',12,1400,'tek',4,'basin',true),
('gazete_kose_5','Basın','Köşe yazısı yaz V','Oyuncu gazetesinde köşe yazıları yayımla. Hedef: 25.','gazete_kose',25,2300,'tek',5,'basin',true),
('gazete_yayin_gun_1','Basın','Düzenli gazetecilik yap I','Farklı günlerde gazete yayını yap. Hedef: 1.','gazete_yayin_gun',1,300,'tek',1,'basin',true),
('gazete_yayin_gun_2','Basın','Düzenli gazetecilik yap II','Farklı günlerde gazete yayını yap. Hedef: 3.','gazete_yayin_gun',3,550,'tek',2,'basin',true),
('gazete_yayin_gun_3','Basın','Düzenli gazetecilik yap III','Farklı günlerde gazete yayını yap. Hedef: 7.','gazete_yayin_gun',7,850,'tek',3,'basin',true),
('gazete_yayin_gun_4','Basın','Düzenli gazetecilik yap IV','Farklı günlerde gazete yayını yap. Hedef: 14.','gazete_yayin_gun',14,1400,'tek',4,'basin',true),
('gazete_yayin_gun_5','Basın','Düzenli gazetecilik yap V','Farklı günlerde gazete yayını yap. Hedef: 30.','gazete_yayin_gun',30,2300,'tek',5,'basin',true),
('gazete_yorum_1','Basın','Haberlere yorum kat I','Farklı köşe yazılarına yorum yap. Hedef: 1.','gazete_yorum',1,300,'tek',1,'basin',true),
('gazete_yorum_2','Basın','Haberlere yorum kat II','Farklı köşe yazılarına yorum yap. Hedef: 3.','gazete_yorum',3,550,'tek',2,'basin',true),
('gazete_yorum_3','Basın','Haberlere yorum kat III','Farklı köşe yazılarına yorum yap. Hedef: 6.','gazete_yorum',6,850,'tek',3,'basin',true),
('gazete_yorum_4','Basın','Haberlere yorum kat IV','Farklı köşe yazılarına yorum yap. Hedef: 12.','gazete_yorum',12,1400,'tek',4,'basin',true),
('gazete_yorum_5','Basın','Haberlere yorum kat V','Farklı köşe yazılarına yorum yap. Hedef: 25.','gazete_yorum',25,2300,'tek',5,'basin',true),
('gazeteler_yayin_1','Basın','Farklı gazetelerde yaz I','Birden çok oyuncu gazetesinde yazı yayımla. Hedef: 1.','gazeteler_yayin',1,400,'tek',1,'basin',true),
('gazeteler_yayin_2','Basın','Farklı gazetelerde yaz II','Birden çok oyuncu gazetesinde yazı yayımla. Hedef: 2.','gazeteler_yayin',2,650,'tek',2,'basin',true),
('gazeteler_yayin_3','Basın','Farklı gazetelerde yaz III','Birden çok oyuncu gazetesinde yazı yayımla. Hedef: 3.','gazeteler_yayin',3,950,'tek',3,'basin',true),
('gazeteler_yayin_4','Basın','Farklı gazetelerde yaz IV','Birden çok oyuncu gazetesinde yazı yayımla. Hedef: 5.','gazeteler_yayin',5,1500,'tek',4,'basin',true),
('gazeteler_yayin_5','Basın','Farklı gazetelerde yaz V','Birden çok oyuncu gazetesinde yazı yayımla. Hedef: 8.','gazeteler_yayin',8,2400,'tek',5,'basin',true),
('roportaj_davet_1','Basın','Röportaj davetleri gönder I','Gazeteci olarak başka oyunculara röportaj daveti yönelt. Hedef: 1.','roportaj_davet',1,300,'tek',1,'basin',true),
('roportaj_davet_2','Basın','Röportaj davetleri gönder II','Gazeteci olarak başka oyunculara röportaj daveti yönelt. Hedef: 3.','roportaj_davet',3,550,'tek',2,'basin',true),
('roportaj_davet_3','Basın','Röportaj davetleri gönder III','Gazeteci olarak başka oyunculara röportaj daveti yönelt. Hedef: 6.','roportaj_davet',6,850,'tek',3,'basin',true),
('roportaj_davet_4','Basın','Röportaj davetleri gönder IV','Gazeteci olarak başka oyunculara röportaj daveti yönelt. Hedef: 12.','roportaj_davet',12,1400,'tek',4,'basin',true),
('roportaj_davet_5','Basın','Röportaj davetleri gönder V','Gazeteci olarak başka oyunculara röportaj daveti yönelt. Hedef: 25.','roportaj_davet',25,2300,'tek',5,'basin',true),
('roportaj_yayin_1','Basın','Röportaj yayımla I','Oyuncularla yapılan röportajları gazetede yayımla. Hedef: 1.','roportaj_yayin',1,300,'tek',1,'basin',true),
('roportaj_yayin_2','Basın','Röportaj yayımla II','Oyuncularla yapılan röportajları gazetede yayımla. Hedef: 3.','roportaj_yayin',3,550,'tek',2,'basin',true),
('roportaj_yayin_3','Basın','Röportaj yayımla III','Oyuncularla yapılan röportajları gazetede yayımla. Hedef: 6.','roportaj_yayin',6,850,'tek',3,'basin',true),
('roportaj_yayin_4','Basın','Röportaj yayımla IV','Oyuncularla yapılan röportajları gazetede yayımla. Hedef: 12.','roportaj_yayin',12,1400,'tek',4,'basin',true),
('roportaj_yayin_5','Basın','Röportaj yayımla V','Oyuncularla yapılan röportajları gazetede yayımla. Hedef: 25.','roportaj_yayin',25,2300,'tek',5,'basin',true),
('roportaj_cevap_1','Basın','Röportajlara cevap ver I','Sana gönderilen röportaj davetlerini yanıtla. Hedef: 1.','roportaj_cevap',1,300,'tek',1,'basin',true),
('roportaj_cevap_2','Basın','Röportajlara cevap ver II','Sana gönderilen röportaj davetlerini yanıtla. Hedef: 3.','roportaj_cevap',3,550,'tek',2,'basin',true),
('roportaj_cevap_3','Basın','Röportajlara cevap ver III','Sana gönderilen röportaj davetlerini yanıtla. Hedef: 6.','roportaj_cevap',6,850,'tek',3,'basin',true),
('roportaj_cevap_4','Basın','Röportajlara cevap ver IV','Sana gönderilen röportaj davetlerini yanıtla. Hedef: 12.','roportaj_cevap',12,1400,'tek',4,'basin',true),
('roportaj_cevap_5','Basın','Röportajlara cevap ver V','Sana gönderilen röportaj davetlerini yanıtla. Hedef: 25.','roportaj_cevap',25,2300,'tek',5,'basin',true),
('haber_cevap_1','Basın','Basında cevap hakkı kullan I','Hakkında çıkan haberlerde resmî cevap yayımla. Hedef: 1.','haber_cevap',1,400,'tek',1,'basin',true),
('haber_cevap_2','Basın','Basında cevap hakkı kullan II','Hakkında çıkan haberlerde resmî cevap yayımla. Hedef: 2.','haber_cevap',2,650,'tek',2,'basin',true),
('haber_cevap_3','Basın','Basında cevap hakkı kullan III','Hakkında çıkan haberlerde resmî cevap yayımla. Hedef: 3.','haber_cevap',3,950,'tek',3,'basin',true),
('haber_cevap_4','Basın','Basında cevap hakkı kullan IV','Hakkında çıkan haberlerde resmî cevap yayımla. Hedef: 5.','haber_cevap',5,1500,'tek',4,'basin',true),
('haber_cevap_5','Basın','Basında cevap hakkı kullan V','Hakkında çıkan haberlerde resmî cevap yayımla. Hedef: 8.','haber_cevap',8,2400,'tek',5,'basin',true),
('duello_davet_1','Siyasi tartışmalar','Tartışma daveti gönder I','Başka oyuncuları siyasi düelloya davet et. Hedef: 1.','duello_davet',1,300,'tek',1,'sivil',true),
('duello_davet_2','Siyasi tartışmalar','Tartışma daveti gönder II','Başka oyuncuları siyasi düelloya davet et. Hedef: 3.','duello_davet',3,550,'tek',2,'sivil',true),
('duello_davet_3','Siyasi tartışmalar','Tartışma daveti gönder III','Başka oyuncuları siyasi düelloya davet et. Hedef: 6.','duello_davet',6,850,'tek',3,'sivil',true),
('duello_davet_4','Siyasi tartışmalar','Tartışma daveti gönder IV','Başka oyuncuları siyasi düelloya davet et. Hedef: 12.','duello_davet',12,1400,'tek',4,'sivil',true),
('duello_davet_5','Siyasi tartışmalar','Tartışma daveti gönder V','Başka oyuncuları siyasi düelloya davet et. Hedef: 25.','duello_davet',25,2300,'tek',5,'sivil',true),
('duello_konus_1','Siyasi tartışmalar','Siyasi tartışmada konuş I','Karşılıklı tartışmada söz al. Hedef: 1.','duello_konus',1,300,'tek',1,'sivil',true),
('duello_konus_2','Siyasi tartışmalar','Siyasi tartışmada konuş II','Karşılıklı tartışmada söz al. Hedef: 3.','duello_konus',3,550,'tek',2,'sivil',true),
('duello_konus_3','Siyasi tartışmalar','Siyasi tartışmada konuş III','Karşılıklı tartışmada söz al. Hedef: 6.','duello_konus',6,850,'tek',3,'sivil',true),
('duello_konus_4','Siyasi tartışmalar','Siyasi tartışmada konuş IV','Karşılıklı tartışmada söz al. Hedef: 12.','duello_konus',12,1400,'tek',4,'sivil',true),
('duello_konus_5','Siyasi tartışmalar','Siyasi tartışmada konuş V','Karşılıklı tartışmada söz al. Hedef: 25.','duello_konus',25,2300,'tek',5,'sivil',true),
('duello_oy_1','Siyasi tartışmalar','Düello izleyicisi ol I','Farklı siyasi düellolarda oy kullan. Hedef: 1.','duello_oy',1,300,'tek',1,'sivil',true),
('duello_oy_2','Siyasi tartışmalar','Düello izleyicisi ol II','Farklı siyasi düellolarda oy kullan. Hedef: 3.','duello_oy',3,550,'tek',2,'sivil',true),
('duello_oy_3','Siyasi tartışmalar','Düello izleyicisi ol III','Farklı siyasi düellolarda oy kullan. Hedef: 6.','duello_oy',6,850,'tek',3,'sivil',true),
('duello_oy_4','Siyasi tartışmalar','Düello izleyicisi ol IV','Farklı siyasi düellolarda oy kullan. Hedef: 12.','duello_oy',12,1400,'tek',4,'sivil',true),
('duello_oy_5','Siyasi tartışmalar','Düello izleyicisi ol V','Farklı siyasi düellolarda oy kullan. Hedef: 25.','duello_oy',25,2300,'tek',5,'sivil',true),
('duello_tamam_1','Siyasi tartışmalar','Tartışmaları tamamla I','Tarafı olduğun düelloların tamamlanmasını sağla. Hedef: 1.','duello_tamam',1,300,'tek',1,'sivil',true),
('duello_tamam_2','Siyasi tartışmalar','Tartışmaları tamamla II','Tarafı olduğun düelloların tamamlanmasını sağla. Hedef: 3.','duello_tamam',3,550,'tek',2,'sivil',true),
('duello_tamam_3','Siyasi tartışmalar','Tartışmaları tamamla III','Tarafı olduğun düelloların tamamlanmasını sağla. Hedef: 6.','duello_tamam',6,850,'tek',3,'sivil',true),
('duello_tamam_4','Siyasi tartışmalar','Tartışmaları tamamla IV','Tarafı olduğun düelloların tamamlanmasını sağla. Hedef: 12.','duello_tamam',12,1400,'tek',4,'sivil',true),
('duello_tamam_5','Siyasi tartışmalar','Tartışmaları tamamla V','Tarafı olduğun düelloların tamamlanmasını sağla. Hedef: 25.','duello_tamam',25,2300,'tek',5,'sivil',true),
('imza_baslat_1','Vatandaşlık','İmza kampanyası başlat I','Kamusal bir talep için imza kampanyası aç. Hedef: 1.','imza_baslat',1,300,'tek',1,'sivil',true),
('imza_baslat_2','Vatandaşlık','İmza kampanyası başlat II','Kamusal bir talep için imza kampanyası aç. Hedef: 3.','imza_baslat',3,550,'tek',2,'sivil',true),
('imza_baslat_3','Vatandaşlık','İmza kampanyası başlat III','Kamusal bir talep için imza kampanyası aç. Hedef: 6.','imza_baslat',6,850,'tek',3,'sivil',true),
('imza_baslat_4','Vatandaşlık','İmza kampanyası başlat IV','Kamusal bir talep için imza kampanyası aç. Hedef: 12.','imza_baslat',12,1400,'tek',4,'sivil',true),
('imza_baslat_5','Vatandaşlık','İmza kampanyası başlat V','Kamusal bir talep için imza kampanyası aç. Hedef: 25.','imza_baslat',25,2300,'tek',5,'sivil',true),
('imza_kat_1','Vatandaşlık','Toplumsal talepleri imzala I','Diğer oyuncuların imza kampanyalarına destek ver. Hedef: 1.','imza_kat',1,300,'tek',1,'sivil',true),
('imza_kat_2','Vatandaşlık','Toplumsal talepleri imzala II','Diğer oyuncuların imza kampanyalarına destek ver. Hedef: 3.','imza_kat',3,550,'tek',2,'sivil',true),
('imza_kat_3','Vatandaşlık','Toplumsal talepleri imzala III','Diğer oyuncuların imza kampanyalarına destek ver. Hedef: 6.','imza_kat',6,850,'tek',3,'sivil',true),
('imza_kat_4','Vatandaşlık','Toplumsal talepleri imzala IV','Diğer oyuncuların imza kampanyalarına destek ver. Hedef: 12.','imza_kat',12,1400,'tek',4,'sivil',true),
('imza_kat_5','Vatandaşlık','Toplumsal talepleri imzala V','Diğer oyuncuların imza kampanyalarına destek ver. Hedef: 25.','imza_kat',25,2300,'tek',5,'sivil',true),
('imza_basari_1','Vatandaşlık','İmza hedefini tuttur I','Başlattığın kampanyaların yeterli imzaya ulaşmasını sağla. Hedef: 1.','imza_basari',1,400,'tek',1,'sivil',true),
('imza_basari_2','Vatandaşlık','İmza hedefini tuttur II','Başlattığın kampanyaların yeterli imzaya ulaşmasını sağla. Hedef: 2.','imza_basari',2,650,'tek',2,'sivil',true),
('imza_basari_3','Vatandaşlık','İmza hedefini tuttur III','Başlattığın kampanyaların yeterli imzaya ulaşmasını sağla. Hedef: 3.','imza_basari',3,950,'tek',3,'sivil',true),
('imza_basari_4','Vatandaşlık','İmza hedefini tuttur IV','Başlattığın kampanyaların yeterli imzaya ulaşmasını sağla. Hedef: 5.','imza_basari',5,1500,'tek',4,'sivil',true),
('imza_basari_5','Vatandaşlık','İmza hedefini tuttur V','Başlattığın kampanyaların yeterli imzaya ulaşmasını sağla. Hedef: 8.','imza_basari',8,2400,'tek',5,'sivil',true),
('dilekce_gonder_1','Vatandaşlık','Resmî dilekçe gönder I','Devlet makamlarına talep ve öneri dilekçeleri gönder. Hedef: 1.','dilekce_gonder',1,300,'tek',1,'sivil',true),
('dilekce_gonder_2','Vatandaşlık','Resmî dilekçe gönder II','Devlet makamlarına talep ve öneri dilekçeleri gönder. Hedef: 3.','dilekce_gonder',3,550,'tek',2,'sivil',true),
('dilekce_gonder_3','Vatandaşlık','Resmî dilekçe gönder III','Devlet makamlarına talep ve öneri dilekçeleri gönder. Hedef: 6.','dilekce_gonder',6,850,'tek',3,'sivil',true),
('dilekce_gonder_4','Vatandaşlık','Resmî dilekçe gönder IV','Devlet makamlarına talep ve öneri dilekçeleri gönder. Hedef: 12.','dilekce_gonder',12,1400,'tek',4,'sivil',true),
('dilekce_gonder_5','Vatandaşlık','Resmî dilekçe gönder V','Devlet makamlarına talep ve öneri dilekçeleri gönder. Hedef: 25.','dilekce_gonder',25,2300,'tek',5,'sivil',true),
('dilekce_yanit_1','Vatandaşlık','Halkın talebini yanıtla I','Makam sahibi olarak vatandaş dilekçelerine resmî yanıt yayımla. Hedef: 1.','dilekce_yanit',1,300,'tek',1,'devlet',true),
('dilekce_yanit_2','Vatandaşlık','Halkın talebini yanıtla II','Makam sahibi olarak vatandaş dilekçelerine resmî yanıt yayımla. Hedef: 3.','dilekce_yanit',3,550,'tek',2,'devlet',true),
('dilekce_yanit_3','Vatandaşlık','Halkın talebini yanıtla III','Makam sahibi olarak vatandaş dilekçelerine resmî yanıt yayımla. Hedef: 6.','dilekce_yanit',6,850,'tek',3,'devlet',true),
('dilekce_yanit_4','Vatandaşlık','Halkın talebini yanıtla IV','Makam sahibi olarak vatandaş dilekçelerine resmî yanıt yayımla. Hedef: 12.','dilekce_yanit',12,1400,'tek',4,'devlet',true),
('dilekce_yanit_5','Vatandaşlık','Halkın talebini yanıtla V','Makam sahibi olarak vatandaş dilekçelerine resmî yanıt yayımla. Hedef: 25.','dilekce_yanit',25,2300,'tek',5,'devlet',true),
('dernek_uye_1','Dernekler','Derneklerde yer al I','Farklı sivil toplum kuruluşlarına üye ol. Hedef: 1.','dernek_uye',1,400,'tek',1,'dernek',true),
('dernek_uye_2','Dernekler','Derneklerde yer al II','Farklı sivil toplum kuruluşlarına üye ol. Hedef: 2.','dernek_uye',2,650,'tek',2,'dernek',true),
('dernek_uye_3','Dernekler','Derneklerde yer al III','Farklı sivil toplum kuruluşlarına üye ol. Hedef: 3.','dernek_uye',3,950,'tek',3,'dernek',true),
('dernek_uye_4','Dernekler','Derneklerde yer al IV','Farklı sivil toplum kuruluşlarına üye ol. Hedef: 5.','dernek_uye',5,1500,'tek',4,'dernek',true),
('dernek_uye_5','Dernekler','Derneklerde yer al V','Farklı sivil toplum kuruluşlarına üye ol. Hedef: 8.','dernek_uye',8,2400,'tek',5,'dernek',true),
('dernek_eylem_1','Dernekler','Dernek çalışmasına katkı ver I','Dernek adına açıklama veya etkinlik düzenle. Hedef: 1.','dernek_eylem',1,300,'tek',1,'dernek',true),
('dernek_eylem_2','Dernekler','Dernek çalışmasına katkı ver II','Dernek adına açıklama veya etkinlik düzenle. Hedef: 3.','dernek_eylem',3,550,'tek',2,'dernek',true),
('dernek_eylem_3','Dernekler','Dernek çalışmasına katkı ver III','Dernek adına açıklama veya etkinlik düzenle. Hedef: 6.','dernek_eylem',6,850,'tek',3,'dernek',true),
('dernek_eylem_4','Dernekler','Dernek çalışmasına katkı ver IV','Dernek adına açıklama veya etkinlik düzenle. Hedef: 12.','dernek_eylem',12,1400,'tek',4,'dernek',true),
('dernek_eylem_5','Dernekler','Dernek çalışmasına katkı ver V','Dernek adına açıklama veya etkinlik düzenle. Hedef: 25.','dernek_eylem',25,2300,'tek',5,'dernek',true),
('dernek_eylem_tur_1','Dernekler','Dernek faaliyetlerini çeşitlendir I','Dernek adına farklı türlerde etkinlikler yap. Hedef: 1.','dernek_eylem_tur',1,400,'tek',1,'dernek',true),
('dernek_eylem_tur_2','Dernekler','Dernek faaliyetlerini çeşitlendir II','Dernek adına farklı türlerde etkinlikler yap. Hedef: 2.','dernek_eylem_tur',2,650,'tek',2,'dernek',true),
('dernek_eylem_tur_3','Dernekler','Dernek faaliyetlerini çeşitlendir III','Dernek adına farklı türlerde etkinlikler yap. Hedef: 3.','dernek_eylem_tur',3,950,'tek',3,'dernek',true),
('dernek_eylem_tur_4','Dernekler','Dernek faaliyetlerini çeşitlendir IV','Dernek adına farklı türlerde etkinlikler yap. Hedef: 5.','dernek_eylem_tur',5,1500,'tek',4,'dernek',true),
('dernek_eylem_tur_5','Dernekler','Dernek faaliyetlerini çeşitlendir V','Dernek adına farklı türlerde etkinlikler yap. Hedef: 8.','dernek_eylem_tur',8,2400,'tek',5,'dernek',true),
('dernek_protesto_katil_1','Dernekler','Sivil eyleme katıl I','Farklı dernek protestolarına katıl. Hedef: 1.','dernek_protesto_katil',1,300,'tek',1,'dernek',true),
('dernek_protesto_katil_2','Dernekler','Sivil eyleme katıl II','Farklı dernek protestolarına katıl. Hedef: 3.','dernek_protesto_katil',3,550,'tek',2,'dernek',true),
('dernek_protesto_katil_3','Dernekler','Sivil eyleme katıl III','Farklı dernek protestolarına katıl. Hedef: 6.','dernek_protesto_katil',6,850,'tek',3,'dernek',true),
('dernek_protesto_katil_4','Dernekler','Sivil eyleme katıl IV','Farklı dernek protestolarına katıl. Hedef: 12.','dernek_protesto_katil',12,1400,'tek',4,'dernek',true),
('dernek_protesto_katil_5','Dernekler','Sivil eyleme katıl V','Farklı dernek protestolarına katıl. Hedef: 25.','dernek_protesto_katil',25,2300,'tek',5,'dernek',true),
('dernek_sube_1','Dernekler','Sivil toplum şubesi aç I','Dernek yönetiminde yeni il şubeleri aç. Hedef: 1.','dernek_sube',1,400,'tek',1,'dernek',true),
('dernek_sube_2','Dernekler','Sivil toplum şubesi aç II','Dernek yönetiminde yeni il şubeleri aç. Hedef: 2.','dernek_sube',2,650,'tek',2,'dernek',true),
('dernek_sube_3','Dernekler','Sivil toplum şubesi aç III','Dernek yönetiminde yeni il şubeleri aç. Hedef: 3.','dernek_sube',3,950,'tek',3,'dernek',true),
('dernek_sube_4','Dernekler','Sivil toplum şubesi aç IV','Dernek yönetiminde yeni il şubeleri aç. Hedef: 5.','dernek_sube',5,1500,'tek',4,'dernek',true),
('dernek_sube_5','Dernekler','Sivil toplum şubesi aç V','Dernek yönetiminde yeni il şubeleri aç. Hedef: 8.','dernek_sube',8,2400,'tek',5,'dernek',true),
('dernek_secim_oy_1','Dernekler','Dernek genel kurulunda oy kullan I','Derneklerin yönetim seçimlerinde oy kullan. Hedef: 1.','dernek_secim_oy',1,400,'tek',1,'dernek',true),
('dernek_secim_oy_2','Dernekler','Dernek genel kurulunda oy kullan II','Derneklerin yönetim seçimlerinde oy kullan. Hedef: 2.','dernek_secim_oy',2,650,'tek',2,'dernek',true),
('dernek_secim_oy_3','Dernekler','Dernek genel kurulunda oy kullan III','Derneklerin yönetim seçimlerinde oy kullan. Hedef: 3.','dernek_secim_oy',3,950,'tek',3,'dernek',true),
('dernek_secim_oy_4','Dernekler','Dernek genel kurulunda oy kullan IV','Derneklerin yönetim seçimlerinde oy kullan. Hedef: 5.','dernek_secim_oy',5,1500,'tek',4,'dernek',true),
('dernek_secim_oy_5','Dernekler','Dernek genel kurulunda oy kullan V','Derneklerin yönetim seçimlerinde oy kullan. Hedef: 8.','dernek_secim_oy',8,2400,'tek',5,'dernek',true),
('parti_kurultay_imza_1','Dernekler','Parti içi demokrasiyi destekle I','Parti üyelerinin olağanüstü kurultay taleplerini imzala. Hedef: 1.','parti_kurultay_imza',1,400,'tek',1,'parti',true),
('parti_kurultay_imza_2','Dernekler','Parti içi demokrasiyi destekle II','Parti üyelerinin olağanüstü kurultay taleplerini imzala. Hedef: 2.','parti_kurultay_imza',2,650,'tek',2,'parti',true),
('parti_kurultay_imza_3','Dernekler','Parti içi demokrasiyi destekle III','Parti üyelerinin olağanüstü kurultay taleplerini imzala. Hedef: 3.','parti_kurultay_imza',3,950,'tek',3,'parti',true),
('parti_kurultay_imza_4','Dernekler','Parti içi demokrasiyi destekle IV','Parti üyelerinin olağanüstü kurultay taleplerini imzala. Hedef: 5.','parti_kurultay_imza',5,1500,'tek',4,'parti',true),
('parti_kurultay_imza_5','Dernekler','Parti içi demokrasiyi destekle V','Parti üyelerinin olağanüstü kurultay taleplerini imzala. Hedef: 8.','parti_kurultay_imza',8,2400,'tek',5,'parti',true),
('sirket_kur_1','Ticaret','İşletme kur I','Yeni şirketler kurarak ekonomik faaliyete başla. Hedef: 1.','sirket_kur',1,400,'tek',1,'sirket',true),
('sirket_kur_2','Ticaret','İşletme kur II','Yeni şirketler kurarak ekonomik faaliyete başla. Hedef: 2.','sirket_kur',2,650,'tek',2,'sirket',true),
('sirket_kur_3','Ticaret','İşletme kur III','Yeni şirketler kurarak ekonomik faaliyete başla. Hedef: 3.','sirket_kur',3,950,'tek',3,'sirket',true),
('sirket_kur_4','Ticaret','İşletme kur IV','Yeni şirketler kurarak ekonomik faaliyete başla. Hedef: 5.','sirket_kur',5,1500,'tek',4,'sirket',true),
('sirket_kur_5','Ticaret','İşletme kur V','Yeni şirketler kurarak ekonomik faaliyete başla. Hedef: 8.','sirket_kur',8,2400,'tek',5,'sirket',true),
('sirket_ortak_1','Ticaret','Şirket ortaklığı edin I','Farklı şirketlerde ortak ol. Hedef: 1.','sirket_ortak',1,400,'tek',1,'sirket',true),
('sirket_ortak_2','Ticaret','Şirket ortaklığı edin II','Farklı şirketlerde ortak ol. Hedef: 2.','sirket_ortak',2,650,'tek',2,'sirket',true),
('sirket_ortak_3','Ticaret','Şirket ortaklığı edin III','Farklı şirketlerde ortak ol. Hedef: 3.','sirket_ortak',3,950,'tek',3,'sirket',true),
('sirket_ortak_4','Ticaret','Şirket ortaklığı edin IV','Farklı şirketlerde ortak ol. Hedef: 5.','sirket_ortak',5,1500,'tek',4,'sirket',true),
('sirket_ortak_5','Ticaret','Şirket ortaklığı edin V','Farklı şirketlerde ortak ol. Hedef: 8.','sirket_ortak',8,2400,'tek',5,'sirket',true),
('emlak_sahip_1','Ticaret','Mülk edin I','Satın aldığın yatırım mülkleriyle portföy oluştur. Hedef: 1.','emlak_sahip',1,400,'tek',1,'emlak',true),
('emlak_sahip_2','Ticaret','Mülk edin II','Satın aldığın yatırım mülkleriyle portföy oluştur. Hedef: 2.','emlak_sahip',2,650,'tek',2,'emlak',true),
('emlak_sahip_3','Ticaret','Mülk edin III','Satın aldığın yatırım mülkleriyle portföy oluştur. Hedef: 3.','emlak_sahip',3,950,'tek',3,'emlak',true),
('emlak_sahip_4','Ticaret','Mülk edin IV','Satın aldığın yatırım mülkleriyle portföy oluştur. Hedef: 5.','emlak_sahip',5,1500,'tek',4,'emlak',true),
('emlak_sahip_5','Ticaret','Mülk edin V','Satın aldığın yatırım mülkleriyle portföy oluştur. Hedef: 8.','emlak_sahip',8,2400,'tek',5,'emlak',true),
('emlak_il_1','Ticaret','Farklı illerde mülk edin I','Farklı illerde yatırım mülkü bulundur. Hedef: 1.','emlak_il',1,400,'tek',1,'emlak',true),
('emlak_il_2','Ticaret','Farklı illerde mülk edin II','Farklı illerde yatırım mülkü bulundur. Hedef: 2.','emlak_il',2,650,'tek',2,'emlak',true),
('emlak_il_3','Ticaret','Farklı illerde mülk edin III','Farklı illerde yatırım mülkü bulundur. Hedef: 3.','emlak_il',3,950,'tek',3,'emlak',true),
('emlak_il_4','Ticaret','Farklı illerde mülk edin IV','Farklı illerde yatırım mülkü bulundur. Hedef: 5.','emlak_il',5,1500,'tek',4,'emlak',true),
('emlak_il_5','Ticaret','Farklı illerde mülk edin V','Farklı illerde yatırım mülkü bulundur. Hedef: 8.','emlak_il',8,2400,'tek',5,'emlak',true),
('kanun_teklif_1','Meclis','Kanun öner I','Milletvekili olarak kanun teklifleri hazırla. Hedef: 1.','kanun_teklif',1,400,'tek',1,'devlet',true),
('kanun_teklif_2','Meclis','Kanun öner II','Milletvekili olarak kanun teklifleri hazırla. Hedef: 2.','kanun_teklif',2,650,'tek',2,'devlet',true),
('kanun_teklif_3','Meclis','Kanun öner III','Milletvekili olarak kanun teklifleri hazırla. Hedef: 3.','kanun_teklif',3,950,'tek',3,'devlet',true),
('kanun_teklif_4','Meclis','Kanun öner IV','Milletvekili olarak kanun teklifleri hazırla. Hedef: 5.','kanun_teklif',5,1500,'tek',4,'devlet',true),
('kanun_teklif_5','Meclis','Kanun öner V','Milletvekili olarak kanun teklifleri hazırla. Hedef: 8.','kanun_teklif',8,2400,'tek',5,'devlet',true),
('kanun_oy_1','Meclis','Mecliste oy kullan I','Kanun tekliflerinin oylamalarında görev al. Hedef: 1.','kanun_oy',1,300,'tek',1,'devlet',true),
('kanun_oy_2','Meclis','Mecliste oy kullan II','Kanun tekliflerinin oylamalarında görev al. Hedef: 3.','kanun_oy',3,550,'tek',2,'devlet',true),
('kanun_oy_3','Meclis','Mecliste oy kullan III','Kanun tekliflerinin oylamalarında görev al. Hedef: 6.','kanun_oy',6,850,'tek',3,'devlet',true),
('kanun_oy_4','Meclis','Mecliste oy kullan IV','Kanun tekliflerinin oylamalarında görev al. Hedef: 12.','kanun_oy',12,1400,'tek',4,'devlet',true),
('kanun_oy_5','Meclis','Mecliste oy kullan V','Kanun tekliflerinin oylamalarında görev al. Hedef: 25.','kanun_oy',25,2300,'tek',5,'devlet',true),
('bakan_soru_1','Meclis','Yazılı soru önergesi ver I','Bakanlıklara yazılı soru önergesi gönder. Hedef: 1.','bakan_soru',1,300,'tek',1,'devlet',true),
('bakan_soru_2','Meclis','Yazılı soru önergesi ver II','Bakanlıklara yazılı soru önergesi gönder. Hedef: 3.','bakan_soru',3,550,'tek',2,'devlet',true),
('bakan_soru_3','Meclis','Yazılı soru önergesi ver III','Bakanlıklara yazılı soru önergesi gönder. Hedef: 6.','bakan_soru',6,850,'tek',3,'devlet',true),
('bakan_soru_4','Meclis','Yazılı soru önergesi ver IV','Bakanlıklara yazılı soru önergesi gönder. Hedef: 12.','bakan_soru',12,1400,'tek',4,'devlet',true),
('bakan_soru_5','Meclis','Yazılı soru önergesi ver V','Bakanlıklara yazılı soru önergesi gönder. Hedef: 25.','bakan_soru',25,2300,'tek',5,'devlet',true),
('bakan_yanit_1','Meclis','Bakanlık sorularını yanıtla I','Bakan olarak milletvekillerinin sorularını cevapla. Hedef: 1.','bakan_yanit',1,300,'tek',1,'devlet',true),
('bakan_yanit_2','Meclis','Bakanlık sorularını yanıtla II','Bakan olarak milletvekillerinin sorularını cevapla. Hedef: 3.','bakan_yanit',3,550,'tek',2,'devlet',true),
('bakan_yanit_3','Meclis','Bakanlık sorularını yanıtla III','Bakan olarak milletvekillerinin sorularını cevapla. Hedef: 6.','bakan_yanit',6,850,'tek',3,'devlet',true),
('bakan_yanit_4','Meclis','Bakanlık sorularını yanıtla IV','Bakan olarak milletvekillerinin sorularını cevapla. Hedef: 12.','bakan_yanit',12,1400,'tek',4,'devlet',true),
('bakan_yanit_5','Meclis','Bakanlık sorularını yanıtla V','Bakan olarak milletvekillerinin sorularını cevapla. Hedef: 25.','bakan_yanit',25,2300,'tek',5,'devlet',true),
('anket_oy_1','Seçimler','Haftalık ankete katıl I','Haftalık siyasi anketlerde görüş bildir. Hedef: 1.','anket_oy',1,300,'tek',1,'parti',true),
('anket_oy_2','Seçimler','Haftalık ankete katıl II','Haftalık siyasi anketlerde görüş bildir. Hedef: 3.','anket_oy',3,550,'tek',2,'parti',true),
('anket_oy_3','Seçimler','Haftalık ankete katıl III','Haftalık siyasi anketlerde görüş bildir. Hedef: 7.','anket_oy',7,850,'tek',3,'parti',true),
('anket_oy_4','Seçimler','Haftalık ankete katıl IV','Haftalık siyasi anketlerde görüş bildir. Hedef: 14.','anket_oy',14,1400,'tek',4,'parti',true),
('anket_oy_5','Seçimler','Haftalık ankete katıl V','Haftalık siyasi anketlerde görüş bildir. Hedef: 30.','anket_oy',30,2300,'tek',5,'parti',true),
('parti_tuzuk_oy_1','Meclis','Parti içi oylamaya katıl I','Parti tüzük oylamalarında oy kullan. Hedef: 1.','parti_tuzuk_oy',1,400,'tek',1,'parti',true),
('parti_tuzuk_oy_2','Meclis','Parti içi oylamaya katıl II','Parti tüzük oylamalarında oy kullan. Hedef: 2.','parti_tuzuk_oy',2,650,'tek',2,'parti',true),
('parti_tuzuk_oy_3','Meclis','Parti içi oylamaya katıl III','Parti tüzük oylamalarında oy kullan. Hedef: 3.','parti_tuzuk_oy',3,950,'tek',3,'parti',true),
('parti_tuzuk_oy_4','Meclis','Parti içi oylamaya katıl IV','Parti tüzük oylamalarında oy kullan. Hedef: 5.','parti_tuzuk_oy',5,1500,'tek',4,'parti',true),
('parti_tuzuk_oy_5','Meclis','Parti içi oylamaya katıl V','Parti tüzük oylamalarında oy kullan. Hedef: 8.','parti_tuzuk_oy',8,2400,'tek',5,'parti',true),
('yayin_yap_1','Siyasi tartışmalar','Kamuoyuna açıklama yap I','Oyun içindeki resmî ve siyasi yayınlardan gönder. Hedef: 1.','yayin_yap',1,300,'tek',1,'parti',true),
('yayin_yap_2','Siyasi tartışmalar','Kamuoyuna açıklama yap II','Oyun içindeki resmî ve siyasi yayınlardan gönder. Hedef: 3.','yayin_yap',3,550,'tek',2,'parti',true),
('yayin_yap_3','Siyasi tartışmalar','Kamuoyuna açıklama yap III','Oyun içindeki resmî ve siyasi yayınlardan gönder. Hedef: 6.','yayin_yap',6,850,'tek',3,'parti',true),
('yayin_yap_4','Siyasi tartışmalar','Kamuoyuna açıklama yap IV','Oyun içindeki resmî ve siyasi yayınlardan gönder. Hedef: 12.','yayin_yap',12,1400,'tek',4,'parti',true),
('yayin_yap_5','Siyasi tartışmalar','Kamuoyuna açıklama yap V','Oyun içindeki resmî ve siyasi yayınlardan gönder. Hedef: 25.','yayin_yap',25,2300,'tek',5,'parti',true),
('gazete_kur_1','Basın','Gazete kur I','Oyuncu gazetesi kur. Hedef: 1.','gazete_kur',1,400,'tek',1,'basin',true),
('gazete_kur_2','Basın','Gazete kur II','Oyuncu gazetesi kur. Hedef: 2.','gazete_kur',2,650,'tek',2,'basin',true),
('gazete_kur_3','Basın','Gazete kur III','Oyuncu gazetesi kur. Hedef: 3.','gazete_kur',3,950,'tek',3,'basin',true),
('gazete_kur_4','Basın','Gazete kur IV','Oyuncu gazetesi kur. Hedef: 5.','gazete_kur',5,1500,'tek',4,'basin',true),
('gazete_kur_5','Basın','Gazete kur V','Oyuncu gazetesi kur. Hedef: 8.','gazete_kur',8,2400,'tek',5,'basin',true),
('gunluk_sohbet_mesaj','Toplum','Günlük: Kamusal sohbetlere katıl','Genel sohbet kanallarında anlamlı mesajlar gönder. Hedef: 1.','sohbet_mesaj',1,280,'gunluk',0,'sohbet',true),
('gunluk_sohbet_gun','Toplum','Günlük: Sohbette düzenli bulun','Farklı günlerde genel sohbetlere anlamlı mesaj yaz. Hedef: 1.','sohbet_gun',1,180,'gunluk',0,'sohbet',true),
('gunluk_dernek_sohbet_yazi','Toplum','Günlük: Dernek içinde fikir paylaş','Dernek sohbet kanallarında anlamlı mesajlar yaz. Hedef: 1.','dernek_sohbet_yazi',1,250,'gunluk',0,'sohbet',true),
('gunluk_gazete_yorum','Basın','Günlük: Haberlere yorum kat','Farklı köşe yazılarına yorum yap. Hedef: 1.','gazete_yorum',1,260,'gunluk',0,'basin',true),
('gunluk_miting_konus','Seçimler','Günlük: Miting kürsüsüne çık','Mitinglerde konuşma yap. Hedef: 1.','miting_konus',1,350,'gunluk',0,'gundem',true),
('gunluk_duello_konus','Siyasi tartışmalar','Günlük: Siyasi tartışmada konuş','Karşılıklı tartışmada söz al. Hedef: 1.','duello_konus',1,350,'gunluk',0,'sivil',true),
('gunluk_imza_kat','Vatandaşlık','Günlük: Toplumsal talepleri imzala','Diğer oyuncuların imza kampanyalarına destek ver. Hedef: 1.','imza_kat',1,300,'gunluk',0,'sivil',true),
('gunluk_gazete_haber','Basın','Günlük: Haber yayımla','Oyuncu gazetesinde haber metinleri yayımla. Hedef: 1.','gazete_haber',1,400,'gunluk',0,'basin',true),
('gunluk_dernek_eylem','Dernekler','Günlük: Dernek çalışmasına katkı ver','Dernek adına açıklama veya etkinlik düzenle. Hedef: 1.','dernek_eylem',1,350,'gunluk',0,'dernek',true),
('gunluk_dilekce_gonder','Vatandaşlık','Günlük: Resmî dilekçe gönder','Devlet makamlarına talep ve öneri dilekçeleri gönder. Hedef: 1.','dilekce_gonder',1,330,'gunluk',0,'sivil',true),
('haftalik_secim_oy','Seçimler','Haftalık: Sandığa git','Oyundaki seçimlerde oy kullan; belirli bir parti veya aday şartı yok. Hedef: 1.','secim_oy',1,700,'haftalik',0,'parti',true),
('haftalik_miting_katil','Seçimler','Haftalık: Mitinge katıl','Farklı mitinglerde katılımını kaydettir. Hedef: 1.','miting_katil',1,600,'haftalik',0,'gundem',true),
('haftalik_anket_oy','Seçimler','Haftalık: Haftalık ankete katıl','Haftalık siyasi anketlerde görüş bildir. Hedef: 1.','anket_oy',1,600,'haftalik',0,'parti',true),
('haftalik_gazete_kose','Basın','Haftalık: Köşe yazısı yaz','Oyuncu gazetesinde köşe yazıları yayımla. Hedef: 2.','gazete_kose',2,900,'haftalik',0,'basin',true),
('haftalik_gazete_yayin_gun','Basın','Haftalık: Düzenli gazetecilik yap','Farklı günlerde gazete yayını yap. Hedef: 2.','gazete_yayin_gun',2,700,'haftalik',0,'basin',true),
('haftalik_sohbet_gun','Toplum','Haftalık: Sohbette düzenli bulun','Farklı günlerde genel sohbetlere anlamlı mesaj yaz. Hedef: 3.','sohbet_gun',3,700,'haftalik',0,'sohbet',true),
('haftalik_dernek_sohbet_gun','Toplum','Haftalık: Dernek sohbetine uğra','Dernek üyeleriyle farklı günlerde sohbet et. Hedef: 2.','dernek_sohbet_gun',2,600,'haftalik',0,'sohbet',true),
('haftalik_imza_kat','Vatandaşlık','Haftalık: Toplumsal talepleri imzala','Diğer oyuncuların imza kampanyalarına destek ver. Hedef: 2.','imza_kat',2,800,'haftalik',0,'sivil',true),
('haftalik_kanun_oy','Meclis','Haftalık: Mecliste oy kullan','Kanun tekliflerinin oylamalarında görev al. Hedef: 2.','kanun_oy',2,850,'haftalik',0,'devlet',true),
('haftalik_duello_oy','Siyasi tartışmalar','Haftalık: Düello izleyicisi ol','Farklı siyasi düellolarda oy kullan. Hedef: 1.','duello_oy',1,600,'haftalik',0,'sivil',true)
on conflict(kod) do update set kategori=excluded.kategori,baslik=excluded.baslik,aciklama=excluded.aciklama,metrik=excluded.metrik,hedef=excluded.hedef,odul=excluded.odul,donem=excluded.donem,seviye=excluded.seviye,rota=excluded.rota,aktif=excluded.aktif;
