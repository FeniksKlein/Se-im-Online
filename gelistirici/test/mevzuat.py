"""Mevzuat: kararname/kanun/anayasa hiyerarşisi, oyunculara etkiler, anayasa değişikliği, halk oylaması, belediye kararları.
Çalıştır: ../kur_yerel.sh && python3 mevzuat.py"""
import json
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
j = json.dumps
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000000;")
saat("2026-10-02 12:00")

def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
def makam(tur, u, il=None, parti=1, bakanlik=None):
    q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,bas) values ('{tur}','{u}',{il or 'null'},{parti},{('$$'+bakanlik+'$$') if bakanlik else 'null'},'2026-10-02 11:00+03')")
def duz(kod): return float(q(f"select oyun.duz('{kod}')"))
def kaynak(kod): return q(f"select coalesce((select kaynak from oyun.duzenlemeler where kod='{kod}'),'varsayilan')")
def para(u): return int(float(q(f"select para from oyun.cuzdan where user_id='{u}'")))
def hareket(u, tur): return q(f"select coalesce(sum(tutar),0)::bigint from oyun.hesap_hareket where user_id='{u}' and tur='{tur}'")
def kararname(cb, tur, veri, baslik=None): return rpc(cb, "kararname_cikar", tur, baslik, None, j(veri))

cb = oyuncu("Cumhur", 6, 1); makam("cb", cb)
V = [oyuncu(f"Vekil{i}", 35, 1 if i < 3 else 2) for i in range(1, 6)]
for v in V: makam("mv", v, 35, parti=1 if V.index(v) < 2 else 2)
zengin = oyuncu("Zengin", 34, 1); sakin = oyuncu("Sakin", 34, 2); baskan = oyuncu("Baskan", 34, 1); makam("bel", baskan, 34)
gezgin = oyuncu("Gezgin", 6, 2)
sade = oyuncu("Sade", 6)

# ---------------- 1) KARARNAME İLE KURAL ----------------
hata_bekle(kararname, sade, "duzenleme", {"kod": "servet_vergisi", "deger": 2}, icerir="cumhurbaşkanında")
hata_bekle(kararname, cb, "duzenleme", {"kod": "servet_vergisi", "deger": 20}, icerir="arasında")
hata_bekle(kararname, cb, "duzenleme", {"kod": "emlak", "deger": 50}, icerir="Geçersiz düzenleme")
r = kararname(cb, "duzenleme", {"kod": "servet_vergisi", "deger": 2})
assert duz("servet_vergisi") == 2 and kaynak("servet_vergisi") == "kararname"
assert "Servet vergisi" in q("select baslik from oyun.gazete order by id desc limit 1")
k_kumbara = kararname(cb, "duzenleme", {"kod": "kumbara_saat", "deger": 12})
kararname(cb, "duzenleme", {"kod": "vekil_kesinti", "deger": 20})
hata_bekle(kararname, cb, "duzenleme", {"kod": "seri_tavan", "deger": 40}, icerir="en fazla 3")
p0 = para(zengin)
rpc(zengin, "topla")
kesilen = -int(hareket(zengin, "servet"))
assert kesilen == (p0 - 250000) * 2 // 1000, (kesilen, p0)
assert rpc(zengin, "hayat")["kumbara"]["kapasite"] == 12
ok(f"Cumhurbaşkanı kararnameyle servet vergisi (‰2), 12 saatlik kumbara ve devamsızlık kesintisi getirdi; zengin oyuncudan {kesilen:,} ₺ servet vergisi kesildi")

