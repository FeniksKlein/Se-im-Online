-- 2026-10-09 | İl bazlı sınırlı emlak, belediye haftalık mülk vergisi ve TBMM 600 sandalye.
-- Mevcut tapular, para, geçmiş seçim oyları ve makamlar korunur.
create table if not exists oyun.mulk_haftalik_vergi (
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 malik uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 hafta_sayisi int not null check (hafta_sayisi between 1 and 520),
 oran numeric not null, tutar numeric not null check(tutar>=0),
 zaman timestamptz not null default now()
);
create index if not exists mulk_vergi_il_zaman on oyun.mulk_haftalik_vergi(il_id,zaman);
create index if not exists mulk_vergi_malik on oyun.mulk_haftalik_vergi(malik,zaman);
alter table oyun.mulk_haftalik_vergi enable row level security;
revoke all on oyun.mulk_haftalik_vergi from public,anon,authenticated;

-- Mevcut nüfus verisi yerine il mv dağılımının nüfus ağırlığı kullanılır.
-- Bayburt (mv=1) 8, İstanbul (mv=96) 100 satılabilir daire.
create or replace function oyun.mulk_stok(p_il smallint,p_tip text) returns integer
language sql stable set search_path='' as $$
 select case p_tip
   when 'daire' then c
   when 'dukkan' then greatest(3,round(c*.45)::int)
   when 'villa' then greatest(2,round(c*.20)::int)
   else 0 end
 from (select 8+round(92.0*(i.mv-1)/greatest(1,(select max(mv)-1 from oyun.iller)))::int c
       from oyun.iller i where i.id=p_il) z
$$;
create or replace function oyun.mulk_deger(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
 * (0.8+1.6*(i.mv-1)/greatest(1,(select max(mv)-1 from oyun.iller)))
 * (0.75+least(100,greatest(0,coalesce(d.gelisim,50)))/200.0),-3)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.mulk_vergi_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select coalesce((select deger from oyun.il_duzenleme where il_id=p_il and kod='emlak_mulk_oran_il'),
                 oyun.duz('emlak_mulk_oran'),0.5)
$$;
-- Yasama ülke genelinde, belediye başkanı kendi ilinde haftalık oranı değiştirebilir.
insert into oyun.duzenleme_tanim(kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values ('emlak_mulk_oran','ulke','Haftalık mülk emlak vergisi','yuzde',0.5,0,2,0.1,'gelir',
 'Mülkün alış değerine uygulanan haftalık emlak vergisi. Belediye kasasına aktarılır.',
 'Haftalık kira tahsilatında mülkün sahibinden kesilir.',
 'Meclis kanunuyla genel oran değişir; belediye başkanı kendi iline özel oran belirleyebilir.',60),
 ('emlak_mulk_oran_il','il','Haftalık mülk vergisi','yuzde',0.5,0,2,0.1,'gelir',
 'İldeki mülk sahiplerine uygulanan haftalık emlak vergisi yüzdesi.',
 'Malik başka ilde yaşasa bile mülkün bulunduğu belediyeye öder.',
 'Haftalık kesinti belediye kasasına eklenir; genel kanun oranı özel il kararı yoksa uygulanır.',60)
on conflict (kod) do nothing;

create or replace function public.mulk_il_katalog()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'il_id',i.id,'il',i.ad,'nufus_agirligi',i.mv,'gelisim',coalesce(d.gelisim,50),
  'vergi_oran',oyun.mulk_vergi_oran(i.id),
  'tipler',(select jsonb_agg(jsonb_build_object(
    'tip',x.tip,'stok',oyun.mulk_stok(i.id,x.tip),
    'sahipli',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=x.tip),
    'fiyat',oyun.mulk_deger(i.id,x.tip),
    'haftalik_kira',round(oyun.mulk_deger(i.id,x.tip)*.025))
    order by x.sira)
    from (values ('daire',1),('dukkan',2),('villa',3)) x(tip,sira))
 ) order by i.ad),'[]'::jsonb)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.mulk_il_katalog() from public,anon;
