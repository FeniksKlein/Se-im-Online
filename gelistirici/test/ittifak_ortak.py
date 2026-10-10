"""Modül 54: doğrudan ittifak teklifi ve ittifak içi ortak aday (CB + belediye)."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
saat("2026-10-12 10:00")
def oyuncu(kad, il="İzmir"):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il)); return u
A, B, C = 1, 2, 3
ga, gb, gc, uye = oyuncu("GbA"), oyuncu("GbB"), oyuncu("GbC"), oyuncu("UyeA")
for u, p in ((ga, A), (gb, B), (gc, C), (uye, A)): rpc(u, "partiye_katil", p)
for u, p in ((ga, A), (gb, B), (gc, C)): q(f"update oyun.partiler set gb='{u}' where id={p}")

# 1) Doğrudan teklif
hata_bekle(rpc, uye, "ittifak_teklif", B, "Anadolu Cephesi", icerir="genel başkanı")
hata_bekle(rpc, ga, "ittifak_teklif", B, None, icerir="ad ver")
d = rpc(ga, "ittifak_teklif", B, "Anadolu Cephesi")
assert q(f"select count(*) from oyun.ittifak_davetler where parti_id={B}") == "1"
assert q(f"select count(*) from oyun.bildirimler where user_id='{gb}' and metin like '%Anadolu Cephesi ittifakına davet%'") == "1"
iid = int(q(f"select ittifak_id from oyun.ittifak_uyeler where parti_id={A}"))
rpc(gb, "ittifak_davet_yanit", iid, True)
hata_bekle(rpc, ga, "ittifak_teklif", B, None, icerir="zaten aynı ittifak")
rpc(ga, "ittifak_teklif", C, None)          # ittifak var: ad gerekmez
rpc(gc, "ittifak_davet_yanit", iid, True)
assert q(f"select count(*) from oyun.ittifak_uyeler where ittifak_id={iid}") == "3"
ok("A tek adımda ittifak kurup B'ye teklif etti; B ve C kabul etti (3 parti)")

# 2a) Cumhurbaşkanlığı ortak adayı (aday belirleme dönemi 19-26)
saat("2026-10-20 10:00")
cb = int(q("select id from oyun.secimler where tur='cb' and donem='2026-11'"))
for u, p in ((ga, A), (gb, B), (gc, C)): q(f"insert into oyun.adaylar(secim_id,user_id,parti_id) values ({cb},'{u}',{p})")
m = rpc(gb, "ittifak_masasi", B)
assert m["cb_acik"] and len(m["cb_adaylar"]) == 3
m = rpc(gb, "ittifak_ortak_aday_teklif", "cb", None, A)      # B, A'nın adayını öneriyor → B'nin adayı hemen çekilir
assert q(f"select count(*) from oyun.adaylar where secim_id={cb} and parti_id={B}") == "0"
assert q(f"select destek_parti from oyun.cb_kararlar where parti_id={B}") == str(A)
o = m["oneriler"][0]; assert o["durum"] == "bekliyor" and len(o["bekleyenler"]) == 1, o
hata_bekle(rpc, ga, "ittifak_ortak_aday_yanit", o["id"], True, icerir="gerekmiyor")
hata_bekle(rpc, gc, "ittifak_ortak_aday_teklif", "cb", None, C, icerir="zaten bir ortak aday")
assert rpc(gc, "ittifak_masasi", C)["oneriler"][0]["yanit_bekliyor_benden"]
m = rpc(gc, "ittifak_ortak_aday_yanit", o["id"], True)
assert m["oneriler"][0]["durum"] == "kabul"
assert q(f"select count(*) from oyun.adaylar where secim_id={cb}") == "1"
assert "ortak adayını açıkladı: GbA (CYP)" in q("select metin from oyun.olaylar where metin like '%ortak adayını açıkladı%' order by zaman desc limit 1")
ok("CB: B önerdi (kendi adayı çekildi), C kabul etti → GbA ittifakın ortak cumhurbaşkanı adayı")

# 2b) Belediye ortak adayı (ön seçim sonucu → oy verme öncesi)
for gun in ("2026-10-26", "2026-11-01 23:00", "2026-11-05", "2026-11-09 10:00"):   # görev ihmaline düşmesinler
    q("update oyun.profiller set son_gorulme=now()+interval '60 days'"); saat(gun)
for u, p in ((ga, A), (gb, B), (gc, C)): q(f"update oyun.partiler set gb='{u}' where id={p}")
bel = int(q("select id from oyun.secimler where tur='bel' and donem='2026-11'"))
q("update oyun.secimler set durum='tamam' where tur='bel_on' and donem='2026-11'")
izmir = IL("İzmir")
for u, p in ((ga, A), (gb, B), (gc, C)): q(f"insert into oyun.adaylar(secim_id,user_id,parti_id,il_id) values ({bel},'{u}',{p},{izmir}) on conflict do nothing")
m = rpc(ga, "ittifak_ortak_aday_teklif", "bel", izmir, C)
o = [x for x in m["oneriler"] if x["tur"] == "bel"][0]
rpc(gb, "ittifak_ortak_aday_yanit", o["id"], False)               # B reddeder → kendi adayıyla devam
assert q(f"select count(*) from oyun.adaylar where secim_id={bel} and parti_id={B}") == "1"
assert q(f"select count(*) from oyun.adaylar where secim_id={bel} and parti_id={A}") == "0"
assert [x for x in rpc(ga, "ittifak_masasi", A)["oneriler"] if x["tur"] == "bel"][0]["durum"] == "bekliyor"
ok("Belediye: A İzmir'de C'nin adayını önerdi (A'nınki çekildi); B reddetti, kendi adayıyla yarışıyor")

# 3) Ortaklıktan ayrılan parti → bekleyen öneri düşer
q(f"delete from oyun.ittifak_uyeler where parti_id={C}")
assert q(f"select durum from oyun.ittifak_ortak_teklif where id={o['id']}") == "iptal"
ok("Adayı önerilen parti ittifaktan ayrılınca bekleyen öneri iptal oldu")
print("ittifak_ortak: tamam")
