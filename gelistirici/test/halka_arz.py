"""Modül 62: şirket halka arzı ve yatırım hesaplayıcısı."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
pay = lambda sid, u: float(q(f"select coalesce((select pay from oyun.sirket_ortaklari where sirket_id={sid} and user_id='{u}'),0)"))

saat("2026-10-08 10:00")
def oyuncu(kad, p=5000000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL("İzmir"))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
sahip, y1, y2, y3 = oyuncu("Uygar"), oyuncu("Yatirimci1"), oyuncu("Yatirimci2"), oyuncu("Yatirimci3")
q("update oyun.ulke set asgari=28075 where id=1")

# Şirket: 950.000 ₺ teknoloji → haftalık ortalama net 112.050 ₺ (oyuncunun bildirdiği değer)
sid = rpc(sahip, "sirket_kur", "Uygar Holding", "teknoloji", 950000)["id"]
d = rpc(sahip, "halka_arz_durum", sid)
assert float(d["ort_net"]) == 112050, d["ort_net"]
# Hesaplayıcı: 1.950.000 ₺ yatırım gelirse
h = rpc(sahip, "halka_arz_hesapla", sid, 1950000, None)
assert float(h["yeni_sermaye"]) == 2900000 and float(h["ort_net_sonra"]) == 399675, h
assert float(h["ort_net_artis"]) == 399675 - 112050
ok(f"Hesaplayıcı: 950.000 ₺ → 112.050 ₺/hafta; +1.950.000 ₺ yatırımla 2.900.000 ₺ → 399.675 ₺/hafta "
   f"(önerilen değer {float(h['deger']):,.0f} ₺, yatırımcıya %{h['yatirimci_payi']}, sahibe %{h['benim_payim_sonra']})")

# Sınırlar
hata_bekle(rpc, y1, "halka_arz_baslat", sid, 100000, 1000000, None, 72, icerir="en az %50")
hata_bekle(rpc, sahip, "halka_arz_baslat", sid, 1950000, 900000, None, 72, icerir="Şirket değeri")
hata_bekle(rpc, sahip, "halka_arz_baslat", sid, 1950000, 1000000, None, 72, icerir="en fazla %49")
hata_bekle(rpc, sahip, "halka_arz_baslat", sid, 1950000, 3000000, None, 12, icerir="24, 48 ya da 72")
ok("Yetki, değer aralığı, %49 sınırı ve süre kontrolleri çalışıyor")

# Arzı başlat: değer 3.000.000, hedef 1.950.000 (yaklaşık %39,4), asgari 1.000.000, 72 saat
a = rpc(sahip, "halka_arz_baslat", sid, 1950000, 3000000, 1000000, 72)
aid = a["id"]; assert a["durum"] == "acik" and float(a["satilan_pay_hedef"]) == 39.39
hata_bekle(rpc, sahip, "halka_arz_baslat", sid, 100000, 3000000, None, 72, icerir="zaten açık")
hata_bekle(rpc, sahip, "halka_arz_talep", aid, 10000, icerir="Kendi başlattığın")
rpc(y1, "halka_arz_talep", aid, 1000000); rpc(y2, "halka_arz_talep", aid, 500000); rpc(y3, "halka_arz_talep", aid, 300000)
assert para(y1) == 4000000
rpc(y3, "halka_arz_talep_geri", aid); assert para(y3) == 5000000
hata_bekle(rpc, y3, "halka_arz_talep", aid, 500000, icerir="Kalan talep")
l = rpc(y2, "halka_arz_liste"); assert len(l["acik"]) == 1 and float(l["acik"][0]["talebim"]) == 500000
rpc(y3, "halka_arz_talep", aid, 450000)
ok("Talepler emanete alındı, geri alma iade etti, hedefi aşan talep engellendi")

# Hedef doldu → beklemeden tamamlanır
assert float(q(f"select toplanan from oyun.halka_arz where id={aid}")) == 1950000
assert q(f"select durum from oyun.halka_arz where id={aid}") == "tamam"
s = q(f"select sermaye||'|'||kasa||'|'||halka_acik from oyun.sirketler where id={sid}")
assert s.startswith("2900000|") and s.endswith("|true"), s
toplam = float(q(f"select sum(pay) from oyun.sirket_ortaklari where sirket_id={sid}"))
assert abs(toplam - 100) < 1e-9, toplam
assert abs(pay(sid, sahip) - 3000000 / 4950000 * 100) < 0.001 and abs(pay(sid, y1) - 1000000 / 4950000 * 100) < 0.001
assert float(rpc(sahip, "halka_arz_durum", sid)["ort_net"]) == 399675
ok(f"Arz tamamlandı: sermaye 2.900.000 ₺, paylar toplamı %100 (sahip %{pay(sid, sahip):.2f}, Y1 %{pay(sid, y1):.2f})")

# Haftalık kâr payı yeni ortaklara da gider
saat("2026-10-16 10:00")
q(f"update oyun.sirketler set sonraki_kazanc=now()-interval '1 minute' where id={sid}")
q("select setseed(0.4)"); rpc(y1, "sirket_liste")
assert q(f"select count(*) from oyun.hesap_hareket where user_id='{y1}' and aciklama like 'Sirket #{sid} haftalik%'") == "1"
ok("Haftalık faaliyet sonucu yeni ortağa da paylaştırıldı")

# İkinci şirket: asgari tutara ulaşmayan arz süre dolunca iade edilir
sid2 = rpc(y2, "sirket_kur", "Kuzey Ticaret", "ticaret", 200000)["id"]
a2 = rpc(y2, "halka_arz_baslat", sid2, 100000, 400000, 80000, 24)["id"]
rpc(y3, "halka_arz_talep", a2, 20000); once = para(y3)
saat("2026-10-17 11:00"); q("select oyun.halka_arz_tick()")
assert q(f"select durum from oyun.halka_arz where id={a2}") == "basarisiz" and para(y3) == once + 20000
assert pay(sid2, y3) == 0 and float(q(f"select sermaye from oyun.sirketler where id={sid2}")) == 200000
ok("Asgariye ulaşmayan arz süre dolunca başarısız sayıldı, para iade edildi")

# İptal
a3 = rpc(y2, "halka_arz_baslat", sid2, 50000, 400000, None, 48)["id"]
rpc(y1, "halka_arz_talep", a3, 30000); once = para(y1)
hata_bekle(rpc, y1, "halka_arz_iptal", a3, icerir="yalnız başlatan")
rpc(y2, "halka_arz_iptal", a3)
assert q(f"select durum from oyun.halka_arz where id={a3}") == "iptal" and para(y1) == once + 30000
ok("İptal edilen arzda talepler iade edildi; başkası iptal edemiyor")
print("halka_arz: tamam")