grant execute on function public.mulk_il_katalog() to authenticated;

-- Konum zorunluluğu yok: tüm illerden satın al, fakat illerde stok tükenebilir.
create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
  bedel numeric; kira numeric; mevcut int; kota int; yeni bigint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Oyuncu profili gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl bulunamadı.'; end if;
 perform pg_advisory_xact_lock(71037,p_il::int * 10 + case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 select count(*) into mevcut from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 kota:=oyun.mulk_stok(p_il,p_tip);
 if mevcut>=kota then raise exception 'Bu ilde satılabilir % kalmadı (%/%). Diğer oyuncuların satış ilanlarını incele.',
 (case p_tip when 'daire' then 'daire' when 'dukkan' then 'dükkân' else 'villa' end),mevcut,kota; end if;
 bedel:=oyun.mulk_deger(p_il,p_tip); kira:=round(bedel*.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s satın alındı',
 (select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' il bazlı mülk alımı');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;
-- Eski istemciler kendi ilinde alım yapmaya devam eder; yine stok kontrolü uygulanır.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al_il(p_tip,p.il_id);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Çifte tahsil yok: kira başlangıç tarihinin yedi günlük döngüsü üzerinden tek seferlik kesinti.
-- Önce malik geliri hesaplanır, sonra belediye vergisi aynı tahsilatta kesilir.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare m record; n int; gross numeric; eski_tax numeric; emlak_tax numeric;
 oran numeric; t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  eski_tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
   and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
   then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  oran:=oyun.mulk_vergi_oran(m.il_id);
  emlak_tax:=round(m.alis_bedeli*oran/100*n,2);
  perform oyun.para_islem(p_user,gross-eski_tax-emlak_tax,'kira',
    format('Mülk #%s: %s haftalık kira; çoklu mülk vergisi %s TL; belediye emlak vergisi %s TL',
      m.id,n,eski_tax,emlak_tax),t,eski_tax+emlak_tax);
  if eski_tax>0 then update oyun.ulke set hazine=hazine+eski_tax/1000000.0 where id=1;end if;
  if emlak_tax>0 then
   update oyun.il_durum set kasa=kasa+emlak_tax/1000000.0 where il_id=m.il_id;
   insert into oyun.mulk_haftalik_vergi(mulk_id,malik,il_id,hafta_sayisi,oran,tutar,zaman)
    values(m.id,p_user,m.il_id,n,oran,emlak_tax,t);
  end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
    toplam_kira=toplam_kira+gross-eski_tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

-- Sadece 600 sandalye dağılımı geri getirilir; gerçek kişilere sahte vekillik atanmaz.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
update oyun.meclis_olcek_kayit set sandalye=600
 where secim_id in (select id from oyun.secimler where tur='mv_on' and durum='bekliyor');
-- Kanunlarda salt çoğunluk fiilen görevdeki milletvekillerinin yarısından fazlasıdır.
-- Önceki kural olan dörtte birle kanun geçmesini engelle.
do $plpgsql$
declare defn text;
begin
 select pg_get_functiondef('oyun.kanun_tick(timestamp with time zone)'::regprocedure) into defn;
 if strpos(defn,'c.kabul >= floor(dolu / 4.0) + 1')>0 then
  defn:=replace(defn,'c.kabul >= floor(dolu / 4.0) + 1','c.kabul >= floor(dolu / 2.0) + 1');
  defn:=replace(defn,'floor(dolu / 4.0) + 1','floor(dolu / 2.0) + 1');
  execute defn;
 elsif strpos(defn,'c.kabul >= floor(dolu / 2.0) + 1')=0 then
  raise exception 'Beklenmedik TBMM kanun oylaması işleyişi; işlem uygulanmadı.';
 end if;
end $plpgsql$;
