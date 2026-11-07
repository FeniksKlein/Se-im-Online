"""RPC yüzeyi: istemci izin listesi, anon/authenticated/service_role ve sabit search_path.

Çalıştır: ../kur_yerel.sh && python3 rpc_yuzey.py
Kaynak taraması veritabanı olmadan da listeyi 159 dosyasıyla karşılaştırır;
ayrıcalık kontrolleri yerel oyun_test veritabanını ister.
"""
import os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))
from rpc_yuzey_tara import sonuc, ANON_IZIN, HIZMET
from db import SqlHata

KOK = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SQL = os.path.join(KOK, "gelistirici", "sql", "159_rpc_yuzey.sql")
MIG = os.path.join(KOK, "migrations", "20261031_rpc_yuzey_kilidi.sql")

def ok(m):
    print("  ✓", m)

def izin_dosyasi(yol):
    metin = open(yol, encoding="utf-8").read()
    a = metin.find("-- @@rpc_yuzey_izin_bas@@")
    b = metin.find("-- @@rpc_yuzey_izin_son@@")
    assert a >= 0 and b > a, yol
    govde = metin[a:b]
    return set(re.findall(r"'([a-z][a-z0-9_]{1,63})'", govde))

s = sonuc()
dosya = izin_dosyasi(SQL)
# anon adları da dizide; hizmet adları dizide olmamalı
assert dosya == s["izin"], (
    "159 izin dizisi tarayıcıyla uyuşmuyor",
    sorted(dosya - s["izin"])[:12],
    sorted(s["izin"] - dosya)[:12],
)
assert set(HIZMET).isdisjoint(dosya)
assert set(ANON_IZIN) <= dosya
assert open(SQL, encoding="utf-8").read() == open(MIG, encoding="utf-8").read()
eksik_kapi = sorted(ad for ad, b in s["admin"].items() if not b["kapi"])
assert not eksik_kapi, eksik_kapi
ok(f"İzin listesi {len(dosya)} ad; tarayıcı, 159 ve migration aynı; admin kapısı eksik değil")

def psql(db, sql, dosya=None):
    cmd = ["psql", "-h", "/tmp", "-U", "postgres", "-d", db, "-v", "ON_ERROR_STOP=1", "-q", "-At"]
    if dosya:
        cmd += ["-f", dosya]
        girdi = None
    else:
        cmd += ["-c", sql]
        girdi = None
    r = subprocess.run(cmd, capture_output=True, text=True, input=girdi)
    if r.returncode != 0:
        raise SqlHata((r.stderr or r.stdout).strip().split("\n")[0].replace("ERROR:  ", ""))
    return r.stdout.strip()

# 159'u küçük bir veritabanında uygula. Tam kurulum (kur_yerel.sh) bu depoda
# oyun.eko_vergi_hareket tablosu migrations/'ta olup birleşik kurulumda olmadığı
# için sıfırdan tamamlanmıyor; kilit dosyasının kendisi burada doğrulanır.
psql("postgres", "drop database if exists oyun_rpc_yuzey")
psql("postgres", "create database oyun_rpc_yuzey")
psql("oyun_rpc_yuzey", r"""
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
end $$;
create schema if not exists oyun;
create or replace function public.surum() returns jsonb language sql security definer as $$ select '{"sunucu":"deneme"}'::jsonb $$;
create or replace function public.durum() returns jsonb language sql security definer as $$ select '{"tamam":true}'::jsonb $$;
create or replace function public.parti_kur(text,text,text,text) returns jsonb language sql security definer as $$ select '{}'::jsonb $$;
create or replace function public.push_al(int) returns jsonb language sql security definer as $$ select '[]'::jsonb $$;
create or replace function public.odeme_isle(jsonb) returns jsonb language sql security definer as $$ select '{}'::jsonb $$;
create or replace function public.admin_ozet() returns jsonb language plpgsql security definer as $$
begin
  raise exception 'Bu ekran yalnızca oyun yöneticileri içindir.';
end $$;
create or replace function oyun.tick() returns void language sql security definer as $$ select null::void $$;
create or replace function public._yol_bos() returns int language sql security definer set search_path = '' as $$ select 1 $$;
-- PR #38 / #40 bu dalda yok; kilit onları da doğru bıraksın diye taklit.
create or replace function oyun.canli_sinyal_gorur(p_anahtar text) returns boolean language sql stable security definer as $$ select true $$;
create or replace function oyun.canli_sinyal(p_anahtar text) returns void language sql security definer as $$ select null::void $$;
create or replace function oyun.canli_sinyal_tetik() returns trigger language plpgsql security definer as $$ begin return new; end $$;
create or replace function public.reklam_hazirla() returns jsonb language sql security definer as $$ select '{}'::jsonb $$;
create or replace function public.reklam_ssv_isle(jsonb) returns jsonb language sql security definer as $$ select '{}'::jsonb $$;
create table if not exists oyun._tg_deneme(id int);
create or replace function oyun._tg_deneme_fn() returns trigger language plpgsql as $$
begin
  if new.id is null then new.id := 1; end if;
  return new;
end $$;
drop trigger if exists _tg_deneme on oyun._tg_deneme;
create trigger _tg_deneme before insert on oyun._tg_deneme
  for each row execute function oyun._tg_deneme_fn();
""")
psql("oyun_rpc_yuzey", None, SQL)

def db(sql):
    return psql("oyun_rpc_yuzey", sql)

def ayricalik(rol, sema, ad):
    return db(f"""
      select coalesce(bool_or(has_function_privilege('{rol}', p.oid, 'execute')), false)::text
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = '{sema}' and p.proname = '{ad}' and p.prokind = 'f'
    """) == "true"

