
-- SEÇİM ONLINE / TV: Kutunu Seç - sunucu denetimli, ücretsiz başvurulu ödül yarışması
-- Mevcut oyuncu, kanal ve finansal geçmişini değiştirmez. Maksimum risk kanalın önceden ayırdığı 50.000 TL'dir.
alter table oyun.tv_program drop constraint if exists tv_program_tur_check;
alter table oyun.tv_program add constraint tv_program_tur_check
  check (tur in ('duello','soylesi','haber','yarisma','acik_oturum','kutunu_sec'));
create or replace function oyun.tv_tur_ad(p text) returns text language sql immutable set search_path to '' as $f$
select case p when 'duello' then 'Siyasi düello'
 when 'soylesi' then 'Söyleşi' when 'haber' then 'Haber programı'
 when 'yarisma' then 'Bilgi yarışması' when 'acik_oturum' then 'Açık oturum · Halk soruyor'
 when 'kutunu_sec' then 'Kutunu Seç · kutu yarışması' else 'TV programı' end $f$;

create table if not exists oyun.tv_kutu_oyun(
 program_id bigint primary key references oyun.tv_program(id),
 kanal_id bigint not null references oyun.tv_kanal(id),
 durum text not null default 'basvuru' check(durum in ('basvuru','secim','acilis','teklif','final','bitti','iptal')),
 degerler numeric[] not null,
 secilen integer check(secilen between 1 and 16),
 acilan integer[] not null default '{}'::integer[],
 teklif numeric,
 teklif_sayisi integer not null default 0,
 yarismaci uuid references oyun.profiller(id),
 teminat numeric not null default 50000 check(teminat=50000),
 asil_odul numeric,
 odenen numeric not null default 0,
 iade numeric not null default 0,
 odendi boolean not null default false,
 basvuru_baslangic timestamptz not null default now(),
 baslangic timestamptz,
 son_hamle timestamptz,
 bitis timestamptz
);
create table if not exists oyun.tv_kutu_basvuru(
 program_id bigint not null references oyun.tv_kutu_oyun(program_id),
 user_id uuid not null references oyun.profiller(id),
 zaman timestamptz not null default now(),
 primary key(program_id,user_id)
);
create table if not exists oyun.tv_kutu_hareket(
 id bigint generated always as identity primary key,
 program_id bigint not null references oyun.tv_kutu_oyun(program_id),
 user_id uuid,
 islem text not null,
 kutu integer,
 tutar numeric,
 zaman timestamptz not null default now()
);
create index if not exists tv_kutu_basvuru_user_idx on oyun.tv_kutu_basvuru(user_id,zaman desc);
create index if not exists tv_kutu_hareket_program_idx on oyun.tv_kutu_hareket(program_id,id);
create index if not exists tv_kutu_oyun_durum_idx on oyun.tv_kutu_oyun(durum,son_hamle);
alter table oyun.tv_kutu_oyun enable row level security;
alter table oyun.tv_kutu_basvuru enable row level security;
alter table oyun.tv_kutu_hareket enable row level security;
revoke all on oyun.tv_kutu_oyun,oyun.tv_kutu_basvuru,oyun.tv_kutu_hareket from public,anon,authenticated;

create or replace function oyun.tv_kutu_uygun(p_kanal bigint,u uuid) returns boolean
language sql stable set search_path to '' as $f$
select exists(
 select 1 from oyun.profiller p join oyun.tv_kanal k on k.id=p_kanal
 where p.id=u and p.olusturma<=oyun.simdi()-interval '7 days'
 and not p.yasakli and p.id<>k.sahip
 and not exists(select 1 from oyun.tv_sunucu s where s.kanal_id=k.id and s.user_id=p.id and s.durum='aktif')
 and not exists(select 1 from oyun.tv_odul_kazanc z join oyun.tv_program pr on pr.id=z.program_id
   where z.user_id=p.id and z.tutar>0 and pr.kanal_id=k.id and z.zaman>oyun.simdi()-interval '7 days')
 and (select count(*) from oyun.tv_odul_kazanc z
   where z.user_id=p.id and z.tutar>0 and z.zaman>oyun.simdi()-interval '7 days')<2
) $f$;
revoke all on function oyun.tv_kutu_uygun(bigint,uuid) from public,anon,authenticated;

