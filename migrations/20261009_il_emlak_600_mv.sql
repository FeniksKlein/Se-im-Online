-- 2026-10-09: 81 ilde stoklu emlak, il katsayıları, belediye emlak vergisi, 600 sandalye
-- Eski tapular korunur. Yeni vergiler yalnızca güncelleme sonrasından itibaren işler.
begin;
create table if not exists oyun.emlak_vergi_ayar (
 id integer primary key default 1 check(id=1),
 ulusal_oran numeric not null default 0.20 check(ulusal_oran between 0 and 2),
 degisme timestamptz not null default now()
);
insert into oyun.emlak_vergi_ayar(id,ulusal_oran) values(1,0.20) on conflict(id) do nothing;
create table if not exists oyun.il_emlak_vergi (
 il_id smallint primary key references oyun.iller(id),
 oran numeric not null check(oran between 0 and 2),
 baskan uuid references oyun.profiller(id),
 degisme timestamptz not null default now()
);
create table if not exists oyun.emlak_vergi_borc (
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 il_id smallint not null references oyun.iller(id),
 borc numeric not null default 0 check(borc>=0),
 guncelleme timestamptz not null default now(),
 primary key(user_id,il_id)
);
alter table oyun.yatirim_mulkleri add column if not exists sonraki_emlak_vergi timestamptz;
update oyun.yatirim_mulkleri set sonraki_emlak_vergi=oyun.simdi()+interval '7 days'
where sonraki_emlak_vergi is null;
alter table oyun.yatirim_mulkleri alter column sonraki_emlak_vergi set default (now()+interval '7 days');
alter table oyun.yatirim_mulkleri alter column sonraki_emlak_vergi set not null;
alter table oyun.emlak_vergi_ayar enable row level security;
alter table oyun.il_emlak_vergi enable row level security;
alter table oyun.emlak_vergi_borc enable row level security;
revoke all on oyun.emlak_vergi_ayar,oyun.il_emlak_vergi,oyun.emlak_vergi_borc from public,anon,authenticated;

create or replace function oyun.emlak_haftalik_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select coalesce((select oran from oyun.il_emlak_vergi where il_id=p_il),
                 (select ulusal_oran from oyun.emlak_vergi_ayar where id=1),0.20)
$$;
create or replace function oyun.emlak_kapasite(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case p_tip
  when 'daire' then 8+floor(greatest(0,i.mv-1)*92.0/95)::integer
  when 'dukkan' then 3+floor(greatest(0,i.mv-1)*37.0/95)::integer
  when 'villa' then 2+floor(greatest(0,i.mv-1)*18.0/95)::integer
  else 0 end from oyun.iller i where id=p_il
$$;
create or replace function oyun.emlak_bedel(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end
 * greatest(0.65,least(2.8,0.70 + 1.12*sqrt(i.mv/96.0)+0.008*(d.gelisim-50)))
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function public.emlak_il_katalog()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',i.id,'il',i.ad,'gelisim',round(d.gelisim,1),'nufus_endeksi',i.mv,
 'oran',oyun.emlak_haftalik_oran(i.id),
 'turler',(select jsonb_agg(jsonb_build_object('tip',v.tip,'fiyat',round(oyun.emlak_bedel(i.id,v.tip)),
   'haftalik',round(oyun.emlak_bedel(i.id,v.tip)*0.025),
   'stok',oyun.emlak_kapasite(i.id,v.tip),'satilan',(
     select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=v.tip
   )) order by v.sira)
   from (values('daire',1),('dukkan',2),('villa',3)) v(tip,sira))
 ) order by i.id),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_il_katalog() from public,anon;
grant execute on function public.emlak_il_katalog() to authenticated;

