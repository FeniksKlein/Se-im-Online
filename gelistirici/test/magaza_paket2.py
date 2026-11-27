"""Mağaza Paketi 2 (zz_20261127_magaza_paket2.sql): 20 yeni ürünün RevenueCat olaylarıyla etkisi, Kürsü vitrini ve
Gündem manşeti kuyruğu (3 yer, sıra, önden bildirim, seçim günü duraklama), plaka, mazbata, kutlama, kongre, sahne,
genel merkez, parti bağışı, hediye/parti kartı, destekçi duvarı, rozetler ve iadeler.
Yerel test veritabanında çalışır (kur_yerel.sh + /tmp/m2test hazırlığı)."""
import json, uuid
from db import q, qj, rpc, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
EK = uuid.uuid4().hex[:5]
T0 = "2026-12-12 12:00+03"
q(f"update oyun.ayarlar set test_simdi = '{T0}'")
q("update oyun.m2_ayar set son_tick = null")
q("delete from oyun.m2_yayin; delete from oyun.m2_plaka; delete from oyun.m2_destek; delete from oyun.m2_zafer; delete from oyun.m2_mazbata; delete from oyun.m2_gm_katki; delete from oyun.m2_gm_seviye; delete from oyun.m2_parti_sahne; delete from oyun.m2_kongre; delete from oyun.m2_bagisci")  # yerel deneme veritabanı

def zaman(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}'")
def oyuncu(ad, parti=None, gun=10, il=35):
    u = kullanici_ekle(f"{ad.lower()}_{uuid.uuid4().hex[:6]}@t.com")
    kad = (ad + EK)[:20]
    q(f"insert into oyun.profiller(id, kad, il_id, parti_id, olusturma, ad_soyad) values ('{u}', '{kad}', {il}, {parti or 'null'}, oyun.simdi() - interval '{gun} days', '{ad} Soyad')")
    q(f"select oyun.cuzdanim('{u}')")
    return u
def kad(u): return q(f"select kad from oyun.profiller where id='{u}'")
def para(u): return float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
def jeton(u, k): return int(q(f"select oyun.m2_jeton('{u}', '{k}')"))
def kasa(p): return float(q(f"select kasa from oyun.partiler where id={p}"))
def olay(u, urun, tur="NON_RENEWING_PURCHASE", islem=None, **ek):
    e = {"type": tur, "app_user_id": u, "product_id": urun, "transaction_id": islem or uuid.uuid4().hex}
    e.update(ek)
    return qj(f"select public.odeme_isle($j${json.dumps({'event': e})}$j$::jsonb)")
def al(u, urun, islem=None):
    r = olay(u, urun, islem=islem); assert r["durum"] == "eklendi", r; return r
def tick(): return qj("select oyun.m2_tick()")
def rozet(u):
    r = rpc(u, "magaza_rozetler"); return (r.get(kad(u)) or "").split(",")
def parti(ad):
    return int(q(f"insert into oyun.partiler(ad, kisa, renk, kasa) values ('{ad}{EK}', '{ad[:2].upper()}{EK[:3].upper()}', '#123456', 0) returning id"))

P1 = parti("Mavi"); P2 = parti("Kizil")
gb = oyuncu("Genel", P1); q(f"update oyun.partiler set gb='{gb}' where id={P1}")
uye = oyuncu("Uye", P1); uye2 = oyuncu("Uyeiki", P1); yeni = oyuncu("Yeni", P1, gun=1); bos = oyuncu("Partisiz")
mod = oyuncu("Yonetici"); q(f"update oyun.profiller set yonetici=true where id='{mod}'")
rakip = oyuncu("Rakip", P2)

# 1) Ürünler pasif başlar, vitrinde yok
d = rpc(uye, "magaza_durum")
assert not [p for p in d["paketler"] if p["urun_id"].startswith("secimonline.") and p["urun_id"] in (
  "secimonline.cash_1000000", "secimonline.kursu_showcase_24h", "secimonline.vanity_plate")], d["paketler"]