-- Önceden ayrılmış teminatın tamamı yarışma bitince ya ödüle ya da kasaya iade olur.
create or replace function oyun.tv_kutu_odeme(p_program bigint,p_ham_odul numeric,p_neden text)
returns void language plpgsql security invoker set search_path to '' as $f$
declare g oyun.tv_kutu_oyun; pr oyun.tv_program; t timestamptz:=oyun.simdi();
 bugun numeric; hafta numeric; kanal_hafta numeric; odenecek numeric; iade_tutar numeric;
begin
 select * into g from oyun.tv_kutu_oyun where program_id=p_program for update;
 if g.program_id is null or g.durum='bitti' or g.odendi or g.yarismaci is null then raise exception 'Ödül işlemi geçerli değil.'; end if;
 select * into pr from oyun.tv_program where id=p_program for update;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(g.yarismaci::text,2026));
 select coalesce(sum(z.tutar),0) into bugun from oyun.tv_odul_kazanc z
   where z.user_id=g.yarismaci and (z.zaman at time zone 'Europe/Istanbul')::date=(t at time zone 'Europe/Istanbul')::date;
 select coalesce(sum(z.tutar),0) into hafta from oyun.tv_odul_kazanc z
   where z.user_id=g.yarismaci and z.tutar>0 and z.zaman>t-interval '7 days';
 select coalesce(sum(z.tutar),0) into kanal_hafta from oyun.tv_odul_kazanc z
   join oyun.tv_program pp on pp.id=z.program_id
   where pp.kanal_id=g.kanal_id and z.tutar>0 and z.zaman>t-interval '7 days';
 odenecek:=least(g.teminat,greatest(0,coalesce(p_ham_odul,0)),
    greatest(0,50000-bugun),greatest(0,100000-hafta),greatest(0,250000-kanal_hafta));
 if not oyun.tv_kutu_uygun(g.kanal_id,g.yarismaci) then odenecek:=0; end if;
 iade_tutar:=g.teminat-odenecek;
 update oyun.tv_kutu_oyun set durum='bitti',asil_odul=p_ham_odul,odenen=odenecek,
  iade=iade_tutar,odendi=true,bitis=t,son_hamle=t where program_id=p_program;
 if odenecek>0 then
  insert into oyun.tv_odul_kazanc(program_id,user_id,sira,puan,tutar,zaman)
    values(p_program,g.yarismaci,1,0,odenecek,t);
  perform oyun.para_islem(g.yarismaci,odenecek,'odul',
    format('Kutunu Seç · %s · %s',pr.baslik,coalesce(p_neden,'yarışma ödülü')),t);
 end if;
 if iade_tutar>0 then
  update oyun.tv_kanal set kasa=kasa+iade_tutar where id=g.kanal_id;
  insert into oyun.tv_hareket(kanal_id,zaman,tutar,tur,aciklama)
   values(g.kanal_id,t,iade_tutar,'odul_iade',format('%s · Kutunu Seç dağıtılmayan teminat iadesi',pr.baslik));
 end if;
 insert into oyun.tv_kutu_hareket(program_id,user_id,islem,tutar,zaman)
  values(p_program,g.yarismaci,'odeme',odenecek,t);
 perform oyun.bildir(g.yarismaci,format('%s yarışman tamamlandı. Kazandığın: %s ₺. Ödenen: %s ₺.',pr.baslik,oyun.tl(p_ham_odul),oyun.tl(odenecek)),t);
 insert into oyun.tv_mesaj(program_id,user_id,rol,metin,zaman)
  values(p_program,g.yarismaci,'sistem',format('Kutunu Seç sona erdi: %s, %s ₺ ödül kazandı.',oyun.kad(g.yarismaci),oyun.tl(odenecek)),t);
 update oyun.tv_program set durum='bitti',gercek_bit=t,reklam_arasi=null where id=p_program and durum='canli';
 perform oyun.tv_program_hesapla(p_program);
 perform oyun.tv_sinyal(p_program);
