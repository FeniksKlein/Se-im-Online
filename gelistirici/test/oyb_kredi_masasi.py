"""Oyuncu bankası kredi masası (migrations/20261011_oyuncu_banka_kredi_masasi.sql):
hesap zorunluluğu, sahibin paketleri (vade/taksit/faiz/otomatik), çekmeden önce ödeme planı,
otomatik kredi, onaylı başvuru, banka sahibinin teklifi, mali bilgi talebi, erken kapama, gecikmede dava.
Çalıştır: ../kur_yerel.sh, banka migration'ları, bu migration; sonra python3 oyb_kredi_masasi.py"""
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
q("""update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, baslangic_para=10000""")
saat("2026-10-02 12:00")

def oyuncu(kad, il=35, para=None):
    u = kullanici_ekle(f"{kad}@k.com"); rpc(u, "profil_olustur", kad, il)
    if para is not None: q(f"select oyun.cuzdanim('{u}'); update oyun.cuzdan set para={para} where user_id='{u}'")
    return u
def para(u): return int(float(q(f"select para from oyun.cuzdan where user_id='{u}'")))
def kasa(b): return int(float(q(f"select kasa from oyun.sirketler where id={b}")))

sahip = oyuncu("BankaSahibi", para=0)
ali = oyuncu("AliMusteri", para=1000)
veli = oyuncu("VeliMusteri", para=1000)
banka = int(q(f"""insert into oyun.sirketler(ad, sektor, kurucu, sermaye, kasa, aktif, banka_faiz, banka_kredi_faiz)
  values ('Ege Katılım Bankası', 'banka', '{sahip}', 1000000, 1000000, true, 1.5, 1) returning id"""))
q(f"insert into oyun.sirket_ortaklari(sirket_id, user_id, pay) values ({banka}, '{sahip}', 100)")

# --- Paket: yalnız yönetici, doğrulamalar
hata_bekle(rpc, ali, "oyb_paket_kaydet", banka, None, "Hızlı", 10, 3, 5, 1000, 50000, True, 900, True, icerir="yetkin yok")
hata_bekle(rpc, sahip, "oyb_paket_kaydet", banka, None, "Hızlı", 10, 7, 5, 1000, 50000, True, 900, True, icerir="eşit bölünmeli")
hata_bekle(rpc, sahip, "oyb_paket_kaydet", banka, None, "Hızlı", 10, 5, 25, 1000, 50000, True, 900, True, icerir="%0 – %20")
oto = rpc(sahip, "oyb_paket_kaydet", banka, None, "Hızlı ihtiyaç", 10, 5, 4, 1000, 50000, True, 900, True)["id"]
onayli = rpc(sahip, "oyb_paket_kaydet", banka, None, "Büyük yatırım", 30, 3, 9, 5000, 500000, False, 1000, True)["id"]
ok("Banka sahibi paket tanımlar: vade (gün), taksit, faiz, tutar aralığı, asgari not, otomatik/onaylı")

# --- Gelir yoksa limit 0: test için risk özetini sabit bir limitle değiştir (yalnız yerel)
q("""create or replace function oyun.oyb_kredi_limit(u uuid, p_saat integer) returns jsonb language sql stable as $$
  select jsonb_build_object('azami_kredi', 40000, 'kredi_notu', coalesce((select kredi_notu from oyun.banka_musteri where user_id=u),1100), 'neden', 'test') $$""")

# --- Hesap zorunluluğu
p = rpc(ali, "oyb_kredi_plan", oto, 20000)
assert not p["uygun"] and "hesap" in p["engel"], p
hata_bekle(rpc, ali, "oyb_kredi_cek", oto, 20000, icerir="hesap")
hata_bekle(q, f"insert into oyun.oyb_kredi(banka_id, borclu, anapara, saat, oran, toplam, kalan, paket_id) values ({banka}, '{ali}', 5000, 240, 1, 5050, 5050, {oto})", icerir="hesap açmalısın")
rpc(ali, "oyb_hesap_ac", banka)
hata_bekle(rpc, ali, "oyb_hesap_ac", banka, icerir="zaten")
assert "yeni müşteri" in q(f"select metin from oyun.bildirimler where user_id='{sahip}' order by id desc limit 1")
ok("Hesabı olmayan kredi çekemez/başvuramaz; hesap açılınca banka sahibine bildirim gider")

