-- =====================================================================
-- 178 (07.11.2026) Pano ihalesi: AÇIK ARTIRMA usulü
--   • Verilen teklifler ve artırım geçmişi herkese açıktır.
--   • İlk teklif en az asgari bedel; sonraki her teklif en yüksek teklifi
--     en az "asgari artış" kadar geçmelidir (oran ve taban portaldan).
--   • Teklifin tamamı bloke edilir (kesin tahsil). Teklifi geçilenin bloke
--     tutarı ANINDA iade edilir ve bildirim gider; süre bitene kadar
--     teklifini artırabilir (yeniden teklif verirken eski blokesi düşülür).
--   • En yüksek teklif sahibi kendi teklifini artıramaz.
--   • Son dakika koruması: bitişe "uzatma" dakikasından az kala gelen
--     teklif, süreyi şu andan itibaren o kadar uzatır.
--   • Süre bitince en yüksek teklifin bloke bedeli Hazine'ye geçer.
-- =====================================================================

alter table oyun.pano_ayar add column if not exists ihale_artis_oran numeric not null default 0.02;
alter table oyun.pano_ayar add column if not exists ihale_artis_min numeric not null default 500;
alter table oyun.pano_ayar add column if not exists ihale_uzatma_dk int not null default 5;

alter table oyun.pano_ihale_teklif drop constraint if exists pano_ihale_teklif_durum_check;
alter table oyun.pano_ihale_teklif add constraint pano_ihale_teklif_durum_check
  check (durum in ('bekliyor', 'gecildi', 'kazandi', 'kaybetti', 'irat'));

-- Herkese açık artırım geçmişi
create table if not exists oyun.pano_ihale_artis (
  id          bigint generated always as identity primary key,
  ihale_id    bigint not null references oyun.pano_ihale(id),
  teklif_id   bigint not null references oyun.pano_ihale_teklif(id),
  teklif_ad   text not null,
  tutar       numeric not null,
  zaman       timestamptz not null default now()
);
create index if not exists pano_ihale_artis_ihale on oyun.pano_ihale_artis (ihale_id, tutar desc);
alter table oyun.pano_ihale_artis enable row level security;

-- Eski (kapalı zarf) teklifleri geçmişe aktar
insert into oyun.pano_ihale_artis (ihale_id, teklif_id, teklif_ad, tutar, zaman)
select t.ihale_id, t.id, t.teklif_ad, t.tutar, t.zaman from oyun.pano_ihale_teklif t
 where not exists (select 1 from oyun.pano_ihale_artis x where x.teklif_id = t.id);

-- Asgari artış
create or replace function oyun.pano_ihale_artis_tutar(p_tutar numeric) returns numeric
language sql stable security definer set search_path = '' as $$
  select greatest(a.ihale_artis_min, ceil(p_tutar * a.ihale_artis_oran / 100) * 100) from oyun.pano_ayar a where a.id = 1
$$;

-- Sıradaki geçerli en düşük teklif
create or replace function oyun.pano_ihale_sonraki(p_ihale bigint) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce((select t.tutar + oyun.pano_ihale_artis_tutar(t.tutar) from oyun.pano_ihale_teklif t
                    where t.ihale_id = i.id and t.durum = 'bekliyor' order by t.tutar desc, t.zaman asc limit 1), i.asgari)
    from oyun.pano_ihale i where i.id = p_ihale
$$;

create or replace function public.pano_ihale_teklif_ver(p_ihale bigint, p_tur text, p_id bigint, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); i oyun.pano_ihale; a oyun.pano_ayar; v_tutar numeric := round(coalesce(p_tutar, 0)); ad text;
  tur text := case when p_tur = 'sirket' then 'sirket' else 'oyuncu' end; sid bigint; yas uuid[]; n int;
  l_id bigint; l_tutar numeric; l_user uuid; l_tur text; l_tid bigint; v_min numeric; o_id bigint; o_bloke numeric := 0; v_fark numeric;
  konu text; v_bit timestamptz; t record; uzadi boolean := false;
