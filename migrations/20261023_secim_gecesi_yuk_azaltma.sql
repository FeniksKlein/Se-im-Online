-- 23 Ekim 2026 · Seçim gecesi çöküşü sonrası yük azaltma
-- Canlı Supabase'e uygulandı (migration adları: cek_vade_islet_belirsiz_sutun_duzeltme,
-- tek_zamanlayici_cron_birlestirme, yuk_azaltma_onbellek_okunmamis_takvim, durum_takvim_hizli_ozet).
-- Oyuncu verisine dokunmaz. Tekrar çalıştırmak güvenlidir.
--
-- Ne değişti ve neden:
--  * 21:00'de seçim bitince bütün oyuncular aynı saniyede ana sayfayı yeniledi (her biri ~20 RPC).
--    Micro sunucu doldu; cron işleri "job startup timeout" ile başlayamadı, seçim motoru 2 saatte 23 kez çalışamadı.
--  * durum() ~134 ms → ~25 ms: takvimdeki her seçim için oy engeli artık yalnız sandık açıkken hesaplanıyor
--    (istemci oy_engeli alanını yalnız asama='oy' iken kullanıyor; diğer alanlar birebir aynı, 880 oyuncu×seçim karşılaştırıldı).
--  * rozetler() ~23 ms → ~5 ms: sohbet sayacında kanal listesi ve zaman bir kez hesaplanıyor (önceden satır başına
--    tekrar ediliyordu); tüm sayaçlar en fazla 100 sayıyor (ekran zaten "99+" gösteriyor). 44 oyuncuda sonuçlar birebir aynı.
--  * Seçim gecesi canlı ekranı: herkese aynı olan gece özeti 5 sn, ana sayfa kartı 10 sn sunucu önbelleğinden.
--  * 27 ayrı cron işi tek "oyun-zamanlayici" işine toplandı: her dakika tek bağlantı, adımlar sırayla, her adım
--    ayrı COMMIT; bir adım hata verirse diğerleri sürer, hata oyun.zamanlayici_adim tablosuna yazılır.
--    Eski işler silinmedi, yalnız pasif (active=false). Geri almak için en alttaki yorumlu komutlara bakın.
--  * cek_vade_islet(): "odenen" sütun/değişken çakışması yüzünden her 10 dakikada hata veriyordu; düzeltildi.
--
-- YENİ PERİYODİK İŞ EKLERKEN: cron.schedule yerine
--   insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira) values ('ad', 'select oyun.fonk()', 10, 3, 90);
-- (periyot 60'ı tam bölmeli; ofset, işlerin aynı dakikaya yığılmaması için).

begin;

-- ---------------------------------------------------------------------
-- 1) Çek vadesi işleyicisi: belirsiz sütun düzeltmesi
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyun.cek_vade_islet()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c oyun.cekler; toplam int:=0; v_odenen numeric; kalan numeric;
 t timestamptz:=oyun.simdi(); d date:=(oyun.simdi() at time zone 'Europe/Istanbul')::date;
begin
 for c in select ck.* from oyun.cekler ck
  where ck.durum='aktif' and ck.tarih<=d and ck.odenen<ck.tutar
  order by ck.tarih,ck.id for update skip locked limit 200
 loop
  begin
   kalan:=c.tutar-c.odenen;
   v_odenen:=oyun.cek_odeme_aktar(c.id,kalan,'ibraz');
   update oyun.cekler set ibraz_at=coalesce(ibraz_at,t) where id=c.id;
   if v_odenen<kalan then
     update oyun.cekler set durum='karsiliksiz',karsiliksiz_at=coalesce(karsiliksiz_at,t) where id=c.id;
     update oyun.banka_musteri set kredi_notu=greatest(300,kredi_notu-160)
       where user_id=c.duzenleyen and c.borclu_sirket is null;
     insert into oyun.bildirimler(user_id,zaman,metin) values
      (c.duzenleyen,t,'⚠️ Çek #'||c.id||' vadesinde karşılanamadı. Kalan '||(kalan-v_odenen)||
        ' TL. Kredi notun düştü; yeni çek defteri engellendi ve alacaklı icra başlatabilir.');
     if c.hamil is not null then
      insert into oyun.bildirimler(user_id,zaman,metin) values
       (c.hamil,t,'⚖️ Çek #'||c.id||' vadesinde karşılıksız kaldı. Çek Merkezi''nden icra takibi başlatabilirsin.');
     end if;
   end if;
   toplam:=toplam+1;
  exception when others then
   raise notice 'cek_vade_islet: çek % işlenemedi: %',c.id,sqlerrm;
  end;
 end loop;
 return toplam;
