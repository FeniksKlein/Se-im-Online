-- 2026-10-09 | Il bazli sinirli emlak, haftalik belediye vergisi ve TBMM vekil olcegi.
-- Mevcut tapular, cuzdanlar ve aktif vekillikler korunur.
create table if not exists oyun.emlak_vergi_ayar(
 id integer primary key check (id=1),
 ulusal_oran numeric not null default 0.50 check (ulusal_oran between 0 and 1),
 baslangic timestamptz not null default now(),
 degisiklik timestamptz not null default now()
);
insert into oyun.emlak_vergi_ayar(id,ulusal_oran,baslangic,degisiklik)
values(1,0.50,oyun.simdi(),oyun.simdi()) on conflict(id) do nothing;

create table if not exists oyun.emlak_vergi_il(
 il_id smallint primary key references oyun.iller(id),
 ek_oran numeric not null default 0 check(ek_oran between -0.25 and 0.25),
 baskan uuid references oyun.profiller(id),
 degisiklik timestamptz not null default now()
);
alter table oyun.yatirim_mulkleri add column if not exists emlak_vergi_sonraki timestamptz;
update oyun.yatirim_mulkleri set emlak_vergi_sonraki=oyun.simdi()+interval '7 days'
where emlak_vergi_sonraki is null;
alter table oyun.yatirim_mulkleri alter column emlak_vergi_sonraki set not null;

alter table oyun.emlak_vergi_ayar enable row level security;
alter table oyun.emlak_vergi_il enable row level security;
revoke all on oyun.emlak_vergi_ayar from public,anon,authenticated;
revoke all on oyun.emlak_vergi_il from public,anon,authenticated;

create or replace function oyun.emlak_vergi_orani(p_il smallint) returns numeric
language sql stable set search_path='' as $$
 select greatest(0,least(1,
  (select ulusal_oran from oyun.emlak_vergi_ayar where id=1)
  +coalesce((select ek_oran from oyun.emlak_vergi_il where il_id=p_il),0)))
$$;

-- Oyundaki il milletvekili dagilimi nufus buyuklugunun vekil agirlikli gostergesidir.
-- 96 vekil: 100 daire, 1 vekil: 8 daire; dukkan ve villa stoklari ayridir.
create or replace function oyun.emlak_kapasite(p_il smallint,p_tip text) returns integer
language sql stable set search_path='' as $$
 select greatest(1,
 case p_tip when 'daire' then 8 when 'dukkan' then 2 when 'villa' then 2 else 0 end +
 round((greatest(1,i.mv)-1)::numeric / 95 *
  (case p_tip when 'daire' then 92 when 'dukkan' then 28 when 'villa' then 18 else 0 end)
  *(1+(coalesce(d.gelisim,50)-50)/500.0))::int)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;

create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round(
 (case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end)
 *(0.62+2.15*greatest(1,i.mv)/96.0)
 *(0.8+coalesce(d.gelisim,50)/250.0)
 ,0)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_kira(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round(oyun.emlak_fiyat(p_il,p_tip)*0.025,0)
$$;

create or replace function public.emlak_il_stok() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Giriş yapmalısın.'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'il_id',a.il_id,'il',a.ad,'tur',a.tip,'kapasite',a.kapasite,'satilan',a.satilan,
  'kalan',greatest(0,a.kapasite-a.satilan),'fiyat',oyun.emlak_fiyat(a.il_id,a.tip),
  'haftalik',oyun.emlak_kira(a.il_id,a.tip),'vergi_orani',oyun.emlak_vergi_orani(a.il_id),
  'haftalik_vergi',round(oyun.emlak_fiyat(a.il_id,a.tip)*oyun.emlak_vergi_orani(a.il_id)/100,0)
 ) order by a.ad,a.tip) from (
  select i.id il_id,i.ad,tip,oyun.emlak_kapasite(i.id,tip) kapasite,
    (select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=tip) satilan
  from oyun.iller i cross join (values('daire'),('dukkan'),('villa')) t(tip)
 ) a),'[]'::jsonb);
end $$;
revoke all on function public.emlak_il_stok() from public,anon;
grant execute on function public.emlak_il_stok() to authenticated;

