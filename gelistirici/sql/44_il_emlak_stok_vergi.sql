-- =====================================================================
--  44 · İL BAZLI EMLAK: SINIRLI STOK, İL FİYATI, HAFTALIK MÜLK VERGİSİ
--
--  • Her ilde satılık yeni mülk sayısı nüfusa göre sınırlı (İstanbul ~100 daire, Bayburt 8 daire).
--    Nüfus göstergesi: ilin 600 sandalyelik Meclis'teki ağırlığı (oyun.iller.mv).
--  • Fiyat ve kira ilin büyüklüğüne ve gelişmişliğine göre değişir.
--    Gelişmişlik = %60 ilin kalıcı kalkınma puanı (SEGE sıralamasına yakın 6 kademe)
--                + %40 belediyenin oyun içi gelişim puanı (yatırımlarla değişir).
--  • Oyuncu parası yettikçe yaşamadığı illerden de mülk alabilir, ilana koyup satabilir.
--  • Her mülkten haftalık mülk vergisi alınır, para mülkün bulunduğu ilin belediye kasasına gider.
--    Oran = Meclis'in kanunla belirlediği ulusal oran × o ilin belediye başkanının çarpanı.
--    Ulusal oranı cumhurbaşkanı kararnameyle değiştiremez; yalnız TBMM (ya da anayasa).
--  • Vergi matrahı mülkün bugünkü il rayiç bedelidir (alış fiyatı değil).
--  • Eski mülklerin sahibi ve kirası korunur; ilk vergi bu güncellemeden 7 gün sonra alınır.
-- =====================================================================

alter table oyun.yatirim_mulkleri add column if not exists vergi_sonraki timestamptz;
alter table oyun.yatirim_mulkleri add column if not exists vergi_borc numeric not null default 0;
update oyun.yatirim_mulkleri set vergi_sonraki = oyun.simdi() + interval '7 days' where vergi_sonraki is null;
alter table oyun.yatirim_mulkleri alter column vergi_sonraki set default now() + interval '7 days';

-- Belediye kasasına giden her vergi tahsilatı (belediye başkanı ve oyuncu ekranları için)
create table if not exists oyun.emlak_vergi_tahsilat(
  id       bigint generated always as identity primary key,
  il_id    smallint not null references oyun.iller(id),
  user_id  uuid not null references oyun.profiller(id),
  mulk_id  bigint not null,
  tutar    numeric not null check (tutar >= 0),
  zaman    timestamptz not null default now()
);
create index if not exists emlak_vergi_tahsilat_il_zaman on oyun.emlak_vergi_tahsilat(il_id, zaman);
alter table oyun.emlak_vergi_tahsilat enable row level security;

-- İllerin kalıcı kalkınma puanı (0-100). Kademeler SEGE il sıralamasına yakındır; gerekirse elle ayarlanabilir.
create table if not exists oyun.il_kalkinma(
  il_id smallint primary key references oyun.iller(id),
  puan  numeric not null check (puan between 0 and 100)
);
alter table oyun.il_kalkinma enable row level security;
insert into oyun.il_kalkinma(il_id, puan)
select i.id, case
  when i.id in (6,7,16,26,34,35,41,48,59) then 90
  when i.id in (9,10,11,14,17,20,22,32,33,38,39,42,45,54,77) then 75
  when i.id in (1,3,5,8,15,19,23,24,27,31,37,40,43,44,50,51,53,55,58,61,64,67,70,71,74,78,81) then 60
  when i.id in (18,25,28,29,46,52,57,60,62,66,68,69,79,80) then 45
  when i.id in (2,12,21,36,63,72,75,76) then 30
  else 15 end
from oyun.iller i
on conflict (il_id) do nothing;

-- Yeni tablolar da TRUNCATE korumasına girsin (tam kurulumda kalicilik_son zaten ekler; migration için burada)
do $$ begin
  if to_regproc('oyun.bosaltma_korumasi') is not null then
    drop trigger if exists bosaltma_korumasi on oyun.emlak_vergi_tahsilat;
    create trigger bosaltma_korumasi before truncate on oyun.emlak_vergi_tahsilat for each statement execute function oyun.bosaltma_korumasi();
    drop trigger if exists bosaltma_korumasi on oyun.il_kalkinma;
    create trigger bosaltma_korumasi before truncate on oyun.il_kalkinma for each statement execute function oyun.bosaltma_korumasi();
  end if;
end $$;

