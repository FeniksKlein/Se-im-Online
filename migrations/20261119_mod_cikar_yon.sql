-- Canlıya 19.11.2026'da Supabase migration'ı olarak uygulandı: mod_cikar_yon_20261119 + mod_cikar_yon_duzeltme_20261119
-- Kaynak: gelistirici/sql/zz_20261119_mod_cikar_yon.sql · tekrar çalıştırmak güvenlidir.
begin;

-- 19.11.2026 · MODERASYON: çıkar çatışması yöne göre daraltıldı (Ercan'ın kararı)
-- Sorun: partiler kalabalıklaştıkça moderatör, önüne gelen işlerin büyük bölümünde "aynı partidesiniz" kilidine takılıyordu;
--        üstelik eski kural yanlış yönü kilitliyordu (ceza yasak, "sorun yok" serbest).
-- Yeni kural (yayın ölçeği, binlerce oyuncu):
--   1) CEZA YÖNÜ SERBEST: moderatör kendi partilisinin içeriğini gizleyebilir, kanıtla susturabilir, inceleme kısıtına alabilir,
--      MASAK ihtarı / el koyma önerebilir. Kendi partilisini cezalandırmada kayırma riski yoktur.
--   2) LEHE KARAR KİLİTLİ: aynı partiden (ya da aynı cihaz / aralarında dava olan) oyuncu için "sorun yok", "temiz",
--      talep reddi, susturma ve engel kaldırma kararı moderatörde değildir.
--   3) TALEP AÇMAK GEREKMEZ: kilitli karar kendiliğinden devredilir (oyun.mod_devir). Yetkili ve çatışmasız en çok 5 moderatöre
--      bildirim gider; tarafsız moderatör yoksa hemen, 2 saat içinde bakılmazsa zamanlayıcıyla yöneticiye gider.
--   4) İZ: her moderasyon kaydına "aynı parti" işareti yazılır (mod_kayit.ayni_parti); yönetici moderatör başına
--      kendi partisine / diğerlerine ceza oranını görür (admin_mod_tarafsizlik).
--   Aynı cihaz ve dava çatışmasında ceza yönü de eskisi gibi kilitlidir (yan hesap / husumet).
-- Oyuncu verisi değişmez. Tekrar çalıştırmak güvenlidir.

-- ---------- Tablo ve sütunlar ----------
alter table oyun.mod_kayit add column if not exists ayni_parti boolean;
create index if not exists mod_kayit_ayni_parti on oyun.mod_kayit(zaman desc) where ayni_parti;
create index if not exists sikayetler_yeni_hedef on oyun.sikayetler(hedef_user) where durum = 'yeni';

create table if not exists oyun.mod_devir (
  id bigint generated always as identity primary key,
  kaynak text not null,
  anahtar text not null,
  hedef uuid,
  devreden uuid not null,
  sebep text,
  zaman timestamptz not null default now(),
  durum text not null default 'acik',
  kapanis timestamptz,
  yonetici_bildirim timestamptz,
  constraint mod_devir_kaynak check (kaynak in ('sikayet','akis','masak','talep')),
  constraint mod_devir_durum check (durum in ('acik','kapandi'))
);
create unique index if not exists mod_devir_acik on oyun.mod_devir(kaynak, anahtar) where durum = 'acik';
create index if not exists mod_devir_zaman on oyun.mod_devir(zaman desc);
alter table oyun.mod_devir enable row level security;
revoke all on oyun.mod_devir from public, anon, authenticated;

-- ---------- Çatışma türleri ----------
-- Hızlı kuyruk işareti: yalnız aynı parti (kuyruk listelerinde satır başına çağrılır)
create or replace function oyun.mod_ayni_parti(p_mod uuid, h uuid) returns boolean
language sql stable set search_path to '' as $$
  select exists (select 1 from oyun.profiller a join oyun.profiller b on b.id = h
                  where a.id = p_mod and a.id <> b.id and not coalesce(a.yonetici, false)
                    and a.parti_id is not null and a.parti_id = b.parti_id)
$$;

