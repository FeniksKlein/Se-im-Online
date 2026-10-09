-- İl bazlı sınırlı emlak arzı, farklı fiyat/kira, haftalık yerel vergi ve 600 sandalyeli TBMM.
-- Mevcut tapu, para, oy ve vekil kayıtları korunur.

-- Türkiye genelinde haftalık binde emlak vergisi Meclis yasasıyla değiştirilebilir.
insert into oyun.duzenleme_tanim(kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values('emlak_haftalik_oran','ulke','Haftalık emlak vergisi','binde',2,0,10,0.5,'gelir',
'Her mülkün alış bedeli üzerinden haftalık binde oran. Gelir mülkün bulunduğu ilin belediye kasasına aktarılır.',
'Mülk sahiplerinin haftalık vergisini değiştirir; gelir ilgili belediyeye gider.','Belediyelerin emlak vergisi geliri değişir.',9)
on conflict(kod) do update set ad=excluded.ad,aciklama=excluded.aciklama,oyuncu=excluded.oyuncu,devlet=excluded.devlet;

-- Belediye başkanının mevcut yerel 'emlak' kararı da haftalık vergide etkilidir.
update oyun.duzenleme_tanim set ad='Emlak vergisi ek tutarı',
aciklama='Bu ilde bulunan mülk başına günlük ek emlak vergisi. Haftalık tahsil edilir; belediye kasasına kalır.',
oyuncu='Bu ilde mülkü olanların haftalık vergi maliyetini etkiler (yerleşim ilinden bağımsız).'
where kod='emlak' and kapsam='il';

create table if not exists oyun.emlak_stok (
 il_id smallint not null references oyun.iller(id),
 tip text not null check (tip in ('daire','dukkan','villa')),
 kapasite integer not null check (kapasite>=0),
 primary key(il_id,tip)
);
-- 96 milletvekilli İstanbul'da 100 daire, 1 milletvekilli Bayburt'ta 8 daire.
insert into oyun.emlak_stok(il_id,tip,kapasite)
select i.id,t.tip,
case t.tip
when 'daire' then 8+round(92*(i.mv-1)/95.0)::int
when 'dukkan' then greatest(2,round((8+92*(i.mv-1)/95.0)*0.40)::int)
else greatest(1,round((8+92*(i.mv-1)/95.0)*0.16)::int)
end
from oyun.iller i cross join (values('daire'),('dukkan'),('villa')) t(tip)
on conflict(il_id,tip) do nothing;
alter table oyun.emlak_stok enable row level security;
revoke all on oyun.emlak_stok from public,anon,authenticated;

create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text)
returns jsonb language plpgsql stable set search_path='' as $$
declare i oyun.iller; d numeric; carp numeric; bedel numeric; kira numeric; kapasite int; stok int;
begin
 select * into i from oyun.iller where id=p_il;
 if i.id is null then raise exception 'İl bulunamadı.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 select greatest(0,least(100,gelisim)) into d from oyun.il_durum where il_id=i.id;
 d:=coalesce(d,50);
 carp:=0.55+1.1*power(i.mv::numeric/96.0,0.42)+0.4*d/100.0;
 bedel:=round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 else 520000 end)*carp,-2);
 kira:=round(bedel*(0.022+0.006*d/100.0));
 select kapasite into kapasite from oyun.emlak_stok where il_id=p_il and tip=p_tip;
 select count(*) into stok from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 return jsonb_build_object('bedel',bedel,'haftalik',kira,'stok',stok,'kapasite',coalesce(kapasite,0),'kalan',greatest(0,coalesce(kapasite,0)-stok),
 'gelisim',d,'il',i.ad,'tip',p_tip);
end $$;

create or replace function public.emlak_iller()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Oturum açmalısın.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'nufus_olcegi',i.mv,
   'gelisim',coalesce(d.gelisim,50),
   'daire',oyun.emlak_fiyat(i.id,'daire'),
   'dukkan',oyun.emlak_fiyat(i.id,'dukkan'),
   'villa',oyun.emlak_fiyat(i.id,'villa')) order by i.ad)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id),'[]'::jsonb);
end $$;
revoke all on function public.emlak_iller() from public,anon;
grant execute on function public.emlak_iller() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); k jsonb; t timestamptz:=oyun.simdi(); idd bigint;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Aktif oyuncu hesabı gerekli.'; end if;
 perform pg_advisory_xact_lock(78442,(p_il::integer*10+
  case p_tip when 'daire' then 1 when 'dukkan' then 2 when 'villa' then 3 else 0 end));
 k:=oyun.emlak_fiyat(p_il,p_tip);
 if (k->>'kalan')::int<=0 then raise exception '% ilinde % stoğu doldu, bu ilde yeni devlet mülkü satılamıyor.',k->>'il',p_tip; end if;
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-(k->>'bedel')::numeric,'emlak',format('%s ilinde %s satın alındı',k->>'il',p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,(k->>'bedel')::numeric,(k->>'haftalik')::numeric,t,t+interval '7 days') returning id into idd;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',idd,null,u,(k->>'bedel')::numeric,t,format('%s ilinden devlet mülkü',k->>'il'));
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;

