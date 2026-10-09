-- 2026-10-09 — Emlak il stoku, bölgesel fiyat/kira ve belediyeye haftalık emlak vergisi.
-- Eski tapular, borçlar, cüzdanlar ve meclis kayıtları korunur.
create table if not exists oyun.emlak_vergi_ulusal (
 id integer primary key check (id=1), oran numeric not null default .35 check (oran between .1 and 1.0), son timestamptz not null default now()
);
insert into oyun.emlak_vergi_ulusal(id,oran) values(1,.35) on conflict(id) do nothing;
create table if not exists oyun.emlak_vergi_il (
 il_id smallint primary key references oyun.iller(id), duzeltme numeric not null default 0 check (duzeltme between -1 and 1),
 son_ayar timestamptz
);
insert into oyun.emlak_vergi_il(il_id) select id from oyun.iller on conflict do nothing;
create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key, mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 user_id uuid not null references oyun.profiller(id), il_id smallint not null references oyun.iller(id),
 hafta_sayisi integer not null check (hafta_sayisi between 1 and 520),
 matrah numeric not null, oran numeric not null, vergi numeric not null,
 zaman timestamptz not null default now()
);
create index if not exists emlak_vergi_kayit_mulk on oyun.emlak_vergi_kayit(mulk_id,zaman desc);
alter table oyun.emlak_vergi_ulusal enable row level security;
alter table oyun.emlak_vergi_il enable row level security;
alter table oyun.emlak_vergi_kayit enable row level security;
revoke all on oyun.emlak_vergi_ulusal,oyun.emlak_vergi_il,oyun.emlak_vergi_kayit from public,anon,authenticated;

create or replace function oyun.emlak_oran(p_il smallint) returns numeric
language sql stable set search_path='' as $$
 select greatest(.05,least(1.5, (select oran from oyun.emlak_vergi_ulusal where id=1)
 + coalesce((select duzeltme from oyun.emlak_vergi_il where il_id=p_il),0)))
$$;
create or replace function oyun.emlak_stok(p_il smallint,p_tip text) returns integer
language sql stable set search_path='' as $$
 select case p_tip when 'daire' then 7+round(93*mv::numeric/96)::int
 when 'dukkan' then greatest(3,ceil((7+round(93*mv::numeric/96)::int)*.35)::int)
 when 'villa' then greatest(2,ceil((7+round(93*mv::numeric/96)::int)*.12)::int) end
 from oyun.iller where id=p_il
