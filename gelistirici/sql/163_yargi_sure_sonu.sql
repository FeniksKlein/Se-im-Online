-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 163) YARGIDA SÜRE SONU: ÜYELER OY VERMESE DE HER DOSYA MAKUL SÜREDE KAPANIR
--  İstek (Ercan, 03.11.2026): Mahkemedeki ve üst mahkemedeki davalar belli bir süre sonunda üyeler oy
--  vermezse en makul sürede, en makul şekilde sonuçlansın.
--
--  Canlıda bulunanlar:
--   * İstinaf ek süresinde yerine geçen jüri üyesine "kalan süre" eski (geçmiş) bitişten hesaplanıp
--     yanlış yazılıyordu (ek sürenin kendisi istinaf_sure_24s tetikleyicisiyle zaten 48 saate uzuyor).
--   * Adliye #31: karar yazılmış ama istinaf süresi tanımsız kalmış; dosya hiç kesinleşmiyordu.
--   * İlk derecede heyetin üçü de farklı oy verse bile karar için 72 + 24 saat bekleniyordu.
--   * Anayasa Mahkemesi süresinde çoğunluk çıkmazsa başvuru "düştü" sayılıyor, verilen oylar
--     yok sayılıyordu. Mahkemede hiç üye yoksa AYM ve kapatma davaları sonsuza dek bekliyordu.
--   * İcra itirazının hiçbir süresi yoktu.
--
--  Yeni kurallar:
--   1) İlk derece (Yüksek Mahkeme heyeti): karar süresi savunmadan sonra 48 saat (önceden 72).
--      Heyetin tamamı oy verdiyse ve çoğunluk oluşmadıysa son oydan 2 saat sonra (görüş değiştirme
--      payı) beklemeden CMK m.229/3 ile karar çıkar. Süre dolduğunda oy vermeyen üye varsa bir kez
--      24 saat ek süre; o da dolunca verilen oylarla CMK m.229/3 (oy vermeyen sanık lehine sayılır);
--      hiç oy yoksa dava düşer, harç iade.
--   2) Karar verilmiş ama istinaf süresi tanımsız kalmış dosyada istinaf süresi o an başlar (24 saat),
--      taraflara bildirilir; itiraz yoksa karar kesinleşir.
--   3) İstinaf jürisi (değişmedi): 24 saatte çoğunluk yoksa oy vermeyenler değişir, 24 saat ek süre;
--      sonra verilen oylarla karar (bozma için en az 2 oy ve bozma çoğunluğu). Yeni üyeye doğru kalan süre yazılır.
--   4) Anayasa Mahkemesi: süre dolduğunda oy vermeyen üye varsa bir kez 24 saat ek süre ve hatırlatma;
--      sonra verilen oylarla karar: iptal için heyetin salt çoğunluğu gerekir, sağlanamazsa başvuru
--      REDDEDİLİR (kanun yürürlükte). Son 12 saatte oy vermeyen üyeye hatırlatma.
--   5) Mahkemede hiç üye yoksa: AYM başvurusu ve kapatma davası 7 gün sonra düşer (ilk derecedeki
--      7 gün kuralıyla aynı).
--   6) İcra itirazı: 72 saatte karar çıkmazsa verilen oylara bakılır; itirazı haklı bulan oy çokluğu
--      varsa takip iptal, yoksa itiraz reddedilmiş sayılır ve takip haciz aşamasına geçer
--      (seçim itirazındaki 72 saat kuralıyla aynı).
--  Oyuncu verisini dönüştürmez; iki kez çalışabilir.
-- =====================================================================

alter table oyun.aym_basvuru add column if not exists karar_uzatildi boolean not null default false;
alter table oyun.aym_basvuru add column if not exists hatirlatildi boolean not null default false;

