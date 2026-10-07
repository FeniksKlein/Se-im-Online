-- =====================================================================
-- SEÇİM SİMÜLASYONU ONLINE — 20) SİYASİ SİSTEM
-- Parlamenter sistem, hükümet/güvenoyu/gensoru, erken seçim,
-- gelişmiş anayasa, dinamik TBMM sandalyesi ve teşkilat erişilebilirliği.
-- =====================================================================

alter table oyun.iller add column if not exists mv_secim smallint;
update oyun.iller set mv_secim = mv where mv_secim is null;

alter table oyun.ayarlar alter column teskilat_ucret set default 500;
update oyun.ayarlar set teskilat_ucret = 500 where id = 1 and teskilat_ucret = 2000;

insert into oyun.anayasa(kod,ad,deger,min,max,aciklama) values
 ('hukumet_sistemi','Hükümet sistemi',0,0,1,'0: Cumhurbaşkanlığı sistemi · 1: Parlamenter sistem. Parlamenter sistemde yürütmeyi güvenoyu alan Başbakan ve kabine kullanır.'),
 ('secim_baraji','Genel seçim ülke barajı',7,0,15,'Partilerin TBMM sandalyesi kazanabilmesi için gereken ulusal oy oranı. Bir ittifak bu oranı aşarsa ittifaktaki partiler de barajı geçmiş sayılır.'),
 ('cb_gorev_suresi','Cumhurbaşkanı görev süresi (ay)',1,1,12,'Cumhurbaşkanlığı sisteminde olağan Cumhurbaşkanlığı seçiminin kaç ayda bir yapılacağını belirler.'),
 ('milletvekili_sayisi','TBMM milletvekili sayısı',600,300,750,'Genel seçimde dağıtılacak toplam TBMM sandalyesi. İl kontenjanları mevcut nüfus ağırlıklarına orantılı dağıtılır.'),
 ('yerel_yetki','Yerel yönetim yetkisi (%)',100,25,100,'Belediyelerin yerel vergi ve destekleri varsayılan değerden ne kadar geniş aralıkta değiştirebileceğini belirler.'),
 ('erken_secim_esigi','Erken seçim Meclis eşiği (%)',60,50,75,'Erken seçim kararının kabulü için aktif milletvekillerinin en az bu oranının kabul oyu gerekir.')
on conflict (kod) do update set ad=excluded.ad,min=excluded.min,max=excluded.max,aciklama=excluded.aciklama;

create or replace function oyun.hukumet_sistemi() returns int
language sql stable set search_path='' as $$
  select coalesce((select round(deger)::int from oyun.anayasa where kod='hukumet_sistemi'),0)
$$;

create or replace function oyun.anayasa_deger(p_kod text) returns numeric
language sql stable set search_path='' as $$
  select case
    when p_kod='kararname_sinir'
     and coalesce((select round(deger)::int from oyun.anayasa where kod='hukumet_sistemi'),0)=1 then 0
    else (select deger from oyun.anayasa where kod=p_kod)
  end
$$;

create or replace function oyun.dagit_mv_sandalye(p_toplam int) returns void
language plpgsql set search_path='' as $$
begin
  if p_toplam < 81 or p_toplam > 1000 then raise exception 'Geçersiz milletvekili sayısı.'; end if;
  with q0 as (
    select i.id,
      1 + floor((p_toplam-81) * i.mv::numeric / nullif(sum(i.mv) over(),0))::int as taban,
      ((p_toplam-81) * i.mv::numeric / nullif(sum(i.mv) over(),0))
        - floor((p_toplam-81) * i.mv::numeric / nullif(sum(i.mv) over(),0)) as kesir
    from oyun.iller i
  ), q1 as (
    select q0.*, sum(taban) over() as kullanilan from q0
  ), q2 as (
    select q1.*, row_number() over(order by kesir desc,id) as sira,
      p_toplam-kullanilan as kalan from q1
  )
  update oyun.iller i
     set mv_secim=(q2.taban + case when q2.sira<=q2.kalan then 1 else 0 end)::smallint
  from q2 where q2.id=i.id;
end $$;

select oyun.dagit_mv_sandalye(coalesce((select round(deger)::int from oyun.anayasa where kod='milletvekili_sayisi'),600));

create table if not exists oyun.hukumetler(
  id bigserial primary key,
  kuran_parti bigint not null references oyun.partiler(id),
  basbakan uuid references oyun.profiller(id),
  tur text,
  durum text not null default 'davet' check (durum in ('davet','guvenoyunda','gorevde','basarisiz','dustu')),
  teklif_at timestamptz not null,
  guvenoy_bas timestamptz,
  guvenoy_bit timestamptz,
  bas timestamptz,
  bit timestamptz,
  bitis_neden text
);
create index if not exists hukumetler_durum_idx on oyun.hukumetler(durum,teklif_at desc);

create table if not exists oyun.hukumet_partileri(
  hukumet_id bigint not null references oyun.hukumetler(id) on delete cascade,
  parti_id bigint not null references oyun.partiler(id),
  rol text not null check (rol in ('ortak','destek')),
  kabul boolean,
  aktif boolean not null default true,
  zaman timestamptz,
  primary key(hukumet_id,parti_id)
);

create table if not exists oyun.hukumet_guven_oylari(
  hukumet_id bigint not null references oyun.hukumetler(id) on delete cascade,
  vekil uuid not null references oyun.profiller(id),
  oy text not null check (oy in ('kabul','ret','cekimser')),
  zaman timestamptz not null,
  primary key(hukumet_id,vekil)
);

create table if not exists oyun.gensorular(
  id bigserial primary key,
  hukumet_id bigint not null references oyun.hukumetler(id),
  teklif_eden uuid not null references oyun.profiller(id),
  parti_id bigint references oyun.partiler(id),
  gerekce text not null,
  bas timestamptz not null,
  bit timestamptz not null,
  durum text not null default 'oylamada' check (durum in ('oylamada','kabul','ret'))
);
create table if not exists oyun.gensoru_oylari(
  gensoru_id bigint not null references oyun.gensorular(id) on delete cascade,
  vekil uuid not null references oyun.profiller(id),
  oy text not null check (oy in ('kabul','ret','cekimser')),
  zaman timestamptz not null,
  primary key(gensoru_id,vekil)
);

create table if not exists oyun.erken_secim_teklifleri(
  id bigserial primary key,
  teklif_eden uuid not null references oyun.profiller(id),
  parti_id bigint not null references oyun.partiler(id),
  tur text not null check (tur in ('iktidar_karari','muhalefet_cagrisi')),
  gerekce text not null,
  bas timestamptz not null,
  bit timestamptz not null,
  durum text not null default 'oylamada' check (durum in ('oylamada','kabul','ret')),
  secim_donem text
);
create table if not exists oyun.erken_secim_oylari(
  teklif_id bigint not null references oyun.erken_secim_teklifleri(id) on delete cascade,
  vekil uuid not null references oyun.profiller(id),
  oy text not null check (oy in ('kabul','ret','cekimser')),
  zaman timestamptz not null,
  primary key(teklif_id,vekil)
);

create or replace function oyun.aktif_hukumet_id() returns bigint
language sql stable set search_path='' as $$
  select id from oyun.hukumetler where durum='gorevde' and bit is null order by bas desc nulls last,id desc limit 1
$$;

create or replace function oyun.aktif_vekil_sayi() returns int
language sql stable set search_path='' as $$
  select count(*)::int from oyun.makamlar where tur='mv' and bit is null
$$;

create or replace function oyun.salt_cogunluk() returns int
language sql stable set search_path='' as $$
  select greatest(1,floor(oyun.aktif_vekil_sayi()/2.0)::int+1)
$$;

create or replace function oyun.erken_secim_gerekli_oy() returns int
language sql stable set search_path='' as $$
  select greatest(1,ceil(oyun.aktif_vekil_sayi()
    * coalesce((select deger from oyun.anayasa where kod='erken_secim_esigi'),60)/100.0)::int)
$$;

create or replace function oyun.yurutme_user() returns uuid
language sql stable set search_path='' as $$
  select case when oyun.hukumet_sistemi()=1
    then (select basbakan from oyun.hukumetler where durum='gorevde' and bit is null order by bas desc limit 1)
    else (select user_id from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1)
  end
$$;

create or replace function oyun.yurutme_unvan() returns text
language sql stable set search_path='' as $$
  select case when oyun.hukumet_sistemi()=1 then 'Başbakan' else 'Cumhurbaşkanı' end
$$;

