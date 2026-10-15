-- Canlıya uygulandı (2026-10-15, Supabase migration ekonomi3_*). Tekrar çalıştırılabilir.
begin;
-- 99c · EKONOMİ 3.0 — şirket değeri, piyasa endeksi, genel kurul, hukuki tür, marka filtresi (2026-10-15)
-- İki kez çalıştırılabilir.

-- 1) Hukuki tür ve profesyonel yönetici
alter table oyun.sirketler add column if not exists tur_hukuki text not null default 'ltd';
alter table oyun.sirketler add column if not exists yonetici uuid references oyun.profiller(id) on delete set null;
do $$ begin
  alter table oyun.sirketler add constraint sirketler_tur_hukuki_ck check (tur_hukuki in ('ltd','as'));
exception when duplicate_object then null; end $$;
update oyun.sirketler set tur_hukuki = 'as' where halka_acik and tur_hukuki <> 'as';

-- Yönetim yetkisi: genel kurulun atadığı yönetici (CEO) ya da en az %50 pay sahibi; atanmış yönetici
-- yoksa eskisi gibi en büyük ortak.
create or replace function oyun.sirket_yonetici_mi(p_sirket bigint, u uuid)
 returns boolean language sql stable set search_path to ''
as $function$
  select case
    when (select yonetici from oyun.sirketler where id = p_sirket) is not null then
      u = (select yonetici from oyun.sirketler where id = p_sirket)
      or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = u and o.pay >= 50)
    else exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = u
                 and (o.pay >= 50 or o.pay >= (select max(pay) from oyun.sirket_ortaklari where sirket_id = p_sirket)))
  end
$function$;

-- Halka arz yalnız anonim şirkette (TTK: borsada işlem görmek için A.Ş. olmak gerekir)
create or replace function oyun.tg_halka_arz_as()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  if (select tur_hukuki from oyun.sirketler where id = new.sirket_id) <> 'as' then
    raise exception 'Halka arz için şirketin anonim şirket (A.Ş.) olması gerekir. Önce şirket karnesinden A.Ş.''ye dönüştür (en az 250.000 ₺ sermaye).';
  end if;
  return new;
end $function$;
create or replace trigger halka_arz_as before insert on oyun.halka_arz for each row execute function oyun.tg_halka_arz_as();

create or replace function public.sirket_as_donustur(p_sirket bigint)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; harc numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket for update;
  if s.id is null or not s.aktif then raise exception 'Şirket bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(s.id, p.id) then raise exception 'Tür değişikliğini şirketin yöneticisi başlatır.'; end if;
  if s.tur_hukuki = 'as' then raise exception 'Şirket zaten anonim şirket.'; end if;
  if s.sermaye < 250000 then raise exception 'Anonim şirket için en az 250.000 ₺ sermaye gerekir (şu an %s ₺). Önce sermaye artır.', oyun.tl(s.sermaye); end if;
  harc := greatest(2500, round(s.sermaye * 0.005));
  if s.kasa < harc then raise exception 'Tescil harcı için şirket kasasında % ₺ gerekli.', oyun.tl(harc); end if;
  update oyun.sirketler set kasa = kasa - harc, tur_hukuki = 'as' where id = s.id;
  update oyun.ulke set hazine = hazine + harc / oyun.pazar_tl_milyar() where id = 1;
  insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
  values (s.id, oyun.simdi(), -harc, 'Anonim şirkete dönüşüm: ticaret sicili tescil harcı', 0, harc, 0);
  perform oyun.olay('ekonomi', format('%s anonim şirkete dönüştü; artık halka arz edilebilir.', s.ad), null, null, oyun.simdi());
  return jsonb_build_object('tamam', true, 'harc', harc);
end $function$;

-- 2) Gerçek şirket ve marka adları kullanılamaz (yalnız yeni kayıt ve ad değişikliğinde)
create or replace function oyun.yasakli_marka(p_ad text)
 returns text language sql immutable set search_path to ''
as $function$
  select m from unnest(array[
    'koç holding','sabancı holding','aselsan','roketsan','tusaş','havelsan','baykar','tüpraş','petkim','erdemir',
    'migros','bim','a101','carrefoursa','turkcell','türk telekom','vodafone','türk hava yolları','thy',
    'pegasus','arçelik','vestel','beko','tofaş','ford','toyota','renault','mercedes','bmw','şişecam','ülker','torku',
    'sütaş','garanti bankası','garanti bbva','iş bankası','akbank','yapı kredi','ziraat bankası','halkbank','vakıfbank','qnb','denizbank',
    'enerjisa','limak','kalyon','kolin','emlak konut','demirören','apple','google','microsoft',
    'nvidia','amazon','tesla','facebook','samsung','coca cola','coca-cola','pepsi','mcdonalds','burger king','starbucks',
    'trendyol','hepsiburada','yemeksepeti','show tv','kanal d','star tv','fox tv','trt','cnn türk','ntv','habertürk',
    'sözcü gazetesi','atv','tv8'
  ]) m
  where lower(translate(coalesce(p_ad,''), 'İIŞĞÜÖÇ', 'iışğüöç')) ~ ('(^|[^[:alnum:]çğıöşü])' || regexp_replace(m, '([.+*?^$(){}|\[\]\\-])', '\\\1', 'g') || '($|[^[:alnum:]çğıöşü])')
  limit 1
$function$;

create or replace function oyun.tg_sirket_ad_kontrol()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare m text;
begin
  if tg_op = 'UPDATE' and new.ad is not distinct from old.ad then return new; end if;
  m := oyun.yasakli_marka(new.ad);
  if m is not null then
    raise exception 'Gerçek bir şirketin ya da markanın adı (%) kullanılamaz. Oyun kurgudur; kendi markanı yarat.', m;
  end if;
  return new;
