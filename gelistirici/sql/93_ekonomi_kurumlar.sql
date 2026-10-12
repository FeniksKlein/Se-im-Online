-- =====================================================================
--  93) EKONOMİ KURUMLARI: Merkez Bankası, belediye tahvili, SPK, konkordato/iflas
--  - Merkez Bankası: başkanı yürütme başı atar (aday kabul eder, tarafsız olmalı).
--    PPK haftada bir politika faizini belirler (tek kararda en fazla ±10 puan).
--    Faiz oyun.banka_oranlar() üzerinden devlet bankası mevduat/kredi oranlarını,
--    reel faiz de her gün enflasyon ve büyümeyi etkiler. Karar verilene kadar
--    eski formül (enflasyon + banka_reel_faiz, en az %15) geçerlidir.
--  - Belediye tahvili: belediye başkanı 14/30/60 gün vadeli tahvil ihraç eder,
--    oyuncular 48 saat içinde alır; para il kasasına girer, vadede faiziyle
--    kasadan ödenir. Kasa yetmezse temerrüt (kısmi ödeme, memnuniyet −5).
--  - SPK: bağlantılı hesaplar arası ya da 48 saatte karşılıklı hisse işlemleri
--    otomatik incelenir; Hazine ve Maliye Bakanı 72 saatte karar verir. Ceza
--    işlem tutarının %20'si (en az 10.000 ₺) + 7 gün borsa işlem yasağı.
--  - Konkordato/iflas: kasası eksiye düşen şirket konkordato ilan eder (açık
--    sermayenin yarısını geçerse kendiliğinden başlar); 14 günde açık kapanmazsa
--    şirket iflas eder, borsadan çıkar. Bankalar kapsam dışıdır.
--  Oyuncu verisini değiştirmez; yalnız yeni tablo, fonksiyon ve tetik ekler.
--  Canlıya 2026-10-13'te uygulandı (migrations/20261013_ekonomi_kurumlar.sql).
-- =====================================================================

-- ------------------------------------------------------------ Merkez Bankası
create table if not exists oyun.merkez_bankasi(
  id int primary key default 1 check (id=1),
  baskan uuid references oyun.profiller(id),
  atama timestamptz,
  politika_faiz numeric,
  son_karar timestamptz,
  son_etki_gun date,
  son_maas_gun date
);
insert into oyun.merkez_bankasi(id) values(1) on conflict do nothing;
create table if not exists oyun.ppk_kararlari(
  id bigserial primary key, zaman timestamptz not null, baskan uuid, onceki numeric, yeni numeric not null,
  enflasyon numeric, gerekce text
);
create table if not exists oyun.tcmb_teklifleri(
  id bigserial primary key, teklif_eden uuid not null, aday uuid not null, durum text not null default 'bekliyor',
  zaman timestamptz not null
);
create unique index if not exists tcmb_teklif_tek on oyun.tcmb_teklifleri(aday) where durum='bekliyor';
revoke all on oyun.merkez_bankasi, oyun.ppk_kararlari, oyun.tcmb_teklifleri from anon, authenticated;
alter table oyun.merkez_bankasi enable row level security;
alter table oyun.ppk_kararlari enable row level security;
alter table oyun.tcmb_teklifleri enable row level security;

create or replace function oyun.politika_faizi() returns numeric language sql stable set search_path to '' as $$
  select coalesce((select politika_faiz from oyun.merkez_bankasi where id=1),
                  (select greatest(15,round(u.enflasyon+a.banka_reel_faiz,1)) from oyun.ulke u, oyun.ayarlar a where u.id=1 and a.id=1))
$$;

create or replace function oyun.banka_oranlar() returns jsonb language sql stable set search_path to '' as $function$
  with x as (select oyun.politika_faizi() py)
  select jsonb_build_object(
    'politika',py,'vadesiz',0,
    'vadeli1s',round(py / 365.0 / 24.0,3),
    'vadeli3s',round(py / 365.0 * 3 / 24.0,3),
    'vadeli6s',round(py / 365.0 * 6 / 24.0,3),
    'vadeli12s',round(py / 365.0 * 12 / 24.0,3),
    'vadeli24s',round(py / 365.0,3),
    'vadeli7',round(py / 365.0 * 7,3),
    'vadeli30',round(py / 365.0 * 30,3),
    'kredi',round(py/12*1.60,2),
    'gecikme_gunluk',1
  ) from x
$function$;

create or replace function public.tcmb_baskan_ata(p_kad text) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; t timestamptz := oyun.simdi(); v_id bigint;
begin
  perform oyun.cb_zorunlu(p);
  h := oyun.profil_bul(p_kad);
  if h.yasakli then raise exception 'Yasaklı hesaba teklif gönderilemez.'; end if;
  if (select baskan from oyun.merkez_bankasi where id=1) = h.id then raise exception 'Bu oyuncu zaten Merkez Bankası Başkanı.'; end if;
  if exists(select 1 from oyun.makamlar where user_id=h.id and bit is null) then
    raise exception 'Merkez Bankası Başkanı tarafsız olmalı: adayın aktif bir siyasi görevi var.'; end if;
  insert into oyun.tcmb_teklifleri(teklif_eden,aday,zaman) values(p.id,h.id,t)
    on conflict (aday) where durum='bekliyor' do update set teklif_eden=excluded.teklif_eden, zaman=excluded.zaman
    returning id into v_id;
  perform oyun.bildir(h.id, format('%s %s, seni Merkez Bankası Başkanı olarak atamak istiyor. Hayat › Ekonomi merkezi › Merkez Bankası ekranından kabul edebilir ya da reddedebilirsin. Kabul edersen siyasi görev alamazsın; seçilirsen bankadaki görevin biter.', oyun.yurutme_unvan(), p.kad), t);
  return jsonb_build_object('durum','bekliyor','teklif_id',v_id,'aday',h.kad);
end $$;

