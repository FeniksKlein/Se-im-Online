"""Çoklu hesap önlemleri, vatandaşlık (oy) şartları, parti kuruluşu, arsa ihalesi ve imar barışının oyuncuya etkisi.
Çalıştır: ../kur_yerel.sh && python3 guvenlik.py"""
import json, uuid
from db import q, qj, rpc, saat, hata_bekle, SqlHata

def ok(m): print("  ✓", m)
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', baslangic_para=1000000;")
# üretimdeki sıkı kurallar
q("update oyun.ayarlar set coklu_kontrol=true, eposta_zorunlu=true, min_hesap_gun=3, oy_min_kidem=10, oy_il_gun=7, cihaz_zorunlu=true, cihaz_max_hesap=2, parti_kurucu_sayi=3, parti_kurucu_kidem=30, parti_kurulus_gun=7")
saat("2026-10-02 12:00")

def hesap(email, onayli=True):
    u = str(uuid.uuid4())
    q(f"insert into auth.users(id, email, email_confirmed_at) values ('{u}', '{email}', {'now()' if onayli else 'null'})")
    return u
def oturum(u, cihaz, iz, ip="10.0.0.1"):
    return q(f"""select set_config('request.headers', '{json.dumps({"x-forwarded-for": ip + ", 172.16.0.1"})}', false);
                  select public.oturum_kaydet('{cihaz}', '{iz}');""", u).split("\n")[-1]
def profil(u, kad, il):
    return rpc(u, "profil_olustur", kad, il)
def kidem(u, k): q(f"select oyun.cuzdanim('{u}'); update oyun.cuzdan set kidem={k} where user_id='{u}'")

# ---------------- 1) HESAP AÇMA ----------------
u1 = hesap("ayse@t.com"); oturum(u1, "cihaz-A", "iz-A"); profil(u1, "Ayse", 34)
saat("2026-10-02 12:01")
u2 = hesap("ayse2@t.com"); oturum(u2, "cihaz-A", "iz-A2"); profil(u2, "AyseIki", 34)        # aynı telefonda ikinci hesap: açılır ama şüpheli
u3 = hesap("ayse3@t.com"); oturum(u3, "cihaz-A", "iz-A3")
hata_bekle(profil, u3, "AyseUc", 34, icerir="en fazla 2")
u4 = hesap("sahte@mailinator.com"); oturum(u4, "cihaz-X", "iz-X")
hata_bekle(profil, u4, "Sahte", 34, icerir="Tek kullanımlık")
u5 = hesap("kemal@t.com"); oturum(u5, "cihaz-K", "iz-K", ip="10.0.0.1"); profil(u5, "Kemal", 34)
u6 = hesap("dogrulanmamis@t.com", onayli=False); oturum(u6, "cihaz-D", "iz-D"); profil(u6, "Dogrulanmamis", 34)
u7 = hesap("cihazsiz@t.com"); profil(u7, "Cihazsiz", 34)
assert q(f"select count(*) from oyun.oturumlar where user_id='{u1}' and ip is not null and ip <> '10.0.0.1'") == "1"   # IP özetlenerek saklanır
assert "cihaz-A" not in q("select string_agg(coalesce(cihaz,''), ',') from oyun.oturumlar")
ok("Hesap açma: aynı cihazda en fazla 2 hesap, tek kullanımlık e-posta reddedildi; cihaz ve IP yalnızca tuzlanmış özet olarak saklanıyor")

# ---------------- 2) VATANDAŞLIK ŞARTLARI ----------------
v = rpc(u1, "vatandaslik")
assert not v["uygun"] and len(v["sartlar"]) == 6 and "günlük" in v["engel"]
saat("2026-10-10 12:00")
for u in [u1, u2, u5, u6, u7]: kidem(u, 12)
assert rpc(u1, "vatandaslik")["uygun"] and rpc(u5, "vatandaslik")["uygun"]
assert "başka bir hesap" in rpc(u2, "vatandaslik")["engel"]
assert "E-posta" in rpc(u6, "vatandaslik")["engel"]
assert "Cihaz doğrulaması" in rpc(u7, "vatandaslik")["engel"]
kidem(u5, 5); assert "kıdem" in rpc(u5, "vatandaslik")["engel"]; kidem(u5, 12)
ok("Vatandaşlık şartları: hesap yaşı, doğrulanmış e-posta, cihaz doğrulaması, tek hesap, 'Vatandaş' statüsü — her biri ayrı ayrı denetleniyor")