end $function$;

-- ---------------------------------------------------------------------
-- 2) Tek zamanlayıcı
-- ---------------------------------------------------------------------
create table if not exists oyun.zamanlayici_adim (
  adim text primary key,
  komut text not null,
  periyot_dk int not null default 1 check (periyot_dk between 1 and 60 and 60 % periyot_dk = 0),
  ofset_dk int not null default 0 check (ofset_dk between 0 and 59),
  sira int not null default 100,
  aktif boolean not null default true,
  son_calisma timestamptz,
  son_sure_ms int,
  son_hata text,
  son_hata_at timestamptz,
  hata_sayisi int not null default 0
);
alter table oyun.zamanlayici_adim enable row level security;
revoke all on oyun.zamanlayici_adim from anon, authenticated;

insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira) values
 ('secim_motoru',          'select oyun.tick()',                    1,  0, 10),
 ('secim_gecesi',          'select oyun.secim_gecesi_tick()',       1,  0, 20),
 ('halka_arz',             'select oyun.halka_arz_tick()',          1,  0, 30),
 ('yuksek_mahkeme',        'select oyun.mahkeme_tick()',            5,  0, 40),
 ('adliye_musadere',       'select oyun.adliye_musadere_tick()',    5,  0, 41),
 ('adliye_tazminat',       'select oyun.adliye_tazminat_tick()',    5,  0, 42),
 ('belediye_hizmet_ihale', 'select oyun.belediye_is_tick()',        5,  1, 43),
 ('siyaset_merkezi',       'select oyun.siyaset_merkezi_tick()',    5,  1, 44),
 ('meclis_arastirma',      'select oyun.meclis_arastirma_tick()',   5,  2, 45),
 ('siyasi_kurumlar',       'select oyun.siyasi_kurumlar_tick()',    5,  3, 46),
 ('turkiye_gundem_gazete', 'select oyun.ajans_derle()',             5,  4, 47),
 ('cek_vade',              'select oyun.cek_vade_islet()',          10, 0, 50),
 ('ekonomi_3',             'select oyun.ekonomi3_tick()',           10, 2, 51),
 ('uc_kitap_satis',        'select oyun.uc_kitap_tick()',           10, 3, 52),
 ('avukat_baro',           'select oyun.baro_tick()',               10, 4, 53),
 ('ekonomi_pazar',         'select oyun.pazar_tick()',              10, 5, 54),
 ('eko_otomasyon',         'select oyun.eko_otomasyon_tick()',      10, 6, 55),
 ('uc_etkinlik_bitir',     'select oyun.uc_etkinlik_tick()',        10, 7, 56),
 ('eko_ticaret',           'select oyun.eko_ticaret_tick()',        10, 8, 57),
 ('ekonomi_2',             'select oyun.ekonomi2_tick()',           10, 9, 58),
 ('gun_sonu',              'select oyun.gun_sonu_tick()',           15, 11, 60),
 ('belediye_sehir_bina',   'select oyun.belediye_bina_tick()',      30, 13, 61),
 ('bos_makam_firsat',      'select oyun.bos_makam_firsat_tick()',   30, 17, 62),
 ('kredi_karti_donem',     'select oyun.kart_donem_isle(null)',     60, 5, 70),
 ('belediye_kriz',         'select oyun.belediye_kriz_tick()',      60, 7, 71),
 ('ulke_krizi_sure',       'select oyun.kriz_tick(false)',          60, 19, 72),
 ('npc_isletme',           'select oyun.npc_isletme_tick()',        60, 21, 73)
