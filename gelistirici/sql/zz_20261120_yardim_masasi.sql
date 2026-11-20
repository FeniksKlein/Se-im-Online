-- 20.11.2026 · YARDIM MASASI (Ercan'ın kararı, moderatör ekibinin isteği)
-- İstek: oyuna yeni girenler bazı şeyleri bulamayacak; yönetimle hem talep (ticket) gibi hem de sohbet odası gibi
--        yazışabilsinler, yöneticinin adı görünmesin.
--   1) Sohbet › "Yardım Masası" kanalı (kod: yardim): herkes okur ve soru yazar; deneyimli oyuncular da yanıtlayabilir.
--   2) Oyun yöneticileri (gizlilik sözleşmesini kabul etmiş moderatörler ve kurucu) public.yardim_yanitla ile
--      YÖNETİM ADINA yazar: mesajda kullanıcı adı, parti ve unvan yerine "Oyun Yöneticisi G-06 · Oyun Yönetimi" görünür.
--      Aynı yönetici isterse sıradan oyuncu gibi de (sohbet_yaz) yazabilir. Kimin hangi yanıtı yazdığı yalnız
--      yönetim kaydında (mod_kayit: yardim_yanit) durur.
--   3) Gizlilik: yönetim yanıtında gerçek ad hiçbir oyuncu yüzeyinde dönmez (sohbet_oku, liste özeti, sohbet nöbeti,
--      oyuncu dosyası). Yönetim yanıtı şikâyetle gizlenemez; engelleme listesi bu yanıtları saklamaz.
--   4) Eski mağaza sürümleri etkilenmez: kanal, sohbet_ozet içinde ayrı "yardim" anahtarıyla döner (kanallar listesine
--      ve toplam okunmamış sayısına girmez).
--   5) Yönetime Yaz'a "Soru / Yardım" konusu eklendi (Oyuncu Masası'na düşer).
-- Oyuncu verisi değişmez. Tekrar çalıştırmak güvenlidir.

alter table oyun.mesajlar add column if not exists gorevli boolean not null default false;

-- ---------- Kim yönetim adına yanıtlayabilir ----------
create or replace function oyun.yardim_gorevli_mi(p oyun.profiller)
 returns boolean
 language sql
 stable
 set search_path to ''
as $function$
  select p.id is not null and not coalesce(p.yasakli, false)
     and (coalesce(p.yonetici, false)
          or exists (select 1 from oyun.moderatorler m where m.user_id = p.id and m.sozlesme_at is not null))
$function$;

-- ---------- Liste özeti (sohbet_ozet içinde ayrı anahtar) ----------
create or replace function oyun.yardim_ozet(p oyun.profiller, t timestamp with time zone)
 returns jsonb
 language plpgsql
 stable
 set search_path to ''
as $function$
declare imlec bigint; okunmamis int; son jsonb; gorevli boolean := oyun.yardim_gorevli_mi(p); bekleyen int;
begin
  select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = 'yardim';
  select count(*) into okunmamis from (
    select 1 from oyun.mesajlar m where m.kanal = 'yardim' and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
       and m.zaman <= t and m.zaman > t - interval '3 days' and (m.gorevli or not oyun.engelli(p.id, m.user_id)) limit 100) x;
  select jsonb_build_object('kad', case when m.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
                            'metin', m.metin, 'zaman', m.zaman, 'gorevli', m.gorevli) into son
    from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
   where m.kanal = 'yardim' and not m.gizli and m.zaman <= t and (m.gorevli or not oyun.engelli(p.id, m.user_id))
   order by m.id desc limit 1;
  if gorevli then
    -- son yönetim yanıtından sonra yazılmış oyuncu mesajları (yanıt bekleyen sorular)
    select count(*) into bekleyen from (
      select 1 from oyun.mesajlar m where m.kanal = 'yardim' and not m.gizli and not m.gorevli and m.zaman <= t and m.zaman > t - interval '24 hours'
         and m.id > coalesce((select max(g.id) from oyun.mesajlar g where g.kanal = 'yardim' and g.gorevli and not g.gizli), 0) limit 100) z;
  end if;
  return jsonb_build_object('kanal', 'yardim', 'baslik', 'Yardım Masası', 'kilit', null, 'yazabilir', true,
    'okunmamis', okunmamis, 'son', son, 'sinyal', 'sohbet:yardim', 'gorevli', gorevli, 'bekleyen', bekleyen);
end $function$;

