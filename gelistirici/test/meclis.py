"""TBMM Başkanlık Divanı ve parti grupları: Meclis Başkanı seçimi (4 tur, gizli oy), başkanvekilleri, grup başkanvekilleri,
grup kararı, ihtar, yeni sohbet kanalları, görev düşmesi ve ara seçim.
Çalıştır: ../kur_yerel.sh && python3 meclis.py"""
import json
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=1000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
def mv(u, il, parti):
    q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('mv','{u}',{il},{parti},'2026-10-02 11:00+03')")
def aktif(tur): return q(f"select coalesce(string_agg(p.kad, ',' order by p.kad), '') from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='{tur}' and m.bit is null")

A = [oyuncu(f"Aa{i}", 35, 1) for i in range(1, 6)]
B = [oyuncu(f"Bb{i}", 6, 2) for i in range(1, 4)]
C1 = oyuncu("Cc1", 34, 3)
uye = oyuncu("Uye", 35, 1)
for u in A: mv(u, 35, 1)
for u in B: mv(u, 6, 2)
mv(C1, 34, 3)
q(f"update oyun.partiler set gb='{A[0]}' where id=1")
q("select oyun.meclis_donem_baslat(null, oyun.simdi())")
mb = rpc(uye, "meclis_baskanlik")
assert mb["gecici"] in ("Aa1", "Aa2", "Aa3", "Aa4", "Aa5", "Bb1", "Bb2", "Bb3", "Cc1") and mb["baskan"] is None
assert mb["grup_esigi"] == 2 and [g["parti"]["id"] for g in mb["gruplar"]] == [1, 2]      # parti 3'ün 1 vekili var: grubu yok
bs = next(s for s in mb["secimler"] if s["tur"] == "baskan"); g1 = next(s for s in mb["secimler"] if s["tur"] == "grup" and s["parti"]["id"] == 1)
g2 = next(s for s in mb["secimler"] if s["tur"] == "grup" and s["parti"]["id"] == 2)
assert g1["bskv_hakki"] and g2["bskv_hakki"] and g1["grup_bskv_sayi"] == 3
ok("Yeni yasama dönemi: en kıdemli vekil Geçici Başkan; 20/600 oranlı grup eşiği (2); en büyük gruplara başkanvekili hakkı")

# ---------------- ADAYLIK ----------------
for u in [A[0], B[0], C1]: rpc(u, "meclis_aday_ol", bs["id"], "baskan", True)
hata_bekle(rpc, uye, "meclis_aday_ol", bs["id"], "baskan", True, icerir="milletvekilleri")
hata_bekle(rpc, A[0], "meclis_aday_ol", bs["id"], "baskan", True, icerir="Zaten")
rpc(A[1], "meclis_aday_ol", g1["id"], "bskv", True)
for u in [A[2], A[3]]: rpc(u, "meclis_aday_ol", g1["id"], "grup_bskv", True)
rpc(B[1], "meclis_aday_ol", g2["id"], "bskv", True); rpc(B[2], "meclis_aday_ol", g2["id"], "grup_bskv", True)
hata_bekle(rpc, B[0], "meclis_aday_ol", g1["id"], "grup_bskv", True, icerir="bu partinin")
hata_bekle(rpc, A[0], "meclis_oy", bs["id"], "baskan", "Aa1", icerir="oylama yok")
ok("Adaylık: TBMM Başkanlığına yalnız vekiller; grup görevlerine yalnız partinin vekilleri aday olabiliyor")

# ---------------- OYLAMA (gizli; 4 tur) ----------------
saat("2026-10-03 12:01")
def tur_oyla(oylar):
    for u, a in oylar: rpc(u, "meclis_oy", bs["id"], "baskan", a)