create or replace function public.mulk_satin_al_il(p_il smallint,p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); fiyat numeric;kira numeric; yeni bigint; stok integer;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli)
 then raise exception 'Aktif oyuncu hesabı gerekli.'; end if;
 if p_tip is null or p_tip not in ('daire','dukkan','villa') then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçersiz il.'; end if;
 -- Bir ilde aynı türdeki satış kapasitesi çoklu isteklerde de aşılmaz.
 perform pg_advisory_xact_lock(97410,p_il::integer*10+
   case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 stok:=oyun.emlak_kapasite(p_il,p_tip);
 if (select count(*) from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip)>=stok
 then raise exception 'Bu ildeki % stokları tükendi. Başka il seç veya oyuncu ilanlarına bak.',p_tip; end if;
 fiyat:=round(oyun.emlak_bedel(p_il,p_tip));
 if fiyat is null or fiyat<1 then raise exception 'Bu ilde mülk alımı mümkün değil.'; end if;
 kira:=round(fiyat*0.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-fiyat,'emlak',format('%s, %s yeni mülk alımı',(select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,sonraki_emlak_vergi)
 values(u,p_il,p_tip,fiyat,kira,t,t+interval '7 days',t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,fiyat,t,p_tip||' il bazlı devlet emlak alımı');
 return jsonb_build_object('tamam',true,'mulk_id',yeni,'fiyat',fiyat,'haftalik',kira,'il_id',p_il);
end $$;
revoke all on function public.mulk_satin_al_il(smallint,text) from public,anon;
grant execute on function public.mulk_satin_al_il(smallint,text) to authenticated;

-- Eski p_tip çağrısı açıksa bile il stok sınırını atlayamasın.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 if il is null then raise exception 'Önce bir ile kayıt ol.'; end if;
 perform public.mulk_satin_al_il(il,p_tip);
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function oyun.emlak_vergi_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record; b record; kac integer; oran numeric;t timestamptz:=oyun.simdi();
        tutar numeric; nakit numeric; odenen numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78115));
 -- Tahakkuk: İl bazında malik adına kaydedilir; satıştan sonra da eski borcu kalır.
 for m in select id,il_id,alis_bedeli,sonraki_emlak_vergi from oyun.yatirim_mulkleri
          where user_id=p_user and sonraki_emlak_vergi<=t order by id for update loop
   kac:=least(520,floor(extract(epoch from(t-m.sonraki_emlak_vergi))/604800)::integer+1);
   oran:=oyun.emlak_haftalik_oran(m.il_id);
   tutar:=case when oran>0 then greatest(1,round(m.alis_bedeli*oran/100))*kac else 0 end;
   if tutar>0 then
    insert into oyun.emlak_vergi_borc(user_id,il_id,borc,guncelleme)
    values(p_user,m.il_id,tutar,t)
    on conflict(user_id,il_id) do update
    set borc=oyun.emlak_vergi_borc.borc+excluded.borc,guncelleme=t;
   end if;
   update oyun.yatirim_mulkleri set sonraki_emlak_vergi=m.sonraki_emlak_vergi+make_interval(days=>kac*7) where id=m.id;
 end loop;
 -- Ödenemeyen kısmı borç olarak sakla, cüzdanı negatif yapma.
 for b in select * from oyun.emlak_vergi_borc where user_id=p_user and borc>0 order by il_id for update loop
   perform oyun.cuzdanim(p_user);
   select greatest(0,para) into nakit from oyun.cuzdan where user_id=p_user for update;
   odenen:=least(b.borc,coalesce(nakit,0));
   if odenen>0 then
    perform oyun.para_islem(p_user,-odenen,'emlak_vergisi',
      format('%s haftalık mülk vergisi',(select ad from oyun.iller where id=b.il_id)),t,odenen);
    update oyun.il_durum set kasa=kasa+odenen/1000000000.0 where il_id=b.il_id;
    update oyun.emlak_vergi_borc set borc=borc-odenen,guncelleme=t
      where user_id=p_user and il_id=b.il_id;
   end if;
 end loop;
end $$;
revoke all on function oyun.emlak_vergi_tahsil(uuid) from public,anon,authenticated;

create or replace function public.emlak_vergi_durum()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 perform oyun.emlak_vergi_tahsil(u);
 return jsonb_build_object('borc',coalesce((select sum(borc) from oyun.emlak_vergi_borc where user_id=u),0),
   'haftalik',coalesce((select sum(case when oyun.emlak_haftalik_oran(il_id)>0
    then greatest(1,round(alis_bedeli*oyun.emlak_haftalik_oran(il_id)/100)) else 0 end)
    from oyun.yatirim_mulkleri where user_id=u),0),
   'ulkede_oran',(select ulusal_oran from oyun.emlak_vergi_ayar where id=1),
   'iler',coalesce((select jsonb_agg(jsonb_build_object('il',i.ad,'borc',b.borc))
      from oyun.emlak_vergi_borc b join oyun.iller i on i.id=b.il_id where b.user_id=u and b.borc>0),'[]'::jsonb));
end $$;
revoke all on function public.emlak_vergi_durum() from public,anon;
grant execute on function public.emlak_vergi_durum() to authenticated;

create or replace function public.emlak_belediye_oran(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar:=oyun.baskan_zorunlu(p);
 t timestamptz:=oyun.simdi();son timestamptz;v numeric;
begin
 v:=round(p_oran,2);
 if v is null or v<0 or v>2 then raise exception 'Haftalık emlak vergisi oranı %%0–%%2 aralığında olmalı.'; end if;
 select degisme into son from oyun.il_emlak_vergi where il_id=m.il_id;
 if son is not null and son>t-interval '24 hours' then raise exception 'Vergi oranını 24 saatte yalnızca bir kez değiştirebilirsin.'; end if;
 insert into oyun.il_emlak_vergi(il_id,oran,baskan,degisme) values(m.il_id,v,p.id,t)
 on conflict(il_id) do update set oran=excluded.oran,baskan=excluded.baskan,degisme=t;
 perform oyun.olay('belediye',format('%s Belediye Başkanı haftalık mülk vergisini %%%s yaptı.',
  (select ad from oyun.iller where id=m.il_id),v),m.il_id,p.parti_id,t);
 return jsonb_build_object('il_id',m.il_id,'oran',v);
end $$;
revoke all on function public.emlak_belediye_oran(numeric) from public,anon;
grant execute on function public.emlak_belediye_oran(numeric) to authenticated;

create or replace function public.emlak_vergisi_kanun_teklif(p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();
 s record;newid bigint;oran numeric:=round(p_oran,2);
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri kanun önerisi sunabilir.'; end if;
 if oran is null or oran<0 or oran>2 then raise exception 'Haftalık vergi %%0-%%2 arasında olmalı.'; end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then raise exception 'TBMM Başkanı kanun teklifi veremez.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then raise exception 'Önce açık kanun teklifinin sonuçlanması gerekli.'; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',format('Haftalık Emlak Vergisi %%%s Kanunu',oran),
 'Türkiye genelindeki yeni ve mevcut yatırım mülklerinde haftalık emlak vergisi oranını belirler. Ödenen vergi ilgili il belediyesinin kasasına gider.',
 jsonb_build_object('ozel_tur','emlak_haftalik_vergi','oran',oran),p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama)
 returning id into newid;
 perform oyun.olay('meclis',format('%s, haftalık emlak vergisini %%%s yapma kanunu sundu.',p.kad,oran),null,p.parti_id,t);
 return jsonb_build_object('id',newid,'oran',oran);
end $$;
revoke all on function public.emlak_vergisi_kanun_teklif(numeric) from public,anon;
grant execute on function public.emlak_vergisi_kanun_teklif(numeric) to authenticated;

create or replace function oyun.emlak_kanun_yururluk()
returns trigger language plpgsql security definer set search_path='' as $$
declare yeni_oran numeric;
begin
 if new.durum='yururlukte' and old.durum is distinct from 'yururlukte'
    and new.veri->>'ozel_tur'='emlak_haftalik_vergi' then
   yeni_oran:=(new.veri->>'oran')::numeric;
   if yeni_oran is null or yeni_oran<0 or yeni_oran>2 then raise exception 'Hatalı kanun oranı.'; end if;
   update oyun.emlak_vergi_ayar set ulusal_oran=yeni_oran,degisme=coalesce(new.sonuc_at,oyun.simdi()) where id=1;
   perform oyun.olay('ekonomi',format('TBMM haftalık emlak vergisinin ülke genelindeki temel oranını %%%s olarak kabul etti.',yeni_oran),null,new.teklif_parti,coalesce(new.sonuc_at,oyun.simdi()));
 end if;
 return new;
end $$;
drop trigger if exists emlak_kanun_yururluk on oyun.kanunlar;
create trigger emlak_kanun_yururluk after update of durum on oyun.kanunlar
 for each row execute function oyun.emlak_kanun_yururluk();

-- Gelecekteki seçimlerde 600 sandalye; salt çoğunluk mevcut görevdeki vekiller üzerinden.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
commit;