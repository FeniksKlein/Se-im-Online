"""Seçim gecesi canlı yayını (modül 165): sandık sandık sayım, sızıntı yok, eski uygulama uyumu.
Çalıştır: yerel test veritabanında 165 kurulu iken  python3 secim_yayini.py
Gerçek motor (sonuclandir) çalışır; zaman test saatiyle ilerletilir."""
import json, math, time
from db import q, qj, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def an(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")

q("update oyun.ayarlar set push_aktif = true, test_simdi = '2030-02-20 12:00+03'")
q("update oyun.secim_gecesi_ayar set canli_sayim = true")
q("delete from oyun.genel_onbellek")
# önceki koşuların sentetik geceleri (yalnız yerel test veritabanı)
q("delete from oyun.olaylar where metin like 'Seçim gecesi ·%'")
q("delete from oyun.secimler where donem like 'yayin-%'")
try: q("update oyun.mv_secim_modu set her_aday_vekil = false")
except Exception: pass

U = []
for n in range(12):
    u = kullanici_ekle(f"yayin{n}_{int(time.time())}@test.com")
    try:
        rpc(u, "profil_olustur", f"Yayin_{n}_{int(time.time()) % 100000}", [34, 6, 35, 16, 1, 61][n % 6])
    except Exception:
        q(f"insert into oyun.profiller(id, kad, il_id) values ('{u}', 'Yayin_{n}_{int(time.time()) % 100000}', {[34, 6, 35, 16, 1, 61][n % 6]})")
    U.append(u)

DONEM = f"yayin-{int(time.time())}"
q(f"""
insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,durum) values
 ('mv_on','{DONEM}','2030-02-22 00:00+03','2030-02-25 00:00+03','2030-02-26 08:00+03','2030-02-26 22:00+03','2030-02-26 22:30+03','2030-02-27 00:00+03','tamam'),
 ('mv','{DONEM}',null,null,'2030-03-01 08:00+03','2030-03-01 22:00+03','2030-03-01 22:30+03','2030-03-02 00:00+03','bekliyor'),
 ('cb','{DONEM}',null,null,'2030-03-01 08:00+03','2030-03-01 22:00+03','2030-03-01 22:30+03','2030-03-03 00:00+03','bekliyor');
""")
MV = int(q(f"select id from oyun.secimler where tur='mv' and donem='{DONEM}'"))
CB = int(q(f"select id from oyun.secimler where tur='cb' and donem='{DONEM}'"))
ON = int(q(f"select id from oyun.secimler where tur='mv_on' and donem='{DONEM}'"))
sira = 0
for il in (34, 6, 35, 16, 1, 61):
    for parti in (1, 2):
        u = U[sira % 12]; sira += 1
        q(f"insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,sira) values ({ON},'{u}',{parti},{il},1) on conflict do nothing")
BAG = int(q(f"insert into oyun.adaylar(secim_id,user_id,parti_id,il_id) values ({MV},'{U[11]}',null,35) returning id"))
cbad = {}
for parti, u in ((1, U[0]), (2, U[1]), (3, U[2])):
    cbad[parti] = int(q(f"insert into oyun.adaylar(secim_id,user_id,parti_id) values ({CB},'{u}',{parti}) returning id"))
OY = {34: {1: 6, 2: 5, 3: 2}, 6: {1: 1, 2: 3}, 35: {1: 1, 2: 1, 'b': 1}, 16: {2: 2}, 1: {1: 1}, 61: {3: 1}}
for il, d in OY.items():
    for parti, n in d.items():
        if parti == 'b':
            q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id) select {MV}, gen_random_uuid(), {il}, {BAG} from generate_series(1,{n})")
            q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id) select {CB}, gen_random_uuid(), {il}, {cbad[3]} from generate_series(1,{n})")
            continue
        q(f"insert into oyun.oylar(secim_id,secmen,il_id,parti_id) select {MV}, gen_random_uuid(), {il}, {parti} from generate_series(1,{n})")
        # canlıdaki gibi CB oyunda adayın partisi de yazılır
        q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id,parti_id) select {CB}, gen_random_uuid(), {il}, {cbad[parti]}, {parti} from generate_series(1,{n})")
TOP = sum(sum(d.values()) for d in OY.values())
ok(f"Sentetik gece kuruldu: 6 ilde {TOP} oy (CB + MV, bir bağımsız)")

