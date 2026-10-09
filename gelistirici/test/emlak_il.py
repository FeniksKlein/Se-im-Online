"""İl bazlı emlak stoğu, il fiyatı, haftalık mülk vergisi ve dolu sandalye salt çoğunluğu (modül 43-45)."""
from db import q, qj, rpc, saat, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))

saat("2026-10-12 10:00")
def oyuncu(kad, il):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il)); return u
def para(u, x): q(f"update oyun.cuzdan set para={x} where user_id='{u}'")
def cuzdan(u): return float(q(f"select para from oyun.cuzdan where user_id='{u}'"))

# 1) Stok ve fiyatlar
stok = {x["il"]: x for x in rpc(oyuncu("Bakici", "Ankara"), "mulk_il_stok")}
assert len(stok) == 81
ist, bay = stok["İstanbul"]["urunler"][0], stok["Bayburt"]["urunler"][0]
assert ist["tip"] == "daire" and ist["kontenjan"] == 100 and bay["kontenjan"] == 8, (ist, bay)
assert ist["fiyat"] > 2.5 * bay["fiyat"] and ist["kira"] > bay["kira"], (ist, bay)
ok(f"İstanbul {ist['kontenjan']} daire ({ist['fiyat']:.0f} ₺), Bayburt {bay['kontenjan']} daire ({bay['fiyat']:.0f} ₺)")

# 2) Başka ilden alım, stok sınırı, eski API kendi ilinden
a = oyuncu("Ali", "Ankara"); para(a, 50_000_000)
for _ in range(2): rpc(a, "mulk_il_satin_al", "villa", IL("Bayburt"))
hata_bekle(rpc, a, "mulk_il_satin_al", "villa", IL("Bayburt"), icerir="satılık yeni villa kalmadı")
d = rpc(a, "mulk_satin_al", "daire")
assert sorted(m["il"] for m in d["mulkler"]) == ["Ankara", "Bayburt", "Bayburt"], d["mulkler"]
assert rpc(a, "mulk_il_stok")[[x["il"] for x in rpc(a, "mulk_il_stok")].index("Bayburt")]["urunler"][2]["kalan"] == 0
ok("Ankara'da yaşayan oyuncu Bayburt'tan villa aldı; 3. villa stok bitti; eski uygulama kendi ilinden aldı")

# 3) Haftalık vergi belediye kasasına
p0 = cuzdan(a)
saat("2026-10-19 10:05")
kasa0 = float(q(f"select kasa from oyun.il_durum where il_id={IL('Bayburt')}"))
d = rpc(a, "mulk_liste")
beklenen = sum(m["vergi"] for m in d["mulkler"])
odenen = float(q(f"select coalesce(sum(tutar),0) from oyun.emlak_vergi_tahsilat where user_id='{a}'"))
kira = sum(m["haftalik"] for m in d["mulkler"])
assert abs(odenen - beklenen) < 2 and odenen > 0, (odenen, beklenen)
assert abs((cuzdan(a) - p0) - (kira - odenen)) < 2, (cuzdan(a) - p0, kira, odenen)
by_vergi = float(q(f"select sum(tutar) from oyun.emlak_vergi_tahsilat where il_id={IL('Bayburt')}"))
assert abs(float(q(f"select kasa from oyun.il_durum where il_id={IL('Bayburt')}")) - kasa0 - by_vergi / 1e9) < 1e-9
rpc(a, "mulk_liste")
assert float(q(f"select coalesce(sum(tutar),0) from oyun.emlak_vergi_tahsilat where user_id='{a}'")) == odenen
ok(f"7 gün sonra {odenen:.0f} ₺ vergi kesildi, mülklerin bulunduğu belediyelere gitti; ikinci açılışta tekrar kesilmedi")

