-- 16 Kasim 2026, beta ve lansmanda TBMM anayasal nisap ve oy korumasi.
-- Canli veritabaninda dogrulanan fonksiyon tanimlari; tablo, kayit veya hesap silinmez.
-- Uygulama sirasi: bu kaynak, ana SQL birlestirme listesinin sonlarinda yer alir.
CREATE OR REPLACE FUNCTION oyun.salt_cogunluk()
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select case when oyun.gercekci_siyaset()
    then floor(oyun.tbmm_tamsayi()/2.0)::int+1
    else greatest(1,floor(oyun.aktif_vekil_sayi()/2.0)::int+1) end
$function$

CREATE OR REPLACE FUNCTION public.erken_secim_oy(p_id bigint, p_oy text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); x oyun.erken_secim_teklifleri;
begin
  if p_oy not in ('kabul','ret','cekimser') then raise exception 'Geçersiz oy.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Erken seçimde yalnızca görevdeki milletvekilleri oy kullanabilir.'; end if;
  if oyun.gercekci_siyaset() and exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null)
  then raise exception 'Meclis Başkanı Genel Kurul oylamasına katılamaz (Anayasa md. 94).'; end if;
  select * into x from oyun.erken_secim_teklifleri where id=p_id for update;
  if x.id is null or x.durum<>'oylamada' or t<x.bas or t>=x.bit then raise exception 'Erken seçim oylaması açık değil.'; end if;
  insert into oyun.erken_secim_oylari(teklif_id,vekil,oy,zaman)
  values(x.id,p.id,p_oy,t)
  on conflict(teklif_id,vekil) do nothing;
  if not found then raise exception 'Bu önerge için oyunu kullandın; ikinci kez oy veremezsin.'; end if;
  perform oyun.erken_secim_sonuc(x.id,t);
  return public.siyasi_sistem();
end $function$

