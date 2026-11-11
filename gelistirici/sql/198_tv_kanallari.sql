-- =====================================================================
--  198 (11.11.2026) · TV KANALLARI: CANLI PROGRAM, SİYASİ DÜELLO, SUNUCU VE REKLAM (Ercan)
--  • Oyuncu TV kanalı kurar (250.000 ₺ yayın lisansı, Hazine'ye). Kanalın kendi kasası vardır.
--  • Kanal sahibi maaşlı sunucu alır: günlük ücret teklif eder, oyuncu kabul ederse sözleşme başlar; ücret her gün
--    kanal kasasından ödenir. Kasa yetmezse sözleşme sona erer. Sahip dilediğinde çıkarır, sunucu dilediğinde ayrılır.
--  • Program: sahip ya da sunucu, başlığı ve saatini belirleyerek açar (hemen ya da 14 gün içinde bir tarih/saat;
--    süre 10–180 dk ya da "sunucu bitirene kadar"). Tür: siyasi düello, söyleşi, haber. Sunucu en çok 6 konuk çağırır.
--  • Yayın saati gelince program kendiliğinden canlıya geçer; sunucu ve kabul eden konuklar canlı yazışır.
--    Herkes kanal menüsünden "yayını izle" ile izler; izleyenlerin sayısı ve adları görünür. İzleyiciler alkışlar/
--    yuhalar, düelloda "en ikna edici kim" oyunu kullanır. Sunucu yayını dilediği an bitirir; süre dolunca kendiliğinden biter.
--  • Reklam: kanal sahibi "izleyici başına ücret" belirler. Kişiler cüzdanından, şirket yöneticileri şirket kasasından
--    bir programa bütçeli reklam verir; sahip onaylar. Program bitince kanal, izleyici × birim ücret kadar (en çok bütçe)
--    kazanır; %10 reklam vergisi Hazine'ye, artan bütçe reklamverene iade. Onaylanmayan/iptal edilen reklam tümüyle iade.
--    Kanal sahibi kendi kanalına reklam veremez; sahibinin ortak/yönetici olduğu şirketler de veremez.
--  Mevcut canlı yayın (basın toplantısı, gazete programı) sistemi aynen durur; bu modül ayrı tablolarla çalışır.
-- =====================================================================

create table if not exists oyun.tv_kanal(
  id bigserial primary key, ad text not null, slogan text, sahip uuid not null, kasa numeric not null default 0,
  izleyici_ucret numeric not null default 250 check (izleyici_ucret between 50 and 2000),
  kurulus timestamptz not null, aktif boolean not null default true);
create unique index if not exists tv_kanal_ad_tek on oyun.tv_kanal(lower(ad)) where aktif;
create table if not exists oyun.tv_hareket(
  id bigserial primary key, kanal_id bigint not null references oyun.tv_kanal(id), zaman timestamptz not null, tutar numeric not null, tur text not null, aciklama text);
create index if not exists tv_hareket_k on oyun.tv_hareket(kanal_id, id desc);
create table if not exists oyun.tv_sunucu(
  kanal_id bigint not null references oyun.tv_kanal(id), user_id uuid not null, gunluk_ucret numeric not null,
  durum text not null default 'teklif' check (durum in ('teklif','aktif','ret','ayrildi','cikarildi')),
  teklif_at timestamptz not null, bas timestamptz, bitis timestamptz, son_odeme date, toplam numeric not null default 0, primary key (kanal_id, user_id));
create table if not exists oyun.tv_program(
  id bigserial primary key, kanal_id bigint not null references oyun.tv_kanal(id), sunucu uuid not null,
  tur text not null check (tur in ('duello','soylesi','haber')), baslik text not null, aciklama text,
  bas timestamptz not null, bit timestamptz not null, acik_uclu boolean not null default false,
  durum text not null default 'planli' check (durum in ('planli','canli','bitti','iptal')),
  gercek_bas timestamptz, gercek_bit timestamptz, olusturan uuid not null, olusturma timestamptz not null,
  izleyici int not null default 0, hesaplandi boolean not null default false, sonuc_yazildi boolean not null default false);
create index if not exists tv_program_durum on oyun.tv_program(durum, bas);
create index if not exists tv_program_kanal on oyun.tv_program(kanal_id, id desc);
create table if not exists oyun.tv_konuk(
  program_id bigint not null references oyun.tv_program(id), user_id uuid not null,
  durum text not null default 'davet' check (durum in ('davet','kabul','ret')), zaman timestamptz not null, primary key (program_id, user_id));
create table if not exists oyun.tv_mesaj(
  id bigserial primary key, program_id bigint not null references oyun.tv_program(id), user_id uuid not null,
  rol text not null, metin text not null, zaman timestamptz not null, gizli boolean not null default false);
create index if not exists tv_mesaj_p on oyun.tv_mesaj(program_id, id);
create table if not exists oyun.tv_izleyici(
  program_id bigint not null references oyun.tv_program(id), user_id uuid not null, ilk timestamptz not null, son timestamptz not null,
  primary key (program_id, user_id));
create table if not exists oyun.tv_tepki(
  program_id bigint not null references oyun.tv_program(id), user_id uuid not null,
  tur text not null check (tur in ('alkis','yuh')), zaman timestamptz not null, primary key (program_id, user_id));
create table if not exists oyun.tv_oy(
  program_id bigint not null references oyun.tv_program(id), user_id uuid not null, konuk uuid not null, zaman timestamptz not null,
  primary key (program_id, user_id));
create table if not exists oyun.tv_reklam(
  id bigserial primary key, kanal_id bigint not null references oyun.tv_kanal(id), program_id bigint not null references oyun.tv_program(id),
  veren uuid not null, sirket_id bigint, marka text not null, metin text not null, butce numeric not null check (butce > 0), birim numeric not null,
  durum text not null default 'bekliyor' check (durum in ('bekliyor','onay','ret','iptal','yayinlandi','iade')),
  olusturma timestamptz not null, karar_at timestamptz, odenen numeric not null default 0, vergi numeric not null default 0, iade numeric not null default 0);
create index if not exists tv_reklam_p on oyun.tv_reklam(program_id);
do $r$ declare x text; begin
  foreach x in array array['tv_kanal','tv_hareket','tv_sunucu','tv_program','tv_konuk','tv_mesaj','tv_izleyici','tv_tepki','tv_oy','tv_reklam'] loop
    execute format('alter table oyun.%I enable row level security', x);
    execute format('revoke all on oyun.%I from anon, authenticated', x);
  end loop;
end $r$;

-- ---------------------------------------------------------------- yardımcılar
-- Boş metinde hata vermeyen temizleyici (metin_temizle boş metni reddeder)
create or replace function oyun.metin_ops(m text, n integer) returns text language sql set search_path = '' as $$
  select case when m is null or btrim(m) = '' then '' else oyun.metin_temizle(m, n) end
$$;
revoke all on function oyun.metin_ops(text, integer) from public, anon, authenticated;
create or replace function oyun.tv_sinyal(p_program bigint) returns void language plpgsql set search_path = '' as $$
begin
  if to_regprocedure('oyun.canli_sinyal(text)') is not null then perform oyun.canli_sinyal('yayin:tv' || p_program::text); end if;
exception when others then null;
end $$;
create or replace function oyun.tv_tur_ad(p text) returns text language sql immutable set search_path = '' as $$
  select case p when 'duello' then 'Siyasi düello' when 'soylesi' then 'Söyleşi' else 'Haber programı' end
$$;
create or replace function oyun.tv_yayinci_mi(p_kanal bigint, u uuid) returns boolean language sql stable set search_path = '' as $$
  select exists (select 1 from oyun.tv_kanal k where k.id = p_kanal and k.aktif and k.sahip = u)
      or exists (select 1 from oyun.tv_sunucu s join oyun.tv_kanal k on k.id = s.kanal_id and k.aktif where s.kanal_id = p_kanal and s.user_id = u and s.durum = 'aktif')
$$;
create or replace function oyun.tv_reklam_orani() returns numeric language sql stable set search_path = '' as $$
  select coalesce((select least(0.5, greatest(0, reklam_vergisi)) from oyun.pano_ayar order by id limit 1), 0.10)
$$;
create or replace function oyun.tv_reklam_iade(r oyun.tv_reklam, p_tutar numeric, p_aciklama text, t timestamptz) returns void language plpgsql set search_path = '' as $$
begin
  if coalesce(p_tutar, 0) <= 0 then return; end if;
  if r.sirket_id is not null and exists (select 1 from oyun.sirketler where id = r.sirket_id and aktif) then
    update oyun.sirketler set kasa = kasa + p_tutar where id = r.sirket_id;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar) values (r.sirket_id, t, p_tutar, p_aciklama, 0, 0, 0);
  else
    perform oyun.para_islem(r.veren, p_tutar, 'iade', p_aciklama, t);
  end if;
