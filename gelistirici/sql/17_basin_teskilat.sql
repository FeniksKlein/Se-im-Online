-- Canlı kaynak: supabase_migrations 20261007153118 / basin_ve_teskilat_gorevlisi_20261007
-- 2026.10.07-3. Dış güncelleme işlemini sql_birlestir yönetir; burada tekrar başlatılmaz.
alter table oyun.ayarlar add column if not exists gazete_kur_ucret numeric not null default 10000;
alter table oyun.ayarlar add column if not exists gazete_abone_gun int not null default 30;
alter table oyun.ayarlar add column if not exists gazete_max_abonelik numeric not null default 10000;
alter table oyun.ayarlar add column if not exists gazete_gunluk_yayin int not null default 10;

create table if not exists oyun.parti_teskilat_gorev(
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  il_id smallint not null references oyun.iller(id),
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  atayan uuid not null references oyun.profiller(id),
  atama timestamptz not null default now(),
  aktif boolean not null default true,
  primary key(parti_id, il_id)
);
create index if not exists parti_teskilat_gorev_user
  on oyun.parti_teskilat_gorev(user_id) where aktif;

create table if not exists oyun.oyuncu_gazeteleri(
  id bigserial primary key,
  ad text not null,
  slogan text not null default '',
  sahip uuid not null references oyun.profiller(id) on delete cascade,
  abonelik_ucret numeric not null default 0 check (abonelik_ucret >= 0),
  kasa numeric not null default 0 check (kasa >= 0),
  kurulus timestamptz not null default now(),
  aktif boolean not null default true
);
create unique index if not exists oyuncu_gazete_ad_aktif
  on oyun.oyuncu_gazeteleri(lower(ad)) where aktif;
create unique index if not exists oyuncu_gazete_sahip_aktif
  on oyun.oyuncu_gazeteleri(sahip) where aktif;

create table if not exists oyun.gazete_abonelik(
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  baslangic timestamptz not null,
  bitis timestamptz not null,
  toplam_odeme numeric not null default 0,
  primary key(gazete_id, user_id)
);
create index if not exists gazete_abonelik_user
  on oyun.gazete_abonelik(user_id, bitis desc);

create table if not exists oyun.gazete_yazar_teklif(
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  teklif_eden uuid not null references oyun.profiller(id),
  ucret_yazi numeric not null default 0 check (ucret_yazi >= 0),
  durum text not null default 'bekliyor'
    check (durum in ('bekliyor','kabul','ret','iptal')),
  zaman timestamptz not null,
  yanit timestamptz,
  primary key(gazete_id, user_id)
);

create table if not exists oyun.gazete_yazarlar(
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  ucret_yazi numeric not null default 0 check (ucret_yazi >= 0),
  baslangic timestamptz not null,
  aktif boolean not null default true,
  primary key(gazete_id, user_id)
);
create index if not exists gazete_yazar_user
  on oyun.gazete_yazarlar(user_id) where aktif;

create table if not exists oyun.gazete_yayinlari(
  id bigserial primary key,
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  yazar uuid not null references oyun.profiller(id),
  tur text not null check (tur in ('haber','kose','propaganda')),
  baslik text not null,
  metin text not null,
  hedef_parti bigint references oyun.partiler(id),
  zaman timestamptz not null
);
create index if not exists gazete_yayin_son
  on oyun.gazete_yayinlari(gazete_id, zaman desc, id desc);

create table if not exists oyun.gazete_hareket(
  id bigserial primary key,
  gazete_id bigint not null references oyun.oyuncu_gazeteleri(id) on delete cascade,
  zaman timestamptz not null,
  tutar numeric not null,
  tur text not null,
  aciklama text not null
);
create index if not exists gazete_hareket_son
  on oyun.gazete_hareket(gazete_id, zaman desc, id desc);

create or replace function oyun.gazete_kur_ucreti()
returns numeric
language sql stable
set search_path = ''
as $$
  select round(a.gazete_kur_ucret * u.endeks)
  from oyun.ayarlar a, oyun.ulke u
  where a.id = 1 and u.id = 1
$$;

