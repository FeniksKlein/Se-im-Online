-- 26.11.2026 · KİTAP DOSYASI TAKİBİ (sürüm 2026.11.26-6)
-- Şikâyet (oyuncu, Ercan "bunu da düzelt"): "Kitap yazıp yayınevine gönderiyoruz ama muallakta bekliyor; takip seçeneğimiz yok,
-- yazdığımız kitabı sonrasında göremiyoruz. En azından aşamaları görsek, ya da kitabı görsek ve diğer şirketlere de gönderebilsek."
-- KÖK NEDEN: (1) yayınevi sahibine yeni dosya geldiğinde hiçbir bildirim gitmiyordu — sahipler bekleyen dosyadan habersizdi;
-- (2) yayınevi hiç karar vermezse dosya sonsuza kadar "inceleniyor"da kalıyordu; (3) yazara hiçbir aşama/karar bildirimi gitmiyordu;
-- (4) Kitaplar ekranı yalnız yayımlanmış kitapları gösteriyordu, yazar kendi dosyasını orada göremiyordu (istemci, kitap_vitrini.js).
-- ÇÖZÜM (sunucu — eski telefon uygulamaları dahil herkese hemen):
--   • Aşamalar: gönderildi (gonderim) → yayınevi gördü (incelendi) → karar (karar: yayımlandı / reddedildi / süre doldu / geri çekildi).
--   • Bildirimler: yayınevi yöneticisine yeni dosya; yazara "yayınevi dosyanı gördü", ret (gerekçesiyle), yayım, süre dolumu.
--   • 72 saat kuralı: yayınevi 72 saatte karar vermezse dosya kendiliğinden yazara iade edilir (reddedildi, ret_kod 'sure');
--     yazar hemen başka yayınevine gönderebilir. pg_cron 'kitap-dosya-sure' saatte bir.
--   • 'kopya_gonder' {yayinevi}: aynı kitap aynı anda en çok 3 yayınevinde incelenebilir (eser = ortak numara). Biri yayımlayınca
--     diğer dosyalar kendiliğinden geri çekilir ve o yayınevlerine bildirim gider; aynı kitap iki kez yayımlanamaz.
--   • 'geri_cek': yazar bekleyen dosyasını istediği an geri çeker (sonra başka yayınevine gönderebilir).
--   • 'reddet' artık isteğe bağlı gerekçe alır (p_veri.gerekce, en çok 300 karakter; bölücü süzgecinden geçer).
--   • uc_kitap_panel: kitapta incelendi, karar, ret_kod, ret_gerekce, son_karar (gonderim + 72 saat), inceleme_saat, eser, kopya_bekleyen.
--     Yayınevi yöneticisi paneli açtığında bekleyen dosyalar "görüldü" işaretlenir ve yazara bir kez bildirim gider.
-- Oyuncu verisi değişmez: yalnız boş sütunlar eklenir. Tekrar çalıştırmak güvenlidir.

alter table oyun.uc_kitap add column if not exists gonderim timestamptz;
alter table oyun.uc_kitap add column if not exists incelendi timestamptz;
alter table oyun.uc_kitap add column if not exists karar timestamptz;
alter table oyun.uc_kitap add column if not exists ret_kod text;
alter table oyun.uc_kitap add column if not exists ret_gerekce text;
alter table oyun.uc_kitap add column if not exists eser bigint;

create index if not exists uc_kitap_teklif_gonderim on oyun.uc_kitap (coalesce(gonderim, olusturma)) where durum = 'teklif';
create index if not exists uc_kitap_eser on oyun.uc_kitap (eser) where eser is not null;
create index if not exists uc_kitap_yazar_durum on oyun.uc_kitap (yazar, durum);

-- Bölücü içerik süzgeci ret gerekçesini de kapsasın.
drop trigger if exists bolucu_metin on oyun.uc_kitap;
create trigger bolucu_metin before insert or update on oyun.uc_kitap
  for each row execute function oyun.bolucu_metin_trg('baslik', 'ozet', 'icerik', 'ret_gerekce');

create or replace function oyun.kitap_inceleme_saat() returns int
language sql immutable set search_path to '' as $$ select 72 $$;

