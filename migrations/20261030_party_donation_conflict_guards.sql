-- Deployed on production. Applies to donations recorded after installation.
-- Prevents direct donor/party leader author fees, owner withdrawals and association support.
-- Does not reconstruct historical donors or detect unrelated proxy accounts.
create table if not exists oyun.parti_kurum_bagis_guvenlik (
 id bigint generated always as identity primary key,
 parti_id bigint not null, hedef_tur text not null, hedef_id bigint not null,
 islemi_yapan uuid not null, genel_baskan uuid, tutar numeric not null,
 zaman timestamptz not null default now()
);
alter table oyun.parti_kurum_bagis_guvenlik enable row level security;
revoke all on oyun.parti_kurum_bagis_guvenlik from public,anon,authenticated;
create index if not exists parti_kurum_bagis_guvenlik_hedef on oyun.parti_kurum_bagis_guvenlik(hedef_tur,hedef_id);
DO $fix$
declare d text; a text; b text;
begin
d:=pg_get_functiondef('public.parti_finans_bagis(text,bigint,numeric)'::regprocedure);
a:='    hedef:=g.ad;';
b:=$patch$    if exists(select 1 from oyun.gazete_yazarlar y where y.gazete_id=g.id and y.user_id in (u,pa.gb) and y.ucret_yazi>0)
       or exists(select 1 from oyun.gazete_yazar_teklif y where y.gazete_id=g.id and y.user_id in (u,pa.gb) and y.ucret_yazi>0 and y.durum in ('bekliyor','kabul')) then
      raise exception 'Senin veya genel başkanın ücretli yazarlık ilişkisi bulunan gazeteye parti kasasından bağış yapılamaz.';
    end if;
    hedef:=g.ad;$patch$;
if position(a in d)=0 then raise exception 'Donation guard anchor missing'; end if;
d:=replace(d,a,b);
a:='  insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama)';
b:=$patch$  insert into oyun.parti_kurum_bagis_guvenlik(parti_id,hedef_tur,hedef_id,islemi_yapan,genel_baskan,tutar,zaman)
    values(pa.id,p_hedef_tur,p_hedef_id,u,pa.gb,tut,t);
  insert into oyun.parti_hareket(parti_id,zaman,tutar,tur,aciklama)$patch$;
if position(a in d)=0 then raise exception 'Donation audit anchor missing'; end if;
execute replace(d,a,b);
d:=pg_get_functiondef('public.gazete_yayinla(bigint,text,text,text,bigint)'::regprocedure);
a:='  if u > 0 then';
b:=$patch$  if u > 0 then
    if exists(select 1 from oyun.parti_kurum_bagis_guvenlik b where b.hedef_tur='gazete' and b.hedef_id=g.id and p.id in (b.islemi_yapan,b.genel_baskan)) then
      raise exception 'Parti kasasından bağış yönlendirdiğin gazeteden kişisel yazarlık ücreti alamazsın. Ücretsiz yayın için yazarlık ücretini sıfırlatmalısın.';
    end if;$patch$;
if position(a in d)=0 then raise exception 'Payment guard anchor missing'; end if;
execute replace(d,a,b);
end $fix$;
DO $fix$
declare d text; a text; b text;
begin
d:=pg_get_functiondef('public.gazete_para_cek(bigint,numeric)'::regprocedure);
a:='  if m < 100 then';
b:=$patch$  if exists(select 1 from oyun.parti_kurum_bagis_guvenlik b where b.hedef_tur='gazete' and b.hedef_id=g.id and p.id in (b.islemi_yapan,b.genel_baskan)) then
    raise exception 'Parti bağışı yönlendirdiğin gazetenin kasasından kişisel para çekemezsin.';
  end if;
  if m < 100 then$patch$;
if position(a in d)=0 then raise exception 'Missing withdrawal anchor'; end if;
execute replace(d,a,b);
d:=pg_get_functiondef('public.dernek_uye_destek_karar(bigint,boolean,text)'::regprocedure);
a:=' perform pg_advisory_xact_lock(hashtextextended(a.basvuran::text,651201));';
b:=$patch$ if exists(select 1 from oyun.parti_kurum_bagis_guvenlik b where b.hedef_tur='dernek' and b.hedef_id=d.id and a.basvuran in (b.islemi_yapan,b.genel_baskan)) then
  raise exception 'Parti kasasından bağış yönlendiren kişi veya genel başkan, o dernekten kişisel nakit destek alamaz.';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(a.basvuran::text,651201));$patch$;
if position(a in d)=0 then raise exception 'Missing support anchor'; end if;
execute replace(d,a,b);
end $fix$;