yayin = lambda: rpc(U[3], "secim_yayini", CB)
def yaris(d, tur): return next(y for y in d["yarislar"] if y["tur"] == tur)

# --- 21:30: sandık açık
an("2030-03-01 21:30")
d = yayin()
assert [y["tur"] for y in d["yarislar"]] == ["cb", "mv"], d["yarislar"]
c = yaris(d, "cb")
assert c["durum"] == "oy" and c["acilan_sandik"] == 0 and c["dagilim"] == {} and c["iller"] == [] and c["son"] == []
assert all(x["oy"] == 0 for x in c["secenekler"]) and len(c["secenekler"]) == 3
ok("21:30 sandık açık: yalnız aday listesi, hiçbir sonuç yok")

# --- 22:00:30: sandık kapandı ama plan bir dakika bekler
an("2030-03-01 22:00:30")
q("select oyun.secim_gecesi_tick()")
assert q(f"select count(*) from oyun.secim_gecesi where secim_id in ({MV},{CB})") == "0"
c = yaris(yayin(), "cb")
assert c["durum"] == "once" and c["acilan_sandik"] == 0
ok("22:00:30: son oylar için 1 dakika beklenir; durum 'once'")

# --- 22:01:05: plan + sandıklar
an("2030-03-01 22:01:05")
q("select oyun.secim_gecesi_tick()")
g = qj(f"select row_to_json(x) from (select mod, sure_sn, to_char(baslangic at time zone 'Europe/Istanbul','HH24:MI:SS') bas, plan from oyun.secim_gecesi where secim_id={CB}) x")
assert g["mod"] == "canli" and g["bas"] == "22:02:00" and g["sure_sn"] == 27 * 60, g
assert q(f"select hatirlatma ? 'sonuc' from oyun.secimler where id={CB}") == "f"
for sid in (MV, CB):
    sd = qj(f"select json_agg(row_to_json(s)) from oyun.secim_gecesi_sandik s where secim_id={sid}")
    assert sum(x["oy"] for x in sd) == TOP
    plan = {p["il"]: p for p in qj(f"select plan from oyun.secim_gecesi where secim_id={sid}")}
    for il in OY:
        s_il = [x for x in sd if x["il_id"] == il]
        assert max(float(x["sn"]) for x in s_il) == plan[il]["sn"], (il, s_il, plan[il])
        assert sorted(x["no"] for x in s_il)[0] == 1001
        assert sum(x["oy"] for x in s_il) == sum(OY[il].values())
        assert all(8 <= float(x["sn"]) <= g["sure_sn"] for x in s_il)
        ham = qj(f"""select json_object_agg(k, n) from (select case when {sid}={MV} and parti_id is not null then 'p'||parti_id else 'a'||aday_id end k, count(*) n
                     from oyun.oylar where secim_id={sid} and il_id={il} group by 1) z""")
        top = {}
        for x in s_il:
            for k, n in x["dagilim"].items(): top[k] = top.get(k, 0) + n
        assert top == ham, (il, top, ham)
ok("22:01: plan canlı düzende (22:02 başlangıç, 27 dk); sandıkların toplamı il il gerçek oylarla birebir; ilin son sandığı il planıyla aynı saniyede")

# --- sayım öncesi (22:01:30): hiçbir sandık açık değil, sızıntı yok
an("2030-03-01 22:01:30")
d = yayin()
for y in d["yarislar"]:
    assert y["durum"] == "once" and y["acilan_sandik"] == 0 and y["sayilan_oy"] == 0 and y["dagilim"] == {}
    assert all(i["dagilim"] == {} and i["acilan"] == 0 for i in y["iller"]) and y["son"] == []
    assert y["toplam_sandik"] > 0 and y["toplam_oy"] == TOP
assert 25 <= d["sonraki_sn"] <= 31, d["sonraki_sn"]
ok(f"22:01:30: sayım başlamadı, içerik yok; sandık sayısı ve toplam oy açık; sıradaki olay {d['sonraki_sn']} sn")

