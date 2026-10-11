-- Banka yöneticisi kredi paketini gizleyerek silebilir. Aktif krediler ve sözleşmeler korunur.
begin;
alter table oyun.oyb_kredi_paket add column if not exists silindi_at timestamptz;

CREATE OR REPLACE FUNCTION public.oyb_kredi_masasi(p_banka bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); s oyun.sirketler; yon boolean; r jsonb; sag jsonb; notu integer;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  select * into s from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif;
  if s.id is null then raise exception 'Banka bulunamadı.'; end if;
  -- süresi dolan teklifler
  update oyun.oyb_kredi_teklifi set durum = 'suresi' where banka_id = p_banka and durum = 'teklif' and son <= t;
  yon := oyun.oyb_yonetici(p_banka, u);
  sag := oyun.oyb_saglik(p_banka);
  select coalesce((select kredi_notu from oyun.banka_musteri where user_id = u), 1100) into notu;
  r := jsonb_build_object(
    'banka', jsonb_build_object('id', s.id, 'ad', s.ad, 'kasa', s.kasa, 'kredi_verilebilir', greatest(0, (sag->>'kredi_verilebilir')::numeric)),
    'yonetebilir', yon,
    'ortak', exists(select 1 from oyun.sirket_ortaklari where sirket_id = p_banka and user_id = u and pay > 0),
    'hesap', (select jsonb_build_object('acilis', h.acilis) from oyun.oyb_hesap h where h.banka_id = p_banka and h.user_id = u and h.kapanis is null),
    'kredi_notu', notu, 'not_ad', oyun.not_ad(notu),
    'baska_kredi', exists(select 1 from oyun.oyb_kredi where borclu = u and durum in ('basvuru','aktif')),
    'paketler', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'ad', p.ad, 'vade_gun', p.vade_gun, 'taksit_sayisi', p.taksit_sayisi,
        'faiz', p.faiz, 'min_tutar', p.min_tutar, 'max_tutar', p.max_tutar, 'otomatik', p.otomatik, 'min_not', p.min_not, 'aktif', p.aktif,
        'limitim', least(p.max_tutar, ((oyun.oyb_kredi_limit(u, p.vade_gun * 24))->>'azami_kredi')::numeric)) order by p.vade_gun, p.id)
      from oyun.oyb_kredi_paket p where p.banka_id = p_banka and p.silindi_at is null and (p.aktif or yon)), '[]'),
    'tekliflerim', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tutar', x.tutar, 'vade_gun', x.vade_gun, 'taksit_sayisi', x.taksit_sayisi,
        'faiz', x.faiz, 'mesaj', x.mesaj, 'son', x.son, 'plan', oyun.oyb_plan(x.tutar, x.vade_gun, x.taksit_sayisi, x.faiz, t)) order by x.id desc)
      from oyun.oyb_kredi_teklifi x where x.banka_id = p_banka and x.user_id = u and x.durum = 'teklif'), '[]'),
    'bilgi_talebi', (select jsonb_build_object('istenen', b.istenen, 'izinli', b.izinli, 'durum', b.durum, 'istek_at', b.istek_at)
      from oyun.oyb_hesap_bilgi b where b.banka_id = p_banka and b.user_id = u),
    'kredilerim', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'anapara', k.anapara, 'toplam', k.toplam, 'kalan', k.kalan, 'oran', k.oran,
        'vade_gun', round(k.saat / 24.0, 1), 'durum', case when k.durum = 'aktif' and exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t) then 'gecikmis' else k.durum end,
        'acilis', k.acilis, 'vade', k.vade, 'erken_kapama', oyun.oyb_erken_kapama_tutari(k, t), 'erken_kapandi', k.erken_kapama, 'erken_indirim', k.erken_indirim,
        'icra', (select i.durum from oyun.oyb_icra i where i.kredi_id = k.id),
        'taksitler', coalesce((select jsonb_agg(jsonb_build_object('sira', x.sira, 'vade', x.vade, 'tutar', x.tutar, 'odenen', x.odenen) order by x.sira)
          from oyun.oyb_kredi_taksit x where x.kredi_id = k.id), '[]')) order by k.id desc)
      from (select * from oyun.oyb_kredi where banka_id = p_banka and borclu = u order by id desc limit 10) k), '[]'));
  if yon then
    r := r || jsonb_build_object(
      'saglik', sag,
      'hesaplar', coalesce((select jsonb_agg(jsonb_build_object('kad', oyun.kad(h.user_id), 'acilis', h.acilis,
          'kredi_notu', coalesce(bm.kredi_notu, 1100),
          'borc', (select coalesce(sum(k.kalan), 0) from oyun.oyb_kredi k where k.banka_id = p_banka and k.borclu = h.user_id and k.durum = 'aktif'),
          'aktif_kredi', exists(select 1 from oyun.oyb_kredi k where k.borclu = h.user_id and k.durum in ('basvuru','aktif')),
          'bilgi', (select jsonb_build_object('durum', b.durum, 'istenen', b.istenen, 'izinli', b.izinli) from oyun.oyb_hesap_bilgi b where b.banka_id = p_banka and b.user_id = h.user_id),
          'teklif', (select jsonb_build_object('id', x.id, 'tutar', x.tutar, 'son', x.son) from oyun.oyb_kredi_teklifi x where x.banka_id = p_banka and x.user_id = h.user_id and x.durum = 'teklif' limit 1))
          order by h.acilis desc)
        from oyun.oyb_hesap h left join oyun.banka_musteri bm on bm.user_id = h.user_id
        where h.banka_id = p_banka and h.kapanis is null and h.user_id <> u), '[]'),
      'banka_kredileri', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'borclu', oyun.kad(k.borclu), 'anapara', k.anapara, 'toplam', k.toplam,
          'kalan', k.kalan, 'oran', k.oran, 'vade_gun', round(k.saat / 24.0, 1), 'durum', k.durum, 'acilis', k.acilis, 'vade', k.vade,
          'kaynak', case when k.paket_id is not null then 'paket' when k.teklif_id is not null then 'teklif' else 'basvuru' end,
          'geciken', (select coalesce(sum(x.tutar - x.odenen), 0) from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade < t),
          'dava_acilabilir', k.durum = 'aktif' and exists(select 1 from oyun.oyb_kredi_taksit x where x.kredi_id = k.id and x.odenen < x.tutar and x.vade + interval '12 hours' <= t)
            and not exists(select 1 from oyun.oyb_icra i where i.kredi_id = k.id),
          'icra', (select jsonb_build_object('id', i.id, 'durum', i.durum, 'tur', i.tur) from oyun.oyb_icra i where i.kredi_id = k.id),
          'risk', case when k.durum = 'basvuru' then oyun.oyb_kredi_limit(k.borclu, k.saat) end) order by (k.durum = 'basvuru') desc, k.id desc)
        from (select * from oyun.oyb_kredi where banka_id = p_banka and durum in ('basvuru','aktif') order by id desc limit 60) k), '[]'),
      'gonderilen_teklifler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kad', oyun.kad(x.user_id), 'tutar', x.tutar, 'vade_gun', x.vade_gun,
          'taksit_sayisi', x.taksit_sayisi, 'faiz', x.faiz, 'durum', x.durum, 'son', x.son) order by x.id desc)
        from (select * from oyun.oyb_kredi_teklifi where banka_id = p_banka order by id desc limit 20) x), '[]'));
  end if;
  return r;