create or replace function oyun.unvan(u uuid) returns text
language sql stable set search_path='' as $body$
  select coalesce(
    (select 'Başbakan' from oyun.hukumetler h where h.basbakan=u and h.durum='gorevde' and h.bit is null limit 1),
    (select 'Cumhurbaşkanı' from oyun.makamlar where user_id=u and tur='cb' and bit is null limit 1),
    (select replace(b.ad,'Bakanlığı','Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod=m.bakanlik
       where m.user_id=u and m.tur='bakan' and m.bit is null limit 1),
    (select pa.kisa||' Genel Başkanı' from oyun.partiler pa where pa.gb=u and not pa.kapali limit 1),
    (select i.ad||' Milletvekili' from oyun.makamlar m join oyun.iller i on i.id=m.il_id where m.user_id=u and m.tur='mv' and m.bit is null limit 1),
    (select i.ad||' Belediye Başkanı' from oyun.makamlar m join oyun.iller i on i.id=m.il_id where m.user_id=u and m.tur='bel' and m.bit is null limit 1),
    (select pa.kisa||' Genel Başkan Yardımcısı' from oyun.parti_gby g join oyun.partiler pa on pa.id=g.parti_id where g.user_id=u limit 1)
  )
$body$;

create or replace function oyun.meclis_yazabilir(u uuid) returns boolean
language sql stable set search_path='' as $body$
  select exists(select 1 from oyun.makamlar where user_id=u and bit is null and tur in ('mv','cb','bakan'))
      or exists(select 1 from oyun.hukumetler where basbakan=u and durum='gorevde' and bit is null)
$body$;

create or replace function oyun.cb_zorunlu(p oyun.profiller) returns void
language plpgsql set search_path='' as $$
begin
  if oyun.yurutme_user() is distinct from p.id then
    raise exception 'Bu yetki yalnızca yürütme görevini üstlenen % tarafından kullanılabilir.', oyun.yurutme_unvan();
  end if;
end $$;

create or replace function oyun.bakanlik_vekili(p_user uuid,p_bakanlik text) returns boolean
language sql stable set search_path='' as $$
  select oyun.yurutme_user()=p_user
     and not exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik=p_bakanlik and bit is null)
$$;

create or replace function oyun.hukumet_kapat(p_id bigint,t timestamptz,p_neden text) returns void
language plpgsql set search_path='' as $$
declare m record;
begin
  update oyun.hukumetler set durum='dustu',bit=t,bitis_neden=p_neden
   where id=p_id and durum='gorevde' and bit is null;
  if found then
    for m in select id from oyun.makamlar where tur='bakan' and bit is null loop
      perform oyun.makam_bitir(m.id,t,'hukumet_dustu');
    end loop;
    perform oyun.olay('hukumet',format('Hükümet düştü: %s. Yeni hükümet kurma görüşmeleri başladı.',p_neden),null,null,t);
  end if;
end $$;

create or replace function oyun.hukumet_guvenoyu_baslat(p_id bigint,t timestamptz) returns void
language plpgsql set search_path='' as $$
begin
  if exists(select 1 from oyun.hukumet_partileri where hukumet_id=p_id and kabul is distinct from true) then return; end if;
  update oyun.hukumetler set durum='guvenoyunda',guvenoy_bas=t,guvenoy_bit=t+interval '12 hours'
   where id=p_id and durum='davet';
  if found then perform oyun.olay('hukumet','Yeni hükümet güvenoyu için TBMM''ye sunuldu.',null,null,t); end if;
end $$;

create or replace function oyun.hukumet_guvenoyu_sonuc(p_id bigint,t timestamptz) returns void
language plpgsql set search_path='' as $$
declare h oyun.hukumetler; evet int; hayir int; gerek int; pm uuid; ortak int; ortak_mv int;
begin
  select * into h from oyun.hukumetler where id=p_id for update;
  if h.id is null or h.durum<>'guvenoyunda' then return; end if;
  select count(*) filter(where oy='kabul'),count(*) filter(where oy='ret')
    into evet,hayir from oyun.hukumet_guven_oylari where hukumet_id=p_id;
  gerek:=oyun.salt_cogunluk();
  if evet>=gerek then
    select gb into pm from oyun.partiler where id=h.kuran_parti and not kapali;
    if pm is null then
      update oyun.hukumetler set durum='basarisiz',bit=t,bitis_neden='Kurucu partinin genel başkanı yok' where id=p_id;
      return;
    end if;
    select count(*) into ortak from oyun.hukumet_partileri where hukumet_id=p_id and rol='ortak' and aktif;
    select count(*) into ortak_mv from oyun.makamlar m
      where m.tur='mv' and m.bit is null and m.parti_id in
        (select parti_id from oyun.hukumet_partileri where hukumet_id=p_id and rol='ortak' and aktif);
    update oyun.hukumetler set durum='gorevde',basbakan=pm,bas=t,
      tur=case when ortak>1 then 'koalisyon'
               when ortak_mv>=gerek then 'tek_parti' else 'azinlik' end
      where id=p_id;
    perform oyun.bildir(pm,'Hükümet güvenoyu aldı. Başbakan olarak göreve başladın; kabineni kurabilirsin.',t);
    perform oyun.olay('hukumet',format('%s güvenoyu ile Başbakan oldu (%s kabul, %s ret).',oyun.kad(pm),evet,hayir),null,h.kuran_parti,t);
  elsif t>=h.guvenoy_bit then
    update oyun.hukumetler set durum='basarisiz',bit=t,bitis_neden='Güvenoyu alınamadı' where id=p_id;
    perform oyun.olay('hukumet',format('Hükümet güvenoyu alamadı (%s kabul, %s ret; gerekli %s). Yeni görüşmeler başlayabilir.',evet,hayir,gerek),null,h.kuran_parti,t);
  end if;
end $$;

