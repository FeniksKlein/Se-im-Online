-- 2026-10-09 — Emlak il stoku, bölgesel fiyat/kira ve belediyeye haftalık emlak vergisi.
-- Eski tapular, borçlar, cüzdanlar ve meclis kayıtları korunur.
create table if not exists oyun.emlak_vergi_ulusal (
 id integer primary key check (id=1), oran numeric not null default .35 check (oran between .1 and 1.0), son timestamptz not null default now()
);
insert into oyun.emlak_vergi_ulusal(id,oran) values(1,.35) on conflict(id) do nothing;
create table if not exists oyun.emlak_vergi_il (
 il_id smallint primary key references oyun.iller(id), duzeltme numeric not null default 0 check (duzeltme between -1 and 1),
 son_ayar timestamptz
);
insert into oyun.emlak_vergi_il(il_id) select id from oyun.iller on conflict do nothing;
create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key, mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 user_id uuid not null references oyun.profiller(id), il_id smallint not null references oyun.iller(id),
 hafta_sayisi integer not null check (hafta_sayisi between 1 and 520),
 matrah numeric not null, oran numeric not null, vergi numeric not null,
 zaman timestamptz not null default now()
);
create index if not exists emlak_vergi_kayit_mulk on oyun.emlak_vergi_kayit(mulk_id,zaman desc);
alter table oyun.emlak_vergi_ulusal enable row level security;
alter table oyun.emlak_vergi_il enable row level security;
alter table oyun.emlak_vergi_kayit enable row level security;
revoke all on oyun.emlak_vergi_ulusal,oyun.emlak_vergi_il,oyun.emlak_vergi_kayit from public,anon,authenticated;

create or replace function oyun.emlak_oran(p_il smallint) returns numeric
language sql stable set search_path='' as $$
 select greatest(.05,least(1.5, (select oran from oyun.emlak_vergi_ulusal where id=1)
 + coalesce((select duzeltme from oyun.emlak_vergi_il where il_id=p_il),0)))
$$;
create or replace function oyun.emlak_stok(p_il smallint,p_tip text) returns integer
language sql stable set search_path='' as $$
 select case p_tip when 'daire' then 7+round(93*mv::numeric/96)::int
 when 'dukkan' then greatest(3,ceil((7+round(93*mv::numeric/96)::int)*.35)::int)
 when 'villa' then greatest(2,ceil((7+round(93*mv::numeric/96)::int)*.12)::int) end
 from oyun.iller where id=p_il
$$;
create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end)
   * (0.65 + least(i.mv,96)/96.0*1.45 + greatest(0,least(100,d.gelisim))/100.0*.25)/1000)*1000
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_kira(p_il smallint,p_tip text) returns numeric
language sql stable set search_path='' as $$
 select round(oyun.emlak_fiyat(p_il,p_tip) * (0.018 + greatest(0,least(100,d.gelisim))/100*.012))
 from oyun.il_durum d where d.il_id=p_il
$$;
create or replace function public.emlak_il_rehberi() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',i.id,'il',i.ad,'gelisim',round(d.gelisim,1),'emlak_orani',oyun.emlak_oran(i.id),
 'daire',jsonb_build_object('stok',oyun.emlak_stok(i.id,'daire'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire'),
  'fiyat',oyun.emlak_fiyat(i.id,'daire'),'kira',oyun.emlak_kira(i.id,'daire')),
 'dukkan',jsonb_build_object('stok',oyun.emlak_stok(i.id,'dukkan'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan'),
  'fiyat',oyun.emlak_fiyat(i.id,'dukkan'),'kira',oyun.emlak_kira(i.id,'dukkan')),
 'villa',jsonb_build_object('stok',oyun.emlak_stok(i.id,'villa'),'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa'),
  'fiyat',oyun.emlak_fiyat(i.id,'villa'),'kira',oyun.emlak_kira(i.id,'villa'))
 ) order by i.mv desc,i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_il_rehberi() from public,anon;
grant execute on function public.emlak_il_rehberi() to authenticated;

