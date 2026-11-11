-- =====================================================================
--  199 (11.11.2026) · ŞİRKET KREDİ KAPASİTESİ DÜZELTMESİ (191/192'nin hatası)
--  Hata: kapasite hesabında mevcut kredilerin yalnız ANAPARASI düşülüyor, üstelik çekilen kredinin kasaya giren
--  parası %30 teminat sayılıyordu. Bu yüzden aynı şirket art arda kredi çekerek (her seferinde limitin ~%52'si)
--  toplamda ilk limitin yaklaşık 2 katına ulaşabiliyordu; geri ödeme (anapara + faiz) şirketin ödeme gücünü aşıyordu.
--  Düzeltme:
--   • Mevcut kredilerin FAİZ DAHİL kalan geri ödemesi düşülür: istenen vade içinde ödenecek taksitler gelir
--     kapasitesinden, vade sonrasına kalan borç teminattan.
--   • Kasa teminatında kredi parası sayılmaz: yalnız (kasa − açık kredilerin kalan anaparası) × %30.
--  Sonuç: bir şirket, vadesi içinde kârının %60'ı ve teminatıyla geri ödeyebileceği kadar borçlanır; ikinci kez
--  aynı kapasiteyi kullanamaz. Mevcut krediler ve bakiyeler değişmez.
-- =====================================================================
create or replace function oyun.sirket_kredi_kapasite(p_sirket bigint, p_gun int) returns jsonb
language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler; net28 numeric; haftalik numeric; varlik numeric; acik numeric; gelir_kap numeric; tem numeric; kap numeric; f numeric;
  d_vade numeric; d_top numeric; d_ana numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null then return jsonb_build_object('kapasite', 0); end if;
  select coalesce(sum(coalesce(h.faaliyet_gelir, 0) - coalesce(h.faaliyet_gider, 0)), 0) into net28
    from oyun.sirket_hareket h where h.sirket_id = p_sirket and h.zaman >= now() - interval '28 days';
  haftalik := greatest(0, net28 / 4);
  varlik := coalesce((select sum(adet * maliyet_birim) from oyun.eko_urun_stok where sirket_id = s.id), 0)
          + coalesce((select sum(fiyat) from oyun.eko_arsalar where sahibi_sirket = s.id), 0)
          + coalesce((select sum(maliyet) from oyun.eko_yapilar where sirket_id = s.id), 0);
  select coalesce(sum(greatest(0, c.tutar - coalesce(c.odenen, 0))), 0) into acik
    from oyun.cekler c where c.borclu_sirket = p_sirket and c.durum in ('aktif','karsiliksiz');
  -- açık krediler: bu vade içinde ödenecek kısım, toplam kalan (faiz dahil), kalan anapara
  select coalesce(sum(least(y.kalan, y.gecikmis + y.taksit * p_gun)), 0), coalesce(sum(y.kalan), 0),
         coalesce(sum(round(y.kalan * y.anapara / nullif(y.toplam, 0))), 0)
    into d_vade, d_top, d_ana
    from oyun.yatirim_kredisi y where y.sirket_id = p_sirket and y.durum <> 'kapandi';
  gelir_kap := haftalik * p_gun / 7.0 * 0.60;
  tem := varlik * 0.50 + greatest(0, coalesce(s.kasa, 0) - d_ana) * 0.30;
  f := greatest(1.20, 1 + oyun.yatirim_kredisi_oran() / 100 * p_gun / 365);   -- faiz dahil geri ödeme
  kap := greatest(0, least(250000000, floor(((gelir_kap - d_vade) + greatest(0, tem - (d_top - d_vade)) - acik) / f / 100) * 100));
  return jsonb_build_object('vade', p_gun, 'kapasite', kap, 'haftalik_kar', round(haftalik), 'varlik', round(varlik),
    'kasa', round(coalesce(s.kasa, 0)), 'kredi_borcu', round(d_ana), 'kalan_geri_odeme', round(d_top), 'vade_ici_taksit', round(d_vade),
    'acik_cek', round(acik), 'gelir_kapasitesi', round(gelir_kap), 'teminat', round(tem), 'geri_odeme_carpani', round(f, 4));
end $$;
revoke all on function oyun.sirket_kredi_kapasite(bigint, int) from public, anon, authenticated;