-- Ceza yönünü de kilitleyen çatışma: aynı cihaz (yan hesap olabilir) ya da aralarında dava (husumet)
create or replace function oyun.mod_ceza_engeli(p_mod uuid, h uuid) returns text
language sql stable set search_path to '' as $$
  select case
    when coalesce((select yonetici from oyun.profiller where id = p_mod), false) then null
    when exists (select 1 from oyun.bagli_hesaplar(p_mod) x where x = h)
      then 'Çıkar çatışması: bu oyuncuyla aynı cihazı kullanıyorsunuz.'
    when exists (select 1 from oyun.adliye_davalar d where ((d.davaci = p_mod and d.davali = h) or (d.davaci = h and d.davali = p_mod))
                   and (d.durum = 'acik' or d.acilis > oyun.simdi() - interval '30 days'))
      then 'Çıkar çatışması: bu oyuncuyla aranızda dava var.'
  end
$$;

-- Ceza kapısı: koruma + yalnız cihaz/dava çatışması (aynı parti cezaya engel değil)
create or replace function oyun.korunan_hedef_ceza(p oyun.profiller, h uuid) returns void
language plpgsql set search_path to '' as $$
declare c text;
begin
  perform oyun.mod_koruma(p, h);
  c := oyun.mod_ceza_engeli(p.id, h);
  if c is not null then raise exception '% Yaptırım talebi aç; tarafsız başka bir moderatör karar versin.', c; end if;
end $$;

-- Sıkı kapı (lehe kararlar ve yönetim araçları): her çatışmada kapalı
create or replace function oyun.korunan_hedef(p oyun.profiller, h uuid) returns void
language plpgsql set search_path to '' as $$
declare c text;
begin
  perform oyun.mod_koruma(p, h);
  c := oyun.mod_cikar_catismasi(p.id, h);
  if c is not null then
    raise exception '% Bu oyuncu lehine karar veremezsin; kararı tarafsız bir moderatör ya da yönetici vermeli. Gerekirse "Yöneticiye ilet" kullan.', c;
  end if;
end $$;

-- ---------- Denetim günlüğü: aynı parti işareti ----------
create or replace function oyun.mod_log(p oyun.profiller, p_islem text, p_hedef text, p_ayrinti text) returns void
language sql set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $$
  insert into oyun.mod_kayit(zaman, user_id, kad, islem, hedef, ayrinti, ayni_parti)
  values (oyun.simdi(), p.id, p.kad, p_islem, p_hedef, left(p_ayrinti, 300),
          case when p.parti_id is not null and p_hedef is not null
               then exists (select 1 from oyun.profiller b where lower(b.kad) = lower(p_hedef) and b.parti_id = p.parti_id and b.id <> p.id) end)
$$;

create or replace function oyun.mod_islem_yon(p_islem text) returns text
language sql immutable set search_path to '' as $$
  select case
    when p_islem in ('sikayet_gizle','sikayet_gizle_sustur1','sikayet_gizle_sustur7','sikayet_kapat','akis_gizle','akis_gizle_sustur1','acil_gizle',
                     'yk_sustur','sustur1','sustur7','kapat','yk_engel_sureli','yk_engel_kalici','masak_ihtar','masak_el_koy','masak_el_koy_oneri',
                     'talep_ac','talep_onay') then 'ceza'
    when p_islem in ('sikayet_yok_say','akis_yok_say','masak_temiz','talep_ret','susturma_kaldir','yk_engel_kaldir','ac') then 'lehe'
    when p_islem = 'devir' then 'devir'
  end
$$;

-- ---------- Otomatik devir ----------
create or replace function oyun.mod_devir_ac(p oyun.profiller, p_kaynak text, p_anahtar text, h uuid, p_yetki text, p_sebep text, p_parti bigint default null)
returns boolean language plpgsql set search_path to '' as $$
declare t timestamptz := oyun.simdi(); r record; n int := 0; v_id bigint;
        ne text := case p_kaynak when 'sikayet' then 'şikâyet' when 'akis' then 'Kürsü şikâyeti' when 'masak' then 'MASAK kaydı' else 'yaptırım talebi' end;
        yer text := case p_kaynak when 'sikayet' then 'Şikâyet masası' when 'akis' then 'Kürsü şikâyetleri' when 'masak' then 'MASAK' else 'Yaptırım talepleri' end;
        kim text := coalesce(oyun.kad(h), 'kayıt #' || p_anahtar);