create or replace function public.tcmb_teklif_yanit(p_teklif bigint, p_kabul boolean) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); k oyun.tcmb_teklifleri; t timestamptz := oyun.simdi(); eski uuid;
begin
  select * into k from oyun.tcmb_teklifleri where id=p_teklif and aday=p.id and durum='bekliyor' for update;
  if k.id is null then raise exception 'Teklif bulunamadı.'; end if;
  if not p_kabul then
    update oyun.tcmb_teklifleri set durum='red' where id=k.id;
    perform oyun.bildir(k.teklif_eden, format('%s, Merkez Bankası Başkanlığı teklifini reddetti.', p.kad), t);
    return jsonb_build_object('durum','red');
  end if;
  if oyun.yurutme_user() is distinct from k.teklif_eden then
    update oyun.tcmb_teklifleri set durum='gecersiz' where id=k.id;
    raise exception 'Teklifi yapan kişi artık yürütmenin başında değil; teklif geçersiz.';
  end if;
  if exists(select 1 from oyun.makamlar where user_id=p.id and bit is null) then
    raise exception 'Aktif siyasi görevin varken Merkez Bankası Başkanı olamazsın.'; end if;
  select baskan into eski from oyun.merkez_bankasi where id=1 for update;
  update oyun.merkez_bankasi set baskan=p.id, atama=t, son_maas_gun=(t at time zone 'Europe/Istanbul')::date where id=1;
  update oyun.tcmb_teklifleri set durum='kabul' where id=k.id;
  update oyun.tcmb_teklifleri set durum='gecersiz' where durum='bekliyor';
  if eski is not null and eski<>p.id then perform oyun.bildir(eski, 'Merkez Bankası Başkanlığı görevin sona erdi; yerine yeni başkan atandı.', t); end if;
  perform oyun.olay('ekonomi', format('%s, Merkez Bankası Başkanı olarak göreve başladı.', p.kad), null, null, t);
  perform oyun.gazete_ekle('icraat', 'Merkez Bankası''na yeni başkan', format('%s atamasıyla %s, Merkez Bankası Başkanlığı görevine getirildi. Piyasalar ilk faiz kararını bekliyor.', oyun.yurutme_unvan(), p.kad), null, t);
  return public.merkez_bankasi();
end $$;

create or replace function public.tcmb_baskan_gorevden_al() returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); eski uuid;
begin
  perform oyun.cb_zorunlu(p);
  select baskan into eski from oyun.merkez_bankasi where id=1 for update;
  if eski is null then raise exception 'Merkez Bankası Başkanlığı zaten boş.'; end if;
  update oyun.merkez_bankasi set baskan=null, atama=null where id=1;
  perform oyun.bildir(eski, format('%s kararıyla Merkez Bankası Başkanlığı görevinden alındın.', oyun.yurutme_unvan()), t);
  perform oyun.olay('ekonomi', format('Merkez Bankası Başkanı %s görevden alındı. Piyasalarda belirsizlik.', oyun.kad(eski)), null, null, t);
  update oyun.pazar_ayar set endeks = round(endeks*0.98,4) where id=1;
  return public.merkez_bankasi();
end $$;

create or replace function public.ppk_faiz_karari(p_faiz numeric, p_gerekce text default null) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); m oyun.merkez_bankasi; t timestamptz := oyun.simdi(); eski numeric; enf numeric;
begin
  select * into m from oyun.merkez_bankasi where id=1 for update;
  if m.baskan is distinct from p.id then raise exception 'Faiz kararını yalnızca Merkez Bankası Başkanı verir.'; end if;
  if p_faiz is null or p_faiz<0 or p_faiz>100 or p_faiz<>round(p_faiz,2) then raise exception 'Politika faizi %%0 ile %%100 arasında, en fazla iki ondalıklı olmalı.'; end if;
  if m.son_karar is not null and m.son_karar > t - interval '7 days' then
    raise exception 'Para Politikası Kurulu haftada bir toplanır. Sonraki karar: %', to_char((m.son_karar + interval '7 days') at time zone 'Europe/Istanbul','DD.MM HH24:MI'); end if;
  eski := oyun.politika_faizi();
  if abs(p_faiz-eski) > 10 then raise exception 'Tek kararda en fazla 10 puan değişiklik yapılabilir (şu an %%%s).', eski; end if;
  select enflasyon into enf from oyun.ulke where id=1;
  update oyun.merkez_bankasi set politika_faiz=p_faiz, son_karar=t,
    son_etki_gun=coalesce(son_etki_gun,(t at time zone 'Europe/Istanbul')::date) where id=1;
  insert into oyun.ppk_kararlari(zaman,baskan,onceki,yeni,enflasyon,gerekce) values(t,p.id,eski,p_faiz,round(enf,2),left(nullif(btrim(p_gerekce),''),500));
  update oyun.pazar_ayar set endeks = round(oyun.sinir(endeks*(1 + (eski-p_faiz)*0.002),0.3,3),4) where id=1;
  perform oyun.olay('ekonomi', format('Merkez Bankası politika faizini %%%s''ten %%%s''e %s.', eski, p_faiz,
    case when p_faiz>eski then 'yükseltti' when p_faiz<eski then 'indirdi' else 'sabit bıraktı' end), null, null, t);
  perform oyun.gazete_ekle('icraat', format('PPK kararı: politika faizi %%%s', p_faiz),
    format('Merkez Bankası Para Politikası Kurulu, politika faizini %%%s seviyesinden %%%s seviyesine getirdi. Yıllık enflasyon %%%s.%s', eski, p_faiz, round(enf,1),
      coalesce(' Gerekçe: '||left(nullif(btrim(p_gerekce),''),300),'')), null, t);
  return public.merkez_bankasi();
end $$;

create or replace function public.merkez_bankasi() returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := oyun.ben(); m oyun.merkez_bankasi; u oyun.ulke; pf numeric;
begin
  select * into m from oyun.merkez_bankasi where id=1;
  select * into u from oyun.ulke where id=1;
  pf := oyun.politika_faizi();
  return jsonb_build_object(
    'baskan', case when m.baskan is null then null else jsonb_build_object('id',m.baskan,'kad',oyun.kad(m.baskan),'atama',m.atama) end,
    'politika_faiz', pf, 'tcmb_karari', m.politika_faiz is not null,
    'enflasyon', round(u.enflasyon,2), 'buyume', round(u.buyume,2), 'reel_faiz', round(pf-u.enflasyon,2),
    'oranlar', oyun.banka_oranlar(),
    'sonraki_karar', case when m.son_karar is null then null else m.son_karar + interval '7 days' end,
    'ben_baskan', m.baskan is not distinct from me and me is not null,
    'ben_atayabilir', oyun.yurutme_user() is not distinct from me and me is not null,
    'yurutme_unvan', oyun.yurutme_unvan(),
    'bekleyen_teklifim', (select jsonb_build_object('id',id,'teklif_eden',oyun.kad(teklif_eden),'zaman',zaman) from oyun.tcmb_teklifleri where aday=me and durum='bekliyor' limit 1),
    'kararlar', coalesce((select jsonb_agg(jsonb_build_object('zaman',zaman,'baskan',oyun.kad(baskan),'onceki',onceki,'yeni',yeni,'enflasyon',enflasyon,'gerekce',gerekce) order by zaman desc)
                 from (select * from oyun.ppk_kararlari order by zaman desc limit 20) k),'[]'::jsonb),
    'kural', 'PPK haftada bir toplanır; tek kararda en fazla 10 puan. Reel faiz (faiz − enflasyon) yüksekse enflasyon düşer ama büyüme yavaşlar; düşükse tersi.'
  );
