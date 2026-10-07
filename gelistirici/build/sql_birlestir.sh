#!/bin/bash
# Supabase'e tek seferde yapıştırılacak dosyayı üretir
cd "$(dirname "$0")/../sql"
mkdir -p ../dist
{
  echo "-- ====================================================================="
  echo "--  SEÇİM SİMÜLASYONU ONLINE — SUPABASE KURULUM DOSYASI"
  echo "--  Supabase → SQL Editor → New query → bu dosyanın TAMAMINI yapıştır → Run"
  echo "--  Tekrar çalıştırmak güvenlidir (var olan veriyi silmez)."
  echo "-- ====================================================================="
  echo "--  Bu dosya oyunu SIFIRLAMAZ: önce yedek alır, sonunda oyuncu verisini (hesap, makam, para, kıdem,"
  echo "--  oy, parti…) karşılaştırır; tek bir değer değiştiyse hiçbir şey uygulanmaz."
  echo "begin;"
  cat kalicilik_bas.sql; echo
  echo "select oyun.guncelleme_basla('$(cat ../SURUM | tr -d '\n')', 'supabase-kurulum.sql');"
  cat 01_sema.sql; echo; cat iller.sql; echo; cat 02_motor.sql; echo; cat 03_api.sql; echo; cat 05_kabine_sosyal.sql; echo; cat 07_devlet.sql; echo; cat 08_asama3.sql; echo; cat 09_vatandas.sql; echo; cat 10_ekonomi2.sql; echo; cat 11_bos_makam.sql; echo; cat 12_mevzuat.sql; echo; cat 13_meclis.sql; echo; cat 14_guvenlik.sql; echo; cat 15_ekonomi3.sql; echo; cat 16_moderator.sql; echo; cat 06_yetkiler.sql; echo
  cat kalicilik_son.sql; echo
  echo "select oyun.guncelleme_bitti();"
  echo "commit;"
  echo
  cat 04_zamanlayici.sql
} > ../dist/supabase-kurulum.sql
echo "dist/supabase-kurulum.sql $(wc -l < ../dist/supabase-kurulum.sql) satır"
