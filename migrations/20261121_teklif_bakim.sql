-- Canlıya 21.11.2026'da Supabase migration'ı olarak uygulandı: bakan_teklif_zombi_teklif_kalici_duzeltme + takilan_kayitlar_kalici_bakim
-- Kaynak: gelistirici/sql/zz_20261121_teklif_bakim.sql · tekrar çalıştırmak güvenlidir.
begin;
set local lock_timeout = '5s';

-- 21.11.2026 · Takılan / geçersiz kalan bekleyen kayıtlar (canlı migration'lar:
--   bakan_teklif_zombi_teklif_kalici_duzeltme, takilan_kayitlar_kalici_bakim)
-- Olay: Cumhurbaşkanı istifa etmeden önce kendine bakanlık teklifi gönderdi; istifada teklif iptal edilmediği için
-- kimseye görünmeyen, yanıtlanamayan ama adayı kilitleyen kayıt kaldı. Aynı kalıp ("işareti koy, sonra hata fırlat"
-- → işaret geri alınır; süresiz bekleyen teklif) başka yerlerde de vardı.

-- (Yama yardımcısı oyun._yama: zz_20261121_00_yama.sql)

-- 1) Geçersiz bekleyen bakanlık tekliflerini iptal eden tek merkez
create or replace function oyun.bakan_teklif_temizle()
returns integer language plpgsql security definer set search_path to '' as $fn$
declare
  t timestamptz := oyun.simdi();
  y uuid := oyun.yurutme_user();
  r record;
  n integer := 0;
begin
  for r in
    update oyun.bakan_teklifleri bt
       set durum = 'iptal', yanit_at = t
     where bt.durum = 'bekliyor'
       and (bt.teklif_eden is distinct from y or bt.aday = bt.teklif_eden)
    returning bt.id, bt.aday, bt.teklif_eden, bt.bakanlik
  loop
    n := n + 1;
    if r.aday <> r.teklif_eden then
      perform oyun.bildir(r.aday,
        format('Hükümet değiştiği için sana yapılan %s teklifi geçersiz oldu.',
               (select b.ad from oyun.bakanliklar b where b.kod = r.bakanlik)), t);
    end if;
  end loop;
  return n;
end $fn$;
revoke all on function oyun.bakan_teklif_temizle() from public;
grant execute on function oyun.bakan_teklif_temizle() to service_role;

-- 2) Yürütme değişince otomatik temizlik (bakanlık + Merkez Bankası başkanlığı teklifleri)
create or replace function oyun.bakan_teklif_yurutme_degisti_tg()
returns trigger language plpgsql security definer set search_path to '' as $fn$
declare t timestamptz;
begin
  if tg_table_name = 'makamlar' and tg_op = 'UPDATE' then
    t := coalesce(new.bit, oyun.simdi());
    -- Yeniden seçilip kesintisiz devam eden Cumhurbaşkanının teklifleri geçerli kalır
    if new.bitis_neden = 'donem_bitti' and exists (
         select 1 from oyun.kazananlar k join oyun.secimler s on s.id = k.secim_id
          where s.tur in ('cb','cb2') and s.durum = 'sonuclandi' and k.user_id = new.user_id
            and s.goreve_bas is not null and s.goreve_bas <= t) then
      return null;
    end if;
  end if;
  begin
    perform oyun.bakan_teklif_temizle();
    update oyun.tcmb_teklifleri set durum = 'gecersiz'
     where durum = 'bekliyor' and teklif_eden is distinct from oyun.yurutme_user();
  exception when others then
    -- Temizlik hatası hiçbir zaman görev değişimini (seçim, istifa, atama) engellemesin
    raise warning 'teklif temizliği hata: %', sqlerrm;
  end;
  return null;
end $fn$;
revoke all on function oyun.bakan_teklif_yurutme_degisti_tg() from public;
grant execute on function oyun.bakan_teklif_yurutme_degisti_tg() to service_role;

