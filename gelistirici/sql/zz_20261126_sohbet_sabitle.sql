-- 26.11.2026 · SOHBETTE MESAJ SABİTLEME + PARTİ SÖZCÜSÜ UNVANI (sürüm 2026.11.26-5)
--
-- 1) Parti sözcüsü unvanı (Ercan: "Parti sözcüsü sohbete yazdığında XXP Parti Sözcüsü yazmıyor")
--    Unvan zincirinde sözcü hiç yoktu. Artık: "XXP Parti Sözcüsü"; aynı kişi Genel Başkan Yardımcısıysa
--    "XXP … Genel Başkan Yardımcısı ve Sözcüsü". Daha yüksek makam (bakan, milletvekili, GB…) varsa o görünür.
--    oyun.parti_unvan, zincirdeki oyun.gby_unvan(u) yerine geçer. Taze kurulumda oyun.unvan gövdesi yamalanır
--    (zz_20261125_yuk_hizlandirma.sql bu gövdeyi sonra unvan_hesap'a kopyalar); canlıda unvan_hesap yamalanır.
--    Unvan önbelleği (unvan_yenile) sözcüleri de aday listesine alır — o değişiklik yuk_hizlandirma dosyasında.
--
-- 2) Mesaj sabitleme (YDP GBY'nin önerisi, Ercan: "gerçekleştir")
--    Nerede: parti sohbeti (parti:N), parti yönetimi (yonetim:N), özel gruplar (og:N).
--    Kim: parti sohbetlerinde Genel Başkan, Genel Başkan Yardımcıları ve Parti Sözcüsü; özel grupta grubu kuran.
--    Kural: kanal başına en çok 3 sabit mesaj; 4. sabitlenince en eskisi kendiliğinden düşer (WhatsApp gibi).
--    Sabitlenen mesaj 30 günlük mesaj saklama temizliğinde silinmez; sabitlemesi kaldırılınca normal süreye döner.
--    Moderasyonun gizlediği mesaj sabit listede görünmez. Sabitleme/kaldırma kanal sinyali gönderir,
--    açık ekranlar anında yenilenir. Ek RPC yok: sabitler sohbet_oku dönüşünde gelir (yalnız bu üç kanal türünde,
--    en çok 3 satırlık dizinli okuma).

set local check_function_bodies = off;

-- ---------------------------------------------------------------- 1) sözcü unvanı
create or replace function oyun.parti_unvan(u uuid)
 returns text
 language sql
 stable
 set search_path to ''
as $function$
  select case when x.g is not null and x.s is not null then x.g || ' ve Sözcüsü'
              else coalesce(x.g, x.s || ' Parti Sözcüsü') end
  from (select oyun.gby_unvan(u) g,
               (select pa.kisa from oyun.parti_sozcu ps
                  join oyun.partiler pa on pa.id = ps.parti_id and not pa.kapali
                  join oyun.profiller pr on pr.id = ps.user_id and pr.parti_id = ps.parti_id
                 where ps.user_id = u limit 1) s) x
$function$;
revoke all on function oyun.parti_unvan(uuid) from public, anon, authenticated;

do $u$
declare d text; y text;
begin
  -- taze kurulum: oyun.unvan henüz asıl zincir (önbellek sürümü değil)
  d := pg_get_functiondef('oyun.unvan(uuid)'::regprocedure);
  if position('unvan_onbellek' in d) = 0 and position('oyun.parti_unvan(u)' in d) = 0 then
    y := replace(d, 'oyun.gby_unvan(u)', 'oyun.parti_unvan(u)');
    if y <> d then execute y; else raise notice 'sabitle: oyun.unvan beklenen biçimde değil; sözcü unvanı eklenmedi'; end if;
  end if;
  -- canlı: asıl zincir oyun.unvan_hesap'ta
  if to_regprocedure('oyun.unvan_hesap(uuid)') is not null then
    d := pg_get_functiondef('oyun.unvan_hesap(uuid)'::regprocedure);
    if position('oyun.parti_unvan(u)' in d) = 0 then
      y := replace(d, 'oyun.gby_unvan(u)', 'oyun.parti_unvan(u)');
      if y <> d then execute y; else raise notice 'sabitle: unvan_hesap beklenen biçimde değil; sözcü unvanı eklenmedi'; end if;
    end if;
  end if;
end $u$;

-- ---------------------------------------------------------------- 2) sabit mesajlar
create table if not exists oyun.sohbet_sabit (
  kanal text not null,
  mesaj_id bigint not null references oyun.mesajlar(id) on delete cascade,
  sabitleyen uuid,
  zaman timestamptz not null default now(),
  primary key (kanal, mesaj_id)
);
create index if not exists sohbet_sabit_mesaj on oyun.sohbet_sabit (mesaj_id);
alter table oyun.sohbet_sabit enable row level security;
revoke all on oyun.sohbet_sabit from anon, authenticated;

-- Sabitlemenin açık olduğu kanal türleri
create or replace function oyun.sohbet_sabit_kanal(k text)
 returns boolean
 language sql
 immutable
 set search_path to ''
