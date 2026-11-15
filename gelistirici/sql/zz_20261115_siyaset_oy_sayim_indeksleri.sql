-- 2026-11-15: buyuk oyuncu kitlelerinde anayasal oy sayimi ve aktif oyuncu sayisi icin indeksler.
-- Eski veri silinmez, tablo yeniden yaratılmaz.
create index if not exists profiller_aktif_7gun_idx on oyun.profiller(son_gorulme desc) where not yasakli;
create index if not exists kanun_oylari_sayim_idx on oyun.kanun_oylari(kanun_id,asama,oy);
create index if not exists cb_bagimsiz_kampanya_bas_idx on oyun.cb_bagimsiz_kampanya(secim_id,durum,bit);
