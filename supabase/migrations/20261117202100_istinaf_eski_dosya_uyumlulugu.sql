-- Istinaf 2.0: mevcut dosyalarin kurulu heyetini / oylarini koruyan surumlu uyumluluk paketi.
-- Bu migration, 20261117202000_istinaf_meslek_hakimligi.sql sonrasi uygulanir.
DO $guard$
BEGIN
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='adliye_istinaf') IS DISTINCT FROM 'eb28e8d55d0f0830d60f254eb7fd6f2d'
 THEN RAISE EXCEPTION 'Sürüm çatışması: public.adliye_istinaf değişmiş.'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='adliye_juri_oy') IS DISTINCT FROM '704032b63c5225a1374670a55bec74a8'
 THEN RAISE EXCEPTION 'Sürüm çatışması: public.adliye_juri_oy değişmiş.'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='oyun' AND p.proname='adliye_istinaf_sonuc') IS DISTINCT FROM '6389def0a5e1f3a0490961eae5527559'
 THEN RAISE EXCEPTION 'Sürüm çatışması: oyun.adliye_istinaf_sonuc değişmiş.'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='oyun' AND p.proname='istinaf_sure_24s') IS DISTINCT FROM '9619e74a1c5847cc4aabe16f26b7e215'
 THEN RAISE EXCEPTION 'Sürüm çatışması: oyun.istinaf_sure_24s değişmiş.'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='oyun' AND p.proname='yargi_tick') IS DISTINCT FROM '92ee20a6ed2ec5f3dcbaddc5edc64b64'
 THEN RAISE EXCEPTION 'Sürüm çatışması: oyun.yargi_tick değişmiş.'; END IF;
END $guard$;

-- Degistirilen islev: public.adliye_istinaf
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
 n:=oyun.istinaf_hakim_dosya_ac(d.id,t);
 if n=0 then
  -- exception tüm işlemi geri alır (başvuru kaydı da silinir)
  raise exception 'Şu anda tarafsız jüri oluşturulamadı; daha sonra tekrar dene.';
 end if;
 update oyun.adliye_davalar set istinaf_son=(select i.bit from oyun.adliye_istinaf i where i.dava_id=d.id) where id=d.id;
 perform oyun.olay('adliye',format('Adliye #%s istinafa taşındı; dosya bağımsız, gönüllü istinaf hâkimlerinin görev kabulünü bekliyor.',d.id),null,null,t);
 return jsonb_build_object('tamam',true,'juri',n,'kisisel',kisisel and not vekil);
end $function$;

-- Degistirilen islev: public.adliye_juri_oy
CREATE OR REPLACE FUNCTION public.adliye_juri_oy(p_dava bigint, p_oy text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.adliye_istinaf; ek numeric := 0;
begin
  if p_oy not in ('onay', 'boz') then raise exception 'Onayla ya da boz.'; end if;
  
  -- Yeni kadro dosyalari: yalnız açıkça kabul etmiş, heyet tamamlanmış hâkim oy kullanabilir.
  if exists(select 1 from oyun.istinaf_hakim_dosya where dava_id=p_dava) then
   if not exists(select 1 from oyun.istinaf_hakim_dosya h where h.dava_id=p_dava and h.durum='karar'
       and h.karar_son>t) then raise exception 'Heyet tamamlanmadı veya karar süresi sona erdi.'; end if;
   if not exists(select 1 from oyun.istinaf_hakim_davet h
      where h.dava_id=p_dava and h.user_id=p.id and h.durum='kabul') then
      raise exception 'Bu davada kabul ettiğin hâkimlik görevi bulunamadı.'; end if;
   if char_length(btrim(coalesce(p_gerekce,'')))<40 then
      raise exception 'İstinaf hâkimi kararına en az 40 karakterlik gerekçe yazmalıdır.'; end if;
  end if;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  if i.dava_id is null or i.durum <> 'acik' or t >= i.bit then raise exception 'Bu istinaf oylaması açık değil.'; end if;
  update oyun.adliye_juri set oy = p_oy, gerekce = nullif(left(trim(coalesce(p_gerekce, '')), 800), ''), zaman = t
   where dava_id = p_dava and user_id = p.id and oy is null;
  if not found then raise exception 'Bu davanın jürisinde değilsin ya da oyunu zaten verdin.'; end if;
  ek := oyun.kidem_ekle(p.id, 'juri_oy');
  perform oyun.adliye_istinaf_sonuc(p_dava, t);
  return jsonb_build_object('tamam', true, 'kidem', ek);
end $function$;

-- Degistirilen islev: oyun.adliye_istinaf_sonuc
CREATE OR REPLACE FUNCTION oyun.adliye_istinaf_sonuc(p_dava bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare i oyun.adliye_istinaf; onay int; boz int; toplam int; d oyun.adliye_davalar; r record; degisen int := 0; mesaj text; yeni_bit timestamptz;
  erken boolean; gider numeric; kayb text; alinan numeric := 0; konu text;
begin
 -- Yeni model: iki aynı yönde oy olmadan hiçbir otomatik onama veya bozma yok.
 if exists(select 1 from oyun.istinaf_hakim_dosya where dava_id=p_dava)
 AND NOT exists(select 1 from oyun.adliye_juri where dava_id=p_dava
   group by dava_id having count(*) filter(where oy='onay')>=2
                        or count(*) filter(where oy='boz')>=2) THEN
   return;
 END IF;
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
end $function$;

-- Degistirilen islev: oyun.istinaf_sure_24s
CREATE OR REPLACE FUNCTION oyun.istinaf_sure_24s()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.bas is null then new.bas:=oyun.simdi(); end if;
 IF TG_OP='UPDATE' AND exists(select 1 from oyun.istinaf_hakim_dosya where dava_id=NEW.dava_id) then
    return NEW; -- Yeni dosyanın 6+4 saatlik süresini koru.
 end if;
 new.bit:=new.bas + case when coalesce(new.uzatildi,false) then interval '48 hours' else interval '24 hours' end;
 return new;
end $function$;

-- Degistirilen islev: oyun.yargi_tick
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
           where i.durum = 'acik' and not exists(select 1 from oyun.istinaf_hakim_dosya h where h.dava_id=i.dava_id) and j.oy is null and t >= coalesce(j.atama, i.bas) + interval '8 hours' and t < i.bit - interval '2 hours'
             and (coalesce(p.son_gorulme, '-infinity'::timestamptz) < coalesce(j.atama, i.bas) or p.yasakli) loop
    if oyun.juri_degistir(r.dava_id, r.user_id, t, 'atandıktan sonra 8 saat oyuna girmediğin için görevini yapamadın') is not null then a := a + 1; end if;
  end loop;
  for r in select j.dava_id, j.user_id from oyun.adliye_istinaf i join oyun.adliye_juri j on j.dava_id = i.dava_id
           where i.durum = 'acik' and not exists(select 1 from oyun.istinaf_hakim_dosya h where h.dava_id=i.dava_id) and j.oy is null and t >= coalesce(j.atama, i.bas) + interval '12 hours' and t < i.bit - interval '2 hours' loop
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
end $function$;

