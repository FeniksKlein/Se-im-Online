"""Siyaset Merkezi (modül 102): haftalık takvim, projeksiyon, özet, canlı yayın, transfer, balkon, müşahit,
resmî gün, saha çalışması, yol arkadaşı ve yeni rozetler."""
from db import q, qj, rpc, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
def zaman(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")
def tick(): q("select oyun.siyaset_merkezi_tick()")
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
q("update oyun.ayarlar set kurucu_rozet_bitis='2026-12-31 23:59+03', mentor_odul=1000, stant_bedel=2000, push_aktif=false")
zaman("2026-10-19 09:00")   # pazartesi

def oyuncu(kad, il, gun_once=30):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.profiller set olusturma = oyun.simdi() - interval '{gun_once} days', son_gorulme = oyun.simdi() where id='{u}'")
    return u

pa, pb = [int(x) for x in q("select id from oyun.partiler where not kapali order by id limit 2").split("\n")]
gb_a = oyuncu("LiderA", "İzmir"); gb_b = oyuncu("LiderB", "Ankara")
q(f"update oyun.profiller set parti_id={pa} where id='{gb_a}'; update oyun.profiller set parti_id={pb} where id='{gb_b}';"
  f"update oyun.partiler set gb='{gb_a}', kasa=100000 where id={pa}; update oyun.partiler set gb='{gb_b}', kasa=100000 where id={pb};")
vekil = oyuncu("VekilV", "İzmir")
q(f"update oyun.profiller set parti_id={pb} where id='{vekil}'")
q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas,kaynak) values('mv','{vekil}',{IL('İzmir')},{pb},oyun.simdi() - interval '3 days','atama')")
gazeteci = oyuncu("Muhabir", "Ankara"); izleyici = oyuncu("Izleyici", "İzmir"); yeni = oyuncu("Caylak", "İzmir", gun_once=1)
gz = int(q(f"insert into oyun.oyuncu_gazeteleri(ad, sahip, aktif) values('Sabah Postası','{gazeteci}',true) returning id").split("\n")[0])

# ---- 1) Haftalık takvim
h = rpc(izleyici, "siyasi_hafta")
assert h["gun_no"] == 1 and len(h["gunler"]) == 7 and h["gunler"][0]["bugun"] and h["gunler"][2]["ad"] == "Grup günü", h
q(f"update oyun.profiller set son_gorulme=oyun.simdi() where id='{vekil}'")
zaman("2026-10-19 10:05"); tick()
assert q(f"select count(*) from oyun.bildirimler where user_id='{vekil}' and metin like 'Meclis haftası başladı%'") == "1"
tick()
assert q(f"select count(*) from oyun.bildirimler where user_id='{vekil}' and metin like 'Meclis haftası başladı%'") == "1"
ok("Haftalık takvim 7 gün; pazartesi Meclis hatırlatması bir kez gidiyor")

# ---- 2) Projeksiyon
p0 = rpc(izleyici, "meclis_projeksiyon")
assert p0["toplam"] == 0 and p0["uyari"]
hafta = q("select date_trunc('week', oyun.simdi() at time zone 'Europe/Istanbul')::date")
q(f"insert into oyun.haftalik_anket(hafta) values('{hafta}') on conflict do nothing")
for i in range(12):
    u = oyuncu(f"Anketci{i}", "İzmir" if i < 8 else "Ankara")
    q(f"insert into oyun.haftalik_anket_oy(hafta,user_id,parti_id) values('{hafta}','{u}',{pa if i % 3 else pb})")
p = rpc(izleyici, "meclis_projeksiyon")
toplam_s = sum(x["sandalye"] for x in p["partiler"])
assert p["toplam"] == 12 and toplam_s == 600, (p["toplam"], toplam_s)
izmir = next(x for x in p["iller"] if x["il"] == "İzmir")
assert sum(d["s"] for d in izmir["dagilim"]) == izmir["mv"] and izmir["anketci"] == 8
ok(f"Projeksiyon: 600 sandalye dağıtıldı; {', '.join(x['parti']['kisa'] + ' ' + str(x['sandalye']) for x in p['partiler'])}")