create or replace function public.hukumet_teklif(p_ortaklar bigint[] default '{}'::bigint[],p_destek bigint[] default '{}'::bigint[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pid bigint; hid bigint; x bigint;
begin
  if oyun.hukumet_sistemi()<>1 then raise exception 'Hükümet kurma görüşmeleri yalnızca parlamenter sistemde yapılır.'; end if;
  select id into pid from oyun.partiler where gb=p.id and not kapali limit 1;
  if pid is null then raise exception 'Hükümet kurma teklifi için bir partinin genel başkanı olmalısın.'; end if;
  if oyun.aktif_hukumet_id() is not null then raise exception 'Görevde bir hükümet var.'; end if;
  if exists(select 1 from oyun.hukumetler where durum in ('davet','guvenoyunda')) then raise exception 'Sonuçlanmamış bir hükümet kurma girişimi var.'; end if;
  if pid=any(coalesce(p_ortaklar,'{}'::bigint[])) or pid=any(coalesce(p_destek,'{}'::bigint[])) then raise exception 'Kendi partini ortak veya dış destek listesine ekleme.'; end if;
  if exists(select 1 from unnest(coalesce(p_ortaklar,'{}'::bigint[])) a(id) join unnest(coalesce(p_destek,'{}'::bigint[])) b(id) using(id)) then raise exception 'Bir parti aynı anda hem koalisyon ortağı hem dış destekçi olamaz.'; end if;
  foreach x in array coalesce(p_ortaklar,'{}'::bigint[]) loop
    if not exists(select 1 from oyun.partiler where id=x and not kapali and gb is not null) then raise exception 'Koalisyon ortağı olarak seçilen parti uygun değil.'; end if;
  end loop;
  foreach x in array coalesce(p_destek,'{}'::bigint[]) loop
    if not exists(select 1 from oyun.partiler where id=x and not kapali and gb is not null) then raise exception 'Dış destek için seçilen parti uygun değil.'; end if;
  end loop;
  insert into oyun.hukumetler(kuran_parti,teklif_at) values(pid,t) returning id into hid;
  insert into oyun.hukumet_partileri(hukumet_id,parti_id,rol,kabul,zaman) values(hid,pid,'ortak',true,t);
  insert into oyun.hukumet_partileri(hukumet_id,parti_id,rol,kabul)
    select hid,id,'ortak',null from unnest(coalesce(p_ortaklar,'{}'::bigint[])) u(id) on conflict do nothing;
  insert into oyun.hukumet_partileri(hukumet_id,parti_id,rol,kabul)
    select hid,id,'destek',null from unnest(coalesce(p_destek,'{}'::bigint[])) u(id) on conflict do nothing;
  insert into oyun.bildirimler(user_id,zaman,metin)
    select pa.gb,t,format('%s seni yeni hükümete %s olarak davet etti.',p.kad,case when hp.rol='ortak' then 'koalisyon ortağı' else 'dışarıdan destekçi' end)
    from oyun.hukumet_partileri hp join oyun.partiler pa on pa.id=hp.parti_id
    where hp.hukumet_id=hid and hp.parti_id<>pid and pa.gb is not null;
  perform oyun.hukumet_guvenoyu_baslat(hid,t);
  return public.siyasi_sistem();
end $$;

create or replace function public.hukumet_teklif_yanit(p_hukumet bigint,p_kabul boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pid bigint; h oyun.hukumetler;
begin
  select id into pid from oyun.partiler where gb=p.id and not kapali limit 1;
  if pid is null then raise exception 'Bu yanıtı yalnızca parti genel başkanı verebilir.'; end if;
  select * into h from oyun.hukumetler where id=p_hukumet for update;
  if h.id is null or h.durum<>'davet' then raise exception 'Bu hükümet teklifi artık açık değil.'; end if;
  if not exists(select 1 from oyun.hukumet_partileri where hukumet_id=h.id and parti_id=pid and kabul is null) then raise exception 'Partine bekleyen bir davet yok.'; end if;
  update oyun.hukumet_partileri set kabul=p_kabul,zaman=t where hukumet_id=h.id and parti_id=pid;
  if not p_kabul then
    update oyun.hukumetler set durum='basarisiz',bit=t,bitis_neden='Davet reddedildi' where id=h.id;
    perform oyun.olay('hukumet',format('%s hükümet kurma teklifini reddetti.',(select kisa from oyun.partiler where id=pid)),null,pid,t);
  else
    perform oyun.hukumet_guvenoyu_baslat(h.id,t);
  end if;
  return public.siyasi_sistem();
end $$;

create or replace function public.hukumet_guven_oy(p_hukumet bigint,p_oy text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); h oyun.hukumetler;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='mv' and bit is null) then raise exception 'Güvenoyunda yalnız milletvekilleri oy kullanabilir.'; end if;
  select * into h from oyun.hukumetler where id=p_hukumet;
  if h.id is null or h.durum<>'guvenoyunda' or t<h.guvenoy_bas or t>=h.guvenoy_bit then raise exception 'Güvenoyu şu anda açık değil.'; end if;
  insert into oyun.hukumet_guven_oylari(hukumet_id,vekil,oy,zaman) values(h.id,p.id,p_oy,t)
  on conflict(hukumet_id,vekil) do update set oy=excluded.oy,zaman=excluded.zaman;
  perform oyun.hukumet_guvenoyu_sonuc(h.id,t);
  return public.siyasi_sistem();
end $$;

create or replace function public.hukumet_destek_cek() returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pid bigint; hid bigint; r text;
begin
  select id into pid from oyun.partiler where gb=p.id and not kapali limit 1;
  if pid is null then raise exception 'Bu işlemi yalnızca parti genel başkanı yapabilir.'; end if;
  hid:=oyun.aktif_hukumet_id();
  select rol into r from oyun.hukumet_partileri where hukumet_id=hid and parti_id=pid and aktif;
  if r is null then raise exception 'Partin görevdeki hükümete bağlı değil.'; end if;
  update oyun.hukumet_partileri set aktif=false,zaman=t where hukumet_id=hid and parti_id=pid;
  if r='ortak' then
    perform oyun.hukumet_kapat(hid,t,format('%s koalisyondan çekildi',(select kisa from oyun.partiler where id=pid)));
  else
    perform oyun.olay('hukumet',format('%s azınlık hükümetine verdiği dış desteği çekti.',(select kisa from oyun.partiler where id=pid)),null,pid,t);
  end if;
  return public.siyasi_sistem();
end $$;

create or replace function public.gensoru_ver(p_gerekce text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); hid bigint:=oyun.aktif_hukumet_id(); g text;
begin
  if oyun.hukumet_sistemi()<>1 then raise exception 'Gensoru yalnız parlamenter sistemde kullanılabilir.'; end if;
  if hid is null then raise exception 'Görevde hükümet yok.'; end if;
  if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='mv' and bit is null) then raise exception 'Gensoru önergesini yalnız milletvekili verebilir.'; end if;
  if exists(select 1 from oyun.gensorular where durum='oylamada') then raise exception 'Zaten oylamada bir gensoru var.'; end if;
  g:=oyun.metin_temizle(coalesce(p_gerekce,''),1000);
  if length(btrim(g))<10 then raise exception 'Gensoru gerekçesi en az 10 karakter olmalı.'; end if;
  insert into oyun.gensorular(hukumet_id,teklif_eden,parti_id,gerekce,bas,bit) values(hid,p.id,p.parti_id,g,t,t+interval '12 hours');
  perform oyun.olay('hukumet',format('%s hükümet hakkında gensoru verdi. Oylama başladı.',p.kad),null,p.parti_id,t);
  return public.siyasi_sistem();
end $$;

create or replace function oyun.gensoru_sonuc(p_id bigint,t timestamptz) returns void
language plpgsql set search_path='' as $$
declare g oyun.gensorular; evet int; hayir int; gerek int;
begin
  select * into g from oyun.gensorular where id=p_id for update;
  if g.id is null or g.durum<>'oylamada' then return; end if;
  select count(*) filter(where oy='kabul'),count(*) filter(where oy='ret') into evet,hayir from oyun.gensoru_oylari where gensoru_id=p_id;
  gerek:=oyun.salt_cogunluk();
  if evet>=gerek then
    update oyun.gensorular set durum='kabul' where id=p_id;
    perform oyun.hukumet_kapat(g.hukumet_id,t,format('Gensoru kabul edildi (%s kabul, %s ret)',evet,hayir));
  elsif t>=g.bit then
    update oyun.gensorular set durum='ret' where id=p_id;
    perform oyun.olay('hukumet',format('Gensoru reddedildi (%s kabul, %s ret; hükümeti düşürmek için %s gerekliydi).',evet,hayir,gerek),null,g.parti_id,t);
  end if;
end $$;

create or replace function public.gensoru_oy(p_id bigint,p_oy text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); g oyun.gensorular;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='mv' and bit is null) then raise exception 'Gensoruda yalnız milletvekilleri oy kullanabilir.'; end if;
  select * into g from oyun.gensorular where id=p_id;
  if g.id is null or g.durum<>'oylamada' or t<g.bas or t>=g.bit then raise exception 'Gensoru oylaması açık değil.'; end if;
  insert into oyun.gensoru_oylari(gensoru_id,vekil,oy,zaman) values(g.id,p.id,p_oy,t)
  on conflict(gensoru_id,vekil) do update set oy=excluded.oy,zaman=excluded.zaman;
  perform oyun.gensoru_sonuc(g.id,t);
  return public.siyasi_sistem();
end $$;

