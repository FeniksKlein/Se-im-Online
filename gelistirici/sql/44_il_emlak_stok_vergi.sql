-- 2026-10-09 | İl bazlı sınırlı emlak stoğu, dinamik bedel, haftalık belediye mülk vergisi
-- Nüfus göstergesi olarak 600 MV kontenjanındaki il ağırlıkları kullanılır.
-- Eski mülklerin sahibi/kira tutarı korunur; yeni vergi dönemi ilk uygulamadan 7 gün sonra başlar.
alter table oyun.yatirim_mulkleri add column if not exists vergi_sonraki timestamptz;
alter table oyun.yatirim_mulkleri add column if not exists vergi_borc numeric not null default 0;
update oyun.yatirim_mulkleri set vergi_sonraki=oyun.simdi()+interval '7 days' where vergi_sonraki is null;
alter table oyun.yatirim_mulkleri alter column vergi_sonraki set not null;

insert into oyun.duzenleme_tanim
(kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values
('mulk_vergi_ulusal','ulke','Haftalık mülk vergisi','yuzde',0.30,0.05,1.00,0.05,'gelir',
 'Meclis tarafından belirlenen haftalık mülk vergisi oranı. İllerde belediye çarpanı ile uygulanır.',
 'Sahip olduğun mülklerin alış bedeli üzerinden haftalık vergi kesilir; mülkün bulunduğu belediye kazanır.',
 'Mülk vergileri devlet hazinesine değil, taşınmazın bulunduğu belediye kasasına aktarılır.',21),
('mulk_vergi_yerel','il','Belediye mülk vergisi çarpanı','yuzde',100,50,200,10,'gelir',
 'Ülke genelindeki haftalık mülk vergisinin bu ilde uygulanacak çarpanı. 100 değişiklik yok, 150 vergi yüzde 50 artar.',
 'İldeki mülklerin vergi bedeli değişir; oyuncu başka ilde yaşasa da mülk bu ilde vergilendirilir.',
 'Vergi geliri doğrudan bu ilin belediye kasasına aktarılır.',22)
on conflict(kod) do nothing;

create or replace function oyun.mulk_il_kota(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case p_tip
  when 'daire' then 8 + round((greatest(1,i.mv)-1)*92.0/95)::int
  when 'dukkan' then 3 + round((greatest(1,i.mv)-1)*32.0/95)::int
  when 'villa' then 2 + round((greatest(1,i.mv)-1)*18.0/95)::int
  else 0 end
 from oyun.iller i where i.id=p_il
$$;

create or replace function oyun.mulk_il_bedel(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
       * (0.55 + 1.10*sqrt(greatest(1,i.mv)::numeric/96.0))
       * (0.75 + greatest(0,least(100,d.gelisim))/200.0),0)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;

create or replace function oyun.mulk_il_kira(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round(oyun.mulk_il_bedel(p_il,p_tip)*0.025*(0.80+greatest(0,least(100,d.gelisim))/250.0),0)
 from oyun.il_durum d where d.il_id=p_il
$$;

create or replace function oyun.mulk_haftalik_vergi(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare x record; t timestamptz:=oyun.simdi(); donem integer; tahakkuk numeric; odeme numeric; hazir numeric;
begin
 -- Ana kira tahsil işlevi ayrı kilidi zaten alıyor. Tekrarlı çalıştırmada dönem yeniden tahakkuk etmez.
 for x in select m.*,i.ad il_ad
    from oyun.yatirim_mulkleri m join oyun.iller i on i.id=m.il_id
    where m.user_id=p_user and (m.vergi_sonraki<=t or m.vergi_borc>0)
    order by m.id for update of m loop
   donem:=case when x.vergi_sonraki<=t then least(520,floor(extract(epoch from(t-x.vergi_sonraki))/604800)::int+1) else 0 end;
   tahakkuk:=round(x.alis_bedeli*coalesce(oyun.duz('mulk_vergi_ulusal'),0.30)/100
      * coalesce(oyun.il_duz(x.il_id,'mulk_vergi_yerel'),100)/100*donem,0);
   hazir:=greatest(0,coalesce((select para from oyun.cuzdan where user_id=p_user),0));
   odeme:=least(round(x.vergi_borc+tahakkuk,0),floor(hazir));
   update oyun.yatirim_mulkleri set
    vergi_borc=greatest(0,x.vergi_borc+tahakkuk-odeme),
    vergi_sonraki=x.vergi_sonraki+make_interval(days=>donem*7)
   where id=x.id;
   if odeme>0 then
     perform oyun.para_islem(p_user,-odeme,'emlak_vergi',
       format('%s mülk #%s haftalık emlak vergisi (%s dönem)',x.il_ad,x.id,donem),t,odeme);
     update oyun.il_durum set kasa=coalesce(kasa,0)+odeme/1000000.0 where il_id=x.il_id;
   end if;
 end loop;
end $$;
revoke all on function oyun.mulk_haftalik_vergi(uuid) from public,anon,authenticated;

create or replace function public.mulk_il_stok()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'il_id',i.id,'il',i.ad,'nufus_olcegi',i.mv,'gelisim',d.gelisim,
  'urunler',(select jsonb_agg(jsonb_build_object('tip',v.tip,
    'kontenjan',oyun.mulk_il_kota(i.id,v.tip),
    'sahipli',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=v.tip),
    'kalan',greatest(0,oyun.mulk_il_kota(i.id,v.tip)-
       (select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=v.tip)),
    'fiyat',oyun.mulk_il_bedel(i.id,v.tip),
    'kira',oyun.mulk_il_kira(i.id,v.tip)) order by v.sira)
    from (values('daire',1),('dukkan',2),('villa',3)) v(tip,sira)),
  'haftalik_vergi_oran',round(oyun.duz('mulk_vergi_ulusal')*oyun.il_duz(i.id,'mulk_vergi_yerel')/100,3)
 ) order by i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.mulk_il_stok() from public,anon;
grant execute on function public.mulk_il_stok() to authenticated;

create or replace function public.mulk_il_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); c oyun.iller; f numeric;k numeric; yeni bigint; mevcut int;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oyuncu profili gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if p_il is null then raise exception 'Satın alacağın ili seç.'; end if;
 select * into c from oyun.iller where id=p_il for update;
 if c.id is null then raise exception 'İl bulunamadı.'; end if;
 select count(*) into mevcut from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if mevcut>=oyun.mulk_il_kota(p_il,p_tip) then
   raise exception '% ilinde % için satılık yeni mülk stoğu tükendi. Oyuncu ilanlarını inceleyebilirsin.',c.ad,p_tip;
 end if;
 f:=oyun.mulk_il_bedel(p_il,p_tip);k:=oyun.mulk_il_kira(p_il,p_tip);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-f,'emlak',format('%s: %s yeni mülk satın alındı',c.ad,p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,vergi_sonraki)
 values(u,p_il,p_tip,f,k,t,t+interval '7 days',t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,f,t,format('%s ilinden %s satın alındı',c.ad,p_tip));
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_il_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_il_satin_al(text,smallint) to authenticated;

-- Eski API'den kapasite ve il fiyatını baypas etmeyi kapat.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select p.il_id into il from oyun.profiller p where p.id=auth.uid();
 return public.mulk_il_satin_al(p_tip,il);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Haftalık vergi, kira tahsilinde ve oyuncu mülklerini kontrol ederken işler.
