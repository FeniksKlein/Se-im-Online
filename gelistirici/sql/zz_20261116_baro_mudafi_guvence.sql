-- 2026.11.16-2 · Baro müdafi güvencesi (CMK m.150/151/156)
-- Gözaltındaki oyuncu barodan müdafi istediğinde talep kaybolmaz:
--  * Baro başkanı (ya da geçici yetkili) kısa süre içinde (varsayılan 15 dk) görevlendirmezse sistem otomatik görevlendirir.
--  * Başkan yoksa ya da gözaltındaysa görevlendirme hemen yapılır.
--  * Görevlendirilen avukat yanıt vermezse (varsayılan 20 dk) ya da reddederse / çekilirse dosya derhal başka avukata geçer (CMK m.151).
--  * Oyuncunun kendi seçtiği avukat görevi üstlenirse baro görevlendirmesi kapanır (CMK m.156/3).
--  * Uygun avukat yoksa talep "tamamlandı" görünmez: açık kalır, nedeni yazılır, uygun avukat çıkınca yeniden değerlendirilir.
--  * Zorunlu müdafilik ücreti gözaltındaki kişinin cüzdanından alınmaz; baro CMK ödeneğinden öder.
--  * Ceza niteliğindeki davalarda sanığın (davalı kişi) baro talebi servetine bakılmadan ücretsiz CMK görevlendirmesidir.
-- Oyuncu verisi silinmez; yalnızca sona ermiş gözaltılara ait açık talepler "kapandi" olarak işaretlenir.

-- 1) Şema: yalnız genişletme -------------------------------------------------
alter table oyun.gozalti_baro_talep
  add column if not exists gerekce text,
  add column if not exists denenen uuid[] not null default '{}',
  add column if not exists cagri_zamani timestamptz,
  add column if not exists son_deneme timestamptz,
  add column if not exists otomatik boolean not null default false,
  add column if not exists kapanis timestamptz,
  add column if not exists ucret_odendi boolean not null default false,
  add column if not exists bos_bildirildi boolean not null default false;
alter table oyun.sokak_baro_talep
  add column if not exists denenen uuid[] not null default '{}',
  add column if not exists cagri_zamani timestamptz,
  add column if not exists son_deneme timestamptz,
  add column if not exists otomatik boolean not null default false,
  add column if not exists kapanis timestamptz,
  add column if not exists ucret_odendi boolean not null default false,
  add column if not exists bos_bildirildi boolean not null default false;
alter table oyun.baro_adli_yardim
  add column if not exists cmk boolean not null default false,
  add column if not exists bos_bildirildi boolean not null default false;

alter table oyun.gozalti_baro_talep drop constraint if exists gozalti_baro_talep_durum_check;
alter table oyun.gozalti_baro_talep add constraint gozalti_baro_talep_durum_check
  check (durum = any (array['bekliyor','gorevlendirildi','kapandi','iptal']));
alter table oyun.sokak_baro_talep drop constraint if exists sokak_baro_talep_durum_check;
alter table oyun.sokak_baro_talep add constraint sokak_baro_talep_durum_check
  check (durum = any (array['bekliyor','gorevlendirildi','iptal','kapandi']));

create table if not exists oyun.mudafi_islem (
  id bigserial primary key,
  kaynak text not null,
  dosya_id bigint not null,
  olay text not null,
  avukat uuid,
  aktor uuid,
  ayrinti text,
  zaman timestamptz not null default now()
);
create index if not exists mudafi_islem_dosya_ix on oyun.mudafi_islem(kaynak, dosya_id, zaman desc);
create index if not exists mudafi_islem_avukat_ix on oyun.mudafi_islem(avukat, zaman desc) where olay = 'gorevlendirildi';
alter table oyun.mudafi_islem enable row level security;

insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira,guncelleme) values
 ('mudafi_baskan_sure_dk',15,'dakika','kural','Baro başkanına gözaltı müdafi görevlendirme süresi','Gözaltındaki oyuncu barodan müdafi istediğinde baro başkanı bu süre içinde görevlendirme yapmazsa sistem uygun avukatı otomatik görevlendirir.',905,now()),
 ('mudafi_yanit_sure_dk',20,'dakika','kural','Görevlendirilen müdafinin yanıt süresi','Baronun görevlendirdiği avukat bu süre içinde görevi kabul etmezse dosya başka uygun avukata geçer (CMK m.151).',906,now()),
 ('mudafi_azami_dosya',3,'dosya','kural','Bir avukatın aynı anda üstlenebileceği gözaltı müdafiliği','Adil dağılım için baro, bu sayıya ulaşmış avukata yeni gözaltı dosyası görevlendirmez.',907,now()),
 ('cmk_mudafi_ucret',5000,'TL','ucret','Zorunlu müdafilik (CMK) ücreti','Gözaltı müdafiliğini kabul eden baro avukatına baro CMK ödeneğinden ödenir; gözaltındaki kişiden alınmaz.',908,now()),
 ('cmk_dava_sure_dk',30,'dakika','kural','Ceza davasında CMK müdafi otomatik görevlendirme süresi','Ceza niteliğindeki davada sanık barodan müdafi isterse baro başkanı bu süre içinde görevlendirmezse sistem otomatik görevlendirir.',909,now())
on conflict (kod) do nothing;

-- 2) Ortak yardımcılar ------------------------------------------------------
create or replace function oyun.mudafi_log(p_kaynak text, p_id bigint, p_olay text, p_avukat uuid, p_aktor uuid, p_ayrinti text)
returns void language sql security definer set search_path to '' as $$
  insert into oyun.mudafi_islem(kaynak,dosya_id,olay,avukat,aktor,ayrinti) values(p_kaynak,p_id,p_olay,p_avukat,p_aktor,left(p_ayrinti,500));
$$;

-- Avukatın açık gözaltı müdafiliği sayısı (dosya yoğunluğu)
create or replace function oyun.mudafi_yuk(p_avukat uuid)
returns integer language sql stable set search_path to '' as $$
  select ( (select count(*) from oyun.sokak_gozalti g where g.avukat=p_avukat and g.avukat_durum in ('cagrildi','kabul') and g.durum='aktif' and g.bitis>oyun.simdi())
         + (select count(*) from oyun.icisleri_tedbir_v2 k where k.avukat=p_avukat and k.avukat_durum in ('cagrildi','kabul') and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>oyun.simdi())
         + (select count(*) from oyun.yonetim_tutuklama y where y.avukat=p_avukat and y.avukat_durum in ('cagrildi','kabul') and y.durum='aktif' and y.bitis>oyun.simdi()) )::int
$$;

