-- =====================================================================
-- 27.11.2026 · ADAY MİTİNGİNE OTOBÜS (sürüm 2026.11.27-4)
-- İstek (Ercan): "Cumhurbaşkanı adayı kendi mitingine otobüs kaldırabilsin."
-- Önceden otobüs yalnız parti mitinglerine (parti kasasından, GB/yetkili GBY) kaldırılabiliyordu.
-- Artık aday mitinglerinde de (Cumhurbaşkanı, milletvekili, belediye başkanı adayları):
--   • Mitingi düzenleyen aday kendi cüzdanından otobüs kaldırır (bağımsız aday dahil).
--   • Partili adayın mitingine partinin genel başkanı ya da miting/seçim yetkili yardımcısı parti kasasından kaldırır.
-- Kurallar aynı: tek seferde 1–5 otobüs, bir ilden bir mitinge en çok 10 otobüs (40 koltuk), miting başlamadan 10 dk öncesine kadar,
-- ücret iller arası mesafeye göre; kalkış ilindeki oyunculara bildirim, koltuk ücretsiz. Tekrar çalıştırmak güvenlidir.
-- =====================================================================
alter table oyun.miting_otobus alter column parti_id drop not null;
alter table oyun.miting_otobus add column if not exists odeyen_kisi uuid;

-- Otobüs kaldırma yetkisi: 'aday' (kendi cüzdanından) | 'parti' (parti kasasından) | null
create or replace function oyun.miting_otobus_yetki(u uuid, m oyun.mitingler) returns text
language sql stable set search_path to '' as $f$
  select case
    when m.id is null then null
    when m.tur = 'aday' and m.user_id = u then 'aday'
    when m.parti_id is not null and m.parti_id = (select parti_id from oyun.profiller where id = u) and oyun.parti_miting_yetki(u) is not null then 'parti'
  end
$f$;

create or replace function public.miting_otobus_bilgi(p_miting bigint)
returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare p oyun.profiller := oyun.profilim(); m oyun.mitingler; yetki text;
begin
  select * into m from oyun.mitingler where id = p_miting;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  yetki := oyun.miting_otobus_yetki(p.id, m);
  return jsonb_build_object(
    'id', m.id, 'il', (select ad from oyun.iller where id = m.il_id), 'il_id', m.il_id,
    -- eski uygulama bu alan true değilse pencereyi açmıyor: artık her mitingde otobüs olabilir
    'parti_mitingi', true, 'tur', m.tur, 'yetkili', yetki is not null, 'odeme', yetki, 'benim_ilim', p.il_id,
    'simdi', oyun.simdi(), 'bas', m.bas, 'bit', m.bit,
    'kasa', case when yetki = 'parti' then (select kasa from oyun.partiler where id = m.parti_id)
                 when yetki = 'aday' then (select para from oyun.cuzdan where user_id = p.id) end,
    'iller', case when yetki is not null and m.bas > oyun.simdi() then (select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad, 'ucret', oyun.miting_otobus_ucret(i.id, m.il_id)) order by i.ad), '[]'::jsonb)
                                                                    from oyun.iller i where i.id <> m.il_id) end,
    'otobusler', coalesce((select jsonb_agg(jsonb_build_object(
        'id', o.id, 'kaynak_il', o.kaynak_il, 'kaynak', (select ad from oyun.iller where id = o.kaynak_il),
        'adet', o.adet, 'koltuk', o.adet * o.kapasite, 'dolu', (select count(*) from oyun.miting_otobus_koltuk k where k.otobus_id = o.id),
        'ucret', o.ucret, 'benim_otobusum', exists (select 1 from oyun.miting_otobus_koltuk k where k.otobus_id = o.id and k.user_id = p.id)) order by o.id)
      from oyun.miting_otobus o where o.miting_id = m.id), '[]'::jsonb),
    'rezervasyonum', exists (select 1 from oyun.miting_otobus_koltuk k where k.miting_id = m.id and k.user_id = p.id));
end $f$;

create or replace function public.miting_otobus_kaldir(p_miting bigint, p_kaynak_il integer, p_adet integer default 1)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller := oyun.profilim(); m oyun.mitingler; pa oyun.partiler; t timestamptz := oyun.simdi(); onceki integer; birim numeric; tut numeric;
  kay_ad text; hedef_ad text; yetki text; kim text;