create or replace function oyun.gazete_erisim(
  p_gazete bigint, p_user uuid, p_zaman timestamptz
)
returns boolean
language sql stable
set search_path = ''
as $$
  select exists(
           select 1 from oyun.oyuncu_gazeteleri g
           where g.id = p_gazete and g.aktif and g.sahip = p_user
         )
      or exists(
           select 1 from oyun.gazete_yazarlar y
           where y.gazete_id = p_gazete and y.user_id = p_user and y.aktif
         )
      or exists(
           select 1 from oyun.oyuncu_gazeteleri g
           where g.id = p_gazete and g.aktif and g.abonelik_ucret = 0
         )
      or exists(
           select 1 from oyun.gazete_abonelik a
           where a.gazete_id = p_gazete and a.user_id = p_user and a.bitis > p_zaman
         )
$$;

create or replace function oyun.teskilat_json(p_parti bigint, p oyun.profiller)
returns jsonb
language sql stable
set search_path = ''
as $$
  select jsonb_build_object(
    'sayi', (select count(*) from oyun.parti_teskilat where parti_id = p_parti),
    'iller', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', t.il_id,
        'ad', i.ad,
        'kurulus', t.kurulus,
        'genel_merkez', t.genel_merkez,
        'uye', (select count(*) from oyun.profiller pr
                where pr.parti_id = p_parti and pr.il_id = t.il_id),
        'gorevli', (select oyun.kad(g.user_id)
                    from oyun.parti_teskilat_gorev g
                    where g.parti_id = p_parti
                      and g.il_id = t.il_id
                      and g.aktif)
      ) order by t.genel_merkez desc, i.ad)
      from oyun.parti_teskilat t
      join oyun.iller i on i.id = t.il_id
      where t.parti_id = p_parti
    ), '[]'::jsonb),
    'gorevler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', g.il_id,
        'ad', i.ad,
        'kad', oyun.kad(g.user_id),
        'atama', g.atama,
        'teskilat_acik', oyun.teskilat_var(p_parti, g.il_id)
      ) order by i.ad)
      from oyun.parti_teskilat_gorev g
      join oyun.iller i on i.id = g.il_id
      where g.parti_id = p_parti and g.aktif
    ), '[]'::jsonb),
    'benim_gorevler', coalesce((
      select jsonb_agg(jsonb_build_object(
        'il_id', g.il_id,
        'ad', i.ad,
        'teskilat_acik', oyun.teskilat_var(p_parti, g.il_id),
        'ucret', oyun.teskilat_ucreti(g.il_id)
      ) order by i.ad)
      from oyun.parti_teskilat_gorev g
      join oyun.iller i on i.id = g.il_id
      where g.parti_id = p_parti and g.user_id = p.id and g.aktif
    ), '[]'::jsonb),
    'yetkili', p.parti_id = p_parti and (
      exists(select 1 from oyun.partiler where id = p_parti and gb = p.id)
      or exists(select 1 from oyun.parti_gby
                where parti_id = p_parti and user_id = p.id)
    ),
    'gorev_verebilir', p.parti_id = p_parti
      and exists(select 1 from oyun.partiler where id = p_parti and gb = p.id),
    'zorunlu', (select teskilat_zorunlu from oyun.ayarlar where id = 1),
    'ucretler', jsonb_build_object(
      '1', round(a.teskilat_ucret * u.endeks),
      '2', round(a.teskilat_ucret * 2 * u.endeks),
      '3', round(a.teskilat_ucret * 3 * u.endeks)
    ),
    'kasa', (select round(kasa) from oyun.partiler where id = p_parti),
    'cuzdan', coalesce((select round(para) from oyun.cuzdan where user_id = p.id), 0),
    'benim_ilim_var', p.parti_id = p_parti
      and oyun.teskilat_var(p_parti, p.il_id)
  )
  from oyun.ayarlar a, oyun.ulke u
  where a.id = 1 and u.id = 1
$$;

