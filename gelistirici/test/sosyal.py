"""Kabine, 6 GBY, sohbet, özel mesaj, propaganda, bildirim ve şikâyet testleri.
Çalıştır: ../kur_yerel.sh && python3 sosyal.py"""
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle, SqlHata

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)

q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com")
    rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u

ali   = oyuncu("Ali", 35, 1)      # İzmir, CYP
ayse  = oyuncu("Ayse", 35, 1)
veli  = oyuncu("Veli", 6, 2)      # Ankara, ABP
zeynep = oyuncu("Zeynep", 6, 1)   # Ankara, CYP
uyeler = [oyuncu(f"Uye{i}", 35, 1) for i in range(8)]
yabanci = [oyuncu(f"Yab{i}", 34, 3) for i in range(9)]   # İstanbul, YDP
def k(sql): return q(sql)

# ---------------- 6 GBY ----------------
q(f"update oyun.partiler set gb='{ali}' where id=1")
for i, u in enumerate(uyeler[:6], start=1):
    rpc(ali, "gby_ata", i, f"Uye{uyeler.index(u)}")
hata_bekle(rpc, ali, "gby_ata", 7, "Ayse", icerir="1-6")
assert k("select count(*) from oyun.parti_gby where parti_id=1") == "6"
rpc(ali, "gby_ata", 2, "Uye0")          # Uye0 1. sıradan 2. sıraya geçer, eski 2. sıra boşalır
assert k("select string_agg(sira::text, ',' order by sira) from oyun.parti_gby where parti_id=1") == "2,3,4,5,6"
hata_bekle(rpc, ali, "gby_ata", 1, "Veli", icerir="üyesi değil")
hata_bekle(rpc, ayse, "gby_ata", 1, "Uye7", icerir="Yalnızca genel başkan")
pd = rpc(ali, "parti_detay", 1)
assert len(pd["gby"]) == 5
assert "genel başkan yardımcısı olarak atadı" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{uyeler[3]}'")
rpc(uyeler[3], "istifa", "gby")
assert k("select count(*) from oyun.parti_gby where parti_id=1") == "4"
rpc(uyeler[4], "partiden_ayril")
assert k("select count(*) from oyun.parti_gby where parti_id=1") == "3"
assert rpc(uyeler[5], "durum")["profil"]["gby"] is True
ok("6 genel başkan yardımcısı: atama, sıra değiştirme, yetki, istifa, partiden ayrılınca düşme, bildirim")

# ---------------- KABİNE ----------------
q(f"insert into oyun.makamlar(tur,user_id,parti_id,bas) values ('cb','{ali}',1,'2026-10-02 12:00+03')")
q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('mv','{veli}',6,2,'2026-10-02 12:00+03')")
hata_bekle(rpc, ayse, "bakan_ata", "adalet", "Veli", icerir="yalnızca cumhurbaşkanında")
hata_bekle(rpc, ali, "bakan_ata", "adalet", "Ali", icerir="kendini")
hata_bekle(rpc, ali, "bakan_ata", "uzay", "Ayse", icerir="bulunamadı")
kab = rpc(ali, "kabine")
assert len(kab["bakanlar"]) == 12 and all(b["kad"] is None for b in kab["bakanlar"])
# tek görev kuralı: başka görevi olan kişi bakan atanamaz
hata_bekle(rpc, ali, "bakan_ata", "adalet", "Veli", icerir="önce")          # Veli milletvekili
hata_bekle(rpc, ali, "bakan_ata", "adalet", "Uye0", icerir="önce")          # Uye0 genel başkan yardımcısı
kad_sirasi = ["Ayse", "Yab4", "Zeynep", "Uye6", "Uye7"] + [f"Yab{i}" for i in (0, 1, 2, 5, 6, 7, 8)]
for b, kd in zip(kab["bakanlar"], kad_sirasi):
    kab = rpc(ali, "bakan_ata", b["kod"], kd)
