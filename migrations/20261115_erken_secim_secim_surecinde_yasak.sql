-- KALICI KURAL (15 Kasım 2026): Genel seçim süreci başladıktan sonra (adaylık
-- başvurusunun açılmasından yeni seçilenlerin göreve başlamasına kadar) ne
-- Cumhurbaşkanı ne TBMM erken seçim kararı alabilir. Görevi bitmesi kesinleşmiş
-- Cumhurbaşkanı, yeni seçilenin görev süresini erken seçimle kısaltamaz.
--
-- Olay: 14 Kasım seçimi 22.00'de bitti, yeni CB 15 Kasım 00.00'da göreve
-- başlayacaktı. Eski kontrol yalnız oy verme saatlerine baktığı için görevi
-- biten CB 23.29'da erken seçim kararı alabildi ve 17 Kasım'a yeni takvim açıldı.
-- Bu dosya hem kuralı ekler hem de o hatalı takvimi iptal eder.

-- Genel seçim süreci (MV/CB, ön seçimler ve 2. tur) devam ediyor mu?
-- Başlangıç: adaylık başvurusunun açılması (yoksa oy başlangıcı).
-- Bitiş: seçilenlerin göreve başlaması (yoksa oy bitişi). İptal edilmiş
-- takvimler sayılmaz.
create or replace function oyun.genel_secim_sureci_aktif(t timestamptz) returns boolean
language sql stable set search_path='' as $$
  select exists(
    select 1 from oyun.secimler
     where tur in ('mv_on','mv','cb_on','cb','cb2')
       and coalesce(sonuc->>'iptal','')=''
       and coalesce(basvuru_bas,oy_bas)<=t
       and t<coalesce(goreve_bas,oy_bit,basvuru_bit)
  );
$$;

-- Son güvenlik ağı: hangi yoldan çağrılırsa çağrılsın süreç içinde yeni
-- erken seçim takvimi oluşmaz.
create or replace function oyun.erken_genel_secim_olustur(t timestamp with time zone, p_teklif bigint)
 returns text language plpgsql set search_path to '' as $function$
declare
  ilk date; ongun date; secgun date; dm text; eski text; eski_oy timestamptz;
  karar_sahibi text := case when p_teklif < 0 then 'Cumhurbaşkanı' else 'TBMM' end;