assert "m2" in d and d["m2"]["vitrin"]["yer"] == 3 and d["m2"]["manset"]["yer"] == 3
assert int(q("select count(*) from oyun.paketler where urun_id like 'secimonline.%' and not aktif and urun_id in "
             "('secimonline.cash_1000000','secimonline.politics_card_90d','secimonline.politics_card_365d','secimonline.gift_card_30d','secimonline.party_card_pack',"
             "'secimonline.party_donation','secimonline.hq_campaign','secimonline.launch_stage','secimonline.congress_pack','secimonline.kursu_showcase_24h',"
             "'secimonline.headline_24h','secimonline.mandate','secimonline.victory_night','secimonline.vanity_plate','secimonline.vanity_plate_elite',"
             "'secimonline.plate_change','secimonline.supporter_wall_bronze','secimonline.supporter_wall_silver','secimonline.supporter_wall_gold')")) == 19
ok("19 yeni ürün kimliği aktif=false eklendi; magaza_durum 'm2' alanını taşıyor")

# 2) Hazine ve kartlar
o = para(uye); al(uye, "secimonline.cash_1000000"); assert para(uye) == o + 1000000
o = para(uye); al(uye, "secimonline.politics_card_365d")
assert para(uye) == o + 365000
gun = float(q(f"select extract(epoch from kart_bitis - oyun.simdi())/86400 from oyun.magaza_hesap where user_id='{uye}'"))
assert 364.9 < gun < 365.1, gun
assert "yu" in rozet(uye)
al(uye2, "secimonline.politics_card_90d"); assert "yu" not in rozet(uye2)
ok("Hazine 1.000.000 ₺; Yıllık kart 365.000 ₺ + 365 gün + Yıllık Üye rozeti; 90 günlükte rozet yok")

# 3) Plaka
al(uye, "secimonline.vanity_plate")
pl = q(f"select metin from oyun.m2_plaka where user_id='{uye}'"); assert pl.startswith("35 US "), pl
assert ("p:" + pl) in rozet(uye)
r = rpc(uye, "plaka_kaydet", 35, "AY", "1923"); assert r["plaka"] == "35 AY 1923" and not r["ucretli"]
hata_bekle(rpc, uye, "plaka_kaydet", 35, "AY", "1924", icerir="Plaka Değiştirme")
hata_bekle(rpc, uye2, "plaka_kaydet", 6, "AB", "123", icerir="Özel Plaka")
al(uye2, "secimonline.vanity_plate")
hata_bekle(rpc, uye2, "plaka_kaydet", 35, "AY", "1923", icerir="başka bir oyuncuda")
hata_bekle(rpc, uye2, "plaka_kaydet", 6, "K", "07", icerir="Seçkin")
hata_bekle(rpc, uye2, "plaka_kaydet", 6, "PKK", "123", icerir="kullanılamaz")
hata_bekle(rpc, uye2, "plaka_kaydet", 6, "ÇA", "123", icerir="1–3 harf")
hata_bekle(rpc, uye2, "plaka_kaydet", 6, "AB", "0123", icerir="Standart")
al(uye2, "secimonline.vanity_plate_elite")
assert rpc(uye2, "plaka_kaydet", 6, "K", "07")["plaka"] == "06 K 07"
al(uye, "secimonline.plate_change")
assert rpc(uye, "plaka_kaydet", 35, "AY", "1924")["ucretli"] is True and jeton(uye, "plaka_degis") == 0
q(f"update oyun.partiler set gb=null where id={P1}"); assert "pm" not in rozet(uye)
q(f"update oyun.partiler set gb='{uye}' where id={P1}"); assert "pm" in rozet(uye)
q(f"update oyun.partiler set gb='{gb}' where id={P1}")
ok("Plaka: ilk plaka kendiliğinden, bir kez ücretsiz seçim, sonra Plaka Değiştirme; tekillik, Seçkin kuralı, yasaklı harfler; makamda 'pm'")