# ---- 4) Canlı yayın: basın toplantısı
hata_bekle(rpc, izleyici, "canli_yayin_ac", "basin", "Açıklama", None, None, icerir="makam sahipleri")
b = rpc(vekil, "canli_yayin_ac", "basin", "Asgari ücret açıklaması", None, None)
assert b["durum"] == "canli"
assert q(f"select count(*) from oyun.bildirimler where user_id='{gazeteci}' and metin like '%basın toplantısı düzenliyor%'") == "1"
hata_bekle(rpc, vekil, "canli_yayin_ac", "basin", "İkinci", None, None, icerir="Bugün zaten")
rpc(vekil, "canli_yayin_yaz", b["id"], "Asgari ücrete ara zam teklifi vereceğiz.", None)
zaman("2026-10-19 10:05:05")
s1 = rpc(gazeteci, "canli_yayin_yaz", b["id"], "Kaynağı nereden bulacaksınız?", None)
zaman("2026-10-19 10:05:10")
rpc(gazeteci, "canli_yayin_yaz", b["id"], "Vergi artışı olacak mı?", None)
zaman("2026-10-19 10:05:15")
hata_bekle(rpc, gazeteci, "canli_yayin_yaz", b["id"], "Üçüncü soru", None, icerir="en fazla 2 soru")
hata_bekle(rpc, izleyici, "canli_yayin_yaz", b["id"], "Ben de sorayım", None, icerir="yalnızca gazeteciler")
rpc(vekil, "canli_yayin_yaz", b["id"], "Kaynak bütçede hazır.", s1["id"])
rpc(izleyici, "canli_yayin_tepki", b["id"], "alkis")
d = rpc(gazeteci, "canli_yayin_detay", b["id"], 0)
assert d["rolum"] == "gazeteci" and len(d["mesajlar"]) == 4 and d["alkis"] == 1 and d["mesajlar"][3]["yanit_id"] == s1["id"]
ok("Basın toplantısı: yalnız siyasetçi açar, gazeteci 2 soru sorar, yanıt bağlanır, izleyici tepki verir")

# ---- Program
hata_bekle(rpc, izleyici, "canli_yayin_ac", "program", "Tartışma", None, None, icerir="gazetenin sahibi")
pr = rpc(gazeteci, "canli_yayin_ac", "program", "Ekonomi masası", "2026-10-19 11:00+03", None)
assert pr["durum"] == "yakinda"
rpc(gazeteci, "canli_yayin_davet", pr["id"], "LiderA"); rpc(gazeteci, "canli_yayin_davet", pr["id"], "LiderB")
rpc(gb_a, "canli_yayin_davet_yanit", pr["id"], True); rpc(gb_b, "canli_yayin_davet_yanit", pr["id"], True)
hata_bekle(rpc, gb_a, "canli_yayin_yaz", pr["id"], "Erken söz", None, icerir="henüz başlamadı")
zaman("2026-10-19 11:01"); tick()
assert q(f"select count(*) from oyun.bildirimler where user_id='{gb_a}' and metin like '%programı başladı%'") == "1"
rpc(gazeteci, "canli_yayin_yaz", pr["id"], "Hoş geldiniz. Enflasyon nasıl düşer?", None)
zaman("2026-10-19 11:01:05"); rpc(gb_a, "canli_yayin_yaz", pr["id"], "Faiz politikasıyla.", None)
zaman("2026-10-19 11:01:10"); rpc(gb_b, "canli_yayin_yaz", pr["id"], "Üretimle.", None)
hata_bekle(rpc, izleyici, "canli_yayin_yaz", pr["id"], "Söz istiyorum", None, icerir="moderatör ve konuklar")
hata_bekle(rpc, gb_a, "canli_yayin_oyla", pr["id"], "LiderB", icerir="Moderatör ve konuklar")
rpc(izleyici, "canli_yayin_oyla", pr["id"], "LiderB"); rpc(vekil, "canli_yayin_oyla", pr["id"], "LiderB"); rpc(yeni, "canli_yayin_oyla", pr["id"], "LiderA")
zaman("2026-10-19 12:05"); tick()
haber = q("select metin from oyun.olaylar where metin like 'Tartışma programı sona erdi%' order by id desc limit 1")
assert "LiderB (2 oy)" in haber, haber
assert q(f"select count(*) from oyun.bildirimler where user_id='{gb_b}' and metin like '%en ikna edici%'") == "1"
ok(f"Program: konuk daveti, başlangıç bildirimi, izleyici oylaması → {haber}")