tur_oyla([(u, "Aa1") for u in A] + [(u, "Bb1") for u in B] + [(C1, "Cc1")])      # A1 5 oy < 6 (2/3 × 9)
hata_bekle(rpc, A[0], "meclis_oy", bs["id"], "baskan", "Bb1", icerir="zaten")
for u in A: rpc(u, "meclis_oy", g1["id"], "bskv", "Aa2")
for u in B: rpc(u, "meclis_oy", g2["id"], "bskv", "Bb2")
hata_bekle(rpc, C1, "meclis_oy", g1["id"], "bskv", "Aa2", icerir="partinin")
saat("2026-10-04 00:02")     # 1. tur bitti → 2. tur ; grup seçimleri bitti
s = next(x for x in rpc(uye, "meclis_baskanlik")["secimler"] if x["id"] == bs["id"])
assert s["tur_no"] == 2 and s["turlar"][0]["gerek"] == 6 and s["turlar"][0]["katilim"] == 9
assert aktif("bskv") == "Aa2,Bb2" and aktif("grup_bskv") == "Aa3,Aa4,Bb3", (aktif("bskv"), aktif("grup_bskv"))
tur_oyla([(u, "Aa1") for u in A] + [(u, "Bb1") for u in B] + [(C1, "Cc1")])
saat("2026-10-04 12:03")     # 3. tur: salt çoğunluk 5; A5 C1'e verince A1 4 oyda kalır
tur_oyla([(u, "Aa1") for u in A[:4]] + [(A[4], "Cc1")] + [(u, "Bb1") for u in B] + [(C1, "Cc1")])
saat("2026-10-05 00:04")     # 4. tur: en çok oy alan iki aday (A1 4, B1 3)
s = next(x for x in rpc(uye, "meclis_baskanlik")["secimler"] if x["id"] == bs["id"])
assert s["tur_no"] == 4 and {a["kad"] for a in s["adaylar"] if not a["elendi"]} == {"Aa1", "Bb1"}
hata_bekle(rpc, C1, "meclis_oy", bs["id"], "baskan", "Cc1", icerir="Aday bulunamadı")
tur_oyla([(u, "Aa1") for u in A] + [(u, "Bb1") for u in B] + [(C1, "Bb1")])
saat("2026-10-05 12:05")
assert aktif("tbmm") == "Aa1"
assert q(f"select gb is null from oyun.partiler where id=1") == "t"        # Meclis Başkanı parti faaliyetine katılamaz
assert q(f"select oyun.unvan('{A[0]}')") == "TBMM Başkanı" and q(f"select oyun.unvan('{B[2]}')") == "ABP Grup Başkanvekili"
assert q("select count(*) from oyun.meclis_oy") != "0" and "secmen" not in json.dumps(rpc(uye, "meclis_baskanlik"))
ok("TBMM Başkanı gizli oyla 4. turda seçildi (1-2. tur 2/3, 3. tur salt çoğunluk, 4. tur ilk iki aday); genel başkanlığı düştü; başkanvekilleri ve grup başkanvekilleri seçildi")

# ---------------- MECLİS BAŞKANININ TARAFSIZLIĞI, GRUP KARARI ----------------
saat("2026-10-05 12:10")
k = rpc(B[0], "kanun_teklif", "serbest", "Kent Ormanları Kanunu", "Her ilde bir kent ormanı kurulur.", None)["id"]
hata_bekle(rpc, A[0], "kanun_teklif", "serbest", "Başkanın teklifi", "Başkan da teklif versin.", None, icerir="Meclis Başkanı")
rpc(A[2], "grup_karar", k, "kabul")
rpc(B[2], "grup_karar", k, "ret")
hata_bekle(rpc, C1, "grup_karar", k, "kabul", icerir="grup başkanvekilleri")
hata_bekle(rpc, A[4], "grup_karar", k, "kabul", icerir="grup başkanvekilleri")
assert q(f"select count(*) from oyun.bildirimler where user_id='{A[4]}' and metin like '%grup kararı%'") == "1"
saat("2026-10-06 12:15")
hata_bekle(rpc, A[0], "kanun_oy", k, "kabul", icerir="Meclis Başkanı")
for u in A[1:4]: rpc(u, "kanun_oy", k, "kabul")
rpc(A[4], "kanun_oy", k, "ret")
d = rpc(A[1], "kanun_detay", k)
assert len(d["grup"]["liste"]) == 2 and d["grup"]["benim_grubum"] == "kabul"
assert [v["aykiri"] for v in d["oylar"]["ilk"]["liste"] if v["kad"] == "Aa5"] == [True]
assert [v["aykiri"] for v in d["oylar"]["ilk"]["liste"] if v["kad"] == "Aa2"] == [False]
ok("Meclis Başkanı oy kullanamıyor, teklif veremiyor; grup başkanvekilleri grup kararı aldı, vekillere bildirildi, karara aykırı oy işaretlendi")