end $function$;
create or replace trigger sirket_ad_kontrol before insert or update of ad on oyun.sirketler for each row execute function oyun.tg_sirket_ad_kontrol();

-- 3) Şirket değeri
create table if not exists oyun.sirket_deger_gecmis(
  sirket_id bigint not null references oyun.sirketler(id) on delete cascade,
  gun date not null, defter numeric not null, kar7 numeric not null, deger numeric not null,
  piyasa numeric, guncelleme timestamptz not null default now(),
  primary key(sirket_id, gun));
create index if not exists sirket_deger_gecmis_gun on oyun.sirket_deger_gecmis(gun);
create table if not exists oyun.piyasa_endeks(
  gun date primary key, deger numeric not null, onceki numeric, toplam numeric not null,
  sirket_sayisi int not null, kapanis boolean not null default false, guncelleme timestamptz not null default now());
alter table oyun.sirket_deger_gecmis enable row level security;
alter table oyun.piyasa_endeks enable row level security;

create or replace function oyun.sirket_kar7(p_sirket bigint)
 returns numeric language sql stable set search_path to ''
as $function$
  select coalesce((select sum(net) from oyun.eko_gunluk where sirket_id = p_sirket
                    and gun > (now() at time zone 'Europe/Istanbul')::date - 7), 0)
       + coalesce((select sum(net_kar) from oyun.eko_kar_kayit where sirket_id = p_sirket
                    and gun > (now() at time zone 'Europe/Istanbul')::date - 7), 0)
       + coalesce((select sum(tutar) from oyun.sirket_hareket where sirket_id = p_sirket
                    and aciklama like '7 günlük faaliyet (ajans)%' and zaman > now() - interval '7 days'), 0)
$function$;

create or replace function oyun.sirket_defter(p_sirket bigint)
 returns numeric language sql stable set search_path to ''
as $function$
  select greatest(0,
     s.kasa
   + coalesce((select sum(adet * maliyet_birim) from oyun.eko_urun_stok where sirket_id = s.id), 0)
   + coalesce((select sum(fiyat) from oyun.eko_arsalar where sahibi_sirket = s.id), 0)
   + coalesce((select sum(maliyet) from oyun.eko_yapilar where sirket_id = s.id), 0)
   + case when s.sektor = 'banka' then
       coalesce((select sum(kalan) from oyun.oyb_kredi where banka_id = s.id and durum = 'aktif'), 0)
     - coalesce((select sum(round(m.anapara * (1 + m.faiz / 100), 2)) from oyun.banka_mevduat m where m.banka_id = s.id and not m.kapandi), 0)
     else 0 end)
  from oyun.sirketler s where s.id = p_sirket
$function$;

-- Değer = defter değeri + son 7 günün net kârı × 10 (zarar ×3 düşer; değer defterin yarısının altına inmez)
create or replace function oyun.sirket_deger(p_sirket bigint)
 returns numeric language sql stable set search_path to ''
as $function$
  select round(greatest(d * 0.5, d + case when k > 0 then k * 10 else k * 3 end))
  from (select oyun.sirket_defter(p_sirket) d, oyun.sirket_kar7(p_sirket) k) x
$function$;

create or replace function oyun.piyasa_degerle()
 returns numeric language plpgsql security definer set search_path to ''
as $function$
declare g date := (now() at time zone 'Europe/Istanbul')::date; onceki oyun.piyasa_endeks; bugun_t numeric; dun_t numeric; e numeric; n int;
begin
  insert into oyun.sirket_deger_gecmis(sirket_id, gun, defter, kar7, deger, piyasa, guncelleme)
  select s.id, g, oyun.sirket_defter(s.id), oyun.sirket_kar7(s.id), oyun.sirket_deger(s.id),
         case when s.halka_acik then oyun.borsa_son_fiyat(s.id) * 100 end, now()
  from oyun.sirketler s where s.aktif
  on conflict on constraint sirket_deger_gecmis_pkey do update set defter = excluded.defter, kar7 = excluded.kar7,
     deger = excluded.deger, piyasa = excluded.piyasa, guncelleme = excluded.guncelleme;
  select * into onceki from oyun.piyasa_endeks where gun < g order by gun desc limit 1;
  select coalesce(sum(coalesce(piyasa, deger)), 0), count(*) into bugun_t, n from oyun.sirket_deger_gecmis d
    join oyun.sirketler s on s.id = d.sirket_id and s.aktif where d.gun = g;
  if onceki.gun is null then
    e := 1000;
  else
    -- zincirleme endeks: yalnız iki günde de var olan şirketlerin değişimi (yeni şirket endeksi şişirmez)
    select coalesce(sum(coalesce(b.piyasa, b.deger)), 0), coalesce(sum(coalesce(a.piyasa, a.deger)), 0) into bugun_t, dun_t
    from oyun.sirket_deger_gecmis b join oyun.sirket_deger_gecmis a on a.sirket_id = b.sirket_id and a.gun = onceki.gun
    where b.gun = g;
    e := round(onceki.deger * case when dun_t > 0 then bugun_t / dun_t else 1 end, 2);
    select coalesce(sum(coalesce(piyasa, deger)), 0) into bugun_t from oyun.sirket_deger_gecmis where gun = g;
  end if;
  insert into oyun.piyasa_endeks(gun, deger, onceki, toplam, sirket_sayisi, guncelleme)
  values (g, e, onceki.deger, bugun_t, n, now())
  on conflict (gun) do update set deger = excluded.deger, onceki = excluded.onceki, toplam = excluded.toplam,
    sirket_sayisi = excluded.sirket_sayisi, guncelleme = excluded.guncelleme;
  return e;
end $function$;

