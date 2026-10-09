"""Gazete: 5.000 karakterlik yazı her türde (propaganda dahil) yayımlanır; akışa 600 karakterlik özet gider."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle
saat("2026-10-12 10:00")
q("update oyun.ayarlar set gazete_gunluk_yayin = greatest(gazete_gunluk_yayin, 5) where id = 1")
u = kullanici_ekle("yazar@t.com"); rpc(u, "profil_olustur", "Yazar", int(q("select id from oyun.iller where ad='İzmir'")))
g = int(q(f"insert into oyun.oyuncu_gazeteleri(ad, sahip) values ('Ege Postası', '{u}') returning id").split("\n")[0])
metin = ("Bu ülkenin geleceği için çalışmak hepimizin borcudur. " * 100)[:4990]
for tur in ("haber", "kose", "propaganda"):
    rpc(u, "gazete_yayinla", g, tur, f"Uzun {tur} yazısı", metin, 1 if tur == "propaganda" else None)
assert q(f"select count(*) from oyun.gazete_yayinlari where gazete_id={g} and char_length(metin)={len(metin)}") == "3"
ozet = q("select metin from oyun.yayinlar where unvan like 'Oyuncu gazetesi%' order by id desc limit 1")
assert len(ozet) <= 600 and ozet.endswith("…") and "Uzun propaganda yazısı" in ozet, len(ozet)
hata_bekle(rpc, u, "gazete_yayinla", g, "kose", "Fazla uzun", "x" * 5001, None, icerir="20-5000")
print("  ✓ 4.990 karakterlik haber, köşe yazısı ve propaganda yayımlandı; akış özeti", len(ozet), "karakter")
print("gazete_uzun: tamam")
