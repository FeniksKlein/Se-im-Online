-- 20.11.2026 (3) · İSTİNAF TEMİNATI: gider başvururken peşin alınır (Ercan'ın kararı)
-- Eski düzen (17.11): başvuru reddedilince 50.000 ₺ yargılama gideri kaybedenin CÜZDANINDA NE VARSA ondan alınıyordu.
-- Açık: parasını bankada tutan (ya da cüzdanını boşaltan) oyuncu gideri ödemeden her kararı istinafa taşıyabiliyordu.
-- Yeni kural:
--   1) Tutar aynı (oyun.istinaf_gider: 50.000 ₺; tazminat davasında %10, en az 50.000, en çok 150.000 ₺).
--      Başvuru anında TEMİNAT olarak peşin alınır; yeterli para yoksa başvuru kabul edilmez.
--   2) Kimden: kararı kaybeden taraftan. Kişi → cüzdanı; parti → parti kasası; bakanlık adına açılmış dava → bakanlık
--      kasası; kurum davalı (şirket, dernek, belediye…) → başvuruyu yapan kurum yetkilisinin cüzdanı.
--   3) İade: Daire kararı bozarsa VE Daire çoğunlukla karar veremezse (hiç oy yok, tek oy, eşitlik) teminat geri verilir.
--      Oyuncu, üyeler oy kullanmadı diye para kaybetmez.
--   4) Gider: Daire başvuruyu çoğunlukla (en az 2 onama oyu) reddederse teminat yargılama gideri olarak kalır
--      (CMK m.325, HMK m.326).
--   5) Daire kurulamazsa başvuru hiç yapılmamış sayılır; teminat da alınmaz (aynı işlem geri alınır).
-- İade "iade" türüyle yazılır: MASAK ani servet sayımına ve icra gelir haczine girmez.
-- Oyuncu verisi değişmez (açık istinaf yok). Tekrar çalıştırmak güvenlidir.

alter table oyun.adliye_istinaf add column if not exists teminat numeric not null default 0;
alter table oyun.adliye_istinaf add column if not exists teminat_user uuid;
alter table oyun.adliye_istinaf add column if not exists teminat_parti bigint;
alter table oyun.adliye_istinaf add column if not exists teminat_bakanlik text;
alter table oyun.adliye_istinaf add column if not exists teminat_durum text;

-- ---------- Teminatın kapanması: 'iade' ya da 'gider' ----------
create or replace function oyun.istinaf_teminat_kapat(p_dava bigint, p_sonuc text, t timestamp with time zone)
 returns numeric
 language plpgsql
 set search_path to ''
as $function$
declare i oyun.adliye_istinaf; birim numeric; v_gb uuid;
begin
  select * into i from oyun.adliye_istinaf where dava_id = p_dava for update;
  if i.dava_id is null or coalesce(i.teminat, 0) <= 0 or i.teminat_durum is distinct from 'yatirildi' then return 0; end if;
  if p_sonuc = 'iade' then
    if i.teminat_parti is not null then
      update oyun.partiler set kasa = kasa + i.teminat where id = i.teminat_parti returning gb into v_gb;
      if v_gb is not null then
        perform oyun.bildir(v_gb, format('Adliye #%s: %s ₺ istinaf teminatı parti kasasına iade edildi.', p_dava, oyun.tl(i.teminat)), t);
      end if;
    elsif i.teminat_bakanlik is not null then
      birim := coalesce(oyun.pazar_tl_milyar(), 1000000);
      update oyun.bakanlik_kasa k set kasa = k.kasa + i.teminat / birim where k.kod = i.teminat_bakanlik;
    elsif i.teminat_user is not null then
      perform oyun.para_islem(i.teminat_user, i.teminat, 'iade', format('Adliye #%s istinaf teminatı iadesi', p_dava), t);
      perform oyun.bildir(i.teminat_user, format('Adliye #%s: %s ₺ istinaf teminatın cüzdanına iade edildi.', p_dava, oyun.tl(i.teminat)), t);
    end if;
    update oyun.adliye_istinaf set teminat_durum = 'iade' where dava_id = p_dava;
  else
    -- gider: taraflara giden karar bildirimi tutarı zaten yazar; ayrıca bildirim gönderilmez
    update oyun.adliye_istinaf set teminat_durum = 'gider' where dava_id = p_dava;
  end if;
  return i.teminat;
