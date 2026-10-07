-- =====================================================================
--  16 · MODERATÖR EKİBİ
--  Yönetici (profiller.yonetici = true; oyunun sahibi) her şeyi yapar. Yönetici istediği oyuncuyu moderatör
--  yapar ve hangi yetkilerin onda olacağını tek tek seçer. Moderatör yalnızca kendisine verilen işleri yapabilir;
--  yöneticiye ya da başka bir moderatöre işlem yapamaz, moderatör atayamaz. Her yetkili işlem moderasyon
--  günlüğüne yazılır; günlüğü yalnızca yönetici görür.
--  Moderatör atamak ve uygulama sürümünü zorunlu kılmak yalnızca yöneticinin işidir.
-- =====================================================================

create table if not exists oyun.moderatorler(
  user_id  uuid primary key references oyun.profiller(id) on delete cascade,
  yetkiler text[] not null default '{}',
  atayan   uuid,
  zaman    timestamptz not null
);

create table if not exists oyun.mod_kayit(
  id      bigserial primary key,
  zaman   timestamptz not null,
  user_id uuid,
  kad     text,
  islem   text not null,
  hedef   text,
  ayrinti text
);
create index if not exists mod_kayit_zaman on oyun.mod_kayit(zaman desc);

-- Verilebilecek yetkiler
create or replace function oyun.mod_yetki_tanim() returns table(kod text, ad text, aciklama text, sira int) language sql immutable as $$
  values ('ozet',        'Özet',                    'Oyuncu sayısı, aktiflik, açık şikâyet gibi özet rakamları görür.', 1),
         ('sikayet',     'Şikâyetler',              'Şikâyet edilen mesaj ve yayınları görür; "sorun yok" ya da "gizle" kararı verir.', 2),
         ('sustur',      'Susturma',                'Oyuncuyu 1 ya da 7 gün susturur, susturmayı kaldırır.', 3),
         ('hesap_kapat', 'Hesap kapatma',           'Kural ihlali yapan hesabı kapatır ya da yeniden açar.', 4),
         ('oyuncu_ara',  'Oyuncu inceleme',         'Oyuncunun bilgilerini ve son mesajlarını görür.', 5),
         ('eposta',      'E-posta görme',           'Oyuncu incelerken e-posta adresini de görür (kişisel veri; dikkatli ver).', 6),
         ('duyuru',      'Duyuru',                  'Tüm oyunculara oyun yönetimi adına duyuru gönderir.', 7),
         ('coklu_hesap', 'Çoklu hesap incelemesi',  'Aynı cihazdan açılan hesapları görür, gerçek kişi olanları onaylar.', 8),
         ('kurallar',    'Kurallar ve ayarlar',     'Vatandaşlık, parti kurma, teşkilat, havale ve banka kurallarını değiştirir.', 9)
$$;

create or replace function oyun.yetkili(u uuid, p_yetki text) returns boolean language sql stable as $$
  select coalesce((select yonetici from oyun.profiller where id = u), false)
      or exists (select 1 from oyun.moderatorler m join oyun.profiller p on p.id = m.user_id where m.user_id = u and not p.yasakli and p_yetki = any(m.yetkiler))
$$;

-- Admin fonksiyonlarının kapısı: yönetici her şeyi, moderatör yalnızca kendi yetkisini yapar
create or replace function oyun.yetki_zorunlu(p_yetki text) returns oyun.profiller language plpgsql as $$
declare p oyun.profiller := oyun.profilim();
begin
  if p.yonetici then return p; end if;
  if exists (select 1 from oyun.moderatorler where user_id = p.id and p_yetki = any(yetkiler)) then return p; end if;
  if exists (select 1 from oyun.moderatorler where user_id = p.id) then
    raise exception 'Bu işlem için yetkin yok. Moderatör yetkilerini oyunun yöneticisi belirler.';
  end if;
  raise exception 'Bu ekran yalnızca oyun yöneticileri ve moderatörler içindir.';
end $$;

-- Moderatör, yöneticiye ya da başka bir moderatöre işlem yapamaz
create or replace function oyun.korunan_hedef(p oyun.profiller, h uuid) returns void language plpgsql as $$
begin
  if p.yonetici then return; end if;
  if exists (select 1 from oyun.profiller where id = h and yonetici) or exists (select 1 from oyun.moderatorler where user_id = h) then
    raise exception 'Yöneticiye ya da başka bir moderatöre işlem yapamazsın.';
  end if;
end $$;

