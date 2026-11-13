begin;
-- =====================================================================
--  13.11.2026 · Avukat gözaltına alınınca müvekkilinin gözaltı dosyasındaki
--  görevi düşer, baro yerine başka avukat görevlendirir
--
--  Hata (beta, sohbet grubu): Gözaltındaki Turan River'ın avukatı Celal Kara
--  da gözaltına alındı. Celal "kabul" durumunda kaldığı için:
--   • Turan "Görevdeki bir avukatınız zaten var" uyarısıyla yeni avukat
--     çağıramadı, barodan müdafi isteyemedi;
--   • baro başkanı da "Bu dosyanın avukatı zaten görevde" uyarısı aldı;
--   • Celal kendisi gözaltında olduğu hâlde dosyada avukat görünüyordu.
--
--  Kural (Ercan): Avukat gözaltına alınınca savunduğu gözaltındaki kişiye
--  karşı sorumlulukları düşsün; baro başka bir avukat atasın.
--
--  Çözüm:
--   1) oyun.gozalti_avukat_dusur(avukat): avukatın üstlendiği/çağrıldığı tüm
--      aktif gözaltı dosyalarında görevi düşürür, müvekkile ve avukata bildirir,
--      baro adına uygun bir baro avukatını otomatik görevlendirir (aynı il ve
--      en az iş yüküne öncelik); uygun avukat yoksa talebi baroda bekletir.
--      Gözaltı başladığında (üç türde de) oyun.gozalti_basladi_bildir çağırır.
--   2) Tetikleyici: gözaltındaki bir avukat hiçbir yoldan (eski ya da yeni
--      ekran, baro) çağrılamaz, görev kabul edemez.
--   3) gozalti_avukat_ara listesi gözaltındaki avukatları göstermez.
--
--  Oyuncu verisi değişmez: yalnız işlev, tetikleyici; mevcut kayıtlarda
--  yalnız şu an gözaltındaki avukatların dosyaları (varsa) düşürülür.
-- =====================================================================

-- Baro adına otomatik müdafi seçimi
create or replace function oyun.gozalti_baro_avukat_sec(p_hedef uuid, p_yetkili uuid, p_haric uuid)
returns uuid language sql stable set search_path='' as $$
  select r.user_id
  from oyun.avukat_ruhsat r
  join oyun.profiller p on p.id=r.user_id
  join oyun.baro_uyeleri b on b.user_id=r.user_id and b.durum='aktif'
  where r.durum='aktif' and not coalesce(p.yasakli,false)
    and r.user_id is distinct from p_hedef and r.user_id is distinct from p_yetkili and r.user_id is distinct from p_haric
    and oyun.avukat_gorev_engeli(r.user_id) is null
    and oyun.gozalti_aktif(r.user_id) is null
  order by
    (p.il_id is not distinct from (select h.il_id from oyun.profiller h where h.id=p_hedef)) desc,
    ( (select count(*) from oyun.sokak_gozalti g where g.avukat=r.user_id and g.avukat_durum in ('cagrildi','kabul') and g.durum='aktif' and g.bitis>oyun.simdi())
    + (select count(*) from oyun.icisleri_tedbir_v2 k where k.avukat=r.user_id and k.avukat_durum in ('cagrildi','kabul') and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>oyun.simdi())
    + (select count(*) from oyun.yonetim_tutuklama y where y.avukat=r.user_id and y.avukat_durum in ('cagrildi','kabul') and y.durum='aktif' and y.bitis>oyun.simdi()) ) asc,
    random()
  limit 1
$$;

