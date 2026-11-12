-- =====================================================================
--  200 (11.11.2026) · ÖNE ÇIKAN GİRİŞ KARTLARI İÇİN HAFİF ÖZETLER (Ercan: "bunları oldukları menülerde daha
--  görünür hale getir")
--  Gündem (TV Kanalları), Devlet (Valilik) ve Ekonomi (Ticaret Odası) ekranlarının üstündeki canlı durumlu giriş
--  kartlarını besler. Üçü de yalnız okur (stable); para, kayıt ya da durum değiştirmez.
-- =====================================================================

-- Ticaret Odası kartı: oyuncunun odası, seçim durumu, oy hakkı, aidat borcu
create or replace function public.oda_ozet() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); v_il smallint; o oyun.oda; s oyun.oda_secim; b oyun.oda_secim;
  n_sirket int := 0; n_oy int := 0; n_bos int := 0; borc numeric := 0;
begin
  if u is null then return null; end if;
  select m.il_id into v_il from oyun.oda_uye m join oyun.sirketler c on c.id = m.sirket_id and c.aktif
   where m.aktif and (c.yonetici = u or exists (select 1 from oyun.sirket_ortaklari x where x.sirket_id = c.id and x.user_id = u and x.pay > 0))
     and oyun.sirket_yonetici_mi(c.id, u) order by m.kayit, m.sirket_id limit 1;
  if v_il is null then select pr.il_id into v_il from oyun.profiller pr where pr.id = u; end if;
  v_il := coalesce(v_il, 6);
  select * into o from oyun.oda where il_id = v_il;
  if o.il_id is null then return null; end if;
  select * into s from oyun.oda_secim where il_id = v_il and durum in ('aday','oy') order by id desc limit 1;
  select * into b from oyun.oda_secim where il_id = 0 and durum in ('aday','oy') order by id desc limit 1;
  select count(*), coalesce(sum(m.aidat_borc), 0),
         count(*) filter (where m.il_id = v_il and m.aidat_borc <= 0),
         count(*) filter (where m.il_id = v_il and m.aidat_borc <= 0 and s.durum = 'oy'
                            and not exists (select 1 from oyun.oda_oy y where y.secim_id = s.id and y.sirket_id = m.sirket_id))
    into n_sirket, borc, n_oy, n_bos
    from oyun.oda_uye m join oyun.sirketler c on c.id = m.sirket_id and c.aktif
   where m.aktif and (c.yonetici = u or exists (select 1 from oyun.sirket_ortaklari x where x.sirket_id = c.id and x.user_id = u and x.pay > 0))
     and oyun.sirket_yonetici_mi(c.id, u);
  return jsonb_build_object('il', v_il, 'ad', oyun.oda_ad(v_il), 'uye', oyun.oda_uye_sayisi(v_il), 'baskan', oyun.kad(o.baskan), 'baskanim', coalesce(o.baskan = u, false),
    'sirketim', n_sirket, 'oy_hakki', n_oy, 'oy_bekleyen', coalesce(n_bos, 0), 'aidat_borc', round(borc), 'aidat', o.aidat,
    'secim', case when s.id is null then null else jsonb_build_object('durum', s.durum, 'oy_bas', s.oy_bas, 'oy_son', s.oy_son,
       'aday', (select count(*) from oyun.oda_aday a where a.secim_id = s.id and not a.cekildi),
       'adayim', exists (select 1 from oyun.oda_aday a where a.secim_id = s.id and a.user_id = u and not a.cekildi)) end,
    'birlik', case when b.id is null then null else jsonb_build_object('durum', b.durum, 'oy_bas', b.oy_bas, 'oy_son', b.oy_son,
       'aday', (select count(*) from oyun.oda_aday a where a.secim_id = b.id and not a.cekildi)) end,
    'birlik_baskan', (select oyun.kad(od.baskan) from oyun.oda od where od.il_id = 0), 'simdi', t);
end $$;

