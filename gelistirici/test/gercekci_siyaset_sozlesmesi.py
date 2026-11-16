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
court_fix = sql("zz_20261116_yargi_gozalti_serbest.sql")
check("update oyun.sokak_gozalti set durum='serbest', bitis=t" in court_fix, "Hakimin hukuka aykiri gozaltiya dogrudan son vermesi")
check("update oyun.sokak_gozalti set durum='serbest', bitis=oyun.simdi()" in court_fix, "Nihai mahkeme kararinin dogrudan infazi")
check("if k='aykiri' and not oyun.gercekci_siyaset()" in court_fix, "Mahkeme kararinin CB takdirine bagli olmamasi")

tbmm_fix = sql("zz_20261116_tbmm_nisap_oy_koruma.sql")
check("floor(oyun.tbmm_tamsayi()/2.0)" in tbmm_fix, "TBMM salt cogunluk 600 icin 301")
check("on conflict(teklif_id,vekil) do nothing" in tbmm_fix, "Erken secim oyu bir kez kullanilir")
check("Meclis Başkanı TBMM oylamasına" in tbmm_fix, "Meclis baskani oy yasagi")
check("s.tur_no >= 4" in tbmm_fix and "ceil(dolu/3.0)" in tbmm_fix, "Dorduncu tur 200 katilim nisabi")
check("case when oyun.gercekci_siyaset() then ceil(dolu/3.0)" in tbmm_fix, "Kanun ret nisabi 200")

check("gercekci_siyaset=true" in launch, "Lansman gerçekçi siyaset modu açık")
check("OR NOT (SELECT gercekci_siyaset" in launch, "Lansman gerçekçi siyaseti doğruluyor")
check("gercekci_siyaset boolean not null default true" in core,
      "Gerçekçi siyaset varsayılan olarak beta dahil açık")
beta_patch = sql("zz_20261115_beta_gercekci_siyaset_kalici.sql")
check("alter column gercekci_siyaset set default true" in beta_patch and
      "set gercekci_siyaset=true where id=1" in beta_patch,
      "Mevcut beta verisinde gerçekçi siyaset kalıcı etkinleştiriliyor")
check("ceil(oyun.tbmm_tamsayi()*3/5.0)" in core, "Erken seçim 3/5 eşiği")
check("when oyun.gercekci_siyaset() then 20" in core, "Meclis siyasi parti grubu en az 20 vekil")
check("sokak_eylem_imza_kapisi" in core and "greatest(10" in core,
      "Büyük eylem için sunucu tarafında imza kapısı")
check("cb_bagimsiz_destek" in sign and "0.03" in sign and "50000" in sign,
      "Bağımsız Cumhurbaşkanı adayı: tek seçmen imzası, yüzde 3, teminat")
check("anayasa_tur" in law and "'ikinci'" in law and "48 hours" in law,
      "Anayasa iki tur gizli oylama ve en az 48 saat")
check("kanun_imza" in protection and "anayasa_tur>0" in protection,
      "İkinci turda ilk teklif imzaları değiştirilemez")
check("oyun.gercekci_siyaset() or p.son_gorulme" in afk,
      "Oyuna 7 gün girmeyen vekilin makami düşmez")
check("p_tur='butce'" in budget, "Bütçe kanunu yalnızca Cumhurbaşkanından gelir")
check("cb_parti_aday_gosterebilir" in sql("zz_20261115_cb_parti_aday_yuzde5.sql") and "v_alliance>=5" in sql("zz_20261115_cb_parti_aday_yuzde5.sql"),
      "Parti CB adaylığı: 20 MV veya son genel seçimde en az yüzde 5")
check("cbBagimsizImzaEkrani" in source, "Bağımsız CB kampanyası oyuncu ekranında")
check("Gizli oylama" in source and "anayasa_tur" in source,
      "Anayasa gizli oylama turu oyuncuya gösterilir")

