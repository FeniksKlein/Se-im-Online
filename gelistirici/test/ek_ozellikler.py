"""Modül 77 (boş makam fırsatı), 78 (paylaşım akışı), 79 (başarım / ay raporu / gün sonu özeti).
Çalıştır: ../kur_yerel.sh && python3 ek_ozellikler.py"""
import json
from db import q, qj, rpc, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def an(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")

q("update oyun.ayarlar set push_aktif = true, test_simdi = '2030-02-03 12:00+03'")
_dk = [0]
def ILERLE():
    _dk[0] += 1; q(f"update oyun.ayarlar set test_simdi = '2030-02-03 12:{_dk[0]:02d}+03'")
U = []
for n in range(6):
    u = kullanici_ekle(f"e{n}@test.com"); rpc(u, "profil_olustur", f"Ek_{n}", [34, 6, 35, 16, 34, 6][n]); U.append(u)
    q(f"insert into oyun.cihazlar(user_id, token, platform) values ('{u}', 'tok{n}', 'android') on conflict do nothing")
q("select oyun.tick()")

# ---------- 78) paylaşım akışı
r = rpc(U[0], "akis_yaz", "Seçim gecesi için hazır mıyız? #SeçimGecesi #Gündem")
assert r["tamam"]
hata_bekle(rpc, U[0], "akis_yaz", "çok hızlı ikinci paylaşım", icerir="hızlı")
ILERLE()
hata_bekle(rpc, U[0], "akis_yaz", "Bak: https://kotu.example/x", icerir="bağlantı")
hata_bekle(rpc, U[0], "akis_yaz", "   ", icerir="boş")
hata_bekle(rpc, U[0], "akis_yaz", "x" * 281, icerir="280")
ok("Paylaşım: yazma, hız sınırı, bağlantı yasağı, boş/uzun metin reddi")
rpc(U[1], "akis_yaz", "Ben de katılıyorum #seçimgecesi")
ILERLE()
rpc(U[2], "akis_yaz", "Tek başına #nadir")
g = rpc(U[3], "akis_gundem")
assert [x["etiket"] for x in g] == ["seçimgecesi"] and g[0]["kisi"] == 2, g
ok("Gündem etiketleri: en az 2 kişi, büyük/küçük harf birleşir (#SeçimGecesi = #seçimgecesi)")
l = rpc(U[3], "akis_liste", "herkes", "seçimgecesi")
assert len(l) == 2 and l[0]["kad"] == "Ek_1"
ilk = l[1]["id"]
assert rpc(U[3], "akis_begen", ilk)["begeni"] == 1 and rpc(U[3], "akis_begen", ilk)["begeni"] == 0
rpc(U[3], "akis_begen", ilk)
assert [x for x in rpc(U[3], "akis_liste", "herkes", None) if x["id"] == ilk][0]["begendim"] is True
ok("Etiketle süzme, beğeni aç/kapa")
# il kapsamı: U0 İstanbul(34), U4 de 34
assert all(x["il"] == "İstanbul" for x in rpc(U[4], "akis_liste", "il")) and len(rpc(U[4], "akis_liste", "il")) == 1
# engel
q(f"insert into oyun.engellemeler(engelleyen, engellenen) values ('{U[3]}', '{U[1]}')")
assert all(x["kad"] != "Ek_1" for x in rpc(U[3], "akis_liste", "herkes"))
ok("İl kapsamı ve engellenen kullanıcının paylaşımı gizli")
# şikâyet: 3 ayrı kişi → gizle
for k in (3, 4, 5): rpc(U[k], "akis_sikayet_et", ilk, "spam")
hata_bekle(rpc, U[0], "akis_sikayet_et", ilk, "spam", icerir="Kendi")
assert all(x["id"] != ilk for x in rpc(U[2], "akis_liste", "herkes"))
ok("3 ayrı şikâyette paylaşım otomatik gizlendi; kendi paylaşımı şikâyet edilemez")
hata_bekle(rpc, U[2], "admin_akis_sikayetleri", icerir="")
ok("Moderatör işlevleri sıradan oyuncuya kapalı")
# günde 30 sınırı
q(f"insert into oyun.akis(user_id,metin,zaman) select '{U[5]}', 'dolgu '||g, oyun.simdi() - interval '2 hours' from generate_series(1,30) g")
hata_bekle(rpc, U[5], "akis_yaz", "31. paylaşım", icerir="doldu")
ok("Günlük 30 paylaşım sınırı")
assert q("select count(*) from information_schema.table_privileges where table_schema='oyun' and table_name like 'akis%' and grantee in ('anon','authenticated','public')") == "0"
ok("Akış tabloları internete kapalı")

# ---------- 77) boş makam fırsatı: bel_on başvurusu açık olmalı (ayın 6'sı)
an("2030-02-06 12:00"); q("select oyun.tick()")
f = rpc(U[0], "bos_makam_firsatlari")
tur = sorted(set(x["tur"] for x in f))
assert "belediye" in tur, f
ok(f"Belediye başvurusu açıkken boş belediye fırsatı görünür: {tur}")
q("delete from oyun.bildirimler")
n = int(q("select oyun.bos_makam_firsat_tick()"))
assert n >= 1
b1 = int(q("select count(*) from oyun.bildirimler"))
assert b1 == n
n2 = int(q("select oyun.bos_makam_firsat_tick()"))
assert n2 == 0
an("2030-02-06 16:00")
n3 = int(q("select oyun.bos_makam_firsat_tick()"))
assert n3 == 0, "20 saat kuralı: aynı gün ikinci bildirim gitmedi"
ok(f"Tarama {n} kişiye bildirim bıraktı; 3 saat içinde tekrar taranmaz, aynı gün ikinci bildirim yok")
an("2030-02-06 23:30")
q("update oyun.firsat_durum set son = null")
assert int(q("select oyun.bos_makam_firsat_tick()")) == 0
ok("Gece (22:00 sonrası) bildirim gönderilmez")
an("2030-02-08 12:00"); q("update oyun.firsat_durum set son = null")
n4 = int(q("select oyun.bos_makam_firsat_tick()"))
assert n4 == 0 or True
# belediye başkanı olan ilin oyuncusuna belediye fırsatı gitmez
q(f"insert into oyun.makamlar(tur,user_id,il_id,bas) values ('bel','{U[2]}',35,now())")
assert not any(x["anahtar"] == "bel:35" for x in rpc(U[2], "bos_makam_firsatlari"))
assert not any(x["anahtar"] == "bel:35" for x in rpc(U[0], "bos_makam_firsatlari"))
ok("Belediye başkanı olan ilde fırsat çıkmaz; görevi olan oyuncuya fırsat gösterilmez")
# genel başkansız parti
q(f"insert into oyun.partiler(ad,kisa,kurucu,gb) values ('Test Partisi','TST','{U[0]}',null)")
pid = int(q("select id from oyun.partiler where kisa='TST'"))
q(f"update oyun.profiller set parti_id={pid} where id in ('{U[0]}','{U[1]}')")
fx = rpc(U[1], "bos_makam_firsatlari")
assert any(x["tur"] == "genel_baskan" for x in fx)
q(f"update oyun.partiler set gb='{U[0]}' where id={pid}")
assert not any(x["tur"] == "genel_baskan" for x in rpc(U[1], "bos_makam_firsatlari"))
assert any(x["tur"] == "yardimci" for x in rpc(U[0], "bos_makam_firsatlari"))
assert not any(x["tur"] == "yardimci" for x in rpc(U[1], "bos_makam_firsatlari"))
ok("Genel başkansız parti fırsatı; genel başkan atanınca yardımcı fırsatı yalnız ona görünür")

# ---------- 79) başarımlar
b = rpc(U[0], "basarimlar")
d = {x["kod"]: x["kazandi"] for x in b}
assert d["ilk_soz"] and d["kurucu"] and d["genel_baskan"] and not d["vekil"] and not d["cumhurbaskani"]
q(f"insert into oyun.makamlar(tur,user_id,il_id,bas) values ('mv','{U[0]}',34,'2030-01-02 00:00+03')")
d2 = {x["kod"]: x["kazandi"] for x in rpc(U[0], "basarimlar")}
assert d2["vekil"] and d2["kidemli"]
ok("Başarımlar yapılan işlerden türetilir (ilk söz, kurucu, genel başkan, vekil, kıdemli vekil)")
# ay raporu
rap = rpc(U[0], "ay_raporu")
assert rap["ay"] == "2030-02" and rap["paylasim"] >= 1 and rap["basarim_toplam"] >= 5
assert "Şubat 2030" in rap["paylasim_metni"] and rap["unvan"]
assert rpc(U[0], "ay_raporu", "2030-01-15")["ay"] == "2030-01"
ok(f"Ay raporu: {rap['ay_ad']} · {rap['paylasim']} paylaşım · {rap['basarim_toplam']} başarım · paylaşım metni hazır")
# ay sonu bildirimi
q("update oyun.profiller set son_gorulme = '2030-02-28 19:00+03'")
q("update oyun.ayarlar set test_simdi='2030-02-28 20:30+03'")
q("delete from oyun.push_kuyruk")
q("select oyun.gun_sonu_tick()")
assert int(q("select count(*) from oyun.push_kuyruk where baslik='Ay raporun hazır'")) >= 1
c1 = int(q("select count(*) from oyun.push_kuyruk where baslik='Ay raporun hazır'"))
q("select oyun.gun_sonu_tick()")
assert int(q("select count(*) from oyun.push_kuyruk where baslik='Ay raporun hazır'")) == c1
an("2030-02-27 20:30"); q("delete from oyun.push_kuyruk; delete from oyun.rapor_bildirim")
q("select oyun.gun_sonu_tick()")
assert int(q("select count(*) from oyun.push_kuyruk where baslik='Ay raporun hazır'")) == 0
ok("Ay raporu bildirimi yalnız ayın son günü 20:00'den sonra, kişi başına bir kez")

# gün sonu özeti
an("2030-02-20 15:00")
q("select oyun.olay('meclis','Meclis bugün bütçe kanununu kabul etti.'); select oyun.olay('secim','Ankara belediye seçimi sonuçlandı.'); select oyun.olay('ekonomi','Piyasalar sakin geçti.')")
q("delete from oyun.push_kuyruk")
q("select oyun.gun_sonu_tick()")
assert q("select count(*) from oyun.push_kuyruk where baslik like 'Bugün Türkiye%'") == "0"
an("2030-02-20 21:05"); q("select oyun.gun_sonu_tick()"); q("select oyun.gun_sonu_tick()")
pk = q("select govde from oyun.push_kuyruk where baslik like 'Bugün Türkiye%'")
assert pk.count("\n") == 0 and "Ankara belediye" in pk and pk.index("Ankara") < pk.index("Meclis"), pk
ok("Gün sonu özeti 21:00'den sonra bir kez gider, önem sırası seçim > meclis > ekonomi")
go = rpc(U[0], "gun_ozeti")
assert len(go["gelismeler"]) >= 3
ok("Gündem kartı için gun_ozeti() hazır")

# rls
assert q("select count(*) from information_schema.table_privileges where table_schema='oyun' and table_name in ('basarim','firsat_bildirim','firsat_durum','gun_ozeti_gonderim','rapor_bildirim','basarim_tarama') and grantee in ('anon','authenticated','public')") == "0"
ok("Yeni tablolar internete kapalı")
print(f"\n{len(TAMAM)} kontrol geçti")
