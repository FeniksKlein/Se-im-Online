-- 16.11.2026 · Kayıt başvurusu: ad soyad + moderatör onayı (kalıcı kural)
-- - Oyuna başlarken kullanıcı adının yanında AD SOYAD da istenir.
-- - Her başvuru onaydan geçmeden oyuna başlanamaz (mevcut kural korunur).
-- - Onay/ret yetkisi yalnız yöneticide değil, "Kayıt onayı" yetkisi verilen her moderatörde
--   bireysel olarak vardır; tek moderatörün kararı yeterlidir, her karar günlüğe yazılır.
-- - Gerçek siyasetçi (ya da terör örgütü lideri gibi kamuoyunca bilinen gerçek kişi) adıyla yapılan
--   başvurular reddedilir; başvuru ekranında bu açıkça yazar. Bilinen isimlere benzeyen başvurular
--   moderatöre uyarıyla gösterilir, son kararı moderatör verir.
-- - Reddedilen oyuncu aynı e-posta/şifreyle yeniden başvurabilir; ancak daha önce reddedilen ad
--   soyadı tekrar kullanamaz, ismini değiştirmek zorundadır.

alter table oyun_yonetim.kayit_basvurulari add column if not exists ad_soyad text;
alter table oyun_yonetim.kayit_basvurulari add column if not exists ret_neden text;
alter table oyun_yonetim.kayit_basvurulari add column if not exists red_sayisi integer not null default 0;
alter table oyun.profiller add column if not exists ad_soyad text;

create table if not exists oyun_yonetim.kayit_karar_log (
  id bigserial primary key,
  user_id uuid not null,
  kad text,
  ad_soyad text,
  ad_norm text,
  karar text not null check (karar in ('onay','ret')),
  neden text,
  veren uuid,
  zaman timestamptz not null default now()
);
create index if not exists kayit_karar_log_user_ix on oyun_yonetim.kayit_karar_log(user_id, zaman desc);
alter table oyun_yonetim.kayit_karar_log enable row level security;
revoke all on oyun_yonetim.kayit_karar_log from public, anon, authenticated;

-- Bilinen gerçek kişi adları (yalnız uyarı içindir; kararı moderatör verir)
create table if not exists oyun_yonetim.yasak_isim (
  ad_norm text primary key,
  ad text not null,
  aciklama text
);
alter table oyun_yonetim.yasak_isim enable row level security;
revoke all on oyun_yonetim.yasak_isim from public, anon, authenticated;

create or replace function oyun_yonetim.isim_norm(p text)
returns text language sql immutable set search_path to '' as $$
  select btrim(regexp_replace(
           translate(lower(replace(replace(coalesce(p,''),'İ','i'),'I','ı')), 'çğıöşüâîû', 'cgiosuaiu'),
           '[^a-z]+', ' ', 'g'))
$$;

insert into oyun_yonetim.yasak_isim(ad_norm, ad, aciklama)
select oyun_yonetim.isim_norm(v.ad), v.ad, v.a from (values
  ('Recep Tayyip Erdoğan','Cumhurbaşkanı'),('Tayyip Erdoğan','Cumhurbaşkanı'),
  ('Abdullah Öcalan','Terör örgütü elebaşı'),
  ('Kemal Kılıçdaroğlu','Siyasetçi'),('Özgür Özel','Siyasetçi'),('Devlet Bahçeli','Siyasetçi'),
  ('Ekrem İmamoğlu','Siyasetçi'),('Mansur Yavaş','Siyasetçi'),('Meral Akşener','Siyasetçi'),
  ('Ali Babacan','Siyasetçi'),('Ahmet Davutoğlu','Siyasetçi'),('Fatih Erbakan','Siyasetçi'),
  ('Ümit Özdağ','Siyasetçi'),('Selahattin Demirtaş','Siyasetçi'),('Müsavat Dervişoğlu','Siyasetçi'),
  ('Binali Yıldırım','Siyasetçi'),('Süleyman Soylu','Siyasetçi'),('Numan Kurtulmuş','Siyasetçi'),
  ('Abdullah Gül','Siyasetçi'),('Muharrem İnce','Siyasetçi'),('Temel Karamollaoğlu','Siyasetçi'),
  ('Tülay Hatimoğulları','Siyasetçi'),('Tuncer Bakırhan','Siyasetçi'),('Mustafa Kemal Atatürk','Tarihî devlet kurucusu'),
  ('İsmet İnönü','Tarihî siyasetçi'),('Adnan Menderes','Tarihî siyasetçi'),('Süleyman Demirel','Tarihî siyasetçi'),
  ('Bülent Ecevit','Tarihî siyasetçi'),('Necmettin Erbakan','Tarihî siyasetçi'),('Turgut Özal','Tarihî siyasetçi'),
  ('Alparslan Türkeş','Tarihî siyasetçi'),('Fethullah Gülen','Terör örgütü elebaşı')
) v(ad,a)
on conflict (ad_norm) do nothing;