create or replace function public.teskilat_gorev_ver(p_il int, p_kad text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  h oyun.profiller;
  pa oyun.partiler;
  t timestamptz := oyun.simdi();
  ilad text;
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali;

  if pa.id is null or pa.gb is distinct from p.id then
    raise exception 'İl teşkilat görevlisini yalnızca genel başkan atayabilir.';
  end if;

  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pa.id then
    raise exception 'Yalnızca kendi partinin üyesini görevlendirebilirsin.';
  end if;
  if h.il_id is distinct from p_il::smallint then
    raise exception 'Görevli, teşkilat kurulacak ilde kayıtlı olmalı.';
  end if;

  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;

  insert into oyun.parti_teskilat_gorev(
    parti_id, il_id, user_id, atayan, atama, aktif
  ) values (pa.id, p_il, h.id, p.id, t, true)
  on conflict(parti_id, il_id) do update
    set user_id = excluded.user_id,
        atayan = excluded.atayan,
        atama = excluded.atama,
        aktif = true;

  perform oyun.bildir(
    h.id,
    format(
      '%s Genel Başkanı %s seni %s il teşkilat sorumlusu yaptı. Teşkilat henüz açılmadıysa kuruluş bedelini kendi cüzdanından ödeyebilirsin.',
      pa.kisa, p.kad, ilad
    ),
    t
  );

  return oyun.teskilat_json(pa.id, p);
end $$;

create or replace function public.teskilat_gorev_al(p_il int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  pa oyun.partiler;
  h uuid;
  t timestamptz := oyun.simdi();
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali;

  if pa.id is null or pa.gb is distinct from p.id then
    raise exception 'Bu görevi yalnızca genel başkan kaldırabilir.';
  end if;

  select user_id into h
  from oyun.parti_teskilat_gorev
  where parti_id = pa.id and il_id = p_il and aktif
  for update;

  update oyun.parti_teskilat_gorev
  set aktif = false
  where parti_id = pa.id and il_id = p_il and aktif;

  if h is not null then
    perform oyun.bildir(h, 'İl teşkilat sorumluluğu görevin sona erdirildi.', t);
  end if;

  return oyun.teskilat_json(pa.id, p);
end $$;

create or replace function public.teskilat_ac2(
  p_il int,
  p_kaynak text default 'parti'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  pa oyun.partiler;
  t timestamptz := oyun.simdi();
  ucret numeric;
  ilad text;
  yonetim boolean;
  gorevli boolean;
begin
  select * into pa
  from oyun.partiler
  where id = p.parti_id and not kapali
  for update;

  if pa.id is null then raise exception 'Bir partiye üye değilsin.'; end if;

  yonetim := pa.gb = p.id or exists(
    select 1 from oyun.parti_gby
    where parti_id = pa.id and user_id = p.id
  );
  gorevli := exists(
    select 1 from oyun.parti_teskilat_gorev
    where parti_id = pa.id
      and il_id = p_il
      and user_id = p.id
      and aktif
  );

  if not yonetim and not gorevli then
    raise exception 'Bu ilde teşkilat açma yetkin yok.';
  end if;

  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;

  if gorevli and p.il_id is distinct from p_il::smallint then
    raise exception 'Teşkilat sorumlusu yalnızca kayıtlı olduğu il için ödeme yapabilir.';
  end if;

  if oyun.teskilat_var(pa.id, p_il::smallint) then
    raise exception 'Partinin % ilinde zaten teşkilatı var.', ilad;
  end if;

  ucret := oyun.teskilat_ucreti(p_il::smallint);

  if p_kaynak = 'parti' then
    if not yonetim then
      raise exception 'Parti kasasından ödemeyi yalnızca genel başkan veya yardımcısı yapabilir.';
    end if;
    if pa.kasa < ucret then
      raise exception 'Parti kasasında yeterli para yok (% ₺ gerekli).', oyun.tl(ucret);
    end if;

    update oyun.partiler set kasa = kasa - ucret where id = pa.id;
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
    values (
      pa.id, t, -ucret,
      format('%s il teşkilatı açıldı · parti kasası · %s', ilad, p.kad),
      'teskilat'
    );

  elsif p_kaynak = 'kendi' then
    perform oyun.para_islem(
      p.id, -ucret, 'teskilat',
      format('%s %s il teşkilatı kuruluş bedeli', pa.kisa, ilad),
      t
    );
    insert into oyun.parti_hareket(parti_id, zaman, tutar, aciklama, tur)
    values (
      pa.id, t, 0,
      format('%s il teşkilatı açıldı · %s kendi cüzdanından ödedi', ilad, p.kad),
      'teskilat_uye'
    );
  else
    raise exception 'Ödeme kaynağı parti veya kendi olmalı.';
  end if;

  insert into oyun.parti_teskilat(
    parti_id, il_id, kurulus, kuran, bedel
  ) values (pa.id, p_il, t, p.id, ucret);

  perform oyun.olay(
    'parti',
    format('%s, %s il teşkilatını açtı.', pa.kisa, ilad),
    p_il::smallint,
    pa.id,
    t
  );

  insert into oyun.bildirimler(user_id, zaman, metin)
  select
    id,
    t,
    format(
      '%s artık %s ilinde teşkilatlı: partin bu ilde milletvekili ve belediye başkanı adayı gösterebilir.',
      pa.kisa,
      ilad
    )
  from oyun.profiller
  where parti_id = pa.id
    and il_id = p_il
    and id <> p.id;

  return oyun.teskilat_json(pa.id, p);
end $$;

create or replace function public.teskilat_ac(p_il int)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select public.teskilat_ac2(p_il, 'parti')
$$;

create or replace function oyun._ayril(u uuid, t timestamptz)
returns void
language plpgsql
set search_path = oyun, public, pg_temp
as $$
declare
  pid bigint := (select parti_id from oyun.profiller where id = u);
begin
  if pid is null then return; end if;

  delete from oyun.adaylar a
  using oyun.secimler s
  where a.secim_id = s.id
    and a.user_id = u
    and (
      s.durum = 'bekliyor'
      or (
        s.tur = 'mv_on'
        and exists(
          select 1 from oyun.secimler m
          where m.tur = 'mv'
            and m.donem = s.donem
            and m.durum = 'bekliyor'
        )
      )
    );

  delete from oyun.cb_kararlar k
  where k.parti_id = pid
    and k.aday = u
    and exists(
      select 1 from oyun.secimler s
      where s.tur = 'cb'
        and s.donem = k.donem
        and s.durum = 'bekliyor'
    );

  update oyun.parti_teskilat_gorev
  set aktif = false
  where parti_id = pid
    and user_id = u
    and aktif;

  update oyun.partiler set gb = null where id = pid and gb = u;
  delete from oyun.parti_gby where user_id = u;
  update oyun.profiller set parti_id = null, parti_at = null where id = u;

  update oyun.partiler
  set kapali = true
  where id = pid
    and not sistem
    and not exists(
      select 1 from oyun.profiller where parti_id = pid
    );

  perform oyun.ittifak_temizle();
end $$;

create or replace function public.il_degistir(p_il integer)
returns jsonb
language plpgsql
security definer
set search_path = oyun, public, pg_temp
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  gun int := oyun.il_bekleme_gun(t);
  kn text;
  ucret numeric;
begin
  if not exists(select 1 from oyun.iller where id = p_il) then
    raise exception 'Geçersiz il.';
  end if;
  if p.il_id = p_il then
    raise exception 'Zaten bu ildesin.';
  end if;

  kn := oyun.il_kilit_nedeni(t);
  if kn is not null then raise exception '%', kn; end if;

  if p.son_il_degis is not null
     and p.son_il_degis + make_interval(days => gun) > t then
    raise exception 'İl en fazla % günde bir değiştirilebilir. Bir sonraki: %',
      gun,
      to_char(
        (p.son_il_degis + make_interval(days => gun)) at time zone 'Europe/Istanbul',
        'DD.MM.YYYY HH24:MI'
      );
  end if;

  if exists(
    select 1 from oyun.makamlar
    where user_id = p.id
      and bit is null
      and tur in ('mv','bel')
  ) then
    raise exception 'Görevdeki vekil veya belediye başkanı il değiştiremez.';
  end if;

  ucret := oyun.tasinma_ucreti(p.il_id, p_il::smallint, t);
  if ucret > 0 then
    perform oyun.para_islem(
      p.id,
      -ucret,
      'tasinma',
      format(
        'Taşınma: %s → %s',
        (select ad from oyun.iller where id = p.il_id),
        (select ad from oyun.iller where id = p_il)
      ),
      t
    );
  end if;

  update oyun.parti_teskilat_gorev
  set aktif = false
  where user_id = p.id
    and aktif
    and il_id <> p_il::smallint;

  update oyun.profiller
  set il_id = p_il,
      il_at = t,
      son_il_degis = t
  where id = p.id;

  return public.durum();
end $$;

create or replace function public.basin()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
begin
  return jsonb_build_object(
    'kurulus_ucreti', oyun.gazete_kur_ucreti(),
    'benim', (
      select jsonb_build_object(
        'id', g.id,
        'ad', g.ad,
        'slogan', g.slogan,
        'abonelik_ucret', round(g.abonelik_ucret),
        'kasa', round(g.kasa),
        'abone', (
          select count(*) from oyun.gazete_abonelik a
          where a.gazete_id = g.id and a.bitis > t
        ),
        'yazar', (
          select count(*) from oyun.gazete_yazarlar y
          where y.gazete_id = g.id and y.aktif
        )
      )
      from oyun.oyuncu_gazeteleri g
      where g.sahip = p.id and g.aktif
      limit 1
    ),
    'teklifler', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'gazete_id', g.id,
          'ad', g.ad,
          'sahip', oyun.kad(g.sahip),
          'ucret', round(x.ucret_yazi),
          'zaman', x.zaman
        )
        order by x.zaman desc
      )
      from oyun.gazete_yazar_teklif x
      join oyun.oyuncu_gazeteleri g on g.id = x.gazete_id
      where x.user_id = p.id
        and x.durum = 'bekliyor'
        and g.aktif
    ), '[]'::jsonb),
    'gazeteler', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', g.id,
          'ad', g.ad,
          'slogan', g.slogan,
          'sahip', oyun.kad(g.sahip),
          'abonelik_ucret', round(g.abonelik_ucret),
          'abone', (
            select count(*) from oyun.gazete_abonelik a
            where a.gazete_id = g.id and a.bitis > t
          ),
          'abonem', exists(
            select 1 from oyun.gazete_abonelik a
            where a.gazete_id = g.id
              and a.user_id = p.id
              and a.bitis > t
          ),
          'yaziyim', exists(
            select 1 from oyun.gazete_yazarlar y
            where y.gazete_id = g.id
              and y.user_id = p.id
              and y.aktif
          ),
          'son', (
            select jsonb_build_object(
              'baslik', y.baslik,
              'tur', y.tur,
              'zaman', y.zaman
            )
            from oyun.gazete_yayinlari y
            where y.gazete_id = g.id
            order by y.zaman desc, y.id desc
            limit 1
          )
        )
        order by (
          select count(*) from oyun.gazete_abonelik a
          where a.gazete_id = g.id and a.bitis > t
        ) desc,
        g.kurulus
      )
      from oyun.oyuncu_gazeteleri g
      where g.aktif
    ), '[]'::jsonb)
  );