# ---- 5) Transfer ve rozet
q(f"update oyun.profiller set parti_id={pa} where id='{vekil}'")
g = q(f"select id||'|'||(case when onemli then 't' else 'f' end) from oyun.parti_gecis where user_id='{vekil}' order by id desc limit 1").split("|")
assert g[1] == "t", g
assert "partisine katıldı" in q("select metin from oyun.olaylar where metin like 'Transfer:%' order by id desc limit 1")
assert q(f"select count(*) from oyun.bildirimler where user_id='{gb_b}' and metin like 'VekilV partimizden ayrıldı%'") == "1"
lst = rpc(gb_a, "parti_gecisleri", 10)
assert lst[0]["rozet_takabilirim"] and not rpc(gb_b, "parti_gecisleri", 10)[0]["rozet_takabilirim"]
hata_bekle(rpc, gb_b, "rozet_tak", int(g[0]), None, icerir="genel başkan")
rpc(gb_a, "rozet_tak", int(g[0]), "Birlikte kazanacağız.")
hata_bekle(rpc, gb_a, "rozet_tak", int(g[0]), None, icerir="zaten")
assert q(f"select count(*) from oyun.akis where user_id='{gb_a}' and metin like 'Rozetini taktık: VekilV%'") == "1"
assert len(rpc(izleyici, "oyuncu_parti_gecmisi", "VekilV")) == 2
q(f"update oyun.profiller set parti_id={pa} where id='{izleyici}'")
assert q(f"select onemli from oyun.parti_gecis where user_id='{izleyici}'") == "f"
q(f"update oyun.profiller set parti_id=null where id='{izleyici}'")
ok("Transfer: makamlı geçiş haber + bildirim üretiyor, sıradan üyelik sessiz; rozet töreni akışa düşüyor")

# ---- 6) Balkon ve tebrik
sid = int(q(f"""insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas, durum, sonuc)
  values('mv','test-1', oyun.simdi()-interval '5 days', oyun.simdi()-interval '4 days', oyun.simdi()-interval '3 hours', oyun.simdi()-interval '1 hour',
  oyun.simdi()-interval '30 minutes', oyun.simdi()+interval '1 day', 'tamam',
  jsonb_build_object('ulusal', jsonb_build_array(jsonb_build_object('parti_id',{pa},'sandalye',320), jsonb_build_object('parti_id',{pb},'sandalye',280)))) returning id""").split("\n")[0])
bd = rpc(izleyici, "balkon_durum")
assert bd[0]["kazanan"]["kad"] == "LiderA" and not bd[0]["tebrik_edebilirim"]
hata_bekle(rpc, gb_b, "balkon_konus", sid, "Kazandım", icerir="kazanan yapar")
rpc(gb_a, "balkon_konus", sid, "Bu zafer 81 ilin zaferidir!")
hata_bekle(rpc, gb_a, "balkon_konus", sid, "Tekrar", icerir="zaten")
assert rpc(gb_b, "balkon_durum")[0]["tebrik_edebilirim"]
rpc(gb_b, "tebrik_et", sid, "Seçmenin kararına saygı duyuyoruz, hayırlı olsun.")
hata_bekle(rpc, izleyici, "tebrik_et", sid, "Tebrikler", icerir="genel başkanları")
bd = rpc(izleyici, "balkon_durum")[0]
assert bd["konusma"]["metin"].startswith("Bu zafer") and bd["tebrikler"][0]["kad"] == "LiderB"
assert rpc(izleyici, "siyaset_merkezi_ozet")["balkon"]["kad"] == "LiderA"
ok("Balkon konuşmasını yalnız birinci partinin genel başkanı yapıyor; rakip lider tebrik ediyor")

# ---- 7) Müşahit
s2 = int(q(f"""insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas, durum)
  values('bel','test-2', oyun.simdi()-interval '2 days', oyun.simdi()-interval '1 day', oyun.simdi()+interval '1 hour', oyun.simdi()+interval '9 hours',
  oyun.simdi()+interval '10 hours', oyun.simdi()+interval '1 day', 'bekliyor') returning id""").split("\n")[0])