begin
  if oyun.genel_secim_sureci_aktif(t) then
    raise exception 'Genel seçim süreci devam ediyor; yeni seçilenler göreve başlamadan erken seçim kararı alınamaz.';
  end if;
  ilk:=(t at time zone 'Europe/Istanbul')::date;
  if ilk between date '2026-10-17' and date '2026-10-19'
     and t+interval '8 hours'<=oyun.tr_an(date '2026-10-20',8) then
    ongun:=date '2026-10-20';
    secgun:=date '2026-10-21';
  else
    ilk:=oyun.secim_ilk_oy_gunu(t); -- önce adaylık (en az 24 saat), sonra ön seçim, sonra seçim
    ongun:=ilk;
    secgun:=ilk+1;
  end if;
  dm:='erken-genel-'||p_teklif||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
  select donem,oy_bas into eski,eski_oy from oyun.secimler
  where tur='mv' and not ara and durum='bekliyor' and oy_bas>t order by oy_bas limit 1;

  -- Yakın olağan seçim öne alınmıyor veya ertelenmiyor; adaylıklar korunur.
  if eski is not null and eski_oy<=oyun.tr_an(secgun,8)+interval '7 days' then
    perform oyun.olay('secim',format('%s erken seçim kararı aldı. Genel seçim zaten %s günü yapılacağı için takvim değişmedi; başvurular geçerli.',
      karar_sahibi,to_char(eski_oy at time zone 'Europe/Istanbul','DD.MM.YYYY')),null,null,t);
    return eski;
  end if;
  if eski is not null then
    update oyun.secimler set durum='tamam',
      sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','erken_secim')
    where donem=eski and durum='bekliyor' and tur in ('mv_on','mv','cb_on','cb','cb2');
  end if;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
    ('mv_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
    ('mv',dm,null,null,oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  if oyun.hukumet_sistemi()=0 then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
      ('cb_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
      ('cb',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  end if;
  perform oyun.olay('secim',format('%s erken seçim kararı aldı. Erken genel seçim %s günü yapılacak.',
    karar_sahibi,to_char(secgun,'DD.MM.YYYY')),null,null,t);
  return dm;
end $function$;

-- Cumhurbaşkanı kararı: süreç içinde açık bir hata mesajıyla reddedilir.
create or replace function public.cb_erken_secim_karar(p_gerekce text) returns jsonb
language plpgsql security definer set search_path='' as $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  g text; karar_id bigint; dm text; degisti boolean; secim_bas timestamptz;
begin
  perform 1 from oyun.ayarlar where id=1 for update;
  if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null) then
    raise exception 'Erken seçime yalnızca görevdeki Cumhurbaşkanı karar verebilir.';
  end if;
  if exists(select 1 from oyun.secimler where ara and ara_neden='erken_secim' and durum='bekliyor') then
    raise exception 'Önceden kararlaştırılmış bir erken seçim takvimi zaten var.';
  end if;
  if oyun.genel_secim_sureci_aktif(t) then
    raise exception 'Genel seçim süreci başladı. Adaylıktan yeni seçilenlerin göreve başlamasına kadar erken seçim kararı alınamaz.';
  end if;
  if exists(select 1 from oyun.cb_erken_secim_kararlari where karar_at>t-interval '24 hours') then
    raise exception 'Cumhurbaşkanı 24 saat içinde yeniden erken seçim kararı alamaz.';
  end if;
  g:=oyun.metin_temizle(coalesce(p_gerekce,''),3000);
  if length(btrim(g))<10 then raise exception 'Karar gerekçesi en az 10 karakter olmalı.'; end if;

  insert into oyun.cb_erken_secim_kararlari(cumhurbaskani,gerekce,karar_at,secim_donem,takvim_degisti)
  values(p.id,g,t,'beklemede',false) returning id into karar_id;
  dm:=oyun.erken_genel_secim_olustur(t,-karar_id);
  degisti:=left(dm,12)='erken-genel-';
  update oyun.cb_erken_secim_kararlari set secim_donem=dm,takvim_degisti=degisti where id=karar_id;
  select oy_bas into secim_bas from oyun.secimler where tur='mv' and donem=dm limit 1;
  return jsonb_build_object('donem',dm,'takvim_degisti',degisti,'oy_bas',secim_bas,
    'mesaj',case when degisti then 'Cumhurbaşkanının erken seçim kararı alındı; seçim takvimi açıldı.'
      else 'Karar kaydedildi; yakın olağan seçim tarihi ve mevcut adaylıklar korundu.' end);
end $function$;
revoke all on function public.cb_erken_secim_karar(text) from public, anon;
grant execute on function public.cb_erken_secim_karar(text) to authenticated;

-- TBMM önerisi: süreç içinde yeni öneri başlatılamaz.
create or replace function public.erken_secim_teklif(p_gerekce text) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pid bigint; iktidar boolean:=false; g text;
begin
  select id into pid from oyun.partiler where gb=p.id and not kapali limit 1;
  if pid is null then raise exception 'Erken seçim kararı/çağrısını yalnızca parti genel başkanı başlatabilir.'; end if;
  if oyun.aktif_vekil_sayi()=0 then raise exception 'Görevde TBMM yok.'; end if;
  if exists(select 1 from oyun.erken_secim_teklifleri where durum='oylamada') then raise exception 'Zaten Meclis gündeminde bir erken seçim önerisi var.'; end if;
  if exists(select 1 from oyun.secimler where ara and ara_neden='erken_secim' and durum='bekliyor') then raise exception 'Erken seçim takvimi zaten açık.'; end if;
  if oyun.genel_secim_sureci_aktif(t) then
    raise exception 'Genel seçim süreci başladı. Adaylıktan yeni seçilenlerin göreve başlamasına kadar erken seçim önerisi verilemez.';
  end if;
  if oyun.hukumet_sistemi()=0 then
    iktidar:=exists(select 1 from oyun.makamlar where tur='cb' and bit is null and parti_id=pid);
  else
    iktidar:=exists(select 1 from oyun.hukumet_partileri hp join oyun.hukumetler h on h.id=hp.hukumet_id
      where h.durum='gorevde' and h.bit is null and hp.parti_id=pid and hp.rol='ortak' and hp.aktif);
  end if;
  g:=oyun.metin_temizle(coalesce(p_gerekce,''),3000);
  if length(btrim(g))<5 then g:='Ülkenin erken seçime gitmesi önerilmektedir.'; end if;
  insert into oyun.erken_secim_teklifleri(teklif_eden,parti_id,tur,gerekce,bas,bit)
  values(p.id,pid,case when iktidar then 'iktidar_karari' else 'muhalefet_cagrisi' end,g,t,t+interval '12 hours');
  perform oyun.olay('secim',format('%s %s başlattı; karar TBMM oylamasında.',p.kad,case when iktidar then 'erken seçim kararı' else 'erken seçim çağrısı' end),null,pid,t);
  return public.siyasi_sistem();
end $function$;

-- Süreç başlamadan önce açılmış bir TBMM oylaması süreç içinde sonuçlanırsa
-- takvim açılmaz; öneri düşer.
create or replace function oyun.erken_secim_sonuc(p_id bigint,t timestamptz) returns void
language plpgsql set search_path='' as $function$
declare x oyun.erken_secim_teklifleri; evet int; hayir int; gerek int; dm text;
begin
  perform 1 from oyun.ayarlar where id=1 for update;
  select * into x from oyun.erken_secim_teklifleri where id=p_id for update;
  if x.id is null or x.durum<>'oylamada' then return; end if;
  if oyun.genel_secim_sureci_aktif(t) then
    update oyun.erken_secim_teklifleri set durum='ret' where id=p_id;
    perform oyun.olay('secim','Erken seçim önerisi düştü: genel seçim süreci başladığı için erken seçim kararı alınamaz.',null,x.parti_id,t);
    return;
  end if;
  select count(*) filter(where oy='kabul'),count(*) filter(where oy='ret')
    into evet,hayir from oyun.erken_secim_oylari where teklif_id=p_id;
  gerek:=oyun.erken_secim_gerekli_oy();
  if evet>=gerek then
    select donem into dm from oyun.secimler where tur='mv' and ara
      and ara_neden='erken_secim' and durum='bekliyor' order by oy_bas limit 1;
    if dm is null then dm:=oyun.erken_genel_secim_olustur(t,p_id); end if;
    update oyun.erken_secim_teklifleri set durum='kabul',secim_donem=dm where id=p_id;
  elsif t>=x.bit then
    update oyun.erken_secim_teklifleri set durum='ret' where id=p_id;
    perform oyun.olay('secim',format('Erken seçim önerisi reddedildi (%s kabul, %s ret; gerekli %s).',
      evet,hayir,gerek),null,x.parti_id,t);
  end if;
end $function$;

alter table oyun.cb_erken_secim_kararlari add column if not exists iptal_neden text;

-- TEK SEFERLİK ONARIM: 14 Kasım 23.29'daki geçersiz kararın takvimini iptal et,
-- harcı iade et, yeni Cumhurbaşkanının normal görev süresini koru.
do $onarim$
declare
  t timestamptz := oyun.simdi();
  d text := 'erken-genel--2-20261114232955';
  a record;
begin
  perform 1 from oyun.ayarlar where id=1 for update;
  if exists(select 1 from oyun.tek_seferlik where anahtar='erken_secim_iptal_20261115') then
    raise notice 'Onarim zaten yapilmis'; return;
  end if;
  insert into oyun.tek_seferlik(anahtar,zaman) values('erken_secim_iptal_20261115',t);

  update oyun.secimler set durum='tamam',
    sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','gecersiz_erken_secim_karari')
   where donem=d and durum='bekliyor';

  update oyun.cb_erken_secim_kararlari set takvim_degisti=false,
    iptal_neden='Genel seçim süreci devam ederken alındığı için geçersiz sayıldı.'
   where secim_donem=d;

  -- Bu takvime yapılan adaylık başvurularının harcını iade et.
  for a in
    select h.id,h.user_id,h.tutar from oyun.hesap_hareket h
     where h.tur='aday' and h.tutar<0 and h.zaman>=timestamptz '2026-11-14 20:29:55+00'
       and h.zaman<timestamptz '2026-11-15 06:00+00'
       and exists(select 1 from oyun.adaylar ad join oyun.secimler s on s.id=ad.secim_id
                   where s.donem=d and ad.user_id=h.user_id)
  loop
    perform oyun.para_islem(a.user_id,-a.tutar,'aday',
      'İptal edilen erken seçim adaylık harcı iadesi',t);
    perform oyun.bildir(a.user_id,
      'Geçersiz erken seçim takvimi iptal edildi; adaylık başvuru harcın iade edildi.',t);
  end loop;

  -- Bir sonraki olağan genel seçim: 1 Ocak 2027 (adaylık Aralık sonunda).
  -- Daha önceki erken seçimlerle iptal edilmiş olan bu olağan takvim yeniden
  -- açılır; böylece yeni CB ve Meclis en az 1 aylık normal görev süresini doldurur.
  update oyun.secimler set durum='bekliyor', sonuc=sonuc-'iptal'
   where donem='2027-01' and tur in ('mv_on','mv','cb_on','cb')
     and durum='tamam' and sonuc->>'iptal'='erken_secim'
     and coalesce(basvuru_bas,oy_bas)>t
     and not exists(select 1 from oyun.secimler x where x.donem='2027-01' and x.durum='sonuclandi');

  perform oyun.olay('secim',
    'Görev süresi biten Cumhurbaşkanının seçim süreci içinde aldığı erken seçim kararı geçersiz sayıldı; 16-17 Kasım takvimi iptal edildi. Yeni Cumhurbaşkanı ve Meclis normal görev süresini sürdürüyor. Sonraki olağan genel seçim 1 Ocak 2027.',
    null,null,t);
  insert into oyun.bildirimler(user_id,zaman,metin)
  select id,t,'16-17 Kasım erken seçim takvimi iptal edildi: görevi biten Cumhurbaşkanı seçim süreci içinde erken seçim kararı alamaz. Sonraki olağan genel seçim 1 Ocak 2027.'
    from oyun.profiller where not yasakli;
end $onarim$;