-- 4) Genel kurul
create table if not exists oyun.genel_kurul(
  id bigserial primary key,
  sirket_id bigint not null references oyun.sirketler(id) on delete cascade,
  tur text not null check (tur in ('temettu','yonetici','ad','tasfiye')),
  baslik text not null, veri jsonb not null default '{}'::jsonb,
  acan uuid not null references oyun.profiller(id),
  bas timestamptz not null default now(), bit timestamptz not null,
  durum text not null default 'acik' check (durum in ('acik','kabul','ret','iptal')),
  evet numeric not null default 0, hayir numeric not null default 0, katilim numeric not null default 0,
  sonuc text, sonuc_at timestamptz);
create unique index if not exists genel_kurul_tek_acik on oyun.genel_kurul(sirket_id, tur) where durum = 'acik';
create table if not exists oyun.genel_kurul_oy(
  kurul_id bigint not null references oyun.genel_kurul(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id),
  oy boolean not null, pay numeric not null, zaman timestamptz not null default now(),
  primary key(kurul_id, user_id));
alter table oyun.genel_kurul enable row level security;
alter table oyun.genel_kurul_oy enable row level security;

create or replace function oyun.genel_kurul_say(p_id bigint)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  update oyun.genel_kurul k set
    evet = coalesce((select sum(o.pay) from oyun.genel_kurul_oy v join oyun.sirket_ortaklari o
                     on o.sirket_id = k.sirket_id and o.user_id = v.user_id where v.kurul_id = k.id and v.oy), 0),
    hayir = coalesce((select sum(o.pay) from oyun.genel_kurul_oy v join oyun.sirket_ortaklari o
                     on o.sirket_id = k.sirket_id and o.user_id = v.user_id where v.kurul_id = k.id and not v.oy), 0)
  where k.id = p_id;
  update oyun.genel_kurul set katilim = evet + hayir where id = p_id;
end $function$;

create or replace function oyun.genel_kurul_kapat(p_id bigint, p_zorla boolean default false)
 returns text language plpgsql security definer set search_path to ''
as $function$
declare k oyun.genel_kurul; s oyun.sirketler; esik numeric; karar text; t timestamptz := oyun.simdi();
  x record; stopaj numeric; brut numeric; u uuid; v_ad text;
begin
  perform oyun.genel_kurul_say(p_id);
  select * into k from oyun.genel_kurul where id = p_id for update;
  if k.id is null or k.durum <> 'acik' then return null; end if;
  esik := case when k.tur = 'tasfiye' then 75 else 50 end;
  -- erken sonuç: evet eşiği aşıldıysa ya da artık aşılamayacaksa
  if k.evet > esik or (k.tur = 'tasfiye' and k.evet >= esik) then karar := 'kabul';
  elsif k.hayir >= 100 - esik then karar := 'ret';
  elsif p_zorla or k.bit <= t then
    karar := case when k.katilim >= 25 and k.evet > k.hayir and (k.tur <> 'tasfiye' or k.evet >= 75 * k.katilim / 100) then 'kabul' else 'ret' end;
  else return null; end if;

  select * into s from oyun.sirketler where id = k.sirket_id for update;
  if karar = 'kabul' and s.aktif then
    if k.tur = 'temettu' then
      brut := least((k.veri->>'tutar')::numeric, greatest(0, s.kasa));
      if brut > 0 then
        update oyun.sirketler set kasa = kasa - brut where id = s.id;
        stopaj := oyun.eko_vergi_tahsil(s.id, 'dagitim', brut, 'genel_kurul_temettu', k.id);
        for x in select * from oyun.sirket_ortaklari where sirket_id = s.id loop
          perform oyun.para_islem(x.user_id, round((brut - stopaj) * x.pay / 100, 2), 'sirket',
            format('%s genel kurul temettüsü (%%%s stopaj kesildi)', s.ad, oyun.eko_vergi_oran('stopaj')), t, round(stopaj * x.pay / 100, 2));
        end loop;
        insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
        values (s.id, t, -brut, format('Genel kurul kararıyla temettü dağıtıldı (#%s)', k.id), 0, 0, brut);
      end if;
      k.sonuc := format('%s ₺ temettü dağıtıldı.', oyun.tl(brut));
    elsif k.tur = 'yonetici' then
      u := (k.veri->>'user')::uuid;
      update oyun.sirketler set yonetici = u where id = s.id;
      perform oyun.bildir(u, format('%s genel kurulu seni şirketin yöneticisi (CEO) olarak atadı. Fiyat, kalite, reklam ve yatırım kararlarını artık sen veriyorsun.', s.ad), t);
      k.sonuc := format('%s yönetici (CEO) olarak atandı.', coalesce(oyun.kad(u), 'Yönetici'));
    elsif k.tur = 'ad' then
      v_ad := k.veri->>'ad';
      begin
        update oyun.sirketler set ad = v_ad where id = s.id;
        k.sonuc := format('Şirketin yeni adı: %s.', v_ad);
      exception when others then
        karar := 'ret'; k.sonuc := 'Ad değişikliği tescil edilemedi: ' || sqlerrm;
      end;
    elsif k.tur = 'tasfiye' then
      for x in select * from oyun.sirket_ortaklari where sirket_id = s.id loop
        if greatest(0, s.kasa) * x.pay / 100 > 0 then
          perform oyun.para_islem(x.user_id, round(greatest(0, s.kasa) * x.pay / 100, 2), 'sirket', format('%s tasfiye payı', s.ad), t);
        end if;
      end loop;
      update oyun.sirketler set aktif = false, kasa = 0, satilik = null, son_islem = t where id = s.id;
      update oyun.borsa_emir set durum = 'iptal' where sirket_id = s.id and durum = 'acik';
      perform oyun.olay('ekonomi', format('%s genel kurul kararıyla tasfiye edildi; kasası ortaklarına dağıtıldı.', s.ad), null, null, t);
      k.sonuc := 'Şirket tasfiye edildi, kasa ortaklara dağıtıldı.';
    end if;
  end if;
  update oyun.genel_kurul set durum = karar, sonuc = coalesce(k.sonuc, case when karar = 'ret' then 'Önerge reddedildi.' end), sonuc_at = t where id = k.id;
  for x in select user_id from oyun.sirket_ortaklari where sirket_id = k.sirket_id loop
    perform oyun.bildir(x.user_id, format('%s genel kurulu: "%s" önergesi %s. %s', s.ad, k.baslik,
      case when karar = 'kabul' then 'kabul edildi' else 'reddedildi' end, coalesce(k.sonuc, '')), t);
  end loop;
  return karar;
