-- İl bazlı sınırlı gayrimenkul, şehir fiyatları, haftalık belediye emlak vergisi.
-- Oyun verileri korunur; mevcut mülkler geriye dönük silinmez.
create table if not exists oyun.il_emlak_stok (
 il_id smallint primary key references oyun.iller(id),
 daire_limit integer not null check (daire_limit>=0),
 dukkan_limit integer not null check (dukkan_limit>=0),
 villa_limit integer not null check (villa_limit>=0),
 guncelleme timestamptz not null default now()
);
insert into oyun.il_emlak_stok(il_id,daire_limit,dukkan_limit,villa_limit)
select i.id,
 greatest(8,8+round((i.mv-1)*92.0/95)::int,(select count(*)::int from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire')),
 greatest(3,3+round((i.mv-1)*23.0/95)::int,(select count(*)::int from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan')),
 greatest(1,1+round((i.mv-1)*7.0/95)::int,(select count(*)::int from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa'))
from oyun.iller i on conflict(il_id) do nothing;
alter table oyun.il_emlak_stok enable row level security;
revoke all on oyun.il_emlak_stok from public,anon,authenticated;

create table if not exists oyun.il_emlak_vergi (
 il_id smallint primary key references oyun.iller(id),
 oran numeric(4,2) not null check (oran between 0 and 2),
 baskan uuid references oyun.profiller(id),
 zaman timestamptz not null default now()
);
alter table oyun.il_emlak_vergi enable row level security;
revoke all on oyun.il_emlak_vergi from public,anon,authenticated;

insert into oyun.duzenleme_tanim(kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values ('emlak_mulk','ulke','Haftalık gayrimenkul vergisi','yuzde',0.5,0,2,0.1,'gelir',
 'Devletten veya başka bir oyuncudan alınan her mülk için alış bedelinin haftalık vergisi.',
 'Her 7 günde bir kira tahsilinde, mülkün güncel sahibinden alış bedelinin belirlenen yüzdesi kesilir. Gelir mülkün bulunduğu belediyeye gider. Belediye başkanı kendi ilinin oranını ayrıca değiştirebilir.',
 'Belediyeler gerçek oyuncu mülklerinden haftalık emlak vergisi tahsil eder.',90)
on conflict (kod) do nothing;

create or replace function oyun.emlak_vergi_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select coalesce((select oran from oyun.il_emlak_vergi where il_id=p_il),
    coalesce(oyun.duz('emlak_mulk'),0.5))
$$;

create or replace function oyun.emlak_il_fiyat(p_il smallint,p_tip text)
returns numeric language plpgsql stable set search_path='' as $$
declare mv integer; gelisim numeric; taban numeric; nufus_carpan numeric; gelisim_carpan numeric;
begin
 select i.mv,d.gelisim into mv,gelisim from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il;
 if mv is null then raise exception 'Geçersiz il.'; end if;
 taban:=case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end;
 if taban is null then raise exception 'Geçersiz gayrimenkul türü.'; end if;
 -- TBMM nüfus ağırlığı 1..96; şehrin güncel gelişmişliği de fiyatı etkiler.
 nufus_carpan:=0.7+1.15*sqrt(mv/96.0);
 gelisim_carpan:=greatest(0.65,least(1.5,0.75+coalesce(gelisim,50)/200));
 return greatest(10000,round(taban*nufus_carpan*gelisim_carpan/1000)*1000);
end $$;

create or replace function public.emlak_il_piyasa()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',i.id,'il',i.ad,'gelisim',round(d.gelisim,1),'nufus_agirligi',i.mv,
   'emlak_vergi_oran',oyun.emlak_vergi_oran(i.id),
   'daire',jsonb_build_object('fiyat',oyun.emlak_il_fiyat(i.id,'daire'),'kira',round(oyun.emlak_il_fiyat(i.id,'daire')*.025),
      'stok',s.daire_limit,'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire')),
   'dukkan',jsonb_build_object('fiyat',oyun.emlak_il_fiyat(i.id,'dukkan'),'kira',round(oyun.emlak_il_fiyat(i.id,'dukkan')*.025),
      'stok',s.dukkan_limit,'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan')),
   'villa',jsonb_build_object('fiyat',oyun.emlak_il_fiyat(i.id,'villa'),'kira',round(oyun.emlak_il_fiyat(i.id,'villa')*.025),
      'stok',s.villa_limit,'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa'))
 ) order by i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_emlak_stok s on s.il_id=i.id
 join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_il_piyasa() from public,anon;
grant execute on function public.emlak_il_piyasa() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); i oyun.il_emlak_stok;
  fiyat numeric; kira numeric; mevcut integer; limit_sayi integer; idd bigint; ilad text;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oyuncu profili gerekli.'; end if;
 if p_tip is null or p_tip not in ('daire','dukkan','villa') then raise exception 'Mülk türünü seç.'; end if;
 select * into i from oyun.il_emlak_stok where il_id=p_il for update;
 if i.il_id is null then raise exception 'Geçersiz il.'; end if;
 limit_sayi:=case p_tip when 'daire' then i.daire_limit when 'dukkan' then i.dukkan_limit else i.villa_limit end;
 select count(*) into mevcut from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if mevcut>=limit_sayi then raise exception 'Bu ilde % tipi için satış kontenjanı doldu. Başka il seç veya oyuncu ilanlarını incele.',p_tip; end if;
 fiyat:=oyun.emlak_il_fiyat(p_il,p_tip);kira:=round(fiyat*0.025,2);
 select ad into ilad from oyun.iller where id=p_il;
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-fiyat,'emlak',format('%s ilinden %s mülk alındı',ilad,p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,fiyat,kira,t,t+interval '7 days') returning id into idd;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',idd,null,u,fiyat,t,ilad||' / '||p_tip||' devlet gayrimenkul alımı');
 return jsonb_build_object('id',idd,'il',ilad,'tip',p_tip,'fiyat',fiyat,'kira',kira,'kalan_stok',limit_sayi-mevcut-1);
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;

-- Eski istemci aynı RPC'yi kullanırsa oyuncunun kayıtlı ilini baz alır,
-- stok sınırını atlatamaz.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 if il is null then raise exception 'Önce il seçmelisin.'; end if;
 perform public.mulk_satin_al_il(p_tip,il);
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Belediye başkanı emlak vergisini kendi ilinde 24 saatte bir belirleyebilir.
create or replace function public.emlak_vergi_belediye_ayarla(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); il smallint; son timestamptz; eski numeric; t timestamptz:=oyun.simdi(); ilad text;
begin
 select il_id into il from oyun.makamlar where user_id=u and tur='bel' and bit is null order by bas desc limit 1;
 if il is null then raise exception 'Yalnızca görevdeki belediye başkanı oran değiştirebilir.'; end if;
 if p_oran is null or p_oran<0 or p_oran>2 or p_oran*10<>trunc(p_oran*10) then raise exception 'Vergi %%0-%%2 arası, 0,1 puanlık adımlarla olmalı.'; end if;
 select zaman,oran into son,eski from oyun.il_emlak_vergi where il_id=il for update;
 if son is not null and son>t-interval '24 hours' then raise exception 'Emlak vergisi en fazla 24 saatte bir değiştirilebilir.'; end if;
 if coalesce(eski,oyun.duz('emlak_mulk'))=p_oran then raise exception 'Vergi oranında değişiklik yok.'; end if;
 insert into oyun.il_emlak_vergi(il_id,oran,baskan,zaman) values(il,p_oran,u,t)
 on conflict(il_id) do update set oran=excluded.oran,baskan=excluded.baskan,zaman=excluded.zaman;
 select i.ad into ilad from oyun.iller i where i.id=il;
 perform oyun.olay('belediye',format('%s Belediyesi haftalık mülk vergisini %s%% olarak belirledi.',ad,p_oran),il,null,t);
 return jsonb_build_object('il',ilad,'oran',p_oran,'degisim',t);
end $$;
revoke all on function public.emlak_vergi_belediye_ayarla(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayarla(numeric) to authenticated;

-- Her mülkün emlak vergisi, kira vadesinde tahsil edilir ve o ilin belediyesine aktarılır.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric;oran numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  oran:=oyun.emlak_vergi_oran(m.il_id);
  emlak_tax:=round(m.alis_bedeli*oran*n/100,2);
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',
    format('Mülk #%s: %s haftalık kira; ulusal vergi %s ₺, belediye emlak vergisi %s ₺',
      m.id,n,oyun.tl(tax),oyun.tl(emlak_tax)),t,tax+emlak_tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1; end if;
  if emlak_tax>0 then update oyun.il_durum set kasa=kasa+emlak_tax/1000000 where il_id=m.il_id; end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
   toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;
