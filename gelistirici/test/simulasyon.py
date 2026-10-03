"""Tam bir aylık seçim döngüsünü 400 oyuncuyla simüle eder ve kuralları denetler.
Çalıştır: ../kur_yerel.sh && python3 simulasyon.py"""
import random, json, collections
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle, SqlHata

random.seed(7)
TAMAM = []
def ok(msg):
    TAMAM.append(msg); print("  ✓", msg)

q("update oyun.ayarlar set baslangic = '2026-10-02 12:00+03', test_simdi = '2026-10-02 12:00+03', baslangic_para = 10000000;")
saat("2026-10-02 12:00")

# --- takvim kontrolü
rows = q("""select string_agg(tur||' '||donem||' başvuru:'||coalesce(to_char(basvuru_bas at time zone 'Europe/Istanbul','MM-DD HH24:MI'),'-')||
   ' oy:'||to_char(oy_bas at time zone 'Europe/Istanbul','MM-DD HH24:MI')||'→'||to_char(oy_bit at time zone 'Europe/Istanbul','HH24:MI')||
   ' göreve:'||coalesce(to_char(goreve_bas at time zone 'Europe/Istanbul','MM-DD HH24:MI'),'-'), ' ;; ' order by oy_bas, tur) from oyun.secimler""")
print("Takvim:\n   " + rows.replace(" ;; ", "\n   "))
assert "bel_on 2026-10 başvuru:10-06 00:00 oy:10-08 08:00→17:00" in rows
assert "mv 2026-11 başvuru:- oy:11-01 08:00→17:00 göreve:11-02 00:00" in rows
assert "mv_on 2026-11 başvuru:10-26 00:00 oy:10-28 08:00" in rows
assert "kurultay 2026-10 başvuru:10-15 00:00 oy:10-18 08:00→17:00 göreve:10-19 00:00" in rows
ok("Ekim takvimi doğru (6-8-10-11 belediye, 15-18-19 kurultay, 26-28-1-2 genel)")

# Şubat kontrolü: 26 Şubat başvuru, 28 Şubat ön seçim, 1 Mart genel seçim
q("select oyun.donem_olustur('2027-02-01')")
sub = q("""select string_agg(tur||':'||to_char(coalesce(basvuru_bas,oy_bas) at time zone 'Europe/Istanbul','MM-DD')||'/'||to_char(oy_bas at time zone 'Europe/Istanbul','MM-DD'), ' ' order by tur)
           from oyun.secimler where donem = '2027-03' """)
assert "mv:03-01/03-01" in sub and "mv_on:02-26/02-28" in sub, sub
q("delete from oyun.secimler where donem in ('2027-02','2027-03')")
ok("Şubat ayı: 26 Şubat başvuru, 28 Şubat ön seçim, 1 Mart genel seçim")

# --- oyuncular
iller = [int(x) for x in q("select string_agg(id::text, ',' order by id) from oyun.iller").split(",")]
mv = dict(tuple(map(int, r.split(":"))) for r in q("select string_agg(id||':'||mv, ',') from oyun.iller").split(","))
aktif_iller = [34, 6, 35, 16, 7, 1, 42, 27, 21, 61, 55, 38, 20, 69, 62, 74, 11, 48, 31, 65]
agirlik = [mv[i] for i in aktif_iller]

oyuncular = []
for n in range(400):
    u = kullanici_ekle(f"o{n}@test.com")
    il = random.choices(aktif_iller, agirlik)[0]
    rpc(u, "profil_olustur", f"Oyuncu_{n}", il)
    oyuncular.append({"u": u, "il": il, "n": n})
for n in range(400, 404):   # Bayburt (1 vekil) için kalabalık bir liste: yedek senaryosu
    u = kullanici_ekle(f"o{n}@test.com"); rpc(u, "profil_olustur", f"Oyuncu_{n}", 69)
    oyuncular.append({"u": u, "il": 69, "n": n, "bayburt": True})
ok("404 oyuncu profili oluşturuldu")