-- Görev engeli: null = uygun, metin = neden uygun olmadığı
create or replace function oyun.mudafi_engel(p_avukat uuid, p_hedef uuid, p_yetkili uuid)
returns text language plpgsql stable set search_path to '' as $$
declare v text;
begin
  if p_avukat is null then return 'Avukat seçilmedi'; end if;
  if not exists(select 1 from oyun.avukat_ruhsat r where r.user_id=p_avukat and r.durum='aktif') then return 'Aktif avukatlık ruhsatı yok'; end if;
  if not exists(select 1 from oyun.baro_uyeleri b where b.user_id=p_avukat and b.durum='aktif') then return 'Baroya aktif üye değil'; end if;
  if exists(select 1 from oyun.profiller p where p.id=p_avukat and coalesce(p.yasakli,false)) then return 'Hesabı kısıtlı'; end if;
  v := oyun.avukat_gorev_engeli(p_avukat);
  if v is not null then return v; end if;
  if oyun.gozalti_aktif(p_avukat) is not null then return 'Avukatın kendisi gözaltında'; end if;
  if p_avukat = p_hedef then return 'Kişi kendi müdafisi olamaz'; end if;
  if p_avukat = p_yetkili then return 'Gözaltı kararını veren kişi müdafi olamaz (çıkar çatışması)'; end if;
  if exists(select 1 from oyun.makamlar m where m.user_id=p_avukat and m.bit is null and (m.tur='cb' or (m.tur='bakan' and m.bakanlik='icisleri'))) then
    return 'Gözaltı yetkisini elinde tutan makam sahibi müdafi olamaz (çıkar çatışması)'; end if;
  if oyun.mudafi_yuk(p_avukat) >= oyun.gozalti_ayar('mudafi_azami_dosya',3) then return 'Avukatın dosya yükü dolu'; end if;
  return null;
end $$;

-- Adil sıralama: gönüllü → aynı il → en az dosya → en uzun süredir görev almamış → rastgele
create or replace function oyun.mudafi_aday(p_hedef uuid, p_yetkili uuid, p_haric uuid[])
returns uuid language sql stable set search_path to '' as $$
  select b.user_id
  from oyun.baro_uyeleri b join oyun.profiller p on p.id=b.user_id
  where b.durum='aktif' and not (b.user_id = any(coalesce(p_haric,'{}')))
    and oyun.mudafi_engel(b.user_id,p_hedef,p_yetkili) is null
  order by b.gonullu desc,
    (p.il_id is not distinct from (select h.il_id from oyun.profiller h where h.id=p_hedef)) desc,
    oyun.mudafi_yuk(b.user_id) asc,
    (select max(i.zaman) from oyun.mudafi_islem i where i.avukat=b.user_id and i.olay='gorevlendirildi') asc nulls first,
    random()
  limit 1
$$;

-- Eski çağıranlar için aynı imza korunur; yeni adil sıralamayı kullanır.
create or replace function oyun.gozalti_baro_avukat_sec(p_hedef uuid, p_yetkili uuid, p_haric uuid)
returns uuid language sql stable set search_path to '' as $$
  select oyun.mudafi_aday(p_hedef,p_yetkili,case when p_haric is null then '{}'::uuid[] else array[p_haric] end)
$$;

