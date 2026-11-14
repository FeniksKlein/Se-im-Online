-- 2026.11.15-2 · Görev devri koruması (canlıda 15 Kasım'da uygulandı; tek seferlik onarımlar migrations/20261115_*.sql)
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


-- KALICI KURAL (15 Kasım 2026): Görevi biten yürütme, yeni hükümetin Hazine'yi
-- kullanmasını engelleyemez.
-- 1) Genel seçim süreci boyunca (adaylıktan yeni seçilenlerin göreve
--    başlamasına kadar) Hazine'den Varlık Fonu'na aktarım yapılamaz.
-- 2) Fondan çekimdeki 6 saat bekleme ve 7 günlük tavan, yalnız görevdeki
--    Cumhurbaşkanı/Başbakanın KENDİ görev süresindeki çekimlerine göre işler.
--    Selefin çekimleri halefin hakkını tüketmez.
-- Olay: 14 Kasım 23.47'de görevi bitmek üzere olan CB Hazine'nin tamamını
-- (958 milyar ₺) fona yatırıp 1 milyar çekerek beklemeyi başlattı.

-- Görevdeki yürütme başkanının göreve başlama anı.
create or replace function oyun.yurutme_bas() returns timestamptz
language sql stable set search_path='' as $$
  select case when oyun.hukumet_sistemi()=1
    then (select bas from oyun.hukumetler where durum='gorevde' and bit is null order by bas desc limit 1)
    else (select bas from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1)
  end
$$;

create or replace function public.varlik_fonu_aktar(p_yon text, p_tutar numeric, p_gerekce text default null::text)
 returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v oyun.varlik_fonu; x numeric; cek numeric; hz numeric; gr text; b text;
        sistem text := case when oyun.hukumet_sistemi() = 1 then 'Başbakan' else 'Cumhurbaşkanı' end;
        gb timestamptz := coalesce(oyun.yurutme_bas(), '-infinity'::timestamptz);
begin
  if p.id is null or p.id is distinct from oyun.yurutme_user() then
    raise exception 'Varlık Fonu aktarımına yalnız görevdeki % karar verir.', lower(sistem);
  end if;
  if coalesce(p_yon, '') not in ('cek', 'yatir') then raise exception 'Geçersiz işlem.'; end if;
  if p_yon = 'yatir' and oyun.genel_secim_sureci_aktif(t) then
    raise exception 'Genel seçim süreci devam ediyor. Yeni seçilenler göreve başlayana kadar Hazine''den Varlık Fonu''na aktarım yapılamaz.';
  end if;
  x := round(coalesce(p_tutar, 0), 1);
  if x < 0.1 then raise exception 'Tutar en az 0,1 milyar ₺ (100 milyon ₺) olmalı.'; end if;
  gr := nullif(btrim(coalesce(p_gerekce, '')), '');
  if gr is not null then gr := oyun.metin_temizle(gr, 1500); end if;
  perform pg_advisory_xact_lock(920158, 1);
  select * into v from oyun.varlik_fonu where id = 1 for update;
  if p_yon = 'cek' and exists (select 1 from oyun.varlik_fonu_hareket h where h.tur = 'cek'
       and h.user_id = p.id and h.zaman >= gb and h.zaman > t - interval '6 hours') then
    raise exception 'Varlık Fonu''ndan çekim 6 saatte bir yapılabilir. Hazine''den fona iade/yatırım için bekleme yoktur.';
  end if;
  if p_yon = 'cek' then
    select coalesce(sum(h.tutar), 0) into cek from oyun.varlik_fonu_hareket h
     where h.tur = 'cek' and h.user_id = p.id and h.zaman >= gb and h.zaman > t - make_interval(days => v.aktarim_gun);
    if cek + x > v.aktarim_tavan then
      raise exception 'Varlık Fonu''ndan % günde en çok % milyar ₺ çekilebilir; kalan hak % milyar ₺.',
        v.aktarim_gun, oyun.bm_sayi(v.aktarim_tavan, 0), oyun.bm_sayi(greatest(0, v.aktarim_tavan - cek), 1);
    end if;
    if v.bakiye < x then raise exception 'Fonda yeterli varlık yok.'; end if;
    update oyun.varlik_fonu set bakiye = bakiye - x where id = 1;
    insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama, user_id)
    values (t, x, v.bakiye - x, 'cek', coalesce(gr, 'Hazine''ye aktarım'), p.id);
    perform oyun.hazine_kaydet('vf_aktarim', x, 'Varlık Fonu''ndan Hazine''ye aktarım');
    b := format('Türkiye Varlık Fonu''ndan Hazine''ye %s Milyar ₺ Aktarılması Hakkında Karar', oyun.bm_sayi(x, 1));
  else
    select u.hazine into hz from oyun.ulke u where u.id = 1;
    if hz < x then raise exception 'Hazine''de yeterli nakit yok (% milyar ₺ var).', oyun.bm_sayi(hz, 1); end if;
    perform oyun.hazine_kaydet('vf_aktarim', -x, 'Hazine''den Varlık Fonu''na aktarım');
    update oyun.varlik_fonu set bakiye = bakiye + x where id = 1;
    insert into oyun.varlik_fonu_hareket(zaman, tutar, bakiye, tur, aciklama, user_id)
    values (t, x, v.bakiye + x, 'yatir', coalesce(gr, 'Bütçe fazlası fona aktarıldı'), p.id);
    b := format('Hazine''den Türkiye Varlık Fonu''na %s Milyar ₺ Aktarılması Hakkında Karar', oyun.bm_sayi(x, 1));
  end if;
  perform oyun.gazete_ekle('kararname', b,
    coalesce(gr || ' ', '') || format('Aktarım finansman işlemidir; bütçe geliri ya da gideri sayılmaz. Fonda kalan varlık %s milyar ₺.',
      oyun.bm_sayi((select f.bakiye from oyun.varlik_fonu f where f.id = 1), 1)), null, t);
  perform oyun.olay('ekonomi', format('%s %s: %s', sistem, p.kad, b), null, p.parti_id, t);
  return public.butce_raporu(7);
end $function$;