u0 = oyuncular[0]["u"]
hata_bekle(rpc, u0, "profil_olustur", "Baska", 34, icerir="zaten")
yeni = kullanici_ekle("x@test.com")
hata_bekle(rpc, yeni, "profil_olustur", "oyuncu_5", 34, icerir="alınmış")
hata_bekle(rpc, yeni, "profil_olustur", "ab", 34, icerir="3-20")
hata_bekle(rpc, yeni, "profil_olustur", "Yönetici", 34, icerir="kullanılamaz")
ok("Kullanıcı adı kuralları (tekil, büyük/küçük harf duyarsız, uzunluk, yasaklı)")

# Parti kur — hesap yaşı engeli (3 gün)
hata_bekle(rpc, oyuncular[1]["u"], "parti_kur", "Gençlik Hamlesi Partisi", "GHP", "#00897b", "a_gunes", icerir="günlük")
saat("2026-10-05 12:00")
hata_bekle(rpc, oyuncular[1]["u"], "parti_kur", "Yeni AK Parti Hareketi", "YAP", "#00897b", "a_gunes", icerir="Gerçek")
hata_bekle(rpc, oyuncular[1]["u"], "parti_kur", "Halkın Sesi Partisi", "CHP", "#00897b", "a_gunes", icerir="Gerçek")
hata_bekle(rpc, oyuncular[1]["u"], "parti_kur", "Cumhuriyet Yolu Partisi", "CYX", "#00897b", "a_gunes", icerir="zaten")
d = rpc(oyuncular[1]["u"], "parti_kur", "Gençlik Hamlesi Partisi", "GHP", "#00897b", "a_gunes")
GHP = d["profil"]["parti"]["id"]
assert d["profil"]["gb"] is True
ok("Parti kurma: 3 gün kuralı, gerçek parti adı/kısaltması engeli, kurucu genel başkan olur")

parti_agirlik = {1: 32, 2: 26, 3: 20, 4: 10, 5: 6, GHP: 5}
for o in oyuncular[2:]:
    if o.get("bayburt"):
        rpc(o["u"], "partiye_katil", 1); o["p"] = 1; continue
    if random.random() < 0.04:
        o["p"] = None; continue
    p = random.choices(list(parti_agirlik), list(parti_agirlik.values()))[0]
    rpc(o["u"], "partiye_katil", p); o["p"] = p
oyuncular[1]["p"] = GHP; oyuncular[0]["p"] = None
rpc(u0, "partiye_katil", 1); oyuncular[0]["p"] = 1
uyeler = collections.Counter(o["p"] for o in oyuncular)
print("   Üye dağılımı:", dict(uyeler))

def oy_ver_hepsi(secim, secici):
    n = 0
    for o in oyuncular:
        h = secici(o)
        if h is None: continue
        try:
            rpc(o["u"], "oy_ver", secim, h); n += 1
        except SqlHata as e:
            o.setdefault("hatalar", []).append(str(e))
    return n

def secim_id(tur, donem):
    return int(q(f"select id from oyun.secimler where tur='{tur}' and donem='{donem}'"))

# ---------------- BELEDİYE ----------------
saat("2026-10-06 10:00")
for o in oyuncular:
    if o["p"] and random.random() < 0.08:
        rpc(o["u"], "aday_ol", "bel_on"); o["bel_on"] = True
hata_bekle(rpc, oyuncular[3]["u"], "aday_ol", "mv_on", icerir="açık değil")
ok("Belediye aday adaylığı 6'sında açık, vekil başvurusu kapalı")

BO = secim_id("bel_on", "2026-10")
saat("2026-10-08 07:59")
hata_bekle(rpc, u0, "oy_ver", BO, 1, icerir="kapalı")
saat("2026-10-08 12:00")
def bel_on_sec(o):
    det = o.get("_bo") or rpc(o["u"], "secim_detay", BO)
    s = det["secenekler"]
    return random.choice(s)["hedef"] if s else None