-- Benzerlik: tam eşleşme ya da bilinen adın tüm kelimelerini içerme (ör. "Tayyip Erdoğan 1")
create or replace function oyun_yonetim.isim_uyari(p_ad text)
returns text language sql stable set search_path to '' as $$
  select string_agg(y.ad || ' (' || coalesce(y.aciklama,'') || ')', ', ')
    from oyun_yonetim.yasak_isim y
   where oyun_yonetim.isim_norm(p_ad) = y.ad_norm
      or (select bool_and(position(' '||w||' ' in ' '||oyun_yonetim.isim_norm(p_ad)||' ') > 0)
            from unnest(string_to_array(y.ad_norm,' ')) w)
$$;

-- Kayıt onay yetkisi: yönetici ya da "kayit" yetkili moderatör
create or replace function oyun.mod_yetki_tanim()
returns table(kod text, ad text, aciklama text, sira integer)
language sql immutable set search_path to 'oyun', 'public', 'extensions', 'pg_temp' as $$
  values ('ozet',        'Özet',                    'Oyuncu sayısı, aktiflik, açık şikâyet gibi özet rakamları görür.', 1),
         ('sikayet',     'Şikâyetler',              'Şikâyet edilen mesaj ve yayınları görür; "sorun yok" ya da "gizle" kararı verir.', 2),
         ('sustur',      'Susturma',                'Oyuncuyu susturur, susturmayı kaldırır.', 3),
         ('hesap_kapat', 'Engelleme ve hesap kapatma', 'Oyuncuyu süreli ya da kalıcı engeller, hesabı kapatır ya da yeniden açar.', 4),
         ('oyuncu_ara',  'Oyuncu inceleme',         'Oyuncunun bilgilerini ve son mesajlarını görür.', 5),
         ('eposta',      'E-posta görme',           'Oyuncu incelerken e-posta adresini de görür (kişisel veri; dikkatli ver).', 6),
         ('duyuru',      'Duyuru ve bildirim',      'Tüm oyunculara duyuru, seçtiği oyunculara bildirim gönderir.', 7),
         ('coklu_hesap', 'Çoklu hesap incelemesi',  'Aynı cihazdan açılan hesapları görür, gerçek kişi olanları onaylar.', 8),
         ('kurallar',    'Kurallar ve ayarlar',     'Vatandaşlık, parti kurma, teşkilat, havale ve banka kurallarını değiştirir.', 9),
         ('ekonomi',     'MASAK (ekonomi denetimi)', 'Şüpheli işlem bildirimlerini inceler; temiz, ihtar ya da el koyma kararı verir.', 10),
         ('para',        'Para ve kıdem',           'Oyunculara, bir ile, bir partiye ya da herkese para ve kıdem ekler veya çıkarır.', 11),
         ('makam',       'Görev verme ve alma',     'Oyuncuyu makama atar, görevden alır; parti görevlerini, ilini, partisini ve aday olma yasağını değiştirir.', 12),
         ('kayit',       'Kayıt onayı',             'Yeni oyuncu başvurularını (kullanıcı adı, ad soyad, il) inceler; oyuna kabul eder ya da gerekçeyle reddeder. Gerçek siyasetçi adıyla yapılan başvurular reddedilir.', 13)
$$;

create or replace function oyun_yonetim.kayit_yetkili()
returns oyun.profiller language plpgsql stable security definer set search_path to '' as $$
declare p oyun.profiller;
begin
  select * into p from oyun.profiller where id=auth.uid();
  if p.id is null or coalesce(p.yasakli,false) then raise exception 'Bu işlem için yetkin yok.'; end if;
  if p.yonetici and exists(select 1 from oyun.yonetici_kimlik y where y.user_id=p.id) then return p; end if;
  if exists(select 1 from oyun.moderatorler m where m.user_id=p.id and 'kayit' = any(m.yetkiler)) then return p; end if;
  raise exception 'Kayıt başvurularını yalnız yönetici ve "Kayıt onayı" yetkili moderatörler görebilir.';