hata_bekle(rpc, vekil, "musahit_ata", s2, IL("İzmir"), "VekilV", icerir="genel başkan")
hata_bekle(rpc, gb_a, "musahit_ata", s2, IL("Ankara"), "VekilV", icerir="ilde yaşamalı")
hata_bekle(rpc, gb_a, "musahit_ata", s2, IL("İzmir"), "LiderB", icerir="üyesi olmalı")
pn = rpc(gb_a, "musahit_ata", s2, IL("İzmir"), "VekilV")
sec = next(x for x in pn["secimler"] if x["id"] == s2)
assert sec["atananlar"][0]["kad"] == "VekilV" and sec["kapsama"][0]["il"] == 1
izmirli2 = oyuncu("IzmirMusahit", "İzmir"); q(f"update oyun.profiller set parti_id={pa} where id='{izmirli2}'")
rpc(gb_a, "musahit_ata", s2, IL("İzmir"), "IzmirMusahit")
assert next(x for x in rpc(gb_a, "musahit_paneli")["secimler"] if x["id"] == s2)["atananlar"][0]["kad"] == "IzmirMusahit"
rpc(gb_a, "musahit_kaldir", s2, IL("İzmir"))
assert next(x for x in rpc(gb_a, "musahit_paneli")["secimler"] if x["id"] == s2)["atananlar"] == []
assert rpc(izmirli2, "musahit_paneli")["gorevlerim"] == []
rpc(gb_a, "musahit_ata", s2, IL("İzmir"), "VekilV")
hata_bekle(rpc, vekil, "musahit_sandik", s2, icerir="oy saatlerinde")
zaman("2026-10-19 13:30")
rpc(vekil, "musahit_sandik", s2)
q(f"update oyun.secimler set durum='tamam', sonuc_at=oyun.simdi() where id={s2}")
rpc(vekil, "musahit_tutanak", s2, "itiraz", "Sayımda 3 oy pusulası eksik çıktı.")
assert q(f"select count(*) from oyun.bildirimler where user_id='{gb_a}' and metin like '%itiraz tutanağı%'") == "1"
assert any(r["ad"] == "Sandık Görevlisi" for r in qj(f"select oyun.rozetler('{vekil}')"))
ok("Müşahit: yalnız yönetici atar, aynı ilde yaşayan üye; sandık başı + itiraz tutanağı yönetime gidiyor; rozet")

# ---- 8) Resmî gün
zaman("2026-10-29 08:10"); tick()
assert q(f"select count(*) from oyun.bildirimler where user_id='{vekil}' and metin like 'Bugün Cumhuriyet Bayramı%'") == "1"
r = rpc(vekil, "resmi_gunler"); assert r["bugun"]["ad"] == "Cumhuriyet Bayramı" and r["yazabilirim"]
rpc(vekil, "resmi_gun_mesaj_yaz", "Cumhuriyetimizin 103. yılı kutlu olsun!")
hata_bekle(rpc, vekil, "resmi_gun_mesaj_yaz", "Bir daha", icerir="zaten")
hata_bekle(rpc, izleyici, "resmi_gun_mesaj_yaz", "Kutlu olsun", icerir="makam sahipleri")
assert rpc(izleyici, "siyaset_merkezi_ozet")["resmi_gun"]["mesaj"] == 1
zaman("2026-10-30 10:00"); hata_bekle(rpc, vekil, "resmi_gun_mesaj_yaz", "Geç", icerir="resmî bir gün değil")
ok("Resmî gün: hatırlatma, makamlı mesaj, günde bir kez")

# ---- 9) Saha
izmirli = oyuncu("IzmirSakini", "İzmir")
q(f"delete from oyun.parti_teskilat where parti_id={pa}")
hata_bekle(rpc, gb_a, "stant_ac", IL("İzmir"), "Kordon standı", icerir="teşkilatı yok")
q(f"insert into oyun.parti_teskilat(parti_id, il_id, kurulus, kuran, bedel) values({pa},{IL('İzmir')},oyun.simdi(),'{gb_a}',0)")
st = rpc(gb_a, "stant_ac", IL("İzmir"), "Kordon standı")
assert q(f"select kasa from oyun.partiler where id={pa}") == "98000"
assert q(f"select count(*) from oyun.bildirimler where user_id='{izmirli}' and metin like '%seçim standı açtı%'") == "1"
hata_bekle(rpc, gb_a, "stant_ac", IL("İzmir"), "İkinci", icerir="zaten stant")
hata_bekle(rpc, gb_b, "stant_ziyaret", st["id"], None, icerir="bu ilde yaşayanlar")
z = rpc(izmirli, "stant_ziyaret", st["id"], "Kira yardımı gelecek mi?")
rpc(vekil, "stant_gonullu_ol", st["id"])
zid = int(q(f"select id from oyun.stant_ziyaret where stant_id={st['id']}"))
rpc(vekil, "stant_cevapla", zid, "Evet, ilk ay başlıyor.")
s = rpc(izmirli, "stantlar", None)["canli"][0]
assert s["ziyaretci"] == 1 and s["gonullu"] == 1 and s["sorular"][0]["cevap"].startswith("Evet")
k = rpc(vekil, "kapi_kapi_haklarim")
assert k["kalan"] == 3
hata_bekle(rpc, vekil, "kapi_kapi", "LiderA", "Merhaba", icerir="Kendi partinin")
hata_bekle(rpc, vekil, "kapi_kapi", "LiderB", "Merhaba", icerir="kendi ilinde")
rpc(vekil, "kapi_kapi", "IzmirSakini", "Merhaba komşu, pazar standımıza bekleriz.")
assert q(f"select count(*) from oyun.bildirimler where user_id='{izmirli}' and metin like '%kapını çaldı%'") == "1"
hata_bekle(rpc, gb_a, "kapi_kapi", "IzmirSakini", "Tekrar merhaba", icerir="zaten çaldı")
q(f"insert into oyun.engellemeler(engelleyen, engellenen, zaman) values('{izleyici}','{vekil}',now())")
hata_bekle(rpc, vekil, "kapi_kapi", "Izleyici", "Selam", icerir="engelledi")
assert rpc(vekil, "kapi_kapi_haklarim")["kalan"] == 2
ok("Saha: teşkilat şartı, parti kasasından stant, ziyaret/soru/cevap/gönüllü; kapı kapı haftada 3, engel ve tekrar korumalı")