# --- sayım boyunca: her an yalnız açılmış sandıklar
def denetle(saat):
    an(saat)
    d = yayin()
    gecen_cb = None
    for y in d["yarislar"]:
        sid = y["secim_id"]
        gecen = float(q(f"select oyun.secim_gecesi_gecen({sid})"))
        acik = qj(f"select coalesce(json_agg(row_to_json(s)), '[]') from oyun.secim_gecesi_sandik s where secim_id={sid} and sn <= {gecen}")
        bek = {}
        for x in acik:
            for k, n in x["dagilim"].items(): bek[k] = bek.get(k, 0) + n
        assert y["dagilim"] == bek, (saat, y["dagilim"], bek)
        assert y["acilan_sandik"] == len(acik) and y["sayilan_oy"] == sum(x["oy"] for x in acik)
        for i in y["iller"]:
            ib = {}
            for x in acik:
                if x["il_id"] == i["il_id"]:
                    for k, n in x["dagilim"].items(): ib[k] = ib.get(k, 0) + n
            assert i["dagilim"] == ib and i["sayilan"] == sum(v for v in ib.values())
        oy_sec = sum(x["oy"] for x in y["secenekler"]) + sum(x["oy"] for x in y.get("bagimsizlar", []))
        assert oy_sec == y["sayilan_oy"], (oy_sec, y["sayilan_oy"])
        assert all(float(s["sn"]) <= gecen for s in y["son"])
        if y["tur"] == "cb": gecen_cb = gecen
    return d
onceki = -1
for dk in range(2, 30, 2):
    d = denetle(f"2030-03-01 22:{dk:02d}:20")
    c = yaris(d, "cb")
    assert c["acilan_sandik"] >= onceki; onceki = c["acilan_sandik"]
    assert c["durum"] == ("sayim" if dk < 29 else "tamam"), (dk, c["durum"])
ok("22:02–22:28: 14 anda denetlendi — ulusal, il il ve son sandıklar yalnız açılmış sandıklardan; sayılar hiç geri gitmiyor")

# sonraki_sn: bir sonraki sandık
an("2030-03-01 22:10:00")
d = yayin()
mins = []
for sid in (MV, CB):
    gecen = float(q(f"select oyun.secim_gecesi_gecen({sid})"))
    m = q(f"select min(sn) from oyun.secim_gecesi_sandik where secim_id={sid} and sn > {gecen}")
    if m: mins.append(float(m) - gecen)
assert d["sonraki_sn"] == max(1, math.ceil(min(mins))), (d["sonraki_sn"], mins)
ok(f"22:10: sıradaki sandık {d['sonraki_sn']} sn sonra — istemci tam o anda yeniler")

# Eski uygulama uyumu: secim_gecesi (il il), secim_detay (sonuç yok), Gündem kartı
eski = rpc(U[3], "secim_gecesi", MV)
gecen = float(q(f"select oyun.secim_gecesi_gecen({MV})"))
tam_il = int(q(f"select count(*) from (select il_id from oyun.secim_gecesi_sandik where secim_id={MV} group by il_id having max(sn) <= {gecen}) x"))
assert eski["aktif"] is True and eski["acilan_il"] == tam_il, (eski["acilan_il"], tam_il)
det = rpc(U[3], "secim_detay", MV)
assert (det.get("sonuc") is None or det["sonuc"]["toplam"] == 0) and det["gece"]["aktif"] is True
akt = rpc(U[3], "secim_gecesi_aktif")
assert {a["tur"] for a in akt} == {"cb", "mv"} and all("acilan_sandik" in a for a in akt)
ok("Eski uygulama: il il kart aynı (tamamlanan il sayısı tutarlı), secim_detay sonuç vermiyor, Gündem kartı sandık oranını alıyor")

# --- bildirimler: başladı / yarısı / tamamı (yalnız CB yarışı), Gündem'e 3 ara satır
q("delete from oyun.push_kuyruk")
for saat in ("22:02:30", "22:09:00", "22:16:00", "22:23:00", "22:29:10", "22:29:20"):
    an(f"2030-03-01 {saat}"); q("select oyun.secim_gecesi_tick()")
pk = [r for r in q(f"select baslik from oyun.push_kuyruk where konu='s_tum' and veri->>'id' in ('{CB}','{MV}') order by id").split("\n") if r]
print("   bildirimler:", pk)
assert len(pk) == 3 and "başladı" in pk[0] and "yarısı" in pk[1] and "tamamı" in pk[2], pk
ara = q("select count(*) from oyun.olaylar where metin like 'Seçim gecesi · Cumhurbaşkanlığı%' and zaman > '2030-03-01 22:00+03'")
assert ara == "3", ara
assert q("select count(*) from oyun.olaylar where metin like 'Seçim gecesi · Genel seçim%' and zaman > '2030-03-01 22:00+03'") == "0"
ok("Canlı düzende 3 bildirim (başladı, yarısı, tamamı) ve 3 Gündem satırı; MV yarışı tekrarlamıyor")