begin
  select * into a from oyun.pano_ayar where id = 1;
  select * into i from oyun.pano_ihale where id = p_ihale for update;
  if i.id is null then raise exception 'İhale bulunamadı.'; end if;
  if i.durum <> 'acik' or i.bit <= now() then raise exception 'Bu ihalenin süresi doldu.'; end if;
  if v_tutar > 1000000000 then raise exception 'Teklif çok yüksek.'; end if;
  if tur = 'sirket' then
    sid := p_id;
    if not oyun.pano_odeme_yetki(p.id, 'sirket', sid) then raise exception 'Bu şirket adına teklif vermek için şirketin yöneticisi ya da çoğunluk ortağı olmalısın.'; end if;
    select s.ad into ad from oyun.sirketler s where s.id = sid and s.aktif;
    if ad is null then raise exception 'Şirket bulunamadı.'; end if;
  else
    sid := null; ad := p.kad;
  end if;
  yas := oyun.pano_ihale_yetkilileri(i.kapsam, i.il_id);
  if p.id = any (yas) then
    raise exception 'İhale yetkilisi bu ihaleye katılamaz (%). Belediye başkanı kendi ilinin, Cumhurbaşkanı ve Ulaştırma Bakanı ülke geneli pano ihalesine teklif veremez.', oyun.pano_idare_ad(i.kapsam, i.il_id);
  end if;
  if tur = 'sirket' and exists (select 1 from oyun.sirketler s where s.id = sid and (s.yonetici = any (yas) or s.kurucu = any (yas)))
     or tur = 'sirket' and exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = sid and o.pay > 0 and o.user_id = any (yas)) then
    raise exception 'Bu şirkette ihale yetkilisinin yönetimi ya da ortaklığı var; şirket bu ihaleye katılamaz.';
  end if;
  select count(*) into n from oyun.pano_isletme z
   where z.durum = 'aktif' and z.bit > now()
     and (z.isletmeci_user = p.id or (z.isletmeci_tur = 'sirket' and z.isletmeci_id in (select s.id from oyun.sirketler s where s.yonetici = p.id or s.kurucu = p.id)));
  if n >= a.ihale_en_fazla then raise exception 'Aynı anda en fazla % pano işletmesi tutabilirsin (tekel sınırı).', a.ihale_en_fazla; end if;

  -- Şu anki en yüksek teklif
  select t2.id, t2.tutar, t2.user_id, t2.teklif_tur, t2.teklif_id into l_id, l_tutar, l_user, l_tur, l_tid
    from oyun.pano_ihale_teklif t2 where t2.ihale_id = i.id and t2.durum = 'bekliyor' order by t2.tutar desc, t2.zaman asc limit 1;
  if l_id is not null and l_tur = tur and ((tur = 'sirket' and l_tid = sid) or (tur = 'oyuncu' and l_user = p.id)) then
    raise exception 'En yüksek teklif zaten senin (% ₺). Teklifin geçilirse artırabilirsin.', oyun.pano_tl(l_tutar);
  end if;
  v_min := case when l_id is null then i.asgari else l_tutar + oyun.pano_ihale_artis_tutar(l_tutar) end;
  if v_tutar < v_min then
    if l_id is null then raise exception 'En az % ₺ teklif vermelisin (muhammen bedel % ₺).', oyun.pano_tl(v_min), oyun.pano_tl(i.muhammen);
    else raise exception 'Şu anki en yüksek teklif % ₺. En az % ₺ teklif vermelisin.', oyun.pano_tl(l_tutar), oyun.pano_tl(v_min); end if;
  end if;

  -- Bu teklif sahibinin önceki satırı (varsa eski blokesi düşülür)
  select t2.id, t2.teminat into o_id, o_bloke from oyun.pano_ihale_teklif t2
   where t2.ihale_id = i.id and t2.teklif_tur = tur and ((tur = 'sirket' and t2.teklif_id = sid) or (tur = 'oyuncu' and t2.user_id = p.id)) for update;
  o_bloke := coalesce(o_bloke, 0);
  v_fark := v_tutar - o_bloke;
  begin
    perform oyun.pano_odeme(case when tur = 'oyuncu' then 'oyuncu' else 'kasa' end, tur, sid, p.id, -v_fark, format('İhale teklifi bloke · pano ihalesi #%s', i.id));
  exception when others then
    raise exception 'Teklifin tamamı (% ₺) bloke edilir; % yeterli bakiye yok.', oyun.pano_tl(v_tutar),
      case when tur = 'oyuncu' then 'cüzdanında' else 'şirket kasasında' end;
  end;
  if o_id is null then
    insert into oyun.pano_ihale_teklif (ihale_id, teklif_tur, teklif_id, user_id, teklif_ad, tutar, teminat, zaman, durum)
    values (i.id, tur, sid, p.id, ad, v_tutar, v_tutar, now(), 'bekliyor') returning id into o_id;
  else
    update oyun.pano_ihale_teklif set tutar = v_tutar, teminat = v_tutar, zaman = now(), durum = 'bekliyor', user_id = p.id, teklif_ad = ad where id = o_id;
  end if;
  insert into oyun.pano_ihale_artis (ihale_id, teklif_id, teklif_ad, tutar) values (i.id, o_id, ad, v_tutar);

  -- Son dakika koruması
  v_bit := i.bit;
  if i.bit - now() < make_interval(mins => a.ihale_uzatma_dk) then
    v_bit := now() + make_interval(mins => a.ihale_uzatma_dk); uzadi := true;
    update oyun.pano_ihale set bit = v_bit where id = i.id;
  end if;

  -- Geçilen teklif(ler)in blokesi anında iade
  konu := case when i.kapsam = 'il' then (select il.ad from oyun.iller il where il.id = i.il_id) || ' il panoları' else 'Ülke geneli dev panolar' end;
  for t in select * from oyun.pano_ihale_teklif where ihale_id = i.id and durum = 'bekliyor' and id <> o_id for update loop
    if t.teminat > 0 then
      perform oyun.pano_odeme(case when t.teklif_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, t.teklif_tur, t.teklif_id, t.user_id,
                              t.teminat, format('İhale teklifi geçildi, bloke iadesi · pano ihalesi #%s', i.id));
    end if;
    update oyun.pano_ihale_teklif set durum = 'gecildi', teminat = 0 where id = t.id;
    perform oyun.bildir(t.user_id, format('%s ihalesinde teklifin geçildi! Yeni en yüksek teklif: %s ₺ (%s). Bloke ettiğin %s ₺ iade edildi. Süre bitmeden (%s) teklifini artırabilirsin: Reklam Panoları → Pano ihaleleri.',
      konu, oyun.pano_tl(v_tutar), ad, oyun.pano_tl(t.teminat), to_char(v_bit at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), oyun.simdi());
  end loop;

  return jsonb_build_object('tamam', true, 'tutar', v_tutar, 'bloke', v_fark, 'teminat', v_tutar, 'bit', v_bit, 'uzadi', uzadi,
                            'sonraki', v_tutar + oyun.pano_ihale_artis_tutar(v_tutar));
end $$;

-- Sonuçlandırma: en yüksek ödeyebilen teklif kazanır; diğerlerinin kalan blokesi iade
create or replace function oyun.pano_ihale_kapat(p_ihale bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare i oyun.pano_ihale; t record; k_id bigint; k_tur text; k_tid bigint; k_user uuid; k_ad text; k_tutar numeric; konu text; bas timestamptz; n int; fy jsonb; sayi int := 0; v_kalan numeric;
begin
  select * into i from oyun.pano_ihale where id = p_ihale and durum = 'acik' for update;
  if i.id is null then return; end if;
  konu := case when i.kapsam = 'il' then (select il.ad from oyun.iller il where il.id = i.il_id) || ' il panoları' else 'Ülke geneli dev panolar' end;
  for t in select * from oyun.pano_ihale_teklif where ihale_id = i.id order by (durum = 'bekliyor') desc, tutar desc, zaman asc loop
    sayi := sayi + 1;
    if k_id is null then
      v_kalan := greatest(0, t.tutar - t.teminat);
      begin
        if v_kalan > 0 then
          perform oyun.pano_odeme(case when t.teklif_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, t.teklif_tur, t.teklif_id, t.user_id,
                                  -v_kalan, format('İhale bedeli · %s işletme hakkı · ihale #%s', konu, i.id));
        end if;
        k_id := t.id; k_tur := t.teklif_tur; k_tid := t.teklif_id; k_user := t.user_id; k_ad := t.teklif_ad; k_tutar := t.tutar;
        update oyun.pano_ihale_teklif set durum = 'kazandi', teminat = t.tutar where id = t.id;
      exception when others then
        update oyun.pano_ihale_teklif set durum = 'irat' where id = t.id;
        if t.teminat > 0 then
          perform oyun.pano_ihale_gelir(i.kapsam, i.il_id, t.teminat, format('Pano ihalesi #%s: bedeli ödenmeyen teklifin teminatı irat kaydedildi', i.id));
        end if;
        perform oyun.bildir(t.user_id, format('%s ihalesinde en yüksek teklif sizindi ama kalan bedel (%s ₺) ödenemedi. %s ₺ teminat Hazine''ye gelir kaydedildi.',
          konu, oyun.pano_tl(v_kalan), oyun.pano_tl(t.teminat)), oyun.simdi());
      end;
    else
      if t.teminat > 0 then
        perform oyun.pano_odeme(case when t.teklif_tur = 'oyuncu' then 'oyuncu' else 'kasa' end, t.teklif_tur, t.teklif_id, t.user_id,
                                t.teminat, format('İhale teklifi iadesi · pano ihalesi #%s', i.id));
      end if;
      update oyun.pano_ihale_teklif set durum = 'kaybetti', teminat = 0 where id = t.id;
    end if;
  end loop;
  if sayi = 0 then update oyun.pano_ihale set durum = 'teklifsiz' where id = i.id; return; end if;
  if k_id is null then update oyun.pano_ihale set durum = 'bozuldu' where id = i.id; return; end if;

  perform oyun.pano_ihale_gelir(i.kapsam, i.il_id, k_tutar, format('Pano işletme hakkı ihale bedeli · %s · ihale #%s · %s', konu, i.id, k_ad));
  n := i.slot;
  bas := greatest(now(), coalesce((select max(z.bit) from oyun.pano_isletme z where z.durum = 'aktif' and z.kapsam = i.kapsam
                                    and z.il_id is not distinct from i.il_id and z.bit > now()), now()));
  fy := oyun.pano_fiyat(i.kapsam, i.il_id);
  insert into oyun.pano_isletme (ihale_id, kapsam, il_id, slot, isletmeci_tur, isletmeci_id, isletmeci_user, isletmeci_ad, bedel, bas, bit, fiyatlar)
  values (i.id, i.kapsam, i.il_id, n, k_tur, k_tid, k_user, k_ad, k_tutar,
          bas, bas + make_interval(days => i.isletme_gun),
          (select jsonb_agg(coalesce((fy ->> 'devlet_gunluk')::numeric, (fy ->> 'gunluk')::numeric, 1000)) from generate_series(1, n)));
  update oyun.pano_ihale set durum = 'sonuclandi', kazanan_teklif = k_id, bedel = k_tutar where id = i.id;
  perform oyun.bildir(k_user, format('Tebrikler! %s işletme hakkı ihalesini %s ₺ ile kazandın (%s katılımcı). Bloke edilen bedel Hazine''ye aktarıldı. İşletme %s – %s. Pano fiyatlarını Reklam Panoları → İşletmelerim bölümünden belirle.',
    konu, oyun.pano_tl(k_tutar), sayi, to_char(bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'),
    to_char((bas + make_interval(days => i.isletme_gun)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), oyun.simdi());
  for t in select * from oyun.pano_ihale_teklif where ihale_id = i.id and durum = 'kaybetti' loop
    perform oyun.bildir(t.user_id, format('%s ihalesi sona erdi. Kazanan: %s · %s ₺. Bloke edilmiş tutarın yoksa zaten iade edilmişti.',
      konu, k_ad, oyun.pano_tl(k_tutar)), oyun.simdi());
  end loop;
end $$;

-- İhale merkezi: açık artırma bilgileri eklendi
create or replace function public.pano_ihale_merkez() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); a oyun.pano_ayar; benim bigint[];
begin
  select * into a from oyun.pano_ayar where id = 1;
  select coalesce(array_agg(s.id), '{}') into benim from oyun.sirketler s where s.aktif and oyun.pano_odeme_yetki(p.id, 'sirket', s.id);
  return jsonb_build_object(
    'ayar', jsonb_build_object('acik', a.ihale_acik, 'teklif_saat', a.ihale_teklif_saat, 'isletme_gun', a.ihale_isletme_gun, 'asgari_oran', a.ihale_asgari_oran,
                               'teminat_oran', a.ihale_teminat_oran, 'en_fazla', a.ihale_en_fazla, 'vergi', a.reklam_vergisi,
                               'artis_oran', a.ihale_artis_oran, 'artis_min', a.ihale_artis_min, 'uzatma_dk', a.ihale_uzatma_dk, 'usul', 'acik'),
    'simdi', now(),
    'ihaleler', coalesce((select jsonb_agg(q order by q.sira, q.bit_sira) from (
      select case when i.durum = 'acik' then 0 else 1 end sira, case when i.durum = 'acik' then extract(epoch from i.bit) else -extract(epoch from i.bit) end bit_sira,
             i.id, i.kapsam, i.il_id, (select il.ad from oyun.iller il where il.id = i.il_id) il, oyun.pano_idare_ad(i.kapsam, i.il_id) idare,
             i.slot, i.isletme_gun, i.isletme_bas, i.muhammen, i.asgari, i.teminat_oran, i.bas, i.bit, i.durum, i.bedel,
             (select count(*) from oyun.pano_ihale_artis x where x.ihale_id = i.id) teklif_say,
             (select count(*) from oyun.pano_ihale_teklif t where t.ihale_id = i.id) katilimci,
             (p.id = any (oyun.pano_ihale_yetkilileri(i.kapsam, i.il_id))) yetkili,
             (select jsonb_agg(jsonb_build_object('ad', t.teklif_ad, 'tur', t.teklif_tur, 'id', t.teklif_id, 'tutar', t.tutar, 'teminat', t.teminat, 'durum', t.durum))
                from oyun.pano_ihale_teklif t where t.ihale_id = i.id and (t.user_id = p.id or (t.teklif_tur = 'sirket' and t.teklif_id = any (benim)))) benim,
             (select jsonb_build_object('ad', t.teklif_ad, 'tutar', t.tutar, 'zaman', t.zaman,
                       'benim', (t.user_id = p.id and t.teklif_tur = 'oyuncu') or (t.teklif_tur = 'sirket' and t.teklif_id = any (benim)))
                from oyun.pano_ihale_teklif t where t.ihale_id = i.id and t.durum = 'bekliyor' order by t.tutar desc, t.zaman asc limit 1) lider,
             case when i.durum = 'acik' then oyun.pano_ihale_sonraki(i.id) end sonraki,
             (select jsonb_agg(jsonb_build_object('ad', x.teklif_ad, 'tutar', x.tutar, 'zaman', x.zaman,
                       'benim', exists (select 1 from oyun.pano_ihale_teklif t where t.id = x.teklif_id and ((t.teklif_tur = 'oyuncu' and t.user_id = p.id) or (t.teklif_tur = 'sirket' and t.teklif_id = any (benim)))))
                       order by x.tutar desc, x.zaman desc)
                from (select * from oyun.pano_ihale_artis x where x.ihale_id = i.id order by x.tutar desc, x.zaman desc limit 15) x) gecmis,
             (select jsonb_build_object('ad', t.teklif_ad, 'tutar', t.tutar) from oyun.pano_ihale_teklif t where t.id = i.kazanan_teklif) kazanan
        from oyun.pano_ihale i
       where i.durum = 'acik' or i.id in (select x.id from oyun.pano_ihale x where x.durum <> 'acik' order by x.bit desc limit 12)) q), '[]'::jsonb),
    'isletmelerim', coalesce((select jsonb_agg(jsonb_build_object('id', z.id, 'kapsam', z.kapsam, 'il_id', z.il_id, 'il', (select il.ad from oyun.iller il where il.id = z.il_id),
             'isletmeci_ad', z.isletmeci_ad, 'isletmeci_tur', z.isletmeci_tur, 'bas', z.bas, 'bit', z.bit, 'slot', z.slot, 'fiyatlar', z.fiyatlar,
             'bedel', z.bedel, 'gelir', z.gelir, 'vergi', z.vergi, 'devlet_gunluk', (oyun.pano_fiyat(z.kapsam, z.il_id) ->> 'devlet_gunluk')::numeric,
             'dolu', (select count(distinct y.slot) from oyun.pano_yayin y where y.isletme_id = z.id and y.durum = 'aktif' and y.bas <= now() and y.bit > now()),
             'kiralama', (select count(*) from oyun.pano_yayin y where y.isletme_id = z.id)) order by z.bit)
        from oyun.pano_isletme z
       where z.durum = 'aktif' and z.bit > now()
         and ((z.isletmeci_tur = 'oyuncu' and z.isletmeci_user = p.id) or (z.isletmeci_tur = 'sirket' and z.isletmeci_id = any (benim)))), '[]'::jsonb),
    'isletmeler', coalesce((select jsonb_agg(jsonb_build_object('kapsam', z.kapsam, 'il_id', z.il_id, 'il', (select il.ad from oyun.iller il where il.id = z.il_id),
             'ad', z.isletmeci_ad, 'bas', z.bas, 'bit', z.bit, 'bedel', z.bedel) order by z.bas)
        from oyun.pano_isletme z where z.durum = 'aktif' and z.bit > now()), '[]'::jsonb),
    'kaynaklar', (select jsonb_build_array(jsonb_build_object('tur', 'oyuncu', 'id', null, 'ad', p.kad || ' (kendi adına)', 'kasa', coalesce((select c.para from oyun.cuzdan c where c.user_id = p.id), 0)))
                  || coalesce((select jsonb_agg(jsonb_build_object('tur', 'sirket', 'id', s.id, 'ad', s.ad, 'kasa', s.kasa) order by s.ad) from oyun.sirketler s where s.id = any (benim)), '[]'::jsonb)));
end $$;

do $portal$
begin
  if to_regclass('oyun.yp_ayar_katalog') is not null then
    insert into oyun.yp_ayar_katalog (anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, risk, etki, sira) values
      ('pano.ihale_artis_oran', 'oyun.pano_ayar', 'ihale_artis_oran', '{"id":"1"}', 'ekonomi', 'İhale asgari artış oranı',
       'Açık artırmada yeni teklif, en yüksek teklifi en az bu oran kadar geçmelidir.', 'sayi', 'kat', 0.005, 0.2, 'dusuk', 'Hemen.', 315),
      ('pano.ihale_artis_min', 'oyun.pano_ayar', 'ihale_artis_min', '{"id":"1"}', 'ekonomi', 'İhale asgari artış tabanı',
       'Oranla hesaplanan artış bundan küçükse en az bu kadar artırılır.', 'tamsayi', '₺', 100, 100000, 'dusuk', 'Hemen.', 316),
      ('pano.ihale_uzatma_dk', 'oyun.pano_ayar', 'ihale_uzatma_dk', '{"id":"1"}', 'ekonomi', 'Son dakika uzatması',
       'Bitişe bu kadar dakika kala gelen teklif süreyi bu kadar uzatır (son saniye kapmayı önler).', 'tamsayi', 'dakika', 0, 60, 'dusuk', 'Hemen.', 317)
    on conflict (anahtar) do nothing;
  end if;
end $portal$;

revoke all on function oyun.pano_ihale_kapat(bigint), oyun.pano_ihale_artis_tutar(numeric), oyun.pano_ihale_sonraki(bigint) from public, anon, authenticated;