end $function$;

create or replace function public.genel_kurul_ac(p_sirket bigint, p_tur text, p_veri jsonb default '{}'::jsonb)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; benim numeric; v_id bigint; baslik text; hedef uuid; t timestamptz := oyun.simdi(); x record; sonuc text;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif then raise exception 'Şirket bulunamadı.'; end if;
  select pay into benim from oyun.sirket_ortaklari where sirket_id = s.id and user_id = p.id;
  if coalesce(benim, 0) < 5 and not oyun.sirket_yonetici_mi(s.id, p.id) then
    raise exception 'Genel kurula önerge vermek için en az %%5 pay sahibi ya da şirketin yöneticisi olmalısın.';
  end if;
  if exists (select 1 from oyun.genel_kurul where sirket_id = s.id and tur = p_tur and durum = 'acik') then
    raise exception 'Bu konuda açık bir önerge zaten var.';
  end if;
  if p_tur = 'temettu' then
    if coalesce((p_veri->>'tutar')::numeric, 0) < 1000 or (p_veri->>'tutar')::numeric > s.kasa * 0.9 then
      raise exception 'Temettü en az 1.000 ₺ ve şirket kasasının en fazla %%90''ı olabilir (kasa %s ₺).', oyun.tl(s.kasa);
    end if;
    baslik := format('%s ₺ temettü dağıtılması', oyun.tl((p_veri->>'tutar')::numeric));
  elsif p_tur = 'yonetici' then
    select id into hedef from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_veri->>'kad', '')));
    if hedef is null then raise exception 'Bu kullanıcı adında oyuncu bulunamadı.'; end if;
    p_veri := jsonb_build_object('user', hedef, 'kad', oyun.kad(hedef));
    baslik := format('%s yönetici (CEO) olarak atansın', oyun.kad(hedef));
  elsif p_tur = 'ad' then
    if char_length(btrim(coalesce(p_veri->>'ad', ''))) not between 3 and 50 then raise exception 'Şirket adı 3-50 karakter olmalı.'; end if;
    if oyun.yasakli_marka(p_veri->>'ad') is not null then raise exception 'Gerçek bir şirketin ya da markanın adı kullanılamaz.'; end if;
    p_veri := jsonb_build_object('ad', btrim(p_veri->>'ad'));
    baslik := format('Şirketin adı "%s" olsun', p_veri->>'ad');
  elsif p_tur = 'tasfiye' then
    p_veri := '{}'::jsonb;
    baslik := 'Şirket tasfiye edilsin, kasa ortaklara dağıtılsın';
  else raise exception 'Geçersiz önerge türü.'; end if;

  insert into oyun.genel_kurul(sirket_id, tur, baslik, veri, acan, bas, bit)
  values (s.id, p_tur, baslik, p_veri, p.id, t, t + interval '24 hours') returning id into v_id;
  if coalesce(benim, 0) > 0 then
    insert into oyun.genel_kurul_oy(kurul_id, user_id, oy, pay) values (v_id, p.id, true, benim);
  end if;
  for x in select user_id from oyun.sirket_ortaklari where sirket_id = s.id and user_id <> p.id loop
    perform oyun.bildir(x.user_id, format('%s genel kuruluna önerge geldi: "%s" (%s). 24 saat içinde oy ver.', s.ad, baslik, p.kad), t);
  end loop;
  sonuc := oyun.genel_kurul_kapat(v_id);
  return jsonb_build_object('id', v_id, 'durum', coalesce(sonuc, 'acik'));
end $function$;

create or replace function public.genel_kurul_oy(p_kurul bigint, p_oy boolean)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); k oyun.genel_kurul; benim numeric; sonuc text;
begin
  select * into k from oyun.genel_kurul where id = p_kurul;
  if k.id is null or k.durum <> 'acik' then raise exception 'Bu önerge oylamaya açık değil.'; end if;
  select pay into benim from oyun.sirket_ortaklari where sirket_id = k.sirket_id and user_id = p.id;
  if coalesce(benim, 0) <= 0 then raise exception 'Genel kurulda yalnız ortaklar oy kullanır.'; end if;
  insert into oyun.genel_kurul_oy(kurul_id, user_id, oy, pay) values (k.id, p.id, p_oy, benim)
  on conflict (kurul_id, user_id) do update set oy = excluded.oy, pay = excluded.pay, zaman = now();
  sonuc := oyun.genel_kurul_kapat(k.id);
  return jsonb_build_object('durum', coalesce(sonuc, 'acik'));
end $function$;

-- 5) Borsa: haftalık net artık günlük faaliyetten
create or replace function oyun.borsa_haftalik_net(p_sirket bigint)
 returns numeric language sql stable set search_path to ''
as $function$
  select case when exists (select 1 from oyun.eko_gunluk where sirket_id = p_sirket)
    then round(oyun.sirket_kar7(p_sirket))
    else coalesce((select round(avg(tutar)) from (select tutar from oyun.sirket_hareket where sirket_id = p_sirket and faaliyet_gelir > 0
      and aciklama like '7 günlük%' order by zaman desc, id desc limit 4) z), 0) end
$function$;