n = oy_ver_hepsi(BO, bel_on_sec)
# başka partinin adayına oy denemesi
yabanci = qj(f"select row_to_json(a) from oyun.adaylar a where secim_id={BO} limit 1")
deneyen = next(o for o in oyuncular if o["p"] and o["p"] != yabanci["parti_id"] and o["il"] == yabanci["il_id"])
hata_bekle(rpc, deneyen["u"], "oy_ver", BO, yabanci["id"])
hata_bekle(rpc, oyuncular[5]["u"], "oy_ver", BO, 999999)
ok(f"Belediye ön seçimi: {n} oy; 08:00 öncesi ve başka partinin ön seçimine oy reddedildi")

saat("2026-10-08 18:01")
BEL = secim_id("bel", "2026-10")
bel_aday = int(q(f"select count(*) from oyun.adaylar where secim_id={BEL}"))
grup = int(q(f"select count(distinct (il_id, parti_id)) from oyun.adaylar where secim_id={BO}"))
assert bel_aday == grup, (bel_aday, grup)
ok(f"Ön seçim sonucu: her il+parti için 1 belediye başkanı adayı ({bel_aday} aday)")

saat("2026-10-10 12:00")
def bel_sec(o):
    det = rpc(o["u"], "secim_detay", BEL)
    s = det["secenekler"]
    if not s: return None
    kendi = [x for x in s if x["parti_id"] == o["p"]]
    return (kendi or s)[0]["hedef"] if random.random() < 0.85 else random.choice(s)["hedef"]
n = oy_ver_hepsi(BEL, bel_sec)
hata_bekle(rpc, oyuncular[2]["u"], "oy_ver", BEL, 1)
saat("2026-10-10 18:01")
saat("2026-10-11 00:01")
bel_say = int(q("select count(*) from oyun.makamlar where tur='bel' and bit is null"))
il_aday = int(q(f"select count(distinct il_id) from oyun.adaylar where secim_id={BEL}"))
assert bel_say == il_aday
# kazananı doğrula
for il_id, kad in [r.split("|") for r in q(f"""select string_agg(m.il_id||'|'||p.kad, E'\\n') from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='bel' and m.bit is null""").split("\n")]:
    en = q(f"select p.kad from oyun.adaylar a join oyun.profiller p on p.id=a.user_id where a.secim_id={BEL} and a.il_id={il_id} order by a.oy desc, a.basvuru_at limit 1")
    assert en == kad, (il_id, en, kad)
ok(f"Belediye seçimi: {n} oy, {bel_say} il belediye başkanı 11'inde göreve başladı, kazananlar doğru")

# ---------------- İL DEĞİŞTİRME ----------------
kilit = q("select oyun.il_kilit_nedeni('2026-10-07 12:00+03')")
assert "Belediye" in kilit
saat("2026-10-13 12:00")
o7 = oyuncular[7]
d = rpc(o7["u"], "il_degistir", 69 if o7["il"] != 69 else 62)
o7["il"] = d["profil"]["il_id"]
hata_bekle(rpc, o7["u"], "il_degistir", 34 if o7["il"] != 34 else 6, icerir="günde bir")
belbsk = q("select user_id from oyun.makamlar where tur='bel' and bit is null limit 1")
hata_bekle(rpc, belbsk, "il_degistir", 81, icerir="Görevdeki")
ok("İl değiştirme: seçim döneminde kilitli, 30 gün kuralı, görevdeki başkan değiştiremez")

# ---------------- KURULTAY ----------------
saat("2026-10-15 10:00")
for pid in [1, 2, 3, 4, 5]:
    adaylar = [o for o in oyuncular if o["p"] == pid][:random.randint(1, 3)]
    for o in adaylar: rpc(o["u"], "aday_ol", "kurultay")
saat("2026-10-18 12:00")
KU = secim_id("kurultay", "2026-10")
n = oy_ver_hepsi(KU, lambda o: random.choice(s)["hedef"] if o["p"] and (s := rpc(o["u"], "secim_detay", KU)["secenekler"]) else None)
saat("2026-10-18 18:01")
saat("2026-10-19 00:01")
gbler = dict(tuple(r.split("|")) for r in q("select string_agg(id||'|'||coalesce(gb::text,'-'), E'\\n') from oyun.partiler").split("\n"))
for pid in [1, 2, 3, 4, 5]:
    assert gbler[str(pid)] != "-", pid
