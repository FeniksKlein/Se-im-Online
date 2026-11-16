-- 2026.11.16-5 · Genel başkan yardımcılığı: tüzükle belirlenen sayı, gerçek yetki kayıtları, limit ve işlem geçmişi
-- SPK: parti organlarının görev ve yetkileri parti tüzüğüyle belirlenir. Oyunda tüzük ayarı her partiye aittir.
--  * GBY sayısı sabit 6 değil: parti tüzüğü 1–20 arası belirler (varsayılan 6, eski davranış).
--  * Yetki unvan yazısından değil `oyun.parti_gby_yetki` kayıtlarından gelir; GB verir/geri alır; her işlem loglanır.
--  * Mali yetkiye günlük harcama sınırı konabilir; sınır parti kasası hareketinde sunucuda denetlenir.
--  * Üyelik biterse, yardımcılık biterse ya da parti kapanırsa yetkiler kendiliğinden pasifleşir (kayıt silinmez).
-- Mevcut yardımcılar korunur; görev alanı ve miting yetkisi olanlara aynı yetkiler kayıt olarak aktarılır.

-- Sıra kısıtı tüzük sınırıyla uyumlu (en çok 20)
alter table oyun.parti_gby drop constraint if exists parti_gby_sira_check;
alter table oyun.parti_gby add constraint parti_gby_sira_check check (sira between 1 and 20);

create table if not exists oyun.parti_tuzuk_ayar (
  parti_id bigint primary key references oyun.partiler(id),
  gby_azami smallint not null default 6 check (gby_azami between 1 and 20),
  il_baskan_donem_gun integer not null default 60 check (il_baskan_donem_gun between 14 and 730),
  il_kongre_aday_saat integer not null default 24 check (il_kongre_aday_saat between 6 and 168),
  il_kongre_oy_saat integer not null default 24 check (il_kongre_oy_saat between 6 and 168),
  il_gecici_azami_gun integer not null default 14 check (il_gecici_azami_gun between 3 and 90),
  il_yk_azami smallint not null default 7 check (il_yk_azami between 3 and 25),
  guncelleme timestamptz not null default now(),
  guncelleyen uuid
);
alter table oyun.parti_tuzuk_ayar enable row level security;

create table if not exists oyun.parti_yetki_katalog (
  kod text primary key, ad text not null, aciklama text not null, limitli boolean not null default false, sira smallint not null default 100
);
insert into oyun.parti_yetki_katalog(kod,ad,aciklama,limitli,sira) values
 ('teskilat','Teşkilat yönetimi','İl teşkilatı açma, geçici il başkanı görevlendirme, il kongresi açma ve il başkanını gerekçeli görevden alma.',false,1),
 ('secim','Seçim işleri','Aday belirleme, aday tanıtımı ve seçim çalışmalarıyla ilgili parti işlemleri.',false,2),
 ('tanitim','Tanıtım ve medya','Parti adına duyuru, tanıtım, reklam ve medya işlemleri.',false,3),
 ('mali','Mali işler','Parti kasasından harcama ve yatırım işlemleri; günlük harcama sınırı konabilir.',true,4),
 ('hukuk','Siyasi ve hukuki işler','Disiplin süreci başlatma ve partinin hukuki işlemleri.',false,5),
 ('miting','Miting düzenleme','Parti adına istenen ilde miting düzenleme.',false,6)
on conflict (kod) do update set ad=excluded.ad, aciklama=excluded.aciklama, limitli=excluded.limitli, sira=excluded.sira;

create table if not exists oyun.parti_gby_yetki (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  user_id uuid not null references oyun.profiller(id),
  yetki text not null references oyun.parti_yetki_katalog(kod),
  gunluk_limit numeric check (gunluk_limit is null or gunluk_limit >= 0),
  kaynak text not null default 'ozel' check (kaynak in ('ozel','gorev_alani','gecis')),
  veren uuid,
  verilis timestamptz not null default now(),
  aktif boolean not null default true,
  bitis timestamptz,
  bitis_neden text,
  geri_alan uuid
);
create unique index if not exists parti_gby_yetki_aktif_uq on oyun.parti_gby_yetki(parti_id,user_id,yetki) where aktif;
create index if not exists parti_gby_yetki_kisi_ix on oyun.parti_gby_yetki(user_id) where aktif;
alter table oyun.parti_gby_yetki enable row level security;