-- ---------- Okuma: yönetim yanıtında kimlik yerine görev unvanı ----------
create or replace function public.sohbet_oku(p_kanal text, p_once bigint default null::bigint, p_sonra bigint default null::bigint)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb; son bigint;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id,
            'kad', case when x.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
            'metin', x.metin, 'zaman', x.zaman,
            'parti', case when x.gorevli then null else oyun.parti_json(pr.parti_id) end,
            'unvan', case when x.gorevli then 'Oyun Yönetimi' else oyun.unvan(x.user_id) end,
            'benim', x.user_id = p.id, 'gorevli', x.gorevli) order by x.id), '[]'::jsonb)
    into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal = k and not m.gizli and m.zaman <= oyun.simdi() and (m.gorevli or not oyun.engelli(p.id, m.user_id))
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
    'baslik', oyun.kanal_baslik(p, p_kanal), 'sinyal', 'sohbet:' || k,
    'gorevli_yazabilir', k = 'yardim' and oyun.yardim_gorevli_mi(p));
end $function$;

-- ---------- Yönetim adına yanıt ----------
create or replace function public.yardim_yanitla(p_metin text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m text;
begin
  if not oyun.yardim_gorevli_mi(p) then
    raise exception 'Yardım Masası''nda oyun yönetimi adına yalnız oyun yöneticileri yanıt verebilir.';
  end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 1500);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman, gorevli) values ('yardim', p.id, m, t, true);
  update oyun.profiller set son_mesaj = t where id = p.id;
  perform oyun.mod_log(p, 'yardim_yanit', null, m);
  return jsonb_build_object('tamam', true);
end $function$;

-- ---------- Yönetime Yaz: "Soru / Yardım" konusu ----------
create or replace function oyun.destek_konu_tanim()
 returns table(kod text, ad text, aciklama text, masa text, kategori text, sira integer)
 language sql
 immutable
 set search_path to ''
as $function$
  values
  ('soru',    'Soru / Yardım',          'Bulamadığın bir ekran, anlamadığın bir kural ya da nasıl yapılacağını bilmediğin bir işlem.', 'oyuncu', 'diger', 0),
  ('sikayet', 'Oyuncu şikâyeti',        'Küfür, hakaret, taciz, bölücü ya da uygunsuz içerik; bir oyuncunun davranışı.', 'icerik', 'oyuncu', 1),
  ('hile',    'Para ve hile ihbarı',    'Banka, şirket, borsa, kredi ya da havale ile haksız kazanç; çoklu hesapla para aktarma.', 'finans', 'oyuncu', 2),
  ('sahte',   'Sahte / çoklu hesap',    'Aynı kişinin birden çok hesabı, seçimde hile şüphesi, uygunsuz kullanıcı adı.', 'oyuncu', 'oyuncu', 3),
  ('itiraz',  'Yaptırıma itiraz',       'Susturma, kısıt, içerik kaldırma ya da başka bir yönetim kararına itiraz.', 'oyuncu', 'hesap', 4),
  ('hesap',   'Hesap sorunu',           'Giriş, kayıt, kullanıcı adı, satın alma ve hesapla ilgili sorunlar.', 'oyuncu', 'hesap', 5),
  ('hata',    'Oyunda hata',            'Çalışmayan ekran, yanlış hesaplama, takılan işlem.', 'oyuncu', 'hata', 6),
  ('oneri',   'Öneri',                  'Oyuna eklenmesini ya da değişmesini istediğin şey.', 'kurucu', 'oneri', 7),
  ('diger',   'Diğer',                  'Yukarıdakilere uymayan her şey.', 'oyuncu', 'diger', 8)
$function$;

