-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 6) YETKİLER
--  Yalnızca giriş yapmış oyuncular bu fonksiyonları çağırabilir.
-- =====================================================================
-- ---------- YETKİLER ----------
do $$
declare f text;
begin
  foreach f in array array[
    'profil_olustur(text,int)','il_degistir(int)','parti_kur(text,text,text,text)','partiye_katil(bigint)','partiden_ayril()',
    'gby_ata(int,text)','cb_aday_belirle(text,text)','aday_ol(text)','adaylik_geri_cek(bigint)','oy_ver(bigint,bigint)',
    'durum()','secim_detay(bigint)','harita()','il_detay(int)','partiler()','parti_detay(bigint)','meclis()',
    'gecmis_secimler(int)','haberler(int)','hesabimi_sil()',
    'bakan_ata(text,text)','bakan_gorevden_al(text)','istifa(text)','kabine()','oyuncu_kart(text)',
    'sohbet_oku(text,bigint,bigint)','sohbet_yaz(text,text)','ozel_liste()','ozel_oku(text,bigint)','ozel_yaz(text,text)',
    'yayin_haklari()','yayin_gonder(text,text,bigint)','bildirim_kutusu(int)','rozetler()',
    'engelle(text)','engel_kaldir(text)','engellenenler()','sikayet_et(text,bigint,text,text)',
    'bakanlik_paneli()','icraat_yap(text,int)','ulke_karnesi()','gazete(int)',
    'kararname_cikar(text,text,text,jsonb)','kararnameler(int)',
    'kanun_teklif(text,text,text,jsonb)','kanun_geri_cek(bigint)','kanun_oy(bigint,text)','kanun_cb_karar(bigint,text,text)','kanunlar(int)','kanun_detay(bigint)',
    'ittifak_bilgi(bigint)','ittifak_kur(text)','ittifak_davet(bigint)','ittifak_davet_yanit(bigint,boolean)','ittifak_ayril()','cb_destek(bigint)',
    'belediye_paneli()','belediye_hizmet(text,boolean)','belediye_yatirim(text)','belediye_ayar(numeric,numeric)',
    'hayat()','topla()','reklam_odul()','reklam_al()','magaza()','bagis_yap(numeric)','parti_destek(text,numeric)','parti_kasa(bigint)','parti_ucret_ayarla(jsonb)',
    'politika_ayarla(text,numeric)','politika_onizle(text,numeric)',
    'vaat_secenekleri(text,int)','vaat_hesapla(text,jsonb,int)','vaat_yaz(bigint,text,jsonb)','vaatlerim(bigint)','beyanname_kaydet(text,jsonb)',
    'admin_ozet()','admin_sikayetler(text)','admin_sikayet_karar(text,bigint,text,text)','admin_oyuncu(text)','admin_islem(text,text)','admin_duyuru(text)','admin_ayar(int)',
    'il_bagis(numeric)','il_bagis_durum()','vergi_karnem()','sohbet_ozet()',
    'cihaz_kaydet(text,text)','cihaz_sil(text)','bildirim_ayar_kaydet(jsonb)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
