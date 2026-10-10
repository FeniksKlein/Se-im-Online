"""Modül 83: Yargı reformu (3 üyeli mahkeme, bağımsızlık, süre, istinaf jürisi, harç, akış, yeni cezalar, AYM).
Çalıştır: ../kur_yerel.sh && python3 yargi.py"""
from db import q, qj, rpc, kullanici_ekle, hata_bekle
TAMAM = []
def ok(m): TAMAM.append(m); print("  ✓", m)
def an(ts): q(f"update oyun.ayarlar set test_simdi = '{ts}+03'")
def tick(): return int(q("select oyun.mahkeme_tick()"))
def para(u): return float(q(f"select para from oyun.cuzdan where user_id='{u}'"))

an("2030-04-01 10:00")
def oyuncu(ad, il=34):
    u = kullanici_ekle(f"{ad}@y.com"); rpc(u, "profil_olustur", ad, il)
    q(f"select oyun.cuzdanim('{u}'); update oyun.cuzdan set para=100000 where user_id='{u}'; update oyun.profiller set son_gorulme='2030-04-01 09:00+03' where id='{u}'")
    return u
P = {}
for kisa in ("AAA", "BBB", "CCC"):
    P[kisa] = int(q(f"insert into oyun.partiler(ad,kisa) values ('{kisa} Partisi','{kisa}') returning id"))
CB = oyuncu("Reis")
A, B, C, D_ = oyuncu("YargicA"), oyuncu("YargicB"), oyuncu("YargicC"), oyuncu("YargicD")
X = oyuncu("Davaci"); Y = oyuncu("Davali")
MV = [oyuncu(f"Vekil{i}") for i in range(7)]
q(f"insert into oyun.makamlar(tur,user_id,bas) values ('cb','{CB}',now())")
for i, v in enumerate(MV):
    pk = ["AAA", "BBB", "CCC"][i % 3]
    q(f"update oyun.profiller set parti_id={P[pk]} where id='{v}'")
    q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('mv','{v}',34,{P[pk]},now())")
q(f"update oyun.profiller set parti_id={P['AAA']} where id='{X}'; update oyun.profiller set parti_id={P['BBB']} where id='{Y}'")
q(f"insert into oyun.makamlar(tur,user_id,il_id,parti_id,bas) values ('mv','{Y}',34,{P['BBB']},now())")
q(f"update oyun.partiler set gb='{MV[0]}' where id={P['AAA']}; update oyun.partiler set gb='{MV[1]}' where id={P['BBB']}; update oyun.partiler set gb='{MV[2]}' where id={P['CCC']}")
assert q("select oyun.salt_cogunluk()") == "5"   # 8 vekil

# ---------- 1-2) atama ve bağımsızlık
hata_bekle(rpc, CB, "adliye_hakim_ata", "Vekil3", icerir="partiye üye olmamalı")
rpc(CB, "adliye_hakim_ata", "YargicA")
m = rpc(A, "adliye_mahkeme")
assert m["uyeler"][0]["kad"] == "YargicA" and m["uye_miyim"] and q("select oyun.kad(hakim) from oyun.adliye_makam") == "YargicA"
hata_bekle(rpc, CB, "adliye_hakim_ata", "YargicD", icerir="görev süresi dolmadan")
hata_bekle(rpc, CB, "adliye_hakim_al", "Bu yargıç çok yavaş karar veriyor", icerir="Meclis")
ok("CB yalnız partisiz adayı mahkeme başkanı atayabilir; süre dolmadan değiştiremez, görevden alamaz")
hata_bekle(q, f"update oyun.profiller set parti_id={P['AAA']} where id='{A}'", icerir="partiye üye olamaz")
hata_bekle(q, f"insert into oyun.makamlar(tur,user_id,bakanlik,bas) values ('bakan','{A}','saglik',now())", icerir="başka bir makamda")
sid = q("select id from oyun.secimler limit 1")
hata_bekle(q, f"insert into oyun.adaylar(secim_id,user_id) values ({sid},'{A}')", icerir="aday olamaz")
ok("Yargıç görevdeyken partiye giremez, makam alamaz, aday olamaz")