create or replace function oyun.erken_genel_secim_olustur(t timestamptz,p_teklif bigint) returns text
language plpgsql set search_path='' as $$
declare ilk date; ongun date; secgun date; dm text; eski text;
begin
  ilk:=(t at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(ilk,8)<t+interval '8 hours' then ilk:=ilk+1; end if;
  ongun:=ilk; secgun:=ilk+1;
  dm:='erken-genel-'||p_teklif||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
  select donem into eski from oyun.secimler where tur='mv' and not ara and durum='bekliyor' and oy_bas>t order by oy_bas limit 1;
  if eski is not null then
    update oyun.secimler set durum='tamam',sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','erken_secim')
    where donem=eski and durum='bekliyor' and tur in ('mv_on','mv','cb_on','cb','cb2');
  end if;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
   ('mv_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,17),oyun.tr_an(ongun,18),null,true,'erken_secim'),
   ('mv',dm,null,null,oyun.tr_an(secgun,8),oyun.tr_an(secgun,17),oyun.tr_an(secgun,18),oyun.tr_an(secgun+1,0),true,'erken_secim');
  if oyun.hukumet_sistemi()=0 then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
     ('cb_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,17),oyun.tr_an(ongun,18),null,true,'erken_secim'),
     ('cb',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(secgun,8),oyun.tr_an(secgun,17),oyun.tr_an(secgun,18),oyun.tr_an(secgun+1,0),true,'erken_secim');
  end if;
  perform oyun.olay('secim',format('TBMM erken seçim kararı aldı. Erken genel seçim %s günü yapılacak.',to_char(secgun,'DD.MM.YYYY')),null,null,t);
  return dm;
end $$;

create or replace function public.erken_secim_teklif(p_gerekce text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pid bigint; iktidar boolean:=false; g text;
begin
  select id into pid from oyun.partiler where gb=p.id and not kapali limit 1;
  if pid is null then raise exception 'Erken seçim kararı/çağrısını yalnızca parti genel başkanı başlatabilir.'; end if;
  if oyun.aktif_vekil_sayi()=0 then raise exception 'Görevde TBMM yok.'; end if;
  if exists(select 1 from oyun.erken_secim_teklifleri where durum='oylamada') then raise exception 'Zaten Meclis gündeminde bir erken seçim önerisi var.'; end if;
  if exists(select 1 from oyun.secimler where ara and ara_neden='erken_secim' and durum='bekliyor') then raise exception 'Erken seçim takvimi zaten açık.'; end if;
  if oyun.hukumet_sistemi()=0 then
    iktidar:=exists(select 1 from oyun.makamlar where tur='cb' and bit is null and parti_id=pid);
  else
    iktidar:=exists(select 1 from oyun.hukumet_partileri hp join oyun.hukumetler h on h.id=hp.hukumet_id
      where h.durum='gorevde' and h.bit is null and hp.parti_id=pid and hp.rol='ortak' and hp.aktif);
  end if;
  g:=oyun.metin_temizle(coalesce(p_gerekce,''),1000);
  if length(btrim(g))<5 then g:='Ülkenin erken seçime gitmesi önerilmektedir.'; end if;
  insert into oyun.erken_secim_teklifleri(teklif_eden,parti_id,tur,gerekce,bas,bit)
  values(p.id,pid,case when iktidar then 'iktidar_karari' else 'muhalefet_cagrisi' end,g,t,t+interval '12 hours');
  perform oyun.olay('secim',format('%s %s başlattı; karar TBMM oylamasında.',p.kad,case when iktidar then 'erken seçim kararı' else 'erken seçim çağrısı' end),null,pid,t);
  return public.siyasi_sistem();
end $$;

create or replace function oyun.erken_secim_sonuc(p_id bigint,t timestamptz) returns void
language plpgsql set search_path='' as $$
declare x oyun.erken_secim_teklifleri; evet int; hayir int; gerek int; dm text;
begin
  select * into x from oyun.erken_secim_teklifleri where id=p_id for update;
  if x.id is null or x.durum<>'oylamada' then return; end if;
  select count(*) filter(where oy='kabul'),count(*) filter(where oy='ret') into evet,hayir from oyun.erken_secim_oylari where teklif_id=p_id;
  gerek:=oyun.erken_secim_gerekli_oy();
  if evet>=gerek then
    dm:=oyun.erken_genel_secim_olustur(t,p_id);
    update oyun.erken_secim_teklifleri set durum='kabul',secim_donem=dm where id=p_id;
  elsif t>=x.bit then
    update oyun.erken_secim_teklifleri set durum='ret' where id=p_id;
    perform oyun.olay('secim',format('Erken seçim önerisi reddedildi (%s kabul, %s ret; gerekli %s).',evet,hayir,gerek),null,x.parti_id,t);
  end if;
end $$;

create or replace function public.erken_secim_oy(p_id bigint,p_oy text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); x oyun.erken_secim_teklifleri;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='mv' and bit is null) then raise exception 'Erken seçim oylamasında yalnız milletvekilleri oy kullanabilir.'; end if;
  select * into x from oyun.erken_secim_teklifleri where id=p_id;
  if x.id is null or x.durum<>'oylamada' or t<x.bas or t>=x.bit then raise exception 'Erken seçim oylaması açık değil.'; end if;
  insert into oyun.erken_secim_oylari(teklif_id,vekil,oy,zaman) values(x.id,p.id,p_oy,t)
  on conflict(teklif_id,vekil) do update set oy=excluded.oy,zaman=excluded.zaman;
  perform oyun.erken_secim_sonuc(x.id,t);
  return public.siyasi_sistem();
end $$;

create or replace function oyun.siyasi_tick(t timestamptz) returns void
language plpgsql set search_path='' as $$
declare r record;
begin
  for r in select id from oyun.hukumetler where durum='guvenoyunda' and guvenoy_bit<=t loop perform oyun.hukumet_guvenoyu_sonuc(r.id,t); end loop;
  for r in select id from oyun.gensorular where durum='oylamada' and bit<=t loop perform oyun.gensoru_sonuc(r.id,t); end loop;
  for r in select id from oyun.erken_secim_teklifleri where durum='oylamada' and bit<=t loop perform oyun.erken_secim_sonuc(r.id,t); end loop;
end $$;

create or replace function oyun.hukumet_secim_sonrasi_tg() returns trigger
language plpgsql set search_path='' as $$
declare hid bigint;
begin
  if new.tur='mv' and old.durum='sonuclandi' and new.durum='tamam' and oyun.hukumet_sistemi()=1 then
    hid:=oyun.aktif_hukumet_id();
    if hid is not null then perform oyun.hukumet_kapat(hid,coalesce(new.goreve_bas,oyun.simdi()),'Yeni TBMM göreve başladı'); end if;
    update oyun.hukumetler set durum='basarisiz',bit=coalesce(new.goreve_bas,oyun.simdi()),bitis_neden='Yeni TBMM göreve başladı' where durum in ('davet','guvenoyunda');
    perform oyun.olay('hukumet','Yeni TBMM göreve başladı. Hükümet kurma görüşmeleri açıldı.',null,null,coalesce(new.goreve_bas,oyun.simdi()));
  end if;
  return new;
end $$;
drop trigger if exists hukumet_secim_sonrasi on oyun.secimler;
create trigger hukumet_secim_sonrasi after update of durum on oyun.secimler
for each row when (new.tur='mv' and old.durum is distinct from new.durum)
execute function oyun.hukumet_secim_sonrasi_tg();

create or replace function oyun.teskilat_engeli(p oyun.profiller,p_tur text) returns text
language sql stable set search_path='' as $$
  select case
    when p_tur='mv_on' and (select teskilat_zorunlu from oyun.ayarlar where id=1) and p.parti_id is not null
      and not exists(select 1 from oyun.parti_teskilat where parti_id=p.parti_id)
      then 'Partinin genel seçime katılabilmesi için Türkiye''de en az bir il teşkilatı açması gerekir.'
    when p_tur='bel_on' and (select teskilat_zorunlu from oyun.ayarlar where id=1) and p.parti_id is not null and not oyun.teskilat_var(p.parti_id,p.il_id)
      then format('Partinin %s belediye başkanı adayı gösterebilmesi için bu ilde teşkilat açması gerekir.',(select ad from oyun.iller where id=p.il_id))
  end
$$;

create or replace function oyun._sonuc_mv(s oyun.secimler) returns jsonb
language plpgsql set search_path='' as $$
declare
  baraj numeric:=(select baraj from oyun.ayarlar where id=1);
  onsecim oyun.secimler; toplam bigint; il record; pids bigint[]; oys bigint[]; kaz int[]; lim int[];
  i int; k int; en int; enq numeric; q numeric; iller_j jsonb:='{}'::jsonb; ilj jsonb; bos int:=0; dolu int:=0; sandalye_top int;
begin
  select * into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;
  select count(*) into toplam from oyun.oylar where secim_id=s.id;
  sandalye_top:=coalesce((select sum(mv_secim) from oyun.iller),600);
  create temp table if not exists _ulusal(parti_id bigint primary key,oy bigint,yuzde numeric,gecti boolean,sandalye int default 0) on commit drop;
  delete from _ulusal;
  insert into _ulusal(parti_id,oy) select parti_id,count(*) from oyun.oylar where secim_id=s.id group by parti_id;
  update _ulusal set yuzde=case when toplam>0 then round(oy*100.0/toplam,2) else 0 end;
  update _ulusal u set gecti=(u.yuzde>=baraj) or coalesce((
    select sum(u2.oy)*100.0/nullif(toplam,0)>=baraj
    from oyun.ittifak_uyeler iu join oyun.ittifak_uyeler iu2 on iu2.ittifak_id=iu.ittifak_id
    join _ulusal u2 on u2.parti_id=iu2.parti_id where iu.parti_id=u.parti_id),false);
  create temp table if not exists _kaz(user_id uuid,il_id smallint,parti_id bigint) on commit drop;
  delete from _kaz;
  for il in select * from oyun.iller order by id loop
    select array_agg(x.parti_id order by x.oy desc,x.parti_id),array_agg(x.oy order by x.oy desc,x.parti_id),array_agg(x.lim order by x.oy desc,x.parti_id)
    into pids,oys,lim
    from (
      select o.parti_id,count(*) oy,(select count(*) from oyun.adaylar a where a.secim_id=onsecim.id and a.il_id=il.id and a.parti_id=o.parti_id and a.sira is not null)::int lim
      from oyun.oylar o join _ulusal u on u.parti_id=o.parti_id and u.gecti
      where o.secim_id=s.id and o.il_id=il.id group by o.parti_id
    ) x where x.lim>0;
    kaz:=array_fill(0,array[coalesce(array_length(pids,1),0)]);
    if pids is not null then
      for k in 1..coalesce(il.mv_secim,il.mv) loop
        en:=null; enq:=-1;
        for i in 1..array_length(pids,1) loop
          if kaz[i]<lim[i] then q:=oys[i]::numeric/(kaz[i]+1); if q>enq then enq:=q; en:=i; end if; end if;
        end loop;
        exit when en is null; kaz[en]:=kaz[en]+1;
      end loop;
      for i in 1..array_length(pids,1) loop
        if kaz[i]>0 then
          insert into _kaz select a.user_id,il.id,pids[i] from oyun.adaylar a
          where a.secim_id=onsecim.id and a.il_id=il.id and a.parti_id=pids[i] and a.sira is not null order by a.sira limit kaz[i];
          update _ulusal set sandalye=sandalye+kaz[i] where parti_id=pids[i];
        end if;
      end loop;
    end if;
    select jsonb_build_object('gecerli',(select count(*) from oyun.oylar where secim_id=s.id and il_id=il.id),
      'partiler',coalesce((select jsonb_object_agg(o.parti_id::text,jsonb_build_object('oy',o.n,'sandalye',(select count(*) from _kaz z where z.il_id=il.id and z.parti_id=o.parti_id)))
        from (select parti_id,count(*) n from oyun.oylar where secim_id=s.id and il_id=il.id group by parti_id)o),'{}'::jsonb),
      'secilen',coalesce((select jsonb_agg(jsonb_build_object('kad',pr.kad,'parti_id',z.parti_id)) from _kaz z join oyun.profiller pr on pr.id=z.user_id where z.il_id=il.id),'[]'::jsonb),
      'mv',coalesce(il.mv_secim,il.mv)) into ilj;
    if (ilj->>'gecerli')::int>0 or jsonb_array_length(ilj->'secilen')>0 then iller_j:=iller_j||jsonb_build_object(il.id::text,ilj); end if;
  end loop;
  insert into oyun.kazananlar(secim_id,user_id,il_id,parti_id) select s.id,user_id,il_id,parti_id from _kaz on conflict do nothing;
  select count(*) into dolu from _kaz; bos:=sandalye_top-dolu;
  perform oyun.olay('secim',format('Genel seçim sonuçlandı: %s oy kullanıldı, %s sandalye doldu, %s sandalye boş kaldı.',toplam,dolu,bos),null,null,s.sonuc_at);
  return jsonb_build_object('toplam',toplam,'baraj',baraj,'sandalye_toplam',sandalye_top,'dolu',dolu,'bos',bos,
    'ulusal',coalesce((select jsonb_agg(jsonb_build_object('parti_id',u.parti_id,'kisa',p.kisa,'ad',p.ad,'renk',p.renk,'oy',u.oy,'yuzde',u.yuzde,'gecti',u.gecti,'sandalye',u.sandalye) order by u.oy desc)
      from _ulusal u join oyun.partiler p on p.id=u.parti_id),'[]'::jsonb),'iller',iller_j);
end $$;

create or replace function oyun.cb_secim_gerekli(p_oy_gun timestamptz) returns boolean
language plpgsql stable set search_path='' as $$
declare b timestamptz; ay int:=coalesce((select round(deger)::int from oyun.anayasa where kod='cb_gorev_suresi'),1);
begin
  if oyun.hukumet_sistemi()=1 then return false; end if;
  select bas into b from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1;
  if b is null then return true; end if;
  return p_oy_gun>=b+make_interval(months=>ay);
end $$;

create or replace function oyun.donem_olustur(p_ay date) returns void
language plpgsql set search_path='' as $$
declare m date:=date_trunc('month',p_ay)::date; n date:=(date_trunc('month',p_ay)+interval '1 month')::date;
  dm text:=to_char(m,'YYYY-MM'); dn text:=to_char(n,'YYYY-MM'); b timestamptz:=(select baslangic from oyun.ayarlar where id=1);
begin
  if oyun.tr_an(m+5,0)>=b then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
      ('bel_on',dm,oyun.tr_an(m+5,0),oyun.tr_an(m+6,0),oyun.tr_an(m+7,8),oyun.tr_an(m+7,17),oyun.tr_an(m+7,18),null),
      ('bel',dm,null,null,oyun.tr_an(m+9,8),oyun.tr_an(m+9,17),oyun.tr_an(m+9,18),oyun.tr_an(m+10,0))
    on conflict(tur,donem) do nothing;
  end if;
  if oyun.tr_an(m+14,0)>=b then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
      ('kurultay',dm,oyun.tr_an(m+14,0),oyun.tr_an(m+17,0),oyun.tr_an(m+17,8),oyun.tr_an(m+17,17),oyun.tr_an(m+17,18),oyun.tr_an(m+18,0))
    on conflict(tur,donem) do nothing;
  end if;
  if oyun.tr_an(m+25,0)>=b then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
      ('mv_on',dn,oyun.tr_an(m+25,0),oyun.tr_an(m+26,0),oyun.tr_an(m+27,8),oyun.tr_an(m+27,17),oyun.tr_an(m+27,18),null),
      ('mv',dn,null,null,oyun.tr_an(n,8),oyun.tr_an(n,17),oyun.tr_an(n,18),oyun.tr_an(n+1,0))
    on conflict(tur,donem) do nothing;
    if oyun.cb_secim_gerekli(oyun.tr_an(n,8)) then
      insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas) values
        ('cb',dn,oyun.tr_an(m+18,0),oyun.tr_an(m+25,0),oyun.tr_an(n,8),oyun.tr_an(n,17),oyun.tr_an(n,18),oyun.tr_an(n+1,0)),
        ('cb_on',dn,oyun.tr_an(m+25,0),oyun.tr_an(m+26,0),oyun.tr_an(m+27,8),oyun.tr_an(m+27,17),oyun.tr_an(m+27,18),null)
      on conflict(tur,donem) do nothing;
    end if;
  end if;
end $$;

create or replace function oyun.anayasa_dogrula(p_veri jsonb) returns jsonb
language plpgsql stable set search_path='' as $$
declare m text:=p_veri->>'madde'; a oyun.anayasa; v numeric;
begin
  if m='duzenleme' then
    v:=oyun.duzenleme_dogrula(p_veri->>'kod',(p_veri->>'deger')::numeric,'ulke');
    return jsonb_build_object('madde',m,'kod',p_veri->>'kod','deger',v);
  elsif m='serbest_birak' then
    if not exists(select 1 from oyun.duzenlemeler where kod=p_veri->>'kod' and kaynak='anayasa') then raise exception 'Bu kural zaten anayasada değil.'; end if;
    return jsonb_build_object('madde',m,'kod',p_veri->>'kod');
  elsif m in ('kararname_sinir','vergi_tavani','hukumet_sistemi','secim_baraji','cb_gorev_suresi','milletvekili_sayisi','yerel_yetki','erken_secim_esigi') then
    select * into a from oyun.anayasa where kod=m;
    if a.kod is null then raise exception 'Anayasa maddesi bulunamadı.'; end if;
    v:=(p_veri->>'deger')::numeric;
    if m in ('kararname_sinir','vergi_tavani','hukumet_sistemi','cb_gorev_suresi','milletvekili_sayisi','yerel_yetki','erken_secim_esigi') then v:=round(v); else v:=round(v,1); end if;
    if v is null or v<a.min or v>a.max then raise exception '"%" % ile % arasında olmalı.',a.ad,a.min,a.max; end if;
    if v=a.deger then raise exception 'Bu madde zaten bu değerde.'; end if;
    return jsonb_build_object('madde',m,'deger',v);
  end if;
  raise exception 'Geçersiz anayasa maddesi.';
end $$;

create or replace function oyun.anayasa_aciklama(v jsonb) returns text
language sql stable set search_path='' as $$
  select case v->>'madde'
    when 'duzenleme' then format('%s: %s olarak anayasaya bağlanır. Bundan sonra kanunla ya da kararnameyle değiştirilemez.',(select ad from oyun.duzenleme_tanim where kod=v->>'kod'),oyun.duz_yaz(v->>'kod',(v->>'deger')::numeric))
    when 'serbest_birak' then format('%s anayasadan çıkarılır; Meclis yeniden kanunla düzenleyebilir.',(select ad from oyun.duzenleme_tanim where kod=v->>'kod'))
    when 'kararname_sinir' then case when (v->>'deger')::numeric=0 then 'Cumhurbaşkanının kararname yetkisi kaldırılır.' else format('Cumhurbaşkanı günde en fazla %s kararname çıkarabilir.',v->>'deger') end
    when 'vergi_tavani' then format('Gelir vergisinin anayasal tavanı %%%s olur.',v->>'deger')
    when 'hukumet_sistemi' then case when (v->>'deger')::int=1 then 'Türkiye parlamenter sisteme geçer; yürütme güvenoyu alan Başbakan ve kabineye geçer.' else 'Türkiye Cumhurbaşkanlığı hükümet sistemine geçer.' end
    when 'secim_baraji' then format('Genel seçim ülke barajı %%%s olur; ittifak toplamı barajı aşarsa ittifak partileri barajı geçmiş sayılır.',v->>'deger')
    when 'cb_gorev_suresi' then format('Cumhurbaşkanı görev süresi %s ay olur.',v->>'deger')
    when 'milletvekili_sayisi' then format('TBMM %s milletvekilinden oluşur.',v->>'deger')
    when 'yerel_yetki' then format('Yerel yönetimlerin düzenleme yetkisi %%%s genişlikte olur.',v->>'deger')
    when 'erken_secim_esigi' then format('Erken seçim kararı için aktif milletvekillerinin %%%s kabul oyu gerekir.',v->>'deger')
  end
$$;

create or replace function oyun.anayasa_uygula(k oyun.kanunlar,t timestamptz) returns void
language plpgsql set search_path='' as $$
declare v jsonb:=k.veri; m text:=k.veri->>'madde'; tv numeric; hid bigint; x record;
begin
  if m='duzenleme' then
    perform oyun.duzenleme_uygula(v->>'kod',(v->>'deger')::numeric,'anayasa',k.id,t);
  elsif m='serbest_birak' then
    update oyun.duzenlemeler set kaynak='kanun',ref_id=k.id,zaman=t where kod=v->>'kod' and kaynak='anayasa';
  elsif m in ('kararname_sinir','vergi_tavani','hukumet_sistemi','secim_baraji','cb_gorev_suresi','milletvekili_sayisi','yerel_yetki','erken_secim_esigi') then
    update oyun.anayasa set deger=(v->>'deger')::numeric,kanun_id=k.id,zaman=t where kod=m;
    if m='vergi_tavani' then
      tv:=(v->>'deger')::numeric;
      update oyun.ulke set vergi_ust=least(vergi_ust,tv),vergi_alt=least(vergi_alt,tv),vergi=least(vergi,tv),vergi_kanun=least(vergi_kanun,tv) where id=1;
    elsif m='secim_baraji' then
      if exists(select 1 from oyun.secimler o join oyun.secimler g on g.donem=o.donem and g.tur='mv' where o.tur='mv_on' and t>=o.basvuru_bas and g.durum='bekliyor') then update oyun.ulke set bekleyen_baraj=(v->>'deger')::numeric where id=1;
      else update oyun.ayarlar set baraj=(v->>'deger')::numeric where id=1; end if;
    elsif m='milletvekili_sayisi' then
      perform oyun.dagit_mv_sandalye((v->>'deger')::int);
    elsif m='hukumet_sistemi' then
      if (v->>'deger')::int=1 then
        update oyun.secimler set durum='tamam',sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','parlamenter_sistem')
          where tur in ('cb','cb_on','cb2') and durum='bekliyor' and not ara and oy_bas>t;
        for x in select id from oyun.makamlar where tur='bakan' and bit is null loop perform oyun.makam_bitir(x.id,t,'sistem_degisti'); end loop;
        perform oyun.olay('anayasa','Parlamenter sisteme geçildi. Hükümet kurma görüşmeleri başladı.',null,null,t);
      else
        hid:=oyun.aktif_hukumet_id();
        if hid is not null then perform oyun.hukumet_kapat(hid,t,'Cumhurbaşkanlığı sistemine geçildi'); end if;
        update oyun.hukumetler set durum='basarisiz',bit=t,bitis_neden='Sistem değişti' where durum in ('davet','guvenoyunda');
        update oyun.secimler set durum='bekliyor',sonuc=null
          where tur in ('cb','cb_on') and not ara and durum='tamam' and sonuc->>'iptal'='parlamenter_sistem' and oy_bas>t and oyun.cb_secim_gerekli(oy_bas);
        if not exists(select 1 from oyun.makamlar where tur='cb' and bit is null) then perform oyun.ara_secim_olustur('cb',null,null,t); end if;
        perform oyun.olay('anayasa','Cumhurbaşkanlığı hükümet sistemine geçildi.',null,null,t);
      end if;
    elsif m='cb_gorev_suresi' then
      update oyun.secimler set durum='tamam',sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','cb_gorev_suresi')
       where tur in ('cb','cb_on') and durum='bekliyor' and not ara and oy_bas>t and not oyun.cb_secim_gerekli(oy_bas);
    end if;
  end if;
end $$;

create or replace function oyun.il_kurallar_json(p_il smallint,t timestamptz) returns jsonb
language sql stable set search_path='' as $$
  select jsonb_agg(jsonb_build_object('kod',d.kod,'ad',d.ad,'birim',d.birim,'tur',d.tur,
    'min',greatest(d.min,d.varsayilan-(d.varsayilan-d.min)*coalesce(oyun.anayasa_deger('yerel_yetki'),100)/100.0),
    'max',least(d.max,d.varsayilan+(d.max-d.varsayilan)*coalesce(oyun.anayasa_deger('yerel_yetki'),100)/100.0),
    'adim',d.adim,'aciklama',d.aciklama,'oyuncu',d.oyuncu,'devlet',d.devlet,'deger',oyun.il_duz(p_il,d.kod),
    'yazi',oyun.duz_yaz(d.kod,oyun.il_duz(p_il,d.kod)),
    'hazir',(select z.zaman+interval '24 hours' from oyun.il_duzenleme z where z.il_id=p_il and z.kod=d.kod and z.zaman>t-interval '24 hours'),
    'gunluk_gelir',case when d.kod='emlak' then round(oyun.il_duz(p_il,'emlak')*(select endeks from oyun.ulke where id=1)*oyun.nufus('il_hane')*(select mv from oyun.iller where id=p_il)/600/1e9,4) end,
    'birim_maliyet',case when d.kod='hosgeldin' then round(oyun.il_duz(p_il,'hosgeldin')*2000/1e9,4) end) order by d.sira)
  from oyun.duzenleme_tanim d where d.kapsam='il'
$$;

create or replace function public.belediye_duzenle(p_kod text,p_deger numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); m oyun.makamlar:=oyun.baskan_zorunlu(p); v numeric; d oyun.duzenleme_tanim;
  son timestamptz; onceki numeric; ilad text; yetki numeric:=coalesce(oyun.anayasa_deger('yerel_yetki'),100); amin numeric; amax numeric;
begin
  v:=oyun.duzenleme_dogrula(p_kod,p_deger,'il'); select * into d from oyun.duzenleme_tanim where kod=p_kod;
  amin:=greatest(d.min,d.varsayilan-(d.varsayilan-d.min)*yetki/100.0); amax:=least(d.max,d.varsayilan+(d.max-d.varsayilan)*yetki/100.0);
  if v<amin or v>amax then raise exception 'Anayasanın yerel yönetim yetkisi sınırı nedeniyle "%" şu an % ile % arasında değiştirilebilir.',d.ad,round(amin,2),round(amax,2); end if;
  select zaman,deger into son,onceki from oyun.il_duzenleme where il_id=m.il_id and kod=p_kod;
  if coalesce(onceki,d.varsayilan)=v then raise exception 'Değişiklik yok.'; end if;
  if son is not null and son>t-interval '24 hours' then raise exception '"%" 24 saatte bir değiştirilebilir (sonraki: %).',d.ad,to_char((son+interval '24 hours') at time zone 'Europe/Istanbul','DD.MM HH24:MI'); end if;
  insert into oyun.il_duzenleme(il_id,kod,deger,baskan,zaman) values(m.il_id,p_kod,v,p.id,t)
  on conflict(il_id,kod) do update set deger=excluded.deger,baskan=excluded.baskan,zaman=excluded.zaman;
  select ad into ilad from oyun.iller where id=m.il_id;
  perform oyun.gazete_ekle('belediye',format('%s Belediye Meclisi kararı: %s %s',ilad,d.ad,oyun.duz_yaz(p_kod,v)),d.oyuncu,null,t);
  perform oyun.olay('belediye',format('%s Belediye Başkanı %s: %s %s → %s.',ilad,p.kad,d.ad,oyun.duz_yaz(p_kod,coalesce(onceki,d.varsayilan)),oyun.duz_yaz(p_kod,v)),m.il_id,p.parti_id,t);
  insert into oyun.bildirimler(user_id,zaman,metin) select x.id,t,format('%s Belediyesi: %s artık %s. %s',ilad,d.ad,oyun.duz_yaz(p_kod,v),d.oyuncu)
    from oyun.profiller x where x.il_id=m.il_id and x.id<>p.id and not x.yasakli;
  return public.belediye_paneli();
end $$;

create or replace function public.kabine() returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); hid bigint:=oyun.aktif_hukumet_id();
begin
  return jsonb_build_object(
    'sistem',case when oyun.hukumet_sistemi()=1 then 'parlamenter' else 'cumhurbaskanligi' end,
    'yurutme_benim',oyun.yurutme_user()=p.id,
    'basbakan',(select jsonb_build_object('kad',oyun.kad(h.basbakan),'parti',oyun.parti_json(h.kuran_parti),'bas',h.bas,'tur',h.tur) from oyun.hukumetler h where h.id=hid),
    'hukumet_id',hid,
    'cb',(select jsonb_build_object('kad',oyun.kad(m.user_id),'parti',oyun.parti_json(m.parti_id),'bas',m.bas) from oyun.makamlar m where m.tur='cb' and m.bit is null order by m.bas desc limit 1),
    'bakanlar',(select jsonb_agg(jsonb_build_object('kod',b.kod,'ad',b.ad,'kad',oyun.kad(m.user_id),'parti',oyun.parti_json((select parti_id from oyun.profiller where id=m.user_id)),'bas',m.bas) order by b.sira)
      from oyun.bakanliklar b left join oyun.makamlar m on m.bakanlik=b.kod and m.tur='bakan' and m.bit is null)
  );
end $$;

create or replace function public.bakan_ata(p_bakanlik text,p_kad text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); h oyun.profiller; b oyun.bakanliklar; m record; uv text:=oyun.yurutme_unvan();
begin
  perform oyun.cb_zorunlu(p); select * into b from oyun.bakanliklar where kod=p_bakanlik;
  if b.kod is null then raise exception 'Bakanlık bulunamadı.'; end if;
  h:=oyun.profil_bul(p_kad); if h.id=p.id then raise exception '% kendini bakan atayamaz.',uv; end if;
  if oyun.uyari(h,t) is not null then raise exception 'Atanacak kişi için: %',oyun.uyari(h,t); end if;
  if exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik=b.kod and bit is null and user_id=h.id) then raise exception '% zaten bu bakanlıkta.',h.kad; end if;
  if oyun.rol_cakisma(h.id,'bakan') is not null then raise exception '% şu anda % görevinde. Bakan atanabilmesi için önce o görevden ayrılması gerekir.',h.kad,oyun.rol_cakisma(h.id,'bakan'); end if;
  for m in select id from oyun.makamlar where tur='bakan' and bakanlik=b.kod and bit is null loop perform oyun.makam_bitir(m.id,t,'gorevden_alindi'); end loop;
  insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,kaynak,bas) values('bakan',h.id,null,h.parti_id,b.kod,'atama',t);
  perform oyun.bildir(h.id,format('%s %s seni %s olarak atadı.',uv,p.kad,replace(b.ad,'Bakanlığı','Bakanı')),t);
  perform oyun.olay('makam',format('%s, %s olarak atandı.',h.kad,replace(b.ad,'Bakanlığı','Bakanı')),null,h.parti_id,t);
  perform oyun.gazete_ekle('atama',format('%s''na %s atandı',b.ad,h.kad),format('%s %s tarafından %s olarak atanmıştır.',uv,p.kad,replace(b.ad,'Bakanlığı','Bakanı')),null,t);
  return public.kabine();
