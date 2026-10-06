"""3. aşama: belediye projeleri, seçim bildirgesi, rozetler, yönetici paneli, push kuyruğu.
Çalıştır: ../kur_yerel.sh && python3 asama3.py"""
import json
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

baskan = oyuncu("Baskan", 35, 1)
kucuk = oyuncu("KucukBaskan", 69, 2)
vatandas = oyuncu("Vatandas", 35, 1)
admin = oyuncu("Gozcu", 6)
kotu = oyuncu("Trol", 34, 3)
q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('bel','{baskan}',35,1,'2026-10-02 12:00+03'),('bel','{kucuk}',69,2,'2026-10-02 12:00+03')")

# ---------------- BELEDİYE ----------------
hata_bekle(rpc, vatandas, "belediye_hizmet", "lokanta", True, icerir="il belediye başkanlarındadır")
assert rpc(vatandas, "belediye_paneli") is None
pan = rpc(baskan, "belediye_paneli")
taban = 0.02 + 0.004 * 28
assert pan["il_ad"] == "İzmir" and abs(pan["gelir"] - taban * 1.2) < 0.001 and abs(pan["kasa"] - 5 * taban) < 0.001
assert len(pan["hizmetler"]) == 4 and len(pan["yatirimlar"]) == 4 and len(pan["kurallar"]) == 2 and pan["kent_vergisi"] == 2
hata_bekle(rpc, baskan, "belediye_yatirim", "rayli", icerir="yeterli para")
pan = rpc(baskan, "belediye_hizmet", "lokanta", True)
lok = next(x for x in pan["hizmetler"] if x["kod"] == "lokanta")
assert lok["acik"] and abs(lok["gider"] - 0.12 * taban) < 0.0001 and abs(pan["gider"] - lok["gider"]) < 0.0001
hata_bekle(rpc, baskan, "belediye_hizmet", "lokanta", True, icerir="zaten açık")
saat("2026-10-06 00:05")    # 4 gece: gelir girer, lokanta gideri düşer
pan = rpc(baskan, "belediye_paneli")
assert abs(pan["kasa"] - (5 * taban + 4 * (taban * 1.2 - 0.12 * taban))) < 0.01, pan["kasa"]
pk = rpc(kucuk, "belediye_paneli")
assert abs(pk["gelir"] - 0.024 * 1.2) < 0.001
rpc(kucuk, "belediye_hizmet", "istihdam", True)
d = rpc(vatandas, "il_detay", 69)
assert d["projeler"][0]["ad"] == "Belediye istihdam ofisi" and d["hizmetler"][0]["kaynak"] == "Belediye istihdam ofisi"
ok("Belediye: gelir il büyüklüğü, gelişmişlik ve kent vergisine göre; hizmetlerin günlük gideri kasadan düşüyor; yetki; il detayında görünüyor")

# ---------------- VAAT ----------------
q("update oyun.profiller set parti_at='2026-10-01 00:00+03'")
rpc(vatandas, "aday_ol", "bel_on")
bo = int(k("select id from oyun.secimler where tur='bel_on' and donem='2026-10'"))
hata_bekle(rpc, baskan, "vaat_yaz", bo, "Vaat", icerir="adaylığın yok")
hata_bekle(rpc, vatandas, "vaat_yaz", bo, "x" * 281, icerir="280")
rpc(vatandas, "vaat_yaz", bo, "Her mahalleye kreş, ücretsiz toplu taşıma!")
saat("2026-10-08 12:00")
sec = rpc(baskan, "secim_detay", bo)["secenekler"]
assert sec[0]["vaat"] == "Her mahalleye kreş, ücretsiz toplu taşıma!"
saat("2026-10-08 18:01")
bel = int(k("select id from oyun.secimler where tur='bel' and donem='2026-10'"))
assert k(f"select vaat from oyun.adaylar where secim_id={bel}") == "Her mahalleye kreş, ücretsiz toplu taşıma!"
rpc(vatandas, "vaat_yaz", bel, "Güncel bildirge: 7/24 açık belediye")
assert k(f"select vaat from oyun.adaylar where secim_id={bel}") == "Güncel bildirge: 7/24 açık belediye"
saat("2026-10-10 17:00")
hata_bekle(rpc, vatandas, "vaat_yaz", bel, "Geç kalmış vaat", icerir="Oylama bittikten")
ok("Seçim bildirgesi: yalnız aday yazar, 280 karakter, ön seçimden asıl seçime taşınır, oylama bitince kilitlenir, pusulada görünür")

