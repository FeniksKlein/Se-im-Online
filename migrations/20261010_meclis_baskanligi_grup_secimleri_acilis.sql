-- 10 Ekim 2026: Mevcut gecici milletvekilleri icin ilk TBMM ve parti grubu secimlerini baslat.
-- Hicbir oyuncunun makami, bakiyesi, partisinin konumu veya secim takvimi degistirilmez.
-- Sonraki genel secimler icin mevcut oyun.meclis_donem_baslat / oyun.meclis_tick kullanilir.
begin;
do $acilis$
declare
  t timestamptz := oyun.simdi();
  dolu int := oyun.dolu_sandalye();
  g record;
  acilan int := 0;
begin
  if dolu = 0 then
    raise notice 'Aktif milletvekili bulunmuyor; secim acilmadi.';
    return;
  end if;
  -- TBMM Baskanligi: tum aktif milletvekilleri aday olabilir ve gizli oy kullanir.
  if not exists (select 1 from oyun.makamlar where tur = 'tbmm' and bit is null)
     and not exists (select 1 from oyun.meclis_secim where tur = 'baskan' and durum <> 'bitti') then
    insert into oyun.meclis_secim (mv_secim_id, tur, olusturma, aday_bit)
    values (null, 'baskan', t, t + interval '8 hours');
    acilan := acilan + 1;
  end if;

  -- Meclis grubu olusturabilen partilerin kendi vekilleri arasinda oylama.
  for g in select * from oyun.gruplar() loop
    if not exists (select 1 from oyun.meclis_secim where tur='grup' and parti_id=g.parti_id and durum <> 'bitti')
       and not exists (select 1 from oyun.makamlar where tur='grup_bskv' and parti_id=g.parti_id and bit is null) then
      insert into oyun.meclis_secim
        (mv_secim_id,tur,parti_id,olusturma,aday_bit,oy_bit,bskv_hakki,grup_bskv_sayi)
      values
        (null,'grup',g.parti_id,t,t + interval '8 hours',t + interval '20 hours',
         g.sira <= 3,case when g.vekil * 6 > dolu then 3 else 2 end);
      acilan := acilan + 1;
    end if;
  end loop;

  if acilan > 0 then
    insert into oyun.bildirimler(user_id,zaman,metin)
    select distinct m.user_id,t,
      'TBMM Baskanligi ve parti grubu baskanvekilleri secimi acildi! Devlet > Meclis bolumunden aday ol ve oy kullan.'
    from oyun.makamlar m where m.tur='mv' and m.bit is null;
    perform oyun.olay('meclis',
      'TBMM Baskanligi ve Meclis parti gruplari icin secim basladi. Milletvekilleri Devlet > Meclis ekranindan aday olabilir.',
      null,null,t);
  end if;
end
$acilis$;
commit;