end $$;

create or replace function oyun.merkez_bankasi_tick(t timestamptz) returns void language plpgsql set search_path to '' as $$
declare m oyun.merkez_bankasi; bugun date := (t at time zone 'Europe/Istanbul')::date; g date; reel numeric; maas numeric;
begin
  select * into m from oyun.merkez_bankasi where id=1 for update;
  if m.baskan is not null and (exists(select 1 from oyun.makamlar where user_id=m.baskan and bit is null)
       or (select yasakli from oyun.profiller where id=m.baskan)) then
    perform oyun.bildir(m.baskan, 'Siyasi görev aldığın için Merkez Bankası Başkanlığın sona erdi.', t);
    perform oyun.olay('ekonomi', format('%s, siyasi görev aldığı için Merkez Bankası Başkanlığından ayrıldı.', oyun.kad(m.baskan)), null, null, t);
    update oyun.merkez_bankasi set baskan=null, atama=null where id=1 returning * into m;
  end if;
  if m.politika_faiz is not null and m.son_etki_gun is not null and m.son_etki_gun < bugun then
    g := greatest(m.son_etki_gun, bugun-31);
    while g < bugun loop
      g := g+1;
      select oyun.politika_faizi() - enflasyon into reel from oyun.ulke where id=1;
      reel := oyun.sinir(reel,-40,40);
      update oyun.ulke set enflasyon = oyun.sinir(enflasyon - reel*0.01, 0, 200),
                           buyume   = oyun.sinir(buyume - reel*0.006, -10, 15) where id=1;
    end loop;
    update oyun.merkez_bankasi set son_etki_gun=bugun where id=1;
  end if;
  if m.baskan is not null and coalesce(m.son_maas_gun, bugun-1) < bugun then
    maas := round(oyun.makam_maasi('bakan', null) / 30);
    perform oyun.para_islem(m.baskan, maas, 'maas', 'Merkez Bankası Başkanlığı günlük maaşı', t);
    update oyun.merkez_bankasi set son_maas_gun=bugun where id=1;
  end if;
end $$;

-- ------------------------------------------------------------ Belediye tahvili
create table if not exists oyun.belediye_tahvil(
  id bigserial primary key, il_id smallint not null references oyun.iller(id), ihrac_eden uuid not null,
  hedef numeric not null, toplanan numeric not null default 0, faiz numeric not null, vade_gun int not null,
  bas timestamptz not null, satis_bit timestamptz not null, vade timestamptz,
  durum text not null default 'satista' check (durum in ('satista','tutuluyor','odendi','temerrut','iptal')),
  odenen numeric, sonuc_zaman timestamptz
);
create index if not exists belediye_tahvil_durum on oyun.belediye_tahvil(durum, satis_bit, vade);
create table if not exists oyun.belediye_tahvil_pay(
  tahvil_id bigint not null references oyun.belediye_tahvil(id), user_id uuid not null, tutar numeric not null, alis timestamptz not null,
  primary key(tahvil_id,user_id)
);
revoke all on oyun.belediye_tahvil, oyun.belediye_tahvil_pay from anon, authenticated;
alter table oyun.belediye_tahvil enable row level security;
alter table oyun.belediye_tahvil_pay enable row level security;

create or replace function oyun.bel_tahvil_tavan(p_il smallint) returns numeric language sql stable set search_path to '' as $$
  select round(greatest(1, coalesce((select kasa from oyun.il_durum where il_id=p_il),0)) * oyun.pazar_tl_milyar())
$$;

create or replace function public.belediye_tahvil_ihrac(p_hedef numeric, p_faiz numeric, p_vade_gun int) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v_il smallint; tavan numeric; acik numeric; yillik numeric; v_id bigint; ilad text;
begin
  select il_id into v_il from oyun.makamlar where tur='bel' and user_id=p.id and bit is null limit 1;
  if v_il is null then raise exception 'Belediye tahvilini yalnızca görevdeki belediye başkanı ihraç edebilir.'; end if;
  if p_vade_gun not in (14,30,60) then raise exception 'Vade 14, 30 veya 60 gün olabilir.'; end if;
  if p_faiz is null or p_faiz<=0 or p_faiz<>round(p_faiz,2) then raise exception 'Dönem faizi pozitif ve en fazla iki ondalıklı olmalı.'; end if;
  yillik := p_faiz*365.0/p_vade_gun;
  if yillik > oyun.politika_faizi()+25 then
    raise exception 'Yıllık karşılığı %%%s; politika faizinin 25 puan üstüne çıkamaz (en fazla %%%s dönem faizi).', round(yillik,1), round((oyun.politika_faizi()+25)*p_vade_gun/365.0,2); end if;
  tavan := oyun.bel_tahvil_tavan(v_il);
  if p_hedef is null or p_hedef<100000 or p_hedef<>round(p_hedef) or p_hedef>tavan then
    raise exception 'Tahvil tutarı 100.000 ₺ ile %s ₺ arasında olmalı (sınır belediye kasasına göre belirlenir).', oyun.tl(tavan); end if;
  select coalesce(sum(case when durum='satista' then hedef else toplanan end),0) into acik from oyun.belediye_tahvil where il_id=v_il and durum in ('satista','tutuluyor');
  if acik + p_hedef > tavan*2 then raise exception 'Belediyenin ödenmemiş tahvil stoku sınırı aşar (en fazla %s ₺ daha).', oyun.tl(greatest(0,tavan*2-acik)); end if;
  if exists(select 1 from oyun.belediye_tahvil where il_id=v_il and durum='satista') then raise exception 'Satışta olan bir tahvil varken yenisi ihraç edilemez.'; end if;
  insert into oyun.belediye_tahvil(il_id,ihrac_eden,hedef,faiz,vade_gun,bas,satis_bit)
    values(v_il,p.id,p_hedef,p_faiz,p_vade_gun,t,t+interval '48 hours') returning id into v_id;
  select ad into ilad from oyun.iller where id=v_il;
  perform oyun.olay('ekonomi', format('%s Belediyesi %s ₺ tutarında, %s gün vadeli, %%%s getirili tahvil ihraç etti. Satış 48 saat sürecek.', ilad, oyun.tl(p_hedef), p_vade_gun, p_faiz), v_il, p.parti_id, t);
  perform oyun.gazete_ekle('icraat', format('%s Belediyesi borçlanmaya gidiyor', ilad),
    format('Belediye Başkanı %s, %s ₺ tutarında %s gün vadeli tahvil ihraç etti. Yatırımcılara dönem sonunda %%%s getiri vaat ediliyor.', p.kad, oyun.tl(p_hedef), p_vade_gun, p_faiz), v_id, t);
  return public.belediye_tahvilleri();