-- Dosyadaki avukat alanını kaynağa göre günceller
create or replace function oyun.mudafi_dosya_yaz(p_kaynak text, p_id bigint, p_avukat uuid, p_durum text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if p_kaynak='sokak' then
    update oyun.sokak_gozalti set avukat=p_avukat, avukat_durum=p_durum where id=p_id;
  elsif p_kaynak='icisleri' then
    update oyun.icisleri_tedbir_v2 set avukat=p_avukat, avukat_durum=p_durum where id=p_id;
  elsif p_kaynak='yonetim' then
    update oyun.yonetim_tutuklama set avukat=p_avukat, avukat_durum=p_durum where id=p_id;
  else raise exception 'Geçersiz gözaltı türü'; end if;
end $$;

-- Talep satırını tek biçimde okur
create or replace function oyun.mudafi_talep(p_kaynak text, p_id bigint)
returns jsonb language sql stable set search_path to '' as $$
  select case when p_kaynak='sokak' then
    (select jsonb_build_object('durum',t.durum,'zaman',t.basvuru,'avukat',t.avukat,'gorevlendiren',t.gorevlendiren,'denenen',to_jsonb(t.denenen),
       'cagri_zamani',coalesce(t.cagri_zamani,t.karar_zamani),'gerekce',t.gerekce,'otomatik',t.otomatik,'ucret_odendi',t.ucret_odendi,'bos_bildirildi',t.bos_bildirildi,'talep_eden',t.talep_eden)
       from oyun.sokak_baro_talep t where t.gozalti_id=p_id)
  else
    (select jsonb_build_object('durum',t.durum,'zaman',t.zaman,'avukat',t.avukat,'gorevlendiren',t.gorevlendiren,'denenen',to_jsonb(t.denenen),
       'cagri_zamani',coalesce(t.cagri_zamani,t.karar_zamani),'gerekce',t.gerekce,'otomatik',t.otomatik,'ucret_odendi',t.ucret_odendi,'bos_bildirildi',t.bos_bildirildi,'talep_eden',t.talep_eden)
       from oyun.gozalti_baro_talep t where t.kaynak=p_kaynak and t.dosya_id=p_id)
  end
$$;

-- Talep satırını kaynağa göre günceller (yalnız verilen alanlar)
create or replace function oyun.mudafi_talep_guncelle(p_kaynak text, p_id bigint, p_alan jsonb)
returns void language plpgsql security definer set search_path to '' as $$
declare t timestamptz:=oyun.simdi();
begin
  if p_kaynak='sokak' then
    update oyun.sokak_baro_talep set
      durum=coalesce(p_alan->>'durum',durum),
      avukat=case when p_alan ? 'avukat' then (p_alan->>'avukat')::uuid else avukat end,
      gorevlendiren=case when p_alan ? 'gorevlendiren' then (p_alan->>'gorevlendiren')::uuid else gorevlendiren end,
      karar_zamani=case when p_alan ? 'avukat' then t else karar_zamani end,
      cagri_zamani=case when p_alan ? 'cagri_zamani' then (p_alan->>'cagri_zamani')::timestamptz else cagri_zamani end,
      basvuru=case when p_alan ? 'zaman' then (p_alan->>'zaman')::timestamptz else basvuru end,
      gerekce=case when p_alan ? 'gerekce' then p_alan->>'gerekce' else gerekce end,
      otomatik=coalesce((p_alan->>'otomatik')::boolean,otomatik),
      ucret_odendi=coalesce((p_alan->>'ucret_odendi')::boolean,ucret_odendi),
      bos_bildirildi=coalesce((p_alan->>'bos_bildirildi')::boolean,bos_bildirildi),
      son_deneme=case when p_alan ? 'son_deneme' then (p_alan->>'son_deneme')::timestamptz else son_deneme end,
      kapanis=case when p_alan ? 'kapanis' then (p_alan->>'kapanis')::timestamptz else kapanis end,
      denenen=case when p_alan->>'denenen_ekle' is not null then array(select distinct x from unnest(denenen||(p_alan->>'denenen_ekle')::uuid) x)
                   when p_alan ? 'denenen_sifirla' then '{}' else denenen end
    where gozalti_id=p_id;
  else
    update oyun.gozalti_baro_talep set
      durum=coalesce(p_alan->>'durum',durum),
      avukat=case when p_alan ? 'avukat' then (p_alan->>'avukat')::uuid else avukat end,
      gorevlendiren=case when p_alan ? 'gorevlendiren' then (p_alan->>'gorevlendiren')::uuid else gorevlendiren end,
      karar_zamani=case when p_alan ? 'avukat' then t else karar_zamani end,
      cagri_zamani=case when p_alan ? 'cagri_zamani' then (p_alan->>'cagri_zamani')::timestamptz else cagri_zamani end,
      zaman=case when p_alan ? 'zaman' then (p_alan->>'zaman')::timestamptz else zaman end,
      gerekce=case when p_alan ? 'gerekce' then p_alan->>'gerekce' else gerekce end,
      otomatik=coalesce((p_alan->>'otomatik')::boolean,otomatik),
      ucret_odendi=coalesce((p_alan->>'ucret_odendi')::boolean,ucret_odendi),
      bos_bildirildi=coalesce((p_alan->>'bos_bildirildi')::boolean,bos_bildirildi),
      son_deneme=case when p_alan ? 'son_deneme' then (p_alan->>'son_deneme')::timestamptz else son_deneme end,
      kapanis=case when p_alan ? 'kapanis' then (p_alan->>'kapanis')::timestamptz else kapanis end,
      denenen=case when p_alan->>'denenen_ekle' is not null then array(select distinct x from unnest(denenen||(p_alan->>'denenen_ekle')::uuid) x)
                   when p_alan ? 'denenen_sifirla' then '{}' else denenen end
    where kaynak=p_kaynak and dosya_id=p_id;
  end if;
end $$;

-- Talep açar ya da yeniden açar (denenen listesi korunabilir)
create or replace function oyun.mudafi_talep_ac(p_kaynak text, p_id bigint, p_talep_eden uuid, p_zaman timestamptz, p_gerekce text, p_sifirla boolean)
returns void language plpgsql security definer set search_path to '' as $$
begin
  if p_kaynak='sokak' then
    insert into oyun.sokak_baro_talep(gozalti_id,talep_eden,durum,basvuru,gerekce)
    values(p_id,p_talep_eden,'bekliyor',p_zaman,p_gerekce)
    on conflict (gozalti_id) do update set durum='bekliyor', talep_eden=excluded.talep_eden, basvuru=excluded.basvuru,
      avukat=null, gorevlendiren=null, karar_zamani=null, cagri_zamani=null, gerekce=excluded.gerekce, otomatik=false,
      kapanis=null, bos_bildirildi=false, son_deneme=null,
      denenen=case when p_sifirla then '{}' else oyun.sokak_baro_talep.denenen end,
      ucret_odendi=case when p_sifirla then false else oyun.sokak_baro_talep.ucret_odendi end;
  else
    insert into oyun.gozalti_baro_talep(kaynak,dosya_id,talep_eden,durum,zaman,gerekce)
    values(p_kaynak,p_id,p_talep_eden,'bekliyor',p_zaman,p_gerekce)
    on conflict (kaynak,dosya_id) do update set durum='bekliyor', talep_eden=excluded.talep_eden, zaman=excluded.zaman,
      avukat=null, gorevlendiren=null, karar_zamani=null, cagri_zamani=null, gerekce=excluded.gerekce, otomatik=false,
      kapanis=null, bos_bildirildi=false, son_deneme=null,
      denenen=case when p_sifirla then '{}' else oyun.gozalti_baro_talep.denenen end,
      ucret_odendi=case when p_sifirla then false else oyun.gozalti_baro_talep.ucret_odendi end;
  end if;
end $$;

-- Görevlendirme (başkan elle ya da sistem otomatik)
create or replace function oyun.mudafi_ata(p_kaynak text, p_id bigint, p_avukat uuid, p_gorevlendiren uuid, p_otomatik boolean)
returns void language plpgsql security definer set search_path to '' as $$
declare d jsonb; t timestamptz:=oyun.simdi(); hedef uuid; bas uuid;
begin
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  hedef := (d->>'hedef')::uuid;
  perform oyun.mudafi_dosya_yaz(p_kaynak,p_id,p_avukat,'cagrildi');
  if oyun.mudafi_talep(p_kaynak,p_id) is null then
    perform oyun.mudafi_talep_ac(p_kaynak,p_id,coalesce(p_gorevlendiren,hedef),t,null,true);
  end if;
  perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('durum','gorevlendirildi','avukat',p_avukat,
     'gorevlendiren',coalesce(p_gorevlendiren,p_avukat),'cagri_zamani',t,'otomatik',p_otomatik,'denenen_ekle',p_avukat,
     'gerekce',case when p_otomatik then 'Baro adına sistem otomatik görevlendirdi' else 'Baro başkanı görevlendirdi' end));
  perform oyun.mudafi_log(p_kaynak,p_id,'gorevlendirildi',p_avukat,p_gorevlendiren,case when p_otomatik then 'otomatik' else 'baro_baskani' end);
  perform oyun.bildir(p_avukat, format('⚖️ Baro sizi gözaltındaki %s için (dosya #%s) müdafi olarak görevlendirdi%s. %s dakika içinde Menü › Gözaltı ve Avukat ekranından kabul edin; yanıt verilmezse dosya başka avukata geçer.',
     oyun.kad(hedef), p_id, case when p_otomatik then ' (otomatik görevlendirme)' else '' end, oyun.gozalti_ayar('mudafi_yanit_sure_dk',20)::int), t);
  perform oyun.bildir(hedef, format('⚖️ Baro gözaltı #%s için size müdafi görevlendirdi: %s. Kabul edince yalnız onunla özel mesajlaşabilirsiniz. Müdafilik ücreti sizden alınmaz.', p_id, oyun.kad(p_avukat)), t);
  if p_otomatik then
    bas := oyun.baro_baskan();
    if bas is not null and bas<>p_avukat then
      perform oyun.bildir(bas, format('⚖️ Gözaltı #%s (%s): süre içinde görevlendirme yapılmadığı için baro adına %s otomatik görevlendirildi.', p_id, oyun.kad(hedef), oyun.kad(p_avukat)), t);
    end if;
  end if;
end $$;

-- Tek bir talebi değerlendirir; sonucu metin olarak döndürür
create or replace function oyun.mudafi_degerlendir(p_kaynak text, p_id bigint)
returns text language plpgsql security definer set search_path to '' as $$
declare d jsonb; tl jsonb; t timestamptz:=oyun.simdi(); bas uuid; av uuid; hedef uuid; yetkili uuid;
  v_yanit interval := make_interval(mins => oyun.gozalti_ayar('mudafi_yanit_sure_dk',20)::int);
  v_bas interval := make_interval(mins => oyun.gozalti_ayar('mudafi_baskan_sure_dk',15)::int);
  haric uuid[]; ucret numeric; kasa numeric;