create table if not exists oyun.parti_yetki_islem (
  id bigserial primary key,
  parti_id bigint not null,
  user_id uuid,
  yetki text,
  islem text not null,
  tutar numeric,
  ayrinti text,
  zaman timestamptz not null default now()
);
create index if not exists parti_yetki_islem_ix on oyun.parti_yetki_islem(parti_id, zaman desc);
create index if not exists parti_yetki_islem_mali_ix on oyun.parti_yetki_islem(user_id, zaman desc) where yetki='mali' and islem='harcama';
alter table oyun.parti_yetki_islem enable row level security;

-- Yardımcılar ------------------------------------------------------------
create or replace function oyun.parti_tuzuk(p_parti bigint)
returns oyun.parti_tuzuk_ayar language sql stable set search_path to '' as $$
  select coalesce((select t from oyun.parti_tuzuk_ayar t where t.parti_id=p_parti),
                  row(p_parti,6::smallint,60,24,24,14,7::smallint,now(),null::uuid)::oyun.parti_tuzuk_ayar)
$$;

create or replace function oyun.parti_yetki_log(p_parti bigint, p_user uuid, p_yetki text, p_islem text, p_tutar numeric, p_ayrinti text)
returns void language sql security definer set search_path to '' as $$
  insert into oyun.parti_yetki_islem(parti_id,user_id,yetki,islem,tutar,ayrinti,zaman)
  values(p_parti,p_user,p_yetki,p_islem,p_tutar,left(p_ayrinti,500),oyun.simdi());
$$;

-- Kişi şu an bu partinin üyesi ve yardımcısı mı, ve yetkisi aktif mi
create or replace function oyun.gby_yetkili(u uuid, p_parti bigint, p_yetki text)
returns boolean language sql stable set search_path to '' as $$
  select exists(
    select 1 from oyun.parti_gby_yetki y
     join oyun.parti_gby g on g.parti_id=y.parti_id and g.user_id=y.user_id
     join oyun.profiller p on p.id=y.user_id and p.parti_id=y.parti_id
     join oyun.partiler pa on pa.id=y.parti_id and not pa.kapali
    where y.user_id=u and y.parti_id=p_parti and y.yetki=p_yetki and y.aktif and not coalesce(p.yasakli,false))
$$;

-- Eski imza korunur: GB ya da alanlardan birinde aktif yetkisi olan yardımcı → parti id
create or replace function oyun.parti_gorevli(u uuid, p_alanlar text[])
returns bigint language sql stable set search_path to '' as $$
  select coalesce(
    (select pa.id from oyun.profiller p join oyun.partiler pa on pa.id = p.parti_id
      where p.id = u and pa.gb = u and not pa.kapali limit 1),
    (select pa.id from oyun.profiller p join oyun.partiler pa on pa.id = p.parti_id and not pa.kapali
      where p.id = u and exists(select 1 from unnest(p_alanlar) a where oyun.gby_yetkili(u, pa.id, a)) limit 1))
$$;

create or replace function oyun.teskilat_yonetici(u uuid, p_parti bigint)
returns boolean language sql stable set search_path to '' as $$
  select exists (select 1 from oyun.partiler where id = p_parti and gb = u and not kapali
                   and exists(select 1 from oyun.profiller p where p.id=u and p.parti_id=p_parti))
      or oyun.gby_yetkili(u, p_parti, 'teskilat')
$$;

create or replace function oyun.gby_unvan(u uuid)
returns text language sql stable set search_path to '' as $$
  select pa.kisa || ' ' || coalesce(nullif(btrim(g.gorev), '') || ' ', '') || 'Genel Başkan Yardımcısı'
  from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id and not pa.kapali
  join oyun.profiller p on p.id=g.user_id and p.parti_id=g.parti_id
  where g.user_id = u limit 1
