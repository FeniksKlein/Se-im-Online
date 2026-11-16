-- 2026.11.16-4 · Seçim ve makam güvenliği
--  * İptal edilmiş (erken seçim, geçersiz karar vb.) bir seçim hiçbir yoldan yeniden sonuçlanamaz/göreve başlatamaz.
--  * Hedefli (tek il) milletvekili ara seçimi ülke genelindeki milletvekillerinin görevini bitiremez.
--  * Aynı kişi yeniden Cumhurbaşkanı seçilirse kabinesi ve yardımcıları görevde kalır (görev devri yoktur);
--    farklı kişi seçilirse önceki Cumhurbaşkanının bakan ve yardımcılarının görevi yeni Cumhurbaşkanı göreve başladığında sona erer.
--  * Görev sona erme kayıtları "olağan / hukuki / yaptırım / kaldırılmış kural / belirsiz" olarak sınıflandırılabilir.
--  * Erken seçim KARARI hiçbir görevi sona erdirmez (oyun.erken_genel_secim_olustur yalnız takvim oluşturur);
--    görev değişimi yalnızca yeni seçimin göreve başlama anında goreve_baslat ile olur.
--  * DÜZELTME: 15.11.2026 sürümü kazananlar tablosunda olmayan "sira" sütununa göre sıralıyordu; her seçimde göreve başlatma
--    hata verecekti (17.11 belediye ara seçimi ve 1.12 genel seçim). Sıralama il_id, user_id olarak düzeltildi.
-- 1 Aralık 2026 olağan seçim takvimine, mevcut makamlara ve iptal edilmiş seçimlere dokunulmaz.

-- 1) İptal edilmiş seçim kilidi
create or replace function oyun.secim_iptal_kilidi_tg()
returns trigger language plpgsql set search_path to '' as $function$
begin
  if old.sonuc ? 'iptal' and old.durum = 'tamam'
     and coalesce(current_setting('oyun.iptal_secim_ac', true),'') <> 'evet' then
    -- İptal edilmiş seçim yeniden "bekliyor/sonuclandi" yapılamaz, iptal bilgisi silinemez.
    new.durum := 'tamam';
    new.sonuc := old.sonuc || coalesce(new.sonuc,'{}'::jsonb) || jsonb_build_object('iptal', old.sonuc->'iptal');
  end if;
  return new;
end $function$;
create or replace trigger secim_iptal_kilidi before update on oyun.secimler
  for each row execute function oyun.secim_iptal_kilidi_tg();

-- 2) Yeniden seçilen Cumhurbaşkanının yardımcıları görevde kalır
create or replace function oyun.cb_yardimcisi_cb_degisti_tg()
returns trigger language plpgsql set search_path to '' as $function$
declare m record; t timestamptz:=coalesce(new.bit,oyun.simdi());
begin
  -- Aynı kişi yeni dönem için de Cumhurbaşkanı seçildiyse görev devri yoktur.
  if new.bitis_neden = 'donem_bitti' and exists (
       select 1 from oyun.kazananlar k join oyun.secimler s on s.id=k.secim_id
        where s.tur in ('cb','cb2') and s.durum='sonuclandi' and k.user_id=new.user_id
          and s.goreve_bas is not null and s.goreve_bas <= t) then
    return new;
  end if;
  for m in select id from oyun.makamlar where tur='cb_yardimcisi' and bit is null loop
    perform oyun.makam_bitir(m.id,t,'kabine_yenilendi');
  end loop;
  update oyun.cb_yardimcisi_teklifleri set durum='iptal',yanit_at=t where durum='bekliyor';
  return new;
end $function$;

-- 3) Göreve başlatma: iptal kilidi, ara seçim koruması, kabine sürekliliği
create or replace function oyun.goreve_baslat(p_sid bigint)
returns void language plpgsql set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $function$
DECLARE s oyun.secimler; k record; m record; t timestamptz:=oyun.simdi();
 v_hata text; v_detay text; v_yeni_cb boolean:=false; v_eski_cb uuid; v_yeni_cb_user uuid;
