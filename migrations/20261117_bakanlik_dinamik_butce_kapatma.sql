-- close
CREATE OR REPLACE FUNCTION public.bakanlik_kapat(p_kod text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p oyun.profiller:=oyun.profilim(); b oyun.bakanliklar; v_t timestamptz:=oyun.simdi(); v_gerekce text;
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN RAISE EXCEPTION 'Bu yetki yalnız görevdeki Cumhurbaşkanına aittir.'; END IF;
 PERFORM pg_advisory_xact_lock(40881117);
 v_gerekce:=btrim(coalesce(p_gerekce,''));
 IF length(v_gerekce)<10 OR length(v_gerekce)>350 THEN
  RAISE EXCEPTION 'Kapatma gerekçesi 10-350 karakter olmalıdır.'; END IF;
 SELECT * INTO b FROM oyun.bakanliklar WHERE kod=p_kod FOR UPDATE;
 IF b.kod IS NULL THEN RAISE EXCEPTION 'Bakanlık bulunamadı.'; END IF;
 IF NOT b.aktif THEN RAISE EXCEPTION 'Bakanlık zaten kapalı.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.makamlar WHERE tur='bakan' AND bakanlik=b.kod AND bit IS NULL)
 THEN RAISE EXCEPTION 'Önce bu bakanlıktaki görevli bakanı Kabine ekranından görevden almalısın.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.bakanlik_odenek_talep WHERE kod=b.kod AND durum='bekliyor')
 THEN RAISE EXCEPTION 'Bu bakanlığın bekleyen ödenek talebi var. Önce sonuçlandır.'; END IF;
 IF EXISTS(SELECT 1 FROM oyun.bakanlik_etkinlik WHERE bakanlik=b.kod AND durum='aktif' AND bit>v_t) THEN RAISE EXCEPTION 'Aktif bir etkinlik devam ederken bakanlık kapatılamaz.'; END IF;
 UPDATE oyun.bakan_teklifleri SET durum='iptal',yanit_at=v_t WHERE bakanlik=b.kod AND durum='bekliyor';
 UPDATE oyun.bakanliklar SET aktif=false,kapanis_at=v_t,kapanis_gerekce=v_gerekce WHERE kod=b.kod;
 PERFORM oyun.bakanlik_butce_pay_duzenle(b.kod,0);
 PERFORM oyun.olay('duyuru',format('Cumhurbaşkanı %s, %s kurumunu kapattı. Gerekçe: %s',p.kad,b.ad,v_gerekce),null,p.parti_id,v_t);
 RETURN jsonb_build_object('tamam',true,'islem','kapatildi','kod',b.kod,'ad',b.ad);
END $function$;

-- open
CREATE OR REPLACE FUNCTION public.bakanlik_yeniden_ac(p_kod text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p oyun.profiller:=oyun.profilim(); b oyun.bakanliklar; v_t timestamptz:=oyun.simdi();
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN RAISE EXCEPTION 'Bu yetki yalnız görevdeki Cumhurbaşkanına aittir.'; END IF;
 PERFORM pg_advisory_xact_lock(40881117);
 SELECT * INTO b FROM oyun.bakanliklar WHERE kod=p_kod FOR UPDATE;
 IF b.kod IS NULL THEN RAISE EXCEPTION 'Bakanlık bulunamadı.'; END IF;
 IF b.aktif THEN RAISE EXCEPTION 'Bakanlık zaten açık.'; END IF;
 IF (SELECT count(*) FROM oyun.bakanliklar WHERE aktif)>=30 THEN
  RAISE EXCEPTION 'Aynı anda en fazla 30 bakanlık açık olabilir.'; END IF;
 UPDATE oyun.bakanliklar SET aktif=true,kapanis_at=null,kapanis_gerekce=null WHERE kod=b.kod;
 PERFORM oyun.bakanlik_butce_pay_duzenle(b.kod,2);
 INSERT INTO oyun.bakanlik_kasa(kod,kasa) VALUES(b.kod,0) ON CONFLICT(kod) DO NOTHING;
 PERFORM oyun.olay('duyuru',format('Cumhurbaşkanı %s, %s kurumunu yeniden açtı.',p.kad,b.ad),null,p.parti_id,v_t);
 RETURN jsonb_build_object('tamam',true,'islem','yeniden_acildi','kod',b.kod,'ad',b.ad);
END $function$;

-- dist
CREATE OR REPLACE FUNCTION public.kamu_butce_dagit(p_toplam numeric, p_paylar jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); total numeric := 0; c record; t timestamptz := oyun.simdi(); n int; pay numeric;
begin
  if u is null or not (exists(select 1 from oyun.makamlar where user_id = u and tur = 'cb' and bit is null) or u = oyun.yurutme_user()) then
    raise exception 'Merkezi bütçeyi yalnız görevdeki Cumhurbaşkanı (parlamenter sistemde Başbakan) dağıtabilir.';
  end if;
  if p_toplam is null or p_toplam < 0.001 or p_toplam > 5 or p_toplam <> round(p_toplam, 3) then
    raise exception 'Dağıtılacak tutar 0,001 ile 5 milyar ₺ arasında olmalı.';
  end if;
  if p_paylar is null or jsonb_typeof(p_paylar) <> 'object' then raise exception 'Bütçe payları geçersiz.'; end if;
  select count(*) into n from jsonb_object_keys(p_paylar);
  if n < 1 or n > 30 then raise exception 'En az bir, en çok 30 açık bakanlığa pay verilmeli.'; end if;
  for c in select key, value from jsonb_each_text(p_paylar) loop
    if not exists(select 1 from oyun.bakanliklar b where b.kod = c.key and b.aktif) or c.value !~ '^[0-9]+([.][0-9]+)?$' or (c.value)::numeric > 100 then
      raise exception 'Geçersiz bütçe payı: %', c.key;
    end if;
    total := total + (c.value)::numeric;
  end loop;
  if total <> 100 then raise exception 'Bütçe paylarının toplamı %%100 olmalı.'; end if;
  perform pg_advisory_xact_lock(920044, 1);
  if exists(select 1 from oyun.kamu_butce_kararlar where tarih > t - interval '24 hours') then
    raise exception 'Merkezi bütçe en erken 24 saat sonra yeniden dağıtılabilir.';
  end if;
  perform set_config('oyun.hazine_islem','Merkezi bütçe tahsisi',true);
update oyun.ulke set hazine = hazine - p_toplam where id = 1 and hazine >= p_toplam;
  perform set_config('oyun.hazine_islem','',true);
  if not found then raise exception 'Hazine''de yeterli kaynak yok.'; end if;
  for c in select key, value from jsonb_each_text(p_paylar) loop
    pay := round(p_toplam * (c.value)::numeric / 100, 6);
    if pay <= 0 then continue; end if;
    perform oyun.bm_neden('tahsis', 'Merkezi bütçe tahsisi (Hazine''den)');
    update oyun.bakanlik_kasa set kasa = kasa + pay where kod = c.key;
    if not found then raise exception 'Bakanlık kasası eksik: %', c.key; end if;
  end loop;
  perform oyun.bm_neden(null, null);
  insert into oyun.kamu_butce_kararlar(karar_veren, toplam_milyar, paylar, tarih) values (u, p_toplam, p_paylar, t);
  return public.kamu_butce_panel();
end $function$;

-- panel
CREATE OR REPLACE FUNCTION public.kamu_butce_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u uuid:=auth.uid();
BEGIN
 IF u IS NULL THEN RAISE EXCEPTION 'Giris gerekli'; END IF;
 RETURN jsonb_build_object(
  'hazine',(SELECT hazine FROM oyun.ulke WHERE id=1),
  'son_hazine_hareketleri',coalesce((select jsonb_agg(jsonb_build_object('id',z.id,'zaman',z.zaman,'onceki',z.onceki,'sonraki',z.sonraki,'fark',z.fark,'tur',z.tur,'aciklama',z.aciklama) order by z.id desc) from (select * from oyun.hazine_hareketleri where abs(fark) >= 0.0005 order by id desc limit 15) z),'[]'::jsonb),
  'ekonomi',(SELECT jsonb_build_object('buyume',buyume,'enflasyon',enflasyon,'issizlik',issizlik,'memnuniyet',memnuniyet) FROM oyun.ulke WHERE id=1),
  'bakanliklar',COALESCE((SELECT jsonb_agg(jsonb_build_object('kod',k.kod,'kasa',k.kasa) ORDER BY k.kod) FROM oyun.bakanlik_kasa k JOIN oyun.bakanliklar b ON b.kod=k.kod WHERE b.aktif),'[]'::jsonb),
  'yetkili',EXISTS(SELECT 1 FROM oyun.makamlar WHERE tur='cb' AND user_id=u AND bit IS NULL),
  'son_karar',(SELECT tarih FROM oyun.kamu_butce_kararlar ORDER BY id DESC LIMIT 1),
  'kararlar',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',x.id,'toplam',x.toplam_milyar,'paylar',x.paylar,'tarih',x.tarih) ORDER BY x.id DESC)
   FROM (SELECT * FROM oyun.kamu_butce_kararlar ORDER BY id DESC LIMIT 20)x),'[]'::jsonb)
 );
