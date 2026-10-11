-- Genel seçim sonrası 13 Ekim Meclis Başkanı takvimi ve her dakika Yüksek Mahkeme sandığı geçişi.
CREATE OR REPLACE FUNCTION oyun.meclis_donem_baslat(p_mv bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare m record; g record; dolu int := oyun.dolu_sandalye(); gb uuid;
begin
  for m in select id from oyun.makamlar where tur in ('tbmm','bskv','grup_bskv') and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'donem_bitti');
  end loop;
  update oyun.meclis_secim set durum = 'bitti', sonuc = coalesce(sonuc, 'Yasama dönemi sona erdi.') where durum <> 'bitti';
  insert into oyun.meclis_secim(mv_secim_id, tur, olusturma, aday_bit) values (p_mv, 'baskan', t,
 case when exists(select 1 from oyun.secimler g where g.id=p_mv and g.tur='mv' and
  (g.oy_bas at time zone 'Europe/Istanbul')::date=date '2026-10-12')
 then greatest(t + interval '30 minutes',oyun.tr_an(date '2026-10-13',9))
 else t + interval '24 hours' end);
  for g in select * from oyun.gruplar() loop
    insert into oyun.meclis_secim(mv_secim_id, tur, parti_id, olusturma, aday_bit, oy_bit, bskv_hakki, grup_bskv_sayi)
    values (p_mv, 'grup', g.parti_id, t, t + interval '24 hours', t + interval '36 hours', g.sira <= 3, case when g.vekil * 6 > dolu then 3 else 2 end);
  end loop;
  gb := oyun.gecici_baskan();
  perform oyun.olay('meclis', format('Yeni yasama dönemi başladı. Geçici Başkan %s. TBMM Başkanlığı ve grup başkanvekilliği adaylıkları 24 saat açık.', coalesce(oyun.kad(gb), '—')), null, null, t);
  insert into oyun.bildirimler(user_id, zaman, metin)
    select x.user_id, t, 'Yeni yasama dönemi: TBMM Başkanlığına ve partinin grup görevlerine 24 saat içinde aday olabilirsin (Devlet › Meclis).'
    from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
end $function$

CREATE OR REPLACE FUNCTION oyun.tick()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare t timestamptz:=oyun.simdi(); ay date; r record; n int:=0;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay:=date_trunc('month',t at time zone 'Europe/Istanbul')::date;
  perform oyun.donem_olustur(ay); perform oyun.donem_olustur((ay+interval '1 month')::date);
  if (select son_temizlik from oyun.ayarlar where id=1) is distinct from (t at time zone 'Europe/Istanbul')::date then
    delete from oyun.mesajlar where zaman<t-interval '30 days'; delete from oyun.yayinlar where zaman<t-interval '30 days'; delete from oyun.bildirimler where zaman<t-interval '60 days';
    delete from oyun.ozel where zaman<t-interval '90 days'; delete from oyun.push_kuyruk where olusturma<now()-interval '7 days';
    update oyun.ayarlar set son_temizlik=(t at time zone 'Europe/Istanbul')::date where id=1;
  end if;
  loop
    select * into r from (
      select id,sonuc_at as zaman,0 as asama,oyun.oncelik(tur)o from oyun.secimler where durum='bekliyor' and sonuc_at<=t
      union all select id,goreve_bas,1,oyun.oncelik(tur) from oyun.secimler where durum='sonuclandi' and goreve_bas<=t
    )x order by zaman,asama,o limit 1;
    exit when not found;
    if r.asama=0 then perform oyun.sonuclandir(r.id); else perform oyun.goreve_baslat(r.id); end if;
    n:=n+1; exit when n>200;
  end loop;
  perform oyun.kanun_tick(t); perform oyun.mevzuat_tick(t); perform oyun.meclis_tick(t); perform oyun.mahkeme_toplu_tick(t); perform oyun.parti_tuzuk_tick(t); perform oyun.siyasi_tick(t);
  perform oyun.guvenlik_tick(t); perform oyun.gunluk_ekonomi(t); perform oyun.banka_tick(t); perform oyun.meclis_olcek_uygula(t); perform oyun.ihmal_tick(t); perform oyun.miting_tick(t);
  perform oyun.push_hatirlatmalar(t); perform oyun.push_tetikle();
  return n;
end $function$