end $function$;

-- ---------- Başvuru: teminat peşin ----------
create or replace function public.adliye_istinaf(p_dava bigint, p_gerekce text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; t timestamptz:=oyun.simdi(); kayb text; kisisel boolean; vekil boolean:=oyun.vekil_islem_mi(); n int;
        v_gider numeric; v_user uuid; v_parti bigint; v_bak text; v_var numeric; birim numeric; v_yer text;
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

 -- İstinaf teminatı: kararı kaybeden taraftan, başvuru anında peşin
 v_gider:=coalesce(oyun.istinaf_gider(d),0);
 if kayb='davali' then
  if d.davali is not null then v_user:=d.davali;
  elsif d.davali_parti is not null then v_parti:=d.davali_parti;
  else v_user:=p.id; end if;                       -- kurum davalı: başvuran kurum yetkilisi
 else
  if d.davaci_bakanlik is not null then v_bak:=d.davaci_bakanlik;
  elsif d.davaci_parti is not null then v_parti:=d.davaci_parti;
  else v_user:=d.davaci; end if;
 end if;
 if v_gider>0 then
  if v_parti is not null then
   select pa.kasa into v_var from oyun.partiler pa where pa.id=v_parti for update;
   if coalesce(v_var,0)<v_gider then
    raise exception 'İstinaf başvurusu için parti kasasında % ₺ teminat bulunmalı (kasada % ₺ var). Teminat, karar bozulursa iade edilir.', oyun.tl(v_gider), oyun.tl(coalesce(v_var,0));
   end if;
   update oyun.partiler set kasa=kasa-v_gider where id=v_parti;
   v_yer:='parti kasasından';
  elsif v_bak is not null then
   birim:=coalesce(oyun.pazar_tl_milyar(),1000000);
   select k.kasa into v_var from oyun.bakanlik_kasa k where k.kod=v_bak for update;
   if coalesce(v_var,0)*birim<v_gider then
    raise exception 'İstinaf başvurusu için bakanlık kasasında % ₺ teminat bulunmalı. Teminat, karar bozulursa iade edilir.', oyun.tl(v_gider);
   end if;
   update oyun.bakanlik_kasa k set kasa=k.kasa-v_gider/birim where k.kod=v_bak;
   v_yer:='bakanlık kasasından';
  else
   perform oyun.cuzdanim(v_user);
   select c.para into v_var from oyun.cuzdan c where c.user_id=v_user for update;
   if coalesce(v_var,0)<v_gider then
    raise exception 'İstinaf başvurusu için cüzdanda % ₺ teminat bulunmalı (cüzdanda % ₺ var). Para bankadaysa önce cüzdana çekilmeli. Teminat, karar bozulursa iade edilir.', oyun.tl(v_gider), oyun.tl(coalesce(v_var,0));
   end if;
   perform oyun.para_islem(v_user,-v_gider,'adliye',format('Adliye #%s istinaf teminatı',d.id),t);
   v_yer:='cüzdandan';
  end if;
 end if;

 insert into oyun.adliye_istinaf(dava_id,basvuran,gerekce,bas,teminat,teminat_user,teminat_parti,teminat_bakanlik,teminat_durum)
 values(d.id,p.id,trim(p_gerekce),t,v_gider,v_user,v_parti,v_bak,case when v_gider>0 then 'yatirildi' end);
 perform oyun.bildir(x.id, format('Adliye #%s istinaf başvurusu alındı. %s ₺ istinaf teminatı %s tahsil edildi. İstinaf Dairesi kararı bozarsa ya da çoğunlukla karar veremezse teminat iade edilir; başvuruyu reddederse yargılama gideri olarak kalır (CMK m.325, HMK m.326).', d.id, oyun.tl(v_gider), coalesce(v_yer,'')), t)
   from (select p.id union select case when kayb='davali' then d.davali else d.davaci end) x where x.id is not null;
 n:=oyun.adliye_juri_kur(d.id,t);
 if n=0 then
  -- exception tüm işlemi geri alır (başvuru kaydı ve teminat da geri döner)
  raise exception 'Şu anda tarafsız İstinaf Dairesi oluşturulamadı; birkaç saat sonra yeniden dene. Süren dolmak üzereyse Ben › Yönetime Yaz ekranından bildir.';
 end if;
 update oyun.adliye_davalar set istinaf_son=(select i.bit from oyun.adliye_istinaf i where i.dava_id=d.id) where id=d.id;
 perform oyun.olay('adliye',format('Adliye #%s kararı istinafa taşındı; dosya %s üyeli İstinaf Dairesine verildi.',d.id,n),null,null,t);
 return jsonb_build_object('tamam',true,'juri',n,'kisisel',kisisel and not vekil,'teminat',v_gider);
end $function$;

-- ---------- Karar: teminatın iadesi ya da gidere dönmesi; dosyada teminat bilgisi ----------
do $yama$
declare s text;
begin
  s := pg_get_functiondef('oyun.adliye_istinaf_sonuc(bigint, timestamp with time zone)'::regprocedure);
  if position('istinaf_teminat_kapat' in s) = 0 then
    s := replace(s, 'alinan numeric := 0; konu text;', 'alinan numeric := 0; iade numeric := 0; konu text;');
    s := replace(s, 'update oyun.adliye_istinaf set durum = ''bozuldu'' where dava_id = p_dava;',
                    'update oyun.adliye_istinaf set durum = ''bozuldu'' where dava_id = p_dava;' || E'\n' ||
                    '  iade := oyun.istinaf_teminat_kapat(p_dava, ''iade'', t);');
    s := replace(s, 'gider := oyun.istinaf_gider(d);',
                    'gider := case when coalesce(i.teminat, 0) > 0 then 0 else oyun.istinaf_gider(d) end;' || E'\n' ||
                    '  if coalesce(i.teminat, 0) > 0 then' || E'\n' ||
                    '   -- teminat yalnız Dairenin onama çoğunluğuyla reddettiği başvuruda gider olur; oy yokluğu, tek oy ve eşitlikte iade edilir' || E'\n' ||
                    '   if onay >= 2 and onay > boz then alinan := oyun.istinaf_teminat_kapat(p_dava, ''gider'', t);' || E'\n' ||
                    '   else iade := oyun.istinaf_teminat_kapat(p_dava, ''iade'', t); end if;' || E'\n' ||
                    '  end if;');
    s := replace(s, 'format('' Başvuru reddedildiğinden %s TL istinaf yargılama gideri başvurana yüklendi.'', alinan) else '''' end;',
                    'format('' Başvuru reddedildiğinden %s ₺ istinaf teminatı yargılama gideri olarak kaldı.'', oyun.tl(alinan)) else '''' end' || E'\n' ||
                    '   || case when iade > 0 then format('' Daire çoğunlukla karar veremediğinden %s ₺ istinaf teminatı iade edildi.'', oyun.tl(iade)) else '''' end;');
    execute s;
  end if;

  s := pg_get_functiondef('public.adliye_dava_ek(bigint)'::regprocedure);
  if position('teminat_durum' in s) = 0 then
    s := replace(s, '''heyet_gizli'', true,', '''heyet_gizli'', true, ''teminat'', i.teminat, ''teminat_durum'', i.teminat_durum,');
    execute s;
  end if;
end $yama$;

revoke all on function oyun.istinaf_teminat_kapat(bigint, text, timestamp with time zone) from public, anon, authenticated;