end $f$;
revoke all on function oyun.tv_kutu_odeme(bigint,numeric,text) from public,anon,authenticated;

-- Mevcut TV kapanışları, 45 dakikada biten veya iptal edilen yarışmaların teminatını geri öder.
create or replace function oyun.tv_kutu_bitis_koruma() returns trigger
language plpgsql security definer set search_path to '' as $f$
declare g oyun.tv_kutu_oyun; t timestamptz:=oyun.simdi();
begin
 if old.tur<>'kutunu_sec' or old.durum=new.durum or new.durum not in ('bitti','iptal') then return new; end if;
 select * into g from oyun.tv_kutu_oyun where program_id=new.id for update;
 if g.program_id is null or g.durum in ('bitti','iptal') then return new; end if;
 if old.durum='canli' and t<old.bit and g.durum<>'basvuru' then
   raise exception 'Devam eden kutu yarışması erken bitirilemez. Yarışmacının oyunu tamamlaması gerekir.';
 end if;
 update oyun.tv_kutu_oyun set durum='iptal',iade=teminat,odendi=true,bitis=t,son_hamle=t where program_id=new.id;
 update oyun.tv_kanal set kasa=kasa+g.teminat where id=g.kanal_id;
 insert into oyun.tv_hareket(kanal_id,zaman,tutar,tur,aciklama)
 values(g.kanal_id,t,g.teminat,'odul_iade',format('%s · Kutunu Seç tamamlanamadı; teminat iadesi',new.baslik));
 insert into oyun.tv_kutu_hareket(program_id,islem,tutar,zaman) values(new.id,'iptal_iade',g.teminat,t);
 return new;
end $f$;
drop trigger if exists tv_kutu_bitis_koruma_t on oyun.tv_program;
create trigger tv_kutu_bitis_koruma_t before update of durum on oyun.tv_program
 for each row execute function oyun.tv_kutu_bitis_koruma();

create or replace function public.tv_kutu_program_ac(p_kanal bigint,p_baslik text default 'Kutunu Seç',
 p_bas timestamptz default null,p_sunucu text default null) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller:=oyun.profilim(); k oyun.tv_kanal; pr oyun.tv_program;
 v jsonb; i bigint; t timestamptz:=oyun.simdi(); d numeric[];
begin
 select * into k from oyun.tv_kanal where id=p_kanal and aktif for update;
 if k.id is null or k.sahip<>p.id then raise exception 'Kutunu Seç programını kanal sahibi açar.'; end if;
 if k.kasa<50000 then raise exception 'Kanal kasasında 50.000 ₺ ödül teminatı olmalı.'; end if;
 v:=public.tv_program_ac(p_kanal,'yarisma',case when nullif(btrim(p_baslik),'') is null
   then 'Kutunu Seç' else left(p_baslik,90) end,
   '16 kutu · rastgele yarışmacı · otomatik bankacı · büyük ödül 50.000 ₺',
   p_bas,45,p_sunucu);
 i:=(v->>'id')::bigint;
 update oyun.tv_program set tur='kutunu_sec' where id=i returning * into pr;
 select array_agg(z.deger order by pg_catalog.gen_random_uuid()) into d
 from unnest(array[0,100,250,500,1000,1500,2000,3000,5000,7500,10000,12500,15000,20000,30000,50000]::numeric[]) z(deger);
 insert into oyun.tv_kutu_oyun(program_id,kanal_id,degerler,basvuru_baslangic,son_hamle)
  values(i,k.id,d,t,t);
 update oyun.tv_kanal set kasa=kasa-50000 where id=k.id;
 insert into oyun.tv_hareket(kanal_id,zaman,tutar,tur,aciklama)
   values(k.id,t,-50000,'odul',format('%s · Kutunu Seç bloke edilen büyük ödül',pr.baslik));
 perform oyun.tv_sinyal(i);
 return public.tv_detay(i);