-- Yayınevinin yöneticilerine (payı %50 ve üstü) bildirim
create or replace function oyun.kitap_yayinevi_bildir(p_yayinevi bigint, p_metin text)
returns void language sql security definer set search_path to '' as $$
  select oyun.bildir(so.user_id, p_metin, oyun.simdi())
  from oyun.sirket_ortaklari so where so.sirket_id = p_yayinevi and so.pay >= 50;
$$;

create or replace function public.uc_kitap_islem(p_islem text, p_id bigint, p_veri jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  u uuid := auth.uid();
  t timestamptz := oyun.simdi();
  s oyun.sirketler;
  k oyun.uc_kitap;
  title text; qty int; price numeric; expense numeric; bid bigint; grp bigint; gerekce text; r record; n int;
  saat int := oyun.kitap_inceleme_saat();
begin
  perform oyun.profilim();
  if p_veri is null or jsonb_typeof(p_veri) <> 'object' then
    raise exception 'Veri hatalı';
  end if;

  if p_islem = 'teklif' then
    select * into s from oyun.sirketler
      where id = p_id and sektor = 'medya' and aktif;
    if s.id is null then raise exception 'Yayınevi bulunamadı'; end if;
    title := trim(coalesce(p_veri->>'baslik',''));
    if length(title) not between 4 and 100
       or length(coalesce(p_veri->>'icerik','')) not between 100 and 50000
       or length(coalesce(p_veri->>'ozet','')) > 2000
    then raise exception 'Başlık 4-100, kitap metni 100-50.000, özet en çok 2000 karakter olmalı'; end if;
    if (select count(*) from oyun.uc_kitap where yazar=u and durum='teklif') >= 5
    then raise exception 'En fazla 5 bekleyen kitap dosyan olabilir. Bekleyen bir dosyayı geri çekebilir ya da kararı bekleyebilirsin'; end if;
    -- Eski mobil surumlerle uyum: eksik fiyat icin 300 TL varsayilir.
    price := coalesce(nullif(p_veri->>'fiyat','')::numeric,300);
    if price not between 100 and 2000 or price <> trunc(price)
    then raise exception 'Kitap fiyatı 100-2000 ₺ arasında tam sayı olmalı'; end if;
    insert into oyun.uc_kitap
      (yayinevi,yazar,baslik,tur,ozet,icerik,fiyat,olusturma,gonderim)
    values(s.id,u,title,left(coalesce(p_veri->>'tur','Siyasi hatırat'),40),
      left(coalesce(p_veri->>'ozet',''),600),p_veri->>'icerik',price,t,t)
    returning id into bid;
    perform oyun.kitap_yayinevi_bildir(s.id, '📚 '||s.ad||' yayınevine yeni kitap dosyası geldi: «'||title||'» — yazar '||coalesce(oyun.kad(u),'?')||
      '. İş Dünyası › Kitap ve yayınevi ekranından metni inceleyip yayımlayabilir ya da gerekçe yazarak reddedebilirsin. '||saat||' saat içinde karar verilmezse dosya yazara iade edilir.');
    return jsonb_build_object('id',bid,'durum','teklif','fiyat',price,'son_karar',t + make_interval(hours => saat));
  end if;

  select * into k from oyun.uc_kitap where id=p_id for update;
  if k.id is null then raise exception 'Kitap bulunamadı'; end if;

  if p_islem = 'satinal' then
    if k.durum <> 'yayinda' or k.stok < 1 or k.yazar = u
    then raise exception 'Kitap satışı uygun değil'; end if;
    if exists(select 1 from oyun.uc_kitap_satis where kitap_id=k.id and alici=u)
    then raise exception 'Kitabı zaten aldın'; end if;
    update oyun.cuzdan set para=para-k.fiyat
      where user_id=u and para>=k.fiyat;
    if not found then raise exception 'Bakiye yetersiz'; end if;
    return oyun.uc_kitap_kazanc(k.id,1,u,null);
  end if;

  if p_islem = 'fiyat' then
    if k.yazar <> u then raise exception 'Kitap fiyatını yalnızca yazarı belirleyebilir'; end if;
    if k.durum not in ('teklif','yayinda')
    then raise exception 'Bu kitabın fiyatı değiştirilemez'; end if;
    price := nullif(p_veri->>'fiyat','')::numeric;
    if price is null or price not between 100 and 2000 or price <> trunc(price)
    then raise exception 'Fiyat 100-2000 ₺ arasında tam sayı olmalı'; end if;
    if k.durum = 'yayinda' and k.fiyat_son_degisim is not null
        and k.fiyat_son_degisim > t - interval '24 hours'
    then raise exception 'Yayımlanmış kitabın fiyatı 24 saatte bir değiştirilebilir'; end if;
    if k.durum='yayinda' and price=k.fiyat then
      return jsonb_build_object('fiyat',k.fiyat,'degismedi',true);
    end if;
    update oyun.uc_kitap set fiyat=price,fiyat_son_degisim=t where id=k.id;
    return jsonb_build_object('fiyat',price,'durum',k.durum);
  end if;

  -- Yazar: bekleyen dosyayı geri çek (istediği an)
  if p_islem = 'geri_cek' then
    if k.yazar <> u then raise exception 'Dosyayı yalnızca kitabın yazarı geri çekebilir'; end if;
    if k.durum <> 'teklif' then raise exception 'Yalnız incelemede bekleyen dosya geri çekilebilir'; end if;
    update oyun.uc_kitap set durum='reddedildi', karar=t, ret_kod='geri_cekti', ret_gerekce=null where id=k.id;
    select ad into title from oyun.sirketler where id=k.yayinevi;
    perform oyun.kitap_yayinevi_bildir(k.yayinevi, '📚 «'||k.baslik||'» dosyası yazarı tarafından '||coalesce(title||' yayınevinden','yayınevinden')||' geri çekildi.');
    return jsonb_build_object('durum','reddedildi','ret_kod','geri_cekti');
  end if;

  -- Yazar: aynı kitabı başka bir yayınevine de gönder (aynı anda en çok 3 yayınevi)
  if p_islem in ('kopya_gonder','yayinevi_degistir') then
    if k.yazar <> u then raise exception 'Bu işlemi yalnızca kitabın yazarı yapabilir'; end if;
    grp := coalesce(k.eser, k.id);
    perform 1 from oyun.uc_kitap where coalesce(eser,id) = grp for update;
    if exists(select 1 from oyun.uc_kitap where coalesce(eser,id) = grp and durum='yayinda')
    then raise exception 'Bu kitap zaten yayımlandı; başka yayınevine gönderilemez'; end if;
    if p_islem = 'yayinevi_degistir' then
      if k.durum not in ('teklif','reddedildi') then raise exception 'Yayımlanmış kitabın yayınevi değiştirilemez'; end if;
      if k.durum = 'teklif' and coalesce(k.gonderim, k.olusturma) > t - interval '24 hours' then
        raise exception 'Yayınevinin dosyanı incelemesi için 24 saati var. Kitabını % saatinden sonra taşıyabilir ya da "Başka yayınevine de gönder" ile aynı anda başka bir yayınevine de sunabilirsin',
          to_char((coalesce(k.gonderim, k.olusturma) + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
      end if;
    end if;
    bid := case when coalesce(p_veri->>'yayinevi','') ~ '^[0-9]{1,15}$' then (p_veri->>'yayinevi')::bigint end;
    if bid is null then raise exception 'Yayınevi seç'; end if;
    if exists(select 1 from oyun.uc_kitap where coalesce(eser,id) = grp and yayinevi = bid and durum='teklif' and id <> k.id)
       or (bid = k.yayinevi and k.durum = 'teklif')
    then raise exception 'Bu kitap o yayınevinde zaten inceleniyor'; end if;
    if p_islem = 'yayinevi_degistir' and bid = k.yayinevi then raise exception 'Farklı bir yayınevi seç'; end if;
    select * into s from oyun.sirketler where id = bid and sektor = 'medya' and aktif;
    if s.id is null then raise exception 'Yayınevi bulunamadı'; end if;
    if to_regprocedure('oyun.kurum_durdurma_aktif(text,bigint)') is not null then
      execute 'select (oyun.kurum_durdurma_aktif($1, $2)).id' into expense using 'sirket', s.id;
      if expense is not null then raise exception 'Bu yayınevinin yayın ve faaliyetleri oyun yönetimi kararıyla durduruldu; başka bir yayınevi seç'; end if;
    end if;
    n := (select count(*) from oyun.uc_kitap where yazar=u and durum='teklif');
    if (p_islem = 'kopya_gonder' or k.durum = 'reddedildi') and n >= 5
    then raise exception 'En fazla 5 bekleyen kitap dosyan olabilir. Bekleyen bir dosyayı geri çekebilir ya da kararı bekleyebilirsin'; end if;
    if p_islem = 'kopya_gonder' then
      if (select count(*) from oyun.uc_kitap where coalesce(eser,id) = grp and durum='teklif') >= 3
      then raise exception 'Bir kitap aynı anda en çok 3 yayınevinde incelenebilir'; end if;
      if k.eser is null then update oyun.uc_kitap set eser = k.id where id = k.id; end if;
      insert into oyun.uc_kitap (yayinevi,yazar,baslik,tur,ozet,icerik,fiyat,olusturma,gonderim,eser)
      values (s.id,u,k.baslik,k.tur,k.ozet,k.icerik,k.fiyat,t,t,grp)
      returning id into bid;
    else
      update oyun.uc_kitap set yayinevi = s.id, durum = 'teklif', gonderim = t,
        incelendi = null, karar = null, ret_kod = null, ret_gerekce = null where id = k.id;
      bid := k.id;
    end if;
    perform oyun.kitap_yayinevi_bildir(s.id, '📚 '||s.ad||' yayınevine yeni kitap dosyası geldi: «'||k.baslik||'» — yazar '||coalesce(oyun.kad(u),'?')||
      '. İş Dünyası › Kitap ve yayınevi ekranından inceleyebilirsin. '||saat||' saat içinde karar verilmezse dosya yazara iade edilir.');
    return jsonb_build_object('id',bid,'durum','teklif','yayinevi',s.id,'yayinevi_ad',s.ad,'son_karar',t + make_interval(hours => saat));
  end if;

  select * into s from oyun.sirketler
    where id=k.yayinevi and aktif for update;
  if s.id is null or not exists (
    select 1 from oyun.sirket_ortaklari
    where sirket_id=s.id and user_id=u and pay>=50
  ) then raise exception 'Yayınevini yönetme yetkin yok'; end if;

  if p_islem = 'reddet' then
    gerekce := nullif(left(trim(regexp_replace(coalesce(p_veri->>'gerekce',''), '\s+', ' ', 'g')), 300), '');
    update oyun.uc_kitap set durum='reddedildi', karar=t, ret_kod='ret', ret_gerekce=gerekce,
      incelendi=coalesce(incelendi,t)
      where id=k.id and durum='teklif';
    if not found then raise exception 'Bekleyen teklif bulunamadı'; end if;
    perform oyun.bildir(k.yazar, '📚 '||s.ad||' «'||k.baslik||'» dosyanı reddetti'||coalesce('. Gerekçe: '||gerekce,'')||
      '. Kitabın sende duruyor; Kitaplar › Dosyalarım ya da İş Dünyası › Kitap ve yayınevi ekranından hemen başka bir yayınevine gönderebilirsin.', t);
    return jsonb_build_object('durum','reddedildi','ret_gerekce',gerekce);
  elsif p_islem in ('yayinla','yenibaski') then
    if (p_islem='yayinla' and k.durum<>'teklif')
       or (p_islem='yenibaski' and k.durum<>'yayinda')
    then raise exception 'Kitap durumu uygun değil'; end if;
    if p_islem = 'yayinla' then
      grp := coalesce(k.eser, k.id);
      perform 1 from oyun.uc_kitap where coalesce(eser,id) = grp and id <> k.id for update;
      if exists(select 1 from oyun.uc_kitap where coalesce(eser,id) = grp and durum='yayinda' and id <> k.id)
      then raise exception 'Bu kitap başka bir yayınevinde yayımlandı'; end if;
    end if;
    qty := coalesce(nullif(p_veri->>'adet','')::int,0);
    -- Yayinevi istemciden gelen fiyati degistiremez.
    price := k.fiyat;
    if qty not between 10 and 200 or price not between 100 and 2000
    then raise exception 'Baskı 10-200 adet olmalı; yazar önce 100-2000 ₺ arası fiyat belirlemeli'; end if;
    expense := round(qty*price*.4);
    update oyun.sirketler set kasa=kasa-expense
      where id=s.id and kasa>=expense;
    if not found then raise exception 'Baskı gideri için kasa yetersiz'; end if;
    update oyun.uc_kitap set stok=stok+qty,durum='yayinda',
      yayin=coalesce(yayin,t),son_satis=coalesce(son_satis,t),
      karar=coalesce(karar,t),incelendi=coalesce(incelendi,t)
      where id=k.id;
    if p_islem = 'yayinla' then
      perform oyun.bildir(k.yazar, '🎉 «'||k.baslik||'» '||s.ad||' tarafından '||qty||' adet basılıp yayımlandı! Artık Kitaplar vitrininde; her satıştan %'||round(case when coalesce(k.telif_orani,15) > 1 then coalesce(k.telif_orani,15) else k.telif_orani*100 end)::int||' telif alırsın.', t);
      -- Aynı kitabın başka yayınevlerindeki bekleyen dosyaları kendiliğinden geri çekilir
      for r in select b.id, b.yayinevi from oyun.uc_kitap b where coalesce(b.eser,b.id) = grp and b.id <> k.id and b.durum='teklif' loop
        update oyun.uc_kitap set durum='reddedildi', karar=t, ret_kod='baska_yayinevi', ret_gerekce=null where id=r.id;
        perform oyun.kitap_yayinevi_bildir(r.yayinevi, '📚 «'||k.baslik||'» başka bir yayınevinde yayımlandığı için dosya yazar adına geri çekildi.');
      end loop;
    end if;
    return jsonb_build_object('baski',qty,'gider',expense,'fiyat',price);
  end if;
  raise exception 'Bilinmeyen kitap işlemi';
end $function$;

create or replace function public.uc_kitap_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid := auth.uid(); saat int := oyun.kitap_inceleme_saat(); r record;
begin
 perform oyun.profilim();
 -- Yayınevi yöneticisi paneli açınca bekleyen dosyalar "görüldü" olur; yazara bir kez haber verilir.
 for r in update oyun.uc_kitap k set incelendi = oyun.simdi()
   where k.durum='teklif' and k.incelendi is null
     and k.yayinevi in (select so.sirket_id from oyun.sirket_ortaklari so where so.user_id=u and so.pay>=50)
   returning k.yazar, k.baslik, (select ad from oyun.sirketler where id=k.yayinevi) ad
 loop
   perform oyun.bildir(r.yazar, '📖 '||coalesce(r.ad,'Yayınevi')||' «'||r.baslik||'» dosyanı gördü; karar bekleniyor.', oyun.simdi());
 end loop;
 return jsonb_build_object(
 'inceleme_saat',saat,
 'yayinevleri',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad,'kasa',oyun.kasa_goster('sirket',id,kasa),
    'sahip',(select oyun.kad(so.user_id) from oyun.sirket_ortaklari so where so.sirket_id=sirketler.id and so.pay>=50 order by so.pay desc, so.user_id limit 1),
    'bekleyen',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='teklif'),
    'yayinlanan',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='yayinda')))
  from oyun.sirketler where aktif and sektor='medya'),'[]'::jsonb),
 'benim_yayinevleri',coalesce((select jsonb_agg(s.id)
  from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id
  where s.aktif and s.sektor='medya' and o.user_id=u and o.pay>=50),'[]'::jsonb),
 'kitaplar',coalesce((select jsonb_agg(jsonb_build_object(
  'id',k.id,'baslik',k.baslik,'tur',k.tur,'ozet',k.ozet,
  'icerik',case when k.yazar=u
   or exists(select 1 from oyun.sirket_ortaklari o
     where o.sirket_id=k.yayinevi and o.user_id=u and o.pay>=50)
   or exists(select 1 from oyun.uc_kitap_satis a
     where a.kitap_id=k.id and a.alici=u) then k.icerik else null end,
  'yazar',(select kad from oyun.profiller where id=k.yazar),
  'yazar_benim',k.yazar=u,'yayinevi',k.yayinevi,'yayinevi_ad',s.ad,
  'durum',k.durum,'fiyat',k.fiyat,'stok',k.stok,'satilan',k.satilan,
  'telif',k.telif_orani,'aldim',
  exists(select 1 from oyun.uc_kitap_satis a where a.kitap_id=k.id and a.alici=u),
  'fiyat_son_degisim',k.fiyat_son_degisim,
  'gonderim',coalesce(k.gonderim,k.olusturma),'degisim_saat',24,
  'olusturma',k.olusturma,'yayin',k.yayin,
  'incelendi',k.incelendi,'karar',k.karar,'ret_kod',k.ret_kod,'ret_gerekce',k.ret_gerekce,
  'son_karar',case when k.durum='teklif' then coalesce(k.gonderim,k.olusturma) + make_interval(hours => saat) end,
  'eser',coalesce(k.eser,k.id),
  'kopya_bekleyen',case when k.yazar=u then (select count(*) from oyun.uc_kitap b where coalesce(b.eser,b.id)=coalesce(k.eser,k.id) and b.durum='teklif') end,
  'eser_yayinda',case when k.yazar=u then exists(select 1 from oyun.uc_kitap b where coalesce(b.eser,b.id)=coalesce(k.eser,k.id) and b.durum='yayinda') end,
  'yayinevi_sahip',(select oyun.kad(so.user_id) from oyun.sirket_ortaklari so where so.sirket_id=k.yayinevi and so.pay>=50 order by so.pay desc, so.user_id limit 1)
  ) order by k.id desc) from oyun.uc_kitap k join oyun.sirketler s on s.id=k.yayinevi
  where k.durum='yayinda' or k.yazar=u or exists(
    select 1 from oyun.sirket_ortaklari o where o.sirket_id=k.yayinevi
    and o.user_id=u and o.pay>=50)),'[]'::jsonb)
 );
