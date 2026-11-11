"""184 · yazı sınırları: yeni sınıra yakın metin kabul edilir, tablo kısıtı engellemez (yerel PG)."""
from db import q, rpc, hata_bekle
u = q("select id from oyun.profiller where kad='Ercan_Ege'")
v = q("select id from oyun.profiller where kad='SelinKarakaya'")
q(f"update oyun.profiller set son_mesaj=null where id='{u}'") if q("select count(*) from information_schema.columns where table_name='profiller' and column_name='son_mesaj'")=='1' else None
def uzun(n): return ('Uzun bir siyasi metin. ' * (n // 23 + 1))[:n]
def dene(ad, fn, *a, tablo=None, sutun='metin', n=None):
    import time; time.sleep(6)
    try:
        rpc(u, fn, *a)
        if tablo:
            L = int(q(f"select max(char_length({sutun})) from {tablo}"))
            assert L >= n - 5, f"{ad}: metin kısaltılmış ({L} < {n})"
        print(f"✓ {ad}: {n} karakter kabul edildi")
    except Exception as e:
        print(f"✗ {ad}: {e}"); raise
oda = q("select kanal from oyun.mesajlar order by id desc limit 1") or 'genel'
dene('Sohbet', 'sohbet_yaz', oda, uzun(1490), tablo='oyun.mesajlar', n=1490)
dene('Özel mesaj', 'ozel_yaz', 'SelinKarakaya', uzun(2990), tablo='oyun.ozel', n=2990)
dene('Kürsü/akış', 'akis_yaz', uzun(995), tablo='oyun.akis', n=995)
print('TAMAM')
