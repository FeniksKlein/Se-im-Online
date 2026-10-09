-- City-limited property stock, distinct city prices/rents, weekly property tax & occupied-seat parliament majorities.
-- Live assets / ownership untouched; all newly created records are additive.
create table if not exists oyun.emlak_vergi_borclari (
 user_id uuid not null references oyun.profiller(id),
 il_id smallint not null references oyun.iller(id),
 borc numeric not null default 0 check (borc>=0),
 son timestamptz,
 primary key(user_id,il_id)
);
alter table oyun.emlak_vergi_borclari enable row level security;
revoke all on oyun.emlak_vergi_borclari from public,anon,authenticated;
alter table oyun.yatirim_mulkleri add column if not exists sonraki_vergi timestamptz;
-- Older assets get a fresh first tax date, without retroactive deductions.
update oyun.yatirim_mulkleri set sonraki_vergi=oyun.simdi()+interval '7 days' where sonraki_vergi is null;
alter table oyun.yatirim_mulkleri alter column sonraki_vergi set default (now()+interval '7 days');
alter table oyun.yatirim_mulkleri alter column sonraki_vergi set not null;

-- Emlak: local difference in per-mille added to national baseline.
update oyun.duzenleme_tanim set ad='Haftalık emlak vergisi (yerel fark)',birim='binde',
 varsayilan=0,min=-3,max=10,adim=1,tur='gelir',
 aciklama='Belediye başkanı Meclisin belirlediği haftalık mülk vergisi oranını ilde artırabilir veya azaltabilir. Vergi mülkün bulunduğu belediyeye ödenir.',
 oyuncu='7 günde bir mülkün alış değeri üzerinden vergi alınır. Mülk başka ildeyse vergi o ilin belediyesine gider.',
 devlet='Tahsil edilen emlak vergisi fiilen belediye kasasına girer; mülkü olmayan oyuncuya vergi uygulanmaz.'
where kod='emlak';
insert into oyun.duzenleme_tanim (kod,kapsam,ad,birim,varsayilan,min,max,adim,tur,aciklama,oyuncu,devlet,sira)
values ('emlak_haftalik','ulke','Ulusal haftalık emlak vergisi','binde',3,0,15,1,'gelir',
'TBMM ülke geneli haftalık mülk vergisinin binde oranını belirler. Belediye başkanı iline özel farkı belirleyebilir.',
'Her mülk için haftalık alış bedeli baz alınır; ödediğin vergi mülkün bulunduğu ilin belediyesine aktarılır.',
'Emlak vergileri 7 günde bir gerçek mülk sahiplerinden tahsil edilerek ilgili belediyenin kasasına eklenir.',120)
on conflict (kod) do nothing;

create or replace function oyun.emlak_vergi_orani(p_il smallint)
returns numeric language sql stable set search_path='' as $$
 select greatest(0,oyun.duz('emlak_haftalik')+oyun.il_duz(p_il,'emlak'))
$$;

-- Electoral-seat counts are a stable population proxy (Istanbul 96, Bayburt 1).
create or replace function oyun.emlak_il_stok(p_il smallint,p_tip text)
returns integer language sql stable set search_path='' as $$
 select case when p_tip='daire' then 8+round((i.mv-1)*92.0/95)::int
             when p_tip='dukkan' then greatest(3,round((8+(i.mv-1)*92.0/95)*0.40)::int)
             when p_tip='villa' then greatest(2,round((8+(i.mv-1)*92.0/95)*0.18)::int) end
 from oyun.iller i where i.id=p_il
