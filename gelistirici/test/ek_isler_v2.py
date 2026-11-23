"""Ek İşler 2.0 (sql/zz_20261124_ek_isler_v2.sql): günlük 5 hak, 20 meslek, tek ödeme, eşzamanlı istekler, yönetim.
Çalıştır: bash ../kur_yerel.sh ; python3 ek_isler_v2.py
(Yerel kurulum yarıda kalsa da olur: test 109, 113 ve yeni modülü kendisi uygular; hepsi tekrar çalıştırılabilir.)"""
import json, os, subprocess, uuid
from db import q, qj, rpc, hata_bekle, SqlHata, DB

KOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sql")
def ok(m): print("  ✓", m)
def uygula(dosya):
    env = dict(os.environ, PGOPTIONS="-c check_function_bodies=off -c client_min_messages=warning")
    r = subprocess.run(["psql", "-h", "/tmp", "-U", "postgres", "-d", "oyun_test", "-q", "-v", "ON_ERROR_STOP=1", "-1", "-f", os.path.join(KOK, dosya)],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 0, dosya + ": " + r.stderr[-600:]

for d in ("109_ek_is_yeni_sektorler.sql", "113_yonetici_kontrol.sql", "zz_20261124_ek_isler_v2.sql"): uygula(d)
uygula("zz_20261124_ek_isler_v2.sql")          # ikinci kez: tekrar çalıştırmak güvenli olmalı
# Önceki koşudan kalanları temizle (yalnız yerel test veritabanı)
q("delete from oyun.ek_is_kayit; delete from oyun.ek_is_katalog where kod not in ('garson','kurye','taksi','market','guvenlik','insaat','oto_tamir','elektrik','tesisat','fotograf','ozel_ders','muhasebe','yazilim','tasarim','sosyal_medya','gazetecilik','organizasyon','tarim','asci','bilgisayar_servis','tamirat');"
  "update oyun.ek_is_ayar set tohum=0; delete from oyun.yk_degisiklik where tablo like 'oyun.ek_is%';")
uygula("zz_20261124_ek_isler_v2.sql")

def oyuncu(kad, yonetici=False):
    u = str(uuid.uuid4())
    q(f"insert into auth.users(id, email, email_confirmed_at) values ('{u}', '{kad.lower()}-{u[:6]}@t.com', now());"
      f"insert into oyun.profiller(id, kad, il_id, yonetici) values ('{u}', '{kad}{u[:5]}', 34, {str(yonetici).lower()});"
      f"select oyun.cuzdanim('{u}'); update oyun.cuzdan set para=0 where user_id='{u}';")
    return u
def para(u): return float(q(f"select coalesce((select para from oyun.cuzdan where user_id='{u}'),0)"))
def bitir(u): q(f"update oyun.ek_is_kayit set baslama=baslama-interval '9 hours', bitis=now()-interval '1 second' where user_id='{u}' and odendi_at is null")
def kosut(u, sql, n):
    """Aynı çağrıyı n ayrı bağlantıdan aynı anda gönderir; (başarılı sayısı, hata metinleri) döner."""
    tam = f"select set_config('request.jwt.claim.sub', '{u}', false);\n{sql}"
    ps = [subprocess.Popen(DB + ["-c", tam], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(n)]
    basari, hatalar = 0, []
    for p in ps:
        o, e = p.communicate()
        if p.returncode == 0: basari += 1
        else: hatalar.append(e.strip().split("\n")[0])
    return basari, hatalar

# ---------------- 1) Katalog ve ayar ----------------
BEKLENEN = {"garson": 750, "kurye": 1000, "taksi": 1250, "market": 850, "guvenlik": 1100, "insaat": 1400, "oto_tamir": 1750,
            "elektrik": 1800, "tesisat": 1650, "fotograf": 1500, "ozel_ders": 1750, "muhasebe": 2000, "yazilim": 2500, "tasarim": 1650,
            "sosyal_medya": 1500, "gazetecilik": 1400, "organizasyon": 1200, "tarim": 950, "asci": 1300, "bilgisayar_servis": 1900}
kat = {x["kod"]: x for x in qj("select jsonb_agg(to_jsonb(k)) from oyun.ek_is_katalog k")}
assert len(BEKLENEN) == 20
for kod, ucret in BEKLENEN.items():
    assert kat[kod]["asgari_ucret"] == ucret and kat[kod]["azami_ucret"] == ucret, (kod, kat[kod])
    assert kat[kod]["aktif"] and not kat[kod]["silindi"] and 15 <= kat[kod]["sure_dakika"] <= 480
assert "tamirat" in kat and kat["tamirat"]["aktif"], "eski iş silinmemeli"
assert q("select gunluk_limit from oyun.ek_is_ayar") == "5"
ok("20 meslek tablodaki ücretlerle kurulu, eski 'Ev ve Cihaz Tamiri' duruyor, günlük hak 5")

# ---------------- 2) Panel ----------------
a = oyuncu("Ayse")
p = rpc(a, "ek_is_paneli")
assert p["gunluk_limit"] == 5 and p["bugun_yapilan"] == 0 and p["kalan"] == 5 and p["aktif"] is None and len(p["isler"]) == 21
assert all(k in p["isler"][0] for k in ("kod", "ad", "simge", "aciklama", "sure_dakika", "asgari_ucret", "azami_ucret", "kategori", "kategori_ad", "uygun"))
assert q("select (((now() at time zone 'Europe/Istanbul')::date + 1)::timestamp at time zone 'Europe/Istanbul') = '%s'::timestamptz" % p["sifirlanma"]) == "t"
oz = rpc(a, "ek_is_ozet")
assert oz["kalan"] == 5 and oz["aktif"] is None
ok("panel: 5/5 hak, 21 iş, sıfırlanma = Türkiye saatiyle gece yarısı")

# ---------------- 3) İş başlat: ücret peşin ödenmez, ikinci iş açılmaz, süre dolmadan ödeme yok ----------------
b0 = para(a)
r = rpc(a, "ek_is_baslat", "yazilim")
assert r["ucret"] == 2500 and r["kalan"] == 4 and r["onceki_odeme"] is None
assert para(a) == b0, "iş başlarken para yatmamalı"
hata_bekle(rpc, a, "ek_is_baslat", "garson", icerir="devam eden")
hata_bekle(rpc, a, "ek_is_ucret_al", r["id"], icerir="henüz bitmedi")
assert para(a) == b0
ok("iş başlarken ödeme yok; süre dolmadan ücret alınamıyor; aynı anda ikinci iş yok")

# ---------------- 4) Ödeme: tek sefer, gerçek cüzdan, işlem geçmişi ----------------
bitir(a)
assert rpc(a, "ek_is_paneli")["aktif"]["hazir"] is True
o = rpc(a, "ek_is_ucret_al", r["id"])
assert o["ucret"] == 2500 and para(a) == b0 + 2500
h = qj(f"select jsonb_agg(to_jsonb(x)) from oyun.hesap_hareket x where user_id='{a}' and tur='ek_is'")
assert len(h) == 1 and float(h[0]["tutar"]) == 2500 and "Yazılım Geliştirme" in h[0]["aciklama"]
hata_bekle(rpc, a, "ek_is_ucret_al", r["id"], icerir="daha önce ödendi")
assert para(a) == b0 + 2500
c = oyuncu("Cem")
hata_bekle(rpc, c, "ek_is_ucret_al", r["id"], icerir="bulunamadı")       # başkasının işi
ok("ücret cüzdana ve hesap hareketlerine bir kez işlendi; ikinci istek ve başkasının isteği reddedildi")

# ---------------- 5) Günde 5 iş, altıncı yok; her mesleğin ücreti doğru ----------------
toplam = 2500
for kod in ("garson", "kurye", "tarim", "muhasebe"):
    x = rpc(a, "ek_is_baslat", kod); assert x["ucret"] == BEKLENEN[kod], (kod, x)
    bitir(a); rpc(a, "ek_is_ucret_al", x["id"]); toplam += BEKLENEN[kod]
p = rpc(a, "ek_is_paneli")
assert p["bugun_yapilan"] == 5 and p["kalan"] == 0 and float(p["bugun_kazanilan"]) == toplam and para(a) == b0 + toplam
m = hata_bekle(rpc, a, "ek_is_baslat", "garson", icerir="5 ek iş hakkını doldurdun")
assert "00.00" in m
assert q(f"select count(*) from oyun.ek_is_kayit where user_id='{a}'") == "5"
ok(f"5 iş yapıldı ({int(toplam)} ₺), 6. iş sunucuda reddedildi")

d = oyuncu("Deniz")                          # her mesleğin ücreti (günlük sınır testten bağımsız olsun diye gün kaydırılır)
for kod, ucret in BEKLENEN.items():
    x = rpc(d, "ek_is_baslat", kod); assert x["ucret"] == ucret
    bitir(d); assert rpc(d, "ek_is_ucret_al", x["id"])["ucret"] == ucret
    q(f"update oyun.ek_is_kayit set gun = gun - 1 where user_id='{d}' and gun = (now() at time zone 'Europe/Istanbul')::date")
assert para(d) == sum(BEKLENEN.values())
ok("20 mesleğin 20'si de tablodaki ücreti ödedi")

# ---------------- 6) Gün dönümü: haklar yenilenir ----------------
q(f"update oyun.ek_is_kayit set gun = gun - 1, baslama = baslama - interval '1 day' where user_id='{a}'")
p = rpc(a, "ek_is_paneli")
assert p["bugun_yapilan"] == 0 and p["kalan"] == 5
x = rpc(a, "ek_is_baslat", "asci"); assert x["kalan"] == 4
ok("yeni günde haklar 5'e döndü (dünkü işler sayılmıyor)")

# ---------------- 7) Süresi dolmuş iş varken yeni iş: önceki ücret aynı işlemde bir kez ödenir ----------------
once = para(a); bitir(a)
y = rpc(a, "ek_is_baslat", "market")
assert y["onceki_odeme"]["ucret"] == 1300 and para(a) == once + 1300
hata_bekle(rpc, a, "ek_is_ucret_al", x["id"], icerir="daha önce ödendi")
assert q(f"select count(*) from oyun.ek_is_kayit where user_id='{a}' and odendi_at is null") == "1"
ok("biten işin ücreti yeni iş başlarken otomatik ve tek sefer ödendi")

# ---------------- 8) Eşzamanlı istekler (yenileme, çoklu sekme, iki cihaz) ----------------
e = oyuncu("Emre")
n, hatalar = kosut(e, "select public.ek_is_baslat('garson');", 12)
assert n == 1, (n, hatalar)
assert q(f"select count(*) from oyun.ek_is_kayit where user_id='{e}'") == "1"
bitir(e); kid = q(f"select id from oyun.ek_is_kayit where user_id='{e}' and odendi_at is null")
e0 = para(e)
n, hatalar = kosut(e, f"select public.ek_is_ucret_al({kid});", 12)
assert n == 1 and para(e) == e0 + 750, (n, para(e) - e0, hatalar)
assert q(f"select count(*) from oyun.hesap_hareket where user_id='{e}' and tur='ek_is'") == "1"
for _ in range(3):                                        # 4 hak kullanılmış olsun
    z = rpc(e, "ek_is_baslat", "garson"); bitir(e); rpc(e, "ek_is_ucret_al", z["id"])
n, hatalar = kosut(e, "select public.ek_is_baslat('garson');", 12)       # son hak için 12 istek
assert n == 1 and q(f"select count(*) from oyun.ek_is_kayit where user_id='{e}'") == "5", (n, hatalar)
bitir(e)
n, hatalar = kosut(e, "select public.ek_is_baslat('kurye');", 12)        # hak bitti: hiçbiri geçmemeli
assert n == 0 and all("hakkını doldurdun" in h for h in hatalar), hatalar
assert q(f"select count(*) from oyun.ek_is_kayit where user_id='{e}'") == "5"
ok("12'şer eşzamanlı istek: tek iş açıldı, tek ödeme yapıldı, günlük 5 sınırı aşılamadı")

# ---------------- 9) Yönetim: yetki ----------------
yon = oyuncu("Sahip", yonetici=True)
for fn, args in (("yk_ek_is_liste", ()), ("yk_ek_is_ayar", (9,)), ("yk_ek_is_sil", ("garson",))):
    hata_bekle(rpc, a, fn, *args, icerir="yalnızca oyunun yöneticisi")
try:
    qj("select public.yk_ek_is_kaydet('garson', '{\"asgari_ucret\":\"999999\",\"azami_ucret\":\"999999\"}'::jsonb)", a); raise AssertionError("yetkisiz ücret değişti")
except SqlHata as h: assert "yalnızca oyunun yöneticisi" in str(h)
assert q("select asgari_ucret from oyun.ek_is_katalog where kod='garson'") == "750"
ok("oyuncu yönetim işlevlerini çağıramıyor")

# ---------------- 10) Yönetim: ücret/süre düzenle, ekle, pasifleştir, sil/arşivle, günlük hak ----------------
def kaydet(kod, veri):
    kodsql = "null" if kod is None else "'" + kod + "'"
    return qj(f"select public.yk_ek_is_kaydet({kodsql}, '{json.dumps(veri, ensure_ascii=False)}'::jsonb)", yon)
l = rpc(yon, "yk_ek_is_liste")
assert l["gunluk_limit"] == 5 and len(l["isler"]) == 21 and len(l["kategoriler"]) == 8
r = kaydet("garson", {"asgari_ucret": "900", "azami_ucret": "900", "sure_dakika": "30"})
assert r["is"]["asgari_ucret"] == 900 and r["is"]["sure_dakika"] == 30
f = oyuncu("Fatma")
x = rpc(f, "ek_is_baslat", "garson"); assert x["ucret"] == 900
assert q(f"select round(extract(epoch from bitis-baslama)/60) from oyun.ek_is_kayit where id={x['id']}") == "30"
r = kaydet(None, {"ad": "Çiçekçilik İşleri", "aciklama": "Buket hazırla ve teslim et.", "sure_dakika": "40", "asgari_ucret": "600", "kategori": "hizmet", "simge": "💐"})
assert r["yeni"] and r["is"]["kod"] == "cicekcilik_isleri" and r["is"]["azami_ucret"] == 600
assert any(i["kod"] == "cicekcilik_isleri" for i in rpc(f, "ek_is_paneli")["isler"])
try: kaydet(None, {"ad": "çiçekçilik işleri", "aciklama": "aynı ad tekrar", "sure_dakika": "40", "asgari_ucret": "600"}); raise AssertionError("aynı ad kabul edildi")
except SqlHata as h: assert "zaten var" in str(h)
for veri, mesaj in (({"sure_dakika": "5"}, "15 ile 480"), ({"asgari_ucret": "0", "azami_ucret": "0"}, "1 ile 1.000.000"),
                    ({"asgari_ucret": "500", "azami_ucret": "400"}, "az olamaz"), ({"kategori": "uzay"}, "türü geçersiz"),
                    ({"sure_dakika": "kırk"}, "tam sayı"), ({"ad": "x"}, "3–40")):
    try: kaydet("kurye", veri); raise AssertionError("geçersiz değer kabul edildi: %s" % veri)
    except SqlHata as h: assert mesaj in str(h), (veri, str(h))
assert q("select asgari_ucret||'/'||sure_dakika from oyun.ek_is_katalog where kod='kurye'") == "1000/70"
# pasifleştir: listeden kalkar, başlatılamaz; süren iş yine ödenir
kaydet("garson", {"aktif": False})
assert not any(i["kod"] == "garson" for i in rpc(a, "ek_is_paneli")["isler"])
hata_bekle(rpc, c, "ek_is_baslat", "garson", icerir="mevcut değil")
bitir(f); f0 = para(f); assert rpc(f, "ek_is_ucret_al", x["id"])["ucret"] == 900 and para(f) == f0 + 900
kaydet("garson", {"aktif": True})
# sil: geçmişi yoksa kalıcı, varsa arşiv
s = rpc(yon, "yk_ek_is_sil", "cicekcilik_isleri"); assert s["kalici"] is True
assert q("select count(*) from oyun.ek_is_katalog where kod='cicekcilik_isleri'") == "0"
s = rpc(yon, "yk_ek_is_sil", "garson"); assert s["kalici"] is False
assert q("select aktif||'/'||silindi from oyun.ek_is_katalog where kod='garson'") == "false/true"
assert not any(i["kod"] == "garson" for i in rpc(a, "ek_is_paneli")["isler"])
assert any(g["ad"] == "Garsonluk" for g in rpc(e, "ek_is_paneli")["gecmis"]), "arşivlenen mesleğin ödeme geçmişi kaybolmamalı"
kaydet("garson", {"silindi": False, "aktif": True, "asgari_ucret": "750", "azami_ucret": "750", "sure_dakika": "55"})
assert any(i["kod"] == "garson" for i in rpc(a, "ek_is_paneli")["isler"])
# günlük hak
hata_bekle(rpc, yon, "yk_ek_is_ayar", 0, icerir="1 ile 24")
rpc(yon, "yk_ek_is_ayar", 6)
g = oyuncu("Gul")
for i in range(6):
    z = rpc(g, "ek_is_baslat", "garson"); bitir(g); rpc(g, "ek_is_ucret_al", z["id"])
hata_bekle(rpc, g, "ek_is_baslat", "garson", icerir="6 ek iş hakkını doldurdun")
rpc(yon, "yk_ek_is_ayar", 5)
assert rpc(g, "ek_is_paneli")["kalan"] == 0
# kıdem şartı
kaydet("yazilim", {"min_kidem": "25"})
hk = oyuncu("Hakan")
hata_bekle(rpc, hk, "ek_is_baslat", "yazilim", icerir="en az 25 kıdem")
assert [i for i in rpc(hk, "ek_is_paneli")["isler"] if i["kod"] == "yazilim"][0]["uygun"] is False
q(f"select oyun.cuzdanim('{hk}'); update oyun.cuzdan set kidem=30 where user_id='{hk}'")
assert rpc(hk, "ek_is_baslat", "yazilim")["ucret"] == 2500
kaydet("yazilim", {"min_kidem": "0"})
kayit = int(q("select count(*) from oyun.yk_degisiklik where tablo='oyun.ek_is_katalog'")), int(q("select count(*) from oyun.yk_degisiklik where tablo='oyun.ek_is_ayar'"))
assert kayit[0] >= 8 and kayit[1] == 2, kayit
ok("yönetim: ücret/süre düzenleme, yeni meslek, pasifleştirme, silme/arşiv, günlük hak, kıdem şartı; hepsi değişiklik geçmişinde")

# ---------------- 11) Tekrar kurulum yöneticinin değişikliğini ezmez ----------------
kaydet("kurye", {"asgari_ucret": "1111", "azami_ucret": "1111"})
uygula("109_ek_is_yeni_sektorler.sql"); uygula("zz_20261124_ek_isler_v2.sql")
assert q("select asgari_ucret from oyun.ek_is_katalog where kod='kurye'") == "1111"
kaydet("kurye", {"asgari_ucret": "1000", "azami_ucret": "1000"})
ok("kurulum dosyası yeniden çalışınca panelden verilen ücret korunuyor")

# ---------------- 12) İzinler ----------------
izin = qj("""select jsonb_object_agg(f, jsonb_build_array(has_function_privilege('anon', f, 'execute'), has_function_privilege('authenticated', f, 'execute')))
  from unnest(array['public.ek_is_paneli()','public.ek_is_ozet()','public.ek_is_baslat(text)','public.ek_is_ucret_al(bigint)','public.yk_ek_is_liste()',
   'public.yk_ek_is_ayar(integer)','public.yk_ek_is_kaydet(text,jsonb)','public.yk_ek_is_sil(text)','oyun.ek_is_ode(uuid,bigint,timestamptz)']) f""")
for f, (anon, auth) in izin.items():
    assert anon is False, f
    assert auth is (not f.startswith("oyun.")), f
tablo = qj("""select jsonb_object_agg(t, has_table_privilege('authenticated', t, 'select') or has_table_privilege('authenticated', t, 'update') or has_table_privilege('anon', t, 'select'))
  from unnest(array['oyun.ek_is_katalog','oyun.ek_is_kayit','oyun.ek_is_ayar']) t""")
assert not any(tablo.values()), tablo
assert q("select bool_and(relrowsecurity) from pg_class where oid in ('oyun.ek_is_katalog'::regclass,'oyun.ek_is_kayit'::regclass,'oyun.ek_is_ayar'::regclass)") == "t"
ok("anonim erişim yok; ödeme işlevi ve tablolar istemciye kapalı; RLS açık")
print("Ek İşler 2.0 sunucu testleri başarılı.")
