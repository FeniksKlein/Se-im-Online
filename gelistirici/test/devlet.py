"""2. aşama: ekonomi, bakanlık icraatları, kararnameler, kanun süreci, ittifaklar.
Çalıştır: ../kur_yerel.sh && python3 devlet.py"""
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle, SqlHata

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def k(sql): return q(sql)
def f(sql): return float(q(sql))

q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
def makam(u, tur, il=None, parti=None, bakanlik=None):
    q(f"""insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,bas)
          values ('{tur}','{u}',{il or 'null'},{parti or 'null'},{"'" + bakanlik + "'" if bakanlik else 'null'},'2026-10-02 12:00+03')""")

cb = oyuncu("Reis", 6, 1)
vekiller = [oyuncu(f"Vekil{i}", 6 if i < 6 else 35, 1 if i < 5 else (2 if i < 8 else 3)) for i in range(10)]
makam(cb, "cb", parti=1)
for i, u in enumerate(vekiller): makam(u, "mv", il=6 if i < 6 else 35, parti=1 if i < 5 else (2 if i < 8 else 3))
saglik = oyuncu("Saglikci", 34, 2); makam(saglik, "bakan", parti=2, bakanlik="saglik")
vatandas = oyuncu("Vatandas", 34)

# ---------------- EKONOMİ ----------------
k0 = rpc(vatandas, "ulke_karnesi")
assert k0["hazine"] == 200 and k0["vergi"] == 20 and len(k0["butce"]) == 12 and len(k0["iller"]) == 81
assert abs(sum(b["pay"] for b in k0["butce"]) - 100) < 0.01
h0 = k0["hesap"]
assert abs(h0["gelir_vergisi"] - 28075 / 30 * 0.6 * 25e6 * 0.20 / 1e9) < 0.01 and h0["denge"] > 0
saat("2026-10-05 00:05")   # 3 gün geçti
k1 = rpc(vatandas, "ulke_karnesi")
assert k("select count(*) from oyun.ulke_gecmis") == "4", k("select count(*) from oyun.ulke_gecmis")
assert k1["hazine"] > 200, k1["hazine"]                     # bütçe küçük fazla veriyor
kasa_saglik = f("select kasa from oyun.bakanlik_kasa where kod='saglik'")
assert abs(kasa_saglik - (20 + 3 * 10 * 0.13)) < 0.05, kasa_saglik
assert k1["enflasyon"] < 35 and k1["endeks"] > 1             # hedef 25'e iniyor; fiyat düzeyi enflasyonla artıyor
ok(f"Günlük ekonomi: 3 gün işlendi, günlük denge +{h0['denge']} milyar, kasalar doluyor, fiyat düzeyi ×{k1['endeks']}")

# yüksek vergi senaryosu: büyüme ve memnuniyet düşer, hazine hızla dolar
q("update oyun.ulke set vergi=35 where id=1")
oncesi = rpc(vatandas, "ulke_karnesi")
saat("2026-10-15 00:05")
sonra = rpc(vatandas, "ulke_karnesi")
assert sonra["buyume"] < oncesi["buyume"] and sonra["memnuniyet"] < oncesi["memnuniyet"] and sonra["hazine"] - oncesi["hazine"] > 25
q("update oyun.ulke set vergi=20 where id=1")
ok(f"Vergi %35'e çıkınca 10 günde hazine +{sonra['hazine'] - oncesi['hazine']:.0f} milyar, büyüme {oncesi['buyume']}→{sonra['buyume']}, memnuniyet {oncesi['memnuniyet']}→{sonra['memnuniyet']}")

