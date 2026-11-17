-- Fonksiyonlarin hedeflenenden farkli surumlerle ezilmesini engelle.
DO $sha$
BEGIN
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='oyun' AND p.proname='meclis_tick') IS DISTINCT FROM '8f06198e6af25490c6827f7b755bcb4a' THEN
 RAISE EXCEPTION 'Surum catismasi: oyun.meclis_tick'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='oyun' AND p.proname='meclis_secim_json') IS DISTINCT FROM '8f4def9c334ee9ac4e5ebacf4ddb62cf' THEN
 RAISE EXCEPTION 'Surum catismasi: oyun.meclis_secim_json'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='oyun' AND p.proname='tg_yargic_makam') IS DISTINCT FROM '50c625bd82c2b4beeb4fe10ba3531f08' THEN
 RAISE EXCEPTION 'Surum catismasi: oyun.tg_yargic_makam'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='oyun' AND p.proname='tg_yargic_parti') IS DISTINCT FROM 'fd3f39ad739b28a7dc9eec8d6edbb131' THEN
 RAISE EXCEPTION 'Surum catismasi: oyun.tg_yargic_parti'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='oyun' AND p.proname='goreve_baslat') IS DISTINCT FROM '70d96663bf3d5602fd7e6ee215cb9d37' THEN
 RAISE EXCEPTION 'Surum catismasi: oyun.goreve_baslat'; END IF;
 IF (SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='oyun' AND p.proname='tg_mahkeme_sira3_islem_koru') IS DISTINCT FROM '3d2751da267bf4c98d037598ae830226' THEN
 RAISE EXCEPTION 'Surum catismasi: oyun.tg_mahkeme_sira3_islem_koru'; END IF;
END $sha$;

-- 17.11.2026: 600 MV/81 il - tutarli siyasi kurumlar, sadece ileri donuk program kodu.
-- KESINLIKLE mevcut makam, secim, oy, para, dava ve aday satirlarini guncellemez.
-- ONCE test ortami ve kod incelemesi. Canliya otomatik uygulanmaz.
-- 1) Tek TBMM Baskanligi esigi, hem sunucu motoru hem oyuncu ekrani.
CREATE OR REPLACE FUNCTION oyun.tbmm_baskan_gerekli(p_tur integer)
RETURNS integer LANGUAGE sql STABLE SET search_path TO '' AS $merkez$
SELECT CASE WHEN p_tur IN (1,2) THEN ceil(oyun.tbmm_tamsayi()*2/3.0)::int
            WHEN p_tur=3 THEN floor(oyun.tbmm_tamsayi()/2.0)::int+1
            ELSE 0 END
$merkez$;