end $$;

create or replace function public.gazete_detay(p_gazete bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  g oyun.oyuncu_gazeteleri;
  er boolean;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;

  er := oyun.gazete_erisim(g.id, p.id, t);

  return jsonb_build_object(
    'id', g.id,
    'ad', g.ad,
    'slogan', g.slogan,
    'sahip', oyun.kad(g.sahip),
    'sahibim', g.sahip = p.id,
    'abonelik_ucret', round(g.abonelik_ucret),
    'kasa', case when g.sahip = p.id then round(g.kasa) end,
    'erisim', er,
    'abonelik_bitis', (
      select a.bitis
      from oyun.gazete_abonelik a
      where a.gazete_id = g.id
        and a.user_id = p.id
        and a.bitis > t
    ),
    'abone', (
      select count(*)
      from oyun.gazete_abonelik a
      where a.gazete_id = g.id and a.bitis > t
    ),
    'yazarlar', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'kad', oyun.kad(y.user_id),
          'ucret', round(y.ucret_yazi),
          'benim', y.user_id = p.id
        )
        order by oyun.kad(y.user_id)
      )
      from oyun.gazete_yazarlar y
      where y.gazete_id = g.id and y.aktif
    ), '[]'::jsonb),
    'hareketler', case when g.sahip = p.id then coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'zaman', h.zaman,
          'tutar', round(h.tutar),
          'tur', h.tur,
          'aciklama', h.aciklama
        )
        order by h.zaman desc, h.id desc
      )
      from (
        select *
        from oyun.gazete_hareket
        where gazete_id = g.id
        order by zaman desc, id desc
        limit 20
      ) h
    ), '[]'::jsonb) else '[]'::jsonb end,
    'yayinlar', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', y.id,
          'tur', y.tur,
          'baslik', y.baslik,
          'metin', case
            when er then y.metin
            else left(y.metin, 220)
                 || case when length(y.metin) > 220 then '…' else '' end
          end,
          'kilitli', not er and g.abonelik_ucret > 0,
          'yazar', oyun.kad(y.yazar),
          'zaman', y.zaman,
          'hedef_parti', case
            when y.hedef_parti is null then null
            else oyun.parti_json(y.hedef_parti)
          end
        )
        order by y.zaman desc, y.id desc
      )
      from (
        select *
        from oyun.gazete_yayinlari
        where gazete_id = g.id
        order by zaman desc, id desc
        limit 80
      ) y
    ), '[]'::jsonb)
  );
