-- 160 (02.11.2026) — BANKA GÜVEN NOTU: GECİKME SINIFLAMASI VE ÖNEMLİLİK
-- Oyuncu şikâyeti (beta sohbeti, 01.11.2026): 68 bin liralık kredinin 3 bin liralık taksidi birkaç saat gecikince
-- 12 milyon liralık bankanın notu AAA'dan A'ya düşüyor.
--
-- Kök neden (135 · oyun.banka_bilanco):
--   1) Tek bir taksit bir dakika bile gecikse kredinin KALAN BAKİYESİNİN TAMAMI "takipteki alacak" sayılıyordu.
--   2) Takipteki oran yalnız kredi defterine bölünüyordu; bankanın 11 milyonluk kasası, özkaynağı hiç hesaba girmiyordu.
--      Kredi defteri küçük bankada birkaç binlik gecikme bile %15-20 "takipteki" görünüp notu iki basamak düşürüyordu.
--
-- Gerçek bankacılıkta (BDDK sınıflandırma yönetmeliği, TFRS 9 aşamaları):
--   • 30 güne kadar gecikme: kredi normal sayılır (1. aşama).
--   • 30-90 gün: "yakın izlemedeki kredi" (2. aşama); takipteki değildir.
--   • 90 gün ve üzeri ya da yasal takip: "takipteki alacak" (3. aşama, NPL).
--   • Derecelendirme kuruluşları sorunlu krediyi bankanın zarar karşılama gücüyle (özkaynak) birlikte değerlendirir.
-- Oyunda bir gün ≈ bir ay (krediler 20-30 günlük, taksitler günlük). Buna göre:
--   • gecikme < 24 saat  → normal (yalnız "geciken taksit" bilgisi)
--   • 24-72 saat         → yakın izleme
--   • ≥ 72 saat, açık icra takibi ya da durum 'takip' → takipteki alacak
--   • Not cezası, sorunlu kredinin oranı × bankanın kredi riskinin özkaynağa göre ağırlığı (en az %20) ile
--     sorunlu kredinin özkaynağa oranından (sermaye etkisi) büyük olanıdır.
-- Oyuncu verisini değiştirmez; yalnız hesaplama ve gösterim fonksiyonları yenilenir. İki kez çalıştırmak güvenlidir.

-- ---------------------------------------------------------------------
-- A. Tek kredinin sınıfı: 1 normal · 2 yakın izleme · 3 takipteki
-- ---------------------------------------------------------------------
create or replace function oyun.oyb_kredi_gecikme_bas(p_kredi bigint, t timestamptz default null)
returns timestamptz language sql stable security definer set search_path = '' as $$
  -- Ödenmemiş ve vadesi geçmiş ilk taksitin vadesi; taksit planı olmayan eski kredilerde kredi vadesi.
  select coalesce(
    (select min(x.vade) from oyun.oyb_kredi_taksit x
      where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < coalesce(t, oyun.simdi())),
    case when k.vade < coalesce(t, oyun.simdi()) and k.kalan > 0
              and not exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id)
         then k.vade end)
  from oyun.oyb_kredi k where k.id = p_kredi
$$;

create or replace function oyun.oyb_kredi_sinif(p_kredi bigint, t timestamptz default null)
returns smallint language plpgsql stable security definer set search_path = '' as $$
declare k oyun.oyb_kredi; z timestamptz := coalesce(t, oyun.simdi()); bas timestamptz;
begin
  select * into k from oyun.oyb_kredi where id = p_kredi;
  if k.id is null or k.durum not in ('aktif', 'takip') or coalesce(k.kalan, 0) <= 0 then return 1; end if;
  if k.durum = 'takip' then return 3; end if;
  if to_regclass('oyun.oyb_icra') is not null
     and exists(select 1 from oyun.oyb_icra i where i.kredi_id = k.id and i.durum = 'acik') then return 3; end if;
  bas := oyun.oyb_kredi_gecikme_bas(k.id, z);
  if bas is null then return 1; end if;
  if bas <= z - interval '72 hours' then return 3; end if;
  if bas <= z - interval '24 hours' then return 2; end if;
  return 1;
end $$;