end $$;

create or replace function public.vekalet_paneli() returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
begin
  if oyun.yurutme_user() is distinct from p.id then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(oyun.bakanlik_panel_json(b.kod,t) order by b.sira) from oyun.bakanliklar b
    where not exists(select 1 from oyun.makamlar m where m.tur='bakan' and m.bakanlik=b.kod and m.bit is null)),'[]'::jsonb);
end $$;

create or replace function public.politika_ayarla(p_kod text,p_deger numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); d record; s record; eski numeric; yeni numeric; son timestamptz; mk text; unvan text; bas text; pe jsonb;
begin
  select * into d from oyun.politika_tanim() x where x.kod=p_kod; if d.kod is null then raise exception 'Geçersiz politika.'; end if;
  if oyun.yurutme_user()=p.id then mk:=case when oyun.hukumet_sistemi()=1 then 'basbakan' else 'cb' end; unvan:=oyun.yurutme_unvan();
  elsif exists(select 1 from oyun.makamlar where user_id=p.id and tur='bakan' and bakanlik=d.bakanlik and bit is null) then mk:='bakan'; unvan:=(select replace(ad,'Bakanlığı','Bakanı') from oyun.bakanliklar where kod=d.bakanlik);
  else raise exception 'Bu ayarı yalnızca yürütme başkanı ve ilgili bakan yapabilir.'; end if;
  select * into s from oyun.politika_sinir(p_kod); eski:=oyun.politika_deger(p_kod); yeni:=case when d.birim in ('tl_ay','tl_gun') then round(p_deger) else round(p_deger,1) end;
  if yeni is null or yeni=eski then raise exception 'Yeni değer mevcut değerle aynı.'; end if;
  if yeni<s.alt or yeni>s.ust then raise exception '% şu an % ile % arasında ayarlanabilir.',d.ad,oyun.birim_yaz(s.alt,d.birim),oyun.birim_yaz(s.ust,d.birim); end if;
  select max(zaman) into son from oyun.politika_kayit where kod=p_kod;
  if son is not null and son+make_interval(days=>d.bekleme_gun)>t then raise exception '% en erken % tarihinde yeniden değiştirilebilir.',d.ad,to_char((son+make_interval(days=>d.bekleme_gun)) at time zone 'Europe/Istanbul','DD.MM HH24:MI'); end if;
  pe:=oyun.politika_etki(p_kod,yeni); execute format('update oyun.ulke set %I=$1 where id=1',p_kod) using yeni;
  if p_kod='vergi' then perform oyun.etki_uygula(jsonb_build_object('enflasyon',coalesce((pe->>'enflasyon')::numeric,0),'buyume',coalesce((pe->>'buyume')::numeric,0),'issizlik',coalesce((pe->>'issizlik')::numeric,0),'memnuniyet',coalesce((pe->>'memnuniyet')::numeric,0)),null); end if;
  insert into oyun.politika_kayit(kod,eski,yeni,user_id,makam,zaman) values(p_kod,eski,yeni,p.id,mk,t);
  bas:=format('%s: %s → %s',d.ad,oyun.birim_yaz(eski,d.birim),oyun.birim_yaz(yeni,d.birim));
  perform oyun.gazete_ekle(case when mk in ('cb','basbakan') then 'kararname' else 'icraat' end,bas,format('%s %s tarafından belirlendi.',unvan,p.kad),null,t);
  perform oyun.olay('ekonomi',format('%s %s: %s',unvan,p.kad,bas),null,p.parti_id,t);
  return jsonb_build_object('tamam',true,'kod',p_kod,'eski',eski,'yeni',yeni,'etki',pe);
