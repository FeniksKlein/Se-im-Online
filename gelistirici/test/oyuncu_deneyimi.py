"""39_oyuncu_deneyimi.sql testleri.
Önce ESKİ kurulum (39 olmadan) kurulur ve takvim üretilir; sonra 39 canlıdaki gibi ayrı dosya olarak uygulanır.
Böylece canlı sunucudaki geçiş (mevcut seçimlerin saatleri, kumbara tanımı) da sınanır.
Çalıştır: python3 oyuncu_deneyimi.py   (yerel Postgres /tmp soketinde açık olmalı)"""
import os, subprocess, json
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle, SqlHata

KOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PSQL = ["psql", "-h", "/tmp", "-U", "postgres", "-q", "-v", "ON_ERROR_STOP=1"]
def ok(m): print("  ✓", m)
def psql_dosya(yol, ek_ortam=None):
    env = dict(os.environ, PGOPTIONS="-c client_min_messages=warning " + (ek_ortam or ""))
    r = subprocess.run(PSQL + ["-d", "oyun_test", "-f", yol], capture_output=True, text=True, env=env)
    if r.returncode: raise SystemExit(r.stderr[-2000:])

# ---------------- 1) Eski kurulum + takvim, sonra 39 ----------------
subprocess.run(["node", os.path.join(KOK, "build/sql_birlestir.js")], check=True, capture_output=True)
eski = open(os.path.join(KOK, "dist/supabase-kurulum.sql")).read()
eski = eski.replace("create extension if not exists pg_cron with schema pg_catalog;", "")
# 39 dosyası birleşik kurulumda varsa çıkar (canlıdaki eski durumu taklit et)
i39 = eski.find("--  SEÇİM SİMÜLASYONU ONLINE — 39)")
if i39 >= 0:
    j = eski.find("\n-- =====================================================================\n--  SEÇİM SİMÜLASYONU ONLINE — 6) YETKİLER", i39)
    eski = eski[:eski.rfind("\n", 0, i39 - 1)] + eski[j:]
open("/tmp/eski_kurulum.sql", "w").write(eski)
subprocess.run(PSQL + ["-c", "drop database if exists oyun_test", "-c", "create database oyun_test"], check=True, capture_output=True)
for f in ["sql/00_supabase_taklit.sql", "sql/00_cron_taklit.sql"]: psql_dosya(os.path.join(KOK, f))
psql_dosya("/tmp/eski_kurulum.sql", "-c check_function_bodies=off")
assert q("select to_regclass('oyun.mitingler') is null") == "t", "eski kurulumda 39 olmamalı"

q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', baslangic_para=200000, maas_hizi=1, "
  "min_hesap_gun=3, oy_min_kidem=3, oy_il_gun=7, cihaz_zorunlu=false, coklu_kontrol=false, eposta_zorunlu=true, "
  "parti_kurucu_sayi=1, parti_kurucu_kidem=0, parti_kur_ucret=0, teskilat_zorunlu=false, havale_sinir=1")
saat("2026-10-09 11:00")
eski_takvim = q("select to_char(oy_bit at time zone 'Europe/Istanbul','HH24:MI') from oyun.secimler where tur='bel' and donem='2026-10'")
assert eski_takvim == "17:00", eski_takvim
psql_dosya(os.path.join(KOK, "sql/39_oyuncu_deneyimi.sql"))
psql_dosya(os.path.join(KOK, "sql/39_oyuncu_deneyimi.sql"))     # ikinci kez: değişiklik yapmamalı
def takvim(tur, donem):
    return q(f"""select coalesce(to_char(basvuru_bas at time zone 'Europe/Istanbul','MM-DD HH24:MI'),'-')||'→'||coalesce(to_char(basvuru_bit at time zone 'Europe/Istanbul','MM-DD HH24:MI'),'-')
       ||' | '||to_char(oy_bas at time zone 'Europe/Istanbul','MM-DD HH24:MI')||'→'||to_char(oy_bit at time zone 'Europe/Istanbul','HH24:MI')
       ||' sonuç '||to_char(sonuc_at at time zone 'Europe/Istanbul','HH24:MI') from oyun.secimler where tur='{tur}' and donem='{donem}' and not ara""")