end $$;

create or replace function public.belediye_tahvil_al(p_tahvil bigint, p_tutar numeric) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.belediye_tahvil; ilad text;
begin
  select * into b from oyun.belediye_tahvil where id=p_tahvil for update;
  if b.id is null or b.durum<>'satista' or b.satis_bit<=t then raise exception 'Bu tahvilin satışı kapandı.'; end if;
  if p_tutar is null or p_tutar<1000 or p_tutar<>round(p_tutar) then raise exception 'En az 1.000 ₺, tam sayı tutar gir.'; end if;
  if b.toplanan+p_tutar > b.hedef then raise exception 'Kalan tahvil miktarı %s ₺.', oyun.tl(b.hedef-b.toplanan); end if;
  select ad into ilad from oyun.iller where id=b.il_id;
  perform oyun.para_islem(p.id,-p_tutar,'tahvil',format('%s Belediyesi tahvili #%s alımı',ilad,b.id),t);
  insert into oyun.belediye_tahvil_pay(tahvil_id,user_id,tutar,alis) values(b.id,p.id,p_tutar,t)
    on conflict (tahvil_id,user_id) do update set tutar=oyun.belediye_tahvil_pay.tutar+excluded.tutar;
  update oyun.belediye_tahvil set toplanan=toplanan+p_tutar where id=b.id;
  return public.belediye_tahvilleri();
end $$;

create or replace function public.belediye_tahvilleri() returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := oyun.ben(); v_il smallint;
begin
  select il_id into v_il from oyun.makamlar where tur='bel' and user_id=me and bit is null limit 1;
  return jsonb_build_object(
    'tahviller', coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'il_id',b.il_id,'il',i.ad,'ihrac_eden',oyun.kad(b.ihrac_eden),
        'hedef',b.hedef,'toplanan',b.toplanan,'faiz',b.faiz,'yillik',round(b.faiz*365.0/b.vade_gun,1),'vade_gun',b.vade_gun,
        'satis_bit',b.satis_bit,'vade',b.vade,'durum',b.durum,'odenen',b.odenen,
        'payim',(select tutar from oyun.belediye_tahvil_pay x where x.tahvil_id=b.id and x.user_id=me)) order by b.bas desc)
      from (select * from oyun.belediye_tahvil where durum in ('satista','tutuluyor') or bas > oyun.simdi()-interval '30 days' order by bas desc limit 60) b
      join oyun.iller i on i.id=b.il_id),'[]'::jsonb),
    'belediyem', case when v_il is null then null else jsonb_build_object('il_id',v_il,'il',(select ad from oyun.iller where id=v_il),'tavan',oyun.bel_tahvil_tavan(v_il),
       'acik_stok',(select coalesce(sum(case when durum='satista' then hedef else toplanan end),0) from oyun.belediye_tahvil where il_id=v_il and durum in ('satista','tutuluyor')),
       'max_yillik_faiz', oyun.politika_faizi()+25) end,
    'politika_faiz', oyun.politika_faizi(),
    'kural','Satış 48 saat sürer; hedefin %30''u toplanmazsa iptal edilip para iade edilir. Vadede belediye kasası yetmezse tahvil temerrüde düşer ve yatırımcılar kasadaki kadarını alır.'
  );
end $$;