$$;
create or replace function oyun.emlak_sehir_fiyat(p_il smallint,p_tip text)
returns numeric language sql stable set search_path='' as $$
 select round((case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end) *
   (0.55+1.5*power(i.mv::numeric/96,0.65))*(0.75+d.gelisim/200.0)/1000)*1000
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function public.emlak_sehirler()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,'gelisim',round(d.gelisim,1),
  'vergi_binde',oyun.emlak_vergi_orani(i.id),'mv',i.mv,
  'tipler',(select jsonb_agg(jsonb_build_object('tur',z.tip,
     'stok',oyun.emlak_il_stok(i.id,z.tip),
     'satilan',(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip=z.tip),
     'fiyat',oyun.emlak_sehir_fiyat(i.id,z.tip),
     'haftalik',round(oyun.emlak_sehir_fiyat(i.id,z.tip)*0.025))
   order by z.sira) from (values ('daire',1),('dukkan',2),('villa',3)) z(tip,sira)))
  order by i.mv desc,i.ad),'[]'::jsonb)
 from oyun.iller i join oyun.il_durum d on d.il_id=i.id
$$;
revoke all on function public.emlak_sehirler() from public,anon;
grant execute on function public.emlak_sehirler() to authenticated;

create or replace function public.mulk_satin_al_il(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 bedel numeric; kira numeric; yeni bigint; stok integer; dolu integer;
begin
 if u is null then raise exception 'Önce giriş yapmalısın.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk tipi.'; end if;
 if p_il is null or not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl seçmelisin.'; end if;
 -- Lock the city to serialize remaining stock; never oversell the same property type.
 perform 1 from oyun.il_durum where il_id=p_il for update;
 stok:=oyun.emlak_il_stok(p_il,p_tip);
 select count(*) into dolu from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if dolu>=stok then raise exception 'Bu ilde % stoğu tükendi: %/% satıldı.',p_tip,dolu,stok; end if;
 bedel:=oyun.emlak_sehir_fiyat(p_il,p_tip);
 kira:=round(bedel*0.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s (%s) satın alındı',p_tip,(select ad from oyun.iller where id=p_il)),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira,sonraki_vergi)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days',t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' devlet gayrimenkul alımı');
 return public.mulk_liste();
end $$;
revoke all on function public.mulk_satin_al_il(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al_il(text,smallint) to authenticated;
-- The legacy endpoint also checks stock and rates, but buys in registered home city.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare il smallint;
begin
 select il_id into il from oyun.profiller where id=auth.uid();
 if il is null then raise exception 'Önce şehir seçmelisin.'; end if;
 return public.mulk_satin_al_il(p_tip,il);
end $$;
revoke all on function public.mulk_satin_al(text) from public,anon;
grant execute on function public.mulk_satin_al(text) to authenticated;

-- Account balances never go below zero; taxes not paid remain in the OWNER's ledger, not the house.
create or replace function oyun.emlak_vergi_tahsil(t timestamptz)
returns void language plpgsql set search_path='' as $$
declare m oyun.yatirim_mulkleri; n int; bedel numeric; borc numeric; topla numeric;
 x record; odenen numeric;
begin
 for m in select * from oyun.yatirim_mulkleri where sonraki_vergi<=t order by id for update skip locked loop
  n:=least(52,1+floor(extract(epoch from(t-m.sonraki_vergi))/604800)::int);
  bedel:=round(m.alis_bedeli*oyun.emlak_vergi_orani(m.il_id)/1000)*n;
  if bedel>0 then
   insert into oyun.emlak_vergi_borclari(user_id,il_id,borc,son)
   values(m.user_id,m.il_id,bedel,t)
   on conflict(user_id,il_id) do update set borc=oyun.emlak_vergi_borclari.borc+excluded.borc,son=t;
  end if;
  update oyun.yatirim_mulkleri set sonraki_vergi=sonraki_vergi+make_interval(weeks=>n) where id=m.id;
 end loop;
 for x in select b.user_id,b.il_id,b.borc from oyun.emlak_vergi_borclari b where b.borc>0 order by b.user_id,b.il_id for update skip locked loop
   select least(x.borc,c.para) into odenen from oyun.cuzdan c where c.user_id=x.user_id for update;
   if coalesce(odenen,0)>0 then
     perform oyun.para_islem(x.user_id,-odenen,'emlak',format('%s haftalık mülk vergisi (‰%s)',
      (select ad from oyun.iller where id=x.il_id),oyun.emlak_vergi_orani(x.il_id)),t,odenen);
     update oyun.il_durum set kasa=kasa+odenen/1000000000.0 where il_id=x.il_id;
     update oyun.emlak_vergi_borclari set borc=greatest(0,borc-odenen),son=t where user_id=x.user_id and il_id=x.il_id;
   end if;
 end loop;
end $$;
revoke all on function oyun.emlak_vergi_tahsil(timestamptz) from public,anon,authenticated;


-- Replace legacy daily assessment and dynamic 81-seat parliament controls.
CREATE OR REPLACE FUNCTION oyun.gunluk_kesinti(u uuid, t timestamp with time zone)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
declare p oyun.profiller; c oyun.cuzdan; s numeric; muaf numeric; ks numeric := 0; em numeric; top numeric := 0; ilad text; banka numeric; a numeric; b numeric;
begin
  select * into p from oyun.profiller where id = u;
  select * into c from oyun.cuzdan where user_id = u;
  s := oyun.duz('servet_vergisi');
  if s > 0 then
    muaf := round(250000 * (select endeks from oyun.ulke where id = 1));
    banka := oyun.mevduat_toplam(u);            -- bankadaki mevduat da servete dahildir (15_ekonomi3)
    ks := floor(greatest(0, c.para + banka - muaf) * s / 1000);
    if ks > 0 then
      a := least(ks, c.para);
      if a > 0 then
        perform oyun.para_islem(u, -a, 'servet', format('Servet vergisi (binde %s, %s ₺ muafiyetin üstü%s)', replace(s::text, '.', ','), oyun.tl(muaf),
                                                       case when banka > 0 then ', banka mevduatı dahil' else '' end), t);
      end if;
      b := least(ks - a, floor(coalesce((select vadesiz from oyun.banka_musteri where user_id = u), 0)));
      if b > 0 then
        update oyun.banka_musteri set vadesiz = vadesiz - b where user_id = u;
        perform oyun.banka_kayit(u, 'vadesiz', -b, 'Servet vergisi (cüzdan yetmedi)', t);
      end if;
      top := top + a + b;
    end if;
  end if;
  -- Weekly owner-asset tax is collected separately and credited to the property city.
  perform oyun.kira_ode(u, t);
  return top;
end $function$


;

CREATE OR REPLACE FUNCTION oyun.il_gelir(p_il smallint)
 RETURNS numeric
 LANGUAGE sql
 STABLE
AS $function$
  select round(oyun.il_gunluk_gelir(i.mv) * u.endeks * (0.5 + d.gelisim / 100) * (0.5 + 0.5 * u.belediye_payi / 10) * (1 + d.kent_vergisi / 10)
               , 4)
  from oyun.iller i join oyun.il_durum d on d.il_id = i.id, oyun.ulke u where i.id = p_il and u.id = 1
$function$


;

CREATE OR REPLACE FUNCTION oyun.il_kurallar_json(p_il smallint, t timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select jsonb_agg(jsonb_build_object('kod',d.kod,'ad',d.ad,'birim',d.birim,'tur',d.tur,
    'min',greatest(d.min,d.varsayilan-(d.varsayilan-d.min)*coalesce(oyun.anayasa_deger('yerel_yetki'),100)/100.0),
    'max',least(d.max,d.varsayilan+(d.max-d.varsayilan)*coalesce(oyun.anayasa_deger('yerel_yetki'),100)/100.0),
    'adim',d.adim,'aciklama',d.aciklama,'oyuncu',d.oyuncu,'devlet',d.devlet,'deger',oyun.il_duz(p_il,d.kod),
    'yazi',oyun.duz_yaz(d.kod,oyun.il_duz(p_il,d.kod)),
    'hazir',(select z.zaman+interval '24 hours' from oyun.il_duzenleme z where z.il_id=p_il and z.kod=d.kod and z.zaman>t-interval '24 hours'),
    'gunluk_gelir',case when d.kod='emlak' then (select round(coalesce(sum(m.alis_bedeli),0)*oyun.emlak_vergi_orani(p_il)/1000/7/1e9,4) from oyun.yatirim_mulkleri m where m.il_id=p_il) end,
    'birim_maliyet',case when d.kod='hosgeldin' then round(oyun.il_duz(p_il,'hosgeldin')*2000/1e9,4) end) order by d.sira)
  from oyun.duzenleme_tanim d where d.kapsam='il'
$function$


;

CREATE OR REPLACE FUNCTION oyun.belediye_gunluk(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare r record; h record; v_kasa numeric; bas uuid;
begin
  perform oyun.emlak_vergi_tahsil(t);
  for r in select d.il_id, i.ad, i.mv from oyun.il_durum d join oyun.iller i on i.id = d.il_id loop
    update oyun.il_durum set kasa = least(60 * oyun.il_gelir(r.il_id), coalesce(kasa, 0) + oyun.il_gelir(r.il_id)) - oyun.il_gider(r.il_id)
     where il_id = r.il_id returning kasa into v_kasa;
    if v_kasa < 0 then
      bas := (select user_id from oyun.makamlar where tur = 'bel' and il_id = r.il_id and bit is null limit 1);
      update oyun.il_durum set hemsehri = 0 where il_id = r.il_id and hemsehri > 0;
      for h in select k.kod, b.ad from oyun.il_hizmet k join oyun.belediye_hizmetleri b on b.kod = k.kod
               where k.il_id = r.il_id order by b.oran desc loop
        exit when (select kasa from oyun.il_durum where il_id = r.il_id) >= 0;
        delete from oyun.il_hizmet where il_id = r.il_id and kod = h.kod;
        update oyun.il_durum set kasa = kasa + oyun.hizmet_gider(r.il_id, h.kod) where il_id = r.il_id;
        perform oyun.olay('belediye', format('%s Belediyesi kasası yetmediği için %s hizmetini kapattı.', r.ad, h.ad), r.il_id, null, t);
      end loop;
      if bas is not null then perform oyun.bildir(bas, 'Belediye kasası eksiye düştü: hemşehri desteği durduruldu, gerekirse hizmetler kapatıldı.', t); end if;
      update oyun.il_durum set kasa = greatest(kasa, 0) where il_id = r.il_id;
    end if;
  end loop;
  -- gelişmişlik yatırım almazsa yavaşça ortalamaya döner; memnuniyet hizmetlere, desteğe ve vergiye göre şekillenir
  update oyun.il_durum d set gelisim = gelisim + (50 - gelisim) * 0.01,
    memnuniyet = oyun.sinir(memnuniyet + (50 + 4 * (select count(*) from oyun.il_hizmet ih where ih.il_id = d.il_id) + least(10, hemsehri / 30)
                                          - kent_vergisi * 2 - oyun.il_duz(d.il_id, 'emlak') / 30 - memnuniyet) * 0.05, 0, 100);
end $function$


;

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
  n := anayasal;
  return jsonb_build_object('aktif', aktif, 'sandalye', n, 'anayasal', anayasal, 'olcek', a);
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
    'dolu', dolu, 'toplanti_yeter', ceil(dolu / 3.0), 'karar_yeter', floor(dolu / 2.0) + 1, 'israr_yeter', floor(dolu / 2.0) + 1,
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


;

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
 perform oyun.emlak_vergi_tahsil(oyun.simdi());
 perform oyun.mulk_kira_tahsil(u);
 select jsonb_build_object(
   'mulkler',coalesce(jsonb_agg(jsonb_build_object(
      'id',m.id,'tip',m.tip,'il',i.ad,'alis',m.alis_bedeli,
      'haftalik',m.haftalik_kira,'sonraki',m.sonraki_kira,
      'toplam_kira',m.toplam_kira,'kira_sayisi',m.kira_sayisi
   ) order by m.satin_alma desc,m.id desc),'[]'::jsonb),
   'adet',count(m.id),
   'haftalik_toplam',coalesce(sum(m.haftalik_kira),0),
   'mulk_degeri',coalesce(sum(m.alis_bedeli),0),
   'cuzdan',(select para from oyun.cuzdan where user_id=u)
 ) into j
 from oyun.yatirim_mulkleri m join oyun.iller i on i.id=m.il_id where m.user_id=u;
 return j;
end $function$
;
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