end $$;

-- Program bitişi: reklam hesabı (izleyici × birim, en çok bütçe; vergi; artan iade)
create or replace function oyun.tv_program_hesapla(p_program bigint) returns void language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; r oyun.tv_reklam; n int; nn int; hak numeric; v_vergi numeric; oran numeric := oyun.tv_reklam_orani();
  gelir numeric := 0; iptal boolean;
begin
  select * into pr from oyun.tv_program where id = p_program for update;
  if pr.id is null or pr.hesaplandi or pr.durum not in ('bitti','iptal') then return; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id for update;
  iptal := pr.durum = 'iptal';
  select count(*) into n from oyun.tv_izleyici where program_id = pr.id;
  for r in select * from oyun.tv_reklam where program_id = pr.id and durum in ('bekliyor','onay') order by id for update loop
    if iptal or r.durum = 'bekliyor' then
      perform oyun.tv_reklam_iade(r, r.butce, format('%s reklam bütçesi iadesi (%s)', k.ad, case when iptal then 'program iptal' else 'onaylanmadı' end), t);
      update oyun.tv_reklam set durum = 'iade', iade = r.butce, karar_at = t where id = r.id;
      perform oyun.bildir(r.veren, format('%s kanalındaki "%s" programı için verdiğin reklamın bütçesi (%s ₺) iade edildi: %s.', k.ad, pr.baslik, oyun.tl(r.butce),
        case when iptal then 'program iptal edildi' else 'kanal reklamı onaylamadı' end), t);
    else
      nn := greatest(0, n - (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id and z.user_id = r.veren)::int);
      hak := least(r.butce, nn * r.birim);
      v_vergi := round(hak * oran);
      update oyun.tv_reklam set durum = 'yayinlandi', odenen = hak, vergi = v_vergi, iade = r.butce - hak, karar_at = t where id = r.id;
      if hak > 0 then
        insert into oyun.tv_hareket(kanal_id, zaman, tutar, tur, aciklama) values (k.id, t, hak - v_vergi, 'reklam',
          format('%s reklamı · "%s" · %s izleyici × %s ₺ (vergi %s ₺)', r.marka, pr.baslik, nn, oyun.tl(r.birim), oyun.tl(v_vergi)));
        if v_vergi > 0 then perform oyun.hazine_kaydet('dolayli_vergi', v_vergi / oyun.pazar_tl_milyar(), k.ad || ' TV reklam vergisi'); end if;
        gelir := gelir + hak - v_vergi;
      end if;
      perform oyun.tv_reklam_iade(r, r.butce - hak, format('%s reklamı: kullanılmayan bütçe iadesi', k.ad), t);
      perform oyun.bildir(r.veren, format('%s kanalındaki "%s" programında reklamın yayınlandı: %s izleyici × %s ₺ = %s ₺ ödendi, %s ₺ iade edildi.',
        k.ad, pr.baslik, nn, oyun.tl(r.birim), oyun.tl(hak), oyun.tl(r.butce - hak)), t);
    end if;
  end loop;
  if gelir > 0 then update oyun.tv_kanal set kasa = kasa + gelir where id = k.id; end if;
  update oyun.tv_program set izleyici = n, hesaplandi = true where id = pr.id;
  if not iptal then
    perform oyun.bildir(k.sahip, format('%s · "%s" programı bitti: %s izleyici, %s ₺ reklam geliri kanal kasasına geçti.', k.ad, pr.baslik, n, oyun.tl(gelir)), t);
  end if;
end $$;

-- Saat gelince canlıya geçir, süre dolunca bitir
create or replace function oyun.tv_program_guncelle(p_program bigint) returns oyun.tv_program language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; r record;
begin
  select * into pr from oyun.tv_program where id = p_program;
  if pr.id is null or pr.durum in ('bitti','iptal') or (pr.durum = 'planli' and t < pr.bas) or (pr.durum = 'canli' and t < pr.bit) then return pr; end if;
  select * into pr from oyun.tv_program where id = p_program for update;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  if pr.durum = 'planli' and t >= pr.bas then
    update oyun.tv_program set durum = 'canli', gercek_bas = pr.bas where id = pr.id returning * into pr;
    for r in select * from oyun.tv_reklam where program_id = pr.id and durum = 'onay' order by id loop
      insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, r.veren, 'reklam', r.marka || ': ' || r.metin, pr.bas);
    end loop;
    if t < pr.bit then
      perform oyun.bildir(x.user_id, format('%s · "%s" programı başladı. Konuksun: Gündem › TV Kanalları''ndan stüdyoya gir.', k.ad, pr.baslik), t)
         from oyun.tv_konuk x where x.program_id = pr.id and x.durum = 'kabul';
      if pr.sunucu is distinct from pr.olusturan or pr.olusturma < t - interval '2 minutes' then
        perform oyun.bildir(pr.sunucu, format('%s · "%s" programın yayında. Stüdyoya gir.', k.ad, pr.baslik), t); end if;
      perform oyun.olay('basin', format('%s canlı yayında: "%s" (%s, sunucu %s).', k.ad, pr.baslik, oyun.tv_tur_ad(pr.tur), oyun.kad(pr.sunucu)), null, null, t);
    end if;
    perform oyun.tv_sinyal(pr.id);
  end if;
  if pr.durum = 'canli' and t >= pr.bit then
    update oyun.tv_program set durum = 'bitti', gercek_bit = pr.bit where id = pr.id returning * into pr;
    perform oyun.tv_program_hesapla(pr.id);
    perform oyun.tv_sinyal(pr.id);
    select * into pr from oyun.tv_program where id = p_program;
  end if;
  return pr;
end $$;

