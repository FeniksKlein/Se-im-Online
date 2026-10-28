-- 2026-10-29: Her Hazine değişikliğini izlenebilir kıl ve tahsisleri açıklamalı kaydet.
create table if not exists oyun.hazine_hareketleri (
  id bigint generated always as identity primary key,
  zaman timestamptz not null default now(),
  onceki numeric not null,
  sonraki numeric not null,
  fark numeric not null,
  tur text not null,
  aciklama text not null,
  kullanici uuid,
  constraint hazine_hareket_denge check (sonraki=onceki+fark)
);
create index if not exists hazine_hareketleri_zaman on oyun.hazine_hareketleri(id desc);
alter table oyun.hazine_hareketleri enable row level security;

create or replace function oyun.tg_hazine_hareket()
returns trigger language plpgsql security definer set search_path = '' as $$
declare tanim text;
begin
  if new.hazine is distinct from old.hazine then
    tanim:=nullif(current_setting('oyun.hazine_islem',true),'');
    insert into oyun.hazine_hareketleri(onceki,sonraki,fark,tur,aciklama,kullanici)
    values(old.hazine,new.hazine,new.hazine-old.hazine,
      case when new.hazine<old.hazine then 'cikis' else 'giris' end,
      coalesce(tanim,case when new.hazine<old.hazine then 'Diğer Hazine çıkışı' else 'Diğer Hazine girişi' end),
      auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists hazine_hareket_kaydi on oyun.ulke;
create trigger hazine_hareket_kaydi after update of hazine on oyun.ulke
for each row execute function oyun.tg_hazine_hareket();

-- Var olan onay ve güvenlik kontrollerine dokunmadan isimlendirilmiş denetim izi ekle.
do $audit$
declare d text; eski text;
begin
  d:=pg_get_functiondef('public.kamu_butce_dagit(numeric,jsonb)'::regprocedure);
  eski:='update oyun.ulke set hazine = hazine - p_toplam where id = 1 and hazine >= p_toplam;';
  if position(eski in d)=0 then raise exception 'kamu_butce_dagit fonksiyonu degismis, incele.'; end if;
  d:=replace(d,eski,
    'perform set_config(''oyun.hazine_islem'',''Merkezi bütçe tahsisi'',true);' || chr(10) ||
    eski || chr(10) ||
    '  perform set_config(''oyun.hazine_islem'','''',true);');
  execute d;

  d:=pg_get_functiondef('public.bakanlik_odenek_karar(bigint,boolean,text)'::regprocedure);
  eski:='update oyun.ulke set hazine = hazine - x.tutar where id = 1;';
  if position(eski in d)=0 then raise exception 'bakanlik_odenek_karar fonksiyonu degismis, incele.'; end if;
  d:=replace(d,eski,
    'perform set_config(''oyun.hazine_islem'',''Bakanlığa ek ödenek'',true);' || chr(10) ||
    eski || chr(10) ||
    '    perform set_config(''oyun.hazine_islem'','''',true);');
  execute d;

  d:=pg_get_functiondef('public.kamu_butce_panel()'::regprocedure);
  eski:='''hazine'',(SELECT hazine FROM oyun.ulke WHERE id=1),';
  if position(eski in d)=0 then raise exception 'kamu_butce_panel fonksiyonu degismis, incele.'; end if;
  d:=replace(d,eski,eski||chr(10)||
    '  ''son_hazine_hareketleri'',coalesce((select jsonb_agg(jsonb_build_object(''id'',z.id,''zaman'',z.zaman,''onceki'',z.onceki,''sonraki'',z.sonraki,''fark'',z.fark,''tur'',z.tur,''aciklama'',z.aciklama) order by z.id desc) from (select * from oyun.hazine_hareketleri order by id desc limit 15) z),''[]''::jsonb),');
  execute d;

  d:=pg_get_functiondef('public.yurutme_butce_masasi()'::regprocedure);
  eski:='''hazine'', round(u.hazine, 1)';
  if position(eski in d)=0 then raise exception 'yurutme_butce_masasi fonksiyonu degismis, incele.'; end if;
  d:=replace(d,eski,
    '''hazine'', round(u.hazine, 3), ''son_hazine_hareketleri'',coalesce((select jsonb_agg(jsonb_build_object(''zaman'',z.zaman,''fark'',round(z.fark,3),''onceki'',round(z.onceki,3),''sonraki'',round(z.sonraki,3),''aciklama'',z.aciklama) order by z.id desc) from (select * from oyun.hazine_hareketleri order by id desc limit 8) z),''[]''::jsonb)');
  execute d;

  -- Mitingin türü, il dışından gelen oyuncuların arayüzünü doğru göstermek için.
  d:=pg_get_functiondef('public.miting_meydan(bigint)'::regprocedure);
  eski:='''id'', m.id, ''baslik'', m.baslik';
  if position(eski in d)=0 then raise exception 'miting_meydan fonksiyonu degismis, incele.'; end if;
  d:=replace(d,eski,'''id'', m.id, ''tur'', m.tur, ''baslik'', m.baslik');
  execute d;
end $audit$;