end $function$;

-- 72 saatte karar verilmeyen dosyalar yazara iade edilir (saatte bir; sınırlı, tekrar çalıştırılabilir)
create or replace function oyun.kitap_dosya_zaman_asimi()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare t timestamptz := oyun.simdi(); r record; n int := 0; saat int := oyun.kitap_inceleme_saat();
begin
  if not pg_try_advisory_xact_lock(827615) then return jsonb_build_object('kilitli',true); end if;
  for r in select k.id, k.yazar, k.baslik, k.yayinevi, s.ad from oyun.uc_kitap k
     left join oyun.sirketler s on s.id = k.yayinevi
     where k.durum='teklif' and coalesce(k.gonderim,k.olusturma) <= t - make_interval(hours => saat)
     order by coalesce(k.gonderim,k.olusturma) limit 500
     for update of k skip locked
  loop
    begin
      update oyun.uc_kitap set durum='reddedildi', karar=t, ret_kod='sure', ret_gerekce=null where id=r.id and durum='teklif';
      perform oyun.bildir(r.yazar, '📚 '||coalesce(r.ad,'Yayınevi')||' «'||r.baslik||'» dosyan için '||saat||' saat içinde karar vermedi; dosya sana iade edildi. Hemen başka bir yayınevine gönderebilirsin.', t);
      perform oyun.kitap_yayinevi_bildir(r.yayinevi, '📚 «'||r.baslik||'» dosyası için '||saat||' saat içinde karar verilmediğinden dosya yazarına iade edildi.');
      n := n + 1;
    exception when others then
      raise warning 'kitap_dosya_zaman_asimi %: %', r.id, sqlerrm;
    end;
  end loop;
  return jsonb_build_object('iade', n);