-- ---------- Yerinde yamalar ----------
do $yama$
declare s text;
begin
  -- Kanal çözümü, başlığı ve moderasyon görünürlüğü
  s := pg_get_functiondef('oyun.kanal_coz(oyun.profiller, text)'::regprocedure);
  if position('''yardim''' in s) = 0 then
    s := replace(s, 'when ''genel'' then ''genel''', 'when ''genel'' then ''genel'' when ''yardim'' then ''yardim''');
    execute s;
  end if;
  s := pg_get_functiondef('oyun.kanal_baslik(oyun.profiller, text)'::regprocedure);
  if position('''yardim''' in s) = 0 then
    s := replace(s, 'when ''genel'' then ''Türkiye Meydanı''', 'when ''genel'' then ''Türkiye Meydanı'' when ''yardim'' then ''Yardım Masası''');
    execute s;
  end if;
  s := pg_get_functiondef('oyun.mod_kanal_acik(text)'::regprocedure);
  if position('''yardim''' in s) = 0 then
    s := replace(s, 'k = ''genel'' or', 'k = ''genel'' or k = ''yardim'' or');
    execute s;
  end if;
  s := pg_get_functiondef('oyun.mod_kanal_ad(text)'::regprocedure);
  if position('''yardim''' in s) = 0 then
    s := replace(s, 'when ''genel'' then ''Genel''', 'when ''genel'' then ''Genel'' when ''yardim'' then ''Yardım Masası''');
    execute s;
  end if;

  -- Liste özeti: Yardım Masası ayrı anahtarda (eski sürümlerin kanal listesine ve okunmamış toplamına girmez)
  s := pg_get_functiondef('public.sohbet_ozet()'::regprocedure);
  if position('yardim_ozet' in s) = 0 then
    s := replace(s, 'return jsonb_build_object(''kanallar'', liste,', 'return jsonb_build_object(''yardim'', oyun.yardim_ozet(p, t), ''kanallar'', liste,');
    execute s;
  end if;

  -- Yönetim yanıtı "moderatör olduğunu söyleme" süzgecine takılmaz (zaten görev unvanıyla yayımlanır)
  s := pg_get_functiondef('oyun.tg_mod_ifsa()'::regprocedure);
  if position('j->>''gorevli''' in s) = 0 then
    s := replace(s, 'if coalesce(j->>''tur'', '''') = ''sistem'' then return new; end if;',
                    'if coalesce(j->>''tur'', '''') = ''sistem'' then return new; end if;' || E'\n' ||
                    '  if coalesce(j->>''gorevli'', '''') = ''true'' then return new; end if;');
    execute s;
  end if;

  -- Yönetim yanıtı şikâyetle gizlenemez
  s := pg_get_functiondef('public.sikayet_et(text, bigint, text, text)'::regprocedure);
  if position('and gorevli) then raise' in s) = 0 then
    s := replace(s, 'if p_tur = ''mesaj'' then select user_id into hedef from oyun.mesajlar where id = p_id;',
                    'if p_tur = ''mesaj'' and exists (select 1 from oyun.mesajlar where id = p_id and gorevli) then raise exception ''Oyun yönetiminin yanıtları şikâyet edilemez. İtirazın varsa Ben › Yönetime Yaz ekranından yazabilirsin.''; end if;' || E'\n' ||
                    '  if p_tur = ''mesaj'' then select user_id into hedef from oyun.mesajlar where id = p_id;');
    execute s;
  end if;

  -- Sohbet nöbeti: yönetim yanıtı görev unvanıyla görünür
  s := pg_get_functiondef('public.mod_sohbet_nobeti(text, boolean, bigint, integer)'::regprocedure);
  if position('x.gorevli' in s) = 0 then
    s := replace(s, '''kad'', pr.kad,', '''kad'', case when x.gorevli then oyun.mod_imza(pr) else pr.kad end, ''gorevli'', x.gorevli,');
    execute s;
  end if;

  -- Oyuncu dosyası: yönetim adına yazılan yanıtlar kişinin mesaj listesinde yalnız kurucuya görünür
  s := pg_get_functiondef('public.yk_oyuncu(text)'::regprocedure);
  if position('not gorevli or' in s) = 0 then
    s := replace(s, 'from (select * from oyun.mesajlar where user_id = h.id order by id desc limit 10) m)',
                    'from (select * from oyun.mesajlar where user_id = h.id and (not gorevli or coalesce((select yy.yonetici from oyun.profiller yy where yy.id = auth.uid()), false)) order by id desc limit 10) m)');
    execute s;
  end if;
  s := pg_get_functiondef('public.admin_oyuncu(text)'::regprocedure);
  if position('not gorevli or' in s) = 0 then
    s := replace(s, 'from (select * from oyun.mesajlar where user_id = h.id order by id desc limit 15) m)',
                    'from (select * from oyun.mesajlar where user_id = h.id and (not gorevli or coalesce((select yy.yonetici from oyun.profiller yy where yy.id = auth.uid()), false)) order by id desc limit 15) m)');
    execute s;
  end if;
end $yama$;

revoke all on function oyun.yardim_gorevli_mi(oyun.profiller) from public, anon, authenticated;
revoke all on function oyun.yardim_ozet(oyun.profiller, timestamp with time zone) from public, anon, authenticated;
revoke all on function public.yardim_yanitla(text) from public, anon;
grant execute on function public.yardim_yanitla(text) to authenticated, service_role;
