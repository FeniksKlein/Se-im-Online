-- 2026.11.16-6 · İl başkanlığı ve il kongresi (SPK m.19: il başkanı ve il yönetim kurulu il kongresince seçilir;
-- işten el çektirme ve geçici yönetim parti tüzüğüne göre merkez yönetimince yapılır)
--  * Teşkilat ilk kurulduğunda ya da başkanlık boşaldığında genel başkan / teşkilat yetkili GBY GEÇİCİ il başkanı görevlendirir.
--  * Geçici başkanlık seçilmiş başkanlıkla aynı statü değildir; tüzükteki süre (varsayılan 14 gün) dolunca kongre kendiliğinden açılır.
--  * Kongrede yalnız o partinin, kongre açılmadan önce üye olmuş ve o ilde kayıtlı oyuncuları aday olur ve oy kullanır (kişi başı 1 oy).
--  * Seçilmiş başkanın dönemi tüzükle (varsayılan 60 gün) belirlenir; dönem bitince başkan görevde kalır ve olağan kongre açılır.
--  * Görevden alma yalnız gerekçeli "işten el çektirme" işlemiyle olur ve olağanüstü kongre kendiliğinden açılır.
--  * İl yönetim kurulu: seçilmiş/geçici il başkanı il üyelerinden tüzük sınırına kadar kişi ekler ve görev verir.
--  * Başka partiye geçen il başkanının ve yönetim kurulu üyesinin eski partideki görevleri biter (zz_20261116_gby_yetki_sistemi.sql).
--  * Milletvekili adaylığı il başkanlığını sona erdirir (2839 m.18; mevcut secim_adayligi_kamu_gorev_tg). Görevdeki milletvekilinin
--    sonradan il başkanı seçilmesini yasaklayan açık bir kanun hükmü bulunmadığından buna izin verilir.
-- Mevcut il başkanları silinmez; "geçici" statüyle kayda geçer.

create table if not exists oyun.il_baskanlik (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  il_id smallint not null,
  user_id uuid not null references oyun.profiller(id),
  statu text not null check (statu in ('gecici','secilmis')),
  bas timestamptz not null default now(),
  donem_bit timestamptz,
  kongre_id bigint,
  atayan uuid,
  aktif boolean not null default true,
  bitis timestamptz,
  bitis_neden text
);
create unique index if not exists il_baskanlik_aktif_uq on oyun.il_baskanlik(parti_id,il_id) where aktif;
create index if not exists il_baskanlik_kisi_ix on oyun.il_baskanlik(user_id) where aktif;
alter table oyun.il_baskanlik enable row level security;

create table if not exists oyun.il_kongre (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  il_id smallint not null,
  tur text not null check (tur in ('ilk','olagan','olaganustu')),
  acan uuid,
  acilis timestamptz not null default now(),
  aday_bit timestamptz not null,
  oy_bit timestamptz not null,
  durum text not null default 'aday' check (durum in ('aday','oy','tamam','sonucsuz','iptal')),
  kazanan uuid,
  sonuc jsonb,
  kapanis timestamptz
);
create unique index if not exists il_kongre_acik_uq on oyun.il_kongre(parti_id,il_id) where durum in ('aday','oy');
create index if not exists il_kongre_zaman_ix on oyun.il_kongre(oy_bit) where durum in ('aday','oy');
alter table oyun.il_kongre enable row level security;

create table if not exists oyun.il_kongre_aday (
  kongre_id bigint not null references oyun.il_kongre(id),
  user_id uuid not null references oyun.profiller(id),
  vaat text,
  basvuru timestamptz not null default now(),
  cekildi boolean not null default false,
  primary key (kongre_id,user_id)
);
alter table oyun.il_kongre_aday enable row level security;

create table if not exists oyun.il_kongre_oy (
  kongre_id bigint not null references oyun.il_kongre(id),
  secmen uuid not null references oyun.profiller(id),
  aday uuid not null references oyun.profiller(id),
  zaman timestamptz not null default now(),
  primary key (kongre_id,secmen)
);
create index if not exists il_kongre_oy_aday_ix on oyun.il_kongre_oy(kongre_id,aday);
alter table oyun.il_kongre_oy enable row level security;

