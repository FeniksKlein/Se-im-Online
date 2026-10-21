-- Seçim Simülasyonu Online · 2026-10-22 · Yönetici Kontrol Merkezi — ONAY GEREKEN BÖLÜM
-- Bu dosyadaki fonksiyonların içinde "silme" (delete) komutu geçtiği için Supabase onay ister.
-- İçerik: (1) hata yalıtımlı oyun motoru, (2) veri düzenleyicide satır silme, (3) göreve atama,
-- (4) parti görevinden alma, (5) zamanlayıcı geçmişi temizliği. Oyuncu verisini değiştirmez; iki kez çalıştırmak güvenlidir.
-- Kullanım: Supabase › SQL Editor › New query › bu dosyanın TAMAMINI yapıştır › Run.
begin;

create or replace function oyun.tick() returns integer language plpgsql set search_path = oyun, public, pg_temp as $$
declare t timestamptz := oyun.simdi(); ay date; r record; n int := 0; atla bigint[] := '{}'; h text; b text;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay := date_trunc('month', t at time zone 'Europe/Istanbul')::date;
  begin
    perform oyun.donem_olustur(ay); perform oyun.donem_olustur((ay + interval '1 month')::date);
  exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('donem_olustur', h, b); end;
  if (select son_temizlik from oyun.ayarlar where id = 1) is distinct from (t at time zone 'Europe/Istanbul')::date then
    begin
      delete from oyun.mesajlar where zaman < t - interval '30 days'; delete from oyun.yayinlar where zaman < t - interval '30 days'; delete from oyun.bildirimler where zaman < t - interval '60 days';
      delete from oyun.ozel where zaman < t - interval '90 days'; delete from oyun.push_kuyruk where olusturma < now() - interval '7 days';
      delete from oyun.tick_hata where son < now() - interval '14 days';
      update oyun.ayarlar set son_temizlik = (t at time zone 'Europe/Istanbul')::date where id = 1;
    exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('gunluk_temizlik', h, b); end;
  end if;
  -- Seçim sonuçları ve göreve başlamalar: biri hata verirse o seçim bu dakika atlanır, diğerleri işler
  loop
    select * into r from (
      select id, sonuc_at as zaman, 0 as asama, oyun.oncelik(tur) o from oyun.secimler where durum = 'bekliyor' and sonuc_at <= t
      union all select id, goreve_bas, 1, oyun.oncelik(tur) from oyun.secimler where durum = 'sonuclandi' and goreve_bas <= t
    ) x where not (x.id = any(atla)) order by zaman, asama, o limit 1;
    exit when not found;
    begin
      if r.asama = 0 then perform oyun.sonuclandir(r.id); else perform oyun.goreve_baslat(r.id); end if;
    exception when others then
      get stacked diagnostics h = message_text, b = pg_exception_context;
      atla := atla || r.id;
      perform oyun.tick_hata_yaz(case when r.asama = 0 then 'sonuclandir #' else 'goreve_baslat #' end || r.id, h, b);
    end;
    n := n + 1; exit when n > 200;
  end loop;
  begin perform oyun.kanun_tick(t);          exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('kanun_tick', h, b); end;
  begin perform oyun.mevzuat_tick(t);        exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('mevzuat_tick', h, b); end;
  begin perform oyun.meclis_tick(t);         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('meclis_tick', h, b); end;
  begin perform oyun.mahkeme_toplu_tick(t);  exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('mahkeme_toplu_tick', h, b); end;
  begin perform oyun.parti_tuzuk_tick(t);    exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('parti_tuzuk_tick', h, b); end;
  begin perform oyun.siyasi_tick(t);         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('siyasi_tick', h, b); end;
  begin perform oyun.guvenlik_tick(t);       exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('guvenlik_tick', h, b); end;
  begin perform oyun.gunluk_ekonomi(t);      exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('gunluk_ekonomi', h, b); end;
  begin perform oyun.banka_tick(t);          exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('banka_tick', h, b); end;
  begin perform oyun.meclis_olcek_uygula(t); exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('meclis_olcek_uygula', h, b); end;
  begin perform oyun.ihmal_tick(t);          exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('ihmal_tick', h, b); end;
  begin perform oyun.miting_tick(t);         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('miting_tick', h, b); end;
  begin perform oyun.yk_engel_tick(t);       exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('yk_engel_tick', h, b); end;
  begin perform oyun.push_hatirlatmalar(t);  exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('push_hatirlatmalar', h, b); end;
  begin perform oyun.push_tetikle();         exception when others then get stacked diagnostics h = message_text, b = pg_exception_context; perform oyun.tick_hata_yaz('push_tetikle', h, b); end;
  return n;