-- Gözaltına alınan avukatın müvekkil dosyalarındaki görevini düşür + baro yeni avukat görevlendirsin
create or replace function oyun.gozalti_avukat_dusur(p_avukat uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare r record; t timestamptz:=oyun.simdi(); bas uuid; yeni uuid; n int:=0; akad text;
begin
  if p_avukat is null then return 0; end if;
  akad := oyun.kad(p_avukat);
  for r in
    select 'sokak'::text kaynak, g.id, g.hedef, (select pl.yapan from oyun.sokak_polis pl where pl.id=g.polis_id) yetkili
      from oyun.sokak_gozalti g where g.avukat=p_avukat and g.avukat_durum in ('cagrildi','kabul') and g.durum='aktif' and g.bitis>t and g.hedef<>p_avukat
    union all
    select 'icisleri', k.id, k.hedef, k.bakan
      from oyun.icisleri_tedbir_v2 k where k.avukat=p_avukat and k.avukat_durum in ('cagrildi','kabul') and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>t and k.hedef<>p_avukat
    union all
    select 'yonetim', y.id, y.hedef, y.yetkili
      from oyun.yonetim_tutuklama y where y.avukat=p_avukat and y.avukat_durum in ('cagrildi','kabul') and y.durum='aktif' and y.bitis>t and y.hedef<>p_avukat
  loop
    n := n+1;
    -- 1) Görev düşer
    if r.kaynak='sokak' then
      update oyun.sokak_gozalti set avukat=null, avukat_durum='yok' where id=r.id;
    elsif r.kaynak='icisleri' then
      update oyun.icisleri_tedbir_v2 set avukat=null, avukat_durum='yok' where id=r.id;
    else
      update oyun.yonetim_tutuklama set avukat=null, avukat_durum='yok' where id=r.id;
    end if;
    perform oyun.bildir(p_avukat, format('⚖️ Gözaltına alındığınız için %s adlı müvekkilinizin gözaltı dosyasındaki (#%s) avukatlık göreviniz düştü. Baro yerinize başka avukat görevlendirir.', oyun.kad(r.hedef), r.id));

    -- 2) Baro yeni müdafi görevlendirir
    bas := oyun.baro_baskan();
    if bas is not null and oyun.gozalti_aktif(bas) is not null then bas := null; end if;
    yeni := oyun.gozalti_baro_avukat_sec(r.hedef, r.yetkili, p_avukat);

    if r.kaynak='sokak' then
      insert into oyun.sokak_baro_talep(gozalti_id,talep_eden,durum,basvuru,avukat,gorevlendiren,karar_zamani)
      values(r.id, r.hedef, case when yeni is null then 'bekliyor' else 'gorevlendirildi' end, t, yeni, case when yeni is null then null else coalesce(bas,yeni) end, case when yeni is null then null else t end)
      on conflict (gozalti_id) do update set durum=excluded.durum, talep_eden=excluded.talep_eden, basvuru=excluded.basvuru,
        avukat=excluded.avukat, gorevlendiren=excluded.gorevlendiren, karar_zamani=excluded.karar_zamani, gerekce=null;
      if yeni is not null then update oyun.sokak_gozalti set avukat=yeni, avukat_durum='cagrildi' where id=r.id; end if;
    else
      insert into oyun.gozalti_baro_talep(kaynak,dosya_id,talep_eden,durum,zaman,avukat,gorevlendiren,karar_zamani)
      values(r.kaynak, r.id, r.hedef, case when yeni is null then 'bekliyor' else 'gorevlendirildi' end, t, yeni, case when yeni is null then null else coalesce(bas,yeni) end, case when yeni is null then null else t end)
      on conflict (kaynak,dosya_id) do update set durum=excluded.durum, talep_eden=excluded.talep_eden, zaman=excluded.zaman,
        avukat=excluded.avukat, gorevlendiren=excluded.gorevlendiren, karar_zamani=excluded.karar_zamani;
      if yeni is not null then
        if r.kaynak='icisleri' then update oyun.icisleri_tedbir_v2 set avukat=yeni, avukat_durum='cagrildi' where id=r.id;
        else update oyun.yonetim_tutuklama set avukat=yeni, avukat_durum='cagrildi' where id=r.id; end if;
      end if;
    end if;

    if yeni is not null then
      perform oyun.bildir(r.hedef, format('⚖️ Avukatınız %s gözaltına alındığı için görevi düştü. Baro gözaltı #%s için size yeni avukat görevlendirdi: %s. Kabul edince yalnız onunla özel mesajlaşabilirsiniz. Dilerseniz Menü › Gözaltı ve Avukat ekranından başka avukat da çağırabilirsiniz.', akad, r.id, oyun.kad(yeni)));
      perform oyun.bildir(yeni, format('⚖️ Baro sizi gözaltındaki %s için (dosya #%s) müdafi olarak görevlendirdi; önceki avukatı %s gözaltına alındı. Menü › Gözaltı ve Avukat ekranından kabul edin.', oyun.kad(r.hedef), r.id, akad));
      if bas is not null and bas<>yeni then
        perform oyun.bildir(bas, format('⚖️ Gözaltı #%s (%s): avukatı %s gözaltına alındı; baro adına %s görevlendirildi. Gerekirse Menü › Gözaltı ve Avukat › Baro bölümünden değiştirebilirsiniz.', r.id, oyun.kad(r.hedef), akad, oyun.kad(yeni)));
      end if;
    else
      perform oyun.bildir(r.hedef, format('⚖️ Avukatınız %s gözaltına alındığı için görevi düştü. Barodan müdafi talebiniz otomatik açıldı (dosya #%s); dilerseniz Menü › Gözaltı ve Avukat ekranından kendiniz de avukat çağırabilirsiniz.', akad, r.id));
      if bas is not null then
        perform oyun.bildir(bas, format('⚖️ Gözaltı #%s (%s): avukatı %s gözaltına alındı, dosya avukatsız kaldı. Menü › Gözaltı ve Avukat › Baro bölümünden yeni müdafi gönderin.', r.id, oyun.kad(r.hedef), akad));
      end if;
    end if;
  end loop;
  return n;
end $$;