-- Karar süresi 72 → 48 saat (yalnız bir kez; yönetici sonradan değiştirirse güncelleme ezmez).
do $$
begin
  insert into oyun.tek_seferlik(anahtar) values ('yargi_sure_sonu_163_karar_saat') on conflict do nothing;
  if found then
    update oyun.mahkeme_ayar set karar_saat = 48 where karar_saat = 72;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- İlk derece: süre doldu ya da heyetin tamamı oy verdi ama çoğunluk yok
-- ---------------------------------------------------------------------
create or replace function oyun.adliye_sure_doldu(p_dava bigint, t timestamptz) returns text
language plpgsql set search_path to '' as $$
declare d oyun.adliye_davalar; heyet uuid[]; nh int; gerek int; oylar int; r record; kum int:=0; sec record; v_hakim uuid; v_ger text; ozet text; bitis timestamptz; bulundu boolean:=false; tum boolean;
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then return null; end if;
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
end $$;

-- ---------------------------------------------------------------------
-- İstinaf jürisi: ek süre gerçekten 24 saat verilir
-- ---------------------------------------------------------------------
create or replace function oyun.adliye_istinaf_sonuc(p_dava bigint, t timestamptz) returns void
language plpgsql set search_path to '' as $$
declare i oyun.adliye_istinaf; onay int; boz int; toplam int; d oyun.adliye_davalar; r record; degisen int := 0; mesaj text; yeni_bit timestamptz;
begin
 select * into i from oyun.adliye_istinaf where dava_id = p_dava for update;
 if i.dava_id is null or i.durum <> 'acik' then return; end if;
 select count(*) filter (where oy = 'onay'), count(*) filter (where oy = 'boz'), count(*) into onay, boz, toplam from oyun.adliye_juri where dava_id = p_dava;
 if not (onay >= oyun.cogunluk(toplam) or boz >= oyun.cogunluk(toplam)) then
  if t < i.bit then return; end if;
  if not i.uzatildi then
   -- Önce bitiş saati uzar (istinaf_sure_24s tetikleyicisi ek sürede bitişi başvurudan 48 saate çeker);
   -- böylece yerine geçen üyelere giden bildirim doğru kalan süreyi yazar.
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
 if boz > onay and boz + onay >= 2 then
  update oyun.adliye_istinaf set durum = 'bozuldu' where dava_id = p_dava;
  update oyun.adliye_davalar set karar = case when d.karar = 'beraat' then 'uyari' else 'beraat' end, ceza_bitis = null, tazminat_tutar = null where id = p_dava;
  if d.davali is not null then perform oyun.adliye_susturma_yenile(d.davali, t); end if;
  perform oyun.adliye_duyur((select user_id from oyun.adliye_juri where dava_id = p_dava and oy = 'boz' order by zaman limit 1),
    format('İstinaf jürisi Adliye #%s kararını BOZDU (%s boz / %s onay). #Adliye', p_dava, boz, onay), array['adliye'], t);
 else
  update oyun.adliye_istinaf set durum = 'onaylandi' where dava_id = p_dava;
  mesaj := case
   when onay + boz = 0 then format('Adliye #%s istinaf jürisi ek süre dahil oy kullanmadı; bozma için çoğunluk oluşmadığından ilk derece kararı onandı.', p_dava)
   when onay + boz = 1 then format('Adliye #%s istinafında ek süre dahil yalnız 1 üye oy kullandı; tek oyla karar bozulamayacağından ilk derece kararı onandı.', p_dava)
   when onay = boz then format('Adliye #%s istinafında oylar eşit (%s/%s); bozma için çoğunluk oluşmadığından ilk derece kararı onandı.', p_dava, onay, boz)
   else format('İstinaf jürisi Adliye #%s kararını onayladı (%s onay / %s boz).', p_dava, onay, boz) end;
  perform oyun.olay('adliye', mesaj, null, null, t);
 end if;
 perform oyun.adliye_kesinlestir(p_dava, t);
end $$;

