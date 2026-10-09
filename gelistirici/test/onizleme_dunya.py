"""Önizleme dünyası: simulasyon.py ile oynanmış Ekim–Kasım ayının üstüne gerçekçi adlar, portreler,
parti kimlikleri, Aralık genel seçimi adaylıkları ve bir canlı miting ekler.
Kullanım: bash ../kur_yerel.sh && python3 simulasyon.py && python3 onizleme_dunya.py [asama]
  asama: gundem (25 Kasım 20:00) · sandik (1 Aralık 12:00) · sonuc (1 Aralık 22:31)"""
import random, sys
from db import q, qj, rpc, saat, SqlHata
random.seed(11)
asama = sys.argv[1] if len(sys.argv) > 1 else "gundem"

def herkes(parti=None):
    w = f"where not yasakli" + (f" and parti_id={parti}" if parti else "")
    return q(f"select string_agg(id::text, ',') from oyun.profiller {w}").split(",")

if asama == "gundem":
    ADLAR = """Ayşe Yıldız Mehmet Kaya Zeynep Demir Mustafa Çelik Elif Şahin Ahmet Arslan Fatma Koç Emre Aydın Merve Öztürk Burak Doğan
    Selin Kılıç Can Aslan Ece Çetin Kerem Kara Deniz Yalçın Barış Polat Nazlı Erdem Onur Güneş Gizem Aksoy Tolga Özdemir Damla Kurt
    Serkan Bulut İrem Uçar Hakan Tekin Pınar Ateş Volkan Şen Derya Korkmaz Umut Yavuz Esra Bozkurt Cem Ekinci Gamze Tunç Murat Erdoğan
    Sevgi Karaca Okan Turan Buse Akın Levent Sarı Hande Duman Erkan Keskin Tuğba Gök Sinan Kaplan Melis Özer Gökhan Uysal Cansu Taş""".split()
    adlar = [ADLAR[i] + ADLAR[i + 1][:1] for i in range(0, len(ADLAR) - 1, 2)]   # "AyşeY" biçiminde tekil kullanıcı adları
    eklenen = ["Ercan_Ege", "SelinKarakaya", "Mert.Aksu", "NurPolat", "Berk_Akdeniz"]
    idler = q("select string_agg(id::text, ',' order by kad) from oyun.profiller where kad like 'Oyuncu_%'").split(",")
    for i, u in enumerate(idler):
        ad = (eklenen + adlar)[i] if i < len(eklenen) + len(adlar) else None
        if ad: q(f"update oyun.profiller set kad='{ad}' where id='{u}'")

    # Portreler ve biyografiler (oyuncuların yarısı)
    BIYO = ["Ege'nin rüzgârı, Meclis'in sesi.", "Esnaf çocuğu, emeğin yanında.", "Önce şehir, sonra siyaset.", "Gençler için daha çok iş.",
            "Kooperatifçi. Tarım ve su politikaları.", "Hukukçu. Kuvvetler ayrılığı şart.", "Belediyecilik okulu: önce hizmet.", None]
    for u in q("select string_agg(id::text, ',') from oyun.profiller").split(","):
        if random.random() < 0.6:
            kod = f"{random.randint(0,5)}-{random.randint(0,9)}-{random.randint(0,4)}-{random.choice([0,0,0,1,2])}-{random.randint(0,7)}-{random.randint(0,7)}"
            b = random.choice(BIYO)
            q(f"insert into oyun.oyuncu_kimlik(user_id, avatar, biyografi) values ('{u}', '{kod}', {('$$'+b+'$$') if b else 'null'}) on conflict (user_id) do update set avatar=excluded.avatar, biyografi=excluded.biyografi")
    # İzleyici oyuncu (önizlemeyi onun gözünden görürüz)
    IZ = q("select id from oyun.profiller where kad='Ercan_Ege'")
    q(f"update oyun.profiller set il_id=35 where id='{IZ}'")
    q(f"insert into oyun.oyuncu_kimlik(user_id, avatar, biyografi) values ('{IZ}', '2-2-1-0-1-3', 'İzmir. Kooperatif, kıyı ve emek.') on conflict (user_id) do update set avatar=excluded.avatar, biyografi=excluded.biyografi")
    print("izleyici: Ercan_Ege")

    def herkes(parti=None):
        w = f"where not yasakli" + (f" and parti_id={parti}" if parti else "")
        return q(f"select string_agg(id::text, ',') from oyun.profiller {w}").split(",")

    q("update oyun.ayarlar set oy_min_kidem=0, oy_il_gun=0, min_hesap_gun=0, cihaz_zorunlu=false, coklu_kontrol=false, ihmal_gun_atama=0, ihmal_gun_secim=0 where id=1")
    saat("2026-11-23 10:00")
    for u in herkes():
        try: rpc(u, "durum")
        except SqlHata: pass
    saat("2026-11-24 10:00")
    adaylar = []
    for u in herkes():
        if random.random() < 0.28:
            try: rpc(u, "aday_ol", "mv_on"); adaylar.append(u)
            except SqlHata: pass
    for pid in (1, 2):
        gb = q(f"select gb from oyun.partiler where id={pid}")
        if gb:
            try: rpc(gb, "cb_aday_belirle", "kendisi")
            except SqlHata as e: print("cb", e)
    print("vekil aday adayı:", len(adaylar))

    # Canlı miting (izleyicinin ilinde) ve yaklaşan bir tane
    izmir_aday = q("select a.user_id from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id where s.tur='mv_on' and s.donem='2026-12' and a.il_id=35 limit 1")
    if not izmir_aday:
        izmir_aday = q("select id from oyun.profiller where il_id=35 and parti_id is not null and id<>'" + IZ + "' limit 1"); rpc(izmir_aday, "aday_ol", "mv_on")
    mvon = q("select id from oyun.secimler where tur='mv_on' and donem='2026-12' and not ara")
    saat("2026-11-25 19:00")
    try: rpc(izmir_aday, "miting_duzenle", int(mvon), "2026-11-25 19:30+03", "Gündoğdu'da emek ve kıyı buluşması")
    except SqlHata as e: print("miting", e)
    saat("2026-11-25 19:40")
    for u in q("select string_agg(id::text, ',') from oyun.profiller where il_id=35").split(",")[:23]:
        try: rpc(u, "miting_katil", q(f"select id from oyun.mitingler where user_id='{izmir_aday}' order by id desc limit 1"))
        except SqlHata: pass
    diger = q("select a.user_id from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id where s.tur='mv_on' and s.donem='2026-12' and a.il_id=6 limit 1")
    if diger:
        try: rpc(diger, "miting_duzenle", int(mvon), "2026-11-26 18:00+03", "Kızılay'dan Meclis'e")
        except SqlHata as e: print("miting2", e)
    saat("2026-11-25 19:55")
    raise SystemExit