# --- Ödeme planı çekmeden önce
p = rpc(ali, "oyb_kredi_plan", oto, 20000)
assert p["uygun"] and p["toplam"] == 20800 and p["faiz_tutari"] == 800 and len(p["taksitler"]) == 5, p
assert sum(t["tutar"] for t in p["taksitler"]) == 20800 and p["taksit_araligi_saat"] == 48
assert not rpc(ali, "oyb_kredi_plan", oto, 60000)["uygun"]          # paket üst sınırı
assert "en çok" in rpc(ali, "oyb_kredi_plan", oto, 45000)["engel"]   # gelir limiti (40.000) — paket 50.000'e izin verse de
ok("Çekmeden önce ödeme planı: 20.000 ₺ → 5 taksit × 4.160 ₺, 2 günde bir, toplam 20.800 ₺; limit ve paket sınırı gösterilir")

# --- Otomatik kredi
k0 = kasa(banka)
r = rpc(ali, "oyb_kredi_cek", oto, 20000)
assert r["durum"] == "aktif" and para(ali) == 21000 and kasa(banka) == k0 - 20000
assert q(f"select count(*) from oyun.oyb_kredi_taksit where kredi_id={r['id']}") == "5"
assert "otomatik kredi" in q(f"select metin from oyun.bildirimler where user_id='{sahip}' order by id desc limit 1")
hata_bekle(rpc, ali, "oyb_kredi_cek", oto, 1000, icerir="diğer oyuncu bankası kredini")
ok("Otomatik pakette kredi anında: banka kasasından düşer, cüzdana geçer, taksit planı yazılır, sahibe bildirim")

# --- Erken kapama (geçen süre kadar faiz + %1)
saat("2026-10-04 12:00")   # 10 günlük vadenin %20'si geçti; ilk taksit vadesi doldu
m = rpc(ali, "oyb_kredi_masasi", banka)
ek = m["kredilerim"][0]["erken_kapama"]
assert ek["tutar"] == 20000 + 160 + 200 and ek["indirim"] == 20800 - 20360, ek
rpc(ali, "oyb_kredi_erken_kapat", r["id"])
assert para(ali) == 21000 - 20360 and kasa(banka) == k0 + 360
assert q(f"select durum||'/'||kalan::int||'/'||erken_kapama from oyun.oyb_kredi where id={r['id']}") == "odendi/0/true"
assert q(f"select count(*) from oyun.oyb_kredi_taksit where kredi_id={r['id']} and odenen<tutar") == "0"
ok("Erken kapama: 2 günde 20.360 ₺ (anapara + geçen sürenin faizi 160 + %1 ücret 200); 440 ₺ indirim, taksitler kapanır")

# --- Onaylı paket: başvuru → sahip onayı
rpc(veli, "oyb_hesap_ac", banka)
q(f"insert into oyun.banka_musteri(user_id, kredi_notu, son_faiz) values ('{veli}', 1200, now()) on conflict (user_id) do update set kredi_notu=1200")
r2 = rpc(veli, "oyb_kredi_cek", onayli, 30000)
assert r2["durum"] == "basvuru" and para(veli) == 1000
assert "başvurusu" in q(f"select metin from oyun.bildirimler where user_id='{sahip}' order by id desc limit 1")
yon = rpc(sahip, "oyb_kredi_masasi", banka)
assert any(k["id"] == r2["id"] and k["durum"] == "basvuru" for k in yon["banka_kredileri"])
rpc(sahip, "oyb_kredi_karar", r2["id"], True)
assert para(veli) == 31000
assert q(f"select count(*) from oyun.oyb_kredi_taksit where kredi_id={r2['id']}") == "3"
ok("Onaylı pakette başvuru sahibin kredi masasına düşer; onaylanınca 30 günlük 3 taksitli kredi kullandırılır")

