"""183 · Yüksek Mahkeme fezlekesi → TBMM → Meclis soruşturması → Yüce Divan akışı (yerel PG, rollback yok: test veritabanı).
Çalıştırma: python3 ym_fezleke_akis.py   (kur_yerel.sh ile kurulmuş, en az ~200 vekilli bir dünya gerekir)
"""
from db import q, qj, rpc, hata_bekle

def tek(sql):
    return q(sql)

ym = qj("select to_jsonb(oyun.mahkeme_uyeleri())")
assert ym and len(ym) >= 1, "Yüksek Mahkeme üyesi yok"
vekiller = q("select string_agg(user_id::text, ',' order by user_id) from oyun.makamlar where tur='mv' and bit is null").split(',')
bakanlar = q("select string_agg(p.kad || '|' || m.id, ',' order by m.id) from oyun.makamlar m join oyun.profiller p on p.id=m.user_id "
             "where m.tur='bakan' and m.bit is null and not exists (select 1 from oyun.ym_fezleke z where z.makam_id=m.id and z.durum in ('imza','onerge','oylama1','komisyon','oylama2'))").split(',')
assert len(bakanlar) >= 2, "En az iki bakan gerekir"
hedef1, makam1 = bakanlar[0].split('|'); hedef2, makam2 = bakanlar[1].split('|')
sade = next(v for v in vekiller if v not in ym)
dolu = len(vekiller)
esik = qj("select (public.ym_fezleke_panel())->'esik'", ym[0])
print('vekil', dolu, 'eşik', esik, 'YM', len(ym))

ISNAT = "Bakan, görevi sırasında ihale sürecinde yakınlarına ait şirketlere kamu kaynağı aktarmış ve bu yolla kamu zararına yol açmıştır. " * 3
HUKUKI = "Eylem görevi kötüye kullanma ve kamu zararı oluşturma niteliğindedir; Anayasa m.106 uyarınca Meclis soruşturması gereklidir."

# 1) Yetki ve doğrulama
hata_bekle(rpc, sade, 'ym_fezleke_yaz', hedef1, 'Görevi kötüye kullanma iddiası', ISNAT, '', HUKUKI, icerir='yalnız Yüksek Mahkeme')
hata_bekle(rpc, ym[0], 'ym_fezleke_yaz', hedef1, 'Kısa', ISNAT, '', HUKUKI, icerir='başlığı')
hata_bekle(rpc, ym[0], 'ym_fezleke_yaz', hedef1, 'Görevi kötüye kullanma iddiası', 'kısa', '', HUKUKI, icerir='isnadı')
hata_bekle(rpc, ym[0], 'ym_fezleke_yaz', 'olmayan_kisi_xyz', 'Görevi kötüye kullanma iddiası', ISNAT, '', HUKUKI, icerir='bulunamadı')
r = rpc(ym[0], 'ym_fezleke_yaz', hedef1, 'Görevi kötüye kullanma ve kamu zararı', ISNAT, 'İhale dosyası, banka dökümleri', HUKUKI)
f1 = r['id']; print('fezleke', f1, r['durum'])
hata_bekle(rpc, ym[0], 'ym_fezleke_yaz', hedef1, 'Aynı bakan için ikinci dosya', ISNAT, '', HUKUKI, icerir='zaten açık')

# 2) YM imzaları → TBMM
if r['durum'] == 'imza':
    hata_bekle(rpc, ym[0], 'ym_fezleke_imzala', f1, icerir='zaten imzaladın')
    for u in ym[1:]:
        if q(f"select durum from oyun.ym_fezleke where id={f1}") == 'imza':
            rpc(u, 'ym_fezleke_imzala', f1)
assert q(f"select durum from oyun.ym_fezleke where id={f1}") == 'onerge', 'TBMM önerge aşamasına geçmedi'
bildirim = int(q(f"select count(*) from oyun.bildirimler where metin like '%fezlekesi #{f1} ulaştı%'"))
assert bildirim >= dolu - 1, f'Vekillere bildirim gitmedi ({bildirim})'

# 3) Önerge imzaları (salt çoğunluk)
oyl = [v for v in vekiller if v != q(f"select bakan_id from oyun.ym_fezleke where id={f1}")]
for i, v in enumerate(oyl[:esik['onerge']]):
    rpc(v, 'ym_fezleke_onerge_imzala', f1)
hata_bekle(rpc, oyl[0], 'ym_fezleke_onerge_imzala', f1)
assert q(f"select durum from oyun.ym_fezleke where id={f1}") == 'oylama1', 'Soruşturma oylamasına geçmedi'