IZ = q("select id from oyun.profiller where kad='Ercan_Ege'")
mvon = q("select id from oyun.secimler where tur='mv_on' and donem='2026-12' and not ara")
if asama == "sandik":

    saat("2026-11-28 12:00")
    s = qj(f"select to_jsonb(s) from oyun.secimler s where id={mvon}")
    for u in herkes():
        try:
            d = rpc(u, "secim_detay", int(mvon))
            if d.get("secenekler") and not d.get("oy_engeli"):
                rpc(u, "oy_ver", int(mvon), random.choice(d["secenekler"])["hedef"])
        except SqlHata: pass
    saat("2026-12-01 12:00")
    mv = q("select id from oyun.secimler where tur='mv' and donem='2026-12' and not ara")
    cb = q("select id from oyun.secimler where tur='cb' and donem='2026-12' and not ara")
    agirlik = {1: 34, 2: 30, 3: 18, 4: 11, 5: 7}
    for u in herkes():
        if u == IZ: continue
        for sid in (mv, cb):
            if not sid: continue
            try:
                d = rpc(u, "secim_detay", int(sid))
                sec = d.get("secenekler") or []
                if sec and not d.get("oy_engeli") and not d.get("oy_verdim"):
                    w = [agirlik.get(x.get("parti_id"), 3) for x in sec]
                    rpc(u, "oy_ver", int(sid), random.choices(sec, w)[0]["hedef"])
            except SqlHata: pass
if asama == "sonuc":
    saat("2026-12-01 22:31")