CREATE OR REPLACE FUNCTION oyun.meclis_tick(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
declare s oyun.meclis_secim; ms oyun.secimler; r record; dolu int; gerek int; ust record; ikinci uuid; n int; dongu int; m record; pk text;
begin
  -- Zamanlayıcı ile eşzamanlı oturumlar aynı turu iki kez sonuçlandıramaz.
  perform pg_advisory_xact_lock(hashtext('oyun.meclis_tick'));
  -- yeni yasama dönemi
  for ms in select * from oyun.secimler x where x.tur = 'mv' and x.durum = 'tamam' and x.goreve_bas <= t and x.goreve_bas > t - interval '20 days'
              and not exists (select 1 from oyun.meclis_secim y where y.mv_secim_id = x.id) order by x.goreve_bas loop
    perform oyun.meclis_donem_baslat(ms.id, ms.goreve_bas);
  end loop;
  -- görev şartı kalmayanlar (vekilliği düşen, partisi değişen)
  for m in select x.* from oyun.makamlar x where x.tur in ('tbmm','bskv','grup_bskv') and x.bit is null
             and (not oyun.aktif_vekil(x.user_id) or (x.tur in ('bskv','grup_bskv') and oyun.aktif_mv_parti(x.user_id) is distinct from x.parti_id)) loop
    perform oyun.makam_bitir(m.id, t, 'gorev_dustu');
    if m.tur = 'tbmm' and not exists (select 1 from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti') then
      insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (null, 'baskan', t, t + interval '24 hours');
      perform oyun.olay('meclis', 'TBMM Başkanlığı boşaldı. Ara seçim için adaylık 24 saat açık.', null, null, t);
    end if;
  end loop;
  -- TBMM Başkanı seçimi
  for s in select * from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      if not exists (select 1 from oyun.meclis_aday where secim_id = s.id) then
        if s.uzatma < 2 then
          update oyun.meclis_secim set aday_bit = aday_bit + interval '24 hours', uzatma = uzatma + 1 where id = s.id;
          perform oyun.olay('meclis', 'TBMM Başkanlığı için aday çıkmadı; adaylık süresi 24 saat uzatıldı.', null, null, t);
        else
          update oyun.meclis_secim set durum = 'bitti', sonuc = 'Aday çıkmadı; Geçici Başkan oturumları yönetmeye devam ediyor.' where id = s.id;
        end if;
        continue;
      end if;
      update oyun.meclis_secim set durum = 'oylama', tur_no = 1, tur_bas = aday_bit + interval '30 minutes', tur_bit = aday_bit + interval '75 minutes' where id = s.id;
      insert into oyun.bildirimler(user_id, zaman, metin)
        select x.user_id, s.aday_bit, 'TBMM Başkanlığı adaylığı bitti. 1. tur 30 dakika sonra başlayacak; gizli oy pusulan Devlet › Meclis ekranında.'
        from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
      select * into s from oyun.meclis_secim where id = s.id;
    end if;
    dongu := 0;
    while s.durum = 'oylama' and t >= s.tur_bit and dongu < 5 loop
      dongu := dongu + 1;
      dolu := oyun.tbmm_tamsayi();
      gerek := oyun.tbmm_baskan_gerekli(s.tur_no);
      select * into ust from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) limit 1;
      update oyun.meclis_secim set turlar = turlar || jsonb_build_array(jsonb_build_object('tur', s.tur_no, 'gerek', gerek, 'katilim',
          (select count(*) from oyun.meclis_oy where secim_id = s.id and tur_no = s.tur_no and gorev = 'baskan'),
          'sonuc', (select jsonb_agg(jsonb_build_object('kad', oyun.kad(x.user_id), 'oy', x.oy)) from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x)))
        where id = s.id;
      -- Dördüncü turda yalnız en çok oy alan iki aday yarışır; eşitlikte seçilmiş ilan edilmez.
      -- Eşitlik oluşursa 15 dakika sonra 45 dakikalık yeni bir nihai oylama açılır.
      select x.oy into n from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) offset 1 limit 1;
      if ust.user_id is not null and ((s.tur_no < 4 and ust.oy >= gerek)
         or (s.tur_no >= 4 and ust.oy > 0 and ust.oy > coalesce(n, -1) and (not oyun.gercekci_siyaset() or (select count(*) from oyun.meclis_oy where secim_id=s.id and tur_no=s.tur_no and gorev='baskan') >= ceil(dolu/3.0)))) then
        perform oyun.meclis_gorev_ata(ust.user_id, 'tbmm', s.tur_bit);
        update oyun.meclis_secim set durum = 'bitti', sonuc = format('%s %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy) where id = s.id;
        perform oyun.olay('meclis', format('%s, %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy), null, oyun.aktif_mv_parti(ust.user_id), s.tur_bit);
        perform oyun.gazete_ekle('atama', format('TBMM Başkanlığına %s seçilmiştir', oyun.kad(ust.user_id)), format('Genel Kurul''un gizli oylamasında %s. turda %s oy.', s.tur_no, ust.oy), null, s.tur_bit);
      elsif ust.user_id is null then
        update oyun.meclis_secim set durum = 'bitti', sonuc = 'Adaylar milletvekilliği sıfatını kaybettiği için seçim sonuçsuz kaldı.' where id = s.id;
      else
        if s.tur_no = 3 then
          -- 4. tur: en çok oy alan iki aday
          update oyun.meclis_aday set elendi = true where secim_id = s.id and gorev = 'baskan'
            and user_id not in (select x.user_id from oyun.meclis_sayim(s.id, 3, 'baskan') x where oyun.aktif_vekil(x.user_id) limit 2);
        end if;
        update oyun.meclis_secim set tur_no = tur_no + 1, tur_bas = tur_bit + interval '15 minutes', tur_bit = tur_bit + interval '60 minutes' where id = s.id;
        perform oyun.olay('meclis', format('TBMM Başkanlığı seçiminin %s. turunda başkan seçilemedi; %s. tur oylaması 15 dakika sonra başlayacak.', s.tur_no, s.tur_no + 1), null, null, s.tur_bit);
        insert into oyun.bildirimler(user_id, zaman, metin)
        select distinct x.user_id, s.tur_bit,
          format('TBMM Başkanlığı %s. tur oylaması %s saatinde açılacak ve 45 dakika açık kalacak.',
            s.tur_no + 1,
            to_char((s.tur_bit + interval '15 minutes') at time zone 'Europe/Istanbul', 'HH24:MI'))
        from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
      end if;
      select * into s from oyun.meclis_secim where id = s.id;
    end loop;
  end loop;
  -- Parti grup seçimleri
  for s in select * from oyun.meclis_secim where tur = 'grup' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      update oyun.meclis_secim set durum = 'oylama' where id = s.id;
      s.durum := 'oylama';
    end if;
    if s.durum = 'oylama' and t >= s.oy_bit then
      select kisa into pk from oyun.partiler where id = s.parti_id;
      if s.bskv_hakki then
        select * into ust from oyun.meclis_sayim(s.id, 0, 'bskv') x
          where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'bskv') is null limit 1;
        if ust.user_id is not null then
          perform oyun.meclis_gorev_ata(ust.user_id, 'bskv', s.oy_bit);
          perform oyun.olay('meclis', format('%s grubu %s''i TBMM Başkanvekili olarak seçti.', pk, oyun.kad(ust.user_id)), null, s.parti_id, s.oy_bit);
        end if;
      end if;
      n := (select count(*) from oyun.meclis_aday a where a.secim_id = s.id and a.gorev = 'grup_bskv');
      for r in select x.* from oyun.meclis_sayim(s.id, 0, 'grup_bskv') x
                where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'grup_bskv') is null
                  and (n <= s.grup_bskv_sayi or x.oy > 0)
                limit s.grup_bskv_sayi loop
        perform oyun.meclis_gorev_ata(r.user_id, 'grup_bskv', s.oy_bit);
      end loop;
      update oyun.meclis_secim set durum = 'bitti', sonuc = 'Grup seçimi tamamlandı.' where id = s.id;
      perform oyun.olay('meclis', format('%s Meclis grubu başkanvekillerini seçti.', pk), null, s.parti_id, s.oy_bit);
    end if;
  end loop;
end $function$;


CREATE OR REPLACE FUNCTION oyun.meclis_secim_json(s oyun.meclis_secim, p oyun.profiller, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
  select jsonb_build_object('id', s.id, 'tur', s.tur, 'parti', oyun.parti_json(s.parti_id), 'durum', s.durum, 'aday_bit', s.aday_bit,
    'oy_bit', coalesce(s.oy_bit, s.tur_bit), 'tur_no', s.tur_no, 'tur_bas', s.tur_bas, 'tur_bit', s.tur_bit, 'bskv_hakki', s.bskv_hakki, 'grup_bskv_sayi', s.grup_bskv_sayi,
    'sonuc', s.sonuc, 'turlar', s.turlar,
    'gerek', case when s.tur = 'baskan' and s.durum = 'oylama' then
               oyun.tbmm_baskan_gerekli(s.tur_no) end,
    'adaylar', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'gorev', a.gorev, 'elendi', a.elendi, 'parti', oyun.parti_json(pr.parti_id),
                   'il', (select i.ad from oyun.makamlar m join oyun.iller i on i.id = m.il_id where m.user_id = pr.id and m.tur = 'mv' and m.bit is null limit 1),
                   'benim', pr.id = p.id) order by a.gorev, a.zaman)
                 from oyun.meclis_aday a join oyun.profiller pr on pr.id = a.user_id where a.secim_id = s.id), '[]'::jsonb),
    'oylarim', coalesce((select jsonb_agg(o.gorev) from oyun.meclis_oy o where o.secim_id = s.id and o.secmen = p.id
                          and o.tur_no = case when s.tur = 'baskan' then s.tur_no else 0 end), '[]'::jsonb),
    'katilabilir', oyun.aktif_vekil(p.id) and (s.tur = 'baskan' or oyun.aktif_mv_parti(p.id) = s.parti_id))