end $$;

create or replace function public.bos_makamlar() returns jsonb
language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi(); cb text:=(select oyun.kad(user_id) from oyun.makamlar where tur='cb' and bit is null limit 1);
  mv int; toplam int:=coalesce((select sum(mv_secim) from oyun.iller),600);
begin
  select count(*) into mv from oyun.makamlar where tur='mv' and bit is null;
  return jsonb_build_object('cb',cb,
    'bakanliklar',coalesce((select jsonb_agg(jsonb_build_object('kod',b.kod,'ad',b.ad) order by b.sira) from oyun.bakanliklar b where not exists(select 1 from oyun.makamlar m where m.tur='bakan' and m.bakanlik=b.kod and m.bit is null)),'[]'::jsonb),
    'belediyeler',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad) order by i.ad) from oyun.iller i where not exists(select 1 from oyun.makamlar m where m.tur='bel' and m.il_id=i.id and m.bit is null)),'[]'::jsonb),
    'vekil',jsonb_build_object('dolu',mv,'bos',greatest(0,toplam-mv),'toplam',toplam),
    'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',pa.id,'kisa',pa.kisa)) from oyun.partiler pa where not pa.kapali and pa.gb is null and exists(select 1 from oyun.profiller where parti_id=pa.id)),'[]'::jsonb),
    'sonraki',coalesce((select jsonb_agg(jsonb_build_object('tur',x.tur,'basvuru_bas',x.basvuru_bas,'basvuru_bit',x.basvuru_bit,'oy_bas',x.oy_bas) order by x.oy_bas)
      from (select distinct on(tur) tur,basvuru_bas,basvuru_bit,oy_bas from oyun.secimler where durum='bekliyor' and tur in ('bel','mv','cb','kurultay') and oy_bit>t order by tur,oy_bas)x),'[]'::jsonb));