begin
  if p_adet is null or p_adet < 1 or p_adet > 5 then raise exception 'Tek seferde 1–5 otobüs kaldırabilirsin.'; end if;
  if p_kaynak_il is null or p_kaynak_il < 1 or p_kaynak_il > 81 then raise exception 'Kalkış ili geçersiz.'; end if;
  select * into m from oyun.mitingler where id = p_miting for update;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if t >= m.bas - interval '10 minutes' then raise exception 'Mitinge 10 dakikadan az kaldı; otobüs planlaması kapandı.'; end if;
  if p_kaynak_il = m.il_id then raise exception 'Mitingin yapıldığı il için otobüse gerek yok.'; end if;
  yetki := oyun.miting_otobus_yetki(p.id, m);
  if yetki is null then
    raise exception '%', case when m.tur = 'parti' then 'Yalnız parti genel başkanı veya yetkili yardımcısı otobüs kaldırabilir.'
                              else 'Bu mitinge otobüsü mitingi düzenleyen aday ya da partisinin genel başkanı (veya yetkili yardımcısı) kaldırır.' end;
  end if;
  select adet into onceki from oyun.miting_otobus where miting_id = m.id and kaynak_il = p_kaynak_il;
  if coalesce(onceki, 0) + p_adet > 10 then raise exception 'Aynı ilden bir mitinge en fazla 10 otobüs kaldırılabilir.'; end if;
  birim := oyun.miting_otobus_ucret(p_kaynak_il::smallint, m.il_id);
  tut := birim * p_adet;
  select ad into kay_ad from oyun.iller where id = p_kaynak_il;
  select ad into hedef_ad from oyun.iller where id = m.il_id;
  if yetki = 'parti' then
    select * into pa from oyun.partiler where id = m.parti_id for update;
    if pa.id is null or pa.kapali then raise exception 'Parti etkin değil.'; end if;
    update oyun.partiler set kasa = kasa - tut where id = pa.id and kasa >= tut;
    if not found then raise exception 'Parti kasası yetersiz. % ₺ gerekli, kasada % ₺ var.', tut, pa.kasa; end if;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
    values (pa.id, t, -tut, format('%s → %s mitingi: %s otobüs (40 koltuk/otobüs)', kay_ad, hedef_ad, p_adet), 'miting');
    kim := pa.kisa || ' partisi';
  else
    perform oyun.para_islem(p.id, -tut, 'miting', format('%s → %s miting otobüsü: %s otobüs (40 koltuk/otobüs)', kay_ad, hedef_ad, p_adet), t);
    kim := coalesce(nullif(btrim(p.ad_soyad), ''), p.kad);
  end if;
  insert into oyun.miting_otobus(miting_id, parti_id, kaynak_il, adet, ucret, odeyen_kisi)
  values (m.id, m.parti_id, p_kaynak_il, p_adet, tut, case when yetki = 'aday' then p.id end)
  on conflict (miting_id, kaynak_il) do update set adet = oyun.miting_otobus.adet + excluded.adet, ucret = oyun.miting_otobus.ucret + excluded.ucret;
  insert into oyun.bildirimler(user_id, zaman, metin)
  select x.id, t, format('%s, %s → %s mitingine ücretsiz katılım otobüsü kaldırdı ("%s"). Miting sayfasından koltuk ayırtabilirsin.', kim, kay_ad, hedef_ad, m.baslik)
  from oyun.profiller x where x.il_id = p_kaynak_il and not coalesce(x.yasakli, false) and x.son_gorulme > t - interval '14 days'
  limit 3000;
  return public.miting_otobus_bilgi(m.id);
end $f$;

create or replace function public.miting_otobus_yer_ayirt(p_miting bigint)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller := oyun.profilim(); m oyun.mitingler; b oyun.miting_otobus; dolu integer;
begin
  select * into m from oyun.mitingler where id = p_miting;
  if m.id is null then raise exception 'Miting bulunamadı.'; end if;
  if oyun.simdi() >= m.bit then raise exception 'Miting sona erdi.'; end if;
  if p.il_id = m.il_id then raise exception 'Aynı ilde yaşıyorsun; doğrudan mitinge katılabilirsin.'; end if;
  select * into b from oyun.miting_otobus where miting_id = m.id and kaynak_il = p.il_id for update;
  if b.id is null then raise exception 'Yaşadığın ilden bu mitinge otobüs kaldırılmamış.'; end if;
  if exists (select 1 from oyun.miting_otobus_koltuk where miting_id = m.id and user_id = p.id) then return public.miting_otobus_bilgi(m.id); end if;
  select count(*) into dolu from oyun.miting_otobus_koltuk where otobus_id = b.id;
  if dolu >= b.adet * b.kapasite then raise exception 'Bu ilin otobüsleri dolmuş. Yeni otobüs kaldırılmasını bekle.'; end if;
  insert into oyun.miting_otobus_koltuk(miting_id, otobus_id, user_id) values (m.id, b.id, p.id);
  perform oyun.bildir(p.id, format('Miting otobüsünde yerin ayrıldı. Miting başladığında %s meydanına katılabilirsin.', (select ad from oyun.iller where id = m.il_id)), oyun.simdi());
  return public.miting_otobus_bilgi(m.id);
end $f$;

revoke all on function oyun.miting_otobus_yetki(uuid, oyun.mitingler) from public, anon, authenticated;
do $g$
declare f text;
begin
  foreach f in array array['miting_otobus_bilgi(bigint)', 'miting_otobus_kaldir(bigint, integer, integer)', 'miting_otobus_yer_ayirt(bigint)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $g$;
