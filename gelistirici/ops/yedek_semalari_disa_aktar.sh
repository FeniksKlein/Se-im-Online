#!/bin/bash
# yedek_* şemalarını pg_dump ile dışa aktarır. SİLMEZ. Canlıda bu oturumda çalıştırılmadı.
#
# Kullanım (okuma yeter; yazma yetkisi gerekmez):
#   DATABASE_URL='postgresql://...sslmode=require' bash gelistirici/ops/yedek_semalari_disa_aktar.sh [cikti_klasoru]
#
# Çıktı: her şema için bir .sql dosyası ve semalar.txt listesi.
# Dosyaları güvenli bir yerde saklayın. Ardından, ancak o zaman,
# gelistirici/ops/yedek_semalari_sil.sql içindeki adımları elle uygulayın.
#
# 31 Ekim 2026 canlı envanter (çalıştırma anında yeniden okunur, bu liste sabit değildir):
#   yedek_20261025_122229_550495   ~14 MB  496 tablo   bankacilik_v2 öncesi
#   yedek_20261027_225552_077167   ~16 MB  525 tablo   bakanlik_masasi öncesi
#   yedek_20261028_170736_683171   ~17 MB  535 tablo   adliye düzeltmesi öncesi
#   yedek_20261031_144556_896359   ~20 MB  573 tablo   kamu maliyesi öncesi
#   yedek_test_reset_20261008_0830 ~1 MB    99 tablo   eski test sıfırlaması
# Birincil anahtarı olmayan ~2229 tablonun 2228'i bu şemalardadır.
# yuk_testi (1 tablo, ~16 KB) yedek şeması değildir; bu betik ona dokunmaz.
set -euo pipefail
if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL gerekli. Örnek: postgresql://postgres.***@db.<proje>.supabase.co:5432/postgres?sslmode=require" >&2
  exit 2
fi
cikti="${1:-yedek-semalar-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$cikti"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At -c "select nspname from pg_namespace where nspname ~ '^yedek_' order by 1" > "$cikti/semalar.txt"
if [[ ! -s "$cikti/semalar.txt" ]]; then
  echo "yedek_ ile başlayan şema yok. Çıkılıyor."
  exit 0
fi
echo "Dışa aktarılacak şemalar:"
cat "$cikti/semalar.txt"
while IFS= read -r sema; do
  [[ -z "$sema" ]] && continue
  if [[ ! "$sema" =~ ^yedek_[A-Za-z0-9_]+$ ]]; then
    echo "Beklenmeyen şema adı, atlandı: $sema" >&2
    exit 1
  fi
  echo "pg_dump $sema"
  pg_dump "$DATABASE_URL" --schema="$sema" --no-owner --no-privileges --file="$cikti/${sema}.sql"
done < "$cikti/semalar.txt"
echo "Bitti: $cikti"
echo "Silme bu betikte yoktur. Geri yükleme: psql \"\$DATABASE_URL\" -v ON_ERROR_STOP=1 -f $cikti/<sema>.sql"