-- Eski cagrilar kendi ilinden satin alir; yeni istemci tum 81 ilden alabilir.
create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric;
 t timestamptz:=oyun.simdi(); yeni_mulk_id bigint; cap int; n int;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Geçerli bir oyuncu profili gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçersiz il.'; end if;
 perform pg_advisory_xact_lock(77124,p_il::int*10+
  case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 cap:=oyun.emlak_kapasite(p_il,p_tip);
 select count(*) into n from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if n>=cap then raise exception 'Bu şehirde satılabilir % stoku doldu.',p_tip; end if;
 bedel:=oyun.emlak_fiyat(p_il,p_tip);
 kira:=oyun.emlak_kira(p_il,p_tip);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s / %s devlet gayrimenkul alımı',p_tip,(select ad from oyun.iller where id=p_il)),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,emlak_vergi_sonraki)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days',t+interval '7 days')
 returning id into yeni_mulk_id;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni_mulk_id,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;

create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language sql security definer set search_path='' as $$
 select public.mulk_satin_al(p_tip,(select il_id from oyun.profiller where id=auth.uid()))
$$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.emlak_vergi_durum(p_il smallint default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare il smallint;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
 il:=coalesce(p_il,(select il_id from oyun.profiller where id=auth.uid()));
 return jsonb_build_object('ulusal',(select ulusal_oran from oyun.emlak_vergi_ayar where id=1),
 'yerel',coalesce((select ek_oran from oyun.emlak_vergi_il where il_id=il),0),
 'toplam',oyun.emlak_vergi_orani(il),'il',il,
 'baskan_miyim',exists(select 1 from oyun.makamlar where user_id=auth.uid() and tur='bel' and il_id=il and bit is null),
 'son',(select degisiklik from oyun.emlak_vergi_il where il_id=il));
end $$;
revoke all on function public.emlak_vergi_durum(smallint) from public,anon;
grant execute on function public.emlak_vergi_durum(smallint) to authenticated;

create or replace function public.emlak_vergi_belediye(p_ek_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar:=oyun.baskan_zorunlu(p); oldt timestamptz;
 t timestamptz:=oyun.simdi();
begin
 if p_ek_oran is null or p_ek_oran<>round(p_ek_oran,2) or p_ek_oran not between -0.25 and 0.25 then
  raise exception 'Belediyenin yetkisi ulusal orana -0,25 ile +0,25 puan eklemektir.'; end if;
 select degisiklik into oldt from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if oldt>t-interval '24 hours' then raise exception 'Emlak vergisi 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_vergi_il(il_id,ek_oran,baskan,degisiklik)
 values(m.il_id,p_ek_oran,p.id,t)
 on conflict(il_id) do update set ek_oran=excluded.ek_oran,baskan=excluded.baskan,degisiklik=excluded.degisiklik;
 perform oyun.olay('belediye',format('%s Belediye Başkanı haftalık emlak vergisini %s olarak belirledi.',
 (select ad from oyun.iller where id=m.il_id),oyun.emlak_vergi_orani(m.il_id)),m.il_id,p.parti_id,t);
 return public.emlak_vergi_durum(m.il_id);
end $$;
revoke all on function public.emlak_vergi_belediye(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye(numeric) to authenticated;

create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); su record; bid bigint;
 bas text:=btrim(coalesce(p_baslik,'')); gerekce text;
begin
 if not oyun.aktif_vekil(p.id) or exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null)
 then raise exception 'Yalnızca oy kullanabilen milletvekilleri teklif verebilir.'; end if;
 if p_oran is null or p_oran<>round(p_oran,2) or p_oran not between 0 and 1 then raise exception 'Haftalık emlak vergisi %%0-%%1 arasında olmalıdır.'; end if;
 if length(bas) not between 5 and 120 or oyun.kufurlu(bas) then raise exception 'Geçersiz kanun başlığı.'; end if;
 gerekce:=oyun.metin_temizle(p_metin,3000);
 if length(gerekce)<10 then raise exception 'Gerekçe en az 10 karakter olmalı.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr'))
 then raise exception 'Sonuçlanmamış bir teklifin var.'; end if;
 select * into su from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',bas,gerekce,jsonb_build_object('ozel_tur','emlak_vergisi','oran',p_oran),
 p.id,p.parti_id,t,t+su.gorusme,t+su.gorusme+su.oylama) returning id into bid;
 perform oyun.olay('meclis',format('%s haftalık emlak vergisini %s yapacak kanunu sundu.',p.kad,p_oran),null,p.parti_id,t);
 return jsonb_build_object('id',bid,'oran',p_oran);
end $$;
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text,text) to authenticated;

