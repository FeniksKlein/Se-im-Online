-- 26.11.2026 · Yardım Masası kapatma anahtarı + Yönetime Yaz destek talebi otomatik görevli ataması
-- Canlı migration'lar: yardim_masasi_kapatma_anahtari, yardim_masasi_yazma_kapat, yardim_masasi_herkesten_gizle,
--   destek_talep_otomatik_atama, destek_aday_mod_yuk_dengesi, sohbet_ozet_gorevli_bayragi (26.11 akşam)
--
-- Yardım Masası (herkese açık 'yardim' kanalı): Ercan'ın kararıyla kapatıldı (ayarlar.yardim_masasi_acik=false).
--   Kapalıyken sohbet listesinde kimseye görünmez (yardim_ozet null), oyuncu okuyamaz/yazamaz; görevliler arşivi okuyabilir,
--   yazamaz. Kısayollara dokunan oyuncu "Ben › Yönetime Yaz"a yönlendirilir. Yeniden açmak: ayarlar.yardim_masasi_acik=true.
--   sohbet_ozet dönüşüne üst düzey 'gorevli' eklendi: istemcinin "Mod" sekmesi artık Yardım Masası'na bağlı değil.
-- Destek ataması (Ercan: "talebe bir mod atansın, tüm modlar görsün, yardım bitince kapatılsın"):
--   - Yeni/yeniden açılan talep (durum 'yeni'), çevrimiçi (10 dk), sözleşmeli, yasaksız bir moderatöre atanır:
--     en az açık talebi olan; kendi masasındaki görevli 2 talep avantajlı. Kurucu masası atanmaz (Ercan'a gider).
--   - Görevliye bildirim; oyuncuya ilk atamada "Talebin #N Oyun Yöneticisi G-07'ye iletildi".
--   - 30 dakika görevli yanıtı yoksa başka çevrimiçi görevliye devredilir. Çevrimiçi görevli yoksa atanmaz, sonra atanır.
--   - Yanıt veren görevli talebi üstlenmiş sayılır; "Üstlen" RPC'si (mod_kutu_ustlen) ile de alınabilir.
--   - Yanıtlanmış ama 48 saat yeni mesaj gelmeyen talep kendiliğinden kapanır. Yanıt bekleyen talep kendiliğinden kapanmaz.
--   - Bütün moderatörler talepleri görmeye ve yanıtlamaya devam eder (mod_kutu_gorur değişmedi).
--   - pg_cron 'destek_atama_tick' 5 dakikada bir.

-- Yardım Masası anahtarı (yeni kurulumda da kapalı başlar; canlıda sütun zaten var)
alter table oyun.ayarlar add column if not exists yardim_masasi_acik boolean not null default false;

create or replace function oyun.yardim_acik()
returns boolean language sql stable security definer set search_path to '' as $$
 select coalesce((select yardim_masasi_acik from oyun.ayarlar where id=1), true);
$$;

CREATE OR REPLACE FUNCTION oyun.kanal_hata(kod text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  select case when kod like 'og:%' then 'Bu sohbet grubunun üyesi değilsin ya da grup kapatıldı.'
  else case kod
    when 'yardim' then 'Yardım Masası kapatıldı. Soru, şikâyet ve destek talepleri için Ben › Yönetime Yaz bölümünü kullanabilirsin.'
    when 'ittifak' then 'İttifak sohbetine yalnızca üye partilerin genel başkanları, yönetimi, il başkanları ve milletvekilleri girebilir.'
    when 'kabine' then 'Bakanlar Kurulu sohbetine yalnızca cumhurbaşkanı ve bakanlar girebilir.'
    when 'yonetim' then 'Parti yönetimi sohbetine yalnızca genel başkan ve genel başkan yardımcıları girebilir.'
    when 'grup' then 'Meclis grubu sohbetine yalnızca partinin milletvekilleri ve genel başkanı girebilir.'
    when 'divan' then 'Başkanlık Divanı sohbetine TBMM Başkanı, başkanvekilleri ve grup başkanvekilleri girebilir.'
    else 'Parti sohbeti için bir partiye üye olmalısın.' end end
$function$;

CREATE OR REPLACE FUNCTION oyun.kanal_coz(p oyun.profiller, p_kanal text)
 RETURNS text LANGUAGE plpgsql STABLE SET search_path TO ''
AS $function$
declare gid bigint;
begin
  if p_kanal like 'og:%' then
    if p_kanal !~ '^og:[0-9]{1,18}$' then return null; end if;
    gid := substr(p_kanal, 4)::bigint;
    if oyun.sgrup_uye_mi(gid, p.id) then return 'og:' || gid; end if;
    return null;
  end if;
  if p_kanal = 'yardim' then
    if oyun.yardim_acik() or oyun.yardim_gorevli_mi(p) then return 'yardim'; end if;
    return null;
  end if;
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'belediye' then 'belediye:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (
      select 'ittifak:' || u.ittifak_id
      from oyun.ittifak_uyeler u
      join oyun.partiler pa on pa.id = u.parti_id
      where u.parti_id = p.parti_id
        and not pa.kapali
        and (
          pa.gb = p.id
          or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = p.id)
          or exists (select 1 from oyun.parti_teskilat_gorev tg where tg.parti_id = pa.id and tg.user_id = p.id and tg.aktif)
          or exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null)
        )
    )
    when 'kabine' then case when exists (
      select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('cb','bakan','cb_yardimcisi')
    ) then 'kabine' end
    when 'grup' then case
      when oyun.aktif_mv_parti(p.id) is not null then 'grup:' || oyun.aktif_mv_parti(p.id)
      when exists (select 1 from oyun.partiler pa where pa.gb = p.id and pa.id = p.parti_id) then 'grup:' || p.parti_id end
    when 'divan' then case when exists (
      select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('tbmm','bskv','grup_bskv')
    ) then 'divan' end
    when 'yonetim' then (
      select 'yonetim:' || pa.id from oyun.partiler pa
      where pa.id = p.parti_id and not pa.kapali
        and (pa.gb = p.id or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = p.id))
    )
    else null end;