# 4) Parti bağışı
k0 = kasa(P1); al(uye, "secimonline.party_donation")
assert kasa(P1) == k0 + 250000 and jeton(uye, "m2_bagis") == 0
assert ("bb:%s" % P1) in rozet(uye)
m = q(f"select metin from oyun.mesajlar where kanal='parti:{P1}' order by id desc limit 1"); assert m.startswith("[Büyük Bağış]"), m
assert q(f"select tur from oyun.parti_hareket where parti_id={P1} order by id desc limit 1") == "bagis"
al(bos, "secimonline.party_donation"); assert jeton(bos, "m2_bagis") == 1
q(f"update oyun.profiller set parti_id={P2} where id='{bos}'"); k2 = kasa(P2)
rpc(bos, "m2_bekleyen_uygula"); assert kasa(P2) == k2 + 250000 and jeton(bos, "m2_bagis") == 0
q(f"update oyun.profiller set parti_id=null where id='{bos}'"); assert not [x for x in rozet(bos) if x.startswith("bb:")]
ok("Bağış: 250.000 ₺ kasaya, parti sohbetine kart, 30 gün bb rozeti; partisizde jeton bekler, katılınca uygulanır; partiden çıkınca rozet düşer")

# 5) Genel Merkez
k0 = kasa(P1)
al(yeni, "secimonline.hq_campaign"); assert jeton(yeni, "m2_gm") == 1  # hesap 3 günden yeni
for i in range(10): al(uye2, "secimonline.hq_campaign")
assert kasa(P1) == k0 + 1000000
g = rpc(uye, "genel_merkez"); assert g["katki"] == 10 and g["seviye"] == 1 and g["sonraki"] == 25, g
assert "gm:1" in rozet(uye) and "gm:1" in rozet(gb) and not [x for x in rozet(rakip) if x.startswith("gm:")]
assert q(f"select metin from oyun.olaylar where parti_id={P1} order by id desc limit 1").endswith("İl Binası'ne taşındı")
assert g["siralama"][0]["id"] == P1 and g["liste"][0]["adet"] == 10
ok("Genel Merkez: 10 katkıda İl Binası, bütün üyelere gm:1 rozeti, haber; 3 günlük hesap şartı; sıralama")

# 6) Lansman Sahnesi + Kongre
al(uye, "secimonline.launch_stage"); assert P1 in rpc(rakip, "m2_genel")["sahne"]
al(uye2, "secimonline.launch_stage"); assert jeton(uye2, "m2_sahne") == 1
assert str(P1) in rpc(rakip, "magaza_rozetler")["#sahne"].split(",")
sid = int(q(f"insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, durum, hedef_parti_id) values "
            f"('kurultay', 'k{EK}', oyun.simdi() - interval '1 day', oyun.simdi() + interval '1 day', oyun.simdi() + interval '2 day', oyun.simdi() + interval '2 day 6 hours', oyun.simdi() + interval '3 day', 'bekliyor', {P1}) returning id"))
al(uye, "secimonline.congress_pack"); assert jeton(uye, "m2_kongre") == 1  # henüz aday değil
q(f"set session_replication_role = replica; insert into oyun.adaylar(secim_id, user_id, parti_id) values ({sid}, '{uye}', {P1})")
r = rpc(uye, "kongre_slogan", "Birlikte daha güçlü"); assert r["slogan"] == "Birlikte daha güçlü" and jeton(uye, "m2_kongre") == 0
k = rpc(rakip, "kongre_paketleri", sid); assert k[0]["kad"] == kad(uye) and k[0]["slogan"] == "Birlikte daha güçlü"
ok("Lansman Sahnesi partiye kalıcı (ikincisi jeton olarak bekler); Kongre Paketi adaylıkta uygulanır, slogan değişir")

# 7) Mazbata ve kutlama
al(uye2, "secimonline.victory_night"); assert jeton(uye2, "m2_kutlama") == 1
ms = int(q(f"insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, durum) values "
           f"('mv', 'm{EK}', oyun.simdi() - interval '5 day', oyun.simdi() - interval '3 day', oyun.simdi() - interval '2 day', oyun.simdi() - interval '2 day' + interval '9 hours', oyun.simdi() - interval '1 day', 'tamam') returning id"))