# --- 22:29:30: tüm sandıklar açık, resmî sonuç yok
d = denetle("2030-03-01 22:29:30")
for y in d["yarislar"]:
    assert y["durum"] == "tamam" and y["acilan_sandik"] == y["toplam_sandik"] and y["sayilan_oy"] == TOP
    assert "kesin_sonuc" not in y
hata_bekle(rpc, U[3], "secim_yayini_tekrar", CB, icerir="yeniden izlenebilir")
ok("22:29:30: sandıkların tamamı açık, resmî sonuç henüz yok; yeniden izleme kapalı")

# --- 22:30:10: motor resmî sonucu yazar
an("2030-03-01 22:30:10")
q(f"select oyun.sonuclandir({MV}); select oyun.sonuclandir({CB});")
d = yayin()
c, m = yaris(d, "cb"), yaris(d, "mv")
assert c["durum"] == "kesin" and m["durum"] == "kesin"
ks = c["kesin_sonuc"]
assert ks["ikinci_tur"] is True or ks["kazanan"] is not None
cb_ham = qj(f"select sonuc from oyun.secimler where id={CB}")
for a in cb_ham["adaylar"]:
    assert c["dagilim"].get("a" + str(a["aday_id"]), 0) == a["oy"]
mv_ham = qj(f"select sonuc from oyun.secimler where id={MV}")
assert m["kesin_sonuc"]["dolu"] == mv_ham["dolu"] and len(m["kesin_sonuc"]["ulusal"]) == len(mv_ham["ulusal"])
assert "user_id" not in json.dumps(ks)
ok(f"22:30: resmî sonuç geldi — yayın sayıları motorla birebir; {'ikinci tur' if ks['ikinci_tur'] else 'kazanan ' + ks['kazanan']['kad']}; kullanıcı kimliği yok")
assert q(f"select hatirlatma ? 'sonuc' from oyun.secimler where id={MV}") == "f"
ok("Resmî 'Sonuçlar açıklandı' bildirimi bastırılmadı (sonuç saatinde gider)")

t = rpc(U[3], "secim_yayini_tekrar", CB)
for y in t["yarislar"]:
    assert sum(s["oy"] for s in y["sandiklar"]) == TOP and y["toplam_sandik"] == len(y["sandiklar"])
    assert y["acilan_sandik"] == 0 and y["dagilim"] == {}
    assert len(y["iller_bilgi"]) == len(OY)
ok("Yeniden izleme: bütün sandıklar saniyeleriyle geliyor; başlangıç durumu boş")

# --- eski düzen anahtarı: canli_sayim=false → sonuçtan sonra 12 dk
q("update oyun.secim_gecesi_ayar set canli_sayim = false")
D2 = DONEM + "-e"
q(f"""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,goreve_bas,durum) values
 ('cb','{D2}','2030-03-05 08:00+03','2030-03-05 22:00+03','2030-03-05 22:30+03','2030-03-06 00:00+03','bekliyor')""")
CB2 = int(q(f"select id from oyun.secimler where tur='cb' and donem='{D2}'"))
a1 = int(q(f"insert into oyun.adaylar(secim_id,user_id,parti_id) values ({CB2},'{U[0]}',1) returning id"))
a2 = int(q(f"insert into oyun.adaylar(secim_id,user_id,parti_id) values ({CB2},'{U[1]}',2) returning id"))
q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id) select {CB2}, gen_random_uuid(), 34, {a1} from generate_series(1,5)")
q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id) select {CB2}, gen_random_uuid(), 6, {a2} from generate_series(1,3)")
an("2030-03-05 22:00:10"); q("select oyun.secim_gecesi_tick()")
g2 = qj(f"select row_to_json(x) from (select mod, to_char(baslangic at time zone 'Europe/Istanbul','HH24:MI') bas from oyun.secim_gecesi where secim_id={CB2}) x")
assert g2 == {"mod": "sonuc", "bas": "22:30"}, g2
an("2030-03-05 22:30:05"); q(f"select oyun.sonuclandir({CB2})")
an("2030-03-05 22:34:00")
e2 = rpc(U[3], "secim_yayini", CB2)["yarislar"][0]
assert e2["durum"] == "sayim" and "kesin_sonuc" not in e2 and e2["sayilan_oy"] < 8
an("2030-03-05 22:42:30")
e2 = rpc(U[3], "secim_yayini", CB2)["yarislar"][0]
assert e2["durum"] == "kesin" and e2["sayilan_oy"] == 8 and e2["kesin_sonuc"]["kazanan"]["kad"]
q("update oyun.secim_gecesi_ayar set canli_sayim = true")
ok("Kapatma anahtarı: eski düzende sayım 22:30'dan sonra; resmî sonuç sayım bitene dek gizli")

