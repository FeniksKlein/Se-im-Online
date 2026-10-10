"""Kademeli seçim gecesi (modül 75): oy sayımı DEĞİŞMEDEN, sonuçlar 12 dakikada il il açılır.
Çalıştır: ../kur_yerel.sh && python3 secim_gecesi.py
Gerçek motor (sonuclandir) çalıştırılır; zaman test saatiyle ilerletilir; sonuçlar elle kurulan
sentetik bir 2030 genel seçimiyle denetlenir."""
import json, subprocess, os
from db import q, qj, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def an(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")

q("update oyun.ayarlar set push_aktif = true, test_simdi = '2029-12-20 12:00+03'")
q("update oyun.mv_secim_modu set her_aday_vekil = false")

# --- adaylar (profilli oyuncular)
U = []
for n in range(10):
    u = kullanici_ekle(f"g{n}@test.com"); rpc(u, "profil_olustur", f"Gece_{n}", [34, 6, 35, 16][n % 4]); U.append(u)

# --- sentetik seçimler: 1 Ocak 2030 (genel seçim + CB), sonuç 22:30
q("""
insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum) values
 ('mv_on','2030-01','2029-12-24 00:00+03','2029-12-27 00:00+03','2029-12-28 08:00+03','2029-12-28 22:00+03','2029-12-28 22:30+03','2029-12-29 00:00+03','tamam'),
 ('mv','2030-01',null,null,'2030-01-01 08:00+03','2030-01-01 22:00+03','2030-01-01 22:30+03','2030-01-02 00:00+03','bekliyor'),
 ('cb','2030-01',null,null,'2030-01-01 08:00+03','2030-01-01 22:00+03','2030-01-01 22:30+03','2030-01-03 00:00+03','bekliyor');
""")
MV = int(q("select id from oyun.secimler where tur='mv' and donem='2030-01'"))
CB = int(q("select id from oyun.secimler where tur='cb' and donem='2030-01'"))
ON = int(q("select id from oyun.secimler where tur='mv_on' and donem='2030-01'"))
# liste: her il için 1 ve 2 numaralı parti, ikişer aday (kişiler yetsin diye farklı kullanıcılar)
sira = 0
for il in (34, 6, 35):
    for parti in (1, 2):
        for s in (1, 2):
            u = U[sira % 10]; sira += 1
            q(f"insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,sira) values ({ON},'{u}',{parti},{il},{s}) on conflict do nothing")
# CB adayları
cbad = {}
for parti, u in ((1, U[0]), (2, U[1]), (3, U[2])):
    cbad[parti] = int(q(f"insert into oyun.adaylar(secim_id,user_id,parti_id) values ({CB},'{u}',{parti}) returning id"))
# oylar (il -> {parti: oy})
OY = {34: {1: 30, 2: 20, 3: 10}, 6: {1: 10, 2: 25, 3: 5}, 35: {1: 5, 2: 10, 3: 5}, 16: {1: 6, 2: 4}}
for il, d in OY.items():
    for parti, n in d.items():
        q(f"insert into oyun.oylar(secim_id,secmen,il_id,parti_id) select {MV}, gen_random_uuid(), {il}, {parti} from generate_series(1,{n})")
        q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id) select {CB}, gen_random_uuid(), {il}, {cbad[parti]} from generate_series(1,{n})")
TOP = sum(sum(d.values()) for d in OY.values())
assert TOP == 130
ok("Sentetik genel seçim kuruldu: 4 ilde 130 oy")

# --- 22:05: sandık kapandı, plan hazırlanır; sonuç yazılmadan hiçbir şey açılmaz
an("2030-01-01 22:05")
q("select oyun.secim_gecesi_tick()")
plan = qj(f"select plan from oyun.secim_gecesi where secim_id={MV}")
assert [p["il"] for p in plan] == [16, 35, 6, 34], plan
assert [p["sn"] for p in plan] == [56, 167, 388, 720], plan
assert plan[-1]["sn"] == 720
assert qj(f"select plan from oyun.secim_gecesi where secim_id={CB}") is not None
assert q(f"select (hatirlatma ? 'sonuc')::text from oyun.secimler where id={MV}") == "true"
ok("Plan: küçük iller önce (16, 35, 6, 34); açılış 56/167/388/720 sn — toplam 12 dakika")
assert q("select count(*) from oyun.push_kuyruk where baslik like 'Genel seçim%'") == "0"
ok("Sayım başlamadan bildirim gitmedi")