assert all(b["kad"] for b in kab["bakanlar"])
# Veli önce vekilliğinden istifa eder, sonra atanabilir
rpc(veli, "istifa", "mv")
assert k(f"select count(*) from oyun.makamlar where user_id='{veli}' and tur='mv' and bit is null") == "0"
yab4 = k("select id from oyun.profiller where kad='Yab4'")
rpc(ali, "bakan_ata", "disisleri", "Veli")
assert rpc(veli, "durum")["profil"]["makamlar"][0]["bakanlik"] == "disisleri"
assert "seni Dışişleri Bakanlığı görevinden aldı" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{yab4}'")
# bakanlığa başka biri atanınca eskisi görevden alınır
rpc(ali, "bakan_ata", "adalet", "Yab3")
assert "seni Adalet Bakanlığı görevinden aldı" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{ayse}'")
# bakan başka bir göreve (başka bakanlık dahil) atanamaz; aynı anda iki görev yok
hata_bekle(rpc, ali, "bakan_ata", "saglik", "Veli", icerir="önce")
assert k(f"select string_agg(bakanlik, ',') from oyun.makamlar where user_id='{veli}' and bit is null") == "disisleri"
# genel başkan yardımcısı yalnızca vekil olabilir: bakan, belediye başkanı ya da başka makam sahibi atanamaz
rpc(veli, "istifa", "bakan")
assert "istifa etti" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{ali}'")
rpc(ali, "bakan_gorevden_al", "ticaret")
hata_bekle(rpc, ali, "bakan_gorevden_al", "ticaret", icerir="boş")
ok("Kabine: 12 bakanlık, yalnız CB atar, başka görevi olan atanamaz (önce istifa), yerine atama/istifa/görevden alma")

# yeni cumhurbaşkanı göreve başlayınca kabine düşer
dolu = int(k("select count(*) from oyun.makamlar where tur='bakan' and bit is null"))
sid = k("""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,goreve_bas,durum,sonuc)
           values ('cb','2099-01','2026-10-02 08:00+03','2026-10-02 09:00+03','2026-10-02 10:00+03','2026-10-02 12:30+03','sonuclandi','{"ikinci_tur":false}') returning id""").split("\n")[0]
q(f"insert into oyun.kazananlar values ({sid}, '{zeynep}', null, 1)")
q(f"select oyun.goreve_baslat({sid})")
assert k("select count(*) from oyun.makamlar where tur='bakan' and bit is null") == "0"
assert k(f"select user_id from oyun.makamlar where tur='cb' and bit is null") == zeynep
assert k("select count(*) from oyun.makamlar where bitis_neden='kabine_yenilendi'") == str(dolu - 1)  # Zeynep'in bakanlığı 'yeni_gorev' ile bitti
ok(f"Yeni cumhurbaşkanı göreve başlayınca {dolu} kişilik kabine düştü, herkese bildirim gitti")
cb = zeynep

# ---------------- SOHBET ----------------
saat("2026-10-03 10:00:00")
rpc(ali, "sohbet_yaz", "genel", "Merhaba Türkiye!")
hata_bekle(rpc, ali, "sohbet_yaz", "genel", "ikinci", icerir="hızlı")
saat("2026-10-03 10:00:05")
rpc(ali, "sohbet_yaz", "il", "İzmirliler toplanın")
saat("2026-10-03 10:00:10")
rpc(ali, "sohbet_yaz", "parti", "Parti içi gizli toplantı")
hata_bekle(rpc, ayse, "sohbet_yaz", "genel", "Sen bir şerefsizsin", icerir="uygunsuz")
hata_bekle(rpc, ayse, "sohbet_yaz", "genel", "x" * 501, icerir="500")
hata_bekle(rpc, ayse, "sohbet_yaz", "genel", "   ", icerir="boş")
g = rpc(veli, "sohbet_oku", "genel")
assert [m["metin"] for m in g["mesajlar"]] == ["Merhaba Türkiye!"] and g["mesajlar"][0]["unvan"] == "CYP Genel Başkanı"
assert rpc(veli, "sohbet_oku", "il")["mesajlar"] == []                     # Veli Ankara'da
assert [m["metin"] for m in rpc(ayse, "sohbet_oku", "il")["mesajlar"]] == ["İzmirliler toplanın"]
assert rpc(veli, "sohbet_oku", "parti")["mesajlar"] == []                  # Veli ABP'de
assert rpc(ayse, "sohbet_oku", "parti")["mesajlar"][0]["metin"] == "Parti içi gizli toplantı"
assert rpc(ayse, "sohbet_oku", "il")["baslik"] == "İzmir Kahvesi"
partisiz = oyuncu("Partisiz", 35)
hata_bekle(rpc, partisiz, "sohbet_oku", "parti", icerir="partiye üye")
# Meclis kanalı
hata_bekle(rpc, ayse, "sohbet_yaz", "meclis", "Söz istiyorum", icerir="Genel Kurul")
saat("2026-10-03 10:01:00")
rpc(cb, "sohbet_yaz", "meclis", "Sayın Başkan, değerli milletvekilleri")
m = rpc(ayse, "sohbet_oku", "meclis")
assert m["yazabilir"] is False and m["mesajlar"][0]["unvan"] == "Cumhurbaşkanı"
# canlı takip (p_sonra) ve geçmiş (p_once)
son_id = g["mesajlar"][-1]["id"]
for i in range(5):
    saat(f"2026-10-03 10:02:{10 + i * 4:02d}"); rpc(ayse, "sohbet_yaz", "genel", f"mesaj {i}")
