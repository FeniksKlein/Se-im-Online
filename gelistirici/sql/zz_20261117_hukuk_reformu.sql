-- 17.11.2026 · Hukuk reformu: istinaf, kesin hüküm, tarafsız jüri
-- Canlı sunucuya Supabase migration'larıyla uygulandı (hukuk_reformu_1..5); bu dosya tam kurulumla eşitlik içindir.
-- 1) İstinaf beraat kararını bozarsa dosya Yüksek Mahkemeye İADE edilir: bozmaya uymak zorunlu, beraat verilemez;
--    tazminat dosyasında yalnız tutar belirlenir (önceden her bozma "uyarı"ya çevriliyordu — Adliye #72 hatası).
--    Süre dolarsa: tazminatta verilen tutarların ortancası, hiç oy yoksa talebin 1/4'ü; cezada en hafif oy, yoksa uyarı. Karar kesin.
-- 2) Derdestlik ve kesin hüküm (HMK m.114, m.303): aynı taraflar arasında aynı türde açık dava varken ya da
--    kesinleşmeden sonraki 15 gün içinde yeni dava açılamaz ("düştü" ile bitenler hariç).
-- 3) Uyarı ve 1 saatlik susturma kesin karardır (istinafa kapalı).
-- 4) Reddedilen istinafın yargılama gideri (CMK m.325, HMK m.326): maktu 50.000 ₺; tazminatta tutarın %10'u (50.000–150.000 ₺).
-- 5) Jüri: oyuna girip 12 saat oy vermeyen asıl üyenin yerine yedek geçer; karar çıkınca yedeklere ve oyu gereksiz kalan
--    asıl üyeye bildirim gider; kura aktif oyuncular arasında önce farklı partilerden seçer, taraflarla son 30 günde davalık olanı almaz.

alter table oyun.adliye_davalar add column if not exists bozma_iade boolean not null default false;

create table if not exists oyun.adliye_karar_oy_arsiv (
  dava_id bigint, uye uuid, karar text, gerekce text, zaman timestamptz, tazminat_tutar numeric,
  musadere_tutar numeric, musadere_sorumlu uuid, musadere_sirket bigint, arsiv_zaman timestamptz, neden text);
alter table oyun.adliye_karar_oy_arsiv enable row level security;

alter table oyun.mahkeme_ayar add column if not exists istinaf_gider numeric not null default 50000,
  add column if not exists istinaf_nispi numeric not null default 0.10,
  add column if not exists istinaf_gider_ust numeric not null default 150000;