create or replace function oyun.belediye_tahvil_tick(t timestamptz) returns void language plpgsql set search_path to '' as $$
declare b oyun.belediye_tahvil; x record; ilad text; kur numeric; borc numeric; v_kasa numeric; oran numeric; od numeric; toplam_od numeric; bb uuid;
begin
  kur := oyun.pazar_tl_milyar();
  for b in select * from oyun.belediye_tahvil where durum='satista' and satis_bit<=t order by id for update loop
    select ad into ilad from oyun.iller where id=b.il_id;
    if b.toplanan < b.hedef*0.3 then
      for x in select * from oyun.belediye_tahvil_pay where tahvil_id=b.id loop
        perform oyun.para_islem(x.user_id, x.tutar, 'tahvil', format('%s Belediyesi tahvili #%s iptal: iade', ilad, b.id), t);
      end loop;
      update oyun.belediye_tahvil set durum='iptal', sonuc_zaman=t where id=b.id;
      perform oyun.bildir(b.ihrac_eden, format('%s Belediyesi tahvili yeterli talep görmedi (%s / %s ₺); iptal edildi, paralar iade edildi.', ilad, oyun.tl(b.toplanan), oyun.tl(b.hedef)), t);
      perform oyun.olay('ekonomi', format('%s Belediyesi tahvili yeterli talep görmediği için iptal edildi.', ilad), b.il_id, null, t);
    else
      update oyun.il_durum set kasa=coalesce(kasa,0)+b.toplanan/kur where il_id=b.il_id;
      update oyun.belediye_tahvil set durum='tutuluyor', vade=t+make_interval(days=>b.vade_gun) where id=b.id;
      perform oyun.bildir(b.ihrac_eden, format('%s Belediyesi tahvil satışı tamamlandı: %s ₺ belediye kasasına girdi. Vadede %s ₺ geri ödenecek.', ilad, oyun.tl(b.toplanan), oyun.tl(round(b.toplanan*(1+b.faiz/100)))), t);
      perform oyun.olay('ekonomi', format('%s Belediyesi tahvil satışında %s ₺ topladı.', ilad, oyun.tl(b.toplanan)), b.il_id, null, t);
    end if;
  end loop;
  for b in select * from oyun.belediye_tahvil where durum='tutuluyor' and vade<=t order by vade for update loop
    select ad into ilad from oyun.iller where id=b.il_id;
    borc := round(b.toplanan*(1+b.faiz/100));
    select coalesce(d.kasa,0) into v_kasa from oyun.il_durum d where d.il_id=b.il_id for update;
    v_kasa := coalesce(v_kasa,0);
    oran := case when v_kasa*kur >= borc then 1 else greatest(0, v_kasa*kur/borc) end;
    toplam_od := 0;
    for x in select * from oyun.belediye_tahvil_pay where tahvil_id=b.id loop
      od := floor(x.tutar*(1+b.faiz/100)*oran);
      if od>0 then
        perform oyun.para_islem(x.user_id, od, 'tahvil', format('%s Belediyesi tahvili #%s vade ödemesi%s', ilad, b.id, case when oran<1 then ' (kısmi — temerrüt)' else '' end), t);
        toplam_od := toplam_od+od;
      end if;
      if oran<1 then perform oyun.bildir(x.user_id, format('%s Belediyesi tahvil borcunu ödeyemedi. Alacağının yalnızca %%%s''i ödendi.', ilad, round(oran*100)), t); end if;
    end loop;
    update oyun.il_durum d set kasa=greatest(0,coalesce(d.kasa,0)-toplam_od/kur) where d.il_id=b.il_id;
    if oran<1 then
      update oyun.belediye_tahvil set durum='temerrut', odenen=toplam_od, sonuc_zaman=t where id=b.id;
      update oyun.il_durum d set memnuniyet=greatest(0,d.memnuniyet-5) where d.il_id=b.il_id;
      perform oyun.olay('ekonomi', format('%s Belediyesi tahvil borcunu ödeyemedi: temerrüt! Yatırımcılar alacağının %%%s''ini alabildi.', ilad, round(oran*100)), b.il_id, null, t);
      perform oyun.gazete_ekle('icraat', format('%s Belediyesi temerrüde düştü', ilad),
        format('%s Belediyesi, %s ₺ tutarındaki tahvil borcunu vadesinde ödeyemedi. Yatırımcılar alacağının ancak %%%s''ini tahsil edebildi; kent halkında memnuniyetsizlik büyüyor.', ilad, oyun.tl(borc), round(oran*100)), b.id, t);
      bb := oyun.makam_sahibi('bel',null,b.il_id);
      if bb is not null then perform oyun.bildir(bb, format('%s Belediyesi tahvil borcunu ödeyemedi; kentte memnuniyet 5 puan düştü.', ilad), t); end if;
    else
      update oyun.belediye_tahvil set durum='odendi', odenen=toplam_od, sonuc_zaman=t where id=b.id;
      perform oyun.olay('ekonomi', format('%s Belediyesi %s ₺ tahvil borcunu vadesinde ödedi.', ilad, oyun.tl(toplam_od)), b.il_id, null, t);
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------ SPK
create table if not exists oyun.spk_inceleme(
  id bigserial primary key, sirket_id bigint references oyun.sirketler(id), taraf1 uuid not null, taraf2 uuid,
  tur text not null check (tur in ('bagli_hesap','karsilikli_islem','manipulasyon')),
  kanit jsonb not null default '{}'::jsonb, acan uuid, bas timestamptz not null, bit timestamptz not null,
  durum text not null default 'acik' check (durum in ('acik','ceza','beraat')),
  ceza numeric, karar_veren uuid, karar_not text, karar_zaman timestamptz
);
create index if not exists spk_acik on oyun.spk_inceleme(durum, bit);
create table if not exists oyun.spk_yasak(user_id uuid primary key, bit timestamptz not null, neden text);
revoke all on oyun.spk_inceleme, oyun.spk_yasak from anon, authenticated;
alter table oyun.spk_inceleme enable row level security;
alter table oyun.spk_yasak enable row level security;

create or replace function oyun.spk_yasakli_mi(u uuid) returns boolean language sql stable set search_path to '' as $$
  select exists(select 1 from oyun.spk_yasak where user_id=u and bit>oyun.simdi())
$$;

create or replace function oyun.bagli_hesap_mi(a uuid, b uuid) returns boolean language sql stable set search_path to '' as $$
  select exists(select 1 from oyun.oturumlar x join oyun.oturumlar y on y.user_id=b
                where x.user_id=a and ((x.cihaz is not null and x.cihaz<>'' and x.cihaz=y.cihaz) or (x.iz is not null and x.iz<>'' and x.iz=y.iz)))
$$;

create or replace function oyun.tg_spk_emir() returns trigger language plpgsql set search_path to '' as $$
begin
  if oyun.spk_yasakli_mi(new.satici) then raise exception 'SPK işlem yasağın sürüyor; borsada emir veremezsin.'; end if;
  return new;
end $$;
create or replace function oyun.tg_spk_islem_once() returns trigger language plpgsql set search_path to '' as $$
begin
  if oyun.spk_yasakli_mi(new.alici) then raise exception 'SPK işlem yasağın sürüyor; borsada alım yapamazsın.'; end if;
  if oyun.spk_yasakli_mi(new.satici) then raise exception 'Satıcıya SPK işlem yasağı getirildi; bu emir işlem göremez.'; end if;
  return new;
end $$;

create or replace function oyun.tg_spk_gozetim() returns trigger language plpgsql set search_path to '' as $$
declare v_tur text; k jsonb; t timestamptz := oyun.simdi(); sad text;
begin
  if new.alici is null or new.satici is null or new.alici=new.satici then return new; end if;
  if exists(select 1 from oyun.spk_inceleme where durum='acik' and sirket_id=new.sirket_id
            and ((taraf1=new.alici and taraf2=new.satici) or (taraf1=new.satici and taraf2=new.alici))) then return new; end if;
  if oyun.bagli_hesap_mi(new.alici,new.satici) then
    v_tur := 'bagli_hesap';
  elsif exists(select 1 from oyun.borsa_islem b where b.sirket_id=new.sirket_id and b.alici=new.satici and b.satici=new.alici
               and b.zaman > t - interval '48 hours' and b.id<>new.id) then
    v_tur := 'karsilikli_islem';
  else
    return new;
  end if;
  k := jsonb_build_object('islem_id',new.id,'pay',new.pay,'birim',new.birim,'tutar',new.tutar,
       'iliskili_tutar',(select coalesce(sum(tutar),0) from oyun.borsa_islem b where b.sirket_id=new.sirket_id and b.zaman>t-interval '7 days'
                          and ((b.alici=new.alici and b.satici=new.satici) or (b.alici=new.satici and b.satici=new.alici))));
  insert into oyun.spk_inceleme(sirket_id,taraf1,taraf2,tur,kanit,bas,bit) values(new.sirket_id,new.alici,new.satici,v_tur,k,t,t+interval '72 hours');
  select ad into sad from oyun.sirketler where id=new.sirket_id;
  perform oyun.olay('ekonomi', format('SPK, %s hisselerinde olağandışı işlemler tespit etti ve inceleme başlattı.', sad), null, null, t);
  perform oyun.bildir(new.alici, format('SPK, %s hisselerindeki işlemin hakkında inceleme başlattı. Karar 72 saat içinde.', sad), t);
  perform oyun.bildir(new.satici, format('SPK, %s hisselerindeki işlemin hakkında inceleme başlattı. Karar 72 saat içinde.', sad), t);
  return new;
