-- 25.11.2026 · ŞİRKET KAZANÇ DENGESİ (sürüm 2026.11.25-4)
-- İstek (Ercan): "Oyuncular şirket kurup hemen hızlıca para kazanamasın, hiç kazanamayıp oyundan da soğumasın;
--   büyümek için para satın almak istesin." + "Şimdiye kadar para satın alıp şirket kuranları dengeye yavaş yavaş sokalım."
-- Bulgular: (1) mağaza NPC satışında fiyat duyarlılığı yoktu (önerilenin 3 katına satış; 300 bin ₺ sermayeli
--   market 8 saatte 307 bin ₺ net), (2) şubeler 4-5 haftada kendini ödüyordu (10 şubeli şirket haftada %35).
-- Kurallar (hepsi oyun.sirket_denge_ayar satırından; Yönetim portalı › Ekonomi):
--   1) Kuruluş dönemi verimi: yeni şirket/şube ilk gün %35, 21 günde %100 (yeni sermaye de olgunlaşır).
--   2) Şirket düzeyinde yumuşak kazanç tavanı = merkez tavanı (sermayeye bağlı; büyüdükçe oran düşer;
--      şubeye bağlanan sermayenin %40'ı merkezden düşülür) + şube tavanları (açılış bedeline bağlı; sıra arttıkça düşer).
--      Tavanın %60'ına kadar dokunulmaz, üstü tavana doğru sıkışır. Gelir ve gider aynı çarpanla ölçeklenir.
--   3) Kuruluş koruması: ilk 7 gün işletme zararı yazılmaz (en ucuz fiyat politikası hariç).
--   4) Mağaza NPC satışı: sermayeye bağlı haftalık ciro tavanı (günlük payı 1/7); önerilen fiyatın üstünde talep
--      hızla düşer; düşük talepli (lüks) ürün önerilenin 1,3 katından pahalıysa satılmaz.
--   5) NPC stoklu işletmenin günlük brüt kâr tavanı aynı eğriye bağlı (eski %2,5 üst sınır olarak durur).
--   6) pazar_hesapla: "zarar ediyor" uyarısı yalnız gerçekten zarardaysa; kayıt açıklamasına verim notu.
--   7) Geçiş dönemi: denge öncesi kurulmuş ve sermayesi satın alınan parayla karşılanmış şirketlerde kuruluş verimi
--      uygulanmaz; eski tahmin ile yeni denge arasındaki sabit fark 30 günde S eğrisiyle sıfıra iner.
-- Kapatma: update oyun.sirket_denge_ayar set aktif=false;  Eski tanımlar: oyun.sirket_denge_yedek.
-- Oyuncu verisi değişmez. Tekrar çalıştırmak güvenlidir.
-- UYARI: pazar_tahmin, sube_bolge_analiz, sube_pazar_tahmin, halka_arz_net_tahmin bu dosyada TAM olarak yeniden
--   yazılır; pazar_hesapla, eko_ticaret_tick, npc_isletme_tick, pazar_danisman yamalanır. Bu işlevlere dokunan
--   sonraki değişiklikler CANLI tanımdan (pg_get_functiondef) başlamalı, eski kaynak dosyalardan değil.

create table if not exists oyun.sirket_denge_ayar (
  id smallint primary key default 1 check (id = 1),
  aktif boolean not null default true,
  baslangic timestamptz not null default now(),
  olgun_bas numeric not null default 0.35,
  olgun_gun integer not null default 21,
  koruma_gun integer not null default 7,
  tavan_oran numeric not null default 12,
  tavan_ref numeric not null default 200000,
  tavan_us numeric not null default 0.30,
  tavan_taban numeric not null default 3.5,
  serbest numeric not null default 0.6,
  sube_oran numeric not null default 7,
  sube_us numeric not null default 0.35,
  sube_taban numeric not null default 3,
  sube_pay numeric not null default 0.4,
  perakende_kat numeric not null default 2,
  npc_kat numeric not null default 2,
  fiyat_esneklik numeric not null default 3,
  luks_fiyat_sinir numeric not null default 1.3,
  gecis_gun integer not null default 30,
  guncelleme timestamptz not null default now()
);
alter table oyun.sirket_denge_ayar add column if not exists sube_pay numeric not null default 0.4;
alter table oyun.sirket_denge_ayar add column if not exists gecis_gun integer not null default 30;
alter table oyun.sirket_denge_ayar enable row level security;
insert into oyun.sirket_denge_ayar(id) values (1) on conflict (id) do nothing;

create table if not exists oyun.sirket_denge_durum (
  sirket_id bigint primary key references oyun.sirketler(id) on delete cascade,
  sermaye_iz numeric,
  olgun_bas timestamptz,
  tanitim timestamptz,
  olgun timestamptz,
  tavan_bildirim timestamptz,
  gecis_kapsam numeric,
  gecis_fark numeric
);
alter table oyun.sirket_denge_durum add column if not exists gecis_kapsam numeric;
alter table oyun.sirket_denge_durum add column if not exists gecis_fark numeric;
alter table oyun.sirket_denge_durum enable row level security;

-- Değiştirilen işlevlerin 25.11.2026 öncesi tanımları (ilk çalıştırmada bir kez alınır).
create table if not exists oyun.sirket_denge_yedek (
  fonksiyon text primary key,
  tanim text not null,
  zaman timestamptz not null default now()
);
alter table oyun.sirket_denge_yedek enable row level security;
insert into oyun.sirket_denge_yedek(fonksiyon, tanim)
select p.oid::regprocedure::text, pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where (n.nspname = 'oyun' and p.proname in ('pazar_tahmin','sube_bolge_analiz','halka_arz_net_tahmin','pazar_hesapla','eko_ticaret_tick','npc_isletme_tick'))
   or (n.nspname = 'public' and p.proname = 'pazar_danisman')
on conflict (fonksiyon) do nothing;

-- İşlevler (canlı veritabanındaki tanımların birebir kopyası)
CREATE OR REPLACE FUNCTION oyun.sd_ayar()
 RETURNS oyun.sirket_denge_ayar
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a oyun.sirket_denge_ayar; g text := coalesce(current_setting('oyun.sd_test', true), '');
begin
  select * into a from oyun.sirket_denge_ayar where id = 1;
  if a.id is null then a.aktif := false; return a; end if;
  -- Yalnız SQL oturumundan deneme için: oyun.sd_test = '1' açık, '0' kapalı sayar.
  if g = '1' then a.aktif := true; elsif g = '0' then a.aktif := false; end if;
  return a;
end $function$;

CREATE OR REPLACE FUNCTION oyun.sd_baslangic()
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ select coalesce((select baslangic from oyun.sirket_denge_ayar where id = 1), '-infinity'::timestamptz) $function$;

