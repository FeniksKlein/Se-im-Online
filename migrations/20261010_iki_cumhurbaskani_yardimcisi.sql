
-- Cumhurbaşkanlığı için tam iki bağımsız yardımcı makamı (1 ve 2).
-- Mevcut cumhurbaşkanı, bakan, milletvekili ve seçim kayıtlarına dokunmaz.
alter table oyun.makamlar drop constraint if exists makamlar_tur_check;
alter table oyun.makamlar add constraint makamlar_tur_check
 check (tur = any (array['mv','bel','cb','bakan','tbmm','bskv','grup_bskv','cb_yardimcisi']));
create unique index if not exists makamlar_cb_yardimcisi_slot_tek
 on oyun.makamlar (bakanlik) where tur='cb_yardimcisi' and bit is null;
create unique index if not exists makamlar_cb_yardimcisi_oyuncu_tek
 on oyun.makamlar (user_id) where tur='cb_yardimcisi' and bit is null;
alter table oyun.makamlar drop constraint if exists makamlar_cb_yardimcisi_slot_check;
alter table oyun.makamlar add constraint makamlar_cb_yardimcisi_slot_check
 check (tur<>'cb_yardimcisi' or bakanlik in ('1','2'));

create table if not exists oyun.cb_yardimcisi_teklifleri (
 id bigint generated always as identity primary key,
 sira smallint not null check (sira in (1,2)),
 teklif_eden uuid not null references oyun.profiller(id),
 aday uuid not null references oyun.profiller(id),
 durum text not null default 'bekliyor' check(durum in ('bekliyor','kabul','ret','iptal')),
 zaman timestamptz not null default now(),
 yanit_at timestamptz
);
create unique index if not exists cb_yardimcisi_bekleyen_aday
 on oyun.cb_yardimcisi_teklifleri(aday) where durum='bekliyor';
create unique index if not exists cb_yardimcisi_bekleyen_teklif
 on oyun.cb_yardimcisi_teklifleri(sira,aday) where durum='bekliyor';
alter table oyun.cb_yardimcisi_teklifleri enable row level security;
revoke all on oyun.cb_yardimcisi_teklifleri from public,anon,authenticated;

create or replace function oyun.cb_yardimcisi_yetkili(p oyun.profiller) returns void
language plpgsql stable set search_path='' as $fn$
begin
 if not exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.tur='cb' and m.bit is null)
 then raise exception 'Cumhurbaşkanı yardımcısını yalnız görevdeki cumhurbaşkanı atayabilir.'; end if;
end $fn$;

create or replace function public.cb_yardimcisi_ata(p_sira integer,p_kad text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; t timestamptz:=oyun.simdi(); tid bigint;
begin
 perform oyun.cb_yardimcisi_yetkili(p);
 if p_sira not in (1,2) or p_sira is null then raise exception 'Yalnız 1. veya 2. yardımcılık seçilebilir.'; end if;
 h:=oyun.profil_bul(p_kad);
 if h.yasakli then raise exception 'Yasaklı oyuncuya teklif gönderilemez.'; end if;
 if h.id=p.id then raise exception 'Cumhurbaşkanı kendisini yardımcı atayamaz.'; end if;
 if exists(select 1 from oyun.makamlar where tur='cb_yardimcisi' and user_id=h.id and bit is null)
 then raise exception 'Bu oyuncu zaten cumhurbaşkanı yardımcısı.'; end if;
 if exists(select 1 from oyun.cb_yardimcisi_teklifleri where aday=h.id and durum='bekliyor')
 then raise exception 'Bu oyuncunun bekleyen cumhurbaşkanı yardımcılığı teklifi var.'; end if;
 insert into oyun.cb_yardimcisi_teklifleri(sira,teklif_eden,aday,zaman)
 values(p_sira,p.id,h.id,t) returning id into tid;
 perform oyun.bildir(h.id,format('Cumhurbaşkanı %s sana %s. Cumhurbaşkanı Yardımcılığı teklif etti. Bildirimler bölümünden kabul veya ret verebilirsin. Mevcut görevlerin korunacak.',p.kad,p_sira),t);
 return jsonb_build_object('durum','bekliyor','teklif_id',tid,'sira',p_sira,'aday',h.kad);
end $fn$;

create or replace function public.cb_yardimcisi_tekliflerim()
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim();
begin
 return coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'sira',x.sira,'teklif_eden',oyun.kad(x.teklif_eden),'zaman',x.zaman) order by x.zaman desc)
 from oyun.cb_yardimcisi_teklifleri x
 where x.aday=p.id and x.durum='bekliyor'
 and x.teklif_eden = (select m.user_id from oyun.makamlar m where m.tur='cb' and m.bit is null order by m.bas desc limit 1)), '[]'::jsonb);
