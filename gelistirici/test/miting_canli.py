"""Canlı miting meydanı (modül 46): kürsü konuşması, tepkiler, sloganlar, coşku ve Gündem haberi."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
saat("2026-10-12 10:00")
def oyuncu(kad, il):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il)); return u

aday = oyuncu("Hatip", "İzmir")
dinleyenler = [oyuncu(f"Izmirli{i}", "İzmir") for i in range(4)]
uzak = oyuncu("Ankarali", "Ankara")
sec = q("select id from oyun.secimler order by id limit 1")
mid = int(q(f"insert into oyun.mitingler(user_id,secim_id,il_id,baslik,bas,bit) values('{aday}',{sec},{IL('İzmir')},'Gündoğdu buluşması','2026-10-12 10:30+03','2026-10-12 11:30+03') returning id").split("\n")[0])

hata_bekle(rpc, aday, "miting_konus", mid, "Merhaba İzmir!", icerir="henüz başlamadı")
saat("2026-10-12 10:31")
assert q(f"select count(*) from oyun.bildirimler where user_id='{aday}' and metin like '%kürsüden konuş%'") == "1"
d = rpc(aday, "miting_konus", mid, "Merhaba İzmir! Emeğin hakkını vereceğiz.")
assert d["canli"] and len(d["konusmalar"]) == 1
hata_bekle(rpc, aday, "miting_konus", mid, "İkinci söz", icerir="15 saniye")
hata_bekle(rpc, dinleyenler[0], "miting_konus", mid, "Ben de konuşayım", icerir="yalnız mitingi düzenleyen")
ok("Kürsüde yalnız düzenleyen konuşuyor; başlamadan ve arka arkaya konuşamıyor")

k1 = d["konusmalar"][0]["id"]
hata_bekle(rpc, uzak, "miting_tepki", k1, "alkis", icerir="İzmir ilinde yaşamalısın")   # 52: yerli oyuncu tepkiyle kendiliğinden katılır
hata_bekle(rpc, uzak, "miting_katil", mid, icerir="Yalnızca bu ilde")
izle = rpc(uzak, "miting_meydan", mid)
assert not izle["katilabilir"] and izle["konusmalar"][0]["metin"].startswith("Merhaba")
for u in dinleyenler: rpc(u, "miting_katil", mid)
rpc(dinleyenler[0], "miting_tepki", k1, "tezahurat")
rpc(dinleyenler[1], "miting_tepki", k1, "alkis")
rpc(dinleyenler[2], "miting_tepki", k1, "alkis")
rpc(dinleyenler[3], "miting_tepki", k1, "yuh")
d = rpc(dinleyenler[3], "miting_tepki", k1, "islik")   # tepki değiştirilebilir
kk = d["konusmalar"][0]
assert (kk["tezahurat"], kk["alkis"], kk["islik"], kk["yuh"], kk["tepkim"]) == (1, 2, 1, 0, "islik"), kk
assert d["cosku"] == round(50 + 25 * (2 + 1 + 1 - 1) / 4), d["cosku"]
hata_bekle(rpc, aday, "miting_tepki", k1, "alkis", icerir="Kendi konuşmana")
ok(f"Başka ilden izlenebiliyor; katılanlar tepki verdi, tepki değiştirildi; coşku {d['cosku']}/100")

rpc(dinleyenler[0], "miting_slogan_at", mid, "Hak, hukuk, adalet!")
hata_bekle(rpc, dinleyenler[0], "miting_slogan_at", mid, "Bir daha!", icerir="20 saniye")
hata_bekle(rpc, dinleyenler[1], "miting_slogan_at", mid, "siktir git", icerir="uygunsuz")
saat("2026-10-12 10:33")
d = rpc(aday, "miting_konus", mid, "Bu meydan değişimin meydanıdır!")
for u in dinleyenler: rpc(u, "miting_tepki", d["konusmalar"][1]["id"], "tezahurat")
assert [s["metin"] for s in rpc(uzak, "miting_meydan", mid)["sloganlar"]] == ["Hak, hukuk, adalet!"]
ok("Slogan atıldı; hız sınırı ve küfür filtresi çalışıyor")

saat("2026-10-12 11:31")
hata_bekle(rpc, dinleyenler[0], "miting_slogan_at", mid, "Geç kaldım", icerir="canlı değil")
c = int(q(f"select cosku from oyun.mitingler where id={mid}"))
haber = q(f"select metin from oyun.olaylar where metin like 'Hatip İzmir mitingi%' order by zaman desc limit 1")
assert "4 kişi" in haber and f"coşku {c}/100" in haber and "Bu meydan değişimin meydanıdır!" in haber, haber
assert rpc(uzak, "mitingler")[0]["cosku"] == c
ok(f"Bitince Gündem haberi: {haber}")
print("miting_canli: tamam")