end $function$;

CREATE OR REPLACE FUNCTION oyun.kanal_yazabilir(p oyun.profiller, kod text)
 RETURNS boolean LANGUAGE sql STABLE SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
  select case kod
    when 'meclis' then oyun.meclis_yazabilir(p.id)
    when 'belediye' then exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null and m.tur in ('bel','mv') and m.il_id = p.il_id)
    when 'yardim' then oyun.yardim_acik()
    else true end
$function$;

CREATE OR REPLACE FUNCTION oyun.kanal_yaz_hata(kod text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
  select case kod
    when 'belediye' then 'Belediye meclisinde yalnızca o ilin belediye başkanı ve milletvekilleri söz alabilir; herkes izleyebilir.'
    when 'yardim' then 'Yardım Masası kapatıldı. Soru, şikâyet ve destek talepleri için Ben › Yönetime Yaz bölümünü kullanabilirsin.'
    else 'Genel Kurul''da yalnızca milletvekilleri, bakanlar ve cumhurbaşkanı söz alabilir.' end
$function$;

CREATE OR REPLACE FUNCTION oyun.yardim_ozet(p oyun.profiller, t timestamp with time zone)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO ''
AS $function$
declare imlec bigint; okunmamis int; son jsonb; gorevli boolean; bekleyen int;
begin
  -- Yardım Masası kapalıyken sohbet listesinde kimseye (görevliler dahil) gösterilmez.
  if not oyun.yardim_acik() then return null; end if;
  gorevli := oyun.yardim_gorevli_mi(p);
  select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = 'yardim';
  select count(*) into okunmamis from (
    select 1 from oyun.mesajlar m where m.kanal = 'yardim' and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
       and m.zaman <= t and m.zaman > t - interval '3 days' and (m.gorevli or not oyun.engelli(p.id, m.user_id)) limit 100) x;
  select jsonb_build_object('kad', case when m.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
                            'metin', m.metin, 'zaman', m.zaman, 'gorevli', m.gorevli) into son
    from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
   where m.kanal = 'yardim' and not m.gizli and m.zaman <= t and (m.gorevli or not oyun.engelli(p.id, m.user_id))
   order by m.id desc limit 1;
  if gorevli then
    select count(*) into bekleyen from (
      select 1 from oyun.mesajlar m where m.kanal = 'yardim' and not m.gizli and not m.gorevli and m.zaman <= t and m.zaman > t - interval '24 hours'
         and m.id > coalesce((select max(g.id) from oyun.mesajlar g where g.kanal = 'yardim' and g.gorevli and not g.gizli), 0) limit 100) z;
  end if;
  return jsonb_build_object('kanal', 'yardim', 'baslik', 'Yardım Masası', 'kilit', null, 'yazabilir', true,
    'okunmamis', okunmamis, 'son', son, 'sinyal', 'sohbet:yardim', 'gorevli', gorevli, 'bekleyen', bekleyen);
end $function$;

CREATE OR REPLACE FUNCTION public.yardim_yanitla(p_metin text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m text;
begin
  if not oyun.yardim_gorevli_mi(p) then
    raise exception 'Yardım Masası''nda oyun yönetimi adına yalnız oyun yöneticileri yanıt verebilir.';
  end if;
  if not oyun.yardim_acik() then
    raise exception 'Yardım Masası kapalı. Oyunculara Ben › Yönetime Yaz talepleri üzerinden yanıt verebilirsin.';
  end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 1500);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman, gorevli) values ('yardim', p.id, m, t, true);
  update oyun.profiller set son_mesaj = t where id = p.id;
  perform oyun.mod_log(p, 'yardim_yanit', null, m);
  return jsonb_build_object('tamam', true);
