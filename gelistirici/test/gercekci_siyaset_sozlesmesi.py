#!/usr/bin/env python3
"""Gerçekçi siyaset kaynak sözleşmesi.
Yalnızca kaynakları okur, canlı sunucuya bağlanmaz ve oyuncu verisini değiştirmez.
Yayın öncesi GitHub Actions tarafından zorunlu çalıştırılır.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
SQLDIR = ROOT / "sql"
builder = (ROOT / "build" / "sql_birlestir.js").read_text(encoding="utf-8")
launch = (SQLDIR / "lansman_4_parti_100bin_7gun_2026.sql").read_text(encoding="utf-8")
source = (ROOT / "www" / "index.html").read_text(encoding="utf-8")
checks = []

def check(condition, why):
    checks.append((bool(condition), why))

rules = sorted(SQLDIR.glob("zz_20261115_*.sql"))
check(len(rules) >= 11, "En az 11 anayasal reform yaması kaynakta olmalı")
for file in rules:
    check(f"'{file.name}'" in builder, f"Yama kurulum listesine eklendi: {file.name}")
    check(file.stat().st_size >= 120, f"Boş SQL dosyası yok: {file.name}")

def sql(file):
    return (SQLDIR / file).read_text(encoding="utf-8")

core = sql("zz_20261115_gercekci_siyaset_asama1.sql")
law = sql("zz_20261115_anayasa_iki_gorusme.sql")
sign = sql("zz_20261115_cb_bagimsiz_imza.sql")
protection = sql("zz_20261115_anayasa_imza_2tur_koruma.sql")
afk = sql("zz_20261115_mv_afk_gorev_korumasi.sql")
budget = sql("zz_20261115_butce_teklif_cumhurbaskani.sql")
check("gercekci_siyaset=true" in launch, "Lansman gerçekçi siyaset modu açık")
check("OR NOT (SELECT gercekci_siyaset" in launch, "Lansman gerçekçi siyaseti doğruluyor")
check("gercekci_siyaset boolean not null default false" in core,
      "Mevcut beta dünyasında geriye dönük etki yok")
check("ceil(oyun.tbmm_tamsayi()*3/5.0)" in core, "Erken seçim 3/5 eşiği")
check("when oyun.gercekci_siyaset() then 20" in core, "Meclis siyasi parti grubu en az 20 vekil")
check("sokak_eylem_imza_kapisi" in core and "greatest(10" in core,
      "Büyük eylem için sunucu tarafında imza kapısı")
check("cb_bagimsiz_destek" in sign and "0.03" in sign and "50000" in sign,
      "Bağımsız Cumhurbaşkanı adayı: tek seçmen imzası, yüzde 3, teminat")
check("anayasa_tur" in law and "'ikinci'" in law and "interval '48 hours'" in law,
      "Anayasa iki tur gizli oylama ve en az 48 saat")
check("kanun_imza" in protection and "anayasa_tur>0" in protection,
      "İkinci turda ilk teklif imzaları değiştirilemez")
check("oyun.gercekci_siyaset() or p.son_gorulme" in afk,
      "Oyuna 7 gün girmeyen vekilin makami düşmez")
check("p_tur='butce'" in budget, "Bütçe kanunu yalnızca Cumhurbaşkanından gelir")
check("cbBagimsizImzaEkrani" in source, "Bağımsız CB kampanyası oyuncu ekranında")
check("Gizli oylama" in source and "anayasa_tur" in source,
      "Anayasa gizli oylama turu oyuncuya gösterilir")

errors = [name for passed, name in checks if not passed]
for passed, name in checks:
    print(("OK  " if passed else "HATA ") + name)
print(f"Kontrol: {len(checks)}; başarısız: {len(errors)}")
sys.exit(1 if errors else 0)