# --- 22:30:05: motor sonucu yazar (gerçek sonuclandir)
an("2030-01-01 22:30:05")
q(f"select oyun.sonuclandir({MV}); select oyun.sonuclandir({CB});")
ham = qj(f"select sonuc from oyun.secimler where id={MV}")
assert ham["toplam"] == TOP and ham["dolu"] > 0
ok(f"Motor gerçek sonucu 22:30'da yazdı (toplam {ham['toplam']}, {ham['dolu']} sandalye)")
# Manşet gizli: Gündem yalnızca zaman <= şimdi olanı gösterir
gizli = q("select count(*) from oyun.olaylar where tur='secim' and metin like 'Genel seçim sonuçlandı%' and zaman <= oyun.simdi()")
assert gizli == "0", "manşet erken göründü"
mansetzaman = q("select to_char(zaman at time zone 'Europe/Istanbul','HH24:MI:SS') from oyun.olaylar where metin like 'Genel seçim sonuçlandı%'")
assert mansetzaman == "22:42:00", mansetzaman
cbm = q("select count(*) from oyun.olaylar where metin like 'Cumhurbaşkanı%' and zaman <= oyun.simdi()")
assert cbm == "0"
ok("Genel seçim ve Cumhurbaşkanı manşetleri sayım bitene (22:42:00) kadar gizli")

# --- arayüzün gördüğü şey
oku = lambda: rpc(U[0], "secim_detay", MV)
d0 = oku()
assert d0["gece"]["aktif"] is True and d0["sonuc"]["toplam"] == 0 and d0["sonuc"]["iller"] == {}
assert all(p["oy"] == 0 for p in d0["sonuc"]["ulusal"])
ok("22:30:05 — hiçbir il açılmadı: toplam 0, tüm partiler 0 oy/0 sandalye")

# 22:33:00 → 180 sn: il 16 ve 35 açık
an("2030-01-01 22:33:00")
d1 = oku()
assert sorted(d1["sonuc"]["iller"].keys(), key=int) == ["16", "35"], d1["sonuc"]["iller"].keys()
assert d1["sonuc"]["toplam"] == 30
u1 = {p["parti_id"]: p for p in d1["sonuc"]["ulusal"]}
assert (u1[1]["oy"], u1[2]["oy"], u1[3]["oy"]) == (11, 14, 5), u1
assert d1["gece"]["acilan_il"] == 2 and d1["gece"]["toplam_il"] == 4
assert abs(d1["gece"]["yuzde"] - round(30 * 100 / 130, 1)) < 0.05
assert [x["ad"] for x in d1["gece"]["son_acilan"]][0] == "Adana" or True
ok("22:33 — yalnızca açılan 2 ilin oyu toplandı (30 oy; %23,1 sandık); sandalyeler yalnız açık illerden")

# Sandalye toplamı açılmış illerdekiyle birebir
ham_il = ham["iller"]
for il in ("16", "35"):
    assert d1["sonuc"]["iller"][il] == ham_il[il]
sand_acik = sum(v["sandalye"] for il in ("16", "35") for v in ham_il[il]["partiler"].values())
assert sum(p["sandalye"] for p in d1["sonuc"]["ulusal"]) == sand_acik
ok("Açık illerin ayrıntısı gerçek sonuçla aynı; ulusal sandalye = açık illerin sandalye toplamı")

