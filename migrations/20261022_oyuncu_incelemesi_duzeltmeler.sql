-- CANLIDA UYGULANDI: 2026-10-22, oyuncu_incelemesi_duzeltmeler_20261022 + rls_tamamla_20261022 (11. bölüm) + meclis_rehber_hizlandir_20261022 (12. bölüm)
-- 119 · Oyuncu gözüyle inceleme (2026-10-22): her çağrıda hata veren 9 sunucu fonksiyonunun düzeltmesi.
-- Oyuncu verisini DEĞİŞTİRMEZ, hiçbir şeyi sıfırlamaz; yalnızca fonksiyon tanımlarını onarır. İki kez çalıştırmak güvenlidir.
--  1) kriz_karar_ver            "maliyet" hem değişken hem sütun → ülke krizi kararı hiç verilemiyordu
--  2) oyb_kredi_basvur          RETURNING "toplam" belirsiz → oyuncu bankasından kredi başvurusu hep hata
--  3) oyb_icra_haciz_sec        "pay" belirsiz → banka icra haczi seçilemiyordu
--  4) icra_haczet               "pay" belirsiz → kredi alacağı için haciz yapılamıyordu
--  5) adliye_secim_itiraz_karar "gb" belirsiz → Yüksek Yargıç seçim itirazına karar veremiyordu
--  6) mv_ortak_liste_yanit      "gb" belirsiz → ortak MV listesi teklifi yanıtlanamıyordu
--  7) mv_ortak_liste_teklif     oyun.olay(il) tür uyuşmazlığı → ortak MV listesi teklif edilemiyordu
--  8) admin_transferler_sayfa   koşulsuz geçici tablo temizliği API'de reddediliyordu → yönetici "Transferler" sayfası açılmıyordu
--  9) oyun._sonuc_mv            aynı sebep → "Motoru şimdi çalıştır" ile genel seçim sonuçlandırılamıyordu
-- 10) akis_tepki düzeltmesi "delete" içerdiği için migrations/20261022_yonetici_kontrol_onayli.sql dosyasındadır.
-- Fonksiyon canlıdaki (veya bu kurulumdaki) son hâlinden okunur, yalnızca hatalı ifade değiştirilir.
do $duzelt$
declare r record; d text; adet int;
begin
  for r in select * from (values
    ('public.kriz_karar_ver', E'AS $function$\n', E'AS $function$\n#variable_conflict use_variable\n'),
    ('public.oyb_kredi_basvur', 'RETURNING id,oran,toplam INTO yeni_id,faiz,toplam',
                                'RETURNING oyb_kredi.id,oyb_kredi.oran,oyb_kredi.toplam INTO yeni_id,faiz,toplam'),
    ('public.oyb_icra_haciz_sec', 'WHERE sirket_id=d.banka_id AND user_id=auth.uid() AND pay>=50)',
                                  'WHERE sirket_id=d.banka_id AND user_id=auth.uid() AND sirket_ortaklari.pay>=50)'),
    ('public.icra_haczet', E'WHERE sirket_id=d.alacakli_sirket AND user_id=u AND pay>=50)',
                           E'WHERE sirket_id=d.alacakli_sirket AND user_id=u AND sirket_ortaklari.pay>=50)'),
    ('public.adliye_secim_itiraz_karar', 'select gb into gb from oyun.partiler where id=it.parti_id;',
                                         'select partiler.gb into gb from oyun.partiler where id=it.parti_id;'),
    ('public.mv_ortak_liste_yanit', 'where id=x.ortak_parti and gb=p.id and not kapali)',
                                    'where id=x.ortak_parti and partiler.gb=p.id and not kapali)'),
    ('public.mv_ortak_liste_yanit', 'select gb into gb from oyun.partiler where id=x.teklif_eden_parti;',
                                    'select partiler.gb into gb from oyun.partiler where id=x.teklif_eden_parti;'),
    ('public.mv_ortak_liste_teklif', 'ilan),p_il,pa.id,t);', 'ilan),p_il::smallint,pa.id,t);')
  ) v(fn, eski, yeni) loop
    if to_regproc(r.fn) is null then raise notice '% bu kurulumda yok, atlandı', r.fn; continue; end if;
    d := pg_get_functiondef(to_regproc(r.fn));
    if position(r.yeni in d) > 0 then raise notice '% zaten düzeltilmiş', r.fn; continue; end if;
    adet := (length(d) - length(replace(d, r.eski, ''))) / length(r.eski);
    if adet = 0 then raise notice '% bu kurulumda farklı yazılmış, atlandı: %', r.fn, r.eski; continue; end if;
    if adet > 1 then raise exception '% içinde ifade % kez geçiyor (1 olmalı): %', r.fn, adet, r.eski; end if;
    execute replace(d, r.eski, r.yeni);
  end loop;
