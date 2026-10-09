-- 2026-10-09: 81 ilde kapasiteye bagli emlak, haftalik belediye vergisi,
-- 600 anayasal TBMM koltugu + fiilen gorevdeki vekillerin salt cogunlugu.
-- Mevcut tapular/hesaplar korunur.
create table if not exists oyun.il_emlak_stok (
  il_id smallint not null references oyun.iller(id),
  tip text not null check (tip in ('daire','dukkan','villa')),
  kapasite integer not null check(kapasite>=1),
  primary key (il_id,tip)
);
insert into oyun.il_emlak_stok(il_id,tip,kapasite)
select i.id,t.tip,case t.tip
 when 'daire' then 8+round((i.mv::numeric-1)*92/95)::int
 when 'dukkan' then 3+round((i.mv::numeric-1)*37/95)::int
 else 2+round((i.mv::numeric-1)*23/95)::int end
from oyun.iller i cross join (values ('daire'),('dukkan'),('villa')) t(tip)
on conflict(il_id,tip) do nothing;

-- Meclis tarafindan "Duzenleme Kanunu" olarak teklif verilebilen
-- ulke geneli haftalik emlak vergisi (mulk degerinin yuzdesi).
insert into oyun.duzenleme_tanim(kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,
 aciklama,oyuncu,devlet,sira)
values('emlak_haftalik','ulke','Haftalık emlak vergisi','%',0.20,0,1.00,0.05,'gelir',
 'Mülkün alış bedelinden haftada bir hesaplanan belediye emlak vergisinin ulusal taban oranı.',
 'Kiradan tahsil edilir; mülk hangi ildeyse vergi o ilin belediye kasasına aktarılır.',
 'Meclis kanunla ulusal oranı değiştirebilir; belediye başkanı kendi ilindeki çarpanı düzenler.', 95)
on conflict (kod) do nothing;

create table if not exists oyun.il_emlak_oran (
 il_id smallint primary key references oyun.iller(id),
 carpan numeric not null default 100 check (carpan between 0 and 200),
 degistiren uuid references oyun.profiller(id),
 guncelleme timestamptz not null default now()
);
insert into oyun.il_emlak_oran(il_id,carpan)
 select id,100 from oyun.iller on conflict(il_id) do nothing;

create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000
                         when 'villa' then 520000 else 0 end)
     * (0.65+0.65*sqrt(greatest(1,i.mv)::numeric/96.0))
     * (0.70+coalesce(d.gelisim,50)*0.006))
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_vergi(p_il smallint,p_deger numeric)
returns numeric language sql stable set search_path='' as $$
 select round(greatest(0,p_deger) * greatest(0,oyun.duz('emlak_haftalik'))/100
   * coalesce((select carpan from oyun.il_emlak_oran where il_id=p_il),100)/100)
$$;

create or replace function public.emlak_sehirler()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
 'il_id',i.id,'il',i.ad,'nufus_olcegi',i.mv,'gelisim',coalesce(d.gelisim,50),
 'tipler',(select jsonb_agg(jsonb_build_object(
   'tip',st.tip,'kapasite',st.kapasite,'satilan', (select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=st.tip),
   'kalan',greatest(0,st.kapasite-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=st.tip)),
   'fiyat',oyun.emlak_fiyat(i.id,st.tip),'haftalik',round(oyun.emlak_fiyat(i.id,st.tip)*0.025),
   'vergi',oyun.emlak_vergi(i.id,oyun.emlak_fiyat(i.id,st.tip))
  ) order by case st.tip when 'daire' then 1 when 'dukkan' then 2 else 3 end)
  from oyun.il_emlak_stok st where st.il_id=i.id),
 'ulusal_vergi',oyun.duz('emlak_haftalik'),
 'belediye_carpan',coalesce((select carpan from oyun.il_emlak_oran where il_id=i.id),100)
 ) order by i.ad),'[]'::jsonb)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_sehirler() from public,anon;
grant execute on function public.emlak_sehirler() to authenticated;