drop trigger if exists bakan_teklif_cb_bitti on oyun.makamlar;
create trigger bakan_teklif_cb_bitti after update of "bit" on oyun.makamlar for each row
  when (old.tur = 'cb' and old."bit" is null and new."bit" is not null)
  execute function oyun.bakan_teklif_yurutme_degisti_tg();
drop trigger if exists bakan_teklif_cb_basladi on oyun.makamlar;
create trigger bakan_teklif_cb_basladi after insert on oyun.makamlar for each row
  when (new.tur = 'cb' and new."bit" is null)
  execute function oyun.bakan_teklif_yurutme_degisti_tg();
drop trigger if exists bakan_teklif_hukumet_degisti on oyun.hukumetler;
create trigger bakan_teklif_hukumet_degisti after insert or update or delete on oyun.hukumetler for each statement
  execute function oyun.bakan_teklif_yurutme_degisti_tg();
drop trigger if exists bakan_teklif_sistem_degisti on oyun.anayasa;
create trigger bakan_teklif_sistem_degisti after update on oyun.anayasa for each row
  when (new.kod = 'hukumet_sistemi' and old.deger is distinct from new.deger)
  execute function oyun.bakan_teklif_yurutme_degisti_tg();

-- 3) Tablo düzeyinde koruma: kendine teklif asla oluşamaz
create or replace function oyun.bakan_teklif_tek_kisi()
returns trigger language plpgsql set search_path to '' as $fn$
BEGIN
 IF NEW.durum='bekliyor' THEN
   IF NEW.aday = NEW.teklif_eden THEN
     RAISE EXCEPTION 'Kendine bakanlık teklif edemezsin.';
   END IF;
   IF EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.tur='bakan' AND m.bit IS NULL AND m.user_id=NEW.aday) THEN
     RAISE EXCEPTION 'Bu oyuncu zaten bakan. Aynı oyuncuya ikinci bakanlık teklif edilemez.';
   END IF;
   IF EXISTS(SELECT 1 FROM oyun.bakan_teklifleri b
      WHERE b.aday=NEW.aday AND b.durum='bekliyor' AND b.id IS DISTINCT FROM NEW.id AND b.bakanlik IS DISTINCT FROM NEW.bakanlik) THEN
     RAISE EXCEPTION 'Bu oyuncunun cevap bekleyen başka bir bakanlık teklifi var.';
   END IF;
 END IF;
 RETURN NEW;
END $fn$;

-- 4) Teklif gönderme: kendine teklif yasak + göndermeden önce geçersizleri temizle
create or replace function public.bakan_ata(p_bakanlik text, p_kad text)
returns jsonb language plpgsql security definer set search_path to '' as $fn$
declare
 p oyun.profiller := oyun.profilim();
 h oyun.profiller;
 b oyun.bakanliklar;
 t timestamptz := oyun.simdi();
 teklif_id bigint;
begin
 perform oyun.cb_zorunlu(p);
 select * into b from oyun.bakanliklar where kod=p_bakanlik;
 if b.kod is null then raise exception 'Bakanlık bulunamadı.'; end if;
 h := oyun.profil_bul(p_kad);
 if h.id = p.id then
   raise exception '% aynı anda bakan olamaz; kendine bakanlık teklif edemezsin.', oyun.yurutme_unvan();
 end if;
 if h.yasakli then raise exception 'Yasaklı hesaba teklif gönderilemez.'; end if;
 if exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik=b.kod and bit is null and user_id=h.id)
 then raise exception 'Oyuncu zaten bu bakanlıkta görev yapıyor.'; end if;
 -- Eski hükümetten kalan geçersiz teklifler yeni teklifi kilitlemesin
 perform oyun.bakan_teklif_temizle();
 insert into oyun.bakan_teklifleri(bakanlik,teklif_eden,aday,durum,zaman)
 values(b.kod,p.id,h.id,'bekliyor',t)
 on conflict (bakanlik,aday) where durum='bekliyor'
 do update set teklif_eden=excluded.teklif_eden, zaman=excluded.zaman
 returning id into teklif_id;
 perform oyun.bildir(h.id,format('%s %s, sana %s görevi teklif etti. Bildirimler bölümünden kabul edebilir veya reddedebilirsin. Mevcut görevlerin korunacak.',oyun.yurutme_unvan(),p.kad,b.ad),t);
 return jsonb_build_object('durum','bekliyor','teklif_id',teklif_id,'bakanlik',b.ad,'aday',h.kad);