-- Valilik kartı: oyuncunun valilik durumu + ülke geneli sayılar
create or replace function public.vali_ozet() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi(); a oyun.vali_akademi; h oyun.vali_havuz; x oyun.icisleri_atama; v_durum text;
begin
  if u is null then return null; end if;
  select * into a from oyun.vali_akademi where user_id = u;
  select * into h from oyun.vali_havuz where user_id = u;
  x := oyun.vali_atama(u);
  v_durum := case when x.id is not null then 'vali'
                  when h.user_id is not null and h.durum = 'aday' then 'havuz'
                  when a.sinav_gecildi is not null then 'ayrildi'
                  when a.user_id is null then 'yok'
                  when a.baslangic + interval '24 hours' > t then 'egitim'
                  when a.son_sinav is not null and a.son_sinav > t - interval '24 hours' then 'bekle'
                  else 'sinav' end;
  return jsonb_build_object('durum', v_durum, 'il', (select ad from oyun.iller where id = x.il_id),
    'egitim_bitti', a.baslangic + interval '24 hours', 'yeni_sinav', a.son_sinav + interval '24 hours',
    'cb', exists (select 1 from oyun.makamlar where tur = 'cb' and user_id = u and bit is null),
    'vali', (select count(*) from oyun.icisleri_atama i where i.tur = 'vali' and i.durum = 'aktif' and (i.bitis is null or i.bitis > t)),
    'havuz', (select count(*) from oyun.vali_havuz v where v.durum = 'aday'),
    'bekleyen', (select count(*) from oyun.vali_havuz v where v.durum = 'aday' and (oyun.vali_atama(v.user_id)).id is null and oyun.vali_siyasi_engel(v.user_id) is null),
    'simdi', t);
end $$;

-- TV kartı: en çok izlenen canlı yayın, sıradaki program, oyuncuyu bekleyen davet ve teklifler
create or replace function public.tv_canli_ozet() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := auth.uid(); t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'canli', (select count(*) from oyun.tv_program pr where pr.bit > t and (pr.durum = 'canli' or (pr.durum = 'planli' and pr.bas <= t))),
    'yakinda', (select count(*) from oyun.tv_program pr where pr.durum = 'planli' and pr.bas > t),
    'kanal', (select count(*) from oyun.tv_kanal k where k.aktif),
    'ilk', (select jsonb_build_object('id', q.id, 'baslik', q.baslik, 'kanal', q.kanal, 'tur_ad', oyun.tv_tur_ad(q.tur), 'sunucu', oyun.kad(q.sunucu), 'izleyici', q.izleyici)
              from (select pr.id, pr.baslik, pr.tur, pr.sunucu, pr.bas, k.ad kanal,
                           (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id and z.son > t - interval '45 seconds') izleyici
                      from oyun.tv_program pr join oyun.tv_kanal k on k.id = pr.kanal_id
                     where pr.bit > t and (pr.durum = 'canli' or (pr.durum = 'planli' and pr.bas <= t))) q
             order by q.izleyici desc, q.bas desc limit 1),
    'siradaki', (select jsonb_build_object('id', pr.id, 'baslik', pr.baslik, 'kanal', k.ad, 'tur_ad', oyun.tv_tur_ad(pr.tur), 'bas', pr.bas)
                   from oyun.tv_program pr join oyun.tv_kanal k on k.id = pr.kanal_id where pr.durum = 'planli' and pr.bas > t order by pr.bas limit 1),
    'davet', case when u is null then 0 else (select count(*) from oyun.tv_konuk x join oyun.tv_program pr on pr.id = x.program_id and pr.durum in ('planli','canli')
                                               where x.user_id = u and x.durum = 'davet') end,
    'teklif', case when u is null then 0 else (select count(*) from oyun.tv_sunucu s join oyun.tv_kanal k on k.id = s.kanal_id and k.aktif
                                                where s.user_id = u and s.durum = 'teklif') end,
    'simdi', t);
end $$;

do $g$ declare f text; begin
  foreach f in array array['oda_ozet()','vali_ozet()','tv_canli_ozet()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $g$;
