-- İl bazında emlak stoku, değerleme ve belediyeye haftalık emlak vergisi
-- Mevcut mülkleri ve kira kayıtlarını korur.
create table if not exists oyun.emlak_vergi_ayar (
 id smallint primary key check(id=1),
 oran numeric not null default 0.10 check(oran between 0 and 0.50),
 guncelleme timestamptz not null default now()
);
insert into oyun.emlak_vergi_ayar(id,oran) values (1,0.10) on conflict(id) do nothing;
create table if not exists oyun.emlak_vergi_il (
 il_id smallint primary key references oyun.iller(id),
 carpan numeric not null default 100 check (carpan between 50 and 200),
 baskan uuid references oyun.profiller(id),
 guncelleme timestamptz not null default now()
);
alter table oyun.emlak_vergi_ayar enable row level security;
alter table oyun.emlak_vergi_il enable row level security;
revoke all on oyun.emlak_vergi_ayar from public,anon,authenticated;
revoke all on oyun.emlak_vergi_il from public,anon,authenticated;

create or replace function oyun.emlak_stok(p_il smallint,p_tip text)
returns integer language sql stable security definer set search_path='' as $$
 with sehir as (select mv from oyun.iller where id=p_il)
 select case when p_tip='daire' then taban
   when p_tip='dukkan' then greatest(2,round(taban*.45)::int)
   when p_tip='villa' then greatest(1,round(taban*.20)::int)
   else 0 end
 from (select 8+round(92*(mv-1)::numeric/95)::int taban from sehir) z
$$;
create or replace function oyun.emlak_bedel(p_il smallint,p_tip text)
returns numeric language sql stable security definer set search_path='' as $$
 select round((case p_tip when 'daire' then 130000
    when 'dukkan' then 260000 when 'villa' then 520000 else 0 end) *
    greatest(.55,least(2.65,.65+1.45*sqrt(i.mv::numeric/96)
         +(coalesce(d.gelisim,50)-50)/200)),0)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_oran(p_il smallint)
returns numeric language sql stable security definer set search_path='' as $$
 select round((select oran from oyun.emlak_vergi_ayar where id=1)*
  coalesce((select carpan from oyun.emlak_vergi_il where il_id=p_il),100)/100,4)