do $$ declare d text; begin
  d := pg_get_functiondef('public.borsa_sirket(bigint)'::regprocedure);
  d := replace(d, $q$'haftalar',coalesce((select jsonb_agg(jsonb_build_object('zaman',h.zaman,'net',h.tutar) order by h.zaman)
       from (select zaman,tutar from oyun.sirket_hareket
         where sirket_id=s.id and faaliyet_gelir>0 and aciklama like '7 günlük%'
         order by zaman desc,id desc limit 8) h),'[]'::jsonb),$q$,
   $q$'haftalar',coalesce((select jsonb_agg(jsonb_build_object('zaman',h.zaman,'net',h.tutar) order by h.zaman)
       from (select zaman,tutar from oyun.sirket_hareket
         where sirket_id=s.id and faaliyet_gelir>0 and aciklama like '7 günlük%'
         union all
         select (date_trunc('week', gun::timestamp) + interval '7 days')::timestamptz, sum(net)
           from oyun.eko_gunluk where sirket_id=s.id group by date_trunc('week', gun::timestamp)
         order by 1 desc limit 8) h),'[]'::jsonb),$q$);
  execute d;
end $$;

-- 6) Piyasa panosu ve şirket karnesi
create or replace function public.piyasa_panosu()
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); g date := (now() at time zone 'Europe/Istanbul')::date; e oyun.piyasa_endeks; dun date;
begin
  select * into e from oyun.piyasa_endeks order by gun desc limit 1;
  if e.gun is null or e.guncelleme < now() - interval '70 minutes' then perform oyun.piyasa_degerle(); select * into e from oyun.piyasa_endeks order by gun desc limit 1; end if;
  select max(gun) into dun from oyun.sirket_deger_gecmis where gun < e.gun;
  return jsonb_build_object(
    'endeks', jsonb_build_object('deger', e.deger, 'onceki', e.onceki,
       'degisim', case when coalesce(e.onceki, 0) > 0 then round((e.deger / e.onceki - 1) * 100, 2) end,
       'toplam', round(e.toplam), 'sirket', e.sirket_sayisi, 'guncelleme', e.guncelleme),
    'seri', coalesce((select jsonb_agg(jsonb_build_object('gun', gun, 'deger', deger) order by gun)
       from (select gun, deger from oyun.piyasa_endeks order by gun desc limit 30) z), '[]'::jsonb),
    'buyukler', coalesce((select jsonb_agg(x order by (x->>'deger')::numeric desc) from (
       select jsonb_build_object('id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sektor_ad', coalesce(k.ad, s.sektor),
         'il', (select i.ad from oyun.pazar_sirket ps join oyun.iller i on i.id = ps.il_id where ps.sirket_id = s.id),
         'deger', coalesce(d.piyasa, d.deger), 'kar7', round(d.kar7), 'halka_acik', s.halka_acik, 'tur', s.tur_hukuki,
         'sahip', oyun.kad(oyun.sirket_sahibi(s.id)),
         'degisim', case when coalesce(dd.deger, 0) > 0 then round((coalesce(d.piyasa, d.deger) / coalesce(dd.piyasa, dd.deger) - 1) * 100, 1) end) x
       from oyun.sirket_deger_gecmis d join oyun.sirketler s on s.id = d.sirket_id and s.aktif
       left join oyun.pazar_sektor k on k.kod = s.sektor
       left join oyun.sirket_deger_gecmis dd on dd.sirket_id = d.sirket_id and dd.gun = dun
       where d.gun = e.gun order by coalesce(d.piyasa, d.deger) desc limit 20) q), '[]'::jsonb),
    'yukselenler', coalesce((select jsonb_agg(x) from (
       select jsonb_build_object('id', s.id, 'ad', s.ad, 'degisim', round((coalesce(d.piyasa, d.deger) / coalesce(dd.piyasa, dd.deger) - 1) * 100, 1)) x
       from oyun.sirket_deger_gecmis d join oyun.sirket_deger_gecmis dd on dd.sirket_id = d.sirket_id and dd.gun = dun
       join oyun.sirketler s on s.id = d.sirket_id and s.aktif
       where d.gun = e.gun and coalesce(dd.piyasa, dd.deger) > 0
       order by coalesce(d.piyasa, d.deger) / coalesce(dd.piyasa, dd.deger) desc limit 5) q), '[]'::jsonb),
    'sektorler', coalesce((select jsonb_agg(x order by (x->>'kar7')::numeric desc) from (
       select jsonb_build_object('kod', s.sektor, 'ad', coalesce(k.ad, s.sektor), 'sirket', count(*),
         'kar7', round(sum(d.kar7)), 'deger', round(sum(coalesce(d.piyasa, d.deger)))) x
       from oyun.sirket_deger_gecmis d join oyun.sirketler s on s.id = d.sirket_id and s.aktif
       left join oyun.pazar_sektor k on k.kod = s.sektor where d.gun = e.gun group by s.sektor, k.ad) q), '[]'::jsonb),
    'zincir', jsonb_build_object(
       'elektrik', coalesce((select round(sum(tutar)) from oyun.eko_b2b where kalem = 'Elektrik faturası' and satici is not null and gun > g - 7), 0),
       'lojistik', coalesce((select round(sum(tutar)) from oyun.eko_b2b where kalem = 'Lojistik ve servis' and satici is not null and gun > g - 7), 0),
       'reklam', coalesce((select round(sum(tutar)) from oyun.eko_b2b where kalem = 'Reklam' and satici is not null and gun > g - 7), 0),
       'npc', coalesce((select round(sum(tutar)) from oyun.eko_b2b where satici is null and gun > g - 7), 0)),
    'benim', jsonb_build_object(
       'portfoy', coalesce((select round(sum(coalesce(d.piyasa, d.deger) * o.pay / 100)) from oyun.sirket_ortaklari o
          join oyun.sirket_deger_gecmis d on d.sirket_id = o.sirket_id and d.gun = e.gun where o.user_id = p.id), 0),
       'bugun', coalesce((select round(sum(gl.net * o.pay / 100)) from oyun.sirket_ortaklari o
          join oyun.eko_gunluk gl on gl.sirket_id = o.sirket_id and gl.gun = g where o.user_id = p.id), 0),
       'hafta', coalesce((select round(sum(gl.net * o.pay / 100)) from oyun.sirket_ortaklari o
          join oyun.eko_gunluk gl on gl.sirket_id = o.sirket_id and gl.gun > g - 7 where o.user_id = p.id), 0),
       'sirketler', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'ad', s.ad, 'pay', o.pay,
          'deger', coalesce(d.piyasa, d.deger), 'kar7', round(d.kar7)) order by coalesce(d.piyasa, d.deger) desc)
          from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id and s.aktif
          left join oyun.sirket_deger_gecmis d on d.sirket_id = s.id and d.gun = e.gun where o.user_id = p.id), '[]'::jsonb),
       'il', p.il_id, 'bolge', oyun.bolge_tesvik(p.il_id)),
    'bolgeler', (select jsonb_agg(jsonb_build_object('bolge', b, 'vergi_indirim', (array[0,10,20,30,45,60])[b],
       'sgk_destek', (array[0,0,5,10,15,20])[b],
       'ornek', (select string_agg(ad, ', ' order by ad) from (select i.ad from oyun.iller i where oyun.il_bolge(i.id) = b order by i.mv desc limit 3) z))
       order by b) from generate_series(1, 6) b),
    'kurumlar', oyun.eko_vergi_oran('kurumlar'),
    'politika_faizi', oyun.politika_faizi());