$function$;


-- 2) Ucuncu YK uyesi TBMM secimi: eski Adalet Bakani tetikleyicisi kalkiyor.
DROP TRIGGER IF EXISTS mahkeme_3_secim_koru ON oyun.mahkeme_meclis_oy;
CREATE OR REPLACE FUNCTION oyun.tg_mahkeme_sira3_islem_koru()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.sira=3 AND oyun.gercekci_siyaset() THEN
    RAISE EXCEPTION 'Yüksek Mahkeme TBMM kontenjanındaki üye siyasi oylamayla azledilemez.';
  END IF;
  RETURN NEW;
END $function$;


-- 3) Tum mahkeme uyeleri ayni siyasi gorev ve parti uyeligi kisitina tabi.
CREATE OR REPLACE FUNCTION oyun.tg_yargic_makam()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.bit IS NULL AND EXISTS (SELECT 1 FROM oyun.mahkeme_uye WHERE sira IN (1,2,3) AND user_id=NEW.user_id)
  THEN RAISE EXCEPTION 'Yüksek Mahkemenin 1., 2. ve 3. üyeleri başka makam alamaz.'; END IF;
  RETURN NEW;
END $function$;


CREATE OR REPLACE FUNCTION oyun.tg_yargic_parti()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.parti_id IS NOT NULL AND NEW.parti_id IS DISTINCT FROM OLD.parti_id
    AND EXISTS (SELECT 1 FROM oyun.mahkeme_uye WHERE sira IN (1,2,3) AND user_id=NEW.id)
  THEN RAISE EXCEPTION 'Yüksek Mahkemenin 1., 2. ve 3. üyeleri partiye üye olamaz.'; END IF;
  RETURN NEW;
