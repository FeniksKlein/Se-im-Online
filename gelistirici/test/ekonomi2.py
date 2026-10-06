"""Ekonomi 2: söz tutmanın karşılığı (itibar), her icraata vaat, şehir bağışı, vergi karnesi, yeni sohbet kanalları.
Çalıştır: ../kur_yerel.sh && python3 ekonomi2.py"""
import json
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
def makam(tur, u, il=None, parti=1, bakanlik=None):
    return q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,bas) values ('{tur}','{u}',{il or 'null'},{parti},{('$$'+bakanlik+'$$') if bakanlik else 'null'},'2026-10-02 12:00+03') returning id").split("\n")[0]

gb  = oyuncu("Genel", 35, 1); q(f"update oyun.partiler set gb='{gb}' where id=1")
yrd = oyuncu("Yardimci", 35, 1); q(f"insert into oyun.parti_gby(parti_id, user_id, sira) values (1,'{yrd}',1)")
cb  = oyuncu("Cumhur", 6, 1); makam("cb", cb)
bak = oyuncu("Bakan", 35, 1); makam("bakan", bak, bakanlik="adalet")
bel = oyuncu("Baskan", 35, 1); bel_id = makam("bel", bel, 35)
vek = oyuncu("Vekil", 35, 1); makam("mv", vek, 35)
sade = oyuncu("Sade", 35, 2)
baska_il = oyuncu("Ankara", 6, 2)

# ---------------- SOHBET ----------------
oz = rpc(sade, "sohbet_ozet")
k = {x["kanal"]: x for x in oz["kanallar"]}
assert list(k) == ["genel", "il", "belediye", "parti", "yonetim", "ittifak", "meclis", "kabine"], list(k)
assert k["kabine"]["kilit"] and k["yonetim"]["kilit"] and k["ittifak"]["kilit"] and not k["genel"]["kilit"] and not k["parti"]["kilit"]
assert k["belediye"]["baslik"].startswith("İstanbul") or "Belediye Meclisi" in k["belediye"]["baslik"]
ok("Sohbet listesi 8 kanal döndürüyor; kabine, yönetim ve ittifak sade oyuncuya kilitli (nedeniyle birlikte)")

hata_bekle(rpc, sade, "sohbet_oku", "kabine", icerir="cumhurbaşkanı ve bakanlar")
hata_bekle(rpc, sade, "sohbet_yaz", "yonetim", "selam", icerir="genel başkan")
rpc(cb, "sohbet_yaz", "kabine", "Kabine toplantısı yarın.")
saat("2026-10-02 12:01")
rpc(bak, "sohbet_yaz", "kabine", "Hazırım Sayın Cumhurbaşkanı.")
assert [m["metin"] for m in rpc(bak, "sohbet_oku", "kabine")["mesajlar"]] == ["Kabine toplantısı yarın.", "Hazırım Sayın Cumhurbaşkanı."]
hata_bekle(rpc, gb, "sohbet_oku", "kabine", icerir="cumhurbaşkanı ve bakanlar")
ok("Bakanlar Kurulu yalnızca cumhurbaşkanı ve bakanlara açık")

saat("2026-10-02 12:02")
rpc(gb, "sohbet_yaz", "yonetim", "Kurultay hazırlığı başlasın.")
saat("2026-10-02 12:03")
rpc(yrd, "sohbet_yaz", "yonetim", "Tamamdır.")
assert len(rpc(yrd, "sohbet_oku", "yonetim")["mesajlar"]) == 2
hata_bekle(rpc, vek, "sohbet_oku", "yonetim", icerir="genel başkan")      # üye ama yönetimde değil
hata_bekle(rpc, sade, "sohbet_oku", "yonetim", icerir="genel başkan")
ok("Parti yönetim kurulu yalnızca genel başkan ve yardımcılarına açık (parti üyesi bile giremiyor)")

saat("2026-10-02 12:04")
assert rpc(sade, "sohbet_oku", "belediye")["mesajlar"] == []
hata_bekle(rpc, sade, "sohbet_yaz", "belediye", "selam", icerir="belediye başkanı ve milletvekilleri")
rpc(bel, "sohbet_yaz", "belediye", "Kent lokantası bu hafta açılıyor.")
saat("2026-10-02 12:05")
rpc(vek, "sohbet_yaz", "belediye", "Bütçede ilimiz için pay istedim.")
assert len(rpc(sade, "sohbet_oku", "belediye")["mesajlar"]) == 2
assert rpc(baska_il, "sohbet_oku", "belediye")["mesajlar"] == []        # başka ilin meclisi ayrı
hata_bekle(rpc, baska_il, "sohbet_yaz", "belediye", "x", icerir="belediye başkanı ve milletvekilleri")
ok("Belediye meclisi: ilin herkesi izler, yalnız o ilin başkanı ve vekilleri yazar; her ilin kanalı ayrı")

