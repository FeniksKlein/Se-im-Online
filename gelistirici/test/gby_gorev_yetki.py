"""Modül 53: GB yardımcısının görev alanı yetki verir."""
from db import q, rpc, saat, kullanici_ekle, hata_bekle
def ok(m): print("  ✓", m)
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))
saat("2026-10-12 10:00")
q("update oyun.ayarlar set teskilat_zorunlu=true where id=1")
def oyuncu(kad, il):
    u = kullanici_ekle(f"{kad}@t.com"); rpc(u, "profil_olustur", kad, IL(il))
    q(f"update oyun.cuzdan set para=500000 where user_id='{u}'"); return u
gb, tes, sec, mal, huk, tan, bos, uye = [oyuncu(k, "Ankara") for k in ("Genbas", "Tes", "Sec", "Mal", "Huk", "Tan", "Bos", "Uye")]
izmirli = oyuncu("Izmirli", "İzmir")
for u in (gb, tes, sec, mal, huk, tan, bos, uye, izmirli): rpc(u, "partiye_katil", 1)
q(f"update oyun.partiler set gb='{gb}', kasa=1000000 where id=1")
for i, u in enumerate((tes, sec, mal, huk, tan, bos), 1): q(f"insert into oyun.parti_gby(parti_id,sira,user_id) values (1,{i},'{u}')")
q(f"delete from oyun.parti_teskilat where parti_id=1 and il_id in ({IL('Van')},{IL('Muş')},{IL('İzmir')})")

# Teşkilat: görevli yokken herkes, atanınca yalnız GB + Teşkilat GBY
rpc(bos, "teskilat_ac", IL("Van"))
ok("Teşkilattan Sorumlu yokken görevsiz yardımcı il teşkilatı açabildi (eski kural)")
rpc(gb, "gby_gorev_ver", "Tes", "Teşkilattan Sorumlu")
hata_bekle(rpc, bos, "teskilat_ac", IL("Muş"), icerir="yetkin yok")
rpc(tes, "teskilat_ac", IL("Muş"))
assert rpc(tes, "parti_yetkilerim")["alanlar"] == ["teskilat"]
rpc(tes, "teskilat_gorev_ver", IL("İzmir"), "Izmirli")
assert q(f"select count(*) from oyun.parti_teskilat_gorev where il_id={IL('İzmir')} and aktif") == "1"
hata_bekle(rpc, bos, "teskilat_gorev_ver", IL("İzmir"), "Izmirli", icerir="Teşkilattan Sorumlu")
rpc(tes, "teskilat_gorev_al", IL("İzmir"))
ok("Teşkilattan Sorumlu atanınca: o açar ve İl Başkanı atar/alır; görevsiz yardımcı artık açamaz")

# Mali
rpc(gb, "gby_gorev_ver", "Mal", "Mali İşlerden Sorumlu")
hata_bekle(rpc, bos, "parti_destek", "Uye", 1000, icerir="Mali İşlerden")
rpc(mal, "parti_destek", "Uye", 1000)
rpc(mal, "parti_ucret_ayarla", '{"mv_on":2,"bel_on":1,"kurultay":1,"cb_on":1}')
ok("Mali İşlerden Sorumlu kasadan destek verdi, adaylık ücretini ayarladı")

# Tanıtım: grup konuşması
rpc(gb, "gby_gorev_ver", "Tan", "Tanıtım ve Medyadan Sorumlu")
hata_bekle(rpc, bos, "grup_duyuru_yayinla", "Ekonomi gündemi", "Bu hafta ekonomiyi konuşacağız.", icerir="Tanıtım ve Medyadan")
rpc(tan, "grup_duyuru_yayinla", "Ekonomi gündemi", "Bu hafta ekonomiyi konuşacağız.")
assert q(f"select count(*) from oyun.bildirimler where user_id='{uye}' and metin like 'CYP Tanıtım ve Medyadan Sorumlu Genel Başkan Yardımcısı yeni grup%'") == "1"
ok("Tanıtım ve Medyadan Sorumlu grup konuşması yayımladı; üyeye unvanıyla bildirim gitti")

# Hukuk: disiplin, GB'yi sevk edemez
rpc(gb, "gby_gorev_ver", "Huk", "Siyasi ve Hukuki İşlerden Sorumlu")
hata_bekle(rpc, bos, "disiplin_baslat", "Uye", "Parti kararlarına aykırı davrandı.", icerir="Hukuki")
hata_bekle(rpc, huk, "disiplin_baslat", "Genbas", "Parti kararlarına aykırı davrandı.", icerir="Genel başkan disipline")
rpc(huk, "disiplin_baslat", "Uye", "Parti kararlarına aykırı davrandı.")
ok("Siyasi ve Hukuki İşlerden Sorumlu üyeyi disipline sevk etti; genel başkanı edemedi")

# Seçim: miting yetkisi beklemeden parti mitingi
rpc(gb, "gby_gorev_ver", "Sec", "Seçim İşlerinden Sorumlu")
hata_bekle(rpc, bos, "parti_miting_duzenle", IL("Van"), "2026-10-12 15:00+03", "Van buluşması", "true", icerir="yalnız genel başkan")
rpc(sec, "parti_miting_duzenle", IL("Van"), "2026-10-12 15:00+03", "Van buluşması", "true")
ok("Seçim İşlerinden Sorumlu ayrı yetki almadan Van'a parti mitingi koydu")

hata_bekle(rpc, bos, "parti_aday_tanit", 999999, "herkes", "Bu aday Türkiye için çalışacak, destek bekliyoruz.", icerir="tanıtabilir")
hata_bekle(rpc, sec, "parti_aday_tanit", 999999, "herkes", "Bu aday Türkiye için çalışacak, destek bekliyoruz.", icerir="Aday kaydı bulunamadı")
hata_bekle(rpc, tan, "parti_aday_tanit", 999999, "herkes", "Bu aday Türkiye için çalışacak, destek bekliyoruz.", icerir="Aday kaydı bulunamadı")
ok("Aday tanıtımında Seçim ve Tanıtım yardımcıları yetki kontrolünü geçti; görevsiz yardımcı geçemedi")

# Genel başkan hâlâ her şeyi yapar
y = rpc(gb, "parti_yetkilerim"); assert y["gb"] and y["alanlar"] == ["teskilat","secim","tanitim","mali","hukuk"], y
rpc(gb, "parti_destek", "Uye", 1000)
ok("Genel başkan bütün alanlarda yetkili kaldı")
print("gby_gorev_yetki: tamam")
