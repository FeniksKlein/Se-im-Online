-- 22.11.2026 · Caydırıcı küçük cezalar, kademeli susturma, saatlik uzaklaştırma
-- İstek (Ercan): sohbette ırkçı vb. yazılara karşı moderatörlerin elinde kalıcı banın yanında
-- küçük ve kademeli cezalar olsun; tekrar edenin cezası kendiliğinden ağırlaşsın.
--   1) Resmî uyarı (ihtar): kısıt yok, kayda geçer. 24 saatte 3. uyarı → kendiliğinden 1 saat susturma.
--   2) Para cezası: 1.000 / 2.500 / 5.000 / 10.000 ₺ (tek imza üst sınırı 10.000 ₺, kurucu sınırsız).
--      Para Hazine'ye gelir yazılır. Cüzdanda yetmezse cüzdandaki kadarı alınır (cüzdan eksiye düşmez).
--      Aynı oyuncuya 1 saat içinde ikinci para cezası kesilemez.
--   3) Kademeli susturma: son 30 günde susturulmuş oyuncunun yeni susturması en az
--      2. → 1 saat · 3. → 6 saat · 4. → 24 saat · 5. → 3 gün · 6.+ → 7 gün (moderatörün seçtiği daha uzunsa o).
--      Moderatörün kaldırdığı susturma ("Susturma kaldırıldı.") sayılmaz. Kurucuya uygulanmaz (kurucu seçtiği süreyi verir).
--   4) Uzaklaştırma: 1 günden kısa hesap engeli (1/3/6/12 saat) bildirimde "uzaklaştırma" olarak yazılır.
-- Yetki: uyarı ve para cezası mevcut 'sustur' yetkisine bağlıdır (İçerik ve Oyuncu masaları). Çıkar çatışması
-- ve korunan hesap kuralları (korunan_hedef_ceza) aynen geçerlidir. Yetki her zaman sunucuda denetlenir.

create table if not exists oyun.mod_ceza (
  id bigserial primary key,
  hedef uuid not null references oyun.profiller(id) on delete cascade,
  tur text not null check (tur in ('uyari', 'para')),
  tutar numeric not null default 0,
  tahsil numeric not null default 0,
  gerekce text not null,
  kanit text,
  veren uuid,
  zaman timestamptz not null default now()
);
create index if not exists mod_ceza_hedef_zaman on oyun.mod_ceza (hedef, zaman desc);
alter table oyun.mod_ceza enable row level security;
revoke all on table oyun.mod_ceza from anon, authenticated;

-- Kademeli susturma alt sınırı (saat). n = son 30 günde sayılan önceki susturma sayısı.
create or replace function oyun.sustur_kademe(h uuid, t timestamptz)
returns table(onceki int, alt_saat numeric) language sql stable set search_path to '' as $f$
  with n as (
    select count(*)::int c from oyun.mod_kisit k
     where k.hedef = h and k.kod = 'sustur' and k.baslangic > t - interval '30 days'
       and coalesce(k.kalkis_not, '') <> 'Susturma kaldırıldı.')
  select n.c, case when n.c <= 0 then 0 when n.c = 1 then 1 when n.c = 2 then 6 when n.c = 3 then 24 when n.c = 4 then 72 else 168 end::numeric
    from n
$f$;
revoke all on function oyun.sustur_kademe(uuid, timestamptz) from public, anon, authenticated;

-- yk_sustur: moderatörün süresi kademe alt sınırının altındaysa yükselt, gerekçeye not düş
select oyun._yama('public.yk_sustur(text,numeric,text)',
  $d$if p_saat > 87600 then raise exception 'Süre çok uzun.'; end if;$d$,
  $d$if p_saat > 87600 then raise exception 'Süre çok uzun.'; end if;
    /* kademe_sustur */ if not yon then
      declare kd record;
      begin
        select * into kd from oyun.sustur_kademe(h.id, t);
        kd.alt_saat := least(kd.alt_saat, coalesce((select ms.tek from oyun.mod_sinir(p.id, 'sustur') ms), kd.alt_saat));
        if kd.alt_saat > p_saat then
          p_saat := kd.alt_saat;
          neden := left(concat_ws(' ', neden, format('(Tekrar eden ihlal: son 30 günde %s. susturma, süre kademeli olarak %s oldu.)', kd.onceki + 1, oyun.mod_sure_yaz(p_saat))), 300);
        end if;
      end;
    end if;$d$,
  '/* kademe_sustur */', true);

