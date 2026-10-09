-- 2026-10-09 | İl bazlı kıt emlak, belediye vergisi, 600 sandalyeli TBMM
-- Korunanlar: bütün mevcut mülkler, satış ilanları, oyuncular, eski yasalar.
create table if not exists oyun.emlak_ulke_ayar(
 id int primary key default 1 check(id=1),
 vergi_oran numeric not null default .35 check(vergi_oran between .1 and 1.5)
);
insert into oyun.emlak_ulke_ayar(id,vergi_oran) values(1,.35) on conflict(id) do nothing;
create table if not exists oyun.emlak_il_ayar(
 il_id smallint primary key references oyun.iller(id),
 stok_daire integer not null,
 stok_dukkan integer not null,
 stok_villa integer not null,
 yerel_fark numeric not null default 0 check(yerel_fark between -.5 and .5),
 son_karar timestamptz
);
insert into oyun.emlak_il_ayar(il_id,stok_daire,stok_dukkan,stok_villa)
select i.id,8+round(92*(i.mv-1)::numeric/95)::int,
  3+round(27*(i.mv-1)::numeric/95)::int,
  2+round(18*(i.mv-1)::numeric/95)::int
from oyun.iller i on conflict(il_id) do nothing;
create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 il_id smallint not null references oyun.iller(id),
 user_id uuid not null references oyun.profiller(id),
 hafta_sayisi integer not null check(hafta_sayisi>0),
 oran numeric not null,
 tutar numeric not null,
 zaman timestamptz not null
);
create index if not exists emlak_vergi_kayit_user on oyun.emlak_vergi_kayit(user_id,zaman desc);
do $$ declare t text;begin
 foreach t in array array['emlak_ulke_ayar','emlak_il_ayar','emlak_vergi_kayit'] loop
 execute format('alter table oyun.%I enable row level security',t);
 execute format('revoke all on oyun.%I from public,anon,authenticated',t);
 end loop;
end $$;

create or replace function oyun.emlak_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select greatest(.1,least(1.5,g.vergi_oran+coalesce(i.yerel_fark,0)))
 from oyun.emlak_ulke_ayar g left join oyun.emlak_il_ayar i on i.il_id=p_il where g.id=1
$$;
create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end
  * (0.65+0.9*(greatest(1,i.mv)-1)/95.0+
    greatest(-.08,least(.15,(coalesce(d.gelisim,50)-50)/250.0)))
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;