end $fn$;

-- 5) Aday listesi: yalnız görevdeki yürütmenin teklifleri "bekleyen teklif" sayılır; kendisi seçilemez
create or replace function public.bakan_adaylari(p_ara text default ''::text)
returns jsonb language plpgsql security definer set search_path to '' as $fn$
declare p oyun.profiller := oyun.profilim(); a text := lower(btrim(coalesce(p_ara,'')));
begin
 perform oyun.cb_zorunlu(p);
 return coalesce((
 select jsonb_agg(x order by (x->>'kidem')::numeric desc) from (
   select jsonb_build_object(
     'kad',pr.kad,'il',(select ad from oyun.iller where id=pr.il_id),
     'parti',oyun.parti_json(pr.parti_id),
     'kidem',oyun.kidem_puani(pr.id),
     'statu',oyun.statu_ad(oyun.statu_basamak(oyun.kidem_puani(pr.id))),
     'gorev',null,
     'bakanlik',(select b.ad from oyun.makamlar m join oyun.bakanliklar b on b.kod=m.bakanlik
       where m.user_id=pr.id and m.tur='bakan' and m.bit is null limit 1),
     'uygun',
     pr.id <> p.id
     AND NOT EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.user_id=pr.id AND m.tur='bakan' AND m.bit IS NULL)
     AND NOT EXISTS(SELECT 1 FROM oyun.bakan_teklifleri bt WHERE bt.aday=pr.id AND bt.durum='bekliyor' AND bt.teklif_eden=p.id),
     'engel',CASE
       WHEN pr.id = p.id
         THEN 'Kendine bakanlık teklif edemezsin'
       WHEN EXISTS(SELECT 1 FROM oyun.makamlar m WHERE m.user_id=pr.id AND m.tur='bakan' AND m.bit IS NULL)
         THEN 'Zaten bir bakanlıkta görev yapıyor'
       WHEN EXISTS(SELECT 1 FROM oyun.bakan_teklifleri bt WHERE bt.aday=pr.id AND bt.durum='bekliyor' AND bt.teklif_eden=p.id)
         THEN 'Cevap bekleyen başka bakanlık teklifi var'
       ELSE NULL END
   ) x
   from oyun.profiller pr
   where not pr.yasakli
     and (a='' or lower(pr.kad) like a||'%' or lower(pr.kad) like '%'||a||'%')
   order by (lower(pr.kad) like a||'%') desc,pr.son_gorulme desc nulls last
   limit 25
 ) q),'[]'::jsonb);
end $fn$;

select oyun.bakan_teklif_temizle();
alter table oyun.bakan_teklifleri drop constraint if exists bakan_teklifleri_kendine_teklif_yok;
alter table oyun.bakan_teklifleri add constraint bakan_teklifleri_kendine_teklif_yok
  check (durum <> 'bekliyor' or aday <> teklif_eden);

-- 6) "İşareti koy, sonra hata fırlat" yamaları
-- Borsa: payı yetmeyen satış emri gerçekten iptal edilsin
select oyun._yama('public.borsa_al(bigint,numeric)',
  $re$update\s+oyun\.borsa_emir\s+set\s+durum\s*=\s*'iptal'\s+where\s+id\s*=\s*e\.id;\s*raise\s+exception\s+'Satıcının payı artık yetmiyor; emir iptal edildi\.';$re$,
  $new$update oyun.borsa_emir set durum = 'iptal' where id = e.id;
    perform oyun.bildir(e.satici, format('Borsa: %s şirketindeki %%%s paylık satış emrin, elindeki pay yetmediği için iptal edildi.', s.ad, e.kalan), t);
    perform oyun.bildir(p.id, format('Borsa: %s için seçtiğin satış emri geçersizdi (satıcının payı yetmiyor). Emir tahtadan kaldırıldı; alım yapılmadı, paran çekilmedi.', s.ad), t);
    return public.borsa_sirket(s.id);$new$,
  'Emir tahtadan kaldırıldı');