begin
  tl := oyun.mudafi_talep(p_kaynak,p_id);
  if tl is null or tl->>'durum' not in ('bekliyor','gorevlendirildi') then return 'talep_yok'; end if;
  begin d := oyun.gozalti_dosya(p_kaynak,p_id); exception when others then d := null; end;
  if d is null or not coalesce((d->>'aktif')::boolean,false) then
    perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('durum',case when tl->>'durum'='gorevlendirildi' and tl->>'avukat' is not null then 'gorevlendirildi' else 'kapandi' end,'kapanis',t,'gerekce','Gözaltı sona erdiği için talep kapandı'));
    perform oyun.mudafi_log(p_kaynak,p_id,'kapandi',null,null,'gözaltı sona erdi');
    return 'kapandi';
  end if;
  hedef := (d->>'hedef')::uuid; yetkili := (d->>'yetkili')::uuid;

  -- Avukat görevi üstlenmiş: baro talebi kapanır; baro avukatıysa CMK ücreti bir kez ödenir
  if d->>'avukat_durum'='kabul' then
    if (d->>'avukat')::uuid is not distinct from (tl->>'avukat')::uuid then
      if not coalesce((tl->>'ucret_odendi')::boolean,false) then
        ucret := oyun.gozalti_ayar('cmk_mudafi_ucret',5000);
        select b.kasa into kasa from oyun.baro b where b.id=1 for update;
        ucret := least(ucret, greatest(coalesce(kasa,0),0));
        if ucret>0 then
          perform oyun.baro_kasa(-ucret,'adli_yardim',format('Gözaltı #%s CMK müdafilik ücreti · Av. %s',p_id,oyun.kad((d->>'avukat')::uuid)),(d->>'avukat')::uuid);
          perform oyun.para_islem((d->>'avukat')::uuid,ucret,'adliye',format('Gözaltı #%s CMK müdafilik ücreti (baro ödedi)',p_id),t);
        end if;
        perform oyun.mudafi_log(p_kaynak,p_id,'ucret',(d->>'avukat')::uuid,null,ucret::text);
      end if;
      perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('durum','gorevlendirildi','ucret_odendi',true,'kapanis',t,'gerekce','Müdafi görevi kabul etti'));
      return 'kabul';
    else
      perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('durum','kapandi','kapanis',t,'gerekce','Oyuncunun kendi seçtiği avukat görevi üstlendi (CMK m.156/3)'));
      perform oyun.mudafi_log(p_kaynak,p_id,'kapandi',(d->>'avukat')::uuid,null,'oyuncunun seçtiği avukat');
      return 'kendi_avukati';
    end if;
  end if;

  -- Görevlendirilmiş ama henüz kabul edilmemiş
  if tl->>'durum'='gorevlendirildi' then
    if d->>'avukat_durum'='cagrildi' and (d->>'avukat')::uuid is not distinct from (tl->>'avukat')::uuid then
      if coalesce((tl->>'cagri_zamani')::timestamptz,t) > t - v_yanit then return 'yanit_bekleniyor'; end if;
      perform oyun.mudafi_dosya_yaz(p_kaynak,p_id,null,'yok');
      perform oyun.bildir((tl->>'avukat')::uuid, format('⚖️ Gözaltı #%s müdafiliğine süresi içinde yanıt vermediğiniz için dosya başka avukata devredildi.',p_id),t);
      perform oyun.mudafi_log(p_kaynak,p_id,'yanit_yok',(tl->>'avukat')::uuid,null,null);
    else
      perform oyun.mudafi_log(p_kaynak,p_id,'reddedildi',(tl->>'avukat')::uuid,null,d->>'avukat_durum');
      if d->>'avukat_durum'='cagrildi' then
        -- oyuncu bu arada kendi avukatını çağırdı; o çağrıya yanıt süresi tanınır
        if coalesce((tl->>'cagri_zamani')::timestamptz,t) > t - v_yanit then return 'oyuncu_cagrisi_bekleniyor'; end if;
      end if;
    end if;
    perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('durum','bekliyor','avukat',null,'gorevlendiren',null,
      'cagri_zamani',null,'zaman',t - v_bas,'denenen_ekle',(tl->>'avukat'),'gerekce','Önceki müdafi görevi üstlenmedi; yeni müdafi aranıyor'));
    tl := oyun.mudafi_talep(p_kaynak,p_id);
    d := oyun.gozalti_dosya(p_kaynak,p_id);
  end if;

  -- Oyuncunun kendi çağrısı süre içindeyse beklenir
  if d->>'avukat_durum'='cagrildi' and (d->>'avukat') is not null then
    if (tl->>'zaman')::timestamptz > t - v_yanit then return 'oyuncu_cagrisi_bekleniyor'; end if;
    perform oyun.bildir((d->>'avukat')::uuid, format('⚖️ Gözaltı #%s için size yapılan avukatlık çağrısı süresinde yanıtlanmadı; baro müdafi görevlendiriyor.',p_id),t);
    perform oyun.mudafi_dosya_yaz(p_kaynak,p_id,null,'yok');
  end if;

  -- Baro başkanına tanınan süre (başkan yoksa ya da gözaltındaysa beklenmez)
  bas := oyun.baro_baskan();
  if bas is not null and oyun.gozalti_aktif(bas) is not null then bas := null; end if;
  if bas is not null and (tl->>'zaman')::timestamptz > t - v_bas then return 'baskan_bekleniyor'; end if;

  select array(select (jsonb_array_elements_text(coalesce(tl->'denenen','[]'::jsonb)))::uuid) into haric;
  av := oyun.mudafi_aday(hedef,yetkili,haric);
  if av is null and cardinality(haric)>0 then
    -- herkes denendiyse son denenen hariç yeniden sıraya al
    av := oyun.mudafi_aday(hedef,yetkili,array[haric[cardinality(haric)]]);
  end if;
  if av is null then
    perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('son_deneme',t,
      'gerekce','Şu anda görev alabilecek uygun avukat yok (ruhsat, baro üyeliği, görev engeli, çıkar çatışması, gözaltı ya da dosya yükü nedeniyle). Talep açık; uygun avukat çıkınca sistem görevlendirir.'));
    if not coalesce((tl->>'bos_bildirildi')::boolean,false) then
      perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('bos_bildirildi',true));
      perform oyun.bildir(hedef, format('⚖️ Gözaltı #%s: şu anda görev alabilecek uygun baro avukatı yok. Talebiniz açık; uygun avukat çıkar çıkmaz sistem görevlendirir. Dilerseniz kendiniz de avukat çağırabilirsiniz.',p_id),t);
      if bas is not null then perform oyun.bildir(bas, format('⚖️ Gözaltı #%s (%s): müdafi talebi için uygun avukat bulunamadı; talep açık bekliyor.',p_id,oyun.kad(hedef)),t); end if;
      perform oyun.mudafi_log(p_kaynak,p_id,'avukat_yok',null,null,null);
    end if;
    return 'avukat_yok';
  end if;
  perform oyun.mudafi_ata(p_kaynak,p_id,av,null,true);
  return 'atandi';
end $$;