-- Kurallar: ulusal oran (Meclis) ve il çarpanı (belediye başkanı)
insert into oyun.duzenleme_tanim(kod, kapsam, ad, birim, varsayilan, min, max, adim, tur, aciklama, oyuncu, devlet, sira) values
('mulk_vergi_ulusal','ulke','Haftalık mülk vergisi','yuzde',0.5,0.1,3.0,0.1,'gelir',
 'Mülklerin il rayiç bedeli üzerinden her hafta alınan vergi. Yalnız TBMM kanunla değiştirir; illerde belediye çarpanıyla uygulanır.',
 'Sahip olduğun her mülk için haftada bir, mülkün bugünkü il değeri üzerinden vergi ödersin.',
 'Vergi hazineye değil, mülkün bulunduğu ilin belediye kasasına gider.',21),
('mulk_vergi_yerel','il','Mülk vergisi çarpanı','yuzde',100,50,200,10,'gelir',
 'Meclis''in belirlediği haftalık mülk vergisinin bu ilde uygulanan çarpanı. 100 değişiklik yok demektir, 150 vergiyi yarı yarıya artırır.',
 'Bu ildeki mülklerin vergisi değişir; mülk sahibi başka ilde yaşasa da vergiyi bu il alır.',
 'Gelir doğrudan bu ilin belediye kasasına girer.',22)
on conflict (kod) do update set kapsam = excluded.kapsam, ad = excluded.ad, birim = excluded.birim, varsayilan = excluded.varsayilan,
  min = excluded.min, max = excluded.max, adim = excluded.adim, tur = excluded.tur, aciklama = excluded.aciklama,
  oyuncu = excluded.oyuncu, devlet = excluded.devlet, sira = excluded.sira;

-- Ulusal oranı cumhurbaşkanı kararnameyle değiştiremez.
create or replace function oyun.duzenleme_engel(p_kod text, p_kaynak text) returns text language sql stable as $$
  select case when d.kaynak = 'anayasa' and p_kaynak <> 'anayasa'
                then 'Bu kural anayasada düzenlenmiş; ancak halk oylamasıyla yapılacak bir anayasa değişikliğiyle değiştirilebilir.'
              when p_kod = 'mulk_vergi_ulusal' and p_kaynak = 'kararname'
                then 'Haftalık mülk vergisi oranını yalnız TBMM kanunla değiştirebilir; kararnameyle değiştirilemez.'
              when d.kaynak = 'kanun' and p_kaynak = 'kararname'
                then 'Bu konu Meclis tarafından kanunla düzenlenmiş; kanunla düzenlenen konuda cumhurbaşkanlığı kararnamesi çıkarılamaz.' end
  from (select 1) x left join oyun.duzenlemeler d on d.kod = p_kod
$$;

-- ---------------------------------------------------------------------
-- HESAPLAR
-- ---------------------------------------------------------------------
create or replace function oyun.mulk_il_gelismislik(p_il smallint) returns numeric
language sql stable set search_path = '' as $$
  select round(0.6 * coalesce(k.puan, 50) + 0.4 * greatest(0, least(100, coalesce(d.gelisim, 50))), 1)
  from oyun.iller i left join oyun.il_kalkinma k on k.il_id = i.id left join oyun.il_durum d on d.il_id = i.id
  where i.id = p_il
$$;

create or replace function oyun.mulk_il_kota(p_il smallint, p_tip text) returns integer
language sql stable set search_path = '' as $$
  select case p_tip
    when 'daire'  then 8 + round((least(96, greatest(1, i.mv)) - 1) * 92.0 / 95)::int
    when 'dukkan' then 3 + round((least(96, greatest(1, i.mv)) - 1) * 32.0 / 95)::int
    when 'villa'  then 2 + round((least(96, greatest(1, i.mv)) - 1) * 18.0 / 95)::int
    else 0 end
  from oyun.iller i where i.id = p_il
$$;

create or replace function oyun.mulk_il_bedel(p_il smallint, p_tip text) returns numeric
language sql stable set search_path = '' as $$
  select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end)
               * (0.55 + 1.10 * sqrt(least(96, greatest(1, i.mv))::numeric / 96.0))
               * (0.60 + oyun.mulk_il_gelismislik(p_il) / 125.0), -3)
  from oyun.iller i where i.id = p_il
$$;

-- Kira: il değerinin ~1/13'ü; gelişmiş ilde kira getirisi biraz daha yüksek.
create or replace function oyun.mulk_il_kira(p_il smallint, p_tip text) returns numeric
language sql stable set search_path = '' as $$
  select round(oyun.mulk_il_bedel(p_il, p_tip) / 13.0 * (0.85 + oyun.mulk_il_gelismislik(p_il) / 333.0), -1)
