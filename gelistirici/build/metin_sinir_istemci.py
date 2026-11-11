# 184 metin sınırlarının istemci karşılığı: maxlength, maxLength ve "N karakter" ifadeleri aynı tabloyla büyütülür.
# Bir kez çalıştırıldı (11.11.2026). Tekrar çalıştırmayın: 1000→3000 sonra 3000→8000 olur.
import re, pathlib, sys
M = {280:1000,300:1000,350:1000,400:1500,450:1500,500:1500,600:2000,700:2000,750:2000,800:2000,850:2000,900:2500,
     1000:3000,1200:3000,1500:4000,1600:5000,2000:5000,2500:6000,3000:8000,5000:15000,6000:12000,15000:50000}
kok = pathlib.Path(__file__).resolve().parents[2]
HARIC = {'reklam_panosu.js','yonetici_kontrol.js','yonetim_portali.js','tasarim_v5.js','tasarim_v5_ikon.js','tasarim_v4.js','veri.js','ym_fezleke.js'}
dosyalar = [p for p in (kok/'gelistirici/www').glob('*.js') if p.name not in HARIC] + [kok/'gelistirici/www/index.html', kok/'docs/halk-org-davet.js']
def esle(m):
    n = int(m.group(2).replace('.', ''))
    if n not in M: return m.group(0)
    v = M[n]; s = f'{v:,}'.replace(',', '.') if '.' in m.group(2) else str(v)
    return m.group(1) + s + (m.group(3) if m.lastindex >= 3 else '')
desen = [re.compile(r'(maxlength=\\?["\']?)(\d+)()'), re.compile(r'(\.maxLength\s*=\s*)(\d+)()'),
         re.compile(r'((?<![\d.])\d+\s*[–-]\s*)(\d{1,3}(?:\.\d{3})+|\d{3,5})(\s?karakter)'),
         re.compile(r'((?:en fazla|en çok|azami|En fazla)\s+)(\d{1,3}(?:\.\d{3})+|\d{3,5})(\s?karakter)')]
toplam = 0
for p in dosyalar:
    s = p.read_text(encoding='utf8'); y = s
    for d in desen: y = d.sub(esle, y)
    if p.name == 'canli_ek.js': y = y.replace('/280', '/1000')
    if p.name == 'kursu.js': y = y.replace('kalan = 280 - l', 'kalan = 1000 - l').replace('l / 280)', 'l / 1000)')
    if p.name == 'index.html': y = y.replace('metinMax: 280,', 'metinMax: 1000,')
    if y != s:
        n = sum(1 for a, b in zip(s.splitlines(), y.splitlines()) if a != b); toplam += n
        p.write_text(y, encoding='utf8'); print(f'{p.relative_to(kok)}: {n} satır')
print('toplam', toplam)