create table if not exists oyun.il_yonetim_kurulu (
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id),
  il_id smallint not null,
  user_id uuid not null references oyun.profiller(id),
  gorev text,
  ekleyen uuid,
  eklenme timestamptz not null default now(),
  aktif boolean not null default true,
  cikis timestamptz,
  cikis_neden text
);
create unique index if not exists il_yk_aktif_uq on oyun.il_yonetim_kurulu(parti_id,il_id,user_id) where aktif;
create index if not exists il_yk_kisi_ix on oyun.il_yonetim_kurulu(user_id) where aktif;
alter table oyun.il_yonetim_kurulu enable row level security;

-- Yardımcılar ------------------------------------------------------------
create or replace function oyun.il_kongre_secmen_mi(p_kongre oyun.il_kongre, u uuid)
returns boolean language sql stable set search_path to '' as $$
  select exists(select 1 from oyun.profiller p where p.id=u and p.parti_id=p_kongre.parti_id and p.il_id=p_kongre.il_id
     and not coalesce(p.yasakli,false)
     and coalesce(p.parti_at,p.olusturma) <= p_kongre.acilis
     and coalesce(p.il_at,p.olusturma) <= p_kongre.acilis)
$$;

create or replace function oyun.il_baskani(p_parti bigint, p_il smallint)
returns uuid language sql stable set search_path to '' as $$
  select g.user_id from oyun.parti_teskilat_gorev g where g.parti_id=p_parti and g.il_id=p_il and g.aktif limit 1
$$;

-- parti_teskilat_gorev (eski arayüzlerin kullandığı tek "il başkanı" kaydı) ile statü geçmişini eşit tutar
create or replace function oyun.il_baskanlik_esitle_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi(); st text := nullif(current_setting('oyun.il_baskan_statu',true),'');
  kid bigint := nullif(current_setting('oyun.il_baskan_kongre',true),'')::bigint;
  neden text := coalesce(nullif(current_setting('oyun.il_baskan_neden',true),''),'gorev_bitti');
begin
  if tg_op='UPDATE' and old.aktif and (not new.aktif or new.user_id is distinct from old.user_id) then
    update oyun.il_baskanlik set aktif=false, bitis=t, bitis_neden=neden
     where parti_id=old.parti_id and il_id=old.il_id and aktif;
    update oyun.il_yonetim_kurulu set aktif=false, cikis=t, cikis_neden='il_baskani_degisti'
     where parti_id=old.parti_id and il_id=old.il_id and aktif and new.user_id is distinct from old.user_id;
  end if;
  if new.aktif and (tg_op='INSERT' or not old.aktif or new.user_id is distinct from old.user_id) then
    update oyun.il_baskanlik set aktif=false, bitis=t, bitis_neden=neden where parti_id=new.parti_id and il_id=new.il_id and aktif;
    insert into oyun.il_baskanlik(parti_id,il_id,user_id,statu,bas,donem_bit,kongre_id,atayan)
    values(new.parti_id,new.il_id,new.user_id,coalesce(st,'gecici'),t,
      case when coalesce(st,'gecici')='secilmis' then t + make_interval(days => (oyun.parti_tuzuk(new.parti_id)).il_baskan_donem_gun) end,
      kid,new.atayan);
  end if;
  return new;
end $$;
create or replace trigger il_baskanlik_esitle after insert or update on oyun.parti_teskilat_gorev
  for each row execute function oyun.il_baskanlik_esitle_tg();