$$;

-- Bu ilde uygulanan haftalık oran (yüzde)
create or replace function oyun.mulk_vergi_oran(p_il smallint) returns numeric
language sql stable set search_path = '' as $$
  select round(oyun.duz('mulk_vergi_ulusal') * oyun.il_duz(p_il, 'mulk_vergi_yerel') / 100.0, 3)
$$;

create or replace function oyun.mulk_haftalik_vergi_tutar(p_mulk bigint) returns numeric
language sql stable set search_path = '' as $$
  select round(oyun.mulk_il_bedel(m.il_id, m.tip) * oyun.mulk_vergi_oran(m.il_id) / 100.0)
  from oyun.yatirim_mulkleri m where m.id = p_mulk
$$;

-- Vadesi gelen dönemleri tahakkuk ettirir, cüzdandaki parayla öder; yetmeyen kısım borç olarak kalır.
create or replace function oyun.mulk_haftalik_vergi(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare x record; t timestamptz := oyun.simdi(); donem int; tahakkuk numeric; odeme numeric; hazir numeric;
begin
  for x in select m.id, m.il_id, m.tip, m.vergi_sonraki, m.vergi_borc, i.ad il_ad
           from oyun.yatirim_mulkleri m join oyun.iller i on i.id = m.il_id
           where m.user_id = p_user and (m.vergi_sonraki <= t or m.vergi_borc > 0)
           order by m.id for update of m loop
    donem := case when x.vergi_sonraki <= t then least(520, floor(extract(epoch from (t - x.vergi_sonraki)) / 604800)::int + 1) else 0 end;
    tahakkuk := coalesce(oyun.mulk_haftalik_vergi_tutar(x.id), 0) * donem;
    hazir := greatest(0, coalesce((select para from oyun.cuzdan where user_id = p_user), 0));
    odeme := least(x.vergi_borc + tahakkuk, floor(hazir));
    update oyun.yatirim_mulkleri
       set vergi_borc = greatest(0, x.vergi_borc + tahakkuk - odeme),
           vergi_sonraki = x.vergi_sonraki + make_interval(days => donem * 7)
     where id = x.id;
    if odeme > 0 then
      perform oyun.para_islem(p_user, -odeme, 'emlak_vergi',
        format('%s Belediyesi mülk vergisi · mülk #%s%s', x.il_ad, x.id, case when donem > 1 then format(' (%s hafta)', donem) else '' end), t, odeme);
      update oyun.il_durum set kasa = coalesce(kasa, 0) + odeme / 1e9 where il_id = x.il_id;  -- belediye kasası milyar ₺
      insert into oyun.emlak_vergi_tahsilat(il_id, user_id, mulk_id, tutar, zaman) values (x.il_id, p_user, x.id, odeme, t);
    end if;
  end loop;
end $$;
revoke all on function oyun.mulk_haftalik_vergi(uuid) from public, anon, authenticated;

-- Kira tahsili (24'teki ile aynı) + haftalık mülk vergisi
create or replace function oyun.mulk_kira_tahsil(p_user uuid) returns void
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare m record; n int; gross numeric; tax numeric; t timestamptz := oyun.simdi();
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 78113));
  for m in select * from oyun.yatirim_mulkleri where user_id = p_user and sonraki_kira <= t order by id for update loop
    n := least(520, floor(extract(epoch from (t - m.sonraki_kira)) / 604800)::int + 1);
    gross := round(m.haftalik_kira * n, 2);
    tax := case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id = p_user
                        and (x.satin_alma < m.satin_alma or (x.satin_alma = m.satin_alma and x.id <= m.id))) >= 3
                then round(gross * oyun.yasa_oran('coklu_mulk_vergi') / 100, 2) else 0 end;
    perform oyun.para_islem(p_user, gross - tax, 'kira', format('Mülk #%s: %s haftalık kira, vergi %s ₺', m.id, n, tax), t, tax);
    if tax > 0 then update oyun.ulke set hazine = hazine + tax / 1000000 where id = 1; end if;
    update oyun.yatirim_mulkleri set sonraki_kira = sonraki_kira + n * interval '7 days', toplam_kira = toplam_kira + gross - tax,
      kira_sayisi = kira_sayisi + n where id = m.id;
  end loop;
  perform oyun.mulk_haftalik_vergi(p_user);
end $function$;

