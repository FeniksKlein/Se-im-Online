"""Kalıcılık: güncellemeler oyunu asla sıfırlamaz/bozmaz.
 1) Gerçek kurulum dosyası (dist/supabase-kurulum.sql) ile kurulan, oynanmış bir oyun
 2) Aynı güncelleme iki kez uygulanınca bütün oyuncu verisi bayt bayt aynı kalır, yedek alınır
 3) Yeni makam türü + yeni tablo + yeni sütun ekleyen bir güncelleme: eski makamlar ve kişiler değişmez
 4) Oyuncu verisini değiştiren hatalı güncelleme kendiliğinden geri alınır
 5) TRUNCATE / DROP TABLE / DROP COLUMN engellenir
 6) Sahibin araçları: yedeğe dönüş ve sıfırlama (yalnızca onay cümlesiyle)
Çalıştır: python3 kalicilik.py   (oyun_test veritabanını kendisi kurar)"""
import json, subprocess, os
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle, SqlHata

def ok(m): print("  ✓", m)
KOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PSQL = ["psql", "-h", "/tmp", "-U", "postgres", "-q"]

def kur(tam=False):
    """Supabase'deki gibi kurulum dosyasını çalıştır. tam=False: zamanlayıcı kısmı hariç (o kısım test saatini gerçek saate
    çevirip motoru bir tur çalıştırır; oyun ilerlemesi güncellemenin etkisiyle karışmasın diye ayrı tutulur)."""
    yol = os.path.join(KOK, "dist/supabase-kurulum.sql")
    if not tam:
        metin = open(yol).read(); yol = "/tmp/kalicilik_guncelleme.sql"
        open(yol, "w").write(metin[:metin.index("\ncommit;") + len("\ncommit;")] + "\n")
    r = subprocess.run(PSQL + ["-d", "oyun_test", "-f", yol], capture_output=True, text=True)
    hatalar = [l for l in r.stderr.splitlines() if "ERROR" in l and "cron" not in l]
    return hatalar

subprocess.run(PSQL + ["-c", "drop database if exists oyun_test", "-c", "create database oyun_test"], check=True, capture_output=True)
subprocess.run(PSQL + ["-d", "oyun_test", "-f", os.path.join(KOK, "sql/00_supabase_taklit.sql")], check=True, capture_output=True)
assert kur(tam=True) == []
assert q("select count(*) from oyun.surumler where bitis is not null") == "1"
assert q("select yedek is null from oyun.surumler") == "t"          # ilk kurulumda yedeklenecek oyuncu yok
ok("İlk kurulum: sürüm kaydı açıldı, koruma kuruldu")

# ---------------- OYNANMIŞ BİR OYUN ----------------
q("update oyun.ayarlar set baslangic='2026-10-02 12:00+03', test_simdi='2026-10-02 12:00+03', min_hesap_gun=0, oy_min_kidem=0, oy_il_gun=0, cihaz_zorunlu=false, coklu_kontrol=false, eposta_zorunlu=false, parti_kurucu_sayi=1, parti_kurucu_kidem=0, baslangic_para=500000")
saat("2026-10-02 12:00")
def oyuncu(kad, il, parti=None):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, il)
    if parti: rpc(u, "partiye_katil", parti)
    return u
cb = oyuncu("Cumhur", 6, 1); vek = oyuncu("Vekil", 35, 2); bas = oyuncu("Baskan", 34, 1); vat = oyuncu("Vatandas", 34)
q(f"""insert into oyun.makamlar(tur,user_id,parti_id,bas) values ('cb','{cb}',1,'2026-10-02 11:00+03');
      insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('mv','{vek}',35,2,'2026-10-02 11:00+03'), ('bel','{bas}',34,1,'2026-10-02 11:00+03')""")
rpc(cb, "bakan_ata", "adalet", "Vatandas")
for u in [cb, vek, bas, vat]: rpc(u, "topla")
rpc(vat, "parti_kur", "Kalici Yol Partisi", "KYP", "#225588", "a_gul")
rpc(cb, "kararname_cikar", "duzenleme", None, None, json.dumps({"kod": "yeni_hibe", "deger": 3000}))
rpc(vek, "kanun_teklif", "serbest", "Kalıcılık Kanunu", "Oyun hiç sıfırlanmasın.", None)
rpc(bas, "belediye_duzenle", "emlak", 40)
saat("2026-10-03 12:00")
rpc(vat, "topla")