BEGIN
 SELECT * INTO s FROM oyun.secimler WHERE id=p_sid FOR UPDATE;
 IF s.id IS NULL OR s.durum<>'sonuclandi' THEN RETURN; END IF;
 -- İptal edilmiş seçim hiçbir görevi değiştiremez.
 IF s.sonuc ? 'iptal' THEN
  UPDATE oyun.secimler SET durum='tamam' WHERE id=s.id;
  RETURN;
 END IF;
 -- GEÇMİŞE DOĞRU GÖREV DEĞİŞİKLİĞİ YASAK; gelecekteki seçim çalıştırılamaz.
 IF s.goreve_bas IS NULL OR s.goreve_bas>t THEN RETURN; END IF;
 IF s.tur='kurultay' THEN
  FOR k IN SELECT * FROM oyun.kazananlar WHERE secim_id=s.id LOOP
   BEGIN
    CONTINUE WHEN NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=k.user_id AND parti_id=k.parti_id);
    IF (SELECT gb FROM oyun.partiler WHERE id=k.parti_id) IS DISTINCT FROM k.user_id THEN
      DELETE FROM oyun.parti_gby WHERE parti_id=k.parti_id;
    END IF;
    DELETE FROM oyun.parti_gby WHERE user_id=k.user_id;
    -- Parti genel başkanlığı milletvekilliği veya bakanlık görevini düşürmez.
    -- TBMM başkanlığı ile aktif parti liderliği bağdaşmaz.
    FOR m IN SELECT id FROM oyun.makamlar
      WHERE user_id=k.user_id AND tur='tbmm' AND bit IS NULL AND bas<=t
    LOOP
      PERFORM oyun.makam_bitir(m.id,t,'gorev_bagdasmazligi');
    END LOOP;
    UPDATE oyun.partiler SET gb=k.user_id WHERE id=k.parti_id;
    PERFORM oyun.bildir(k.user_id,
      format('Kurultayı kazandın: %s Genel Başkanı oldun.',(SELECT ad FROM oyun.partiler WHERE id=k.parti_id)),t);
   EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hata=MESSAGE_TEXT,v_detay=PG_EXCEPTION_CONTEXT;
    PERFORM oyun.tick_hata_yaz('goreve_baslat kurultay #'||s.id,v_hata,v_detay);
   END;
  END LOOP;
  PERFORM oyun.gb_halef(t);
 ELSIF s.tur='cb' AND coalesce((s.sonuc->>'ikinci_tur')::boolean,false) THEN
  NULL;
 ELSE
  SELECT user_id INTO v_eski_cb FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL ORDER BY bas DESC LIMIT 1;
  -- Yalnızca ülke geneli (olağan ya da erken) seçimde kazanan varsa yeni yasama dönemi başlar.
  -- Tek ile hedefli ara seçim, diğer illerin milletvekillerine dokunmaz.
  IF s.tur='mv' AND s.hedef_il_id IS NULL AND EXISTS(SELECT 1 FROM oyun.kazananlar WHERE secim_id=s.id) THEN
   FOR m IN SELECT id FROM oyun.makamlar
     WHERE tur='mv' AND bit IS NULL AND bas<=s.goreve_bas AND
       (secim_id IS DISTINCT FROM s.id)
   LOOP
    PERFORM oyun.makam_bitir(m.id,t,'donem_bitti');
   END LOOP;
  END IF;
  FOR k IN SELECT * FROM oyun.kazananlar WHERE secim_id=s.id ORDER BY il_id NULLS FIRST, user_id LOOP
   BEGIN
    CONTINUE WHEN NOT EXISTS(SELECT 1 FROM oyun.profiller WHERE id=k.user_id);
    -- Seçim anında uygun olmayan aday tüm seçimi kilitleyemez; sessizce de göreve geçirilmez.
    IF EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=k.user_id AND sira IN (1,2)) THEN
      PERFORM oyun.bildir(k.user_id,'Yüksek Mahkeme üyeliği ile seçilmiş siyasi görev bağdaşmadığı için göreve başlayamadın.',t);
      INSERT INTO oyun_yonetim.gorev_denetim(makam_id,user_id,gorev,olay,neden,aktor)
        VALUES(NULL,k.user_id,CASE WHEN s.tur='cb2' THEN 'cb' ELSE s.tur END,'engellendi','yuksek_mahkeme_uyeligi: secim #'||s.id,NULL);
      IF s.tur='mv' THEN PERFORM oyun.yedek_getir(s.id,k.il_id,k.parti_id,t); END IF;
      CONTINUE;
    END IF;
    -- 2972 m.17: MV iken belediye başkanı seçilenin 15 günlük görev tercih süresi.
    IF s.tur='bel' AND EXISTS(SELECT 1 FROM oyun.makamlar
       WHERE user_id=k.user_id AND tur='mv' AND bit IS NULL) THEN
      INSERT INTO oyun.gorev_tercihi(secim_id,user_id,il_id,parti_id,baslangic,son_tarih)
       VALUES(s.id,k.user_id,k.il_id,k.parti_id,t,t+interval '15 days')
       ON CONFLICT(secim_id,user_id,il_id) DO NOTHING;
      PERFORM oyun.bildir(k.user_id,
        format('Belediye başkanı seçildin. 15 gün içinde milletvekilliğini korumayı veya belediye başkanlığını seçmelisin. Son tarih: %s.',
        to_char((t+interval '15 days') AT TIME ZONE 'Europe/Istanbul','DD.MM.YYYY HH24:MI')),t);
      CONTINUE;
    END IF;
    IF s.tur='bel' THEN
      FOR m IN SELECT id FROM oyun.makamlar WHERE tur='bel' AND il_id=k.il_id AND bit IS NULL LOOP
        PERFORM oyun.makam_bitir(m.id,t,'donem_bitti');
      END LOOP;
    ELSIF s.tur IN ('cb','cb2') THEN
      FOR m IN SELECT id FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL LOOP
        PERFORM oyun.makam_bitir(m.id,t,'donem_bitti');
      END LOOP;
    END IF;
    -- Yalnızca yeni görevin atanmasıyla mevzuata göre çakışanlar düşer (makam_bagdasmazlik_tg).
    IF NOT EXISTS(SELECT 1 FROM oyun.makamlar
       WHERE secim_id=s.id AND tur=CASE WHEN s.tur='cb2' THEN 'cb' ELSE s.tur END AND user_id=k.user_id AND bit IS NULL) THEN
      INSERT INTO oyun.makamlar(tur,user_id,il_id,parti_id,secim_id,bas)
      VALUES(CASE WHEN s.tur='cb2' THEN 'cb' ELSE s.tur END,k.user_id,k.il_id,k.parti_id,s.id,t);
    END IF;
    IF s.tur IN ('cb','cb2') THEN v_yeni_cb:=true; v_yeni_cb_user:=k.user_id; END IF;
    PERFORM oyun.bildir(k.user_id,
      CASE WHEN s.tur IN ('cb','cb2') THEN 'Cumhurbaşkanlığı görevine başladın.'
        ELSE format('%s olarak göreve başladın.',
          CASE WHEN s.tur='mv' THEN (SELECT ad FROM oyun.iller WHERE id=k.il_id)||' Milletvekili'
               ELSE (SELECT ad FROM oyun.iller WHERE id=k.il_id)||' Belediye Başkanı' END) END,t);
   EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hata=MESSAGE_TEXT,v_detay=PG_EXCEPTION_CONTEXT;
      PERFORM oyun.tick_hata_yaz('goreve_baslat #'||s.id||' aday',v_hata,v_detay);
      PERFORM oyun.bildir(k.user_id,'Seçildiğin göreve geçişte teknik veya hukuki engel oluştu. Diğer oyuncuların seçim işlemleri devam ediyor.',t);
   END;
  END LOOP;
  IF s.tur IN ('cb','cb2') AND v_yeni_cb THEN
    IF v_yeni_cb_user IS DISTINCT FROM v_eski_cb THEN
      -- Görev devri: önceki Cumhurbaşkanının bakanları yeni Cumhurbaşkanı göreve başlayınca görevden ayrılır.
      FOR m IN SELECT id FROM oyun.makamlar WHERE tur='bakan' AND bit IS NULL
         AND secim_id IS DISTINCT FROM s.id
      LOOP
        PERFORM oyun.makam_bitir(m.id,t,'kabine_yenilendi');
      END LOOP;
    ELSE
      PERFORM oyun.bildir(v_yeni_cb_user,'Yeniden Cumhurbaşkanı seçildin; kabinen ve yardımcıların görevde devam ediyor. Dilediğin zaman değişiklik yapabilirsin.',t);
    END IF;
  END IF;
  IF s.tur='mv' AND s.hedef_il_id IS NULL THEN PERFORM oyun.kanunlar_kaduk(t); END IF;
 END IF;
 UPDATE oyun.secimler SET durum='tamam' WHERE id=s.id;
