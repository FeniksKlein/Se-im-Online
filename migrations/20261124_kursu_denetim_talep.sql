-- Canlı Supabase migration adı: kursu_denetim_talep_20261124
-- Kaynak: gelistirici/sql/zz_20261124_kursu_denetim_talep.sql (aynı gövde) · tekrar çalıştırmak güvenlidir.
-- DURUM (24.11.2026 01:31): canlıya UYGULANDI. Önce canlıda geri alınan işlemle denendi (gelistirici/test/kursu_denetim_talep_canli_test.sql);
--   uygulandıktan sonra mod_kursu_kaldir, kursu_hiz_kapisi ve mod_kutu_gorur gövdeleri kaynakla md5 eşleşti.
-- Geri dönüş: paylaşım aralığını kapatmak için  update oyun.kursu_ayar set paylasim_aralik_dk = 0;
--   Talep kutusunu yeniden masalara bölmek için oyun.mod_kutu_gorur'un önceki tanımı (masa = ana_gorev) geri yazılır.
--   Kürsü şikâyet ekranını kapatmak için: revoke execute on function public.admin_akis_sikayetleri(), public.admin_akis_karar(bigint,text) from authenticated;
begin;
select set_config('lock_timeout', '4s', true);

-- 24.11.2026 · KÜRSÜ DENETİMİ, PAYLAŞIM ARALIĞI, TALEP KUTUSU (sürüm 2026.11.24-3)
-- İstek (Ercan): "Kürsü ekranında ne benim ne de içerik moderatörlerinin yetkisi yok gözüküyor; şikâyetleri kontrol
-- edebilelim ve istediğimiz içeriği kaldırabilelim. Kürsü'ye oyuncu başına 5 dakikada bir paylaşım. Şikâyet ve destek
-- talepleri için yardım masasına bütün modlar girip talepleri görüp cevap yazabilsin; isimleri değil G-01, G-09 yazsın."
--
-- 1) KÜRSÜ ŞİKÂYETLERİ: admin_akis_sikayetleri ve admin_akis_karar'a istemci çağrı izni hiç verilmemişti (RPC yüzey
--    kilidi listesinde yoktu); kurucu dahil herkes "Bu işlem için yetkin yok" görüyordu. Yetki denetimi zaten işlevlerin
--    içinde: oyun.yetki_zorunlu('sikayet') → kurucu + İçerik Masası + Oyuncu Masası. Burada yalnız çağrı izni açılır.
-- 2) ŞİKÂYET BEKLEMEDEN KALDIRMA: mod_kursu_kaldir(p_id, p_gerekce) — aynı 'sikayet' yetkisi, çıkar çatışması/korunan
--    hesap kuralı (korunan_hedef_ceza), yönetim kaydı (akis_gizle), paylaşım sahibine gerekçeli bildirim.
--    mod_kursu_kaldirilanlar(): son 14 günde kaldırılan paylaşımlar (geri yükleme admin_akis_karar(id,'yok_say') ile).
-- 3) PAYLAŞIM ARALIĞI: bir oyuncu Kürsü'de oyun.kursu_ayar.paylasim_aralik_dk (başlangıç 5) dakikada bir paylaşım yapar.
--    Yeni gönderi, alıntı ve kurum adına gönderi sayılır; YANIT sayılmaz. Kurucuya uygulanmaz. Sayaç ayrı tabloda
--    (oyun.kursu_hiz) ve tek ifadede kilitlenir: gönderiyi silip yeniden yazmak ya da aynı anda çok istek atmak aşamaz.
--    Aralık 0 yapılırsa sınır kapanır (Kontrol Merkezi › Veri › oyun.kursu_ayar).
-- 4) TALEP KUTUSU: Yönetime Yaz talepleri artık yalnız ilgili masaya değil bütün oyun yöneticilerine görünür ve hepsi
--    yanıtlayabilir. Korunanlar aynen: kendi açtığı talep, kendisi hakkındaki talep ve Kurucu masasındaki talepler
--    (yönetici hakkındaki şikâyetler, öneriler) görünmez. Yazışmada yanıtlayanın adı yerine görev kodu (G-07) görünür;
--    kurucu kodun yanında kullanıcı adını da görür. Oyuncuya zaten "Oyun Yöneticisi G-07" olarak gidiyordu.
-- Oyuncu verisi değişmez; tekrar çalıştırmak güvenlidir. _yama yardımcısını kullanır (zz_20261121_00_yama.sql).