end $$;
revoke all on function oyun_yonetim.kayit_yetkili() from public, anon, authenticated;

create or replace function oyun_yonetim.ad_soyad_kontrol(p_ad text)
returns text language plpgsql immutable set search_path to '' as $$
declare a text := btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
begin
  if char_length(a) < 5 or char_length(a) > 50 then raise exception 'Ad soyad 5-50 karakter olmalı.'; end if;
  if a !~ '^[A-Za-zÇĞİÖŞÜçğıöşüÂÎÛâîû'' ]+$' then raise exception 'Ad soyad yalnız harflerden oluşmalı.'; end if;
  if array_length(string_to_array(a,' '),1) < 2 then raise exception 'Adını ve soyadını birlikte yaz (en az iki kelime).'; end if;
  return a;
end $$;

-- Başvuru (ilk ya da ret sonrası yeniden)
create or replace function public.kayit_basvuru_gonder(p_kad text, p_il integer, p_ad_soyad text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); b oyun_yonetim.kayit_basvurulari; k text := btrim(coalesce(p_kad,'')); a text; an text;
begin
  if u is null then raise exception 'Önce giriş yap.'; end if;
  select * into b from oyun_yonetim.kayit_basvurulari where user_id=u for update;
  if b.user_id is null then raise exception 'Bu hesaba kayıt onayı gerekmiyor.'; end if;
  if b.durum='onaylandi' then raise exception 'Bu hesap zaten onaylanmış.'; end if;
  a := oyun_yonetim.ad_soyad_kontrol(p_ad_soyad);
  an := oyun_yonetim.isim_norm(a);
  if exists(select 1 from oyun_yonetim.kayit_karar_log l where l.user_id=u and l.karar='ret' and l.ad_norm=an) then
    raise exception 'Bu ad soyad ile yaptığın başvuru daha önce reddedildi. Yeniden başvurmak için farklı bir ad soyad yazmalısın.';
  end if;
  if k !~ '^[A-Za-z0-9_çğıöşüÇĞİÖŞÜ]{3,20}$' then raise exception 'Kullanıcı adı 3-20 karakter olmalı.'; end if;
  if oyun.yasakli_kad(k) then raise exception 'Bu kullanıcı adı kullanılamaz.'; end if;
  if exists(select 1 from oyun.profiller where lower(kad)=lower(k))
     or exists(select 1 from oyun_yonetim.kayit_basvurulari where user_id<>u and lower(kad)=lower(k) and durum in ('beklemede','onaylandi'))
  then raise exception 'Bu kullanıcı adı alınmış.'; end if;
  if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçersiz il.'; end if;
  update oyun_yonetim.kayit_basvurulari
     set kad=k, il_id=p_il, ad_soyad=a, basvuru_at=clock_timestamp(), durum='beklemede',
         karar_at=null, karar_veren=null, ret_neden=null
   where user_id=u;
  return jsonb_build_object('durum','beklemede');
end $$;

-- Eski istemci uyumluluğu: ad soyad olmadan başvuru alınmaz
create or replace function public.kayit_basvur(p_kad text, p_il integer)
returns jsonb language plpgsql security definer set search_path to '' as $$
begin
  raise exception 'Başvuru için ad soyad da gerekiyor. Uygulamayı güncelleyip yeniden dene.';
end $$;

create or replace function public.kayit_durumum()
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); b oyun_yonetim.kayit_basvurulari;
begin
  if u is null then raise exception 'Önce giriş yap.'; end if;
  select * into b from oyun_yonetim.kayit_basvurulari where user_id=u;
  if b.user_id is null then return jsonb_build_object('gerekli',false); end if;
  return jsonb_build_object('gerekli',true,'durum',b.durum,'kad',b.kad,'il_id',b.il_id,'ad_soyad',b.ad_soyad,
    'basvuru_at',b.basvuru_at,'karar_at',b.karar_at,'ret_neden',b.ret_neden,'red_sayisi',b.red_sayisi,
    'reddedilen_isimler',coalesce((select jsonb_agg(distinct l.ad_soyad) from oyun_yonetim.kayit_karar_log l where l.user_id=u and l.karar='ret' and l.ad_soyad is not null),'[]'::jsonb));
end $$;

