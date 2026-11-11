-- =====================================================================
--  184 (11.11.2026) · YAZI KARAKTER SINIRLARI ARTIRILDI
--  Oyuncuların yazdığı gövde metinlerinin (sohbet, Kürsü/akış, özel mesaj, gerekçe, savunma, dava iddiası,
--  dilekçe, rapor, gazete yazısı, kitap…) üst sınırı büyütülür. Ad, başlık, slogan gibi kısa alanlar
--  (200 karakter ve altı) ve görsel sığdırma gerektiren alanlar (afiş, pano, biyografi) DEĞİŞMEZ.
--
--  Yöntem: fonksiyon gövdelerindeki sınır karşılaştırmaları, metin_temizle(x, N) çağrıları ve hata
--  mesajlarındaki "20–1000 karakter" gibi sayılar aşağıdaki tabloya göre yeniden yazılır; tablo CHECK
--  kısıtları aynı tabloyla genişletilir. Yalnız sınır GENİŞLER; mevcut hiçbir kayıt geçersiz olmaz.
--  Bir kez çalışır (oyun.metin_sinir_surum işareti). Yeni yazılan kodda yeni sınırları kullanın.
--  Canlıda uygulandı: 11.11.2026 05:32 (sürüm 2) ve 05:33 (sürüm 3). İstemci karşılığı: build/metin_sinir_istemci.py.
-- =====================================================================
create table if not exists oyun.metin_sinir_surum (surum int primary key, uygulandi timestamptz not null default now(), ozet jsonb);
alter table oyun.metin_sinir_surum enable row level security;
revoke all on oyun.metin_sinir_surum from public, anon, authenticated;