create or replace function oyun.emlak_vergi_kanun_yururluk() returns trigger
language plpgsql security definer set search_path='' as $$
declare o numeric;
begin
 if old.durum<>'yururlukte' and new.durum='yururlukte'
 and new.veri->>'ozel_tur'='emlak_vergisi' then
  o:=(new.veri->>'oran')::numeric;
  if o is null or o<0 or o>1 then raise exception 'Geçersiz emlak vergisi kanunu.'; end if;
  update oyun.emlak_vergi_ayar set ulusal_oran=o,degisiklik=oyun.simdi() where id=1;
  perform oyun.olay('meclis',format('TBMM haftalık emlak vergisi ulusal tabanını %s yaptı.',o),null,new.teklif_parti,oyun.simdi());
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_aktif on oyun.kanunlar;
create trigger emlak_vergi_kanun_aktif after update of durum on oyun.kanunlar
for each row execute function oyun.emlak_vergi_kanun_yururluk();

-- Yeniden ölçeklendirmeyi kapat: teorik sandalye sayısı 600, gerçek doluluk oyunculara bağlı.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);


create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare m record; n int; n_tax int; gross numeric; income_tax numeric; emlak_tax numeric;
 t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user
  and (sonraki_kira<=t or emlak_vergi_sonraki<=t) order by id for update loop
   n:=case when m.sonraki_kira<=t then least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1) else 0 end;
   n_tax:=case when m.emlak_vergi_sonraki<=t then least(520,floor(extract(epoch from (t-m.emlak_vergi_sonraki))/604800)::int+1) else 0 end;
   gross:=round(m.haftalik_kira*n,2);
   income_tax:=case when (select count(*) from oyun.yatirim_mulkleri x
    where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
    then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
   emlak_tax:=round(m.alis_bedeli*oyun.emlak_vergi_orani(m.il_id)/100*n_tax,0);
   if n>0 or n_tax>0 then
    perform oyun.para_islem(p_user,gross-income_tax-emlak_tax,'kira',
     format('Mulk #%s: %s haftalik kira (%s ₺) / %s haftalik belediye emlak vergisi (%s ₺)',
       m.id,n,gross,n_tax,emlak_tax),t,income_tax);
   end if;
   if income_tax>0 then update oyun.ulke set hazine=hazine+income_tax/1000000 where id=1;end if;
   if emlak_tax>0 then
    update oyun.il_durum set kasa=kasa+emlak_tax/1000000000.0 where il_id=m.il_id;
    perform oyun.para_islem(p_user,0,'emlak_vergi',
      format('Mulk #%s · %s Belediyesi: %s hafta emlak vergisi: %s TL',
       m.id,(select ad from oyun.iller where id=m.il_id),n_tax,emlak_tax),t,emlak_tax);
   end if;
   update oyun.yatirim_mulkleri
     set sonraki_kira=sonraki_kira+n*interval '7 days',
       emlak_vergi_sonraki=emlak_vergi_sonraki+n_tax*interval '7 days',
       toplam_kira=toplam_kira+gross-income_tax-emlak_tax,
       kira_sayisi=kira_sayisi+n
     where id=m.id;
 end loop;
end $$;

CREATE OR REPLACE FUNCTION public.mulk_liste()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; j jsonb;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 perform oyun.mulk_kira_tahsil(u);
 select jsonb_build_object(
   'mulkler',coalesce(jsonb_agg(jsonb_build_object(
      'id',m.id,'tip',m.tip,'il',i.ad,'alis',m.alis_bedeli,
      'haftalik',m.haftalik_kira,'sonraki',m.sonraki_kira,
      'toplam_kira',m.toplam_kira,'kira_sayisi',m.kira_sayisi,
      'emlak_vergi_orani',oyun.emlak_vergi_orani(m.il_id),
      'emlak_vergi_haftalik',round(m.alis_bedeli*oyun.emlak_vergi_orani(m.il_id)/100,0),
      'emlak_vergi_sonraki',m.emlak_vergi_sonraki
   ) order by m.satin_alma desc,m.id desc),'[]'::jsonb),
   'adet',count(m.id),
   'haftalik_toplam',coalesce(sum(m.haftalik_kira),0),
   'mulk_degeri',coalesce(sum(m.alis_bedeli),0),
   'cuzdan',(select para from oyun.cuzdan where user_id=u)
 ) into j
 from oyun.yatirim_mulkleri m join oyun.iller i on i.id=m.il_id where m.user_id=u;
 return j;
end $function$


CREATE OR REPLACE FUNCTION oyun.kanun_tick(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare k oyun.kanunlar; c record; dolu int; cb uuid; s record;
begin
  select * into s from oyun.kanun_suresi();
  -- anayasa değişikliği: görüşme bitince imza sayısı dolu sandalyelerin üçte birine ulaşmadıysa teklif düşer
  for k in select * from oyun.kanunlar where durum = 'gorusmede' and tur = 'anayasa' and t >= oy_bas order by oy_bas loop
    dolu := oyun.dolu_sandalye();
    if (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza') < ceil(dolu / 3.0) then
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bas,
        sonuc_metin = format('Yeterli imza toplanamadı: %s imza, en az %s gerekliydi (dolu sandalyelerin üçte biri).',
                             (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza'), ceil(dolu / 3.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin yeterli imza toplayamadı.', k.baslik), k.oy_bas);
    end if;
  end loop;
  update oyun.kanunlar set durum = 'oylamada' where durum = 'gorusmede' and t >= oy_bas;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur = 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    cb := oyun.aktif_cb();
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then
      update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
        sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: üçte iki çoğunluk sağlandı.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.bildir(cb, format('"%s" anayasa değişikliği Meclis''ten üçte iki çoğunlukla geçti. 48 saat içinde yayımla ya da halkoyuna sun.', k.baslik), k.oy_bit);
      perform oyun.olay('meclis', format('"%s" anayasa değişikliği üçte iki çoğunlukla kabul edildi (%s kabul). Cumhurbaşkanına sunuldu.', k.baslik, c.kabul), null, k.teklif_parti, k.oy_bit);
    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      update oyun.kanunlar set sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.referandum_baslat(k.id, k.oy_bit);
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = format('Reddedildi: gizli oylamada %s kabul oyu çıktı; halkoyuna sunulması için en az %s (beşte üç) gerekliydi.', c.kabul, ceil(dolu * 3 / 5.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin Meclis''te gerekli çoğunluğu alamadı.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur <> 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul + c.ret + c.cekimser >= ceil(dolu / 3.0) and c.kabul > c.ret and c.kabul >= floor(dolu / 2.0) + 1 then
      cb := oyun.aktif_cb();
      if cb is null then
        perform oyun.kanun_yururluk(k.id, k.oy_bit, format('Meclis''te %s kabul, %s ret oyla kabul edildi (cumhurbaşkanı makamı boş).', c.kabul, c.ret));
      else
        update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
          sonuc_metin = format('Meclis''te %s kabul, %s ret, %s çekimser oyla kabul edildi.', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.bildir(cb, format('"%s" kanunu Meclis''ten geçti ve onayınızı bekliyor. 48 saat içinde onaylayın ya da veto edin.', k.baslik), k.oy_bit);
        perform oyun.olay('meclis', format('"%s" Meclis''te kabul edildi (%s kabul, %s ret). Cumhurbaşkanının onayına sunuldu.', k.baslik, c.kabul, c.ret), null, k.teklif_parti, k.oy_bit);
      end if;
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = case when c.kabul + c.ret + c.cekimser < ceil(dolu / 3.0) then format('Toplantı yeter sayısı sağlanamadı (%s vekil katıldı, en az %s gerekliydi).', c.kabul + c.ret + c.cekimser, ceil(dolu / 3.0))
                           else format('Reddedildi: %s kabul, %s ret, %s çekimser (kabul için en az %s ve retten fazla oy gerekliydi).', c.kabul, c.ret, c.cekimser, floor(dolu / 2.0) + 1) end
      where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" teklifin Meclis''te kabul edilmedi.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'cb_onayinda' and t >= cb_bit order by cb_bit loop
    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = 'anayasa' then 'Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.'
                                                    else 'Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.' end);
  end loop;
  for k in select * from oyun.kanunlar where durum = 'israr' and t >= israr_bit order by israr_bit loop
    select * into c from oyun.kanun_say(k.id, 'israr');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul >= floor(dolu / 2.0) + 1 then
      perform oyun.kanun_yururluk(k.id, k.israr_bit, format('Veto sonrası Meclis %s oyla ısrar etti.', c.kabul));
    else
      update oyun.kanunlar set durum = 'dustu', sonuc_at = k.israr_bit,
        sonuc_metin = format('Veto sonrası ısrar için %s oy gerekiyordu, %s kabul oyu çıktı. Kanun düştü.', floor(dolu / 2.0) + 1, c.kabul) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" veto sonrası ısrar oylamasında düştü.', k.baslik), k.israr_bit);
    end if;
  end loop;
  -- seçim döneminde kabul edilen baraj, seçim bitince uygulanır
  if (select bekleyen_baraj from oyun.ulke where id = 1) is not null
     and not exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                     where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor') then
    update oyun.ayarlar set baraj = (select bekleyen_baraj from oyun.ulke where id = 1) where id = 1;
    update oyun.ulke set bekleyen_baraj = null where id = 1;
  end if;
end $function$


CREATE OR REPLACE FUNCTION public.mulk_ilan_satin_al(p_ilan bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); a oyun.mulk_ilan%rowtype; m oyun.yatirim_mulkleri%rowtype;
 v_satis_vergisi numeric; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 select * into a from oyun.mulk_ilan where id=p_ilan for update;
 if not found or a.durum<>'acik' then raise exception 'İlan artık açık değil'; end if;
 if a.satici=u then raise exception 'Kendi mülkünü satın alamazsın'; end if;
 select * into m from oyun.yatirim_mulkleri where id=a.mulk_id for update;
 if not found or m.user_id<>a.satici then raise exception 'Satıcı artık mülkün sahibi değil'; end if;
 perform oyun.mulk_kira_tahsil(a.satici);
 v_satis_vergisi:=round(a.fiyat*0.02);
 perform oyun.para_islem(u,-a.fiyat,'emlak','Oyuncudan mülk satın alındı #'||a.mulk_id,t);
 perform oyun.para_islem(a.satici,a.fiyat-v_satis_vergisi,'emlak','Mülk satışı #'||a.mulk_id,t);
 update oyun.ulke set hazine=hazine+v_satis_vergisi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=u,satin_alma=t,alis_bedeli=a.fiyat,
   sonraki_kira=t+interval '7 days',emlak_vergi_sonraki=t+interval '7 days',toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=u,kapanma=t where id=a.id;
 perform oyun.bildir(a.satici,'Satıştaki mülkün satıldı. Satış vergisi %2.',t);
 return public.mulk_pazar();
end $function$


CREATE OR REPLACE FUNCTION oyun._emlak_pazarlik_tamamla(p_teklif bigint, p_fiyat numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare z oyun.emlak_pazarlik;i oyun.mulk_ilan; m oyun.yatirim_mulkleri;
  vergi numeric;t timestamptz:=oyun.simdi();
begin
 select * into z from oyun.emlak_pazarlik where id=p_teklif for update;
 if z.id is null or z.durum not in ('bekliyor','karsi') then raise exception 'Teklif artık geçerli değil.'; end if;
 if p_fiyat is null or p_fiyat<10000 or p_fiyat>1000000000 then raise exception 'Geçersiz teklif bedeli.'; end if;
 select * into i from oyun.mulk_ilan where id=z.ilan_id for update;
 if i.id is null or i.durum<>'acik' or i.satici<>z.satici then raise exception 'İlan artık geçerli değil.'; end if;
 select * into m from oyun.yatirim_mulkleri where id=i.mulk_id for update;
 if m.id is null or m.user_id<>i.satici then raise exception 'Mülk artık satışta değil.'; end if;
 if z.alici=z.satici then raise exception 'Kendi mülkünü alamazsın.'; end if;
 perform oyun.mulk_kira_tahsil(z.satici);
 vergi:=round(p_fiyat*0.02);
 perform oyun.para_islem(z.alici,-p_fiyat,'emlak','Pazarlıkla mülk satın alındı #'||i.mulk_id,t);
 perform oyun.para_islem(z.satici,p_fiyat-vergi,'emlak','Pazarlıkla mülk satışı #'||i.mulk_id,t);
 update oyun.ulke set hazine=hazine+vergi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=z.alici,satin_alma=t,alis_bedeli=p_fiyat,sonraki_kira=t+interval '7 days',emlak_vergi_sonraki=t+interval '7 days',
   toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=z.alici,kapanma=t where id=i.id;
 update oyun.emlak_pazarlik set durum='kabul',sonuc_at=t where id=z.id;
 update oyun.emlak_pazarlik set durum='iptal',sonuc_at=t where ilan_id=i.id and id<>z.id and durum in ('bekliyor','karsi');
 perform oyun.bildir(z.alici,format('Pazarlık kabul edildi! Mülk #%s %s ₺ karşılığında senin.',i.mulk_id,oyun.tl(p_fiyat)),t);
 perform oyun.bildir(z.satici,format('Mülk #%s %s ₺ karşılığında satıldı; %%2 işlem vergisi kesildi.',i.mulk_id,oyun.tl(p_fiyat)),t);
end $function$