# ---------- Meclis seçimi
for v in MV[:5]: r = rpc(v, "mahkeme_meclis_oy", 2, "YargicB")
assert r["secildi"] and rpc(A, "adliye_mahkeme")["uyeler"][1]["kad"] == "YargicB"
hata_bekle(rpc, X, "mahkeme_meclis_oy", 3, "YargicC", icerir="milletvekilleri")
for v in MV[:3]: rpc(v, "mahkeme_meclis_oy", 3, "YargicC")
assert rpc(A, "adliye_mahkeme")["uyeler"][2]["kad"] is None
q("update oyun.mahkeme_uye set bos_since = bos_since - interval '73 hours' where sira=3")
tick()
assert rpc(A, "adliye_mahkeme")["uyeler"][2]["kad"] == "YargicC"
ok("Meclis 2. üyeyi salt çoğunlukla seçti; 3. koltuk 72 saat dolmayınca en çok oyu alana (3 vekil) geçti")

# ---------- 3-5) dava, harç, heyet oyu, istinaf jürisi
p0 = para(X)
d1 = rpc(X, "adliye_dava_ac", "oyuncu", "Davali", "hakaret", "Davalı sohbette bana ağır hakaretlerde bulundu, kayıtlar ekte.", "Genel sohbet 10:05", None)
assert d1["harc"] == 5000 and para(X) == p0 - 5000
D1 = d1["id"]
rpc(Y, "adliye_beyan_ver", D1, "İddiaları kabul etmiyorum, bu bir siyasi eleştiridir.")
hata_bekle(rpc, X, "adliye_oy_ver", D1, "beraat", "Yargıç olmayan biri oy vermeye çalışıyor burada.", icerir="Yalnız Yüksek Mahkeme")
hata_bekle(rpc, A, "adliye_oy_ver", D1, "parti_para", "Kişiye parti cezası verilemez, deneme yapıyoruz.", icerir="yalnız partilere")
rpc(A, "adliye_oy_ver", D1, "para_10b", "Hakaret sabit görüldü; para cezası uygun görülmüştür.")
rpc(B, "adliye_oy_ver", D1, "beraat", "İfadeler siyasi eleştiri sınırında kalmaktadır, beraat.")
ek = rpc(X, "adliye_dava_ek", D1)
assert ek["oy_sayi"] == 2 and ek["oylar"] is None and ek["gerekli"] == 2
r = rpc(C, "adliye_karar_ver", D1, "para_10b", "Ağır ifadeler hakaret niteliğindedir; para cezası verilmiştir.")  # eski düğme de oy verir
assert r["karar_cikti"]
d = qj(f"select to_jsonb(d) from oyun.adliye_davalar d where id={D1}")
assert d["karar"] == "para_10b" and d["kesin"] is False and para(Y) == 100000
ok("Dava harcı peşin alındı; 3 üyeden 2'si aynı karara varınca karar çıktı; oylar karara kadar gizli; ağır ceza kesinleşmeyi bekliyor")
assert int(q(f"select count(*) from oyun.akis_etiket e join oyun.akis a on a.id=e.akis_id where e.etiket='adliye' and a.metin like '%#{D1}%'")) == 1
assert int(q(f"select count(*) from oyun.olaylar where tur='adliye' and metin like '%#{D1}%'")) >= 1
ok("Karar Akış'a #Adliye etiketiyle ve Gündem'e düştü")
ek = rpc(X, "adliye_dava_ek", D1); assert ek["istinaf_hakkim"] is False and len(ek["oylar"]) == 3
hata_bekle(rpc, X, "adliye_istinaf", D1, "Kazandığım davaya itiraz etmeye çalışıyorum.", icerir="kaybeden")
assert rpc(Y, "adliye_dava_ek", D1)["istinaf_hakkim"] is True
r = rpc(Y, "adliye_istinaf", D1, "Karar siyasi eleştiriyi cezalandırıyor, bozulmalı.")
juri = q(f"select string_agg(oyun.kad(user_id), ',') from oyun.adliye_juri where dava_id={D1}").split(",")
assert len(juri) == 3 and sum(j.startswith("Vekil") for j in juri) == 2 and "Reis" not in juri and not any(j in ("YargicA","YargicB","YargicC","Davaci","Davali") for j in juri), juri
partileri = q(f"select string_agg(distinct coalesce(p.parti_id::text,'-'), ',' order by coalesce(p.parti_id::text,'-')) from oyun.adliye_juri j join oyun.profiller p on p.id=j.user_id where j.dava_id={D1}")
assert set(partileri.split(",")) == {str(P["CCC"]), "-"}, partileri
ok(f"İstinaf: jüri kurayla önce davayla ilgisiz partinin vekillerinden, yetmeyince tarafsız oyunculardan seçildi (CB ve yargıçlar hariç): {juri}")
JU = [q(f"select id from oyun.profiller where kad='{j}'") for j in juri]
rpc(JU[0], "adliye_juri_oy", D1, "boz", "Eleştiri sınırında")
assert q(f"select durum from oyun.adliye_istinaf where dava_id={D1}") == "acik"
rpc(JU[1], "adliye_juri_oy", D1, "boz", "")
d = qj(f"select to_jsonb(d) from oyun.adliye_davalar d where id={D1}")
assert d["karar"] == "beraat" and d["kesin"] and d["harc_durum"] == "hazine" and para(Y) == 100000 and para(X) == p0 - 5000
hata_bekle(rpc, JU[2], "adliye_juri_oy", D1, "onay", "", icerir="açık değil")
ok("Jüri 2/3 'boz' dedi: karar beraate döndü, kesinleşti; davacı kaybettiği için harç hazinede kaldı")