-- Merkez Bankası başkanlığı teklifi: geçersiz işareti kalıcı olsun
select oyun._yama('public.tcmb_teklif_yanit(bigint,boolean)',
  $re$update\s+oyun\.tcmb_teklifleri\s+set\s+durum\s*=\s*'gecersiz'\s+where\s+id\s*=\s*k\.id;\s*raise\s+exception\s+'Teklifi yapan kişi artık yürütmenin başında değil; teklif geçersiz\.';$re$,
  $new$update oyun.tcmb_teklifleri set durum='gecersiz' where id=k.id;
    perform oyun.bildir(p.id, 'Merkez Bankası Başkanlığı teklifi geçersiz: teklifi yapan kişi artık yürütmenin başında değil.', t);
    return public.merkez_bankasi();$new$,
  'Başkanlığı teklifi geçersiz: teklifi yapan');
-- İçişleri kamu anlaşması: süresi geçmiş teklif/kabul artık oyuncuyu kilitlemesin
select oyun._yama('public.icisleri_anlasma_teklif(uuid,text,bigint,text,text)',
  $re$WHERE\s+oyuncu\s*=\s*p_oyuncu\s+AND\s+durum\s+IN\s*\(\s*'teklif'\s*,\s*'kabul'\s*,\s*'tamamlandi'\s*\)$re$,
  $new$WHERE oyuncu=p_oyuncu AND ((durum='teklif' AND olusturma>=t-interval '48 hours') OR (durum='kabul' AND cevap_at>=t-interval '72 hours') OR durum='tamamlandi')$new$,
  'cevap_at>=t-interval');

-- 7) Ortak bakım adımı: geçersiz / süresi dolmuş bekleyen kayıtları kapatır (10 dakikada bir)
create or replace function oyun.teklif_bakim()
returns integer language plpgsql security definer set search_path to '' as $fn$
declare
  t timestamptz := oyun.simdi();
  r record;
  c integer;
  n integer := 0;