# ---------------- BAKANLIK İCRAATLARI ----------------
hata_bekle(rpc, vatandas, "icraat_yap", "sag_ucretsiz", None, icerir="ilgili bakan")
hata_bekle(rpc, saglik, "icraat_yap", "san_osb", 35, icerir="ilgili bakan")
hata_bekle(rpc, saglik, "icraat_yap", "sag_hastane", None, icerir="il seç")
pan = rpc(saglik, "bakanlik_paneli")
assert pan["ad"] == "Sağlık Bakanlığı" and len(pan["icraatlar"]) == 2 and pan["politikalar"] == []
mem0 = f("select memnuniyet from oyun.ulke")
kasa0 = pan["kasa"]
g0 = rpc(vatandas, "hayat")["kumbara"]["saatlik"]["gecim"]
pan = rpc(saglik, "icraat_yap", "sag_ucretsiz", None)
assert abs(pan["kasa"] - (kasa0 - 6)) < 0.11
assert abs(f("select memnuniyet from oyun.ulke") - (mem0 + 1)) < 0.01
g1 = rpc(vatandas, "hayat")["kumbara"]["saatlik"]["gecim"]
assert abs(g1 - g0 * 0.9) < 0.02, (g0, g1)                                # oyuncunun geçim masrafı %10 düştü
assert next(i for i in pan["icraatlar"] if i["kod"] == "sag_ucretsiz")["aktif_bit"] is not None
hata_bekle(rpc, saglik, "icraat_yap", "sag_ucretsiz", None, icerir="tekrar yapılabilir")
q("update oyun.bakanlik_kasa set kasa=2 where kod='saglik'")
hata_bekle(rpc, saglik, "icraat_yap", "sag_hastane", 35, icerir="yeterli ödenek")
assert "Ücretsiz sağlık hizmeti" in k("select string_agg(baslik, '|') from oyun.gazete where tur='icraat'")
assert len(rpc(vatandas, "gazete", 10)) >= 1
ok("Bakanlık icraatları: yetki, il seçimi, kasa düşümü, gösterge etkisi, oyuncuya etkisi (geçim −%10), bekleme süresi, yetersiz ödenek, Resmî Gazete")

# ---------------- KARARNAMELER ----------------
hata_bekle(rpc, vatandas, "kararname_cikar", "serbest", "Deneme kararı", "Metin", "{}", icerir="cumhurbaşkanında")
hz = f("select hazine from oyun.ulke"); g6 = f("select gelisim from oyun.il_durum where il_id=6")
r = rpc(cb, "kararname_cikar", "il_destek", None, None, '{"il_id":6,"miktar":20}')
assert r["no"] == 1 and "Ankara" in r["baslik"]
assert abs(f("select hazine from oyun.ulke") - (hz - 20)) < 0.01 and abs(f("select gelisim from oyun.il_durum where il_id=6") - (g6 + 8)) < 0.01
r = rpc(cb, "kararname_cikar", "odenek", None, None, '{"bakanlik":"saglik","miktar":10}')
assert abs(f("select kasa from oyun.bakanlik_kasa where kod='saglik'") - 12) < 0.01
hata_bekle(rpc, cb, "kararname_cikar", "vergi", None, None, '{"oran":24}', icerir="Geçersiz kararname")
hata_bekle(rpc, cb, "politika_ayarla", "vergi", 26, icerir="arasında")              # bir seferde en fazla 5 puan
r = rpc(cb, "politika_ayarla", "vergi", 22.5)
assert f("select vergi from oyun.ulke") == 22.5
hata_bekle(rpc, cb, "politika_ayarla", "vergi", 21, icerir="en erken")             # 3 günde bir
rpc(cb, "kararname_cikar", "serbest", "Üçüncü Karar Denemesi", "Metin metin", "{}")
hata_bekle(rpc, cb, "kararname_cikar", "serbest", "Dördüncü karar", "Metin metin", "{}", icerir="en fazla 3")
saat("2026-10-16 09:00")
rpc(cb, "kararname_cikar", "serbest", "Millî Yas İlanı Hakkında Karar", "Ülke genelinde üç gün millî yas ilan edilmiştir.", "{}")
kl = rpc(vatandas, "kararnameler", 10)
assert [x["no"] for x in kl] == [4, 3, 2, 1]
assert "Gelir vergisi: %20 → %22,5" in k("select string_agg(baslik, '|') from oyun.gazete where tur='kararname'")
ok("Kararnameler: yalnız CB, il desteği, ek ödenek, günde 3 sınırı, numaralandırma; vergi artık politika ayarı (bant, ±5 puan, 3 günde bir, Resmî Gazete)")

# ---------------- KANUN SÜRECİ ----------------
hata_bekle(rpc, vatandas, "kanun_teklif", "serbest", "Deneme kanunu", "Gerekçe metni yeterince uzun", None, icerir="milletvekilleri")
paylar = {"adalet":5,"disisleri":5,"icisleri":8,"maliye":6,"savunma":10,"egitim":16,"saglik":20,"sanayi":7,"ticaret":5,"tarim":6,"ulastirma":7,"calisma":5}
import json
yanlis = dict(paylar, saglik=30)
hata_bekle(rpc, vekiller[0], "kanun_teklif", "butce", "2027 Bütçe Kanunu", "Sağlığa öncelik veren bütçe.", json.dumps({"vergi_ust": 18, "paylar": yanlis}), icerir="toplamı 100")
hata_bekle(rpc, vekiller[0], "kanun_teklif", "butce", "2027 Bütçe Kanunu", "Sağlığa öncelik veren bütçe.", json.dumps({"vergi_ust": 50, "paylar": paylar}), icerir="Vergi bandı")
r = rpc(vekiller[0], "kanun_teklif", "butce", "2027 Bütçe Kanunu", "Sağlığa öncelik veren, vergi tavanını düşüren, belediyelere daha çok pay veren bütçe.",
        json.dumps({"vergi_alt": 10, "vergi_ust": 18, "belediye_payi": 15, "paylar": paylar}))