CREATE OR REPLACE FUNCTION oyun.sd_sikistir(p_ham numeric, p_tavan numeric, p_serbest numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare a numeric; b numeric; x double precision;
begin
  if p_ham is null then return null; end if;
  if p_ham <= 0 or p_tavan is null then return p_ham; end if;
  if p_tavan <= 0 then return 0; end if;
  a := p_tavan * least(greatest(coalesce(p_serbest, 0), 0), 0.99);
  if p_ham <= a then return p_ham; end if;
  b := p_tavan - a;
  x := ((p_ham - a) / b)::double precision;
  if x > 40 then return p_tavan; end if;
  return a + b * (1 - exp(-x))::numeric;
end $function$;

CREATE OR REPLACE FUNCTION oyun.sd_olgunluk_h(p_bas timestamp with time zone, p_an timestamp with time zone, p_ilk numeric, p_gun integer)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case when p_bas is null or p_an is null or p_ilk is null then 1::numeric
    else least(1::numeric, greatest(least(1::numeric, greatest(0.01, p_ilk)),
           p_ilk + (1 - p_ilk) * (extract(epoch from (p_an - p_bas))::numeric / 86400.0) / greatest(1, coalesce(p_gun, 1)))) end
$function$;

CREATE OR REPLACE FUNCTION oyun.sd_tavan_yuzde(p_sermaye numeric, a oyun.sirket_denge_ayar)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select greatest(coalesce(a.tavan_taban, 0),
    a.tavan_oran * power(greatest(1::numeric, coalesce(p_sermaye, 0) / greatest(1::numeric, a.tavan_ref)), -a.tavan_us))
$function$;

CREATE OR REPLACE FUNCTION oyun.sd_gecis_oran(p_an timestamp with time zone, a oyun.sirket_denge_ayar)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case when a.baslangic is null or p_an is null or coalesce(a.gecis_gun, 0) <= 0 then 0::numeric
    else (select case when q.x >= 1 then 0::numeric when q.x <= 0 then 1::numeric
                      else round((0.5 * (1 + cos(pi() * q.x)))::numeric, 4) end
          from (select extract(epoch from (p_an - a.baslangic))::double precision / (a.gecis_gun * 86400.0) as x) q) end
$function$;

CREATE OR REPLACE FUNCTION oyun.sd_olgun_bas(p_sirket bigint, p_kurulus timestamp with time zone)
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce((select d.olgun_bas from oyun.sirket_denge_durum d where d.sirket_id = p_sirket), p_kurulus)
$function$;

CREATE OR REPLACE FUNCTION oyun.sd_perakende_tavan(p_sirket bigint, p_an timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a oyun.sirket_denge_ayar := oyun.sd_ayar(); s oyun.sirketler;
begin
  if not coalesce(a.aktif, false) then return null; end if;
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null then return null; end if;
  return round(greatest(0, s.sermaye) * oyun.sd_tavan_yuzde(s.sermaye, a) / 100
    * oyun.sd_olgunluk_h(oyun.sd_olgun_bas(s.id, s.kurulus), coalesce(p_an, oyun.simdi()), a.olgun_bas, a.olgun_gun)
    * a.perakende_kat);
end $function$;

CREATE OR REPLACE FUNCTION oyun.sd_npc_marj_tavan(p_sirket bigint, p_an timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a oyun.sirket_denge_ayar := oyun.sd_ayar(); s oyun.sirketler;
begin
  if not coalesce(a.aktif, false) then return null; end if;
  select * into s from oyun.sirketler where id = p_sirket;
  if s.id is null then return null; end if;
  return round(greatest(0, s.sermaye) * oyun.sd_tavan_yuzde(s.sermaye, a) / 100 / 7
    * oyun.sd_olgunluk_h(oyun.sd_olgun_bas(s.id, s.kurulus), coalesce(p_an, oyun.simdi()), a.olgun_bas, a.olgun_gun)
    * a.npc_kat);
end $function$;

CREATE OR REPLACE FUNCTION oyun.sd_perakende_talep(p_ref numeric, p_fiyat numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a oyun.sirket_denge_ayar := oyun.sd_ayar(); r numeric := coalesce(p_ref, 0) / greatest(coalesce(p_fiyat, 1), 1);
begin
  if r <= 0 then return 0; end if;
  if not coalesce(a.aktif, false) then return greatest(.12, least(1.4, r ^ .8)); end if;
  if r >= 1 then return least(1.4, r ^ .8); end if;
  return power(r, greatest(0.8, a.fiyat_esneklik));
end $function$;

CREATE OR REPLACE FUNCTION oyun.sd_luks_satar(p_ref numeric, p_fiyat numeric)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare a oyun.sirket_denge_ayar := oyun.sd_ayar();
begin
  if not coalesce(a.aktif, false) then return true; end if;
  return coalesce(p_fiyat, 0) <= coalesce(p_ref, 0) * greatest(1, a.luks_fiyat_sinir);
end $function$;

CREATE OR REPLACE FUNCTION oyun.sd_perakende_adet(p_adet integer, p_fiyat numeric, p_w numeric, p_hafta numeric, p_gun numeric)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare d numeric; kh numeric; kg numeric; izin integer;
begin
  if p_w is null or coalesce(p_adet, 0) <= 0 or coalesce(p_fiyat, 0) <= 0 then return greatest(coalesce(p_adet, 0), 0); end if;
  d := p_w / 7; kh := p_w - coalesce(p_hafta, 0); kg := d - coalesce(p_gun, 0);
  if kh <= 0 then return 0; end if;
  izin := floor(least(kh, greatest(kg, 0)) / p_fiyat)::integer;
  if izin >= 1 then return least(p_adet, izin); end if;
  if p_fiyat > d and kh >= p_fiyat then return 1; end if;
  return 0;
end $function$;

CREATE OR REPLACE FUNCTION oyun.sd_tavan_bildir(p_sirket bigint, p_an timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare x record; v_ad text;
begin
  insert into oyun.sirket_denge_durum(sirket_id) values (p_sirket) on conflict (sirket_id) do nothing;
  update oyun.sirket_denge_durum set tavan_bildirim = p_an
   where sirket_id = p_sirket and (tavan_bildirim is null or tavan_bildirim < p_an - interval '3 days');
  if not found then return; end if;
  select ad into v_ad from oyun.sirketler where id = p_sirket;
  for x in select user_id from oyun.sirket_ortaklari where sirket_id = p_sirket and pay > 0 loop
    perform oyun.bildir(x.user_id, format(
      '%s satış tavanına ulaştı. Mağazanın müşterilere satış kapasitesi sermayesine bağlıdır ve kuruluş döneminde her gün artar. Kalan stok yerinde durur, satış yarın devam eder. Sermayeyi artırırsan satış tavanı da yükselir.',
      v_ad), p_an);
  end loop;
end $function$;

CREATE OR REPLACE FUNCTION oyun.sube_bolge_analiz(p_sirket bigint, p_il smallint, p_fiyat smallint DEFAULT NULL::smallint, p_kalite smallint DEFAULT NULL::smallint, p_an timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
 s oyun.sirketler;ps oyun.pazar_sirket;k oyun.pazar_sektor;u oyun.ulke;
 zt timestamptz:=coalesce(p_an,oyun.simdi());
 vf smallint;vq smallint;price_factor numeric;macro numeric;policy_factor numeric;
 market_size numeric;mine numeric;other_comp numeric:=0;self_count int:=0;
 share_ratio numeric;demand numeric;capacity numeric;revenue numeric;
 wage numeric;fixed_cost numeric;stock numeric;cost numeric;
 sgk numeric;ts jsonb;competitors int:=0;tax_rate numeric;tax numeric;
 advertising numeric;license_rate numeric;lic_fees numeric;pre_tax numeric;net numeric;
 fitout numeric;deposit numeric;opening_stock numeric;training numeric;
 initial_permits numeric;cost_to_open numeric;operating_reserve numeric;
 years_weeks int;city_name text; sector_stock_ratio numeric;enterprise_cost_factor numeric;
 da oyun.sirket_denge_ayar; v_sira int; v_acilis timestamptz; olgun numeric:=1; olcek numeric:=1; carpan numeric:=1; tavan numeric;
 r_rev numeric; r_wage numeric; r_fix numeric; r_stock numeric; r_pre numeric; r_net numeric;
begin
 select * into s from oyun.sirketler where id=p_sirket;
 select * into ps from oyun.pazar_sirket where sirket_id=p_sirket;
 select * into k from oyun.pazar_sektor where kod=s.sektor;
 select * into u from oyun.ulke where id=1;
 select ad into city_name from oyun.iller where id=p_il;
 if s.id is null or ps.sirket_id is null or k.kod is null or city_name is null then
  raise exception 'Şirketin veya ilin geçerli pazar bilgisi bulunamadı.';
 end if;
 vf:=coalesce(p_fiyat,ps.fiyat);
 vq:=coalesce(p_kalite,ps.kalite);
 price_factor:=oyun.pazar_fiyat_katsayi(vf);
 macro:=case when s.sektor in ('enerji','sanayi','insaat') then
  oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.06,0.7,1.4)
  else oyun.sinir(1+(coalesce(u.buyume,3)-3)*0.03+
       (coalesce(u.memnuniyet,50)-50)*0.004,0.8,1.25) end;
 policy_factor:=oyun.sektor_pol_carpan(s.sektor,zt)*oyun.kriz_sektor_carpani(s.sektor,zt);
 market_size:=k.taban*oyun.pazar_il_agirlik(p_il)*macro*policy_factor;
 mine:=(1+0.35*vq+ps.marka/100.0)/power(price_factor,k.esneklik);
 select coalesce(sum((1+0.35*p2.kalite+p2.marka/100.0)/
   power(oyun.pazar_fiyat_katsayi(p2.fiyat),k.esneklik)),0),count(*)
 into other_comp,competitors
 from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id=p2.sirket_id
 where s2.aktif and s2.sektor=s.sektor and s2.id<>s.id
  and (p2.il_id=p_il or exists(
   select 1 from oyun.sirket_il_subeleri sb
    where sb.sirket_id=s2.id and sb.il_id=p_il and sb.acilis<=zt));
 -- Aynı şehirde şirketin mevcut merkezi de bölgesel müşteri talebini paylaşır.
 select (case when ps.il_id=p_il then 1 else 0 end)+count(*) into self_count
 from oyun.sirket_il_subeleri sb
 where sb.sirket_id=p_sirket and sb.il_id=p_il and sb.acilis<=zt;
 share_ratio:=mine/(k.dis*(0.85+least(greatest(
   coalesce((select kasa from oyun.bakanlik_kasa where kod=k.bakanlik),20),0),60)/100.0)
   +other_comp+mine*greatest(1,self_count));
 demand:=market_size*share_ratio;
 capacity:=greatest(15000,least(s.sermaye*k.kapasite*0.8,180000));
 revenue:=round(least(demand,capacity)*price_factor);
 ts:=oyun.bolge_tesvik(p_il);
 sgk:=coalesce((ts->>'sgk_destek')::numeric,0);
 wage:=round(coalesce(u.asgari,30000)/4.3*
    (1.35+0.25*k.personel+0.13*vq)*(1-sgk/100));
 fixed_cost:=round(greatest(2500,coalesce(u.asgari,30000)*0.12)*
    oyun.il_kurulus_endeksi(p_il));
 sector_stock_ratio:=case
  when s.sektor='market' then 0.78
  when s.sektor in ('ticaret','e_ticaret','yapi_market','mobilya_magaza',
                  'elektronik_magaza','tekstil_magaza') then 0.63
  when s.sektor in ('akaryakit','oto_galeri') then 0.83
  when s.sektor in ('turizm','danismanlik','ozel_okul','ozel_hastane','oto_servis')
   then 0.28
  else 0.42 end;
 stock:=round(revenue*sector_stock_ratio);
 cost:=wage+fixed_cost+stock;
 advertising:=round(revenue*(array[0,0.015,0.03,0.05])[coalesce(ps.reklam,0)+1]);
 license_rate:=coalesce((select oran from oyun.il_ruhsat where il_id=p_il),0);
 lic_fees:=round(revenue*license_rate/100);
 pre_tax:=revenue-cost-advertising-lic_fees;
 tax_rate:=coalesce(nullif(oyun.eko_vergi_oran('kurumlar'),0),
                    (select kurumlar from oyun.pazar_ayar where id=1));
 tax:=round(greatest(0,pre_tax)*tax_rate/100*
    (1-coalesce((ts->>'vergi_indirim')::numeric,0)/100));
 net:=pre_tax-tax;

 enterprise_cost_factor:=case when s.sektor='market' then 0.90
   when s.sektor in ('ticaret','e_ticaret','tekstil_magaza','elektronik_magaza','mobilya_magaza','yapi_market') then 0.75
   when s.sektor in ('turizm','ozel_hastane','sanayi','enerji') then 1.80
   when s.sektor in ('akaryakit','oto_galeri') then 1.55
   else 1.10 end;
 fitout:=round(greatest(35000*oyun.il_kurulus_endeksi(p_il),revenue*enterprise_cost_factor));
 deposit:=round(fixed_cost*6);
 opening_stock:=round(stock*1.5);
 training:=round(wage*1.5);
 initial_permits:=round(greatest(6000,revenue*0.04));
 cost_to_open:=fitout+deposit+opening_stock+training+initial_permits;
 operating_reserve:=round(greatest(20000,(wage+fixed_cost+stock*0.28)*2));

 -- ŞİRKET KAZANÇ DENGESİ (şube): açılış bedeli ve rezerv yukarıdaki ham değerlerle kalır.
 -- Ham değerler şirket havuzu için ayrıca döner; haftalik_* alanları şubenin tek başına
 -- (kendi tavanı ve kuruluş verimiyle) beklenen kazancını gösterir.
 r_rev:=revenue; r_wage:=wage; r_fix:=fixed_cost; r_stock:=stock; r_pre:=pre_tax; r_net:=net;
 select x.rn,x.acilis into v_sira,v_acilis from (
   select sb.il_id,sb.acilis,row_number() over (order by sb.acilis,sb.id) rn
   from oyun.sirket_il_subeleri sb where sb.sirket_id=p_sirket and sb.acilis<=zt) x
 where x.il_id=p_il order by x.rn limit 1;
 if v_sira is null then
   select count(*)+1 into v_sira from oyun.sirket_il_subeleri sb where sb.sirket_id=p_sirket and sb.acilis<=zt;
 end if;
 da:=oyun.sd_ayar();
 if da.aktif then
   if v_acilis is not null then
     -- Geçiş dönemi: denge başlamadan önce açılmış şube, şirketin kapsam oranı kadar olgun sayılır.
     if v_acilis < da.baslangic then
       v_acilis:=v_acilis-(coalesce((select d.gecis_kapsam from oyun.sirket_denge_durum d where d.sirket_id=p_sirket),0)*da.olgun_gun)::double precision*interval '1 day';
     end if;
     olgun:=oyun.sd_olgunluk_h(v_acilis,zt,da.olgun_bas,da.olgun_gun);
   end if;
   tavan:=cost_to_open*greatest(coalesce(da.sube_taban,0),da.sube_oran*power(greatest(1,v_sira)::numeric,-da.sube_us))/100;
   if pre_tax>0 then olcek:=oyun.sd_sikistir(pre_tax,tavan,da.serbest)/pre_tax; end if;
   carpan:=olgun*olcek;
   revenue:=round(revenue*carpan); wage:=round(wage*carpan);
   fixed_cost:=round(fixed_cost*carpan); stock:=round(stock*carpan);
   cost:=wage+fixed_cost+stock;
   advertising:=round(revenue*(array[0,0.015,0.03,0.05])[coalesce(ps.reklam,0)+1]);
   lic_fees:=round(revenue*license_rate/100);
   pre_tax:=revenue-cost-advertising-lic_fees;
   tax:=round(greatest(0,pre_tax)*tax_rate/100*
      (1-coalesce((ts->>'vergi_indirim')::numeric,0)/100));
   net:=pre_tax-tax;
 end if;

 years_weeks:=case when net>0 then ceil(cost_to_open/net)::int+case when da.aktif then 1 else 0 end else null end;
 return jsonb_build_object(
  'il_id',p_il,'il',city_name,'sektor',s.sektor,'sektor_ad',k.ad,
  'haftalik_ciro',revenue,'haftalik_personel',wage,'haftalik_sabit',fixed_cost,
  'haftalik_urun_maliyeti',stock,'haftalik_reklam',advertising,
  'haftalik_harc',lic_fees,'haftalik_vergi',tax,'haftalik_gider',cost+advertising+lic_fees+tax,
  'haftalik_net',net,'pay',round(share_ratio*100,1),'rakip',competitors,
  'dekorasyon_donanim',fitout,'depozito',deposit,'ilk_stok',opening_stock,
  'personel_hazirlik',training,'izin_ruhsat',initial_permits,
  'acilis_maliyeti',cost_to_open,'isletme_rezervi',operating_reserve,
  'gerekli_kasa',cost_to_open+operating_reserve,
  'geri_donus_hafta',years_weeks)
  || jsonb_build_object('sube_sira',v_sira,'verim',round(carpan*100),'olgunluk',round(olgun*100),
  'olgun_oran',olgun,'tavan',round(coalesce(tavan,0)),
  'ham_ciro',r_rev,'ham_personel',r_wage,'ham_sabit',r_fix,'ham_stok',r_stock,'ham_brut',r_pre,'ham_net',r_net);
end $function$;

CREATE OR REPLACE FUNCTION oyun.sube_pazar_tahmin(p_sirket bigint, p_fiyat smallint DEFAULT NULL::smallint, p_kalite smallint DEFAULT NULL::smallint, p_an timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  sb record; d jsonb; zt timestamptz:=coalesce(p_an,oyun.simdi());
  total_sales numeric:=0;total_cost numeric:=0;wage_cost numeric:=0;
  fixed_cost numeric:=0;goods_cost numeric:=0;n integer:=0;details jsonb:='[]'::jsonb;
  m numeric; h_gelir numeric:=0; h_personel numeric:=0; h_sabit numeric:=0; h_stok numeric:=0; h_tavan numeric:=0; h_acilis numeric:=0;
begin
  for sb in
   select a.id,a.il_id from oyun.sirket_il_subeleri a
   where a.sirket_id=p_sirket and a.acilis<=zt
   order by a.il_id,a.id
  loop
    d:=oyun.sube_bolge_analiz(p_sirket,sb.il_id,p_fiyat,p_kalite,zt);
    n:=n+1;
    total_sales:=total_sales+(d->>'haftalik_ciro')::numeric;
    wage_cost:=wage_cost+(d->>'haftalik_personel')::numeric;
    fixed_cost:=fixed_cost+(d->>'haftalik_sabit')::numeric;
    goods_cost:=goods_cost+(d->>'haftalik_urun_maliyeti')::numeric;
    -- Şirket Kazanç Dengesi: şirket havuzu için ham (tavansız) değerler, şubenin kuruluş verimiyle.
    m:=coalesce((d->>'olgun_oran')::numeric,1);
    h_gelir:=h_gelir+coalesce((d->>'ham_ciro')::numeric,(d->>'haftalik_ciro')::numeric)*m;
    h_personel:=h_personel+coalesce((d->>'ham_personel')::numeric,(d->>'haftalik_personel')::numeric)*m;
    h_sabit:=h_sabit+coalesce((d->>'ham_sabit')::numeric,(d->>'haftalik_sabit')::numeric)*m;
    h_stok:=h_stok+coalesce((d->>'ham_stok')::numeric,(d->>'haftalik_urun_maliyeti')::numeric)*m;
    h_tavan:=h_tavan+coalesce((d->>'tavan')::numeric,0)*m;
    h_acilis:=h_acilis+coalesce((d->>'acilis_maliyeti')::numeric,0);
    details:=details||jsonb_build_array(jsonb_build_object(
      'id',sb.id,'il_id',sb.il_id,'il',d->>'il',
      'gelir',(d->>'haftalik_ciro')::numeric,
      'personel',(d->>'haftalik_personel')::numeric,
      'kira_enerji',(d->>'haftalik_sabit')::numeric,
      'satis_maliyeti',(d->>'haftalik_urun_maliyeti')::numeric,
      'gider',(d->>'haftalik_personel')::numeric+
        (d->>'haftalik_sabit')::numeric+(d->>'haftalik_urun_maliyeti')::numeric,
      'tahmini_net',(d->>'haftalik_net')::numeric,
      'pazar_payi',(d->>'pay')::numeric,
      'ham_gelir',coalesce((d->>'ham_ciro')::numeric,(d->>'haftalik_ciro')::numeric)*m,
      'ham_personel',coalesce((d->>'ham_personel')::numeric,(d->>'haftalik_personel')::numeric)*m,
      'ham_sabit',coalesce((d->>'ham_sabit')::numeric,(d->>'haftalik_sabit')::numeric)*m,
      'ham_stok',coalesce((d->>'ham_stok')::numeric,(d->>'haftalik_urun_maliyeti')::numeric)*m,
      'ham_net',coalesce((d->>'ham_net')::numeric,(d->>'haftalik_net')::numeric)*m));
  end loop;
  total_cost:=wage_cost+fixed_cost+goods_cost;
  return jsonb_build_object('sube_sayisi',n,
   'gelir',total_sales,'gider',total_cost,'personel',wage_cost,
   'sabit',fixed_cost,'stok',goods_cost,'subeler',details)
   || jsonb_build_object('ham_gelir',h_gelir,'ham_personel',h_personel,'ham_sabit',h_sabit,
   'ham_stok',h_stok,'tavan',h_tavan,'acilis',h_acilis);
end $function$;

CREATE OR REPLACE FUNCTION oyun.pazar_tahmin_ic(p_sirket bigint, p_fiyat smallint DEFAULT NULL::smallint, p_kalite smallint DEFAULT NULL::smallint, p_kaynak text DEFAULT NULL::text, t timestamp with time zone DEFAULT NULL::timestamp with time zone, p_ek_sermaye numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare s oyun.sirketler; ps oyun.pazar_sirket; k oyun.pazar_sektor; u oyun.ulke; zt timestamptz := coalesce(t, oyun.simdi());
  v_f smallint; v_k smallint; v_kay text; w numeric; makro numeric; pol numeric; pazar numeric; dis numeric; kamu numeric;
  ben numeric; toplam numeric; pay numeric; gelir numeric; kap numeric; gider numeric; personel numeric; ruh numeric; ruhsat numeric;
  vergi numeric; net numeric; ceza numeric := 0; kalite_gid numeric; kaynak_gid numeric := 0; rakip int; usd numeric; pold text;
  sabit numeric; talep numeric; reklam_oran numeric; reklam numeric; tes jsonb; kv numeric; sgk numeric; brut numeric; v_sube jsonb;
  da oyun.sirket_denge_ayar; ceza_oran numeric := 0; ham_brut numeric; olgun numeric := 1; olcek numeric := 1; carpan numeric := 1;
  tavan numeric; tavan_yuzde numeric; destek numeric := 0; diger numeric; hedef numeric; kf numeric; v_not text := '';
  sg numeric; sp numeric; ss numeric; st numeric; acilis numeric := 0; k_merkez numeric; detay jsonb;
  gecis numeric := 0; gecis_g numeric := 0; kv_e numeric;
begin
  select * into s from oyun.sirketler where id = p_sirket;
  select * into ps from oyun.pazar_sirket where sirket_id = p_sirket;
  select * into k from oyun.pazar_sektor where kod = s.sektor;
  if s.id is null or ps.sirket_id is null or k.kod is null then return null; end if;
  s.sermaye := s.sermaye + greatest(0, coalesce(p_ek_sermaye, 0));
  select * into u from oyun.ulke where id = 1;
  v_f := coalesce(p_fiyat, ps.fiyat); v_k := coalesce(p_kalite, ps.kalite);
  v_kay := case when s.sektor = 'enerji' then coalesce(p_kaynak, ps.kaynak, 'dogalgaz') else null end;

  w := oyun.pazar_il_agirlik(ps.il_id);
  makro := case when s.sektor in ('enerji','sanayi','insaat') then oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.06, 0.7, 1.4)
                else oyun.sinir(1 + (coalesce(u.buyume, 3) - 3) * 0.03 + (coalesce(u.memnuniyet, 50) - 50) * 0.004, 0.8, 1.25) end;
  pold := oyun.sektor_pol_durum(s.sektor, zt);
  pol := case pold when 'tesvik' then 1.15 when 'denetim' then 0.92 else 1 end;
  pazar := k.taban * w * makro * pol * oyun.kriz_sektor_carpani(s.sektor, zt);

  kamu := coalesce((select kasa from oyun.bakanlik_kasa where kod = k.bakanlik), 20);
  dis := k.dis * (0.85 + least(greatest(kamu, 0), 60) / 100.0);

  ben := (1 + 0.35 * v_k + ps.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(v_f), k.esneklik);
  select coalesce(sum((1 + 0.35 * p2.kalite + p2.marka / 100.0) / power(oyun.pazar_fiyat_katsayi(p2.fiyat), k.esneklik)), 0), count(*)
    into toplam, rakip
  from oyun.pazar_sirket p2 join oyun.sirketler s2 on s2.id = p2.sirket_id
  where p2.il_id = ps.il_id and s2.sektor = s.sektor and s2.aktif and p2.sirket_id <> s.id;
  pay := ben / (dis + toplam + ben);
  kap := s.sermaye * k.kapasite;
  talep := pazar * pay;
  gelir := least(talep, kap) * oyun.pazar_fiyat_katsayi(v_f);

  tes := oyun.bolge_tesvik(ps.il_id);
  sgk := (tes->>'sgk_destek')::numeric;
  personel := coalesce(u.asgari, 30000) * k.personel * power(greatest(0.25, s.sermaye / 400000.0), 0.7) * (1 - sgk / 100);
  kalite_gid := s.sermaye * case v_k when 1 then 0.01 when 2 then 0.022 when 3 then 0.036 else 0 end;
  sabit := s.sermaye * k.sabit;
  if v_kay = 'komur' then sabit := sabit * 0.75;
  elsif v_kay = 'dogalgaz' then
    usd := coalesce((select fiyat from oyun.piyasa_varlik where kod = 'USD'), 42);
    kaynak_gid := s.sermaye * 0.015 * usd / 42.0;
  elsif v_kay = 'yenilenebilir' then sabit := sabit + s.sermaye * 0.02;
  end if;
  reklam_oran := (array[0, 0.015, 0.03, 0.05])[coalesce(ps.reklam, 0) + 1];
  ruh := coalesce((select oran from oyun.il_ruhsat where il_id = ps.il_id), 0);
  if pold = 'denetim' and (v_k = 0 or v_kay = 'komur') then ceza_oran := 0.12; end if;

  -- Merkez faaliyetinin yanina her ek subenin kendi cirosu ve maliyeti eklenir.
  v_sube := oyun.sube_pazar_tahmin(p_sirket,v_f,v_k,zt);
  da := oyun.sd_ayar();
  if da.aktif then
    -- ŞİRKET KAZANÇ DENGESİ: kuruluş verimi (merkez ve her şube kendi yaşıyla) ×
    -- şirket düzeyinde yumuşak tavan (merkez tavanı + şube tavanları).
    -- Gelir ve giderler aynı çarpanla ölçeklenir; kârlı şirket zarara düşmez.
    olgun := oyun.sd_olgunluk_h(oyun.sd_olgun_bas(s.id, s.kurulus), zt, da.olgun_bas, da.olgun_gun);
    gelir := gelir * olgun; sabit := sabit * olgun; personel := personel * olgun;
    kalite_gid := kalite_gid * olgun; kaynak_gid := kaynak_gid * olgun;
    sg := coalesce((v_sube->>'ham_gelir')::numeric, 0); sp := coalesce((v_sube->>'ham_personel')::numeric, 0);
    ss := coalesce((v_sube->>'ham_sabit')::numeric, 0); st := coalesce((v_sube->>'ham_stok')::numeric, 0);
    acilis := coalesce((v_sube->>'acilis')::numeric, 0);
    -- Şubelere bağlanan sermayenin bir payı merkez tavanından düşülür.
    k_merkez := s.sermaye * (1 - coalesce(da.sube_pay, 0) * least(1::numeric, acilis / greatest(1::numeric, s.sermaye)));
    tavan_yuzde := oyun.sd_tavan_yuzde(k_merkez, da);
    tavan := k_merkez * tavan_yuzde / 100 * olgun + coalesce((v_sube->>'tavan')::numeric, 0);
    ham_brut := (gelir + sg) * (1 - reklam_oran - ruh / 100 - ceza_oran) - sabit - personel - kalite_gid - kaynak_gid - ss - sp - st;
    if ham_brut > 0 then olcek := oyun.sd_sikistir(ham_brut, tavan, da.serbest) / ham_brut; end if;
    gelir := gelir * olcek; sabit := sabit * olcek; personel := personel * olcek;
    kalite_gid := kalite_gid * olcek; kaynak_gid := kaynak_gid * olcek;
    sg := sg * olcek; sp := sp * olcek; ss := ss * olcek; st := st * olcek;
    carpan := olgun * olcek;
    select coalesce(jsonb_agg(jsonb_build_object('id', e->'id', 'il_id', e->'il_id', 'il', e->'il',
        'gelir', round((e->>'ham_gelir')::numeric * olcek),
        'personel', round((e->>'ham_personel')::numeric * olcek),
        'kira_enerji', round((e->>'ham_sabit')::numeric * olcek),
        'satis_maliyeti', round((e->>'ham_stok')::numeric * olcek),
        'gider', round(((e->>'ham_personel')::numeric + (e->>'ham_sabit')::numeric + (e->>'ham_stok')::numeric) * olcek),
        'tahmini_net', round((e->>'ham_net')::numeric * olcek),
        'pazar_payi', e->'pazar_payi')), '[]'::jsonb)
      into detay from jsonb_array_elements(coalesce(v_sube->'subeler', '[]'::jsonb)) e;
  else
    sg := coalesce((v_sube->>'gelir')::numeric,0); sp := coalesce((v_sube->>'personel')::numeric,0);
    ss := coalesce((v_sube->>'sabit')::numeric,0); st := coalesce((v_sube->>'stok')::numeric,0);
    detay := coalesce(v_sube->'subeler','[]'::jsonb);
  end if;
  -- Geçiş dönemi: denge öncesi kurulmuş şirketin eski tahmini ile yeni denge arasındaki sabit fark, süre boyunca eriyerek eklenir.
  if da.aktif then
    gecis_g := oyun.sd_gecis_oran(zt, da);
    if gecis_g > 0 then
      select coalesce(d.gecis_fark, 0) into gecis from oyun.sirket_denge_durum d where d.sirket_id = s.id;
      gecis := coalesce(gecis, 0) * gecis_g;
    end if;
  end if;
  gelir := gelir + sg;
  if gecis > 0 then
    kv_e := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), (select kurumlar from oyun.pazar_ayar where id = 1)) / 100
            * (1 - (tes->>'vergi_indirim')::numeric / 100);
    gelir := gelir + gecis / greatest(0.05, (1 - reklam_oran - ruh / 100 - ceza_oran) * (1 - kv_e));
  end if;
  sabit := sabit + ss;
  personel := personel + sp;
  reklam := gelir * reklam_oran;
  gider := sabit + personel + kalite_gid + kaynak_gid + reklam + st;

  ceza := gelir * ceza_oran;
  ruhsat := gelir * ruh / 100;
  brut := gelir - gider - ruhsat - ceza;

  -- Kuruluş koruması: ilk günlerde işletme zararı yazılmaz (en ucuz fiyat politikası hariç).
  if da.aktif and brut < 0 and v_f >= 2 and coalesce(da.koruma_gun, 0) > 0
     and zt < s.kurulus + make_interval(days => da.koruma_gun + 1) then
    diger := gider - reklam;
    -- Günlük hesaptaki ±%12 oynamada da zarara düşmemesi için %12 pay bırakılır.
    hedef := greatest(0, gelir - ruhsat - ceza - reklam) * 0.88;
    if diger > 0 and hedef < diger then
      kf := hedef / diger;
      destek := diger - hedef;
      sabit := sabit * kf; personel := personel * kf; kalite_gid := kalite_gid * kf; kaynak_gid := kaynak_gid * kf;
      gider := hedef + reklam;
      brut := gelir - gider - ruhsat - ceza;
    end if;
  end if;

  kv := coalesce(nullif(oyun.eko_vergi_oran('kurumlar'), 0), (select kurumlar from oyun.pazar_ayar where id = 1));
  vergi := greatest(0, brut) * kv / 100 * (1 - (tes->>'vergi_indirim')::numeric / 100);
  net := brut - vergi;

  if da.aktif and olgun < 0.995 then
    v_not := format(' · kuruluş dönemi verimi %%%s (her gün artar)%s', round(olgun * 100),
      case when olcek < 0.95 and gecis <= 0 then ' · kazanç tavanı uygulandı' else '' end);
  end if;
  if da.aktif and olgun >= 0.995 and olcek < 0.95 and gecis <= 0 then v_not := ' · kazanç tavanı uygulandı'; end if;
  if destek > 0 then v_not := v_not || ' · kuruluş koruması zararı karşıladı'; end if;

  return jsonb_build_object('sube_sayisi',coalesce((v_sube->>'sube_sayisi')::int,0),
    'sube_gelir',round(sg),
    'sube_gider',round(sp + ss + st),
    'sube_detaylar',detay,
    'pazar', round(pazar), 'pay', round(pay * 100, 1), 'rakip', rakip, 'gelir', round(gelir),
    'talep', round(talep), 'kapasite', round(kap), 'kapasite_dolu', talep >= kap - 1, 'gider', round(gider), 'personel', round(personel),
    'kalite_gider', round(kalite_gid), 'kaynak_gider', round(kaynak_gid), 'sabit', round(sabit), 'reklam', round(reklam),
    'reklam_seviye', coalesce(ps.reklam, 0),
    'ruhsat', round(ruhsat), 'ruhsat_oran', ruh, 'ceza', round(ceza), 'vergi', round(vergi), 'net', round(net),
    'gunluk_net', round(net / 7), 'kurumlar_orani', kv,
    'bolge', (tes->>'bolge')::int, 'vergi_indirim', (tes->>'vergi_indirim')::int, 'sgk_destek', (tes->>'sgk_destek')::int,
    'politika', pold, 'kamu_guc', round(dis, 2),
    'fiyat', v_f, 'kalite', v_k, 'kaynak', v_kay, 'getiri', round(net / nullif(s.sermaye, 0) * 100, 1))
    || jsonb_build_object('denge', coalesce(da.aktif, false), 'verim', round(carpan * 100), 'olgunluk', round(olgun * 100),
    'olcek', round(olcek * 100), 'tavan_oran', round(coalesce(tavan_yuzde, 0), 2), 'tavan', round(coalesce(tavan, 0)),
    'kurulus_destek', round(destek), 'verim_not', v_not);
end $function$;

CREATE OR REPLACE FUNCTION oyun.pazar_tahmin(p_sirket bigint, p_fiyat smallint DEFAULT NULL::smallint, p_kalite smallint DEFAULT NULL::smallint, p_kaynak text DEFAULT NULL::text, t timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select oyun.pazar_tahmin_ic(p_sirket, p_fiyat, p_kalite, p_kaynak, t, 0)
$function$;

CREATE OR REPLACE FUNCTION oyun.halka_arz_net_tahmin(p_sirket bigint, p_ek_sermaye numeric DEFAULT 0)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare s oyun.sirketler; v jsonb; ek numeric := greatest(0, coalesce(p_ek_sermaye, 0));
begin
  select * into s from oyun.sirketler where id = p_sirket and aktif;
  if s.id is null then raise exception 'Şirket bulunamadı'; end if;
  v := oyun.pazar_tahmin_ic(p_sirket, null, null, null, null, ek);
  if v is null then return oyun.sirket_ort_net(s.sermaye + ek, s.sektor); end if;
  return (v->>'net')::numeric;
end $function$;

CREATE OR REPLACE FUNCTION oyun.sirket_denge_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a oyun.sirket_denge_ayar := oyun.sd_ayar(); t timestamptz := oyun.simdi(); r record; x record;
  h jsonb; h2 jsonb; metin text; n1 int := 0; n2 int := 0; hata int := 0;
begin
  if not pg_try_advisory_xact_lock(hashtext('oyun.sirket_denge_tick')) then return jsonb_build_object('kilitli', true); end if;

  insert into oyun.sirket_denge_durum(sirket_id, sermaye_iz, olgun_bas)
    select s.id, s.sermaye, s.kurulus from oyun.sirketler s where s.aktif
    on conflict (sirket_id) do nothing;
  update oyun.sirket_denge_durum d
     set sermaye_iz = coalesce(d.sermaye_iz, s.sermaye), olgun_bas = coalesce(d.olgun_bas, s.kurulus)
    from oyun.sirketler s where s.id = d.sirket_id and (d.sermaye_iz is null or d.olgun_bas is null);
  -- Sermaye arttıysa kuruluş verimi başlangıcı, yeni paranın payı kadar ileri alınır.
  update oyun.sirket_denge_durum d
     set olgun_bas = least(t, d.olgun_bas + (t - d.olgun_bas) * ((s.sermaye - d.sermaye_iz) / s.sermaye)::double precision),
         sermaye_iz = s.sermaye
    from oyun.sirketler s
   where s.id = d.sirket_id and s.aktif and s.sermaye > 0 and s.sermaye > d.sermaye_iz * 1.001 and t > d.olgun_bas;
  update oyun.sirket_denge_durum d set sermaye_iz = s.sermaye
    from oyun.sirketler s where s.id = d.sirket_id and s.sermaye < d.sermaye_iz;

  if not coalesce(a.aktif, false) then return jsonb_build_object('aktif', false); end if;

  -- 1) Tanıtım: her şirkete bir kez.
  for r in select d.sirket_id, s.ad, s.kurulus from oyun.sirket_denge_durum d join oyun.sirketler s on s.id = d.sirket_id
           where s.aktif and d.tanitim is null and exists (select 1 from oyun.pazar_sirket p where p.sirket_id = s.id)
           order by d.sirket_id limit 200 loop
    begin
      update oyun.sirket_denge_durum set tanitim = t where sirket_id = r.sirket_id;
      if r.kurulus < a.baslangic then
        metin := format('Şirket Kazanç Dengesi yürürlüğe girdi (%s için tahminler güncellendi). Kısaca: 1) Yeni şirket ve şubeler ilk gün %%%s verimle çalışır; kazanç her gün artar ve %s günde tam kapasiteye ulaşır. 2) Şirket büyüdükçe toplam kazanç artar, ama her liranın getirisi azalır; sermaye artırmak ve şube açmak kazanç tavanını yükseltir. 3) Mağazaların müşteriye satışı sermayeye bağlı bir tavana tabidir; önerilen fiyatın çok üstündeki ürünü müşteri almaz. Amaç kısa sürede aşırı kazancı önlemek, emek ve yatırımla büyüyen şirketi ödüllendirmektir.',
          r.ad, round(a.olgun_bas * 100), a.olgun_gun);
      else
        metin := format('%s kuruldu, hayırlı olsun. Yeni şirket müşteri çevresini zamanla kurar: ilk gün yaklaşık %%%s verimle çalışır, kazancı her gün artar ve %s günde tam kapasiteye ulaşır. İlk %s gün işletme zararına karşı kuruluş koruması vardır (en ucuz fiyat politikası hariç). Şirket büyüdükçe toplam kazancın artar; sermaye artırmak ve şube açmak kazanç tavanını yükseltir.',
          r.ad, round(a.olgun_bas * 100), a.olgun_gun, a.koruma_gun);
      end if;
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = r.sirket_id and pay > 0 loop
        perform oyun.bildir(x.user_id, metin, t);
      end loop;
      n1 := n1 + 1;
    exception when others then hata := hata + 1;
    end;
  end loop;

  -- 2) Tam kapasite: kuruluş dönemi bitince bir kez, büyüme tahminiyle.
  for r in select d.sirket_id, s.ad, s.sermaye from oyun.sirket_denge_durum d join oyun.sirketler s on s.id = d.sirket_id
           where s.aktif and d.olgun is null and d.tanitim is not null
             and oyun.sd_olgunluk_h(coalesce(d.olgun_bas, s.kurulus), t, a.olgun_bas, a.olgun_gun) >= 1
             and exists (select 1 from oyun.pazar_sirket p where p.sirket_id = s.id)
           order by d.sirket_id limit 200 loop
    begin
      update oyun.sirket_denge_durum set olgun = t where sirket_id = r.sirket_id;
      h := oyun.pazar_tahmin_ic(r.sirket_id);
      h2 := oyun.pazar_tahmin_ic(r.sirket_id, null, null, null, null, r.sermaye);
      metin := format('%s tam kapasiteye ulaştı: kuruluş dönemi bitti. Haftalık net kâr tahmini %s ₺.', r.ad, oyun.tl((h->>'net')::numeric));
      if (h2->>'net')::numeric > (h->>'net')::numeric * 1.05 and (h->>'net')::numeric > 0 then
        metin := metin || format(' Büyüme fırsatı: sermayeyi %s ₺''ye çıkarırsan haftalık net yaklaşık %s ₺ olur (yeni sermaye %s günde olgunlaşır). Şube açmak da kazanç tavanını yükseltir.',
          oyun.tl(r.sermaye * 2), oyun.tl((h2->>'net')::numeric), a.olgun_gun);
      end if;
      for x in select user_id from oyun.sirket_ortaklari where sirket_id = r.sirket_id and pay > 0 loop
        perform oyun.bildir(x.user_id, metin, t);
      end loop;
      n2 := n2 + 1;
    exception when others then hata := hata + 1;
    end;
  end loop;
  return jsonb_build_object('tanitim', n1, 'olgun', n2, 'hata', hata);
end $function$;

-- Mevcut büyük işlevlere küçük, doğrulamalı yamalar. Bir işlevin bütün hedef metinleri tam 1'er kez bulunursa
-- hepsi birlikte uygulanır; biri eksikse o işleve hiç dokunulmaz (uyarı verir, kurulumu durdurmaz); yamalıysa atlar.
create or replace function oyun.sd_yama(p_fn text, p_isaret text, p_cift text[])
returns boolean language plpgsql set search_path to '' as $sdyama$
declare r regprocedure := to_regprocedure(p_fn); d text; i int; n int;
begin
  if r is null then raise warning 'sd_yama atlandı (işlev yok): %', p_fn; return false; end if;
  d := pg_get_functiondef(r);
  if position(p_isaret in d) > 0 then return false; end if;
  for i in 1 .. coalesce(array_length(p_cift, 1), 0) / 2 loop
    n := (length(d) - length(replace(d, p_cift[2*i-1], ''))) / length(p_cift[2*i-1]);
    if n <> 1 then
      raise warning 'sd_yama atlandı (% içinde beklenen metin % kez bulundu): «%»', p_fn, n, left(p_cift[2*i-1], 70);
      return false;
    end if;
    d := replace(d, p_cift[2*i-1], p_cift[2*i]);
  end loop;
  if position(p_isaret in d) = 0 then raise warning 'sd_yama atlandı (işaret yeni gövdede yok): % [%]', p_fn, p_isaret; return false; end if;
  execute d;
  return true;
end $sdyama$;

-- oyun.pazar_hesapla: günlük kayıt açıklamasına verim notu; "zarar ediyor" uyarısı yalnız gerçekten zarardaysa
select oyun.sd_yama('oyun.pazar_hesapla(bigint)', 'verim_not', array[
  $e$case when b2b_in > 0 then format(', şirketlerden %s ₺ satış', oyun.tl(b2b_in)) else '' end),$e$,
  $y$case when b2b_in > 0 then format(', şirketlerden %s ₺ satış', oyun.tl(b2b_in)) else '' end) || coalesce(h->>'verim_not', ''),$y$,
  $e$if kasa_son < s.sermaye * 0.25 and (ps.son_uyari is null$e$,
  $y$if kasa_son < s.sermaye * 0.25 and coalesce(net, 0) < 0 and (ps.son_uyari is null$y$
]::text[]);

-- oyun.eko_ticaret_tick: fiyat esnekliği, lüks ürün fiyat sınırı, sermayeye bağlı haftalık ciro tavanı
select oyun.sd_yama('oyun.eko_ticaret_tick()', 'sd_perakende_talep', array[
  $e$ v_donem timestamptz:=date_trunc('hour',now());$e$,
  $y$ v_donem timestamptz:=date_trunc('hour',now());
 sd_w numeric; sd_hafta numeric:=0; sd_gun numeric:=0;$y$,
  $e$faktor:=greatest(.12,least(1.4,(item.onerilen_satis*coalesce(mag.fd,1)/greatest(item.satis_fiyati,1))^.8))$e$,
  $y$faktor:=oyun.sd_perakende_talep(item.onerilen_satis*coalesce(mag.fd,1),item.satis_fiyati)$y$,
  $e$%greatest(2,7-item.talep)=0$e$,
  $y$%greatest(2,7-item.talep)=0 and oyun.sd_luks_satar(item.onerilen_satis*coalesce(mag.fd,1),item.satis_fiyati)$y$,
  $e$if v_sehir_kalan<=0 then continue;end if;$e$,
  $y$if v_sehir_kalan<=0 then continue;end if;
  -- Şirket Kazanç Dengesi: mağazanın haftalık NPC satış cirosu tavanı (günlük payı 1/7).
  sd_w:=oyun.sd_perakende_tavan(mag.sirket_id,t);
  if sd_w is not null then
    select coalesce(sum(ns.ciro),0),
           coalesce(sum(ns.ciro) filter (where ns.donem>=(t at time zone 'Europe/Istanbul')::date at time zone 'Europe/Istanbul'),0)
      into sd_hafta,sd_gun
    from oyun.eko_npc_satis ns
    where ns.sirket_id=mag.sirket_id and ns.donem>=greatest(t-interval '7 days',oyun.sd_baslangic());
    if sd_hafta>=sd_w or sd_gun>=sd_w/7 then
      perform oyun.sd_tavan_bildir(mag.sirket_id,t);
      continue;
    end if;
  end if;$y$,
  $e$siparis:=least(item.adet,talep,v_saat_kalan,v_sehir_kalan);$e$,
  $y$siparis:=least(item.adet,talep,v_saat_kalan,v_sehir_kalan);
    if sd_w is not null and siparis>0 then
      siparis:=oyun.sd_perakende_adet(siparis,item.satis_fiyati,sd_w,sd_hafta,sd_gun);
    end if;$y$,
  $e$satilan:=satilan+siparis;$e$,
  $y$satilan:=satilan+siparis;
    sd_hafta:=sd_hafta+ciro; sd_gun:=sd_gun+ciro;$y$
]::text[]);

-- oyun.npc_isletme_tick: günlük brüt kâr tavanı sermaye eğrisine bağlanır (eski yüzde tavanı üst sınır olarak kalır)
select oyun.sd_yama('oyun.npc_isletme_tick()', 'sd_npc_marj_tavan', array[
  $e$v_tavan:=greatest(0,coalesce(s.sermaye,0))*v_tavan_oran/100;$e$,
  $y$v_tavan:=least(greatest(0,coalesce(s.sermaye,0))*v_tavan_oran/100,coalesce(oyun.sd_npc_marj_tavan(s.id,t),'Infinity'::numeric));$y$
]::text[]);

-- public.pazar_danisman: "Kârda" etiketi kuruluş dönemindeki küçük kârı da kârda sayar
select oyun.sd_yama('public.pazar_danisman(bigint)', 's.sermaye * 0.002', array[
  $e$when (h->>'net')::numeric > s.sermaye * 0.01 then 'karda'$e$,
  $y$when (h->>'net')::numeric > s.sermaye * 0.002 then 'karda'$y$
]::text[]);

-- Düzenli iş (30 dakikada bir): sermaye izi + bir kerelik bilgilendirmeler.
insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
values ('sirket_denge', 'select oyun.sirket_denge_tick()', 30, 14, 127, true)
on conflict (adim) do nothing;

-- Yönetim portalı ayarları (kod yazmadan değiştirilebilir).
insert into oyun.yp_ayar_katalog(anahtar, tablo, sutun, satir, grup, baslik, aciklama, tur, birim, en_az, en_cok, en_uzun, risk, etki, sira, aktif) values
('sirket_denge.aktif','oyun.sirket_denge_ayar','aktif',null,'ekonomi','Şirket kazanç dengesi','Kuruluş dönemi verimi, sermayeye bağlı kazanç tavanı, şube tavanı ve mağaza satış tavanı. Kapatılırsa eski (tavansız) hesap geçerli olur.','evet_hayir',null,null,null,null,'yuksek','Hemen: bir sonraki tahmin ve günlük hesapta.',80,true),
('sirket_denge.olgun_bas','oyun.sirket_denge_ayar','olgun_bas',null,'ekonomi','Yeni şirketin ilk gün verimi','Yeni şirket ve şubenin ilk gün çalıştığı verim (0,35 = %35). Zamanla 1''e çıkar.','sayi',null,0.05,1,null,'orta','Hemen: bir sonraki tahmin ve günlük hesapta.',81,true),
('sirket_denge.olgun_gun','oyun.sirket_denge_ayar','olgun_gun',null,'ekonomi','Tam kapasiteye ulaşma süresi','Yeni şirket, şube ve yeni sermayenin tam verime ulaştığı gün sayısı.','tamsayi','gün',1,120,null,'orta','Hemen: bir sonraki tahmin ve günlük hesapta.',82,true),
('sirket_denge.koruma_gun','oyun.sirket_denge_ayar','koruma_gun',null,'ekonomi','Kuruluş koruması süresi','Yeni şirkete işletme zararı yazılmayan gün sayısı (0 = koruma yok).','tamsayi','gün',0,30,null,'dusuk','Hemen: bir sonraki günlük hesapta.',83,true),
('sirket_denge.tavan_oran','oyun.sirket_denge_ayar','tavan_oran',null,'ekonomi','Küçük şirket haftalık kazanç tavanı','Referans sermayedeki (200 bin ₺) şirketin vergi öncesi haftalık kârının sermayeye oranla üst sınırı.','sayi','%',1,60,null,'yuksek','Hemen: bir sonraki tahmin ve günlük hesapta.',84,true),
('sirket_denge.tavan_us','oyun.sirket_denge_ayar','tavan_us',null,'ekonomi','Büyüdükçe getiri azalma hızı','0 = büyük şirket de aynı oranda kazanır; 0,30 = sermaye 10 katına çıkınca oran yarıya iner. Büyüdükçe makas açılmasını bu ayar önler.','sayi',null,0,1,null,'yuksek','Hemen: bir sonraki tahmin ve günlük hesapta.',85,true),
('sirket_denge.tavan_taban','oyun.sirket_denge_ayar','tavan_taban',null,'ekonomi','Dev şirket haftalık kazanç tabanı','En büyük şirketlerde bile haftalık kazanç tavanı bu oranın altına inmez.','sayi','%',0,60,null,'orta','Hemen: bir sonraki tahmin ve günlük hesapta.',86,true),
('sirket_denge.sube_oran','oyun.sirket_denge_ayar','sube_oran',null,'ekonomi','İlk şubenin haftalık kazanç tavanı','Şubenin vergi öncesi haftalık kârının açılış bedeline oranla üst sınırı (ilk şube). Sonraki şubelerde azalır.','sayi','%',1,60,null,'yuksek','Hemen: bir sonraki tahmin ve günlük hesapta.',87,true),
('sirket_denge.sube_us','oyun.sirket_denge_ayar','sube_us',null,'ekonomi','Şube sayısı arttıkça getiri azalma hızı','0 = her şube aynı; 0,35 = 10. şubenin tavanı ilk şubenin yarısından az.','sayi',null,0,1,null,'orta','Hemen: bir sonraki tahmin ve günlük hesapta.',88,true),
('sirket_denge.sube_pay','oyun.sirket_denge_ayar','sube_pay',null,'ekonomi','Şubeye bağlanan sermayenin merkezden düşülen payı','Aynı para hem merkezde hem şubede kazanç tavanı yaratmasın diye, şube açılış bedellerinin bu oranı merkez tavanı hesabında sermayeden düşülür.','sayi',null,0,1,null,'orta','Hemen: bir sonraki tahmin ve günlük hesapta.',89,true),
('sirket_denge.perakende_kat','oyun.sirket_denge_ayar','perakende_kat',null,'ekonomi','Mağaza satış tavanı katsayısı','Mağazanın müşteriye haftalık satış cirosu tavanı = haftalık kazanç tavanı × bu katsayı.','sayi','×',0.1,50,null,'yuksek','Hemen: bir sonraki saatlik satışta.',90,true),
('sirket_denge.npc_kat','oyun.sirket_denge_ayar','npc_kat',null,'ekonomi','Stoklu işletme kâr tavanı katsayısı','Akaryakıt, yapı market, galeri gibi stoklu işletmelerin günlük brüt kâr tavanı = günlük kazanç tavanı × bu katsayı.','sayi','×',0.1,50,null,'orta','Hemen: bir sonraki satışta.',91,true),
('sirket_denge.fiyat_esneklik','oyun.sirket_denge_ayar','fiyat_esneklik',null,'ekonomi','Pahalı ürüne talep düşüş hızı','Mağaza ürünü önerilen fiyatın üstüne çıktıkça müşteri talebinin ne kadar hızlı düştüğü (3 = iki kat fiyatta talep sekizde bire iner).','sayi',null,0.8,10,null,'orta','Hemen: bir sonraki saatlik satışta.',92,true),
('sirket_denge.gecis_gun','oyun.sirket_denge_ayar','gecis_gun',null,'ekonomi','Eski şirketlerin dengeye geçiş süresi','Denge başlamadan önce kurulmuş, sermayesi satın alınan parayla karşılanmış şirketlerin eski kazançtan yeni dengeye indiği gün sayısı (0 = geçiş yok, hemen yeni denge).','tamsayi','gün',0,180,null,'orta','Hemen: bir sonraki tahmin ve günlük hesapta.',93,true)
on conflict (anahtar) do update set tablo = excluded.tablo, sutun = excluded.sutun, grup = excluded.grup, baslik = excluded.baslik,
  aciklama = excluded.aciklama, tur = excluded.tur, birim = excluded.birim, en_az = excluded.en_az, en_cok = excluded.en_cok,
  risk = excluded.risk, etki = excluded.etki, sira = excluded.sira, aktif = excluded.aktif;

-- Geçiş dönemi (bir kerelik; canlıda 25.11.2026 19:00'da uygulandı). Denge başlamadan önce kurulmuş şirketlerde
-- kapsam = sermayenin, ortakların satın aldığı oyun parasıyla karşılanan oranı (0-1). Kapsamı hesaplanmış
-- şirkete yeniden dokunmaz; dengeden sonra kurulan şirketler geçişe girmez.
do $gecis$
declare r record; v_eski numeric; v_yeni numeric; a oyun.sirket_denge_ayar;
begin
  select * into a from oyun.sirket_denge_ayar where id = 1;
  if a.id is null or not a.aktif then return; end if;
  insert into oyun.sirket_denge_durum(sirket_id, sermaye_iz, olgun_bas)
    select s.id, s.sermaye, s.kurulus from oyun.sirketler s where s.aktif on conflict (sirket_id) do nothing;
  for r in
    select s.id, s.kurulus,
      least(1, greatest(0, coalesce((select sum(o.pay / 100.0 * least(1, coalesce(al.tl, 0) / nullif(s.sermaye * o.pay / 100.0, 0)))
                from oyun.sirket_ortaklari o
                left join (select user_id, sum(miktar) tl from oyun.satin_almalar where not coalesce(iade, false) group by 1) al on al.user_id = o.user_id
                where o.sirket_id = s.id and o.pay > 0), 0))) kapsam
    from oyun.sirketler s join oyun.sirket_denge_durum d on d.sirket_id = s.id
    where s.aktif and s.kurulus < a.baslangic and d.gecis_kapsam is null
  loop
    update oyun.sirket_denge_durum d
       set gecis_kapsam = round(r.kapsam, 4), gecis_fark = 0,
           olgun_bas = case when r.kapsam > 0 then r.kurulus - (r.kapsam * a.olgun_gun)::double precision * interval '1 day' else d.olgun_bas end,
           olgun = case when r.kapsam >= 0.999 then coalesce(d.olgun, now()) else d.olgun end
     where d.sirket_id = r.id;
    if r.kapsam > 0 then
      perform set_config('oyun.sd_test', '0', true);
      v_eski := (oyun.pazar_tahmin(r.id)->>'net')::numeric;
      perform set_config('oyun.sd_test', '', true);
      v_yeni := (oyun.pazar_tahmin(r.id)->>'net')::numeric;
      update oyun.sirket_denge_durum set gecis_fark = round(r.kapsam * greatest(0, coalesce(v_eski, 0) - coalesce(v_yeni, 0))) where sirket_id = r.id;
    end if;
  end loop;
end $gecis$;