end $$;

drop trigger if exists spk_emir on oyun.borsa_emir;
create trigger spk_emir before insert on oyun.borsa_emir for each row execute function oyun.tg_spk_emir();
drop trigger if exists spk_islem_once on oyun.borsa_islem;
create trigger spk_islem_once before insert on oyun.borsa_islem for each row execute function oyun.tg_spk_islem_once();
drop trigger if exists spk_gozetim on oyun.borsa_islem;
create trigger spk_gozetim after insert on oyun.borsa_islem for each row execute function oyun.tg_spk_gozetim();

create or replace function oyun.spk_sonuclandir(p_id bigint, p_ceza boolean, p_karar_veren uuid, p_not text, t timestamptz) returns void language plpgsql set search_path to '' as $$
declare i oyun.spk_inceleme; tutar numeric; c numeric; odenen numeric; u uuid; sad text; toplam numeric := 0;
begin
  select * into i from oyun.spk_inceleme where id=p_id and durum='acik' for update;
  if i.id is null then return; end if;
  select ad into sad from oyun.sirketler where id=i.sirket_id;
  if p_ceza then
    tutar := greatest(coalesce((i.kanit->>'iliskili_tutar')::numeric,(i.kanit->>'tutar')::numeric,0), coalesce((i.kanit->>'tutar')::numeric,0));
    c := greatest(10000, round(tutar*0.20));
    foreach u in array array_remove(array[i.taraf1,i.taraf2],null) loop
      odenen := oyun.tahsil_et(u, c, false, format('SPK idari para cezası (%s, inceleme #%s)', coalesce(sad,'borsa'), i.id), t);
      toplam := toplam + coalesce(odenen,0);
      insert into oyun.spk_yasak(user_id,bit,neden) values(u,t+interval '7 days',format('SPK inceleme #%s',i.id))
        on conflict (user_id) do update set bit=greatest(oyun.spk_yasak.bit,excluded.bit), neden=excluded.neden;
      perform oyun.bildir(u, format('SPK kararı: %s hisselerindeki işlemlerin piyasa dolandırıcılığı sayıldı. %s ₺ idari para cezası ve 7 gün borsa işlem yasağı.', coalesce(sad,'—'), oyun.tl(c)), t);
    end loop;
    if toplam>0 then update oyun.ulke set hazine=hazine+toplam/oyun.pazar_tl_milyar() where id=1; end if;
    update oyun.spk_inceleme set durum='ceza', ceza=c, karar_veren=p_karar_veren, karar_not=p_not, karar_zaman=t where id=i.id;
    perform oyun.olay('ekonomi', format('SPK, %s hisselerinde işlem yapan %s hakkında ceza kararı verdi: kişi başı %s ₺ ve 7 gün işlem yasağı.', coalesce(sad,'—'),
       concat_ws(' ve ', oyun.kad(i.taraf1), case when i.taraf2 is not null then oyun.kad(i.taraf2) end), oyun.tl(c)), null, null, t);
    perform oyun.gazete_ekle('icraat', 'SPK''dan borsa cezası', format('Sermaye Piyasası Kurulu, %s hisselerindeki şüpheli işlemlerle ilgili incelemesini cezayla sonuçlandırdı.', coalesce(sad,'—')), i.id, t);
  else
    update oyun.spk_inceleme set durum='beraat', karar_veren=p_karar_veren, karar_not=p_not, karar_zaman=t where id=i.id;
    foreach u in array array_remove(array[i.taraf1,i.taraf2],null) loop
      perform oyun.bildir(u, format('SPK, %s hisselerindeki işlemlerin hakkındaki incelemeyi kapattı; ihlal bulunmadı.', coalesce(sad,'—')), t);
    end loop;
  end if;
end $$;

create or replace function public.spk_inceleme_ac(p_sirket bigint, p_kad text, p_aciklama text) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; t timestamptz := oyun.simdi(); s oyun.sirketler; v_tutar numeric;
begin
  if oyun.bakanlik_yetkilisi('maliye') is distinct from p.id then raise exception 'SPK incelemesini Hazine ve Maliye Bakanı başlatır (bakanlık boşsa yürütme başı).'; end if;
  select * into s from oyun.sirketler where id=p_sirket and aktif and halka_acik;
  if s.id is null then raise exception 'Borsada işlem gören şirket bulunamadı.'; end if;
  h := oyun.profil_bul(p_kad);
  select coalesce(sum(tutar),0) into v_tutar from oyun.borsa_islem where sirket_id=s.id and (alici=h.id or satici=h.id) and zaman>t-interval '14 days';
  if v_tutar=0 then raise exception 'Bu oyuncunun son 14 günde bu şirkette borsa işlemi yok.'; end if;
  if exists(select 1 from oyun.spk_inceleme where durum='acik' and sirket_id=s.id and (taraf1=h.id or taraf2=h.id)) then raise exception 'Bu konuda açık inceleme zaten var.'; end if;
  if (select count(*) from oyun.spk_inceleme where acan=p.id and bas>t-interval '24 hours')>=3 then raise exception 'Günde en fazla 3 inceleme başlatılabilir.'; end if;
  update oyun.bakanlik_kasa set kasa=kasa-0.5 where kod='maliye' and kasa>=0.5;
  if not found then raise exception 'Maliye Bakanlığı kasasında 0,5 milyar ₺ gerekli.'; end if;
  insert into oyun.spk_inceleme(sirket_id,taraf1,tur,kanit,acan,bas,bit)
    values(s.id,h.id,'manipulasyon',jsonb_build_object('tutar',v_tutar,'iliskili_tutar',v_tutar,'iddia',left(coalesce(p_aciklama,''),500)),p.id,t,t+interval '72 hours');
  perform oyun.bildir(h.id, format('SPK, %s hisselerindeki işlemlerin hakkında manipülasyon incelemesi başlattı.', s.ad), t);
  perform oyun.olay('ekonomi', format('SPK, %s hisselerinde manipülasyon iddiasıyla inceleme başlattı.', s.ad), null, p.parti_id, t);
  return public.spk_ekrani();