end $$;
revoke all on function oyun.kitap_dosya_zaman_asimi() from public;
revoke all on function oyun.kitap_yayinevi_bildir(bigint,text) from public;

do $$ begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobid) from cron.job where jobname = 'kitap-dosya-sure';
    perform cron.schedule('kitap-dosya-sure', '17 * * * *', 'select oyun.kitap_dosya_zaman_asimi()');
  end if;
end $$;

-- Bekleyen dosyası olan yayınevi yöneticilerine bir kerelik hatırlatma (akilli_bildir: tekrar çalıştırılınca yinelenmez)
select oyun.akilli_bildir(so.user_id, 'kitap_bekleyen_20261126:'||x.yayinevi,
  '📚 '||x.ad||' yayınevinde karar bekleyen '||x.n||' kitap dosyası var. İş Dünyası › Kitap ve yayınevi ekranından inceleyip yayımlayabilir ya da reddedebilirsin. '||
  'Bundan sonra '||oyun.kitap_inceleme_saat()||' saat içinde karar verilmeyen dosyalar yazara iade edilir.')
from (select k.yayinevi, s.ad, count(*) n from oyun.uc_kitap k join oyun.sirketler s on s.id=k.yayinevi
      where k.durum='teklif' group by k.yayinevi, s.ad) x
join oyun.sirket_ortaklari so on so.sirket_id = x.yayinevi and so.pay >= 50;
