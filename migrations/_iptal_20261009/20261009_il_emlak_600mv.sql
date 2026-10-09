-- 2026-10-09: İl bazlı sınırlı gayrimenkul, haftalık belediye emlak vergisi, 600 koltuk.
-- Var olan mülk/para/vekil kayıtlarını silmez.
create table if not exists oyun.emlak_vergi_genel (
 id int primary key check(id=1), oran numeric not null default 0.30 check(oran between 0.10 and 2),
 guncelleme timestamptz not null default now()
);
insert into oyun.emlak_vergi_genel(id,oran) values(1,0.30) on conflict(id) do nothing;
create table if not exists oyun.emlak_vergi_il (
 il_id smallint primary key references oyun.iller(id),
 carpan numeric not null default 1 check(carpan between 0.5 and 1.5),
 son_degis timestamptz,
 baskan uuid references oyun.profiller(id)
);
alter table oyun.yatirim_mulkleri add column if not exists sonraki_vergi timestamptz;
alter table oyun.yatirim_mulkleri add column if not exists vergi_borcu numeric not null default 0;
alter table oyun.yatirim_mulkleri add column if not exists toplam_vergi numeric not null default 0;
update oyun.yatirim_mulkleri set sonraki_vergi=oyun.simdi()+interval '7 days' where sonraki_vergi is null;
alter table oyun.yatirim_mulkleri alter column sonraki_vergi set not null;
do $$declare t text;begin
 foreach t in array array['emlak_vergi_genel','emlak_vergi_il'] loop
  execute format('alter table oyun.%I enable row level security',t);
  execute format('revoke all on oyun.%I from public,anon,authenticated',t);
 end loop;
end$$;

-- İl MV ağırlığı nüfusun oyun içi vekilidir. Stok tür başına il genelinde sayılır.
create or replace function oyun.emlak_il_stok(p_il smallint,p_tip text)
returns int language sql stable set search_path='' as $$
 select case p_tip
  when 'daire' then greatest(8,least(100,round(8+92*(i.mv-1)::numeric/95)::int))
  when 'dukkan' then greatest(4,least(40,round(4+36*(i.mv-1)::numeric/95)::int))
  when 'villa' then greatest(2,least(20,round(2+18*(i.mv-1)::numeric/95)::int))
  end from oyun.iller i where i.id=p_il
$$;
create or replace function oyun.emlak_il_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end)
     * (0.7 + 1.3*(i.mv-1)::numeric/95)
     * greatest(0.7,least(1.4,1+(coalesce(d.gelisim,50)-50)::numeric/200)),0)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_vergi_orani(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select round(g.oran*coalesce(x.carpan,1),3)
 from oyun.emlak_vergi_genel g left join oyun.emlak_vergi_il x on x.il_id=p_il where g.id=1
$$;

create or replace function public.emlak_il_listesi()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'nufus_agirligi',i.mv,'gelisim',d.gelisim,
    'vergi_orani',oyun.emlak_vergi_orani(i.id),
    'mulkler',(select jsonb_agg(jsonb_build_object('tip',x.tip,'fiyat',oyun.emlak_il_fiyat(i.id,x.tip),
      'haftalik_kira',round(oyun.emlak_il_fiyat(i.id,x.tip)*0.025),
      'stok',oyun.emlak_il_stok(i.id,x.tip),
      'satilan',(select count(*) from oyun.yatirim_mulkleri y where y.il_id=i.id and y.tip=x.tip),
      'kalan',greatest(0,oyun.emlak_il_stok(i.id,x.tip)-
       (select count(*) from oyun.yatirim_mulkleri y where y.il_id=i.id and y.tip=x.tip)))
      order by x.sira) from (values ('daire',1),('dukkan',2),('villa',3)) x(tip,sira)))
  order by i.ad) from oyun.iller i left join oyun.il_durum d on d.il_id=i.id),'[]'::jsonb);