$$;
create or replace function public.emlak_piyasa()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Oturum açmalısın.'; end if;
 return jsonb_build_object(
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,
    'emlak_vergi',oyun.emlak_oran(i.id),'emlak_carpan',coalesce(t.carpan,100),
    'daire',jsonb_build_object('bedel',oyun.emlak_bedel(i.id,'daire'),'kira',round(oyun.emlak_bedel(i.id,'daire')*.025),
      'toplam',oyun.emlak_stok(i.id,'daire'),'kalan',greatest(0,oyun.emlak_stok(i.id,'daire')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire'))),
    'dukkan',jsonb_build_object('bedel',oyun.emlak_bedel(i.id,'dukkan'),'kira',round(oyun.emlak_bedel(i.id,'dukkan')*.025),
      'toplam',oyun.emlak_stok(i.id,'dukkan'),'kalan',greatest(0,oyun.emlak_stok(i.id,'dukkan')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan'))),
    'villa',jsonb_build_object('bedel',oyun.emlak_bedel(i.id,'villa'),'kira',round(oyun.emlak_bedel(i.id,'villa')*.025),
      'toplam',oyun.emlak_stok(i.id,'villa'),'kalan',greatest(0,oyun.emlak_stok(i.id,'villa')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa')))
   ) order by i.ad) from oyun.iller i left join oyun.emlak_vergi_il t on t.il_id=i.id),'[]'::jsonb),
 'ulusal_emlak_vergi',(select oran from oyun.emlak_vergi_ayar where id=1));
end $$;
revoke all on function public.emlak_piyasa() from public,anon;
grant execute on function public.emlak_piyasa() to authenticated;

-- Emlak varlıklarının şehirler arasında alımı mümkündür. Satışlar kilitlenerek stok aşımı önlenir.
create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric;
  t timestamptz:=oyun.simdi(); yeni bigint; stok int; alinmis int;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Aktif oyuncu hesabı gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl bulunamadı.'; end if;
 perform pg_advisory_xact_lock(68742,hashtext(p_il::text||':'||p_tip));
 stok:=oyun.emlak_stok(p_il,p_tip);
 select count(*) into alinmis from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if alinmis>=stok then raise exception 'Bu ilde % stoku tükendi. Oyuncuların satış ilanlarına bakabilirsin.',p_tip; end if;
 bedel:=oyun.emlak_bedel(p_il,p_tip);
 kira:=round(bedel*.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s alımı', (select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
-- Eski istemciyle yapılan satın alımlar da şehir stokuna ve yeni fiyatlara tabidir.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare sehir smallint;
begin
 select il_id into sehir from oyun.profiller where id=auth.uid();
 if sehir is null then raise exception 'Önce profil oluşturmalısın.'; end if;
 return public.mulk_satin_al(p_tip,sehir);
end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;

-- Biriken 7 günlük kirayı tahsil ederken her hafta için emlak vergisini belediyeye aktar.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric; t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
   n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
   gross:=round(m.haftalik_kira*n,2);
   tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
             and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
      then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
   emlak_tax:=round(m.alis_bedeli*oyun.emlak_oran(m.il_id)/100*n,2);
   -- Eski mülklerde de kira bakiyesi korunur. Vergi negatif cüzdan oluşturmaz.
   perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',
      format('Mülk #%s: %s haftalık kira, gelir vergisi %s, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),
      t,tax+emlak_tax);
   if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000.0 where id=1;end if;
   if emlak_tax>0 then
     update oyun.il_durum set kasa=coalesce(kasa,0)+emlak_tax/1000000.0 where il_id=m.il_id;
   end if;
   update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
        toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

create or replace function public.emlak_vergi_belediye_ayarla(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar;
  son timestamptz; t timestamptz:=oyun.simdi();
begin
 select * into m from oyun.makamlar where user_id=p.id and tur='bel' and bit is null order by bas desc limit 1;
 if m.id is null then raise exception 'Yalnızca görevdeki belediye başkanı oran değiştirebilir.'; end if;
 if p_carpan is null or p_carpan<50 or p_carpan>200 or p_carpan<>round(p_carpan) then
  raise exception 'Emlak vergisi katsayısı %50–%200 arasında olmalı.'; end if;
 select guncelleme into son from oyun.emlak_vergi_il where il_id=m.il_id;
 if son is not null and son>t-interval '24 hours' then
   raise exception 'Emlak vergisi oranı 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_vergi_il(il_id,carpan,baskan,guncelleme)
 values(m.il_id,p_carpan,p.id,t)
 on conflict(il_id) do update set carpan=excluded.carpan,baskan=excluded.baskan,guncelleme=excluded.guncelleme;
 perform oyun.olay('belediye',format('%s Belediyesi emlak vergisi yerel katsayısını %%%s yaptı.',(select ad from oyun.iller where id=m.il_id),p_carpan),m.il_id,p.parti_id,t);
 return jsonb_build_object('carpan',p_carpan,'toplam_oran',oyun.emlak_oran(m.il_id),'il_id',m.il_id);
end $$;
revoke all on function public.emlak_vergi_belediye_ayarla(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayarla(numeric) to authenticated;

-- Milletvekili teklif eder; olağan TBMM oylamasından geçince ulusal emlak vergisi değişir.
create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); s record; yeni bigint;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Kanun teklifini milletvekilleri verebilir.'; end if;
 if p_oran is null or p_oran<0 or p_oran>0.50 then raise exception 'Haftalık emlak vergisi %%0–%%0,50 arasında olmalı.'; end if;
 if length(btrim(coalesce(p_baslik,''))) not between 5 and 120 then raise exception 'Kanun başlığı 5–120 karakter olmalı.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
   raise exception 'Önceki kanun teklifin henüz sonuçlanmadı.'; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',btrim(p_baslik),oyun.metin_temizle(p_metin,3000),
   jsonb_build_object('ozel_tur','emlak_vergi','deger',round(p_oran,2)),
   p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama) returning id into yeni;
 return jsonb_build_object('id',yeni,'oran',round(p_oran,2));
end $$;
create or replace function oyun.emlak_vergi_kanun_yururluk()
returns trigger language plpgsql security definer set search_path='' as $$
declare oran numeric;
begin
 if new.durum='yururlukte' and old.durum is distinct from 'yururlukte'
    and new.veri->>'ozel_tur'='emlak_vergi' then
    oran:=(new.veri->>'deger')::numeric;
    if oran is null or oran<0 or oran>0.50 then raise exception 'Geçersiz emlak vergisi kanunu.';end if;
    update oyun.emlak_vergi_ayar set oran=oran,guncelleme=oyun.simdi() where id=1;
    perform oyun.olay('ekonomi',format('Meclis ulusal haftalık emlak vergisini %%%s olarak belirledi.',oran),null,new.teklif_parti,oyun.simdi());
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_yururluk on oyun.kanunlar;
create trigger emlak_vergi_kanun_yururluk after update of durum on oyun.kanunlar
 for each row execute function oyun.emlak_vergi_kanun_yururluk();
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text,text) to authenticated;

-- Oyunda 600 TBMM sandalyesi. Yalnızca fiilen seçilmiş vekiller oy kullanabilir.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
create or replace function oyun.meclis_olcek_hesap(t timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('aktif',
   (select count(*) from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days'),
   'sandalye',600,'anayasal',600,'olcek',0)
$$;
