-- 2026.11.16-3 · Cumhurbaşkanının 48 saatte kabine kurma zorunluluğu kaldırıldı.
-- Türkiye Cumhuriyeti Anayasası'nda (m.104, m.106) Cumhurbaşkanının belirli sürede belirli sayıda bakan atayamaması
-- nedeniyle görevinin kendiliğinden sona ermesi diye bir hüküm yoktur. Bakanlıklar boş kalsa da Cumhurbaşkanı,
-- diğer bakanlar ve Cumhurbaşkanı yardımcıları görevde kalır; Cumhurbaşkanı boş bakanlığa istediği zaman atama yapar.
-- Eski kuraldan kalan zamanlayıcı yalnız bilgilendirme yapar (günde en çok bir kez). Geçmiş kayıtlar silinmez.
-- Önceki hata: süre dolunca düşürme işlemi gazete_ekle('siyaset',…) çağırdığı için gazete_tur_check kısıtına takılıp
-- her dakika geri alınıyordu (2.009 hata). Bu yüzden 13–14 Kasım'da beratelpablo2 düşürülemedi; yeni kodda düşürme ve
-- o gazete çağrısı yoktur.

create or replace function oyun.cb_kabine_tick()
returns integer language plpgsql security definer set search_path to '' as $function$
declare
  t timestamptz := oyun.simdi();
  v_cb oyun.makamlar;
  v_k oyun.cb_kabine_sure;
  dolu integer; toplam integer; eksik text;
begin
  if oyun.hukumet_sistemi() <> 0 then return 0; end if;
  if not pg_try_advisory_xact_lock(40881111) then return 0; end if;
  select * into v_cb from oyun.makamlar where tur='cb' and bit is null order by bas desc limit 1;
  if v_cb.id is null then return 0; end if;

  insert into oyun.cb_kabine_sure(makam_id,baslangic,son_tarih)
  values (v_cb.id, coalesce(v_cb.bas,t), coalesce(v_cb.bas,t))
  on conflict (makam_id) do nothing;
  select * into v_k from oyun.cb_kabine_sure where makam_id=v_cb.id for update;

  select count(*) into toplam from oyun.bakanliklar;
  select count(*) into dolu from oyun.bakanliklar b
   where exists (select 1 from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.bakanlik=b.kod);

  if dolu = toplam and toplam > 0 then
    if v_k.durum <> 'tamam' then
      update oyun.cb_kabine_sure set durum='tamam', ilk_tamam=coalesce(ilk_tamam,t), son_islem=t, son_uyari=0 where makam_id=v_cb.id;
      perform oyun.bildir(v_cb.user_id, format('Kabine tam: %s/%s bakanlıkta görevli bakan var.', dolu, toplam), t);
    end if;
    return 0;
  end if;

  -- Boş bakanlık var: yalnız bilgilendirme (24 saatte bir). Hiçbir görev sona erdirilmez.
  if v_k.durum = 'tamam' then
    update oyun.cb_kabine_sure set durum='yenileme', son_uyari=0, son_islem=t - interval '24 hours' where makam_id=v_cb.id;
    select * into v_k from oyun.cb_kabine_sure where makam_id=v_cb.id;
  end if;
  if v_k.son_uyari = 0 or v_k.son_islem <= t - interval '24 hours' then
    select string_agg(b.ad, ', ' order by b.sira) into eksik from oyun.bakanliklar b
     where not exists (select 1 from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.bakanlik=b.kod);
    update oyun.cb_kabine_sure set son_uyari=son_uyari+1, son_islem=t where makam_id=v_cb.id;
    perform oyun.bildir(v_cb.user_id,
      format('Bilgi: %s bakanlık boş (%s/%s dolu): %s. Dilediğin zaman Yönetim › Kabine ekranından atama yapabilirsin; boş bakanlık görevini etkilemez.',
        toplam-dolu, dolu, toplam, coalesce(eksik,'')), t);
  end if;
  return 0;
end $function$;

create or replace function oyun.cb_kabine_baslangic_tg()
returns trigger language plpgsql set search_path to '' as $function$
begin
  if new.tur='cb' and new.bit is null and oyun.hukumet_sistemi()=0 then
    insert into oyun.cb_kabine_sure(makam_id,baslangic,son_tarih)
    values (new.id, coalesce(new.bas,oyun.simdi()), coalesce(new.bas,oyun.simdi()))
    on conflict (makam_id) do nothing;
    perform oyun.bildir(new.user_id,
      'Cumhurbaşkanlığı: Bakanları sen atarsın. Bakanlıklara istediğin zaman atama yapabilirsin; boş kalan bakanlık görevini düşürmez.',
      oyun.simdi());
  end if;
  return new;
end $function$;

-- Bakan atamasında 48 saat engeli kaldırıldı; yalnız "atamayı yapacak Cumhurbaşkanı var mı" denetimi kalır.
create or replace function oyun.cb_kabine_sure_ata_kontrol()
returns trigger language plpgsql set search_path to '' as $function$
begin
  if new.tur='bakan' and new.bit is null and oyun.hukumet_sistemi()=0 then
    if not exists (select 1 from oyun.makamlar m where m.tur='cb' and m.bit is null) then
      raise exception 'Cumhurbaşkanı bulunmadığı için yeni bakan atanamaz.';
    end if;
  end if;
  return new;
end $function$;

-- Kabine ekranı: süre/geri sayım yok, yalnız boş bakanlık bilgisi (alan adları eski istemcilerle uyumlu)
do $k$
declare s text := pg_get_functiondef('public.kabine()'::regprocedure);
  eski text := $e$'durum',v_sure.durum,
       'son_tarih',v_sure.son_tarih,$e$;
  yeni text := $e$'durum',case when v_dolu>=v_toplam then 'tamam' else 'eksik' end,
       'zorunlu',false,
       'aciklama','Boş bakanlık Cumhurbaşkanının görevini etkilemez; atama dilediğin zaman yapılabilir.',
       'son_tarih',null,$e$;
  eski2 text := $e$'kalan_saniye',greatest(0,floor(extract(epoch FROM v_sure.son_tarih-oyun.simdi()))::integer),$e$;
  yeni2 text := $e$'kalan_saniye',null,$e$;
begin
  if position(eski in s)>0 then s := replace(s,eski,yeni); end if;
  if position(eski2 in s)>0 then s := replace(s,eski2,yeni2); end if;
  execute s;
end $k$;

update oyun.zamanlayici_adim set periyot_dk=60, ofset_dk=7 where adim='cb_kabine_48saat';