butce_id = r["id"]
hata_bekle(rpc, vekiller[0], "kanun_teklif", "serbest", "İkinci teklif", "Gerekçe gerekçe gerekçe", None, icerir="Sonuçlanmamış")
assert "Yeni kanun teklifi" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{vekiller[1]}'")
hata_bekle(rpc, vekiller[1], "kanun_oy", butce_id, "kabul", icerir="oylamada değil")
saat("2026-10-17 09:00")        # 24 saat görüşme bitti
assert rpc(vekiller[1], "kanun_detay", butce_id)["durum"] == "oylamada"
for u in vekiller[:5]: rpc(u, "kanun_oy", butce_id, "kabul")      # CYP 5
for u in vekiller[5:8]: rpc(u, "kanun_oy", butce_id, "ret")       # ABP 3
rpc(vekiller[8], "kanun_oy", butce_id, "cekimser")
rpc(vekiller[7], "kanun_oy", butce_id, "kabul")                    # fikir değiştirdi
hata_bekle(rpc, vatandas, "kanun_oy", butce_id, "kabul", icerir="milletvekilleri")
d = rpc(vekiller[0], "kanun_detay", butce_id)
assert d["oylar"]["ilk"]["kabul"] == 6 and d["oylar"]["ilk"]["ret"] == 2 and d["karar_yeter"] == 3 and d["toplanti_yeter"] == 4
saat("2026-10-18 09:01")        # oylama bitti
d = rpc(cb, "kanun_detay", butce_id)
assert d["durum"] == "cb_onayinda" and d["cb_karar_verebilir"] is True, d["durum"]
assert "onayınızı bekliyor" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{cb}'")
hata_bekle(rpc, cb, "kanun_cb_karar", butce_id, "veto", None, icerir="gerekçe")
rpc(cb, "kanun_cb_karar", butce_id, "veto", "Vergi tavanı hazineyi zora sokar.")
assert rpc(cb, "kanun_detay", butce_id)["durum"] == "israr"
for u in vekiller[:6]: rpc(u, "kanun_oy", butce_id, "kabul")      # 6 ≥ 10/2+1
saat("2026-10-19 09:02")
d = rpc(cb, "kanun_detay", butce_id)
assert d["durum"] == "yururlukte" and d["no"] == 8001, (d["durum"], d.get("sonuc_metin"))
assert f("select vergi from oyun.ulke") == 18 and f("select vergi_ust from oyun.ulke") == 18 and f("select belediye_payi from oyun.ulke") == 15   # vergi tavana çekildi
assert f("select (butce->>'saglik')::numeric from oyun.ulke") == 20
assert "8001 sayılı 2027 Bütçe Kanunu" in k("select string_agg(baslik,'|') from oyun.gazete where tur='kanun'")
ok("Kanun: teklif → 24s görüşme → 24s oylama → kabul → CB veto → ısrar (salt çoğunluk) → yürürlük; vergi bandı (vergi tavana çekildi), belediye payı ve bakanlık payları uygulandı, 8001 sayılı")

# CB onayı, kendiliğinden yürürlük, ret, geri çekme
r1 = rpc(vekiller[1], "kanun_teklif", "serbest", "Sokak Hayvanları Kanunu", "Belediyelere barınak zorunluluğu getirilir.", None)["id"]
r2 = rpc(vekiller[2], "kanun_teklif", "serbest", "Kıyı Koruma Kanunu", "Kıyılarda yapılaşma yasaklanır ve denetlenir.", None)["id"]
r3 = rpc(vekiller[5], "kanun_teklif", "serbest", "Muhalefet Teklifi", "Yalnızca muhalefetin desteklediği bir teklif.", None)["id"]
r4 = rpc(vekiller[6], "kanun_teklif", "serbest", "Geri Çekilecek Teklif", "Bu teklif geri çekilecek, deneme amaçlı.", None)["id"]
rpc(vekiller[6], "kanun_geri_cek", r4)
hata_bekle(rpc, vekiller[0], "kanun_geri_cek", r1, icerir="kendi teklifini")
saat("2026-10-20 09:03")
for u in vekiller[:5]: rpc(u, "kanun_oy", r1, "kabul"); rpc(u, "kanun_oy", r2, "kabul")
rpc(vekiller[5], "kanun_oy", r3, "kabul"); rpc(vekiller[6], "kanun_oy", r3, "kabul")   # yalnız 2 katılım: toplantı yeter sayısı yok
saat("2026-10-21 09:04")
rpc(cb, "kanun_cb_karar", r1, "onay", None)
assert rpc(cb, "kanun_detay", r1)["durum"] == "yururlukte"
assert rpc(cb, "kanun_detay", r3)["durum"] == "ret" and "Toplantı yeter sayısı" in rpc(cb, "kanun_detay", r3)["sonuc_metin"]
assert rpc(cb, "kanun_detay", r4)["durum"] == "geri_cekildi"
saat("2026-10-23 09:05")   # CB 48 saatte karar vermedi
d2 = rpc(cb, "kanun_detay", r2)
assert d2["durum"] == "yururlukte" and "kendiliğinden" in d2["sonuc_metin"]
ok("Kanun: CB onayı, 48 saatte karar verilmezse kendiliğinden yürürlük, toplantı yeter sayısı yoksa ret, geri çekme")

