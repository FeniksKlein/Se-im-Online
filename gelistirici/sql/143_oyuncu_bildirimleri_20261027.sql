-- =====================================================================
--  143 · OYUNCU BİLDİRİMLERİ — 27.10.2026
--  Beta oyuncularının bildirdiği sorunlar:
--  1) Hazine birim hatası: otomatik stok yenileme aboneliğinin 12.000 ₺'si
--     Hazine'ye "12.000 milyar ₺" olarak yazılıyordu (her abonelikte).
--     Aynı türden küçük birim hataları (milyon / milyar bölenleri) de
--     oyunun TL ↔ milyar çevirisine (oyun.pazar_tl_milyar) bağlandı.
--     Mevcut Hazine bakiyesine DOKUNULMAZ; yalnız bundan sonraki kayıtlar
--     doğru birimle yazılır.
--  2) Cüzdan: son 24 saatte cüzdana giren / çıkan paranın kaynağı
--     (public.cuzdan_hareketleri).
--  3) Şirket satın alırken inceleme raporu: sermaye, kasa, ciro, kâr,
--     kâr marjı, sermaye getirisi (public.sirket_satis_raporu).
--     Kasa; şirketin tamamı satılıkken (alıcıya kasasıyla devredildiği
--     için), ortağa ya da sahibi kasayı "herkese açık" yaptıysa görünür.
--     Hisse ilanında ve borsadaki şirkette kasa, satıcı / sahip açtıysa
--     görünür; ciro ve kârlılık her durumda görünür.
--  Yalnız fonksiyon ekler ve tek ifade değiştirir; iki kez çalıştırmak güvenlidir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Hazine birim düzeltmeleri (canlı tanımı okur, tek ifadeyi değiştirir;
--    ifade yoksa — zaten düzeltilmişse — dokunmaz)
-- ---------------------------------------------------------------------
do $hazine$
declare
  r record; d text;
begin
  for r in select * from (values
    ('public.eko_ticaret_islem(text,jsonb)',
     'update oyun.ulke set hazine=hazine+12000 where id=1',
     'update oyun.ulke set hazine=hazine+12000/oyun.pazar_tl_milyar() where id=1'),
    ('public.cek_ticaret_islem(text,jsonb)',
     'update oyun.ulke set hazine=hazine+2*v_harc/1000000.0 where id=1',
     'update oyun.ulke set hazine=hazine+2*v_harc/oyun.pazar_tl_milyar() where id=1'),
    ('oyun.icra_tahsil_et(bigint,numeric,text)',
     'UPDATE oyun.ulke SET hazine=hazine+v/1000000000 WHERE id=1',
     'UPDATE oyun.ulke SET hazine=hazine+v/oyun.pazar_tl_milyar() WHERE id=1'),
    ('oyun.mulk_tapu_bedel_ode(uuid,uuid,numeric,bigint,timestamptz)',
     'UPDATE oyun.ulke SET hazine=hazine+2*h/1000000.0 WHERE id=1',
     'UPDATE oyun.ulke SET hazine=hazine+2*h/oyun.pazar_tl_milyar() WHERE id=1'),
    ('oyun.yatirim_pazar_kira_tahsil(uuid)',
     'update oyun.ulke set hazine=hazine+tax/1000000.0 where id=1',
     'update oyun.ulke set hazine=hazine+tax/oyun.pazar_tl_milyar() where id=1')
  ) v(fn, eski, yeni) loop
    if to_regprocedure(r.fn) is null then continue; end if;
    d := pg_get_functiondef(to_regprocedure(r.fn));
    if position(r.eski in d) > 0 then
      begin
        execute replace(d, r.eski, r.yeni);
      exception when others then
        raise warning 'Hazine birim düzeltmesi uygulanamadı (%): %', r.fn, sqlerrm;
      end;
    end if;
  end loop;
end $hazine$;

