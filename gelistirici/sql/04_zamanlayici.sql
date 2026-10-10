-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 4) ZAMANLAYICI (yalnızca Supabase'de)
--  Seçim motorunu her dakika çalıştırır: takvimi üretir, 18:00'de sayar,
--  göreve başlatmaları yapar. Supabase'de "pg_cron" eklentisi gerekir.
-- =====================================================================
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;

-- Oyun saatini bu andan başlat (bu andan önceki seçimler oluşturulmaz)
-- İlk kurulumda (henüz hiç seçim yokken) başlangıcı şimdiye al; güncellemelerde takvime dokunma
update oyun.ayarlar set test_simdi = null where id = 1;
update oyun.ayarlar set baslangic = now() where id = 1 and not exists (select 1 from oyun.secimler);

-- Varsa eski zamanlayıcıyı kaldır, yenisini kur
select cron.unschedule(jobid) from cron.job where jobname = 'secim-motoru';
select cron.schedule('secim-motoru', '* * * * *', 'select oyun.tick()');
-- Türkiye Gündem otomatik gazetesi (5 dakikada bir)
select cron.schedule('turkiye-gundem-otomatik-gazete', '*/5 * * * *', 'select oyun.ajans_derle()');
-- Şirket halka arzları: süresi dolanları her dakika sonuçlandır
select cron.schedule('halka-arz', '* * * * *', 'select oyun.halka_arz_tick()');

-- İlk takvimi hemen üret
select oyun.tick();