assert takvim("bel", "2026-10") == "-→- | 10-10 08:00→22:00 sonuç 22:30", takvim("bel", "2026-10")
assert takvim("bel_on", "2026-10").startswith("10-06 00:00→10-07 00:00 | 10-08 08:00→17:00"), "geçmiş seçime dokunulmamalı"
assert takvim("mv_on", "2026-11") == "10-24 00:00→10-27 00:00 | 10-28 08:00→22:00 sonuç 22:30", takvim("mv_on", "2026-11")
assert takvim("mv", "2026-11") == "-→- | 11-01 08:00→22:00 sonuç 22:30", takvim("mv", "2026-11")
assert takvim("kurultay", "2026-10") == "10-15 00:00→10-18 00:00 | 10-18 08:00→22:00 sonuç 22:30"
cbon = takvim("cb_on", "2026-11")
assert cbon == "" or cbon.startswith("10-26 00:00→10-28 00:00"), cbon
ok("Geçiş: kapanmamış seçimler 08–22 / sonuç 22:30; başvurular 3 gün; biten seçime dokunulmadı; iki kez çalıştırmak güvenli")

q("select oyun.donem_olustur('2026-12-01')")
assert takvim("bel_on", "2026-12") == "12-04 00:00→12-07 00:00 | 12-08 08:00→22:00 sonuç 22:30", takvim("bel_on", "2026-12")
assert takvim("mv_on", "2027-01") == "12-24 00:00→12-27 00:00 | 12-28 08:00→22:00 sonuç 22:30"
ok("Yeni üretilen takvim: belediye başvurusu 4–6, vekil başvurusu 24–26, sandık 08–22")
assert q("select varsayilan||'/'||min||'/'||max from oyun.duzenleme_tanim where kod='kumbara_saat'") == "16/12/24"
assert q("select oyun.kumbara_saat()") == "16"
ok("Kumbara 16 saat (yasayla 12–24)")

# ---------------- 2) Yeni oyuncu: seçmen kartı ----------------
def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad.lower()}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
saat("2026-10-04 09:00")
ali = oyuncu("Ali", 35, 1); veli = oyuncu("Veli", 35, 2); ayse = oyuncu("Ayse", 6, 1)
saat("2026-10-05 09:00"); tasinan = oyuncu("Tasinan", 34, 1)
for g in ["10-05", "10-06", "10-07", "10-08"]:
    saat(f"2026-{g} 09:30")
    for u in (ali, veli, ayse, tasinan): rpc(u, "topla")
q(f"update oyun.profiller set il_id=35, il_at='2026-10-07 10:00+03', son_il_degis='2026-10-07 10:00+03' where id='{tasinan}'")
saat("2026-10-10 10:00")
bel = q("select id from oyun.secimler where tur='bel' and donem='2026-10'")
engel_ali = q(f"select oyun.oy_engeli(p, s) from oyun.profiller p, oyun.secimler s where p.id='{ali}' and s.id={bel}")
engel_tas = q(f"select oyun.oy_engeli(p, s) from oyun.profiller p, oyun.secimler s where p.id='{tasinan}' and s.id={bel}")
assert engel_ali == "", engel_ali
assert "Seçmen kütüğü" in engel_tas, engel_tas
v = rpc(ali, "vatandaslik")
assert v["uygun"] is True and all(s["tamam"] for s in v["sartlar"]), v
ok("6 günlük oyuncu ilk seçtiği ilde belediye seçiminde oy kullanabilir; il değiştiren 7 gün bekler")

ia = rpc(ali, "ilk_adimlar")
durum = {a["kod"]: a["tamam"] for a in ia["adimlar"]}
assert durum["maas"] and durum["parti"] and not durum["kimlik"] and not durum["oy"], durum
ok("İlk adımlar listesi gerçek duruma göre işaretleniyor")

# ---------------- 3) Seri ----------------
saat("2026-10-10 09:00"); rpc(ali, "topla")
seri_once = int(q(f"select seri from oyun.cuzdan where user_id='{ali}'"))
saat("2026-10-13 09:00")                         # 11 ve 12 kaçırıldı
g = qj(f"select oyun.gelir_hesap('{ali}', oyun.simdi())")
assert g["seri"] == seri_once - 2, (seri_once, g["seri"])
ok(f"Seri kaçırılan gün başına bir basamak düşüyor ({seri_once} → {g['seri']}), sıfırlanmıyor")