# 4) Belediye başkanı çarpanı ve Meclis/kararname
b = oyuncu("Baskan", "Bayburt")
q(f"insert into oyun.makamlar(tur,user_id,il_id,kaynak,bas) values('bel','{b}',{IL('Bayburt')},'secim',oyun.simdi())")
oran0 = float(q(f"select oyun.mulk_vergi_oran({IL('Bayburt')}::smallint)"))
rpc(b, "belediye_duzenle", "mulk_vergi_yerel", 150)
assert abs(float(q(f"select oyun.mulk_vergi_oran({IL('Bayburt')}::smallint)")) - oran0 * 1.5) < 1e-6
assert q("select oyun.duzenleme_engel('mulk_vergi_ulusal','kararname')").startswith("Haftalık mülk vergisi")
q("select oyun.duzenleme_uygula('mulk_vergi_ulusal', 1.0, 'kanun', null, oyun.simdi())")
assert abs(float(q(f"select oyun.mulk_vergi_oran({IL('Bayburt')}::smallint)")) - 1.5) < 1e-6
oz = rpc(b, "belediye_emlak_ozet"); assert oz["il"] == "Bayburt" and oz["toplam_vergi"] > 0
ok("Belediye başkanı çarpanı 150 yaptı, TBMM ulusal oranı %1 yaptı (Bayburt %1,5); kararname yolu kapalı")

# 5) Parası yetmeyince borç; tapu devrinde satıcıdan kesilir
para(a, 0); q(f"update oyun.yatirim_mulkleri set haftalik_kira=1 where user_id='{a}'")  # kira gelmesin, vergi borca dönsün
saat("2026-10-26 10:10")
rpc(a, "mulk_liste")
borc = float(q(f"select sum(vergi_borc) from oyun.yatirim_mulkleri where user_id='{a}'"))
assert borc > 0
v = int(q(f"select id from oyun.yatirim_mulkleri where user_id='{a}' and il_id={IL('Bayburt')} order by id limit 1"))
mb = float(q(f"select vergi_borc from oyun.yatirim_mulkleri where id={v}"))
rpc(a, "mulk_ilan_ver", v, 400000)
c = oyuncu("Can", "İzmir"); para(c, 5_000_000)
ilan = int(q(f"select id from oyun.mulk_ilan where mulk_id={v} and durum='acik'"))
rpc(c, "mulk_ilan_satin_al", ilan)
assert q(f"select user_id from oyun.yatirim_mulkleri where id={v}") == c
assert float(q(f"select vergi_borc from oyun.yatirim_mulkleri where id={v}")) == 0
assert abs(cuzdan(a) - (400000 - 8000 - mb)) < 2, (cuzdan(a), mb)
ok(f"Parası olmayan oyuncuya {borc:.0f} ₺ borç yazıldı; satışta mülkün {mb:.0f} ₺ borcu satıcıdan kesildi")

# 6) 600 sandalye, dolu sandalyeye göre salt çoğunluk (11 vekil -> 6 evet)
assert int(q("select (oyun.meclis_olcek_hesap(oyun.simdi())->>'sandalye')::int")) == 600
vekiller = [oyuncu(f"Vekil{i}", "Ankara") for i in range(11)]
for u in vekiller:
    q(f"insert into oyun.makamlar(tur,user_id,il_id,kaynak,bas) values('mv','{u}',{IL('Ankara')},'secim',oyun.simdi())")
assert int(q("select oyun.dolu_sandalye()")) == 11
def kanun(evet, ret):
    k = q(f"insert into oyun.kanunlar(tur,baslik,metin,teklif_eden,durum,teklif_at,oy_bas,oy_bit) values('serbest','T{evet}','m','{vekiller[0]}','oylamada',oyun.simdi()-interval '2 days',oyun.simdi()-interval '1 day',oyun.simdi()-interval '1 minute') returning id").split("\n")[0]
    for i, u in enumerate(vekiller[:evet + ret]):
        q(f"insert into oyun.kanun_oylari values({k},'ilk','{u}',null,'{'kabul' if i < evet else 'ret'}',oyun.simdi()-interval '2 hours')")
    q("select oyun.kanun_tick(oyun.simdi())")
    return q(f"select durum from oyun.kanunlar where id={k}")
assert kanun(6, 0) in ("cb_onayinda", "yururlukte")
assert kanun(5, 0) == "ret"
ok("600 sandalye açık; 11 dolu sandalyede kanun 6 evetle geçti, 5 evetle reddedildi")
print("emlak_il: tamam")