on conflict (adim) do nothing;

CREATE OR REPLACE PROCEDURE oyun.zamanlayici_calistir()
 LANGUAGE plpgsql
AS $procedure$
declare
  simdi_dk timestamptz := date_trunc('minute', now());
  m int := extract(minute from now())::int;
  a record;
  adimlar text[];
  slot timestamptz;
  bas timestamptz;
  i int;
begin
  -- Önceki tur hâlâ sürüyorsa bu dakikayı atla; kaçan adımlar bir sonraki turda telafi edilir.
  if not pg_try_advisory_lock(hashtext('oyun.zamanlayici_calistir')) then
    return;
  end if;

  select array_agg(z.adim order by z.sira, z.adim) into adimlar
  from oyun.zamanlayici_adim z where z.aktif;

  if adimlar is not null then
    for i in 1 .. array_length(adimlar, 1) loop
      select * into a from oyun.zamanlayici_adim where adim = adimlar[i];
      -- Bu adımın en son planlanan dakikası; o dakikadan beri çalışmadıysa şimdi çalışır.
      slot := simdi_dk - make_interval(mins => (((m - a.ofset_dk) % a.periyot_dk) + a.periyot_dk) % a.periyot_dk);
      if a.son_calisma is null or a.son_calisma < slot then
        bas := clock_timestamp();
        begin
          perform set_config('lock_timeout', '10s', true);
          execute a.komut;
          update oyun.zamanlayici_adim
             set son_calisma = slot, son_sure_ms = (extract(epoch from clock_timestamp() - bas) * 1000)::int
           where adim = a.adim;
        exception when others then
          update oyun.zamanlayici_adim
             set son_calisma = slot,
                 son_sure_ms = (extract(epoch from clock_timestamp() - bas) * 1000)::int,
                 son_hata = left(sqlerrm, 500), son_hata_at = now(), hata_sayisi = hata_sayisi + 1
           where adim = a.adim;
        end;
        commit;
      end if;
    end loop;
  end if;

  perform pg_advisory_unlock(hashtext('oyun.zamanlayici_calistir'));
end $procedure$;

revoke all on procedure oyun.zamanlayici_calistir() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3) Kısa ömürlü genel önbellek
-- ---------------------------------------------------------------------
create unlogged table if not exists oyun.genel_onbellek (
  anahtar text primary key,
  veri jsonb,
  bitis timestamptz not null
);
alter table oyun.genel_onbellek enable row level security;
revoke all on oyun.genel_onbellek from anon, authenticated;

CREATE OR REPLACE FUNCTION oyun.onbellek_oku(p_anahtar text)
 RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $function$
  select g.veri from oyun.genel_onbellek g where g.anahtar = p_anahtar and g.bitis > clock_timestamp()
$function$;

CREATE OR REPLACE FUNCTION oyun.onbellek_yaz(p_anahtar text, p_veri jsonb, p_sure interval)
 RETURNS void LANGUAGE plpgsql SET search_path TO ''
AS $function$
begin
  insert into oyun.genel_onbellek(anahtar, veri, bitis) values (p_anahtar, p_veri, clock_timestamp() + p_sure)
  on conflict (anahtar) do update set veri = excluded.veri, bitis = excluded.bitis;
exception when others then
  -- salt-okunur işlemde ya da kilit çakışmasında önbelleği atla; sonuç yine döner
  null;
end $function$;

revoke all on function oyun.onbellek_oku(text) from public, anon, authenticated;
revoke all on function oyun.onbellek_yaz(text, jsonb, interval) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4) Okunmamış sayaçları
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyun.sohbet_okunmamis(p oyun.profiller)
 RETURNS integer LANGUAGE plpgsql STABLE