# ---------------- 4) Para hediyesi sınırı ----------------
q("update oyun.ayarlar set havale_sinir=0.5 where id=1")
tavan = int(q("select oyun.aktarim_tavani()"))
rpc(ali, "serbest_bagis", "oyuncu", "Veli", tavan - 1000, "kampanya")
hata_bekle(rpc, ali, "serbest_bagis", "oyuncu", "Veli", 2000, None, icerir="Günlük para aktarma sınırı")
rpc(ali, "serbest_bagis", "parti", "1", 50000, None)          # partiye sınırsız
hak = rpc(ali, "aktarim_hakki"); assert hak["kalan"] == 1000, hak
yeni = oyuncu("Yenigelen", 35)
hata_bekle(rpc, yeni, "serbest_bagis", "oyuncu", "Veli", 100, None, icerir="seçmen kartın")
q(f"update oyun.profiller set yonetici=true where id='{ayse}'")
tr = rpc(ayse, "admin_transferler_sayfa", 50, 0, None, None)
assert any(s["kanal"] == "hediye" and s["gonderen"] == "Ali" for s in tr["satirlar"]), tr
k_once = float(q(f"select kidem from oyun.cuzdan where user_id='{veli}'"))
ok("Hediye havaleyle ortak günlük sınıra tabi; seçmen kartı ister; partiye bağış sınırsız; yönetici listesinde görünür")

# ---------------- 5) Meclis ölçeği ----------------
for n in range(40):
    u = oyuncu(f"Seçmen{n}", [34, 6, 35, 16][n % 4], 1 + n % 3); rpc(u, "durum")
saat("2026-10-24 00:05")
k = qj("select to_jsonb(k) from oyun.meclis_olcek_kayit k order by secim_id desc limit 1")
assert k and k["sandalye"] == 81 and k["anayasal"] == 600, k      # 45 aktif × 0,25 → alt sınır 81
assert q("select sum(mv_secim) from oyun.iller") == "81"
m = rpc(ali, "meclis"); assert m["toplam"] == 81 and m["anayasal"] == 600, (m.get("toplam"), m.get("anayasal"))
assert "81 sandalyeden" in q("select metin from oyun.olaylar where tur='meclis' order by id desc limit 1")
h = rpc(ali, "harita"); assert sum(x["mv"] for x in h) == 81
ok("Genel seçim başvurusu açılınca Meclis aktif oyuncuya göre 81 sandalyeye küçüldü; anayasal sınır 600 korunuyor")

# ---------------- 7) Kimlik, parti kimliği, tarih ----------------
rpc(ali, "kimlik_guncelle", "3-5-0-1-2-7", "İzmir'den, emekten yana.")
hata_bekle(rpc, ali, "kimlik_guncelle", "<script>", None, icerir="Geçersiz")
kim = rpc(veli, "kimlikler", "{Ali,Veli}")
assert kim["Ali"]["avatar"] == "3-5-0-1-2-7" and kim["Veli"]["avatar"] is None
pk = rpc(ali, "parti_kimlikleri")
assert any(x["parti"]["kisa"] == "EÖP" and x["eko"] == -5 for x in pk)
hata_bekle(rpc, ali, "parti_kimlik_ayarla", 1, 1, "x", icerir="genel başkan")
gb1 = q("select gb from oyun.partiler where id=1")
if gb1:
    rpc(gb1, "parti_kimlik_ayarla", -2, -1, "Yeni yol")
t = rpc(ali, "tarih_arsivi")
assert isinstance(t["cumhurbaskanlari"], list) and "kanunlar" in t and "rekorlar" in t and len(t["partiler"]) >= 5
ok("Portre ve biyografi, parti eksenleri, Cumhuriyet tarihi arşivi")

