"""Yönetici kontrol merkezi (modül 113): para/kıdem, engel, susturma, makam ver/al, parti/il/ad,
kasalar, veri düzenleyici + geri alma, uygulama ayarları, bakım modu, moderatör yetkileri ve
hata yalıtımlı oyun motoru."""
import json
from db import q, qj, rpc, kullanici_ekle, hata_bekle, SqlHata

def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
J = lambda o: json.dumps(o, ensure_ascii=False)
q("update oyun.ayarlar set test_simdi = null, push_aktif = false")

def oyuncu(kad, il):
    u = kullanici_ekle(f"{kad.lower()}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.profiller set olusturma = oyun.simdi() - interval '20 days', son_gorulme = oyun.simdi() where id='{u}'")
    return u

pa, pb = [int(x) for x in q("select id from oyun.partiler where not kapali order by id limit 2").split("\n")]
sahip = oyuncu("Sahip", "Ankara"); q(f"update oyun.profiller set yonetici = true where id='{sahip}'")
a = oyuncu("OyuncuA", "İzmir"); b = oyuncu("OyuncuB", "İzmir"); c = oyuncu("OyuncuC", "Ankara")
mod = oyuncu("Moddy", "Bursa")
q(f"update oyun.profiller set parti_id={pa} where id in ('{a}','{b}'); update oyun.profiller set parti_id={pb} where id='{c}'")
q(f"insert into oyun.moderatorler(user_id, yetkiler, zaman) values ('{mod}', '{{para,oyuncu_ara}}', now())")
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))

# ---- 1) Yetki kapısı
hata_bekle(rpc, a, "yk_ozet", icerir="yalnızca oyun yöneticileri")
o = rpc(sahip, "yk_ozet"); assert o["oyuncu"] >= 5 and o["yonetici"] is True, o
hata_bekle(rpc, mod, "yk_tablolar", icerir="yalnızca oyunun yöneticisi")
ok("Yönetici özeti açılıyor; oyuncu ve moderatör sahibe özel ekranlara giremiyor")

# ---- 2) Oyuncu listesi ve kartı
l = rpc(sahip, "yk_oyuncular", "Oyuncu", "hepsi", "ad", 10, 0)
assert l["toplam"] == 3 and [x["kad"] for x in l["liste"]] == ["OyuncuA", "OyuncuB", "OyuncuC"], l
k = rpc(sahip, "yk_oyuncu", "oyuncua"); assert k["kad"] == "OyuncuA" and k["parti"]["id"] == pa and k["eposta"] == "oyuncua@t.com", k
ok("Oyuncu arama/sıralama ve oyuncu kartı (e-posta yalnız sahibe)")

# ---- 3) Para ve kıdem
p0 = para(a); r = rpc(sahip, "yk_para", "oyuncu", "OyuncuA", 5000, "Turnuva ödülü", True)
assert r["kisi"] == 1 and para(a) == p0 + 5000
assert q(f"select count(*) from oyun.hesap_hareket where user_id='{a}' and tur='yonetici' and tutar=5000") == "1"
assert q(f"select count(*) from oyun.bildirimler where user_id='{a}' and metin like 'Oyun yönetimi cüzdanına 5.000 ₺ yükledi.%'") == "1"
r = rpc(sahip, "yk_para", "oyuncu", "OyuncuA", -999999999, "Düzeltme", False); assert para(a) == 0 and r["toplam"] == -(p0 + 5000), r
r = rpc(sahip, "yk_para", "parti", str(pa), 100, None, False); assert r["kisi"] == 2, r
r = rpc(sahip, "yk_para", "il", str(IL("Ankara")), 7, None, False); assert r["kisi"] == 2, r   # Sahip + OyuncuC
n_herkes = int(q("select count(*) from oyun.profiller where not yasakli"))
r = rpc(sahip, "yk_para", "herkes", None, 1, None, False); assert r["kisi"] == n_herkes, r
k0 = float(q(f"select kidem from oyun.cuzdan where user_id='{b}'")); rpc(sahip, "yk_kidem", "oyuncu", "OyuncuB", 12.5, "Etkinlik")
assert float(q(f"select kidem from oyun.cuzdan where user_id='{b}'")) == k0 + 12.5
hata_bekle(rpc, sahip, "yk_para", "oyuncu", "OyuncuA", 0, None, True, icerir="sıfır olamaz")
ok("Para ekleme/çıkarma (cüzdan kadar), il/parti/herkes hedefleri, kıdem, bildirim ve hesap hareketi")