begin
  -- Bakanlık teklifleri: geçersiz kalanlar + 72 saat yanıtsız kalanlar
  begin
    n := n + oyun.bakan_teklif_temizle();
    for r in
      update oyun.bakan_teklifleri bt set durum = 'iptal', yanit_at = t
       where bt.durum = 'bekliyor' and bt.zaman < t - interval '72 hours'
      returning bt.aday, bt.teklif_eden, bt.bakanlik
    loop
      n := n + 1;
      perform oyun.bildir(r.aday, format('%s teklifi 72 saat içinde yanıtlanmadığı için düştü.',
        (select b.ad from oyun.bakanliklar b where b.kod = r.bakanlik)), t);
      perform oyun.bildir(r.teklif_eden, format('%s, %s teklifini 72 saat içinde yanıtlamadı; teklif düştü. Dilersen yeniden teklif gönderebilirsin.',
        oyun.kad(r.aday), (select b.ad from oyun.bakanliklar b where b.kod = r.bakanlik)), t);
    end loop;
  exception when others then
    perform oyun.tick_hata_yaz('teklif_bakim: bakan', sqlerrm, null);
  end;

  -- Merkez Bankası başkanlığı: eski yürütmenin teklifleri
  begin
    for r in
      update oyun.tcmb_teklifleri k set durum = 'gecersiz'
       where k.durum = 'bekliyor' and k.teklif_eden is distinct from oyun.yurutme_user()
      returning k.aday
    loop
      n := n + 1;
      perform oyun.bildir(r.aday, 'Merkez Bankası Başkanlığı teklifi geçersiz oldu: teklifi yapan kişi artık yürütmenin başında değil.', t);
    end loop;
  exception when others then
    perform oyun.tick_hata_yaz('teklif_bakim: tcmb', sqlerrm, null);
  end;

  -- Oyuncu bankası kredi teklifleri: süresi dolanlar
  begin
    update oyun.oyb_kredi_teklifi set durum = 'suresi' where durum = 'teklif' and son <= t;
    get diagnostics c = row_count; n := n + c;
  exception when others then
    perform oyun.tick_hata_yaz('teklif_bakim: oyb_kredi', sqlerrm, null);
  end;

  -- Kamu kurumu atama teklifleri: 24 saatte yanıtlanmayanlar
  begin
    update oyun.kamu_kurum_atama set durum = 'suresi_doldu', yanit_at = t
     where durum = 'teklif' and teklif_at < t - interval '24 hours';
    get diagnostics c = row_count; n := n + c;
  exception when others then
    perform oyun.tick_hata_yaz('teklif_bakim: kamu_kurum', sqlerrm, null);
  end;

  -- İçişleri kamu hizmeti anlaşmaları: 48 saatte yanıtlanmayan teklif, 72 saatte raporlanmayan kabul
  begin
    for r in
      update oyun.icisleri_anlasma_v2 a set durum = 'suresi_doldu', karar_at = t
       where (a.durum = 'teklif' and a.olusturma < t - interval '48 hours')
          or (a.durum = 'kabul' and a.cevap_at < t - interval '72 hours')
      returning a.id, a.bakan, a.oyuncu
    loop
      n := n + 1;
      perform oyun.bildir(r.oyuncu, format('Kamu hizmeti anlaşması #%s süresi içinde tamamlanmadığı için düştü.', r.id), t);
      perform oyun.bildir(r.bakan, format('Kamu hizmeti anlaşması #%s süresi içinde yanıtlanmadığı ya da raporlanmadığı için düştü.', r.id), t);
    end loop;
  exception when others then
    perform oyun.tick_hata_yaz('teklif_bakim: icisleri_anlasma', sqlerrm, null);
  end;

  -- Hükümet kurma daveti (parlamenter sistem): 48 saatte yanıtlanmayan davet başarısız sayılır
  begin
    for r in
      update oyun.hukumetler h set durum = 'basarisiz', bit = t,
             bitis_neden = 'Davetler 48 saat içinde yanıtlanmadı'
       where h.durum = 'davet' and h.teklif_at < t - interval '48 hours'
      returning h.id, h.kuran_parti
    loop
      n := n + 1;
      perform oyun.olay('hukumet', 'Hükümet kurma girişimi düştü: davet edilen partiler 48 saat içinde yanıt vermedi. Yeni görüşmeler başlayabilir.', null, r.kuran_parti, t);
    end loop;
  exception when others then
    perform oyun.tick_hata_yaz('teklif_bakim: hukumet_davet', sqlerrm, null);
  end;

  -- Borsa: satıcısının elindeki paydan büyük kalan açık satış emirleri
  begin
    for r in
      update oyun.borsa_emir e set durum = 'iptal'
       where e.durum = 'acik'
         and e.kalan > coalesce((select o.pay from oyun.sirket_ortaklari o
                                  where o.sirket_id = e.sirket_id and o.user_id = e.satici), 0)
      returning e.satici, e.sirket_id, e.kalan
    loop
      n := n + 1;
      perform oyun.bildir(r.satici, format('Borsa: %s şirketindeki %%%s paylık satış emrin, elindeki pay yetmediği için iptal edildi.',
        (select s.ad from oyun.sirketler s where s.id = r.sirket_id), r.kalan), t);
    end loop;
  exception when others then
    perform oyun.tick_hata_yaz('teklif_bakim: borsa', sqlerrm, null);
  end;

  return n;
end $fn$;
revoke all on function oyun.teklif_bakim() from public;
grant execute on function oyun.teklif_bakim() to service_role;

insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif)
values ('teklif_bakim', 'select oyun.teklif_bakim()', 10, 6, 12, true)
on conflict (adim) do update set komut = excluded.komut, periyot_dk = excluded.periyot_dk,
  ofset_dk = excluded.ofset_dk, sira = excluded.sira, aktif = true;

commit;