end $fn$;

create or replace function public.cb_yardimcisi_yanit(p_teklif bigint,p_kabul boolean)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); x oyun.cb_yardimcisi_teklifleri; m record; t timestamptz:=oyun.simdi(); mid bigint;
begin
 if p_kabul is null then raise exception 'Kabul veya ret seçmelisin.'; end if;
 select * into x from oyun.cb_yardimcisi_teklifleri where id=p_teklif;
 if x.id is null or x.aday<>p.id then raise exception 'Teklif sana ait değil.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('cb_yardimcisi'),x.sira);
 select * into x from oyun.cb_yardimcisi_teklifleri where id=p_teklif for update;
 if x.durum<>'bekliyor' then raise exception 'Teklif artık geçerli değil.'; end if;
 if not exists(select 1 from oyun.makamlar where user_id=x.teklif_eden and tur='cb' and bit is null)
 then raise exception 'Cumhurbaşkanı değiştiği için teklif geçersiz.'; end if;
 if not p_kabul then
  update oyun.cb_yardimcisi_teklifleri set durum='ret',yanit_at=t where id=x.id;
  perform oyun.bildir(x.teklif_eden,format('%s, %s. Cumhurbaşkanı Yardımcılığı teklifini reddetti.',p.kad,x.sira),t);
  return jsonb_build_object('durum','ret','sira',x.sira);
 end if;
 if p.yasakli then raise exception 'Yasaklı hesap görevi kabul edemez.'; end if;
 if exists(select 1 from oyun.makamlar where tur='cb_yardimcisi' and user_id=p.id and bit is null)
 then raise exception 'Zaten cumhurbaşkanı yardımcısısın.'; end if;
 for m in select id from oyun.makamlar where tur='cb_yardimcisi' and bakanlik=x.sira::text and bit is null loop
  perform oyun.makam_bitir(m.id,t,'gorevden_alindi');
 end loop;
 insert into oyun.makamlar(tur,user_id,il_id,parti_id,bakanlik,kaynak,bas)
 values('cb_yardimcisi',p.id,null,p.parti_id,x.sira::text,'atama',t) returning id into mid;
 update oyun.cb_yardimcisi_teklifleri set durum='kabul',yanit_at=t where id=x.id;
 update oyun.cb_yardimcisi_teklifleri set durum='iptal',yanit_at=t
 where durum='bekliyor' and (sira=x.sira or aday=p.id);
 perform oyun.bildir(x.teklif_eden,format('%s, %s. Cumhurbaşkanı Yardımcılığı teklifini kabul etti.',p.kad,x.sira),t);
 perform oyun.bildir(p.id,format('%s. Cumhurbaşkanı Yardımcılığı görevin başladı. Diğer görevlerin korunuyor.',x.sira),t);
 perform oyun.olay('makam',format('%s, %s. Cumhurbaşkanı Yardımcısı olarak atandı.',p.kad,x.sira),null,p.parti_id,t);
 return jsonb_build_object('durum','kabul','sira',x.sira,'makam_id',mid);
end $fn$;

create or replace function public.cb_yardimcisi_gorevden_al(p_sira integer)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar; t timestamptz:=oyun.simdi();
begin
 perform oyun.cb_yardimcisi_yetkili(p);
 if p_sira not in (1,2) or p_sira is null then raise exception 'Geçersiz yardımcılık.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('cb_yardimcisi'),p_sira);
 select * into m from oyun.makamlar where tur='cb_yardimcisi' and bakanlik=p_sira::text and bit is null for update;
 if m.id is null then raise exception 'Bu yardımcılık makamı zaten boş.'; end if;
 perform oyun.makam_bitir(m.id,t,'gorevden_alindi');
 perform oyun.olay('makam',format('%s. Cumhurbaşkanı Yardımcısı görevden alındı.',p_sira),null,p.parti_id,t);
 return jsonb_build_object('durum','gorevden_alindi','sira',p_sira);
end $fn$;

create or replace function public.cb_yardimcisi_istifa()
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar; t timestamptz:=oyun.simdi(); cb uuid;
begin
 select * into m from oyun.makamlar where tur='cb_yardimcisi' and user_id=p.id and bit is null for update;
 if m.id is null then raise exception 'Cumhurbaşkanı yardımcısı değilsin.'; end if;
 perform oyun.makam_bitir(m.id,t,'istifa');
 select user_id into cb from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1;
 if cb is not null then perform oyun.bildir(cb,format('%s, %s. Cumhurbaşkanı Yardımcılığından istifa etti.',p.kad,m.bakanlik),t); end if;
 perform oyun.olay('makam',format('%s, %s. Cumhurbaşkanı Yardımcılığından istifa etti.',p.kad,m.bakanlik),null,p.parti_id,t);
 return jsonb_build_object('durum','istifa','sira',m.bakanlik::int);