TABLOLAR = [r for r in q("""select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
                            where n.nspname='oyun' and c.relkind='r' and c.relname not in ('surumler','ayarlar') order by 1""").split("\n")]
SUTUN = {t: q(f"select string_agg(quote_ident(attname), ',' order by attnum) from pg_attribute where attrelid='oyun.{t}'::regclass and attnum>0 and not attisdropped") for t in TABLOLAR}
def dokum():
    d = {}
    for t in TABLOLAR:
        d[t] = q(f"select md5(coalesce(string_agg(x::text, E'\\n' order by x::text), '')) from (select {SUTUN[t]} from oyun.{t}) x")
    return d
once = dokum()
oz = {"oyuncu": q("select count(*) from oyun.profiller"), "para": q("select sum(para) from oyun.cuzdan"), "makam": q("select count(*) from oyun.makamlar where bit is null")}
assert int(oz["oyuncu"]) == 4 and int(oz["makam"]) == 4

# ---------------- 2) GÜNCELLEME İKİ KEZ ----------------
assert kur() == []
assert kur() == []
sonra = dokum()
fark = [t for t in TABLOLAR if once[t] != sonra[t]]
assert fark == [], fark
assert q("select count(*) from oyun.surumler where bitis is not null") == "3"
y = q("select yedek from oyun.surumler order by id desc limit 1")
assert y.startswith("yedek_") and q(f"select count(*) from {y}.profiller") == "4" and q(f"select sum(para) from {y}.cuzdan") == oz["para"]
assert q(f"select count(*) from oyun.makamlar where bit is null") == oz["makam"]
assert rpc(vat, "durum")["profil"]["kad"] == "Vatandas"
ok(f"Güncelleme iki kez uygulandı: {len(TABLOLAR)} tablonun tamamı bayt bayt aynı (hesaplar, makamlar, paralar, kıdemler, partiler, kanunlar, kurallar); her seferinde yedek alındı")

# ---------------- 3) YENİ MAKAM GETİREN GÜNCELLEME ----------------
once3 = dokum()
GOC = """begin;
select oyun.guncelleme_basla('2026.12.01-1', 'Yeni makam: Kamu Denetçisi');
alter table oyun.makamlar drop constraint if exists makamlar_tur_check;
alter table oyun.makamlar add constraint makamlar_tur_check check (tur in ('mv','bel','cb','bakan','tbmm','bskv','grup_bskv','denetci'));
create table if not exists oyun.denetci_raporlari(id bigserial primary key, user_id uuid, metin text, zaman timestamptz);
alter table oyun.profiller add column if not exists rozet_renk text not null default 'altin';
%s
select oyun.guncelleme_bitti();
commit;"""
# güncellemenin içinden birine makam vermeye kalkışmak engellenir (makam sahiplerini yalnızca oyun belirler)
hata_bekle(q, GOC % "insert into oyun.makamlar(tur,user_id,kaynak,bas) select 'denetci', id, 'atama', oyun.simdi() from oyun.profiller where kad='Vekil';", icerir="GÜNCELLEME DURDURULDU")
assert q("select count(*) from information_schema.tables where table_schema='oyun' and table_name='denetci_raporlari'") == "0"
q(GOC % "")
q("insert into oyun.makamlar(tur,user_id,kaynak,bas) select 'denetci', id, 'atama', oyun.simdi() from oyun.profiller where kad='Vekil'")   # oyun içinden atama
yeni = dokum()
degisen = [t for t in TABLOLAR if once3[t] != yeni[t]]
assert degisen == ["makamlar"], degisen                     # yalnızca yeni makam satırı eklendi
assert q("select count(*) from oyun.makamlar where bit is null") == str(int(oz["makam"]) + 1)
assert q("select string_agg(tur, ',' order by id) from oyun.makamlar where tur <> 'denetci' and bit is null") == "cb,mv,bel,bakan"
assert q("select count(*) from oyun.profiller where rozet_renk = 'altin'") == "4"
ok("Yeni makam getiren güncelleme: yeni makam türü, tablo ve sütun eklendi; eski makamlar, kişiler, paralar aynen duruyor. Güncellemenin içinden birine makam verilmesi engellendi; atama oyun içinden yapıldı")

# ---------------- 4) HATALI GÜNCELLEME ----------------
para0 = q("select sum(para) from oyun.cuzdan"); n0 = q("select count(*) from oyun.surumler")
try:
    q("""begin;
    select oyun.guncelleme_basla('2026.12.02-1', 'Hatalı güncelleme');
    alter table oyun.cuzdan add column if not exists deneme int;
    update oyun.cuzdan set para = 0 where user_id = (select id from oyun.profiller where kad='Cumhur');
    select oyun.guncelleme_bitti();
    commit;""")
    raise AssertionError("hatalı güncelleme geçti")