# ---------------- 2) MECLİS: KANUN, ANAYASA TEKLİFLERİ ----------------
saat("2026-10-02 12:10")
hata_bekle(rpc, sade, "kanun_teklif", "duzenleme", "Servet vergisi kanunu", "Servet vergisi binde bire iner.", j({"kod": "servet_vergisi", "deger": 1}), icerir="milletvekilleri")
k1 = rpc(V[0], "kanun_teklif", "duzenleme", "Servet Vergisi Kanunu", "Servet vergisi binde bire iner.", j({"kod": "servet_vergisi", "deger": 1}))["id"]
hata_bekle(rpc, V[1], "kanun_teklif", "anayasa", "Geçersiz", "Geçersiz madde metni.", j({"madde": "yok"}), icerir="Geçersiz anayasa")
a1 = rpc(V[1], "kanun_teklif", "anayasa", "Seçime Katılım Anayasa Değişikliği", "Sandığa gitmek vatandaşlık görevidir.", j({"madde": "duzenleme", "kod": "oy_cezasi", "deger": 1000}))["id"]
a2 = rpc(V[3], "kanun_teklif", "anayasa", "Kararname Yetkisinin Sınırlanması", "Yürütme Meclis'e hesap versin.", j({"madde": "kararname_sinir", "deger": 1}))["id"]
a3 = rpc(V[4], "kanun_teklif", "anayasa", "Vergi Tavanı Değişikliği", "Vergi tavanı yüzde kırk olsun.", j({"madde": "vergi_tavani", "deger": 40}))["id"]
ip = rpc(V[2], "kanun_teklif", "iptal", "Kumbara Kararının İptali", "Esnek mesai kararı iptal edilmeli.", j({"kararname_id": int(q(f"select id from oyun.kararnameler where no={k_kumbara['no']}"))}))["id"]
rpc(V[2], "kanun_imza", a1)
for v in V[:3]: rpc(v, "kanun_imza", a2)
hata_bekle(rpc, sade, "kanun_imza", a1, icerir="milletvekilleri")
hata_bekle(rpc, V[1], "kanun_imza", a1, icerir="Teklif sahibinin")
hata_bekle(rpc, V[0], "kanun_imza", k1, icerir="yalnızca anayasa")
d = rpc(V[0], "kanun_detay", a1)
assert d["imza_yeter"] == 2 and d["uc_bes"] == 3 and d["iki_uc"] == 4 and "anayasaya bağlanır" in d["anayasa_aciklama"]
ok("Vekiller kanun ve anayasa değişikliği teklifi veriyor; anayasa teklifi için vekillerin üçte biri imza veriyor")

# ---------------- 3) DÜZENLEME KARARNAMESİ: HOŞ GELDİN HİBESİ, TAHVİL, ÖZELLEŞTİRME ----------------
saat("2026-10-03 09:00")
kararname(cb, "duzenleme", {"kod": "yeni_hibe", "deger": 5000})
yeni = oyuncu("YeniGelen", 6)
assert para(yeni) == 10000000 + 5000 and hareket(yeni, "hibe") == "5000"
hz = float(q("select hazine from oyun.ulke"))
kararname(cb, "tahvil", {"miktar": 50})
assert abs(float(q("select hazine from oyun.ulke")) - hz - 50) < 0.01
b = qj("select row_to_json(b) from oyun.borclar b")
assert b["kalan_gun"] == 60 and abs(b["gunluk"] - 50 * (1 + b["faiz"] / 100) / 60) < 0.001
assert qj("select oyun.ulke_hesap(u) from oyun.ulke u")["borc"] > 0
kararname(cb, "ozellestirme", {"miktar": 20})
assert float(q("select kamu_varlik from oyun.ulke")) == 380
ok(f"Hoş geldin hibesi yeni oyuncuya 5.000 ₺ yattı; tahvil (faiz %{b['faiz']}, 60 günde geri ödenir) ve özelleştirme hazineye para kazandırdı")