-- Profil partiden/ilden ayrılınca yönetim kurulu üyeliği ve kongre adaylığı biter
create or replace function oyun.il_teskilat_profil_tg()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  if new.parti_id is distinct from old.parti_id or new.il_id is distinct from old.il_id then
    update oyun.il_yonetim_kurulu set aktif=false, cikis=oyun.simdi(), cikis_neden='uyelik_veya_il_degisti'
     where user_id=new.id and aktif and (parti_id is distinct from new.parti_id or il_id is distinct from new.il_id);
    update oyun.il_kongre_aday a set cekildi=true from oyun.il_kongre k
     where a.kongre_id=k.id and a.user_id=new.id and k.durum in ('aday','oy') and not a.cekildi
       and (k.parti_id is distinct from new.parti_id or k.il_id is distinct from new.il_id);
  end if;
  return new;
end $$;
create or replace trigger il_teskilat_profil after update of parti_id, il_id on oyun.profiller
  for each row execute function oyun.il_teskilat_profil_tg();

-- Kongre açar (iç)
create or replace function oyun.il_kongre_ac_ic(p_parti bigint, p_il smallint, p_tur text, p_acan uuid)
returns bigint language plpgsql security definer set search_path to '' as $$
declare tz oyun.parti_tuzuk_ayar := oyun.parti_tuzuk(p_parti); t timestamptz := oyun.simdi(); kid bigint; ilad text;
begin
  select id into kid from oyun.il_kongre where parti_id=p_parti and il_id=p_il and durum in ('aday','oy');
  if kid is not null then return kid; end if;
  insert into oyun.il_kongre(parti_id,il_id,tur,acan,acilis,aday_bit,oy_bit)
  values(p_parti,p_il,p_tur,p_acan,t,t+make_interval(hours=>tz.il_kongre_aday_saat),t+make_interval(hours=>tz.il_kongre_aday_saat+tz.il_kongre_oy_saat))
  returning id into kid;
  select ad into ilad from oyun.iller where id=p_il;
  perform oyun.bildir(p.id, format('%s %s il kongresi açıldı (%s). Aday başvurusu %s''e kadar; oy verme ardından %s saat.',
      (select kisa from oyun.partiler where id=p_parti), ilad,
      case p_tur when 'ilk' then 'ilk kongre' when 'olagan' then 'olağan' else 'olağanüstü' end,
      to_char((t+make_interval(hours=>tz.il_kongre_aday_saat)) at time zone 'Europe/Istanbul','DD.MM HH24:MI'), tz.il_kongre_oy_saat), t)
   from oyun.profiller p where p.parti_id=p_parti and p.il_id=p_il and not coalesce(p.yasakli,false);
  perform oyun.parti_yetki_log(p_parti,p_acan,'teskilat','kongre_acildi',null,format('il %s, %s, kongre #%s',p_il,p_tur,kid));
  return kid;
end $$;

-- Görev ataması (iç): statü ile parti_teskilat_gorev'e yazar
create or replace function oyun.il_baskan_yaz(p_parti bigint, p_il smallint, p_user uuid, p_statu text, p_kongre bigint, p_atayan uuid, p_neden text)
returns void language plpgsql security definer set search_path to '' as $$
begin
  perform set_config('oyun.il_baskan_statu',p_statu,true);
  perform set_config('oyun.il_baskan_kongre',coalesce(p_kongre::text,''),true);
  perform set_config('oyun.il_baskan_neden',coalesce(p_neden,''),true);
  if p_user is null then
    update oyun.parti_teskilat_gorev set aktif=false where parti_id=p_parti and il_id=p_il and aktif;
  else
    insert into oyun.parti_teskilat_gorev(parti_id,il_id,user_id,atayan,atama,aktif)
    values(p_parti,p_il,p_user,p_atayan,oyun.simdi(),true)
    on conflict(parti_id,il_id) do update set user_id=excluded.user_id, atayan=excluded.atayan, atama=excluded.atama, aktif=true;
    -- aynı kişi yeniden seçilirse satır değişmeyebilir: statü kaydını açıkça güncelle
    if p_statu='secilmis' then
      update oyun.il_baskanlik set statu='secilmis', kongre_id=p_kongre,
        donem_bit=oyun.simdi()+make_interval(days=>(oyun.parti_tuzuk(p_parti)).il_baskan_donem_gun)
       where parti_id=p_parti and il_id=p_il and aktif and user_id=p_user;
    end if;
  end if;
  perform set_config('oyun.il_baskan_statu','',true);
  perform set_config('oyun.il_baskan_kongre','',true);
  perform set_config('oyun.il_baskan_neden','',true);