yeni = rpc(veli, "sohbet_oku", "genel", None, son_id)["mesajlar"]
assert [x["metin"] for x in yeni] == [f"mesaj {i}" for i in range(5)]
eski = rpc(veli, "sohbet_oku", "genel", yeni[0]["id"], None)["mesajlar"]
assert [x["metin"] for x in eski] == ["Merhaba Türkiye!"]
# dakikada 12 sınırı
saat("2026-10-03 11:00:00")
for i in range(12):
    saat(f"2026-10-03 11:00:{i * 4:02d}"); rpc(veli, "sohbet_yaz", "genel", f"seri {i}")
saat("2026-10-03 11:00:50")
hata_bekle(rpc, veli, "sohbet_yaz", "genel", "bir tane daha", icerir="dakikada")
ok("Sohbet: genel/il/parti/meclis kanalları ayrı, Meclis'e yalnız vekil-bakan-CB yazar, unvan rozetleri, küfür/uzunluk/hız sınırı, canlı takip")

# ---------------- ENGELLEME ----------------
rpc(ayse, "engelle", "Veli")
assert all(x["kad"] != "Veli" for x in rpc(ayse, "sohbet_oku", "genel")["mesajlar"])
assert [x["kad"] for x in rpc(ayse, "engellenenler")] == ["Veli"]
saat("2026-10-03 11:05:00")
hata_bekle(rpc, veli, "ozel_yaz", "Ayse", "selam", icerir="engelleme")
hata_bekle(rpc, ayse, "ozel_yaz", "Veli", "selam", icerir="engelleme")
rpc(ayse, "engel_kaldir", "Veli")
assert any(x["kad"] == "Veli" for x in rpc(ayse, "sohbet_oku", "genel")["mesajlar"])
ok("Engelleme: engellenen kişinin mesajları görünmez, iki yönlü özel mesaj kapanır, engel kaldırılabilir")

# ---------------- ÖZEL MESAJ ----------------
saat("2026-10-03 11:10:00"); rpc(veli, "ozel_yaz", "Ayse", "Merhaba Ayşe Hanım, ittifak konuşalım mı?")
saat("2026-10-03 11:10:05"); rpc(veli, "ozel_yaz", "Ayse", "Akşam uygun musunuz?")
hata_bekle(rpc, veli, "ozel_yaz", "Veli", "kendime", icerir="Kendine")
hata_bekle(rpc, veli, "ozel_yaz", "Yokboyle", "x", icerir="bulunamadı")
assert rpc(ayse, "rozetler")["ozel"] == 2
lst = rpc(ayse, "ozel_liste")
assert lst[0]["kad"] == "Veli" and lst[0]["okunmamis"] == 2 and lst[0]["son"] == "Akşam uygun musunuz?"
konusma = rpc(ayse, "ozel_oku", "Veli")
assert len(konusma["mesajlar"]) == 2 and not konusma["mesajlar"][0]["benim"]
assert rpc(ayse, "rozetler")["ozel"] == 0
saat("2026-10-03 11:11:00"); rpc(ayse, "ozel_yaz", "Veli", "Olur, görüşelim.")
assert rpc(veli, "ozel_liste")[0]["okunmamis"] == 1
assert rpc(yabanci[0], "ozel_liste") == []
ok("Özel mesaj: gönderme, konuşma listesi, okunmamış sayısı, okununca sıfırlanma, başkası göremez")