# ---------------- 4) OYLAMA ----------------
saat("2026-10-03 12:30")
assert q(f"select durum from oyun.kanunlar where id={a3}") == "ret"     # 1 imza, en az 2 gerekliydi
assert "imza" in q(f"select sonuc_metin from oyun.kanunlar where id={a3}")
for v in V[:4]: rpc(v, "kanun_oy", k1, "kabul"); rpc(v, "kanun_oy", ip, "kabul"); rpc(v, "kanun_oy", a2, "kabul")
for v in V[:3]: rpc(v, "kanun_oy", a1, "kabul")
rpc(V[3], "kanun_oy", a1, "ret")
d = rpc(V[0], "kanun_detay", a1)
assert d["oylar"]["ilk"]["kabul"] == 3 and d["oylar"]["ilk"]["liste"] == [] and len(d["oylar"]["imza"]["liste"]) == 2
ok("Anayasa teklifi yeterli imza toplamazsa düşüyor; anayasa oylaması gizli (yalnız sayılar görünüyor, imzalar açık)")

saat("2026-10-04 12:20")
assert q(f"select durum from oyun.kanunlar where id={k1}") == "cb_onayinda"
assert q(f"select durum from oyun.kanunlar where id={a1}") == "halkoylamasinda"
assert q(f"select durum from oyun.kanunlar where id={a2}") == "cb_onayinda"
ref = qj(f"select row_to_json(r) from oyun.referandumlar r where kanun_id={a1}")
assert ref["oy_bas"].startswith("2026-10-06T05:00") or "2026-10-06 08:00" in q(f"select oy_bas at time zone 'Europe/Istanbul' from oyun.referandumlar where id={ref['id']}")
hata_bekle(rpc, cb, "kanun_cb_karar", a2, "veto", "olmaz", icerir="veto edilemez")
rpc(cb, "kanun_cb_karar", k1, "onay", None)
rpc(cb, "kanun_cb_karar", ip, "onay", None)
rpc(cb, "kanun_cb_karar", a2, "onay", None)
assert duz("servet_vergisi") == 1 and kaynak("servet_vergisi") == "kanun"
assert duz("kumbara_saat") == 8 and kaynak("kumbara_saat") == "varsayilan"
assert q("select deger from oyun.anayasa where kod='kararname_sinir'") == "1"
assert q("select tur from oyun.gazete where baslik like '%Kararname Yetkisinin%'") == "anayasa"
ok("Beşte üç → halk oylaması; üçte iki → cumhurbaşkanı yayımladı (anayasa veto edilemez); kanun onaylandı; kararname kanunla iptal edilince kural eski hâline döndü")

hata_bekle(kararname, cb, "duzenleme", {"kod": "servet_vergisi", "deger": 3}, icerir="kanunla düzenlenmiş")
mz = rpc(cb, "mevzuat")
sv = next(x for x in mz["kurallar"] if x["kod"] == "servet_vergisi")
assert sv["kaynak"] == "kanun" and sv["cb_engel"] and not sv["kanun_engel"] and len(mz["kurallar"]) == 7 and len(mz["il_kurallar"]) == 2
ok("Normlar hiyerarşisi: kanunla düzenlenen konuda cumhurbaşkanı kararname çıkaramıyor")

# devamsızlık kesintisi: Vekil5 3 oylamanın hiçbirine katılmadı → %20 × 1 = %20
assert float(rpc(V[4], "hayat")["kumbara"]["vekil_kesinti"]) == 20
assert float(rpc(V[0], "hayat")["kumbara"]["vekil_kesinti"]) == 0
mv_maas = float(qj(f"select oyun.gelir_hesap('{V[4]}', oyun.simdi())")["saatlik"]["makam"])
tam = float(q("select oyun.makam_maasi('mv', 35::smallint) / 720"))
assert abs(mv_maas - tam * 0.8) < 0.05, (mv_maas, tam)
ok("Meclis devamsızlık kesintisi: oylamalara katılmayan vekilin makam maaşı %20 düştü, katılanınki tam")

