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
-- Belediye: bina inşaat/bakım (30 dk) ve kriz masası (saatte bir; açık krizlerin süresini de kapatır)
select cron.schedule('belediye-sehir-bina-tick', '*/30 * * * *', 'select oyun.belediye_bina_tick()');
select cron.schedule('belediye-kriz', '7 * * * *', 'select oyun.belediye_kriz_tick()');
-- Ekonomi kurumları (Merkez Bankası, belediye tahvili, SPK, konkordato): 10 dakikada bir
select cron.unschedule(jobid) from cron.job where jobname = 'ekonomi-2';
select cron.schedule('ekonomi-2', '*/10 * * * *', 'select oyun.ekonomi2_tick()');
-- Siyasi kurumlar (davet ödülleri, ulusal kriz masası, kapatma davaları, kol etkinlikleri): 5 dakikada bir
select cron.unschedule(jobid) from cron.job where jobname = 'siyasi-kurumlar';
select cron.schedule('siyasi-kurumlar', '*/5 * * * *', 'select oyun.siyasi_kurumlar_tick()');