end $function$;

create or replace function public.sirket_karnesi(p_sirket bigint)
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; ps oyun.pazar_sirket; g date := (now() at time zone 'Europe/Istanbul')::date;
  benim numeric; yon boolean;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null then raise exception 'Şirket bulunamadı.'; end if;
  select * into ps from oyun.pazar_sirket where sirket_id = s.id;
  select pay into benim from oyun.sirket_ortaklari where sirket_id = s.id and user_id = p.id;
  yon := oyun.sirket_yonetici_mi(s.id, p.id);
  if s.aktif and benim is not null then perform oyun.sirket_hesapla(s.id); select * into s from oyun.sirketler where id = p_sirket; end if;
  return jsonb_build_object(
    'id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'sektor_ad', coalesce((select ad from oyun.pazar_sektor where kod = s.sektor), s.sektor),
    'aktif', s.aktif, 'tur', s.tur_hukuki, 'halka_acik', s.halka_acik, 'kurulus', s.kurulus,
    'sermaye', s.sermaye, 'kasa', round(s.kasa), 'defter', round(oyun.sirket_defter(s.id)), 'kar7', round(oyun.sirket_kar7(s.id)),
    'deger', oyun.sirket_deger(s.id), 'piyasa', case when s.halka_acik then oyun.borsa_son_fiyat(s.id) * 100 end,
    'yonetici', oyun.kad(s.yonetici), 'sahip', oyun.kad(oyun.sirket_sahibi(s.id)),
    'benim_pay', coalesce(benim, 0), 'yonetici_mi', yon,
    'il', (select ad from oyun.iller where id = ps.il_id), 'il_id', ps.il_id,
    'bolge', case when ps.il_id is not null then oyun.bolge_tesvik(ps.il_id) end,
    'fiyat', ps.fiyat, 'kalite', ps.kalite, 'reklam', ps.reklam, 'marka', round(ps.marka), 'otopilot', ps.otopilot,
    'tahmin', case when s.aktif and ps.sirket_id is not null then oyun.pazar_tahmin(s.id) end,
    'gunler', coalesce((select jsonb_agg(jsonb_build_object('gun', gun, 'gelir', round(gelir + b2b_gelir), 'gider', round(gider + ruhsat + ceza),
        'vergi', round(vergi), 'tesvik', round(tesvik), 'net', round(net), 'b2b_gelir', round(b2b_gelir), 'pay', pay, 'rakip', rakip) order by gun)
       from (select * from oyun.eko_gunluk where sirket_id = s.id order by gun desc limit 14) z), '[]'::jsonb),
    'deger_seri', coalesce((select jsonb_agg(jsonb_build_object('gun', gun, 'deger', coalesce(piyasa, deger)) order by gun)
       from (select * from oyun.sirket_deger_gecmis where sirket_id = s.id order by gun desc limit 30) z), '[]'::jsonb),
    'musteriler', coalesce((select jsonb_agg(jsonb_build_object('ad', s2.ad, 'kalem', b.kalem, 'tutar', b.t) order by b.t desc)
       from (select alici, kalem, round(sum(tutar)) t from oyun.eko_b2b where satici = s.id and gun > g - 7 group by 1, 2 order by 3 desc limit 8) b
       join oyun.sirketler s2 on s2.id = b.alici), '[]'::jsonb),
    'tedarikciler', coalesce((select jsonb_agg(jsonb_build_object('ad', coalesce(s2.ad, 'Yurt içi tedarikçiler'), 'kalem', b.kalem, 'tutar', b.t) order by b.t desc)
       from (select satici, kalem, round(sum(tutar)) t from oyun.eko_b2b where alici = s.id and gun > g - 7 group by 1, 2 order by 3 desc limit 8) b
       left join oyun.sirketler s2 on s2.id = b.satici), '[]'::jsonb),
    'ortaklar', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(o.user_id), 'pay', o.pay) order by o.pay desc)
       from oyun.sirket_ortaklari o where o.sirket_id = s.id), '[]'::jsonb),
    'kurullar', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'tur', k.tur, 'baslik', k.baslik, 'durum', k.durum,
        'acan', oyun.kad(k.acan), 'bit', k.bit, 'evet', k.evet, 'hayir', k.hayir, 'katilim', k.katilim, 'sonuc', k.sonuc,
        'benim_oy', (select oy from oyun.genel_kurul_oy v where v.kurul_id = k.id and v.user_id = p.id)) order by k.id desc)
       from (select * from oyun.genel_kurul where sirket_id = s.id order by (durum = 'acik') desc, id desc limit 8) k), '[]'::jsonb),
    'as_esik', 250000, 'as_harc', greatest(2500, round(s.sermaye * 0.005)));
