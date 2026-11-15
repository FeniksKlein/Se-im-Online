-- 2026-11-15 / Anayasa md.175: iki gizli oylama, arada 48 saat, zorunlu referandum ayrımı.
-- Veri silme yok; kural etkinliği oyun.gercekci_siyaset() ile kontrol edilir.
alter table oyun.kanunlar add column if not exists anayasa_tur smallint not null default 0;
alter table oyun.kanun_oylari drop constraint if exists kanun_oylari_asama_check;
alter table oyun.kanun_oylari add constraint kanun_oylari_asama_check check(asama in ('ilk','ikinci','israr','imza'));
DO $patch$
declare s text;
begin
  s:=pg_get_functiondef('oyun.kanun_tick(timestamptz)'::regprocedure);
  if strpos(s,'if oyun.gercekci_siyaset() and k.anayasa_tur=0')=0 then
    if strpos(s,'    select * into c from oyun.kanun_say(k.id, ''ilk'');
    dolu := oyun.tbmm_tamsayi();
    cb := oyun.aktif_cb();
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then')=0 then raise exception 'Kanun yamasi surum uyumsuz: oyun.kanun_tick(timestamp'; end if;
    s:=replace(s,'    select * into c from oyun.kanun_say(k.id, ''ilk'');
    dolu := oyun.tbmm_tamsayi();
    cb := oyun.aktif_cb();
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then','    select * into c from oyun.kanun_say(k.id,case when oyun.gercekci_siyaset() and k.anayasa_tur=1 then ''ikinci'' else ''ilk'' end);
    dolu := oyun.tbmm_tamsayi();
    cb := oyun.aktif_cb();
    if oyun.gercekci_siyaset() and k.anayasa_tur=0 then
      if c.kabul>=ceil(dolu*3/5.0) then
        update oyun.kanunlar set durum=''gorusmede'',anayasa_tur=1,
          oy_bas=k.oy_bit+interval ''48 hours'',oy_bit=k.oy_bit+interval ''72 hours'',
          sonuc_metin=format(''İlk gizli oylamada %s kabul. İkinci oylama en az 48 saat sonra.'',c.kabul)
          where id=k.id;
        perform oyun.olay(''meclis'',format(''"%s" anayasa değişikliği ilk görüşmeyi geçti (%s kabul); ikinci oylama 48 saat sonra.'',k.baslik,c.kabul),null,k.teklif_parti,k.oy_bit);
      else
        update oyun.kanunlar set durum=''ret'',sonuc_at=k.oy_bit,
          sonuc_metin=format(''İlk anayasa oylaması reddedildi: %s kabul; en az %s gerekli.'',c.kabul,ceil(dolu*3/5.0)) where id=k.id;
      end if;
      continue;
    end if;
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then');
    if strpos(s,'    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      update oyun.kanunlar set sonuc_metin = format(''Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.'', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.referandum_baslat(k.id, k.oy_bit);')=0 then raise exception 'Kanun yamasi surum uyumsuz: oyun.kanun_tick(timestamp'; end if;
    s:=replace(s,'    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      update oyun.kanunlar set sonuc_metin = format(''Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.'', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.referandum_baslat(k.id, k.oy_bit);','    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      if oyun.gercekci_siyaset() and cb is not null then
        update oyun.kanunlar set durum=''cb_onayinda'',cb_bit=k.oy_bit+s.cb,
          sonuc_metin=format(''İkinci gizli oylamada %s kabul. CB gerekçeli geri gönderebilir; aksi hâlde referandum zorunlu.'',c.kabul) where id=k.id;
        perform oyun.bildir(cb,format(''"%s" anayasa değişikliği %s oyla geçti: gerekçeli iade veya referandum.'',k.baslik,c.kabul),k.oy_bit);
      else
        update oyun.kanunlar set sonuc_metin = format(''Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.'', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.referandum_baslat(k.id, k.oy_bit);
      end if;');
    if strpos(s,'    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = ''anayasa'' then ''Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.''
                                                    else ''Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.'' end);')=0 then raise exception 'Kanun yamasi surum uyumsuz: oyun.kanun_tick(timestamp'; end if;
    s:=replace(s,'    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = ''anayasa'' then ''Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.''
                                                    else ''Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.'' end);','    if oyun.gercekci_siyaset() and k.tur=''anayasa'' and k.veto_gerekce is null
      and (select count(*) from oyun.kanun_oylari o where o.kanun_id=k.id
         and o.asama=case when k.anayasa_tur=1 then ''ikinci'' else ''ilk'' end and o.oy=''kabul'')<ceil(oyun.tbmm_tamsayi()*2/3.0)
    then
      perform oyun.referandum_baslat(k.id,k.cb_bit);
    else
      perform oyun.kanun_yururluk(k.id,k.cb_bit,case when k.tur=''anayasa'' then ''Cumhurbaşkanı süre içinde karar vermedi; yayımlandı.''
          else ''Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.'' end);
    end if;');
    execute s;
  end if;
  s:=pg_get_functiondef('public.kanun_oy(bigint,text)'::regprocedure);
  if strpos(s,'k.anayasa_tur=1')=0 then
    if strpos(s,'if k.durum = ''oylamada'' and t >= k.oy_bas and t < k.oy_bit then a := ''ilk'';')=0 then raise exception 'Kanun yamasi surum uyumsuz: public.kanun_oy(bigint,te'; end if;
    s:=replace(s,'if k.durum = ''oylamada'' and t >= k.oy_bas and t < k.oy_bit then a := ''ilk'';','if k.durum = ''oylamada'' and t >= k.oy_bas and t < k.oy_bit then
    a := case when oyun.gercekci_siyaset() and k.tur=''anayasa'' and k.anayasa_tur=1 then ''ikinci'' else ''ilk'' end;');
    execute s;
  end if;
  s:=pg_get_functiondef('public.kanun_detay(bigint)'::regprocedure);
  if strpos(s,'''anayasa_tur'',k.anayasa_tur')=0 then
    if strpos(s,'case when k.durum=''israr'' then ''israr'' else ''ilk'' end')=0 then raise exception 'Kanun yamasi surum uyumsuz: public.kanun_detay(bigint'; end if;
    s:=replace(s,'case when k.durum=''israr'' then ''israr'' else ''ilk'' end','case when k.durum=''israr'' then ''israr'' when oyun.gercekci_siyaset() and k.tur=''anayasa'' and k.anayasa_tur=1 then ''ikinci'' else ''ilk'' end');
    if strpos(s,'case when k.durum = ''israr'' then ''israr'' else ''ilk'' end')=0 then raise exception 'Kanun yamasi surum uyumsuz: public.kanun_detay(bigint'; end if;
    s:=replace(s,'case when k.durum = ''israr'' then ''israr'' else ''ilk'' end','case when k.durum = ''israr'' then ''israr'' when oyun.gercekci_siyaset() and k.tur=''anayasa'' and k.anayasa_tur=1 then ''ikinci'' else ''ilk'' end');
    if strpos(s,'''gercekci'', oyun.gercekci_siyaset(), ''metin'',')=0 then raise exception 'Kanun yamasi surum uyumsuz: public.kanun_detay(bigint'; end if;
    s:=replace(s,'''gercekci'', oyun.gercekci_siyaset(), ''metin'',','''gercekci'', oyun.gercekci_siyaset(), ''anayasa_tur'',k.anayasa_tur, ''metin'',');
    if strpos(s,'k.tur = ''anayasa'' and o.asama = ''ilk''')=0 then raise exception 'Kanun yamasi surum uyumsuz: public.kanun_detay(bigint'; end if;
    s:=replace(s,'k.tur = ''anayasa'' and o.asama = ''ilk''','k.tur = ''anayasa'' and o.asama in (''ilk'',''ikinci'',''israr'')');
    execute s;
  end if;
  s:=pg_get_functiondef('oyun.kanun_ozet(oyun.kanunlar,oyun.profiller,timestamptz)'::regprocedure);
  if strpos(s,'''anayasa_tur'',k.anayasa_tur')=0 then
    if strpos(s,'''oy_verdim'', exists')=0 then raise exception 'Kanun yamasi surum uyumsuz: oyun.kanun_ozet(oyun.kanu'; end if;
    s:=replace(s,'''oy_verdim'', exists','''anayasa_tur'',k.anayasa_tur,''oy_verdim'', exists');
    if strpos(s,'case when k.durum = ''israr'' then ''israr'' else ''ilk'' end')=0 then raise exception 'Kanun yamasi surum uyumsuz: oyun.kanun_ozet(oyun.kanu'; end if;
    s:=replace(s,'case when k.durum = ''israr'' then ''israr'' else ''ilk'' end','case when k.durum = ''israr'' then ''israr'' when oyun.gercekci_siyaset() and k.tur=''anayasa'' and k.anayasa_tur=1 then ''ikinci'' else ''ilk'' end');
    execute s;
  end if;
  s:=pg_get_functiondef('public.kanun_cb_karar(bigint,text,text)'::regprocedure);
  if strpos(s,'and k.veto_gerekce is null')=0 then
    if strpos(s,'    if p_karar = ''onay'' then
      perform oyun.kanun_yururluk(k.id, t, format(''Meclis''''te üçte iki çoğunlukla kabul edildi; Cumhurbaşkanı %s yayımladı.'', p.kad));')=0 then raise exception 'Kanun yamasi surum uyumsuz: public.kanun_cb_karar(big'; end if;
    s:=replace(s,'    if p_karar = ''onay'' then
      perform oyun.kanun_yururluk(k.id, t, format(''Meclis''''te üçte iki çoğunlukla kabul edildi; Cumhurbaşkanı %s yayımladı.'', p.kad));','    if p_karar = ''onay'' then
      if oyun.gercekci_siyaset() and k.veto_gerekce is null and
       (select count(*) from oyun.kanun_oylari o where o.kanun_id=k.id and o.asama=case when k.anayasa_tur=1 then ''ikinci'' else ''ilk'' end and o.oy=''kabul'')<ceil(oyun.tbmm_tamsayi()*2/3.0)
      then
        perform oyun.referandum_baslat(k.id,t);
      else
        perform oyun.kanun_yururluk(k.id,t,format(''Anayasa değişikliği Cumhurbaşkanı %s tarafından yayımlandı.'',p.kad));
      end if;');
    execute s;
  end if;
end
$patch$;