# ---------------- 5) ANAYASAL KARARNAME SINIRI, SİYASİ KATILIM FONU ----------------
saat("2026-10-05 09:00")
kararname(cb, "duzenleme", {"kod": "aday_destek", "deger": 50})
hata_bekle(kararname, cb, "duzenleme", {"kod": "seri_tavan", "deger": 40}, icerir="en fazla 1")
kasa0 = float(q("select kasa from oyun.partiler where id=2"))
ucret = float(q(f"select oyun.aday_ucreti(2, 'mv_on', 6::smallint)"))
q(f"select oyun.aday_ucreti_al(p, 'mv_on', oyun.simdi()) from oyun.profiller p where id='{gezgin}'")
assert int(hareket(gezgin, "aday")) == -round(ucret / 2) and abs(float(q("select kasa from oyun.partiler where id=2")) - kasa0 - ucret) < 1
ok("Anayasa günlük kararname sınırını 1'e indirdi; siyasi katılım fonu aday ücretinin yarısını ödedi, parti kasasına tamamı girdi")

# ---------------- 6) BELEDİYE KARARLARI ----------------
hata_bekle(rpc, sade, "belediye_duzenle", "emlak", 100, icerir="belediye başkanlarındadır")
pan = rpc(baskan, "belediye_duzenle", "emlak", 100)
assert next(x for x in pan["kurallar"] if x["kod"] == "emlak")["deger"] == 100
g0 = float(q("select oyun.il_gelir(34::smallint)"))
assert next(x for x in pan["kurallar"] if x["kod"] == "emlak")["gunluk_gelir"] > 0
hata_bekle(rpc, baskan, "belediye_duzenle", "emlak", 120, icerir="24 saatte")
hata_bekle(rpc, baskan, "belediye_duzenle", "hosgeldin", 50000, icerir="arasında")
rpc(baskan, "belediye_duzenle", "hosgeldin", 5000)
q("update oyun.il_durum set kasa = 5 where il_id = 34")
p0 = para(gezgin)
q(f"update oyun.profiller set il_id = 34 where id = '{gezgin}'")
assert para(gezgin) == p0 + 5000
q(f"update oyun.profiller set il_id = 6 where id = '{gezgin}'"); q(f"update oyun.profiller set il_id = 34 where id = '{gezgin}'")
assert para(gezgin) == p0 + 5000                        # her ilde bir kez
assert abs(float(q("select kasa from oyun.il_durum where il_id=34")) - (5 - 5000 * 2000 / 1e9)) < 1e-6
saat("2026-10-06 07:00")
p1 = para(sakin); rpc(sakin, "topla")
assert hareket(sakin, "emlak") == str(-round(100 * float(q("select endeks from oyun.ulke")))), hareket(sakin, "emlak")
k0 = float(q("select kasa from oyun.il_durum where il_id=34")); gl0 = float(q("select gelisim from oyun.il_durum where il_id=34"))
pan = rpc(baskan, "belediye_yatirim", "imar_barisi")
assert float(q("select kasa from oyun.il_durum where il_id=34")) > k0 and float(q("select gelisim from oyun.il_durum where il_id=34")) < gl0
assert len([y for y in pan["yatirimlar"] if y["tur"] == "gelir"]) == 2
ok("Belediye: emlak vergisi hemşehrinin cüzdanından kesildi ve il gelirini artırdı; hoş geldin desteği yeni gelene bir kez ödendi; imar barışı kasaya gelir getirdi, gelişmişliği düşürdü")