create or replace function oyun.gozalti_mudafi_tick()
returns integer language plpgsql security definer set search_path to '' as $$
declare r record; n int:=0; v text;
begin
  if not pg_try_advisory_xact_lock(781232) then return 0; end if;
  for r in
    select 'sokak'::text kaynak, gozalti_id id from oyun.sokak_baro_talep where durum='bekliyor' or (durum='gorevlendirildi' and kapanis is null)
    union all
    select kaynak, dosya_id from oyun.gozalti_baro_talep where durum='bekliyor' or (durum='gorevlendirildi' and kapanis is null)
    limit 500
  loop
    begin
      v := oyun.mudafi_degerlendir(r.kaynak,r.id);
      if v in ('atandi','kapandi','kabul','kendi_avukati') then n:=n+1; end if;
    exception when others then
      raise warning 'gozalti_mudafi_tick %/%: %',r.kaynak,r.id,sqlerrm;
    end;
  end loop;
  return n;
end $$;

-- 3) Gözaltı dosyası: baro talebinin durumu ve gerekçesi ------------------
create or replace function oyun.gozalti_dosya(p_kaynak text, p_id bigint)
returns jsonb language plpgsql stable set search_path to '' as $function$
declare r jsonb; t timestamptz:=oyun.simdi(); tl jsonb;
begin
  if p_kaynak='sokak' then
    select jsonb_build_object('kaynak','sokak','id',g.id,'hedef',g.hedef,'baslangic',g.baslangic,'bitis',g.bitis,
      'aktif',(g.durum='aktif' and g.bitis>t),'avukat',g.avukat,'avukat_durum',g.avukat_durum,
      'yetkili',(select p.yapan from oyun.sokak_polis p where p.id=g.polis_id),
      'tur_ad','Eylem gözaltısı','gerekce','Eylem #'||g.eylem_id||' sırasında polis müdahalesi','eylem_id',g.eylem_id,
      'baro_talep',exists(select 1 from oyun.sokak_baro_talep b where b.gozalti_id=g.id and b.durum='bekliyor'))
      into r from oyun.sokak_gozalti g where g.id=p_id;
  elsif p_kaynak='icisleri' then
    select jsonb_build_object('kaynak','icisleri','id',k.id,'hedef',k.hedef,'baslangic',coalesce(k.karar_at,k.acilis),'bitis',k.bitis,
      'aktif',(k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>t),'avukat',k.avukat,'avukat_durum',k.avukat_durum,
      'yetkili',k.bakan,'tur_ad','İçişleri gözaltısı (mahkeme onaylı)','gerekce',k.gerekce,
      'baro_talep',exists(select 1 from oyun.gozalti_baro_talep b where b.kaynak='icisleri' and b.dosya_id=k.id and b.durum='bekliyor'))
      into r from oyun.icisleri_tedbir_v2 k where k.id=p_id and k.tur='gozalti';
  elsif p_kaynak='yonetim' then
    select jsonb_build_object('kaynak','yonetim','id',y.id,'hedef',y.hedef,'baslangic',y.baslangic,'bitis',y.bitis,
      'aktif',(y.durum='aktif' and y.bitis>t),'avukat',y.avukat,'avukat_durum',y.avukat_durum,
      'yetkili',y.yetkili,'tur_ad',case y.makam when 'cumhurbaskani' then 'Cumhurbaşkanlığı gözaltı kararı' else 'İçişleri Bakanlığı gözaltı kararı' end,
      'gerekce',y.gerekce,
      'baro_talep',exists(select 1 from oyun.gozalti_baro_talep b where b.kaynak='yonetim' and b.dosya_id=y.id and b.durum='bekliyor'))
      into r from oyun.yonetim_tutuklama y where y.id=p_id;
  else
    raise exception 'Geçersiz gözaltı türü';
  end if;
  if r is null then raise exception 'Gözaltı dosyası bulunamadı'; end if;
  tl := oyun.mudafi_talep(p_kaynak,p_id);
  if tl is not null then
    r := r || jsonb_build_object('baro_durum',tl->>'durum','baro_not',tl->>'gerekce',
      'baro_otomatik_at', case when tl->>'durum'='bekliyor' then (tl->>'zaman')::timestamptz + make_interval(mins => oyun.gozalti_ayar('mudafi_baskan_sure_dk',15)::int) end,
      'baro_yanit_son', case when tl->>'durum'='gorevlendirildi' and r->>'avukat_durum'='cagrildi' then (tl->>'cagri_zamani')::timestamptz + make_interval(mins => oyun.gozalti_ayar('mudafi_yanit_sure_dk',20)::int) end);
  end if;
  return r;
end $function$;

-- 4) RPC'ler ---------------------------------------------------------------
create or replace function public.gozalti_baro_iste2(p_kaynak text, p_id bigint)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); d jsonb; bas uuid; v text; t timestamptz:=oyun.simdi();
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  if p_kaynak not in ('sokak','icisleri','yonetim') then raise exception 'Geçersiz gözaltı türü'; end if;
  if p_kaynak='sokak' then perform pg_advisory_xact_lock(781231,1); end if;
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if (d->>'hedef')::uuid is distinct from u then raise exception 'Yalnız kendi gözaltı dosyanız için talep yapabilirsiniz'; end if;
  if not (d->>'aktif')::boolean then raise exception 'Bu gözaltı sona ermiş'; end if;
  if d->>'avukat_durum'='kabul' then raise exception 'Görevdeki bir avukatınız zaten var'; end if;
  if (d->>'baro_talep')::boolean or (d->>'baro_durum'='gorevlendirildi' and d->>'avukat_durum'='cagrildi') then
    raise exception 'Baro talebiniz zaten işlemde'; end if;
  perform oyun.mudafi_talep_ac(p_kaynak,p_id,u,t,'Müdafi aranıyor',true);
  perform oyun.mudafi_log(p_kaynak,p_id,'talep',null,u,null);
  bas := oyun.baro_baskan();
  if bas is not null and oyun.gozalti_aktif(bas) is null then
    perform oyun.bildir(bas, format('⚖️ %s gözaltında (dosya #%s) ve barodan müdafi istiyor. %s dakika içinde Menü › Gözaltı ve Avukat › Baro bölümünden görevlendirin; görevlendirilmezse sistem uygun avukatı otomatik görevlendirir.',
      oyun.kad(u), p_id, oyun.gozalti_ayar('mudafi_baskan_sure_dk',15)::int), t);
  end if;
  v := oyun.mudafi_degerlendir(p_kaynak,p_id);
  return jsonb_build_object('tamam',true,'durum',case when v='atandi' then 'gorevlendirildi' else 'bekliyor' end,'sonuc',v,
    'mesaj',case v when 'atandi' then 'Baro adına müdafi görevlendirildi.'
                   when 'avukat_yok' then 'Şu anda uygun avukat yok; talebiniz açık kalacak ve uygun avukat çıkınca görevlendirilecek.'
                   else format('Talebiniz baroya iletildi. En geç %s dakika içinde müdafi görevlendirilir.',oyun.gozalti_ayar('mudafi_baskan_sure_dk',15)::int) end);
end $function$;

create or replace function public.sokak_baro_iste(p_gozalti bigint)
returns jsonb language sql security definer set search_path to '' as $$
  select public.gozalti_baro_iste2('sokak',p_gozalti)
$$;