end $function$;

-- Sohbet özetinde üst düzey görevli bayrağı ("Mod" sekmesi Yardım Masası'ndan bağımsız)
select oyun._yama('public.sohbet_ozet()',
  'jsonb_build_object(''yardim'', oyun.yardim_ozet(p, t),',
  'jsonb_build_object(''gorevli'', oyun.yardim_gorevli_mi(p), ''yardim'', oyun.yardim_ozet(p, t),',
  '''gorevli'', oyun.yardim_gorevli_mi(p)', true);

-- ---------------------------------------------------------------------------------------------
-- Destek talebi otomatik ataması
alter table oyun.destek_talep add column if not exists atanan uuid references oyun.profiller(id) on delete set null;
alter table oyun.destek_talep add column if not exists atama_zaman timestamptz;
alter table oyun.destek_talep add column if not exists atama_sayisi int not null default 0;
create index if not exists destek_talep_atanan_idx on oyun.destek_talep(atanan) where durum <> 'kapali';
create index if not exists destek_talep_durum_idx on oyun.destek_talep(durum, son_hareket);

-- Uygun görevli: çevrimiçi (10 dk), sözleşmeli, yasaksız moderatör; talep sahibi/şikâyet edilen değil.
-- Yük dengesi: kendi masasındaki görevli, başka masadakine göre 2 talep avantajlı.
create or replace function oyun.destek_aday_mod(p_id bigint, p_t timestamptz, p_haric uuid)
returns uuid language sql stable security definer set search_path to '' as $$
 select m.user_id
 from oyun.destek_talep d
 join oyun.moderatorler m on true
 join oyun.profiller pr on pr.id = m.user_id
 where d.id = p_id
   and m.sozlesme_at is not null
   and not coalesce(pr.yasakli, false) and not coalesce(pr.yonetici, false)
   and pr.son_gorulme > p_t - interval '10 minutes'
   and m.user_id <> d.user_id and m.user_id is distinct from d.hedef
   and m.user_id is distinct from p_haric
 order by (select count(*) from oyun.destek_talep z where z.atanan = m.user_id and z.durum = 'yeni')
          + case when m.ana_gorev = coalesce(d.masa, 'oyuncu') then 0 else 2 end asc,
          pr.son_gorulme desc, random()
 limit 1;
$$;

create or replace function oyun.destek_ata(p_id bigint, p_t timestamptz, p_haric uuid default null)
returns uuid language plpgsql security definer set search_path to '' as $$
declare d oyun.destek_talep; u uuid; v_konu text;
begin
  select * into d from oyun.destek_talep where id = p_id for update;
  if d.id is null or d.durum <> 'yeni' or coalesce(d.masa, 'oyuncu') = 'kurucu' then return null; end if;
  u := oyun.destek_aday_mod(p_id, p_t, p_haric);
  if u is null then return null; end if;
  update oyun.destek_talep set atanan = u, atama_zaman = p_t, atama_sayisi = atama_sayisi + 1 where id = d.id;
  v_konu := coalesce((select k.ad from oyun.destek_konu_tanim() k where k.kod = d.konu), initcap(coalesce(d.kategori, 'destek')));
  perform oyun.bildir(u, format('Sana destek talebi atandı: #%s (%s). Moderasyon Merkezi › Talep kutusu. 30 dakika içinde yanıtlanmazsa başka bir görevliye geçer.', d.id, v_konu), p_t);
  if d.atama_sayisi = 0 then
    perform oyun.bildir(d.user_id, format('Talebin #%s %s''ne iletildi. Yanıtı Ben › Yönetime Yaz bölümünde göreceksin.',
      d.id, (select oyun.mod_imza(pr) from oyun.profiller pr where pr.id = u)), p_t);
  end if;
  return u;
end $$;

create or replace function oyun.tg_destek_talep_ata()
returns trigger language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi();
begin
  if pg_trigger_depth() > 1 then return null; end if;
  if new.durum <> 'yeni' or coalesce(new.masa, 'oyuncu') = 'kurucu' then return null; end if;
  if new.atanan is null then
    perform oyun.destek_ata(new.id, t, null);
  elsif tg_op = 'UPDATE' and old.durum is distinct from 'yeni' then
    -- oyuncu karşılık yazdı: atanan görevli haberdar edilir, 30 dk süresi yeniden başlar
    update oyun.destek_talep set atama_zaman = t where id = new.id;
    perform oyun.bildir(new.atanan, format('Destek talebi #%s: oyuncu yeni mesaj yazdı. Moderasyon Merkezi › Talep kutusu.', new.id), t);
  end if;
  return null;
end $$;

drop trigger if exists destek_talep_ata on oyun.destek_talep;
create trigger destek_talep_ata after insert or update of durum on oyun.destek_talep
  for each row execute function oyun.tg_destek_talep_ata();

-- 5 dakikada bir: atanmamışları ata, 30 dk yanıtsızları devret, 48 saat hareketsiz yanıtlanmışları kapat (sınırlı, kayıt başına hata yalıtımlı)
create or replace function oyun.destek_atama_tick()
returns void language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi(); r record;
begin
  for r in select id from oyun.destek_talep
            where durum = 'yeni' and coalesce(masa, 'oyuncu') <> 'kurucu' and atanan is null
            order by zaman limit 200 loop
    begin perform oyun.destek_ata(r.id, t, null); exception when others then raise warning 'destek_ata #%: %', r.id, sqlerrm; end;
  end loop;
  for r in select d.id, d.atanan from oyun.destek_talep d
            where d.durum = 'yeni' and coalesce(d.masa, 'oyuncu') <> 'kurucu' and d.atanan is not null
              and d.atama_zaman < t - interval '30 minutes'
              and not exists (select 1 from oyun.destek_mesaj m where m.talep_id = d.id and m.gorevli and m.zaman >= d.atama_zaman)
            order by d.zaman limit 200 loop
    begin
      if oyun.destek_ata(r.id, t, r.atanan) is not null then
        perform oyun.bildir(r.atanan, format('Destek talebi #%s 30 dakika yanıtsız kaldığı için başka bir görevliye devredildi.', r.id), t);
      end if;
    exception when others then raise warning 'destek devir #%: %', r.id, sqlerrm; end;
  end loop;
  for r in update oyun.destek_talep set durum = 'kapali', son_hareket = t
            where durum = 'yanitlandi' and coalesce(son_hareket, yanit_zaman, zaman) < t - interval '48 hours'
            returning id, user_id loop
    perform oyun.bildir(r.user_id, format('Talebin #%s 48 saat yeni mesaj gelmediği için kapatıldı. Yeni bir sorunun olursa Ben › Yönetime Yaz''dan yeni talep açabilirsin.', r.id), t);
  end loop;
end $$;

revoke all on function oyun.destek_aday_mod(bigint,timestamptz,uuid), oyun.destek_ata(bigint,timestamptz,uuid), oyun.destek_atama_tick() from public, anon, authenticated;

do $cron$
begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobid) from cron.job where jobname = 'destek_atama_tick';
    perform cron.schedule('destek_atama_tick', '*/5 * * * *', 'select oyun.destek_atama_tick()');
  end if;
end $cron$;

-- Görevli üstlenme
create or replace function public.mod_kutu_ustlen(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); d oyun.destek_talep; t timestamptz := oyun.simdi();
begin
  select * into d from oyun.destek_talep where id = p_id for update;
  if d.id is null or not oyun.mod_kutu_gorur(p, d) then raise exception 'Talep bulunamadı ya da senin masanda değil.'; end if;
  if d.durum = 'kapali' then raise exception 'Bu talep kapatılmış.'; end if;
  if d.atanan = p.id then raise exception 'Bu talep zaten sende.'; end if;
  update oyun.destek_talep set atanan = p.id, atama_zaman = t, atama_sayisi = atama_sayisi + 1 where id = d.id;
  if d.atanan is not null then
    perform oyun.bildir(d.atanan, format('Destek talebi #%s %s tarafından üstlenildi; artık sende değil.', d.id, oyun.mod_kod(p.id)), t);
  end if;
  perform oyun.mod_log(p, 'destek_ustlen', oyun.kad(d.user_id), format('#%s', d.id));
  return public.mod_kutu('acik');
end $$;
revoke all on function public.mod_kutu_ustlen(bigint) from public, anon;
grant execute on function public.mod_kutu_ustlen(bigint) to authenticated;

-- Yanıt veren görevli talebi üstlenmiş sayılır (kurucu yanıtında mevcut atama korunur)
CREATE OR REPLACE FUNCTION public.mod_kutu_yanitla(p_id bigint, p_metin text, p_kapat boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); d oyun.destek_talep; t timestamptz := oyun.simdi(); m text := nullif(btrim(coalesce(p_metin, '')), '');
begin
  select * into d from oyun.destek_talep where id = p_id for update;
  if d.id is null or not oyun.mod_kutu_gorur(p, d) then raise exception 'Talep bulunamadı ya da senin masanda değil.'; end if;
  if d.durum = 'kapali' then raise exception 'Bu talep kapatılmış.'; end if;
  if m is null and not coalesce(p_kapat, false) then raise exception 'Yanıt yaz (2-1000 karakter).'; end if;
  if m is not null and (char_length(m) < 2 or char_length(m) > 1000) then raise exception 'Yanıt 2-1000 karakter olmalı.'; end if;
  if m is not null then insert into oyun.destek_mesaj (talep_id, yazan, gorevli, metin, zaman) values (d.id, p.id, true, m, t); end if;
  update oyun.destek_talep set yanit = coalesce(m, yanit), yanit_zaman = case when m is not null then t else yanit_zaman end,
         yanitlayan = p.id, durum = case when p_kapat then 'kapali' else 'yanitlandi' end, okundu = false, son_hareket = t,
         atanan = case when coalesce(p.yonetici, false) then coalesce(atanan, p.id) else p.id end, atama_zaman = t
   where id = d.id;
  perform oyun.bildir(d.user_id, case when m is not null then format('Talebine yanıt geldi (#%s, %s): %s%s', d.id, oyun.mod_imza(p), left(m, 300), case when p_kapat then ' · Talep kapatıldı.' else ' · Ben › Yönetime Yaz''dan karşılık yazabilirsin.' end)
                                      else format('Talebin #%s kapatıldı (%s).', d.id, oyun.mod_imza(p)) end, t);
  perform oyun.mod_log(p, case when p_kapat then 'destek_kapat' else 'destek_yanit' end, oyun.kad(d.user_id), format('#%s %s', d.id, coalesce(left(m, 200), '')));
  return public.mod_kutu('acik');
end $function$;

-- Eski moderasyon ekranının yanıt işlevi: kapalı talebe mesaj eklenmesi hatası düzeltildi, atama işlendi
CREATE OR REPLACE FUNCTION public.mod_destek_yanitla(p_id bigint, p_metin text, p_kapat boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.yetki_zorunlu('destek'); d oyun.destek_talep; t timestamptz := oyun.simdi(); m text := nullif(btrim(coalesce(p_metin, '')), '');
begin
  select * into d from oyun.destek_talep where id = p_id for update;
  if d.id is null or not oyun.mod_kutu_gorur(p, d) then raise exception 'Destek talebi bulunamadı.'; end if;
  if d.durum = 'kapali' then raise exception 'Bu talep kapatılmış.'; end if;
  if m is null and not coalesce(p_kapat, false) then raise exception 'Yanıt yaz (2-1000 karakter).'; end if;
  if m is not null and (char_length(m) < 2 or char_length(m) > 1000) then raise exception 'Yanıt 2-1000 karakter olmalı.'; end if;
  if m is not null then insert into oyun.destek_mesaj (talep_id, yazan, gorevli, metin, zaman) values (d.id, p.id, true, m, t); end if;
  update oyun.destek_talep set yanit = coalesce(m, yanit), yanit_zaman = case when m is not null then now() else yanit_zaman end,
         yanitlayan = p.id, durum = case when p_kapat then 'kapali' else 'yanitlandi' end, okundu = false, son_hareket = t,
         atanan = case when coalesce(p.yonetici, false) then coalesce(atanan, p.id) else p.id end, atama_zaman = t
   where id = d.id;
  perform oyun.bildir(d.user_id, case when m is not null then format('Destek yanıtı (talep #%s, %s): %s', d.id, oyun.mod_imza(p), m)
                                      else format('Destek talebin #%s kapatıldı (%s).', d.id, oyun.mod_imza(p)) end, t);
  perform oyun.mod_log(p, case when p_kapat then 'destek_kapat' else 'destek_yanit' end, oyun.kad(d.user_id), format('#%s %s', d.id, coalesce(left(m, 200), '')));
  return public.mod_destek('acik');
end $function$;

-- JSON: atanan görevli (oyuncuya görev unvanı, görevliye kod + bana_atandi)
CREATE OR REPLACE FUNCTION oyun.destek_talep_json(x oyun.destek_talep, p_gorevli boolean)
 RETURNS jsonb LANGUAGE sql STABLE SET search_path TO ''
AS $function$
  select jsonb_build_object('id', x.id, 'konu', coalesce(x.konu, x.kategori),
    'konu_ad', coalesce((select k.ad from oyun.destek_konu_tanim() k where k.kod = x.konu), case x.konu when 'yonetim' then 'Oyun yönetiminden mesaj' when 'yonetim_uyari' then 'Oyun yönetiminden uyarı' else initcap(x.kategori) end),
    'durum', x.durum, 'zaman', x.zaman, 'son_hareket', coalesce(x.son_hareket, x.yanit_zaman, x.zaman), 'okundu', x.okundu,
    'hedef', oyun.kad(x.hedef), 'metin', x.metin,
    'gorevli_ad', case when x.atanan is not null then (select oyun.mod_imza(pr) from oyun.profiller pr where pr.id = x.atanan) end,
    'mesajlar', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'gorevli', m.gorevli, 'metin', m.metin, 'zaman', m.zaman,
                    'yazan', case when not m.gorevli then 'oyuncu' when p_gorevli then oyun.mod_kod(m.yazan) || case when coalesce((select pv.yonetici from oyun.profiller pv where pv.id = auth.uid()), false) then ' · ' || oyun.kad(m.yazan) else '' end
                                  else (select oyun.mod_imza(pr) from oyun.profiller pr where pr.id = m.yazan) end) order by m.id)
                  from oyun.destek_mesaj m where m.talep_id = x.id),
               case when x.yanit is not null then jsonb_build_array(jsonb_build_object('gorevli', true, 'metin', x.yanit, 'zaman', x.yanit_zaman, 'yazan', 'Oyun yönetimi')) else '[]'::jsonb end))
     || case when p_gorevli then jsonb_build_object('kad', oyun.kad(x.user_id), 'surum', x.surum, 'platform', x.platform,
                 'masa', coalesce(x.masa, 'oyuncu'),
                 'masa_ad', case coalesce(x.masa, 'oyuncu') when 'kurucu' then 'Kurucu' else oyun.mod_birim_ad(coalesce(x.masa, 'oyuncu')) end,
                 'onceki', (select count(*) from oyun.destek_talep z where z.user_id = x.user_id and z.id <> x.id),
                 'hedef_sikayet', case when x.hedef is not null then (select count(*) from oyun.destek_talep z where z.hedef = x.hedef and z.id <> x.id) end,
                 'atanan_kod', case when x.atanan is not null then oyun.mod_kod(x.atanan) || case when coalesce((select pv.yonetici from oyun.profiller pv where pv.id = auth.uid()), false) then ' · ' || oyun.kad(x.atanan) else '' end end,
                 'bana_atandi', x.atanan is not null and x.atanan = auth.uid())
             else '{}'::jsonb end
$function$;

-- Talep kutusu: bana atananlar en üstte
CREATE OR REPLACE FUNCTION public.mod_kutu(p_durum text DEFAULT 'acik'::text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); t timestamptz := oyun.simdi(); v_acik boolean := coalesce(p_durum, 'acik') <> 'tum';
begin
  return jsonb_build_object(
    'masalar', (select jsonb_agg(jsonb_build_object('kod', b.kod, 'ad', b.ad) order by b.sira) from oyun.mod_birim_tanim() b),
    'yonetici', coalesce(p.yonetici, false),
    'bana_atanan', (select count(*) from oyun.destek_talep z where z.atanan = p.id and z.durum = 'yeni'),
    'talepler', coalesce((select jsonb_agg(q.j order by q.ben desc, q.yeni desc, q.s) from (
        select oyun.destek_talep_json(d, true) j, (d.atanan is not null and d.atanan = p.id and d.durum = 'yeni') ben, (d.durum = 'yeni') yeni, coalesce(d.son_hareket, d.zaman) s
          from oyun.destek_talep d
         where ((v_acik and d.durum = 'yeni') or (not v_acik and d.zaman > t - interval '30 days')) and oyun.mod_kutu_gorur(p, d)
         order by (d.atanan is not null and d.atanan = p.id and d.durum = 'yeni') desc, (d.durum = 'yeni') desc, coalesce(d.son_hareket, d.zaman) limit 100) q), '[]'::jsonb));
end $function$;
