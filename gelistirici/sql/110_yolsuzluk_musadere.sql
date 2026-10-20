-- Yolsuzluk/rusvet dosyalarinda kesinlesmis mali musadere.
-- Canli oyuncu verilerini sifirlamaz; mahkeme karari kesinlesmeden para almaz.

alter table oyun.adliye_davalar drop constraint if exists adliye_davalar_karar_check;
alter table oyun.adliye_davalar add constraint adliye_davalar_karar_check check (karar in
 ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur',
  'para_10b','para_50b','aday_yasagi','parti_para','dusme','tazminat','musadere'));

alter table oyun.adliye_karar_oy add column if not exists musadere_tutar numeric;
alter table oyun.adliye_karar_oy add column if not exists musadere_sorumlu uuid references oyun.profiller(id);
alter table oyun.adliye_karar_oy add column if not exists musadere_sirket bigint references oyun.sirketler(id);
alter table oyun.adliye_karar_oy add constraint adliye_musadere_oy_check check
 ((karar = 'musadere' and musadere_tutar > 0 and musadere_tutar <= 1000000000000
     and musadere_tutar = trunc(musadere_tutar) and musadere_sorumlu is not null)
  or (karar <> 'musadere' and musadere_tutar is null and musadere_sorumlu is null and musadere_sirket is null));

create table if not exists oyun.adliye_musadere (
 dava_id bigint primary key references oyun.adliye_davalar(id),
 sorumlu uuid not null references oyun.profiller(id),
 sirket_id bigint references oyun.sirketler(id),
 tutar numeric not null check(tutar > 0 and tutar = trunc(tutar)),
 tahsil numeric not null default 0 check(tahsil >= 0 and tahsil <= tutar),
 aciklama text not null,
 kayit_at timestamptz not null default now(),
 son_tahsil_at timestamptz,
 tamam_at timestamptz
);
create index if not exists adliye_musadere_bekleyen on oyun.adliye_musadere(dava_id) where tamam_at is null;
alter table oyun.adliye_musadere enable row level security;
revoke all on oyun.adliye_musadere from public, anon, authenticated;

-- Tek transaction: izlenebilir sirket kaynagi, sonra oyuncu cuzdani, sonra vadesiz banka.
-- Eksik tutar kapanmaz; sonraki kazancindan 5 dakikada bir tahsil edilir.
create or replace function oyun.adliye_musadere_tahsil(p_dava bigint, t timestamptz)
returns numeric language plpgsql set search_path = '' as $fn$
declare a oyun.adliye_musadere; d oyun.adliye_davalar;
 kalan numeric; mevcut numeric; al numeric; toplam numeric := 0;
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
    values(a.sirket_id,t,-al,format('Adliye #%s: kanitlanmis yolsuzluk parasinin Hazineye iadesi',p_dava));
   toplam:=toplam+al; kalan:=kalan-al;
  end if;
 end if;
 if kalan>0 then
  perform oyun.cuzdanim(a.sorumlu);
  select greatest(0,coalesce(para,0)) into mevcut from oyun.cuzdan where user_id=a.sorumlu for update;
  al:=least(kalan,coalesce(mevcut,0));
  if al>0 then
   perform oyun.para_islem(a.sorumlu,-al,'adliye',format('Adliye #%s yolsuzluk parasinin Hazineye iadesi',p_dava),t);
   toplam:=toplam+al; kalan:=kalan-al;
  end if;
 end if;
 if kalan>0 then
  select greatest(0,coalesce(vadesiz,0)) into mevcut from oyun.banka_musteri where user_id=a.sorumlu for update;
  al:=least(kalan,coalesce(mevcut,0));
  if al>0 then
   update oyun.banka_musteri set vadesiz=vadesiz-al where user_id=a.sorumlu;
   insert into oyun.banka_hareket(user_id,zaman,hesap,tutar,aciklama)
    values(a.sorumlu,t,'vadesiz',-al,format('Adliye #%s: Hazineye musadere',p_dava));
   toplam:=toplam+al; kalan:=kalan-al;
  end if;
 end if;
 if toplam>0 then
  update oyun.ulke set hazine=hazine+toplam where id=1;
  if not found then raise exception 'Hazine kaydi bulunamadi; tahsilat geri alindi.'; end if;
  update oyun.adliye_musadere set tahsil=tahsil+toplam,son_tahsil_at=t,
    tamam_at=case when tahsil+toplam>=tutar then t else null end where dava_id=p_dava;
  perform oyun.bildir(a.sorumlu,
   format('Adliye #%s: %s TL kanitlanan yolsuzluk parasi Hazineye aktarildi. Kalan: %s TL.',
   p_dava,toplam,kalan),t);
 end if;
 return toplam;
end $fn$;

