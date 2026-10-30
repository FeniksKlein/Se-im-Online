-- 145 (30.10.2026)
-- 1) Oyuncu bankaları vadeli mevduatı geri ödeme gücüne göre kabul eder:
--    toplam mevduat özkaynağın 5 katını, tek kişinin bir bankadaki açık vadeli mevduatı özkaynağı aşamaz.
--    (Küçük bir bankaya bilerek dev mevduat yatırıp bankanın notunu/likiditesini çökertme açığı kapandı.)
-- 2) CB yardımcısı ataması kolaylaştı: aynı makama yeni teklif eskisini otomatik iptal eder,
--    bekleyen teklif geri çekilebilir, görevden alınan kişiye bildirim gider.
-- Oyuncu verisini değiştirmez.

create or replace function oyun.oyb_mevduat_kapasite(p_banka bigint, p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare b jsonb; oz numeric; vadesiz numeric; vadeli numeric; kisi numeric; kalan_t numeric; kalan_k numeric; azami numeric;
begin
  b := oyun.banka_bilanco(p_banka);
  oz := greatest(0, coalesce((b->>'ozkaynak')::numeric, 0));
  vadesiz := coalesce((b->>'vadesiz')::numeric, 0);
  vadeli := coalesce((b->>'vadeli_anapara')::numeric, 0);
  select coalesce(sum(anapara), 0) into kisi from oyun.banka_mevduat
   where banka_id = p_banka and user_id = p_user and not kapandi;
  kalan_t := greatest(0, oz * 5 - vadesiz - vadeli);
  kalan_k := greatest(0, oz - kisi);
  azami := floor(least(kalan_t, kalan_k, 10000000) / 1000) * 1000;
  return jsonb_build_object('ozkaynak', round(oz), 'toplam_sinir', round(oz * 5), 'kisi_sinir', round(oz),
    'mevcut_mevduat', round(vadesiz + vadeli), 'senin_mevduatin', round(kisi), 'azami_tutar', azami);
end $$;

create or replace function oyun.oyb_kapasite_kontrol(p_banka bigint, p_user uuid, p_tutar numeric)
returns void language plpgsql stable security definer set search_path = '' as $$
declare k jsonb := oyun.oyb_mevduat_kapasite(p_banka, p_user);
begin
  if p_tutar > (k->>'azami_tutar')::numeric then
    if (k->>'azami_tutar')::numeric < 1000 then
      raise exception 'Bu banka şu an yeni vadeli mevduat kabul edemiyor: geri ödeme gücü (özkaynak % ₺) mevcut mevduatları karşılamaya ayrılmış.',
        oyun.tl((k->>'ozkaynak')::numeric);
    end if;
    raise exception 'Bu banka geri ödeme gücüne göre sana en fazla % ₺ yatırma izni verebilir (özkaynak % ₺; bir kişinin mevduatı özkaynağı, toplam mevduat özkaynağın 5 katını aşamaz).',
      oyun.tl((k->>'azami_tutar')::numeric), oyun.tl((k->>'ozkaynak')::numeric);
  end if;
end $$;

create or replace function public.oyb_teklif(p_banka bigint, p_tutar numeric, p_saat integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid();s oyun.sirketler; f numeric; yeni numeric; y numeric; a numeric; al numeric; tampon numeric; uygun boolean; kap jsonb; sinirda boolean;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1000 or p_tutar>10000000 then
  raise exception 'Tutar 1.000 - 10.000.000 TL arasinda tam sayi olmali';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif;
 if not found then raise exception 'Banka bulunamadi';end if;
 f:=oyun.oyb_oran(p_banka,p_saat);
 yeni:=round(p_tutar*(1+f/100));
 select coalesce(sum(round(anapara*(1+faiz/100))),0),coalesce(sum(anapara),0)
 into y,a from oyun.banka_mevduat where banka_id=p_banka and not kapandi;
 select coalesce(sum(least(kalan,anapara) * case when vade<oyun.simdi() then .25 else .70 end),0)
 into al from oyun.oyb_kredi where banka_id=p_banka and durum='aktif';
 tampon:=greatest(s.sermaye*.10,(a+p_tutar)*.10);
 kap:=oyun.oyb_mevduat_kapasite(p_banka,u);
 sinirda:=p_tutar<=(kap->>'azami_tutar')::numeric;
 uygun:=not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
   and not exists(select 1 from oyun.banka_mevduat where banka_id=p_banka and not kapandi and vade<=oyun.simdi())
   and s.kasa+p_tutar+al>=y+yeni+tampon and sinirda;
 return jsonb_build_object('banka',s.ad,'saat',p_saat,'oran',f,
  'tutar',p_tutar,'faiz_kazanci',yeni-p_tutar,'vade_sonu_odeme',yeni,
  'odeme_gucu_yeterli',uygun,'vade',oyun.simdi()+make_interval(hours=>p_saat),
  'azami_tutar',(kap->>'azami_tutar')::numeric,'kapasite',kap,
  'uyari',case when uygun then 'Banka bu mevduatı geri ödeme gücü içinde kabul edebilir; kredi riski devam eder. Bu bankaya en fazla '||oyun.tl((kap->>'azami_tutar')::numeric)||' ₺ yatırabilirsin.'
    when not sinirda then 'Banka geri ödeme gücüne göre en fazla '||oyun.tl((kap->>'azami_tutar')::numeric)||' ₺ kabul edebilir (özkaynak '||oyun.tl((kap->>'ozkaynak')::numeric)||' ₺).'
    else 'Banka yeni mevduat kabul edecek mali yeterlilikte degil veya kendi bankana yatirmaya calisiyorsun.' end);
end $$;

create or replace function public.oyb_yatir(p_banka bigint, p_tutar numeric, p_saat integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid:=auth.uid();s oyun.sirketler;t timestamptz:=oyun.simdi();f numeric; yeni numeric;y numeric;a numeric;al numeric;tampon numeric;x bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<1000 or p_tutar>10000000 then
  raise exception 'Tutar 1.000 - 10.000.000 TL arasinda tam sayi olmali';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if not found then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_banka and user_id=u and pay>0)
 then raise exception 'Kendi bankana faizli mevduat yatiramazsin';end if;
 if exists(select 1 from oyun.banka_mevduat where banka_id=p_banka and not kapandi and vade<=t)
 then raise exception 'Bankanin gecikmis odemesi var; yeni mevduat kabul edilemiyor';end if;
 perform oyun.oyb_kapasite_kontrol(p_banka,u,p_tutar);
 f:=oyun.oyb_oran(p_banka,p_saat); yeni:=round(p_tutar*(1+f/100));
 select coalesce(sum(round(anapara*(1+faiz/100))),0),coalesce(sum(anapara),0)
 into y,a from oyun.banka_mevduat where banka_id=p_banka and not kapandi;
 select coalesce(sum(least(kalan,anapara) * case when vade<t then .25 else .70 end),0)
 into al from oyun.oyb_kredi where banka_id=p_banka and durum='aktif';
 tampon:=greatest(s.sermaye*.10,(a+p_tutar)*.10);
 if s.kasa+p_tutar+al<y+yeni+tampon
 then raise exception 'Bankanin yeni mevduat ve faiz yukumlulugunu karsilayacak mali gucu yok';end if;
 perform oyun.para_islem(u,-p_tutar,'mevduat','Oyuncu bankasina '||p_saat||' saat vadeli yatirim',t);
 update oyun.sirketler set kasa=kasa+p_tutar where id=p_banka;
 insert into oyun.banka_mevduat(banka_id,user_id,anapara,faiz,acilis,vade,vade_saat)
 values(p_banka,u,p_tutar,f,t,t+make_interval(hours=>p_saat),p_saat) returning id into x;
 return jsonb_build_object('id',x,'vade',t+make_interval(hours=>p_saat),'odeme',yeni);
end $$;

-- Eski 7 günlük yol da aynı sınıra tabi
create or replace function public.banka_mevduat_yatir(p_banka bigint, p_tutar numeric)
returns jsonb language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare u uuid:=auth.uid();s oyun.sirketler;t timestamptz:=oyun.simdi();
        v_borc numeric; v_anapara numeric; v_yeni_borc numeric; v_guvence numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<1000 or p_tutar>10000000
 then raise exception 'Mevduat 1.000 - 10.000.000 TL arasinda tam sayi olmali';end if;
 select * into s from oyun.sirketler where id=p_banka and sektor='banka' and aktif for update;
 if s.id is null then raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.sirket_ortaklari o
           where o.sirket_id=p_banka and o.user_id=u and o.pay>0)
 then raise exception 'Kendi bankana faizli mevduat yatiramazsin; baska bir oyuncu bankasi sec';end if;
 if s.banka_faiz<0 or s.banka_faiz>1.8 then raise exception 'Banka faiz sinirini asiyor';end if;
 perform oyun.oyb_kapasite_kontrol(p_banka,u,p_tutar);
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),
        coalesce(sum(m.anapara),0)
 into v_borc,v_anapara from oyun.banka_mevduat m where m.banka_id=p_banka and not m.kapandi;
 v_yeni_borc:=round(p_tutar*(1+s.banka_faiz/100));
 v_guvence:=greatest(s.sermaye*0.10,(v_anapara+p_tutar)*0.10);
 if s.kasa < v_borc+(v_yeni_borc-p_tutar)+v_guvence
 then raise exception 'Banka likiditesi/teminati yetersiz. Mevduat kabul edilemiyor';end if;
 perform oyun.para_islem(u,-p_tutar,'mevduat','Oyuncu bankasina 7 gun vadeli mevduat',t);
 update oyun.sirketler set kasa=kasa+p_tutar where id=p_banka;
 insert into oyun.banka_mevduat(banka_id,user_id,anapara,faiz,vade)
 values(p_banka,u,p_tutar,s.banka_faiz,t+interval '7 days');
 return jsonb_build_object('tamam',true,'banka',p_banka,'faiz',s.banka_faiz,'vade',t+interval '7 days');