# kararname iptali kanunla
saat("2026-10-23 10:00")
rpc(cb, "kararname_cikar", "serbest", "Gece Yarısı Sokağa Çıkma Yasağı Hakkında Karar", "Gece yarısından sonra sokağa çıkmak yasaktır.", "{}")
kid = int(k("select id from oyun.kararnameler order by id desc limit 1"))
r5 = rpc(vekiller[5], "kanun_teklif", "iptal", "Sokağa Çıkma Yasağı Kararının İptali", "Karar Meclis iradesine aykırıdır.", json.dumps({"kararname_id": kid}))["id"]
saat("2026-10-24 10:01")
for u in vekiller: rpc(u, "kanun_oy", r5, "kabul")
saat("2026-10-25 10:02")
rpc(cb, "kanun_cb_karar", r5, "onay", None)
assert k(f"select durum from oyun.kararnameler where id={kid}") == "iptal"
ok("Kararname iptali kanunu: kararname iptal edildi")

# ---------------- İTTİFAK ----------------
q(f"update oyun.partiler set gb='{vekiller[0]}' where id=1; update oyun.partiler set gb='{vekiller[5]}' where id=2; update oyun.partiler set gb='{vekiller[8]}' where id=3;")
hata_bekle(rpc, vekiller[1], "ittifak_kur", "Halk İttifakı", icerir="genel başkanı")
hata_bekle(rpc, vekiller[0], "ittifak_kur", "Cumhur İttifakı", icerir="Gerçek")
i = rpc(vekiller[0], "ittifak_kur", "Anadolu Cephesi")
iid = i["ittifak"]["id"]
rpc(vekiller[0], "ittifak_davet", 3)
assert "davet etti" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{vekiller[8]}'")
gd = rpc(vekiller[8], "ittifak_bilgi", 3)["gelen_davetler"]
assert gd[0]["ad"] == "Anadolu Cephesi"
rpc(vekiller[8], "ittifak_davet_yanit", iid, True)
assert k(f"select count(*) from oyun.ittifak_uyeler where ittifak_id={iid}") == "2"
hata_bekle(rpc, vekiller[5], "ittifak_davet_yanit", iid, True, icerir="davet yok")
# ittifak sohbeti
saat("2026-10-25 10:10")
rpc(vekiller[8], "sohbet_yaz", "ittifak", "Ortak strateji toplantısı yarın.")
assert rpc(vekiller[1], "sohbet_oku", "ittifak")["baslik"] == "Anadolu Cephesi"
assert rpc(vekiller[1], "sohbet_oku", "ittifak")["mesajlar"][0]["metin"] == "Ortak strateji toplantısı yarın."
hata_bekle(rpc, vekiller[5], "sohbet_oku", "ittifak", icerir="ittifakta değil")
ok("İttifak: yalnız GB kurar, gerçek ittifak adı engeli, davet/bildirim/kabul, ittifak sohbet kanalı")