except SqlHata as e_:
    assert "GÜNCELLEME DURDURULDU" in str(e_) and "cuzdanlar" in str(e_), e_
assert q("select sum(para) from oyun.cuzdan") == para0 and q("select count(*) from oyun.surumler") == n0
assert q("select count(*) from information_schema.columns where table_schema='oyun' and table_name='cuzdan' and column_name='deneme'") == "0"
ok("Oyuncunun parasını sıfırlayan hatalı güncelleme kendiliğinden durdu; hiçbir değişiklik (yeni sütun dahil) uygulanmadı")

# ---------------- 5) SİLME KORUMASI ----------------
for sql, icerir in [("set client_min_messages=warning; truncate oyun.profiller cascade", "boşaltılamaz"), ("truncate oyun.cuzdan", "boşaltılamaz"),
                    ("drop table oyun.mesajlar", "silinemez"), ("alter table oyun.cuzdan drop column kidem", "silinemez")]:
    hata_bekle(q, sql, icerir=icerir)
assert q("select count(*) from oyun.profiller") == "4"
ok("Koruma: oyun tabloları boşaltılamıyor (TRUNCATE), silinemiyor (DROP TABLE), sütunları kaldırılamıyor (DROP COLUMN)")

# ---------------- 6) SAHİBİN ARAÇLARI ----------------
y = q("select yedek from oyun.surumler where yedek is not null order by id desc limit 1")
q(f"update oyun.cuzdan set para = para + 777 where user_id = '{vat}'")      # oyun içi bir değişiklik
hata_bekle(q, f"select oyun.yedekten_don('{y}', 'evet')", icerir="GERİ YÜKLE")
q(f"select oyun.yedekten_don('{y}', 'GERİ YÜKLE')")
assert q("select sum(para) from oyun.cuzdan") == q(f"select sum(para) from {y}.cuzdan")
assert q("select count(*) from oyun.makamlar where tur='denetci'") == "0"     # yedek, yeni makamdan önceydi
assert q("select count(*) from oyun.hosgeldin_kayit") == q(f"select count(*) from {y}.hosgeldin_kayit")   # tetikleyiciler yeniden çalışmadı
u_yeni = oyuncu("YedekSonrasi", 6)                                          # kimlik sayaçları doğru: yeni kayıt çakışmıyor
ok("Yedeğe dönüş: onay cümlesi şart; oyun yedekteki hâline döndü, tetikleyiciler tekrar çalışmadı, yeni kayıtlar sorunsuz")

hata_bekle(q, "select oyun.oyunu_sifirla('evet')", icerir="OYUNU SIFIRLA")
try:
    q("set role authenticated; select oyun.oyunu_sifirla('OYUNU SIFIRLA')"); raise AssertionError("uygulamadan sıfırlanabildi")
except SqlHata as e_:
    assert "permission denied" in str(e_), e_
iller = q("select count(*) from oyun.iller")
q("select oyun.oyunu_sifirla('OYUNU SIFIRLA')")
assert q("select count(*) from oyun.profiller") == "0" and q("select count(*) from oyun.makamlar") == "0" and q("select count(*) from oyun.iller") == iller
assert q("select count(*) from auth.users") != "0"                           # hesaplar (giriş bilgileri) duruyor
assert kur() == []                                                           # başlangıç verileri yeniden yüklenir
assert q("select count(*) from oyun.ulke") == "1" and int(q("select count(*) from oyun.partiler")) >= 1
assert q("select count(*) from oyun.yedekler() where aciklama like 'Sıfırlama öncesi%'") == "1"
ok("Sıfırlama: yalnızca sahip, yalnızca 'OYUNU SIFIRLA' cümlesiyle; önce yedek alındı; katalog ve giriş hesapları kaldı; kurulum dosyası başlangıç verilerini geri yükledi")

s = qj("select public.surum()")
assert s["son_uygulama"] == open(os.path.join(KOK, "SURUM")).read().strip() and s["min_uygulama"] == "0"
assert int(q("select count(*) from oyun.yedekler()")) <= 5
ok(f"Sürüm bilgisi: sunucu {s['sunucu']}, en düşük uygulama {s['min_uygulama']}; en fazla 5 yedek tutuluyor")
print("\nTÜM KALICILIK KONTROLLERİ GEÇTİ")