END $function$;

-- cabinet
CREATE OR REPLACE FUNCTION public.yurutme_butce_masasi()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.bakanlik_ayar; u oyun.ulke; y uuid := oyun.yurutme_user();
begin
  select * into a from oyun.bakanlik_ayar where id = 1;
  select * into u from oyun.ulke where id = 1;
  return jsonb_build_object(
    'simdi', t, 'yetkili', p.id = y, 'cb', exists(select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb' and m.bit is null),
    'yurutme', (select x.kad from oyun.profiller x where x.id = y),
    'sistem', case when oyun.hukumet_sistemi() = 1 then 'parlamenter' else 'baskanlik' end,
    'hazine', round(u.hazine, 3), 'son_hazine_hareketleri',coalesce((select jsonb_agg(jsonb_build_object('zaman',z.zaman,'fark',round(z.fark,3),'onceki',round(z.onceki,3),'sonraki',round(z.sonraki,3),'aciklama',z.aciklama) order by z.id desc) from (select * from oyun.hazine_hareketleri where abs(fark) >= 0.0005 order by id desc limit 8) z),'[]'::jsonb), 'hesap', oyun.ulke_hesap(u), 'maliye', oyun.maliye_ozet(), 'tavan', a.tavan,
    'aktarim_oran', a.aktarim_oran, 'aktarim_bekleme_saat', a.aktarim_bekleme_saat, 'talep_ust', a.talep_ust,
    'son_tahsis', (select max(k.tarih) from oyun.kamu_butce_kararlar k),
    'bakanliklar', (select jsonb_agg(jsonb_build_object(
        'kod', b.kod, 'ad', b.ad, 'kasa', round(k.kasa, 2), 'pay', coalesce((u.butce ->> b.kod)::numeric, 0),
        'gunluk', round((oyun.ulke_hesap(u) ->> 'cari')::numeric * coalesce((u.butce ->> b.kod)::numeric, 0) / 100, 3),
        'bakan', (select x.kad from oyun.makamlar m join oyun.profiller x on x.id = m.user_id where m.tur = 'bakan' and m.bakanlik = b.kod and m.bit is null limit 1),
        'harcama7', (select round(coalesce(-sum(h.tutar), 0), 2) from oyun.bakanlik_hareket h where h.kod = b.kod and h.tutar < 0 and h.zaman > t - interval '7 days'),
        'aktarim_hazir', (select max(h.zaman) + make_interval(hours => a.aktarim_bekleme_saat) from oyun.bakanlik_hareket h where h.kod = b.kod and h.tur = 'aktarim' and h.tutar < 0),
        'aktif_etkinlik', exists(select 1 from oyun.bakanlik_etkinlik e where e.bakanlik = b.kod and e.durum = 'aktif' and e.bit > t),
        'puan', (oyun.bm_karne(b.kod, t) ->> 'puan')::numeric) order by b.sira)
      from oyun.bakanliklar b join oyun.bakanlik_kasa k on k.kod = b.kod where b.aktif),
    'talepler', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'kod', x.kod, 'ad', bk.ad, 'kad', pr.kad, 'tutar', x.tutar, 'gerekce', x.gerekce,
                                   'durum', x.durum, 'zaman', x.zaman, 'bitis', x.bitis, 'karar_zaman', x.karar_zaman, 'karar_not', x.karar_not)
                                   order by (x.durum = 'bekliyor') desc, x.zaman desc)
                 from (select * from oyun.bakanlik_odenek_talep z where z.durum = 'bekliyor' or z.zaman > t - interval '14 days' order by z.zaman desc limit 30) x
                 join oyun.bakanliklar bk on bk.kod = x.kod left join oyun.profiller pr on pr.id = x.user_id), '[]'::jsonb));