$$;

-- Yetki verme / geri alma (iç)
create or replace function oyun.gby_yetki_yaz(p_parti bigint, p_user uuid, p_yetki text, p_aktif boolean, p_limit numeric, p_kaynak text, p_aktor uuid, p_neden text)
returns void language plpgsql security definer set search_path to '' as $$
declare t timestamptz:=oyun.simdi();
begin
  if p_aktif then
    update oyun.parti_gby_yetki set gunluk_limit=p_limit,
      kaynak=case when kaynak='ozel' then 'ozel' else coalesce(p_kaynak,kaynak) end
     where parti_id=p_parti and user_id=p_user and yetki=p_yetki and aktif;
    if not found then
      insert into oyun.parti_gby_yetki(parti_id,user_id,yetki,gunluk_limit,kaynak,veren,verilis)
      values(p_parti,p_user,p_yetki,p_limit,coalesce(p_kaynak,'ozel'),p_aktor,t);
    end if;
    perform oyun.parti_yetki_log(p_parti,p_user,p_yetki,'verildi',p_limit,coalesce(p_neden,''));
  else
    update oyun.parti_gby_yetki set aktif=false, bitis=t, bitis_neden=coalesce(p_neden,'geri_alindi'), geri_alan=p_aktor
     where parti_id=p_parti and user_id=p_user and yetki=p_yetki and aktif;
    if found then perform oyun.parti_yetki_log(p_parti,p_user,p_yetki,'geri_alindi',null,coalesce(p_neden,'')); end if;
  end if;
  -- Eski arayüzün okuduğu miting bayrağı yetki kaydıyla eşit kalır
  if p_yetki='miting' then
    perform set_config('oyun.gby_esitleme','1',true);
    update oyun.parti_gby set miting_yetkisi=p_aktif where parti_id=p_parti and user_id=p_user and miting_yetkisi is distinct from p_aktif;
    perform set_config('oyun.gby_esitleme','',true);
  end if;
end $$;

-- Tetikleyiciler: yardımcılık değişimi / bitişi, üyelik değişimi, parti kapanması
create or replace function oyun.parti_gby_yetki_esitle_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
declare eski text; yeni text;
begin
  if tg_op='DELETE' then
    update oyun.parti_gby_yetki set aktif=false, bitis=oyun.simdi(), bitis_neden='yardimcilik_bitti'
     where parti_id=old.parti_id and user_id=old.user_id and aktif;
    return old;
  end if;
  if tg_op='INSERT' then
    yeni := oyun.gby_alan(new.gorev);
    if yeni is not null then perform oyun.gby_yetki_yaz(new.parti_id,new.user_id,yeni,true,null,'gorev_alani',null,'görev alanı'); end if;
    if coalesce(new.miting_yetkisi,false) then perform oyun.gby_yetki_yaz(new.parti_id,new.user_id,'miting',true,null,'gorev_alani',null,'miting yetkisi'); end if;
    return new;
  end if;
  if coalesce(current_setting('oyun.gby_esitleme',true),'')='1' then return new; end if;
  eski := oyun.gby_alan(old.gorev); yeni := oyun.gby_alan(new.gorev);
  if eski is distinct from yeni then
    if eski is not null then
      update oyun.parti_gby_yetki set aktif=false, bitis=oyun.simdi(), bitis_neden='gorev_alani_degisti'
       where parti_id=new.parti_id and user_id=new.user_id and yetki=eski and aktif and kaynak in ('gorev_alani','gecis');
    end if;
    if yeni is not null then perform oyun.gby_yetki_yaz(new.parti_id,new.user_id,yeni,true,null,'gorev_alani',auth.uid(),'görev alanı'); end if;
  end if;
  if coalesce(old.miting_yetkisi,false) is distinct from coalesce(new.miting_yetkisi,false) then
    perform oyun.gby_yetki_yaz(new.parti_id,new.user_id,'miting',coalesce(new.miting_yetkisi,false),null,'ozel',auth.uid(),'miting yetkisi');
  end if;
  return new;