AS $function$
declare
  t timestamptz := oyun.simdi();
  kanallar text[];
  k text;
  n int;
  toplam int := 0;
begin
  select array_agg(distinct z.c) into kanallar
  from (select oyun.kanal_coz(p, x.kod) c
        from unnest(array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine']::text[]) x(kod)) z
  where z.c is not null;
  if kanallar is null then return 0; end if;
  foreach k in array kanallar loop
    select count(*) into n from (
      select 1
      from oyun.mesajlar m
      where m.kanal = k
        and m.id > coalesce((select r.son_id from oyun.kanal_okuma r where r.user_id = p.id and r.kanal = k), 0)
        and m.user_id <> p.id
        and not m.gizli
        and m.zaman <= t
        and m.zaman > t - interval '3 days'
        and not exists (select 1 from oyun.engellemeler e where e.engelleyen = p.id and e.engellenen = m.user_id)
      limit 100
    ) q;
    toplam := toplam + n;
  end loop;
  return toplam;
end $function$;

CREATE OR REPLACE FUNCTION oyun.okunmamis(p oyun.profiller)
 RETURNS jsonb LANGUAGE plpgsql STABLE
AS $function$
declare
  t timestamptz := oyun.simdi();
  b1 int; b2 int; oz int;
begin
  select count(*) into b1 from (
    select 1 from oyun.yayinlar y
    where not y.gizli and y.gonderen <> p.id
      and y.zaman > p.bildirim_okundu and y.zaman <= t
      and (y.hedef_il is null or y.hedef_il = p.il_id)
      and (y.hedef_parti is null or y.hedef_parti = p.parti_id)
      and not exists (select 1 from oyun.engellemeler e where e.engelleyen = p.id and e.engellenen = y.gonderen)
    limit 100) a;
  select count(*) into b2 from (
    select 1 from oyun.bildirimler b
    where b.user_id = p.id and b.zaman > p.bildirim_okundu and b.zaman <= t
    limit 100) a;
  select count(*) into oz from (
    select 1 from oyun.ozel o
    where o.alici = p.id and not o.okundu and not o.gizli
      and not exists (select 1 from oyun.engellemeler e where e.engelleyen = p.id and e.engellenen = o.gonderen)
    limit 100) a;
  return jsonb_build_object('bildirim', b1 + b2, 'ozel', oz, 'sohbet', oz + oyun.sohbet_okunmamis(p));
end $function$;

-- ---------------------------------------------------------------------
-- 5) Ana durum takvimi için hızlı seçim özeti (secim_ozet aynen kalır; seçim ekranı onu kullanır)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyun.secim_ozet_takvim(s oyun.secimler, p oyun.profiller, t timestamp with time zone)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO ''
AS $function$
declare
  a text := oyun.asama(s, t);
  bagimsiz boolean := p.parti_id is null and s.tur in ('mv_on','bel_on','cb_on');
  hedef bigint;
  ucret numeric;
begin
  if bagimsiz then
    hedef := oyun.bagimsiz_hedef_secim(s.id);
    ucret := oyun.aday_ucreti(null, s.tur, p.il_id);
  end if;
  return jsonb_build_object(
    'id', s.id, 'tur', s.tur, 'donem', s.donem, 'asama', a,
    'basvuru_bas', s.basvuru_bas, 'basvuru_bit', s.basvuru_bit,
    'oy_bas', s.oy_bas, 'oy_bit', s.oy_bit, 'sonuc_at', s.sonuc_at, 'goreve_bas', s.goreve_bas,
    'ara', s.ara, 'hedef_il_id', s.hedef_il_id,
    'hedef_il_ad', (select i.ad from oyun.iller i where i.id = s.hedef_il_id),
    'hedef_parti_id', s.hedef_parti_id,
    'hedef_parti', oyun.parti_json(s.hedef_parti_id),
    'ara_neden', s.ara_neden,
    'adayim', exists(select 1 from oyun.adaylar x where x.secim_id = s.id and x.user_id = p.id),
    'bagimsiz_adayim', case when bagimsiz then exists(
        select 1 from oyun.adaylar x where x.secim_id = hedef and x.user_id = p.id and x.parti_id is null)
      else false end,
    'bagimsiz_hedef_secim_id', case when bagimsiz then hedef end,
    'bagimsiz_ucret', case when bagimsiz then greatest(0, ucret - round(ucret * oyun.duz('aday_destek') / 100)) end,
    'oy_verdim', exists(select 1 from oyun.oylar o where o.secim_id = s.id and o.secmen = p.id),
    'oy_engeli', case when a = 'oy' then oyun.oy_engeli(p, s) end,
    'katilim', case when s.durum <> 'bekliyor' or t >= s.oy_bas
      then (select count(*) from oyun.oylar o where o.secim_id = s.id) end
  );
end $function$;

-- durum(): yalnız takvimdeki özet fonksiyonu değişir (gövdenin geri kalanı canlıdaki gibi kalır)
do $$
declare d text := pg_get_functiondef('public.durum()'::regprocedure);
begin
  if position('oyun.secim_ozet(s,p,t)' in d) > 0 then
    execute replace(d, 'oyun.secim_ozet(s,p,t)', 'oyun.secim_ozet_takvim(s,p,t)');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 6) Seçim gecesi: herkese aynı olan kısımlar önbellekten
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.secim_detay(p_secim bigint)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare r jsonb; s oyun.secimler; g jsonb;
begin
  r := oyun._secim_detay_ham(p_secim);
  select * into s from oyun.secimler where id = p_secim;
  if s.id is not null and s.tur in ('mv','cb','cb2') and oyun.secim_gecesi_aktif_mi(p_secim) then
    g := oyun.onbellek_oku('secim_gecesi_detay:' || p_secim);
    if g is null then
      g := jsonb_build_object(
        'sonuc', coalesce(oyun.secim_gecesi_filtre(s, r->'sonuc'), 'null'::jsonb),
        'gece', public.secim_gecesi(p_secim));
      perform oyun.onbellek_yaz('secim_gecesi_detay:' || p_secim, g, interval '5 seconds');
    end if;
    r := jsonb_set(r, '{sonuc}', g->'sonuc') || jsonb_build_object('gece', g->'gece');
  end if;
  return r;