# ---- 4) Moderatör yetkileri
rpc(mod, "yk_para", "oyuncu", "OyuncuC", 50, None, False)
hata_bekle(rpc, mod, "yk_para", "oyuncu", "Sahip", 50, None, False, icerir="Yöneticiye ya da başka bir moderatöre")
hata_bekle(rpc, mod, "yk_engelle", "OyuncuC", 1, None, False, icerir="yetkin yok")
ok("Moderatör yalnız verilen yetkiyle işlem yapıyor, yöneticiye dokunamıyor")

# ---- 5) Süreli engel
q("update oyun.ayarlar set test_simdi = '2026-11-03 10:00+03'")
k = rpc(sahip, "yk_engelle", "OyuncuB", 1, "Hakaret", False); assert k["yasakli"] and k["engel_bitis"], k
e = hata_bekle(rpc, b, "durum", icerir="tarihine kadar oyun yönetimi tarafından engellendi")
assert "Hakaret" in e and "04.11.2026 10:00" in e, e
hata_bekle(rpc, b, "hayat", icerir="engellendi")
q("update oyun.ayarlar set test_simdi = '2026-11-04 10:01+03'")
d = rpc(b, "durum"); assert d["profil"]["kad"] == "OyuncuB"
assert q(f"select yasakli::text || coalesce(engel_bitis::text,'-') from oyun.profiller where id='{b}'") == "false-"
rpc(sahip, "yk_engelle", "OyuncuB", 0.5, None, False)
q("update oyun.ayarlar set test_simdi = '2026-11-04 23:00+03'"); q("select oyun.tick()")
assert q(f"select yasakli from oyun.profiller where id='{b}'") == "f"
ok("Süreli engel: açıklamalı mesaj, süre dolunca girişte ve motorda kendiliğinden kalkıyor")

# ---- 6) Makam ver / al
rpc(sahip, "yk_makam_ver", "OyuncuA", "bakan", None, "maliye", None, True)
assert q(f"select count(*) from oyun.makamlar where user_id='{a}' and tur='bakan' and bakanlik='maliye' and bit is null") == "1"
rpc(sahip, "yk_makam_ver", "OyuncuC", "bakan", None, "maliye", None, True)
assert q(f"select count(*) from oyun.makamlar where user_id='{a}' and tur='bakan' and bit is null") == "0"
assert q(f"select count(*) from oyun.makamlar where user_id='{c}' and tur='bakan' and bakanlik='maliye' and bit is null") == "1"
rpc(sahip, "yk_makam_ver", "OyuncuA", "bel", IL("İzmir"), None, None, True)
rpc(sahip, "yk_makam_ver", "OyuncuA", "mv", IL("İzmir"), None, None, True)   # vekil olunca belediye başkanlığı düşer (tek görev)
roller = q(f"select string_agg(tur, ',' order by tur) from oyun.makamlar where user_id='{a}' and bit is null")
assert roller == "mv", roller
hata_bekle(rpc, sahip, "yk_makam_ver", "OyuncuA", "mv", IL("İzmir"), None, None, True, icerir="zaten bu görevde")
q(f"update oyun.iller set mv = (select count(*) from oyun.makamlar where tur='mv' and bit is null and il_id={IL('İzmir')}) where id={IL('İzmir')}")
hata_bekle(rpc, sahip, "yk_makam_ver", "OyuncuB", "mv", IL("İzmir"), None, None, True, icerir="milletvekilliği dolu")
rpc(sahip, "yk_makam_ver", "OyuncuB", "gb", None, None, None, True)
assert q(f"select gb from oyun.partiler where id={pa}") == b
rpc(sahip, "yk_makam_ver", "OyuncuA", "gby", None, None, 2, True)
assert q(f"select user_id from oyun.parti_gby where parti_id={pa} and sira=2") == a
rpc(sahip, "yk_makam_ver", "OyuncuC", "cb", None, None, None, True)
assert q(f"select count(*) from oyun.makamlar where tur='cb' and bit is null and user_id='{c}'") == "1"
mid = int(q(f"select id from oyun.makamlar where user_id='{a}' and tur='mv' and bit is null"))
k = rpc(sahip, "yk_makam_al", mid, "Deneme"); assert all(m["tur"] != "mv" for m in k["makamlar"]), k
rpc(sahip, "yk_parti_gorev_al", "OyuncuA", "gby"); assert q(f"select count(*) from oyun.parti_gby where user_id='{a}'") == "0"
mk = rpc(sahip, "yk_makamlar"); assert any(x["kad"] == "OyuncuC" and x["tur"] == "cb" for x in mk["makamlar"]) and len(mk["iller"]) == 81
ok("Makam ver (bakan koltuğu devri, tek görev kuralı, vekil kotası, GB/GBY, CB) ve görevden alma")

