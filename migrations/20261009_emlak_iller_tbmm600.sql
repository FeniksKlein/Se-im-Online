-- 2026-10-09 | İl bazlı emlak stoku/fiyatları, haftalık belediye vergisi, 600 sandalye.
-- Mevcut tapular ve cüzdanlar korunur. Yaşayan şehir ekonomisinde fiyatlar il gelişmişliğine göre değişir.
insert into oyun.duzenleme_tanim
 (kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
 values
 ('emlak_ulusal_oran','ulke','Haftalık emlak vergisi oranı','yuzde',0.5,0,2,0.05,'gelir',
  'TBMM tarafından belirlenen mülk alış bedeli üzerinden haftalık belediye emlak vergisi oranı.',
  'Mülk kiraları tahsil edilirken otomatik kesilir.','Verginin tamamı mülkün bulunduğu ilin belediye kasasına gider.',23),
 ('emlak_mulk_carpan','il','Mülk emlak vergisi yerel çarpanı','yuzde',100,50,200,10,'gelir',
  'Ulusal emlak vergisi oranı üzerine bu ilin belediye başkanının uyguladığı yerel çarpan.',
  'İl dışında yaşayan mülk sahipleri de bu ilin emlak vergisini öder.','Bu ildeki mülklerden alınan tutar doğrudan belediye kasasına girer.',20)
 on conflict(kod) do nothing;

create or replace function oyun.emlak_stok(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case p_tip
 when 'daire' then greatest(8,least(100,round(8+(i.mv-1)*92.0/95)::int))
 when 'dukkan' then greatest(4,least(42,round(4+(i.mv-1)*38.0/95)::int))
 when 'villa' then greatest(2,least(20,round(2+(i.mv-1)*18.0/95)::int))
 else 0 end
 from oyun.iller i where i.id=p_il
$$;

create or replace function oyun.emlak_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 else 0 end)
   *(0.80+1.35*(i.mv-1)/95.0)
   *(0.90+coalesce(d.gelisim,50)/500.0),-3)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;

create or replace function public.emlak_sehirler() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',i.id,'ad',i.ad,'gelisim',coalesce(d.gelisim,50),'nufus_gostergesi',i.mv,
  'yerel_carpan',oyun.il_duz(i.id,'emlak_mulk_carpan'),
  'ulusal_oran',oyun.duz('emlak_ulusal_oran'),
  'tipler',(select jsonb_agg(jsonb_build_object('tip',x.tip,
    'stok',oyun.emlak_stok(i.id,x.tip),
    'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=x.tip),
    'kalan',greatest(0,oyun.emlak_stok(i.id,x.tip)-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=x.tip)),
    'fiyat',oyun.emlak_fiyat(i.id,x.tip),'haftalik',round(oyun.emlak_fiyat(i.id,x.tip)*0.025),
    'haftalik_vergi',round(oyun.emlak_fiyat(i.id,x.tip)*oyun.duz('emlak_ulusal_oran')/100*oyun.il_duz(i.id,'emlak_mulk_carpan')/100)
    ) from (values ('daire'),('dukkan'),('villa')) x(tip)))
  order by i.ad),'[]'::jsonb)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_sehirler() from public,anon;
grant execute on function public.emlak_sehirler() to authenticated;

create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); f numeric; r numeric; t timestamptz:=oyun.simdi();
        yeni bigint; mevcut integer; kapasite integer;