end $$;

create or replace function public.siyasi_sistem() returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); hid bigint:=oyun.aktif_hukumet_id(); kur bigint; g bigint; er bigint;
begin
  select id into kur from oyun.hukumetler where durum in ('davet','guvenoyunda') order by teklif_at desc limit 1;
  select id into g from oyun.gensorular where durum='oylamada' order by bas desc limit 1;
  select id into er from oyun.erken_secim_teklifleri where durum='oylamada' order by bas desc limit 1;
  return jsonb_build_object(
    'sistem',case when oyun.hukumet_sistemi()=1 then 'parlamenter' else 'cumhurbaskanligi' end,
    'anayasa',coalesce((select jsonb_agg(jsonb_build_object('kod',a.kod,'ad',a.ad,'deger',a.deger,'min',a.min,'max',a.max,'aciklama',a.aciklama) order by
      case a.kod when 'hukumet_sistemi' then 1 when 'milletvekili_sayisi' then 2 when 'secim_baraji' then 3 when 'cb_gorev_suresi' then 4 when 'yerel_yetki' then 5 when 'erken_secim_esigi' then 6 else 20 end,a.kod) from oyun.anayasa a),'[]'::jsonb),
    'meclis',jsonb_build_object('dolu',oyun.aktif_vekil_sayi(),'toplam',coalesce((select sum(mv_secim) from oyun.iller),600),'salt',oyun.salt_cogunluk(),'erken_secim_gerekli',oyun.erken_secim_gerekli_oy()),
    'ben',jsonb_build_object('vekil_mi',exists(select 1 from oyun.makamlar where user_id=p.id and tur='mv' and bit is null),'gb_mi',exists(select 1 from oyun.partiler where gb=p.id and not kapali),'parti_id',p.parti_id,'yurutme_mi',oyun.yurutme_user()=p.id),
    'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',pa.id,'ad',pa.ad,'kisa',pa.kisa,'renk',pa.renk,'gb',oyun.kad(pa.gb),'vekil',(select count(*) from oyun.makamlar m where m.tur='mv' and m.bit is null and m.parti_id=pa.id))
      order by (select count(*) from oyun.makamlar m where m.tur='mv' and m.bit is null and m.parti_id=pa.id) desc,pa.id) from oyun.partiler pa where not pa.kapali),'[]'::jsonb),
    'hukumet',case when hid is null then null else (select jsonb_build_object('id',h.id,'tur',h.tur,'basbakan',oyun.kad(h.basbakan),'parti',oyun.parti_json(h.kuran_parti),'bas',h.bas,
      'partiler',coalesce((select jsonb_agg(jsonb_build_object('parti',oyun.parti_json(hp.parti_id),'rol',hp.rol,'aktif',hp.aktif)) from oyun.hukumet_partileri hp where hp.hukumet_id=h.id and hp.aktif),'[]'::jsonb),
      'benim_rol',(select hp.rol from oyun.hukumet_partileri hp where hp.hukumet_id=h.id and hp.parti_id=p.parti_id and hp.aktif)) from oyun.hukumetler h where h.id=hid) end,
    'kurulus',case when kur is null then null else (select jsonb_build_object('id',h.id,'durum',h.durum,'kuran_parti',oyun.parti_json(h.kuran_parti),'teklif_at',h.teklif_at,'oy_bit',h.guvenoy_bit,'gerekli',oyun.salt_cogunluk(),
      'oylar',jsonb_build_object('kabul',(select count(*) from oyun.hukumet_guven_oylari where hukumet_id=h.id and oy='kabul'),'ret',(select count(*) from oyun.hukumet_guven_oylari where hukumet_id=h.id and oy='ret'),'cekimser',(select count(*) from oyun.hukumet_guven_oylari where hukumet_id=h.id and oy='cekimser')),
      'benim_oy',(select oy from oyun.hukumet_guven_oylari where hukumet_id=h.id and vekil=p.id),
      'partiler',coalesce((select jsonb_agg(jsonb_build_object('parti',oyun.parti_json(hp.parti_id),'rol',hp.rol,'kabul',hp.kabul)) from oyun.hukumet_partileri hp where hp.hukumet_id=h.id),'[]'::jsonb),
      'benim_davet',(select jsonb_build_object('rol',hp.rol,'kabul',hp.kabul) from oyun.hukumet_partileri hp join oyun.partiler pa on pa.id=hp.parti_id where hp.hukumet_id=h.id and pa.gb=p.id and hp.kabul is null)) from oyun.hukumetler h where h.id=kur) end,
    'gensoru',case when g is null then null else (select jsonb_build_object('id',x.id,'gerekce',x.gerekce,'teklif_eden',oyun.kad(x.teklif_eden),'bas',x.bas,'bit',x.bit,'gerekli',oyun.salt_cogunluk(),
      'kabul',(select count(*) from oyun.gensoru_oylari where gensoru_id=x.id and oy='kabul'),'ret',(select count(*) from oyun.gensoru_oylari where gensoru_id=x.id and oy='ret'),'benim_oy',(select oy from oyun.gensoru_oylari where gensoru_id=x.id and vekil=p.id)) from oyun.gensorular x where x.id=g) end,
    'erken_secim',case when er is null then null else (select jsonb_build_object('id',x.id,'tur',x.tur,'gerekce',x.gerekce,'teklif_eden',oyun.kad(x.teklif_eden),'parti',oyun.parti_json(x.parti_id),'bas',x.bas,'bit',x.bit,'gerekli',oyun.erken_secim_gerekli_oy(),
      'kabul',(select count(*) from oyun.erken_secim_oylari where teklif_id=x.id and oy='kabul'),'ret',(select count(*) from oyun.erken_secim_oylari where teklif_id=x.id and oy='ret'),'benim_oy',(select oy from oyun.erken_secim_oylari where teklif_id=x.id and vekil=p.id)) from oyun.erken_secim_teklifleri x where x.id=er) end
  );