CREATE OR REPLACE FUNCTION oyun.adliye_kesin_karar_mi(p_karar text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$ select p_karar in ('uyari','sustur_1s') $function$
;

CREATE OR REPLACE FUNCTION oyun.istinaf_gider(d oyun.adliye_davalar)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select case when d.tur = 'tazminat' then
      least(a.istinaf_gider_ust, greatest(a.istinaf_gider,
        round(coalesce(case when d.karar = 'tazminat' then d.tazminat_tutar else d.tazminat_talep end, 0) * a.istinaf_nispi / 1000) * 1000))
    else a.istinaf_gider end
  from oyun.mahkeme_ayar a
$function$
;

CREATE OR REPLACE FUNCTION oyun.tg_adliye_dava_duzen()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare t timestamptz := oyun.simdi();
begin
  if coalesce(old.bozma_iade,false) then
    new.ilk_karar := old.ilk_karar;
    if new.durum='karar' and old.durum='acik' and not coalesce(new.kesin,false) then
      new.istinaf_son := t;
    end if;
  elsif new.durum='karar' and old.durum='acik' and not coalesce(new.kesin,false) and oyun.adliye_kesin_karar_mi(new.karar) then
    new.istinaf_son := t;
    perform oyun.bildir(x.id, format('Adliye #%s: "%s" hafif yaptırım olduğundan karar kesindir, istinaf yolu kapalıdır.', new.id, new.karar), t)
      from (select new.davaci id union select new.davali where new.davali is not null) x;
  end if;
  return new;
end $function$
;
drop trigger if exists adliye_dava_duzen_tg on oyun.adliye_davalar;
create trigger adliye_dava_duzen_tg before update of durum, ilk_karar, istinaf_son on oyun.adliye_davalar
  for each row execute function oyun.tg_adliye_dava_duzen();

CREATE OR REPLACE FUNCTION oyun.tg_dava_tekrar_engel()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare t timestamptz := oyun.simdi(); taz boolean; x oyun.adliye_davalar; bekle int := 15;
begin
  taz := new.tur='tazminat' or coalesce(current_setting('oyun.tazminat_davasi',true),'')='1';
  select d.* into x from oyun.adliye_davalar d
   where (case when new.davaci_parti is not null then d.davaci_parti = new.davaci_parti
               else d.davaci = new.davaci and d.davaci_parti is null end)
     and (case when new.davali is not null then d.davali = new.davali
               when new.davali_parti is not null then d.davali_parti = new.davali_parti
               else d.davali_kurum_tur = new.davali_kurum_tur and d.davali_kurum_id = new.davali_kurum_id end)
     and (d.tur='tazminat') = taz
     and d.karar is distinct from 'dusme'
     and (not coalesce(d.kesin,false) or coalesce(d.karar_at,d.acilis) > t - make_interval(days => bekle))
   order by d.id desc limit 1;
  if x.id is not null then
    if not coalesce(x.kesin,false) then
      raise exception 'Aynı taraflar arasında aynı konuda görülmekte olan dava var (#%). Derdest dava varken aynı dava yeniden açılamaz (HMK m.114). Yeni iddia ve delilleri o dosyaya ek beyan olarak verin.', x.id;
    else
      raise exception 'Aynı taraflar arasındaki #% numaralı dava kesin hükme bağlandı. Kesin hüküm bulunan konuda yeniden dava açılamaz (HMK m.303, ne bis in idem). Yeni bir olay için % tarihinden sonra dava açabilirsin.',
        x.id, to_char((coalesce(x.karar_at,x.acilis) + make_interval(days => bekle)) at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI');
    end if;
  end if;
  return new;
end $function$
;
drop trigger if exists dava_tekrar_engel_tg on oyun.adliye_davalar;
create trigger dava_tekrar_engel_tg before insert on oyun.adliye_davalar
  for each row execute function oyun.tg_dava_tekrar_engel();

CREATE OR REPLACE FUNCTION oyun.adliye_iade_sonuc(p_dava bigint, t timestamp with time zone)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d oyun.adliye_davalar; heyet uuid[]; nh int; oylar int; v_karar text; v_tutar numeric; v_hakim uuid; v_ger text; bitis timestamptz;
begin
  select * into d from oyun.adliye_davalar where id=p_dava for update;
  if d.id is null or d.durum<>'acik' or not d.bozma_iade then return null; end if;
  if oyun.adliye_oy_say(d.id,t) then return 'karar'; end if;
  heyet := oyun.dava_heyeti(d); nh := cardinality(heyet);
  select count(*) into oylar from oyun.adliye_karar_oy o where o.dava_id=d.id and o.uye=any(heyet);
  if not d.karar_uzatildi and nh>0 and oylar<nh then
    update oyun.adliye_davalar set karar_son=t+interval '24 hours', karar_uzatildi=true, karar_hatirlatildi=false where id=d.id;
    perform oyun.bildir(u, format('Yüksek Mahkeme: Adliye #%s (istinaf bozması sonrası) için süre doldu, 24 saat ek süre verildi. Ek süre de dolarsa verilen oylardan, oy yoksa kanuni varsayılanla karar çıkacak.', d.id), t)
      from unnest(heyet) u;
    return 'uzatildi';
  end if;
  if d.tur='tazminat' and d.davali is not null then
    v_karar := 'tazminat';
    select percentile_disc(0.5) within group (order by o.tazminat_tutar) into v_tutar
      from oyun.adliye_karar_oy o where o.dava_id=d.id and o.uye=any(heyet) and o.karar='tazminat' and o.tazminat_tutar>0;
    if v_tutar is null then
      v_tutar := greatest(1000, least(1000000, round(coalesce(d.tazminat_talep,4000)*0.25/1000)*1000));
      v_ger := format('İstinaf jürisi ilk derece kararını bozdu ve tazminat sorumluluğunu tespit etti. Yüksek Mahkeme ek süre dahil tutar belirlemediğinden, hakkaniyet gereği talep edilen %s TL''nin dörtte biri olan %s TL manevi tazminata hükmedildi (TBK m.58, BK m.4 takdir yetkisi).', d.tazminat_talep, v_tutar);
    else
      v_ger := format('İstinaf bozmasına uyularak tazminat tutarı heyet oylarının ortanca değeri olan %s TL olarak belirlendi.', v_tutar);
    end if;
  else
    select o.karar into v_karar from oyun.adliye_karar_oy o where o.dava_id=d.id and o.uye=any(heyet) and o.karar<>'beraat'
      order by oyun.adliye_karar_agirlik(o.karar), o.zaman limit 1;
    if v_karar is null then
      v_karar := 'uyari';
      v_ger := 'İstinaf jürisi beraat kararını bozdu. Yüksek Mahkeme ek süre dahil yaptırım belirlemediğinden, kanuni en hafif yaptırım olan uyarıya hükmedildi.';
    else
      v_ger := format('İstinaf bozmasına uyuldu; heyet oyları arasında sanık lehine olan en hafif yaptırım (%s) uygulandı (CMK m.229/3 lehe oy ilkesi).', v_karar);
    end if;
  end if;
  select o.uye into v_hakim from oyun.adliye_karar_oy o where o.dava_id=d.id and o.uye=any(heyet) order by o.zaman limit 1;
  update oyun.adliye_davalar set durum='karar', karar=v_karar, gerekce=v_ger, hakim=coalesce(v_hakim,hakim), karar_at=t,
    tazminat_tutar=case when v_karar='tazminat' then v_tutar end, kesin=false, istinaf_son=t where id=d.id returning * into d;
  bitis := oyun.adliye_hafif_ceza(d,t);
  update oyun.adliye_davalar set ceza_bitis=bitis where id=d.id;
  perform oyun.adliye_kesinlestir(d.id,t);
  perform oyun.olay('adliye', format('Adliye #%s: istinaf bozmasına uyularak verilen karar kesinleşti (%s%s).', d.id, v_karar,
     case when v_karar='tazminat' then ', '||v_tutar||' TL' else '' end), null, null, t);
  return 'karar';
end $function$
;

CREATE OR REPLACE FUNCTION oyun.adliye_istinaf_sonuc(p_dava bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare i oyun.adliye_istinaf; onay int; boz int; toplam int; d oyun.adliye_davalar; r record; degisen int := 0; mesaj text; yeni_bit timestamptz;
  erken boolean; gider numeric; kayb text; alinan numeric := 0; konu text;
begin
 select * into i from oyun.adliye_istinaf where dava_id = p_dava for update;
 if i.dava_id is null or i.durum <> 'acik' then return; end if;
 select count(*) filter (where oy = 'onay'), count(*) filter (where oy = 'boz'), count(*) into onay, boz, toplam from oyun.adliye_juri where dava_id = p_dava;
 erken := (onay >= oyun.cogunluk(toplam) or boz >= oyun.cogunluk(toplam)) and t < i.bit;
 if not (onay >= oyun.cogunluk(toplam) or boz >= oyun.cogunluk(toplam)) then
  if t < i.bit then return; end if;
  if not i.uzatildi then
   update oyun.adliye_istinaf set uzatildi = true, hatirlatildi = false, bit = greatest(i.bit, t) + interval '24 hours'
    where dava_id = p_dava returning bit into yeni_bit;
   update oyun.adliye_davalar set istinaf_son = yeni_bit where id = p_dava;
   for r in select j.user_id from oyun.adliye_juri j where j.dava_id = p_dava and j.oy is null loop
    if oyun.juri_degistir(p_dava, r.user_id, t, '24 saatlik sürede oy kullanmadın') is not null then degisen := degisen + 1; end if;
   end loop;
   perform oyun.bildir(j.user_id, format('Adliye #%s istinaf jürisinde çoğunluk oluşmadı; 24 saat ek süre verildi. Ek süre de dolarsa verilen oylara göre karar çıkar.', p_dava), t)
     from oyun.adliye_juri j where j.dava_id = p_dava and j.oy is null and (j.atama is null or j.atama < t);
   perform oyun.olay('adliye', format('Adliye #%s istinaf jürisi süresinde çoğunluk sağlayamadı; %s üye değiştirildi, 24 saat ek süre verildi.', p_dava, degisen), null, null, t);
   return;
  end if;
  for r in select j.user_id from oyun.adliye_juri j where j.dava_id = p_dava and j.oy is null loop
   insert into oyun.juri_ihmal(user_id, dava_id, zaman) values (r.user_id, p_dava, t) on conflict do nothing;
   perform oyun.bildir(r.user_id, format('Adliye #%s istinaf jürisinde ek süre dahil oy kullanmadın; karar diğer üyelerin oylarıyla çıktı. 14 gün boyunca jüriye seçilmeyeceksin.', p_dava), t);
  end loop;
 end if;
 select * into d from oyun.adliye_davalar where id = p_dava for update;
 kayb := case when d.karar = 'beraat' then 'davaci' else 'davali' end;

 if boz > onay and boz + onay >= 2 then
  update oyun.adliye_istinaf set durum = 'bozuldu' where dava_id = p_dava;
  if d.karar = 'beraat' then
   -- Bozma + iade: Yüksek Mahkeme bozmaya uymak zorunda; beraat veremez, yalnız yaptırımı / tazminat tutarını belirler.
   konu := case when d.tur = 'tazminat' and d.davali is not null then 'yalnız tazminat TUTARINI' else 'yalnız YAPTIRIMI' end;
   insert into oyun.adliye_karar_oy_arsiv(dava_id,uye,karar,gerekce,zaman,tazminat_tutar,musadere_tutar,musadere_sorumlu,musadere_sirket,arsiv_zaman,neden)
     select o.dava_id,o.uye,o.karar,o.gerekce,o.zaman,o.tazminat_tutar,o.musadere_tutar,o.musadere_sorumlu,o.musadere_sirket,t,'istinaf_bozma'
     from oyun.adliye_karar_oy o where o.dava_id = p_dava;
   delete from oyun.adliye_karar_oy where dava_id = p_dava;
   update oyun.adliye_davalar set durum = 'acik', karar = null, bozma_iade = true, kesin = false,
     karar_son = t + make_interval(hours => (select karar_saat from oyun.mahkeme_ayar)), karar_uzatildi = false, karar_hatirlatildi = false,
     gerekce = format('İstinaf jürisi beraat kararını %s boz / %s onay oyla BOZDU. Dosya, bozmaya uyularak %s belirlemek üzere Yüksek Mahkemeye iade edildi (beraat verilemez).', boz, onay, konu)
     where id = p_dava;
   perform oyun.bildir(u, format('⚖️ Adliye #%s istinafta BOZULDU ve size iade edildi. Bozmaya uymak zorunludur: %s belirleyin, beraat verilemez. Süre %s saat; oy kullanılmazsa kanuni varsayılanla karar çıkar.',
       p_dava, konu, (select karar_saat from oyun.mahkeme_ayar)), t) from unnest(oyun.dava_heyeti(d)) u;
   perform oyun.bildir(x.id, format('Adliye #%s: istinaf jürisi beraat kararını bozdu (%s/%s). Yüksek Mahkeme bozmaya uyarak %s belirleyecek; bu karar kesin olacak.', p_dava, boz, onay, konu), t)
     from (select d.davaci id union select d.davali where d.davali is not null) x;
   perform oyun.adliye_duyur((select user_id from oyun.adliye_juri where dava_id = p_dava and oy = 'boz' order by zaman limit 1),
     format('İstinaf jürisi Adliye #%s beraat kararını BOZDU (%s boz / %s onay); dosya yaptırım/tutar için Yüksek Mahkemeye iade edildi. #Adliye', p_dava, boz, onay), array['adliye'], t);
  else
   update oyun.adliye_davalar set karar = 'beraat', ceza_bitis = null, tazminat_tutar = null where id = p_dava;
   if d.davali is not null then perform oyun.adliye_susturma_yenile(d.davali, t); end if;
   perform oyun.adliye_duyur((select user_id from oyun.adliye_juri where dava_id = p_dava and oy = 'boz' order by zaman limit 1),
     format('İstinaf jürisi Adliye #%s kararını BOZDU (%s boz / %s onay); istinaf mahkemesi esastan beraat kararı verdi. #Adliye', p_dava, boz, onay), array['adliye'], t);
  end if;
 else
  update oyun.adliye_istinaf set durum = 'onaylandi' where dava_id = p_dava;
  -- Kanun yolu giderleri başvurusu reddedilen tarafa yüklenir (CMK m.325, HMK m.326)
  gider := oyun.istinaf_gider(d);
  if gider > 0 then
   if kayb = 'davali' then
    if d.davali is not null then alinan := oyun.adliye_tahsil(d.davali, gider, format('Adliye #%s istinaf yargılama gideri', p_dava), t);
    elsif d.davali_parti is not null then
      update oyun.partiler set kasa = kasa - least(kasa, gider) where id = d.davali_parti; alinan := gider; end if;
   else
    if d.davaci_parti is not null then update oyun.partiler set kasa = kasa - least(kasa, gider) where id = d.davaci_parti; alinan := gider;
    else alinan := oyun.adliye_tahsil(d.davaci, gider, format('Adliye #%s istinaf yargılama gideri', p_dava), t); end if;
   end if;
  end if;
  mesaj := case
   when onay + boz = 0 then format('Adliye #%s istinaf jürisi ek süre dahil oy kullanmadı; bozma için çoğunluk oluşmadığından ilk derece kararı onandı.', p_dava)
   when onay + boz = 1 then format('Adliye #%s istinafında ek süre dahil yalnız 1 üye oy kullandı; tek oyla karar bozulamayacağından ilk derece kararı onandı.', p_dava)
   when onay = boz then format('Adliye #%s istinafında oylar eşit (%s/%s); bozma için çoğunluk oluşmadığından ilk derece kararı onandı.', p_dava, onay, boz)
   else format('İstinaf jürisi Adliye #%s kararını onayladı (%s onay / %s boz).', p_dava, onay, boz) end
   || case when alinan > 0 then format(' Başvuru reddedildiğinden %s TL istinaf yargılama gideri başvurana yüklendi.', alinan) else '' end;
  perform oyun.olay('adliye', mesaj, null, null, t);
  perform oyun.bildir(x.id, mesaj, t) from (select d.davaci id union select d.davali where d.davali is not null) x;
 end if;

 -- Görevi sona eren yedeklere ve (çoğunluk erken oluştuğu için) oy kullanmasına gerek kalmayan asıl üyelere bilgi
 perform oyun.bildir(y.user_id, format('Adliye #%s istinafı karara bağlandı. Asıl üyeler görevini yaptığı için yedek üye olarak göreve çağrılmana gerek kalmadı; görevin sona erdi.', p_dava), t)
   from oyun.adliye_juri_yedek y where y.dava_id = p_dava and not y.kullanildi
     and not exists (select 1 from oyun.adliye_juri j where j.dava_id = p_dava and j.user_id = y.user_id);
 if erken then
  perform oyun.bildir(j.user_id, format('Adliye #%s istinafında 3 üyeden 2''si aynı yönde oy verdiği için çoğunluk oluştu ve karar çıktı (oy çokluğu). Oyuna gerek kalmadı; herhangi bir yaptırım yok.', p_dava), t)
    from oyun.adliye_juri j where j.dava_id = p_dava and j.oy is null;
 end if;

 if not (boz > onay and boz + onay >= 2 and d.karar = 'beraat') then
  perform oyun.adliye_kesinlestir(p_dava, t);
 end if;
end $function$
;

CREATE OR REPLACE FUNCTION oyun.adliye_sure_doldu(p_dava bigint, t timestamp with time zone)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d oyun.adliye_davalar; heyet uuid[]; nh int; gerek int; oylar int; r record; kum int:=0; sec record; v_hakim uuid; v_ger text; ozet text; bitis timestamptz; bulundu boolean:=false; tum boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then return null; end if;
 if d.bozma_iade then return oyun.adliye_iade_sonuc(d.id,t); end if;
 heyet:=oyun.dava_heyeti(d); nh:=cardinality(heyet);
 if nh=0 then
  update oyun.adliye_davalar set karar_son=t+make_interval(hours=>(select karar_saat from oyun.mahkeme_ayar)) where id=d.id;
  return 'heyet_yok';
 end if;
 if oyun.adliye_oy_say(d.id,t) then return 'karar'; end if;
 select count(*) into oylar from oyun.adliye_karar_oy o where o.dava_id=d.id and o.uye=any(heyet);
 tum := oylar>=nh;
 -- Ek süre yalnız oy vermeyen üye varsa anlamlıdır; heyetin tamamı oy verdiyse beklemeden karar çıkar.
 if not d.karar_uzatildi and not tum then
  update oyun.adliye_davalar set karar_son=t+interval '24 hours', karar_uzatildi=true, karar_hatirlatildi=false where id=d.id;
  perform oyun.bildir(u,format('Yüksek Mahkeme: Adliye #%s için karar süresi doldu ve heyet çoğunluğu aynı görüşte birleşmedi. 24 saat ek süre verildi; ek süre de dolarsa verilen oylardan CMK m.229 kuralıyla karar çıkacak.',d.id),t)
   from unnest(heyet) u;
  perform oyun.olay('adliye',format('Adliye #%s süresinde karara bağlanamadı; mahkemeye 24 saat ek süre verildi.',d.id),null,null,t);
  return 'uzatildi';
 end if;
 if oylar=0 then
  v_ger:='Yüksek Mahkeme ek süre dahil hiç oy kullanmadığı için dosya karara bağlanamadı. Dava düştü, harç iade edildi. Davacı aynı iddiayla yeniden dava açabilir.';
  update oyun.adliye_davalar set durum='karar',karar='dusme',ilk_karar='dusme',karar_at=t,kesin=false,gerekce=v_ger where id=d.id;
  perform oyun.adliye_kesinlestir(d.id,t);
  perform oyun.olay('adliye',format('Adliye #%s: mahkeme ek süre dahil oy kullanmadığı için dava düştü.',d.id),null,null,t);
  return 'dusme';
 end if;
 gerek:=oyun.cogunluk(nh);
 for r in
  select g.karar, g.tutar, g.mtutar, g.msor, g.msir, g.n from (
    select o.karar, coalesce(o.tazminat_tutar,0) tutar, coalesce(o.musadere_tutar,0) mtutar, o.musadere_sorumlu msor, o.musadere_sirket msir, count(*)::int n
      from oyun.adliye_karar_oy o where o.dava_id=d.id and o.uye=any(heyet)
      group by 1,2,3,4,5
    union all
    select 'beraat'::text, 0::numeric, 0::numeric, null::uuid, null::bigint, (nh-oylar)::int where nh>oylar
  ) g
  order by oyun.adliye_karar_agirlik(g.karar) desc, g.tutar desc, g.mtutar desc
 loop
  kum:=kum+r.n;
  if kum>=gerek then sec:=r; bulundu:=true; exit; end if;
 end loop;
 if not bulundu then return null; end if;
 select o.uye,o.gerekce into v_hakim,v_ger from oyun.adliye_karar_oy o
  where o.dava_id=d.id and o.uye=any(heyet) and o.karar=sec.karar and coalesce(o.tazminat_tutar,0)=sec.tutar and coalesce(o.musadere_tutar,0)=sec.mtutar
    and o.musadere_sorumlu is not distinct from sec.msor and o.musadere_sirket is not distinct from sec.msir
  order by o.zaman limit 1;
 select string_agg(format('%s: %s',oyun.kad(o.uye),o.karar),', ' order by o.zaman) into ozet from oyun.adliye_karar_oy o where o.dava_id=d.id and o.uye=any(heyet);
 v_ger:=case when tum then
     format('Heyetin tamamı oy kullandı (%s/%s üye — %s) ancak çoğunluk aynı görüşte birleşmedi. CMK m.229/3 gereği sanığın en çok aleyhine olan oy, çoğunluk oluşuncaya kadar kendisine en yakın oya eklendi.',oylar,nh,ozet)
   else
     format('Karar süresi (ek süre dahil) doldu; heyet çoğunluğu aynı görüşte birleşmedi (%s/%s üye oy kullandı — %s). CMK m.229/3 gereği sanığın en çok aleyhine olan oy, çoğunluk oluşuncaya kadar kendisine en yakın oya eklendi; oy kullanmayan üyeler sanık lehine sayıldı.',oylar,nh,ozet)
   end
   || case when v_ger is not null then E'\n\n'||v_ger else E'\n\nMahkûmiyet için gerekli çoğunluk oluşmadığından şüpheden sanık yararlanır ilkesi uyarınca beraat.' end;
 update oyun.adliye_davalar set durum='karar',karar=sec.karar,ilk_karar=sec.karar,gerekce=v_ger,hakim=v_hakim,karar_at=t,
   tazminat_tutar=case when sec.karar='tazminat' then sec.tutar end,kesin=false,
   istinaf_son=t+make_interval(hours=>(select istinaf_saat from oyun.mahkeme_ayar))
  where id=d.id returning * into d;
 if sec.karar='musadere' then
  insert into oyun.adliye_musadere(dava_id,sorumlu,sirket_id,tutar,aciklama) values(d.id,sec.msor,sec.msir,sec.mtutar,v_ger) on conflict(dava_id) do nothing;
 end if;
 bitis:=oyun.adliye_hafif_ceza(d,t);
 update oyun.adliye_davalar set ceza_bitis=bitis where id=d.id;
 perform oyun.bildir(x.id,format('Adliye #%s karari: %s (CMK m.229 oy toplama kuralıyla). Istinaf yolu acik.',d.id,sec.karar),t)
  from (select d.davaci id union select d.davali where d.davali is not null) x;
 perform oyun.adliye_duyur(v_hakim,format('Yuksek Mahkeme #%s: %s davasinda karar "%s" (%s, CMK m.229/3 oy toplama). Istinaf yolu acik. #Adliye',
   d.id,d.tur,sec.karar,case when tum then 'heyet oylari ayristi' else 'sure doldu' end),array['adliye'],t);
 return 'karar';
end $function$
;

CREATE OR REPLACE FUNCTION oyun.yargi_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t timestamptz := oyun.simdi(); r record; dv oyun.adliye_davalar; a int := 0; b int := 0; c int := 0; e int := 0; gb uuid; rn int; kn int; kabul boolean; g text;
begin
  if not pg_try_advisory_xact_lock(hashtext('yargi_tick')) then return null; end if;
  for r in select j.dava_id, j.user_id from oyun.adliye_istinaf i join oyun.adliye_juri j on j.dava_id = i.dava_id join oyun.profiller p on p.id = j.user_id
           where i.durum = 'acik' and j.oy is null and t >= coalesce(j.atama, i.bas) + interval '8 hours' and t < i.bit - interval '2 hours'
             and (coalesce(p.son_gorulme, '-infinity'::timestamptz) < coalesce(j.atama, i.bas) or p.yasakli) loop
    if oyun.juri_degistir(r.dava_id, r.user_id, t, 'atandıktan sonra 8 saat oyuna girmediğin için görevini yapamadın') is not null then a := a + 1; end if;
  end loop;
  for r in select j.dava_id, j.user_id from oyun.adliye_istinaf i join oyun.adliye_juri j on j.dava_id = i.dava_id
           where i.durum = 'acik' and j.oy is null and t >= coalesce(j.atama, i.bas) + interval '12 hours' and t < i.bit - interval '2 hours' loop
    if oyun.juri_degistir(r.dava_id, r.user_id, t, 'atandıktan sonra 12 saat içinde oy kullanmadığın için görev yedek üyeye geçti') is not null then a := a + 1; end if;
  end loop;
  for dv in select * from oyun.adliye_davalar d where d.durum = 'acik' and not d.bozma_iade and d.acilis < t - interval '7 days' and cardinality(oyun.dava_heyeti(d)) = 0 loop
    g := 'Davaya bakabilecek tarafsız Yüksek Mahkeme üyesi 7 gün içinde bulunamadı. Dava düştü, harç iade edildi. Davacı aynı iddiayla yeniden dava açabilir.';
    update oyun.adliye_davalar set durum = 'karar', karar = 'dusme', ilk_karar = 'dusme', karar_at = t, kesin = false, gerekce = g where id = dv.id;
    perform oyun.adliye_kesinlestir(dv.id, t);
    perform oyun.olay('adliye', format('Adliye #%s: tarafsız yargıç bulunamadığı için dava düştü, harç iade edildi.', dv.id), null, null, t);
    b := b + 1;
  end loop;
  for r in select * from oyun.adliye_secim_itirazlari where durum = 'bekliyor' and zaman < t - interval '72 hours' loop
    g := 'Yüksek Yargıç 72 saat içinde karar vermediği için itiraz incelenmeden reddedilmiş sayıldı. Açıklanan seçim sonucu geçerlidir.';
    update oyun.adliye_secim_itirazlari set durum = 'ret', karar_at = t, karar_gerekce = g where id = r.id;
    select pa.gb into gb from oyun.partiler pa where pa.id = r.parti_id;
    if gb is not null then perform oyun.bildir(gb, format('Seçim itirazı #%s: 72 saat içinde karar verilmediği için reddedilmiş sayıldı.', r.id), t); end if;
    c := c + 1;
  end loop;
  -- İcra itirazı: 72 saatte karar çıkmazsa verilen oylara bakılır
  for r in select * from oyun.icra_takip where durum = 'itiraz' and itiraz_tarih is not null and itiraz_tarih <= t - interval '72 hours' for update skip locked loop
    select count(*) filter (where o.ret), count(*) filter (where not o.ret) into rn, kn from oyun.icra_itiraz_oy o where o.takip_id = r.id;
    kabul := kn > rn;
    g := format('Yüksek Mahkeme 72 saat içinde itirazı karara bağlamadı (%s ret / %s kabul oyu). %s', rn, kn,
        case when kabul then 'Verilen oyların çoğunluğu itirazı haklı bulduğundan takip iptal edildi.'
             else 'İtirazı haklı bulan oy çokluğu oluşmadığından itiraz reddedilmiş sayıldı, takip haciz aşamasına geçti.' end);
    update oyun.icra_takip set durum = case when kabul then 'iptal' else 'haciz' end, karar_tarih = t, karar_gerekce = g where id = r.id;
    perform oyun.bildir(r.borclu, format('İcra takibi #%s: itirazın 72 saat içinde karara bağlanmadı. %s', r.id,
      case when kabul then 'Verilen oyların çoğunluğu itirazını haklı buldu; takip iptal edildi.'
           else 'İtirazın reddedilmiş sayıldı; takip haciz aşamasına geçti.' end), t);
    e := e + 1;
  end loop;
  return jsonb_build_object('juri_degisim', a, 'dusen_dava', b, 'itiraz_ret', c, 'icra_itiraz', e);
end $function$
;

CREATE OR REPLACE FUNCTION oyun.juri_cek(d oyun.adliye_davalar, t timestamp with time zone, p_n integer)
 RETURNS uuid[]
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  with havuz as (
    select pr.id, pr.parti_id,
      case when pr.son_gorulme > t - interval '24 hours' then 0 when pr.son_gorulme > t - interval '72 hours' then 1
           when pr.son_gorulme > t - interval '7 days' then 2 else 3 end kat, random() rnd
    from oyun.profiller pr
    where pr.son_gorulme > t - interval '30 days'
      and not exists(select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = pr.id)
      and not exists(select 1 from oyun.adliye_juri_yedek y where y.dava_id = d.id and y.user_id = pr.id)
      and (select count(*) from oyun.adliye_juri j join oyun.adliye_istinaf s on s.dava_id = j.dava_id
            where j.user_id = pr.id and s.durum = 'acik' and j.oy is null) < 2
      and not exists(select 1 from oyun.adliye_davalar h where h.acilis > t - interval '30 days' and h.id <> d.id
            and ((h.davaci = pr.id and (h.davali = d.davaci or h.davali = d.davali))
              or (h.davali = pr.id and (h.davaci = d.davaci or h.davaci = d.davali))))
      and oyun.juri_aday_uygun(d, pr.id, t)
  ), sirali as (
    select h.id, h.kat, h.rnd,
      (row_number() over (partition by coalesce(h.parti_id::text, h.id::text) order by h.kat, h.rnd) > 1
       or (h.parti_id is not null and exists(select 1 from oyun.adliye_juri j2 join oyun.profiller p2 on p2.id = j2.user_id
             where j2.dava_id = d.id and p2.parti_id = h.parti_id)))::int tekrar
    from havuz h
  )
  select coalesce(array_agg(q.id order by q.o1, q.tekrar, q.kat, q.rnd), '{}'::uuid[]) from (
    select id, tekrar, kat, rnd, (kat > 1)::int o1 from sirali order by (kat > 1)::int, tekrar, kat, rnd limit p_n) q
$function$
;

CREATE OR REPLACE FUNCTION public.adliye_oy_ver(p_dava bigint, p_karar text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar;
 t timestamptz:=oyun.simdi(); karar_cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Açık bir dava bulunamadı.'; end if;
 if d.bozma_iade and d.tur='tazminat' and d.davali is not null then raise exception 'Bu dosya istinaf bozması sonrası iade edildi: bozmaya uymak zorunludur, yalnız tazminat tutarını belirleyebilirsiniz.'; end if;
 if d.bozma_iade and p_karar='beraat' then raise exception 'Bu dosya istinafta bozuldu: bozmaya uymak zorunludur, beraat verilemez; yalnız yaptırımı belirleyin.'; end if;
 if not p.id=any(oyun.dava_heyeti(d)) then raise exception 'Bu davada taraf, taraf vekili ya da taraf parti genel başkanı olduğun için oy kullanamazsın (CMK m.22: hâkimin davaya bakamayacağı haller).'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma süresinin dolmasını bekleyin.'; end if;
 if p_karar not in ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h',
  'vekillik_dusur','para_10b','para_50b','aday_yasagi','parti_para') then raise exception 'Geçersiz karar.'; end if;
 if d.davali_parti is not null and p_karar not in ('beraat','uyari','parti_para') then
  raise exception 'Partiye yalnız beraat, uyarı veya hazine yardımı kesintisi verilebilir.'; end if;
 if d.davali_kurum_tur is not null and (p_karar not in ('beraat','uyari','para_10b','para_50b') or (d.davali_kurum_tur='makam' and p_karar not in ('beraat','uyari'))) then raise exception 'Bu kuruma seçilen yaptırım uygulanamaz.'; end if;
 if d.davali is not null and p_karar='parti_para' then raise exception 'Parti cezası sadece partiye verilir.'; end if;
 if p_karar='vekillik_dusur' and not exists
   (select 1 from oyun.makamlar where user_id=d.davali and tur='mv' and bit is null) then
  raise exception 'Davalının aktif milletvekilliği yok.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 5000 then raise exception 'Gerekçeli oy 20-5000 karakter olmalı.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,gerekce,zaman)
 values(d.id,p.id,p_karar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar=excluded.karar,gerekce=excluded.gerekce,
  zaman=excluded.zaman,tazminat_tutar=null,musadere_tutar=null,
  musadere_sorumlu=null,musadere_sirket=null;
 karar_cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',karar_cikti);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_istinaf(p_dava bigint, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; t timestamptz:=oyun.simdi(); kayb text; kisisel boolean; vekil boolean:=oyun.vekil_islem_mi(); n int;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'karar' or d.kesin or d.karar='dusme' then raise exception 'Bu karar istinafa açık değil.'; end if;
 if d.bozma_iade then raise exception 'Bu karar istinaf bozmasına uyularak verildi; kesindir, yeniden istinafa gidilemez.'; end if;
 if oyun.adliye_kesin_karar_mi(d.karar) then raise exception 'Uyarı ve 1 saatlik susturma hafif yaptırımdır; bu kararlar kesindir, istinafa gidilemez (CMK m.272/3 kesinlik sınırı).'; end if;
 if t>d.istinaf_son then raise exception 'İstinaf süresi doldu.'; end if;
 if exists(select 1 from oyun.adliye_istinaf where dava_id=d.id) then raise exception 'Bu karara zaten istinaf başvurusu yapıldı.'; end if;
 kayb:=case when d.karar='beraat' then 'davaci' else 'davali' end;
 if not oyun.dava_muvekkil_mi(d,kayb,p.id) then raise exception 'İstinafa yalnız kararı kaybeden taraf ya da avukatı başvurabilir.'; end if;
 kisisel:=(kayb='davali' and d.davali=p.id) or (kayb='davaci' and d.davaci=p.id and d.davaci_parti is null);
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 4000 then raise exception 'İstinaf gerekçesi 20–4000 karakter olmalı.'; end if;
 insert into oyun.adliye_istinaf(dava_id,basvuran,gerekce,bas) values(d.id,p.id,trim(p_gerekce),t);
 perform oyun.bildir(x.id, format('Adliye #%s istinaf başvurusu alındı. Uyarı: başvuru reddedilirse (karar onanırsa) %s TL istinaf yargılama gideri kararı kaybeden tarafa yüklenir (CMK m.325, HMK m.326). Bozulursa gider yoktur.', d.id, oyun.istinaf_gider(d)), t)
   from (select p.id union select case when kayb='davali' then d.davali else d.davaci end) x where x.id is not null;
 n:=oyun.adliye_juri_kur(d.id,t);
 if n=0 then
  -- exception tüm işlemi geri alır (başvuru kaydı da silinir)
  raise exception 'Şu anda tarafsız jüri oluşturulamadı; daha sonra tekrar dene.';
 end if;
 update oyun.adliye_davalar set istinaf_son=(select i.bit from oyun.adliye_istinaf i where i.dava_id=d.id) where id=d.id;
 perform oyun.olay('adliye',format('Adliye #%s kararı istinafa taşındı; %s asıl ve %s yedek jüri üyesi kurayla belirlendi.',d.id,n,
   (select count(*) from oyun.adliye_juri_yedek y where y.dava_id=d.id)),null,null,t);
 return jsonb_build_object('tamam',true,'juri',n,'kisisel',kisisel and not vekil);
end $function$
;

CREATE OR REPLACE FUNCTION public.adliye_durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim();
begin
 return jsonb_build_object(
 'ben',p.kad,'parti_id',p.parti_id,
 'cb_miyim',exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null),
 'hakim',(select oyun.kad(hakim) from oyun.adliye_makam where id=1),
 'hakim_miyim',exists(select 1 from oyun.adliye_makam where id=1 and hakim=p.id),
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',pa.id,'ad',pa.ad,'kisa',pa.kisa,'gb',oyun.kad(pa.gb),'sozcu',oyun.kad(s.user_id),
 'gb_miyim',pa.gb=p.id,'sozcu_muyum',s.user_id=p.id) order by pa.ad)
 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where not pa.kapali),'[]'::jsonb),
 'davalar',coalesce((select jsonb_agg(jsonb_build_object(
 'id',d.id,'davaci',oyun.kad(d.davaci),'davaci_parti',dp.ad,'davali',coalesce(oyun.kad(d.davali),d.davali_kurum_ad),'davali_parti',hp.ad,'davali_kurum_tur',d.davali_kurum_tur,'davali_kurum_id',d.davali_kurum_id,'davali_kurum_ad',d.davali_kurum_ad,
 'tur',d.tur,'iddia',d.iddia,'delil',d.delil,'acilis',d.acilis,'savunma_son',d.savunma_son,
 'savunma_geldi',d.savunma_geldi,'durum',d.durum,'hakim',oyun.kad(d.hakim),
 'karar',d.karar,'tazminat_talep',d.tazminat_talep,'tazminat_tutar',d.tazminat_tutar,'tazminat_odenen',d.tazminat_odenen,'gerekce',d.gerekce,'karar_at',d.karar_at,'ceza_bitis',d.ceza_bitis,
 'af_at',d.af_at,'af_veren',oyun.kad(d.af_veren),'af_gerekce',d.af_gerekce,'bozma_iade',d.bozma_iade,'ilk_karar',d.ilk_karar,'kesin',d.kesin,
 'davalimiyim',(coalesce(d.davali=p.id,false) or oyun.adliye_kurum_yetkili(d.davali_kurum_tur,d.davali_kurum_id,p.id)),'davacimiyim',d.davaci=p.id,'temsil_iznim',exists(select 1 from oyun.adliye_temsil a where a.dava_id=d.id and a.yetki_veren=p.id and a.aktif),
 'sozcu_savunabilir',(
  (d.davali_parti is not null and exists(select 1 from oyun.parti_sozcu s join oyun.profiller pr on pr.id=p.id and pr.parti_id=s.parti_id where s.parti_id=d.davali_parti and s.user_id=p.id))
  or (d.davali is not null and exists(select 1 from oyun.adliye_temsil t join oyun.parti_sozcu s on s.user_id=p.id join oyun.profiller pr on pr.id=d.davali and pr.parti_id=s.parti_id where t.dava_id=d.id and t.aktif and t.yetki_veren=d.davali))
 )
 ) order by d.id desc)
 from (select * from oyun.adliye_davalar order by id desc limit 100) d
 left join oyun.partiler dp on dp.id=d.davaci_parti
 left join oyun.partiler hp on hp.id=d.davali_parti),'[]'::jsonb),
 'aflar',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'cb',oyun.kad(a.cb),'tur',a.tur,'dava_id',a.dava_id,'gerekce',a.gerekce,'affedilen',a.affedilen,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_aflar order by id desc limit 20) a),'[]'::jsonb),
 'atamalar',coalesce((select jsonb_agg(jsonb_build_object('yapan',oyun.kad(a.yapan),'eski',oyun.kad(a.eski),'yeni',oyun.kad(a.yeni),'gerekce',a.gerekce,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_atama_kayit order by id desc limit 15) a),'[]'::jsonb)
 );
end $function$
;
