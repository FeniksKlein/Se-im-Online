-- 2026-10-09: illere göre sınırlı emlak, belediye emlak vergisi, 600 MV ve fiili çoğunluk
-- Mevcut mülkleri / seçim sonuçlarını silmez.
-- Stok nüfus vekil ağırlığından türetilir; her il her mülk türünde ayrı limite sahiptir.

create or replace function oyun.emlak_kapasite(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case p_tip when 'daire' then
  least(100,greatest(8,ceil(i.mv*1.05)::int))
 when 'dukkan' then greatest(3,ceil(least(100,greatest(8,ceil(i.mv*1.05)::int))*.35)::int)
 when 'villa' then greatest(2,ceil(least(100,greatest(8,ceil(i.mv*1.05)::int))*.15)::int)
 else 0 end from oyun.iller i where i.id=p_il
$$;
create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else 0 end)
 * (0.62 + least(i.mv/96.0,1)*.95 + least(100,greatest(0,coalesce(d.gelisim,50)))/250.0))
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_vergi_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select greatest(0,least(300,coalesce(
   (select deger from oyun.il_duzenleme where il_id=p_il and kod='emlak'),
   (select deger from oyun.duzenlemeler where kod='emlak'),
   50
 ))) / 10000.0
$$;
create or replace function public.emlak_iller()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',i.id,'ad',i.ad,'gelisim',coalesce(d.gelisim,50),'emlak_vergi',round(oyun.emlak_vergi_oran(i.id)*100,2),
   'mulkler',(select jsonb_agg(jsonb_build_object(
    'tur',tip.tur,'ad',tip.ad,'kapasite',oyun.emlak_kapasite(i.id,tip.tur),
    'satildi',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=tip.tur),
    'kalan',greatest(0,oyun.emlak_kapasite(i.id,tip.tur)-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=tip.tur)),
    'fiyat',oyun.emlak_fiyat(i.id,tip.tur),
    'kira',round(oyun.emlak_fiyat(i.id,tip.tur)*.025)
   ) order by tip.sira) from (values ('daire','Daire',1),('dukkan','Dükkân',2),('villa','Villa',3)) tip(tur,ad,sira))
 ) order by i.mv desc,i.ad),'[]'::jsonb)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_iller() from public,anon;
grant execute on function public.emlak_iller() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric;
  t timestamptz:=oyun.simdi(); yeni bigint; stok int; alinmis int;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into p from oyun.profiller where id=u;
 if p.id is null or p.yasakli then raise exception 'Geçerli oyuncu profili gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists (select 1 from oyun.iller where id=p_il) then raise exception 'Geçerli bir il seçmelisin.'; end if;
 perform pg_advisory_xact_lock(822100+p_il::int,case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 stok:=oyun.emlak_kapasite(p_il,p_tip);
 select count(*) into alinmis from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if alinmis>=stok then raise exception 'Bu ilde satılabilecek yeni % kalmadı (%/%). Başka il seç veya bir oyuncunun ilanını incele.',p_tip,alinmis,stok; end if;
 bedel:=oyun.emlak_fiyat(p_il,p_tip); kira:=round(bedel*.025,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s satın alındı',(select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,format('Devlet emlağı: il #%s %s',p_il,p_tip));
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;

-- Eski tek parametreli RPC sınırı geçemesin: profilin iline göre aynı stok kuralı.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al_il(p_tip,p.il_id);
end $$;

-- Kira ve belediye emlak vergisi aynı 7 günlük döngüde tek seferde işlenir.
-- Vergi kiradan kesilir; negatif cüzdan oluşmaz, il bütçesine işlenir.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;tax numeric;tax_mulk numeric;tax_coklu numeric;
  t timestamptz:=oyun.simdi();rate numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
   n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
   gross:=round(m.haftalik_kira*n,2);
   tax_coklu:=case when (select count(*) from oyun.yatirim_mulkleri x
      where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
      then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
   rate:=oyun.emlak_vergi_oran(m.il_id);
   tax_mulk:=least(greatest(0,gross-tax_coklu),round(m.alis_bedeli*rate*n,2));
   tax:=tax_coklu+tax_mulk;
   perform oyun.para_islem(p_user,gross-tax,'kira',
     format('Mülk #%s: %s haftalık kira, belediye emlak vergisi %s TL, diğer vergi %s TL',m.id,n,tax_mulk,tax_coklu),t,tax);
   if tax_coklu>0 then update oyun.ulke set hazine=hazine+tax_coklu/1000000.0 where id=1; end if;
   if tax_mulk>0 then update oyun.il_durum set kasa=kasa+tax_mulk/1000000.0 where il_id=m.il_id; end if;
   update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
      toplam_kira=toplam_kira+gross-tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

-- TBMM anayasal kapasitesi 600 kalırken yalnızca fiilen seçilmiş vekiller çoğunlukta sayılır.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