-- ---------------------------------------------------------------------
-- Anayasa Mahkemesi: süre sonunda verilen oylarla karar
-- ---------------------------------------------------------------------
create or replace function oyun.aym_sure_doldu(p_id bigint, t timestamptz) returns text
language plpgsql set search_path to '' as $$
declare b oyun.aym_basvuru; heyet uuid[] := oyun.mahkeme_uyeleri(); nh int; ip int; rt int; k oyun.kanunlar; v_hakim uuid; v_ger text;
begin
  select * into b from oyun.aym_basvuru where id = p_id for update;
  if b.id is null or b.durum <> 'acik' then return null; end if;
  nh := cardinality(heyet);
  select * into k from oyun.kanunlar where id = b.kanun_id;
  if nh = 0 then
    if t >= b.bas + interval '7 days' then
      v_ger := 'Anayasa Mahkemesinde 7 gün boyunca görevde üye bulunmadığından başvuru incelenemedi ve düştü. Kanun yürürlükte kalır.';
      update oyun.aym_basvuru set durum = 'dustu', karar_at = t, karar_gerekce = v_ger where id = p_id;
      perform oyun.bildir(x, format('Anayasa Mahkemesi: "%s" başvurusu, mahkemede 7 gün üye bulunmadığı için düştü; kanun yürürlükte.', k.baslik), t)
        from unnest(array[b.basvuran, k.teklif_eden]) x where x is not null;
      return 'dustu';
    end if;
    update oyun.aym_basvuru set karar_son = t + make_interval(hours => (select karar_saat from oyun.mahkeme_ayar)) where id = p_id;
    return 'heyet_yok';
  end if;
  if oyun.aym_oy_say(p_id, t) then return 'karar'; end if;
  select count(*) filter (where o.karar = 'iptal'), count(*) filter (where o.karar = 'ret') into ip, rt
    from oyun.aym_oy o where o.basvuru_id = p_id and o.uye = any(heyet);
  if not b.karar_uzatildi and ip + rt < nh then
    update oyun.aym_basvuru set karar_son = t + interval '24 hours', karar_uzatildi = true where id = p_id;
    perform oyun.bildir(u, format('Anayasa Mahkemesi: "%s" başvurusunda karar süresi doldu, çoğunluk oluşmadı. 24 saat ek süre verildi; ek süre de dolarsa verilen oylarla karar çıkacak (iptal için salt çoğunluk gerekir).', k.baslik), t)
      from unnest(heyet) u where not exists (select 1 from oyun.aym_oy o where o.basvuru_id = p_id and o.uye = u);
    perform oyun.olay('adliye', format('Anayasa Mahkemesi "%s" başvurusunu süresinde karara bağlayamadı; 24 saat ek süre verildi.', left(k.baslik, 100)), null, null, t);
    return 'uzatildi';
  end if;
  -- İptal için üye tamsayısının salt çoğunluğu gerekir; sağlanamazsa başvuru reddedilir.
  select o.uye, o.gerekce into v_hakim, v_ger from oyun.aym_oy o where o.basvuru_id = p_id and o.karar = 'ret' and o.uye = any(heyet) order by o.zaman limit 1;
  v_ger := format('Karar süresi%s doldu. İptal için %s üyeden en az %s üyenin iptal oyu gerekir. Oylar: %s iptal, %s ret, %s üye oy kullanmadı. Gerekli çoğunluk sağlanamadığından başvuru reddedildi, kanun yürürlükte kalır.',
      case when b.karar_uzatildi then ' (ek süre dahil)' else '' end, nh, oyun.cogunluk(nh), ip, rt, nh - ip - rt)
    || case when v_ger is not null then E'\n\n' || v_ger else '' end;
  update oyun.aym_basvuru set durum = 'ret', karar_at = t, hakim = v_hakim, karar_gerekce = v_ger where id = p_id;
  perform oyun.adliye_duyur(v_hakim, format('Anayasa Mahkemesi "%s" kanunu hakkındaki başvuruyu reddetti (süre doldu; %s iptal / %s ret / %s oy kullanmadı). Kanun yürürlükte. #AnayasaMahkemesi',
     left(k.baslik, 100), ip, rt, nh - ip - rt), array['anayasamahkemesi','adliye'], t);
  perform oyun.bildir(x, format('Anayasa Mahkemesi "%s" başvurusunu reddetti: iptal için gerekli çoğunluk süresinde sağlanamadı.', k.baslik), t)
    from unnest(array[b.basvuran, k.teklif_eden]) x where x is not null;
  return 'ret';