end $function$;

-- 7) Ekonomi başarımları
create or replace function oyun.basarim_durum(u uuid)
 returns table(kod text, ad text, aciklama text, sinif text, sira integer, kazandi boolean)
 language plpgsql stable
as $function$
declare t timestamptz := oyun.simdi(); hesap timestamptz; n_akis int; n_begeni int; mv_gun numeric; portfoy numeric; sg date;
begin
  select pr.olusturma into hesap from oyun.profiller pr where pr.id = u;
  select count(*) into n_akis from oyun.akis where user_id = u;
  select count(*) into n_begeni from oyun.akis_begeni b join oyun.akis a on a.id = b.akis_id where a.user_id = u and b.user_id <> u;
  select coalesce(sum(extract(epoch from coalesce(m.bit, t) - m.bas) / 86400), 0) into mv_gun from oyun.makamlar m where m.user_id = u and m.tur = 'mv';
  select max(d.gun) into sg from oyun.sirket_deger_gecmis d;
  select coalesce(sum(coalesce(d.piyasa, d.deger) * o.pay / 100), 0) into portfoy
    from oyun.sirket_ortaklari o join oyun.sirket_deger_gecmis d on d.sirket_id = o.sirket_id and d.gun = sg where o.user_id = u;
  return query select * from (values
    ('yerlesik',   'Yerleşik Vatandaş',  'Hesabın 7 günü geçti.',                                'bronz', 1, hesap is not null and hesap <= t - interval '7 days'),
    ('koklu',      'Köklü Vatandaş',     'Hesabın 30 günü geçti.',                               'gumus', 2, hesap is not null and hesap <= t - interval '30 days'),
    ('ilk_soz',    'İlk Söz',            'İlk kısa paylaşımını yaptın.',                         'bronz', 3, n_akis >= 1),
    ('gundem',     'Gündem Belirleyici', '25 paylaşıma ulaştın.',                                'gumus', 4, n_akis >= 25),
    ('sesini',     'Sesini Duyuran',     'Paylaşımların 50 beğeni topladı.',                     'gumus', 5, n_begeni >= 50),
    ('kurucu',     'Parti Kurucusu',     'Bir parti kurdun.',                                    'gumus', 6, exists (select 1 from oyun.partiler pa where pa.kurucu = u)),
    ('genel_baskan','Genel Başkan',      'Bir partinin genel başkanısın.',                       'gumus', 7, exists (select 1 from oyun.partiler pa where pa.gb = u and not pa.kapali)),
    ('vekil',      'Meclis Kürsüsü',     'Milletvekili seçildin.',                               'gumus', 8, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'mv')),
    ('belediye',   'Şehrin Başkanı',     'Belediye başkanı seçildin.',                           'gumus', 9, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bel')),
    ('bakan',      'Kabine Üyesi',       'Bakan oldun.',                                         'altin', 10, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bakan')),
    ('kidemli',    'Kıdemli Vekil',      'Meclis''te toplam 30 gün görev yaptın.',               'altin', 11, mv_gun >= 30),
    ('cumhurbaskani','Çankaya',          'Cumhurbaşkanı seçildin.',                              'altin', 12, exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'cb')),
    ('girisimci',  'Girişimci',          'İlk şirketini kurdun.',                                'bronz', 13, exists (select 1 from oyun.sirketler s where s.kurucu = u)),
    ('ilk_kar',    'İlk Kâr',            'Ortağı olduğun bir şirket günü kârla kapattı.',        'bronz', 14, exists (select 1 from oyun.eko_gunluk g join oyun.sirket_ortaklari o on o.sirket_id = g.sirket_id where o.user_id = u and g.net > 0)),
    ('patron',     'Patron',             'Şirket paylarının değeri 1 milyon ₺''yi aştı.',        'gumus', 15, portfoy >= 1000000),
    ('gong',       'Gong Çaldı',         'Kurduğun bir şirket halka arz edildi.',               'gumus', 16, exists (select 1 from oyun.sirketler s where s.kurucu = u and s.halka_acik)),
    ('holding',    'Holding',            'Üç farklı sektörde çoğunluk sahibi olduğun şirket var.','altin', 17, (select count(distinct s.sektor) from oyun.sirket_ortaklari o join oyun.sirketler s on s.id = o.sirket_id and s.aktif where o.user_id = u and o.pay >= 50) >= 3),
    ('sektor_devi','Sektör Devi',        'Şirketin Türkiye''nin en değerli 10 şirketi arasında.', 'altin', 18, exists (select 1 from (select d.sirket_id from oyun.sirket_deger_gecmis d join oyun.sirketler s on s.id = d.sirket_id and s.aktif where d.gun = sg order by coalesce(d.piyasa, d.deger) desc limit 10) z join oyun.sirket_ortaklari o on o.sirket_id = z.sirket_id where o.user_id = u and o.pay >= 50))
  ) v(kod, ad, aciklama, sinif, sira, kazandi);
end $function$;

-- 8) Ekonomi zamanlayıcısı: genel kurullar, saatlik değerleme, 18:00 borsa kapanışı, 20:00 gün sonu bilançosu
create or replace function oyun.ekonomi3_tick()
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare k record; yerel timestamp := now() at time zone 'Europe/Istanbul'; g date := (now() at time zone 'Europe/Istanbul')::date;
  e oyun.piyasa_endeks; x record; metin text; n_kurul int := 0; kapanis boolean := false; bilanco int := 0; son timestamptz;
