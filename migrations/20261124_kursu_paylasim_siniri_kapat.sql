-- Canlı Supabase migration adı: kursu_paylasim_siniri_kapat_20261124
-- DURUM (24.11.2026 01:38): canlıya UYGULANDI. Canlıda geri alınan denemede bir oyuncu art arda iki paylaşım yapabildi.
-- İstek (Ercan): "Kürsü 5 dakika kısıtını kaldır".
-- Düzenek (oyun.kursu_hiz_kapisi, oyun.kursu_hiz) yerinde durur; ayar 0 iken hiçbir şeyi engellemez ve sayaç tutmaz.
-- Yeniden açmak için: update oyun.kursu_ayar set paylasim_aralik_dk = 5 where id = 1;
begin;
select set_config('lock_timeout', '4s', true);
alter table oyun.kursu_ayar alter column paylasim_aralik_dk set default 0;
update oyun.kursu_ayar set paylasim_aralik_dk = 0, guncelleme = now() where id = 1;
commit;