-- Tapu devrinde vergi borcu satıcıdan kesilir (satış bedeli cüzdanına girdikten sonra çalışır).
create or replace function oyun.mulk_devir_vergi() returns trigger
language plpgsql security definer set search_path = '' as $$
declare ilad text;
begin
  if new.user_id is distinct from old.user_id and old.vergi_borc > 0 then
    select ad into ilad from oyun.iller where id = old.il_id;
    perform oyun.para_islem(old.user_id, -old.vergi_borc, 'emlak_vergi',
      format('%s Belediyesi mülk vergisi borcu (tapu devri) · mülk #%s', ilad, old.id), oyun.simdi(), old.vergi_borc);
    update oyun.il_durum set kasa = coalesce(kasa, 0) + old.vergi_borc / 1e9 where il_id = old.il_id;
    insert into oyun.emlak_vergi_tahsilat(il_id, user_id, mulk_id, tutar, zaman) values (old.il_id, old.user_id, old.id, old.vergi_borc, oyun.simdi());
    new.vergi_borc := 0;
  end if;
  return new;
end $$;
drop trigger if exists mulk_devir_vergi on oyun.yatirim_mulkleri;
create trigger mulk_devir_vergi before update of user_id on oyun.yatirim_mulkleri
  for each row execute function oyun.mulk_devir_vergi();

-- ---------------------------------------------------------------------
-- UYGULAMA (RPC)
-- ---------------------------------------------------------------------
-- Deneme sürümlerinden kalmış olabilecek farklı imzalı kopyalar (uygulama çağrısı belirsiz kalmasın)
do $$ declare r record; begin
  for r in select p.oid::regprocedure f from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname in ('mulk_il_satin_al', 'mulk_il_stok') loop
    execute format('drop function %s', r.f);
  end loop;
end $$;

create or replace function public.mulk_il_stok() returns jsonb
language sql stable security definer set search_path = '' as $$
  with sahip as (select il_id, tip, count(*) n from oyun.yatirim_mulkleri group by il_id, tip)
  select coalesce(jsonb_agg(jsonb_build_object(
    'il_id', i.id, 'il', i.ad, 'nufus', i.mv, 'gelismislik', oyun.mulk_il_gelismislik(i.id),
    'benim_ilim', i.id = (select p.il_id from oyun.profiller p where p.id = auth.uid()),
    'vergi_oran', oyun.mulk_vergi_oran(i.id), 'carpan', oyun.il_duz(i.id, 'mulk_vergi_yerel'),
    'urunler', (select jsonb_agg(jsonb_build_object(
        'tip', v.tip, 'kontenjan', oyun.mulk_il_kota(i.id, v.tip),
        'kalan', greatest(0, oyun.mulk_il_kota(i.id, v.tip) - coalesce((select n from sahip s where s.il_id = i.id and s.tip = v.tip), 0)),
        'fiyat', oyun.mulk_il_bedel(i.id, v.tip), 'kira', oyun.mulk_il_kira(i.id, v.tip),
        'vergi', round(oyun.mulk_il_bedel(i.id, v.tip) * oyun.mulk_vergi_oran(i.id) / 100.0)) order by v.sira)
      from (values ('daire', 1), ('dukkan', 2), ('villa', 3)) v(tip, sira))
  )), '[]'::jsonb)
  from oyun.iller i
$$;
revoke all on function public.mulk_il_stok() from public, anon;
grant execute on function public.mulk_il_stok() to authenticated;

create or replace function public.mulk_il_satin_al(p_tip text, p_il integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_il smallint := p_il; u uuid := auth.uid(); t timestamptz := oyun.simdi(); c oyun.iller; f numeric; k numeric; yeni bigint; mevcut int;
  tipad text := case p_tip when 'daire' then 'daire' when 'dukkan' then 'dükkân' when 'villa' then 'villa' end;
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u and not yasakli) then raise exception 'Oyuncu profili gerekli.'; end if;
  if tipad is null then raise exception 'Geçersiz mülk türü.'; end if;
  if v_il is null then raise exception 'Satın alacağın ili seç.'; end if;
  select * into c from oyun.iller where id = v_il for update;   -- aynı ilde eş zamanlı alımlar sırayla işlenir
  if c.id is null then raise exception 'İl bulunamadı.'; end if;
  select count(*) into mevcut from oyun.yatirim_mulkleri where il_id = v_il and tip = p_tip;
  if mevcut >= oyun.mulk_il_kota(v_il, p_tip) then
    raise exception '% ilinde satılık yeni % kalmadı. Oyuncuların ilanlarına bakabilirsin.', c.ad, tipad;
  end if;
  f := oyun.mulk_il_bedel(v_il, p_tip); k := oyun.mulk_il_kira(v_il, p_tip);
  perform oyun.mulk_kira_tahsil(u);
  perform oyun.para_islem(u, -f, 'emlak', format('%s: yeni %s satın alındı', c.ad, tipad), t);
  insert into oyun.yatirim_mulkleri(user_id, il_id, tip, alis_bedeli, haftalik_kira, satin_alma, sonraki_kira, vergi_sonraki)
  values (u, v_il, p_tip, f, k, t, t + interval '7 days', t + interval '7 days') returning id into yeni;
  insert into oyun.ticaret_devir_kayit(tur, varlik_id, satici, alici, bedel, zaman, aciklama)
  values ('mulk_devlet', yeni, null, u, f, t, format('%s ilinden %s satın alındı', c.ad, tipad));
  return public.mulk_liste();
