-- TBMM turlarında eşzamanlı otomatik sayaç/sayım güvenliği
begin;
create or replace function oyun.meclis_tick(t timestamptz) returns void language plpgsql as $
declare s oyun.meclis_secim; ms oyun.secimler; r record; dolu int; gerek int; ust record; ikinci uuid; n int; dongu int; m record; pk text;
begin
  -- Zamanlayıcı ve eşzamanlı milletvekili oturumları aynı turu iki kez sonuçlandıramaz.
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
      update oyun.meclis_secim set durum = 'oylama', tur_no = 1, tur_bas = aday_bit + interval '30 minutes', tur_bit = aday_bit + interval '2 hours' where id = s.id;
      insert into oyun.bildirimler(user_id, zaman, metin)
        select x.user_id, s.aday_bit, 'TBMM Başkanlığı adaylığı bitti. 1. tur 30 dakika sonra başlayacak; gizli oy pusulan Devlet › Meclis ekranında.'
        from oyun.makamlar x where x.tur = 'mv' and x.bit is null;
      select * into s from oyun.meclis_secim where id = s.id;
    end if;
    dongu := 0;
    while s.durum = 'oylama' and t >= s.tur_bit and dongu < 5 loop
      dongu := dongu + 1;
      dolu := oyun.dolu_sandalye();
      gerek := case when s.tur_no <= 2 then 400 when s.tur_no = 3 then 301 else 0 end;
      select * into ust from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) limit 1;
      update oyun.meclis_secim set turlar = turlar || jsonb_build_array(jsonb_build_object('tur', s.tur_no, 'gerek', gerek, 'katilim',
          (select count(*) from oyun.meclis_oy where secim_id = s.id and tur_no = s.tur_no and gorev = 'baskan'),
          'sonuc', (select jsonb_agg(jsonb_build_object('kad', oyun.kad(x.user_id), 'oy', x.oy)) from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x)))
        where id = s.id;
      -- Dördüncü turda yalnız en çok oy alan iki aday yarışır; eşitlikte seçilmiş ilan edilmez.
      -- Eşitlik oluşursa 15 dakika sonra 90 dakikalık yeni bir nihai oylama açılır.
      select x.oy into n from oyun.meclis_sayim(s.id, s.tur_no, 'baskan') x
        where oyun.aktif_vekil(x.user_id) offset 1 limit 1;
      if ust.user_id is not null and ((s.tur_no < 4 and ust.oy >= gerek)
         or (s.tur_no >= 4 and ust.oy > 0 and ust.oy > coalesce(n, -1))) then
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
        update oyun.meclis_secim set tur_no = tur_no + 1, tur_bas = tur_bit + interval '15 minutes', tur_bit = tur_bit + interval '105 minutes' where id = s.id;
        perform oyun.olay('meclis', format('TBMM Başkanlığı seçiminin %s. turunda başkan seçilemedi; %s. tur oylaması 15 dakika sonra başlayacak.', s.tur_no, s.tur_no + 1), null, null, s.tur_bit);
        insert into oyun.bildirimler(user_id, zaman, metin)
        select distinct x.user_id, s.tur_bit,
          format('TBMM Başkanlığı %s. tur oylaması %s saatinde açılacak ve 90 dakika açık kalacak.',
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
end $$;
commit;