assert gbler[str(GHP)] == oyuncular[1]["u"]   # aday çıkmadı → kurucu genel başkan devam eder
ok(f"Kurultay: {n} oy; 5 partiye genel başkan seçildi, adaysız partide mevcut başkan devam etti")

def gb_of(pid): return q(f"select gb from oyun.partiler where id={pid}")
def kad_of(u): return q(f"select kad from oyun.profiller where id='{u}'")
def o_by_u(u): return next(o for o in oyuncular if o["u"] == u)

# GBY atama
cyp_gb = gb_of(1)
uye = next(o for o in oyuncular if o["p"] == 1 and o["u"] != cyp_gb)
rpc(cyp_gb, "gby_ata", 1, kad_of(uye["u"]))
hata_bekle(rpc, uye["u"], "gby_ata", 2, "Oyuncu_0", icerir="Yalnızca genel başkan")
yabanci = next(o for o in oyuncular if o["p"] == 2)
hata_bekle(rpc, cyp_gb, "gby_ata", 2, kad_of(yabanci["u"]), icerir="üyesi değil")
ok("Genel başkan yardımcısı atama yetkisi yalnızca genel başkanda")

# ---------------- CB ADAY KARARI (19-25) ----------------
saat("2026-10-20 12:00")
rpc(cyp_gb, "cb_aday_belirle", "kendisi")
abp_gb = gb_of(2)
abp_aday = next(o for o in oyuncular if o["p"] == 2 and o["u"] != abp_gb)
rpc(abp_gb, "cb_aday_belirle", "baskasi", kad_of(abp_aday["u"]))
rpc(gb_of(3), "cb_aday_belirle", "onsecim")
hata_bekle(rpc, uye["u"], "cb_aday_belirle", "kendisi", icerir="yalnızca genel başkan")
saat("2026-10-26 09:00")
hata_bekle(rpc, cyp_gb, "cb_aday_belirle", "onsecim", icerir="19")
ok("CB adayı kararı: kendisi / başkası / ön seçim; 26'sında kapanıyor; yetki sadece GB'de")

# ---------------- VEKİL + CB ÖN SEÇİM BAŞVURUSU (26) ----------------
cyp_gb_o = o_by_u(cyp_gb)
hata_bekle(rpc, cyp_gb, "aday_ol", "mv_on", icerir="Genel başkan")   # genel başkan vekil adayı olamaz
gbler = {gb_of(pid) for pid in range(1, 6)}
for o in oyuncular:
    if o["p"] and o["u"] not in gbler and (random.random() < 0.30 or o.get("bayburt") or (o["p"] == 1 and o["il"] == cyp_gb_o["il"])):
        rpc(o["u"], "aday_ol", "mv_on"); o["mv_on"] = True
hata_bekle(rpc, next(o for o in oyuncular if o["p"] == 1 and o["u"] != cyp_gb)["u"], "aday_ol", "cb_on", icerir="doğrudan")
for pid in [3, 4, GHP]:
    for o in [o for o in oyuncular if o["p"] == pid][:2]:
        try: rpc(o["u"], "aday_ol", "cb_on")
        except SqlHata: pass
ok("26'sı: vekil aday adaylığı ve CB ön seçim başvuruları alındı; doğrudan adaylı partide ön seçim engellendi")

saat("2026-10-27 12:00")
hata_bekle(rpc, oyuncular[9]["u"], "il_degistir", 81 if oyuncular[9]["il"] != 81 else 80, icerir="Genel seçim")
# bir aday partiden ayrılırsa listeden düşer
ayrilan = next(o for o in oyuncular if o.get("mv_on") and o["u"] not in (cyp_gb, abp_aday["u"]))
rpc(ayrilan["u"], "partiden_ayril")
MVON = secim_id("mv_on", "2026-11")
assert q(f"select count(*) from oyun.adaylar where secim_id={MVON} and user_id='{ayrilan['u']}'") == "0"
ayrilan["p"] = None
ok("Seçim döneminde il değiştirme kapalı; partiden ayrılan adayın adaylığı düştü")

