"""Modül 93: Merkez Bankası, belediye tahvili, SPK, konkordato/iflas."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
para = lambda u: float(q(f"select para from oyun.cuzdan where user_id='{u}'"))
num = lambda s: float(q(s))

saat("2026-10-13 10:00")
def oyuncu(kad, p=5000000):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL("İzmir"))
    q(f"update oyun.cuzdan set para={p} where user_id='{u}'"); return u
def makam(u, tur, il=None, bakanlik=None):
    q(f"insert into oyun.makamlar(tur,user_id,il_id,bakanlik,kaynak,bas) values('{tur}','{u}',{il or 'null'},{repr(bakanlik) if bakanlik else 'null'},'atama',now())")

cb, ekonomist, baskan, y1, y2, maliye, patron = (oyuncu(k) for k in ["Reis", "Ekonomist", "Baskan", "Yatirimci1", "Yatirimci2", "Maliyeci", "Patron"])
makam(cb, "cb"); makam(baskan, "bel", IL("İzmir")); makam(maliye, "bakan", bakanlik="maliye")

# ---------------- Merkez Bankası
eski_faiz = num("select oyun.politika_faizi()")
hata_bekle(rpc, ekonomist, "tcmb_baskan_ata", "Ekonomist", icerir="yalnızca yürütme")
hata_bekle(rpc, cb, "tcmb_baskan_ata", "Baskan", icerir="tarafsız")
r = rpc(cb, "tcmb_baskan_ata", "Ekonomist"); assert r["durum"] == "bekliyor"
m = rpc(ekonomist, "merkez_bankasi"); assert m["bekleyen_teklifim"]["id"] == r["teklif_id"] and not m["ben_baskan"]
m = rpc(ekonomist, "tcmb_teklif_yanit", r["teklif_id"], True)
assert m["ben_baskan"] and m["baskan"]["kad"] == "Ekonomist" and not m["tcmb_karari"]
ok(f"Başkan atandı (teklif + kabul); karar yokken faiz eski formülle %{eski_faiz}")

hata_bekle(rpc, cb, "ppk_faiz_karari", 40, None, icerir="yalnızca Merkez Bankası")
hata_bekle(rpc, ekonomist, "ppk_faiz_karari", eski_faiz + 10.5, None, icerir="10 puan")
m = rpc(ekonomist, "ppk_faiz_karari", eski_faiz + 8, "Enflasyonla mücadele")
assert float(m["politika_faiz"]) == eski_faiz + 8 and m["tcmb_karari"] and len(m["kararlar"]) == 1
assert float(q("select oyun.banka_oranlar()->>'politika'")) == eski_faiz + 8
hata_bekle(rpc, ekonomist, "ppk_faiz_karari", eski_faiz, None, icerir="haftada bir")
ok(f"PPK kararı %{eski_faiz} → %{eski_faiz + 8}; banka oranları güncellendi, ikinci karar haftaya kaldı")

enf0 = num("select enflasyon from oyun.ulke where id=1"); p0 = para(ekonomist)
saat("2026-10-16 10:00"); q("select oyun.ekonomi2_tick()")
enf1 = num("select enflasyon from oyun.ulke where id=1")
assert para(ekonomist) > p0, "maaş ödenmedi"
ok(f"Reel faiz etkisi ve maaş: enflasyon (tick sonrası) {enf0:.2f} → {enf1:.2f}, maaş +{para(ekonomist) - p0:,.0f} ₺")

makam(ekonomist, "mv", IL("İzmir")); q("select oyun.ekonomi2_tick()")
assert q("select baskan is null from oyun.merkez_bankasi") == "t"
ok("Siyasi görev alan başkanın Merkez Bankası görevi kendiliğinden bitti")

# ---------------- Belediye tahvili
hata_bekle(rpc, y1, "belediye_tahvil_ihrac", 100000, 2, 30, icerir="belediye başkanı")
hata_bekle(rpc, baskan, "belediye_tahvil_ihrac", 100000, 2, 20, icerir="Vade")
hata_bekle(rpc, baskan, "belediye_tahvil_ihrac", 100000, 50, 30, icerir="25 puan")
q(f"update oyun.il_durum set kasa=2 where il_id={IL('İzmir')}")
tavan = num(f"select oyun.bel_tahvil_tavan({IL('İzmir')}::smallint)")
hata_bekle(rpc, baskan, "belediye_tahvil_ihrac", tavan + 1, 2, 30, icerir="arasında")
v = rpc(baskan, "belediye_tahvil_ihrac", 200000, 3, 30)
tid = v["tahviller"][0]["id"]; assert v["belediyem"]["il"] == "İzmir"
rpc(y1, "belediye_tahvil_al", tid, 120000); rpc(y2, "belediye_tahvil_al", tid, 30000)
hata_bekle(rpc, y2, "belediye_tahvil_al", tid, 60000, icerir="Kalan")
assert para(y1) == 5000000 - 120000
saat("2026-10-18 11:00"); kasa0 = num(f"select kasa from oyun.il_durum where il_id={IL('İzmir')}")
q("select oyun.ekonomi2_tick()")
assert q(f"select durum from oyun.belediye_tahvil where id={tid}") == "tutuluyor"
kur = num("select oyun.pazar_tl_milyar()")
assert abs(num(f"select kasa from oyun.il_durum where il_id={IL('İzmir')}") - (kasa0 + 150000 / kur)) < 1e-6
ok(f"Tahvil satışı: 150.000 ₺ toplandı, il kasasına {150000 / kur:.4f} milyar eklendi")

# Vade: kasa yetmezse temerrüt (kısmi ödeme)
q(f"update oyun.il_durum set kasa=(75000/oyun.pazar_tl_milyar()) where il_id={IL('İzmir')}")
q(f"update oyun.belediye_tahvil set vade=now()-interval '1 minute' where id={tid}")
p1 = para(y1); q("select oyun.ekonomi2_tick()")
assert q(f"select durum from oyun.belediye_tahvil where id={tid}") == "temerrut"
odenen = para(y1) - p1; assert 0 < odenen < 120000 * 1.03, odenen
ok(f"Kasa yetmeyince temerrüt: Yatırımcı1 alacağın ancak {odenen:,.0f} ₺'sini aldı")

v2 = rpc(baskan, "belediye_tahvil_ihrac", 100000, 1, 14); t2 = v2["tahviller"][0]["id"]
rpc(y1, "belediye_tahvil_al", t2, 10000); p1 = para(y1)
q(f"update oyun.belediye_tahvil set satis_bit=now()-interval '1 minute' where id={t2}"); q("select oyun.ekonomi2_tick()")
assert q(f"select durum from oyun.belediye_tahvil where id={t2}") == "iptal" and para(y1) == p1 + 10000
ok("Hedefin %30'una ulaşmayan tahvil iptal edildi, para iade edildi")

# ---------------- SPK
makam(maliye, "bakan", bakanlik="maliye")  # test: önceki tick kabine kontrolünde atamayı kapatmış olabilir
sid = rpc(patron, "sirket_kur", "Patron Holding", "teknoloji", 500000)["id"]
q(f"update oyun.sirketler set halka_acik=true where id={sid}")
q(f"insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values({sid},'{y1}',10),({sid},'{y2}',10) on conflict do nothing")
q(f"update oyun.sirket_ortaklari set pay=80 where sirket_id={sid} and user_id='{patron}'")
q(f"insert into oyun.borsa_islem(sirket_id,satici,alici,pay,birim,tutar,komisyon,zaman) values({sid},'{y1}','{y2}',1,5000,5000,0,oyun.simdi())")
assert q("select count(*) from oyun.spk_inceleme") == "0"
q(f"insert into oyun.borsa_islem(sirket_id,satici,alici,pay,birim,tutar,komisyon,zaman) values({sid},'{y2}','{y1}',1,9000,9000,0,oyun.simdi())")
assert q("select tur from oyun.spk_inceleme") == "karsilikli_islem"
ok("48 saat içinde karşılıklı al-sat otomatik SPK incelemesine alındı")

# Bağlantılı hesaplar: aynı cihaz
q(f"insert into oyun.oturumlar(user_id,cihaz,iz,ip,ilk,son,sayi) values('{patron}','cihaz-A','iz1','1.1.1.1',now(),now(),1),('{y2}','cihaz-A','iz2','1.1.1.2',now(),now(),1)")
q(f"insert into oyun.borsa_islem(sirket_id,satici,alici,pay,birim,tutar,komisyon,zaman) values({sid},'{patron}','{y2}',5,4000,20000,0,oyun.simdi())")
iid = int(q("select id from oyun.spk_inceleme where tur='bagli_hesap'"))
e = rpc(maliye, "spk_ekrani"); assert e["yetkili"] and len(e["incelemeler"]) == 2
hata_bekle(rpc, y1, "spk_karar", iid, True, None, icerir="Maliye")
pp = para(patron); rpc(maliye, "spk_karar", iid, True, "Paravan hesap")
assert q(f"select durum from oyun.spk_inceleme where id={iid}") == "ceza" and para(patron) < pp
hata_bekle(q, f"insert into oyun.borsa_emir(sirket_id,satici,pay,kalan,birim,zaman,durum) values({sid},'{patron}',1,1,4000,oyun.simdi(),'acik')", icerir="yasağın")
ok(f"Bağlantılı hesap işlemi cezalandı ({pp - para(patron):,.0f} ₺) ve 7 gün işlem yasağı emirleri durduruyor")

saat("2026-10-22 10:00"); q("select oyun.ekonomi2_tick()")
assert q("select durum from oyun.spk_inceleme where tur='karsilikli_islem'") == "beraat"
ok("Süresi dolan karşılıklı işlem incelemesi kendiliğinden ihlal yok kararıyla kapandı")

# ---------------- Konkordato / iflas
sid2 = rpc(y1, "sirket_kur", "Batik Ticaret", "ticaret", 200000)["id"]
hata_bekle(rpc, y1, "sirket_konkordato_ilan", sid2, icerir="artıda")
q(f"update oyun.sirketler set kasa=-50000 where id={sid2}")
k = rpc(y1, "konkordato_ekrani"); assert k["riskli"][0]["id"] == sid2 and not k["riskli"][0]["surecte"]
hata_bekle(rpc, y2, "sirket_konkordato_ilan", sid2, icerir="yöneticisi")
rpc(y1, "sirket_konkordato_ilan", sid2)
assert q(f"select durum from oyun.sirket_konkordato where sirket_id={sid2}") == "surec"
q(f"update oyun.sirketler set kasa=1000 where id={sid2}")
saat("2026-11-06 10:00"); q("select oyun.ekonomi2_tick()")
assert q(f"select durum from oyun.sirket_konkordato where sirket_id={sid2}") == "kurtuldu"
ok("Konkordato ilan edildi; kasa artıya dönünce şirket kurtuldu")

sid3 = rpc(y2, "sirket_kur", "Iflas AS", "ticaret", 200000)["id"]
q(f"update oyun.sirketler set kasa=-150000, halka_acik=true where id={sid3}")
q(f"insert into oyun.borsa_emir(sirket_id,satici,pay,kalan,birim,zaman,durum) values({sid3},'{y2}',5,5,1000,oyun.simdi(),'acik')")
q("select oyun.ekonomi2_tick()")
assert q(f"select durum from oyun.sirket_konkordato where sirket_id={sid3}") == "surec"
saat("2026-11-21 10:00"); q("select oyun.ekonomi2_tick()")
assert q(f"select durum||'|'||(select aktif from oyun.sirketler where id={sid3})||'|'||(select halka_acik from oyun.sirketler where id={sid3}) from oyun.sirket_konkordato where sirket_id={sid3}") == "iflas|false|false"
assert q(f"select count(*) from oyun.borsa_emir where sirket_id={sid3} and durum='acik'") == "0"
ok("Açığı sermayenin yarısını geçen şirket kendiliğinden konkordatoya girdi, 14 gün sonra iflas etti, emirleri iptal edildi")
print("ekonomi kurumları: tüm kontroller geçti")