end $function$;

CREATE OR REPLACE FUNCTION public.secim_gecesi_aktif()
 RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path TO ''
AS $function$
declare r jsonb;
begin
  r := oyun.onbellek_oku('secim_gecesi_aktif');
  if r is not null then return r; end if;
  select coalesce(jsonb_agg(jsonb_build_object('secim_id', g.secim_id, 'tur', s.tur,
           'bitis', g.baslangic + make_interval(secs => g.sure_sn),
           'yuzde', (oyun.secim_gecesi_ozet(g.secim_id))->'yuzde') order by g.secim_id), '[]'::jsonb)
    into r
  from oyun.secim_gecesi g join oyun.secimler s on s.id = g.secim_id
  where oyun.secim_gecesi_aktif_mi(g.secim_id);
  perform oyun.onbellek_yaz('secim_gecesi_aktif', r, interval '10 seconds');
  return r;
end $function$;

grant execute on function public.secim_gecesi_aktif() to authenticated;
grant execute on function public.secim_detay(bigint) to authenticated;

-- ---------------------------------------------------------------------
-- 7) cuzdan_ozet: durum() her çağrıda cüzdan satırını FOR UPDATE ile kilitliyordu (cuzdanim üzerinden).
--    Cüzdan bugün açılmışsa kilitsiz okunur; günün ilk çağrısında ya da cüzdan yoksa eskisi gibi cuzdanim çalışır.
--    44 oyuncuda çıktı birebir aynı (migration: cuzdan_ozet_kilitsiz_okuma).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION oyun.cuzdan_ozet(u uuid, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
declare c oyun.cuzdan; g jsonb;
begin
  select * into c from oyun.cuzdan where user_id = u;
  if c.user_id is null or c.gun is distinct from (oyun.simdi() at time zone 'Europe/Istanbul')::date then
    c := oyun.cuzdanim(u);
  end if;
  g := oyun.gelir_hesap(u, t);
  return jsonb_build_object('para', c.para, 'birikmis', g -> 'birikmis', 'dolu', g -> 'dolu',
                            'gunun_ilki', c.seri_gun is distinct from (t at time zone 'Europe/Istanbul')::date);
end $function$;

commit;

-- ---------------------------------------------------------------------
-- 8) Cron geçişi (bir kez, ayrı çalıştırılır; tekrar çalıştırmak zararsızdır)
-- ---------------------------------------------------------------------
-- update oyun.zamanlayici_adim z set son_calisma =
--   date_trunc('minute', now()) - make_interval(mins => (((extract(minute from now())::int - z.ofset_dk) % z.periyot_dk) + z.periyot_dk) % z.periyot_dk)
--   where son_calisma is null;
-- select cron.alter_job(jobid, active := false) from cron.job where jobname in (
--  'secim-motoru','secim-gecesi','halka-arz','yuksek-mahkeme','adliye-musadere-tahsil','adliye-tazminat-tahsil',
--  'belediye-hizmet-ihale','siyaset-merkezi','meclis-arastirma','siyasi-kurumlar','turkiye-gundem-otomatik-gazete',
--  'cek-vade-otomatik-20261023','ekonomi-3','uc-kitap-satis','avukat-baro','ekonomi-pazar','eko_otomatik_uretim_kendi_tedarik',
--  'uc-etkinlik-bitir','eko-ticaret-periyodik','ekonomi-2','gun-sonu','belediye-sehir-bina-tick','bos-makam-firsat',
--  'oyun-kredi-karti-donem-kontrol','belediye-kriz','ulke_krizi_sure_20261010','npc-isletme-hourly');
-- select cron.schedule('oyun-zamanlayici', '* * * * *', 'call oyun.zamanlayici_calistir()');
--
-- GERİ ALMA (gerekirse): eski işleri aç, yeni işi kapat
-- select cron.alter_job(jobid, active := true) from cron.job where jobname in (...yukarıdaki liste...);
-- select cron.alter_job(jobid, active := false) from cron.job where jobname = 'oyun-zamanlayici';
--
-- İZLEME: select adim, son_calisma, son_sure_ms, hata_sayisi, son_hata from oyun.zamanlayici_adim order by sira;