# --- zamanlayıcı gecikse de ilk izleyici sayımı başlatır
D3 = DONEM + "-z"
q(f"""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,goreve_bas,durum) values
 ('cb2','{D3}','2030-03-08 08:00+03','2030-03-08 17:00+03','2030-03-08 18:00+03','2030-03-09 00:00+03','bekliyor')""")
C3 = int(q(f"select id from oyun.secimler where tur='cb2' and donem='{D3}'"))
b1 = int(q(f"insert into oyun.adaylar(secim_id,user_id,parti_id) values ({C3},'{U[0]}',1) returning id"))
q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id) select {C3}, gen_random_uuid(), (array[34,6,35])[1+(g%3)], {b1} from generate_series(1,7) g")
an("2030-03-08 17:05:00")
z = rpc(U[3], "secim_yayini", C3)
assert len(z["yarislar"]) == 1 and z["yarislar"][0]["durum"] == "sayim" and z["yarislar"][0]["mod"] == "canli"
assert z["yarislar"][0]["sure_sn"] == 40 * 60
ok("Zamanlayıcı geciktiğinde ilk izleyici sayımı başlatıyor; 2. turda tek yarış; uzun arada sayım 40 dakika")

# --- yük: 3000 oyluk gece
D4 = DONEM + "-y"
q(f"""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,goreve_bas,durum) values
 ('cb','{D4}','2030-03-10 08:00+03','2030-03-10 22:00+03','2030-03-10 22:30+03','2030-03-11 00:00+03','bekliyor')""")
C4 = int(q(f"select id from oyun.secimler where tur='cb' and donem='{D4}'"))
ids = [int(q(f"insert into oyun.adaylar(secim_id,user_id,parti_id) values ({C4},'{U[i]}',{i+1}) returning id")) for i in range(4)]
q(f"insert into oyun.oylar(secim_id,secmen,il_id,aday_id) select {C4}, gen_random_uuid(), 1 + (g % 81), (array{ids})[1 + (g*7 % 4)] from generate_series(1,3000) g")
an("2030-03-10 22:01:10"); q("select oyun.secim_gecesi_tick()")
ns = int(q(f"select count(*) from oyun.secim_gecesi_sandik where secim_id={C4}"))
kap = int(q(f"select sandik_kap from oyun.secim_gecesi where secim_id={C4}"))
an("2030-03-10 22:15:00")
def sure_ms():
    m = hata_bekle(q, f"do $x$ declare a timestamptz; b interval; begin perform set_config('request.jwt.claim.sub','{U[3]}',true); a := clock_timestamp(); perform public.secim_yayini({C4}); b := clock_timestamp() - a; raise exception 'SURE %', round(extract(epoch from b) * 1000, 2); end $x$;")
    return float(m.split("SURE ")[1].split()[0])
q("delete from oyun.genel_onbellek")
ilk = sure_ms()
# hata_bekle işlemi geri aldığı için önbellek yazılmadı; bir kez gerçekten çağırıp yeniden ölç
rpc(U[3], "secim_yayini", C4)
sonra = sure_ms()
print(f"   3000 oy → {ns} sandık (sandık başına {kap} oy); önbelleksiz {ilk:.1f} ms, önbellekli {sonra:.1f} ms (sunucu içi)")
assert 120 <= ns <= 200 and kap == 20, (ns, kap)
assert sonra < ilk
ok("Yük: 3000 oy ~160 sandığa bölünüyor; önbellekli çağrı önbelleksizden hafif")

print(f"\nTAMAM: {len(TAMAM)} denetim")
