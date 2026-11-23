-- Kürsü denetimi + paylaşım aralığı + Talep kutusu · canlıda GERİ ALINAN deneme (sonda kasıtlı hata; hiçbir şey kalıcı olmaz).
do $canli_test$
declare res jsonb := '{}'::jsonb; sahip uuid; icerik uuid; finans uuid; o1 uuid; o2 uuid; r text; x jsonb; id1 bigint; id3 bigint; tk bigint; tkk bigint; tko bigint;
  pf oyun.profiller; d oyun.destek_talep; etiket text := ' ' || substr(md5(random()::text), 1, 8);
begin
  perform set_config('lock_timeout', '4s', true);
  execute $modul$
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

$modul$;
  select id into sahip from oyun.profiller where yonetici and not yasakli order by olusturma limit 1;
  select m.user_id into icerik from oyun.moderatorler m join oyun.profiller p on p.id = m.user_id where m.ana_gorev = 'icerik' and 'sikayet' = any(m.yetkiler) and not p.yasakli and m.sozlesme_at is not null order by m.kod_no limit 1;
  select m.user_id into finans from oyun.moderatorler m join oyun.profiller p on p.id = m.user_id where m.ana_gorev = 'finans' and not p.yasakli and m.sozlesme_at is not null order by m.kod_no limit 1;
  select jsonb_agg(q.id) into x from (select p.id from oyun.profiller p
    where not p.yasakli and not p.yonetici and p.susturma_bitis is null and p.adliye_susturma_bitis is null and p.son_gorulme > now() - interval '1 day'
      and not exists (select 1 from oyun.moderatorler m where m.user_id = p.id)
      and not exists (select 1 from oyun.akis a where a.user_id = p.id and a.zaman > now() - interval '2 hours')
      and exists (select 1 from oyun.cuzdan c where c.user_id = p.id)
    order by p.son_gorulme desc limit 2) q;
  o1 := (x->>0)::uuid; o2 := (x->>1)::uuid;
  res := res || jsonb_build_object('T1_izin', (select jsonb_object_agg(f, (has_function_privilege('anon', f, 'execute'))::text || '/' || (has_function_privilege('authenticated', f, 'execute'))::text)
    from unnest(array['public.admin_akis_sikayetleri()','public.admin_akis_karar(bigint,text)','public.mod_kursu_kaldir(bigint,text)','public.mod_kursu_kaldirilanlar()','oyun.kursu_hiz_kapisi(oyun.profiller,timestamptz)']) f),
    'T1_yama', jsonb_build_object('akis_yaz', position('/* kursu_hiz */' in pg_get_functiondef('public.akis_yaz(text)'::regprocedure)) > 0,
      'yanit', position('/* kursu_yanit */' in pg_get_functiondef('public.akis_yanit_yaz(bigint,text)'::regprocedure)) > 0,
      'json', position('/* kutu_kod */' in pg_get_functiondef('oyun.destek_talep_json(oyun.destek_talep,boolean)'::regprocedure)) > 0),
    'T1_tablo_kapali', not (has_table_privilege('authenticated','oyun.kursu_hiz','select') or has_table_privilege('authenticated','oyun.kursu_ayar','select')));

  -- T2: içerik moderatörü ve kurucu şikâyet listesini açabiliyor; finans ve oyuncu açamıyor
  perform set_config('request.jwt.claim.sub', icerik::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', icerik, 'role', 'authenticated')::text, true);
  res := res || jsonb_build_object('T2_icerik_sikayet', jsonb_array_length(public.admin_akis_sikayetleri()));
  perform set_config('request.jwt.claim.sub', sahip::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', sahip, 'role', 'authenticated')::text, true);
  res := res || jsonb_build_object('T2_kurucu_sikayet', jsonb_array_length(public.admin_akis_sikayetleri()));
  perform set_config('request.jwt.claim.sub', finans::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', finans, 'role', 'authenticated')::text, true);
  begin perform public.admin_akis_sikayetleri(); r := 'FINANS GORDU!'; exception when others then r := sqlerrm; end;
  res := res || jsonb_build_object('T2_finans', r);

  -- T3: paylaşım aralığı
  perform set_config('request.jwt.claim.sub', o1::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', o1, 'role', 'authenticated')::text, true);
  begin perform public.admin_akis_sikayetleri(); r := 'OYUNCU GORDU!'; exception when others then r := sqlerrm; end;
  res := res || jsonb_build_object('T2_oyuncu', r);
  id1 := (public.akis_yaz('Deneme paylaşımı bir' || etiket)->>'id')::bigint;
  begin perform public.akis_yaz('Deneme paylaşımı iki' || etiket); r := 'IKINCI PAYLASIM GECTI!'; exception when others then r := sqlerrm; end;
  res := res || jsonb_build_object('T3_ikinci', r);
  begin perform public.kursu_alinti(id1, 'Deneme alıntı' || etiket); r := 'ALINTI GECTI!'; exception when others then r := left(sqlerrm, 60); end;
  res := res || jsonb_build_object('T3_alinti', r);
  begin perform public.akis_yanit_yaz(id1, 'Deneme yanıt' || etiket); r := 'yanit serbest'; exception when others then r := 'YANIT ENGELLENDI: ' || sqlerrm; end;
  res := res || jsonb_build_object('T3_yanit', r, 'T3_isaret_temiz', coalesce(current_setting('oyun.kursu_yanit', true), '') = '');
  begin perform public.akis_yaz('Deneme paylaşımı yanıttan sonra' || etiket); r := 'YANITTAN SONRA GECTI!'; exception when others then r := left(sqlerrm, 45); end;
  res := res || jsonb_build_object('T3_yanit_sonrasi', r);
  update oyun.kursu_hiz set son = son - interval '5 minutes 1 second' where user_id = o1;
  id3 := (public.akis_yaz('Deneme paylaşımı üç' || etiket)->>'id')::bigint;
  res := res || jsonb_build_object('T3_bes_dk_sonra', id3 is not null,
    'T3_kayit', (select jsonb_build_object('gonderi', count(*) filter (where yanit_id is null), 'yanit', count(*) filter (where yanit_id is not null)) from oyun.akis where user_id = o1 and metin like '%' || etiket));
  perform set_config('request.jwt.claim.sub', sahip::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', sahip, 'role', 'authenticated')::text, true);
  begin perform public.akis_yaz('Kurucu deneme bir' || etiket); perform public.akis_yaz('Kurucu deneme iki' || etiket); r := 'kurucu sinirsiz'; exception when others then r := 'KURUCU ENGELLENDI: ' || sqlerrm; end;
  res := res || jsonb_build_object('T3_kurucu', r);

  -- T4: yönetim kaldırır / geri yükler
  perform set_config('request.jwt.claim.sub', finans::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', finans, 'role', 'authenticated')::text, true);
  begin perform public.mod_kursu_kaldir(id1, 'Deneme gerekçesi yeterli'); r := 'FINANS KALDIRDI!'; exception when others then r := left(sqlerrm, 40); end;
  res := res || jsonb_build_object('T4_finans', r);
  perform set_config('request.jwt.claim.sub', o2::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', o2, 'role', 'authenticated')::text, true);
  begin perform public.mod_kursu_kaldir(id1, 'Deneme gerekçesi yeterli'); r := 'OYUNCU KALDIRDI!'; exception when others then r := left(sqlerrm, 40); end;
  res := res || jsonb_build_object('T4_oyuncu', r);
  perform set_config('request.jwt.claim.sub', icerik::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', icerik, 'role', 'authenticated')::text, true);
  begin perform public.mod_kursu_kaldir(id1, 'kısa'); r := 'KISA GEREKCE GECTI!'; exception when others then r := left(sqlerrm, 40); end;
  res := res || jsonb_build_object('T4_kisa', r);
  begin
    perform public.mod_kursu_kaldir(id1, 'Deneme: hakaret içerdiği için kaldırıldı.');
    res := res || jsonb_build_object('T4_kaldirildi', (select gizli from oyun.akis where id = id1),
      'T4_listede', exists (select 1 from jsonb_array_elements(public.mod_kursu_kaldirilanlar()) e where (e->>'id')::bigint = id1),
      'T4_kayit', (select count(*) from oyun.mod_kayit k where to_jsonb(k)::text like '%akis_gizle%' and to_jsonb(k)::text like '%' || btrim(etiket) || '%'));
    begin perform public.mod_kursu_kaldir(id1, 'Deneme: ikinci kez kaldırma'); r := 'IKI KEZ!'; exception when others then r := sqlerrm; end;
    res := res || jsonb_build_object('T4_tekrar', r);
    perform public.admin_akis_karar(id1, 'yok_say');
    res := res || jsonb_build_object('T4_geri_yuklendi', (select not gizli from oyun.akis where id = id1));
  exception when others then res := res || jsonb_build_object('T4_HATA', sqlerrm);
  end;

  -- T5: Talep kutusu bütün yöneticilere açık; korunanlar aynen
  select * into pf from oyun.profiller where id = finans;
  select * into d from oyun.destek_talep where coalesce(masa, 'oyuncu') = 'icerik' and user_id <> finans and hedef is distinct from finans order by id desc limit 1;
  insert into oyun.destek_talep (user_id, kategori, metin, masa, konu, zaman, son_hareket) values (o2, 'oneri', 'Deneme talebi: kurucu masası (geri alınacak).', 'kurucu', 'oneri', now(), now()) returning id into tkk;
  insert into oyun.destek_talep (user_id, kategori, metin, masa, konu, zaman, son_hareket) values (finans, 'diger', 'Deneme talebi: yöneticinin kendi talebi (geri alınacak).', 'oyuncu', 'diger', now(), now()) returning id into tko;
  res := res || jsonb_build_object('T5_finans_icerik_talebini_gorur', oyun.mod_kutu_gorur(pf, d),
    'T5_kurucu_masasi_gizli', not oyun.mod_kutu_gorur(pf, (select t from oyun.destek_talep t where t.id = tkk)),
    'T5_kendi_talebi_gizli', not oyun.mod_kutu_gorur(pf, (select t from oyun.destek_talep t where t.id = tko)));
  select t.* into d from oyun.destek_talep t where exists (select 1 from oyun.destek_mesaj m where m.talep_id = t.id and m.gorevli) and t.user_id <> finans and t.hedef is distinct from finans and coalesce(t.masa, 'oyuncu') <> 'kurucu' order by t.id desc limit 1;
  perform set_config('request.jwt.claim.sub', finans::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', finans, 'role', 'authenticated')::text, true);
  x := public.mod_kutu('tum');
  res := res || jsonb_build_object('T5_finans_kutu', jsonb_build_object('talep', jsonb_array_length(x->'talepler'),
    'kurucu_masasi_yok', not exists (select 1 from jsonb_array_elements(x->'talepler') e where (e->>'id')::bigint = tkk),
    'kendi_yok', not exists (select 1 from jsonb_array_elements(x->'talepler') e where (e->>'id')::bigint = tko)),
    'T5_yazan_mod', (select jsonb_agg(distinct (m->>'yazan') ~ '^(G-[0-9]{2}|Yönetici|Görevli)$') from jsonb_array_elements(oyun.destek_talep_json(d, true)->'mesajlar') m where (m->>'gorevli')::boolean));
  if d.id is null then raise exception 'GERI_ALINDI (yanıtlanmış talep yok) %', res; end if;
  perform public.mod_kutu_yanitla(d.id, 'Deneme yanıtı (geri alınacak).', false);
  res := res || jsonb_build_object('T5_finans_yanitladi', (select count(*) from oyun.destek_mesaj m where m.talep_id = d.id and m.yazan = finans and m.gorevli),
    'T5_oyuncu_gorur', (select oyun.destek_talep_json(d, false)->'mesajlar'->-1->>'yazan'));
  perform set_config('request.jwt.claim.sub', sahip::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', sahip, 'role', 'authenticated')::text, true);
  res := res || jsonb_build_object('T5_yazan_kurucu', (select bool_and((m->>'yazan') ~ '^(G-[0-9]{2}|Yönetici|Görevli) · .+') from jsonb_array_elements(oyun.destek_talep_json(d, true)->'mesajlar') m where (m->>'gorevli')::boolean));

  -- T6: Yardım Masası (sohbet kanalı) her yönetici için açık ve görev koduyla yanıtlanıyor
  perform set_config('request.jwt.claim.sub', finans::text, true); perform set_config('request.jwt.claims', jsonb_build_object('sub', finans, 'role', 'authenticated')::text, true);
  begin
    x := public.sohbet_oku('yardim');
    perform public.yardim_yanitla('Deneme yanıtı (geri alınacak).');
    res := res || jsonb_build_object('T6_yardim', jsonb_build_object('gorevli_yazabilir', x->'gorevli_yazabilir',
      'imza', (select e->>'kad' from jsonb_array_elements(public.sohbet_oku('yardim')->'mesajlar') e order by (e->>'id')::bigint desc limit 1)));
  exception when others then res := res || jsonb_build_object('T6_HATA', sqlerrm);
  end;
  raise exception 'GERI_ALINDI %', res;
end $canli_test$;
