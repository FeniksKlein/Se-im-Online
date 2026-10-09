-- City-limited property stock, distinct city prices/rents, weekly property tax & occupied-seat parliament majorities.
-- Live assets / ownership untouched; all newly created records are additive.
create table if not exists oyun.emlak_vergi_borclari (
 user_id uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 borc numeric not null default 0 check (borc>=0),
 son timestamptz,
 primary key(user_id,il_id)
);
alter table oyun.emlak_vergi_borclari enable row level security;
revoke all on oyun.emlak_vergi_borclari from public,anon,authenticated;
alter table oyun.yatirim_mulkleri add column if not exists sonraki_vergi timestamptz;
-- Older assets get a fresh first tax date, without retroactive deductions.
update oyun.yatirim_mulkleri set sonraki_vergi=oyun.simdi()+interval '7 days' where sonraki_vergi is null;
alter table oyun.yatirim_mulkleri alter column sonraki_vergi set default (now()+interval '7 days');
alter table oyun.yatirim_mulkleri alter column sonraki_vergi set not null;

-- Emlak: local difference in per-mille added to national baseline.
update oyun.duzenleme_tanim set ad='Haftalık emlak vergisi (yerel fark)',birim='binde',
 varsayilan=0,min=-3,max=10,adim=1,tur='gelir',
 aciklama='Belediye başkanı Meclisin belirlediği haftalık mülk vergisi oranını ilde artırabilir veya azaltabilir. Vergi mülkün bulunduğu belediyeye ödenir.',
 oyuncu='7 günde bir mülkün alış değeri üzerinden vergi alınır. Mülk başka ildeyse vergi o ilin belediyesine gider.',
 devlet='Tahsil edilen emlak vergisi fiilen belediye kasasına girer; mülkü olmayan oyuncuya vergi uygulanmaz.'
where kod='emlak';
insert into oyun.duzenleme_tanim (kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values ('emlak_haftalik','ulke','Ulusal haftalık emlak vergisi','binde',3,0,15,1,'gelir',
'TBMM ülke geneli haftalık mülk vergisinin binde oranını belirler. Belediye başkanı iline özel farkı belirleyebilir.',
'Her mülk için haftalık alış bedeli baz alınır; ödediğin vergi mülkün bulunduğu ilin belediyesine aktarılır.',
'Emlak vergileri 7 günde bir gerçek mülk sahiplerinden tahsil edilerek ilgili belediyenin kasasına eklenir.',120)
on conflict (kod) do nothing;

create or replace function oyun.emlak_vergi_orani(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select greatest(0,oyun.duz('emlak_haftalik')+oyun.il_duz(p_il,'emlak'))
$$;

-- Electoral-seat counts are a stable population proxy (Istanbul 96, Bayburt 1).
create or replace function oyun.emlak_il_stok(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case when p_tip='daire' then 8+round((i.mv-1)*92.0/95)::int
             when p_tip='dukkan' then greatest(3,round((8+(i.mv-1)*92.0/95)*0.40)::int)
             when p_tip='villa' then greatest(2,round((8+(i.mv-1)*92.0/95)*0.18)::int) end
 from oyun.iller i where i.id=p_il
$$;
create or replace function oyun.emlak_sehir_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end) *
   (0.55+1.5*power(i.mv::numeric/96,0.65))*(0.75+d.gelisim/200.0)/1000)*1000
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function public.emlak_sehirler()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'gelisim',round(d.gelisim,1),
  'vergi_binde',oyun.emlak_vergi_orani(i.id),'mv',i.mv,
  'tipler',(select jsonb_agg(jsonb_build_object('tur',z.tip,
     'stok',oyun.emlak_il_stok(i.id,z.tip),
     'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=z.tip),
     'fiyat',oyun.emlak_sehir_fiyat(i.id,z.tip),
     'haftalik',round(oyun.emlak_sehir_fiyat(i.id,z.tip)*0.025))
   order by z.sira) from (values ('daire',1),('dukkan',2),('villa',3)) z(tip,sira)))
  order by i.mv desc,i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_sehirler() from public,anon;
grant execute on function public.emlak_sehirler() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 bedel numeric; kira numeric; yeni bigint; stok integer; dolu integer;
begin
 if u is null then raise exception 'Önce giriş yapmalısın.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk tipi.'; end if;
 if p_il is null or not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl seçmelisin.'; end if;
 -- Lock the city to serialize remaining stock; never oversell the same property type.
 perform 1 from oyun.il_durum where il_id=p_il for update;
 stok:=oyun.emlak_il_stok(p_il,p_tip);
 select count(*) into dolu from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if dolu>=stok then raise exception 'Bu ilde % stoğu tükendi: %/% satıldı.',p_tip,dolu,stok; end if;
 bedel:=oyun.emlak_sehir_fiyat(p_il,p_tip);
 kira:=round(bedel*0.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s (%s) satın alındı',p_tip,(select ad from oyun.iller where id=p_il)),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,sonraki_vergi)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days',t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' devlet gayrimenkul alımı');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;
-- The legacy endpoint also checks stock and rates, but buys in registered home city.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 if il is null then raise exception 'Önce şehir seçmelisin.'; end if;
 return public.mulk_satin_al_il(p_tip,il);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Account balances never go below zero; taxes not paid remain in the OWNER's ledger, not the house.
create or replace function oyun.emlak_vergi_tahsil(t timestamptz)
returns void language plpgsql set search_path='' as $$
declare m oyun.yatirim_mulkleri; n int; bedel numeric; borc numeric; topla numeric;
 x record; odenen numeric;
begin
 for m in select * from oyun.yatirim_mulkleri where sonraki_vergi<=t order by id for update skip locked loop
  n:=least(52,1+floor(extract(epoch from(t-m.sonraki_vergi))/604800)::int);
  bedel:=round(m.alis_bedeli*oyun.emlak_vergi_orani(m.il_id)/1000)*n;
  if bedel>0 then
   insert into oyun.emlak_vergi_borclari(user_id,il_id,borc,son)
   values(m.user_id,m.il_id,bedel,t)
   on conflict(user_id,il_id) do update set borc=oyun.emlak_vergi_borclari.borc+excluded.borc,son=t;
  end if;
  update oyun.yatirim_mulkleri set sonraki_vergi=sonraki_vergi+make_interval(weeks=>n) where id=m.id;
 end loop;
 for x in select b.user_id,b.il_id,b.borc from oyun.emlak_vergi_borclari b where b.borc>0 order by b.user_id,b.il_id for update skip locked loop
   select least(x.borc,c.para) into odenen from oyun.cuzdan c where c.user_id=x.user_id for update;
   if coalesce(odenen,0)>0 then
     perform oyun.para_islem(x.user_id,-odenen,'emlak',format('%s haftalık mülk vergisi (‰%s)',
      (select ad from oyun.iller where id=x.il_id),oyun.emlak_vergi_orani(x.il_id)),t,odenen);
     update oyun.il_durum set kasa=kasa+odenen/1000000000.0 where il_id=x.il_id;
     update oyun.emlak_vergi_borclari set borc=greatest(0,borc-odenen),son=t where user_id=x.user_id and il_id=x.il_id;
   end if;
 end loop;
end $$;
revoke all on function oyun.emlak_vergi_tahsil(timestamptz) from public,anon,authenticated;
