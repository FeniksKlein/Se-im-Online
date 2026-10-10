"""Modül 55: dernekler — kuruluş, üyelik, yönetim, bağış, şube, açıklamalar, protesto."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
saat("2026-10-08 10:00")
def oyuncu(kad, il="İzmir", para=100000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para={para} where user_id='{u}'"); return u
bas, uye, yon, uzak, gbp = oyuncu("Baskan"), oyuncu("Uye"), oyuncu("Kurulcu"), oyuncu("Uzakli", "Van"), oyuncu("PartiGB")
rpc(gbp, "partiye_katil", 1); q(f"update oyun.partiler set gb='{gbp}' where id=1")
saat("2026-10-12 10:00"); q("update oyun.profiller set son_gorulme=now()+interval '30 days'"); q(f"update oyun.partiler set gb='{gbp}' where id=1")

# Kuruluş
harc = float(q("select oyun.dernek_harci()"))
d = rpc(bas, "dernek_kur", "Ege Doğa Derneği", "cevre", "Kıyıların korunması için çalışırız.")
did = d["id"]; assert d["rolum"] == "baskan" and d["merkez"] == "İzmir" and len(d["subeler"]) == 1
assert float(q(f"select para from oyun.cuzdan where user_id='{bas}'")) == 100000 - harc
hata_bekle(rpc, uye, "dernek_kur", "ege doğa derneği", "cevre", "", icerir="zaten var")
hata_bekle(rpc, bas, "dernek_kur", "İkinci Dernek", "genel", "", icerir="Zaten bir derneğin başkanı")
ok(f"Dernek kuruldu ({harc:.0f} ₺ harç), merkez şube İzmir; aynı ad ve ikinci başkanlık engellendi")

# Üyelik, yönetim, devretme kuralı
for u in (uye, yon, uzak): rpc(u, "dernek_katil", did)
hata_bekle(rpc, uye, "dernek_eylem", did, "basin", "Kıyılar talan ediliyor", "Kıyılarımız betonlaşmaya karşı korunmalı.", icerir="başkanı ya da yönetim")
rpc(bas, "dernek_yonetim_ata", did, "Kurulcu", True)
hata_bekle(rpc, bas, "dernek_ayril", did, icerir="devretmeli")
ok("Üyeler katıldı; sıradan üye açıklama yapamıyor; başkan devretmeden ayrılamıyor")

# Bağış ve şube
rpc(uye, "dernek_bagis", did, 5000)
assert float(q(f"select kasa from oyun.dernekler where id={did}")) == 5000
su = float(q(f"select oyun.dernek_sube_ucreti({IL('Van')}::smallint)"))
rpc(yon, "dernek_sube_ac", did, IL("Van"))
assert float(q(f"select kasa from oyun.dernekler where id={did}")) == 5000 - su
ok(f"Bağış kasaya girdi; yönetim üyesi Van şubesini {su:.0f} ₺ ile açtı")

# Açıklamalar ve hedefe bildirim
rpc(bas, "dernek_eylem", did, "basin", "Kıyılar talan ediliyor", "Kıyılarımız betonlaşmaya karşı korunmalı.", "genel", "Kıyı imarı")
rpc(yon, "dernek_eylem", did, "destek", "CYP'ye destek", "Çevre politikaları nedeniyle CYP'yi destekliyoruz.", "parti", "1")
hata_bekle(rpc, bas, "dernek_eylem", did, "destek", "Genel destek", "Bu bir destek açıklamasıdır.", "genel", None, icerir="partiye ya da bir oyuncuya")
rpc(bas, "dernek_eylem", did, "bildiri", "Oyuncuya çağrı", "Belediye başkanını göreve çağırıyoruz.", "oyuncu", "PartiGB")
assert q(f"select count(*) from oyun.bildirimler where user_id='{gbp}' and metin like 'Ege Doğa Derneği%'") == "2"
hata_bekle(rpc, bas, "dernek_eylem", did, "bildiri", "Dördüncü açıklama", "Günlük sınırı aşan açıklama.", "genel", None, icerir="en fazla 3")
assert "Ege Doğa Derneği destek açıkladı (Cumhuriyet Yolu Partisi)" in q("select string_agg(metin, '|') from oyun.olaylar where tur='dernek'")
ok("Basın açıklaması, destek ve bildiri yayımlandı; parti GB'sine ve oyuncuya bildirim; günlük sınır çalışıyor")

# Protesto
hata_bekle(rpc, bas, "dernek_eylem", did, "protesto", "Ankara eylemi", "Ankara'da toplanıyoruz.", "genel", None, IL("Ankara"), "2026-10-12 12:00+03", icerir="şube yok")
d = rpc(bas, "dernek_eylem", did, "protesto", "Kordon'da büyük eylem", "Kıyı imarına karşı Kordon'da buluşuyoruz.", "parti", "1", IL("İzmir"), "2026-10-12 11:00+03")
eid = [e for e in d["eylemler"] if e["tur"] == "protesto"][0]["id"]
hata_bekle(rpc, bas, "dernek_eylem", did, "protesto", "Van eylemi", "Van'da toplanıyoruz.", "genel", None, IL("Van"), "2026-10-12 15:00+03", icerir="aynı gün")
hata_bekle(rpc, uye, "dernek_protesto_katil", eid, icerir="henüz başlamadı")
saat("2026-10-12 11:01")
assert q(f"select count(*) from oyun.bildirimler where user_id='{uye}' and metin like '%protesto düzenliyor%'") == "1"
assert q(f"select count(*) from oyun.bildirimler where user_id='{uzak}' and metin like 'Derneğin%protestoda%'") == "1"
rpc(uye, "dernek_protesto_katil", eid); rpc(gbp, "dernek_protesto_katil", eid)
hata_bekle(rpc, uzak, "dernek_protesto_katil", eid, icerir="İzmir ilinde yaşayanlar")
a = rpc(uzak, "dernek_akis", 10); assert a["protestolar"][0]["canli"] and a["protestolar"][0]["katilim"] == 2
saat("2026-10-12 12:01")
assert "protestosu 2 kişiyle tamamlandı" in q("select metin from oyun.olaylar where tur='dernek' order by id desc limit 1")
ok("Protesto: şubesiz ilde ve aynı gün ikinci eylem engellendi; başlayınca bildirim; 2 İzmirli katıldı, Vanlı izledi; bitince Gündem haberi")

# Devret ve ayrıl; son üye ayrılınca kapanır
rpc(bas, "dernek_baskan_devret", did, "Kurulcu")
assert q(f"select kad from oyun.profiller where id=(select baskan from oyun.dernekler where id={did})") == "Kurulcu"
rpc(bas, "dernek_ayril", did)
ok("Başkanlık devredildi, eski başkan ayrıldı")
print("dernek: tamam")