# --- Gecikme → dava (gelir haczi)
saat("2026-10-15 00:00")   # ilk taksit 10 gün sonra (12.10 12:00) + 12 saat ek süre geçti
yon = rpc(sahip, "oyb_kredi_masasi", banka)
kr = next(k for k in yon["banka_kredileri"] if k["id"] == r2["id"])
assert kr["dava_acilabilir"] and kr["geciken"] > 0, kr
d = rpc(sahip, "oyb_icra_baslat", r2["id"], "gelir", "Borçlu ilk taksiti vadesinde ödemedi, gelirine haciz istiyoruz.")
assert d["durum"] == "acik"
assert rpc(veli, "oyb_kredi_masasi", banka)["kredilerim"][0]["durum"] == "gecikmis"
ok("Taksit 12 saat gecikince sahip Adliye'de icra (gelir haczi) davası açabilir; borçlu kredisini gecikmiş görür")

# --- Banka sahibinin inisiyatifi: mali bilgi talebi + teklif
hata_bekle(rpc, sahip, "oyb_hesap_bilgi_iste", banka, "Yok", "{maas}", icerir="hesabı yok")
rpc(sahip, "oyb_hesap_bilgi_iste", banka, "AliMusteri", "{maas,mulk,gunluk}")
hata_bekle(rpc, sahip, "oyb_hesap_bilgi_dokum", banka, "AliMusteri", icerir="izin vermedi")
assert rpc(ali, "oyb_kredi_masasi", banka)["bilgi_talebi"]["durum"] == "talep"
rpc(ali, "oyb_hesap_bilgi_yanit", banka, True, "{maas,gunluk}")
dk = rpc(sahip, "oyb_hesap_bilgi_dokum", banka, "AliMusteri")
assert set(dk["izinli"]) == {"maas", "gunluk"} and "maas" in dk["dokum"] and "mulk" not in dk["dokum"] and "son_gelirler" in dk["dokum"]
ok("Sahip hesap sahibinden gelir/maaş dökümü/gayrimenkul ister; oyuncu kısmen izin verir, sahip yalnız izinli kısmı görür")

hata_bekle(rpc, ali, "oyb_kredi_teklif_ver", banka, "VeliMusteri", 5000, 7, 7, 3, None, icerir="yetkin yok")
t = rpc(sahip, "oyb_kredi_teklif_ver", banka, "AliMusteri", 15000, 6, 3, 3, "Düzenli müşterimize özel")["id"]
mt = rpc(ali, "oyb_kredi_masasi", banka)["tekliflerim"]
assert mt[0]["id"] == t and mt[0]["plan"]["toplam"] == 15450 and len(mt[0]["plan"]["taksitler"]) == 3
a0 = para(ali)
rpc(ali, "oyb_kredi_teklif_yanit", t, True)
assert para(ali) == a0 + 15000
assert q(f"select durum from oyun.oyb_kredi_teklifi where id={t}") == "kabul"
ok("Sahip hesap sahibine kendi şartlarıyla kredi teklif eder; oyuncu planı görüp kabul edince kredi kullandırılır")

# --- Hesap kapatma kuralları
hata_bekle(rpc, ali, "oyb_hesap_kapat", banka, icerir="kredin kapanmadan")
# --- Kasa sınırı
k = kasa(banka)
q(f"update oyun.sirketler set kasa=1000 where id={banka}")
yeni = oyuncu("CanMusteri", para=0); rpc(yeni, "oyb_hesap_ac", banka)
assert "kasası" in rpc(yeni, "oyb_kredi_plan", oto, 5000)["engel"]
q(f"update oyun.sirketler set kasa={k} where id={banka}")
ok("Kredi, banka kasasının (mevduat güvencesi ayrıldıktan sonra) verebildiği kadarla sınırlı")

print(f"\noyb_kredi_masasi: {len(TAMAM)} kontrol tamam")