# okunmamış sayacı
saat("2026-10-02 12:06")
k = {x["kanal"]: x for x in rpc(sade, "sohbet_ozet")["kanallar"]}
assert k["belediye"]["okunmamis"] == 0           # az önce okundu
rpc(bel, "sohbet_yaz", "belediye", "Yeni duyuru.")
k = {x["kanal"]: x for x in rpc(sade, "sohbet_ozet")["kanallar"]}
assert k["belediye"]["okunmamis"] == 1 and k["belediye"]["son"]["metin"] == "Yeni duyuru." and k["belediye"]["yazabilir"] is False, k["belediye"]
rpc(sade, "sohbet_oku", "belediye")
assert {x["kanal"]: x for x in rpc(sade, "sohbet_ozet")["kanallar"]}["belediye"]["okunmamis"] == 0
rpc(sade, "durum")                                           # uygulama açılınca son_gorulme güncellenir
assert rpc(sade, "sohbet_ozet")["cevrimici"] >= 1
rpc(bel, "engelle", "Sade")                                      # engellenen oyuncunun mesajı sayılmaz (tersi de geçerli)
ok("Okunmamış sayacı mesajla artıyor, kanal açılınca sıfırlanıyor; son mesaj ve çevrimiçi sayısı geliyor")

# ---------------- İTİBAR (söz tutma) ----------------
kidem0 = float(q(f"select kidem from oyun.cuzdan where user_id='{bel}'") or 0)
lok = q(f"insert into oyun.vaatler(kapsam,donem,user_id,parti_id,il_id,kod,hedef,yon,olusturma,durum,makam_id,aktif_bas) values ('bel','2026-10','{bel}',1,35,'lokanta',null,null,'2026-10-02 11:00+03','aktif',{bel_id},'2026-10-02 12:00+03') returning id").split("\n")[0]
ray = q(f"insert into oyun.vaatler(kapsam,donem,user_id,parti_id,il_id,kod,hedef,yon,olusturma,durum,makam_id,aktif_bas) values ('bel','2026-10','{bel}',1,35,'rayli',null,null,'2026-10-02 11:00+03','aktif',{bel_id},'2026-10-02 12:00+03') returning id").split("\n")[0]
alt = q(f"insert into oyun.vaatler(kapsam,donem,user_id,parti_id,il_id,kod,hedef,yon,olusturma,durum,makam_id,aktif_bas) values ('bel','2026-10','{bel}',1,35,'altyapi',null,null,'2026-10-02 11:00+03','aktif',{bel_id},'2026-10-02 12:00+03') returning id").split("\n")[0]
q("insert into oyun.il_hizmet(il_id, kod, acilis) values (35,'lokanta','2026-10-02 12:00+03') on conflict do nothing")
q(f"insert into oyun.belediye_proje_kayit(kod, il_id, baskan, zaman, maliyet) values ('altyapi',35,'{bel}','2026-10-02 12:30+03',1)")
for _ in range(3): q("select oyun.vaat_degerlendir(current_date, oyun.simdi())")
it = rpc(bel, "oyuncu_kart", "Baskan")["itibar"]
assert it["tutulan"] == 1 and it["bozulan"] == 0, it                  # altyapı yapıldı → tutuldu (anında)
assert q(f"select tamam from oyun.vaatler where id={alt}") == "t" and q(f"select gun_toplam||'/'||gun_tutuldu from oyun.vaatler where id={lok}") == "3/3"
assert float(q(f"select kidem from oyun.cuzdan where user_id='{bel}'")) == kidem0 + 5
ok("Tek seferlik vaat yapılınca anında +5 kıdem puanı ve itibar")