end $$;

create or replace function oyun.yk_sil(p oyun.profiller, p_t regclass, p_anahtar jsonb, p_islem text default 'sil', p_aciklama text default null)
returns jsonb language plpgsql as $$
declare pk text[] := oyun.yk_pk(p_t); kosul text; once jsonb; tad text := oyun.yk_ad(p_t);
begin
  if pk is null then raise exception 'Bu tablonun birincil anahtarı yok; satır silinemez.'; end if;
  if p_anahtar is null or exists (select 1 from unnest(pk) c where not (p_anahtar ? c)) then raise exception 'Satır anahtarı eksik.'; end if;
  kosul := (select string_agg(format('t.%I = k.%I', c, c), ' and ') from unnest(pk) c);
  execute format('delete from %s t using jsonb_populate_record(null::%s, $1) k where %s returning to_jsonb(t)', tad, tad, kosul) into once using p_anahtar;
  if once is null then raise exception 'Satır bulunamadı (zaten silinmiş olabilir).'; end if;
  perform oyun.yk_kaydet_log(p, p_t, p_islem, oyun.yk_anahtar(p_t, once), once, null, p_aciklama);
  return once;
end $$;

-- Makam ver. p_tur: cb, cb_yardimcisi (p_sira 1/2), bakan (p_bakanlik), mv (p_il), bel (p_il), tbmm, bskv, grup_bskv, gb, gby (p_sira 1-6)
create or replace function public.yk_makam_ver(p_kad text, p_tur text, p_il int default null, p_bakanlik text default null, p_sira int default null, p_tek_gorev boolean default true)
returns jsonb language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi();
        m record; v_ad text; bak text; kota int; dolu int; pa oyun.partiler; eski uuid;