create or replace function public.gozalti_baro_gonder2(p_kaynak text, p_id bigint, p_avukat_kad text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); av uuid; d jsonb; engel text;
begin
  if u is null or u is distinct from oyun.baro_baskan() then raise exception 'Yalnız baro başkanı (ya da geçici yetkili) müdafi gönderebilir'; end if;
  if p_kaynak not in ('sokak','icisleri','yonetim') then raise exception 'Geçersiz gözaltı türü'; end if;
  if p_kaynak='sokak' then perform pg_advisory_xact_lock(781231,1); end if;
  av := oyun.gozalti_kullanici(p_avukat_kad);
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if not (d->>'aktif')::boolean then raise exception 'Devam eden gözaltı yok'; end if;
  if d->>'avukat_durum'='kabul' then raise exception 'Bu dosyanın avukatı zaten görevde'; end if;
  engel := oyun.mudafi_engel(av,(d->>'hedef')::uuid,(d->>'yetkili')::uuid);
  if engel is not null then raise exception 'Bu avukat görevlendirilemez: %', engel; end if;
  if d->>'avukat_durum'='cagrildi' and d->>'avukat' is not null and (d->>'avukat')::uuid<>av then
    perform oyun.bildir((d->>'avukat')::uuid, format('⚖️ Gözaltı #%s için yapılan avukatlık çağrısı, baro başka müdafi görevlendirdiği için düştü.',p_id));
  end if;
  perform oyun.mudafi_ata(p_kaynak,p_id,av,u,false);
  return jsonb_build_object('tamam',true,'durum','gorevlendirildi');
end $function$;

create or replace function public.sokak_baro_gonder(p_gozalti bigint, p_avukat uuid)
returns jsonb language sql security definer set search_path to '' as $$
  select public.gozalti_baro_gonder2('sokak',p_gozalti,oyun.kad(p_avukat))
$$;

-- Avukat görevden çekilir; zorunlu müdafilik kesintiye uğramaz (CMK m.151)
create or replace function public.gozalti_avukat_cekil(p_kaynak text, p_id bigint, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); d jsonb; t timestamptz:=oyun.simdi(); v text; bas uuid;
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  if char_length(btrim(coalesce(p_gerekce,''))) < 10 then raise exception 'Çekilme gerekçesi en az 10 karakter olmalı'; end if;
  if p_kaynak='sokak' then perform pg_advisory_xact_lock(781231,1); end if;
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if (d->>'avukat')::uuid is distinct from u or d->>'avukat_durum'<>'kabul' then raise exception 'Bu dosyada üstlendiğiniz bir müdafilik yok'; end if;
  if not (d->>'aktif')::boolean then raise exception 'Gözaltı zaten sona ermiş'; end if;
  perform oyun.mudafi_dosya_yaz(p_kaynak,p_id,null,'yok');
  perform oyun.mudafi_talep_ac(p_kaynak,p_id,(d->>'hedef')::uuid,t - make_interval(mins => oyun.gozalti_ayar('mudafi_baskan_sure_dk',15)::int),'Önceki müdafi çekildi; yeni müdafi aranıyor',false);
  perform oyun.mudafi_talep_guncelle(p_kaynak,p_id,jsonb_build_object('denenen_ekle',u));
  perform oyun.mudafi_log(p_kaynak,p_id,'cekildi',u,u,left(btrim(p_gerekce),300));
  perform oyun.bildir((d->>'hedef')::uuid, format('⚖️ Avukatınız %s gözaltı #%s dosyasındaki görevinden çekildi. Baro size derhal yeni müdafi görevlendiriyor; dilerseniz kendiniz de avukat çağırabilirsiniz.',oyun.kad(u),p_id),t);
  bas := oyun.baro_baskan();
  if bas is not null and bas<>u then perform oyun.bildir(bas, format('⚖️ Gözaltı #%s (%s): müdafi %s çekildi; sistem yeni müdafi görevlendiriyor.',p_id,oyun.kad((d->>'hedef')::uuid),oyun.kad(u)),t); end if;
  v := oyun.mudafi_degerlendir(p_kaynak,p_id);
  return jsonb_build_object('tamam',true,'sonuc',v);
end $function$;

-- Dosyanın müdafi geçmişi (gözaltındaki kişi, avukatı ve baro başkanı görebilir)
create or replace function public.gozalti_mudafi_gecmis(p_kaynak text, p_id bigint)
returns jsonb language plpgsql stable security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); d jsonb;
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if u is distinct from (d->>'hedef')::uuid and u is distinct from (d->>'avukat')::uuid and u is distinct from oyun.baro_baskan()
     and not exists(select 1 from oyun.profiller p where p.id=u and p.yonetici) then
    raise exception 'Bu dosyanın müdafi kayıtlarını göremezsiniz'; end if;
  return jsonb_build_object('talep', (oyun.mudafi_talep(p_kaynak,p_id) - 'denenen' - 'talep_eden' - 'avukat' - 'gorevlendiren')
      || jsonb_build_object('avukat_kad',oyun.kad((oyun.mudafi_talep(p_kaynak,p_id)->>'avukat')::uuid)),
    'kayitlar', coalesce((select jsonb_agg(jsonb_build_object('olay',i.olay,'avukat',oyun.kad(i.avukat),'zaman',i.zaman) order by i.zaman desc)
       from (select * from oyun.mudafi_islem i where i.kaynak=p_kaynak and i.dosya_id=p_id order by zaman desc limit 30) i),'[]'::jsonb));
end $function$;

-- Yanıt fonksiyonları: ret sonrası talep kendiliğinden yeniden değerlendirilir
create or replace function public.icisleri_avukat_yanit(p_id bigint, p_kabul boolean)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); d oyun.icisleri_tedbir_v2;
begin
 if u is null or p_kabul is null then raise exception 'Giriş ve cevap gerekli'; end if;
 select * into d from oyun.icisleri_tedbir_v2 where id=p_id for update;
 if d.id is null or d.avukat<>u or d.avukat_durum<>'cagrildi' then raise exception 'Aktif avukatlık daveti yok'; end if;
 if p_kabul and not (d.tur='gozalti' and d.durum in ('onay','itiraz') and d.bitis>oyun.simdi()) then raise exception 'Gözaltı sona ermiş'; end if;
 update oyun.icisleri_tedbir_v2 set avukat_durum=case when p_kabul then 'kabul' else 'red' end where id=p_id;
 perform oyun.bildir(d.hedef,'Avukat '||oyun.kad(u)||' gözaltı #'||p_id||' için '||case when p_kabul
   then 'savunmanızı üstlendi. Gözaltı süresince yalnız onunla özel mesajlaşabilirsiniz; adınıza açıklamayı o yapar.'
   else 'görevi reddetti. Baro talebiniz varsa sistem başka müdafi görevlendirir; dilerseniz başka avukat çağırabilirsiniz.' end);
 perform oyun.mudafi_log('icisleri',p_id,case when p_kabul then 'kabul' else 'reddedildi' end,u,u,null);
 begin perform oyun.mudafi_degerlendir('icisleri',p_id); exception when others then null; end;
 return jsonb_build_object('tamam',true);
end $function$;