for i, (u, p) in enumerate([(uye2, P1), (uye, P1), (rakip, P2)]):
    vu = oyuncu(f"Secmen{i}", p)
    q(f"insert into oyun.oylar(secim_id, secmen, il_id, parti_id) values ({ms}, '{vu}', 35, {p})")
q(f"insert into oyun.kazananlar(secim_id, user_id, il_id, parti_id) values ({ms}, '{uye2}', 35, {P1})")
z = qj(f"select to_jsonb(z) from oyun.m2_zafer z where user_id='{uye2}'")
assert z and z["gorev"] == "İzmir milletvekili" and float(z["oy_orani"]) == 66.7, z
assert any(x.startswith("z:") for x in rozet(uye2)) and jeton(uye2, "m2_kutlama") == 0
assert q("select metin from oyun.mesajlar where kanal='genel' order by id desc limit 1").startswith("[Zafer]")
bek = rpc(uye2, "magaza_durum")["m2"]["kutlama_bekleyen"]; assert bek["gorev"] == "İzmir milletvekili"
rpc(uye2, "kutlama_goruldu", bek["id"]); assert rpc(uye2, "magaza_durum")["m2"]["kutlama_bekleyen"] is None
al(uye2, "secimonline.mandate")
mz = rpc(rakip, "mazbatalar", kad(uye2)); assert len(mz) == 1 and mz[0]["gorev"] == "İzmir milletvekili" and float(mz[0]["oy_orani"]) == 66.7
al(rakip, "secimonline.mandate"); assert jeton(rakip, "m2_mazbata") == 1  # zaferi yok, bekler
hata_bekle(rpc, rakip, "mazbata_olustur", ms, icerir="mazbata alınamaz")
ok("Kutlama önceden alınınca zafer gecesi kendiliğinden (sahne, [Zafer] sohbet kartı, z: rozeti); mazbata oy oranıyla; zaferi olmayanda bekler")

# 8) Destekçiler duvarı
al(rakip, "secimonline.supporter_wall_gold"); al(uye, "secimonline.supporter_wall_bronze")
dv = rpc(mod, "destekci_duvari"); assert dv["liste"][0]["kad"] == kad(rakip) and dv["liste"][0]["kademe"] == 3
assert "dw:3" in rozet(rakip) and "dw:1" in rozet(uye)
ok("Destekçiler Duvarı: altın en üstte, ay boyunca dw rozeti")

# 9) Hediye ve parti kartı
o = para(bos); al(uye, "secimonline.gift_card_30d")
hata_bekle(rpc, uye, "hediye_kart_ver", kad(uye), None, icerir="Kendine")
r = rpc(uye, "hediye_kart_ver", kad(bos), "Hayırlı olsun"); assert r["kalan"] == 0 and para(bos) == o + 30000
assert q(f"select kart_bitis > oyun.simdi() + interval '29 days' from oyun.magaza_hesap where user_id='{bos}'") == "t"
hata_bekle(rpc, uye, "hediye_kart_ver", kad(bos), None, icerir="hakkın yok")
al(uye, "secimonline.party_card_pack"); assert jeton(uye, "m2_parti_kart") == 5
hata_bekle(rpc, uye, "parti_kart_ver", kad(uye2), icerir="genel başkan")
q(f"update oyun.profiller set parti_id={P1} where id='{gb}'")
al(gb, "secimonline.party_card_pack")
hata_bekle(rpc, gb, "parti_kart_ver", kad(rakip), icerir="üyelerine")
rpc(gb, "parti_kart_ver", kad(uye2)); hata_bekle(rpc, gb, "parti_kart_ver", kad(uye2), icerir="son 30 günde")
assert jeton(gb, "m2_parti_kart") == 4
ok("Hediye kartı (30.000 ₺ + 30 gün, kendine yok); Parti Kart Paketi 5 hak, yalnız GB/GBY, yalnız üyeye, üye başına 30 günde bir")