begin
  insert into oyun.mod_devir(kaynak, anahtar, hedef, devreden, sebep, zaman)
  values (p_kaynak, p_anahtar, h, p.id, left(p_sebep, 200), t)
  on conflict (kaynak, anahtar) where durum = 'acik' do nothing
  returning id into v_id;
  if v_id is null then
    if not exists (select 1 from oyun.mod_devir d where d.kaynak = p_kaynak and d.anahtar = p_anahtar and d.durum = 'acik' and d.devreden = p.id) then
      perform oyun.bildir(p.id, format('Moderasyon: %s hakkındaki %s zaten tarafsız karar bekliyor; lehine kararın uygulanmadı. Talep açmana gerek yok.', kim, ne), t);
    end if;
    return false;
  end if;
  for r in select m.user_id from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id
            where m.user_id <> p.id and not coalesce(pr.yasakli, false) and not coalesce(pr.yonetici, false)
              and (p_parti is null or pr.parti_id is distinct from p_parti)
              and oyun.yetkili(m.user_id, p_yetki)
              and (h is null or oyun.mod_cikar_catismasi(m.user_id, h) is null)
            order by pr.son_gorulme desc nulls last limit 5 loop
    perform oyun.bildir(r.user_id, format('Moderasyon: %s hakkındaki %s tarafsız karar bekliyor (çıkar çatışması nedeniyle sana düştü). Moderasyon Merkezi › %s.', kim, ne, yer), t);
    n := n + 1;
  end loop;
  if n = 0 then
    for r in select pr.id from oyun.profiller pr where pr.yonetici and not coalesce(pr.yasakli, false) limit 5 loop
      perform oyun.bildir(r.id, format('Moderasyon uyarısı: %s hakkındaki %s için tarafsız moderatör yok (yetkililerin hepsi çıkar çatışmasında). Karar sende: Moderasyon Merkezi › %s.', kim, ne, yer), t);
    end loop;
    update oyun.mod_devir set yonetici_bildirim = t where id = v_id;
  end if;
  perform oyun.mod_log(p, 'devir', oyun.kad(h), format('%s %s · %s%s', ne, p_anahtar, coalesce(p_sebep, ''),
                       case when n = 0 then ' · tarafsız moderatör yok, yöneticiye gitti' else '' end));
  perform oyun.bildir(p.id, format('Moderasyon: %s hakkındaki %s için lehine kararın uygulanmadı (%s). Dosya tarafsız bir moderatöre devredildi; talep açmana gerek yok.%s',
                                   kim, ne, coalesce(nullif(rtrim(regexp_replace(coalesce(p_sebep, ''), '^Çıkar çatışması: ', ''), '.'), ''), 'çıkar çatışması'),
                                   case when h is not null and oyun.mod_ceza_engeli(p.id, h) is null then ' İhlal görüyorsan ceza yönünde işlem yapabilirsin.' else '' end), t);
  return true;
end $$;

-- Devir zamanlayıcısı: sonuçlanan devri kapatır; 2 saattir bekleyenleri tek bildirimle yöneticiye taşır
create or replace function oyun.mod_devir_tick() returns void
language plpgsql security definer set search_path to '' as $$
declare d record; t timestamptz := oyun.simdi(); v_acik boolean; r record; v_n int := 0; v_ornek text;
begin
  for d in select * from oyun.mod_devir where durum = 'acik' order by zaman limit 300 loop
    begin
      v_acik := case d.kaynak
        when 'sikayet' then exists (select 1 from oyun.sikayetler s where s.durum = 'yeni' and s.hedef_user = d.hedef
                                     and s.tur = split_part(d.anahtar, ':', 1) and s.kayit_id = split_part(d.anahtar, ':', 2)::bigint)
        when 'akis' then exists (select 1 from oyun.akis_sikayet s where s.akis_id = d.anahtar::bigint and s.durum = 'yeni')
        when 'masak' then exists (select 1 from oyun.masak k where k.id = d.anahtar::bigint and k.durum = 'yeni')
        when 'talep' then exists (select 1 from oyun.mod_talep z where z.id = d.anahtar::bigint and z.durum = 'acik')
        else false end;
      if not v_acik then
        update oyun.mod_devir set durum = 'kapandi', kapanis = t where id = d.id;
      elsif d.yonetici_bildirim is null and d.zaman < t - interval '2 hours' then
        update oyun.mod_devir set yonetici_bildirim = t where id = d.id;
        v_n := v_n + 1;
        v_ornek := coalesce(v_ornek, oyun.kad(d.hedef), 'kayıt #' || d.anahtar);
      end if;
    exception when others then
      raise warning 'mod_devir_tick #%: %', d.id, sqlerrm;
    end;
  end loop;
  if v_n > 0 then
    for r in select pr.id from oyun.profiller pr where pr.yonetici and not coalesce(pr.yasakli, false) limit 5 loop
      perform oyun.bildir(r.id, case when v_n = 1
        then format('Moderasyon uyarısı: %s hakkındaki dosya 2 saattir tarafsız karar bekliyor (aynı partiden moderatör devretti, kimse bakmadı). Moderasyon Merkezi › Ekip yönetimi › Tarafsızlık.', v_ornek)
        else format('Moderasyon uyarısı: %s dosya 2 saattir tarafsız karar bekliyor (ilki: %s). Moderasyon Merkezi › Ekip yönetimi › Tarafsızlık.', v_n, v_ornek) end, t);
    end loop;
  end if;