create or replace function public.sokak_avukat_cevap(p_gozalti bigint, p_kabul boolean)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); g oyun.sokak_gozalti;
begin
 if u is null or p_kabul is null then raise exception 'Oturum ve cevap gerekli';end if;
 select * into g from oyun.sokak_gozalti where id=p_gozalti for update;
 if g.avukat is distinct from u or g.avukat_durum<>'cagrildi' then raise exception 'Sizin için bekleyen avukat çağrısı bulunmuyor';end if;
 if p_kabul and (g.durum<>'aktif' or g.bitis<=oyun.simdi()) then raise exception 'Gözaltı sona ermiş'; end if;
 update oyun.sokak_gozalti set avukat_durum=case when p_kabul then 'kabul' else 'ret' end where id=p_gozalti;
 perform oyun.bildir(g.hedef,'Avukat '||oyun.kad(u)||' gözaltı #'||g.id||' için '||case when p_kabul then 'savunmanızı üstlendi. Hukuk bölümünden görüşebilirsiniz.'
   else 'görevi reddetti. Baro talebiniz varsa sistem başka müdafi görevlendirir.' end);
 perform oyun.mudafi_log('sokak',p_gozalti,case when p_kabul then 'kabul' else 'reddedildi' end,u,u,null);
 begin perform oyun.mudafi_degerlendir('sokak',p_gozalti); exception when others then null; end;
 return jsonb_build_object('tamam',true);
end $function$;

create or replace function public.gozalti_avukat_yanit2(p_kaynak text, p_id bigint, p_kabul boolean)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare u uuid:=auth.uid(); y oyun.yonetim_tutuklama;
begin
  if u is null or p_kabul is null then raise exception 'Oturum ve cevap gerekli'; end if;
  if p_kaynak='sokak' then return public.sokak_avukat_cevap(p_id, p_kabul);
  elsif p_kaynak='icisleri' then return public.icisleri_avukat_yanit(p_id, p_kabul);
  elsif p_kaynak<>'yonetim' then raise exception 'Geçersiz gözaltı türü'; end if;
  select * into y from oyun.yonetim_tutuklama where id=p_id for update;
  if y.id is null or y.avukat is distinct from u or y.avukat_durum<>'cagrildi' then raise exception 'Sizin için bekleyen avukat çağrısı bulunmuyor'; end if;
  if p_kabul and (y.durum<>'aktif' or y.bitis<=oyun.simdi()) then raise exception 'Gözaltı sona ermiş'; end if;
  update oyun.yonetim_tutuklama set avukat_durum=case when p_kabul then 'kabul' else 'red' end where id=p_id;
  perform oyun.bildir(y.hedef, 'Avukat '||oyun.kad(u)||' gözaltı #'||p_id||' için '||case when p_kabul
    then 'savunmanızı üstlendi. Gözaltı süresince yalnız onunla özel mesajlaşabilirsiniz; adınıza açıklamayı o yapar.'
    else 'görevi reddetti. Baro talebiniz varsa sistem başka müdafi görevlendirir; dilerseniz başka avukat çağırabilirsiniz.' end);
  perform oyun.mudafi_log('yonetim',p_id,case when p_kabul then 'kabul' else 'reddedildi' end,u,u,null);
  begin perform oyun.mudafi_degerlendir('yonetim',p_id); exception when others then null; end;
  return jsonb_build_object('tamam',true);
end $function$;

-- 5) Dava adli yardımı: CMK ayrımı ve "uygun avukat yok" bildirimi ----------
create or replace function oyun.dava_ceza_mi(p_tur text)
returns boolean language sql immutable set search_path to '' as $$
  select coalesce(p_tur,'') in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk')
$$;

create or replace function public.baro_adli_yardim_iste(p_dava bigint, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; tr text; b oyun.baro; para numeric; yid bigint; bas uuid; kisi boolean; v_ucretli boolean; v_cmk boolean; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.adliye_davalar where id=p_dava;
 if d.id is null or not (d.durum='acik' or (d.durum='karar' and not d.kesin and d.karar<>'dusme' and t<=coalesce(d.istinaf_son,t)
     and not exists(select 1 from oyun.adliye_istinaf i where i.dava_id=d.id))) then
  raise exception 'Avukat görevlendirmesi yalnız açık dosyalarda ya da istinaf süresi işleyen kararlarda istenebilir.';
 end if;
 tr:=case when oyun.dava_muvekkil_mi(d,'davali',p.id) then 'davali' when oyun.dava_muvekkil_mi(d,'davaci',p.id) then 'davaci' end;
 if tr is null then raise exception 'Avukat görevlendirmesini yalnız davanın tarafı (ya da parti/kurum adına yetkili kişi) isteyebilir.'; end if;
 if exists(select 1 from oyun.avukat_vekaletleri where dava_id=d.id and taraf=tr and aktif) then raise exception 'Bu dosyada zaten avukatın var.'; end if;
 if exists(select 1 from oyun.baro_adli_yardim where dava_id=d.id and taraf=tr and durum='bekliyor') then raise exception 'Bu dosya için bekleyen bir görevlendirme talebin var.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 10 and 1500 then raise exception 'Talep gerekçesi 10-1500 karakter olmalı.'; end if;
 select * into b from oyun.baro where id=1;
 select c.para into para from oyun.cuzdan c where c.user_id=p.id;
 kisi:=(tr='davali' and d.davali=p.id) or (tr='davaci' and d.davaci=p.id and d.davaci_parti is null);
 -- CMK m.150: ceza niteliğindeki davada sanığa müdafi, servetine bakılmadan ücretsiz görevlendirilir.
 v_cmk := kisi and tr='davali' and oyun.dava_ceza_mi(d.tur);
 v_ucretli:=not v_cmk and (not kisi or coalesce(para,0)>=b.adli_yardim_sinir);
 if v_ucretli and coalesce(para,0)<b.adli_yardim_ucret then
  raise exception 'Ücretli baro görevlendirmesi için cüzdanında en az % ₺ olmalı.',oyun.tl(b.adli_yardim_ucret);
 end if;
 if not exists(select 1 from oyun.baro_uyeleri u where u.durum='aktif' and oyun.avukat_mi(u.user_id)
     and not oyun.dava_muvekkil_mi(d,'davaci',u.user_id) and not oyun.dava_muvekkil_mi(d,'davali',u.user_id)
     and not exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.aktif and v.avukat_id=u.user_id)) then
  if not v_cmk then
   raise exception 'Şu anda bu dosyada görev alabilecek avukat yok; savunmanı ya da istinafını kendin yapabilirsin.';
  end if;
 end if;
 insert into oyun.baro_adli_yardim(dava_id,taraf,talep_eden,gerekce,ucretli,cmk) values(d.id,tr,p.id,trim(p_gerekce),v_ucretli,v_cmk) returning id into yid;
 bas:=oyun.baro_baskan();
 if bas is not null then
  perform oyun.bildir(bas,format('Dava #%s için %s avukat görevlendirme talebi geldi. %s içinde Türkiye Barosu > Davalar bölümünden görevlendir; karar verilmezse sistem uygun avukatı otomatik atar.',d.id,
    case when v_cmk then 'CMK (zorunlu müdafilik, ücretsiz)' when v_ucretli then 'ücretli' else 'adli yardım (ücretsiz)' end,
    case when v_cmk then oyun.gozalti_ayar('cmk_dava_sure_dk',30)::int||' dakika' else '3 saat' end),t);
 end if;
 perform oyun.bildir(u.user_id,format('Dava #%s için avukat görevlendirme talebi var. Gönüllüysen baro başkanı ya da sistem seni görevlendirebilir.',d.id),t)
  from oyun.baro_uyeleri u where u.durum='aktif' and u.gonullu and u.user_id is distinct from bas and oyun.avukat_mi(u.user_id)
   and not oyun.dava_muvekkil_mi(d,'davaci',u.user_id) and not oyun.dava_muvekkil_mi(d,'davali',u.user_id);
 return jsonb_build_object('id',yid,'ucretli',v_ucretli,'cmk',v_cmk,'ucret',case when v_ucretli then b.adli_yardim_ucret else 0 end,
   'mesaj',case when v_cmk then format('Ceza davasında müdafi talebin alındı (CMK, ücretsiz). %s dakika içinde başkan atamazsa sistem otomatik atar.',oyun.gozalti_ayar('cmk_dava_sure_dk',30)::int)
     when v_ucretli then format('Talebin alındı. Görevlendirme yapılınca %s ₺ baro tarifesi ücreti cüzdanından ödenecek; 3 saat içinde başkan atamazsa sistem otomatik atar.',oyun.tl(b.adli_yardim_ucret))
     else 'Adli yardım talebin alındı. 3 saat içinde başkan atamazsa sistem gönüllü avukatlardan otomatik atar.' end);