# ---------------- PROPAGANDA ----------------
saat("2026-10-03 12:00:00")
haklar = rpc(cb, "yayin_haklari")
cbh = next(h for h in haklar if h["tur"] == "cb")
assert cbh["hedef"] == "Tüm Türkiye" and cbh["kalan"] == 1 and cbh["kitle"] == int(k("select count(*) from oyun.profiller")) - 1
r = rpc(cb, "yayin_gonder", "cb", "Aziz milletim, yeni dönem hayırlı olsun!", None)
assert r["kitle"] == cbh["kitle"]
hata_bekle(rpc, cb, "yayin_gonder", "cb", "Bir daha", None, icerir="Bugünkü")
hata_bekle(rpc, ayse, "yayin_gonder", "cb", "Ben de", None, icerir="yetkin yok")
# genel başkan (Ali, CYP) 3/gün parti genelgesi → yalnız CYP üyeleri
for i in range(3): rpc(ali, "yayin_gonder", "parti", f"Genelge {i + 1}", None)
hata_bekle(rpc, ali, "yayin_gonder", "parti", "Genelge 4", None, icerir="Bugünkü")
# GBY 1/gün
rpc(uyeler[5], "yayin_gonder", "parti", "GBY duyurusu", None)
# vekil: il halkına (Veli artık vekil değil; Zeynep CB). Yeni vekil oluştur
q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('mv','{ayse}',35,1,'2026-10-03 00:00+03')")
rpc(ayse, "yayin_gonder", "vekil", "İzmir için çalışıyorum", None)
kutu_veli = rpc(veli, "bildirim_kutusu", 50)
metinler_veli = [x["metin"] for x in kutu_veli if x["tur"] == "yayin"]
assert metinler_veli == ["Aziz milletim, yeni dönem hayırlı olsun!"], metinler_veli   # Ankara + ABP: yalnız CB'yi görür
kutu_uye = rpc(uyeler[7], "bildirim_kutusu", 50)
mu = [x["metin"] for x in kutu_uye if x["tur"] == "yayin"]
assert set(mu) == {"Aziz milletim, yeni dönem hayırlı olsun!", "Genelge 1", "Genelge 2", "Genelge 3", "GBY duyurusu", "İzmir için çalışıyorum"}, mu
assert next(x for x in kutu_uye if x["metin"] == "GBY duyurusu")["unvan"] == "CYP Genel Başkan Yardımcısı"
assert all(x["yeni"] for x in kutu_uye if x["tur"] == "yayin")
assert rpc(uyeler[7], "rozetler")["bildirim"] == 0       # kutu açılınca okundu
saat("2026-10-03 12:30:00")
q(f"select oyun.bildir('{uyeler[7]}', 'Test bildirimi')")
assert rpc(uyeler[7], "rozetler")["bildirim"] == 1
# ertesi gün hak yenilenir
saat("2026-10-04 00:00:30")
assert next(h for h in rpc(cb, "yayin_haklari") if h["tur"] == "cb")["kalan"] == 1
ok("Propaganda: CB tüm Türkiye'ye, GB 3/gün ve GBY 1/gün partiye, vekil iline; kitleler doğru, günlük kota gece yarısı yenileniyor")

# aday propagandası: belediye ön seçimi → partinin o ildeki üyeleri
saat("2026-10-06 10:00")
q("update oyun.profiller set parti_at='2026-10-01 00:00+03', olusturma='2026-09-01 00:00+03'")   # başvuru öncesi üyelik
q(f"update oyun.makamlar set bit='2026-10-06 00:00+03' where user_id='{ayse}' and tur='mv'")
rpc(ayse, "aday_ol", "bel_on")
h = [x for x in rpc(ayse, "yayin_haklari") if x["tur"] == "aday"]
assert h and h[0]["hedef"] == "CYP İzmir üyeleri" and "belediye başkanı aday adayı" in h[0]["unvan"]
rpc(ayse, "yayin_gonder", "aday", "Ön seçimde bana oy verin!", h[0]["secim_id"])
assert "Ön seçimde bana oy verin!" in [x["metin"] for x in rpc(uyeler[0], "bildirim_kutusu", 50)]
assert "Ön seçimde bana oy verin!" not in [x["metin"] for x in rpc(zeynep, "bildirim_kutusu", 50)]   # Zeynep CYP ama Ankara'da
saat("2026-10-08 17:00")   # oylama bitti → hak düşer
assert not [x for x in rpc(ayse, "yayin_haklari") if x["tur"] == "aday"]
ok("Aday propagandası: ön seçim adayı yalnız partisinin ildeki üyelerine ulaşır, oylama bitince hak kalkar")