end $$;

-- Bankaya özel kapasite sorgusu (arayüz için)
create or replace function public.oyb_mevduat_kapasite(p_banka bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if not exists(select 1 from oyun.sirketler where id=p_banka and sektor='banka') then raise exception 'Banka bulunamadi'; end if;
  return oyun.oyb_mevduat_kapasite(p_banka, auth.uid());
end $$;
revoke all on function public.oyb_mevduat_kapasite(bigint) from public, anon;
grant execute on function public.oyb_mevduat_kapasite(bigint) to authenticated;
revoke all on function oyun.oyb_mevduat_kapasite(bigint, uuid) from public, anon, authenticated;
revoke all on function oyun.oyb_kapasite_kontrol(bigint, uuid, numeric) from public, anon, authenticated;

-- ===================== CB YARDIMCILARI =====================
create or replace function public.cb_yardimcisi_ata(p_sira integer, p_kad text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; t timestamptz:=oyun.simdi(); tid bigint; eski record;
begin
 perform oyun.cb_yardimcisi_yetkili(p);
 if p_sira not in (1,2) or p_sira is null then raise exception 'Yalnız 1. veya 2. yardımcılık seçilebilir.'; end if;
 h:=oyun.profil_bul(p_kad);
 if h.yasakli then raise exception 'Yasaklı oyuncuya teklif gönderilemez.'; end if;
 if h.id=p.id then raise exception 'Cumhurbaşkanı kendisini yardımcı atayamaz.'; end if;
 if exists(select 1 from oyun.makamlar where tur='cb_yardimcisi' and user_id=h.id and bakanlik=p_sira::text and bit is null)
 then raise exception 'Bu oyuncu zaten bu makamda.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('cb_yardimcisi'),p_sira);
 -- Aynı makam için bekleyen eski teklifler ve adayın başka bekleyen teklifleri yenisiyle değişir.
 for eski in select id, aday from oyun.cb_yardimcisi_teklifleri
   where durum='bekliyor' and (sira=p_sira or aday=h.id) for update loop
   update oyun.cb_yardimcisi_teklifleri set durum='iptal', yanit_at=t where id=eski.id;
   if eski.aday<>h.id then
     perform oyun.bildir(eski.aday, format('Cumhurbaşkanı %s, %s. Cumhurbaşkanı Yardımcılığı teklifini geri çekti.', p.kad, p_sira), t);
   end if;
 end loop;
 insert into oyun.cb_yardimcisi_teklifleri(sira,teklif_eden,aday,zaman)
 values(p_sira,p.id,h.id,t) returning id into tid;
 perform oyun.bildir(h.id,format('Cumhurbaşkanı %s sana %s. Cumhurbaşkanı Yardımcılığı teklif etti. Devlet › Hükümet ekranından veya Bildirimler''den kabul ya da ret verebilirsin. Mevcut görevlerin korunur.',p.kad,p_sira),t);
 return jsonb_build_object('durum','bekliyor','teklif_id',tid,'sira',p_sira,'aday',h.kad);
end $$;

create or replace function public.cb_yardimcisi_teklif_geri(p_sira integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz:=oyun.simdi(); x record; n int := 0;
begin
 perform oyun.cb_yardimcisi_yetkili(p);
 if p_sira not in (1,2) or p_sira is null then raise exception 'Geçersiz yardımcılık.'; end if;
 for x in select id, aday from oyun.cb_yardimcisi_teklifleri where durum='bekliyor' and sira=p_sira for update loop
   update oyun.cb_yardimcisi_teklifleri set durum='iptal', yanit_at=t where id=x.id;
   perform oyun.bildir(x.aday, format('Cumhurbaşkanı %s, %s. Cumhurbaşkanı Yardımcılığı teklifini geri çekti.', p.kad, p_sira), t);
   n := n + 1;
 end loop;
 if n = 0 then raise exception 'Bu makam için bekleyen teklif yok.'; end if;
 return jsonb_build_object('durum','geri_cekildi','sira',p_sira);
end $$;
revoke all on function public.cb_yardimcisi_teklif_geri(integer) from public, anon;
grant execute on function public.cb_yardimcisi_teklif_geri(integer) to authenticated;

create or replace function public.cb_yardimcisi_gorevden_al(p_sira integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar; t timestamptz:=oyun.simdi(); ad text;
begin
 perform oyun.cb_yardimcisi_yetkili(p);
 if p_sira not in (1,2) or p_sira is null then raise exception 'Geçersiz yardımcılık.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('cb_yardimcisi'),p_sira);
 select * into m from oyun.makamlar where tur='cb_yardimcisi' and bakanlik=p_sira::text and bit is null for update;
 if m.id is null then raise exception 'Bu yardımcılık makamı zaten boş.'; end if;
 ad := oyun.kad(m.user_id);
 perform oyun.makam_bitir(m.id,t,'gorevden_alindi');
 perform oyun.bildir(m.user_id, format('Cumhurbaşkanı %s seni %s. Cumhurbaşkanı Yardımcılığı görevinden aldı. Diğer görevlerin sürüyor.', p.kad, p_sira), t);
 perform oyun.olay('makam',format('%s, %s. Cumhurbaşkanı Yardımcılığı görevinden alındı.',ad,p_sira),null,p.parti_id,t);
 return jsonb_build_object('durum','gorevden_alindi','sira',p_sira,'kad',ad);
end $$;

-- Teklif listesinde teklif saati de gelsin (CB ekranı için)
create or replace function public.cb_yardimcilari()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller:=oyun.profilim(); cb_aktif boolean;
begin
 cb_aktif := exists(select 1 from oyun.makamlar where tur='cb' and user_id=p.id and bit is null);
 return jsonb_build_object(
  'cb_miyim', cb_aktif,
  'yardimcilar', (select jsonb_agg(jsonb_build_object('sira',s.sira,'kad',oyun.kad(m.user_id),'parti',oyun.parti_json(pr.parti_id),'bas',m.bas,'benim',m.user_id=p.id) order by s.sira)
  from (values(1),(2)) s(sira)
  left join oyun.makamlar m on m.tur='cb_yardimcisi' and m.bakanlik=s.sira::text and m.bit is null
  left join oyun.profiller pr on pr.id=m.user_id),
  'bekleyen', case when cb_aktif then coalesce((select jsonb_agg(jsonb_build_object('sira',x.sira,'aday',oyun.kad(x.aday),'zaman',x.zaman) order by x.sira)
  from oyun.cb_yardimcisi_teklifleri x where x.durum='bekliyor' and x.teklif_eden=p.id),'[]'::jsonb) else '[]'::jsonb end
 );
end $$;

-- ===================== HAVALE SINIRI =====================
-- Yönetici panelindeki üst sınır 10 → 50 asgari ücret (canlı değer migration ile 15'e çıkarıldı: 15 × 30.000 = 450.000 ₺/gün)
create or replace function public.admin_kurallar(p jsonb default null::jsonb)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $function$
declare y oyun.profiller := oyun.yetki_zorunlu('kurallar'); a oyun.ayarlar;
begin
  if p is not null then
    update oyun.ayarlar set
      min_hesap_gun      = oyun.sinir(coalesce((p ->> 'min_hesap_gun')::int, min_hesap_gun), 0, 30),
      oy_min_kidem       = oyun.sinir(coalesce((p ->> 'oy_min_kidem')::int, oy_min_kidem), 0, 100),
      oy_il_gun          = oyun.sinir(coalesce((p ->> 'oy_il_gun')::int, oy_il_gun), 0, 30),
      cihaz_max_hesap    = oyun.sinir(coalesce((p ->> 'cihaz_max_hesap')::int, cihaz_max_hesap), 1, 5),
      parti_kurucu_sayi  = oyun.sinir(coalesce((p ->> 'parti_kurucu_sayi')::int, parti_kurucu_sayi), 1, 30),
      parti_kurucu_kidem = oyun.sinir(coalesce((p ->> 'parti_kurucu_kidem')::int, parti_kurucu_kidem), 0, 300),
      parti_kurulus_gun  = oyun.sinir(coalesce((p ->> 'parti_kurulus_gun')::int, parti_kurulus_gun), 1, 30),
      parti_kur_ucret    = oyun.sinir(coalesce((p ->> 'parti_kur_ucret')::numeric, parti_kur_ucret), 0, 1000000),
      teskilat_ucret     = oyun.sinir(coalesce((p ->> 'teskilat_ucret')::numeric, teskilat_ucret), 0, 100000),
      teskilat_zorunlu   = coalesce((p ->> 'teskilat_zorunlu')::boolean, teskilat_zorunlu),
      havale_sinir       = oyun.sinir(coalesce((p ->> 'havale_sinir')::numeric, havale_sinir), 0, 50),
      banka_acik         = coalesce((p ->> 'banka_acik')::boolean, banka_acik),
      banka_reel_faiz    = oyun.sinir(coalesce((p ->> 'banka_reel_faiz')::numeric, banka_reel_faiz), -10, 30),
      banka_tavan        = oyun.sinir(coalesce((p ->> 'banka_tavan')::numeric, banka_tavan), 0, 100000000),
      meclis_olcek       = oyun.sinir(coalesce((p ->> 'meclis_olcek')::numeric, meclis_olcek), 0, 5),
      ihmal_gun_atama    = oyun.sinir(coalesce((p ->> 'ihmal_gun_atama')::int, ihmal_gun_atama), 0, 30),
      ihmal_gun_secim    = oyun.sinir(coalesce((p ->> 'ihmal_gun_secim')::int, ihmal_gun_secim), 0, 30)
    where id = 1;
    perform oyun.mod_log(y, 'kurallar', null, p::text);
  end if;
  select * into a from oyun.ayarlar where id = 1;
  return jsonb_build_object('min_hesap_gun', a.min_hesap_gun, 'oy_min_kidem', a.oy_min_kidem, 'oy_il_gun', a.oy_il_gun,
    'cihaz_max_hesap', a.cihaz_max_hesap, 'parti_kurucu_sayi', a.parti_kurucu_sayi, 'parti_kurucu_kidem', a.parti_kurucu_kidem,
    'parti_kurulus_gun', a.parti_kurulus_gun,
    'parti_kur_ucret', a.parti_kur_ucret, 'teskilat_ucret', a.teskilat_ucret, 'teskilat_zorunlu', a.teskilat_zorunlu,
    'havale_sinir', a.havale_sinir, 'banka_acik', a.banka_acik, 'banka_reel_faiz', a.banka_reel_faiz, 'banka_tavan', a.banka_tavan,
    'meclis_olcek', a.meclis_olcek, 'ihmal_gun_atama', a.ihmal_gun_atama, 'ihmal_gun_secim', a.ihmal_gun_secim);
end $function$;
