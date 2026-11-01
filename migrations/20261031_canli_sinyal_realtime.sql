-- Canlı veritabanına YALNIZCA bu dosyayı uygulayın. supabase-kurulum.sql'in tamamını tekrar çalıştırmayın.
-- Supabase SQL Editor bu betiği tek işlemde çalıştırır; hata olursa hiçbir adım kalmaz.
begin;

-- 159 (31.10.2026) — Canlı ekranlar veritabanını sürekli yoklamasın
-- Sorun: sohbet, özel mesaj, miting, seçim gecesi, canlı yayın, müzayede ve Kürsü
-- açıkken her cihaz birkaç saniyede bir okuma RPC'si atıyordu. Oyuncu sayısı artınca
-- bu, hiç değişiklik olmasa da sabit bir okuma yükü üretiyor.
-- Çözüm: public.canli_sinyal yalnız "bu konu değişti" der (anahtar + rev + zaman).
-- Mesaj metni, para, kullanıcı adı veya başka bir özel yük yoktur.
-- İstemci sinyali alınca zaten yetkili olan RPC ile kendi ekranını tazeler.
-- Özel kutu anahtarı (kutu:<uuid>) yalnız sahibine açıktır; sohbet anahtarı yalnız
-- o kanalı zaten görebilen oyuncuya açıktır. Diğer konular (miting, seçim, yayın,
-- müzayede, kürsü) oyun içi herkese açık etkinliklerdir.
-- Yeni oyun RPC'si yok. Yazma fonksiyonu istemciye kapalıdır.
-- 06_yetkiler.sql bilinçli olarak değiştirilmedi.

create table if not exists public.canli_sinyal(
  anahtar text primary key check (char_length(anahtar) between 1 and 80),
  rev bigint not null default 1,
  zaman timestamptz not null default now(),
  constraint canli_sinyal_anahtar_bicim check (anahtar ~ '^(sohbet|kutu|miting|secim|yayin|muzayede|kursu):[A-Za-z0-9_.:-]{1,72}$')
);
comment on table public.canli_sinyal is
  'Canlı ekran uyarısı. Sütunlar yalnız anahtar, rev ve zaman. Mesaj, para veya kimlik taşımaz.';

alter table public.canli_sinyal enable row level security;
revoke all on public.canli_sinyal from public, anon, authenticated;
grant select on public.canli_sinyal to authenticated;

