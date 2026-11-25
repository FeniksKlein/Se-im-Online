-- Canlı Supabase migration adı: dernek_yk_sube_bedeli_20261125
-- DURUM (25.11.2026 16:40): canlıya UYGULANDI. Bu dosya depo eşitlemesidir; tekrar çalıştırmak güvenlidir.
begin;
select set_config('lock_timeout', '4s', true);

-- 25.11.2026 · DERNEK: ŞUBE BEDELİ YAZISI DÜZELTMESİ + YÖNETİM KURULU ÜYE SAYISINA GÖRE (sürüm 2026.11.25-3)
-- 1) HATA: Şubeler sekmesi "küçük il 1.000 ₺, orta 2.000 ₺, büyük 3.000 ₺" yazıyor, kasadan 5.000 / 10.000 / 15.000 ₺ düşüyordu.
--    Tahsilat doğru (oyun.dernek_sube_ucreti = fiyat tablosundaki 'dernek_sube' × il büyüklüğü × endeks); yanlış olan
--    dernek_detay'daki eski sabit rakamlardı. Artık ekrandaki rakam tahsilatla AYNI kaynaktan hesaplanır.
-- 2) ÖNERİ (moderatör): "Dernek YK sayısı üye sayısıyla orantılı artabilir." Eskiden sabit 4'tü.
--    Yeni sınır: 4 + her 10 üye için 1, en çok 12 (başkan hariç). 9 üye → 4, 19 → 5, 33 → 7, 80+ → 12.
--    Üye sayısı düşerse kuruldakiler görevde kalır; yalnız yeni atama sınıra takılır. dernek_detay 'yk_sinir' döner.
-- Oyuncu verisi değişmez. Tekrar çalıştırmak güvenlidir. oyun._yama kullanır.

create or replace function oyun.dernek_yk_siniri(p_dernek bigint) returns integer
language sql stable set search_path = '' as $f$
  select least(12, 4 + (select count(*) from oyun.dernek_uyeler where dernek_id = p_dernek)::int / 10)
$f$;
revoke all on function oyun.dernek_yk_siniri(bigint) from public, anon, authenticated;

select oyun._yama('public.dernek_yonetim_ata(bigint,text,boolean)',
  $a$rol = 'yonetim') >= 4 then$a$,
  $b$rol = 'yonetim') >= oyun.dernek_yk_siniri(d.id) then$b$,
  'dernek_yk_siniri(d.id) then', true);
select oyun._yama('public.dernek_yonetim_ata(bigint,text,boolean)',
  $a$raise exception 'Yönetim kurulu en fazla 4 kişidir.';$a$,
  $b$raise exception 'Yönetim kurulu bu üye sayısıyla en fazla % kişi olabilir. Her 10 üye için kurula 1 kişi daha eklenir (en çok 12).', oyun.dernek_yk_siniri(d.id);$b$,
  'Her 10 üye için kurula', true);

select oyun._yama('public.dernek_detay(bigint)',
  $a$'harc', oyun.dernek_harci(),$a$,
  $b$'harc', oyun.dernek_harci(), 'yk_sinir', oyun.dernek_yk_siniri(d.id),$b$,
  'yk_sinir', true);
select oyun._yama('public.dernek_detay(bigint)',
  $a$jsonb_build_object('1', round(1000 * e / 100) * 100, '2', round(2000 * e / 100) * 100, '3', round(3000 * e / 100) * 100)$a$,
  $b$jsonb_build_object('1', round(oyun.tf('dernek_sube') * 1 * e / 100) * 100, '2', round(oyun.tf('dernek_sube') * 2 * e / 100) * 100, '3', round(oyun.tf('dernek_sube') * 3 * e / 100) * 100)$b$,
  $c$oyun.tf('dernek_sube') * 1 * e$c$, true);

commit;