# ---- 7) Parti, il, ad
rpc(sahip, "yk_parti_degistir", "OyuncuA", pb); assert q(f"select parti_id from oyun.profiller where id='{a}'") == str(pb)
rpc(sahip, "yk_parti_degistir", "OyuncuA", None); assert q(f"select coalesce(parti_id::text,'yok') from oyun.profiller where id='{a}'") == "yok"
rpc(sahip, "yk_il_degistir", "OyuncuA", IL("Bursa")); assert q(f"select il_id from oyun.profiller where id='{a}'") == str(IL("Bursa"))
rpc(sahip, "yk_ad_degistir", "OyuncuA", "YeniAd"); assert q(f"select kad from oyun.profiller where id='{a}'") == "YeniAd"
hata_bekle(rpc, sahip, "yk_ad_degistir", "YeniAd", "OyuncuB", icerir="kullanımda")
ok("Parti değiştirme/bağımsız yapma, il taşıma, ad değiştirme")

# ---- 8) Susturma, adaylık yasağı, kalıcı engel
rpc(sahip, "yk_sustur", "OyuncuC", 2, "Spam"); assert q(f"select susturma_bitis > oyun.simdi() from oyun.profiller where id='{c}'") == "t"
rpc(sahip, "yk_sustur", "OyuncuC", 0, None); assert q(f"select susturma_bitis is null from oyun.profiller where id='{c}'") == "t"
rpc(sahip, "yk_adaylik_yasagi", "OyuncuC", 10, None); assert q(f"select adaylik_yasagi_bitis > oyun.simdi() from oyun.profiller where id='{c}'") == "t"
rpc(sahip, "yk_engelle", "OyuncuC", None, "Hile", True)
assert q(f"select count(*) from oyun.makamlar where user_id='{c}' and bit is null") == "0"
hata_bekle(rpc, c, "durum", icerir="Hesabın kural ihlali nedeniyle kapatıldı. Gerekçe: Hile.")
rpc(sahip, "yk_engel_kaldir", "OyuncuC"); rpc(c, "durum")
hata_bekle(rpc, sahip, "yk_engelle", "Sahip", None, None, False, icerir="Kendi hesabını")
ok("Susturma, aday olma yasağı, kalıcı engel (görevler düşer) ve engel kaldırma")

# ---- 9) Kasalar
h0 = float(q("select hazine from oyun.ulke where id=1")); rpc(sahip, "yk_kasa", "hazine", None, 25, "Destek")
assert abs(float(q("select hazine from oyun.ulke where id=1")) - (h0 + 25)) < 1e-6
k0 = float(q(f"select kasa from oyun.partiler where id={pb}")); rpc(sahip, "yk_kasa", "parti", str(pb), -10**12, None)
assert float(q(f"select kasa from oyun.partiler where id={pb}")) == 0
ok("Hazine ve parti kasası (sıfırın altına inmiyor)")

# ---- 10) Veri düzenleyici + geri alma
t = rpc(sahip, "yk_tablolar"); assert any(x["ad"] == "oyun.profiller" for x in t)
v = rpc(sahip, "yk_tablo", "oyun.profiller", "OyuncuB", None, None, None, True, 10, 0)
assert v["toplam"] == 1 and v["pk"] == ["id"] and v["satirlar"][0]["kad"] == "OyuncuB", v
v = rpc(sahip, "yk_tablo", "profiller", None, "kad", "Oyuncu%", "kad", False, 10, 0); assert v["toplam"] == 2, v
s = rpc(sahip, "yk_satir_kaydet", "oyun.cuzdan", J({"user_id": b}), J({"para": "123456", "kidem": 77}), "deneme")
assert s["para"] == 123456 and s["kidem"] == 77
did = int(q("select max(id) from oyun.yk_degisiklik"))
rpc(sahip, "yk_geri_al", did); assert float(q(f"select kidem from oyun.cuzdan where user_id='{b}'")) != 77
hata_bekle(rpc, sahip, "yk_geri_al", did, icerir="zaten geri alındı")
yeni = rpc(sahip, "yk_satir_kaydet", "oyun.bildirimler", None, J({"user_id": b, "metin": "Elle eklendi", "zaman": "2026-11-04T10:00:00+03:00"}), None)
assert q(f"select count(*) from oyun.bildirimler where id={yeni['id']}") == "1"
rpc(sahip, "yk_geri_al", int(q("select max(id) from oyun.yk_degisiklik where islem='ekle'")))
assert q(f"select count(*) from oyun.bildirimler where id={yeni['id']}") == "0"
bid = int(q(f"select max(id) from oyun.bildirimler where user_id='{b}'"))
rpc(sahip, "yk_satir_sil", "oyun.bildirimler", J({"id": bid})); assert q(f"select count(*) from oyun.bildirimler where id={bid}") == "0"
rpc(sahip, "yk_geri_al", int(q("select max(id) from oyun.yk_degisiklik where islem='sil'")))
assert q(f"select count(*) from oyun.bildirimler where id={bid}") == "1"
q("create table if not exists oyun.zz_kimlik(id bigint generated always as identity primary key, ad text)")
z = rpc(sahip, "yk_satir_kaydet", "oyun.zz_kimlik", None, J({"ad": "x"}), None)
rpc(sahip, "yk_satir_sil", "oyun.zz_kimlik", J({"id": z["id"]}))
rpc(sahip, "yk_geri_al", int(q("select max(id) from oyun.yk_degisiklik where islem='sil'")))
assert q(f"select ad from oyun.zz_kimlik where id={z['id']}") == "x"
q("begin; select set_config('oyun.tablo_kaldir', 'evet', true); drop table oyun.zz_kimlik; commit;")
hata_bekle(rpc, sahip, "yk_tablo", "auth.users", None, None, None, None, True, 10, 0, icerir="Yalnız oyun tabloları")
dg = rpc(sahip, "yk_degisiklikler", 20, None); assert len(dg) >= 6
ok("Veri düzenleyici: arama/süzme, güncelle/ekle/sil, kimlik sütunlu tablo ve her işlemin geri alınması")