create or replace function oyun.tv_guncelle_hepsi() returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); r record; n int := 0; kaz record;
begin
  for r in select id from oyun.tv_program where (durum = 'planli' and bas <= t) or (durum = 'canli' and bit <= t) order by id loop
    perform oyun.tv_program_guncelle(r.id); n := n + 1;
  end loop;
  -- düello sonucu: oylama program bittikten 15 dakika sonra kapanır
  for r in select p.*, k.ad kanal from oyun.tv_program p join oyun.tv_kanal k on k.id = p.kanal_id
            where p.durum = 'bitti' and not p.sonuc_yazildi and p.gercek_bit <= t - interval '15 minutes' loop
    if r.tur = 'duello' then
      select o.konuk, count(*) oy into kaz from oyun.tv_oy o where o.program_id = r.id group by o.konuk order by count(*) desc, min(o.zaman) limit 1;
      if kaz.konuk is not null then
        perform oyun.olay('basin', format('%s · "%s" düellosunu izleyici oylamasıyla %s kazandı (%s oy, %s izleyici).', r.kanal, r.baslik, oyun.kad(kaz.konuk), kaz.oy, r.izleyici), null, null, t);
        perform oyun.bildir(kaz.konuk, format('%s kanalındaki "%s" düellosunu izleyici oylamasıyla sen kazandın (%s oy).', r.kanal, r.baslik, kaz.oy), t);
      end if;
    end if;
    update oyun.tv_program set sonuc_yazildi = true where id = r.id; n := n + 1;
  end loop;
  return n;
end $$;

create or replace function oyun.tv_program_ozet(pr oyun.tv_program, t timestamptz) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object('id', pr.id, 'kanal_id', pr.kanal_id, 'kanal', (select ad from oyun.tv_kanal where id = pr.kanal_id), 'tur', pr.tur, 'tur_ad', oyun.tv_tur_ad(pr.tur),
    'baslik', pr.baslik, 'aciklama', pr.aciklama, 'bas', pr.bas, 'bit', case when pr.durum in ('bitti','iptal') then coalesce(pr.gercek_bit, pr.bit) else pr.bit end,
    'acik_uclu', pr.acik_uclu, 'durum', pr.durum, 'sunucu', oyun.kad(pr.sunucu),
    'konuklar', (select coalesce(jsonb_agg(oyun.kad(x.user_id) order by x.zaman), '[]'::jsonb) from oyun.tv_konuk x where x.program_id = pr.id and x.durum = 'kabul'),
    'izleyici', case when pr.durum = 'canli' then (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id and z.son > t - interval '45 seconds')
                     else greatest(pr.izleyici, (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id)) end,
    'reklam', (select count(*) from oyun.tv_reklam r where r.program_id = pr.id and r.durum in ('onay','yayinlandi')))
$$;

-- ---------------------------------------------------------------- kanal
create or replace function public.tv_liste() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  perform oyun.tv_guncelle_hepsi();
  return jsonb_build_object('simdi', t, 'kur_ucret', 250000,
    'kanalim', (select jsonb_build_object('id', k.id, 'ad', k.ad) from oyun.tv_kanal k where k.sahip = p.id and k.aktif limit 1),
    'sunuculuk', (select coalesce(jsonb_agg(jsonb_build_object('kanal_id', k.id, 'kanal', k.ad, 'gunluk_ucret', s.gunluk_ucret)), '[]'::jsonb)
                    from oyun.tv_sunucu s join oyun.tv_kanal k on k.id = s.kanal_id and k.aktif where s.user_id = p.id and s.durum = 'aktif'),
    'sunucu_teklif', (select coalesce(jsonb_agg(jsonb_build_object('kanal_id', k.id, 'kanal', k.ad, 'gunluk_ucret', s.gunluk_ucret, 'sahip', oyun.kad(k.sahip))), '[]'::jsonb)
                    from oyun.tv_sunucu s join oyun.tv_kanal k on k.id = s.kanal_id and k.aktif where s.user_id = p.id and s.durum = 'teklif'),
    'davetlerim', (select coalesce(jsonb_agg(oyun.tv_program_ozet(pr, t) order by pr.bas), '[]'::jsonb) from oyun.tv_program pr
                    join oyun.tv_konuk x on x.program_id = pr.id and x.user_id = p.id and x.durum = 'davet' where pr.durum in ('planli','canli')),
    'canli', (select coalesce(jsonb_agg(oyun.tv_program_ozet(pr, t) order by pr.bas), '[]'::jsonb) from oyun.tv_program pr where pr.durum = 'canli'),
    'yakinda', (select coalesce(jsonb_agg(oyun.tv_program_ozet(pr, t) order by pr.bas), '[]'::jsonb) from oyun.tv_program pr where pr.durum = 'planli'),
    'biten', (select coalesce(jsonb_agg(x.j order by x.b desc), '[]'::jsonb) from (select oyun.tv_program_ozet(pr, t) j, coalesce(pr.gercek_bit, pr.bit) b
                from oyun.tv_program pr where pr.durum = 'bitti' order by coalesce(pr.gercek_bit, pr.bit) desc limit 15) x),
    'kanallar', (select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'ad', k.ad, 'slogan', k.slogan, 'sahip', oyun.kad(k.sahip), 'izleyici_ucret', k.izleyici_ucret,
        'canli', exists (select 1 from oyun.tv_program pr where pr.kanal_id = k.id and pr.durum = 'canli'),
        'program', (select count(*) from oyun.tv_program pr where pr.kanal_id = k.id and pr.durum = 'bitti'),
        'toplam_izleyici', (select coalesce(sum(pr.izleyici), 0) from oyun.tv_program pr where pr.kanal_id = k.id and pr.durum = 'bitti'))
        order by (select coalesce(sum(pr.izleyici), 0) from oyun.tv_program pr where pr.kanal_id = k.id and pr.durum = 'bitti') desc, k.id), '[]'::jsonb)
      from oyun.tv_kanal k where k.aktif));
end $$;

-- Gündem ekranındaki rozet için hafif özet (yalnız okuma)
create or replace function public.tv_canli_ozet() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'canli', (select count(*) from oyun.tv_program pr where pr.durum = 'canli' and pr.bit > oyun.simdi()),
    'yakinda', (select count(*) from oyun.tv_program pr where pr.durum = 'planli' and pr.bas < oyun.simdi() + interval '24 hours'),
    'ilk', (select jsonb_build_object('id', pr.id, 'baslik', pr.baslik, 'kanal', k.ad) from oyun.tv_program pr join oyun.tv_kanal k on k.id = pr.kanal_id
             where (pr.durum = 'canli' and pr.bit > oyun.simdi()) or (pr.durum = 'planli' and pr.bas <= oyun.simdi()) order by pr.bas desc limit 1))
$$;