# ---------------- 7) HALK OYLAMASI ----------------
rid = ref["id"]
hata_bekle(rpc, zengin, "referandum_oy", rid, "evet", icerir="Sandık şu anda kapalı")
saat("2026-10-06 09:00")
gec = oyuncu("GecKalan", 6)
assert "kütüğü" in rpc(gec, "referandum_detay", rid)["engel"]
hata_bekle(rpc, gec, "referandum_oy", rid, "evet", icerir="kütüğü")
for u in [zengin, sakin, baskan]: rpc(u, "referandum_oy", rid, "evet")
rpc(V[3], "referandum_oy", rid, "hayir")
hata_bekle(rpc, zengin, "referandum_oy", rid, "hayir", icerir="zaten oy")
hata_bekle(rpc, cb, "referandum_oy", rid, "belki", icerir="Geçersiz")
d = rpc(sade, "referandum_detay", rid)
assert d["katilim"] == 4 and d["iller"] is None and d["oy_kullandim"] is False
assert rpc(zengin, "referandum_detay", rid)["oy_kullandim"] is True
cols = q("select string_agg(column_name, ',') from information_schema.columns where table_schema='oyun' and table_name='referandum_katilim'")
assert "oy" not in cols.split(","), cols                   # oy gizli: kimin ne dediği hiçbir yerde tutulmuyor
q(f"update oyun.profiller set son_gorulme = '2026-10-06 09:00+03' where id in ('{sade}','{gezgin}','{V[4]}')")
saat("2026-10-06 20:05")
d = rpc(sade, "referandum_detay", rid)
assert d["durum"] == "sonuclandi" and d["sonuc"] == "kabul" and d["evet"] == 3 and d["hayir"] == 1
assert {x["ad"]: (x["evet"], x["hayir"]) for x in d["iller"]} == {"İstanbul": (3, 0), "İzmir": (0, 1)}, d["iller"]
assert duz("oy_cezasi") == 1000 and kaynak("oy_cezasi") == "anayasa"
assert q(f"select durum from oyun.kanunlar where id={a1}") == "yururlukte"
assert hareket(sade, "ceza") == "0"          # ceza bu oylamayla geldi: geriye yürümez
ok("Halk oylaması: sandık 08:00-20:00, kütük sonrası açılan hesap oy kullanamadı, oy gizli, %75 Evet ile kabul; il il sonuç; yeni ceza geriye yürümedi")

hata_bekle(rpc, V[0], "kanun_teklif", "duzenleme", "Ceza kaldırılsın", "Ceza kaldırılsın diyoruz.", j({"kod": "oy_cezasi", "deger": 0}), icerir="anayasada")
hata_bekle(kararname, cb, "duzenleme", {"kod": "oy_cezasi", "deger": 0}, icerir="anayasada")
ok("Anayasaya bağlanan kural kanunla da kararnameyle de değiştirilemiyor")

# ---------------- 8) SEÇİMDE OY KULLANMAYANA CEZA ----------------
sid = q("""insert into oyun.secimler(tur,donem,oy_bas,oy_bit,sonuc_at,goreve_bas,durum)
           values ('bel','2026-90','2026-10-07 08:00+03','2026-10-07 17:00+03','2026-10-07 18:00+03','2026-12-01 00:00+03','sonuclandi') returning id""").split("\n")[0]
q(f"insert into oyun.adaylar(secim_id,user_id,parti_id,il_id) values ({sid},'{baskan}',1,34)")
q(f"insert into oyun.oylar(secim_id,secmen,il_id,parti_id) values ({sid},'{sakin}',34,1)")
q(f"update oyun.profiller set son_gorulme = '2026-10-07 09:00+03' where id in ('{sakin}','{gezgin}','{yeni}')")
c_gez, c_sak, c_yeni = hareket(gezgin, "ceza"), hareket(sakin, "ceza"), hareket(yeni, "ceza")
saat("2026-10-07 17:30")
assert int(hareket(gezgin, "ceza")) == int(c_gez) - 1000      # İstanbul'da, oy kullanmadı
assert hareket(sakin, "ceza") == c_sak                       # oy kullandı
assert hareket(yeni, "ceza") == c_yeni                       # Ankara: o ilde aday yoktu
saat("2026-10-07 17:35")
assert int(hareket(gezgin, "ceza")) == int(c_gez) - 1000      # bir kez
ok("Seçimde oy kullanabilecekken kullanmayana bir kez ceza; oy kullanan ve ilinde aday olmayan cezasız")