end $$;

-- ---------- Mevcut fonksiyonlara yamalar (tek eşleşme şartı, işaretle tekrar güvenli) ----------
create or replace function pg_temp.cy_yama(p_fn regprocedure, p_isaret text, p_eski text, p_yeni text) returns void
language plpgsql as $y$
declare d text := pg_get_functiondef(p_fn); n int;
begin
  if position(p_isaret in d) > 0 then return; end if;
  n := (length(d) - length(replace(d, p_eski, ''))) / length(p_eski);
  if n <> 1 then raise exception 'Yama uygulanamadı: % içinde % eşleşme (beklenen 1): %', p_fn, n, left(p_eski, 70); end if;
  d := replace(d, p_eski, p_yeni);
  if position(p_isaret in d) = 0 then raise exception 'Yama işareti yok: % / %', p_fn, p_isaret; end if;
  execute d;
end $y$;

-- Şikâyet kararı: gizle/sustur = ceza kapısı; "sorun yok" çatışmada devredilir
select pg_temp.cy_yama('public.admin_sikayet_karar(text,bigint,text,text)'::regprocedure, '/* cikar_yon */',
  $e$if p_islem <> 'yok_say' then perform oyun.korunan_hedef(p, h.id); end if;$e$,
  $n$/* cikar_yon */ if p_islem <> 'yok_say' then perform oyun.korunan_hedef_ceza(p, h.id);
  elsif not coalesce(p.yonetici, false) and oyun.mod_cikar_catismasi(p.id, h.id) is not null then
    perform oyun.mod_devir_ac(p, 'sikayet', p_tur || ':' || coalesce(p_kayit, 0)::text || ':' || h.id::text, h.id, 'sikayet', oyun.mod_cikar_catismasi(p.id, h.id));
    return public.admin_sikayetler('yeni');
  end if;$n$);

-- Kürsü paylaşımı kararı
select pg_temp.cy_yama('public.admin_akis_karar(bigint,text)'::regprocedure, '/* cikar_yon */',
  $e$if p_islem <> 'yok_say' then perform oyun.korunan_hedef(p, h.id); end if;$e$,
  $n$/* cikar_yon */ if p_islem <> 'yok_say' then perform oyun.korunan_hedef_ceza(p, h.id);
  elsif not coalesce(p.yonetici, false) and oyun.mod_cikar_catismasi(p.id, h.id) is not null then
    perform oyun.mod_devir_ac(p, 'akis', p_id::text, h.id, 'sikayet', oyun.mod_cikar_catismasi(p.id, h.id));
    return public.admin_akis_sikayetleri();
  end if;$n$);

-- Eski panel işlemleri: susturma/kapatma = ceza; susturma kaldırma/açma = lehe (sıkı kapı)
select pg_temp.cy_yama('public.admin_islem(text,text)'::regprocedure, '/* cikar_yon */',
  $e$perform oyun.korunan_hedef(p, h.id);$e$,
  $n$/* cikar_yon */ if p_islem in ('sustur1','sustur7','kapat') then perform oyun.korunan_hedef_ceza(p, h.id); else perform oyun.korunan_hedef(p, h.id); end if;$n$);

select pg_temp.cy_yama('public.yk_sustur(text,numeric,text)'::regprocedure, '/* cikar_yon */',
  $e$perform oyun.korunan_hedef(p, h.id);$e$,
  $n$/* cikar_yon */ if coalesce(p_saat, 0) > 0 then perform oyun.korunan_hedef_ceza(p, h.id); else perform oyun.korunan_hedef(p, h.id); end if;$n$);