# 4) Savunma + soruşturma oylaması (3/5, gizli)
bakan1 = q(f"select bakan_id from oyun.ym_fezleke where id={f1}")
rpc(bakan1, 'ym_fezleke_savunma', f1, 'İddialar asılsızdır; ihaleler kanuna uygun yapılmıştır, belgeler ektedir.')
pv = qj(f"select x from jsonb_array_elements((public.ym_fezleke_panel())->'dosyalar') x where (x->>'id')::bigint={f1}", oyl[0])
assert pv['oy_verebilirim'] and pv['oy1'] is None, 'Panel oy hakkını göstermiyor'
for v in oyl[:esik['sorusturma'] - 1]:
    rpc(v, 'ym_fezleke_oy', f1, 'kabul')
pv = qj(f"select x from jsonb_array_elements((public.ym_fezleke_panel())->'dosyalar') x where (x->>'id')::bigint={f1}", oyl[0])
assert pv['katilim'] == esik['sorusturma'] - 1 and pv['oy1'] is None, 'Oylama sürerken sonuç görünmemeli (gizli oy)'
rpc(oyl[esik['sorusturma'] - 1], 'ym_fezleke_oy', f1, 'kabul')
assert q(f"select durum from oyun.ym_fezleke where id={f1}") == 'komisyon', 'Komisyona geçmedi'

# 5) Komisyon süresi → sevk oylaması
q(f"update oyun.ym_fezleke set asama_bit = oyun.simdi() - interval '1 minute' where id={f1}; select oyun.ym_fezleke_tick();")
assert q(f"select durum from oyun.ym_fezleke where id={f1}") == 'oylama2', 'Sevk oylamasına geçmedi'
for v in oyl[:esik['sevk']]:
    if q(f"select durum from oyun.ym_fezleke where id={f1}") != 'oylama2': break
    rpc(v, 'ym_fezleke_oy', f1, 'kabul')
assert q(f"select durum from oyun.ym_fezleke where id={f1}") == 'yuce_divan', 'Yüce Divan''a sevk edilmedi'
assert q(f"select bit is not null from oyun.makamlar where id={makam1}") == 't', 'Sevk edilen bakanın görevi bitmedi'
print('✓ tam akış: imza → önerge → soruşturma → komisyon → Yüce Divan, bakan görevden düştü')

# 6) Ret yolu: ikinci bakan, soruşturma reddedilir
r = rpc(ym[0], 'ym_fezleke_yaz', hedef2, 'Bütçe ödeneklerinin amaç dışı kullanımı', ISNAT, '', HUKUKI)
f2 = r['id']
for u in ym[1:]:
    if q(f"select durum from oyun.ym_fezleke where id={f2}") == 'imza': rpc(u, 'ym_fezleke_imzala', f2)
oyl2 = [v for v in vekiller if v != q(f"select bakan_id from oyun.ym_fezleke where id={f2}")]
for v in oyl2[:esik['onerge']]: rpc(v, 'ym_fezleke_onerge_imzala', f2)
for v in oyl2[:dolu - esik['sorusturma'] + 1]: rpc(v, 'ym_fezleke_oy', f2, 'ret')
d = qj(f"select jsonb_build_object('durum',durum,'oy1_ret',oy1_ret) from oyun.ym_fezleke where id={f2}")
assert d['durum'] == 'ret', f'Erken ret olmadı: {d}'
assert q(f"select bit is null from oyun.makamlar where id={makam2}") == 't', 'Reddedilen dosyada bakan görevde kalmalı'
print('✓ ret yolu: yeter sayı imkânsızlaşınca dosya erken reddedildi, bakan görevde')

# 7) İmza süresi dolan taslak düşer (birden çok YM üyesi varsa)
if len(ym) > 1:
    b3 = q("select p.kad from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='bakan' and m.bit is null "
           "and not exists (select 1 from oyun.ym_fezleke z where z.makam_id=m.id and z.durum in ('imza','onerge','oylama1','komisyon','oylama2')) limit 1")
    if b3:
        f3 = rpc(ym[1], 'ym_fezleke_yaz', b3, 'Süre dolumu deneme dosyası', ISNAT, '', HUKUKI)['id']
        q(f"update oyun.ym_fezleke set asama_bit = oyun.simdi() - interval '1 minute' where id={f3}; select oyun.ym_fezleke_tick();")
        assert q(f"select durum from oyun.ym_fezleke where id={f3}") == 'dusmus'
        print('✓ 72 saatte imza toplanmayan taslak düştü')
print('TAMAM')