# geç gelen hesap: 31 Ekim'de açılır, 1 Kasım'da oy kullanamaz
saat("2026-10-28 12:00")
CBON = secim_id("cb_on", "2026-11")
def onsecim_sec(o):
    if not o["p"]: return None
    s = rpc(o["u"], "secim_detay", MVON)["secenekler"]
    if not s: return None
    return random.choice(s)["hedef"]
n1 = oy_ver_hepsi(MVON, onsecim_sec)
n2 = oy_ver_hepsi(CBON, lambda o: random.choice(s)["hedef"] if o["p"] and (s := rpc(o["u"], "secim_detay", CBON)["secenekler"]) else None)
saat("2026-10-28 18:01")
listeler = int(q(f"select count(distinct (il_id,parti_id)) from oyun.adaylar where secim_id={MVON} and sira is not null"))
assert q(f"select count(*) from oyun.adaylar where secim_id={MVON} and user_id='{cyp_gb}'") == "0"   # genel başkan vekil adayı olamadı
cb_adaylar = q("select string_agg(p.kisa, ',' order by p.kisa) from oyun.adaylar a join oyun.partiler p on p.id=a.parti_id where a.secim_id=" + str(secim_id("cb", "2026-11")))
print("   CB adayları:", cb_adaylar)
assert cb_adaylar.count(",") >= 3
ok(f"Ön seçimler: {n1} vekil ön seçim oyu → {listeler} il/parti listesi; {n2} CB ön seçim oyu → CB aday listesi tamam")

saat("2026-10-31 12:00")
gec = kullanici_ekle("gec@test.com"); rpc(gec, "profil_olustur", "GecGelen", 34)

# ---------------- GENEL SEÇİM + CB (1 Kasım) ----------------
saat("2026-11-01 12:00")
MV = secim_id("mv", "2026-11"); CB = secim_id("cb", "2026-11")
hata_bekle(rpc, gec, "oy_ver", MV, 1, icerir="günlük")
def mv_sec(o):
    s = rpc(o["u"], "secim_detay", MV)["secenekler"]
    if not s: return None
    kendi = [x for x in s if x["hedef"] == o["p"]]
    return kendi[0]["hedef"] if kendi and (random.random() < 0.9 or o.get("bayburt")) else random.choice(s)["hedef"]
n_mv = oy_ver_hepsi(MV, mv_sec)
def cb_sec(o):
    s = rpc(o["u"], "secim_detay", CB)["secenekler"]
    kendi = [x for x in s if x["parti_id"] == o["p"]]
    return kendi[0]["hedef"] if kendi and random.random() < 0.85 else random.choice(s)["hedef"]
n_cb = oy_ver_hepsi(CB, cb_sec)
hata_bekle(rpc, u0, "oy_ver", CB, int(q(f"select min(id) from oyun.adaylar where secim_id={CB}")), icerir="zaten")
ok(f"1 Kasım: {n_mv} genel seçim oyu, {n_cb} CB oyu; yeni hesap ve ikinci oy reddedildi")

saat("2026-11-01 18:01")
son = qj(f"select sonuc from oyun.secimler where id={MV}")
print("   Ulusal:", [(p["kisa"], p["yuzde"], p["gecti"], p["sandalye"]) for p in son["ulusal"]])

# ---- D'Hondt'u Python'da bağımsız olarak yeniden hesapla
baraj = float(son["baraj"])
gecen = {p["parti_id"] for p in son["ulusal"] if p["gecti"]}
toplam_sandalye = 0
for il_id, ilj in son["iller"].items():
    il_id = int(il_id)
    oylar = {int(k): v["oy"] for k, v in ilj["partiler"].items() if int(k) in gecen}
    lim = {pid: int(q(f"select count(*) from oyun.adaylar where secim_id={MVON} and il_id={il_id} and parti_id={pid} and sira is not null")) for pid in oylar}
    kaz = {pid: 0 for pid in oylar}
    sirali = sorted(oylar, key=lambda p: (-oylar[p], p))
    for _ in range(mv[il_id]):
        aday = [p for p in sirali if kaz[p] < lim[p]]
        if not aday: break
        en = max(aday, key=lambda p: (oylar[p] / (kaz[p] + 1), oylar[p], -p))
        kaz[en] += 1
    for pid, v in ilj["partiler"].items():
        beklenen = kaz.get(int(pid), 0)
        assert v["sandalye"] == beklenen, (il_id, pid, v, beklenen)
        toplam_sandalye += v["sandalye"]
    assert sum(v["sandalye"] for v in ilj["partiler"].values()) <= mv[il_id]