end $$;

-- ---------------------------------------------------------------------
-- Yüksek Mahkeme zamanlayıcısı
-- ---------------------------------------------------------------------
create or replace function oyun.mahkeme_tick() returns integer
language plpgsql set search_path to '' as $$
declare t timestamptz := oyun.simdi(); r record; dv oyun.adliye_davalar; n int := 0; a oyun.mahkeme_ayar; eng text; ab oyun.aym_basvuru;
begin
  if not pg_try_advisory_xact_lock(424245) then return 0; end if;
  select * into a from oyun.mahkeme_ayar;
  for r in select * from oyun.mahkeme_uye where user_id is not null and gorev_bit <= t loop
    perform oyun.mahkeme_indir(r.sira, null, 'Görev süresi doldu.', t); n := n + 1;
  end loop;
  for r in
    select u.sira, o.aday, count(*) c from oyun.mahkeme_uye u join oyun.mahkeme_meclis_oy o on o.sira = u.sira
     join oyun.makamlar m on m.user_id = o.vekil and m.tur = 'mv' and m.bit is null
     where u.user_id is null and u.kaynak = 'meclis' and u.bos_since <= t - interval '72 hours'
       AND NOT (EXISTS (SELECT 1 FROM oyun.secimler g WHERE g.tur='mv'
           AND (g.oy_bas AT TIME ZONE 'Europe/Istanbul')::date=date '2026-10-12')
         AND NOT EXISTS (SELECT 1 FROM oyun.mahkeme_toplu_secim s WHERE s.durum='bitti'))
     group by u.sira, o.aday having count(*) >= 3 order by u.sira, count(*) desc, min(o.zaman)
  loop
    if exists (select 1 from oyun.mahkeme_uye where sira = r.sira and user_id is null) and oyun.yargic_uygunluk(r.aday) is null then
      perform oyun.mahkeme_oturt(r.sira, r.aday, null, t); n := n + 1;
    end if;
  end loop;
  -- Dokunulmazlık: görevdeki Cumhurbaşkanı (ve yasa yürürlükteyse milletvekili) hakkındaki açık ceza davaları düşer
  for r in select d.id, d.davali, d.tur from oyun.adliye_davalar d where d.durum = 'acik' and d.davali is not null loop
    eng := oyun.dokunulmazlik_engel(r.davali, r.tur);
    if eng is not null then perform oyun.adliye_dokunulmazlik_dusur(r.id, eng, t); n := n + 1; end if;
  end loop;
  -- Karar süresi doldu ya da heyetin tamamı oy verdi (son oydan 2 saat geçti) ama çoğunluk yok:
  -- hiç üye yoksa süre işlemez; oy vermeyen varsa bir kez 24 saat ek süre; sonra CMK m.229/3 ile karar
  for dv in select * from oyun.adliye_davalar d where d.durum = 'acik' loop
    if (dv.karar_son is not null and dv.karar_son <= t)
       or (cardinality(oyun.dava_heyeti(dv)) > 0
           and (select count(*) from oyun.adliye_karar_oy o where o.dava_id = dv.id and o.uye = any(oyun.dava_heyeti(dv))) >= cardinality(oyun.dava_heyeti(dv))
           and (select max(o.zaman) from oyun.adliye_karar_oy o where o.dava_id = dv.id) <= t - interval '2 hours') then
      if cardinality(oyun.mahkeme_uyeleri()) = 0 then
        update oyun.adliye_davalar set karar_son = t + make_interval(hours => a.karar_saat) where id = dv.id;
      else
        perform oyun.adliye_sure_doldu(dv.id, t); n := n + 1;
      end if;
    end if;
  end loop;
  -- Karar süresinin son 12 saati: oy kullanmayan heyet üyelerine hatırlatma
  for dv in select * from oyun.adliye_davalar d where d.durum = 'acik' and not d.karar_hatirlatildi and d.karar_son is not null
              and d.karar_son - interval '12 hours' <= t and (d.savunma_geldi or d.savunma_son <= t) loop
    perform oyun.bildir(u, format('Yüksek Mahkeme hatırlatması: Adliye #%s için karar süresinin dolmasına 12 saatten az kaldı; gerekçeli oyunu kullan.', dv.id), t)
      from unnest(oyun.dava_heyeti(dv)) u where not exists (select 1 from oyun.adliye_karar_oy o where o.dava_id = dv.id and o.uye = u);
    update oyun.adliye_davalar set karar_hatirlatildi = true where id = dv.id;
  end loop;
  -- İstinaf jürisi süresi (çoğunluk yoksa bir kez yedeklerle ek tur)
  for r in select dava_id from oyun.adliye_istinaf where durum = 'acik' and bit <= t loop
    perform oyun.adliye_istinaf_sonuc(r.dava_id, t); n := n + 1;
  end loop;
  -- İstinaf oylamasının son 8 saati: oy kullanmayan jüri üyelerine hatırlatma
  for r in select dava_id from oyun.adliye_istinaf where durum = 'acik' and not hatirlatildi and bit - interval '8 hours' <= t loop
    perform oyun.bildir(j.user_id, format('Hatırlatma: Adliye #%s istinaf oylamasının bitmesine 8 saatten az kaldı. Kararı onayla ya da boz.', r.dava_id), t)
      from oyun.adliye_juri j where j.dava_id = r.dava_id and j.oy is null;
    update oyun.adliye_istinaf set hatirlatildi = true where dava_id = r.dava_id;
  end loop;
  -- Karar verilmiş ama istinaf süresi tanımsız kalmış dosya: istinaf süresi şimdi başlar, taraflara bildirilir
  for dv in select * from oyun.adliye_davalar d where d.durum = 'karar' and not coalesce(d.kesin, false) and d.istinaf_son is null
              and not exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id) loop
    update oyun.adliye_davalar set istinaf_son = t + make_interval(hours => a.istinaf_saat) where id = dv.id;
    perform oyun.bildir(x.id, format('Adliye #%s kararı: %s. İstinaf süresi şimdi başladı; %s saat içinde itiraz edilmezse karar kesinleşir.', dv.id, dv.karar, a.istinaf_saat), t)
      from (select dv.davaci id union select dv.davali where dv.davali is not null) x;
    perform oyun.olay('adliye', format('Adliye #%s kararı için %s saatlik istinaf süresi başladı.', dv.id, a.istinaf_saat), null, null, t);
    n := n + 1;
  end loop;
  for r in select d.id from oyun.adliye_davalar d where d.durum = 'karar' and not coalesce(d.kesin, false)
              and ((d.istinaf_son <= t and not exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id))
                   or exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id and i.durum <> 'acik')) loop
    perform oyun.adliye_kesinlestir(r.id, t); n := n + 1;
  end loop;
  for r in select id from oyun.mahkeme_azil where durum = 'acik' and bit <= t loop perform oyun.mahkeme_azil_say(r.id, t); end loop;
  -- Anayasa Mahkemesi: son 12 saatte hatırlatma; süre dolunca ek süre ya da verilen oylarla karar
  for ab in select * from oyun.aym_basvuru where durum = 'acik' and not hatirlatildi and karar_son - interval '12 hours' <= t loop
    perform oyun.bildir(u, format('Anayasa Mahkemesi hatırlatması: "%s" kanunu başvurusunda karar süresinin dolmasına 12 saatten az kaldı; gerekçeli oyunu kullan.',
        (select k.baslik from oyun.kanunlar k where k.id = ab.kanun_id)), t)
      from unnest(oyun.mahkeme_uyeleri()) u where not exists (select 1 from oyun.aym_oy o where o.basvuru_id = ab.id and o.uye = u);
    update oyun.aym_basvuru set hatirlatildi = true where id = ab.id;
  end loop;
  for r in select id from oyun.aym_basvuru where durum = 'acik' and karar_son <= t loop
    perform oyun.aym_sure_doldu(r.id, t); n := n + 1;
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------------
-- Parti kapatma davası: mahkemede 7 gün üye yoksa dava düşer
-- ---------------------------------------------------------------------
create or replace function oyun.pkd_tick(t timestamptz) returns void
language plpgsql set search_path to '' as $$
declare r record; n int; pa oyun.partiler;
begin
  for r in select * from oyun.pkd_dava where durum = 'imza' and t >= imza_son loop
    select count(*) into n from oyun.pkd_imza where dava_id = r.id;
    update oyun.pkd_dava set durum = 'dustu', karar_at = t, karar_gerekce = format('Yeterli imza toplanamadı (%s/%s).', n, r.imza_gerek) where id = r.id;
    perform oyun.bildir(r.acan, 'Başlattığın kapatma davası yeterli imza toplanamadığı için düştü.', t);
  end loop;
  for r in select * from oyun.pkd_dava where durum = 'savunma' and t >= savunma_son loop
    perform oyun.pkd_yargilamaya_al(r.id, t);
  end loop;
  for r in select * from oyun.pkd_dava where durum = 'yargilama' and t >= karar_son loop
    if cardinality(oyun.mahkeme_uyeleri()) = 0 then
      if t >= coalesce(r.savunma_son, r.bas) + interval '7 days' then
        update oyun.pkd_dava set durum = 'dustu', karar_at = t, karar_gerekce = 'Anayasa Mahkemesinde 7 gün boyunca görevde üye bulunmadığından dava karara bağlanamadı ve düştü.' where id = r.id;
        select * into pa from oyun.partiler where id = r.parti_id;
        perform oyun.bildir(x, format('%s hakkındaki kapatma davası, mahkemede 7 gün üye bulunmadığı için düştü.', pa.kisa), t)
          from unnest(array[r.acan, pa.gb]) x where x is not null;
      else
        update oyun.pkd_dava set karar_son = t + interval '24 hours' where id = r.id;   -- mahkeme boşsa süre işlemez
      end if;
    else
      perform oyun.pkd_oy_say(r.id, t, true);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Yargı düzeni zamanlayıcısı (+ icra itirazı 72 saat)
