-- 201 · Finans güvenliği (2026-11-12)
-- Banka ve ekonomi denetiminde bulunan açıkların kapatılması. Oyuncu verisi değişmez; yalnız kural eklenir.
--  A) NaN / Infinity: "NaN" tutarıyla cüzdan ve hesaplar sonsuz paraya çevrilebiliyordu.
--     Bütün sayısal sütunlara "sonlu sayı" kısıtı + para_islem girişinde denetim.
--  B) EFT: günlük aktarma sınırı, aynı cihaz, takip ve servet vergisi denetimleri yoktu.
--  C) Banka içi havale: takip / kapalı hesap / engel denetimi yoktu.
--  D) Şirket kâr payı: ortak başına yuvarlama, kasadan çıkandan fazlasını dağıtıyordu.
--  E) Kart: oyuncu, ortağı ya da yöneticisi olduğu şirkete kartla para aktarabiliyordu.
--  F) Banka bilançosu: henüz tahsil edilmemiş kredi faizi "kâr" sayılıp dağıtılabiliyordu.
--  G) Çek: bankalar çek yazarak kasayı (mevduat dahil) boşaltabiliyordu; kişisel çeklerde
--     aynı cihaz / takip / servet vergisi / kapalı hesap / engel denetimleri yoktu.

-- Canlıdaki işlev gövdesine küçük, doğrulamalı yama: beklenen metin yoksa durur, yama varsa atlar.
create or replace function oyun.fn_yama(p_fn regprocedure, p_isaret text, p_cift text[])
returns boolean language plpgsql as $f$
declare d text := pg_get_functiondef(p_fn); i int;
begin
  if position(p_isaret in d) > 0 then return false; end if;
  if coalesce(array_length(p_cift, 1), 0) = 0 or array_length(p_cift, 1) % 2 <> 0 then
    raise exception 'fn_yama: eski/yeni çiftleri eksik (%).', p_fn; end if;
  for i in 1 .. array_length(p_cift, 1) / 2 loop
    if position(p_cift[2*i-1] in d) = 0 then
      raise exception 'fn_yama: % içinde beklenen metin yok: «%»', p_fn, left(p_cift[2*i-1], 70); end if;
    d := replace(d, p_cift[2*i-1], p_cift[2*i]);
  end loop;
  if position(p_isaret in d) = 0 then raise exception 'fn_yama: yama işareti (%) yeni gövdede yok (%).', p_isaret, p_fn; end if;
  execute d;
  return true;
end $f$;
revoke all on function oyun.fn_yama(regprocedure, text, text[]) from public, anon, authenticated;

-- ───────────────────────── A) NaN / Infinity ─────────────────────────
-- numeric türü 'NaN' ve 'Infinity' kabul eder; NaN her sayıdan büyük sayıldığı için
-- "bakiye yetersiz" denetimlerinden geçer. Hiçbir sayısal sütuna yazılamasın.
create or replace function oyun.sonlu_kisit_kur() returns integer language plpgsql as $f$
declare r record; n int := 0;
begin
  for r in
    select c.oid::regclass as tbl,
           string_agg(format('add constraint %I check (%I > ''-Infinity'' and %I < ''Infinity'')',
                             left('sonlu_' || a.attname, 63), a.attname, a.attname), ', ' order by a.attnum) as ekler,
           count(*) as k
      from pg_class c
      join pg_namespace ns on ns.oid = c.relnamespace
      join pg_attribute a on a.attrelid = c.oid
     where ns.nspname = 'oyun' and c.relkind = 'r' and a.attnum > 0 and not a.attisdropped
       and a.atttypid in ('numeric'::regtype, 'float4'::regtype, 'float8'::regtype)
       and not exists (select 1 from pg_constraint k
                        where k.conrelid = c.oid and k.conname = left('sonlu_' || a.attname, 63))
     group by c.oid
     order by c.oid::regclass::text
  loop
    execute format('alter table %s %s', r.tbl, r.ekler);
    n := n + r.k;
  end loop;
  return n;
end $f$;
revoke all on function oyun.sonlu_kisit_kur() from public, anon, authenticated;

select oyun.sonlu_kisit_kur();

select oyun.fn_yama('oyun.para_islem(uuid,numeric,text,text,timestamptz,numeric)'::regprocedure, '/*201*/', array[
  'perform oyun.cuzdanim(u);',
  'if p_tutar is null or p_tutar = ''NaN''::numeric or p_tutar = ''Infinity''::numeric or p_tutar = ''-Infinity''::numeric then /*201*/
    raise exception ''Geçersiz tutar.'';
  end if;
  perform oyun.cuzdanim(u);'
]);