# ---- 11) Uygulama ayarları ve bakım modu
assert q("select public.uygulama_ayar() ->> 'iletisim'") == "feniksklein@gmail.com"     # giriş yapmadan
rpc(sahip, "yk_uygulama_ayar_kaydet", J({"bakim": True, "bakim_mesaj": "Sunucu taşınıyor.", "duyuru_bandi": "Hafta sonu çift maaş!"}))
hata_bekle(rpc, b, "durum", icerir="Oyun bakımda. Sunucu taşınıyor.")
hata_bekle(rpc, b, "hayat", icerir="Oyun bakımda.")
rpc(sahip, "durum"); rpc(sahip, "yk_ozet")
rpc(sahip, "yk_uygulama_ayar_kaydet", J({"bakim": False})); rpc(b, "durum")
assert q("select public.uygulama_ayar() ->> 'duyuru_bandi'") == "Hafta sonu çift maaş!"
ok("Uygulama ayarları (giriş öncesi okunur), bakım modunda yalnız yönetici girer")

# ---- 12) Hata yalıtımlı motor
q("alter function oyun.miting_tick(timestamptz) rename to miting_tick_asil")
q("create function oyun.miting_tick(t timestamptz) returns void language plpgsql as $$ begin raise exception 'deneme hatasi'; end $$")
try:
    q("update oyun.ayarlar set test_simdi = '2026-11-05 10:00+03'")
    rpc(sahip, "yk_engelle", "OyuncuB", 0.01, None, False)
    q("update oyun.ayarlar set test_simdi = '2026-11-05 10:30+03'")
    q("select oyun.tick()"); q("select oyun.tick()")
    assert q(f"select yasakli from oyun.profiller where id='{b}'") == "f", "motorun diğer adımları çalışmalı"
    assert q("select sayi from oyun.tick_hata where adim='miting_tick' order by id desc limit 1") == "2"
    sh = rpc(sahip, "yk_sistem_hatalari", 10); assert any(x["adim"] == "miting_tick" and "deneme hatasi" in x["hata"] for x in sh["motor"]), sh
finally:
    q("drop function oyun.miting_tick(timestamptz)"); q("alter function oyun.miting_tick_asil(timestamptz) rename to miting_tick")
r = rpc(sahip, "yk_motor_calistir"); assert "islenen" in r
assert isinstance(rpc(sahip, "yk_secimler"), list)
ok("Motorun bir adımı hata verse de diğerleri işliyor; hata kaydı ve 'motoru çalıştır'")

# ---- 13) Günlük
lg = rpc(sahip, "admin_mod_kayit", 100)
islemler = {x["islem"] for x in lg}
for beklenen in ("yk_para_ekle", "yk_para_al", "yk_engel_sureli", "yk_makam_ver", "yk_makam_al", "yk_veri_guncelle", "yk_geri_al"):
    assert beklenen in islemler, (beklenen, islemler)
ok("Her yönetici işlemi moderasyon günlüğünde")
print("yonetici_kontrol: hepsi geçti")