-- ---------- 2) Şikâyet beklemeden kaldırma ----------
create or replace function public.mod_kursu_kaldir(p_id bigint, p_gerekce text) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet'); a oyun.akis; h oyun.profiller;
  g text := btrim(coalesce(p_gerekce, '')); t timestamptz := oyun.simdi();
begin
  if char_length(g) < 5 or char_length(g) > 300 then
    raise exception 'Kaldırma gerekçesini yaz (5-300 karakter; paylaşımın sahibi görür).';
  end if;
  select * into a from oyun.akis where id = p_id for update;
  if a.id is null then raise exception 'Paylaşım bulunamadı.'; end if;
  if a.gizli then raise exception 'Bu paylaşım zaten kaldırılmış.'; end if;
  select * into h from oyun.profiller where id = a.user_id;
  perform oyun.korunan_hedef_ceza(p, h.id);
  update oyun.akis set gizli = true where id = a.id;
  update oyun.akis_sikayet set durum = 'incelendi' where akis_id = a.id and durum = 'yeni';
  perform oyun.mod_log(p, 'akis_gizle', h.kad, left(a.metin, 300) || ' · Gerekçe: ' || g);
  perform oyun.bildir(h.id, format('Kürsü paylaşımın topluluk kurallarına aykırı bulunduğu için oyun yönetimi tarafından kaldırıldı. Gerekçe: %s · İtiraz için: Ben › Yönetime Yaz.', g), t);
  return jsonb_build_object('tamam', true, 'id', a.id);
end $f$;

create or replace function public.mod_kursu_kaldirilanlar() returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('sikayet');
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'kad', q.kad, 'metin', left(q.metin, 500), 'zaman', q.zaman, 'sikayet', q.sikayet) order by q.zaman desc)
    from (select a.id, pr.kad, a.metin, a.zaman, (select count(*) from oyun.akis_sikayet s where s.akis_id = a.id) sikayet
            from oyun.akis a join oyun.profiller pr on pr.id = a.user_id
           where a.gizli and a.zaman > oyun.simdi() - interval '14 days'
           order by a.zaman desc limit 60) q), '[]'::jsonb);
end $f$;

-- ---------- 3) Paylaşım aralığı ----------
create table if not exists oyun.kursu_ayar(
  id smallint primary key default 1 check (id = 1),
  paylasim_aralik_dk integer not null default 5 check (paylasim_aralik_dk between 0 and 1440),
  guncelleme timestamptz not null default now()
);
insert into oyun.kursu_ayar(id) values (1) on conflict (id) do nothing;
create table if not exists oyun.kursu_hiz(
  user_id uuid primary key references oyun.profiller(id) on delete cascade,
  son timestamptz not null
);
alter table oyun.kursu_ayar enable row level security;
alter table oyun.kursu_hiz enable row level security;
revoke all on oyun.kursu_ayar, oyun.kursu_hiz from public, anon, authenticated;

-- İlk kurulumda son bir saatin gönderileri sayaca işlenir (uygulandığı anda sınır herkes için doğru başlasın).
insert into oyun.kursu_hiz(user_id, son)
select a.user_id, max(a.zaman) from oyun.akis a
 where a.yanit_id is null and a.zaman > now() - interval '1 hour' and a.zaman <= now()
 group by a.user_id
on conflict (user_id) do nothing;