end $$;

-- Eski "İl Başkanı ata / kaldır" uçları: seçilmiş başkan bu yolla değiştirilemez; atananlar geçicidir
do $e$
declare s text;
begin
  s := pg_get_functiondef('public.teskilat_gorev_ver(integer,text)'::regprocedure);
  s := replace(s, $x$  select ad into ilad from oyun.iller where id=p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;$x$, $x$  select ad into ilad from oyun.iller where id=p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;
  if exists(select 1 from oyun.il_baskanlik b where b.parti_id=pa.id and b.il_id=p_il and b.aktif and b.statu='secilmis') then
    raise exception 'Bu ilde kongrede seçilmiş bir il başkanı var. Değiştirmek için önce gerekçeli "Görevden al" işlemiyle işten el çektirmelisin; ardından olağanüstü kongre açılır.';
  end if;
  if coalesce(h.yasakli,false) then raise exception 'Kısıtlı oyuncu il başkanı olamaz.'; end if;
  perform set_config('oyun.il_baskan_statu','gecici',true);$x$);
  s := replace(s, $x$seni %s Parti İl Başkanı yaptı. Milletvekili olsan da bu görev devam eder.$x$, $x$seni %s GEÇİCİ Parti İl Başkanı olarak görevlendirdi; il kongresi yapılınca il başkanını üyeler seçecek.$x$);
  if position('il_baskan_statu' in s)=0 then raise exception 'teskilat_gorev_ver yaması uygulanamadı'; end if;
  execute s;
  s := pg_get_functiondef('public.teskilat_gorev_al(integer)'::regprocedure);
  s := replace(s, $x$  select user_id into h from oyun.parti_teskilat_gorev$x$, $x$  if exists(select 1 from oyun.il_baskanlik b where b.parti_id=pa.id and b.il_id=p_il and b.aktif and b.statu='secilmis') then
    raise exception 'Seçilmiş il başkanı yalnız gerekçeli "Görevden al" işlemiyle işten el çektirilebilir.';
  end if;
  select user_id into h from oyun.parti_teskilat_gorev$x$);
  if position('Seçilmiş il başkanı yalnız' in s)=0 then raise exception 'teskilat_gorev_al yaması uygulanamadı'; end if;
  execute s;
end $e$;

-- RPC'ler ------------------------------------------------------------------
create or replace function public.il_kongre_ac(p_il integer)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; kid bigint; tur text;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali;
  if pa.id is null or not oyun.teskilat_yonetici(p.id,pa.id) then raise exception 'İl kongresini genel başkan ya da teşkilat yetkili genel başkan yardımcısı açabilir.'; end if;
  if not exists(select 1 from oyun.parti_teskilat where parti_id=pa.id and il_id=p_il) then raise exception 'Bu ilde parti teşkilatı yok.'; end if;
  if exists(select 1 from oyun.il_kongre where parti_id=pa.id and il_id=p_il and durum in ('aday','oy')) then raise exception 'Bu ilde süren bir kongre var.'; end if;
  tur := case when exists(select 1 from oyun.il_kongre where parti_id=pa.id and il_id=p_il and durum='tamam') then 'olagan' else 'ilk' end;
  kid := oyun.il_kongre_ac_ic(pa.id,p_il::smallint,tur,p.id);
  return public.il_teskilat_detay(pa.id,p_il);
end $$;

create or replace function public.il_gecici_baskan_ata(p_il integer, p_kad text)
returns jsonb language sql security definer set search_path to '' as $$
  select public.teskilat_gorev_ver(p_il,p_kad) || jsonb_build_object('il_detay',public.il_teskilat_detay((select parti_id from oyun.profiller where id=auth.uid()),p_il))
$$;