# ---------------- ROZETLER ----------------
r = {x["ad"] for x in rpc(vatandas, "oyuncu_kart", "Baskan")["rozetler"]}
assert "Belediye Başkanı" in r
r = {x["ad"] for x in rpc(baskan, "oyuncu_kart", "Vatandas")["rozetler"]}
assert r == set(), r
ok("Rozetler: görev geçmişi ve etkinliğe göre hesaplanıyor")

# ---------------- YÖNETİCİ ----------------
hata_bekle(rpc, vatandas, "admin_ozet", icerir="yöneticileri")
q(f"update oyun.profiller set yonetici=true where id='{admin}'")
assert rpc(admin, "durum")["profil"]["yonetici"] is True
saat("2026-10-11 10:00:00"); rpc(kotu, "sohbet_yaz", "genel", "Hepiniz aptalsınız")
mid = int(k("select id from oyun.mesajlar where metin='Hepiniz aptalsınız'"))
rpc(vatandas, "sikayet_et", "mesaj", mid, None, "hakaret")
rpc(baskan, "sikayet_et", "mesaj", mid, None, "hakaret")
oz = rpc(admin, "admin_ozet")
assert oz["sikayet"] == 1 and oz["oyuncu"] == 5
sk = rpc(admin, "admin_sikayetler", "yeni")
assert sk[0]["icerik"] == "Hepiniz aptalsınız" and sk[0]["sayi"] == 2 and sk[0]["hedef"] == "Trol"
sk = rpc(admin, "admin_sikayet_karar", "mesaj", mid, "Trol", "gizle_sustur1")
assert sk == [] and k(f"select gizli from oyun.mesajlar where id={mid}") == "t"
hata_bekle(rpc, kotu, "sohbet_yaz", "genel", "Neden?", icerir="mesaj gönderemez")
assert "Topluluk kurallarını" in k(f"select string_agg(metin,'|') from oyun.bildirimler where user_id='{kotu}'")
o = rpc(admin, "admin_oyuncu", "Trol")
assert o["eposta"] == "Trol@t.com" and o["susturma_bitis"] is not None and o["son_mesajlar"][0]["gizli"] is True
rpc(admin, "admin_islem", "Trol", "susturma_kaldir")
o = rpc(admin, "admin_islem", "Baskan", "kapat")
assert o["yasakli"] is True and k(f"select count(*) from oyun.makamlar where user_id='{baskan}' and bit is null") == "0"
hata_bekle(rpc, baskan, "durum", icerir="kapatıldı")
hata_bekle(rpc, baskan, "sohbet_oku", "genel", icerir="kapatıldı")
rpc(admin, "admin_islem", "Baskan", "ac")
assert rpc(baskan, "durum")["profil"]["kad"] == "Baskan"
hata_bekle(rpc, admin, "admin_islem", "Gozcu", "kapat", icerir="Kendi")
r = rpc(admin, "admin_duyuru", "Bakım çalışması: bu gece 03:00-03:30 arası.")
assert any(x.get("unvan") == "Oyun Yönetimi" for x in rpc(vatandas, "bildirim_kutusu", 20))
rpc(admin, "admin_ayar", 1)
assert k("select min_hesap_gun from oyun.ayarlar") == "1"
q("update oyun.ayarlar set min_hesap_gun=0")
ok("Yönetici: özet, şikâyet listesi ve karar (gizle+sustur), oyuncu kartı (e-posta), hesap kapatma/açma, duyuru, ayar; yetkisize kapalı")