end $function$;

-- manage
CREATE OR REPLACE FUNCTION public.bakanlik_yonetimi()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p oyun.profiller:=oyun.profilim();
BEGIN
 IF oyun.aktif_cb() IS DISTINCT FROM p.id THEN
  RAISE EXCEPTION 'Bakanlık kurma ve kapatma ekranı yalnız görevdeki Cumhurbaşkanına açıktır.';
 END IF;
 RETURN jsonb_build_object(
  'sinir',30,
  'alanlar',coalesce((SELECT jsonb_agg(jsonb_build_object('kod',s.alan,'ad',s.ad) ORDER BY s.ad) FROM oyun.bakanlik_sablonlar s),'[]'::jsonb),
  'bakanliklar',coalesce((SELECT jsonb_agg(jsonb_build_object(
    'kod',b.kod,'ad',b.ad,'aktif',b.aktif,'sistem',b.sistem,'alan',b.alan,
    'pay',coalesce(((SELECT u.butce FROM oyun.ulke u WHERE u.id=1)->>b.kod)::numeric,0),
    'kasa',coalesce(k.kasa,0),'bakan',oyun.kad(m.user_id),
    'kurulus_at',b.kurulus_at,'kapanis_at',b.kapanis_at,
    'kapanis_gerekce',b.kapanis_gerekce) ORDER BY b.sira)
   FROM oyun.bakanliklar b
   LEFT JOIN oyun.bakanlik_kasa k ON k.kod=b.kod
   LEFT JOIN LATERAL (SELECT x.user_id FROM oyun.makamlar x
    WHERE x.tur='bakan' AND x.bakanlik=b.kod AND x.bit IS NULL
    ORDER BY x.bas DESC LIMIT 1) m ON true),'[]'::jsonb)
 );