-- ---------------------------------------------------------------------
-- B. Bilanço, oranlar ve güven notu (135'teki sürümün yerine; anahtarlar korunur, yenileri eklenir)
-- ---------------------------------------------------------------------
create or replace function oyun.banka_bilanco(p_banka bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  s oyun.sirketler; t timestamptz := oyun.simdi();
  nakit numeric; kredi numeric := 0; kredi_izl numeric := 0; kredi_gec numeric := 0; taksit_gec numeric := 0;
  kart numeric := 0; kart_izl numeric := 0; kart_gec numeric := 0; dibs numeric := 0;
  vadesiz numeric := 0; vadeli_ana numeric := 0; vadeli_yuk numeric := 0; yakin numeric := 0; gecik_mev numeric := 0;
  tampon numeric; rezerv numeric; riskli numeric; ozk numeric; emniyet numeric := 0; al numeric;
  kv numeric; dag numeric; azalt numeric; lik numeric; syr numeric; npl numeric; izl numeric; km numeric;
  sorunlu numeric; sorunlu_ozk numeric; agirlik numeric;
  c_lik int := 0; c_syr int := 0; c_npl int := 0; c_izl int := 0; c_mev int := 0; c_ozk int := 0;
  c_npl_oran numeric := 0; c_npl_sermaye int := 0;
  puan int := 100; harf text; v_durum text; etken jsonb := '[]'::jsonb;
begin
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka';
  if s.id is null then raise exception 'Banka bulunamadı.'; end if;
  nakit := coalesce(s.kasa, 0);

  -- Kredi defteri: her kredi kalan bakiyesiyle tek bir sınıfa girer; geciken taksit tutarı ayrıca toplanır.
  select coalesce(sum(k.kalan), 0),
         coalesce(sum(k.kalan) filter (where x.sinif = 2), 0),
         coalesce(sum(k.kalan) filter (where x.sinif = 3), 0),
         coalesce(sum(x.geciken), 0)
    into kredi, kredi_izl, kredi_gec, taksit_gec
    from oyun.oyb_kredi k
    cross join lateral (
      select oyun.oyb_kredi_sinif(k.id, t) as sinif,
             coalesce((select sum(tk.tutar - tk.odenen) from oyun.oyb_kredi_taksit tk
                        where tk.kredi_id = k.id and tk.odenen < tk.tutar and tk.vade < t), 0) as geciken) x
   where k.banka_id = p_banka and k.durum in ('aktif','takip');

  -- Kartlar: asgari ödemesi gecikmiş kart yakın izlemede; yasal takipteki ya da kapatılmış borçlu kart takipte.
  if to_regclass('oyun.kredi_kartlari') is not null then
    select coalesce(sum(borc), 0),
           coalesce(sum(borc) filter (where gecikmis_asgari > 0 and durum not in ('takip','kapali')), 0),
           coalesce(sum(borc) filter (where durum in ('takip','kapali')), 0)
      into kart, kart_izl, kart_gec
      from oyun.kredi_kartlari where banka_id = p_banka and borc > 0;
  end if;

  select coalesce(sum(tutar), 0) into dibs from oyun.banka_dibs where banka_id = p_banka and durum = 'acik';
  vadesiz := oyun.banka_vadesiz_toplam(p_banka);

  select coalesce(sum(anapara), 0),
         coalesce(sum(round(anapara * (1 + faiz / 100), 2)), 0),
         coalesce(sum(round(anapara * (1 + faiz / 100), 2)) filter (where vade <= t + interval '24 hours'), 0),
         coalesce(sum(round(anapara * (1 + faiz / 100), 2)) filter (where vade <= t), 0)
    into vadeli_ana, vadeli_yuk, yakin, gecik_mev
    from oyun.banka_mevduat where banka_id = p_banka and not kapandi;

  emniyet := coalesce((select emniyet_payi from oyun.banka_politika where banka_id = p_banka), 0);

  -- Yasal tampon: sermayenin ya da toplam mevduatın %10'u (hangisi büyükse)
  tampon := greatest(round(s.sermaye * .10, 2), round((vadeli_ana + vadesiz) * .10, 2));
  -- Likidite rezervi: vadesizin %30'u + (vadelilerin yarısı ya da 24 saatte ödenecekler) + tampon
  rezerv := round(vadesiz * .30, 2) + greatest(round(vadeli_ana * .50, 2), yakin) + tampon;
  -- Risk ağırlıklı varlıklar (DİBS risksiz). Yalnız takipteki alacak %150 ağırlık alır.
  riskli := (kredi - kredi_gec) + kredi_gec * 1.5 + (kart - kart_gec) + kart_gec * 1.5;
  -- Özkaynak = varlıklar - borçlar
  ozk := nakit + kredi + kart + dibs - vadesiz - vadeli_yuk;
  -- Kredi kapasitesi: normal kredi %70, yakın izleme %50, takipteki %25 tahsil edilebilir sayılır.
  al := (kredi - kredi_izl - kredi_gec) * .70 + kredi_izl * .50 + kredi_gec * .25;
  kv := greatest(0, least(nakit - rezerv - emniyet, (nakit + al - vadeli_yuk - vadesiz - tampon) / .30));
  -- Dağıtılabilir kâr: birikmiş kâr, kasadaki serbest nakit ve %12 sermaye yeterliliği sınırı
  dag := greatest(0, least(ozk - s.sermaye, nakit - rezerv, ozk - riskli * .12));
  -- Sermaye azaltımı: asgari 1.000.000 ₺ sermaye, nakit ve %12 sınırı
  azalt := greatest(0, least(s.sermaye - 1000000, nakit - rezerv, ozk - riskli * .12));

  lik := case when (vadesiz + yakin + vadeli_ana * .5) > 0 then round(nakit / (vadesiz + yakin + vadeli_ana * .5), 2) end;
  syr := case when riskli > 0 then round(ozk / riskli * 100, 1) end;
  npl := case when (kredi + kart) > 0 then round((kredi_gec + kart_gec) / (kredi + kart) * 100, 1) else 0 end;
  izl := case when (kredi + kart) > 0 then round((kredi_izl + kart_izl) / (kredi + kart) * 100, 1) else 0 end;
  km  := case when (vadesiz + vadeli_ana) > 0 then round((kredi + kart) / (vadesiz + vadeli_ana) * 100, 1) end;
  sorunlu := kredi_gec + kart_gec;
  sorunlu_ozk := case when ozk > 0 then round(sorunlu / ozk * 100, 1) end;
  -- Kredi riskinin bankadaki ağırlığı: kredi defteri özkaynağa göre ne kadar büyükse oranlar o kadar önemli.
  agirlik := case when ozk > 0 then greatest(0.2, least(1, (kredi + kart) / ozk)) else 1 end;

  if lik is not null then c_lik := case when lik < 1 then 35 when lik < 1.2 then 15 else 0 end; end if;
  if syr is not null then c_syr := case when syr < 8 then 40 when syr < 12 then 20 when syr < 15 then 8 else 0 end; end if;
  if sorunlu > 0 then
    c_npl_oran := (case when npl > 20 then 30 when npl > 10 then 15 when npl > 5 then 6 else 0 end) * agirlik;
    c_npl_sermaye := case when sorunlu_ozk is null then 30 when sorunlu_ozk > 50 then 30 when sorunlu_ozk > 25 then 20
                          when sorunlu_ozk > 10 then 10 when sorunlu_ozk > 5 then 4 else 0 end;
    c_npl := round(greatest(c_npl_oran, c_npl_sermaye));
  end if;
  c_izl := round((case when izl > 30 then 6 when izl > 15 then 3 else 0 end) * agirlik);
  if gecik_mev > 0 and nakit < gecik_mev then c_mev := 40; end if;
  if ozk < s.sermaye * .5 then c_ozk := 20; end if;
  puan := 100 - c_lik - c_syr - c_npl - c_izl - c_mev - c_ozk;

  harf := case when puan >= 95 then 'AAA' when puan >= 88 then 'AA' when puan >= 80 then 'A' when puan >= 70 then 'BBB'
               when puan >= 60 then 'BB' when puan >= 45 then 'B' else 'C' end;
  v_durum := case when puan >= 80 then 'saglam' when puan >= 60 then 'dikkat' else 'riskli' end;

  -- Notu etkileyen kalemler (Genel Müdürlük ekranında gösterilir; puanı düşürmeyenler de bilgi için yazılır)
  if c_lik > 0 then etken := etken || jsonb_build_object('kod','likidite','ceza',c_lik,
     'aciklama', format('Kasa, hemen ödenebilecek mevduatın %s katı (güvenli eşik 1,2).', replace(lik::text, '.', ','))); end if;
  if c_syr > 0 then etken := etken || jsonb_build_object('kod','sermaye','ceza',c_syr,
     'aciklama', format('Sermaye yeterliliği %%%s (yasal alt sınır %%12).', replace(syr::text, '.', ','))); end if;
  if sorunlu > 0 then etken := etken || jsonb_build_object('kod','takipteki','ceza',c_npl,
     'aciklama', format('Takipteki alacak %s ₺. Kredi ve kartlara oranı %%%s, özkaynağa oranı %%%s.',
        oyun.tl(sorunlu), replace(npl::text, '.', ','), replace(coalesce(sorunlu_ozk, 100)::text, '.', ','))); end if;
  if kredi_izl + kart_izl > 0 then etken := etken || jsonb_build_object('kod','izleme','ceza',c_izl,
     'aciklama', format('Yakın izlemede %s ₺ (taksidi 1-3 gündür gecikmiş). Takibe düşmeden ödenirse not etkilenmez.',
        oyun.tl(kredi_izl + kart_izl))); end if;
  if taksit_gec > 0 and kredi_izl + kredi_gec = 0 then etken := etken || jsonb_build_object('kod','gecikme','ceza',0,
     'aciklama', format('%s ₺ taksit 24 saatten kısa süredir gecikmede; bu, nota yansımaz.', oyun.tl(taksit_gec))); end if;
  if c_mev > 0 then etken := etken || jsonb_build_object('kod','mevduat','ceza',c_mev,
     'aciklama', 'Vadesi gelen mevduatı ödeyecek nakit yok.'); end if;
  if c_ozk > 0 then etken := etken || jsonb_build_object('kod','ozkaynak','ceza',c_ozk,
     'aciklama', 'Özkaynak sermayenin yarısının altına indi.'); end if;

  return jsonb_build_object(
    'nakit', round(nakit, 2), 'krediler', round(kredi, 2), 'krediler_geciken', round(kredi_gec, 2),
    'krediler_izleme', round(kredi_izl, 2), 'geciken_taksit', round(taksit_gec, 2),
    'kart_alacak', round(kart, 2), 'kart_geciken', round(kart_gec, 2), 'kart_izleme', round(kart_izl, 2), 'dibs', round(dibs, 2),
    'varlik', round(nakit + kredi + kart + dibs, 2),
    'vadesiz', round(vadesiz, 2), 'vadeli_anapara', round(vadeli_ana, 2), 'vadeli_yukumluluk', round(vadeli_yuk, 2),
    'yaklasan_odeme', round(yakin, 2), 'geciken_mevduat', round(gecik_mev, 2),
    'borc', round(vadesiz + vadeli_yuk, 2),
    'ozkaynak', round(ozk, 2), 'sermaye', s.sermaye, 'birikmis_kar', round(ozk - s.sermaye, 2),
    'tampon', round(tampon, 2), 'rezerv', round(rezerv, 2), 'emniyet_payi', emniyet,
    'riskli_varlik', round(riskli, 2),
    'kredi_verilebilir', round(kv, 2), 'dagitilabilir_kar', round(dag, 2), 'sermaye_azaltilabilir', round(azalt, 2),
    'dibs_alinabilir', round(greatest(0, nakit - rezerv), 2),
    'likidite', lik, 'sermaye_yeterlilik', syr, 'takipteki_oran', npl, 'izleme_oran', izl, 'kredi_mevduat', km,
    'takipteki_ozkaynak', sorunlu_ozk, 'kredi_agirlik', round(agirlik, 3),
    'not_etkenleri', etken,
    'puan', greatest(0, puan), 'not', harf, 'durum', v_durum);
end $$;

-- ---------------------------------------------------------------------
-- C. Genel Müdürlük kredi listesine sınıf ve gecikme başlangıcı (yalnız ek alan; ifade bir kez geçer)
-- ---------------------------------------------------------------------
do $duzelt$
declare d text; eski text; yeni text; adet int;
begin
  if to_regprocedure('public.banka_genel_mudurluk(bigint)') is null then
    raise notice 'banka_genel_mudurluk bu kurulumda yok, atlandı'; return;
  end if;
  d := pg_get_functiondef('public.banka_genel_mudurluk(bigint)'::regprocedure);
  eski := $e$'acilis', k.acilis, 'vade', k.vade,$e$;
  yeni := $y$'acilis', k.acilis, 'vade', k.vade, 'sinif', oyun.oyb_kredi_sinif(k.id, t), 'gecikme_bas', oyun.oyb_kredi_gecikme_bas(k.id, t),$y$;
  if position(yeni in d) > 0 then raise notice 'banka_genel_mudurluk zaten güncel'; return; end if;
  adet := (length(d) - length(replace(d, eski, ''))) / length(eski);
  if adet <> 1 then raise notice 'banka_genel_mudurluk: ifade % kez geçiyor, atlandı', adet; return; end if;
  execute replace(d, eski, yeni);
end $duzelt$;

revoke all on function oyun.oyb_kredi_sinif(bigint, timestamptz) from public, anon, authenticated;
revoke all on function oyun.oyb_kredi_gecikme_bas(bigint, timestamptz) from public, anon, authenticated;
revoke all on function oyun.banka_bilanco(bigint) from public, anon, authenticated;