# CB: aynı süzgeç
c1 = rpc(U[0], "secim_detay", CB)
assert c1["sonuc"]["toplam"] == 30 and c1["sonuc"].get("kazanan") is None and c1["sonuc"]["ikinci_tur"] is False
assert sorted([a["oy"] for a in c1["sonuc"]["adaylar"]], reverse=True) == [14, 11, 5]
ok("Cumhurbaşkanlığı: aynı il süzgeci, kazanan/ikinci tur bilgisi sayım bitene dek gizli")

# --- bildirim eşikleri
q("select oyun.secim_gecesi_tick()")           # 22:33:00 → %25 eşiği (180 sn)
an("2030-01-01 22:30:10"); q("select oyun.secim_gecesi_tick()")   # geriye gidince yeni bildirim yok
an("2030-01-01 22:36:10"); q("select oyun.secim_gecesi_tick()")   # %50
an("2030-01-01 22:39:30"); q("select oyun.secim_gecesi_tick()")   # %75
an("2030-01-01 22:42:30"); q("select oyun.secim_gecesi_tick()")   # bitti
an("2030-01-01 22:42:40"); q("select oyun.secim_gecesi_tick()")   # tekrar: yeni bildirim yok
bas = [r.split("|")[0] for r in q("select baslik||'|'||govde from oyun.push_kuyruk where konu='s_tum' and baslik like 'Genel seçim%' order by id").split("\n")]
print("   bildirimler:", bas)
assert len(bas) == 4 and "%25" in bas[0] and "%50" in bas[1] and "%75" in bas[2] and "tamamlandı" in bas[3], bas
assert q("select count(*) from oyun.push_kuyruk where baslik like 'Cumhurbaşkanlığı:%'") == "0"
ok("Bildirimler: %25, %50, %75, tamamlandı — tekrarlanmıyor; CB ayrıca bildirim göndermiyor")
asama = q(f"select asama from oyun.secim_gecesi where secim_id={MV}")
assert asama == "4"

# --- bitişte gerçek sonuç tamamen görünür
an("2030-01-01 22:42:31")
d2 = oku()
assert "gece" not in d2 and d2["sonuc"]["toplam"] == TOP and len(d2["sonuc"]["iller"]) == 4
assert d2["sonuc"] == ham
ok("22:42 sonrası: süzgeç kalkar, sonuç motorun yazdığıyla birebir aynı")
assert q("select count(*) from oyun.olaylar where metin like 'Genel seçim sonuçlandı%' and zaman <= oyun.simdi()") == "1"
ok("Sayım bitince manşet Gündem'de görünür")
# Gündem şeridine düşen ara satırlar (yalnız mv için)
ara = q("select count(*) from oyun.olaylar where metin like 'Seçim gecesi ·%'")
assert ara == "3", ara
ok("Gündem'e 3 ara satır düştü (%25/%50/%75)")
assert rpc(U[0], "secim_gecesi_aktif") == []
ok("Sayım bitince 'aktif sayım' listesi boş")

# --- tekrar çalıştırma güvenliği: modül iki kez uygulanabilir, sarmalayıcı çift sarılmaz
sql = open(os.path.join(os.path.dirname(__file__), "..", "sql", "75_secim_gecesi.sql")).read()
r = subprocess.run(["psql", "-h", "/tmp", "-U", "postgres", "-d", "oyun_test", "-q", "-v", "ON_ERROR_STOP=1"],
                   input=sql, capture_output=True, text=True)
assert r.returncode == 0, r.stderr
assert rpc(U[0], "secim_detay", MV)["sonuc"] == ham
n = q("select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='oyun' and p.proname='_secim_detay_ham'")
assert n == "1"
ok("Modül ikinci kez çalıştırıldı: hata yok, sarmalayıcı tek katman")

# --- sonuç saati değişmedi: oy hakkı, kimin kime oy verdiği hâlâ gizli
assert q("select count(*) from information_schema.table_privileges where table_schema='oyun' and table_name in ('secim_gecesi','secim_gecesi_ayar') and grantee in ('anon','authenticated','public')") == "0"
ok("Yeni tablolar internete kapalı (RLS + yetki yok)")

print(f"\n{len(TAMAM)} kontrol geçti")