create or replace function oyun.metin_sinir_uygula(p_kuru boolean default true) returns jsonb
language plpgsql set search_path = '' as $sinir$
declare
  esle jsonb := '{"280":1000,"300":1000,"350":1000,"400":1500,"450":1500,"500":1500,"600":2000,"700":2000,"750":2000,
                  "800":2000,"850":2000,"900":2500,"1000":3000,"1200":3000,"1500":4000,"1600":5000,"2000":5000,
                  "2500":6000,"3000":8000,"5000":15000,"6000":12000,"15000":50000}';
  -- görsel sığdırma, kimlik/biyografi, yönetici portalı ve sistem işlevleri hariç
  haric text := '^(afis_|pano_|cihaz_kaydet$|kimlik_guncelle$|gazete_detay$|metin_temizle$|yp_|ymf_|ym_fezleke|metin_sinir_uygula$)';
  desen text[] := array[
    -- karşılaştırma: char_length(x) > N | length(x)>N | ... not between a and N
    '((?:char_length|length)\([^;]{0,90}?\)\s*(?:not\s+between\s+\d+\s+and\s+|>\s*))(\d+)()',
    -- metin_temizle(p_metin, N)  (gazete özeti hariç)
    '(metin_temizle\((?:p_[a-z_]+|m|gr|coalesce\(p_[a-z_]+,\s*''''\)),\s*)(\d+)(\))',
    -- mesaj: "20–1000 karakter", "20-1200 karakter"
    '(\d+\s*(?:–|-|ile)\s*)(\d{1,3}(?:\.\d{3})+|\d+)(\s*karakter)',
    -- mesaj: "en fazla 5000 karakter"
    '((?:en fazla|en çok|azami|en fazla da)\s+)(\d{1,3}(?:\.\d{3})+|\d+)(\s*karakter)',
    -- mesaj: "1600 karakteri aşamaz", "500 karakterden uzun olamaz"
    '(\s)(\d{1,3}(?:\.\d{3})+|\d+)(\s*karakter(?:i|den)\s*(?:aşamaz|geçemez|uzun|fazla))'
  ];
  ornek jsonb := '[]'::jsonb;
  r record; d text; yeni text; m text[]; s text; ns text; n text; v int; i int; j int;
  eski_l text[]; yeni_l text[]; say int := 0; atla int := 0; kayit jsonb := '[]'::jsonb;
  c record; cdef text; cnew text;
begin
  if exists (select 1 from oyun.metin_sinir_surum where surum = 2) then
    return jsonb_build_object('durum', 'zaten uygulanmış');
  end if;

  for r in select p.oid, p.proname, n2.nspname from pg_proc p join pg_namespace n2 on n2.oid = p.pronamespace
            where n2.nspname in ('oyun','public') and p.prokind in ('f','p')
              and pg_get_userbyid(p.proowner) = current_user
              and not exists (select 1 from pg_depend dp where dp.objid = p.oid and dp.deptype = 'e')
              and p.proname !~ haric loop
    d := pg_get_functiondef(r.oid);
    eski_l := '{}'; yeni_l := '{}';
    for i in 1 .. array_length(desen, 1) loop
      -- 'gi': büyük harfle yazılmış eski fonksiyonlar (IF char_length(x) NOT BETWEEN ...) da yakalanır.
      -- Canlıda bu iki geçiş ayrı yapıldı: sürüm 2 (küçük harf, 152 fonksiyon) + sürüm 3 (büyük harf, 38 fonksiyon).
      for m in select regexp_matches(d, desen[i], 'gi') loop
        n := replace(m[2], '.', '');
        if esle ? n then
          v := (esle ->> n)::int;
          s := m[1] || m[2] || m[3];
          -- mesajda "1.000" yazılmışsa yenisi de noktalı yazılır
          ns := m[1] || case when m[2] like '%.%' then regexp_replace(v::text, '(\d)(?=(\d{3})+$)', '\1.', 'g') else v::text end || m[3];
          if not (s = any(eski_l)) then eski_l := eski_l || s; yeni_l := yeni_l || ns; end if;
        end if;
      end loop;
    end loop;
    if coalesce(array_length(eski_l, 1), 0) = 0 then continue; end if;
    -- önce yer tutucu, sonra yeni değer (1000→3000 ardından 3000→8000 zinciri oluşmasın)
    yeni := d;
    for j in 1 .. array_length(eski_l, 1) loop yeni := replace(yeni, eski_l[j], chr(1) || j || chr(2)); end loop;
    for j in 1 .. array_length(eski_l, 1) loop yeni := replace(yeni, chr(1) || j || chr(2), yeni_l[j]); end loop;
    if yeni = d then continue; end if;
    if p_kuru then
      say := say + 1;
      if jsonb_array_length(ornek) < 400 then
        for j in 1 .. array_length(eski_l, 1) loop ornek := ornek || jsonb_build_array(r.proname || ': ' || eski_l[j] || '  →  ' || yeni_l[j]); end loop;
      end if;
      continue;
    end if;
    begin
      execute yeni;
      say := say + 1;
      kayit := kayit || jsonb_build_object('f', r.nspname || '.' || r.proname, 'n', array_length(eski_l, 1));
    exception when others then
      atla := atla + 1;
      raise warning '184 atlandı (%.%): %', r.nspname, r.proname, sqlerrm;
    end;
  end loop;

  -- Tablo CHECK kısıtları: üst sınır aynı tabloyla genişler
  for c in select con.oid, con.conname, con.conrelid::regclass::text tbl, pg_get_constraintdef(con.oid) def
             from pg_constraint con
            where con.contype = 'c' and con.connamespace in ('oyun'::regnamespace, 'public'::regnamespace)
              and pg_get_constraintdef(con.oid) ~* 'length'
              and con.conrelid::regclass::text not in ('oyun.oyuncu_kimlik','oyun.parti_kimlik','oyun.banka_politika','oyun.kursu_profil','oyun.ym_fezleke') loop
    cdef := c.def; cnew := cdef;
    for m in select regexp_matches(cdef, '(<=\s*)(\d+)(\))', 'g') loop
      if esle ? m[2] then
        cnew := replace(cnew, m[1] || m[2] || m[3], m[1] || case when c.tbl = 'oyun.adliye_davalar' then '8000' else esle ->> m[2] end || m[3]);
      end if;
    end loop;
    if cnew <> cdef and p_kuru then
      ornek := ornek || jsonb_build_array(c.tbl || ': ' || cdef || '  →  ' || cnew);
    elsif cnew <> cdef then
      begin
        execute format('alter table %s drop constraint %I', c.tbl, c.conname);
        execute format('alter table %s add constraint %I %s not valid', c.tbl, c.conname, cnew);
        execute format('alter table %s validate constraint %I', c.tbl, c.conname);
        kayit := kayit || jsonb_build_object('k', c.tbl || '.' || c.conname);
      exception when others then
        raise warning '184 kısıt atlandı (%): %', c.conname, sqlerrm;
      end;
    end if;
  end loop;

  if p_kuru then return jsonb_build_object('kuru', true, 'fonksiyon', say, 'degisiklik', ornek); end if;
  insert into oyun.metin_sinir_surum(surum, ozet) values (2, jsonb_build_object('fonksiyon', say, 'atlanan', atla, 'ayrinti', kayit));
  return jsonb_build_object('fonksiyon', say, 'atlanan', atla);
end
$sinir$;
revoke all on function oyun.metin_sinir_uygula(boolean) from public, anon, authenticated;
-- Kurulumda bir kez uygula (işaret varsa hiçbir şey yapmaz)
select oyun.metin_sinir_uygula(false);
