"""Modül 52: GB yardımcılarına görev alanı; mitinge katılmadan tepki veren yerli oyuncu kendiliğinden katılır."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
saat("2026-10-12 10:00")
def oyuncu(kad, il):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il)); return u
gb, y1, uye = oyuncu("Baskan", "Ankara"), oyuncu("Yrd", "İzmir"), oyuncu("Uye", "Bursa")
for u in (gb, y1, uye): rpc(u, "partiye_katil", 1)
q(f"update oyun.partiler set gb='{gb}' where id=1")
q(f"insert into oyun.parti_gby(parti_id,sira,user_id) values (1,1,'{y1}')")
hata_bekle(rpc, y1, "gby_gorev_ver", "Yrd", "Teşkilattan Sorumlu", icerir="yalnız genel başkan")
hata_bekle(rpc, gb, "gby_gorev_ver", "Uye", "Teşkilattan Sorumlu", icerir="yardımcısı değil")
l = rpc(gb, "gby_gorev_ver", "Yrd", "Teşkilattan Sorumlu Genel Başkan Yardımcısı")
assert l[0]["gorev"] == "Teşkilattan Sorumlu", l
assert q(f"select oyun.unvan('{y1}')") == "CYP Teşkilattan Sorumlu Genel Başkan Yardımcısı", q(f"select oyun.unvan('{y1}')")
assert q(f"select count(*) from oyun.bildirimler where user_id='{y1}' and metin like '%Teşkilattan Sorumlu%'") == "1"
assert rpc(uye, "gby_gorevleri", 1)[0]["gorev"] == "Teşkilattan Sorumlu"
rpc(gb, "gby_gorev_ver", "Yrd", None)
assert q(f"select oyun.unvan('{y1}')") == "CYP Genel Başkan Yardımcısı"
ok("GB görev verdi/kaldırdı; unvan 'CYP Teşkilattan Sorumlu Genel Başkan Yardımcısı'; yalnız GB verebiliyor")

hatip, yerli, uzak = oyuncu("Hatip", "İzmir"), oyuncu("Yerli", "İzmir"), oyuncu("Uzak", "Van")
sec = q("select id from oyun.secimler order by id limit 1")
mid = int(q(f"insert into oyun.mitingler(user_id,secim_id,il_id,baslik,bas,bit) values('{hatip}',{sec},{IL('İzmir')},'Deneme','2026-10-12 10:05+03','2026-10-12 11:05+03') returning id").split("\n")[0])
saat("2026-10-12 10:06")
k = rpc(hatip, "miting_konus", mid, "Merhaba İzmir!")["konusmalar"][0]["id"]
d = rpc(yerli, "miting_tepki", k, "alkis")
assert d["katildim"] and d["konusmalar"][0]["alkis"] == 1
hata_bekle(rpc, uzak, "miting_tepki", k, "alkis", icerir="İzmir ilinde yaşamalısın")
ok("Katılmadan alkışlayan İzmirli kendiliğinden mitinge katıldı; Van'dan tepki açık bir mesajla reddedildi")
print("gby_gorev_tepki: tamam")