end $$;

create or replace function public.spk_karar(p_id bigint, p_ceza boolean, p_not text default null) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if oyun.bakanlik_yetkilisi('maliye') is distinct from p.id then raise exception 'SPK kararını Hazine ve Maliye Bakanı verir.'; end if;
  if not exists(select 1 from oyun.spk_inceleme where id=p_id and durum='acik') then raise exception 'Açık inceleme bulunamadı.'; end if;
  if exists(select 1 from oyun.spk_inceleme where id=p_id and (taraf1=p.id or taraf2=p.id)) then raise exception 'Taraf olduğun incelemede karar veremezsin.'; end if;
  perform oyun.spk_sonuclandir(p_id, p_ceza, p.id, left(nullif(btrim(p_not),''),500), oyun.simdi());
  return public.spk_ekrani();
end $$;

create or replace function public.spk_ekrani() returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := oyun.ben();
begin
  return jsonb_build_object(
    'yetkili', oyun.bakanlik_yetkilisi('maliye') is not distinct from me and me is not null,
    'yasagim', (select bit from oyun.spk_yasak where user_id=me and bit>oyun.simdi()),
    'sirketler', coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad) order by ad) from oyun.sirketler where aktif and halka_acik),'[]'::jsonb),
    'incelemeler', coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'sirket',s.ad,'sirket_id',i.sirket_id,'taraf1',oyun.kad(i.taraf1),
        'taraf2',case when i.taraf2 is null then null else oyun.kad(i.taraf2) end,'tur',i.tur,
        'tur_ad',case i.tur when 'bagli_hesap' then 'Bağlantılı hesaplar arası işlem' when 'karsilikli_islem' then 'Karşılıklı al-sat (fiyat şişirme şüphesi)' else 'Manipülasyon iddiası' end,
        'tutar',i.kanit->>'iliskili_tutar','iddia',i.kanit->>'iddia','acan',case when i.acan is null then 'Otomatik gözetim' else oyun.kad(i.acan) end,
        'taraf_benim', i.taraf1=me or i.taraf2=me,
        'bas',i.bas,'bit',i.bit,'durum',i.durum,'ceza',i.ceza,'karar_not',i.karar_not) order by i.bas desc)
      from (select * from oyun.spk_inceleme order by bas desc limit 40) i left join oyun.sirketler s on s.id=i.sirket_id),'[]'::jsonb),
    'kural','Bağlantılı hesaplar arasındaki veya 48 saat içinde karşılıklı yapılan hisse işlemleri otomatik incelemeye alınır. Hazine ve Maliye Bakanı 72 saat içinde karar verir; verilmezse bağlantılı hesap vakaları cezayla, diğerleri beraatle kapanır. Ceza: işlem tutarının %20''si (en az 10.000 ₺) ve 7 gün işlem yasağı.'
  );
end $$;

create or replace function oyun.spk_tick(t timestamptz) returns void language plpgsql set search_path to '' as $$
declare r record;
begin
  for r in select id, tur from oyun.spk_inceleme where durum='acik' and bit<=t order by bit limit 100 loop
    perform oyun.spk_sonuclandir(r.id, r.tur='bagli_hesap', null, 'Süre doldu: kurul otomatik karar verdi.', t);
  end loop;
  delete from oyun.spk_yasak where bit < t - interval '30 days';
end $$;

-- ------------------------------------------------------------ Konkordato / iflas
create table if not exists oyun.sirket_konkordato(
  id bigserial primary key, sirket_id bigint not null references oyun.sirketler(id), bas timestamptz not null, bit timestamptz not null,
  durum text not null default 'surec' check (durum in ('surec','kurtuldu','iflas')),
  baslatan uuid, baslangic_kasa numeric, sonuc_zaman timestamptz
);
create unique index if not exists konkordato_tek on oyun.sirket_konkordato(sirket_id) where durum='surec';
revoke all on oyun.sirket_konkordato from anon, authenticated;
alter table oyun.sirket_konkordato enable row level security;

create or replace function oyun.konkordato_baslat(p_sirket bigint, p_baslatan uuid, t timestamptz) returns void language plpgsql set search_path to '' as $$
declare s oyun.sirketler; x record;
begin
  select * into s from oyun.sirketler where id=p_sirket for update;
  if s.id is null or not s.aktif or s.kasa>=0 or s.sektor='banka' then return; end if;
  if exists(select 1 from oyun.sirket_konkordato where sirket_id=s.id and durum='surec') then return; end if;
  insert into oyun.sirket_konkordato(sirket_id,bas,bit,baslatan,baslangic_kasa) values(s.id,t,t+interval '14 days',p_baslatan,s.kasa);
  for x in select user_id from oyun.sirket_ortaklari where sirket_id=s.id loop
    perform oyun.bildir(x.user_id, format('%s konkordato sürecine girdi: kasa açığı %s ₺. 14 gün içinde sermaye artırımıyla açık kapatılmazsa şirket iflas eder ve paylar değersizleşir.', s.ad, oyun.tl(-s.kasa)), t);
  end loop;
  perform oyun.olay('ekonomi', format('%s konkordato ilan etti (kasa açığı %s ₺).', s.ad, oyun.tl(-s.kasa)), null, null, t);
  perform oyun.gazete_ekle('icraat', format('%s konkordato ilan etti', s.ad),
    format('Borç yükü altındaki %s, alacaklılardan koruma için konkordato süreci başlattı. Ortakların 14 gün içinde sermaye koyması bekleniyor.', s.ad), s.id, t);
end $$;

create or replace function public.sirket_konkordato_ilan(p_sirket bigint) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; t timestamptz := oyun.simdi();
begin
  select * into s from oyun.sirketler where id=p_sirket;
  if s.id is null or not s.aktif then raise exception 'Şirket bulunamadı.'; end if;
  if not oyun.sirket_yonetici_mi(s.id,p.id) then raise exception 'Konkordatoyu şirketin yöneticisi (en büyük ortak) ilan eder.'; end if;
  if s.sektor='banka' then raise exception 'Bankalar konkordato ilan edemez.'; end if;
  if s.kasa>=0 then raise exception 'Kasası artıda olan şirket konkordato ilan edemez.'; end if;
  if exists(select 1 from oyun.sirket_konkordato where sirket_id=s.id and durum='surec') then raise exception 'Şirket zaten konkordato sürecinde.'; end if;
  perform oyun.konkordato_baslat(s.id,p.id,t);
  return public.konkordato_durum(s.id);
end $$;