create or replace function public.emlak_sehirler()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',i.id,'ad',i.ad,'nufus_gostergesi',i.mv,
 'gelisim',d.gelisim,'vergi_oran',oyun.emlak_oran(i.id),
 'daire',jsonb_build_object('fiyat',round(oyun.emlak_fiyat(i.id,'daire')),'kira',round(oyun.emlak_fiyat(i.id,'daire')*.025),
  'stok',a.stok_daire,'kalan',greatest(0,a.stok_daire-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire'))),
 'dukkan',jsonb_build_object('fiyat',round(oyun.emlak_fiyat(i.id,'dukkan')),'kira',round(oyun.emlak_fiyat(i.id,'dukkan')*.025),
  'stok',a.stok_dukkan,'kalan',greatest(0,a.stok_dukkan-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan'))),
 'villa',jsonb_build_object('fiyat',round(oyun.emlak_fiyat(i.id,'villa')),'kira',round(oyun.emlak_fiyat(i.id,'villa')*.025),
  'stok',a.stok_villa,'kalan',greatest(0,a.stok_villa-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa')))
 ) order by i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id join oyun.emlak_il_ayar a on a.il_id=i.id
$$;
revoke all on function public.emlak_sehirler() from public,anon;
grant execute on function public.emlak_sehirler() to authenticated;

create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); price numeric; rent numeric;
 yeni bigint; stock int; cnt int; city oyun.emlak_il_ayar;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Aktif oyuncu hesabı gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Mülk tipi geçersiz.'; end if;
 -- Aynı il için paralel satın alımları kilitle; stok aşılamaz.
 select * into city from oyun.emlak_il_ayar where il_id=p_il for update;
 if city.il_id is null then raise exception 'Geçersiz il.'; end if;
 stock:=case p_tip when 'daire' then city.stok_daire when 'dukkan' then city.stok_dukkan else city.stok_villa end;
 select count(*) into cnt from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if cnt>=stock then raise exception 'Bu ilde % stoku tükendi. Oyunculardan satış ilanı bekleyebilirsin.',p_tip; end if;
 price:=round(oyun.emlak_fiyat(p_il,p_tip));
 if price is null or price<10000 then raise exception 'İl fiyatı hesaplanamadı.'; end if;
 rent:=round(price*.025,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-price,'emlak',
  format('%s, %s satın alındı', (select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
  values(u,p_il,p_tip,price,rent,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
  values('mulk_devlet',yeni,null,u,price,t,(select ad from oyun.iller where id=p_il)||' - '||p_tip);
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;

-- Eski tek parametreli istemci de artık stok korumasından geçer.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 if il is null then raise exception 'Önce oyuncu profili oluşturmalısın.'; end if;
 return public.mulk_satin_al(p_tip,il);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;multi_tax numeric;property_tax numeric;
 t timestamptz:=oyun.simdi(); rate numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  multi_tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  rate:=oyun.emlak_oran(m.il_id);
  property_tax:=round(m.alis_bedeli*rate/100*n,2);
  perform oyun.para_islem(p_user,gross-multi_tax-property_tax,'kira',
     format('Mülk #%s: %s haftalık kira, çoklu mülk vergisi %s TL, belediye emlak vergisi %s TL',m.id,n,multi_tax,property_tax),
     t,multi_tax+property_tax);
  if multi_tax>0 then update oyun.ulke set hazine=hazine+multi_tax/1000000 where id=1;end if;
  -- Belediyenin oyun içi kasası milyon TL cinsindendir.
  if property_tax>0 then
    update oyun.il_durum set kasa=kasa+property_tax/1000000 where il_id=m.il_id;
    insert into oyun.emlak_vergi_kayit(mulk_id,il_id,user_id,hafta_sayisi,oran,tutar,zaman)
      values(m.id,m.il_id,p_user,n,rate,property_tax,t);
  end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
    toplam_kira=toplam_kira+gross-multi_tax-property_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

create or replace function public.emlak_vergi_bilgi(p_il smallint)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('il',(select ad from oyun.iller where id=p_il),
   'ulke_orani',(select vergi_oran from oyun.emlak_ulke_ayar where id=1),
   'yerel_fark',(select yerel_fark from oyun.emlak_il_ayar where il_id=p_il),
   'etkin_oran',oyun.emlak_oran(p_il),
   'belediye_kasasi',(select kasa from oyun.il_durum where il_id=p_il),
   'baskan',(select oyun.kad(m.user_id) from oyun.makamlar m where m.tur='bel' and m.il_id=p_il and m.bit is null order by m.bas desc limit 1),
   'ben_baskanim',exists(select 1 from oyun.makamlar m where m.tur='bel' and m.il_id=p_il and m.bit is null and m.user_id=auth.uid()))
$$;
revoke all on function public.emlak_vergi_bilgi(smallint) from public,anon;
grant execute on function public.emlak_vergi_bilgi(smallint) to authenticated;

create or replace function public.emlak_vergi_belediye_ayarla(p_il smallint,p_fark numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t timestamptz:=oyun.simdi();
begin
 if p_fark is null or p_fark not between -.5 and .5 then raise exception 'Yerel vergi farkı -0,5 ile +0,5 puan arasında olmalı.'; end if;
 if not exists(select 1 from oyun.makamlar where tur='bel' and il_id=p_il and user_id=auth.uid() and bit is null)
    then raise exception 'Yalnızca ilgili ilin belediye başkanı vergiyi değiştirebilir.'; end if;
 update oyun.emlak_il_ayar set yerel_fark=round(p_fark,2),son_karar=t where il_id=p_il;
 perform oyun.olay('ekonomi',format('%s Belediyesi emlak vergisi oranını %%%s olarak düzenledi.',
   (select ad from oyun.iller where id=p_il),oyun.emlak_oran(p_il)),p_il,null,t);
 return public.emlak_vergi_bilgi(p_il);
end $$;
revoke all on function public.emlak_vergi_belediye_ayarla(smallint,numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayarla(smallint,numeric) to authenticated;

-- Meclis oylaması normal kanun süresini ve veto süreçlerini kullanır.
create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare k jsonb; idd bigint;
begin
 if p_oran is null or p_oran not between .1 and 1.5 then raise exception 'Ulusal emlak vergisi %%0,1 ile %%1,5 arasında olmalı.'; end if;
 k:=public.kanun_teklif('serbest',p_baslik,p_metin,null);
 idd:=(k->>'id')::bigint;
 update oyun.kanunlar set veri=jsonb_build_object('emlak_vergi_ulke',round(p_oran,2)) where id=idd and teklif_eden=auth.uid();
 return k;
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text,text) to authenticated;

create or replace function oyun.emlak_vergi_kanun_yururluk()
returns trigger language plpgsql security definer set search_path='' as $$
declare rate numeric;
begin
 if new.durum='yururlukte' and old.durum is distinct from 'yururlukte'
   and new.veri?'emlak_vergi_ulke' then
   rate:=(new.veri->>'emlak_vergi_ulke')::numeric;
   if rate between .1 and 1.5 then
     update oyun.emlak_ulke_ayar set vergi_oran=rate where id=1;
     perform oyun.olay('ekonomi',format('TBMM emlak vergisi ulusal oranını %%%s olarak yasalaştırdı.',rate),null,new.teklif_parti,oyun.simdi());
   end if;
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_kabul on oyun.kanunlar;
create trigger emlak_vergi_kanun_kabul after update of durum on oyun.kanunlar
 for each row execute function oyun.emlak_vergi_kanun_yururluk();

-- 600 yasal koltuk, fiilen seçilen vekil sayısına göre toplantı/karar eşiği.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