end $$;
create or replace trigger parti_gby_yetki_esitle after insert or update of gorev, miting_yetkisi or delete on oyun.parti_gby
  for each row execute function oyun.parti_gby_yetki_esitle_tg();

create or replace function oyun.profil_parti_yetki_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  if old.parti_id is not null and new.parti_id is distinct from old.parti_id then
    update oyun.parti_gby_yetki set aktif=false, bitis=oyun.simdi(), bitis_neden='uyelik_bitti'
     where user_id=new.id and parti_id=old.parti_id and aktif;
    -- İl başkanı başka partiye geçerse eski partideki il başkanlığı yetkileri devam etmez
    update oyun.parti_teskilat_gorev set aktif=false where user_id=new.id and parti_id=old.parti_id and aktif;
  end if;
  return new;
end $$;
create or replace trigger profil_parti_yetki after update of parti_id on oyun.profiller
  for each row execute function oyun.profil_parti_yetki_tg();

create or replace function oyun.parti_kapanis_yetki_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  if new.kapali and not coalesce(old.kapali,false) then
    update oyun.parti_gby_yetki set aktif=false, bitis=oyun.simdi(), bitis_neden='parti_kapandi' where parti_id=new.id and aktif;
    update oyun.parti_teskilat_gorev set aktif=false where parti_id=new.id and aktif;
  end if;
  return new;
end $$;
create or replace trigger parti_kapanis_yetki after update of kapali on oyun.partiler
  for each row execute function oyun.parti_kapanis_yetki_tg();

-- Mali yetki sınırı: GBY parti kasasından harcarken günlük sınır sunucuda denetlenir ve loglanır
create or replace function oyun.parti_harcama_yetki_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); lim numeric; harcanan numeric; gb uuid;
begin
  if u is null or new.tutar is null or new.tutar >= 0 then return new; end if;
  select pa.gb into gb from oyun.partiler pa where pa.id=new.parti_id;
  if gb is not distinct from u then return new; end if;
  if not exists(select 1 from oyun.parti_gby g where g.parti_id=new.parti_id and g.user_id=u) then return new; end if;
  select y.gunluk_limit into lim from oyun.parti_gby_yetki y where y.parti_id=new.parti_id and y.user_id=u and y.yetki='mali' and y.aktif;
  if lim is not null then
    select coalesce(sum(i.tutar),0) into harcanan from oyun.parti_yetki_islem i
     where i.user_id=u and i.parti_id=new.parti_id and i.yetki='mali' and i.islem='harcama' and i.zaman > oyun.simdi() - interval '24 hours';
    if harcanan + abs(new.tutar) > lim then
      raise exception 'Mali yetkinin günlük harcama sınırı aşılıyor (sınır % ₺, son 24 saatte % ₺ harcandı).', oyun.tl(lim), oyun.tl(harcanan);
    end if;
  end if;
  perform oyun.parti_yetki_log(new.parti_id,u,'mali','harcama',abs(new.tutar),coalesce(new.tur,'')||': '||coalesce(new.aciklama,''));
  return new;
end $$;
do $h$ begin
  if to_regclass('oyun.parti_hareket') is not null then
    execute 'create or replace trigger parti_harcama_yetki before insert on oyun.parti_hareket for each row execute function oyun.parti_harcama_yetki_tg()';
  end if;
end $h$;