create or replace function public.tv_kanal_detay(p_kanal bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.tv_kanal; sahip boolean;
begin
  perform oyun.tv_guncelle_hepsi();
  select * into k from oyun.tv_kanal where id = p_kanal and aktif;
  if k.id is null then raise exception 'Kanal bulunamadı.'; end if;
  sahip := k.sahip = p.id;
  return jsonb_build_object('id', k.id, 'ad', k.ad, 'slogan', k.slogan, 'sahip', oyun.sm_kisi(k.sahip), 'kurulus', k.kurulus, 'izleyici_ucret', k.izleyici_ucret,
    'reklam_vergisi', round(oyun.tv_reklam_orani() * 100), 'benim', sahip, 'yayinciyim', oyun.tv_yayinci_mi(k.id, p.id), 'simdi', t,
    'kasa', case when sahip then round(k.kasa) end,
    'sunucular', (select coalesce(jsonb_agg(oyun.sm_kisi(s.user_id) || jsonb_build_object('durum', s.durum, 'bas', s.bas,
        'gunluk_ucret', case when sahip or s.user_id = p.id then s.gunluk_ucret end, 'toplam', case when sahip or s.user_id = p.id then round(s.toplam) end) order by s.durum, s.teklif_at), '[]'::jsonb)
      from oyun.tv_sunucu s where s.kanal_id = k.id and (s.durum = 'aktif' or (s.durum = 'teklif' and (sahip or s.user_id = p.id)))),
    'programlar', (select coalesce(jsonb_agg(oyun.tv_program_ozet(pr, t) order by pr.bas), '[]'::jsonb) from oyun.tv_program pr where pr.kanal_id = k.id and pr.durum in ('planli','canli')),
    'gecmis', (select coalesce(jsonb_agg(x.j order by x.b desc), '[]'::jsonb) from (select oyun.tv_program_ozet(pr, t) j, coalesce(pr.gercek_bit, pr.bit) b
                from oyun.tv_program pr where pr.kanal_id = k.id and pr.durum = 'bitti' order by coalesce(pr.gercek_bit, pr.bit) desc limit 12) x),
    'bekleyen_reklam', case when sahip then (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'program', pr.baslik, 'program_bas', pr.bas, 'marka', r.marka, 'metin', r.metin,
        'butce', round(r.butce), 'birim', r.birim, 'veren', oyun.kad(r.veren), 'sirket', (select ad from oyun.sirketler where id = r.sirket_id)) order by r.id), '[]'::jsonb)
      from oyun.tv_reklam r join oyun.tv_program pr on pr.id = r.program_id where r.kanal_id = k.id and r.durum = 'bekliyor') else '[]'::jsonb end,
    'hareketler', case when sahip then (select coalesce(jsonb_agg(jsonb_build_object('zaman', h.zaman, 'tutar', round(h.tutar), 'tur', h.tur, 'aciklama', h.aciklama) order by h.id desc), '[]'::jsonb)
      from (select * from oyun.tv_hareket where kanal_id = k.id order by id desc limit 20) h) else '[]'::jsonb end);
end $$;