create or replace function public.il_baskan_gorevden_al(p_il integer, p_gerekce text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); pa oyun.partiler; h uuid; t timestamptz := oyun.simdi();
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali;
  if pa.id is null or not oyun.teskilat_yonetici(p.id,pa.id) then raise exception 'İl başkanını genel başkan ya da teşkilat yetkili genel başkan yardımcısı görevden alabilir.'; end if;
  if char_length(btrim(coalesce(p_gerekce,''))) < 20 then raise exception 'Görevden alma (işten el çektirme) için en az 20 karakterlik gerekçe yazılmalı.'; end if;
  h := oyun.il_baskani(pa.id,p_il::smallint);
  if h is null then raise exception 'Bu ilde görevde il başkanı yok.'; end if;
  perform oyun.il_baskan_yaz(pa.id,p_il::smallint,null,null,null,p.id,'gorevden_alindi: '||left(btrim(p_gerekce),300));
  perform oyun.parti_yetki_log(pa.id,p.id,'teskilat','il_baskani_gorevden_alindi',null,format('il %s, %s: %s',p_il,oyun.kad(h),left(btrim(p_gerekce),300)));
  perform oyun.bildir(h, format('%s %s il başkanlığı görevinden alındın (işten el çektirme). Gerekçe: %s. İlde olağanüstü kongre açıldı; aday olabilirsin.',
     pa.kisa,(select ad from oyun.iller where id=p_il),left(btrim(p_gerekce),300)), t);
  perform oyun.il_kongre_ac_ic(pa.id,p_il::smallint,'olaganustu',p.id);
  return public.il_teskilat_detay(pa.id,p_il);
end $$;

create or replace function public.il_kongre_aday_ol(p_kongre bigint, p_vaat text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); k oyun.il_kongre;
begin
  select * into k from oyun.il_kongre where id=p_kongre for update;
  if k.id is null or k.durum<>'aday' or oyun.simdi()>=k.aday_bit then raise exception 'Bu kongrede aday başvurusu açık değil.'; end if;
  if not oyun.il_kongre_secmen_mi(k,u) then raise exception 'Aday olmak için kongre açılmadan önce bu ilde partiye üye ve kayıtlı olmalısın.'; end if;
  if oyun.gozalti_aktif(u) is not null then raise exception 'Gözaltındayken aday olunamaz.'; end if;
  insert into oyun.il_kongre_aday(kongre_id,user_id,vaat) values(k.id,u,left(btrim(coalesce(p_vaat,'')),600))
  on conflict (kongre_id,user_id) do update set cekildi=false, vaat=excluded.vaat;
  return public.il_teskilat_detay(k.parti_id,k.il_id);
end $$;

create or replace function public.il_kongre_cekil(p_kongre bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); k oyun.il_kongre;
begin
  select * into k from oyun.il_kongre where id=p_kongre;
  if k.id is null or k.durum not in ('aday','oy') then raise exception 'Kongre sürmüyor.'; end if;
  update oyun.il_kongre_aday set cekildi=true where kongre_id=k.id and user_id=u and not cekildi;
  if not found then raise exception 'Bu kongrede adaylığın yok.'; end if;
  return public.il_teskilat_detay(k.parti_id,k.il_id);
end $$;

create or replace function public.il_kongre_oy(p_kongre bigint, p_aday_kad text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); k oyun.il_kongre; a uuid; t timestamptz := oyun.simdi();
begin
  select * into k from oyun.il_kongre where id=p_kongre;
  if k.id is null or k.durum not in ('aday','oy') or t < k.aday_bit or t >= k.oy_bit then raise exception 'Bu kongrede şu anda oy verilemez.'; end if;
  if not oyun.il_kongre_secmen_mi(k,u) then raise exception 'Bu kongrede oy hakkın yok: kongre açılmadan önce bu ilde partiye üye ve kayıtlı olmalısın.'; end if;
  select a2.user_id into a from oyun.il_kongre_aday a2 join oyun.profiller p on p.id=a2.user_id
   where a2.kongre_id=k.id and not a2.cekildi and lower(p.kad)=lower(btrim(coalesce(p_aday_kad,'')));
  if a is null then raise exception 'Aday bulunamadı.'; end if;
  insert into oyun.il_kongre_oy(kongre_id,secmen,aday,zaman) values(k.id,u,a,t);
  return public.il_teskilat_detay(k.parti_id,k.il_id);