-- RPC'ler ------------------------------------------------------------------
create or replace function public.gby_yetki_ver(p_kad text, p_yetki text, p_gunluk_limit numeric default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; h oyun.profiller; k oyun.parti_yetki_katalog;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Yardımcılara yetkiyi yalnız genel başkan verebilir.'; end if;
  select * into k from oyun.parti_yetki_katalog where kod=p_yetki;
  if k.kod is null then raise exception 'Geçersiz yetki.'; end if;
  select * into h from oyun.profiller where lower(kad)=lower(btrim(coalesce(p_kad,'')));
  if h.id is null or h.parti_id is distinct from pa.id or not exists(select 1 from oyun.parti_gby where parti_id=pa.id and user_id=h.id) then
    raise exception 'Bu oyuncu partinin genel başkan yardımcısı değil.'; end if;
  if p_gunluk_limit is not null and (not k.limitli or p_gunluk_limit < 0 or p_gunluk_limit > 1000000000) then
    raise exception 'Bu yetkiye sınır konamaz ya da sınır geçersiz.'; end if;
  perform oyun.gby_yetki_yaz(pa.id,h.id,k.kod,true,p_gunluk_limit,'ozel',p.id,'genel başkan verdi');
  perform oyun.bildir(h.id, format('%s Genel Başkanı sana "%s" yetkisi verdi%s.', pa.kisa, k.ad,
     case when p_gunluk_limit is not null then format(' (günlük sınır %s ₺)', oyun.tl(p_gunluk_limit)) else '' end), oyun.simdi());
  return public.parti_yetki_durum(pa.id);
end $$;

create or replace function public.gby_yetki_al(p_kad text, p_yetki text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; h oyun.profiller;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Yetkiyi yalnız genel başkan geri alabilir.'; end if;
  select * into h from oyun.profiller where lower(kad)=lower(btrim(coalesce(p_kad,'')));
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  if not exists(select 1 from oyun.parti_gby_yetki where parti_id=pa.id and user_id=h.id and yetki=p_yetki and aktif) then
    raise exception 'Bu yardımcının böyle aktif bir yetkisi yok.'; end if;
  perform oyun.gby_yetki_yaz(pa.id,h.id,p_yetki,false,null,null,p.id,'genel başkan geri aldı');
  perform oyun.bildir(h.id, format('%s Genel Başkanı "%s" yetkini geri aldı; diğer yetkilerin devam ediyor.', pa.kisa,
     (select ad from oyun.parti_yetki_katalog where kod=p_yetki)), oyun.simdi());
  return public.parti_yetki_durum(pa.id);
end $$;

create or replace function public.parti_tuzuk_ayarla(p_ayar jsonb)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; mevcut oyun.parti_tuzuk_ayar; n int;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Tüzük ayarlarını yalnız genel başkan değiştirebilir.'; end if;
  mevcut := oyun.parti_tuzuk(pa.id);
  insert into oyun.parti_tuzuk_ayar(parti_id,gby_azami,il_baskan_donem_gun,il_kongre_aday_saat,il_kongre_oy_saat,il_gecici_azami_gun,il_yk_azami,guncelleme,guncelleyen)
  values(pa.id,
    coalesce((p_ayar->>'gby_azami')::smallint,mevcut.gby_azami),
    coalesce((p_ayar->>'il_baskan_donem_gun')::int,mevcut.il_baskan_donem_gun),
    coalesce((p_ayar->>'il_kongre_aday_saat')::int,mevcut.il_kongre_aday_saat),
    coalesce((p_ayar->>'il_kongre_oy_saat')::int,mevcut.il_kongre_oy_saat),
    coalesce((p_ayar->>'il_gecici_azami_gun')::int,mevcut.il_gecici_azami_gun),
    coalesce((p_ayar->>'il_yk_azami')::smallint,mevcut.il_yk_azami), now(), p.id)
  on conflict (parti_id) do update set gby_azami=excluded.gby_azami, il_baskan_donem_gun=excluded.il_baskan_donem_gun,
    il_kongre_aday_saat=excluded.il_kongre_aday_saat, il_kongre_oy_saat=excluded.il_kongre_oy_saat,
    il_gecici_azami_gun=excluded.il_gecici_azami_gun, il_yk_azami=excluded.il_yk_azami, guncelleme=now(), guncelleyen=p.id;
  select count(*) into n from oyun.parti_gby where parti_id=pa.id and sira > (oyun.parti_tuzuk(pa.id)).gby_azami;
  if n > 0 then raise exception 'Önce tüzük sınırının üstündeki % yardımcının görevini sonlandırın.', n; end if;
  perform oyun.parti_yetki_log(pa.id,p.id,null,'tuzuk',null,p_ayar::text);
  return public.parti_yetki_durum(pa.id);
end $$;

create or replace function public.parti_yetki_durum(p_parti bigint)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); pa oyun.partiler; gor boolean;
begin
  select * into pa from oyun.partiler where id=p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;
  gor := exists(select 1 from oyun.profiller p where p.id=u and p.parti_id=pa.id);
  return jsonb_build_object(
    'parti_id',pa.id,'genel_baskan',pa.gb=u,
    'tuzuk',to_jsonb(oyun.parti_tuzuk(pa.id)) - 'guncelleyen' - 'parti_id',
    'katalog',(select jsonb_agg(jsonb_build_object('kod',kod,'ad',ad,'aciklama',aciklama,'limitli',limitli) order by sira) from oyun.parti_yetki_katalog),
    'yardimcilar',coalesce((select jsonb_agg(jsonb_build_object('sira',g.sira,'kad',oyun.kad(g.user_id),'gorev',g.gorev,
        'yetkiler',coalesce((select jsonb_agg(jsonb_build_object('yetki',y.yetki,'gunluk_limit',y.gunluk_limit,'verilis',y.verilis) order by y.yetki)
           from oyun.parti_gby_yetki y where y.parti_id=pa.id and y.user_id=g.user_id and y.aktif),'[]'::jsonb)) order by g.sira)
       from oyun.parti_gby g join oyun.profiller pr on pr.id=g.user_id and pr.parti_id=g.parti_id where g.parti_id=pa.id),'[]'::jsonb),
    'gecmis',case when gor then coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(i.user_id),'yetki',i.yetki,'islem',i.islem,'tutar',i.tutar,'zaman',i.zaman) order by i.zaman desc)
       from (select * from oyun.parti_yetki_islem i where i.parti_id=pa.id order by zaman desc limit 40) i),'[]'::jsonb) else '[]'::jsonb end);