create or replace function public.admin_kayit_basvurulari()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun_yonetim.kayit_yetkili();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'user_id',b.user_id,'kad',b.kad,'ad_soyad',b.ad_soyad,'il',i.ad,
      'olusturma',b.olusturma,'basvuru_at',b.basvuru_at,'durum',b.durum,'karar_at',b.karar_at,
      'karar_veren',oyun.kad(b.karar_veren),'ret_neden',b.ret_neden,'red_sayisi',b.red_sayisi,
      'uyari',case when b.durum='beklemede' then oyun_yonetim.isim_uyari(b.ad_soyad) end,
      'onceki_red',(select jsonb_agg(jsonb_build_object('ad_soyad',l.ad_soyad,'neden',l.neden,'veren',oyun.kad(l.veren),'zaman',l.zaman) order by l.zaman desc)
                      from oyun_yonetim.kayit_karar_log l where l.user_id=b.user_id and l.karar='ret')
    ) order by (b.durum='beklemede') desc, b.basvuru_at desc nulls last, b.olusturma desc)
    from (select * from oyun_yonetim.kayit_basvurulari x where x.basvuru_at is not null
           order by (x.durum='beklemede') desc, x.basvuru_at desc nulls last limit 300) b
    left join oyun.iller i on i.id=b.il_id
  ),'[]'::jsonb);
end $$;

create or replace function public.admin_kayit_karar2(p_user uuid, p_onay boolean, p_neden text default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun_yonetim.kayit_yetkili(); b oyun_yonetim.kayit_basvurulari; t timestamptz := clock_timestamp(); n text;
begin
  select * into b from oyun_yonetim.kayit_basvurulari where user_id=p_user for update;
  if b.user_id is null or b.kad is null or b.il_id is null then raise exception 'Tamamlanmış kayıt başvurusu bulunamadı.'; end if;
  if b.durum='onaylandi' then raise exception 'Başvuru zaten onaylanmış.'; end if;
  if b.durum='reddedildi' then raise exception 'Bu başvuru zaten reddedildi; oyuncu yeni ad soyadla yeniden başvurursa tekrar karar verilir.'; end if;
  if p_onay then
    if exists(select 1 from oyun.profiller where lower(kad)=lower(b.kad) and id<>b.user_id) then raise exception 'Bu kullanıcı adı artık kullanımda.'; end if;
    update oyun_yonetim.kayit_basvurulari set durum='onaylandi', karar_at=t, karar_veren=p.id, ret_neden=null where user_id=b.user_id;
    insert into oyun.profiller(id,kad,il_id,il_at,olusturma,yonetici,ad_soyad)
      select b.user_id,b.kad,b.il_id,t,t,false,b.ad_soyad
      where not exists(select 1 from oyun.profiller where id=b.user_id);
    update oyun.profiller set ad_soyad=coalesce(ad_soyad,b.ad_soyad) where id=b.user_id;
  else
    n := coalesce(nullif(left(btrim(coalesce(p_neden,'')),300),''), 'Ad soyad ya da kullanıcı adı uygun bulunmadı (gerçek siyasetçi/kamuoyunca bilinen kişi adı kullanılamaz).');
    update oyun_yonetim.kayit_basvurulari set durum='reddedildi', karar_at=t, karar_veren=p.id, ret_neden=n, red_sayisi=red_sayisi+1 where user_id=b.user_id;
  end if;
  insert into oyun_yonetim.kayit_karar_log(user_id,kad,ad_soyad,ad_norm,karar,neden,veren,zaman)
  values(b.user_id,b.kad,b.ad_soyad,oyun_yonetim.isim_norm(b.ad_soyad),case when p_onay then 'onay' else 'ret' end,n,p.id,t);
  perform oyun.mod_log(p, case when p_onay then 'kayit_onay' else 'kayit_ret' end, b.kad, coalesce(b.ad_soyad,'')||coalesce(' · '||n,''));
  return jsonb_build_object('durum',case when p_onay then 'onaylandi' else 'reddedildi' end,'kad',b.kad);
end $$;

create or replace function public.admin_kayit_karar(p_user uuid, p_onay boolean)
returns jsonb language sql security definer set search_path to '' as $$
  select public.admin_kayit_karar2(p_user, p_onay, null)
$$;

do $g$
declare f text;
begin
  foreach f in array array['public.kayit_basvuru_gonder(text,integer,text)','public.kayit_durumum()','public.admin_kayit_basvurulari()',
                           'public.admin_kayit_karar2(uuid,boolean,text)','public.admin_kayit_karar(uuid,boolean)','public.kayit_basvur(text,integer)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $g$;