end $$;
revoke all on function public.mulk_il_satin_al(text, integer) from public, anon;
grant execute on function public.mulk_il_satin_al(text, integer) to authenticated;

-- Eski uygulama sürümleri: kendi ilinden, aynı stok ve il fiyatıyla alır.
create or replace function public.mulk_satin_al(p_tip text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  return public.mulk_il_satin_al(p_tip, (select p.il_id from oyun.profiller p where p.id = auth.uid()));
end $$;
revoke all on function public.mulk_satin_al(text) from public, anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.mulk_liste() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare u uuid := auth.uid(); p oyun.profiller; j jsonb;
begin
  if u is null then raise exception 'Oturum açmalısın'; end if;
  select * into p from oyun.profiller where id = u;
  if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
  perform oyun.mulk_kira_tahsil(u);
  select jsonb_build_object(
    'mulkler', coalesce(jsonb_agg(jsonb_build_object(
       'id', m.id, 'tip', m.tip, 'il', i.ad, 'il_id', m.il_id, 'alis', m.alis_bedeli, 'deger', oyun.mulk_il_bedel(m.il_id, m.tip),
       'haftalik', m.haftalik_kira, 'sonraki', m.sonraki_kira,
       'toplam_kira', m.toplam_kira, 'kira_sayisi', m.kira_sayisi,
       'vergi', oyun.mulk_haftalik_vergi_tutar(m.id), 'vergi_sonraki', m.vergi_sonraki, 'vergi_borc', m.vergi_borc
    ) order by m.satin_alma desc, m.id desc), '[]'::jsonb),
    'adet', count(m.id),
    'haftalik_toplam', coalesce(sum(m.haftalik_kira), 0),
    'haftalik_vergi', coalesce(sum(oyun.mulk_haftalik_vergi_tutar(m.id)), 0),
    'vergi_borc', coalesce(sum(m.vergi_borc), 0),
    'mulk_degeri', coalesce(sum(m.alis_bedeli), 0),
    'piyasa_degeri', coalesce(sum(oyun.mulk_il_bedel(m.il_id, m.tip)), 0),
    'ulusal_oran', oyun.duz('mulk_vergi_ulusal'),
    'cuzdan', (select para from oyun.cuzdan where user_id = u)
  ) into j
  from oyun.yatirim_mulkleri m join oyun.iller i on i.id = m.il_id where m.user_id = u;
  return j;
end $function$;

-- Belediye başkanı için: ildeki mülkler ve son 7 günün vergi geliri
create or replace function public.belediye_emlak_ozet() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); il smallint; t timestamptz := oyun.simdi();
begin
  select m.il_id into il from oyun.makamlar m where m.user_id = p.id and m.tur = 'bel' and m.bit is null limit 1;
  il := coalesce(il, p.il_id);
  return jsonb_build_object('il_id', il, 'il', (select ad from oyun.iller where id = il),
    'mulk', (select count(*) from oyun.yatirim_mulkleri where il_id = il),
    'haftalik_vergi', (select coalesce(sum(tutar), 0) from oyun.emlak_vergi_tahsilat where il_id = il and zaman > t - interval '7 days'),
    'toplam_vergi', (select coalesce(sum(tutar), 0) from oyun.emlak_vergi_tahsilat where il_id = il),
    'oran', oyun.mulk_vergi_oran(il), 'ulusal_oran', oyun.duz('mulk_vergi_ulusal'), 'carpan', oyun.il_duz(il, 'mulk_vergi_yerel'));
end $$;
revoke all on function public.belediye_emlak_ozet() from public, anon;
grant execute on function public.belediye_emlak_ozet() to authenticated;