end $$;
revoke all on function public.emlak_il_listesi() from public,anon;
grant execute on function public.emlak_il_listesi() to authenticated;

-- Şehirde ikamet şartı yoktur. Aynı anda son kalan stokun iki kere satılmasını engelle.
create or replace function public.mulk_il_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); fiyat numeric; kira numeric; yeni bigint;
  adet int;stok int; iladi text;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oyuncu hesabın gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 select ad into iladi from oyun.iller where id=p_il;
 if iladi is null then raise exception 'Geçersiz il seçimi.'; end if;
 perform pg_advisory_xact_lock(97413,p_il::int*10+case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 stok:=oyun.emlak_il_stok(p_il,p_tip);
 select count(*) into adet from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if adet>=stok then raise exception '% ilinde bu mülk türünün satış kontenjanı dolu (%/%).',iladi,adet,stok; end if;
 fiyat:=oyun.emlak_il_fiyat(p_il,p_tip);
 kira:=round(fiyat*0.025,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-fiyat,'emlak',format('%s %s satın alındı',iladi,p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,sonraki_vergi)
 values(u,p_il,p_tip,fiyat,kira,t,t+interval '7 days',t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,fiyat,t,format('%s %s ilk satış',iladi,p_tip));
 return jsonb_build_object('mulk_id',yeni,'il',iladi,'fiyat',fiyat,'kira',kira,'stok_kalan',stok-adet-1);
end $$;
revoke all on function public.mulk_il_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_il_satin_al(text,smallint) to authenticated;
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 perform public.mulk_il_satin_al(p_tip,il);
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Önce haftalık kira ve sonra il belediyesine haftalık emlak vergisi; karşılanamayan borç silinmez.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m oyun.yatirim_mulkleri;n int;gross numeric;tax numeric;t timestamptz:=oyun.simdi();
  emlak_tax numeric; debt numeric; pay numeric; oran numeric; wallet numeric; m_il smallint;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and (sonraki_kira<=t or sonraki_vergi<=t or vergi_borcu>0)
   order by id for update loop
  if m.sonraki_kira<=t then
    n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
    gross:=round(m.haftalik_kira*n,2);
    tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
          and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
         then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
    perform oyun.para_islem(p_user,gross-tax,'kira',format('Mulk #%s: %s haftalik kira, vergi %s TL',m.id,n,tax),t,tax);
    if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
    update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
      toplam_kira=toplam_kira+gross-tax,kira_sayisi=kira_sayisi+n where id=m.id;
  end if;
  debt:=m.vergi_borcu;
  if m.sonraki_vergi<=t then
    n:=least(520,floor(extract(epoch from(t-m.sonraki_vergi))/604800)::int+1);
    oran:=oyun.emlak_vergi_orani(m.il_id);
    emlak_tax:=round(m.alis_bedeli*oran*n/100);
    debt:=debt+emlak_tax;
    update oyun.yatirim_mulkleri set sonraki_vergi=sonraki_vergi+n*interval '7 days',vergi_borcu=debt where id=m.id;
  end if;
  if debt>0 then
    select para into wallet from oyun.cuzdan where user_id=p_user for update;
    pay:=least(debt,greatest(0,floor(coalesce(wallet,0))));
    if pay>0 then
      perform oyun.para_islem(p_user,-pay,'emlak_vergi',format('Mulk #%s haftalik belediye emlak vergisi, il #%s',m.id,m.il_id),t,pay);
      update oyun.il_durum set kasa=kasa+pay/1000000000.0 where il_id=m.il_id;
      update oyun.yatirim_mulkleri set vergi_borcu=greatest(0,vergi_borcu-pay),toplam_vergi=toplam_vergi+pay where id=m.id;
    end if;
  end if;
 end loop;
end $$;

create or replace function public.emlak_vergi_belediye_ayar(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar:=oyun.baskan_zorunlu(p);
 prev timestamptz;t timestamptz:=oyun.simdi(); oran numeric;
begin
 if p_carpan is null or p_carpan<0.5 or p_carpan>1.5 or p_carpan<>round(p_carpan,2) then
  raise exception 'Belediye emlak vergisi çarpanı 0,50–1,50 arasında (0,01 adımlarla) olmalı.'; end if;
 select son_degis into prev from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if prev>t-interval '24 hours' then raise exception 'Emlak vergisi 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_vergi_il(il_id,carpan,son_degis,baskan)
 values(m.il_id,p_carpan,t,p.id)
 on conflict(il_id) do update set carpan=excluded.carpan,son_degis=t,baskan=p.id;
 oran:=oyun.emlak_vergi_orani(m.il_id);
 perform oyun.olay('belediye',format('%s belediye başkanı emlak vergisini haftalık %s%% yaptı.',(select ad from oyun.iller where id=m.il_id),oran),m.il_id,p.parti_id,t);
 return jsonb_build_object('il_id',m.il_id,'carpan',p_carpan,'oran',oran,'sonraki_degisim',t+interval '24 hours');
end $$;
revoke all on function public.emlak_vergi_belediye_ayar(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayar(numeric) to authenticated;

create or replace function public.emlak_vergi_durum()
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('genel',g.oran,
  'il_id',(select il_id from oyun.makamlar where tur='bel' and user_id=auth.uid() and bit is null limit 1),
  'il_carpan',coalesce((select x.carpan from oyun.emlak_vergi_il x where x.il_id=(
    select il_id from oyun.makamlar where tur='bel' and user_id=auth.uid() and bit is null limit 1)),1),
  'son_degis',(select x.son_degis from oyun.emlak_vergi_il x where x.il_id=(
    select il_id from oyun.makamlar where tur='bel' and user_id=auth.uid() and bit is null limit 1)))
 from oyun.emlak_vergi_genel g where g.id=1
$$;
revoke all on function public.emlak_vergi_durum() from public,anon;
grant execute on function public.emlak_vergi_durum() to authenticated;

create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();s record;bid bigint;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri kanun önerebilir.'; end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then
  raise exception 'Meclis Başkanı kanun teklif edemez.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
  raise exception 'Devam eden teklifin varken yeni kanun veremezsin.'; end if;
 if p_oran is null or p_oran<0.1 or p_oran>2 or p_oran<>round(p_oran,2) then raise exception 'Haftalık emlak vergisi %%0,10–%%2 olmalı.'; end if;
 p_baslik:=btrim(coalesce(p_baslik,''));p_metin:=oyun.metin_temizle(p_metin,3000);
 if length(p_baslik)<5 or length(p_baslik)>120 or length(p_metin)<10 then raise exception 'Kanun başlığı ve gerekçesi eksik.'; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',p_baslik,p_metin,jsonb_build_object('ozel_tur','emlak_vergisi','oran',p_oran),
 p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama) returning id into bid;
 perform oyun.olay('meclis',format('Haftalık emlak vergisi %% %s için kanun teklif edildi: %s',p_oran,p_baslik),null,p.parti_id,t);
 return jsonb_build_object('id',bid,'oran',p_oran);
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text,text) to authenticated;

create or replace function oyun.emlak_vergi_kanun_uygula()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.durum='yururlukte' and old.durum is distinct from new.durum
  and new.tur='serbest' and new.veri->>'ozel_tur'='emlak_vergisi' then
  update oyun.emlak_vergi_genel set oran=(new.veri->>'oran')::numeric,guncelleme=oyun.simdi() where id=1;
  perform oyun.olay('meclis',format('Meclis kanunuyla haftalık genel emlak vergisi %s%% oldu.',new.veri->>'oran'),null,new.teklif_parti,oyun.simdi());
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergisi_yururluk on oyun.kanunlar;
create trigger emlak_vergisi_yururluk after update of durum on oyun.kanunlar
for each row execute function oyun.emlak_vergi_kanun_uygula();

-- Seçimde her döneme 600 sandalye; dolmayanlar açık kalır.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