select pg_temp.cy_yama('public.yk_engelle(text,numeric,text,boolean)'::regprocedure, '/* cikar_yon */',
  $e$perform oyun.korunan_hedef(p, h.id);$e$,
  $n$/* cikar_yon */ perform oyun.korunan_hedef_ceza(p, h.id);$n$);

-- MASAK: ihtar / el koyma = ceza; "temiz" çatışmada devredilir
select pg_temp.cy_yama('public.admin_masak_karar(bigint,text,numeric,text)'::regprocedure, '/* cikar_yon */',
  $e$if m.user_id is not null then perform oyun.korunan_hedef(p, m.user_id); end if;$e$,
  $n$/* cikar_yon */ if m.user_id is not null then
    if p_karar <> 'temiz' then perform oyun.korunan_hedef_ceza(p, m.user_id);
    else
      perform oyun.mod_koruma(p, m.user_id);
      if not coalesce(p.yonetici, false) and oyun.mod_cikar_catismasi(p.id, m.user_id) is not null then
        perform oyun.mod_devir_ac(p, 'masak', m.id::text, m.user_id, 'ekonomi', oyun.mod_cikar_catismasi(p.id, m.user_id));
        return public.admin_masak('yeni') || jsonb_build_object('cift_onay', 'Çıkar çatışması: "temiz" kararı tarafsız bir MASAK görevlisine devredildi.');
      end if;
    end if;
  end if;$n$);
select pg_temp.cy_yama('public.admin_masak_karar(bigint,text,numeric,text)'::regprocedure, '/* cikar_yon_parti */',
  $e$if m.parti_id is not null and m.parti_id = p.parti_id then raise exception 'Çıkar çatışması: kayıt kendi partinle ilgili; kararı başka bir MASAK görevlisi vermeli.'; end if;$e$,
  $n$/* cikar_yon_parti */ if m.parti_id is not null and m.parti_id = p.parti_id and p_karar = 'temiz' then
      perform oyun.mod_devir_ac(p, 'masak', m.id::text, m.user_id, 'ekonomi', 'Çıkar çatışması: kayıt moderatörün kendi partisiyle ilgili.', m.parti_id);
      return public.admin_masak('yeni') || jsonb_build_object('cift_onay', 'Çıkar çatışması: kayıt kendi partinle ilgili; "temiz" kararı tarafsız bir MASAK görevlisine devredildi.');
    end if;$n$);

-- Yaptırım talebi: geçici susturma ve inceleme kısıtı aynı partide de uygulanır (ceza yönü)
select pg_temp.cy_yama('public.mod_talep_ac(text,text,numeric,text,text)'::regprocedure, '/* cikar_yon_s */',
  $e$if p_tur = 'sustur' and oyun.mod_cikar_catismasi(p.id, h.id) is null$e$,
  $n$if p_tur = 'sustur' and oyun.mod_ceza_engeli(p.id, h.id) is null /* cikar_yon_s */$n$);
select pg_temp.cy_yama('public.mod_talep_ac(text,text,numeric,text,text)'::regprocedure, '/* cikar_yon_e */',
  $e$and oyun.mod_cikar_catismasi(p.id, h.id) is null$e$,
  $n$and oyun.mod_ceza_engeli(p.id, h.id) is null /* cikar_yon_e */$n$);

-- Moderatör şikâyetiyle anında gizleme: aynı partide de çalışır
select pg_temp.cy_yama('public.akis_sikayet_et(bigint,text)'::regprocedure, '/* cikar_yon */',
  $e$and oyun.mod_cikar_catismasi(p.id, hedef) is null$e$,
  $n$and oyun.mod_ceza_engeli(p.id, hedef) is null /* cikar_yon */$n$);
select pg_temp.cy_yama('public.sikayet_et(text,bigint,text,text)'::regprocedure, '/* cikar_yon */',
  $e$and oyun.mod_cikar_catismasi(p.id, hedef) is null$e$,
  $n$and oyun.mod_ceza_engeli(p.id, hedef) is null /* cikar_yon */$n$);