END $function$;

-- deputy
CREATE OR REPLACE FUNCTION oyun.bakanlik_vekili(p_user uuid, p_bakanlik text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select exists (select 1 from oyun.bakanliklar b where b.kod=p_bakanlik and b.aktif)
     and oyun.yurutme_user()=p_user
     and not exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik=p_bakanlik and bit is null)
$function$;

-- authority
CREATE OR REPLACE FUNCTION oyun.bm_yetki(p_user uuid, p_kod text)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select case
    when p_user is null or not exists(select 1 from oyun.bakanliklar b where b.kod=p_kod and b.aktif) then null
    when exists(select 1 from oyun.makamlar m where m.user_id = p_user and m.tur = 'bakan' and m.bakanlik = p_kod and m.bit is null) then 'bakan'
    when oyun.bakanlik_vekili(p_user, p_kod) then 'vekalet'
  end
$function$;

-- action
CREATE OR REPLACE FUNCTION public.icraat_yap(p_kod text, p_il integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); i oyun.icraatlar; m oyun.makamlar; son timestamptz; v_kasa numeric; ilad text;
        bk text; n int; toplam numeric; ek text := ''; vekalet_mi boolean := false;
begin
  select * into i from oyun.icraatlar where kod = p_kod;
  if i.kod is null then raise exception 'İcraat bulunamadı.'; end if;
  if not exists(select 1 from oyun.bakanliklar b where b.kod=i.bakanlik and b.aktif) then raise exception 'Kapalı bakanlık icraat yapamaz.'; end if;
  select * into m from oyun.makamlar where user_id = p.id and tur = 'bakan' and bit is null and bakanlik = i.bakanlik;
  vekalet_mi := m.id is null and oyun.bakanlik_vekili(p.id, i.bakanlik);     -- boş bakanlığa cumhurbaşkanı vekâlet eder
  if m.id is null and not vekalet_mi then raise exception 'Bu icraatı yalnızca ilgili bakan yapabilir; bakanlık boşsa cumhurbaşkanı vekâleten yapar.'; end if;
  if i.il_gerekli then
    select ad into ilad from oyun.iller where id = p_il;
    if ilad is null then raise exception 'Bir il seçmelisin.'; end if;
  else p_il := null; end if;
  select max(zaman) into son from oyun.icraat_kayit where kod = i.kod;
  if son is not null and son + make_interval(hours => i.bekleme_saat) > t then
    raise exception 'Bu icraat % tarihinden sonra tekrar yapılabilir.', to_char((son + make_interval(hours => i.bekleme_saat)) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  select k.kasa into v_kasa from oyun.bakanlik_kasa k where k.kod = i.bakanlik for update;
  if v_kasa < i.maliyet then raise exception 'Bakanlık kasasında yeterli ödenek yok (% milyar ₺ gerekli, kasada % var).', i.maliyet, round(v_kasa, 1); end if;
  update oyun.bakanlik_kasa set kasa = kasa - i.maliyet where kod = i.bakanlik;
  perform oyun.etki_uygula(i.etki, p_il::smallint);
  select ad into bk from oyun.bakanliklar where kod = i.bakanlik;
  -- oyunculara süreli etki
  perform oyun.etki_ekle(p_il::smallint, 'bakanlik', i.kod, bk || ' · ' || i.ad || coalesce(' (' || ilad || ')', ''), i.oyuncu, i.sure_gun, p.id, t);
  -- tek seferlik ödemeler
  if i.ozel = 'il_yardim' then
    insert into oyun.cuzdan(user_id, para, son_toplama) select id, (select baslangic_para from oyun.ayarlar where id = 1), t - interval '8 hours'
      from oyun.profiller where il_id = p_il on conflict do nothing;
    with h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select id, t, 3000, 'yardim', 'AFAD afet yardımı (' || ilad || ')' from oyun.profiller where il_id = p_il and not yasakli returning user_id)
    update oyun.cuzdan c set para = para + 3000 from h where c.user_id = h.user_id;
    get diagnostics n = row_count;
    ek := format(' %s oyuncuya 3.000''er ₺ ödendi.', n);
  elsif i.ozel = 'vergi_iade' then
    with v as (select user_id, round(sum(vergi) / 2) iade from oyun.hesap_hareket where vergi > 0 and zaman > t - interval '7 days' group by user_id),
         h as (insert into oyun.hesap_hareket(user_id, zaman, tutar, tur, aciklama)
               select user_id, t, iade, 'iade', 'Vergi iadesi (son 7 günün vergisinin yarısı)' from v where iade > 0 returning user_id, tutar)
    , c as (update oyun.cuzdan c set para = para + h.tutar from h where c.user_id = h.user_id returning h.tutar)
    select count(*), coalesce(sum(tutar), 0) into n, toplam from c;
    ek := format(' %s oyuncuya toplam %s ₺ iade edildi.', n, toplam);
  end if;
  insert into oyun.icraat_kayit(kod, bakan, il_id, zaman, maliyet) values (i.kod, p.id, p_il, t, i.maliyet);
  perform oyun.gazete_ekle('icraat', i.ad || coalesce(' — ' || ilad, ''),
    format('%s %s tarafından başlatıldı. %s Maliyet: %s milyar ₺.%s', case when vekalet_mi then bk || ' vekâleten Cumhurbaşkanı' else replace(bk, 'Bakanlığı', 'Bakanı') end, p.kad, i.aciklama, i.maliyet, ek), null, t);
  perform oyun.olay('icraat', format('%s: %s%s.', case when vekalet_mi then 'Cumhurbaşkanı ' || p.kad || ' (' || bk || ' vekâleten)' else (select replace(ad, 'Bakanlığı', 'Bakanı') from oyun.bakanliklar where kod = i.bakanlik) || ' ' || p.kad end, i.ad, coalesce(' (' || ilad || ')', '')), p_il::smallint, p.parti_id, t);
  return public.bakanlik_paneli();
end $function$;