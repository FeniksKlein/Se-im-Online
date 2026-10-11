#!/bin/bash
# Yerel DB'yi kurar, canlıdaki oyuncu bankası migration'larını (kaynakta olmayanlar) ve kredi masasını uygular, testi çalıştırır.
set -e
cd "$(dirname "$0")/.."
bash kur_yerel.sh >/dev/null 2>&1
M=../migrations
for f in 20261008_banka_yeni_kurulus_ve_eski_api_faiz_koruma 20261008_devlet_oyuncu_banka_faiz_dengesi 20261008_oyuncu_banka_kredi_ortak_koruma \
  20261008_oyuncu_banka_kredileri 20261008_oyuncu_banka_odeme_duzeltme 20261008_oyuncu_banka_saatlik 20261008_oyuncu_kredi_basvurusu_iptali \
  20261009_banka_profili 20261010_kredi_banka_yonetim_risk 20261010_kredi_gelir_butce_kredi_notu 20261011_haftalik_kredi_vade_gelir_odeme \
  20261011_kredi_gercek_sozlesme_tutari_duzeltme 20261011_ozel_banka_icra_adliye_haciz 20261011_ozel_banka_kredi_urun_bilgi_taksit \
  20261011_banka_2_3_4_hafta_kredi_paketleri 20261011_ozel_banka_kredi_son_uyumluluk 20261011_ozel_banka_icra_odeme_sonrasi_kapama \
  20261011_ozel_banka_kredi_gizlilik_yargi_duzeltme 20261011_ozel_banka_tam_gayrimenkul_listesi 20261011_oyuncu_banka_kredi_masasi; do
  PGOPTIONS='-c client_min_messages=error' psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1 -f $M/$f.sql >/dev/null
done
# Migration iki kez çalışabilmeli
PGOPTIONS='-c client_min_messages=error' psql -h /tmp -U postgres -d oyun_test -q -v ON_ERROR_STOP=1 -f $M/20261011_oyuncu_banka_kredi_masasi.sql >/dev/null
cd test && python3 oyb_kredi_masasi.py