-- ───────────────────────── B) EFT ─────────────────────────
select oyun.fn_yama('public.ib_eft(bigint,bigint,text,numeric)'::regprocedure, '/*201*/', array[
  'if al is null then raise exception ''Alici kullanici bulunamadi'';end if;',
  'if al is null then raise exception ''Alici kullanici bulunamadi'';end if;
 if al<>u then /*201*/
   if exists(select 1 from oyun.profiller where id=al and yasakli) then raise exception ''Bu oyuncunun hesabı kapatılmış.''; end if;
   if (select coklu_kontrol from oyun.ayarlar where id=1) and exists(select 1 from oyun.bagli_hesaplar(u) b where b=al) then
     raise exception ''Aynı cihazda açılmış hesaplar arasında EFT yapılamaz.''; end if;
   if exists(select 1 from oyun.servet_vergi_borc b where b.user_id=u and b.borc>0) then
     raise exception ''Servet vergisi borcun ödenmeden başka oyuncuya para aktaramazsın.''; end if;
   if oyun.engelli(al,u) then raise exception ''Bu oyuncu seni engellediği için ona para gönderemezsin.''; end if;
   perform oyun.takip_engel(u,''banka transferi yapamazsın'');
   if oyun.gunluk_aktarim(u,tm)+t>oyun.aktarim_tavani() then
     raise exception ''Günlük para aktarma sınırı % ₺ (bugün % ₺ gönderdin). Bankalar arası EFT de bu sınıra dahildir.'',
       oyun.tl(oyun.aktarim_tavani()),oyun.tl(oyun.gunluk_aktarim(u,tm));
   end if;
 end if;',
  '''EFT gonderildi: ''||p_alici',
  'case when al=u then ''EFT (kendi hesabım): '' else ''EFT gonderildi: '' end||p_alici'
]);

-- EFT de günlük aktarma sayacına girer.
select oyun.fn_yama('oyun.gunluk_aktarim(uuid,timestamptz)'::regprocedure, 'EFT gonderildi', array[
  'aciklama like ''Havale: %''',
  '(aciklama like ''Havale: %'' or aciklama like ''EFT gonderildi: %'')'
]);

-- ───────────────────────── C) Banka içi havale ─────────────────────────
select oyun.fn_yama('public.ib_havale(bigint,text,numeric)'::regprocedure, '/*201*/', array[
  'if al is null or al=u then raise exception ''Gecerli bir baska alici sec'';end if;',
  'if al is null or al=u then raise exception ''Gecerli bir baska alici sec'';end if;
 if exists(select 1 from oyun.profiller where id=al and yasakli) then raise exception ''Bu oyuncunun hesabı kapatılmış.''; end if; /*201*/
 if oyun.engelli(al,u) then raise exception ''Bu oyuncu seni engellediği için ona para gönderemezsin.''; end if;
 perform oyun.takip_engel(u,''banka transferi yapamazsın'');'
]);

-- ───────────────────────── D) Şirket kâr payı ─────────────────────────
-- Her ortağa payı aşağı yuvarlanarak ödenir; kasadan yalnız gerçekten dağıtılan tutar düşer.
select oyun.fn_yama('public.sirket_kar_payi(bigint,numeric)'::regprocedure, '/*201*/', array[
  'x record;t timestamptz:=oyun.simdi();',
  'x record;t timestamptz:=oyun.simdi();v_p numeric;v_top numeric:=0;/*201*/',
  'update oyun.sirketler set kasa=kasa-p_tutar where id=p_sirket;',
  '',
  'perform oyun.para_islem(x.user_id,round(p_tutar*x.pay/100,2),''sirket'',''Sirket kar payi'',t);',
  'v_p:=floor(p_tutar*x.pay/100);
 if v_p>0 then perform oyun.para_islem(x.user_id,v_p,''sirket'',''Sirket kar payi'',t); v_top:=v_top+v_p; end if;',
  'return jsonb_build_object(''tamam'',true);',
  'if v_top<=0 then raise exception ''Bu tutar ortak paylarina bolununce kimseye 1 TL dusmuyor; daha yuksek tutar gir.''; end if;
 update oyun.sirketler set kasa=kasa-v_top where id=p_sirket and kasa>=v_top;
 if not found then raise exception ''Sirket kasasi yetersiz.''; end if;
 return jsonb_build_object(''tamam'',true,''dagitilan'',v_top);'
]);

-- ───────────────────────── E) Kart ile kendi şirketine ödeme ─────────────────────────
select oyun.fn_yama('oyun.kart_harca(bigint,numeric,uuid,bigint,text)'::regprocedure, '/*201*/', array[
  'if b.kurucu=u then raise exception',
  'if b.kurucu=u or b.yonetici=u /*201*/
      or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=b.id and o.user_id=u and o.pay>0) then raise exception'
]);