# ---------- 7) aday yasağı, istinafa gidilmeyen karar kesinleşir, harç iadesi + davalıdan tahsil
an("2030-04-01 11:00")
D2 = rpc(X, "adliye_dava_ac", "oyuncu", "Davali", "rusvet", "Davalı oy karşılığı para teklif etti; mesaj kayıtları ektedir.", "", None)["id"]
an("2030-04-01 17:30")
for u, g in ((A, "Rüşvet teklifi sabittir; aday olma hakkı kısıtlanmalı."), (B, "Delil yeterli; adaylık yasağı uygun görülmüştür.")):
    rpc(u, "adliye_oy_ver", D2, "aday_yasagi", g)
assert qj(f"select adaylik_yasagi_bitis from oyun.profiller where id='{Y}'") is None
an("2030-04-02 18:00"); tick()
d = qj(f"select to_jsonb(d) from oyun.adliye_davalar d where id={D2}")
assert d["kesin"] and d["harc_durum"] == "iade"
assert para(X) == p0 - 5000 and para(Y) == 95000
hata_bekle(q, f"insert into oyun.adaylar(secim_id,user_id) values ({sid},'{Y}')", icerir="aday olamazsın")
ok("İstinafa gidilmeyen karar 24 saatte kesinleşti: 30 gün adaylık yasağı, harç davacıya iade ve davalıdan tahsil")

# ---------- 3) karar süresi: dava düşer, harç iade
an("2030-04-03 10:00")
p1 = para(X)
D3 = rpc(X, "adliye_dava_ac", "parti", str(P["BBB"]), "usulsuzluk", "Parti ihale kurallarını çiğnedi; belgeler ekte duruyor.", "", None)["id"]
assert para(X) == p1 - 5000
an("2030-04-06 17:00"); tick()
d = qj(f"select to_jsonb(d) from oyun.adliye_davalar d where id={D3}")
assert d["karar"] == "dusme" and d["kesin"] and para(X) == p1
ok("72 saatte karar çıkmayan dava düştü, harç iade edildi")

# ---------- 7) parti cezası
an("2030-04-06 18:00")
q(f"update oyun.partiler set kasa=40000 where id={P['BBB']}")
D4 = rpc(X, "adliye_dava_ac", "parti", str(P["BBB"]), "yolsuzluk", "Parti kasasından usulsüz harcama yapıldı, kayıtlar ektedir.", "", None)["id"]
an("2030-04-07 01:00")
hata_bekle(rpc, A, "adliye_oy_ver", D4, "para_10b", "Partiye kişi cezası verilmeye çalışılıyor burada.", icerir="Partiye yalnız")
for u in (A, C): rpc(u, "adliye_oy_ver", D4, "parti_para", "Usulsüz harcama sabit, hazine yardımından kesinti uygulanır.")
an("2030-04-08 02:00"); tick()
assert q(f"select kasa from oyun.partiler where id={P['BBB']}") == str(40000 - 25000 - 5000)
ok("Partiye hazine yardımı kesintisi (25.000 ₺) ve harç kesinleşince kasadan alındı")

# ---------- 8) Anayasa Mahkemesi
an("2030-04-08 10:00")
q("update oyun.ayarlar set baraj=7")
kid = int(q(f"""insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,durum,teklif_at,oy_bas,oy_bit)
  values ('secim','Baraj Kanunu','Seçim barajı yüzde 10 olsun.','{{"baraj":10}}','{MV[1]}',{P['BBB']},'cb_onayinda',now(),now(),now()) returning id"""))