$$;
create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end)
   * (0.65 + least(i.mv,96)/96.0*1.45 + greatest(0,least(100,d.gelisim))/100.0*.25)/1000)*1000
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_kira(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round(oyun.emlak_fiyat(p_il,p_tip) * (0.018 + greatest(0,least(100,d.gelisim))/100*.012))
 from oyun.il_durum d where d.il_id=p_il
$$;
create or replace function public.emlak_il_rehberi() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',i.id,'il',i.ad,'gelisim',round(d.gelisim,1),'emlak_orani',oyun.emlak_oran(i.id),
 'daire',jsonb_build_object('stok',oyun.emlak_stok(i.id,'daire'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire'),
  'fiyat',oyun.emlak_fiyat(i.id,'daire'),'kira',oyun.emlak_kira(i.id,'daire')),
 'dukkan',jsonb_build_object('stok',oyun.emlak_stok(i.id,'dukkan'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan'),
  'fiyat',oyun.emlak_fiyat(i.id,'dukkan'),'kira',oyun.emlak_kira(i.id,'dukkan')),
 'villa',jsonb_build_object('stok',oyun.emlak_stok(i.id,'villa'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa'),
  'fiyat',oyun.emlak_fiyat(i.id,'villa'),'kira',oyun.emlak_kira(i.id,'villa'))
 ) order by i.mv desc,i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_il_rehberi() from public,anon;
grant execute on function public.emlak_il_rehberi() to authenticated;

create or replace function public.mulk_satin_al(p_tip text,p_il smallint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p oyun.profiller; fiyat numeric;kira numeric;
        t timestamptz:=oyun.simdi();yeni bigint; stok integer; kullanilan integer;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into p from oyun.profiller where id=u;
 if p.id is null or p.yasakli then raise exception 'Aktif oyuncu profili gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_il is null then raise exception 'Mülk türü veya il seçimi geçersiz.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Seçilen il bulunamadı.'; end if;
 -- Aynı ilde son evi almak için yarışan oyuncular arasında stok aşımı olmaz.
 perform pg_advisory_xact_lock(58191,p_il::int*10 + case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 stok:=oyun.emlak_stok(p_il,p_tip);
 select count(*) into kullanilan from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if kullanilan>=stok then raise exception '% ilinde % için satılabilir yeni mülk kalmadı (%/%). İstersen oyuncu ilanlarını incele.',
   (select ad from oyun.iller where id=p_il),p_tip,kullanilan,stok; end if;
 fiyat:=oyun.emlak_fiyat(p_il,p_tip);kira:=oyun.emlak_kira(p_il,p_tip);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-fiyat,'emlak',format('%s / %s yeni mülk',p_tip,(select ad from oyun.iller where id=p_il)),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,fiyat,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,fiyat,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
-- Eski tek parametreli API de il stoku ve fiyat sınırına tabi tutulur.
create or replace function public.mulk_satin_al(p_tip text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin return public.mulk_satin_al(p_tip,p.il_id); end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.emlak_belediye_oran_ayarla(p_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar:=oyun.baskan_zorunlu(p);
 t timestamptz:=oyun.simdi(); global numeric; old numeric;son timestamptz;
begin
 select son_ayar into son from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if son>t-interval '24 hours' then raise exception 'Emlak vergisi oranı 24 saatte bir değiştirilebilir.'; end if;
 if p_oran is null or p_oran<.1 or p_oran>1.5 then raise exception 'Haftalık emlak vergisi oranı %%0,1 ile %%1,5 arasında olmalı.'; end if;
 select oran into global from oyun.emlak_vergi_ulusal where id=1;
 if (p_oran-global) not between -1 and 1 then raise exception 'İldeki oran ulusal orandan en fazla 1 puan ayrılabilir.'; end if;
 old:=oyun.emlak_oran(m.il_id);
 update oyun.emlak_vergi_il set duzeltme=p_oran-global,son_ayar=t where il_id=m.il_id;
 perform oyun.olay('belediye',format('%s Belediye Başkanı haftalık emlak vergisini %%%s oranından %%%s oranına değiştirdi.',
 (select ad from oyun.iller where id=m.il_id),old,p_oran),m.il_id,p.parti_id,t);
 return jsonb_build_object('il_id',m.il_id,'oran',p_oran,'onceki',old);
end $$;
revoke all on function public.emlak_belediye_oran_ayarla(numeric) from public,anon;
grant execute on function public.emlak_belediye_oran_ayarla(numeric) to authenticated;

-- Milletvekillerinin olağan yasama sürecinde oylayacağı ulusal haftalık emlak vergisi teklifi.
create or replace function public.emlak_kanun_teklif(p_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();s record;idd bigint;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Emlak vergisi kanununu yalnızca milletvekilleri teklif edebilir.'; end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then
  raise exception 'Meclis Başkanı tarafsızlık gereği teklif veremez.'; end if;
 if p_oran is null or p_oran not between .1 and 1 then raise exception 'Ulusal haftalık vergi %%0,1–%%1 arasında olmalı.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
  raise exception 'Önce mevcut kanun teklifini sonuçlandırmalısın.'; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest','Haftalık Emlak Vergisi Düzenlemesi',
 format('Türkiye genelinde mülkler için haftalık emlak vergisi taban oranı %%%s olacaktır. Vergi mülkün bulunduğu il belediyesine gelir kaydedilir. Belediye başkanı il farkı belirleyebilir.',p_oran),
 jsonb_build_object('eylem','emlak_vergisi','oran',p_oran),p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama)
 returning id into idd;
 perform oyun.olay('meclis',format('%s haftalık emlak vergisini %%%s yapmayı Meclis''e teklif etti.',p.kad,p_oran),null,p.parti_id,t);
 return jsonb_build_object('id',idd,'oran',p_oran);
end $$;
revoke all on function public.emlak_kanun_teklif(numeric) from public,anon;
grant execute on function public.emlak_kanun_teklif(numeric) to authenticated;

create or replace function oyun.emlak_kanun_etki() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.durum='yururlukte' and old.durum is distinct from new.durum
    and new.tur='serbest' and new.veri->>'eylem'='emlak_vergisi' then
  update oyun.emlak_vergi_ulusal set oran=(new.veri->>'oran')::numeric,son=oyun.simdi() where id=1;
 end if;
 return new;
end $$;
drop trigger if exists emlak_kanun_uygula on oyun.kanunlar;
create trigger emlak_kanun_uygula after update of durum on oyun.kanunlar for each row
execute function oyun.emlak_kanun_etki();