# CB: ittifak ortağının adayını destekle (19-25 arası)
rpc(vekiller[0], "cb_aday_belirle", "kendisi", None)
hata_bekle(rpc, vekiller[5], "cb_destek", 1, icerir="ittifak ortağının")
rpc(vekiller[8], "cb_destek", 1)
d = rpc(vekiller[8], "durum")
assert d["cb_karar"]["yontem"] == "destek" and d["cb_karar"]["destek"] == "CYP"
cbsid = int(k("select id from oyun.secimler where tur='cb' and donem='2026-11'"))
assert k(f"select count(*) from oyun.adaylar where secim_id={cbsid} and parti_id=3") == "0"
saat("2026-10-26 10:00")   # genel seçim dönemi başladı → kilit
q("update oyun.profiller set parti_at='2026-10-01 00:00+03'")
hata_bekle(rpc, vekiller[9], "aday_ol", "cb_on", icerir="ittifak ortağının")
hata_bekle(rpc, vekiller[8], "ittifak_ayril", icerir="Genel seçim döneminde")
hata_bekle(rpc, vekiller[5], "ittifak_kur", "Yeni Cephe", icerir="Genel seçim döneminde")
ok("CB desteği: ittifak ortağının adayı desteklenir, partinin kendi adayı/ön seçimi olmaz; seçim döneminde ittifak kilitli")

# seçim döneminde kabul edilen baraj seçimden sonra uygulanır
r6 = rpc(vekiller[1], "kanun_teklif", "secim", "Seçim Barajının Düşürülmesi", "Baraj %3'e indirilerek temsilde adalet sağlanır.", json.dumps({"baraj": 3}))["id"]
saat("2026-10-27 10:01")
for u in vekiller: rpc(u, "kanun_oy", r6, "kabul")
saat("2026-10-28 10:02")
rpc(cb, "kanun_cb_karar", r6, "onay", None)
assert f("select baraj from oyun.ayarlar") == 7 and f("select bekleyen_baraj from oyun.ulke") == 3
ok("Seçim kanunu seçim döneminde kabul edildi: baraj bu seçimde %7 kalır, %3 sonraki seçimden itibaren")

# İttifak barajı: mini genel seçim (CYP %60, YDP %5 + ittifak, ABP %6 tek başına)
saat("2026-10-28 18:05")
onsecim = int(k("select id from oyun.secimler where tur='mv_on' and donem='2026-11'"))
q(f"""insert into oyun.adaylar(secim_id,user_id,parti_id,il_id,basvuru_at,sira) values
   ({onsecim},'{vekiller[0]}',1,6,'2026-10-26 10:00+03',1),({onsecim},'{vekiller[1]}',1,6,'2026-10-26 10:00+03',2),
   ({onsecim},'{vekiller[8]}',3,6,'2026-10-26 10:00+03',1),({onsecim},'{vekiller[5]}',2,6,'2026-10-26 10:00+03',1)""")
saat("2026-11-01 12:00")
mvid = int(k("select id from oyun.secimler where tur='mv' and donem='2026-11'"))
import uuid as _u
oylar = [(1, 60), (3, 5), (2, 6), (4, 29)]   # MKP (4) listesiz ama oy alıyor gibi sayılsın diye doğrudan ekliyoruz
vals = []
for pid, n in oylar:
    for _ in range(n): vals.append(f"({mvid},'{_u.uuid4()}',6,{pid})")
q("insert into oyun.oylar(secim_id,secmen,il_id,parti_id) values " + ",".join(vals))
saat("2026-11-01 18:01")
son = qj(f"select sonuc from oyun.secimler where id={mvid}")
gecti = {p["kisa"]: (p["yuzde"], p["gecti"]) for p in son["ulusal"]}
print("   Ulusal:", gecti)
assert gecti["YDP"][1] is True and gecti["ABP"][1] is False and gecti["MKP"][1] is True
saat("2026-11-01 18:02")
assert f("select baraj from oyun.ayarlar") == 3 and k("select bekleyen_baraj is null from oyun.ulke") == "t"
ok("İttifak barajı: %5 alan YDP, ittifakla (%65) barajı geçti; %6 alan ABP tek başına kaldı. Seçim bitince yeni %3 baraj uygulandı")

# Yeni Meclis gelince kadük
r7 = rpc(vekiller[2], "kanun_teklif", "serbest", "Kadük Olacak Teklif", "Dönem sonunda sonuçlanmayan teklif.", None)["id"]
saat("2026-11-02 00:01")
assert rpc(cb, "kanun_detay", r7)["durum"] == "kaduk"
ok("Yeni Meclis göreve başlayınca sonuçlanmamış teklif kadük oldu")

# güvenlik
for sql in ["set role anon; select public.ulke_karnesi();", "set role authenticated; select * from oyun.kanun_oylari;",
            "set role authenticated; select oyun.gunluk_ekonomi(now());"]:
    try: q(sql); raise AssertionError(sql)
    except SqlHata as e: assert "permission denied" in str(e), e
ok("Güvenlik: yeni fonksiyonlar girişsiz kapalı, tablolar ve motor dışarıdan çağrılamıyor")

print(f"\nTÜM DEVLET KONTROLLERİ GEÇTİ ({len(TAMAM)})")