create or replace function oyun.mod_log(p oyun.profiller, p_islem text, p_hedef text, p_ayrinti text) returns void language sql as $$
  insert into oyun.mod_kayit(zaman, user_id, kad, islem, hedef, ayrinti) values (oyun.simdi(), p.id, p.kad, p_islem, p_hedef, left(p_ayrinti, 300))
$$;

-- Uygulamanın paneli göstermesi için: bu oyuncunun yetkileri
create or replace function oyun.yetkilerim(u uuid) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'yonetici', coalesce(p.yonetici, false),
    'moderator', m.user_id is not null,
    'liste', case when p.yonetici then (select jsonb_agg(kod order by sira) from oyun.mod_yetki_tanim())
                  else coalesce(to_jsonb(m.yetkiler), '[]'::jsonb) end)
  from oyun.profiller p left join oyun.moderatorler m on m.user_id = p.id where p.id = u
$$;

-- ---------- Yalnızca yönetici ----------
create or replace function public.admin_moderatorler() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu();
begin
  return jsonb_build_object(
    'tanim', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad, 'aciklama', aciklama) order by sira) from oyun.mod_yetki_tanim()),
    'liste', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'yetkiler', to_jsonb(m.yetkiler), 'zaman', m.zaman, 'atayan', oyun.kad(m.atayan),
                         'son_gorulme', pr.son_gorulme, 'yasakli', pr.yasakli,
                         'islem_7gun', (select count(*) from oyun.mod_kayit k where k.user_id = m.user_id and k.zaman > oyun.simdi() - interval '7 days'))
                         order by m.zaman)
                       from oyun.moderatorler m join oyun.profiller pr on pr.id = m.user_id), '[]'::jsonb));
end $$;

-- Moderatör ata / yetkilerini değiştir. Boş liste = moderatörlükten çıkar.
create or replace function public.admin_moderator_ayarla(p_kad text, p_yetkiler text[]) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi(); h oyun.profiller := oyun.profil_bul(p_kad);
        y text[]; gecersiz text; adlar text; vardi boolean;
begin
  if h.id = p.id then raise exception 'Kendi yetkilerini değiştiremezsin; sen zaten yöneticisin.'; end if;
  if h.yonetici then raise exception '% zaten yönetici; moderatör yapılamaz.', h.kad; end if;
  if h.yasakli then raise exception 'Hesabı kapatılmış oyuncu moderatör yapılamaz.'; end if;
  select array_agg(distinct x order by x) into y from unnest(coalesce(p_yetkiler, '{}')) x where nullif(btrim(x), '') is not null;
  select string_agg(x, ', ') into gecersiz from unnest(coalesce(y, '{}')) x where x not in (select kod from oyun.mod_yetki_tanim());
  if gecersiz is not null then raise exception 'Geçersiz yetki: %', gecersiz; end if;
  vardi := exists (select 1 from oyun.moderatorler where user_id = h.id);
  if y is null or cardinality(y) = 0 then
    delete from oyun.moderatorler where user_id = h.id;
    if vardi then
      perform oyun.bildir(h.id, 'Oyun yönetimindeki moderatörlük görevin sona erdi. Katkın için teşekkürler.', t);
      perform oyun.mod_log(p, 'moderator_cikar', h.kad, null);
    end if;
    return public.admin_moderatorler();
  end if;
  insert into oyun.moderatorler(user_id, yetkiler, atayan, zaman) values (h.id, y, p.id, t)
  on conflict (user_id) do update set yetkiler = excluded.yetkiler, atayan = excluded.atayan;
  select string_agg(ad, ', ' order by sira) into adlar from oyun.mod_yetki_tanim() where kod = any(y);
  perform oyun.bildir(h.id, case when vardi then 'Moderatör yetkilerin güncellendi: ' || adlar || '.'
                                 else 'Oyun yöneticisi seni moderatör yaptı. Yetkilerin: ' || adlar || '. Paneline Profilim › Moderatör paneli''nden ulaşırsın.' end, t);
  perform oyun.mod_log(p, case when vardi then 'moderator_yetki' else 'moderator_ata' end, h.kad, adlar);
  return public.admin_moderatorler();
end $$;

create or replace function public.admin_mod_kayit(p_limit int default 60) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.yonetici_zorunlu();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('zaman', k.zaman, 'kad', k.kad, 'islem', k.islem, 'hedef', k.hedef, 'ayrinti', k.ayrinti) order by k.zaman desc, k.id desc)
                   from (select * from oyun.mod_kayit order by zaman desc, id desc limit least(greatest(coalesce(p_limit, 60), 1), 200)) k), '[]'::jsonb);
end $$;