-- Eski tek parametreli API yerinde kalir; yeni API farkli ilden alima izin verir.
create or replace function public.mulk_satin_al(p_tip text,p_il_id smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric; st oyun.il_emlak_stok;
    t timestamptz:=oyun.simdi(); yeni bigint; mevcut int;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce oyuncu hesabı oluştur'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü'; end if;
 if p_il_id is null or not exists(select 1 from oyun.iller where id=p_il_id) then raise exception 'Geçerli bir il seçmelisin.'; end if;
 select * into st from oyun.il_emlak_stok where il_id=p_il_id and tip=p_tip for update;
 if st.il_id is null then raise exception 'Bu ilde satış stoku bulunamadı.'; end if;
 select count(*) into mevcut from oyun.yatirim_mulkleri where il_id=p_il_id and tip=p_tip;
 if mevcut>=st.kapasite then raise exception 'Bu ilde % stoğu tükendi (%/%). Başka il veya tür seç.',p_tip,mevcut,st.kapasite; end if;
 bedel:=oyun.emlak_fiyat(p_il_id,p_tip);
 kira:=round(bedel*0.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinden %s satın alındı', (select ad from oyun.iller where id=p_il_id),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il_id,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' devlet emlak alimi');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;

create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al(p_tip,p.il_id);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Yerel belediye baskani; 24 saatte bir %0-%200, ulusal oranla carpilir.
create or replace function public.emlak_belediye_oran_ayarla(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar:=oyun.baskan_zorunlu(p);
   t timestamptz:=oyun.simdi(); onceki oyun.il_emlak_oran;
begin
 if p_carpan is null or p_carpan not between 0 and 200 or mod(p_carpan,5)<>0 then
   raise exception 'Belediye emlak çarpanı 0-200 arasında 5 puan adımlarla olmalı.';
 end if;
 select * into onceki from oyun.il_emlak_oran where il_id=m.il_id for update;
 if onceki.carpan=p_carpan then raise exception 'Oran değişmedi.'; end if;
 if onceki.degistiren is not null and onceki.guncelleme>t-interval '24 hours' then
    raise exception 'Emlak vergisi çarpanı 24 saatte bir değiştirilebilir.'; end if;
 update oyun.il_emlak_oran set carpan=p_carpan,degistiren=p.id,guncelleme=t where il_id=m.il_id;
 perform oyun.olay('belediye',format('%s Belediye Başkanı emlak vergisini ulusal oranın %s%% seviyesine ayarladı.',
     (select ad from oyun.iller where id=m.il_id),p_carpan),m.il_id,p.parti_id,t);
 return jsonb_build_object('il_id',m.il_id,'carpan',p_carpan,'ulusal',oyun.duz('emlak_haftalik'));
end $$;
revoke all on function public.emlak_belediye_oran_ayarla(numeric) from public,anon;
grant execute on function public.emlak_belediye_oran_ayarla(numeric) to authenticated;

create or replace function public.emlak_belediye_durum()
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar; r oyun.il_emlak_oran;
begin
 select * into m from oyun.makamlar where user_id=p.id and tur='bel' and bit is null;
 if m.id is null then return jsonb_build_object('yetkili',false); end if;
 select * into r from oyun.il_emlak_oran where il_id=m.il_id;
 return jsonb_build_object('yetkili',true,'il_id',m.il_id,'il',(select ad from oyun.iller where id=m.il_id),
 'carpan',coalesce(r.carpan,100),'ulusal',oyun.duz('emlak_haftalik'),
 'sonraki_degisim',case when r.degistiren is not null then r.guncelleme+interval '24 hours' else null end,
 'kasa',(select kasa from oyun.il_durum where il_id=m.il_id));
end $$;
revoke all on function public.emlak_belediye_durum() from public,anon;
grant execute on function public.emlak_belediye_durum() to authenticated;

-- Emlak vergisi kira gununde o ilin belediye kasasina net olarak aktarilir.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record; n int; gross numeric; tax numeric; emlak numeric; t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
   n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
   gross:=round(m.haftalik_kira*n,2);
   tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
        and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
        then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
   emlak:=least(greatest(0,gross-tax),oyun.emlak_vergi(m.il_id,m.alis_bedeli)*n);
   perform oyun.para_islem(p_user,gross-tax-emlak,'kira',
      format('Mulk #%s: %s haftalik kira, coklu vergi %s TL, emlak vergisi %s TL',m.id,n,tax,emlak),t,tax+emlak);
   if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1; end if;
   if emlak>0 then update oyun.il_durum set kasa=kasa+emlak/1000000 where il_id=m.il_id; end if;
   update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
     toplam_kira=toplam_kira+gross-tax-emlak,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;
