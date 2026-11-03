-- 6 Kasım 2026 Cuma genel seçim + Cumhurbaşkanlığı seçimi (tek seferlik takvim).
-- İstek (Ercan, 03.11.2026): cumhurbaşkanlığı ve genel seçim bu cuma; adaylık süreçleri
-- oyunun erken seçim kurallarına göre takvime oturtulsun.
--
-- Oyunun erken seçim kuralı aynen uygulanır (oyun.erken_genel_secim_olustur ile aynı kayıtlar):
--   * Şimdiden 5 Kasım Perşembe 08.00'e kadar: milletvekili aday adaylığı, bağımsız adaylık,
--     genel başkanların Cumhurbaşkanı adayı kararı (kendisi / başka üye / ön seçim / destek),
--     CB ön seçimi başvurusu, ittifak ortak CB adayı önerisi.
--   * 5 Kasım Perşembe 08.00–22.00: milletvekili ve CB ön seçimleri, sonuç 22.30.
--   * 6 Kasım Cuma 08.00–22.00: genel seçim + CB seçimi, sonuç 22.30.
--   * 7 Kasım Cumartesi 00.00: vekiller ve Cumhurbaşkanı göreve başlar.
--     CB'de kimse %50'yi geçemezse 2. tur 7 Kasım Cumartesi 08.00–22.00 (motor kendisi kurar).
--   * İttifaklar oy verme başlayana kadar (6 Kasım 08.00) değiştirilebilir.
-- 1 Ocak 2027 Cuma olağan genel + CB seçimi İPTAL EDİLMEZ; bir sonraki olağan seçim odur.
-- Belediye (10 Kasım) ve kurultay (18 Kasım) takvimi değişmez.
--
-- Oyuncu verisine (makam, para, kıdem, oy, aday) dokunmaz; yalnız seçim kayıtları ve duyuru ekler.
-- tek_seferlik anahtarıyla korunur; iki kez çalışsa da ikinci kez bir şey yapmaz.
-- Canlıda öncesi yedek: yedek_20261103_225416_915897
do $$
declare
  t timestamptz := oyun.simdi();
  ongun date := date '2026-11-05';
  secgun date := date '2026-11-06';
  dm text;
  metin text;
  r record;