# ---------------- 3) OY: SEÇMEN KÜTÜĞÜ, ŞÜPHELİ HESAP, CİHAZ BAŞINA TEK OY ----------------
u8 = hesap("yeni@t.com"); oturum(u8, "cihaz-Y", "iz-Y"); profil(u8, "YeniGelen", 6)
q(f"update oyun.profiller set olusturma='2026-10-01 00:00+03', il_at='2026-10-01 00:00+03' where id='{u8}'"); kidem(u8, 12)
q(f"update oyun.profiller set il_id=34, il_at='2026-10-08 00:00+03', son_il_degis='2026-10-08 00:00+03' where id='{u8}'")          # 2 gün önce İstanbul'a taşındı
sid = q("""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,durum) values ('bel','2026-91','2026-10-10 08:00+03','2026-10-10 17:00+03','2026-10-10 18:00+03','bekliyor') returning id""").split("\n")[0]
aid = q(f"insert into oyun.adaylar(secim_id,user_id,parti_id,il_id) values ({sid},'{u5}',1,34) returning id").split("\n")[0]
rpc(u1, "oy_ver", int(sid), int(aid))
hata_bekle(rpc, u8, "oy_ver", int(sid), int(aid), icerir="Seçmen kütüğü")
hata_bekle(rpc, u2, "oy_ver", int(sid), int(aid), icerir="başka bir hesap")
admin = hesap("yonetici@t.com"); oturum(admin, "cihaz-Y2", "iz-Y2"); profil(admin, "Denetci", 6); q(f"update oyun.profiller set yonetici=true where id='{admin}'")
rpc(admin, "admin_hesap_onay", "AyseIki", True, "Kardeşi, aynı telefonu paylaşıyorlar")
assert rpc(u2, "vatandaslik")["uygun"]
hata_bekle(rpc, u2, "oy_ver", int(sid), int(aid), icerir="Bu cihazdan bu sandıkta")
ok("Oy: ile yeni taşınan seçmen kütüğüne takıldı; şüpheli hesap oy kullanamadı; yönetici onayından sonra bile aynı cihazdan ikinci oy reddedildi")

# yönetici paneli: kümeler
for i in range(3):
    x = hesap(f"yurt{i}@t.com"); oturum(x, f"cihaz-Y{i+10}", f"iz-Y{i+10}", ip="88.1.1.1"); profil(x, f"Yurt{i}", 6)
s = rpc(admin, "admin_supheler")
assert any({h["kad"] for h in c["hesaplar"]} >= {"Ayse", "AyseIki"} for c in s["cihaz"])
assert any(set(c["hesaplar"]) >= {"Yurt0", "Yurt1", "Yurt2"} for c in s["ip"])
hata_bekle(rpc, u1, "admin_supheler", icerir="yönetici")
r = rpc(admin, "admin_kurallar", json.dumps({"oy_min_kidem": 7, "parti_kurucu_sayi": 3}))
assert r["oy_min_kidem"] == 7 and r["parti_kurucu_sayi"] == 3
ok("Yönetici: aynı cihaz ve aynı IP kümeleri listeleniyor (IP tek başına engel değil); şartlar panelden ayarlanabiliyor")

# ---------------- 4) PARTİ KURULUŞU ----------------
args = ("Yeni Ufuk Partisi", "YUP", "#336699", "a_gul")
hata_bekle(rpc, u5, "parti_kur", *args, icerir="kıdem puanın")
kidem(u5, 31)
rpc(u5, "parti_kur", *args)
pid = int(q("select id from oyun.partiler where kisa='YUP'"))
d = rpc(u5, "parti_detay", pid)
assert d["kurulus_bit"] and d["kurucu_gecerli"] == 1 and d["kurucu_gerekli"] == 3
rpc(u1, "partiye_katil", pid)
rpc(u7, "partiye_katil", pid)                       # cihaz doğrulaması yok: kurucu sayılmaz
saat("2026-10-10 12:30")
assert q(f"select kurulus_bit is not null from oyun.partiler where id={pid}") == "t"
oturum(u7, "cihaz-C7", "iz-C7")
saat("2026-10-10 12:31")
assert q(f"select kurulus_bit is null from oyun.partiler where id={pid}") == "t"
kidem(u8, 31); q(f"update oyun.profiller set il_id=6 where id='{u8}'")
rpc(u8, "parti_kur", "Sessiz Yol Partisi", "SYP", "#996633", "a_gul")
saat("2026-10-17 12:40")
assert q("select kapali from oyun.partiler where kisa='SYP'") == "t" and q(f"select parti_id is null from oyun.profiller where id='{u8}'") == "t"
ok("Parti kuruluşu: kurucuda kıdem şartı; şartları taşıyan 3 kurucu toplanınca kuruluş tamamlandı; 7 günde tamamlanmayan kuruluş düştü")