create or replace function public.mulk_satin_al(p_tip text,p_il smallint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();p oyun.profiller; fiyat numeric;kira numeric;
        t timestamptz:=oyun.simdi();yeni bigint; stok integer; kullanilan integer;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into p from oyun.profiller where id=u;
 if p.id is null or p.yasakli then raise exception 'Aktif oyuncu profili gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_il is null then raise exception 'Mülk türü veya il seçimi geçersiz.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Seçilen il bulunamadı.'; end if;
 -- Aynı ilde son evi almak için yarışan oyuncular arasında stok aşımı olmaz.
 perform pg_advisory_xact_lock(58191,p_il::int*10 + case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 stok:=oyun.emlak_stok(p_il,p_tip);
 select count(*) into kullanilan from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if kullanilan>=stok then raise exception '% ilinde % için satılabilir yeni mülk kalmadı (%/%). İstersen oyuncu ilanlarını incele.',
   (select ad from oyun.iller where id=p_il),p_tip,kullanilan,stok; end if;
 fiyat:=oyun.emlak_fiyat(p_il,p_tip);kira:=oyun.emlak_kira(p_il,p_tip);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-fiyat,'emlak',format('%s / %s yeni mülk',p_tip,(select ad from oyun.iller where id=p_il)),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,fiyat,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,fiyat,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
-- Eski tek parametreli API de il stoku ve fiyat sınırına tabi tutulur.
create or replace function public.mulk_satin_al(p_tip text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin return public.mulk_satin_al(p_tip,p.il_id); end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

create or replace function public.emlak_belediye_oran_ayarla(p_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();m oyun.makamlar:=oyun.baskan_zorunlu(p);
 t timestamptz:=oyun.simdi(); global numeric; old numeric;son timestamptz;
begin
 select son_ayar into son from oyun.emlak_vergi_il where il_id=m.il_id for update;
 if son>t-interval '24 hours' then raise exception 'Emlak vergisi oranı 24 saatte bir değiştirilebilir.'; end if;
 if p_oran is null or p_oran<.1 or p_oran>1.5 then raise exception 'Haftalık emlak vergisi oranı %%0,1 ile %%1,5 arasında olmalı.'; end if;
 select oran into global from oyun.emlak_vergi_ulusal where id=1;
 if (p_oran-global) not between -1 and 1 then raise exception 'İldeki oran ulusal orandan en fazla 1 puan ayrılabilir.'; end if;
 old:=oyun.emlak_oran(m.il_id);
 update oyun.emlak_vergi_il set duzeltme=p_oran-global,son_ayar=t where il_id=m.il_id;
 perform oyun.olay('belediye',format('%s Belediye Başkanı haftalık emlak vergisini %%%s oranından %%%s oranına değiştirdi.',
 (select ad from oyun.iller where id=m.il_id),old,p_oran),m.il_id,p.parti_id,t);
 return jsonb_build_object('il_id',m.il_id,'oran',p_oran,'onceki',old);
end $$;
revoke all on function public.emlak_belediye_oran_ayarla(numeric) from public,anon;
grant execute on function public.emlak_belediye_oran_ayarla(numeric) to authenticated;

-- Milletvekillerinin olağan yasama sürecinde oylayacağı ulusal haftalık emlak vergisi teklifi.
create or replace function public.emlak_kanun_teklif(p_oran numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();s record;idd bigint;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Emlak vergisi kanununu yalnızca milletvekilleri teklif edebilir.'; end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then
  raise exception 'Meclis Başkanı tarafsızlık gereği teklif veremez.'; end if;
 if p_oran is null or p_oran not between .1 and 1 then raise exception 'Ulusal haftalık vergi %%0,1–%%1 arasında olmalı.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
  raise exception 'Önce mevcut kanun teklifini sonuçlandırmalısın.'; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest','Haftalık Emlak Vergisi Düzenlemesi',
 format('Türkiye genelinde mülkler için haftalık emlak vergisi taban oranı %%%s olacaktır. Vergi mülkün bulunduğu il belediyesine gelir kaydedilir. Belediye başkanı il farkı belirleyebilir.',p_oran),
 jsonb_build_object('eylem','emlak_vergisi','oran',p_oran),p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama)
 returning id into idd;
 perform oyun.olay('meclis',format('%s haftalık emlak vergisini %%%s yapmayı Meclis''e teklif etti.',p.kad,p_oran),null,p.parti_id,t);
 return jsonb_build_object('id',idd,'oran',p_oran);
end $$;
revoke all on function public.emlak_kanun_teklif(numeric) from public,anon;
grant execute on function public.emlak_kanun_teklif(numeric) to authenticated;

create or replace function oyun.emlak_kanun_etki() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.durum='yururlukte' and old.durum is distinct from new.durum
    and new.tur='serbest' and new.veri->>'eylem'='emlak_vergisi' then
  update oyun.emlak_vergi_ulusal set oran=(new.veri->>'oran')::numeric,son=oyun.simdi() where id=1;
 end if;
 return new;
end $$;
drop trigger if exists emlak_kanun_uygula on oyun.kanunlar;
create trigger emlak_kanun_uygula after update of durum on oyun.kanunlar for each row
execute function oyun.emlak_kanun_etki();


-- Always offer all 600 constitutional seats in future general elections;
-- ordinary legislation still requires a majority of actually seated legislators.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);

CREATE OR REPLACE FUNCTION oyun.mulk_kira_tahsil(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric;oran numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  oran:=oyun.emlak_oran(m.il_id);
  emlak_tax:=least(greatest(0,gross-tax),round(m.alis_bedeli*oran/100*n,2));
  -- Mülk vergisi yerel yönetimin kasasına, çoklu mülk vergisi ulusal hazineye yazılır.
  if emlak_tax>0 then
    update oyun.il_durum set kasa=kasa+emlak_tax/1000000000.0 where il_id=m.il_id;
    insert into oyun.emlak_vergi_kayit(mulk_id,user_id,il_id,hafta_sayisi,matrah,oran,vergi,zaman)
    values(m.id,p_user,m.il_id,n,m.alis_bedeli,oran,emlak_tax,t);
  end if;
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',format('Mulk #%s: %s haftalik kira, genel vergi %s TL, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),t,tax+emlak_tax);
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $function$
;

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
;