end $duzelt$;

-- 8) Yönetici › Transferler: geçici tablo TRUNCATE ile boşaltılır (API'deki "WHERE'siz DELETE" korumasına takılmaz).
CREATE OR REPLACE FUNCTION public.admin_transferler_sayfa(p_limit integer DEFAULT 100, p_offset integer DEFAULT 0, p_ara text DEFAULT NULL::text, p_min numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p oyun.profiller:=oyun.yonetici_zorunlu();
  lim int:=least(greatest(coalesce(p_limit,100),1),250);
  off int:=greatest(coalesce(p_offset,0),0);
  ara text:=lower(btrim(coalesce(p_ara,'')));
  toplam int;
  satirlar jsonb;
begin
  create temp table if not exists _aktarim(id bigint, kanal text, gonderen uuid, alici uuid, tutar numeric, aciklama text, zaman timestamptz) on commit drop;
  truncate _aktarim;
  insert into _aktarim
    select bt.id,'havale',bt.gonderen,bt.alici,bt.tutar,bt.aciklama,bt.zaman from oyun.banka_transfer bt
    union all
    select sb.id,'hediye',sb.gonderen,sb.alici_id::uuid,sb.tutar,sb.aciklama,sb.zaman from oyun.serbest_bagis_kayit sb where sb.alici_tur='oyuncu';

  select count(*) into toplam
  from _aktarim bt
  join oyun.profiller gp on gp.id=bt.gonderen
  join oyun.profiller ap on ap.id=bt.alici
  where (ara='' or lower(gp.kad) like '%'||ara||'%' or lower(ap.kad) like '%'||ara||'%')
    and (p_min is null or bt.tutar>=p_min);

  select coalesce(jsonb_agg(jsonb_build_object(
      'id',t.id,'kanal',t.kanal,'zaman',t.zaman,'gonderen',g.kad,'alici',a.kad,'tutar',t.tutar,'aciklama',t.aciklama,
      'gonderen_olusturma',g.olusturma,'alici_olusturma',a.olusturma,
      'ikili_30gun',(select count(*) from _aktarim z
        where z.zaman>oyun.simdi()-interval '30 days'
          and ((z.gonderen=t.gonderen and z.alici=t.alici) or (z.gonderen=t.alici and z.alici=t.gonderen))),
      'ikili_tutar_30gun',(select coalesce(sum(z.tutar),0) from _aktarim z
        where z.zaman>oyun.simdi()-interval '30 days'
          and ((z.gonderen=t.gonderen and z.alici=t.alici) or (z.gonderen=t.alici and z.alici=t.gonderen))),
      'bagli_hesap',exists(select 1 from oyun.bagli_hesaplar(t.gonderen)b where b=t.alici)
    ) order by t.zaman desc,t.id desc),'[]'::jsonb)
  into satirlar
  from (
    select bt.* from _aktarim bt
    join oyun.profiller gp on gp.id=bt.gonderen
    join oyun.profiller ap on ap.id=bt.alici
    where (ara='' or lower(gp.kad) like '%'||ara||'%' or lower(ap.kad) like '%'||ara||'%')
      and (p_min is null or bt.tutar>=p_min)
    order by bt.zaman desc,bt.id desc
    limit lim offset off
  )t
  join oyun.profiller g on g.id=t.gonderen
  join oyun.profiller a on a.id=t.alici;

  return jsonb_build_object('toplam',toplam,'offset',off,'limit',lim,'satirlar',satirlar);
end $function$;

-- 9) Genel seçim (MV) sonucu: geçici tablolar TRUNCATE ile boşaltılır; hesaplama mantığı birebir aynıdır.
CREATE OR REPLACE FUNCTION oyun._sonuc_mv(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  baraj numeric:=(select baraj from oyun.ayarlar where id=1);
  onsecim oyun.secimler;
  toplam bigint;
  il record;
  l record;
  k int;
  ana bigint;
  iller_j jsonb:='{}'::jsonb;
  ilj jsonb;
  bos int:=0;
  dolu int:=0;
  sandalye_top int;
  bag_oy bigint;
  bag_sandalye int;
begin
  -- Geçici düşük oyuncu sayısı test modu: her kesinleşmiş aday seçilir.
  if exists (select 1 from oyun.mv_secim_modu where id = 1 and her_aday_vekil) then
    return oyun._sonuc_mv_test(s);
  end if;
  select * into onsecim from oyun.secimler where tur='mv_on' and donem=s.donem;
  select count(*) into toplam from oyun.oylar where secim_id=s.id;
  sandalye_top:=coalesce((select sum(mv_secim) from oyun.iller),600);

  create temp table if not exists _b23_ulusal(
    parti_id bigint primary key,
    oy bigint,
    yuzde numeric,
    gecti boolean,
    sandalye int default 0
  ) on commit drop;
  truncate _b23_ulusal;

  insert into _b23_ulusal(parti_id,oy)
  select parti_id,count(*)
  from oyun.oylar
  where secim_id=s.id and parti_id is not null
  group by parti_id;

  update _b23_ulusal
  set yuzde=case when toplam>0 then round(oy*100.0/toplam,2) else 0 end;

  update _b23_ulusal u
  set gecti=(coalesce(u.oy*100.0/nullif(toplam,0),0)>=baraj) or coalesce((
    select sum(u2.oy)*100.0/nullif(toplam,0)>=baraj
    from oyun.ittifak_uyeler iu
    join oyun.ittifak_uyeler iu2 on iu2.ittifak_id=iu.ittifak_id
    join _b23_ulusal u2 on u2.parti_id=iu2.parti_id
    where iu.parti_id=u.parti_id
  ),false);

  create temp table if not exists _b23_kaz(
    user_id uuid,
    il_id smallint,
    parti_id bigint,
    aday_id bigint
  ) on commit drop;
  truncate _b23_kaz;

  create temp table if not exists _b23_liste(
    anahtar bigint primary key,
    parti_id bigint,
    aday_id bigint,
    oy bigint,
    lim int,
    kaz int default 0
  ) on commit drop;

  for il in select * from oyun.iller order by id loop
    truncate _b23_liste;

    insert into _b23_liste(anahtar,parti_id,aday_id,oy,lim)
    select x.parti_id,x.parti_id,null,x.oy,x.lim
    from (
      select v.lider as parti_id,
             count(*)::bigint oy,
             (select count(*)
              from oyun.adaylar a
              where a.secim_id=onsecim.id
                and a.il_id=il.id
                and a.parti_id is not null
                and oyun.mv_ortak_liste_partisi(s.id,il.id,a.parti_id)=v.lider
                and a.sira is not null)::int lim
      from (
        select oyun.mv_ortak_liste_partisi(s.id,il.id,o.parti_id) as lider
        from oyun.oylar o
        join _b23_ulusal u on u.parti_id=o.parti_id and u.gecti
        where o.secim_id=s.id and o.il_id=il.id and o.parti_id is not null
      ) v
      group by v.lider
    ) x
    where x.lim>0 and x.oy>0;

    insert into _b23_liste(anahtar,parti_id,aday_id,oy,lim)
    select -a.id,null,a.id,count(o.*)::bigint,1
    from oyun.adaylar a
    join oyun.oylar o
      on o.secim_id=s.id and o.aday_id=a.id
    where a.secim_id=s.id
      and a.parti_id is null
      and a.il_id=il.id
    group by a.id
    having count(o.*)>0;

    for k in 1..coalesce(il.mv_secim,il.mv) loop
      ana:=null;
      select anahtar into ana
      from _b23_liste
      where kaz<lim and oy>0
      order by oy::numeric/(kaz+1) desc,oy desc,anahtar
      limit 1;
      exit when ana is null;
      update _b23_liste set kaz=kaz+1 where anahtar=ana;
    end loop;

    for l in select * from _b23_liste where parti_id is not null and kaz>0 loop
      insert into _b23_kaz(user_id,il_id,parti_id,aday_id)
      select a.user_id,il.id,a.parti_id,a.id
      from oyun.adaylar a
      where a.secim_id=onsecim.id
        and a.il_id=il.id
        and a.parti_id is not null
        and oyun.mv_ortak_liste_partisi(s.id,il.id,a.parti_id)=l.parti_id
        and a.sira is not null
      order by a.sira, case when a.parti_id=l.parti_id then 0 else 1 end, a.id
      limit l.kaz;
    end loop;

    insert into _b23_kaz(user_id,il_id,parti_id,aday_id)
    select a.user_id,il.id,null,a.id
    from _b23_liste bl
    join oyun.adaylar a on a.id=bl.aday_id
    where bl.parti_id is null and bl.kaz>0;

    select jsonb_build_object(
      'gecerli',(select count(*) from oyun.oylar where secim_id=s.id and il_id=il.id),
      'partiler',coalesce((
        select jsonb_object_agg(o.parti_id::text,jsonb_build_object(
          'oy',o.n,
          'sandalye',(select count(*) from _b23_kaz z where z.il_id=il.id and z.parti_id=o.parti_id)
        ))
        from (
          select parti_id,count(*) n
          from oyun.oylar
          where secim_id=s.id and il_id=il.id and parti_id is not null
          group by parti_id
        ) o
      ),'{}'::jsonb),
      'bagimsizlar',coalesce((
        select jsonb_agg(jsonb_build_object(
          'aday_id',a.id,
          'kad',pr.kad,
          'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
          'sandalye',case when exists(select 1 from _b23_kaz z where z.aday_id=a.id) then 1 else 0 end
        ) order by (select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id) desc,a.id)
        from oyun.adaylar a
        join oyun.profiller pr on pr.id=a.user_id
        where a.secim_id=s.id and a.parti_id is null and a.il_id=il.id
      ),'[]'::jsonb),
      'secilen',coalesce((
        select jsonb_agg(jsonb_build_object(
          'kad',pr.kad,
          'parti_id',z.parti_id,
          'bagimsiz',z.parti_id is null
        ) order by z.parti_id nulls last,pr.kad)
        from _b23_kaz z
        join oyun.profiller pr on pr.id=z.user_id
        where z.il_id=il.id
      ),'[]'::jsonb),
      'mv',coalesce(il.mv_secim,il.mv)
    ) into ilj;

    if (ilj->>'gecerli')::int>0 or jsonb_array_length(ilj->'secilen')>0 then
      iller_j:=iller_j||jsonb_build_object(il.id::text,ilj);
    end if;
  end loop;

  -- Sandalyeler liste sahibine değil, seçilen adayların kendi partilerine yazılır.
  update _b23_ulusal u set sandalye=(select count(*) from _b23_kaz z where z.parti_id=u.parti_id);

  insert into oyun.kazananlar(secim_id,user_id,il_id,parti_id)
  select s.id,user_id,il_id,parti_id from _b23_kaz
  on conflict do nothing;

  select count(*) into dolu from _b23_kaz;
  bos:=sandalye_top-dolu;
  select count(*) into bag_oy
  from oyun.oylar where secim_id=s.id and parti_id is null and aday_id is not null;
  select count(*) into bag_sandalye
  from _b23_kaz where parti_id is null;

  perform oyun.olay(
    'secim',
    format('Genel seçim sonuçlandı: %s oy kullanıldı, %s sandalye doldu, %s sandalye boş kaldı.',toplam,dolu,bos),
    null,null,s.sonuc_at
  );

  return jsonb_build_object(
    'toplam',toplam,
    'baraj',baraj,
    'sandalye_toplam',sandalye_top,
    'dolu',dolu,
    'bos',bos,
    'bagimsiz_oy',bag_oy,
    'bagimsiz_sandalye',bag_sandalye,
    'bagimsizlar',coalesce((
      select jsonb_agg(jsonb_build_object(
        'aday_id',a.id,
        'kad',pr.kad,
        'il_id',a.il_id,
        'oy',(select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id),
        'sandalye',case when exists(select 1 from _b23_kaz z where z.aday_id=a.id) then 1 else 0 end
      ) order by (select count(*) from oyun.oylar o where o.secim_id=s.id and o.aday_id=a.id) desc,a.id)
      from oyun.adaylar a
      join oyun.profiller pr on pr.id=a.user_id
      where a.secim_id=s.id and a.parti_id is null
    ),'[]'::jsonb),
    'ulusal',coalesce((
      select jsonb_agg(jsonb_build_object(
        'parti_id',u.parti_id,
        'kisa',p.kisa,
        'ad',p.ad,
        'renk',p.renk,
        'oy',u.oy,
        'yuzde',u.yuzde,
        'gecti',u.gecti,
        'sandalye',u.sandalye
      ) order by u.oy desc)
      from _b23_ulusal u
      join oyun.partiler p on p.id=u.parti_id
    ),'[]'::jsonb),
    'iller',iller_j
  );
end $function$;

-- 11) Güvenlik kemeri: sonradan eklenen 12 oyun tablosunda satır güvenliği (RLS) açılır. Oyuncu rolleri bu şemaya
--     zaten erişemiyor ve oyun fonksiyonları tablo sahibi olarak çalıştığı için davranış değişmez; yalnızca ek kat.
do $rls$
declare t text;
begin
  foreach t in array array['borsa_devre_kesici','borsa_fiyat_gecmis','borsa_fiyat_referans','borsa_gozetim_kayit',
    'borsa_supheli_islem','eko_sehir_musteri_limiti','magaza_hesap','oyb_hesap','oyb_hesap_bilgi','oyb_kredi_paket',
    'oyb_kredi_teklifi','oyuncu_hak'] loop
    if to_regclass('oyun.' || t) is not null then execute format('alter table oyun.%I enable row level security', t); end if;
  end loop;
end $rls$;

-- 12) Meclis rehberi (Meclis sekmesi, haritada sandalyeler): vekil başına grup başkanı yeniden hesaplanıyor ve görev
--     listesi il başına (81 kez) tekrar kuruluyordu. 426 vekilde 15 sn → 25 ms; çıktı birebir aynı.
CREATE OR REPLACE FUNCTION public.meclis_rehber()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with v as (
  select m.user_id, m.il_id, m.bas, m.parti_id as secildigi, pr.kad, pr.parti_id as parti
  from oyun.makamlar m
  join oyun.profiller pr on pr.id = m.user_id
  where m.tur = 'mv' and m.bit is null
),
sayi as (select count(*)::int as dolu from v),
g as (select * from oyun.gruplar()),
gbas as (select g.parti_id, oyun.grup_baskani(g.parti_id) as uid from g),
gorev as materialized (
  select v.user_id, jsonb_agg(x.g order by x.s) as liste
  from v
  join lateral (
    select 1 as s, 'TBMM Başkanı' as g
      where exists (select 1 from oyun.makamlar m where m.user_id = v.user_id and m.tur = 'tbmm' and m.bit is null)
    union all
    select 2, 'TBMM Başkanvekili'
      where exists (select 1 from oyun.makamlar m where m.user_id = v.user_id and m.tur = 'bskv' and m.bit is null)
    union all
    select 3, 'Genel Başkan'
      where exists (select 1 from oyun.partiler pa where pa.gb = v.user_id and not pa.kapali)
    union all
    select 3, 'Grup Başkanı'
      where exists (select 1 from gbas where gbas.parti_id = v.parti and gbas.uid = v.user_id)
    union all
    select 4, 'Grup Başkanvekili'
      where exists (select 1 from oyun.makamlar m where m.user_id = v.user_id and m.tur = 'grup_bskv' and m.bit is null)
    union all
    select 5, coalesce(b.ad, 'Bakan')
      from oyun.makamlar m left join oyun.bakanliklar b on b.kod = m.bakanlik
      where m.user_id = v.user_id and m.tur = 'bakan' and m.bit is null
    union all
    select 6, 'Genel Başkan Yardımcısı'
      where exists (select 1 from oyun.parti_gby y where y.user_id = v.user_id)
  ) x on true
  group by v.user_id
),
partiler as (
  select v.parti as id, count(*)::int as n from v where v.parti is not null group by v.parti
)
select jsonb_build_object(
  'toplam', coalesce((select sum(i.mv)::int from oyun.iller i), 600),
  'dolu', (select dolu from sayi),
  'bagimsiz', (select count(*)::int from v where v.parti is null),
  'cogunluk', (select dolu / 2 + 1 from sayi),
  'grup_esigi', oyun.grup_esigi((select dolu from sayi)),
  'baskan', (select jsonb_build_object('kad', oyun.kad(m.user_id), 'parti', oyun.parti_json(pr.parti_id))
             from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
             where m.tur = 'tbmm' and m.bit is null limit 1),
  'gecici', case when oyun.tbmm_baskani() is null then oyun.kad(oyun.gecici_baskan()) end,
  'baskanvekilleri', coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', oyun.parti_json(pr.parti_id)) order by m.bas)
             from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
             where m.tur = 'bskv' and m.bit is null), '[]'::jsonb),
  'partiler', coalesce((select jsonb_agg(oyun.parti_json(p.id) || jsonb_build_object(
        'n', p.n,
        'grup', g.parti_id is not null,
        'sira', g.sira,
        'gb', (select pr.kad from oyun.partiler pa join oyun.profiller pr on pr.id = pa.gb where pa.id = p.id),
        'gb_vekil', exists (select 1 from oyun.partiler pa join v on v.user_id = pa.gb where pa.id = p.id),
        'baskan', case when g.parti_id is not null then oyun.kad((select gbas.uid from gbas where gbas.parti_id = p.id)) end,
        'baskan_benim', g.parti_id is not null and (select gbas.uid from gbas where gbas.parti_id = p.id) = auth.uid(),
        'devir_adaylari', case when g.parti_id is not null and (select gbas.uid from gbas where gbas.parti_id = p.id) = auth.uid()
           then coalesce((select jsonb_agg(jsonb_build_object('id',pr.id,'kad',pr.kad) order by pr.kad)
             from oyun.profiller pr join oyun.makamlar mm on mm.user_id=pr.id and mm.tur='mv' and mm.bit is null
             where pr.parti_id=p.id and pr.id is distinct from (select gb from oyun.partiler where id=p.id)
                and pr.id<>auth.uid()),'[]'::jsonb)
           else '[]'::jsonb end,
        'bskv', coalesce((select jsonb_agg(pr.kad order by m.bas) from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
                          where m.tur = 'grup_bskv' and m.bit is null and m.parti_id = p.id), '[]'::jsonb),
        'bskv_kota', case when g.parti_id is null then 0 when p.n * 6 > (select dolu from sayi) then 3 else 2 end)
      order by p.n desc, p.id)
    from partiler p left join g on g.parti_id = p.id), '[]'::jsonb),
  'sozluk', coalesce((select jsonb_object_agg(x.id::text, oyun.parti_json(x.id))
    from (select parti as id from v where parti is not null union select secildigi from v where secildigi is not null) x), '{}'::jsonb),
  'iller', coalesce((select jsonb_agg(jsonb_build_object(
        'id', i.id, 'ad', i.ad, 'kontenjan', i.mv,
        'vekiller', coalesce((select jsonb_agg(jsonb_build_object(
              'kad', v.kad,
              'parti_id', v.parti,
              'secildigi_id', case when v.secildigi is distinct from v.parti then v.secildigi end,
              'bagimsiz_secildi', v.secildigi is null,
              'bas', v.bas,
              'gorevler', coalesce(gr.liste, '[]'::jsonb))
            order by v.parti nulls last, v.kad)
          from v left join gorev gr on gr.user_id = v.user_id where v.il_id = i.id), '[]'::jsonb))
      order by i.id)
    from oyun.iller i), '[]'::jsonb)
)
$function$;