# 16 Kasım: oyuncu iradesi, secim sonuclari, bagimsiz YSK ve mahkeme modeli.
yeni_yamalar = [
    "zz_20261116_aday_riza_sifir_oy_koruma.sql",
    "zz_20261116_mahkeme_cb_baro_tbmm.sql",
    "zz_20261116_belediye_ertesi_gun_ara_secim.sql",
    "zz_20261116_ysk_bagimsiz_itiraz_sayim.sql",
    "zz_20261116_genel_baskan_secimi_uyeler.sql",
    "zz_20261116_mahkeme_bagimsiz_azil_koruma.sql",
]
for file in yeni_yamalar:
    check(f"'{file}'" in builder, f"Kasım 16 yaması kurulum listesinde: {file}")
    check((SQLDIR / file).exists(), f"Yama dosyası mevcut: {file}")
aday_riza = sql(yeni_yamalar[0])
mahkeme_3 = sql(yeni_yamalar[1])
belediye_ara = sql(yeni_yamalar[2])
ysk = sql(yeni_yamalar[3])
kurultay = sql(yeni_yamalar[4])
check("cb_aday_teklif_cevap" in aday_riza and "onay_bekliyor" in aday_riza,
      "Cumhurbaşkanı adayı için bizzat oyuncunun muvafakati gerekir")
check("coalesce(oy,0) > 0" in aday_riza and "toplam > 0" in aday_riza,
      "Sıfır oyla parti genel başkanı, belediye başkanı veya cumhurbaşkanı seçilemez")
check("mahkeme_aday_riza" in mahkeme_3 and "baro_mahkeme_ata" in mahkeme_3,
      "Baro mahkeme üyesini yalnız başvuran uygun adaylardan atar")
check("where sira=3 and kaynak='adalet'" in mahkeme_3 and "mahkeme_toplu_tick" in mahkeme_3,
      "Adalet Bakanının otomatik mahkeme üyeliği ve tarihsel test ataması kalkar")
check("'bel',dm" in belediye_ara and "oyun.tr_an(ilk_gun,23)" in belediye_ara,
      "Belediye ara seçimi yalnız ilgili ilde ertesi gün sonuçlanır")
check("ysk_yetkili" in ysk and "yeniden_sayim" in ysk and "ysk_tekrar_secim" in ysk,
      "Partisiz bağımsız hakem oyların yeniden sayımını ve tekrarlama seçimlerini yönetir")
check("oyun.ara_secim_olustur('gb'" in kurultay and "update oyun.partiler set gb" not in kurultay,
      "Başkanı olmayan parti için üyelerin oy vereceği kurultay kullanılır")
check("oyun.gercekci_siyaset()" in sql(yeni_yamalar[5]),
      "Mahkeme üyeleri aktif vekil sayısına göre keyfi siyasi azil ile düşürülemez")
adliye_js = (ROOT / "www" / "adliye.js").read_text(encoding="utf-8")
rpc_yuzey = sql("159_rpc_yuzey.sql")
for r in ["cb_aday_tekliflerim","cb_aday_teklif_cevap","mahkeme_aday_ol",
          "mahkeme_aday_listesi","baro_mahkeme_ata","ysk_itiraz_dosyalari",
          "ysk_secim_itiraz_ac","ysk_secim_itiraz_karar"]:
    check(f"'{r}'" in rpc_yuzey, f"Yeni RPC kalıcı authenticated izin listesinde: {r}")
check("cbAdayTeklifCevap" in source, "CB adaylığı kabul/ret kullanıcı ekranında")
check("ysk_secim_itiraz_karar" in adliye_js and "adlBaroMahkemeAta" in adliye_js,
      "YSK ve baro mahkeme atama ekranları istemcide mevcut")

errors = [name for passed, name in checks if not passed]
for passed, name in checks:
    print(("OK  " if passed else "HATA ") + name)
print(f"Kontrol: {len(checks)}; başarısız: {len(errors)}")
sys.exit(1 if errors else 0)