create or replace function oyun.adliye_musadere_tick()
returns integer language plpgsql set search_path = '' as $fn$
declare r record; n integer:=0;
begin
 for r in select a.dava_id from oyun.adliye_musadere a
  join oyun.adliye_davalar d on d.id=a.dava_id
  where a.tahsil<a.tutar and d.kesin and d.karar in ('musadere','uyari')
    and d.af_at is null order by a.dava_id
 loop
  if oyun.adliye_musadere_tahsil(r.dava_id,oyun.simdi())>0 then n:=n+1; end if;
 end loop;
 return n;
end $fn$;

-- Uyelere sadece davalisi belli ve belgelenmis tutari bulunan davalarda musadere oyu.
create or replace function public.adliye_musadere_oy
 (p_dava bigint,p_tutar numeric,p_sorumlu_kad text,p_sirket_id bigint,p_gerekce text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 hedef oyun.profiller; t timestamptz:=oyun.simdi(); cikti boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' or d.tur not in ('yolsuzluk','rusvet','usulsuzluk','dolandiricilik') then
  raise exception 'Bu dosyada mali musadere oyu kullanilamaz.'; end if;
 if not oyun.mahkeme_uyesi_mi(p.id) or not p.id=any(oyun.dava_heyeti(d)) then
  raise exception 'Yalniz gorevli ve tarafsiz mahkeme uyesi oy verebilir.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma suresini bekleyin.'; end if;
 if p_tutar is null or p_tutar<=0 or p_tutar>1000000000000 or p_tutar<>trunc(p_tutar) then
  raise exception 'Kaniti bulunan musadere miktarini tam sayi TL olarak yazin.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then
  raise exception 'Somut delil ve hesap hareketleriyle gerekce 20-2000 karakter olmali.'; end if;
 select * into hedef from oyun.profiller where lower(kad)=lower(trim(coalesce(p_sorumlu_kad,''))) and not yasakli;
 if hedef.id is null then raise exception 'Sorumlu oyuncu bulunamadi.'; end if;
 if d.davali is not null and hedef.id<>d.davali then
  raise exception 'Bireysel davada sadece davali oyuncu sorumlu tutulabilir.'; end if;
 if p_sirket_id is not null and not exists
   (select 1 from oyun.sirketler s where s.id=p_sirket_id and
     (s.kurucu=hedef.id or s.yonetici=hedef.id or exists
       (select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=hedef.id))) then
  raise exception 'Belirtilen sirketin sorumlu oyuncuyla ortaklik/yonetim bagi yok.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,gerekce,zaman,musadere_tutar,musadere_sorumlu,musadere_sirket)
 values(d.id,p.id,'musadere',trim(p_gerekce),t,p_tutar,hedef.id,p_sirket_id)
 on conflict(dava_id,uye) do update set karar='musadere',gerekce=excluded.gerekce,
  zaman=excluded.zaman,tazminat_tutar=null,musadere_tutar=excluded.musadere_tutar,
  musadere_sorumlu=excluded.musadere_sorumlu,musadere_sirket=excluded.musadere_sirket;
 cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',cikti,'tutar',p_tutar,'sorumlu',hedef.kad);
end $fn$;

-- Uyari, beraat veya tazminat oyu ile musadere oyu degistirildiginde eski alanlari temizle.
create or replace function public.adliye_oy_ver(p_dava bigint,p_karar text,p_gerekce text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 t timestamptz:=oyun.simdi(); karar_cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalniz Yuksek Mahkeme uyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Acik bir dava bulunamadi.'; end if;
 if not p.id=any(oyun.dava_heyeti(d)) then raise exception 'Yargic kendi davasinda oy kullanamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma suresinin dolmasini bekleyin.'; end if;
 if p_karar not in ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h',
  'vekillik_dusur','para_10b','para_50b','aday_yasagi','parti_para') then raise exception 'Gecersiz karar.'; end if;
 if d.davali is null and p_karar not in ('beraat','uyari','parti_para') then
  raise exception 'Partiye yalniz beraat, uyari veya hazine yardimi kesintisi verilebilir.'; end if;
 if d.davali is not null and p_karar='parti_para' then raise exception 'Parti cezasi sadece partiye verilir.'; end if;
 if p_karar='vekillik_dusur' and not exists
   (select 1 from oyun.makamlar where user_id=d.davali and tur='mv' and bit is null) then
  raise exception 'Davalinin aktif milletvekilligi yok.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekceli oy 20-2000 karakter olmali.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,gerekce,zaman)
 values(d.id,p.id,p_karar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar=excluded.karar,gerekce=excluded.gerekce,
  zaman=excluded.zaman,tazminat_tutar=null,musadere_tutar=null,
  musadere_sorumlu=null,musadere_sirket=null;
 karar_cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',karar_cikti);
end $fn$;

create or replace function public.adliye_tazminat_oy(p_dava bigint,p_tutar numeric,p_gerekce text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 t timestamptz:=oyun.simdi(); cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalniz Yuksek Mahkeme uyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' or d.tur<>'tazminat' or d.davali is null then
  raise exception 'Bu dosyada tazminata hukmedilemez.'; end if;
 if not p.id=any(oyun.dava_heyeti(d)) then raise exception 'Dava tarafi hakim oy kullanamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma suresini bekleyin.'; end if;
 if p_tutar is null or p_tutar<1000 or p_tutar>least(coalesce(d.tazminat_talep,0),500000) or p_tutar<>trunc(p_tutar) then
  raise exception 'Karar tutari 1.000 TL ile davacinin talebi arasinda tam sayi olmali.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekceli oy 20-2000 karakter olmali.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,tazminat_tutar,gerekce,zaman)
 values(d.id,p.id,'tazminat',p_tutar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar='tazminat',tazminat_tutar=excluded.tazminat_tutar,
  gerekce=excluded.gerekce,zaman=excluded.zaman,musadere_tutar=null,musadere_sorumlu=null,musadere_sirket=null;
 cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',cikti,'tutar',p_tutar);
end $fn$;

-- Heyet uyeleri ayni tutar, oyuncu ve kaynakta birlesmeden karar cikmaz.
create or replace function oyun.adliye_oy_say(p_dava bigint,t timestamptz)
returns boolean language plpgsql set search_path = '' as $fn$
declare d oyun.adliye_davalar; heyet uuid[]; r record;
 bitis timestamptz; v_hakim uuid; v_ger text;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.durum<>'acik' then return false; end if;
 heyet:=oyun.dava_heyeti(d);
 if cardinality(heyet)=0 then return false; end if;
 select o.karar,coalesce(o.tazminat_tutar,0) tutar,
  coalesce(o.musadere_tutar,0) musadere_tutar,o.musadere_sorumlu,o.musadere_sirket,
  count(*) n,min(o.zaman) ilk into r from oyun.adliye_karar_oy o
  where o.dava_id=d.id and o.uye=any(heyet)
  group by o.karar,coalesce(o.tazminat_tutar,0),coalesce(o.musadere_tutar,0),o.musadere_sorumlu,o.musadere_sirket
  order by count(*) desc,min(o.zaman) limit 1;
 if r.karar is null or r.n<oyun.cogunluk(cardinality(heyet)) then return false; end if;
 select o.uye,o.gerekce into v_hakim,v_ger from oyun.adliye_karar_oy o
  where o.dava_id=d.id and o.karar=r.karar
   and coalesce(o.tazminat_tutar,0)=r.tutar
   and coalesce(o.musadere_tutar,0)=r.musadere_tutar
   and o.musadere_sorumlu is not distinct from r.musadere_sorumlu
   and o.musadere_sirket is not distinct from r.musadere_sirket
   and o.uye=any(heyet) order by o.zaman limit 1;
 update oyun.adliye_davalar set durum='karar',karar=r.karar,ilk_karar=r.karar,
  gerekce=v_ger,hakim=v_hakim,karar_at=t,
  tazminat_tutar=case when r.karar='tazminat' then r.tutar else null end,
  kesin=false,istinaf_son=t+make_interval(hours=>(select istinaf_saat from oyun.mahkeme_ayar))
  where id=d.id returning * into d;
 if r.karar='musadere' then
  insert into oyun.adliye_musadere(dava_id,sorumlu,sirket_id,tutar,aciklama)
   values(d.id,r.musadere_sorumlu,r.musadere_sirket,r.musadere_tutar,v_ger)
   on conflict(dava_id) do nothing;
 end if;
 bitis:=oyun.adliye_hafif_ceza(d,t);
 update oyun.adliye_davalar set ceza_bitis=bitis where id=d.id;
 perform oyun.bildir(x.id,format('Adliye #%s karari: %s. Istinaf yolu acik.',d.id,r.karar),t)
   from (select d.davaci id union select d.davali where d.davali is not null) x;
 perform oyun.adliye_duyur(v_hakim,
  format('Yuksek Mahkeme #%s: %s davasinda karar "%s" (%s/%s oy). Istinaf yolu acik. #Adliye',
   d.id,d.tur,r.karar,r.n,cardinality(heyet)),array['adliye'],t);
 return true;
end $fn$;

-- Yalniz kesinlesme sonrasi tahsil; normal cezalarin diger etkileri korunur.
create or replace function oyun.adliye_kesinlestir(p_dava bigint,t timestamptz)
returns void language plpgsql set search_path = '' as $fn$
declare d oyun.adliye_davalar; mv bigint; alinan numeric; davaci_kazandi boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.kesin then return; end if;
 if not d.ceza_uygulandi and d.af_at is null then
  if d.karar='vekillik_dusur' and d.davali is not null then
   select id into mv from oyun.makamlar where user_id=d.davali and tur='mv' and bit is null order by bas desc limit 1;
   if mv is not null then
    update oyun.makamlar set bit=t,bitis_neden='Adliye #'||d.id||' karari'
     where user_id=d.davali and bit is null and tur in ('mv','tbmm','bskv','grup_bskv');
   end if;
  elsif d.karar in ('para_10b','para_50b') then
   alinan:=oyun.adliye_tahsil(d.davali,case d.karar when 'para_10b' then 10000 else 50000 end,
    'Adliye #'||d.id||' para cezasi',t);
  elsif d.karar='tazminat' and d.davali is not null then
   alinan:=oyun.adliye_tahsil(d.davali,least(coalesce(d.tazminat_tutar,0),500000),
     'Adliye #'||d.id||' tazminat tahsili',t);
   if alinan>0 then
    perform oyun.para_islem(d.davaci,alinan,'adliye','Adliye #'||d.id||' tazminat odemesi',t);
    update oyun.adliye_davalar set tazminat_odenen=tazminat_odenen+alinan where id=d.id;
   end if;
  elsif d.karar='aday_yasagi' then
   update oyun.profiller set adaylik_yasagi_bitis=greatest(coalesce(adaylik_yasagi_bitis,t),t+interval '30 days')
    where id=d.davali;
  elsif d.karar='parti_para' and d.davali_parti is not null then
   update oyun.partiler set kasa=kasa-least(kasa,25000) where id=d.davali_parti;
  end if;
 end if;
 davaci_kazandi:=d.karar not in ('beraat','dusme');
 if d.harc>0 and d.harc_durum='yatirildi' then
  if d.karar='dusme' or davaci_kazandi then
   perform oyun.para_islem(d.davaci,d.harc,'adliye','Adliye #'||d.id||' harc iadesi',t);
  end if;
  if davaci_kazandi then
   if d.davali is not null then
    perform oyun.adliye_tahsil(d.davali,d.harc,'Adliye #'||d.id||' yargilama harci',t);
   elsif d.davali_parti is not null then
    update oyun.partiler set kasa=kasa-least(kasa,d.harc) where id=d.davali_parti;
   end if;
  end if;
 end if;
 update oyun.adliye_davalar set kesin=true,ceza_uygulandi=true,
  mv_makam_id=coalesce(mv,mv_makam_id),
  harc_durum=case when harc>0 then case when karar='dusme' or davaci_kazandi then 'iade' else 'hazine' end end
  where id=d.id;
 perform oyun.adliye_musadere_tahsil(d.id,t);
 perform oyun.bildir(x.id,format('Adliye #%s karari kesinlesti: %s.',d.id,d.karar),t)
  from (select d.davaci id union select d.davali where d.davali is not null) x;
end $fn$;

create or replace function public.adliye_musadere_durum(p_dava bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare p oyun.profiller:=oyun.profilim();
begin
 if not exists(select 1 from oyun.adliye_davalar where id=p_dava) then raise exception 'Dava bulunamadi.'; end if;
 return (select jsonb_build_object('tutar',a.tutar,'tahsil',a.tahsil,
  'kalan',a.tutar-a.tahsil,'sorumlu',oyun.kad(a.sorumlu),
  'sirket',s.ad,'kesin',d.kesin,'karar',d.karar,'tamam_at',a.tamam_at)
  from oyun.adliye_musadere a join oyun.adliye_davalar d on d.id=a.dava_id
  left join oyun.sirketler s on s.id=a.sirket_id where a.dava_id=p_dava);
end $fn$;

-- Canli dava kayitlari ve oyuncularin mali bilgileri yalnizca veritabaninda tutulur.

revoke all on function oyun.adliye_musadere_tahsil(bigint,timestamptz),
 oyun.adliye_musadere_tick(),oyun.adliye_oy_say(bigint,timestamptz),
 oyun.adliye_kesinlestir(bigint,timestamptz) from public,anon,authenticated;
revoke all on function public.adliye_musadere_oy(bigint,numeric,text,bigint,text),
 public.adliye_musadere_durum(bigint) from public,anon;
grant execute on function public.adliye_musadere_oy(bigint,numeric,text,bigint,text),
 public.adliye_musadere_durum(bigint) to authenticated;

-- Mevcut yargi zamanlayicisina dokunmadan tahsil borclarini takip et.
select cron.schedule('adliye-musadere-tahsil','*/5 * * * *','select oyun.adliye_musadere_tick()');