# ---------------- ŞİKÂYET ----------------
saat("2026-10-09 10:00")
mid = int(k("select id from oyun.mesajlar where metin='İzmirliler toplanın'"))
for u in uyeler[:2]: rpc(u, "sikayet_et", "mesaj", mid, None, "hakaret")
assert k(f"select gizli from oyun.mesajlar where id={mid}") == "f"
rpc(uyeler[2], "sikayet_et", "mesaj", mid, None, "hakaret")
rpc(uyeler[2], "sikayet_et", "mesaj", mid, None, "hakaret")   # aynı kişi iki kez → tek sayılır
assert k(f"select gizli from oyun.mesajlar where id={mid}") == "t"
assert all(x["id"] != mid for x in rpc(ayse, "sohbet_oku", "il")["mesajlar"])
hata_bekle(rpc, ali, "sikayet_et", "mesaj", int(k("select id from oyun.mesajlar where metin='Merhaba Türkiye!'")), None, "hakaret", icerir="Kendini")
hata_bekle(rpc, ali, "sikayet_et", "mesaj", 1, None, "keyfime", icerir="nedeni")
oid = int(k("select id from oyun.ozel where metin='Olur, görüşelim.'"))
rpc(veli, "sikayet_et", "ozel", oid, None, "taciz")
assert k(f"select gizli from oyun.ozel where id={oid}") == "t"
for u in yabanci[:8]: rpc(u, "sikayet_et", "oyuncu", None, "Ali", "spam")
assert k(f"select susturma_bitis is not null from oyun.profiller where id='{ali}'") == "t"
hata_bekle(rpc, ali, "sohbet_yaz", "genel", "Neden sustum?", icerir="mesaj gönderemez")
ok("Şikâyet: 3 farklı kişi → mesaj gizlenir, özel mesaj şikâyeti anında gizler, 24 saatte 8 kişi → hesap 24 saat susturulur")

# ---------------- OYUNCU KARTI ----------------
kart = rpc(veli, "oyuncu_kart", "Zeynep")
assert kart["unvan"] == "Cumhurbaşkanı" and kart["il_ad"] == "Ankara" and any("cumhurbaşkanlığı" in g["makam"] for g in kart["gecmis"])
ok("Oyuncu kartı: unvan, il, parti ve görev geçmişi")

# ---------------- HESAP SİLME ----------------
rpc(veli, "hesabimi_sil")
for t in ["mesajlar where user_id", "ozel where gonderen", "ozel where alici", "yayinlar where gonderen", "bildirimler where user_id"]:
    assert k(f"select count(*) from oyun.{t}='{veli}'") == "0", t
ok("Hesap silinince sohbet, özel mesaj, yayın ve bildirimleri de silinir")

# ---------------- GÜVENLİK ----------------
for sql in ["set role anon; select public.sohbet_oku('genel');", "set role anon; select public.kabine();",
            "set role authenticated; select * from oyun.ozel;", "set role authenticated; select * from oyun.mesajlar;"]:
    try:
        q(sql); raise AssertionError("erişilmemeliydi: " + sql)
    except SqlHata as e:
        assert "permission denied" in str(e), e
ok("Güvenlik: girişsiz erişim yok, özel mesaj ve sohbet tabloları doğrudan okunamıyor")

# günlük temizlik
q("update oyun.mesajlar set zaman = zaman - interval '40 days' where metin = 'Merhaba Türkiye!'")
saat("2026-10-10 00:01")
assert k("select count(*) from oyun.mesajlar where metin='Merhaba Türkiye!'") == "0"
ok("Günlük temizlik: 30 günden eski sohbet mesajları siliniyor")

print(f"\nTÜM SOSYAL/KABİNE KONTROLLERİ GEÇTİ ({len(TAMAM)})")