# ---------------- 5) ARSA İHALESİ VE İMAR BARIŞI ----------------
q("update oyun.ayarlar set oy_min_kidem=0, oy_il_gun=0, cihaz_zorunlu=false, min_hesap_gun=0, ihmal_gun_secim=0, ihmal_gun_atama=0")   # bu bölüm görev ihmalini sınamıyor
baskan = u5; q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('bel','{baskan}',34,{pid},'2026-10-10 00:00+03')")
uzak = hesap("uzak@t.com"); profil(uzak, "Uzakta", 6)
q("update oyun.il_durum set kasa=5 where il_id=34")
k0 = float(q("select kasa from oyun.il_durum where il_id=34")); g0 = float(q("select gelisim from oyun.il_durum where il_id=34"))
rpc(baskan, "belediye_yatirim", "arsa_satisi")
ih = rpc(u1, "ihaleler")["acik"][0]
assert ih["il"] == "İstanbul" and ih["katilabilir"]
assert float(q("select kasa from oyun.il_durum where il_id=34")) == k0                       # ihale bitmeden kasa değişmez
hata_bekle(rpc, baskan, "arsa_teklif", ih["id"], ih["asgari"], icerir="Belediye başkanı")
hata_bekle(rpc, uzak, "arsa_teklif", ih["id"], ih["asgari"], icerir="o ilde yaşayan")
hata_bekle(rpc, u1, "arsa_teklif", ih["id"], ih["asgari"] - 1000, icerir="en az")
p1 = int(float(q(f"select para from oyun.cuzdan where user_id='{u1}'")))
rpc(u1, "arsa_teklif", ih["id"], ih["asgari"])
assert int(float(q(f"select para from oyun.cuzdan where user_id='{u1}'"))) == p1 - ih["asgari"]     # teminat
ih2 = rpc(u2, "ihaleler")["acik"][0]
rpc(u2, "arsa_teklif", ih["id"], ih2["asgari"])
assert int(float(q(f"select para from oyun.cuzdan where user_id='{u1}'"))) == p1                    # geçilen teklif iade
saat("2026-10-19 13:00")
m = qj(f"select row_to_json(m) from oyun.mulkler m where user_id='{u2}'")
assert m and m["bedel"] == ih2["asgari"] and m["gunluk"] == round(ih2["asgari"] * 0.004)
assert float(q("select kasa from oyun.il_durum where il_id=34")) > k0 and float(q("select gelisim from oyun.il_durum where il_id=34")) < g0
rpc(u2, "topla")
assert int(q(f"select coalesce(sum(tutar),0) from oyun.hesap_hareket where user_id='{u2}' and tur='kira'")) == m["gunluk"]
assert rpc(u2, "ihaleler")["mulklerim"][0]["gunluk"] == m["gunluk"]
ok("Arsa ihalesi: yalnız il sakinleri pey sürdü (başkan ve başka ildeki oyuncu katılamadı), teminat alındı ve geçilince iade edildi; kazanan arsa sahibi oldu ve günlük kira aldı; kasa doldu, gelişmişlik düştü")

g1 = float(q("select gelisim from oyun.il_durum where il_id=34"))
rpc(baskan, "belediye_yatirim", "imar_barisi")
assert float(q("select oyun.bonus(34::smallint, 'gecim', oyun.simdi())")) >= 8
assert float(q("select gelisim from oyun.il_durum where il_id=34")) == g1 - 3
assert q(f"select count(*) from oyun.bildirimler where user_id='{u1}' and metin like '%imar barışı%'") == "1"
ok("İmar barışı: hemşehrilerin geçim masrafı 14 gün %8 düştü, bildirim gitti; gelişmişlik kalıcı olarak 3 puan düştü")

for fn in ["oturum_kaydet('a','b')", "vatandaslik()", "admin_supheler()", "arsa_teklif(1,1)", "ihaleler()"]:
    try:
        q(f"set role anon; select public.{fn};"); raise AssertionError(fn)
    except Exception as e_:
        assert "permission denied" in str(e_), (fn, e_)
for tb in ["oturumlar", "oy_cihaz", "hesap_onay"]:
    try:
        q(f"set role authenticated; select * from oyun.{tb};"); raise AssertionError(tb)
    except Exception as e_:
        assert "permission denied" in str(e_), (tb, e_)
ok("Güvenlik: yeni fonksiyonlar girişsiz kapalı; cihaz/IP kayıtları doğrudan okunamıyor")
print("\nTÜM GÜVENLİK KONTROLLERİ GEÇTİ")