-- Talebi reddetmek lehe karardır: çatışmada devredilir
select pg_temp.cy_yama('public.mod_talep_karar(bigint,boolean,text)'::regprocedure, '/* cikar_yon */',
  $e$if not p_onay and n is null then raise exception 'Reddederken kısa bir gerekçe yaz.'; end if;$e$,
  $n$if not p_onay and n is null then raise exception 'Reddederken kısa bir gerekçe yaz.'; end if;
  /* cikar_yon */ if not p_onay and not coalesce(p.yonetici, false) and x.tur in ('engel','sustur') and oyun.mod_cikar_catismasi(p.id, x.hedef) is not null then
    perform oyun.mod_devir_ac(p, 'talep', x.id::text, x.hedef, case x.tur when 'engel' then 'hesap_kapat' else 'sustur' end, oyun.mod_cikar_catismasi(p.id, x.hedef));
    return public.mod_talepler();
  end if;$n$);

-- Kuyruk listeleri: "kilit" (aynı parti: lehe karar sende değil) ve "devir" (tarafsız karar bekliyor) işaretleri
select pg_temp.cy_yama('oyun.mod_talep_json(oyun.mod_talep,uuid)'::regprocedure, $i$'kilit', $i$,
  $e$'benim', x.talep_eden = ben, 'gecici_bitis', x.gecici_bitis,$e$,
  $n$'benim', x.talep_eden = ben, 'gecici_bitis', x.gecici_bitis,
    'kilit', case when x.durum = 'acik' then oyun.mod_ayni_parti(ben, x.hedef) else false end,
    'devir', exists (select 1 from oyun.mod_devir dv where dv.kaynak = 'talep' and dv.anahtar = x.id::text and dv.durum = 'acik'),$n$);
select pg_temp.cy_yama('public.admin_sikayetler(text)'::regprocedure, $i$'kilit', $i$,
  $e$'hedef_sikayet_toplam', (select count(*) from oyun.sikayetler z where z.hedef_user = s.hedef_user)) x$e$,
  $n$'hedef_sikayet_toplam', (select count(*) from oyun.sikayetler z where z.hedef_user = s.hedef_user),
      'kilit', oyun.mod_ayni_parti(p.id, s.hedef_user),
      'devir', exists (select 1 from oyun.mod_devir dv where dv.kaynak = 'sikayet' and dv.durum = 'acik' and dv.hedef = s.hedef_user
                          and dv.anahtar = s.tur || ':' || s.kayit_id::text || ':' || s.hedef_user::text)) x$n$);
select pg_temp.cy_yama('public.admin_akis_sikayetleri()'::regprocedure, $i$'kilit', $i$,
  $e$'nedenler', jsonb_agg(distinct s.neden), 'ilk', min(s.zaman)) x$e$,
  $n$'nedenler', jsonb_agg(distinct s.neden), 'ilk', min(s.zaman),
             'kilit', oyun.mod_ayni_parti(p.id, (array_agg(a.user_id))[1]),
             'devir', exists (select 1 from oyun.mod_devir dv where dv.kaynak = 'akis' and dv.durum = 'acik' and dv.anahtar = a.id::text)) x$n$);

-- Oyuncu dosyası: cikar_catismasi artık yalnız cezayı da kilitleyen çatışmadır (eski uygulama düğmeleri doğru göstersin);
-- lehe_kilit her çatışmayı döndürür (yeni uygulama "kaldır" düğmelerini gizler)
select pg_temp.cy_yama('public.mod_dosya(text)'::regprocedure, $i$'lehe_kilit'$i$,
  $e$'cikar_catismasi', oyun.mod_cikar_catismasi(p.id, h.id),$e$,
  $n$'cikar_catismasi', oyun.mod_ceza_engeli(p.id, h.id), 'lehe_kilit', oyun.mod_cikar_catismasi(p.id, h.id),$n$);

-- ---------- Yönetici: tarafsızlık paneli ----------
-- Sayım, "aynı parti" işaretinin yazılmaya başladığı andan (19.11.2026) itibaren yapılır; önceki kayıtlarda işaret yoktur.
create or replace function public.admin_mod_tarafsizlik(p_gun integer default 30)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi();
        g int := least(greatest(coalesce(p_gun, 30), 1), 180);
        bas timestamptz := greatest(timestamptz '2026-11-19 12:25:00+00', t - make_interval(days => least(greatest(coalesce(p_gun, 30), 1), 180)));