END $function$;


CREATE OR REPLACE FUNCTION oyun.goreve_baslat(p_sid bigint)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE s oyun.secimler; k record; m record; t timestamptz:=oyun.simdi();
 v_hata text; v_detay text; v_yeni_cb boolean:=false; v_eski_cb uuid; v_yeni_cb_user uuid;
BEGIN
 SELECT * INTO s FROM oyun.secimler WHERE id=p_sid FOR UPDATE;
 IF s.id IS NULL OR s.durum<>'sonuclandi' THEN RETURN; END IF;
 -- GEÇMİŞE DOĞRU GÖREV DEĞİŞİKLİĞİ YASAK; gelecekteki seçim çalıştırılamaz.
 IF s.sonuc ? 'iptal' THEN UPDATE oyun.secimler SET durum='tamam' WHERE id=s.id; RETURN; END IF;
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
  -- Yalnızca yeni seçimde kazanan varsa yeni yasama dönemi başlasın.
  -- Eski milletvekillerinden sonradan atanmış olanlar geçmiş tarihli sonuçla silinemez.
  SELECT user_id INTO v_eski_cb FROM oyun.makamlar WHERE tur='cb' AND bit IS NULL ORDER BY bas DESC LIMIT 1;
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
    -- Seçim anında uygun olmayan aday tüm seçimi kilitleyemez.
    IF EXISTS(SELECT 1 FROM oyun.mahkeme_uye WHERE user_id=k.user_id AND sira IN (1,2,3)) THEN
      PERFORM oyun.bildir(k.user_id,'Yüksek Mahkeme üyeliği ile seçilmiş siyasi görev bağdaşmadığı için göreve başlayamadın.',t);
      INSERT INTO oyun_yonetim.gorev_denetim(makam_id,user_id,gorev,olay,neden,aktor)
        VALUES(NULL,k.user_id,CASE WHEN s.tur='cb2' THEN 'cb' ELSE s.tur END,'engellendi','yuksek_mahkeme_uyeligi: secim #'||s.id,NULL);
      IF s.tur='mv' THEN PERFORM oyun.yedek_getir(s.id,k.il_id,k.parti_id,t); END IF;
      CONTINUE;
    END IF;
    -- 2972 m.17: MV iken belediye başkanı seçilenin 15 günlük görev tercih süresi.
    -- Bu süre içerisinde milletvekilliği düşmez, belediye görev devri bekler.
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
    -- Asla adayın tüm görevlerini indiscriminately kapatma.
    -- Yalnızca yeni görevin atanmasıyla mevzuata göre çakışanlar düşer
    -- (makam_bagdasmazlik_tg atama tetikleyicisinde).
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


-- 4) Ayni adaylik fonksiyonunu iki kez tetikleyen eski tekrar kaldiriliyor.
DROP TRIGGER IF EXISTS gb_mv_cb_adaylik_kontrol ON oyun.adaylar;
-- 'gb_mv_cb_adaylik_kontrol_tg' tetikleyicisi yerinde kalir.