-- ---------------------------------------------------------------------
-- 2) Cüzdan hareketleri: son N saat (varsayılan 24) — kaynak ve gideri
-- ---------------------------------------------------------------------
create or replace function public.cuzdan_hareketleri(p_saat int default 24)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s int := least(greatest(coalesce(p_saat, 24), 1), 168);
  bas timestamptz := t - make_interval(hours => least(greatest(coalesce(p_saat, 24), 1), 168));
begin
  return jsonb_build_object(
    'saat', s, 'bas', bas, 'simdi', t,
    'para', (select c.para from oyun.cuzdan c where c.user_id = p.id),
    'giris', coalesce((select sum(h.tutar) from oyun.hesap_hareket h where h.user_id = p.id and h.zaman > bas and h.tutar > 0), 0),
    'cikis', coalesce((select -sum(h.tutar) from oyun.hesap_hareket h where h.user_id = p.id and h.zaman > bas and h.tutar < 0), 0),
    'vergi', coalesce((select sum(h.vergi) from oyun.hesap_hareket h where h.user_id = p.id and h.zaman > bas and h.vergi > 0), 0),
    'adet', (select count(*) from oyun.hesap_hareket h where h.user_id = p.id and h.zaman > bas),
    'gruplar', coalesce((select jsonb_agg(jsonb_build_object('tur', g.tur, 'giris', g.giris, 'cikis', g.cikis, 'adet', g.adet)
                           order by g.giris + g.cikis desc)
                         from (select h.tur, coalesce(sum(h.tutar) filter (where h.tutar > 0), 0) giris,
                                      coalesce(-sum(h.tutar) filter (where h.tutar < 0), 0) cikis, count(*) adet
                                 from oyun.hesap_hareket h where h.user_id = p.id and h.zaman > bas group by h.tur) g), '[]'::jsonb),
    'liste', coalesce((select jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', h.tutar, 'vergi', h.vergi, 'tur', h.tur, 'aciklama', h.aciklama)
                          order by h.zaman desc, h.id desc)
                        from (select * from oyun.hesap_hareket x where x.user_id = p.id and x.zaman > bas
                              order by x.zaman desc, x.id desc limit 300) h), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- 3) Şirket satın alma incelemesi