end $$;

-- GBY atama: sıra sınırı parti tüzüğünden
do $a$
declare s text := pg_get_functiondef('public.gby_ata(integer,text)'::regprocedure);
begin
  s := replace(s, 'if p_sira is null or p_sira not between 1 and 6 then', 'if p_sira is null or p_sira not between 1 and (oyun.parti_tuzuk(pa.id)).gby_azami then');
  s := replace(s, $e$raise exception 'Geçersiz sıra (1-6).';$e$, $e$raise exception 'Geçersiz sıra: parti tüzüğüne göre en çok % yardımcı atanabilir.', (oyun.parti_tuzuk(pa.id)).gby_azami;$e$);
  if position('parti_tuzuk(pa.id)' in s)=0 then raise exception 'gby_ata yaması uygulanamadı'; end if;
  execute s;
end $a$;

-- Geçiş: mevcut yardımcıların görev alanı ve miting yetkisi kayda aktarılır (yalnız geçerli üyelikte)
insert into oyun.parti_gby_yetki(parti_id,user_id,yetki,kaynak,veren,verilis)
select g.parti_id,g.user_id,oyun.gby_alan(g.gorev),'gecis',null,coalesce(g.atama,now())
  from oyun.parti_gby g join oyun.profiller p on p.id=g.user_id and p.parti_id=g.parti_id join oyun.partiler pa on pa.id=g.parti_id and not pa.kapali
 where oyun.gby_alan(g.gorev) is not null
on conflict do nothing;
insert into oyun.parti_gby_yetki(parti_id,user_id,yetki,kaynak,veren,verilis)
select g.parti_id,g.user_id,'miting','gecis',null,coalesce(g.atama,now())
  from oyun.parti_gby g join oyun.profiller p on p.id=g.user_id and p.parti_id=g.parti_id join oyun.partiler pa on pa.id=g.parti_id and not pa.kapali
 where coalesce(g.miting_yetkisi,false)
on conflict do nothing;

do $g$
declare f text;
begin
  foreach f in array array['public.gby_yetki_ver(text,text,numeric)','public.gby_yetki_al(text,text)','public.parti_tuzuk_ayarla(jsonb)','public.parti_yetki_durum(bigint)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['oyun.parti_yetki_log(bigint,uuid,text,text,numeric,text)','oyun.gby_yetki_yaz(bigint,uuid,text,boolean,numeric,text,uuid,text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $g$;