end $$;

create or replace function public.gazete_kur(
  p_ad text,
  p_slogan text,
  p_abonelik numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  ucret numeric := oyun.gazete_kur_ucreti();
  gid bigint;
  azami numeric := (
    select gazete_max_abonelik from oyun.ayarlar where id = 1
  );
  ab numeric := round(coalesce(p_abonelik, 0));
begin
  p_ad := btrim(regexp_replace(coalesce(p_ad, ''), '\s+', ' ', 'g'));
  p_slogan := btrim(coalesce(p_slogan, ''));

  if char_length(p_ad) < 4 or char_length(p_ad) > 40 then
    raise exception 'Gazete adı 4-40 karakter olmalı.';
  end if;
  if char_length(p_slogan) > 100 then
    raise exception 'Slogan en fazla 100 karakter olabilir.';
  end if;
  if ab < 0 or ab > azami then
    raise exception 'Aylık abonelik 0-% ₺ arasında olmalı.', oyun.tl(azami);
  end if;

  if exists(
    select 1 from oyun.oyuncu_gazeteleri
    where sahip = p.id and aktif
  ) then
    raise exception 'Zaten aktif bir gazeten var.';
  end if;

  if exists(
    select 1 from oyun.oyuncu_gazeteleri
    where aktif and lower(ad) = lower(p_ad)
  ) then
    raise exception 'Bu gazete adı kullanılıyor.';
  end if;

  perform oyun.para_islem(
    p.id,
    -ucret,
    'gazete_kur',
    format('%s gazetesini kurdu', p_ad),
    t
  );

  insert into oyun.oyuncu_gazeteleri(
    ad, slogan, sahip, abonelik_ucret, kurulus
  ) values (
    p_ad, p_slogan, p.id, ab, t
  )
  returning id into gid;

  insert into oyun.gazete_hareket(
    gazete_id, zaman, tutar, tur, aciklama
  ) values (
    gid, t, 0, 'kurulus', format('%s tarafından kuruldu', p.kad)
  );

  return public.gazete_detay(gid);
end $$;

create or replace function public.gazete_abone_ol(p_gazete bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  g oyun.oyuncu_gazeteleri;
  gun int;
  eski timestamptz;
  yeni timestamptz;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif
  for update;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;
  if g.sahip = p.id then
    raise exception 'Kendi gazetene abone olmana gerek yok.';
  end if;
  if g.abonelik_ucret <= 0 then
    raise exception 'Bu gazete ücretsiz.';
  end if;

  gun := (select gazete_abone_gun from oyun.ayarlar where id = 1);

  select bitis into eski
  from oyun.gazete_abonelik
  where gazete_id = g.id and user_id = p.id
  for update;

  yeni := greatest(coalesce(eski, t), t) + make_interval(days => gun);

  perform oyun.para_islem(
    p.id,
    -g.abonelik_ucret,
    'gazete_abone',
    format('%s · %s günlük abonelik', g.ad, gun),
    t
  );

  update oyun.oyuncu_gazeteleri
  set kasa = kasa + g.abonelik_ucret
  where id = g.id;

  insert into oyun.gazete_abonelik(
    gazete_id, user_id, baslangic, bitis, toplam_odeme
  ) values (
    g.id, p.id, t, yeni, g.abonelik_ucret
  )
  on conflict(gazete_id, user_id) do update
  set bitis = excluded.bitis,
      toplam_odeme = oyun.gazete_abonelik.toplam_odeme + excluded.toplam_odeme;

  insert into oyun.gazete_hareket(
    gazete_id, zaman, tutar, tur, aciklama
  ) values (
    g.id, t, g.abonelik_ucret, 'abonelik',
    format('%s abonelik ödedi', p.kad)
  );

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_yazar_teklif(
  p_gazete bigint,
  p_kad text,
  p_ucret numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  h oyun.profiller;
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
  u numeric := round(coalesce(p_ucret, 0));
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.sahip is distinct from p.id then
    raise exception 'Yazar teklifini yalnızca gazete sahibi verebilir.';
  end if;

  h := oyun.profil_bul(p_kad);
  if h.id = p.id then
    raise exception 'Kendine yazar teklifi veremezsin.';
  end if;
  if u < 0 or u > 10000 then
    raise exception 'Yazı başı ücret 0-10.000 ₺ olmalı.';
  end if;

  insert into oyun.gazete_yazar_teklif(
    gazete_id, user_id, teklif_eden, ucret_yazi, durum, zaman, yanit
  ) values (
    g.id, h.id, p.id, u, 'bekliyor', t, null
  )
  on conflict(gazete_id, user_id) do update
  set teklif_eden = excluded.teklif_eden,
      ucret_yazi = excluded.ucret_yazi,
      durum = 'bekliyor',
      zaman = excluded.zaman,
      yanit = null;

  perform oyun.bildir(
    h.id,
    format(
      '%s gazetesi sana yazı başına %s ₺ ile köşe yazarlığı teklif etti.',
      g.ad,
      oyun.tl(u)
    ),
    t
  );

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_yazar_yanit(
  p_gazete bigint,
  p_kabul boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  x oyun.gazete_yazar_teklif;
  t timestamptz := oyun.simdi();
  s uuid;
begin
  select * into x
  from oyun.gazete_yazar_teklif
  where gazete_id = p_gazete
    and user_id = p.id
    and durum = 'bekliyor'
  for update;

  if x.gazete_id is null then
    raise exception 'Bekleyen yazar teklifin yok.';
  end if;

  update oyun.gazete_yazar_teklif
  set durum = case when p_kabul then 'kabul' else 'ret' end,
      yanit = t
  where gazete_id = p_gazete
    and user_id = p.id;

  if p_kabul then
    insert into oyun.gazete_yazarlar(
      gazete_id, user_id, ucret_yazi, baslangic, aktif
    ) values (
      p_gazete, p.id, x.ucret_yazi, t, true
    )
    on conflict(gazete_id, user_id) do update
    set ucret_yazi = excluded.ucret_yazi,
        baslangic = excluded.baslangic,
        aktif = true;
  end if;

  select sahip into s
  from oyun.oyuncu_gazeteleri
  where id = p_gazete;

  if s is not null then
    perform oyun.bildir(
      s,
      format(
        '%s köşe yazarlığı teklifini %s.',
        p.kad,
        case when p_kabul then 'kabul etti' else 'reddetti' end
      ),
      t
    );
  end if;

  return public.basin();
end $$;

create or replace function public.gazete_yazar_cikar(
  p_gazete bigint,
  p_kad text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  h oyun.profiller;
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.sahip is distinct from p.id then
    raise exception 'Bu işlemi yalnızca gazete sahibi yapabilir.';
  end if;

  h := oyun.profil_bul(p_kad);

  update oyun.gazete_yazarlar
  set aktif = false
  where gazete_id = g.id
    and user_id = h.id
    and aktif;

  if found then
    perform oyun.bildir(
      h.id,
      format('%s gazetesindeki köşe yazarlığın sona erdi.', g.ad),
      t
    );
  end if;

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_yayinla(
  p_gazete bigint,
  p_tur text,
  p_baslik text,
  p_metin text,
  p_hedef_parti bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
  u numeric := 0;
  gunluk int := (
    select gazete_gunluk_yayin from oyun.ayarlar where id = 1
  );
  hedef_kisa text;
  ozet text;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif
  for update;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;

  if g.sahip is distinct from p.id then
    select ucret_yazi into u
    from oyun.gazete_yazarlar
    where gazete_id = g.id
      and user_id = p.id
      and aktif;

    if u is null then
      raise exception 'Bu gazetede yazı yayımlama yetkin yok.';
    end if;
  end if;

  if (
    select count(*)
    from oyun.gazete_yayinlari
    where gazete_id = g.id
      and zaman >= oyun.bugun_bas(t)
  ) >= gunluk then
    raise exception 'Gazetenin bugünkü yayın sınırı doldu (% yazı).', gunluk;
  end if;

  if p_tur not in ('haber','kose','propaganda') then
    raise exception 'Yayın türü geçersiz.';
  end if;

  p_baslik := btrim(coalesce(p_baslik, ''));
  p_metin := btrim(coalesce(p_metin, ''));

  if char_length(p_baslik) < 4 or char_length(p_baslik) > 100 then
    raise exception 'Başlık 4-100 karakter olmalı.';
  end if;
  if char_length(p_metin) < 20 or char_length(p_metin) > 5000 then
    raise exception 'Yazı 20-5000 karakter olmalı.';
  end if;

  if p_tur = 'propaganda' then
    select kisa into hedef_kisa
    from oyun.partiler
    where id = p_hedef_parti and not kapali;

    if hedef_kisa is null then
      raise exception 'Propaganda yazısında hedef parti seçmelisin.';
    end if;
  else
    p_hedef_parti := null;
  end if;

  if u > 0 then
    if g.kasa < u then
      raise exception 'Gazete kasasında yazar ücretini ödeyecek kadar para yok (% ₺ gerekli).',
                      oyun.tl(u);
    end if;

    update oyun.oyuncu_gazeteleri
    set kasa = kasa - u
    where id = g.id;

    insert into oyun.gazete_hareket(
      gazete_id, zaman, tutar, tur, aciklama
    ) values (
      g.id, t, -u, 'yazar_ucreti', format('%s yazı ücreti', p.kad)
    );

    perform oyun.para_islem(
      p.id, u, 'gazete_yazar', format('%s yazı ücreti', g.ad), t
    );
  end if;

  insert into oyun.gazete_yayinlari(
    gazete_id, yazar, tur, baslik, metin, hedef_parti, zaman
  ) values (
    g.id, p.id, p_tur, p_baslik, p_metin, p_hedef_parti, t
  );

  insert into oyun.bildirimler(user_id, zaman, metin)
  select
    a.user_id,
    t,
    format('%s: “%s” yayımlandı.', g.ad, p_baslik)
  from oyun.gazete_abonelik a
  where a.gazete_id = g.id
    and a.bitis > t
    and a.user_id <> p.id;

  if p_tur = 'propaganda' then
    ozet := oyun.metin_temizle(
      format(
        E'📰 %s · PROPAGANDA · %s\n%s\n%s',
        g.ad,
        hedef_kisa,
        p_baslik,
        p_metin
      ),
      600
    );

    insert into oyun.yayinlar(
      tur, gonderen, metin, zaman, hedef_il,
      hedef_parti, secim_id, unvan, gizli
    ) values (
      'sistem',
      p.id,
      ozet,
      t,
      null,
      null,
      null,
      'Oyuncu gazetesi · propaganda',
      false
    );
  end if;

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_para_cek(
  p_gazete bigint,
  p_miktar numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
  m numeric := round(coalesce(p_miktar, 0));
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif
  for update;

  if g.sahip is distinct from p.id then
    raise exception 'Gazete kasasını yalnızca sahibi kullanabilir.';
  end if;
  if m < 100 then raise exception 'En az 100 ₺ çekebilirsin.'; end if;
  if g.kasa < m then raise exception 'Gazete kasasında yeterli para yok.'; end if;

  update oyun.oyuncu_gazeteleri
  set kasa = kasa - m
  where id = g.id;

  insert into oyun.gazete_hareket(
    gazete_id, zaman, tutar, tur, aciklama
  ) values (
    g.id, t, -m, 'cekme', format('%s kasadan çekti', p.kad)
  );

  perform oyun.para_islem(
    p.id, m, 'gazete_gelir', format('%s gazete geliri', g.ad), t
  );

  return public.gazete_detay(g.id);
end $$;

create or replace function public.gazete_ayar(
  p_gazete bigint,
  p_slogan text,
  p_abonelik numeric
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  g oyun.oyuncu_gazeteleri;
  azami numeric := (
    select gazete_max_abonelik from oyun.ayarlar where id = 1
  );
  ab numeric := round(coalesce(p_abonelik, 0));
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif;

  if g.sahip is distinct from p.id then
    raise exception 'Gazete ayarlarını yalnızca sahibi değiştirebilir.';
  end if;

  if char_length(coalesce(p_slogan, '')) > 100 then
    raise exception 'Slogan en fazla 100 karakter olabilir.';
  end if;

  if ab < 0 or ab > azami then
    raise exception 'Abonelik 0-% ₺ arasında olmalı.', oyun.tl(azami);
  end if;

  update oyun.oyuncu_gazeteleri
  set slogan = btrim(coalesce(p_slogan, '')),
      abonelik_ucret = ab
  where id = g.id;

  return public.gazete_detay(g.id);
end $$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'teskilat_gorev_ver(int,text)',
    'teskilat_gorev_al(int)',
    'teskilat_ac2(int,text)',
    'basin()',
    'gazete_detay(bigint)',
    'gazete_kur(text,text,numeric)',
    'gazete_abone_ol(bigint)',
    'gazete_yazar_teklif(bigint,text,numeric)',
    'gazete_yazar_yanit(bigint,boolean)',
    'gazete_yazar_cikar(bigint,text)',
    'gazete_yayinla(bigint,text,text,text,bigint)',
    'gazete_para_cek(bigint,numeric)',
    'gazete_ayar(bigint,text,numeric)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