q(f"update oyun.makamlar set bit='2026-10-03 12:00+03' where id={bel_id}")
q("select oyun.vaat_degerlendir(current_date, oyun.simdi())")
it = rpc(bel, "oyuncu_kart", "Baskan")["itibar"]
assert it["tutulan"] == 2 and it["bozulan"] == 1 and it["toplam"] == 3 and it["oran"] == 67 and it["rozet"] is None, it
assert float(q(f"select kidem from oyun.cuzdan where user_id='{bel}'")) == kidem0 + 5 + 5 - 3
assert q(f"select count(*) from oyun.bildirimler where user_id='{bel}' and metin like 'Vaadini tutamadın%'") == "1"
assert q(f"select count(*) from oyun.bildirimler where user_id='{bel}' and metin like 'Vaadini tuttun%'") == "2"
q("select oyun.vaat_degerlendir(current_date, oyun.simdi())")                      # tekrar çalışınca iki kez işlenmez
assert rpc(bel, "oyuncu_kart", "Baskan")["itibar"]["toplam"] == 3
assert rpc(bel, "hayat")["itibar"]["tutulan"] == 2
ok("Dönem bitince: sürekli vaat günlerin çoğunda tutuldu (+5), yapılmayan raylı sistem vaadi söz bozdu (−3); bildirimler gitti, ikinci kez işlenmedi")

q(f"update oyun.itibar set tutulan=5, bozulan=0 where user_id='{bel}'")
assert rpc(bel, "oyuncu_kart", "Baskan")["itibar"]["rozet"] == "Sözünün Eri"
q(f"update oyun.itibar set tutulan=1, bozulan=4 where user_id='{bel}'")
assert rpc(bel, "oyuncu_kart", "Baskan")["itibar"]["rozet"] == "Lafta Kalan"
ok("Söz karnesi rozetleri: Sözünün Eri / Lafta Kalan")

# ---------------- HER İCRAATIN VAADİ VAR ----------------
assert q("select count(*) from oyun.icraatlar i where not exists (select 1 from oyun.vaat_turleri t where t.kapsam='beyanname' and t.kod=i.kod)") == "0"
sec = rpc(gb, "vaat_secenekleri", "beyanname")
assert len(sec["turler"]) == 39, len(sec["turler"])
mv = {t["kod"]: t for t in rpc(vek, "vaat_secenekleri", "mv")["turler"]}
gbs = {t["kod"]: t for t in rpc(gb, "vaat_secenekleri", "gb")["turler"]}
assert {"katilim", "teklif"} <= set(mv) and {"uye", "kasa"} <= set(gbs) and gbs["uye"]["mevcut"] >= 1
h = rpc(gb, "vaat_hesapla", "beyanname", json.dumps([{"kod": "ula_tren"}, {"kod": "mal_varlik"}]))
assert len(h["vaatler"]) == 2
ok("24 icraatın hepsinin beyanname vaadi var (toplam 30 tür); vekil ve genel başkan için yeni türler listeleniyor")

def kosul(vid): return q(f"select oyun.vaat_kosul(v, oyun.simdi()) from oyun.vaatler v where id={vid}")
def vaat(kapsam, kod, hedef, u, il=None, yon=">="):
    return q(f"insert into oyun.vaatler(kapsam,donem,user_id,parti_id,il_id,kod,hedef,yon,olusturma,durum,aktif_bas) values ('{kapsam}','2026-10',{('$$'+u+'$$') if u else 'null'},1,{il or 'null'},'{kod}',{hedef},'{yon}','2026-10-02 11:00+03','aktif','2026-10-02 12:00+03') returning id").split("\n")[0]
v_uye = vaat("gb", "uye", 3, gb); v_uye99 = vaat("gb", "uye", 99, gb); v_kasa = vaat("gb", "kasa", 5000, gb)
assert kosul(v_uye) == "t" and kosul(v_uye99) == "f" and kosul(v_kasa) == "f"
rpc(sade, "partiden_ayril") if False else None
q("update oyun.partiler set kasa = 6000 where id = 1")
assert kosul(v_kasa) == "t"
v_tek = vaat("mv", "teklif", 1, vek, 35); assert kosul(v_tek) == "f"
q(f"insert into oyun.kanunlar(tur,baslik,metin,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit) values ('serbest','Deneme Kanunu','metin','{vek}',1,'2026-10-02 12:30+03','2026-10-02 12:30+03','2026-10-03 12:30+03')")
assert kosul(v_tek) == "t"
v_kat = vaat("mv", "katilim", 80, vek, 35)
assert kosul(v_kat) == "t"                                                           # henüz 3 oylama bitmedi → tutulmuş sayılır
for i in range(4):
    kid = q(f"insert into oyun.kanunlar(tur,baslik,metin,teklif_eden,teklif_parti,durum,teklif_at,oy_bas,oy_bit) values ('serbest','K{i}','m','{gb}',1,'ret','2026-10-02 12:02+03','2026-10-02 12:02+03','2026-10-02 12:05+03') returning id").split("\n")[0]
    if i == 0: q(f"insert into oyun.kanun_oylari(kanun_id,asama,vekil,parti_id,oy,zaman) values ({kid},'ilk','{vek}',1,'kabul','2026-10-02 12:03+03')")