-- ---------------------------------------------------------------------
-- 9) meclis_baskanlik(): okuma yolunda genel kilit beklemesin (migration: meclis_baskanlik_kilitsiz_tick)
--    Önceden her çağrı oyun.meclis_tick() içindeki pg_advisory_xact_lock ile sıraya giriyordu; seçim gecesi
--    milletvekillerinin ana sayfası 8 sn bekleyip 500 alıyordu. oyun.tick() her dakika meclis_tick'i zaten çalıştırır.
-- ---------------------------------------------------------------------
do $$
declare d text := pg_get_functiondef('public.meclis_baskanlik()'::regprocedure);
begin
  if position('  perform oyun.meclis_tick(t);' in d) > 0 then
    d := replace(d, '  perform oyun.meclis_tick(t);',
'  if oyun.onbellek_oku(''meclis_tick_okuma'') is null and pg_try_advisory_xact_lock(hashtext(''oyun.meclis_tick'')) then
    perform oyun.meclis_tick(t);
    perform oyun.onbellek_yaz(''meclis_tick_okuma'', ''true''::jsonb, interval ''15 seconds'');
  end if;');
    execute d;
  end if;
end $$;
-- Not: yük testinde kullanılan geçici "yuk_testi" şeması zararsızdır (yalnız postgres çağırabilir); silmek için:
-- drop schema if exists yuk_testi cascade;