-- Eski tek parametreli RPC, oyuncunun kayıtlı ili üzerinden yeni stok kontrolüne gider.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al_il(p_tip,p.il_id);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Bütün eski mülklerin ilk emlak vergisi bu güncellemeden bir hafta sonra başlar.
alter table oyun.yatirim_mulkleri add column if not exists vergi_sonraki timestamptz;
update oyun.yatirim_mulkleri set vergi_sonraki=oyun.simdi()+interval '7 days' where vergi_sonraki is null;
alter table oyun.yatirim_mulkleri alter column vergi_sonraki set default (now()+interval '7 days');
create table if not exists oyun.emlak_vergi_borc (
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 user_id uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 donem timestamptz not null,
 tutar numeric not null check(tutar>=0),
 odendi_at timestamptz,
 primary key(mulk_id,donem)
);
create index if not exists emlak_vergi_user on oyun.emlak_vergi_borc(user_id,odendi_at);
alter table oyun.emlak_vergi_borc enable row level security;
revoke all on oyun.emlak_vergi_borc from public,anon,authenticated;

create or replace function oyun.emlak_vergi_borclandir(t timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare m oyun.yatirim_mulkleri;v numeric; gun numeric; n int;i int; tarih timestamptz;
begin
 for m in select * from oyun.yatirim_mulkleri where vergi_sonraki<=t order by id for update loop
  n:=least(52,1+floor(extract(epoch from (t-m.vergi_sonraki))/604800)::int);
  for i in 0..n-1 loop
   tarih:=m.vergi_sonraki+i*interval '7 days';
   gun:=coalesce(oyun.il_duz(m.il_id,'emlak'),0);
   v:=round(greatest(0,m.alis_bedeli*oyun.duz('emlak_haftalik_oran')/1000+7*gun));
   insert into oyun.emlak_vergi_borc(mulk_id,user_id,il_id,donem,tutar)
   values(m.id,m.user_id,m.il_id,tarih,v) on conflict do nothing;
  end loop;
  update oyun.yatirim_mulkleri set vergi_sonraki=vergi_sonraki+n*interval '7 days' where id=m.id;
 end loop;
end $$;

create or replace function oyun.emlak_vergi_tahsil(p_user uuid,t timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare x oyun.emlak_vergi_borc; b numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78143));
 for x in select * from oyun.emlak_vergi_borc where user_id=p_user and odendi_at is null order by donem,mulk_id for update loop
  b:=(select para from oyun.cuzdanim(p_user));
  if coalesce(b,0)<x.tutar then exit; end if;
  if x.tutar>0 then
   perform oyun.para_islem(p_user,-x.tutar,'emlak_vergi',
     format('%s ili mülk #%s haftalık emlak vergisi', (select ad from oyun.iller where id=x.il_id),x.mulk_id),t,x.tutar);
   update oyun.il_durum set kasa=kasa+x.tutar/1000000.0 where il_id=x.il_id;
  end if;
  update oyun.emlak_vergi_borc set odendi_at=t where mulk_id=x.mulk_id and donem=x.donem;
 end loop;
end $$;

create or replace function oyun.emlak_vergi_tick(t timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid;
begin
 perform oyun.emlak_vergi_borclandir(t);
 for u in select distinct user_id from oyun.emlak_vergi_borc where odendi_at is null loop
  perform oyun.emlak_vergi_tahsil(u,t);
 end loop;
end $$;

create or replace function public.emlak_vergi_durum()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 perform oyun.emlak_vergi_tick(oyun.simdi());
 return jsonb_build_object(
   'borc',coalesce((select sum(tutar) from oyun.emlak_vergi_borc where user_id=u and odendi_at is null),0),
   'odenmis',coalesce((select sum(tutar) from oyun.emlak_vergi_borc where user_id=u and odendi_at is not null),0),
   'haftalik_tahmin',coalesce((select sum(round(greatest(0,m.alis_bedeli*oyun.duz('emlak_haftalik_oran')/1000+
     7*oyun.il_duz(m.il_id,'emlak')))) from oyun.yatirim_mulkleri m where m.user_id=u),0),
   'ulke_binde',oyun.duz('emlak_haftalik_oran'));
end $$;
revoke all on function public.emlak_vergi_durum() from public,anon;
grant execute on function public.emlak_vergi_durum() to authenticated;

-- Meclis 600 anayasal sandalye ile görünür; oy yeter sayısı mevcut dolu sandalyelerden hesaplanır.
update oyun.ayarlar set meclis_olcek=0 where id=1;
create or replace function oyun.meclis_olcek_hesap(t timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('aktif',(select count(*) from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days'),
  'sandalye',coalesce((select round(deger)::int from oyun.anayasa where kod='milletvekili_sayisi'),600),
  'anayasal',coalesce((select round(deger)::int from oyun.anayasa where kod='milletvekili_sayisi'),600),
  'olcek',0)
$$;
select oyun.dagit_mv_sandalye(600);

-- Mevcut tüm kanun türlerinde normal kabul eşiğini dörtte birden dolu sandalyelerin salt çoğunluğuna yükselt.
do $fix$
declare fonk text;
begin
 select pg_get_functiondef('oyun.kanun_tick(timestamptz)'::regprocedure) into fonk;
 if position('floor(dolu / 4.0) + 1' in fonk)>0 then
  execute replace(fonk,'floor(dolu / 4.0) + 1','floor(dolu / 2.0) + 1');
 end if;
end $fix$;