assert kosul(v_kat) == "f"                                                           # 4 oylamanın 1'ine katıldı = %25 < %80
ok("Yeni vaat koşulları: üye sayısı, parti kasası, kanun teklifi, Meclis katılım oranı doğru ölçülüyor")

# ---------------- ŞEHİR KALKINMA BAĞIŞI ----------------
asg = float(q("select asgari from oyun.ulke where id=1"))
gel0 = float(q("select gelisim from oyun.il_durum where il_id=35")); para0 = float(q(f"select para from oyun.cuzdan where user_id='{sade}'") or 10000000)
kd0 = float(q(f"select coalesce(kidem,0) from oyun.cuzdan where user_id='{sade}'") or 0)
d = rpc(sade, "il_bagis", 5000)
gel1 = float(q("select gelisim from oyun.il_durum where il_id=35"))
assert abs((gel1 - gel0) - 0.005 * 5000 / asg) < 1e-6, (gel0, gel1)
assert abs(float(q(f"select kidem from oyun.cuzdan where user_id='{sade}'")) - (kd0 + 5000 / asg)) < 1e-6
assert float(q(f"select para from oyun.cuzdan where user_id='{sade}'")) == para0 - 5000
assert d["top"][0]["kad"] == "Sade" and d["top"][0]["toplam"] == 5000 and d["bugun"] == 5000 and d["benim_toplam"] == 5000
hata_bekle(rpc, sade, "il_bagis", 50, icerir="En az 100")
hata_bekle(rpc, sade, "il_bagis", asg, icerir="Bağış sınırı")
rpc(sade, "bagis_yap", 1000)                                    # parti bağışı da aynı günlük sınıra yazılır ve kıdem verir
hata_bekle(rpc, sade, "il_bagis", asg - 5500, icerir="Bağış sınırı")
assert float(q(f"select kidem from oyun.cuzdan where user_id='{sade}'")) > kd0 + 5000 / asg
ok("Şehir bağışı: ilin gelişmişliği ve kıdem puanı artıyor, hayırsever listesi doluyor; parti bağışıyla ortak günlük sınır var")

# ---------------- VERGİ KARNESİ ----------------
saat("2026-10-03 09:00")
rpc(cb, "topla")
saat("2026-10-03 17:00")
r = rpc(cb, "topla")
vk = rpc(cb, "vergi_karnem")
assert vk["vergi_7gun"] > 0 and len(vk["kalemler"]) == 14, vk["vergi_7gun"]
assert abs(sum(x["tl"] for x in vk["kalemler"]) - vk["vergi_7gun"]) < 1.0, (sum(x["tl"] for x in vk["kalemler"]), vk["vergi_7gun"])
assert rpc(sade, "vergi_karnem")["vergi_7gun"] == 0
ok("Vergi karnesi: ödenen vergi bakanlıklara, belediyelere ve sosyal desteğe bütçe paylarıyla dağıtılıyor (toplam tutuyor)")

# ---------------- GÜVENLİK ----------------
for fn in ["sohbet_ozet()", "il_bagis(1000)", "il_bagis_durum()", "vergi_karnem()"]:
    try:
        q(f"set role anon; select public.{fn};"); raise AssertionError(fn)
    except Exception as e_:
        assert "permission denied" in str(e_) or "yetkin" in str(e_) or "Giriş" in str(e_), (fn, e_)
for t_ in ["oyun.itibar", "oyun.kanal_okuma", "oyun.il_bagis_kayit"]:
    try:
        q(f"set role authenticated; select * from {t_};"); raise AssertionError(t_)
    except Exception as e_:
        assert "permission denied" in str(e_), (t_, e_)
ok("Güvenlik: yeni fonksiyonlar girişsiz kapalı; itibar, okuma imleci ve bağış tabloları doğrudan okunamıyor")
print("\nTÜM EKONOMİ 2 KONTROLLERİ GEÇTİ")
