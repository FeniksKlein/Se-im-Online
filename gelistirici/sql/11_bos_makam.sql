-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 11) BOŞ MAKAM KURALI
--  Başlangıçta oyuncu az olacağı için bazı makamlar boş kalabilir. Kural:
--   1. Boş bakanlığa cumhurbaşkanı vekâlet eder (icraat yapabilir, bakanlık kasasından).
--   2. Seçimde aday çıkmayan makamda (belediye, cumhurbaşkanlığı) görevdeki, yenisi seçilene kadar devam eder.
--      (02_motor.sql: goreve_baslat)
--   3. Genel başkansız parti kalmaz: üyeler "Genel başkanlığı üstlen" ile hemen devralabilir; kurultayda da kimse aday olmazsa
--      başka görevi olmayan en kıdemli üye genel başkan olur.
--   4. Meclis'in yetersayıları dolu sandalye sayısına göre ölçeklenir (07_devlet.sql).
--   5. Boş Makamlar panosu: neyin boş olduğu, kimin vekâlet ettiği ve sonraki seçim.
-- =====================================================================

-- Cumhurbaşkanı, boş bir bakanlığa vekâlet edebilir mi?
create or replace function oyun.bakanlik_vekili(p_user uuid, p_bakanlik text) returns boolean language sql stable as $$
  select exists (select 1 from oyun.makamlar where user_id = p_user and tur = 'cb' and bit is null)
     and not exists (select 1 from oyun.makamlar where tur = 'bakan' and bakanlik = p_bakanlik and bit is null)
$$;

-- Bir bakanlığın paneli (bakanlik_paneli ile aynı biçim)
create or replace function oyun.bakanlik_panel_json(p_kod text, t timestamptz) returns jsonb language plpgsql stable as $$
declare pay numeric;
begin
  pay := coalesce(((select butce from oyun.ulke where id = 1) ->> p_kod)::numeric, 0);
  return jsonb_build_object(
    'kod', p_kod, 'ad', (select ad from oyun.bakanliklar where kod = p_kod),
    'kasa', round((select kasa from oyun.bakanlik_kasa where kod = p_kod), 1),
    'gunluk', round(10 * pay / 100, 2), 'pay', pay,
    'icraatlar', (select jsonb_agg(jsonb_build_object('kod', i.kod, 'ad', i.ad, 'aciklama', i.aciklama, 'maliyet', i.maliyet,
                    'il_gerekli', i.il_gerekli, 'etki', i.etki, 'bekleme_saat', i.bekleme_saat,
                    'oyuncu', i.oyuncu, 'sure_gun', i.sure_gun, 'ozel', i.ozel,
                    'aktif_bit', (select max(e.bit) from oyun.etkiler e where e.kaynak_kod = i.kod and e.il_id is null and e.bit > t),
                    'hazir', (select max(k.zaman) + make_interval(hours => i.bekleme_saat) from oyun.icraat_kayit k where k.kod = i.kod))
                  order by i.maliyet) from oyun.icraatlar i where i.bakanlik = p_kod));
end $$;

-- Cumhurbaşkanının vekâleten yönettiği (bakanı olmayan) bakanlıkların panelleri
create or replace function public.vekalet_paneli() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'cb' and bit is null) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(oyun.bakanlik_panel_json(b.kod, t) order by b.sira) from oyun.bakanliklar b
                   where not exists (select 1 from oyun.makamlar m where m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null)), '[]'::jsonb);
end $$;