end $$;

create or replace function oyun.tick() returns integer
language plpgsql set search_path='oyun','public','pg_temp' as $$
declare t timestamptz:=oyun.simdi(); ay date; r record; n int:=0;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay:=date_trunc('month',t at time zone 'Europe/Istanbul')::date;
  perform oyun.donem_olustur(ay); perform oyun.donem_olustur((ay+interval '1 month')::date);
  if (select son_temizlik from oyun.ayarlar where id=1) is distinct from (t at time zone 'Europe/Istanbul')::date then
    delete from oyun.mesajlar where zaman<t-interval '30 days'; delete from oyun.yayinlar where zaman<t-interval '30 days'; delete from oyun.bildirimler where zaman<t-interval '60 days';
    delete from oyun.ozel where zaman<t-interval '90 days'; delete from oyun.push_kuyruk where olusturma<now()-interval '7 days';
    update oyun.ayarlar set son_temizlik=(t at time zone 'Europe/Istanbul')::date where id=1;
  end if;
  loop
    select * into r from (
      select id,sonuc_at as zaman,0 as asama,oyun.oncelik(tur)o from oyun.secimler where durum='bekliyor' and sonuc_at<=t
      union all select id,goreve_bas,1,oyun.oncelik(tur) from oyun.secimler where durum='sonuclandi' and goreve_bas<=t
    )x order by zaman,asama,o limit 1;
    exit when not found;
    if r.asama=0 then perform oyun.sonuclandir(r.id); else perform oyun.goreve_baslat(r.id); end if;
    n:=n+1; exit when n>200;
  end loop;
  perform oyun.kanun_tick(t); perform oyun.mevzuat_tick(t); perform oyun.meclis_tick(t); perform oyun.parti_tuzuk_tick(t); perform oyun.siyasi_tick(t);
  perform oyun.guvenlik_tick(t); perform oyun.gunluk_ekonomi(t); perform oyun.banka_tick(t); perform oyun.push_hatirlatmalar(t); perform oyun.push_tetikle();
  return n;
end $$;
