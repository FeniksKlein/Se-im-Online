-- Anayasa 175: CB geri gonderme hakki ve iade edilen metinde 2/3 aynen kabul.
CREATE OR REPLACE FUNCTION public.kanun_cb_karar(p_id bigint, p_karar text, p_gerekce text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kanunlar; s record;
begin
  perform oyun.cb_zorunlu(p);
  select * into k from oyun.kanunlar where id = p_id for update;
  if k.durum <> 'cb_onayinda' or t >= k.cb_bit then raise exception 'Bu kanun onayınızı beklemiyor.'; end if;
  if k.tur = 'anayasa' then
    if p_karar = 'onay' then
      perform oyun.kanun_yururluk(k.id, t, format('Meclis''te üçte iki çoğunlukla kabul edildi; Cumhurbaşkanı %s yayımladı.', p.kad));
    elsif p_karar = 'halkoyu' then
      perform oyun.referandum_baslat(k.id, t);
      perform oyun.olay('referandum', format('Cumhurbaşkanı %s, "%s" anayasa değişikliğini halkoyuna sundu.', p.kad, k.baslik), null, p.parti_id, t);
    elsif p_karar = 'veto' and oyun.gercekci_siyaset() then
      if length(btrim(coalesce(p_gerekce,''))) < 10 then raise exception 'Anayasa değişikliğini iade etmek için gerekçe en az 10 karakter olmalı.'; end if;
      select * into s from oyun.kanun_suresi();
      update oyun.kanunlar set durum='israr',israr_bit=t+s.oylama,
        veto_gerekce=oyun.metin_temizle(p_gerekce,3000) where id=k.id;
      perform oyun.bildir(k.teklif_eden,format('Cumhurbaşkanı "%s" anayasa değişikliğini iade etti. Aynen kabulü için üçte iki (400) kabul oyu gerekir.',k.baslik),t);
      perform oyun.olay('meclis',format('Cumhurbaşkanı %s, "%s" anayasa değişikliğini TBMM''ye geri gönderdi.',p.kad,k.baslik),null,p.parti_id,t);
    else raise exception 'Anayasa değişikliği için yayımla, halkoyuna sun veya gerçekçi siyasette gerekçeli iade seçeneklerinden birini seç.'; end if;
    return public.kanun_detay(p_id);
  end if;
  if p_karar = 'onay' then
    perform oyun.kanun_yururluk(k.id, t, format('Cumhurbaşkanı %s tarafından onaylandı.', p.kad));
  elsif p_karar = 'veto' then
    if oyun.gercekci_siyaset() and k.tur = 'butce' then raise exception 'Bütçe kanunu Cumhurbaşkanınca geri gönderilemez.'; end if;
    if coalesce(btrim(p_gerekce), '') = '' then raise exception 'Veto için gerekçe yazmalısın.'; end if;
    select * into s from oyun.kanun_suresi();
    update oyun.kanunlar set durum = 'israr', israr_bit = t + s.oylama, veto_gerekce = oyun.metin_temizle(p_gerekce, 3000) where id = k.id;
    perform oyun.bildir(k.teklif_eden, format('Cumhurbaşkanı "%s" kanununu veto etti. Meclis 24 saat içinde salt çoğunlukla ısrar edebilir.', k.baslik), t);
    insert into oyun.bildirimler(user_id, zaman, metin)
      select m.user_id, t, format('Veto: "%s" Meclis''e iade edildi. Israr oylaması 24 saat sürecek.', k.baslik)
      from oyun.makamlar m where m.tur = 'mv' and m.bit is null and m.user_id <> k.teklif_eden;
    perform oyun.olay('meclis', format('Cumhurbaşkanı %s, "%s" kanununu veto ederek Meclis''e iade etti.', p.kad, k.baslik), null, p.parti_id, t);
  else raise exception 'Geçersiz karar.'; end if;
  return public.kanun_detay(p_id);
end $function$
;
CREATE OR REPLACE FUNCTION oyun.kanun_tick(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
declare k oyun.kanunlar; c record; dolu int; cb uuid; s record;
begin
  select * into s from oyun.kanun_suresi();
  -- anayasa değişikliği: görüşme bitince imza sayısı dolu sandalyelerin üçte birine ulaşmadıysa teklif düşer
  for k in select * from oyun.kanunlar where durum = 'gorusmede' and tur = 'anayasa' and t >= oy_bas order by oy_bas loop
    dolu := oyun.tbmm_tamsayi();
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
    dolu := oyun.tbmm_tamsayi();
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
  for k in select * from oyun.kanunlar kl
    where kl.durum = 'oylamada' and kl.tur <> 'anayasa'
      and (t >= kl.oy_bit or (
        select count(*) from oyun.kanun_oylari o
        where o.kanun_id = kl.id and o.asama = 'ilk'
      ) >= (case when oyun.gercekci_siyaset() then oyun.tbmm_tamsayi()+1 else greatest(1,ceil(oyun.dolu_sandalye()/2.0)::int) end))
    order by kl.oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.tbmm_tamsayi();
    if dolu > 0 and (c.kabul + c.ret + c.cekimser) >= (case when oyun.gercekci_siyaset() then ceil(dolu / 3.0) else ceil(dolu / 2.0) end) and c.kabul > (c.kabul + c.ret + c.cekimser) / 2.0 and (not oyun.gercekci_siyaset() or c.kabul >= floor(dolu / 4.0)+1) then
      cb := oyun.aktif_cb();
      if cb is null then
        perform oyun.kanun_yururluk(k.id, least(t,k.oy_bit), format('Meclis''te %s kabul, %s ret oyla kabul edildi (cumhurbaşkanı makamı boş).', c.kabul, c.ret));
      else
        update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = least(t,k.oy_bit) + s.cb,
          sonuc_metin = format('Meclis''te %s kabul, %s ret, %s çekimser oyla kabul edildi.', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.bildir(cb, format('"%s" kanunu Meclis''ten geçti ve onayınızı bekliyor. 48 saat içinde onaylayın ya da veto edin.', k.baslik), least(t,k.oy_bit));
        perform oyun.olay('meclis', format('"%s" Meclis''te kabul edildi (%s kabul, %s ret). Cumhurbaşkanının onayına sunuldu.', k.baslik, c.kabul, c.ret), null, k.teklif_parti, least(t,k.oy_bit));
      end if;
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = least(t,k.oy_bit),
        sonuc_metin = format('%s: %s kabul, %s ret, %s çekimser (%s/%s katılım, asgari %s, kabul için %s oy).',
          case when c.kabul+c.ret+c.cekimser < ceil(dolu/2.0)
               then 'Yeterli katılım olmadı' else 'Kabul çoğunluğu sağlanamadı' end,
          c.kabul, c.ret, c.cekimser, c.kabul+c.ret+c.cekimser,
          dolu, ceil(dolu/2.0), floor((c.kabul+c.ret+c.cekimser)/2.0)+1)
      where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" teklifin Meclis''te kabul edilmedi.', k.baslik), least(t,k.oy_bit));
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'cb_onayinda' and t >= cb_bit order by cb_bit loop
    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = 'anayasa' then 'Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.'
                                                    else 'Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.' end);
  end loop;
  for k in select * from oyun.kanunlar kl
    where kl.durum='israr' and (t >= kl.israr_bit or (
      select count(*) from oyun.kanun_oylari o
      where o.kanun_id=kl.id and o.asama='israr'
    ) >= (case when oyun.gercekci_siyaset() then oyun.tbmm_tamsayi()+1 else greatest(1,ceil(oyun.dolu_sandalye()/2.0)::int) end))
    order by kl.israr_bit loop
    select * into c from oyun.kanun_say(k.id, 'israr');
    dolu := oyun.tbmm_tamsayi();
    if dolu > 0 and (c.kabul+c.ret+c.cekimser) >= (case when oyun.gercekci_siyaset() then ceil(dolu/3.0) else ceil(dolu/2.0) end) and c.kabul > (c.kabul+c.ret+c.cekimser)/2.0 and (not oyun.gercekci_siyaset() or c.kabul >= floor(dolu/2.0)+1) then
      if k.tur='anayasa' and oyun.gercekci_siyaset() then
        if c.kabul >= ceil(dolu*2/3.0) then
          update oyun.kanunlar set durum='cb_onayinda',cb_bit=least(t,k.israr_bit)+s.cb,
            sonuc_metin=format('Cumhurbaşkanından iade edilen anayasa değişikliği %s kabul oyuyla aynen kabul edildi.',c.kabul)
          where id=k.id;
          perform oyun.bildir(oyun.aktif_cb(),format('Meclis "%s" anayasa değişikliğinde %s oyla ısrar etti: yayımla veya halkoyuna sun.',k.baslik,c.kabul),least(t,k.israr_bit));
        else
          update oyun.kanunlar set durum='dustu',sonuc_at=least(t,k.israr_bit),
            sonuc_metin=format('İade edilen anayasa değişikliği %s kabul oyu aldı; en az %s gerekliydi.',c.kabul,ceil(dolu*2/3.0))
          where id=k.id;
        end if;
      else
        perform oyun.kanun_yururluk(k.id, least(t,k.israr_bit), format('Veto sonrası Meclis %s oyla ısrar etti.', c.kabul));
      end if;
    else
      update oyun.kanunlar set durum = 'dustu', sonuc_at = least(t,k.israr_bit),
        sonuc_metin = format('Veto sonrası ısrar oylaması sonuçlandı: %s kabul, %s ret, %s çekimser; %s/%s katılım (asgari %s). Kanun düştü.',
          c.kabul,c.ret,c.cekimser,c.kabul+c.ret+c.cekimser,dolu,ceil(dolu/2.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" veto sonrası ısrar oylamasında düştü.', k.baslik), least(t,k.israr_bit));
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