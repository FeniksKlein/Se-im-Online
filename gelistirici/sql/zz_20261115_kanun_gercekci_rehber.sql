-- Meclis kanun teklifleri: gercekci modu 600 sandalye bilgisi, 200/151/301/400 esikleri,
-- anayasa degisikliginde iki gorusme icin iki kat gorusme suresi.
CREATE OR REPLACE FUNCTION public.kanun_detay(p_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; dolu int := oyun.tbmm_tamsayi();
  v_oy_sayisi int; v_katilim int;
begin
  select * into k from oyun.kanunlar where id = p_id;
  if k.id is null then raise exception 'Kanun bulunamadı.'; end if;
  v_katilim := case when oyun.gercekci_siyaset() then ceil(dolu/3.0)::int else greatest(1,ceil(dolu/2.0)::int) end;
  select count(*) into v_oy_sayisi from oyun.kanun_oylari
  where kanun_id = k.id and asama = case when k.durum='israr' then 'israr' else 'ilk' end;
  return oyun.kanun_ozet(k, p, t) || jsonb_build_object(
    'metin', k.metin, 'veri', k.veri, 'veto_gerekce', k.veto_gerekce, 'sonuc_metin', k.sonuc_metin,
    'kararname', case when k.tur = 'iptal' then (select jsonb_build_object('no', no, 'baslik', baslik) from oyun.kararnameler where id = (k.veri ->> 'kararname_id')::bigint) end,
    'dolu', dolu, 'toplanti_yeter', case when k.tur='anayasa' then ceil(dolu/3.0) else v_katilim end,
    'karar_yeter', case when k.tur='anayasa' then ceil(dolu*3/5.0) when oyun.gercekci_siyaset() then greatest(floor(v_oy_sayisi/2.0)+1,floor(dolu/4.0)+1) else floor(greatest(v_oy_sayisi,v_katilim)/2.0)+1 end,
    'israr_yeter', case when oyun.gercekci_siyaset() then case when k.tur='anayasa' then ceil(dolu*2/3.0) else floor(dolu/2.0)+1 end else floor(greatest(v_oy_sayisi,v_katilim)/2.0)+1 end,
    'kullanilan_oy', v_oy_sayisi,
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
CREATE OR REPLACE FUNCTION public.kanun_teklif(p_tur text, p_baslik text, p_metin text, p_veri jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b text; m text; v jsonb; top numeric; k text; yeni bigint; s record; pay numeric;
begin
  if not oyun.aktif_vekil(p.id) then raise exception 'Kanun teklifini yalnızca milletvekilleri verebilir.'; end if;
  if exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'tbmm' and bit is null) then
    raise exception 'Meclis Başkanı kanun teklifi veremez; tarafsız kalmalıdır.';
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