-- Kim hangi sinyal satırını görebilir. Güvenlik tanımlayıcıdır çünkü oyun şeması
-- istemciye kapalıdır; fonksiyon yalnızca evet/hayır döner, satır içeriği dökmez.
create or replace function oyun.canli_sinyal_gorur(p_anahtar text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller; kod text;
begin
  if auth.uid() is null or p_anahtar is null then return false; end if;
  if p_anahtar like 'kutu:%' then
    return p_anahtar = 'kutu:' || (select auth.uid())::text;
  end if;
  if p_anahtar ~ '^(miting|secim|yayin|muzayede|kursu):' then
    return true;
  end if;
  if p_anahtar like 'sohbet:%' then
    select * into p from oyun.profiller where id = (select auth.uid());
    if p.id is null then return false; end if;
    kod := substr(p_anahtar, 8);
    return exists (
      select 1
      from unnest(array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine']::text[]) c
      where oyun.kanal_coz(p, c) = kod
    );
  end if;
  return false;
end $$;

revoke all on function oyun.canli_sinyal_gorur(text) from public, anon;
grant execute on function oyun.canli_sinyal_gorur(text) to authenticated;

drop policy if exists canli_sinyal_okur on public.canli_sinyal;
create policy canli_sinyal_okur
  on public.canli_sinyal for select to authenticated
  using (oyun.canli_sinyal_gorur(anahtar));

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'canli_sinyal'
     ) then
    alter publication supabase_realtime add table public.canli_sinyal;
  end if;
end $$;

-- Aynı veritabanı işleminde aynı anahtar bir kez yazılır. İstemci bu satırı güncelleyemez.
create or replace function oyun.canli_sinyal(p_anahtar text) returns void
language plpgsql security definer set search_path = '' as $$
declare k text := left(btrim(coalesce(p_anahtar, '')), 80);
begin
  if k !~ '^(sohbet|kutu|miting|secim|yayin|muzayede|kursu):[A-Za-z0-9_.:-]{1,72}$' then return; end if;
  if current_setting('oyun.csig_' || md5(k), true) = '1' then return; end if;
  perform set_config('oyun.csig_' || md5(k), '1', true);
  insert into public.canli_sinyal(anahtar, rev, zaman) values (k, 1, now())
  on conflict (anahtar) do update
    set rev = public.canli_sinyal.rev + 1, zaman = now();
end $$;

create or replace function oyun.canli_sinyal_tetik() returns trigger
language plpgsql security definer set search_path = '' as $$
declare tur text := coalesce(tg_argv[0], ''); n bigint; u uuid;
begin
  if tur = 'sohbet' then
    perform oyun.canli_sinyal('sohbet:' || coalesce(new.kanal, old.kanal));
  elsif tur = 'ozel' then
    perform oyun.canli_sinyal('kutu:' || coalesce(new.gonderen, old.gonderen)::text);
    perform oyun.canli_sinyal('kutu:' || coalesce(new.alici, old.alici)::text);
  elsif tur = 'miting' then
    n := coalesce(new.miting_id, old.miting_id);
    if n is not null then perform oyun.canli_sinyal('miting:' || n::text); end if;
  elsif tur = 'miting_kayit' then
    perform oyun.canli_sinyal('miting:' || coalesce(new.id, old.id)::text);
  elsif tur = 'secim' then
    perform oyun.canli_sinyal('secim:' || coalesce(new.secim_id, old.secim_id)::text);
  elsif tur = 'yayin' then
    perform oyun.canli_sinyal('yayin:' || coalesce(new.yayin_id, old.yayin_id)::text);
  elsif tur = 'yayin_kayit' then
    perform oyun.canli_sinyal('yayin:' || coalesce(new.id, old.id)::text);
  elsif tur = 'muzayede_pey' then
    perform oyun.canli_sinyal('muzayede:lot:' || coalesce(new.lot_id, old.lot_id)::text);
    perform oyun.canli_sinyal('muzayede:salon');
  elsif tur = 'muzayede_lot' then
    perform oyun.canli_sinyal('muzayede:lot:' || coalesce(new.id, old.id)::text);
    perform oyun.canli_sinyal('muzayede:salon');
  elsif tur = 'kursu' then
    perform oyun.canli_sinyal('kursu:akis');
  elsif tur = 'kutu' then
    u := coalesce(new.user_id, old.user_id);
    if u is not null then perform oyun.canli_sinyal('kutu:' || u::text); end if;
  end if;
  return coalesce(new, old);
end $$;

revoke all on function oyun.canli_sinyal(text) from public, anon, authenticated;
revoke all on function oyun.canli_sinyal_tetik() from public, anon, authenticated;

-- Sohbet: kanal başına tek satır. Özel mesaj: yalnız iki tarafın kendi kutusu.
drop trigger if exists canli_sinyal_mesaj on oyun.mesajlar;
create trigger canli_sinyal_mesaj
  after insert or delete or update of gizli on oyun.mesajlar
  for each row execute function oyun.canli_sinyal_tetik('sohbet');

drop trigger if exists canli_sinyal_ozel_ekle on oyun.ozel;
create trigger canli_sinyal_ozel_ekle
  after insert or delete on oyun.ozel
  for each row execute function oyun.canli_sinyal_tetik('ozel');

drop trigger if exists canli_sinyal_ozel_guncel on oyun.ozel;
create trigger canli_sinyal_ozel_guncel
  after update of okundu, gizli on oyun.ozel
  for each row when (old.okundu is distinct from new.okundu or old.gizli is distinct from new.gizli)
  execute function oyun.canli_sinyal_tetik('ozel');

-- Miting: konuşma, tepki, slogan, katılım. Coşku bu satırlardan hesaplanır.
drop trigger if exists canli_sinyal_miting_konusma on oyun.miting_konusma;
create trigger canli_sinyal_miting_konusma
  after insert or delete or update of silindi, metin on oyun.miting_konusma
  for each row execute function oyun.canli_sinyal_tetik('miting');

drop trigger if exists canli_sinyal_miting_tepki on oyun.miting_tepki;
create trigger canli_sinyal_miting_tepki
  after insert or delete or update of tur on oyun.miting_tepki
  for each row execute function oyun.canli_sinyal_tetik('miting');

drop trigger if exists canli_sinyal_miting_slogan on oyun.miting_slogan;
create trigger canli_sinyal_miting_slogan
  after insert or delete or update of silindi on oyun.miting_slogan
  for each row execute function oyun.canli_sinyal_tetik('miting');

drop trigger if exists canli_sinyal_miting_katilim on oyun.miting_katilim;
create trigger canli_sinyal_miting_katilim
  after insert or delete on oyun.miting_katilim
  for each row execute function oyun.canli_sinyal_tetik('miting');

drop trigger if exists canli_sinyal_miting_kayit on oyun.mitingler;
create trigger canli_sinyal_miting_kayit
  after update of cosku, duyuruldu, sonuc_yazildi on oyun.mitingler
  for each row when (old.cosku is distinct from new.cosku or old.duyuruldu is distinct from new.duyuruldu or old.sonuc_yazildi is distinct from new.sonuc_yazildi)
  execute function oyun.canli_sinyal_tetik('miting_kayit');

-- Seçim gecesi: il açılışı saatle hesaplanır (satır her saniye değişmez).
-- Sinyal yalnız plan/aşama yazılınca gider. İstemci sonraki ilin saniyesini yerelde bekler.
drop trigger if exists canli_sinyal_secim_gecesi on oyun.secim_gecesi;
create trigger canli_sinyal_secim_gecesi
  after insert or update of asama, plan, baslangic, sure_sn on oyun.secim_gecesi
  for each row execute function oyun.canli_sinyal_tetik('secim');

drop trigger if exists canli_sinyal_yayin_mesaj on oyun.canli_yayin_mesaj;
create trigger canli_sinyal_yayin_mesaj
  after insert or delete on oyun.canli_yayin_mesaj
  for each row execute function oyun.canli_sinyal_tetik('yayin');

drop trigger if exists canli_sinyal_yayin_tepki on oyun.canli_yayin_tepki;
create trigger canli_sinyal_yayin_tepki
  after insert or delete or update of tur on oyun.canli_yayin_tepki
  for each row execute function oyun.canli_sinyal_tetik('yayin');

drop trigger if exists canli_sinyal_yayin_oy on oyun.canli_yayin_oy;
create trigger canli_sinyal_yayin_oy
  after insert or delete or update on oyun.canli_yayin_oy
  for each row execute function oyun.canli_sinyal_tetik('yayin');

drop trigger if exists canli_sinyal_yayin_kayit on oyun.canli_yayin;
create trigger canli_sinyal_yayin_kayit
  after update of iptal, bit, bas on oyun.canli_yayin
  for each row when (old.iptal is distinct from new.iptal or old.bit is distinct from new.bit or old.bas is distinct from new.bas)
  execute function oyun.canli_sinyal_tetik('yayin_kayit');

drop trigger if exists canli_sinyal_muzayede_pey on oyun.muzayede_peyler;
create trigger canli_sinyal_muzayede_pey
  after insert or delete on oyun.muzayede_peyler
  for each row execute function oyun.canli_sinyal_tetik('muzayede_pey');

drop trigger if exists canli_sinyal_muzayede_lot on oyun.muzayede_lotlar;
create trigger canli_sinyal_muzayede_lot
  after insert or update of durum, bitis, en_yuksek, lider on oyun.muzayede_lotlar
  for each row execute function oyun.canli_sinyal_tetik('muzayede_lot');

drop trigger if exists canli_sinyal_kursu on oyun.akis;
create trigger canli_sinyal_kursu
  after insert or delete or update of gizli on oyun.akis
  for each row execute function oyun.canli_sinyal_tetik('kursu');

-- Sohbet okuma cevabına sinyal anahtarı. Eski alanlar durur; parametre değişmez.
create or replace function public.sohbet_oku(p_kanal text, p_once bigint default null, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb; son bigint;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'kad', coalesce(pr.kad, '(silinmiş)'), 'metin', x.metin, 'zaman', x.zaman,
            'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(x.user_id), 'benim', x.user_id = p.id) order by x.id), '[]'::jsonb)
    into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal = k and not m.gizli and m.zaman <= oyun.simdi() and not oyun.engelli(p.id, m.user_id)
      and (p_sonra is null or m.id > p_sonra) and (p_once is null or m.id < p_once)
    order by case when p_sonra is null then -m.id else m.id end
    limit case when p_sonra is null then 40 else 100 end
  ) x left join oyun.profiller pr on pr.id = x.user_id;
  if p_once is null then
    select max(id) into son from oyun.mesajlar where kanal = k and not gizli and zaman <= oyun.simdi();
    if son is not null then
      insert into oyun.kanal_okuma(user_id, kanal, son_id) values (p.id, k, son)
      on conflict (user_id, kanal) do update set son_id = greatest(oyun.kanal_okuma.son_id, excluded.son_id);
    end if;
  end if;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste, 'yazabilir', oyun.kanal_yazabilir(p, p_kanal),
    'baslik', oyun.kanal_baslik(p, p_kanal), 'sinyal', 'sohbet:' || k);