begin
  if not pg_try_advisory_xact_lock(424299) then return jsonb_build_object('kilitli', true); end if;
  for k in select id from oyun.genel_kurul where durum = 'acik' and bit <= now() order by id limit 50 loop
    perform oyun.genel_kurul_kapat(k.id, true); n_kurul := n_kurul + 1;
  end loop;

  select guncelleme into son from oyun.piyasa_endeks where gun = g;
  if son is null or son < now() - interval '55 minutes' then perform oyun.piyasa_degerle(); end if;

  -- 18:00 borsa kapanışı (günde bir kez)
  if extract(hour from yerel) >= 18 and not exists (select 1 from oyun.ekonomi3_kayit where kod = 'kapanis_' || g) then
    perform oyun.piyasa_degerle();
    update oyun.piyasa_endeks set kapanis = true where gun = g;
    select * into e from oyun.piyasa_endeks where gun = g;
    select string_agg(format('%s (%s%s%%)', z.ad, case when z.d >= 0 then '+' else '' end, replace(to_char(z.d, 'FM990.0'), '.', ',')), ', ') into metin
    from (select s.ad, round((coalesce(a.piyasa, a.deger) / nullif(coalesce(b.piyasa, b.deger), 0) - 1) * 100, 1) d
          from oyun.sirket_deger_gecmis a join oyun.sirket_deger_gecmis b on b.sirket_id = a.sirket_id
            and b.gun = (select max(gun) from oyun.sirket_deger_gecmis where gun < g)
          join oyun.sirketler s on s.id = a.sirket_id and s.aktif
          where a.gun = g and coalesce(b.piyasa, b.deger) > 0 order by 2 desc limit 3) z;
    perform oyun.olay('ekonomi', format('Piyasa kapanışı: Şirketler Endeksi %s puan%s. Günün yükselenleri: %s. Piyasadaki toplam şirket değeri %s ₺.',
      replace(to_char(e.deger, 'FM9999990.00'), '.', ','),
      case when coalesce(e.onceki, 0) > 0 then format(' (%s%s%%)', case when e.deger >= e.onceki then '+' else '' end,
        replace(to_char(round((e.deger / e.onceki - 1) * 100, 2), 'FM990.00'), '.', ',')) else '' end,
      coalesce(metin, 'veri yok'), oyun.tl(e.toplam)), null, null, now());
    -- pazar günleri haftanın en değerli şirketleri listesi
    if extract(isodow from yerel) = 7 then
      select string_agg(format('%s. %s (%s ₺)', z.r, z.ad, oyun.tl(z.v)), ' · ') into metin
      from (select row_number() over (order by coalesce(d.piyasa, d.deger) desc) r, s.ad, coalesce(d.piyasa, d.deger) v
            from oyun.sirket_deger_gecmis d join oyun.sirketler s on s.id = d.sirket_id and s.aktif where d.gun = g
            order by 3 desc limit 10) z;
      perform oyun.olay('ekonomi', 'Haftanın listesi — Türkiye''nin en değerli 10 şirketi: ' || coalesce(metin, '—'), null, null, now());
    end if;
    insert into oyun.ekonomi3_kayit(kod, deger) values ('kapanis_' || g, e.deger) on conflict (kod) do nothing;
    kapanis := true;
  end if;

  -- 20:00 gün sonu bilançosu: ortaklara günün kârından kendi payı
  if extract(hour from yerel) >= 20 and not exists (select 1 from oyun.ekonomi3_kayit where kod = 'bilanco_' || g) then
    insert into oyun.ekonomi3_kayit(kod, deger) values ('bilanco_' || g, 1) on conflict (kod) do nothing;
    for x in select o.user_id, round(sum(gl.net * o.pay / 100)) pay_net,
               string_agg(format('%s %s%s ₺', s.ad, case when gl.net >= 0 then '+' else '' end, oyun.tl(gl.net)), ', ' order by gl.net desc) liste
             from oyun.sirket_ortaklari o join oyun.eko_gunluk gl on gl.sirket_id = o.sirket_id and gl.gun = g
             join oyun.sirketler s on s.id = o.sirket_id
             group by o.user_id loop
      perform oyun.bildir(x.user_id, format('Günün bilançosu: %s. Senin payına düşen net: %s ₺.', left(x.liste, 300), oyun.tl(x.pay_net)), now());
      bilanco := bilanco + 1;
    end loop;
  end if;
  return jsonb_build_object('kurul', n_kurul, 'kapanis', kapanis, 'bilanco', bilanco);
end $function$;

do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if not exists (select 1 from cron.job where jobname = 'ekonomi-3') then
      perform cron.schedule('ekonomi-3', '2-59/10 * * * *', 'select oyun.ekonomi3_tick()');
    end if;
  end if;
end $$;

-- 9) Yetkiler
revoke all on function public.piyasa_panosu() from public, anon;
revoke all on function public.sirket_karnesi(bigint) from public, anon;
revoke all on function public.genel_kurul_ac(bigint, text, jsonb) from public, anon;
revoke all on function public.genel_kurul_oy(bigint, boolean) from public, anon;
revoke all on function public.sirket_as_donustur(bigint) from public, anon;
grant execute on function public.piyasa_panosu() to authenticated;
grant execute on function public.sirket_karnesi(bigint) to authenticated;
grant execute on function public.genel_kurul_ac(bigint, text, jsonb) to authenticated;
grant execute on function public.genel_kurul_oy(bigint, boolean) to authenticated;
grant execute on function public.sirket_as_donustur(bigint) to authenticated;
revoke all on function oyun.ekonomi3_tick() from public, anon, authenticated;
revoke all on function oyun.genel_kurul_kapat(bigint, boolean) from public, anon, authenticated;
revoke all on function oyun.piyasa_degerle() from public, anon, authenticated;

select oyun.piyasa_degerle();

alter function oyun.basarim_durum(uuid) set search_path to 'oyun','public','pg_temp';

commit;