exception when unique_violation then raise exception 'Bu kongrede zaten oy kullandın.';
end $$;

create or replace function public.il_yk_ekle(p_il integer, p_kad text, p_gorev text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); pid bigint := (select parti_id from oyun.profiller where id=u); h oyun.profiller; n int;
begin
  if pid is null or not (oyun.il_baskani(pid,p_il::smallint) is not distinct from u or oyun.teskilat_yonetici(u,pid)) then
    raise exception 'İl yönetim kuruluna kişi ekleme yetkisi il başkanında (ve genel merkezde) dır.'; end if;
  if oyun.il_baskani(pid,p_il::smallint) is null then raise exception 'Önce il başkanı belirlenmeli.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pid or h.il_id is distinct from p_il::smallint or coalesce(h.yasakli,false) then
    raise exception 'Yönetim kurulu üyesi bu ilde kayıtlı parti üyesi olmalı.'; end if;
  select count(*) into n from oyun.il_yonetim_kurulu where parti_id=pid and il_id=p_il and aktif;
  if n >= (oyun.parti_tuzuk(pid)).il_yk_azami and not exists(select 1 from oyun.il_yonetim_kurulu where parti_id=pid and il_id=p_il and user_id=h.id and aktif) then
    raise exception 'Tüzüğe göre il yönetim kurulu en çok % kişidir.', (oyun.parti_tuzuk(pid)).il_yk_azami; end if;
  update oyun.il_yonetim_kurulu set gorev=nullif(left(btrim(coalesce(p_gorev,'')),60),'') where parti_id=pid and il_id=p_il and user_id=h.id and aktif;
  if not found then
    insert into oyun.il_yonetim_kurulu(parti_id,il_id,user_id,gorev,ekleyen) values(pid,p_il,h.id,nullif(left(btrim(coalesce(p_gorev,'')),60),''),u);
  end if;
  perform oyun.bildir(h.id, format('%s il yönetim kuruluna alındın%s.', (select ad from oyun.iller where id=p_il),
     case when nullif(btrim(coalesce(p_gorev,'')),'') is not null then ' · Görev: '||left(btrim(p_gorev),60) else '' end), oyun.simdi());
  return public.il_teskilat_detay(pid,p_il);
end $$;