create or replace function public.tv_kanal_kur(p_ad text, p_slogan text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a text; s text; i bigint; ucret numeric := 250000;
begin
  perform oyun.yazabilir_mi(p, t);
  if exists (select 1 from oyun.tv_kanal where sahip = p.id and aktif) then raise exception 'Zaten bir TV kanalın var.'; end if;
  a := oyun.metin_ops(p_ad, 40); s := oyun.metin_ops(p_slogan, 120);
  if char_length(a) < 3 then raise exception 'Kanal adı en az 3 karakter olmalı.'; end if;
  if exists (select 1 from oyun.tv_kanal where lower(ad) = lower(a) and aktif) then raise exception 'Bu adla bir kanal var.'; end if;
  perform oyun.para_islem(p.id, -ucret, 'vergi', 'TV yayın lisansı: ' || a, t);
  perform oyun.hazine_kaydet('diger_gelir', ucret / oyun.pazar_tl_milyar(), 'TV yayın lisansı');
  insert into oyun.tv_kanal(ad, slogan, sahip, kurulus) values (a, nullif(s, ''), p.id, t) returning id into i;
  perform oyun.olay('basin', format('%s, "%s" adlı TV kanalını kurdu.', p.kad, a), null, null, t);
  return public.tv_kanal_detay(i);
end $$;

create or replace function public.tv_kanal_ayar(p_kanal bigint, p_slogan text default null, p_izleyici_ucret numeric default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); k oyun.tv_kanal;
begin
  select * into k from oyun.tv_kanal where id = p_kanal and aktif for update;
  if k.id is null or k.sahip <> p.id then raise exception 'Kanalı yalnız sahibi yönetir.'; end if;
  if p_izleyici_ucret is not null and (p_izleyici_ucret < 50 or p_izleyici_ucret > 2000 or p_izleyici_ucret <> round(p_izleyici_ucret)) then
    raise exception 'İzleyici başına reklam ücreti 50 ₺ ile 2.000 ₺ arasında tam sayı olmalı.'; end if;
  update oyun.tv_kanal set slogan = case when p_slogan is null then slogan else nullif(oyun.metin_ops(p_slogan, 120), '') end,
    izleyici_ucret = coalesce(p_izleyici_ucret, izleyici_ucret) where id = k.id;
  return public.tv_kanal_detay(k.id);
end $$;

create or replace function public.tv_kasa(p_kanal bigint, p_yon text, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.tv_kanal; m numeric := round(coalesce(p_tutar, 0));
begin
  select * into k from oyun.tv_kanal where id = p_kanal and aktif for update;
  if k.id is null or k.sahip <> p.id then raise exception 'Kanal kasasını yalnız sahibi kullanır.'; end if;
  if m < 100 then raise exception 'En az 100 ₺ gir.'; end if;
  if p_yon = 'yatir' then
    perform oyun.para_islem(p.id, -m, 'reklam', k.ad || ' TV kanal kasasına aktarım', t);
    update oyun.tv_kanal set kasa = kasa + m where id = k.id;
    insert into oyun.tv_hareket(kanal_id, zaman, tutar, tur, aciklama) values (k.id, t, m, 'yatirma', p.kad || ' kasaya yatırdı');
  elsif p_yon = 'cek' then
    if k.kasa < m then raise exception 'Kanal kasasında yeterli para yok.'; end if;
    update oyun.tv_kanal set kasa = kasa - m where id = k.id;
    insert into oyun.tv_hareket(kanal_id, zaman, tutar, tur, aciklama) values (k.id, t, -m, 'cekme', p.kad || ' kasadan çekti');
    perform oyun.para_islem(p.id, m, 'reklam', k.ad || ' TV kanal geliri', t);
  else
    raise exception 'Geçersiz işlem.';
  end if;
  return public.tv_kanal_detay(k.id);
end $$;

-- ---------------------------------------------------------------- sunucu
create or replace function public.tv_sunucu_teklif(p_kanal bigint, p_kad text, p_gunluk numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.tv_kanal; h oyun.profiller; g numeric := round(coalesce(p_gunluk, 0));
begin
  select * into k from oyun.tv_kanal where id = p_kanal and aktif;
  if k.id is null or k.sahip <> p.id then raise exception 'Sunucuyu yalnız kanal sahibi alır.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = p.id or h.yasakli then raise exception 'Bu oyuncuya teklif yapılamaz.'; end if;
  if oyun.engelli(h.id, p.id) then raise exception 'Bu oyuncu seni engellediği için teklif yapılamaz.'; end if;
  if g < 500 or g > 100000 then raise exception 'Günlük sunucu ücreti 500 ₺ ile 100.000 ₺ arasında olmalı.'; end if;
  if (select count(*) from oyun.tv_sunucu where kanal_id = k.id and durum in ('teklif','aktif')) >= 5 then raise exception 'Bir kanalda en çok 5 sunucu (teklif dahil) olabilir.'; end if;
  insert into oyun.tv_sunucu(kanal_id, user_id, gunluk_ucret, durum, teklif_at) values (k.id, h.id, g, 'teklif', t)
    on conflict (kanal_id, user_id) do update set gunluk_ucret = excluded.gunluk_ucret, durum = 'teklif', teklif_at = excluded.teklif_at, bas = null, bitis = null
    where oyun.tv_sunucu.durum <> 'aktif';
  if not found then raise exception 'Bu oyuncu zaten kanalın sunucusu.'; end if;
  perform oyun.sm_haber(h.id, format('%s TV kanalı sana günlük %s ₺ ücretle sunuculuk teklif etti. Gündem › TV Kanalları''ndan yanıtla.', k.ad, oyun.tl(g)), 'Sunuculuk teklifi', t);
  return public.tv_kanal_detay(k.id);
end $$;

create or replace function public.tv_sunucu_yanit(p_kanal bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.tv_kanal;
begin
  select * into k from oyun.tv_kanal where id = p_kanal and aktif;
  if k.id is null then raise exception 'Kanal bulunamadı.'; end if;
  update oyun.tv_sunucu set durum = case when p_kabul then 'aktif' else 'ret' end, bas = case when p_kabul then t end,
      son_odeme = case when p_kabul then (t at time zone 'Europe/Istanbul')::date end
   where kanal_id = k.id and user_id = p.id and durum = 'teklif';
  if not found then raise exception 'Bekleyen bir sunuculuk teklifin yok.'; end if;
  perform oyun.bildir(k.sahip, format('%s, %s kanalındaki sunuculuk teklifini %s.', p.kad, k.ad, case when p_kabul then 'kabul etti' else 'reddetti' end), t);
  return public.tv_kanal_detay(k.id);
end $$;

-- p_kad doluysa sahip çıkarır; boşsa sunucu kendisi ayrılır
create or replace function public.tv_sunucu_bitir(p_kanal bigint, p_kad text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.tv_kanal; h oyun.profiller;
begin
  select * into k from oyun.tv_kanal where id = p_kanal and aktif;
  if k.id is null then raise exception 'Kanal bulunamadı.'; end if;
  if p_kad is not null then
    if k.sahip <> p.id then raise exception 'Sunucuyu yalnız kanal sahibi çıkarır.'; end if;
    h := oyun.profil_bul(p_kad);
    update oyun.tv_sunucu set durum = 'cikarildi', bitis = t where kanal_id = k.id and user_id = h.id and durum in ('teklif','aktif');
    if not found then raise exception 'Bu oyuncu kanalın sunucusu değil.'; end if;
    perform oyun.bildir(h.id, format('%s kanalındaki sunuculuk sözleşmen sona erdirildi.', k.ad), t);
  else
    update oyun.tv_sunucu set durum = 'ayrildi', bitis = t where kanal_id = k.id and user_id = p.id and durum = 'aktif';
    if not found then raise exception 'Bu kanalın sunucusu değilsin.'; end if;
    perform oyun.bildir(k.sahip, format('%s, %s kanalındaki sunuculuktan ayrıldı.', p.kad, k.ad), t);
  end if;
  return public.tv_kanal_detay(k.id);
end $$;

-- ---------------------------------------------------------------- program
create or replace function public.tv_program_ac(p_kanal bigint, p_tur text, p_baslik text, p_aciklama text default null, p_bas timestamptz default null,
  p_dakika integer default null, p_sunucu text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.tv_kanal; b text; a text; v_bas timestamptz; v_bit timestamptz; sun uuid; i bigint; h oyun.profiller;
begin
  perform oyun.yazabilir_mi(p, t);
  select * into k from oyun.tv_kanal where id = p_kanal and aktif;
  if k.id is null or not oyun.tv_yayinci_mi(k.id, p.id) then raise exception 'Programı kanalın sahibi ya da sunucusu açar.'; end if;
  if p_tur not in ('duello','soylesi','haber') then raise exception 'Geçersiz program türü.'; end if;
  b := oyun.metin_ops(p_baslik, 90); a := oyun.metin_ops(p_aciklama, 300);
  if char_length(b) < 4 then raise exception 'Program başlığı en az 4 karakter olmalı.'; end if;
  v_bas := greatest(coalesce(p_bas, t), t);
  if v_bas > t + interval '14 days' then raise exception 'Program en çok 14 gün sonrasına planlanabilir.'; end if;
  if p_dakika is not null and (p_dakika < 10 or p_dakika > 180) then raise exception 'Program süresi 10 ile 180 dakika arasında olmalı.'; end if;
  v_bit := v_bas + make_interval(mins => coalesce(p_dakika, 180));
  sun := p.id;
  if p_sunucu is not null and btrim(p_sunucu) <> '' then
    if k.sahip <> p.id then raise exception 'Sunucuyu yalnız kanal sahibi belirler.'; end if;
    h := oyun.profil_bul(p_sunucu);
    if not oyun.tv_yayinci_mi(k.id, h.id) then raise exception 'Bu oyuncu kanalın sunucusu değil. Önce sunuculuk teklif et.'; end if;
    sun := h.id;
  end if;
  if exists (select 1 from oyun.tv_program x where x.kanal_id = k.id and x.durum in ('planli','canli') and x.bas < v_bit and x.bit > v_bas) then
    raise exception 'Kanalın bu saatlerde başka bir programı var.'; end if;
  if (select count(*) from oyun.tv_program x where x.kanal_id = k.id and x.durum <> 'iptal'
        and (x.bas at time zone 'Europe/Istanbul')::date = (v_bas at time zone 'Europe/Istanbul')::date) >= 4 then
    raise exception 'Bir kanal günde en çok 4 program yapabilir.'; end if;
  insert into oyun.tv_program(kanal_id, sunucu, tur, baslik, aciklama, bas, bit, acik_uclu, olusturan, olusturma)
    values (k.id, sun, p_tur, b, nullif(a, ''), v_bas, v_bit, p_dakika is null, p.id, t) returning id into i;
  if v_bas > t + interval '1 minute' then
    perform oyun.olay('basin', format('%s program duyurusu: "%s" (%s) · %s · sunucu %s.', k.ad, b, oyun.tv_tur_ad(p_tur),
      to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'), oyun.kad(sun)), null, null, t);
    if sun <> p.id then perform oyun.bildir(sun, format('%s kanalında "%s" programının sunucususun: %s.', k.ad, b, to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), t); end if;
  end if;
  perform oyun.tv_program_guncelle(i);
  return public.tv_detay(i);
end $$;

create or replace function public.tv_konuk_davet(p_program bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; h oyun.profiller;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  if pr.sunucu <> p.id and k.sahip <> p.id then raise exception 'Konuğu programın sunucusu ya da kanal sahibi çağırır.'; end if;
  if pr.durum not in ('planli','canli') then raise exception 'Program bitti.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = pr.sunucu or h.yasakli then raise exception 'Bu oyuncu konuk çağrılamaz.'; end if;
  if oyun.engelli(h.id, p.id) then raise exception 'Bu oyuncu seni engellediği için çağrılamaz.'; end if;
  if (select count(*) from oyun.tv_konuk where program_id = pr.id and durum <> 'ret') >= 6 then raise exception 'Bir programa en çok 6 konuk çağrılabilir.'; end if;
  insert into oyun.tv_konuk(program_id, user_id, durum, zaman) values (pr.id, h.id, 'davet', t)
    on conflict (program_id, user_id) do update set durum = 'davet', zaman = excluded.zaman where oyun.tv_konuk.durum = 'ret';
  if not found then raise exception 'Bu oyuncu zaten çağrıldı.'; end if;
  perform oyun.sm_haber(h.id, format('%s TV seni "%s" programına (%s) konuk olarak çağırdı: %s. Gündem › TV Kanalları''ndan yanıtla.', k.ad, pr.baslik, oyun.tv_tur_ad(pr.tur),
    to_char(pr.bas at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')), 'TV programına davet', t);
  perform oyun.tv_sinyal(pr.id);
  return public.tv_detay(pr.id);
end $$;

create or replace function public.tv_konuk_yanit(p_program bigint, p_kabul boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or pr.durum not in ('planli','canli') then raise exception 'Program bulunamadı ya da bitti.'; end if;
  update oyun.tv_konuk set durum = case when p_kabul then 'kabul' else 'ret' end, zaman = t where program_id = pr.id and user_id = p.id and durum = 'davet';
  if not found then raise exception 'Bekleyen bir davetin yok.'; end if;
  perform oyun.bildir(pr.sunucu, format('%s, "%s" programına daveti %s.', p.kad, pr.baslik, case when p_kabul then 'kabul etti' else 'reddetti' end), t);
  perform oyun.tv_sinyal(pr.id);
  return public.tv_detay(pr.id);
end $$;

-- Stüdyo: detay (canlıyken izleyici kaydı tutar)
create or replace function public.tv_detay(p_program bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; rol text;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  rol := case when pr.sunucu = p.id then 'sunucu'
              when exists (select 1 from oyun.tv_konuk x where x.program_id = pr.id and x.user_id = p.id and x.durum = 'kabul') then 'konuk'
              when exists (select 1 from oyun.tv_konuk x where x.program_id = pr.id and x.user_id = p.id and x.durum = 'davet') then 'davetli'
              when k.sahip = p.id then 'sahip' else 'izleyici' end;
  if pr.durum = 'canli' and rol in ('izleyici', 'davetli') then
    insert into oyun.tv_izleyici(program_id, user_id, ilk, son) values (pr.id, p.id, t, t)
      on conflict (program_id, user_id) do update set son = excluded.son;
  end if;
  return oyun.tv_program_ozet(pr, t) || jsonb_build_object('simdi', t, 'rolum', rol, 'kanal_sahibi', k.sahip = p.id,
    'sunucu_kisi', oyun.sm_kisi(pr.sunucu), 'izleyici_ucret', k.izleyici_ucret,
    'konuk_liste', (select coalesce(jsonb_agg(oyun.sm_kisi(x.user_id) || jsonb_build_object('durum', x.durum,
        'oy', (select count(*) from oyun.tv_oy o where o.program_id = pr.id and o.konuk = x.user_id)) order by x.zaman), '[]'::jsonb)
      from oyun.tv_konuk x where x.program_id = pr.id),
    'mesajlar', (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'rol', m.rol, 'metin', m.metin, 'zaman', m.zaman,
        'kisi', case when m.rol = 'reklam' then null else oyun.sm_kisi(m.user_id) end, 'benim', m.user_id = p.id) order by m.id), '[]'::jsonb)
      from (select * from (select * from oyun.tv_mesaj where program_id = pr.id and not gizli order by id desc limit 400) q order by id) m),
    'izleyiciler', jsonb_build_object(
      'anlik', (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id and z.son > t - interval '45 seconds'),
      'toplam', (select count(*) from oyun.tv_izleyici z where z.program_id = pr.id),
      'liste', (select coalesce(jsonb_agg(oyun.kad(z.user_id) order by z.ilk), '[]'::jsonb)
                  from (select * from oyun.tv_izleyici where program_id = pr.id and (pr.durum <> 'canli' or son > t - interval '45 seconds') order by ilk limit 150) z)),
    'alkis', (select count(*) from oyun.tv_tepki x where x.program_id = pr.id and x.tur = 'alkis'),
    'yuh', (select count(*) from oyun.tv_tepki x where x.program_id = pr.id and x.tur = 'yuh'),
    'tepkim', (select tur from oyun.tv_tepki where program_id = pr.id and user_id = p.id),
    'oyum', (select oyun.kad(konuk) from oyun.tv_oy where program_id = pr.id and user_id = p.id),
    'oy_acik', pr.tur = 'duello' and (pr.durum = 'canli' or (pr.durum = 'bitti' and coalesce(pr.gercek_bit, pr.bit) > t - interval '15 minutes')),
    'reklamlar', (select coalesce(jsonb_agg(jsonb_build_object('marka', r.marka, 'metin', r.metin) order by r.id), '[]'::jsonb)
                    from oyun.tv_reklam r where r.program_id = pr.id and r.durum in ('onay','yayinlandi')),
    'reklamlarim', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'marka', r.marka, 'butce', round(r.butce), 'durum', r.durum, 'odenen', round(r.odenen), 'iade', round(r.iade),
        'sirket', (select ad from oyun.sirketler where id = r.sirket_id)) order by r.id), '[]'::jsonb)
      from oyun.tv_reklam r where r.program_id = pr.id and r.veren = p.id));
end $$;

create or replace function public.tv_yaz(p_program bigint, p_metin text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; m text; r text; i bigint;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  if pr.durum = 'planli' then raise exception 'Yayın henüz başlamadı.'; end if;
  if pr.durum <> 'canli' then raise exception 'Yayın sona erdi.'; end if;
  perform oyun.yazabilir_mi(p, t);
  if pr.sunucu = p.id then r := 'sunucu';
  elsif exists (select 1 from oyun.tv_konuk where program_id = pr.id and user_id = p.id and durum = 'kabul') then r := 'konuk';
  else raise exception 'Stüdyoda yalnız sunucu ve konuklar konuşur. Sen alkışlayabilir, yuhalayabilir, düelloda oy kullanabilirsin.'; end if;
  m := oyun.metin_temizle(p_metin, 600);
  if char_length(coalesce(m, '')) < 1 then raise exception 'Boş mesaj gönderilemez.'; end if;
  if exists (select 1 from oyun.tv_mesaj where program_id = pr.id and user_id = p.id and zaman > t - interval '2 seconds') then raise exception 'Çok hızlı yazıyorsun; bir an bekle.'; end if;
  insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, p.id, r, m, t) returning id into i;
  update oyun.profiller set son_mesaj = t where id = p.id;
  perform oyun.tv_sinyal(pr.id);
  return jsonb_build_object('tamam', true, 'id', i);
end $$;

create or replace function public.tv_tepki(p_program bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program;
begin
  if p_tur not in ('alkis','yuh') then raise exception 'Geçersiz tepki.'; end if;
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or not (pr.durum = 'canli' or (pr.durum = 'bitti' and coalesce(pr.gercek_bit, pr.bit) > t - interval '15 minutes')) then raise exception 'Bu yayına şu an tepki verilemez.'; end if;
  if pr.sunucu = p.id or exists (select 1 from oyun.tv_konuk where program_id = pr.id and user_id = p.id and durum = 'kabul') then raise exception 'Sunucu ve konuklar tepki veremez.'; end if;
  insert into oyun.tv_tepki(program_id, user_id, tur, zaman) values (pr.id, p.id, p_tur, t)
    on conflict (program_id, user_id) do update set tur = excluded.tur, zaman = excluded.zaman;
  perform oyun.tv_sinyal(pr.id);
  return public.tv_detay(pr.id);
end $$;

create or replace function public.tv_oyla(p_program bigint, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; h oyun.profiller;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or pr.tur <> 'duello' then raise exception 'Oylama yalnız siyasi düellolarda yapılır.'; end if;
  if not (pr.durum = 'canli' or (pr.durum = 'bitti' and coalesce(pr.gercek_bit, pr.bit) > t - interval '15 minutes')) then
    raise exception 'Oylama, düello sürerken ve bittikten sonraki 15 dakika içinde yapılır.'; end if;
  if pr.sunucu = p.id or exists (select 1 from oyun.tv_konuk where program_id = pr.id and user_id = p.id and durum = 'kabul') then raise exception 'Sunucu ve konuklar oy kullanamaz.'; end if;
  h := oyun.profil_bul(p_kad);
  if not exists (select 1 from oyun.tv_konuk where program_id = pr.id and user_id = h.id and durum = 'kabul') then raise exception 'Bu oyuncu düellonun tarafı değil.'; end if;
  insert into oyun.tv_oy(program_id, user_id, konuk, zaman) values (pr.id, p.id, h.id, t)
    on conflict (program_id, user_id) do update set konuk = excluded.konuk, zaman = excluded.zaman;
  perform oyun.tv_sinyal(pr.id);
  return public.tv_detay(pr.id);
end $$;

create or replace function public.tv_bitir(p_program bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal;
begin
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null then raise exception 'Program bulunamadı.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  if pr.sunucu <> p.id and k.sahip <> p.id then raise exception 'Yayını sunucu ya da kanal sahibi bitirir.'; end if;
  if pr.durum = 'planli' then
    update oyun.tv_program set durum = 'iptal', gercek_bit = t where id = pr.id;
    perform oyun.bildir(x.user_id, format('%s · "%s" programı iptal edildi.', k.ad, pr.baslik), t) from oyun.tv_konuk x where x.program_id = pr.id and x.durum <> 'ret';
  elsif pr.durum = 'canli' then
    update oyun.tv_program set durum = 'bitti', gercek_bit = t where id = pr.id;
  else
    raise exception 'Program zaten bitti.';
  end if;
  perform oyun.tv_program_hesapla(pr.id);
  perform oyun.tv_sinyal(pr.id);
  return public.tv_detay(pr.id);
end $$;

-- ---------------------------------------------------------------- reklam
create or replace function public.tv_reklam_ver(p_program bigint, p_marka text, p_metin text, p_butce numeric, p_sirket bigint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pr oyun.tv_program; k oyun.tv_kanal; mk text; mt text; b numeric := round(coalesce(p_butce, 0));
  v_kasa numeric; i bigint;
begin
  perform oyun.yazabilir_mi(p, t);
  pr := oyun.tv_program_guncelle(p_program);
  if pr.id is null or pr.durum not in ('planli','canli') then raise exception 'Reklam yalnız planlanmış ya da süren bir programa verilir.'; end if;
  select * into k from oyun.tv_kanal where id = pr.kanal_id;
  if k.sahip = p.id then raise exception 'Kendi kanalına reklam veremezsin.'; end if;
  mk := oyun.metin_ops(p_marka, 40); mt := oyun.metin_ops(p_metin, 200);
  if char_length(mk) < 2 or char_length(mt) < 5 then raise exception 'Marka en az 2, reklam metni en az 5 karakter olmalı.'; end if;
  if b < 5000 or b > 5000000 then raise exception 'Reklam bütçesi 5.000 ₺ ile 5.000.000 ₺ arasında olmalı.'; end if;
  if (select count(*) from oyun.tv_reklam where program_id = pr.id and durum in ('bekliyor','onay')) >= 8 then raise exception 'Bu programın reklam kuşağı dolu.'; end if;
  if exists (select 1 from oyun.tv_reklam where program_id = pr.id and veren = p.id and durum in ('bekliyor','onay')) then raise exception 'Bu programa zaten bir reklamın var.'; end if;
  if p_sirket is not null then
    if not oyun.sirket_yonetici_mi(p_sirket, p.id) then raise exception 'Bu şirketin yöneticisi değilsin.'; end if;
    if exists (select 1 from oyun.sirketler where id = p_sirket and sektor = 'banka') then raise exception 'Bankalar kasasından TV reklamı verilemez (mevduat sahipleri korunur).'; end if;
    if oyun.sirket_yonetici_mi(p_sirket, k.sahip) or exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = k.sahip and o.pay > 0) then
      raise exception 'Kanal sahibinin ortak ya da yönetici olduğu şirket bu kanala reklam veremez.'; end if;
    perform pg_advisory_xact_lock(98763, pg_catalog.hashtext(p_sirket::text));
    select s.kasa into v_kasa from oyun.sirketler s where s.id = p_sirket and s.aktif for update;
    if not found or coalesce(v_kasa, 0) < b then raise exception 'Şirket kasasında yeterli para yok.'; end if;
    update oyun.sirketler set kasa = kasa - b where id = p_sirket;
    insert into oyun.sirket_hareket(sirket_id, zaman, tutar, aciklama, faaliyet_gelir, faaliyet_gider, dagitilan_kar)
      values (p_sirket, t, -b, format('%s TV reklam bütçesi: "%s" (kullanılmayan kısım iade edilir)', k.ad, pr.baslik), 0, 0, 0);
  else
    perform oyun.para_islem(p.id, -b, 'reklam', format('%s TV reklam bütçesi: "%s"', k.ad, pr.baslik), t);
  end if;
  insert into oyun.tv_reklam(kanal_id, program_id, veren, sirket_id, marka, metin, butce, birim, olusturma)
    values (k.id, pr.id, p.id, p_sirket, mk, mt, b, k.izleyici_ucret, t) returning id into i;
  perform oyun.bildir(k.sahip, format('%s kanalındaki "%s" programı için reklam talebi: %s · bütçe %s ₺. TV Kanalları › Kanalım''dan onayla.', k.ad, pr.baslik, mk, oyun.tl(b)), t);
  return public.tv_detay(pr.id);
end $$;

-- Reklam formu: ödeme kaynakları (cüzdan + kanal sahibiyle bağı olmayan, yöneticisi olduğum şirketler)
create or replace function public.tv_reklam_kaynak(p_program bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); k oyun.tv_kanal;
begin
  select kk.* into k from oyun.tv_program pr join oyun.tv_kanal kk on kk.id = pr.kanal_id where pr.id = p_program;
  if k.id is null then raise exception 'Program bulunamadı.'; end if;
  return jsonb_build_object('cuzdan', coalesce((select round(c.para) from oyun.cuzdan c where c.user_id = p.id), 0),
    'izleyici_ucret', k.izleyici_ucret, 'vergi', round(oyun.tv_reklam_orani() * 100),
    'sirketler', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'ad', c.ad, 'kasa', round(c.kasa)) order by c.ad), '[]'::jsonb)
       from oyun.sirketler c where c.aktif and c.sektor <> 'banka' and oyun.sirket_yonetici_mi(c.id, p.id)
        and not oyun.sirket_yonetici_mi(c.id, k.sahip)
        and not exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = c.id and o.user_id = k.sahip and o.pay > 0)));
end $$;

create or replace function public.tv_reklam_karar(p_reklam bigint, p_onay boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.tv_reklam; k oyun.tv_kanal; pr oyun.tv_program;
begin
  select * into r from oyun.tv_reklam where id = p_reklam for update;
  if r.id is null then raise exception 'Reklam bulunamadı.'; end if;
  select * into k from oyun.tv_kanal where id = r.kanal_id;
  if k.sahip <> p.id then raise exception 'Reklamı yalnız kanal sahibi onaylar.'; end if;
  pr := oyun.tv_program_guncelle(r.program_id);
  select * into r from oyun.tv_reklam where id = p_reklam;
  if r.durum <> 'bekliyor' then raise exception 'Bu reklam talebi artık beklemede değil.'; end if;
  if p_onay then
    update oyun.tv_reklam set durum = 'onay', karar_at = t where id = r.id;
    if pr.durum = 'canli' then
      insert into oyun.tv_mesaj(program_id, user_id, rol, metin, zaman) values (pr.id, r.veren, 'reklam', r.marka || ': ' || r.metin, t);
      perform oyun.tv_sinyal(pr.id);
    end if;
    perform oyun.bildir(r.veren, format('%s kanalı "%s" programındaki reklamını onayladı.', k.ad, pr.baslik), t);
  else
    perform oyun.tv_reklam_iade(r, r.butce, k.ad || ' reklam bütçesi iadesi (reddedildi)', t);
    update oyun.tv_reklam set durum = 'ret', iade = r.butce, karar_at = t where id = r.id;
    perform oyun.bildir(r.veren, format('%s kanalı "%s" programındaki reklam talebini reddetti; %s ₺ iade edildi.', k.ad, pr.baslik, oyun.tl(r.butce)), t);
  end if;
  return public.tv_kanal_detay(k.id);
end $$;

create or replace function public.tv_reklam_iptal(p_reklam bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); r oyun.tv_reklam; pr oyun.tv_program;
begin
  select * into r from oyun.tv_reklam where id = p_reklam for update;
  if r.id is null or r.veren <> p.id then raise exception 'Reklam bulunamadı.'; end if;
  pr := oyun.tv_program_guncelle(r.program_id);
  select * into r from oyun.tv_reklam where id = p_reklam;
  if not (r.durum = 'bekliyor' or (r.durum = 'onay' and pr.durum = 'planli')) then raise exception 'Reklam yalnız onay beklerken ya da program başlamadan iptal edilebilir.'; end if;
  perform oyun.tv_reklam_iade(r, r.butce, 'TV reklam bütçesi iadesi (iptal)', t);
  update oyun.tv_reklam set durum = 'iptal', iade = r.butce, karar_at = t where id = r.id;
  return public.tv_detay(pr.id);
end $$;

-- ---------------------------------------------------------------- zamanlayıcı: program geçişleri + günlük sunucu ücreti
create or replace function oyun.tv_tick() returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; s record; n int := 0; gun int; tutar numeric; ode numeric; v_kasa numeric;
begin
  if not pg_try_advisory_xact_lock(hashtext('oyun.tv_tick')) then return 0; end if;
  n := oyun.tv_guncelle_hepsi();
  for s in select x.*, k.ad kanal, k.sahip from oyun.tv_sunucu x join oyun.tv_kanal k on k.id = x.kanal_id where x.durum = 'aktif' and x.son_odeme < bugun order by x.kanal_id loop
    gun := least(7, bugun - s.son_odeme); tutar := s.gunluk_ucret * gun;
    select kasa into v_kasa from oyun.tv_kanal where id = s.kanal_id for update;
    ode := least(tutar, floor(greatest(0, v_kasa)));
    if ode > 0 then
      update oyun.tv_kanal set kasa = kasa - ode where id = s.kanal_id;
      insert into oyun.tv_hareket(kanal_id, zaman, tutar, tur, aciklama) values (s.kanal_id, t, -ode, 'sunucu', oyun.kad(s.user_id) || ' sunucu ücreti (' || gun || ' gün)');
      perform oyun.para_islem(s.user_id, ode, 'maas', s.kanal || ' TV sunucu ücreti', t);
    end if;
    if ode < tutar then
      update oyun.tv_sunucu set durum = 'ayrildi', bitis = t, son_odeme = bugun, toplam = toplam + ode where kanal_id = s.kanal_id and user_id = s.user_id;
      perform oyun.bildir(s.user_id, format('%s kanalı sunucu ücretini ödeyemedi (kasada para yok); sözleşmen sona erdi.', s.kanal), t);
      perform oyun.bildir(s.sahip, format('%s kanal kasasında para olmadığı için %s ile sunuculuk sözleşmesi sona erdi.', s.kanal, oyun.kad(s.user_id)), t);
    else
      update oyun.tv_sunucu set son_odeme = bugun, toplam = toplam + ode where kanal_id = s.kanal_id and user_id = s.user_id;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;

revoke all on function oyun.tv_sinyal(bigint), oyun.tv_tur_ad(text), oyun.tv_yayinci_mi(bigint, uuid), oyun.tv_reklam_orani(), oyun.tv_reklam_iade(oyun.tv_reklam, numeric, text, timestamptz),
  oyun.tv_program_hesapla(bigint), oyun.tv_program_guncelle(bigint), oyun.tv_guncelle_hepsi(), oyun.tv_program_ozet(oyun.tv_program, timestamptz), oyun.tv_tick() from public, anon, authenticated;
do $g$ declare f text; begin
  foreach f in array array['tv_liste()','tv_canli_ozet()','tv_kanal_detay(bigint)','tv_kanal_kur(text,text)','tv_kanal_ayar(bigint,text,numeric)','tv_kasa(bigint,text,numeric)',
    'tv_sunucu_teklif(bigint,text,numeric)','tv_sunucu_yanit(bigint,boolean)','tv_sunucu_bitir(bigint,text)',
    'tv_program_ac(bigint,text,text,text,timestamptz,integer,text)','tv_konuk_davet(bigint,text)','tv_konuk_yanit(bigint,boolean)','tv_detay(bigint)',
    'tv_yaz(bigint,text)','tv_tepki(bigint,text)','tv_oyla(bigint,text)','tv_bitir(bigint)',
    'tv_reklam_ver(bigint,text,text,numeric,bigint)','tv_reklam_kaynak(bigint)','tv_reklam_karar(bigint,boolean)','tv_reklam_iptal(bigint)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $g$;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, sira, periyot_dk, ofset_dk, komut, aktif)
    values ('tv_kanallari', 83, 5, 3, 'select oyun.tv_tick()', true)
    on conflict (adim) do nothing;
  end if;
exception when others then raise notice 'tv_kanallari zamanlanamadı: %', sqlerrm;
end $z$;