end $f$;

create or replace function public.tv_kutu_durum(p_program bigint) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller:=oyun.profilim(); pr oyun.tv_program; g oyun.tv_kutu_oyun; k oyun.tv_kanal; t timestamptz:=oyun.simdi();
begin
 perform oyun.tv_program_guncelle(p_program);
 select * into g from oyun.tv_kutu_oyun where program_id=p_program;
 select * into pr from oyun.tv_program where id=p_program;
 if pr.id is null or pr.tur<>'kutunu_sec' or g.program_id is null then raise exception 'Kutunu Seç programı bulunamadı.'; end if;
 select * into k from oyun.tv_kanal where id=g.kanal_id;
 return jsonb_build_object(
 'program',p_program,'kanal',k.ad,'program_durum',pr.durum,'durum',g.durum,'simdi',t,
 'bas',pr.bas,'bit',pr.bit,'buyuk_odul',g.teminat,
 'basvuru_sayisi',(select count(*) from oyun.tv_kutu_basvuru b where b.program_id=p_program),
 'basvurdum',exists(select 1 from oyun.tv_kutu_basvuru b where b.program_id=p_program and b.user_id=p.id),
 'uygun',oyun.tv_kutu_uygun(g.kanal_id,p.id) and p.id<>pr.sunucu and p.id<>pr.olusturan,
 'yonetici',p.id=k.sahip or p.id=pr.sunucu,'benim_siram',p.id=g.yarismaci,
 'yarismaci',case when g.yarismaci is not null then oyun.kad(g.yarismaci) end,
 'secilen',g.secilen,'acilan_sayi',coalesce(array_length(g.acilan,1),0),
 'teklif',g.teklif,'teklif_sayisi',g.teklif_sayisi,
 'asil_odul',g.asil_odul,'odenen',g.odenen,'iade',g.iade,
 'basvurular',(select coalesce(jsonb_agg(s.kad order by s.zaman),'[]'::jsonb) from
     (select pp.kad,b.zaman from oyun.tv_kutu_basvuru b
       join oyun.profiller pp on pp.id=b.user_id where b.program_id=p_program order by b.zaman limit 20) s),
 'kutular',(select jsonb_agg(jsonb_build_object(
     'no',i,'acik',i=any(g.acilan),'benim',i=g.secilen,
     'tutar',case when i=any(g.acilan) or g.durum='bitti' then g.degerler[i] end)
    order by i) from generate_series(1,16) i),
 'kalan_oduller',(select jsonb_agg(g.degerler[i] order by g.degerler[i] desc)
    from generate_series(1,16) i where not i=any(g.acilan))
 );
end $f$;

create or replace function public.tv_kutu_basvur(p_program bigint) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller:=oyun.profilim(); pr oyun.tv_program; g oyun.tv_kutu_oyun; t timestamptz:=oyun.simdi();
begin
 perform oyun.tv_program_guncelle(p_program);
 select * into g from oyun.tv_kutu_oyun where program_id=p_program for update;
 select * into pr from oyun.tv_program where id=p_program;
 if g.program_id is null or pr.tur<>'kutunu_sec' or g.durum<>'basvuru'
   or pr.durum not in ('planli','canli') or pr.bit<=t then raise exception 'Yarışma başvuruları kapalı.'; end if;
 if not oyun.tv_kutu_uygun(g.kanal_id,p.id) or p.id in (pr.sunucu,pr.olusturan) then
   raise exception 'Başvuru için 7 günlük hesap, aktif üyelik ve ödül uygunluğu şartları sağlanmalı.'; end if;
 insert into oyun.tv_kutu_basvuru(program_id,user_id,zaman)
   values(p_program,p.id,t) on conflict(program_id,user_id) do nothing;
 if not found then raise exception 'Başvurun zaten kayıtlı.'; end if;
 insert into oyun.tv_kutu_hareket(program_id,user_id,islem,zaman) values(p_program,p.id,'basvuru',t);
 perform oyun.tv_sinyal(p_program);
 return public.tv_kutu_durum(p_program);
