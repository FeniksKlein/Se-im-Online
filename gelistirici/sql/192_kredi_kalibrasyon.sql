-- =====================================================================
--  192 (11.11.2026) · KREDİ ÖDEME GÜCÜ KALİBRASYONU (191'in ince ayarı; Ercan: "mantıklı olan neyse öyle yap")
--  1) Limit, FAİZ DAHİL geri ödemeye göre hesaplanır. 191'de sabit %20 faiz tamponu vardı; oysa 1 yıllık kişisel
--     kredide faiz ~%65, şirket kredisinde ~%45. Artık tampon = max(1,20 ; 1 + o vadenin gerçek faizi):
--     kişi/şirket, anapara + faizin tamamını ödeme gücüyle karşılayabildiği kadar kredi alır.
--     Kısa vadelerde (1–4 hafta, 30–60 gün) sonuç değişmez.
--  2) Kişisel teminatta şirket payı, şirketin PİYASA değeri yerine DEFTER değeri (kasa + stok + arsa + yapı − borç)
--     üzerinden sayılır. Piyasa değeri son 7 günün kârının 10 katını içerir; kısa süreli ciro şişirmesiyle
--     kredi limiti büyütülemesin.
--  Oranlar (nakit %50, mevduat %80, mülk %50, şirket payı %30) ve diğer bütün kurallar aynı. Veri değişmez.
-- =====================================================================

create or replace function oyun.kredi_teminat(p_user uuid) returns jsonb
language sql stable set search_path = '' as $$
  with v as (
    select
      coalesce((select greatest(0, coalesce(c.para, 0)) from oyun.cuzdan c where c.user_id = p_user), 0)
        + coalesce((select greatest(0, coalesce(b.vadesiz, 0)) from oyun.banka_musteri b where b.user_id = p_user), 0) as nakit,
      coalesce((select sum(m.anapara) from oyun.banka_mevduat m where m.user_id = p_user and not m.kapandi and not coalesce(m.iptal, false)), 0)
        + coalesce((select sum(v.anapara) from oyun.vadeli v where v.user_id = p_user and v.durum = 'acik'), 0) as mevduat,
      coalesce((select sum(greatest(0, y.alis_bedeli)) from oyun.yatirim_mulkleri y where y.user_id = p_user), 0) as mulk,
      coalesce((select sum(least(oyun.sirket_defter(o.sirket_id), oyun.sirket_deger(o.sirket_id)) * o.pay / 100) from oyun.sirket_ortaklari o
                 join oyun.sirketler s on s.id = o.sirket_id and s.aktif where o.user_id = p_user and o.pay > 0), 0) as sirket,
      coalesce((select sum(k.kalan) from oyun.krediler k where k.user_id = p_user and k.durum in ('aktif','takip')), 0)
        + coalesce((select sum(k.kalan) from oyun.oyb_kredi k where k.borclu = p_user and k.durum in ('aktif','takip')), 0) as borc
  )
  select jsonb_build_object('nakit', round(nakit), 'mevduat', round(mevduat), 'mulk', round(mulk), 'sirket_paylari', round(sirket),
    'acik_borc', round(borc), 'likit', round(nakit * 0.50 + mevduat * 0.80), 'duran', round(mulk * 0.50 + sirket * 0.30))
  from v
$$;

create or replace function oyun.devlet_kredi_limit(p_user uuid, p_gun int, p_tem jsonb default null) returns jsonb
language plpgsql stable set search_path = '' as $$
declare r jsonb; tem jsonb; puan numeric; notu int; gelir_lim numeric; tem_lim numeric; lim numeric; neden text; engel boolean; f numeric;
begin
  r := oyun.kredi_risk_ozeti(p_user, p_gun * 24);
  tem := coalesce(p_tem, oyun.kredi_teminat(p_user));
  notu := coalesce((r->>'kredi_notu')::int, 1100);
  puan := case when notu < 700 then 0 when notu < 900 then .50 when notu < 1100 then .70 when notu < 1500 then .85 when notu < 1700 then .95 else 1 end;
  engel := (r->>'neden') in ('Kredi notu 700 altinda', 'Kara liste suresi devam ediyor', 'Vadesi gecen oyuncu bankasi kredisi var', 'Yasal takipte devlet bankasi kredisi var');
  -- geri ödeme çarpanı: kredi_cek ile aynı faiz formülü; en az 1,20
  f := greatest(1.20, 1 + coalesce(oyun.kredi_orani(p_user), 0) / 100 * p_gun / 30
                        + case when p_gun in (7, 14, 21, 28) then .0025 * (p_gun / 7 - 1) else 0 end);
  gelir_lim := coalesce((r->>'azami_kredi')::numeric, 0) * 1.20 / f;      -- risk özeti 1,20 ile bölünmüş gelir
  tem_lim := greatest(0, (tem->>'likit')::numeric + case when p_gun >= 60 then (tem->>'duran')::numeric else 0 end - (tem->>'acik_borc')::numeric)
             * puan / f;
  lim := case when engel then 0 else greatest(0, least(250000000, floor((gelir_lim + tem_lim) / 100) * 100)) end;
  neden := case when engel then r->>'neden'
                when lim < 1000 then 'Gelir ve teminat (nakit, mevduat, mülk, şirket payı) yetersiz'
                else 'Ödeme gücüne göre uygun' end;
  return r || jsonb_build_object('azami_kredi', lim, 'uygun', lim >= 1000, 'neden', neden, 'vade_gun', p_gun,
    'gelir_limiti', round(gelir_lim), 'teminat_limiti', round(tem_lim), 'geri_odeme_carpani', round(f, 4), 'teminat', tem);
end $$;

create or replace function oyun.sirket_kredi_kapasite(p_sirket bigint, p_gun int) returns jsonb
language plpgsql stable set search_path = '' as $$
declare s oyun.sirketler; net28 numeric; haftalik numeric; varlik numeric; acik numeric; borc numeric; gelir_kap numeric; tem numeric; kap numeric; f numeric;
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
  borc := oyun.yatirim_kredisi_borc(p_sirket);
  gelir_kap := haftalik * p_gun / 7.0 * 0.60;
  tem := varlik * 0.50 + greatest(0, coalesce(s.kasa, 0)) * 0.30;
  f := greatest(1.20, 1 + oyun.yatirim_kredisi_oran() / 100 * p_gun / 365);   -- faiz dahil geri ödeme
  kap := greatest(0, least(250000000, floor((gelir_kap + tem - borc - acik) / f / 100) * 100));
  return jsonb_build_object('vade', p_gun, 'kapasite', kap, 'haftalik_kar', round(haftalik), 'varlik', round(varlik),
    'kasa', round(coalesce(s.kasa, 0)), 'kredi_borcu', round(borc), 'acik_cek', round(acik), 'gelir_kapasitesi', round(gelir_kap),
    'teminat', round(tem), 'geri_odeme_carpani', round(f, 4));
end $$;

-- Genel limit: vadeler içindeki en yüksek ödeme gücü (uzun vadede faiz arttığı için en uzun vade her zaman en yüksek değildir)
create or replace function oyun.kredi_limiti(u uuid) returns numeric
language sql stable set search_path = '' as $$
  select coalesce(max((oyun.devlet_kredi_limit(u, g, t.tem)->>'azami_kredi')::numeric), 0)
    from (select oyun.kredi_teminat(u) tem) t, unnest(array[28, 60, 90, 180, 365]) g
$$;

revoke all on function oyun.kredi_teminat(uuid), oyun.devlet_kredi_limit(uuid, int, jsonb), oyun.sirket_kredi_kapasite(bigint, int) from public, anon, authenticated;