end $fn$;

create or replace function public.cb_yardimcilari()
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); cb_aktif boolean;
begin
 cb_aktif := exists(select 1 from oyun.makamlar where tur='cb' and user_id=p.id and bit is null);
 return jsonb_build_object(
  'cb_miyim', cb_aktif,
  'yardimcilar', (select jsonb_agg(jsonb_build_object('sira',s.sira,'kad',oyun.kad(m.user_id),'parti',oyun.parti_json(pr.parti_id),'bas',m.bas,'benim',m.user_id=p.id) order by s.sira)
  from (values(1),(2)) s(sira)
  left join oyun.makamlar m on m.tur='cb_yardimcisi' and m.bakanlik=s.sira::text and m.bit is null
  left join oyun.profiller pr on pr.id=m.user_id),
  'bekleyen', case when cb_aktif then coalesce((select jsonb_agg(jsonb_build_object('sira',x.sira,'aday',oyun.kad(x.aday)) order by x.sira)
  from oyun.cb_yardimcisi_teklifleri x where x.durum='bekliyor' and x.teklif_eden=p.id),'[]'::jsonb) else '[]'::jsonb end
 );
end $fn$;

create or replace function oyun.cb_yardimcisi_cb_degisti_tg()
returns trigger language plpgsql set search_path='' as $fn$
declare m record; t timestamptz:=coalesce(new.bit,oyun.simdi());
begin
 -- Yeni CB göreve geçtiğinde veya CB istifa ettiğinde eski yardımcıların yetkisi sona erer.
 for m in select id from oyun.makamlar where tur='cb_yardimcisi' and bit is null loop
  perform oyun.makam_bitir(m.id,t,'kabine_yenilendi');
 end loop;
 update oyun.cb_yardimcisi_teklifleri set durum='iptal',yanit_at=t where durum='bekliyor';
 return new;
end $fn$;
drop trigger if exists cb_yardimcisi_cb_degisti on oyun.makamlar;
create trigger cb_yardimcisi_cb_degisti
after update of bit on oyun.makamlar
for each row when (old.tur='cb' and old.bit is null and new.bit is not null)
execute function oyun.cb_yardimcisi_cb_degisti_tg();

create or replace function oyun.makam_ad(p_tur text,p_il smallint,p_bakanlik text)
returns text language sql stable set search_path='' as $fn$
 select case p_tur
 when 'mv' then (select ad from oyun.iller where id=p_il)||' milletvekilliği'
 when 'bel' then (select ad from oyun.iller where id=p_il)||' belediye başkanlığı'
 when 'cb' then 'cumhurbaşkanlığı'
 when 'cb_yardimcisi' then coalesce(p_bakanlik,'?')||'. Cumhurbaşkanı Yardımcılığı'
 when 'tbmm' then 'TBMM Başkanlığı'
 when 'bskv' then 'TBMM Başkanvekilliği'
 when 'grup_bskv' then 'grup başkanvekilliği'
 else coalesce((select ad from oyun.bakanliklar where kod=p_bakanlik),'bakanlık') end
$fn$;
create or replace function oyun.makam_maasi(p_tur text,p_il smallint)
returns numeric language sql stable set search_path='' as $fn$
 select (case p_tur when 'cb' then 354497 when 'cb_yardimcisi' then 330000
 when 'bakan' then 318009 when 'mv' then 310332
 when 'tbmm' then 60000 when 'bskv' then 30000 when 'grup_bskv' then 20000
 when 'bel' then (select case when mv>=14 then 317800 when mv>=8 then 267800 when mv>=4 then 198900 else 171400 end from oyun.iller where id=p_il)
 else 0 end)*(select endeks from oyun.ulke where id=1)
 *coalesce((select carpan from oyun.makam_ucret_ayar where tur=p_tur),1)
$fn$;

revoke execute on function public.cb_yardimcisi_ata(integer,text),
 public.cb_yardimcisi_tekliflerim(),
 public.cb_yardimcisi_yanit(bigint,boolean),
 public.cb_yardimcisi_gorevden_al(integer),
 public.cb_yardimcisi_istifa(),
 public.cb_yardimcilari()
 from public,anon;
grant execute on function public.cb_yardimcisi_ata(integer,text),
 public.cb_yardimcisi_tekliflerim(),
 public.cb_yardimcisi_yanit(bigint,boolean),
 public.cb_yardimcisi_gorevden_al(integer),
 public.cb_yardimcisi_istifa(),
 public.cb_yardimcilari()
 to authenticated;