end $f$;

create or replace function public.tv_kutu_baslat(p_program bigint) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller:=oyun.profilim(); pr oyun.tv_program; g oyun.tv_kutu_oyun; k oyun.tv_kanal; t timestamptz:=oyun.simdi(); u uuid; say integer;
begin
 perform oyun.tv_program_guncelle(p_program);
 select * into g from oyun.tv_kutu_oyun where program_id=p_program for update;
 select * into pr from oyun.tv_program where id=p_program;
 select * into k from oyun.tv_kanal where id=g.kanal_id;
 if g.program_id is null or g.durum<>'basvuru' or pr.durum<>'canli' or pr.bit<=t then raise exception 'Yarışma başlatılamaz.'; end if;
 if p.id<>pr.sunucu and p.id<>k.sahip then raise exception 'Yarışmayı kanal sahibi veya sunucu başlatabilir.'; end if;
 select count(*) into say from oyun.tv_kutu_basvuru b
 where b.program_id=p_program and b.user_id<>pr.sunucu and b.user_id<>pr.olusturan
   and oyun.tv_kutu_uygun(g.kanal_id,b.user_id);
 if say<5 then raise exception 'Başlamak için en az 5 uygun yarışmacı başvurusu gerekir (şu an %).',say; end if;
 select b.user_id into u from oyun.tv_kutu_basvuru b
 where b.program_id=p_program and b.user_id<>pr.sunucu and b.user_id<>pr.olusturan
   and oyun.tv_kutu_uygun(g.kanal_id,b.user_id)
 order by pg_catalog.gen_random_uuid() limit 1;
 if u is null then raise exception 'Uygun yarışmacı bulunamadı.'; end if;
 update oyun.tv_kutu_oyun set durum='secim',yarismaci=u,baslangic=t,son_hamle=t where program_id=p_program;
 insert into oyun.tv_kutu_hareket(program_id,user_id,islem,zaman) values(p_program,u,'rastgele_secim',t);
 insert into oyun.tv_mesaj(program_id,user_id,rol,metin,zaman)
   values(p_program,u,'sistem',format('Kutunu Seç yarışmacısı rastgele belirlendi: %s. Şimdi bir kutu seç!',oyun.kad(u)),t);
 perform oyun.bildir(u,format('Tebrikler! %s kanalındaki Kutunu Seç yarışmasına sen seçildin. TV stüdyosuna gir ve ilk kutunu seç.',k.ad),t);
 perform oyun.tv_sinyal(p_program);
 return public.tv_kutu_durum(p_program);
end $f$;

create or replace function public.tv_kutu_oyna(p_program bigint,p_islem text,p_kutu integer default null)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller:=oyun.profilim(); g oyun.tv_kutu_oyun; pr oyun.tv_program;
 t timestamptz:=oyun.simdi(); n integer; yeni_adet integer; ort numeric; katsayi numeric; teklif numeric; ham_odul numeric; hedef integer;