-- ───────────────────────── F) Banka bilançosu ─────────────────────────
-- Kredi verildiği anda faizin tamamı özkaynağa yazılıyordu; kâr dağıtımı ve sermaye azaltımı
-- artık yalnız anapara üzerinden (tahsil edilmemiş faiz hariç) hesaplanır. Not ve göstergeler değişmedi.
select oyun.fn_yama('oyun.banka_bilanco(bigint)'::regprocedure, '/*201*/', array[
  'nakit numeric; kredi numeric := 0;',
  'nakit numeric; kredi_ana numeric := 0; ozk_iht numeric; /*201*/ kredi numeric := 0;',
  '-- Kartlar: asgari',
  'select coalesce(sum(least(k.kalan, greatest(0, k.anapara - coalesce(k.anapara_odendi, 0)))), 0) into kredi_ana
    from oyun.oyb_kredi k where k.banka_id = p_banka and k.durum in (''aktif'',''takip'');

  -- Kartlar: asgari',
  'dag := greatest(0, least(ozk - s.sermaye, nakit - rezerv, ozk - riskli * .12));',
  'ozk_iht := ozk - greatest(0, kredi - kredi_ana);
  dag := greatest(0, least(ozk_iht - s.sermaye, nakit - rezerv, ozk_iht - riskli * .12));',
  'azalt := greatest(0, least(s.sermaye - 1000000, nakit - rezerv, ozk - riskli * .12));',
  'azalt := greatest(0, least(s.sermaye - 1000000, nakit - rezerv, ozk_iht - riskli * .12));'
]);

-- ───────────────────────── G) Çek güvenliği ─────────────────────────
create or replace function oyun.cek_guvenlik_201() returns trigger language plpgsql as $f$
declare coklu boolean := coalesce((select coklu_kontrol from oyun.ayarlar where id = 1), false);
begin
  if tg_op = 'INSERT' then
    -- Banka kasası mevduat sahiplerinin parasını da tutar: banka çek yazamaz.
    if new.borclu_sirket is not null
       and exists(select 1 from oyun.sirketler s where s.id = new.borclu_sirket and s.sektor = 'banka') then
      raise exception 'Bankalar çek düzenleyemez. Banka kasasından para yalnız kâr payı, sermaye azaltımı ve bankacılık işlemleriyle çıkar.';
    end if;
    if new.borclu_sirket is null then
      if oyun.gecikmede(new.duzenleyen) then
        raise exception 'Gecikmiş kredi borcun varken çek yazamazsın. Önce borcunu öde (Hayat › Banka).'; end if;
      if exists(select 1 from oyun.servet_vergi_borc b where b.user_id = new.duzenleyen and b.borc > 0) then
        raise exception 'Servet vergisi borcun ödenmeden çek yazamazsın.'; end if;
      if new.ilk_lehtar is not null then
        if exists(select 1 from oyun.profiller p where p.id = new.ilk_lehtar and p.yasakli) then
          raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
        if oyun.engelli(new.ilk_lehtar, new.duzenleyen) then
          raise exception 'Bu oyuncu seni engellediği için ona çek yazamazsın.'; end if;
        if coklu and exists(select 1 from oyun.bagli_hesaplar(new.duzenleyen) b where b = new.ilk_lehtar) then
          raise exception 'Aynı cihazda açılmış hesaplar arasında çek düzenlenemez.'; end if;
      elsif new.ilk_lehtar_sirket is not null then
        if coklu and exists(select 1 from oyun.sirket_ortaklari o
                             join oyun.bagli_hesaplar(new.duzenleyen) b on b = o.user_id
                            where o.sirket_id = new.ilk_lehtar_sirket and o.pay > 0) then
          raise exception 'Aynı cihazdaki bağlı hesapların şirketine çek düzenlenemez.'; end if;
      end if;
    end if;
  elsif new.hamil is not null and new.hamil is distinct from old.hamil and old.hamil is not null then
    -- kişiden kişiye ciro
    if exists(select 1 from oyun.profiller p where p.id = new.hamil and p.yasakli) then
      raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
    if coklu and exists(select 1 from oyun.bagli_hesaplar(old.hamil) b where b = new.hamil) then
      raise exception 'Aynı cihazda açılmış hesaplar arasında çek ciro edilemez.'; end if;
  end if;
  return new;
end $f$;

-- Ad sırasıyla ilk çalışsın diye "cek_a_": diğer çek tetikleyicilerinden önce karar verir.
drop trigger if exists cek_a_guvenlik_201_trg on oyun.cekler;
create trigger cek_a_guvenlik_201_trg before insert or update of hamil on oyun.cekler
  for each row execute function oyun.cek_guvenlik_201();