end $$;

create or replace function public.sohbet_ozet() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); liste jsonb := '[]'; kod text; k text; imlec bigint; okunmamis int; son jsonb; cev int; kilit text;
begin
  foreach kod in array array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine'] loop
    k := oyun.kanal_coz(p, kod);
    kilit := case when k is not null then null else case kod
      when 'parti' then 'Bir partiye katılınca açılır.' when 'yonetim' then 'Genel başkan ya da genel başkan yardımcısı olunca açılır.'
      when 'ittifak' then 'Partin bir ittifaka girince açılır.' when 'kabine' then 'Cumhurbaşkanı ya da bakan olunca açılır.'
      when 'grup' then 'Milletvekili olunca açılır.' when 'divan' then 'TBMM Başkanı, başkanvekili ya da grup başkanvekili olunca açılır.' end end;
    okunmamis := 0; son := null; cev := null;
    if k is not null then
      select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = k;
      select count(*) into okunmamis from (
        select 1 from oyun.mesajlar m where m.kanal = k and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
           and m.zaman <= t and m.zaman > t - interval '3 days' and not oyun.engelli(p.id, m.user_id) limit 100) x;
      select jsonb_build_object('kad', coalesce(pr.kad, '(silinmiş)'), 'metin', m.metin, 'zaman', m.zaman) into son
        from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
       where m.kanal = k and not m.gizli and m.zaman <= t and not oyun.engelli(p.id, m.user_id) order by m.id desc limit 1;
      cev := case kod
        when 'genel' then (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes')
        when 'il' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'belediye' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'parti' then (select count(*) from oyun.profiller where not yasakli and parti_id = p.parti_id and son_gorulme > t - interval '5 minutes')
        end;
    end if;
    liste := liste || jsonb_build_object('kanal', kod, 'baslik', coalesce(oyun.kanal_baslik(p, kod), case kod when 'parti' then 'Parti sohbeti' when 'yonetim' then 'Parti Yönetim Kurulu'
                  when 'ittifak' then 'İttifak sohbeti' when 'kabine' then 'Bakanlar Kurulu' when 'grup' then 'Parti Meclis Grubu'
                  when 'divan' then 'TBMM Başkanlık Divanı' end),
      'kilit', kilit, 'yazabilir', k is not null and oyun.kanal_yazabilir(p, kod), 'okunmamis', okunmamis, 'son', son, 'cevrimici', cev,
      'sinyal', case when k is null then null else 'sohbet:' || k end);
  end loop;
  return jsonb_build_object('kanallar', liste,
    'cevrimici', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes'),
    'toplam_okunmamis', (select coalesce(sum((x ->> 'okunmamis')::int), 0) from jsonb_array_elements(liste) x));
end $$;

-- sonraki_sn: bir sonraki ilin açılmasına (veya sayımın bitmesine) kalan saniye.
-- Hangi il olduğu yazılmaz. İstemci bu süre dolunca bir kez tazeler; arada yoklama gerekmez.
create or replace function public.secim_gecesi(p_secim bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare g oyun.secim_gecesi; s oyun.secimler; gecen numeric; acik int[]; oz jsonb; son jsonb; sonraki numeric;
begin
  select * into g from oyun.secim_gecesi where secim_id = p_secim;
  select * into s from oyun.secimler where id = p_secim;
  if g.secim_id is null then return jsonb_build_object('aktif', false, 'var', false); end if;
  gecen := oyun.secim_gecesi_gecen(p_secim);
  if gecen < 0 then
    return jsonb_build_object('aktif', false, 'var', true, 'basliyor', true, 'baslangic', g.baslangic,
                              'saniye_kaldi', ceil(-gecen)::int, 'sonraki_sn', ceil(-gecen)::int);
  end if;
  acik := oyun.secim_gecesi_acik_iller(p_secim);
  oz := oyun.secim_gecesi_ozet(p_secim);
  select coalesce(jsonb_agg(x order by (x->>'sn')::int desc), '[]'::jsonb) into son from (
    select jsonb_build_object('il_id', (e->>'il')::int, 'ad', i.ad, 'sn', (e->>'sn')::int,
      'onde', case when s.tur = 'mv' then
          (select pa.kisa from oyun.oylar o join oyun.partiler pa on pa.id = o.parti_id
           where o.secim_id = p_secim and o.il_id = (e->>'il')::int and o.parti_id is not null
           group by pa.kisa order by count(*) desc, pa.kisa limit 1)
        else
          (select pr.kad from oyun.oylar o join oyun.adaylar a on a.id = o.aday_id
           join oyun.profiller pr on pr.id = a.user_id
           where o.secim_id = p_secim and o.il_id = (e->>'il')::int
           group by pr.kad order by count(*) desc, pr.kad limit 1) end) x
    from jsonb_array_elements(g.plan) e join oyun.iller i on i.id = (e->>'il')::int
    where (e->>'il')::int = any(acik)
    order by (e->>'sn')::int desc, (e->>'il')::int limit 5) t;
  select min((e->>'sn')::numeric) into sonraki
    from jsonb_array_elements(g.plan) e
    where (e->>'sn')::numeric > gecen;
  return oz || jsonb_build_object('aktif', gecen < g.sure_sn, 'var', true, 'tur', s.tur,
    'baslangic', g.baslangic, 'bitis', g.baslangic + make_interval(secs => g.sure_sn),
    'sure_sn', g.sure_sn, 'gecen_sn', least(gecen, g.sure_sn)::int,
    'saniye_kaldi', greatest(0, ceil(g.sure_sn - gecen))::int, 'son_acilan', son,
    'sonraki_sn', case when sonraki is not null then greatest(1, ceil(sonraki - gecen))::int
                       else greatest(0, ceil(g.sure_sn - gecen))::int end);
end $$;
commit;