# ---- 10) Yol arkadaşı
hata_bekle(rpc, yeni, "mentor_gonullu_ol", "Yardım ederim", True, icerir="14 günlük")
q(f"update oyun.cuzdan set kidem = 50 where user_id='{gb_b}'")
rpc(gb_b, "mentor_gonullu_ol", "Ankara'dan, her akşam çevrimiçiyim.", True)
hata_bekle(rpc, izmirli, "mentor_sec", None, icerir="ilk 14 gününü")
md = rpc(yeni, "mentor_durum"); assert md["acemi_mi"] and md["mentorlar"][0]["kad"] == "LiderB"
assert rpc(yeni, "siyaset_merkezi_ozet")["mentor_oneri"]
rpc(yeni, "mentor_sec", None)
assert rpc(gb_b, "mentor_durum")["acemilerim"][0]["kad"] == "Caylak"
para0 = float(q(f"select para from oyun.cuzdan where user_id='{gb_b}'"))
zaman("2026-10-30 23:00")
q(f"insert into oyun.haftalik_anket(hafta) values('2026-10-26') on conflict do nothing")
q(f"insert into oyun.haftalik_anket_oy(hafta,user_id,parti_id,zaman) values('2026-10-26','{yeni}',{pa},oyun.simdi())")
tick()
assert float(q(f"select para from oyun.cuzdan where user_id='{gb_b}'")) == para0 + 1000
assert q(f"select odul_at is not null from oyun.mentor_bag where acemi='{yeni}'") == "t"
tick(); assert float(q(f"select para from oyun.cuzdan where user_id='{gb_b}'")) == para0 + 1000
assert any(r["ad"] == "Yol Arkadaşı" for r in qj(f"select oyun.rozetler('{gb_b}')"))
assert any(r["ad"] == "Kurucu Vatandaş" for r in qj(f"select oyun.rozetler('{yeni}')"))
ok("Yol arkadaşı: 14 gün/kıdem şartı, otomatik eşleşme, ilk oyda iki tarafa bir kez ödül, rozetler")

# ---- 3) Haftanın özeti (pazar 20.00)
zaman("2026-10-25 20:05"); tick()
oz = rpc(izleyici, "haftanin_ozeti", "2026-10-19")
assert oz["kesin"] and oz["veri"]["yayinlar"]["sayi"] == 2 and len(oz["veri"]["transferler"]) == 1 and oz["veri"]["saha"]["stant"] == 0, oz
assert q("select count(*) from oyun.olaylar where metin like 'Haftanın özeti yayımlandı%'") == "1"
tick(); assert q("select count(*) from oyun.olaylar where metin like 'Haftanın özeti yayımlandı%'") == "1"
assert rpc(izleyici, "siyaset_merkezi_ozet")["ozet_hazir"] == "2026-10-19"
ok(f"Haftanın özeti pazar 20.00'de bir kez: {oz['veri']['yayinlar']['sayi']} yayın, {len(oz['veri']['transferler'])} transfer")
print("siyaset_merkezi: tamam")