# 10) Kürsü vitrini: 3 yer + sıra + önden bildirim
vs = [oyuncu(f"Vit{i}", P2) for i in range(5)]
akis = {}
for i, u in enumerate(vs):
    akis[u] = int(q(f"insert into oyun.akis(user_id, metin, zaman) values ('{u}', 'Vitrin denemesi {i}', oyun.simdi() - interval '{i+1} hours') returning id"))
    al(u, "secimonline.kursu_showcase_24h")
hata_bekle(rpc, vs[0], "kursu_vitrin_baslat", akis[vs[1]], icerir="kendi paylaşımını")
for u in vs[:3]:
    r = rpc(u, "kursu_vitrin_baslat", akis[u]); assert r["durum"] == "yayinda", r
zaman("2026-12-12 13:00+03")
r = rpc(vs[3], "kursu_vitrin_baslat", akis[vs[3]]); assert r["durum"] == "sirada" and r["sira"] == 1, r
assert r["tahmin"].startswith("2026-12-13T12:00"), r
assert "sıraya girdi (1. sıra)" in q(f"select metin from oyun.bildirimler where user_id='{vs[3]}' order by id desc limit 1")
r = rpc(vs[4], "kursu_vitrin_baslat", akis[vs[4]]); assert r["sira"] == 2
hata_bekle(rpc, vs[4], "kursu_vitrin_baslat", akis[vs[4]], icerir="zaten var")
a = rpc(mod, "kursu_akis", "herkes", None, 20)
ilk = [x["g"]["id"] for x in a["liste"][:3]]
assert set(ilk) == {akis[u] for u in vs[:3]} and all(x.get("vitrin") for x in a["liste"][:3]) and sorted(a["vitrin"]) == sorted(ilk)
assert len([x for x in a["liste"] if x["g"]["id"] == ilk[0]]) == 1
assert not rpc(mod, "kursu_akis", "herkes", a["imlec"] or "2026-12-12 10:00+03", 20).get("vitrin")
d = rpc(uye, "magaza_durum")["m2"]["vitrin"]; assert d["dolu"] == 3 and d["sira"] == 2
ok("Vitrin: ilk 3 hemen yayında, 4. ve 5. sırada (tahmini saat bildirimi), akışın başında tek kez, ikinci sayfada yok")

# Seçim günü duraklama: genel oylama sürerken vitrin görünmez, süre işlemez
q(f"insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, durum) values "
  f"('bel', 'd{EK}', oyun.simdi() - interval '3 day', oyun.simdi() - interval '1 day', oyun.simdi() - interval '1 hour', oyun.simdi() + interval '8 hours', oyun.simdi() + interval '9 hours', 'bekliyor')")
tick(); zaman("2026-12-12 13:10+03"); bit0 = q(f"select bit from oyun.m2_yayin where akis_id={akis[vs[0]]}"); tick()
bit1 = q(f"select bit from oyun.m2_yayin where akis_id={akis[vs[0]]}")
assert bit1 > bit0, (bit0, bit1)
assert not rpc(mod, "kursu_akis", "herkes", None, 20).get("vitrin") and rpc(mod, "m2_genel")["duraklat"] is True
q(f"update oyun.secimler set durum='tamam' where donem='d{EK}'")
ok("Seçim günü oy saatlerinde vitrin akıştan kalkıyor ve bitiş süresi uzuyor")

# Süre dolunca sıradaki yayına girer; paylaşım silinirse vitrinden çıkar
zaman("2026-12-13 13:30+03"); r = tick(); assert r["biten"] == 3 and r["baslayan"] == 2, r
assert q(f"select durum from oyun.m2_yayin where akis_id={akis[vs[3]]}") == "yayinda"
assert "şu an yayında" in q(f"select metin from oyun.bildirimler where user_id='{vs[3]}' order by id desc limit 1")
q(f"update oyun.akis set gizli=true where id={akis[vs[4]]}"); tick()
assert q(f"select durum from oyun.m2_yayin where akis_id={akis[vs[4]]}") == "kaldirildi"
ok("Süre dolunca sıradakiler yayına girdi ve haber aldı; gizlenen paylaşım vitrinden çıktı (iade yok)")

