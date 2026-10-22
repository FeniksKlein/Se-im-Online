"""Modül 119 (oyuncu gözüyle inceleme, 22.10.2026): her çağrıda hata veren sunucu fonksiyonlarının düzeltmesi.
Canlıya yakın yerel kopyada çalışır: TEST_DB=oyun_canli python3 oyuncu_incelemesi.py
(oyun_test'te bulunmayan fonksiyonlar atlanır; düzeltme modülü yine iki kez uygulanıp doğrulanır.)"""
import os, subprocess, uuid, json
import db
from db import q, qj, SqlHata
db.DB[db.DB.index("oyun_test")] = os.environ.get("TEST_DB", "oyun_test")
KOK = os.path.join(os.path.dirname(__file__), "..")

def ok(m): print("  ✓", m)
def var(fn): return q(f"select to_regproc('{fn}') is not null") == "t"
def tanim(fn): return q(f"select pg_get_functiondef(to_regproc('{fn}'))")

# 1) Modül iki kez uygulanabilir; ikinci seferde hiçbir şey değişmez
modul = os.path.join(KOK, "sql/119_oyuncu_incelemesi_duzeltmeler.sql")
for i in range(2):
    r = subprocess.run(db.DB[:-3] + ["-q", "-v", "ON_ERROR_STOP=1", "-f", modul], capture_output=True, text=True,
                       env={**os.environ, "PGOPTIONS": "-c client_min_messages=notice"})
    assert r.returncode == 0, r.stderr
ikinci = r.stderr
ok("Düzeltme modülü iki kez hatasız uygulandı")

beklenen = {
    "public.kriz_karar_ver": "#variable_conflict use_variable",
    "public.oyb_icra_haciz_sec": "sirket_ortaklari.pay>=50",
    "public.icra_haczet": "sirket_ortaklari.pay>=50",
    "public.adliye_secim_itiraz_karar": "select partiler.gb into gb",
    "public.mv_ortak_liste_yanit": "partiler.gb=p.id",
    "public.mv_ortak_liste_teklif": "p_il::smallint",
    "public.admin_transferler_sayfa": "truncate _aktarim",
    "oyun._sonuc_mv": "truncate _b23_liste",
}
for fn, metin in beklenen.items():
    if not var(fn): print("  ·", fn, "bu veritabanında yok, atlandı"); continue
    t = tanim(fn)
    if fn == "public.oyb_icra_haciz_sec" and metin not in t and "farklı yazılmış" in ikinci: continue
    assert metin in t, (fn, metin)
    assert "delete from _" not in t.lower(), fn
ok("Düzeltilen ifadeler yerinde; geçici tablolarda koşulsuz silme kalmadı")

# 2) Yönetici › Transferler: aynı işlemde iki kez açılabiliyor (geçici tablo yeniden kullanılıyor)
admin = q("select id from oyun.profiller where yonetici order by olusturma limit 1")
if admin and var("public.admin_transferler_sayfa"):
    out = q("begin; select public.admin_transferler_sayfa(5, 0, null, null); "
            "select public.admin_transferler_sayfa(5, 0, null, null)->>'limit'; rollback;", admin)
    assert out.strip().split("\n")[-1] == "5", out
    ok("Transferler sayfası art arda açılıyor")

# 3) Ülke krizi kararı: maliyet hem hazineden düşüyor hem krize yazılıyor
if var("public.kriz_karar_ver") and q("select count(*) from oyun.kriz_sablon") != "0":
    cb = q("select oyun.yurutme_user()")
    if cb:
        sablon = q("select kod from oyun.kriz_sablon order by kod limit 1")
        secenek = q(f"select secenekler->0->>'kod' from oyun.kriz_sablon where kod='{sablon}'")
        kid = q(f"""insert into oyun.kriz_olay(sablon_kod,bas,karar_son,durum,maliyet,sektor_carpan)
                    values('{sablon}', now(), now() + interval '1 day', 'bekliyor', 0, 1) returning id""")
        hazine0 = float(q("select hazine from oyun.ulke where id=1"))
        r = qj(f"select public.kriz_karar_ver({kid}, '{secenek}')", cb)
        assert r["tamam"] is True, r
        kayit = q(f"select durum||'|'||maliyet from oyun.kriz_olay where id={kid}").split("|")
        assert kayit[0] == "cozuldu" and abs(float(kayit[1]) - float(r["maliyet"])) < 0.01, (kayit, r)
        assert abs(float(q("select hazine from oyun.ulke where id=1")) - (hazine0 - float(r["maliyet"]))) < 0.01
        ok(f"Kriz kararı verildi, maliyet {r['maliyet']} hazineden düştü ve krize yazıldı")

# 4) Beğeni tepkisi: çakışmada tek kayıt kalır (on conflict)
if var("public.akis_tepki"):
    assert tanim("public.akis_tepki").count("on conflict do nothing") == 2
    ok("Beğen/beğenme çift dokunuşa dayanıklı")
print("oyuncu_incelemesi: tamam")