begin
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'Geçerli bir il seçmelisin.'; end if;
 perform pg_advisory_xact_lock(914422,p_il::integer*10+case p_tip when 'daire' then 1 when 'dukkan' then 2 else 3 end);
 kapasite:=oyun.emlak_stok(p_il,p_tip);
 select count(*) into mevcut from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if mevcut>=kapasite then raise exception 'Bu ilde satılabilecek % stoku tükendi. Diğer illeri incele.',p_tip; end if;
 f:=oyun.emlak_fiyat(p_il,p_tip);
 r:=round(f*0.025,2);
 perform oyun.mulk_kira_tahsil(p.id);
 perform oyun.para_islem(p.id,-f,'emlak',format('%s ilinde %s satın alındı', (select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(p.id,p_il,p_tip,f,r,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,p.id,f,t,format('İl %s için %s devlet emlak alımı',p_il,p_tip));
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;

-- Eski istemcilerin tek parametreli alışları da artık bulundukları ilin stokuna tabidir.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 return public.mulk_satin_al(p_tip,p.il_id);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

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
  emlak_tax:=round(m.alis_bedeli*oyun.duz('emlak_ulusal_oran')/100 * oyun.il_duz(m.il_id,'emlak_mulk_carpan')/100 * n,2);
  perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',format('Mulk #%s: %s haftalik kira; gelir vergisi %s TL, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),t,tax+emlak_tax);
  if emlak_tax>0 then update oyun.il_durum set kasa=kasa+emlak_tax/1000000.0 where il_id=m.il_id; end if;
  if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000 where id=1;end if;
  update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $function$

CREATE OR REPLACE FUNCTION oyun.meclis_olcek_hesap(t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a numeric := (select meclis_olcek from oyun.ayarlar where id = 1);
        anayasal int := coalesce((select round(deger)::int from oyun.anayasa where kod = 'milletvekili_sayisi'), 600);
        aktif int := (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '14 days');
        n int;
begin
  -- Anayasal sandalye sayısı korunur; gerçek vekil sayısı görevdeki oyunculardan gelir.
  n := anayasal;
  return jsonb_build_object('aktif', aktif, 'sandalye', n, 'anayasal', anayasal, 'olcek', a);
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
    if dolu > 0 and c.kabul + c.ret + c.cekimser >= floor(dolu / 2.0) + 1 and c.kabul > c.ret and c.kabul >= floor(dolu / 2.0) + 1 then
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
        sonuc_metin = case when c.kabul + c.ret + c.cekimser < floor(dolu / 2.0) + 1 then format('Toplantı yeter sayısı sağlanamadı (%s vekil katıldı, en az %s gerekliydi).', c.kabul + c.ret + c.cekimser, floor(dolu / 2.0) + 1)
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

CREATE OR REPLACE FUNCTION public.kanun_detay(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; dolu int := oyun.dolu_sandalye();
begin
  select * into k from oyun.kanunlar where id = p_id;
  if k.id is null then raise exception 'Kanun bulunamadı.'; end if;
  return oyun.kanun_ozet(k, p, t) || jsonb_build_object(
    'metin', k.metin, 'veri', k.veri, 'veto_gerekce', k.veto_gerekce, 'sonuc_metin', k.sonuc_metin,
    'kararname', case when k.tur = 'iptal' then (select jsonb_build_object('no', no, 'baslik', baslik) from oyun.kararnameler where id = (k.veri ->> 'kararname_id')::bigint) end,
    'dolu', dolu, 'toplanti_yeter', floor(dolu / 2.0)+1, 'karar_yeter', floor(dolu / 2.0) + 1, 'israr_yeter', floor(dolu / 2.0) + 1,
    'vekilim', oyun.aktif_vekil(p.id),
    'oy_acik', (k.durum = 'oylamada' and t >= k.oy_bas and t < k.oy_bit) or (k.durum = 'israr' and t < k.israr_bit),
    'benim_oyum', (select oy from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = case when k.durum = 'israr' then 'israr' else 'ilk' end),
    'cb_karar_verebilir', k.durum = 'cb_onayinda' and t < k.cb_bit and oyun.aktif_cb() = p.id,
    'anayasa_aciklama', case when k.tur = 'anayasa' then oyun.anayasa_aciklama(k.veri) end,
    'grup', oyun.grup_karar_json(k.id, p), 'tbmm_baskani', exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null),
    'duzenleme', case when k.tur = 'duzenleme' then (select jsonb_build_object('ad', d.ad, 'yazi', oyun.duz_yaz(d.kod, (k.veri ->> 'deger')::numeric),
                    'mevcut', oyun.duz_yaz(d.kod, oyun.duz(d.kod)), 'oyuncu', d.oyuncu, 'devlet', d.devlet) from oyun.duzenleme_tanim d where d.kod = k.veri ->> 'kod') end,
    'imza_yeter', ceil(dolu / 3.0), 'uc_bes', ceil(dolu * 3 / 5.0), 'iki_uc', ceil(dolu * 2 / 3.0),
    'imzaladim', exists (select 1 from oyun.kanun_oylari where kanun_id = k.id and vekil = p.id and asama = 'imza'),
    'referandum', (select jsonb_build_object('id', r.id, 'oy_bas', r.oy_bas, 'durum', r.durum, 'sonuc', r.sonuc) from oyun.referandumlar r where r.kanun_id = k.id),
    'benim', k.teklif_eden = p.id,
    'oylar', (select jsonb_object_agg(a.asama, a.j) from (
       select o.asama, jsonb_build_object(
         'kabul', count(*) filter (where o.oy = 'kabul'), 'ret', count(*) filter (where o.oy = 'ret'), 'cekimser', count(*) filter (where o.oy = 'cekimser'),
         'liste', case when k.tur = 'anayasa' and o.asama = 'ilk' then '[]'::jsonb
                       else jsonb_agg(jsonb_build_object('kad', oyun.kad(o.vekil), 'oy', o.oy, 'parti', oyun.parti_json(o.parti_id),
                              'aykiri', o.asama <> 'imza' and exists (select 1 from oyun.grup_kararlari g where g.kanun_id = k.id and g.parti_id = o.parti_id
                                                                         and g.karar in ('kabul','ret') and g.karar <> o.oy)) order by o.parti_id, o.zaman) end) j
       from oyun.kanun_oylari o where o.kanun_id = k.id group by o.asama) a));
end $function$

update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