create or replace function oyun.kursu_hiz_kapisi(p oyun.profiller, t timestamptz) returns void
language plpgsql set search_path to '' as $f$
declare dk integer := (select paylasim_aralik_dk from oyun.kursu_ayar where id = 1); v_son timestamptz; kalan integer;
begin
  if coalesce(dk, 0) <= 0 or coalesce(p.yonetici, false) then return; end if;
  if coalesce(current_setting('oyun.kursu_yanit', true), '') = '1' then return; end if;      -- yanıtlar bu sınıra girmez
  insert into oyun.kursu_hiz as k (user_id, son) values (p.id, t)
  on conflict (user_id) do update set son = excluded.son where k.son <= excluded.son - make_interval(mins => dk)
  returning k.son into v_son;
  if v_son is null then
    select k.son into v_son from oyun.kursu_hiz k where k.user_id = p.id;
    kalan := greatest(1, ceil(extract(epoch from (v_son + make_interval(mins => dk) - t)))::integer);
    raise exception 'Kürsü''de % dakikada bir paylaşım yapabilirsin. % sonra yeniden dene (yanıt yazmak serbest).', dk,
      case when kalan >= 60 then (kalan / 60) || ' dk ' || (kalan % 60) || ' sn' else kalan || ' sn' end;
  end if;
end $f$;
revoke all on function oyun.kursu_hiz_kapisi(oyun.profiller, timestamptz) from public, anon, authenticated;

-- akis_yaz: kayıt eklenmeden hemen önce kapı (bütün gönderi yolları — alıntı, kurum adına — bu işlevden geçer)
select oyun._yama('public.akis_yaz(text)',
  '(insert\s+into\s+oyun\.akis\s*\(\s*user_id)',
  '/* kursu_hiz */ perform oyun.kursu_hiz_kapisi(p, t); \1',
  '/* kursu_hiz */');
-- akis_yanit_yaz: yanıt yazarken kapı atlanır (işlem içi işaret; istemci bu ayarı veremez)
select oyun._yama('public.akis_yanit_yaz(bigint,text)',
  'r := public.akis_yaz(p_metin);',
  '/* kursu_yanit */ perform set_config(''oyun.kursu_yanit'', ''1'', true); r := public.akis_yaz(p_metin); perform set_config(''oyun.kursu_yanit'', '''', true);',
  '/* kursu_yanit */', true);

-- ---------- 4) Talep kutusu bütün oyun yöneticilerine açık ----------
create or replace function oyun.mod_kutu_gorur(p oyun.profiller, x oyun.destek_talep) returns boolean
language sql stable set search_path to '' as $f$
  select coalesce(p.yonetici, false)
      or (x.user_id <> p.id and x.hedef is distinct from p.id
          and coalesce(x.masa, 'oyuncu') <> 'kurucu'
          and exists (select 1 from oyun.moderatorler m where m.user_id = p.id))
$f$;
revoke all on function oyun.mod_kutu_gorur(oyun.profiller, oyun.destek_talep) from public, anon, authenticated;

-- Yazışmada yanıtlayan yöneticinin adı yerine görev kodu; kurucu kodun yanında kullanıcı adını da görür
select oyun._yama('oyun.destek_talep_json(oyun.destek_talep,boolean)',
  'when p_gorevli then oyun.kad(m.yazan)',
  'when p_gorevli then /* kutu_kod */ oyun.mod_kod(m.yazan) || case when coalesce((select pv.yonetici from oyun.profiller pv where pv.id = auth.uid()), false) then '' · '' || oyun.kad(m.yazan) else '''' end',
  '/* kutu_kod */', true);

-- ---------- 1) Çağrı izinleri ----------
do $izin$
declare f text;
begin
  foreach f in array array['public.admin_akis_sikayetleri()', 'public.admin_akis_karar(bigint,text)',
      'public.mod_kursu_kaldir(bigint,text)', 'public.mod_kursu_kaldirilanlar()'] loop
    if to_regprocedure(f) is not null then
      execute format('revoke all on function %s from public, anon', f);
      execute format('grant execute on function %s to authenticated', f);
    end if;
  end loop;
end $izin$;

commit;
