-- Anayasa 88,161: olağan kanun teklifini MV, butce teklifini Cumhurbaskani yapar.
CREATE OR REPLACE FUNCTION public.kanun_teklif(p_tur text, p_baslik text, p_metin text, p_veri jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b text; m text; v jsonb; top numeric; k text; yeni bigint; s record; pay numeric;
begin
  if oyun.gercekci_siyaset() and p_tur='butce' then
    -- Anayasa 161: butce kanun teklifini yalnizca Cumhurbaskani sunar.
    perform oyun.cb_zorunlu(p);
  else
    if not oyun.aktif_vekil(p.id) then raise exception 'Kanun teklifini yalnızca milletvekilleri verebilir; bütçe teklifini Cumhurbaşkanı sunar.'; end if;
    if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then
      raise exception 'Meclis Başkanı kanun teklifi veremez; tarafsız kalmalıdır.';
    end if;
  end if;
  if exists (select 1 from oyun.kanunlar where teklif_eden = p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
    raise exception 'Sonuçlanmamış bir teklifin varken yeni teklif veremezsin.';
  end if;
  b := btrim(coalesce(p_baslik, ''));
  if length(b) < 5 or length(b) > 120 then raise exception 'Kanun başlığı 5-120 karakter olmalı.'; end if;
  if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
  m := oyun.metin_temizle(p_metin, 8000);
  if length(m) < 10 then raise exception 'Gerekçe en az 10 karakter olmalı.'; end if;
  if p_tur = 'serbest' then v := null;
  elsif p_tur = 'butce' then
    -- Bütçe kanunu: gelir vergisi bandı (yürütme bu bant içinde ayarlar), belediye payı, partilere hazine yardımı, bakanlık payları.
    -- Verilmeyen alan yürürlükteki değerinde kalır.
    select jsonb_build_object('vergi_alt', round(coalesce((p_veri ->> 'vergi_alt')::numeric, u.vergi_alt), 1),
                              'vergi_ust', round(coalesce((p_veri ->> 'vergi_ust')::numeric, u.vergi_ust), 1),
                              'belediye_payi', round(coalesce((p_veri ->> 'belediye_payi')::numeric, u.belediye_payi), 1),
                              'parti_yardim', round(coalesce((p_veri ->> 'parti_yardim')::numeric, u.parti_yardim)),
                              'paylar', '{}'::jsonb)
      into v from oyun.ulke u where u.id = 1;
    if (v ->> 'vergi_alt')::numeric < 0 or (v ->> 'vergi_ust')::numeric > 45 or (v ->> 'vergi_alt')::numeric > (v ->> 'vergi_ust')::numeric then
      raise exception 'Vergi bandı %%0-%%45 arasında olmalı ve taban tavandan büyük olamaz.';
    end if;
    if (v ->> 'belediye_payi')::numeric not between 2 and 30 then raise exception 'Belediye payı %%2-%%30 arasında olmalı.'; end if;
    if (v ->> 'parti_yardim')::numeric not between 0 and 200000 then raise exception 'Partilere hazine yardımı günlük 0-200.000 ₺ arasında olmalı.'; end if;
    top := 0;
    for k in select kod from oyun.bakanliklar loop
      pay := coalesce((p_veri -> 'paylar' ->> k)::numeric, ((select butce from oyun.ulke where id = 1) ->> k)::numeric, 0);
      if pay < 0 or pay > 60 then raise exception 'Her bakanlığın payı 0-60 arasında olmalı (%).', k; end if;
      top := top + pay;
      v := jsonb_set(v, array['paylar', k], to_jsonb(round(pay, 1)));
    end loop;
    if abs(top - 100) > 0.5 then raise exception 'Bakanlık paylarının toplamı 100 olmalı (şu an %).', round(top, 1); end if;
  elsif p_tur = 'secim' then
    if (p_veri ->> 'baraj') is null or (p_veri ->> 'baraj')::numeric not between 0 and 10 then raise exception 'Baraj %%0-%%10 arasında olmalı.'; end if;
    v := jsonb_build_object('baraj', round((p_veri ->> 'baraj')::numeric, 1));
  elsif p_tur = 'iptal' then
    if not exists (select 1 from oyun.kararnameler where id = (p_veri ->> 'kararname_id')::bigint and durum = 'yururlukte') then
      raise exception 'İptal edilecek yürürlükte bir kararname seçmelisin.';
    end if;
    v := jsonb_build_object('kararname_id', (p_veri ->> 'kararname_id')::bigint);
  elsif p_tur = 'duzenleme' then
    if oyun.duzenleme_engel(p_veri ->> 'kod', 'kanun') is not null then raise exception '%', oyun.duzenleme_engel(p_veri ->> 'kod', 'kanun'); end if;
    v := jsonb_build_object('kod', p_veri ->> 'kod', 'deger', oyun.duzenleme_dogrula(p_veri ->> 'kod', (p_veri ->> 'deger')::numeric, 'ulke'));
    if (v ->> 'deger')::numeric = oyun.duz(v ->> 'kod') and (select kaynak from oyun.duzenlemeler where kod = v ->> 'kod') = 'kanun' then
      raise exception 'Bu kural zaten kanunla bu değerde.';
    end if;
  elsif p_tur = 'anayasa' then
    v := oyun.anayasa_dogrula(p_veri);
  else raise exception 'Geçersiz kanun türü.'; end if;
  if p_tur = 'butce' and (v ->> 'vergi_ust')::numeric > oyun.anayasa_deger('vergi_tavani') then
    raise exception 'Anayasa gelir vergisinin tavanını %%% olarak belirlemiştir; vergi bandı bunun üstüne çıkamaz.', oyun.anayasa_deger('vergi_tavani');
  end if;
  select * into s from oyun.kanun_suresi();
  -- Anayasa md. 175: anayasa degisikligi iki ayri Genel Kurul gorusmesi gerektirir.
  -- Oyundaki her gorusme en az bir normal gorusme suresi kadar devam eder.
  if p_tur='anayasa' and oyun.gercekci_siyaset() then s.gorusme:=s.gorusme*2; end if;
  insert into oyun.kanunlar(tur, baslik, metin, veri, teklif_eden, teklif_parti, teklif_at, oy_bas, oy_bit)
  values (p_tur, b, m, v, p.id, p.parti_id, t, t + s.gorusme, t + s.gorusme + s.oylama) returning id into yeni;
  if p_tur = 'anayasa' then
    insert into oyun.kanun_oylari(kanun_id, asama, vekil, parti_id, oy, zaman) values (yeni, 'imza', p.id, p.parti_id, 'kabul', t);
  end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
    select m2.user_id, t, case when p_tur = 'anayasa'
             then format('Anayasa değişikliği teklifi: "%s" (%s). Oylamaya geçmesi için vekillerin üçte biri %s''a kadar imza vermeli.', b, p.kad, to_char((t + s.gorusme) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI'))
             else format('Yeni kanun teklifi: "%s" (%s). Oylama %s''da başlıyor.', b, p.kad, to_char((t + s.gorusme) at time zone 'Europe/Istanbul', 'DD.MM HH24:MI')) end
    from oyun.makamlar m2 where m2.tur = 'mv' and m2.bit is null and m2.user_id <> p.id;
  perform oyun.olay('meclis', format('%s Meclis''e kanun teklifi verdi: %s', p.kad, b), null, p.parti_id, t);
  return jsonb_build_object('id', yeni);
end $function$
;