for p in son["ulusal"]:
    if not p["gecti"]: assert p["sandalye"] == 0
assert toplam_sandalye == son["dolu"] and son["dolu"] + son["bos"] == 600
ok(f"D'Hondt bağımsız hesapla birebir aynı; %{baraj:g} barajı altı partiye sandalye yok; dolu {son['dolu']} + boş {son['bos']} = 600")

cbs = qj(f"select sonuc from oyun.secimler where id={CB}")
print("   CB 1. tur:", [(a["kad"], a["kisa"], a["oy"]) for a in cbs["adaylar"]], "ikinci tur:", cbs["ikinci_tur"])
assert cbs["ikinci_tur"] is True
CB2 = secim_id("cb2", "2026-11")
ilk_iki = [a["user_id"] for a in cbs["adaylar"][:2]]
assert sorted(ilk_iki) == sorted(q(f"select string_agg(user_id::text, ',') from oyun.adaylar where secim_id={CB2}").split(","))
ok("Kimse %50'yi geçemedi → ilk iki aday 2 Kasım'da ikinci tura kaldı")

saat("2026-11-02 00:01")
vekil = int(q("select count(*) from oyun.makamlar where tur='mv' and bit is null"))
assert vekil == son["dolu"]
assert q("select count(*) from oyun.makamlar where tur='cb'") == "0"
ok(f"2 Kasım 00:00: {vekil} vekil göreve başladı; CB makamı 2. tur sonucunu bekliyor")

# CYP genel başkanı vekil seçildi mi?
saat("2026-11-02 12:00")
def cb2_sec(o):
    s = rpc(o["u"], "secim_detay", CB2)["secenekler"]
    kendi = [x for x in s if x["parti_id"] == o["p"]]
    if kendi: return kendi[0]["hedef"]
    return random.choice(s)["hedef"]
n = oy_ver_hepsi(CB2, cb2_sec)
saat("2026-11-02 18:01")
vekiller_once = set(q("select string_agg(user_id::text, ',') from oyun.makamlar where tur='mv' and bit is null").split(","))
gby_once = set((q("select string_agg(user_id::text, ',') from oyun.parti_gby") or "").split(","))
saat("2026-11-03 00:01")
cb_kim = q("select user_id from oyun.makamlar where tur='cb' and bit is null")
cb_vekildi = cb_kim in vekiller_once
print("   Cumhurbaşkanı:", kad_of(cb_kim), "| vekil idi:", cb_vekildi)
assert cb_kim in ilk_iki
# tek görev kuralı: cumhurbaşkanı olan kişi vekil ya da genel başkan yardımcısı kalamaz (genel başkan kalabilir)
assert q(f"select count(*) from oyun.makamlar where user_id='{cb_kim}' and bit is null and tur<>'cb'") == "0"
assert q(f"select count(*) from oyun.parti_gby where user_id='{cb_kim}'") == "0"
if cb_vekildi:
    assert q(f"select count(*) from oyun.makamlar where tur='mv' and bit is null and user_id='{cb_kim}'") == "0"
    yedek = q("select count(*) from oyun.makamlar where tur='mv' and bit is null and kaynak='yedek'")
    if yedek == "1":
        assert int(q("select count(*) from oyun.makamlar where tur='mv' and bit is null")) == vekil
        ok("CB seçilen vekilin sandalyesi düştü, listeden sıradaki yedek Meclis'e girdi")
    else:
        assert "yedek kalmadı" in q("select string_agg(metin, ' ') from oyun.olaylar where tur='makam'")
        assert int(q("select count(*) from oyun.makamlar where tur='mv' and bit is null")) == vekil - 1
        ok("CB seçilen vekilin sandalyesi düştü; listede seçilmemiş kimse kalmadığı için sandalye boş kaldı")
        vekil -= 1