-- Gözaltı başlarken (sokak / içişleri / CB-İçişleri kararı) avukatlık görevleri düşer
create or replace function oyun.gozalti_basladi_bildir(p_hedef uuid, p_kaynak text, p_id bigint, p_bitis timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare bas uuid := oyun.baro_baskan();
begin
  perform oyun.bildir(p_hedef, format('🔒 Gözaltı dosyası #%s · bitiş %s. Gözaltı süresince hiçbir sohbete, paylaşıma ya da açıklamaya yazamazsınız; yalnız avukatınızla özel mesajlaşabilirsiniz. Avukat çağırmak ya da barodan müdafi istemek için: Menü › Gözaltı ve Avukat.',
    p_id, to_char(p_bitis at time zone 'Europe/Istanbul','DD.MM HH24:MI')));
  if bas is not null and bas<>p_hedef then
    perform oyun.bildir(bas, format('⚖️ Yeni gözaltı: %s (dosya #%s). Baro olarak müdafi gönderebilirsiniz: Menü › Gözaltı ve Avukat › Baro.', oyun.kad(p_hedef), p_id));
  end if;
  perform oyun.gozalti_avukat_dusur(p_hedef); -- gozalti_avukat_gozaltinda_20261113
end $$;

-- Gözaltındaki avukat hiçbir yoldan çağrılamaz / görev kabul edemez
create or replace function oyun.gozalti_avukat_gozaltinda_trg()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.avukat is not null and new.avukat_durum in ('cagrildi','kabul')
     and (new.avukat is distinct from old.avukat or new.avukat_durum is distinct from old.avukat_durum)
     and oyun.gozalti_aktif(new.avukat) is not null then
    raise exception 'Bu avukat şu anda gözaltında; gözaltı süresince avukatlık görevi alamaz. Başka bir avukat çağırın ya da barodan müdafi isteyin.'
      using errcode='P0001';
  end if;
  return new;
end $$;
drop trigger if exists gozalti_avukat_gozaltinda on oyun.sokak_gozalti;
create trigger gozalti_avukat_gozaltinda before update of avukat, avukat_durum on oyun.sokak_gozalti
  for each row execute function oyun.gozalti_avukat_gozaltinda_trg();
drop trigger if exists gozalti_avukat_gozaltinda on oyun.icisleri_tedbir_v2;
create trigger gozalti_avukat_gozaltinda before update of avukat, avukat_durum on oyun.icisleri_tedbir_v2
  for each row execute function oyun.gozalti_avukat_gozaltinda_trg();
drop trigger if exists gozalti_avukat_gozaltinda on oyun.yonetim_tutuklama;
create trigger gozalti_avukat_gozaltinda before update of avukat, avukat_durum on oyun.yonetim_tutuklama
  for each row execute function oyun.gozalti_avukat_gozaltinda_trg();

-- Avukat arama listesi gözaltındakileri göstermez
create or replace function public.gozalti_avukat_ara(p_ara text default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); q text:=lower(btrim(coalesce(p_ara,'')));
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('kad',x.kad,'il',x.il,'baro',x.baro) order by x.baro desc, x.kad) from (
    select p.kad, (select i.ad from oyun.iller i where i.id=p.il_id) il,
      exists(select 1 from oyun.baro_uyeleri b where b.user_id=p.id and b.durum='aktif') baro
    from oyun.avukat_ruhsat r join oyun.profiller p on p.id=r.user_id
    where r.durum='aktif' and r.user_id<>u and not coalesce(p.yasakli,false)
      and oyun.avukat_gorev_engeli(r.user_id) is null
      and oyun.gozalti_aktif(r.user_id) is null
      and (q='' or lower(p.kad) like '%'||q||'%')
    order by 3 desc, p.kad limit 25) x),'[]'::jsonb);
end $$;

do $$
declare f text;
begin
  foreach f in array array['oyun.gozalti_baro_avukat_sec(uuid,uuid,uuid)','oyun.gozalti_avukat_dusur(uuid)','oyun.gozalti_avukat_gozaltinda_trg()','oyun.gozalti_basladi_bildir(uuid,text,bigint,timestamptz)']
  loop
    execute 'revoke all on function '||f||' from public, anon, authenticated';
  end loop;
  execute 'revoke all on function public.gozalti_avukat_ara(text) from public, anon';
  execute 'grant execute on function public.gozalti_avukat_ara(text) to authenticated';
end $$;

-- Şu an gözaltında olup hâlâ başka gözaltındakinin avukatı görünen varsa düzelt
do $$
declare a uuid;
begin
  for a in
    select distinct x.av from (
      select g.avukat av from oyun.sokak_gozalti g where g.avukat is not null and g.avukat_durum in ('cagrildi','kabul') and g.durum='aktif' and g.bitis>oyun.simdi()
      union select k.avukat from oyun.icisleri_tedbir_v2 k where k.avukat is not null and k.avukat_durum in ('cagrildi','kabul') and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>oyun.simdi()
      union select y.avukat from oyun.yonetim_tutuklama y where y.avukat is not null and y.avukat_durum in ('cagrildi','kabul') and y.durum='aktif' and y.bitis>oyun.simdi()) x
    where oyun.gozalti_aktif(x.av) is not null
  loop
    perform oyun.gozalti_avukat_dusur(a);
  end loop;
end $$;
commit;