-- ---------------------------------------------------------------------
create or replace function oyun.yargi_tick() returns jsonb
language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi(); r record; dv oyun.adliye_davalar; a int := 0; b int := 0; c int := 0; e int := 0; gb uuid; rn int; kn int; kabul boolean; g text;
begin
  if not pg_try_advisory_xact_lock(hashtext('yargi_tick')) then return null; end if;
  for r in select j.dava_id, j.user_id from oyun.adliye_istinaf i join oyun.adliye_juri j on j.dava_id = i.dava_id join oyun.profiller p on p.id = j.user_id
           where i.durum = 'acik' and j.oy is null and t >= coalesce(j.atama, i.bas) + interval '8 hours' and t < i.bit - interval '2 hours'
             and (coalesce(p.son_gorulme, '-infinity'::timestamptz) < coalesce(j.atama, i.bas) or p.yasakli) loop
    if oyun.juri_degistir(r.dava_id, r.user_id, t, 'atandıktan sonra 8 saat oyuna girmediğin için görevini yapamadın') is not null then a := a + 1; end if;
  end loop;
  for dv in select * from oyun.adliye_davalar d where d.durum = 'acik' and d.acilis < t - interval '7 days' and cardinality(oyun.dava_heyeti(d)) = 0 loop
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
end $$;

revoke all on function oyun.aym_sure_doldu(bigint, timestamptz) from public, anon, authenticated;