-- Genel başkansız kalan parti (kurultayda kimse aday olmadı): başka görevi olmayan (cumhurbaşkanı hariç) en kıdemli üye genel başkan olur.
-- Bir sonraki kurultayda üyeler genel başkanı yeniden seçer. Kurultay sonucu işlenince çağrılır (02_motor.sql: goreve_baslat).
create or replace function oyun.gb_halef(t timestamptz) returns void language plpgsql as $$
declare pa record; aday uuid;
begin
  for pa in select id, ad from oyun.partiler where not kapali and gb is null loop
    select pr.id into aday from oyun.profiller pr
     where pr.parti_id = pa.id and not pr.yasakli
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur <> 'cb')
     order by oyun.kidem_puani(pr.id) desc, pr.parti_at, pr.id limit 1;
    continue when aday is null;
    delete from oyun.parti_gby where user_id = aday;       -- genel başkan aynı zamanda yardımcı olamaz
    update oyun.partiler set gb = aday where id = pa.id and gb is null;
    perform oyun.bildir(aday, format('%s kurultayda genel başkansız kaldığı için kıdemin en yüksek olduğu üye olarak genel başkan oldun. Bir sonraki kurultayda üyeler genel başkanı yeniden seçecek; 6 genel başkan yardımcını atayabilirsin.', pa.ad), t);
    perform oyun.olay('parti', format('%s genel başkansız kaldı; kıdemi en yüksek üye %s genel başkan oldu.', pa.ad, (select kad from oyun.profiller where id = aday)), null, pa.id, t);
  end loop;
end $$;

-- Genel başkansız partinin üyesi, başka görevi yoksa genel başkanlığı hemen üstlenebilir (genel başkan yardımcısı da olabilir)
create or replace function public.genel_baskanlik_uslen() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; c text;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null then raise exception 'Önce bir partiye üye olmalısın.'; end if;
  if pa.gb is not null then raise exception 'Partinin genel başkanı var.'; end if;
  select oyun.rol_ad(r) into c from unnest(oyun.roller(p.id)) r where r <> 'gby' and not oyun.rol_uyumlu(r, 'gb') limit 1;
  if c is not null then raise exception 'Şu anda % görevindesin; genel başkan olmak için önce o görevden istifa etmelisin.', c; end if;
  delete from oyun.parti_gby where user_id = p.id;
  update oyun.partiler set gb = p.id where id = pa.id;
  perform oyun.olay('parti', format('%s genel başkansız kalan %s partisinin genel başkanlığını üstlendi.', p.kad, pa.ad), null, pa.id, t);
  perform oyun.bildir(p.id, format('%s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilir, seçim beyannamesini yazabilirsin. Bir sonraki kurultayda üyeler genel başkanı yeniden seçer.', pa.ad), t);
  return public.durum();
end $$;

-- Boş Makamlar panosu
create or replace function public.bos_makamlar() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); cb text := (select oyun.kad(user_id) from oyun.makamlar where tur = 'cb' and bit is null limit 1); mv int;
begin
  select count(*) into mv from oyun.makamlar where tur = 'mv' and bit is null;
  return jsonb_build_object(
    'cb', cb,
    'bakanliklar', coalesce((select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad) order by b.sira) from oyun.bakanliklar b
                             where not exists (select 1 from oyun.makamlar m where m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null)), '[]'::jsonb),
    'belediyeler', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad) order by i.ad) from oyun.iller i
                             where not exists (select 1 from oyun.makamlar m where m.tur = 'bel' and m.il_id = i.id and m.bit is null)), '[]'::jsonb),
    'vekil', jsonb_build_object('dolu', mv, 'bos', 600 - mv),
    'partiler', coalesce((select jsonb_agg(jsonb_build_object('id', pa.id, 'kisa', pa.kisa)) from oyun.partiler pa where not pa.kapali and pa.gb is null
                          and exists (select 1 from oyun.profiller where parti_id = pa.id)), '[]'::jsonb),
    'sonraki', coalesce((select jsonb_agg(jsonb_build_object('tur', x.tur, 'basvuru_bas', x.basvuru_bas, 'basvuru_bit', x.basvuru_bit, 'oy_bas', x.oy_bas) order by x.oy_bas)
                         from (select distinct on (tur) tur, basvuru_bas, basvuru_bit, oy_bas from oyun.secimler
                               where durum = 'bekliyor' and tur in ('bel','mv','cb','kurultay') and oy_bit > t order by tur, oy_bas) x), '[]'::jsonb));
end $$;