q(f"select oyun.kanun_yururluk({kid}, oyun.simdi(), 'test')")
assert q("select (select baraj from oyun.ayarlar)::text||'/'||coalesce((select bekleyen_baraj from oyun.ulke where id=1)::text,'-')") in ("10/-", "7/10"), "kanun uygulanmadı"
hata_bekle(rpc, MV[1], "aym_basvur", kid, "Kendi kanunumuza başvurmaya çalışıyoruz, olmaz bu.", icerir="Kendi partinizin")
hata_bekle(rpc, X, "aym_basvur", kid, "Genel başkan olmayan biri başvurmaya çalışıyor.", icerir="genel başkanları")
assert any(k["id"] == kid for k in rpc(MV[0], "adliye_mahkeme")["aym_kanunlar"])
b = rpc(MV[0], "aym_basvur", kid, "Yüzde on baraj temsilde adaleti bozar, anayasaya aykırıdır.")["id"]
hata_bekle(rpc, A, "aym_oy_ver", b, "iptal", "Görüş süresi dolmadan oy verilmeye çalışılıyor.", icerir="6 saat")
rpc(MV[1], "aym_gorus", b, "Baraj istikrar için gereklidir, iptal edilmemelidir.")
rpc(A, "aym_oy_ver", b, "iptal", "Temsilde adalet ilkesine aykırı, iptal edilmelidir.")
r = rpc(B, "aym_oy_ver", b, "iptal", "Baraj orantısız; kanun iptal edilmelidir diyorum.")
assert r["karar_cikti"] and q(f"select durum from oyun.kanunlar where id={kid}") == "aym_iptal" and q("select (select baraj from oyun.ayarlar)::text||'/'||coalesce((select bekleyen_baraj from oyun.ulke where id=1)::text,'-')") == "7/-"
assert int(q("select count(*) from oyun.akis_etiket where etiket='anayasamahkemesi'")) >= 2
ok("Anayasa Mahkemesi: muhalefet GB başvurdu, kanun sahibi görüş verdi, 2/3 iptal: kanun düştü, baraj %7'ye döndü")

# ---------- 2) görevden alma (Meclis 3/5) ve görev süresi
an("2030-04-09 10:00")
z = rpc(MV[0], "mahkeme_azil_teklif", 2, "Üye tarafsızlığını yitirdi; açıklamaları siyasi taraflılık içeriyor.")["id"]
assert q("select oyun.mahkeme_azil_gerekli()") == "5"
for v in MV[1:3]: rpc(v, "mahkeme_azil_oy", z, "kabul")
for v in MV[3:7]: rpc(v, "mahkeme_azil_oy", z, "ret")
assert q(f"select durum from oyun.mahkeme_azil where id={z}") == "ret"   # 3 kabul + 4 ret: 8 vekilde 5 kabula artık ulaşılamaz → erken ret
z2 = rpc(MV[6], "mahkeme_azil_teklif", 2, "Yeniden teklif: üye görevini kötüye kullandı, delilleri sunduk.")["id"]
for v in MV[:4]: rpc(v, "mahkeme_azil_oy", z2, "kabul")
assert rpc(A, "adliye_mahkeme")["uyeler"][1]["kad"] is None
ok("Görevden alma 3/5 oyla oldu (3/5'e ulaşamayan teklif reddedildi)")
q(f"update oyun.profiller set parti_id={P['AAA']} where id='{B}'")
ok("Görevden alınan eski yargıç partiye girebildi")
an("2030-05-02 12:00"); tick()
assert all(u["kad"] is None for u in rpc(A, "adliye_mahkeme")["uyeler"])
assert "Görev süresi doldu" in q("select gerekce from oyun.adliye_atama_kayit order by id desc limit 1")
ok("30 günlük görev süresi dolunca koltuklar boşaldı")
assert q("select count(*) from information_schema.table_privileges where table_schema='oyun' and table_name in ('mahkeme_uye','adliye_karar_oy','adliye_juri','aym_basvuru','mahkeme_azil') and grantee in ('anon','authenticated','public')") == "0"
ok("Yeni tablolar internete kapalı")
print(f"\n{len(TAMAM)} kontrol geçti")