begin
  -- Aynı anda iki erken seçim takvimi açılmasını engelle (cb_erken_secim_karar ile aynı kilit).
  perform 1 from oyun.ayarlar where id = 1 for update;

  insert into oyun.tek_seferlik(anahtar, zaman) values ('genel_cb_secim_20261106', t) on conflict do nothing;
  if not found then
    raise notice '6 Kasım seçim takvimi daha önce kurulmuş; bir şey yapılmadı.';
    return;
  end if;

  if t >= oyun.tr_an(ongun, 8) then
    raise exception 'Ön seçim saati (5 Kasım 08.00) geçti; 6 Kasım takvimi kurulamaz.';
  end if;
  if exists (select 1 from oyun.secimler where ara and ara_neden = 'erken_secim' and durum = 'bekliyor') then
    raise exception 'Bekleyen bir erken seçim takvimi zaten var.';
  end if;
  if exists (select 1 from oyun.secimler where tur in ('mv_on','mv','cb_on','cb','cb2')
             and durum = 'bekliyor' and oy_bas <= t and oy_bit > t) then
    raise exception 'Şu anda süren bir genel seçim/ön seçim oylaması var.';
  end if;

  dm := 'erken-genel-0-' || to_char(t at time zone 'Europe/Istanbul', 'YYYYMMDDHH24MISS');

  insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas, ara, ara_neden) values
    ('mv_on', dm, t, oyun.tr_an(ongun,8), oyun.tr_an(ongun,8), oyun.tr_an(ongun,22), oyun.tr_an(ongun,22,30), null, true, 'erken_secim'),
    ('mv',    dm, null, null, oyun.tr_an(secgun,8), oyun.tr_an(secgun,22), oyun.tr_an(secgun,22,30), oyun.tr_an(secgun+1,0), true, 'erken_secim');

  if oyun.hukumet_sistemi() = 0 then
    insert into oyun.secimler(tur, donem, basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas, ara, ara_neden) values
      ('cb_on', dm, t, oyun.tr_an(ongun,8), oyun.tr_an(ongun,8), oyun.tr_an(ongun,22), oyun.tr_an(ongun,22,30), null, true, 'erken_secim'),
      ('cb',    dm, t, oyun.tr_an(ongun,8), oyun.tr_an(secgun,8), oyun.tr_an(secgun,22), oyun.tr_an(secgun,22,30), oyun.tr_an(secgun+1,0), true, 'erken_secim');
  end if;

  perform oyun.olay('secim',
    'Seçim takvimi açıklandı: genel seçim ve Cumhurbaşkanlığı seçimi 6 Kasım Cuma 08.00–22.00. '
    || 'Aday adaylığı ve Cumhurbaşkanı adayı kararları 5 Kasım Perşembe 08.00''e kadar, ön seçimler 5 Kasım Perşembe 08.00–22.00.',
    null, null, t);

  metin := 'Resmî duyuru · Genel seçim ve Cumhurbaşkanlığı seçimi 6 Kasım Cuma 08.00–22.00 arasında yapılacak. '
    || 'Milletvekili aday adaylığı, bağımsız adaylık, CB ön seçimi başvurusu ve genel başkanların Cumhurbaşkanı adayı kararı 5 Kasım Perşembe 08.00''e kadar açık. '
    || 'Ön seçimler 5 Kasım Perşembe 08.00–22.00. Sonuçlar 6 Kasım 22.30''da açıklanır, kazananlar 7 Kasım''da göreve başlar. '
    || 'Takvim: Seçimler ekranı.';
  for r in select p.id from oyun.profiller p where not p.yasakli loop
    perform oyun.bildir(r.id, metin, t);
  end loop;

  perform oyun.gazete_ekle('duyuru', 'Genel seçim ve Cumhurbaşkanlığı seçimi 6 Kasım Cuma',
    'Genel seçim ile Cumhurbaşkanlığı seçimi 6 Kasım 2026 Cuma günü 08.00–22.00 saatleri arasında yapılacaktır. '
    || '(1) Başvurular: Milletvekili aday adaylığı, bağımsız adaylık ve Cumhurbaşkanlığı ön seçimi başvuruları 5 Kasım Perşembe saat 08.00''e kadar alınır. '
    || 'Partilerin genel başkanları Cumhurbaşkanı adayını aynı saate kadar belirler: kendisi, partiden başka bir üye, üyelerin ön seçimi ya da başka bir partinin adayına destek. '
    || 'İttifaklar ortak Cumhurbaşkanı adayını aynı süre içinde önerebilir; ittifaklarda değişiklik oy verme başlayana kadar yapılabilir. '
    || '(2) Ön seçimler: 5 Kasım Perşembe 08.00–22.00; partinin ildeki üyeleri milletvekili liste sırasını, ön seçim kararı alan partilerin üyeleri Cumhurbaşkanı adayını belirler. Sonuçlar 22.30''da açıklanır. '
    || '(3) Seçim: 6 Kasım Cuma 08.00–22.00, sonuçlar 22.30. Milletvekilleri ve Cumhurbaşkanı 7 Kasım Cumartesi 00.00''da göreve başlar. '
    || 'Cumhurbaşkanlığında hiçbir aday geçerli oyların yarısından fazlasını alamazsa ilk iki aday 7 Kasım Cumartesi 08.00–22.00 arasında ikinci tura kalır. '
    || '(4) Bir sonraki olağan genel seçim ve Cumhurbaşkanlığı seçimi 1 Ocak 2027 Cuma günüdür. Belediye seçimi (10 Kasım) ve kurultay (18 Kasım) takvimi değişmemiştir.',
    null, t);
end $$;