ok(f"İkinci tur: {n} oy, cumhurbaşkanı 3 Kasım'da göreve başladı")

# vekil il değiştiremez
herhangi_vekil = q("select user_id from oyun.makamlar where tur='mv' and bit is null limit 1")
saat("2026-11-04 12:00")
hata_bekle(rpc, herhangi_vekil, "il_degistir", 81 if o_by_u(herhangi_vekil)["il"] != 81 else 80, icerir="Görevdeki")

# ---------------- OKUMA FONKSİYONLARI ----------------
for fn, args in [("durum", ()), ("harita", ()), ("partiler", ()), ("meclis", ()), ("gecmis_secimler", (10,)),
                 ("haberler", (20,)), ("il_detay", (34,)), ("parti_detay", (1,)), ("secim_detay", (MV,))]:
    r = rpc(u0, fn, *args); assert r is not None, fn
m = rpc(u0, "meclis")
assert m["dolu"] == vekil and sum(p["n"] for p in m["partiler"]) == vekil
h = rpc(u0, "harita"); assert len(h) == 81
print("   Haberler:", [x["metin"] for x in rpc(u0, "haberler", 6)][:4])
ok("Okuma fonksiyonları (durum, harita, partiler, meclis, il/parti/seçim detayı, haberler) çalışıyor")

# ---------------- KASIM BELEDİYE: eski başkanların dönemi biter ----------------
saat("2026-11-11 00:01")
eski = int(q("select count(*) from oyun.makamlar where tur='bel' and bit is not null"))
aktif_bel = int(q("select count(*) from oyun.makamlar where tur='bel' and bit is null"))
assert eski + aktif_bel == bel_say and eski >= 1
ok(f"11 Kasım: {eski} ilde yeni seçilen başkana devir oldu; Kasım seçiminde aday çıkmayan {aktif_bel} ilde görevdeki başkan yerinde kalıyor")

# ---------------- HESAP SİLME ----------------
silinecek = q(f"""select m.user_id from oyun.makamlar m where m.tur='mv' and m.bit is null and exists (
    select 1 from oyun.adaylar a join oyun.profiller pr on pr.id=a.user_id and pr.parti_id=m.parti_id
    where a.secim_id={MVON} and a.il_id=m.il_id and a.parti_id=m.parti_id and a.sira is not null
      and not exists (select 1 from oyun.makamlar x where x.user_id=a.user_id)) limit 1""")
assert silinecek, "yedeği olan vekil bulunamadı"
oncesi = int(q("select count(*) from oyun.oylar"))
yedek_once = int(q("select count(*) from oyun.makamlar where kaynak='yedek' and bit is null"))
rpc(silinecek, "hesabimi_sil")
assert int(q("select count(*) from oyun.makamlar where kaynak='yedek' and bit is null")) == yedek_once + 1
assert int(q("select count(*) from oyun.makamlar where tur='mv' and bit is null")) == vekil
assert q(f"select count(*) from auth.users where id='{silinecek}'") == "0"
assert q(f"select count(*) from oyun.oylar where secmen='{silinecek}'") == "0"
assert int(q("select count(*) from oyun.oylar")) == oncesi
ok("Hesap silme: kullanıcı ve profil silindi, oylar anonimleşti (sayılar korundu), vekilliği yedeğe geçti")

# ---------------- Güvenlik: anon / doğrudan tablo erişimi ----------------
for sql in ["set role anon; select public.durum();", "set role authenticated; select count(*) from oyun.oylar;",
            "set role authenticated; select oyun.tick();"]:
    try:
        q(sql); raise AssertionError("erişilmemeliydi: " + sql)
    except SqlHata as e:
        assert "permission denied" in str(e), e
ok("Güvenlik: girişsiz kullanıcı hiçbir fonksiyonu çağıramıyor; oylar tablosu ve motor dışarıya kapalı")

print(f"\nTÜM KONTROLLER GEÇTİ ({len(TAMAM)})")