begin
 perform oyun.tv_program_guncelle(p_program);
 select * into g from oyun.tv_kutu_oyun where program_id=p_program for update;
 select * into pr from oyun.tv_program where id=p_program;
 if g.program_id is null or pr.tur<>'kutunu_sec' then raise exception 'Kutunu Seç oyunu bulunamadı.'; end if;
 if pr.durum<>'canli' or pr.bit<=t then raise exception 'Yarışma yayını sona erdi.'; end if;
 if g.yarismaci is null or g.yarismaci<>p.id then raise exception 'Hamleyi sadece seçilmiş yarışmacı yapabilir.'; end if;
 if not oyun.tv_kutu_uygun(g.kanal_id,p.id) then raise exception 'Yarışmacının ödül uygunluğu kalmadı.'; end if;
 n:=coalesce(array_length(g.acilan,1),0);
 if p_islem='sec' then
   if g.durum<>'secim' or p_kutu not between 1 and 16 then raise exception 'Önce 1-16 arasında kendi kutunu seç.'; end if;
   update oyun.tv_kutu_oyun set secilen=p_kutu,durum='acilis',son_hamle=t where program_id=p_program;
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,kutu,zaman) values(p_program,p.id,'ana_kutu',p_kutu,t);
 elsif p_islem='ac' then
   if g.durum<>'acilis' or p_kutu not between 1 and 16
      or p_kutu=g.secilen or p_kutu=any(g.acilan) or n>=14 then raise exception 'Bu kutu açılamaz.'; end if;
   yeni_adet:=n+1;
   update oyun.tv_kutu_oyun set acilan=array_append(acilan,p_kutu),son_hamle=t where program_id=p_program;
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,kutu,tutar,zaman)
     values(p_program,p.id,'kutu_ac',p_kutu,g.degerler[p_kutu],t);
   if yeni_adet in (5,9,12,14) then
     select avg(g.degerler[i]) into ort from generate_series(1,16) i
       where i<>p_kutu and i<>all(g.acilan);
     katsayi:=case yeni_adet when 5 then 0.55 when 9 then 0.68 when 12 then 0.80 else 0.90 end;
     teklif:=least(50000,greatest(0,round(ort*katsayi/50)*50));
     update oyun.tv_kutu_oyun set durum='teklif',teklif=teklif,teklif_sayisi=teklif_sayisi+1 where program_id=p_program;
     insert into oyun.tv_kutu_hareket(program_id,user_id,islem,tutar,zaman)
       values(p_program,p.id,'bankaci_teklif',teklif,t);
   end if;
 elsif p_islem='kabul' then
   if g.durum<>'teklif' then raise exception 'Kabul edilecek bankacı teklifi yok.'; end if;
   perform oyun.tv_kutu_odeme(p_program,g.teklif,'bankacı teklifi kabul edildi');
 elsif p_islem='devam' then
   if g.durum<>'teklif' then raise exception 'Önce bankacı teklifini bekle.'; end if;
   update oyun.tv_kutu_oyun set durum=case when n=14 then 'final' else 'acilis' end,
     teklif=null,son_hamle=t where program_id=p_program;
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,zaman) values(p_program,p.id,'devam',t);
 elsif p_islem in ('tut','degistir') then
   if g.durum<>'final' or n<>14 then raise exception 'Final aşamasına henüz gelinmedi.'; end if;
   hedef:=g.secilen;
   if p_islem='degistir' then
     select i into hedef from generate_series(1,16) i where i<>g.secilen and i<>all(g.acilan) limit 1;
   end if;
   if hedef is null then raise exception 'Final kutusu bulunamadı.'; end if;
   ham_odul:=g.degerler[hedef];
   insert into oyun.tv_kutu_hareket(program_id,user_id,islem,kutu,tutar,zaman)
       values(p_program,p.id,p_islem,hedef,ham_odul,t);
   perform oyun.tv_kutu_odeme(p_program,ham_odul,
      case when p_islem='degistir' then 'finalde kutu değiştirildi' else 'finalde kendi kutusu seçildi' end);
 else raise exception 'Bilinmeyen yarışma hamlesi.'; end if;
 perform oyun.tv_sinyal(p_program);
 return public.tv_kutu_durum(p_program);
end $f$;

-- Yeni RPC sadece hesap sahibi ile ve yalnız sunucuda çalışır; özel diziye doğrudan erişim yasaktır.
revoke all on function public.tv_kutu_program_ac(bigint,text,timestamptz,text),
 public.tv_kutu_durum(bigint),public.tv_kutu_basvur(bigint),
 public.tv_kutu_baslat(bigint),public.tv_kutu_oyna(bigint,text,integer)
 from public,anon;
grant execute on function public.tv_kutu_program_ac(bigint,text,timestamptz,text),
 public.tv_kutu_durum(bigint),public.tv_kutu_basvur(bigint),
 public.tv_kutu_baslat(bigint),public.tv_kutu_oyna(bigint,text,integer)
 to authenticated,service_role;