# ---------------- PUSH ----------------
assert k("select count(*) from oyun.push_kuyruk") == "0"      # push kapalıyken kuyruk dolmaz
q("update oyun.ayarlar set push_aktif=true")
hata_bekle(rpc, vatandas, "cihaz_kaydet", "kisa", "ios", icerir="Geçersiz")
rpc(vatandas, "cihaz_kaydet", "tok_vatandas_" + "x" * 30, "ios")
rpc(kucuk, "cihaz_kaydet", "tok_kucuk_" + "y" * 30, "android")
for i in range(6): rpc(kotu, "cihaz_kaydet", f"tok_trol_{i}_" + "z" * 30, "ios")
assert k(f"select count(*) from oyun.cihazlar where user_id='{kotu}'") == "5"
saat("2026-10-11 11:00:00")
q(f"select oyun.bildir('{vatandas}', 'Test kişisel bildirim')")
q(f"select oyun.bildir('{admin}', 'Cihazı yok')")                    # cihazı yok → kuyruğa girmez
rpc(kucuk, "ozel_yaz", "Vatandas", "Merhaba, ittifak?")
rpc(vatandas, "bildirim_ayar_kaydet", '{"ozel": false}')
saat("2026-10-11 11:00:05")
rpc(kucuk, "ozel_yaz", "Vatandas", "Cevap ver lütfen")                 # tercih kapalı → push yok
kuy = json.loads(k("select json_agg(json_build_object('u',user_id,'b',baslik,'g',govde,'konu',konu,'kosul',kosul) order by id) from oyun.push_kuyruk"))
assert len(kuy) == 2 and kuy[0]["g"] == "Test kişisel bildirim" and kuy[1]["b"] == "KucukBaskan", kuy
assert rpc(vatandas, "durum")["profil"]["bildirim_ayar"]["ozel"] is False
# propaganda konuları
q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('bel','{kucuk}',69,2,'2026-10-11 00:00+03') on conflict do nothing")
rpc(kucuk, "yayin_gonder", "belediye", "Bayburt'a yeni park!", None)
q(f"update oyun.partiler set gb='{kucuk}' where id=2")
rpc(kucuk, "yayin_gonder", "parti", "Parti genelgesi", None)
kon = json.loads(k("select json_agg(coalesce(konu, kosul) order by id) from oyun.push_kuyruk where user_id is null"))
assert kon[:3] == ["duyuru", "p_il_69", "p_parti_2"] or kon[-2:] == ["p_il_69", "p_parti_2"], kon
ok("Push kuyruğu: kapalıyken boş; kişisel ve özel mesaj kişiye, tercih kapatılınca gönderilmez; propaganda il/parti konusuna; cihaz sınırı 5")

# seçim hatırlatmaları
q("delete from oyun.push_kuyruk")
saat("2026-10-15 09:00")       # kurultay başvurusu açık
saat("2026-10-15 09:01")       # ikinci kez → tekrar göndermez
assert k("select count(*) from oyun.push_kuyruk where konu='s_tum' and baslik='Başvurular açıldı'") == "1"
rpc(vatandas, "aday_ol", "kurultay")
saat("2026-10-18 08:00:30")
assert k("select count(*) from oyun.push_kuyruk where konu='s_parti_1'") == "1"
saat("2026-10-18 18:01")
saat("2026-10-26 09:00")
saat("2026-11-01 08:00:30")
assert k("select count(*) from oyun.push_kuyruk where konu='s_tum' and baslik like 'Bugün seçim var%'") == "1"
saat("2026-11-01 18:01")
assert k("select count(*) from oyun.push_kuyruk where konu='s_tum' and baslik='Sonuçlar açıklandı'") == "1"
ok("Seçim hatırlatmaları: başvuru, sandık açıldı (genel/parti içi), sonuç — her biri bir kez, yalnız zamanında")

# servis fonksiyonları: yalnız service_role
for sql in ["set role authenticated; select public.push_al(10);", "set role anon; select public.push_bitti('{}');"]:
    try: q(sql); raise AssertionError(sql)
    except SqlHata as e: assert "permission denied" in str(e), e
al = qj("set role service_role; select public.push_al(100);")
kisisel = [x for x in al if x["tokenlar"] is not None]
assert all(isinstance(x["tokenlar"], list) for x in kisisel)
assert qj("set role service_role; select public.push_al(100);") == []          # alınanlar 2 dk tekrar verilmez
q("set role service_role; select public.push_bitti('" + json.dumps({"basarili": [x["id"] for x in al], "hatalar": {}, "gecersiz": ["tok_trol_5_" + "z" * 30]}) + "');")
assert k("select count(*) from oyun.push_kuyruk where gonderildi is null") == "0"
assert k("select count(*) from oyun.cihazlar where token like 'tok_trol_5_%'") == "0"
ok("Push servisi: yalnız service_role çağırır, kuyruk kilitlenerek alınır, sonuç işlenir, geçersiz cihazlar silinir")

print(f"\nTÜM 3. AŞAMA KONTROLLERİ GEÇTİ ({len(TAMAM)})")