end $function$
;

CREATE OR REPLACE FUNCTION public.oyb_paket_kaydet(p_banka bigint, p_id bigint, p_ad text, p_vade_gun integer, p_taksit integer, p_faiz numeric, p_min numeric, p_max numeric, p_otomatik boolean, p_min_not integer, p_aktif boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); yeni bigint;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if not oyun.oyb_yonetici(p_banka, u) then raise exception 'Bankanın kredi yönetim yetkin yok (en az %%50 hisse).'; end if;
  if not exists(select 1 from oyun.sirketler where id = p_banka and sektor = 'banka' and aktif) then raise exception 'Banka faal değil.'; end if;
  if p_vade_gun is null or p_vade_gun not between 1 and 30 then raise exception 'Vade 1–30 gün olmalı.'; end if;
  if p_taksit is null or p_taksit not between 1 and 30 or (p_vade_gun * 24) % p_taksit <> 0 then
    raise exception 'Taksit sayısı vadeye eşit bölünmeli (örneğin 30 gün için 1, 2, 3, 4, 5, 6, 10, 15, 30).'; end if;
  if p_faiz is null or p_faiz not between 0 and 20 then raise exception 'Faiz %%0 – %%20 arasında olmalı (vadenin tamamı için).'; end if;
  if p_min is null or p_max is null or p_min < 1000 or p_max > 10000000 or p_max < p_min then raise exception 'Tutar aralığı 1.000 – 10.000.000 ₺ içinde olmalı.'; end if;
  if char_length(btrim(coalesce(p_ad, ''))) not between 3 and 40 then raise exception 'Paket adı 3–40 karakter olmalı.'; end if;
  if p_id is null then
    if (select count(*) from oyun.oyb_kredi_paket where banka_id = p_banka and silindi_at is null) >= 8 then raise exception 'Bir banka en çok 8 kredi paketi tanımlayabilir.'; end if;
    insert into oyun.oyb_kredi_paket(banka_id, ad, vade_gun, taksit_sayisi, faiz, min_tutar, max_tutar, otomatik, min_not, aktif)
    values (p_banka, btrim(p_ad), p_vade_gun, p_taksit, p_faiz, p_min, p_max, coalesce(p_otomatik, true), coalesce(p_min_not, 900), coalesce(p_aktif, true))
    returning id into yeni;
  else
    update oyun.oyb_kredi_paket set ad = btrim(p_ad), vade_gun = p_vade_gun, taksit_sayisi = p_taksit, faiz = p_faiz, min_tutar = p_min, max_tutar = p_max,
      otomatik = coalesce(p_otomatik, true), min_not = coalesce(p_min_not, 900), aktif = coalesce(p_aktif, true)
    where id = p_id and banka_id = p_banka and silindi_at is null returning id into yeni;
    if yeni is null then raise exception 'Paket bulunamadı.'; end if;
  end if;
  return jsonb_build_object('tamam', true, 'id', yeni);
end $function$
;

create or replace function public.oyb_paket_sil(p_banka bigint, p_id bigint) returns jsonb
language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); silinen bigint;
begin
  if u is null then raise exception 'Oturum gerekli.'; end if;
  if p_banka is null or p_id is null then raise exception 'Banka ve kredi paketi gerekli.'; end if;
  if not oyun.oyb_yonetici(p_banka,u) then raise exception 'Bu bankanın kredi paketlerini silme yetkin yok.'; end if;
  update oyun.oyb_kredi_paket
     set aktif = false, silindi_at = oyun.simdi()
   where id = p_id and banka_id = p_banka and silindi_at is null
   returning id into silinen;
  if silinen is null then raise exception 'Kredi paketi bulunamadı veya daha önce silindi.'; end if;
  return jsonb_build_object('tamam',true,'id',silinen);
end $$;

revoke all on function public.oyb_paket_sil(bigint,bigint) from public, anon, authenticated;
grant execute on function public.oyb_paket_sil(bigint,bigint) to authenticated;
commit;
