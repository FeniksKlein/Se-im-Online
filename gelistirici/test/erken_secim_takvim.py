"""Modül 80: erken seçim kararı yakın olağan genel seçimi iptal etmez."""
from db import q
def an(ts): q(f"update oyun.ayarlar set test_simdi='{ts}+03'; select oyun.tick();")
an("2026-10-29 00:45")   # olağan genel seçim 1 Kasım'da
mv = q("select id||'|'||donem from oyun.secimler where tur='mv' and not ara and durum='bekliyor' order by oy_bas limit 1")
mid, donem = mv.split("|")
oybas = q(f"select to_char(oy_bas at time zone 'Europe/Istanbul','DD.MM') from oyun.secimler where id={mid}")
d = q("select oyun.erken_genel_secim_olustur(oyun.simdi(), 99)")
assert d == donem, (d, donem)
assert q(f"select count(*) from oyun.secimler where donem='{donem}' and sonuc ? 'iptal'") == "0"
assert q("select count(*) from oyun.secimler where donem like 'erken-genel-99-%'") == "0"
assert "takvim değişmedi" in q("select metin from oyun.olaylar order by id desc limit 1")
print(f"  ✓ Olağan seçim {oybas}: erken karar takvimi bozmadı, başvurular korundu")
an("2026-10-05 12:00")   # olağan seçim 27 gün uzakta (1 Kasım)
d2 = q("select oyun.erken_genel_secim_olustur(oyun.simdi(), 98)")
assert d2.startswith("erken-genel-98-")
assert q(f"select count(*) from oyun.secimler where donem='{donem}' and durum='tamam' and sonuc->>'iptal'='erken_secim'") != "0"
assert q(f"select count(*) from oyun.secimler where donem='{d2}'") in ("2", "4")
print("  ✓ Olağan seçim uzaksa erken seçim kurulur, olağan takvim iptal edilir")
print("erken_secim_takvim: tamam")