CREATE OR REPLACE FUNCTION public.meclis_oy(p_secim bigint, p_gorev text, p_aday text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.meclis_secim; a uuid; tn int;
begin
  select * into s from oyun.meclis_secim where id = p_secim;
  if s.id is null or s.durum <> 'oylama' then raise exception 'Bu seçimde şu an oylama yok.'; end if;
  if not oyun.aktif_vekil(p.id) then raise exception 'Yalnızca milletvekilleri oy kullanabilir.'; end if;
  if oyun.gercekci_siyaset() and exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then
    raise exception 'Meclis Başkanı TBMM oylamasına veya parti grubu siyasi faaliyetine katılamaz (Anayasa md. 94).';
  end if;
  if s.tur = 'baskan' then
    if t < coalesce(s.tur_bas, s.aday_bit) then raise exception 'Bu tur henüz başlamadı. Sandık açılınca oy kullanabilirsin.'; end if;
    if t >= s.tur_bit then raise exception 'Bu tur sona erdi.'; end if;
    tn := s.tur_no;
  else
    if t >= s.oy_bit then raise exception 'Oylama sona erdi.'; end if;
    if oyun.aktif_mv_parti(p.id) is distinct from s.parti_id then raise exception 'Grup seçiminde yalnızca partinin milletvekilleri oy kullanır.'; end if;
    tn := 0;
  end if;
  select ad.user_id into a from oyun.meclis_aday ad join oyun.profiller pr on pr.id = ad.user_id
   where ad.secim_id = s.id and ad.gorev = p_gorev and not ad.elendi and lower(pr.kad) = lower(btrim(p_aday));
  if a is null then raise exception 'Aday bulunamadı.'; end if;
  insert into oyun.meclis_oy(secim_id, tur_no, gorev, secmen, aday, zaman) values (s.id, tn, p_gorev, p.id, a, t) on conflict do nothing;
  if not found then raise exception 'Bu oylamada oyunu zaten kullandın.'; end if;
  return public.meclis_baskanlik();
end $function$

CREATE OR REPLACE FUNCTION oyun.meclis_tick(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
declare s oyun.meclis_secim; ms oyun.secimler; r record; dolu int; gerek int; ust record; ikinci uuid; n int; dongu int; m record; pk text;
begin
  -- Zamanlayıcı ile eşzamanlı oturumlar aynı turu iki kez sonuçlandıramaz.
  perform pg_advisory_xact_lock(hashtext('oyun.meclis_tick'));
  -- yeni yasama dönemi
  for ms in select * from oyun.secimler x where x.tur = 'mv' and x.durum = 'tamam' and x.goreve_bas <= t and x.goreve_bas > t - interval '20 days'
              and not exists (select 1 from oyun.meclis_secim y where y.mv_secim_id = x.id) order by x.goreve_bas loop
    perform oyun.meclis_donem_baslat(ms.id, ms.goreve_bas);
  end loop;
  -- görev şartı kalmayanlar (vekilliği düşen, partisi değişen)
  for m in select x.* from oyun.makamlar x where x.tur in ('tbmm','bskv','grup_bskv') and x.bit is null
             and (not oyun.aktif_vekil(x.user_id) or (x.tur in ('bskv','grup_bskv') and oyun.aktif_mv_parti(x.user_id) is distinct from x.parti_id)) loop
    perform oyun.makam_bitir(m.id, t, 'gorev_dustu');
    if m.tur = 'tbmm' and not exists (select 1 from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti') then
      insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (null, 'baskan', t, t + interval '24 hours');
      perform oyun.olay('meclis', 'TBMM Başkanlığı boşaldı. Ara seçim için adaylık 24 saat açık.', null, null, t);
    end if;
  end loop;
  -- TBMM Başkanı seçimi
  for s in select * from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      if not exists (select 1 from oyun.meclis_aday where secim_id = s.id) then
        if s.uzatma < 2 then
          update oyun.meclis_secim set aday_bit = aday_bit + interval '24 hours', uzatma = uzatma + 1 where id = s.id;
          perform oyun.olay('meclis', 'TBMM Başkanlığı için aday çıkmadı; adaylık süresi 24 saat uzatıldı.', null, null, t);
        else
          update oyun.meclis_secim set durum = 'bitti', sonuc = 'Aday çıkmadı; Geçici Başkan oturumları yönetmeye devam ediyor.' where id = s.id;
        end if;
        continue;
      end if;
      update oyun.meclis_secim set durum = 'oylama', tur_no = 1, tur_bas = aday_bit + interval '30 minutes', tur_bit = aday_bit + interval '75 minutes' where id = s.id;
      insert into oyun.bildirimler(user_id, zaman, metin)
        select x.user_id, s.aday_bit, 'TBMM Başkanlığı adaylığı bitti. 1. tur 30 dakika sonra başlayacak; gizli oy pusulan Devlet › Meclis ekranında.'
        from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
      select * into s from oyun.meclis_secim where id = s.id;
    end if;
    dongu := 0;
    while s.durum = 'oylama' and t >= s.tur_bit and dongu < 5 loop
      dongu := dongu + 1;
      dolu := oyun.tbmm_tamsayi();
      gerek := case when s.tur_no <= 2 then ceil(dolu * 2 / 3.0)::int when s.tur_no = 3 then floor(dolu / 2.0)::int + 1 else 0 end;
      select * into ust from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) limit 1;
      update oyun.meclis_secim set turlar = turlar || jsonb_build_array(jsonb_build_object('tur', s.tur_no, 'gerek', gerek, 'katilim',
          (select count(*) from oyun.meclis_oy where secim_id = s.id and tur_no = s.tur_no and gorev = 'baskan'),
          'sonuc', (select jsonb_agg(jsonb_build_object('kad', oyun.kad(x.user_id), 'oy', x.oy)) from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x)))
        where id = s.id;
      -- Dördüncü turda yalnız en çok oy alan iki aday yarışır; eşitlikte seçilmiş ilan edilmez.
      -- Eşitlik oluşursa 15 dakika sonra 45 dakikalık yeni bir nihai oylama açılır.
      select x.oy into n from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) offset 1 limit 1;
      if ust.user_id is not null and ((s.tur_no < 4 and ust.oy >= gerek)
         or (s.tur_no >= 4 and ust.oy > 0 and ust.oy > coalesce(n, -1) and (not oyun.gercekci_siyaset() or (select count(*) from oyun.meclis_oy where secim_id=s.id and tur_no=s.tur_no and gorev='baskan') >= ceil(dolu/3.0)))) then
        perform oyun.meclis_gorev_ata(ust.user_id, 'tbmm', s.tur_bit);
        update oyun.meclis_secim set durum = 'bitti', sonuc = format('%s %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy) where id = s.id;
        perform oyun.olay('meclis', format('%s, %s. turda %s oyla TBMM Başkanı seçildi.', oyun.kad(ust.user_id), s.tur_no, ust.oy), null, oyun.aktif_mv_parti(ust.user_id), s.tur_bit);
        perform oyun.gazete_ekle('atama', format('TBMM Başkanlığına %s seçilmiştir', oyun.kad(ust.user_id)), format('Genel Kurul''un gizli oylamasında %s. turda %s oy.', s.tur_no, ust.oy), null, s.tur_bit);
      elsif ust.user_id is null then
        update oyun.meclis_secim set durum = 'bitti', sonuc = 'Adaylar milletvekilliği sıfatını kaybettiği için seçim sonuçsuz kaldı.' where id = s.id;
      else
        if s.tur_no = 3 then
          -- 4. tur: en çok oy alan iki aday
          update oyun.meclis_aday set elendi = true where secim_id = s.id and gorev = 'baskan'
            and user_id not in (select x.user_id from oyun.meclis_sayim(s.id, 3, 'baskan') x where oyun.aktif_vekil(x.user_id) limit 2);
        end if;
        update oyun.meclis_secim set tur_no = tur_no + 1, tur_bas = tur_bit + interval '15 minutes', tur_bit = tur_bit + interval '60 minutes' where id = s.id;
        perform oyun.olay('meclis', format('TBMM Başkanlığı seçiminin %s. turunda başkan seçilemedi; %s. tur oylaması 15 dakika sonra başlayacak.', s.tur_no, s.tur_no + 1), null, null, s.tur_bit);
        insert into oyun.bildirimler(user_id, zaman, metin)
        select distinct x.user_id, s.tur_bit,
          format('TBMM Başkanlığı %s. tur oylaması %s saatinde açılacak ve 45 dakika açık kalacak.',
            s.tur_no + 1,
            to_char((s.tur_bit + interval '15 minutes') at time zone 'Europe/Istanbul', 'HH24:MI'))
        from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
      end if;
      select * into s from oyun.meclis_secim where id = s.id;
    end loop;
  end loop;
  -- Parti grup seçimleri
  for s in select * from oyun.meclis_secim where tur = 'grup' and durum <> 'bitti' order by id loop
    if s.durum = 'aday' and t >= s.aday_bit then
      update oyun.meclis_secim set durum = 'oylama' where id = s.id;
      s.durum := 'oylama';
    end if;
    if s.durum = 'oylama' and t >= s.oy_bit then
      select kisa into pk from oyun.partiler where id = s.parti_id;
      if s.bskv_hakki then
        select * into ust from oyun.meclis_sayim(s.id, 0, 'bskv') x
          where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'bskv') is null limit 1;
        if ust.user_id is not null then
          perform oyun.meclis_gorev_ata(ust.user_id, 'bskv', s.oy_bit);
          perform oyun.olay('meclis', format('%s grubu %s''i TBMM Başkanvekili olarak seçti.', pk, oyun.kad(ust.user_id)), null, s.parti_id, s.oy_bit);
        end if;
      end if;
      n := (select count(*) from oyun.meclis_aday a where a.secim_id = s.id and a.gorev = 'grup_bskv');
      for r in select x.* from oyun.meclis_sayim(s.id, 0, 'grup_bskv') x
                where oyun.aktif_mv_parti(x.user_id) = s.parti_id and oyun.rol_cakisma(x.user_id, 'grup_bskv') is null
                  and (n <= s.grup_bskv_sayi or x.oy > 0)
                limit s.grup_bskv_sayi loop
        perform oyun.meclis_gorev_ata(r.user_id, 'grup_bskv', s.oy_bit);
      end loop;
      update oyun.meclis_secim set durum = 'bitti', sonuc = 'Grup seçimi tamamlandı.' where id = s.id;
      perform oyun.olay('meclis', format('%s Meclis grubu başkanvekillerini seçti.', pk), null, s.parti_id, s.oy_bit);
    end if;
  end loop;
end $function$

CREATE OR REPLACE FUNCTION oyun.kanun_tick(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
declare k oyun.kanunlar; c record; dolu int; cb uuid; s record;
begin
  select * into s from oyun.kanun_suresi();
  -- anayasa değişikliği: görüşme bitince imza sayısı dolu sandalyelerin üçte birine ulaşmadıysa teklif düşer
  for k in select * from oyun.kanunlar where durum = 'gorusmede' and tur = 'anayasa' and t >= oy_bas and (not oyun.gercekci_siyaset() or anayasa_tur=0) order by oy_bas loop
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
    select * into c from oyun.kanun_say(k.id,case when oyun.gercekci_siyaset() and k.anayasa_tur=1 then 'ikinci' else 'ilk' end);
    dolu := oyun.tbmm_tamsayi();
    cb := oyun.aktif_cb();
    if oyun.gercekci_siyaset() and k.anayasa_tur=0 then
      if c.kabul>=ceil(dolu*3/5.0) then
        update oyun.kanunlar set durum='gorusmede',anayasa_tur=1,
          oy_bas=k.oy_bit+interval '48 hours',oy_bit=k.oy_bit+interval '72 hours',
          sonuc_metin=format('İlk gizli oylamada %s kabul. İkinci oylama en az 48 saat sonra.',c.kabul)
          where id=k.id;
        perform oyun.olay('meclis',format('"%s" anayasa değişikliği ilk görüşmeyi geçti (%s kabul); ikinci oylama 48 saat sonra.',k.baslik,c.kabul),null,k.teklif_parti,k.oy_bit);
      else
        update oyun.kanunlar set durum='ret',sonuc_at=k.oy_bit,
          sonuc_metin=format('İlk anayasa oylaması reddedildi: %s kabul; en az %s gerekli.',c.kabul,ceil(dolu*3/5.0)) where id=k.id;
      end if;
      continue;
    end if;
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then
      update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
        sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: üçte iki çoğunluk sağlandı.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.bildir(cb, format('"%s" anayasa değişikliği Meclis''ten üçte iki çoğunlukla geçti. 48 saat içinde yayımla ya da halkoyuna sun.', k.baslik), k.oy_bit);
      perform oyun.olay('meclis', format('"%s" anayasa değişikliği üçte iki çoğunlukla kabul edildi (%s kabul). Cumhurbaşkanına sunuldu.', k.baslik, c.kabul), null, k.teklif_parti, k.oy_bit);
    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      if oyun.gercekci_siyaset() and cb is not null then
        update oyun.kanunlar set durum='cb_onayinda',cb_bit=k.oy_bit+s.cb,
          sonuc_metin=format('İkinci gizli oylamada %s kabul. CB gerekçeli geri gönderebilir; aksi hâlde referandum zorunlu.',c.kabul) where id=k.id;
        perform oyun.bildir(cb,format('"%s" anayasa değişikliği %s oyla geçti: gerekçeli iade veya referandum.',k.baslik,c.kabul),k.oy_bit);
      else
        update oyun.kanunlar set sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.referandum_baslat(k.id, k.oy_bit);
      end if;
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
          case when c.kabul+c.ret+c.cekimser < (case when oyun.gercekci_siyaset() then ceil(dolu/3.0) else ceil(dolu/2.0) end)
               then 'Yeterli katılım olmadı' else 'Kabul çoğunluğu sağlanamadı' end,
          c.kabul, c.ret, c.cekimser, c.kabul+c.ret+c.cekimser,
          dolu, (case when oyun.gercekci_siyaset() then ceil(dolu/3.0) else ceil(dolu/2.0) end), greatest(floor((c.kabul+c.ret+c.cekimser)/2.0)+1, case when oyun.gercekci_siyaset() then floor(dolu/4.0)+1 else 1 end))
      where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" teklifin Meclis''te kabul edilmedi.', k.baslik), least(t,k.oy_bit));
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'cb_onayinda' and t >= cb_bit order by cb_bit loop
    if oyun.gercekci_siyaset() and k.tur='anayasa' and k.veto_gerekce is null
      and (select count(*) from oyun.kanun_oylari o where o.kanun_id=k.id
         and o.asama=case when k.anayasa_tur=1 then 'ikinci' else 'ilk' end and o.oy='kabul')<ceil(oyun.tbmm_tamsayi()*2/3.0)
    then
      perform oyun.referandum_baslat(k.id,k.cb_bit);
    else
      perform oyun.kanun_yururluk(k.id,k.cb_bit,case when k.tur='anayasa' then 'Cumhurbaşkanı süre içinde karar vermedi; yayımlandı.'
          else 'Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.' end);
    end if;
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
          c.kabul,c.ret,c.cekimser,c.kabul+c.ret+c.cekimser,dolu,case when oyun.gercekci_siyaset() then ceil(dolu/3.0) else ceil(dolu/2.0) end) where id = k.id;
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