-- yk_engelle: 1 günden kısa tek imzalı engel "uzaklaştırma" diye bildirilir
select oyun._yama('public.yk_engelle(text,numeric,text,boolean)',
  $d$engel_neden = case when v_inceleme then left('Yönetim incelemesi: ' || neden, 200) else neden end$d$,
  $d$engel_neden = case when v_inceleme and v_gun < 1 then /* uzaklastirma */ left('Uzaklaştırma: ' || neden, 200) when v_inceleme then left('Yönetim incelemesi: ' || neden, 200) else neden end$d$,
  '/* uzaklastirma */', true);
select oyun._yama('public.yk_engelle(text,numeric,text,boolean)',
  $d$  if v_inceleme then
    perform oyun.bildir(h.id, format('Hesabın şu sebeple yönetim incelemesine alındı$d$,
  $d$  if v_inceleme and v_gun < 1 then /* uzaklastirma_bildir */
    perform oyun.bildir(h.id, format('Oyundan %s uzaklaştırıldın. Sebep: %s Uzaklaştırma %s tarihinde biter; tekrarında süre uzar. İtiraz için: %s',
                                     oyun.mod_sure_yaz(v_gun * 24), neden, to_char(bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI'), oyun.iletisim()), t);
  elsif v_inceleme then
    perform oyun.bildir(h.id, format('Hesabın şu sebeple yönetim incelemesine alındı$d$,
  '/* uzaklastirma_bildir */', true);

-- Ortak denetim: yetki, hedef, gerekçe
create or replace function oyun.mod_kucuk_ceza_hazirla(p_kad text, p_gerekce text, out p oyun.profiller, out h oyun.profiller, out g text)
language plpgsql set search_path to 'oyun', 'public', 'pg_temp' as $f$
begin
  p := oyun.yetki_zorunlu('sustur');
  h := oyun.profil_bul(p_kad);
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  if h.id = p.id then raise exception 'Kendine işlem yapamazsın.'; end if;
  if h.yonetici then raise exception 'Yönetici hesabına uygulanamaz.'; end if;
  perform oyun.korunan_hedef_ceza(p, h.id);
  g := btrim(coalesce(p_gerekce, ''));
  if char_length(g) < 5 or char_length(g) > 300 then raise exception 'Gerekçe 5-300 karakter olmalı (oyuncu görür).'; end if;
end $f$;
revoke all on function oyun.mod_kucuk_ceza_hazirla(text, text) from public, anon, authenticated;

-- 1) Resmî uyarı
create or replace function public.mod_uyari(p_kad text, p_gerekce text, p_kanit text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare z record; t timestamptz := oyun.simdi(); n int; oto boolean := false;
begin
  select * into z from oyun.mod_kucuk_ceza_hazirla(p_kad, p_gerekce);
  insert into oyun.mod_ceza(hedef, tur, gerekce, kanit, veren, zaman)
  values ((z.h).id, 'uyari', z.g, nullif(left(btrim(coalesce(p_kanit, '')), 600), ''), (z.p).id, t);
  select count(*) into n from oyun.mod_ceza where hedef = (z.h).id and tur = 'uyari' and zaman > t - interval '24 hours';
  perform oyun.bildir((z.h).id, format('Oyun yönetiminden resmî uyarı (%s/3): %s Kurallara uymaya devam etmezsen sohbet susturma, para cezası ve uzaklaştırma uygulanır.', least(n, 3), z.g), t);
  perform oyun.mod_log(z.p, 'mod_uyari', (z.h).kad, format('%s. uyarı (24 saat) · %s', n, left(z.g, 200)));
  -- 24 saatte 3. uyarı: kendiliğinden susturma (kademe kuralı da işler)
  if n >= 3 and not coalesce((select susturma_bitis > t from oyun.profiller where id = (z.h).id), false) then
    perform public.yk_sustur((z.h).kad, 1, 'Son 24 saatte 3 resmî uyarı.');
    oto := true;
  end if;
  return public.yk_oyuncu((z.h).kad) || jsonb_build_object('uyari_sayisi', n, 'oto_susturma', oto);
end $f$;
revoke all on function public.mod_uyari(text, text, text) from public, anon;
grant execute on function public.mod_uyari(text, text, text) to authenticated, service_role;

-- 2) Para cezası
create or replace function public.mod_para_cezasi(p_kad text, p_tutar numeric, p_gerekce text, p_kanit text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare z record; t timestamptz := oyun.simdi(); v_tutar numeric := round(coalesce(p_tutar, 0)); v_var numeric; v_al numeric;
begin
  select * into z from oyun.mod_kucuk_ceza_hazirla(p_kad, p_gerekce);
  if v_tutar <= 0 then raise exception 'Ceza tutarı seç.'; end if;
  if not coalesce((z.p).yonetici, false) then
    if v_tutar > 10000 then raise exception 'Tek başına en çok 10.000 ₺ para cezası kesebilirsin. Daha ağırı için yaptırım talebi aç ya da kurucuya ilet.'; end if;
    if exists (select 1 from oyun.mod_ceza where hedef = (z.h).id and tur = 'para' and zaman > t - interval '1 hour') then
      raise exception '% adlı oyuncuya son 1 saat içinde zaten para cezası kesildi. Tekrar ediyorsa susturma ya da uzaklaştırma uygula.', (z.h).kad;
    end if;
  elsif v_tutar > 100000000 then raise exception 'Tutar çok yüksek.';
  end if;
  perform oyun.cuzdanim((z.h).id);
  select para into v_var from oyun.cuzdan where user_id = (z.h).id for update;
  v_al := least(v_tutar, greatest(coalesce(v_var, 0), 0));
  if v_al > 0 then
    perform oyun.para_islem((z.h).id, -v_al, 'ceza', 'Oyun yönetimi para cezası: ' || left(z.g, 150), t);
    perform oyun.hazine_kaydet('ceza', round(v_al / greatest(oyun.pazar_tl_milyar(), 1), 6), 'Oyun yönetimi para cezası');
  end if;
  insert into oyun.mod_ceza(hedef, tur, tutar, tahsil, gerekce, kanit, veren, zaman)
  values ((z.h).id, 'para', v_tutar, v_al, z.g, nullif(left(btrim(coalesce(p_kanit, '')), 600), ''), (z.p).id, t);
  perform oyun.bildir((z.h).id, format('Oyun yönetimi sana %s para cezası kesti%s. Sebep: %s Tekrarında susturma ve uzaklaştırma uygulanır. İtiraz için: %s',
                                       oyun.tl(v_tutar), case when v_al < v_tutar then format(' (cüzdanındaki %s tahsil edildi)', oyun.tl(v_al)) else '' end,
                                       z.g, oyun.iletisim()), t);
  perform oyun.mod_log(z.p, 'mod_para_cezasi', (z.h).kad, format('%s ceza · %s tahsil · %s', oyun.tl(v_tutar), oyun.tl(v_al), left(z.g, 200)));
  return public.yk_oyuncu((z.h).kad) || jsonb_build_object('ceza', v_tutar, 'tahsil', v_al);
end $f$;
revoke all on function public.mod_para_cezasi(text, numeric, text, text) from public, anon;
grant execute on function public.mod_para_cezasi(text, numeric, text, text) to authenticated, service_role;

-- 3) Oyuncunun son 30 gündeki küçük cezaları (moderatör dosyası için)
create or replace function public.mod_kucuk_cezalar(p_kad text)
returns jsonb language plpgsql stable security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.yetki_zorunlu('oyuncu_ara'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); kd record;
begin
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  select * into kd from oyun.sustur_kademe(h.id, t);
  return jsonb_build_object(
    'uyari_24s', (select count(*) from oyun.mod_ceza where hedef = h.id and tur = 'uyari' and zaman > t - interval '24 hours'),
    'uyari_30g', (select count(*) from oyun.mod_ceza where hedef = h.id and tur = 'uyari' and zaman > t - interval '30 days'),
    'para_30g', (select coalesce(sum(tutar), 0) from oyun.mod_ceza where hedef = h.id and tur = 'para' and zaman > t - interval '30 days'),
    'sustur_30g', kd.onceki, 'sonraki_sustur_alt_saat', kd.alt_saat,
    'son', coalesce((select jsonb_agg(jsonb_build_object('tur', c.tur, 'tutar', c.tutar, 'tahsil', c.tahsil, 'gerekce', c.gerekce, 'zaman', c.zaman) order by c.zaman desc)
                       from (select * from oyun.mod_ceza where hedef = h.id order by zaman desc limit 10) c), '[]'::jsonb));
end $f$;
revoke all on function public.mod_kucuk_cezalar(text) from public, anon;
grant execute on function public.mod_kucuk_cezalar(text) to authenticated, service_role;