# ---------------- 9) VAATLER ----------------
r = rpc(cb, "vaat_hesapla", "beyanname", j([{"kod": "servet_vergisi", "hedef": 3}, {"kod": "yeni_hibe", "hedef": 20000}]))
assert r["vaatler"][0]["gunluk"] < 0 and r["vaatler"][1]["gunluk"] > 0
sec = rpc(cb, "vaat_secenekleri", "beyanname")
assert next(x for x in sec["turler"] if x["kod"] == "servet_vergisi")["mevcut"] == 1
r = rpc(baskan, "vaat_hesapla", "bel", j([{"kod": "emlak", "hedef": 0}, {"kod": "hosgeldin", "hedef": 10000}]), 34)
assert r["vaatler"][0]["gunluk"] > 0
vid = q(f"insert into oyun.vaatler(kapsam,donem,user_id,il_id,kod,hedef,yon,olusturma,durum,aktif_bas) values ('bel','x','{baskan}',34,'emlak',50,'<=',now(),'aktif',now()) returning id").split("\n")[0]
assert q(f"select oyun.vaat_kosul(v, oyun.simdi()) from oyun.vaatler v where id={vid}") == "f"
vid2 = q(f"insert into oyun.vaatler(kapsam,donem,user_id,kod,hedef,yon,olusturma,durum,aktif_bas) values ('mv','x','{V[0]}','servet_vergisi',1,'<=',now(),'aktif','2026-10-01') returning id").split("\n")[0]
assert q(f"select oyun.vaat_kosul(v, oyun.simdi()) from oyun.vaatler v where id={vid2}") == "t"
vid3 = q(f"insert into oyun.vaatler(kapsam,donem,user_id,kod,olusturma,durum,aktif_bas) values ('mv','x','{V[2]}','anayasa_imza',now(),'aktif','2026-10-01') returning id").split("\n")[0]
assert q(f"select oyun.vaat_kosul(v, oyun.simdi()) from oyun.vaatler v where id={vid3}") == "t"
ok("Vaatler: servet vergisi gelir getiren vaat olarak bütçeyi rahatlatıyor; belediye emlak/hoş geldin vaatleri ve vekilin 'kanuna oy vereceğim', 'imza vereceğim' vaatleri ölçülüyor")

# ---------------- 10) BAKAN ARAMA ----------------
l = rpc(cb, "bakan_adaylari", "vek")
assert len(l) == 5 and all(not x["uygun"] and "milletvekilliği" in (x["engel"] or "") for x in l), l[:1]
l = rpc(cb, "bakan_adaylari", "")
assert any(x["kad"] == "Sade" and x["uygun"] for x in l)
hata_bekle(rpc, sade, "bakan_adaylari", "", icerir="cumhurbaşkanında")
rpc(cb, "bakan_ata", "adalet", "Sade"); rpc(cb, "bakan_gorevden_al", "adalet"); rpc(cb, "bakan_ata", "adalet", "Zengin")
assert q("select oyun.kad(user_id) from oyun.makamlar where tur='bakan' and bakanlik='adalet' and bit is null") == "Zengin"
ok("Cumhurbaşkanı oyuncu arayıp uygun olanı görüyor; istediği an atıyor, görevden alıp başkasını atıyor")

# ---------------- GÜVENLİK ----------------
for fn in ["mevzuat()", "referandumlar(10)", "referandum_oy(1,'evet')", "kanun_imza(1,true)", "belediye_duzenle('emlak',1)", "bakan_adaylari('a')", "mevzuat_onizle('servet_vergisi',1)"]:
    try:
        q(f"set role anon; select public.{fn};"); raise AssertionError(fn)
    except Exception as e_:
        assert "permission denied" in str(e_), (fn, e_)
for tb in ["referandum_sandik", "referandum_katilim", "duzenlemeler"]:
    try:
        q(f"set role authenticated; select * from oyun.{tb};"); raise AssertionError(tb)
    except Exception as e_:
        assert "permission denied" in str(e_), (tb, e_)
ok("Güvenlik: yeni fonksiyonlar girişsiz kapalı; sandık ve katılım tabloları doğrudan okunamıyor")
print("\nTÜM MEVZUAT KONTROLLERİ GEÇTİ")