create or replace function public.il_yk_cikar(p_il integer, p_kad text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare u uuid := auth.uid(); pid bigint := (select parti_id from oyun.profiller where id=u); h oyun.profiller;
begin
  if pid is null or not (oyun.il_baskani(pid,p_il::smallint) is not distinct from u or oyun.teskilat_yonetici(u,pid)) then
    raise exception 'Yetkin yok.'; end if;
  h := oyun.profil_bul(p_kad);
  update oyun.il_yonetim_kurulu set aktif=false, cikis=oyun.simdi(), cikis_neden='cikarildi' where parti_id=pid and il_id=p_il and user_id=h.id and aktif;
  if not found then raise exception 'Bu kişi il yönetim kurulunda değil.'; end if;
  return public.il_teskilat_detay(pid,p_il);
end $$;

create or replace function public.il_teskilat_detay(p_parti bigint, p_il integer)
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); b oyun.il_baskanlik; k oyun.il_kongre; bitti boolean;
begin
  select * into b from oyun.il_baskanlik where parti_id=p_parti and il_id=p_il and aktif;
  select * into k from oyun.il_kongre where parti_id=p_parti and il_id=p_il order by id desc limit 1;
  bitti := k.id is not null and k.durum in ('tamam','sonucsuz','iptal');
  return jsonb_build_object(
    'il_id',p_il,'il',(select ad from oyun.iller where id=p_il),'teskilat',exists(select 1 from oyun.parti_teskilat where parti_id=p_parti and il_id=p_il),
    'baskan',case when b.id is null then null else jsonb_build_object('kad',oyun.kad(b.user_id),'statu',b.statu,'bas',b.bas,'donem_bit',b.donem_bit) end,
    'yonetim_kurulu',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(y.user_id),'gorev',y.gorev) order by y.eklenme)
       from oyun.il_yonetim_kurulu y where y.parti_id=p_parti and y.il_id=p_il and y.aktif),'[]'::jsonb),
    'kongre',case when k.id is null then null else jsonb_build_object('id',k.id,'tur',k.tur,'durum',k.durum,'acilis',k.acilis,'aday_bit',k.aday_bit,'oy_bit',k.oy_bit,
       'kazanan',oyun.kad(k.kazanan),'sonuc',k.sonuc,
       'adaylar',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(a.user_id),'vaat',a.vaat,
            'oy',case when bitti then (select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id and o.aday=a.user_id) end) order by a.basvuru)
          from oyun.il_kongre_aday a where a.kongre_id=k.id and not a.cekildi),'[]'::jsonb),
       'oy_sayisi',(select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id),
       'secmen_mi',oyun.il_kongre_secmen_mi(k,u),
       'oy_verdim',exists(select 1 from oyun.il_kongre_oy o where o.kongre_id=k.id and o.secmen=u),
       'adayim',exists(select 1 from oyun.il_kongre_aday a where a.kongre_id=k.id and a.user_id=u and not a.cekildi)) end,
    'yonetebilir',oyun.teskilat_yonetici(u,p_parti),
    'il_baskaniyim',b.user_id is not distinct from u and b.id is not null,
    'tuzuk',to_jsonb(oyun.parti_tuzuk(p_parti)) - 'guncelleyen' - 'parti_id');
end $$;