begin
  return jsonb_build_object(
    'gun', g, 'baslangic', bas,
    'moderatorler', coalesce((select jsonb_agg(jsonb_build_object(
          'kad', y.kad, 'kod', y.kod, 'birim', y.birim, 'parti', y.parti,
          'ceza_ayni', y.ceza_ayni, 'lehe_ayni', y.lehe_ayni, 'devir', y.devir, 'ceza_diger', y.ceza_diger, 'lehe_diger', y.lehe_diger,
          'oran_ayni', round(y.oran_ayni), 'oran_diger', round(y.oran_diger),
          'isaret', case when y.isaretli then case when y.oran_ayni < y.oran_diger then 'yumusak' else 'sert' end end)
        order by y.isaretli desc, (y.top_ayni + y.top_diger) desc, y.kad)
      from (select z.*, 100.0 * z.ceza_ayni / nullif(z.top_ayni, 0) oran_ayni, 100.0 * z.ceza_diger / nullif(z.top_diger, 0) oran_diger,
                   coalesce(z.top_ayni >= 8 and z.top_diger >= 8
                            and abs(100.0 * z.ceza_ayni / nullif(z.top_ayni, 0) - 100.0 * z.ceza_diger / nullif(z.top_diger, 0)) >= 30, false) isaretli
              from (select pr.kad, oyun.mod_kod(m.user_id) kod, m.ana_gorev birim, (select pt.kisa from oyun.partiler pt where pt.id = pr.parti_id) parti,
                           s.ceza_ayni, s.lehe_ayni, s.devir, s.ceza_diger, s.lehe_diger,
                           s.ceza_ayni + s.lehe_ayni + s.devir top_ayni, s.ceza_diger + s.lehe_diger top_diger
                      from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id
                      cross join lateral (
                        select count(*) filter (where k.ayni_parti and oyun.mod_islem_yon(k.islem) = 'ceza') ceza_ayni,
                               count(*) filter (where k.ayni_parti and oyun.mod_islem_yon(k.islem) = 'lehe') lehe_ayni,
                               count(*) filter (where oyun.mod_islem_yon(k.islem) = 'devir') devir,
                               count(*) filter (where k.ayni_parti is not true and oyun.mod_islem_yon(k.islem) = 'ceza') ceza_diger,
                               count(*) filter (where k.ayni_parti is not true and oyun.mod_islem_yon(k.islem) = 'lehe') lehe_diger
                          from oyun.mod_kayit k where k.user_id = m.user_id and k.zaman >= bas) s) z) y), '[]'::jsonb),
    'son', coalesce((select jsonb_agg(jsonb_build_object('zaman', k.zaman, 'kad', k.kad, 'islem', k.islem, 'yon', oyun.mod_islem_yon(k.islem),
                       'hedef', k.hedef, 'ayrinti', k.ayrinti) order by k.zaman desc, k.id desc)
                     from (select * from oyun.mod_kayit where ayni_parti and zaman >= bas order by zaman desc, id desc limit 60) k), '[]'::jsonb),
    'devirler', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kaynak', d.kaynak, 'hedef', oyun.kad(d.hedef), 'devreden', oyun.kad(d.devreden),
                       'sebep', d.sebep, 'zaman', d.zaman, 'yoneticide', d.yonetici_bildirim is not null) order by d.zaman)
                     from (select * from oyun.mod_devir where durum = 'acik' order by zaman limit 100) d), '[]'::jsonb),
    'devir_sayi', (select count(*) from oyun.mod_devir where durum = 'acik'));
end $$;

do $g$
declare f text;
begin
  foreach f in array array['oyun.mod_ayni_parti(uuid,uuid)', 'oyun.mod_ceza_engeli(uuid,uuid)', 'oyun.korunan_hedef_ceza(oyun.profiller,uuid)',
      'oyun.mod_islem_yon(text)', 'oyun.mod_devir_ac(oyun.profiller,text,text,uuid,text,text,bigint)', 'oyun.mod_devir_tick()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  revoke all on function public.admin_mod_tarafsizlik(integer) from public, anon;
  grant execute on function public.admin_mod_tarafsizlik(integer) to authenticated, service_role;
end $g$;

-- ---------- Zamanlayıcı (yalnız Supabase'de pg_cron varsa) ----------
do $c$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('mod-devir', '7-59/10 * * * *', 'select oyun.mod_devir_tick()');
  end if;
end $c$;

commit;