END $function$;

-- 4) Görev sona erme sınıflandırması (gerçek düşme / hukuki / yaptırım / kaldırılmış kural / teknik engel)
create or replace function oyun_yonetim.gorev_bitis_sinif(p_tur text, p_neden text)
returns text language sql immutable set search_path to '' as $$
  select case
    when p_neden is null then 'belirsiz'
    when p_neden in ('donem_bitti','istifa','hesap_silindi','hesap_kapatildi','sistem_degisti','hukumet_dustu','gorev_dustu','yeni_gorev') then 'olagan'
    when p_neden in ('gorev_bagdasmazligi','mv_adayligi','yuce_divan','tek_bakanlik_kurali') or p_neden like 'Adliye #%' then 'hukuki'
    when p_neden = 'cb_adayligi' and p_tur = 'bel' then 'hukuki'
    when p_neden in ('gorevden_alindi','yonetici_karari','kabine_yenilendi') then 'yaptirim_veya_gorev_devri'
    when p_neden in ('kabine_48_saat_suresi_doldu','kabine_dustu','ihmal') then 'kaldirilmis_kural'
    when p_neden = 'cb_adayligi' then 'hatali_kural'
    else 'belirsiz' end
$$;

create or replace function public.yk_gorev_kayip_raporu(p_gun integer default 30)
returns jsonb language plpgsql stable security definer set search_path to '' as $function$
begin
  perform oyun.yonetici_zorunlu();
  return jsonb_build_object(
    'ozet', coalesce((select jsonb_agg(jsonb_build_object('sinif',x.sinif,'sayi',x.n) order by x.n desc) from (
       select oyun_yonetim.gorev_bitis_sinif(m.tur,m.bitis_neden) sinif, count(*) n
         from oyun.makamlar m where m.bit is not null and m.bit > oyun.simdi() - make_interval(days => greatest(1,least(coalesce(p_gun,30),365)))
        group by 1) x),'[]'::jsonb),
    'supheli', coalesce((select jsonb_agg(jsonb_build_object('makam_id',m.id,'tur',m.tur,'kad',oyun.kad(m.user_id),'bas',m.bas,'bit',m.bit,'neden',m.bitis_neden,
         'sinif',oyun_yonetim.gorev_bitis_sinif(m.tur,m.bitis_neden)) order by m.bit desc)
       from oyun.makamlar m where m.bit is not null
        and oyun_yonetim.gorev_bitis_sinif(m.tur,m.bitis_neden) in ('kaldirilmis_kural','hatali_kural','belirsiz')),'[]'::jsonb),
    'engellenen', coalesce((select jsonb_agg(jsonb_build_object('zaman',g.zaman,'makam_id',g.makam_id,'kad',oyun.kad(g.user_id),'neden',g.neden) order by g.zaman desc)
       from (select * from oyun_yonetim.gorev_denetim where olay='engellendi' order by zaman desc limit 50) g),'[]'::jsonb));
end $function$;
revoke all on function public.yk_gorev_kayip_raporu(integer) from public, anon;
grant execute on function public.yk_gorev_kayip_raporu(integer) to authenticated;
revoke all on function oyun_yonetim.gorev_bitis_sinif(text,text) from public, anon, authenticated;
revoke all on function oyun.secim_iptal_kilidi_tg() from public, anon, authenticated;