as $function$
  select coalesce(split_part(k, ':', 1) in ('parti', 'yonetim', 'og') and split_part(k, ':', 2) ~ '^[0-9]{1,18}$', false)
$function$;

-- Sabitleme yetkisi (k: kanal_coz çıktısı, yani kişinin zaten erişebildiği kanal)
create or replace function oyun.sohbet_sabit_yetki(p oyun.profiller, k text)
 returns boolean
 language plpgsql
 stable
 set search_path to ''
as $function$
declare tur text := split_part(k, ':', 1); kid bigint;
begin
  if p.id is null or k is null or not oyun.sohbet_sabit_kanal(k) then return false; end if;
  kid := split_part(k, ':', 2)::bigint;
  if coalesce(p.yonetici, false) then return true; end if;
  if tur = 'og' then
    return exists (select 1 from oyun.sohbet_grup g where g.id = kid and g.kurucu = p.id and not g.kapali);
  end if;
  -- parti / yonetim: o partinin üyesi ve GB, GBY ya da sözcü
  if p.parti_id is distinct from kid then return false; end if;
  return exists (select 1 from oyun.partiler pa where pa.id = kid and not pa.kapali and pa.gb = p.id)
      or exists (select 1 from oyun.parti_gby g where g.parti_id = kid and g.user_id = p.id)
      or exists (select 1 from oyun.parti_sozcu s where s.parti_id = kid and s.user_id = p.id);
end $function$;

-- Kanalın sabit mesajları (en yeni sabit önce); gizlenen mesaj listelenmez
create or replace function oyun.sohbet_sabit_liste(k text)
 returns jsonb
 language sql
 stable
 set search_path to ''
as $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', m.id,
           'kad', case when m.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
           'metin', m.metin, 'zaman', m.zaman, 'gorevli', m.gorevli,
           'sabitleyen', coalesce(sp.kad, ''), 'sabit_zaman', s.zaman) order by s.zaman desc), '[]'::jsonb)
  from oyun.sohbet_sabit s
  join oyun.mesajlar m on m.id = s.mesaj_id and m.kanal = s.kanal and not m.gizli
  left join oyun.profiller pr on pr.id = m.user_id
  left join oyun.profiller sp on sp.id = s.sabitleyen
  where s.kanal = k
$function$;
revoke all on function oyun.sohbet_sabit_kanal(text), oyun.sohbet_sabit_yetki(oyun.profiller, text), oyun.sohbet_sabit_liste(text) from public, anon, authenticated;

-- Sabitle / kaldır
create or replace function public.sohbet_sabitle(p_kanal text, p_mesaj bigint, p_sabitle boolean default true)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare p oyun.profiller := oyun.profilim(); k text; m oyun.mesajlar; t timestamptz := clock_timestamp(); dusen bigint;
begin
  if p.id is null then raise exception 'Önce giriş yapmalısın.'; end if;
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  if not oyun.sohbet_sabit_kanal(k) then raise exception 'Bu sohbette mesaj sabitlenemez. Sabitleme parti sohbetinde, parti yönetiminde ve özel gruplarda açıktır.'; end if;
  if not oyun.sohbet_sabit_yetki(p, k) then
    raise exception '%', case when k like 'og:%' then 'Bu grupta mesajı yalnız grubu kuran sabitleyebilir.'
      else 'Mesajı yalnız Genel Başkan, Genel Başkan Yardımcıları ve Parti Sözcüsü sabitleyebilir.' end;
  end if;
  -- aynı kanalda eşzamanlı sabitlemeler sıraya girsin (3 sınırı aşılmasın)
  perform pg_advisory_xact_lock(hashtext('sohbet_sabit:' || k));
  if coalesce(p_sabitle, true) then
    select * into m from oyun.mesajlar where id = p_mesaj;
    if m.id is null or m.kanal is distinct from k then raise exception 'Mesaj bu sohbette bulunamadı.'; end if;
    if m.gizli then raise exception 'Bu mesaj moderasyon tarafından kaldırıldığı için sabitlenemez.'; end if;
    insert into oyun.sohbet_sabit (kanal, mesaj_id, sabitleyen, zaman) values (k, m.id, p.id, t)
    on conflict (kanal, mesaj_id) do update set sabitleyen = excluded.sabitleyen, zaman = excluded.zaman;
    -- en çok 3: fazlası (en eski sabit) düşer
    with fazla as (
      select s.mesaj_id from oyun.sohbet_sabit s where s.kanal = k order by s.zaman desc, s.mesaj_id desc offset 3
    ), sil as (
      delete from oyun.sohbet_sabit s using fazla f where s.kanal = k and s.mesaj_id = f.mesaj_id
      returning s.mesaj_id
    )
    select min(mesaj_id) into dusen from sil;
  else
    delete from oyun.sohbet_sabit where kanal = k and mesaj_id = p_mesaj;
  end if;
  perform oyun.canli_sinyal('sohbet:' || k);
  return jsonb_build_object('sabitler', oyun.sohbet_sabit_liste(k), 'dusen', dusen);
end $function$;
revoke all on function public.sohbet_sabitle(text, bigint, boolean) from public, anon;
grant execute on function public.sohbet_sabitle(text, bigint, boolean) to authenticated;