-- Zamanlayıcı: kongre sonuçları, süresi dolan geçici başkanlık ve dönemi biten başkanlık için kongre
create or replace function oyun.il_kongre_tick()
returns integer language plpgsql security definer set search_path to '' as $$
declare r record; k oyun.il_kongre; t timestamptz := oyun.simdi(); kaz uuid; v_sonuc jsonb; n int := 0;
begin
  if not pg_try_advisory_xact_lock(781240) then return 0; end if;
  update oyun.il_kongre set durum='oy' where durum='aday' and aday_bit<=t;
  for r in select id from oyun.il_kongre where durum in ('aday','oy') and oy_bit<=t order by oy_bit limit 200 loop
    begin
      select * into k from oyun.il_kongre where id=r.id for update;
      select coalesce(jsonb_agg(jsonb_build_object('kad',oyun.kad(x.user_id),'oy',x.oy) order by x.oy desc, x.basvuru),'[]'::jsonb) into v_sonuc
        from (select a.user_id, a.basvuru, (select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id and o.aday=a.user_id) oy
                from oyun.il_kongre_aday a where a.kongre_id=k.id and not a.cekildi) x;
      -- en çok oy; eşitlikte önce başvuran; kazanan hâlâ uygun üye olmalı
      select x.user_id into kaz from (select a.user_id, a.basvuru, (select count(*) from oyun.il_kongre_oy o where o.kongre_id=k.id and o.aday=a.user_id) oy
                from oyun.il_kongre_aday a where a.kongre_id=k.id and not a.cekildi) x
       where x.oy>0 and exists(select 1 from oyun.profiller p where p.id=x.user_id and p.parti_id=k.parti_id and p.il_id=k.il_id and not coalesce(p.yasakli,false))
       order by x.oy desc, x.basvuru limit 1;
      if kaz is null then
        update oyun.il_kongre set durum='sonucsuz', sonuc=jsonb_build_object('adaylar',v_sonuc,'neden','Geçerli oy alan uygun aday yok'), kapanis=t where id=k.id;
        perform oyun.bildir(p.id, format('%s il kongresi sonuçsuz kaldı (geçerli oy alan aday yok). Mevcut il başkanı görevine devam eder.',(select ad from oyun.iller where id=k.il_id)),t)
          from oyun.profiller p where p.parti_id=k.parti_id and p.il_id=k.il_id and not coalesce(p.yasakli,false);
      else
        perform oyun.il_baskan_yaz(k.parti_id,k.il_id,kaz,'secilmis',k.id,null,'kongre_sonucu');
        update oyun.il_kongre set durum='tamam', kazanan=kaz, sonuc=jsonb_build_object('adaylar',v_sonuc), kapanis=t where id=k.id;
        perform oyun.bildir(p.id, format('%s il kongresi tamamlandı: il başkanı %s seçildi.',(select ad from oyun.iller where id=k.il_id),oyun.kad(kaz)),t)
          from oyun.profiller p where p.parti_id=k.parti_id and p.il_id=k.il_id and not coalesce(p.yasakli,false);
        perform oyun.parti_yetki_log(k.parti_id,kaz,'teskilat','il_baskani_secildi',null,format('il %s, kongre #%s',k.il_id,k.id));
      end if;
      n := n+1;
    exception when others then raise warning 'il_kongre_tick #%: %', r.id, sqlerrm;
    end;
  end loop;
  -- Süresi dolan geçici başkanlık ve dönemi biten seçilmiş başkanlık: kongre kendiliğinden açılır, başkan görevde kalır
  for r in select b.parti_id, b.il_id, b.statu from oyun.il_baskanlik b join oyun.partiler pa on pa.id=b.parti_id and not pa.kapali
     where b.aktif and not exists(select 1 from oyun.il_kongre kq where kq.parti_id=b.parti_id and kq.il_id=b.il_id and kq.durum in ('aday','oy'))
       and not exists(select 1 from oyun.il_kongre kq where kq.parti_id=b.parti_id and kq.il_id=b.il_id and kq.kapanis > t - interval '3 days')
       and ((b.statu='gecici' and b.bas <= t - make_interval(days=>(oyun.parti_tuzuk(b.parti_id)).il_gecici_azami_gun))
         or (b.statu='secilmis' and b.donem_bit <= t))
     limit 100 loop
    begin
      perform oyun.il_kongre_ac_ic(r.parti_id,r.il_id,case when r.statu='gecici' and not exists(select 1 from oyun.il_kongre kq where kq.parti_id=r.parti_id and kq.il_id=r.il_id and kq.durum='tamam') then 'ilk' else 'olagan' end,null);
    exception when others then raise warning 'il_kongre_tick ac %/%: %', r.parti_id, r.il_id, sqlerrm;
    end;
  end loop;
  return n;
end $$;

insert into oyun.zamanlayici_adim(adim,komut,periyot_dk,ofset_dk,sira,aktif)
values('il_kongre','select oyun.il_kongre_tick()',5,3,120,true)
on conflict (adim) do update set komut=excluded.komut, periyot_dk=excluded.periyot_dk, aktif=true;

-- Geçiş: mevcut il başkanları silinmeden "geçici" statüyle kayda geçer
insert into oyun.il_baskanlik(parti_id,il_id,user_id,statu,bas,atayan)
select g.parti_id,g.il_id,g.user_id,'gecici',coalesce(g.atama,now()),g.atayan from oyun.parti_teskilat_gorev g
 where g.aktif and not exists(select 1 from oyun.il_baskanlik b where b.parti_id=g.parti_id and b.il_id=g.il_id and b.aktif);

do $g$
declare f text;
begin
  foreach f in array array['public.il_kongre_ac(integer)','public.il_gecici_baskan_ata(integer,text)','public.il_baskan_gorevden_al(integer,text)',
    'public.il_kongre_aday_ol(bigint,text)','public.il_kongre_cekil(bigint)','public.il_kongre_oy(bigint,text)',
    'public.il_yk_ekle(integer,text,text)','public.il_yk_cikar(integer,text)','public.il_teskilat_detay(bigint,integer)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  foreach f in array array['oyun.il_kongre_ac_ic(bigint,smallint,text,uuid)','oyun.il_baskan_yaz(bigint,smallint,uuid,text,bigint,uuid,text)','oyun.il_kongre_tick()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $g$;