end $function$;

create or replace function oyun.baro_adli_yardim_otomatik(t timestamp with time zone)
returns integer language plpgsql set search_path to '' as $function$
declare y record; d oyun.adliye_davalar; av uuid; n int:=0; bas uuid:=oyun.baro_baskan();
begin
 for y in select a.* from oyun.baro_adli_yardim a join oyun.profiller pr on pr.id=a.talep_eden
   where a.durum='bekliyor' and not pr.yasakli
     and (bas is null
          or (a.cmk and a.zaman<=t-make_interval(mins => oyun.gozalti_ayar('cmk_dava_sure_dk',30)::int))
          or (not a.cmk and a.zaman<=t-interval '3 hours'))
   order by a.cmk desc, a.id loop
  select * into d from oyun.adliye_davalar where id=y.dava_id;
  av:=null;
  select u.user_id into av from oyun.baro_uyeleri u
   where u.durum='aktif' and oyun.avukat_mi(u.user_id) and u.user_id is distinct from y.talep_eden
     and oyun.gozalti_aktif(u.user_id) is null
     and not oyun.dava_muvekkil_mi(d,'davaci',u.user_id) and not oyun.dava_muvekkil_mi(d,'davali',u.user_id)
     and not exists(select 1 from oyun.avukat_vekaletleri v where v.dava_id=d.id and v.aktif and v.avukat_id=u.user_id)
   order by u.gonullu desc,
     (select count(*) from oyun.avukat_vekaletleri v2 join oyun.adliye_davalar d2 on d2.id=v2.dava_id where v2.avukat_id=u.user_id and v2.aktif and d2.durum='acik'),
     random()
   limit 1;
  if av is null then
   if not y.bos_bildirildi then
    update oyun.baro_adli_yardim set bos_bildirildi=true where id=y.id;
    perform oyun.bildir(y.talep_eden,format('Dava #%s: şu anda görev alabilecek uygun baro avukatı yok. Talebin açık; uygun avukat çıkınca sistem görevlendirir.',y.dava_id),t);
   end if;
   continue;
  end if;
  begin
   perform oyun.baro_gorevlendir(y.id,av,null,case when y.cmk then 'Baro başkanı süresinde karar vermediği için sistem CMK müdafisini otomatik görevlendirdi (CMK m.150).'
     else 'Baro başkanı 3 saat içinde karar vermediği için sistem otomatik görevlendirdi.' end,true);
   n:=n+1;
  exception when others then
   raise warning 'baro_adli_yardim_otomatik #%: %',y.id,sqlerrm;
   if y.ucretli then
    update oyun.baro_adli_yardim set durum='iptal',karar_gerekce='Görevlendirme ücreti cüzdandan tahsil edilemedi',karar_at=now() where id=y.id and durum='bekliyor';
    perform oyun.bildir(y.talep_eden,format('Dava #%s avukat görevlendirmesi yapılamadı: ücretli baro tarifesi ücreti cüzdanından tahsil edilemedi. Ücretsiz adli yardım koşullarını taşıyorsan yeniden talep edebilirsin.',y.dava_id),t);
   end if;
  end;
 end loop;
 return n;
end $function$;

-- 6) Zamanlayıcı ------------------------------------------------------------
insert into oyun.zamanlayici_adim(adim,komut,periyot_dk,ofset_dk,sira,aktif)
values('gozalti_mudafi','select oyun.gozalti_mudafi_tick()',1,0,60,true)
on conflict (adim) do update set komut=excluded.komut, periyot_dk=excluded.periyot_dk, aktif=true;

-- 7) Eski açık talepler: bitmiş gözaltılar kapanır, sürenler hemen değerlendirilir
select oyun.gozalti_mudafi_tick();
update oyun.gozalti_baro_talep set durum='gorevlendirildi' where durum='kapandi' and avukat is not null and gorevlendiren is not null and kapanis is not null;
update oyun.sokak_baro_talep set durum='gorevlendirildi' where durum='kapandi' and avukat is not null and gorevlendiren is not null and kapanis is not null;

revoke all on function oyun.mudafi_degerlendir(text,bigint) from public, anon, authenticated;
revoke all on function oyun.mudafi_ata(text,bigint,uuid,uuid,boolean) from public, anon, authenticated;
revoke all on function oyun.gozalti_mudafi_tick() from public, anon, authenticated;
do $g$
declare f text;
begin
  foreach f in array array['oyun.mudafi_log(text,bigint,text,uuid,uuid,text)','oyun.mudafi_yuk(uuid)','oyun.mudafi_engel(uuid,uuid,uuid)',
    'oyun.mudafi_aday(uuid,uuid,uuid[])','oyun.mudafi_dosya_yaz(text,bigint,uuid,text)','oyun.mudafi_talep(text,bigint)',
    'oyun.mudafi_talep_guncelle(text,bigint,jsonb)','oyun.mudafi_talep_ac(text,bigint,uuid,timestamptz,text,boolean)','oyun.dava_ceza_mi(text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  revoke all on function public.gozalti_avukat_cekil(text,bigint,text) from public, anon;
  revoke all on function public.gozalti_mudafi_gecmis(text,bigint) from public, anon;
  grant execute on function public.gozalti_avukat_cekil(text,bigint,text) to authenticated;
  grant execute on function public.gozalti_mudafi_gecmis(text,bigint) to authenticated;
end $g$;