# ---------------- KANALLAR VE İHTAR ----------------
assert rpc(A[1], "sohbet_oku", "divan", None, None)["baslik"].startswith("TBMM Başkanlık Divanı")
hata_bekle(rpc, C1, "sohbet_oku", "divan", None, None, icerir="Başkanlık Divanı")
assert rpc(A[3], "sohbet_oku", "grup", None, None)["baslik"] == "CYP Meclis Grubu"
hata_bekle(rpc, uye, "sohbet_oku", "grup", None, None, icerir="milletvekilleri")
rpc(B[0], "sohbet_yaz", "grup", "Grup toplantısı yarın 10:00'da.")
assert rpc(B[1], "sohbet_oku", "grup", None, None)["mesajlar"][-1]["metin"].startswith("Grup toplantısı")
assert rpc(A[3], "sohbet_oku", "grup", None, None)["mesajlar"] == []           # başka partinin grubu ayrı kanal
oz = rpc(A[1], "sohbet_ozet")
assert [k_["kanal"] for k_ in oz["kanallar"]][7:9] == ["grup", "divan"]
rpc(A[0], "meclis_ihtar", "Bb1", "kürsüde hakaret ettiniz")
hata_bekle(rpc, B[0], "sohbet_yaz", "meclis", "Ama Sayın Başkan!", icerir="ihtar")
hata_bekle(rpc, A[2], "meclis_ihtar", "Bb2", "olmaz", icerir="TBMM Başkanı ve başkanvekillerinde")
rpc(B[1], "sohbet_yaz", "meclis", "Söz istiyorum.")
saat("2026-10-06 13:20")
rpc(B[0], "sohbet_yaz", "meclis", "Teşekkür ederim Sayın Başkan.")
ok("Kanallar: Başkanlık Divanı ve parti Meclis grubu; Meclis Başkanı ihtar verdi, vekil 1 saat Genel Kurul'da söz alamadı")

# ---------------- GÖREV DÜŞMESİ VE ARA SEÇİM ----------------
rpc(A[3], "partiden_ayril")
rpc(A[0], "istifa", "mv")
saat("2026-10-06 13:25")
assert aktif("grup_bskv") == "Aa3,Bb3" and aktif("tbmm") == ""
s = [x for x in rpc(uye, "meclis_baskanlik")["secimler"] if x["tur"] == "baskan" and x["durum"] == "aday"]
assert len(s) == 1
ok("Partisinden ayrılan vekilin grup görevi, vekilliği düşen Meclis Başkanının makamı düştü; Meclis Başkanlığı için ara seçim açıldı")

# maaş: görev tazminatı
assert float(q("select oyun.makam_maasi('grup_bskv', null)")) > 0
for fn in ["meclis_baskanlik()", "meclis_oy(1,'baskan','x')", "grup_karar(1,'kabul')", "meclis_ihtar('a','b')"]:
    try:
        q(f"set role anon; select public.{fn};"); raise AssertionError(fn)
    except Exception as e_:
        assert "permission denied" in str(e_), (fn, e_)
for tb in ["meclis_oy", "grup_kararlari"]:
    try:
        q(f"set role authenticated; select * from oyun.{tb};"); raise AssertionError(tb)
    except Exception as e_:
        assert "permission denied" in str(e_), (tb, e_)
ok("Güvenlik: yeni fonksiyonlar girişsiz kapalı; gizli oylar doğrudan okunamıyor")
print("\nTÜM MECLİS KONTROLLERİ GEÇTİ")