def adlar(sema):
    return set(db(f"""
      select coalesce(string_agg(distinct p.proname, ','), '')
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = '{sema}' and p.prokind = 'f'
    """).split(",")) - {""}

public = adlar("public")
auth_acik = set(db("""
  select coalesce(string_agg(distinct p.proname, ','), '')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f'
    and has_function_privilege('authenticated', p.oid, 'execute')
""").split(",")) - {""}
anon_acik = set(db("""
  select coalesce(string_agg(distinct p.proname, ','), '')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f'
    and has_function_privilege('anon', p.oid, 'execute')
""").split(",")) - {""}

beklenen = dosya & public
assert auth_acik == beklenen, (sorted(auth_acik - beklenen)[:15], sorted(beklenen - auth_acik)[:15])
assert anon_acik == set(ANON_IZIN) & public
for ad in ("push_al", "push_bitti", "odeme_isle", "parti_kur"):
    if ad in public:
        assert not ayricalik("authenticated", "public", ad), ad
        assert not ayricalik("anon", "public", ad), ad
assert ayricalik("service_role", "public", "push_al")
assert ayricalik("service_role", "public", "odeme_isle")
assert not ayricalik("authenticated", "oyun", "tick")
assert ayricalik("authenticated", "oyun", "canli_sinyal_gorur")
assert not ayricalik("anon", "oyun", "canli_sinyal_gorur")
assert not ayricalik("authenticated", "oyun", "canli_sinyal")
assert not ayricalik("authenticated", "oyun", "canli_sinyal_tetik")
assert ayricalik("authenticated", "public", "reklam_hazirla")
assert not ayricalik("anon", "public", "reklam_hazirla")
assert not ayricalik("authenticated", "public", "reklam_ssv_isle")
assert ayricalik("service_role", "public", "reklam_ssv_isle")
ok("authenticated yalnız izin listesi; anon yalnız sürüm ve uygulama ayarı; hizmet ve oyun.tick kapalı")

# Giriş yapmadan sürüm okunur; rastgele bir oyun RPC'si anon'a kapalıdır
surum = db("set role anon; select public.surum();")
assert "sunucu" in surum
try:
    db("set role anon; select public.durum();")
    raise AssertionError("anon durum() çalıştırabildi")
except SqlHata as e:
    assert "permission denied" in str(e), e
try:
    db("set role authenticated; select public.push_al(1);")
    raise AssertionError("authenticated push_al çalıştırabildi")
except SqlHata as e:
    assert "permission denied" in str(e), e
ok("anon surum() okur, durum() ve push_al reddedilir")
assert "tamam" in db("set role authenticated; select public.durum();")
try:
    db("set role authenticated; select public.admin_ozet();")
    raise AssertionError("admin_ozet yetkisiz çalıştı")
except SqlHata as e:
    assert "yönetici" in str(e) and "permission denied" not in str(e), e
try:
    db("set role authenticated; select public.parti_kur(null,null,null,null);")
    raise AssertionError("parti_kur açık kaldı")
except SqlHata as e:
    assert "permission denied" in str(e), e
db("select oyun.tick();")
db("insert into oyun._tg_deneme(id) values (null)")
assert db("select id from oyun._tg_deneme") == "1"
yol_bos = db("""
  select coalesce(array_to_string(proconfig, '|'), '')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = '_yol_bos'
""")
assert "search_path=" in yol_bos and "extensions" not in yol_bos, yol_bos
ok("İzinli RPC çalışır, kapalı RPC ve admin kapısı durur, tetikleyici ve eski search_path bozulmaz")

eksik_yol = db("""
  select count(*) from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','oyun') and p.prokind = 'f'
    and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
    and not exists (select 1 from unnest(coalesce(p.proconfig, array[]::text[])) c where c like 'search_path=%')
""")
assert eksik_yol == "0", eksik_yol
# Yeni fonksiyon varsayılan olarak açılmaz ve search_path olay tetikleyicisi yolu yazar
db("create function public._rpc_yuzey_deneme() returns int language sql as 'select 1'")
assert not ayricalik("anon", "public", "_rpc_yuzey_deneme")
assert not ayricalik("authenticated", "public", "_rpc_yuzey_deneme")
assert ayricalik("service_role", "public", "_rpc_yuzey_deneme")
yol = db("""
  select coalesce((select c from unnest(proconfig) c where c like 'search_path=%' limit 1), '')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = '_rpc_yuzey_deneme'
""")
assert yol.startswith("search_path="), yol
db("drop function public._rpc_yuzey_deneme()")
ok("Eksik search_path kalmadı; yeni fonksiyon anon/authenticated'a açılmıyor")
# Canlıdaki hata: postgres, supabase_admin adına ALTER DEFAULT PRIVILEGES yapamaz.
sql_metin = open(SQL, encoding="utf-8").read()
assert "when insufficient_privilege" in sql_metin
assert "supabase_admin varsayılan ayrıcalığı atlandı" in sql_metin
db("""
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'supabase_admin') then create role supabase_admin nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'rpc_editor') then create role rpc_editor nologin; end if;
end $$;
grant rpc_editor to postgres;
set role rpc_editor;
do $koruma$
begin
  begin
    alter default privileges for role supabase_admin revoke execute on functions from PUBLIC, anon, authenticated;
    raise exception 'yetki hatası bekleniyordu';
  exception
    when insufficient_privilege then
      raise notice 'supabase_admin varsayılan ayrıcalığı atlandı (yetki yok): %', sqlerrm;
  end;
end
$koruma$;
""")
ok("supabase_admin varsayılan ayrıcalığı yetki yoksa işlemi durdurmaz")
print("\nTÜM RPC YÜZEY KONTROLLERİ GEÇTİ")