-- ---------------------------------------------------------------------
create or replace function public.sirket_satis_raporu(p_sirket bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  u uuid := (oyun.profilim()).id;
  t timestamptz := oyun.simdi();
  s oyun.sirketler;
  ilan oyun.ilanlar;
  ortak boolean; tam_satis boolean; hisse_ilani boolean; borsa boolean; kasa_acik boolean;
  pr30 record; sh30 record; pr7 record; sh7 record; top record;
  g30 numeric; d30 numeric; n30 numeric; g7 numeric; d7 numeric; n7 numeric; kaynak text;
  fiyat numeric; stok numeric; sube int; sn int;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null or not s.aktif then raise exception 'Şirket bulunamadı ya da faal değil.'; end if;
  if s.sektor = 'banka' then raise exception 'Bankaların mali tablosu Banka Genel Müdürlüğü ve güven notu ekranında yayımlanır.'; end if;
  select * into ilan from oyun.ilanlar i
   where i.varlik in ('sirket', 'hisse') and i.varlik_id = s.id and i.durum = 'yayinda'
   order by (i.varlik = 'sirket') desc, i.id desc limit 1;
  ortak := exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id = s.id and o.user_id = u and o.pay > 0);
  tam_satis := s.satilik is not null or (ilan.id is not null and ilan.varlik = 'sirket');
  hisse_ilani := ilan.id is not null and ilan.varlik = 'hisse';
  borsa := coalesce(s.halka_acik, false);
  if not (ortak or tam_satis or hisse_ilani or borsa) then
    raise exception 'Mali inceleme raporu yalnız satılık ya da borsada işlem gören şirketler için açılır.';
  end if;
  kasa_acik := ortak or tam_satis
            or (hisse_ilani and coalesce(ilan.mali_goster, false))
            or oyun.kasa_goster('sirket', s.id, s.kasa) is not null;
  select coalesce(sum(r.gelir), 0) g, coalesce(sum(r.gider + coalesce(r.ruhsat, 0) + coalesce(r.ceza, 0) + coalesce(r.vergi, 0)), 0) d,
         coalesce(sum(r.net), 0) n, count(*) k
    into pr30 from oyun.pazar_rapor r where r.sirket_id = s.id and r.zaman > t - interval '30 days';
  select coalesce(sum(r.gelir), 0) g, coalesce(sum(r.gider + coalesce(r.ruhsat, 0) + coalesce(r.ceza, 0) + coalesce(r.vergi, 0)), 0) d,
         coalesce(sum(r.net), 0) n, count(*) k
    into pr7 from oyun.pazar_rapor r where r.sirket_id = s.id and r.zaman > t - interval '7 days';
  select coalesce(sum(greatest(0, h.faaliyet_gelir)), 0) g, coalesce(sum(greatest(0, h.faaliyet_gider)), 0) d,
         coalesce(sum(h.tutar), 0) n, count(*) k
    into sh30 from oyun.sirket_hareket h where h.sirket_id = s.id and h.faaliyet_gelir is not null and h.zaman > t - interval '30 days';
  select coalesce(sum(greatest(0, h.faaliyet_gelir)), 0) g, coalesce(sum(greatest(0, h.faaliyet_gider)), 0) d,
         coalesce(sum(h.tutar), 0) n, count(*) k
    into sh7 from oyun.sirket_hareket h where h.sirket_id = s.id and h.faaliyet_gelir is not null and h.zaman > t - interval '7 days';
  if pr30.k > 0 then g30 := pr30.g; d30 := pr30.d; n30 := pr30.n; g7 := pr7.g; d7 := pr7.d; n7 := pr7.n; kaynak := 'rekabetci_pazar';
  else g30 := sh30.g; d30 := sh30.d; n30 := sh30.n; g7 := sh7.g; d7 := sh7.d; n7 := sh7.n; kaynak := 'faaliyet'; end if;
  if kaynak = 'rekabetci_pazar' then
    select coalesce(sum(r.gelir), 0) gelir, coalesce(sum(r.net), 0) net,
           coalesce((select sum(h.dagitilan_kar) from oyun.sirket_hareket h where h.sirket_id = s.id), 0) dagitilan
      into top from oyun.pazar_rapor r where r.sirket_id = s.id;
  else
    select coalesce(sum(greatest(0, h.faaliyet_gelir)), 0) gelir, coalesce(sum(h.tutar) filter (where h.faaliyet_gelir is not null), 0) net,
           coalesce(sum(h.dagitilan_kar), 0) dagitilan
      into top from oyun.sirket_hareket h where h.sirket_id = s.id;
  end if;
  stok := coalesce((select sum(x.adet * coalesce(x.maliyet_birim, 0)) from oyun.eko_urun_stok x where x.sirket_id = s.id), 0);
  sube := 0;
  if to_regclass('oyun.sirket_il_subeleri') is not null then
    execute 'select count(*) from oyun.sirket_il_subeleri where sirket_id = $1' into sn using s.id; sube := sube + sn;
  end if;
  if to_regclass('oyun.eko_subeler') is not null then
    execute 'select count(*) from oyun.eko_subeler where sirket_id = $1 and aktif' into sn using s.id; sube := sube + sn;
  end if;
  fiyat := case when tam_satis then coalesce(case when ilan.varlik = 'sirket' then ilan.fiyat end, s.satilik)
                when hisse_ilani then ilan.fiyat end;
  return jsonb_build_object(
    'id', s.id, 'ad', s.ad, 'sektor', s.sektor, 'kurulus', s.kurulus, 'hukuki', s.tur_hukuki,
    'il', coalesce((select i.ad from oyun.sirket_merkezleri m join oyun.iller i on i.id = m.il_id where m.sirket_id = s.id),
                   (select i.ad from oyun.pazar_sirket ps join oyun.iller i on i.id = ps.il_id where ps.sirket_id = s.id limit 1)),
    'kurucu', (select p.kad from oyun.profiller p where p.id = s.kurucu),
    'ortaklar', coalesce((select jsonb_agg(jsonb_build_object('kad', x.kad, 'pay', o.pay) order by o.pay desc)
                            from oyun.sirket_ortaklari o join oyun.profiller x on x.id = o.user_id
                           where o.sirket_id = s.id and o.pay > 0), '[]'::jsonb),
    'durum', case when tam_satis then 'satilik' when hisse_ilani then 'hisse_ilani' when borsa then 'borsa' else 'ortak' end,
    'ortak', ortak, 'borsa', borsa,
    'fiyat', fiyat, 'pay', case when hisse_ilani then ilan.pay when tam_satis then 100 end,
    'ilan_id', ilan.id,
    'sermaye', s.sermaye,
    'kasa', case when kasa_acik then s.kasa end, 'kasa_gizli', not kasa_acik,
    'stok_degeri', round(stok), 'sube', sube,
    'donem_kaynak', kaynak,
    'son30', jsonb_build_object('gelir', round(g30), 'gider', round(d30), 'net', round(n30),
                                'marj', case when g30 > 0 then round(n30 / g30 * 100, 1) end),
    'son7', jsonb_build_object('gelir', round(g7), 'gider', round(d7), 'net', round(n7),
                               'marj', case when g7 > 0 then round(n7 / g7 * 100, 1) end),
    'toplam', jsonb_build_object('gelir', round(top.gelir), 'net', round(top.net), 'dagitilan', round(top.dagitilan),
                                 'marj', case when top.gelir > 0 then round(top.net / top.gelir * 100, 1) end),
    'sermaye_getirisi_30', case when s.sermaye > 0 then round(n30 / s.sermaye * 100, 1) end,
    'yillik_net_tahmini', round(n30 * 365 / 30),
    'fiyat_kazanc', case when fiyat is not null and n30 > 0 then round(fiyat / (n30 * 365 / 30 * coalesce(case when hisse_ilani then ilan.pay end, 100) / 100), 1) end,
    'fiyat_defter', case when fiyat is not null and kasa_acik and (s.kasa + stok) > 0
                         then round(fiyat / ((s.kasa + stok) * coalesce(case when hisse_ilani then ilan.pay end, 100) / 100), 2) end,
    'not', case when tam_satis then 'Şirketin tamamı satılık: kasa, stok, varlıklar ve yükümlülükler alıcıya geçer; mali tablo alıcılara açıktır.'
                when hisse_ilani then 'Hisse ilanı: ciro ve kârlılık açıktır; kasa yalnız satıcı mali bilgileri açtıysa görünür.'
                when borsa then 'Borsada işlem gören şirket: ciro ve kârlılık yatırımcılara açıktır; kasa yalnız sahibi açtıysa görünür.'
                else 'Ortağı olduğun şirketin mali tablosu.' end);
end $$;

-- İlan Meydanı'ndaki şirket / hisse ilanından inceleme raporu (ilan_detay şirket kimliğini vermez)
create or replace function public.ilan_sirket_raporu(p_ilan bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare i oyun.ilanlar;
begin
  select * into i from oyun.ilanlar x where x.id = p_ilan;
  if i.id is null or i.varlik not in ('sirket', 'hisse') or i.varlik_id is null then
    raise exception 'Bu ilan bir şirket ya da hisse ilanı değil.';
  end if;
  return public.sirket_satis_raporu(i.varlik_id);
end $$;

-- ---------------------------------------------------------------------
-- Yetkiler
-- ---------------------------------------------------------------------
do $yetki$
declare f text;
begin
  foreach f in array array['public.cuzdan_hareketleri(int)', 'public.sirket_satis_raporu(bigint)', 'public.ilan_sirket_raporu(bigint)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $yetki$;