create or replace function public.konkordato_durum(p_sirket bigint default null) returns jsonb language plpgsql security definer set search_path to '' as $$
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id',k.id,'sirket_id',k.sirket_id,'sirket',s.ad,'bas',k.bas,'bit',k.bit,'durum',k.durum,
      'kasa',s.kasa,'baslangic_kasa',k.baslangic_kasa,'sonuc_zaman',k.sonuc_zaman) order by k.bas desc)
    from oyun.sirket_konkordato k join oyun.sirketler s on s.id=k.sirket_id
    where (p_sirket is null and (k.durum='surec' or k.bas>oyun.simdi()-interval '30 days')) or k.sirket_id=p_sirket),'[]'::jsonb);
end $$;

-- Ekran: tüm süreçler + yönettiğim, kasası eksideki şirketler
create or replace function public.konkordato_ekrani() returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := oyun.ben();
begin
  return jsonb_build_object(
    'surecler', public.konkordato_durum(null),
    'riskli', coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',s.kasa,'sermaye',s.sermaye,
        'surecte', exists(select 1 from oyun.sirket_konkordato k where k.sirket_id=s.id and k.durum='surec'),
        'otomatik_esik', round(-0.5*greatest(s.sermaye,1))) order by s.kasa)
      from oyun.sirketler s where s.aktif and s.kasa<0 and s.sektor<>'banka' and oyun.sirket_yonetici_mi(s.id,me)),'[]'::jsonb),
    'kural','Kasası eksiye düşen şirketin yöneticisi konkordato ilan edebilir; açık sermayenin yarısını geçerse süreç kendiliğinden başlar. 14 gün içinde ortaklar sermaye artırımıyla kasayı artıya çekerse şirket kurtulur; çekemezse iflas eder, hisseler borsadan çıkar ve paylar değersizleşir. Bankalar kapsam dışıdır.'
  );
end $$;

create or replace function oyun.konkordato_tick(t timestamptz) returns void language plpgsql set search_path to '' as $$
declare r record; k oyun.sirket_konkordato; s oyun.sirketler; x record;
begin
  for r in select sx.id from oyun.sirketler sx where sx.aktif and sx.sektor<>'banka' and sx.kasa < -0.5*greatest(sx.sermaye,1)
            and not exists(select 1 from oyun.sirket_konkordato kx where kx.sirket_id=sx.id and kx.durum='surec') limit 50 loop
    perform oyun.konkordato_baslat(r.id,null,t);
  end loop;
  for k in select * from oyun.sirket_konkordato kk where kk.durum='surec' and kk.bit<=t order by kk.bit for update loop
    select * into s from oyun.sirketler sx where sx.id=k.sirket_id for update;
    if s.kasa>=0 or not s.aktif then
      update oyun.sirket_konkordato set durum='kurtuldu', sonuc_zaman=t where id=k.id;
      if s.aktif then
        perform oyun.olay('ekonomi', format('%s konkordatodan başarıyla çıktı.', s.ad), null, null, t);
        for x in select o.user_id from oyun.sirket_ortaklari o where o.sirket_id=s.id loop
          perform oyun.bildir(x.user_id, format('%s konkordatodan çıktı; şirket faaliyetine devam ediyor.', s.ad), t);
        end loop;
      end if;
      continue;
    end if;
    if exists(select 1 from oyun.halka_arz h where h.sirket_id=s.id and h.durum='acik') then continue; end if;
    update oyun.borsa_emir e set durum='iptal' where e.sirket_id=s.id and e.durum='acik';
    begin
      update oyun.sirket_hisse_ilanlari i set durum='iptal', kapanis=t where i.sirket_id=s.id and i.kapanis is null;
    exception when others then null; end;
    update oyun.sirketler sx set aktif=false, halka_acik=false, satilik=null where sx.id=s.id;
    update oyun.sirket_konkordato kx set durum='iflas', sonuc_zaman=t where kx.id=k.id;
    for x in select o.user_id from oyun.sirket_ortaklari o where o.sirket_id=s.id loop
      perform oyun.bildir(x.user_id, format('%s iflas etti. Konkordato süresinde açık (%s ₺) kapatılamadı; payların değersiz hâle geldi.', s.ad, oyun.tl(-s.kasa)), t);
    end loop;
    perform oyun.olay('ekonomi', format('%s iflas etti; şirket tasfiye edildi.', s.ad), null, null, t);
    perform oyun.gazete_ekle('icraat', format('%s iflas etti', s.ad),
      format('Konkordato süresinde borçlarını yapılandıramayan %s için iflas kararı verildi. Hisseler borsadan çıkarıldı.', s.ad), s.id, t);
    update oyun.pazar_ayar pa set endeks=round(pa.endeks*0.995,4) where pa.id=1;
  end loop;
end $$;

-- ------------------------------------------------------------ motor
create or replace function oyun.ekonomi2_tick() returns void language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi();
begin
  if not pg_try_advisory_xact_lock(424250) then return; end if;
  perform oyun.merkez_bankasi_tick(t);
  perform oyun.belediye_tahvil_tick(t);
  perform oyun.spk_tick(t);
  perform oyun.konkordato_tick(t);
end $$;

-- ------------------------------------------------------------ yetkiler
revoke all on function public.tcmb_baskan_ata(text), public.tcmb_teklif_yanit(bigint,boolean), public.tcmb_baskan_gorevden_al(),
  public.ppk_faiz_karari(numeric,text), public.merkez_bankasi(),
  public.belediye_tahvil_ihrac(numeric,numeric,int), public.belediye_tahvil_al(bigint,numeric), public.belediye_tahvilleri(),
  public.spk_inceleme_ac(bigint,text,text), public.spk_karar(bigint,boolean,text), public.spk_ekrani(),
  public.sirket_konkordato_ilan(bigint), public.konkordato_durum(bigint), public.konkordato_ekrani() from public, anon;
grant execute on function public.tcmb_baskan_ata(text), public.tcmb_teklif_yanit(bigint,boolean), public.tcmb_baskan_gorevden_al(),
  public.ppk_faiz_karari(numeric,text), public.merkez_bankasi(),
  public.belediye_tahvil_ihrac(numeric,numeric,int), public.belediye_tahvil_al(bigint,numeric), public.belediye_tahvilleri(),
  public.spk_inceleme_ac(bigint,text,text), public.spk_karar(bigint,boolean,text), public.spk_ekrani(),
  public.sirket_konkordato_ilan(bigint), public.konkordato_durum(bigint), public.konkordato_ekrani() to authenticated;