# 11) Gündem manşeti: moderasyon, sıra, haber şeridi, ret iadesi, otomatik inceleme
ms_ = [oyuncu(f"Man{i}") for i in range(5)]
for u in ms_: al(u, "secimonline.headline_24h")
hata_bekle(rpc, ms_[0], "manset_basvur", "kısa", False, icerir="en az 10")
hata_bekle(rpc, ms_[0], "manset_basvur", "Parti adına bir manşet denemesi", True, icerir="Parti adına")
ids = [rpc(u, "manset_basvur", f"Pazar günü Konya'da büyük miting {i}", False)["id"] for i, u in enumerate(ms_)]
hata_bekle(rpc, ms_[0], "manset_onay_liste", icerir="yöneticiler")
assert len(rpc(mod, "manset_onay_liste")["onay"]) == 5
for i in ids[:3]: assert rpc(mod, "manset_karar", i, True, None)["durum"] == "yayinda"
h = rpc(mod, "haberler", 15); assert [x.get("tur") for x in h[:3]] == ["manset"] * 3 and h[0]["metin"].startswith("Manşet · ")
r = rpc(mod, "manset_karar", ids[3], True, None); assert r["durum"] == "sirada" and r["sira"] == 1
hata_bekle(rpc, mod, "manset_karar", ids[4], False, "", icerir="gerekçe")
rpc(mod, "manset_karar", ids[4], False, "Uygunsuz içerik"); assert jeton(ms_[4], "m2_manset") == 1
otomatik = rpc(ms_[4], "manset_basvur", "Kurultayımıza bütün üyeler davetlidir", False)["id"]
zaman("2026-12-14 02:00+03"); tick()
assert q(f"select durum from oyun.m2_yayin where id={otomatik}") in ("sirada", "yayinda")
rpc(mod, "m2_yayin_kaldir", ids[0], "Kurala aykırı içerik")
assert q(f"select durum from oyun.m2_yayin where id={ids[0]}") == "kaldirildi"
ok("Manşet: moderasyon, ilk 3 haber şeridinin başında, 4. sırada; ret hakkı iade eder; 12 saatte otomatik inceleme; yönetim kaldırabilir")

# İptal: sıradaki kayıt geri çekilirse hak iade
u = oyuncu("Iptal"); al(u, "secimonline.headline_24h")
i = rpc(u, "manset_basvur", "Geri çekilecek bir manşet denemesi", False)["id"]
rpc(u, "m2_yayin_iptal", i); assert jeton(u, "m2_manset") == 1
ok("İncelemedeki/sıradaki kayıt geri çekilince hak iade ediliyor")

# 12) İadeler
islem = uuid.uuid4().hex; k0 = kasa(P1); al(uye, "secimonline.party_donation", islem=islem)
assert kasa(P1) == k0 + 250000
olay(uye, "secimonline.party_donation", tur="CANCELLATION", islem=islem, cancel_reason="CUSTOMER_SUPPORT")
assert kasa(P1) == k0
islem = uuid.uuid4().hex; al(uye, "secimonline.supporter_wall_silver", islem=islem); assert "dw:2" in rozet(uye)
olay(uye, "secimonline.supporter_wall_silver", tur="CANCELLATION", islem=islem, cancel_reason="CUSTOMER_SUPPORT")
assert "dw:2" not in rozet(uye) and "dw:1" in rozet(uye)
islem = uuid.uuid4().hex; al(bos, "secimonline.kursu_showcase_24h", islem=islem); assert jeton(bos, "m2_vitrin") == 1
olay(bos, "secimonline.kursu_showcase_24h", tur="CANCELLATION", islem=islem, cancel_reason="CUSTOMER_SUPPORT"); assert jeton(bos, "m2_vitrin") == 0
ok("İade: bağış kasadan geri alınıyor, destek kademesi düşüyor, kullanılmamış vitrin hakkı siliniyor")
print("magaza_paket2: TAMAM")
