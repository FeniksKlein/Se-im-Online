#!/usr/bin/env python3
"""Rütbe sistemi kalıcılık sözleşmesi: kodda yeniden derlemede kaybolmamalı."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
sql = (ROOT / 'sql/210_rutbe_lansman_dengesi.sql').read_text(encoding='utf-8')
builder = (ROOT / 'build/sql_birlestir.js').read_text(encoding='utf-8')
price = (ROOT / 'www/fiyat_tarifesi.js').read_text(encoding='utf-8')
profile = (ROOT / 'www/premium_arayuz.js').read_text(encoding='utf-8')
version = (ROOT / 'SURUM').read_text(encoding='utf-8').strip()

for marker in (
    "rutbe_reformu_20261115", "kidem_primi=5", "kidem_primi=0",
    "onur_unvani", "Duayen Rozeti", "Yaşayan Efsane Nişanı",
    "statu_json", "public.topla", "case when coalesce"
):
    assert marker in sql, f"Rütbe geçişinde eksik: {marker}"
assert "210_rutbe_lansman_dengesi.sql" in builder, "Tam SQL derlemesi rütbe yamasını kaybediyor"
assert "mevcutEsik" in price and "simgeler" in price and "onur" not in price[:20], "Rütbe rehberi eksik"
assert "st.simge" in profile and "st.onur_unvani" in profile, "Profil onur rozetini göstermiyor"
assert re.fullmatch(r"\d{4}\.\d{2}\.\d{2}-\d+", version), "Sürüm geçersiz"
assert "automatic election victory" not in sql.lower(), "Rütbe seçim hakkı veremez"
print(f"Rütbe reformu kaynak sözleşmesi OK ({version})")