# ---------------- 8) Miting ----------------
saat("2026-10-25 10:00")
rpc(ali, "aday_ol", "mv_on")
mvon = q("select id from oyun.secimler where tur='mv_on' and donem='2026-11' and not ara")
haklar = rpc(ali, "miting_haklarim"); assert any(h["secim_id"] == int(mvon) for h in haklar), haklar
hata_bekle(rpc, veli, "miting_duzenle", mvon, "2026-10-25 12:00+03", "Halk", icerir="adayları")
hata_bekle(rpc, ali, "miting_duzenle", mvon, "2026-10-25 10:05+03", "Halk", icerir="15 dakika")
para_once = int(q(f"select para from oyun.cuzdan where user_id='{ali}'"))
d = rpc(ali, "miting_duzenle", mvon, "2026-10-25 12:00+03", "Gündoğdu Meydanı buluşması")
assert int(q(f"select para from oyun.cuzdan where user_id='{ali}'")) == para_once - d["bedel"]
hata_bekle(rpc, veli, "miting_katil", d["id"], icerir="başlamadı")
saat("2026-10-25 12:05")
assert "mitinginde" in q(f"select metin from oyun.bildirimler where user_id='{veli}' order by zaman desc limit 1")
kidem_once = float(q(f"select kidem from oyun.cuzdan where user_id='{veli}'"))
r = rpc(veli, "miting_katil", d["id"]); assert r["katilim"] == 1 and r["kidem"] is True
hata_bekle(rpc, ayse, "miting_katil", d["id"], icerir="bu ilde")
assert float(q(f"select kidem from oyun.cuzdan where user_id='{veli}'")) == kidem_once + 1
ml = rpc(veli, "mitingler"); assert ml[0]["katildim"] and ml[0]["benim_ilim"]
saat("2026-10-25 13:05")
assert "1 kişiye seslendi" in q("select metin from oyun.olaylar where tur='secim' order by id desc limit 1")
assert rpc(ali, "tarih_arsivi")["rekorlar"]["en_kalabalik_miting"]["kisi"] == 1
ok("Miting: yalnızca aday düzenler, ücret alınır, başlayınca ildekilere haber gider, katılan +1 kıdem, bitince haber olur")

# ---------------- 6) Görev ihmali ----------------
cb = oyuncu("Baskan", 6, 1); bakan = oyuncu("Bakan", 6, 1)
q(f"insert into oyun.makamlar(tur,user_id,parti_id,bas) values ('cb','{cb}',1,'2026-10-02 00:00+03')")
q(f"insert into oyun.makamlar(tur,user_id,bakanlik,parti_id,kaynak,bas) values ('bakan','{bakan}','adalet',1,'atama','2026-10-02 00:00+03')")
q(f"update oyun.profiller set son_gorulme='2026-10-26 00:00+03' where id in ('{cb}','{bakan}')")
saat("2026-10-28 01:00")
assert q(f"select count(*) from oyun.ihmal_uyari where user_id='{bakan}'") == "1"
assert "Bir gün içinde" in q(f"select metin from oyun.bildirimler where user_id='{bakan}' order by zaman desc limit 1")
saat("2026-10-29 01:00")
assert q(f"select bitis_neden from oyun.makamlar where user_id='{bakan}'") == "ihmal"
assert q(f"select bit is null from oyun.makamlar where user_id='{cb}'") == "t"
saat("2026-10-31 02:00")
assert "İki gün içinde" in q(f"select metin from oyun.bildirimler where user_id='{cb}' order by zaman desc limit 1")
saat("2026-11-02 03:00")
assert q(f"select bitis_neden from oyun.makamlar where user_id='{cb}' and tur='cb'") == "ihmal"
assert q("select count(*) from oyun.secimler where ara and tur in ('cb','cb_on')") != "0"
assert rpc(ali, "tarih_arsivi")["cumhurbaskanlari"][0]["kad"] == "Baskan"
ok("3 gün girmeyen bakan, 7 gün girmeyen cumhurbaşkanı uyarıldıktan sonra görevden düştü; olağanüstü seçim açıldı")

# ---------------- 9) Sandık 22:00'ye kadar açık ----------------
mv = q("select id from oyun.secimler where tur='mv' and donem='2026-11' and not ara")
assert q(f"select to_char(oy_bit at time zone 'Europe/Istanbul','HH24:MI') from oyun.secimler where id={mv}") == "22:00"
ok("Genel seçim günü 21:30'da sandık hâlâ açık")
print("TÜM OYUNCU DENEYİMİ TESTLERİ GEÇTİ")
