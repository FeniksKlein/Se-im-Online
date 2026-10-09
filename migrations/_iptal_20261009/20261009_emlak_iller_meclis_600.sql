-- 2026-10-09: 81 ilde stoklu emlak, yerel vergi ve 600 sandalyeli TBMM
-- Oyuncu, mülk ve mevcut seçim kayıtları korunur.
insert into oyun.duzenleme_tanim(kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values
 ('emlak_vergi_ulke','ulke','Haftalık emlak vergisi oranı','yuzde',0.10,0,1,0.05,'gelir',
  'Meclisin belirlediği haftalık emlak vergisi oranı. Satın alma bedeli üzerinden hesaplanır.',
  'Her 7 günde bir kira tahsilatından belediye emlak vergisi kesilir.',
  'Vergi ilgili taşınmazın bulunduğu ilin belediye kasasına gider.',20),
 ('emlak_vergi_carpan','il','Emlak vergisi belediye çarpanı','yuzde',100,0,200,10,'gelir',
  'Belediye başkanının ülke genelindeki emlak vergisi oranına uyguladığı yerel çarpan.',
  'İlde satın alınmış mülklerin haftalık vergisini artırır veya azaltır.',
  'Tahsil edilen vergi o ilin belediye kasasına gider.',20)
on conflict (kod) do nothing;

create table if not exists oyun.emlak_vergi_kayit(
 id bigint generated always as identity primary key,
 mulk_id bigint not null references oyun.yatirim_mulkleri(id),
 il_id smallint not null references oyun.iller(id),
 user_id uuid not null references oyun.profiller(id),
 tutar numeric not null check(tutar>=0),
 hafta integer not null check(hafta>0),
 zaman timestamptz not null default now()
);
create index if not exists emlak_vergi_kayit_il_zaman on oyun.emlak_vergi_kayit(il_id,zaman desc);
alter table oyun.emlak_vergi_kayit enable row level security;
revoke all on oyun.emlak_vergi_kayit from public,anon,authenticated;

create or replace function oyun.emlak_vergisi_oran(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select round(oyun.duz('emlak_vergi_ulke')*oyun.il_duz(p_il,'emlak_vergi_carpan')/100.0,4)
$$;
revoke all on function oyun.emlak_vergisi_oran(smallint) from public,anon,authenticated;

create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round(
 case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else null end
 * greatest(.55,least(2.4,.65+(i.mv::numeric/96)*1.1+(coalesce(d.gelisim,50)-50)*.006)))
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
revoke all on function oyun.emlak_fiyat(smallint,text) from public,anon,authenticated;

create or replace function oyun.emlak_stok(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case p_tip when 'daire' then greatest(8,ceil(i.mv*100.0/96)::int)
 when 'dukkan' then greatest(3,ceil(i.mv*40.0/96)::int)
 when 'villa' then greatest(2,ceil(i.mv*25.0/96)::int)
 else 0 end from oyun.iller i where i.id=p_il
$$;
revoke all on function oyun.emlak_stok(smallint,text) from public,anon,authenticated;

create or replace function public.emlak_iller()
returns jsonb language sql stable security definer set search_path='' as $$
select coalesce(jsonb_agg(jsonb_build_object(
 'id',i.id,'ad',i.ad,'nufus_agirligi',i.mv,'gelisim',coalesce(d.gelisim,50),
 'emlak_vergisi',oyun.emlak_vergisi_oran(i.id),
 'turler',(select jsonb_agg(jsonb_build_object(
   'tip',v.tip,'fiyat',oyun.emlak_fiyat(i.id,v.tip),
   'haftalik',round(oyun.emlak_fiyat(i.id,v.tip)*.025,2),
   'kapasite',oyun.emlak_stok(i.id,v.tip),
   'mevcut',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=v.tip),
   'kalan',greatest(0,oyun.emlak_stok(i.id,v.tip)-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=v.tip)))
  order by v.sira) from (values(1,'daire'),(2,'dukkan'),(3,'villa')) v(sira,tip))
) order by i.ad),'[]'::jsonb)
from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_iller() from public,anon;
grant execute on function public.emlak_iller() to authenticated;

create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric;
 t timestamptz:=oyun.simdi(); yeni_mulk_id bigint; kota integer; mevcut integer;
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 if p_tip is null or p_tip not in ('daire','dukkan','villa') then raise exception 'Geçersiz mülk türü'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Satın almak için geçerli bir il seçmelisin.'; end if;
 perform pg_advisory_xact_lock(874922,hashtext(p_il::text||':'||p_tip));
 kota:=oyun.emlak_stok(p_il,p_tip);
 select count(*) into mevcut from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if mevcut>=kota then raise exception 'Bu ilde % stoku tükendi (% / %). Başka bir il seç veya oyuncu ilanlarından satın al.',p_tip,mevcut,kota; end if;
 bedel:=oyun.emlak_fiyat(p_il,p_tip); kira:=round(bedel*.025,2);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s satın alındı (%s)',p_tip,(select ad from oyun.iller where id=p_il)),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni_mulk_id;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni_mulk_id,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;

-- Eski istemciler 1 parametre gönderirse eskisi gibi kayıtlı illerinden alır.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language sql security definer set search_path='' as $$
 select public.mulk_satin_al(p_tip,(select il_id from oyun.profiller where id=auth.uid()))
$$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- 600 sandalye, seçilen gerçek oyuncular kadar fiilî vekil. Gelecek dönemde yeniden küçültme olmasın.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);

CREATE OR REPLACE FUNCTION oyun.mulk_kira_tahsil(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric;t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
  n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
  gross:=round(m.haftalik_kira*n,2);
  tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
       then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
  emlak_tax:=round(m.alis_bedeli*oyun.emlak_vergisi_oran(m.il_id)/100*n,2);
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',format('Mulk #%s: %s haftalik kira, genel vergi %s TL, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),t,tax+emlak_tax);
  if emlak_tax>0 then
    update oyun.il_durum set kasa=kasa+emlak_tax/1000000000.0 where il_id=m.il_id;
    insert into oyun.emlak_vergi_kayit(mulk_id,il_id,user_id,tutar,hafta,zaman) values(m.id,m.il_id,p_user,emlak_tax,n,t);
  end if;
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
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