begin
  perform oyun.korunan_hedef(p, h.id);
  if h.yasakli then raise exception 'Engelli hesaba görev verilemez. Önce engeli kaldır.'; end if;
  if p_tur not in ('cb','cb_yardimcisi','bakan','mv','bel','tbmm','bskv','grup_bskv','gb','gby') then raise exception 'Geçersiz görev türü.'; end if;
  if p_tur in ('mv','bel') and (p_il is null or not exists (select 1 from oyun.iller where id = p_il)) then raise exception 'İl seçmelisin.'; end if;
  if p_tur = 'bakan' then
    select kod into bak from oyun.bakanliklar where kod = p_bakanlik;
    if bak is null then raise exception 'Bakanlık seçmelisin.'; end if;
  elsif p_tur = 'cb_yardimcisi' then
    if p_sira not in (1, 2) or p_sira is null then raise exception 'Yardımcılık sırası 1 ya da 2 olmalı.'; end if;
    bak := p_sira::text;
  end if;
  if p_tur in ('gb','gby','grup_bskv') then
    select * into pa from oyun.partiler where id = h.parti_id;
    if pa.id is null or pa.kapali then raise exception '% bir partiye üye değil. Önce partisini belirle.', h.kad; end if;
  end if;
  if p_tur = 'gby' and (p_sira is null or p_sira not between 1 and 6) then raise exception 'Genel başkan yardımcılığı sırası 1-6 olmalı.'; end if;

  -- zaten aynı görevde mi?
  if p_tur = 'gb' and pa.gb = h.id then raise exception '% zaten genel başkan.', h.kad; end if;
  if p_tur not in ('gb','gby') and exists (select 1 from oyun.makamlar where user_id = h.id and bit is null and tur = p_tur
        and (p_tur not in ('mv','bel') or il_id = p_il) and (p_tur not in ('bakan','cb_yardimcisi') or bakanlik = bak)) then
    raise exception '% zaten bu görevde.', h.kad;
  end if;

  -- tek görev kuralı: uyumsuz görevleri bitir
  if p_tek_gorev then
    for m in select id, tur from oyun.makamlar where user_id = h.id and bit is null loop
      if not oyun.rol_uyumlu(m.tur, p_tur) or (m.tur = p_tur and p_tur not in ('bakan')) then
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end if;
    end loop;
    if p_tur <> 'gb' and not oyun.rol_uyumlu('gb', p_tur) then update oyun.partiler set gb = null where gb = h.id; end if;
    if p_tur <> 'gby' and not oyun.rol_uyumlu('gby', p_tur) then delete from oyun.parti_gby where user_id = h.id; end if;
  end if;

  if p_tur = 'gb' then
    update oyun.partiler set gb = h.id where id = pa.id;
    v_ad := pa.kisa || ' Genel Başkanlığı';
  elsif p_tur = 'gby' then
    select user_id into eski from oyun.parti_gby where parti_id = pa.id and sira = p_sira;
    delete from oyun.parti_gby where parti_id = pa.id and (sira = p_sira or user_id = h.id);
    insert into oyun.parti_gby(parti_id, sira, user_id, atama) values (pa.id, p_sira, h.id, t);
    if eski is not null and eski <> h.id then perform oyun.bildir(eski, format('%s genel başkan yardımcılığı görevin oyun yönetimi kararıyla sona erdi.', pa.kisa), t); end if;
    v_ad := pa.kisa || ' ' || p_sira || '. Genel Başkan Yardımcılığı';
  else
    -- tek kişilik koltuklar: mevcut sahibi görevden alınır
    if p_tur in ('cb','tbmm','bel','bakan','cb_yardimcisi') then
      for m in select id, user_id from oyun.makamlar where bit is null and tur = p_tur and user_id <> h.id
               and (p_tur <> 'bel' or il_id = p_il) and (p_tur not in ('bakan','cb_yardimcisi') or bakanlik = bak) loop
        perform oyun.makam_bitir(m.id, t, 'yonetici_karari');
        perform oyun.bildir(m.user_id, format('Oyun yönetimi kararıyla %s görevin sona erdi.', oyun.makam_ad(p_tur, p_il::smallint, bak)), t);
      end loop;
    end if;
    if p_tur = 'mv' then
      select mv into kota from oyun.iller where id = p_il;
      select count(*) into dolu from oyun.makamlar where tur = 'mv' and bit is null and il_id = p_il;
      if kota is not null and dolu >= kota then raise exception '% ilinin % milletvekilliği dolu. Önce bir vekili görevden al.', (select i.ad from oyun.iller i where i.id = p_il), kota; end if;
    end if;
    insert into oyun.makamlar(tur, user_id, il_id, parti_id, bakanlik, kaynak, bas)
    values (p_tur, h.id, case when p_tur in ('mv','bel') then p_il end, h.parti_id, bak, 'atama', t);
    v_ad := oyun.makam_ad(p_tur, p_il::smallint, bak);
  end if;
  perform oyun.bildir(h.id, format('Oyun yönetimi seni %s görevine atadı. Hayırlı olsun!', v_ad), t);
  perform oyun.olay('makam', format('%s, %s görevine atandı.', h.kad, v_ad), case when p_tur in ('mv','bel') then p_il::smallint end, h.parti_id, t);
  perform oyun.mod_log(p, 'yk_makam_ver', h.kad, v_ad);
  return public.yk_oyuncu(h.kad);
end $$;

-- Parti görevinden al: gb / gby
create or replace function public.yk_parti_gorev_al(p_kad text, p_rol text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); pk text;
begin
  perform oyun.korunan_hedef(p, h.id);
  select kisa into pk from oyun.partiler where id = h.parti_id;
  if p_rol = 'gb' then
    update oyun.partiler set gb = null where gb = h.id;
    if not found then raise exception '% genel başkan değil.', h.kad; end if;
    perform oyun.bildir(h.id, format('Oyun yönetimi kararıyla %s genel başkanlığın sona erdi.', coalesce(pk, 'parti')), t);
  elsif p_rol = 'gby' then
    delete from oyun.parti_gby where user_id = h.id;
    if not found then raise exception '% genel başkan yardımcısı değil.', h.kad; end if;
    perform oyun.bildir(h.id, format('Oyun yönetimi kararıyla %s genel başkan yardımcılığın sona erdi.', coalesce(pk, 'parti')), t);
  else raise exception 'Geçersiz parti görevi.'; end if;
  perform oyun.mod_log(p, 'yk_parti_gorev_al', h.kad, p_rol);
  return public.yk_oyuncu(h.kad);
end $$;

revoke all on function public.yk_makam_ver(text,text,int,text,int,boolean) from public, anon;
grant execute on function public.yk_makam_ver(text,text,int,text,int,boolean) to authenticated;
revoke all on function public.yk_parti_gorev_al(text,text) from public, anon;
grant execute on function public.yk_parti_gorev_al(text,text) to authenticated;

commit;

-- Zamanlayıcı geçmişi temizliği (günde bir, son 7 gün tutulur)
select cron.schedule('cron-gecmis-temizlik', '23 3 * * *', $$delete from cron.job_run_details where end_time < now() - interval '7 days'$$);
