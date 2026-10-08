-- Genel başkan + milletvekili uyumunun seçim ve göreve başlama motorunda tamamlanması.
CREATE OR REPLACE FUNCTION oyun.goreve_baslat(p_sid bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare s oyun.secimler; k record; m record; t timestamptz; ilk oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_sid for update;
  if s.durum <> 'sonuclandi' then return; end if;
  t := s.goreve_bas;

  if s.tur = 'kurultay' then
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id and parti_id = k.parti_id);
      if (select gb from oyun.partiler where id = k.parti_id) is distinct from k.user_id then
        delete from oyun.parti_gby where parti_id = k.parti_id;   -- yeni genel başkan kendi ekibini kurar
      end if;
      delete from oyun.parti_gby where user_id = k.user_id;       -- genel başkan aynı zamanda yardımcı olamaz
      -- Yeni genel başkanın milletvekilliği ve cumhurbaşkanlığı kalır; diğer makamları sona erer
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null and tur not in ('cb','mv') loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      update oyun.partiler set gb = k.user_id where id = k.parti_id;
      perform oyun.bildir(k.user_id, format('Kurultayı kazandın: %s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilirsin.', (select ad from oyun.partiler where id = k.parti_id)), t);
    end loop;
    -- BOŞ MAKAM KURALI: kurultayda kimse aday olmadığı için genel başkansız kalan parti kıdemli üyesini genel başkan yapar
    perform oyun.gb_halef(t);
  elsif s.tur = 'cb' and coalesce((s.sonuc->>'ikinci_tur')::boolean, false) then
    null; -- 2. tur bekleniyor: görevdeki cumhurbaşkanı 2. tur sonucuna kadar devam eder
  else
    -- Milletvekilleri liste usulüyle seçilir: eski Meclis topluca biter. (Boş kalan sandalyeleri yedek listeler doldurur.)
    if s.tur = 'mv' then
      for m in select id from oyun.makamlar where tur = 'mv' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'donem_bitti');
      end loop;
    end if;
    -- BOŞ MAKAM KURALI: belediye başkanlığı ve cumhurbaşkanlığında eski görevli ancak yerine yenisi gerçekten başlayınca düşer.
    -- Seçimde aday çıkmadıysa (ya da kazanan göreve başlayamadıysa) görevdeki, yeni biri seçilene kadar görevine devam eder.
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id);   -- hesap silinmiş
      -- Genel başkan belediye başkanı olamaz; milletvekili olabilir (adaylığı zaten engellenir; yine de güvenceye al)
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) = 'bel'
         and exists (select 1 from oyun.partiler where gb = k.user_id) then
        perform oyun.bildir(k.user_id, 'Genel başkan olduğun için seçildiğin bu görevi üstlenemezsin.', t);
        if s.tur = 'mv' then perform oyun.yedek_getir(s.id, k.il_id, k.parti_id, t); end if;
        continue;
      end if;
      -- Yerine geçilen görevli (aynı ilin belediye başkanı / cumhurbaşkanı) görevi devreder
      if s.tur = 'bel' then
        for m in select id from oyun.makamlar where tur = 'bel' and il_id = k.il_id and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      elsif s.tur in ('cb','cb2') then
        for m in select id from oyun.makamlar where tur = 'cb' and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      end if;
      -- Milletvekili seçilen genel başkan partisini yönetmeye devam edebilir
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) in ('bel','cb') then
        delete from oyun.parti_gby where user_id = k.user_id;
      end if;
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, bas)
      values (case when s.tur = 'cb2' then 'cb' else s.tur end, k.user_id, k.il_id, k.parti_id, s.id, t);
      perform oyun.bildir(k.user_id, case when s.tur in ('cb','cb2') then 'Cumhurbaşkanı olarak göreve başladın. Kabineni kurmak için 12 bakanı atayabilirsin.'
        else format('%s olarak göreve başladın.', case s.tur when 'mv' then (select ad from oyun.iller where id = k.il_id) || ' Milletvekili'
                                                         else (select ad from oyun.iller where id = k.il_id) || ' Belediye Başkanı' end) end, t);
    end loop;
    -- Seçimde kimse kazanamadıysa görevde kalanlara haber ver
    if s.tur in ('cb','cb2') and not exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select user_id from oyun.makamlar where tur = 'cb' and bit is null loop
        perform oyun.bildir(m.user_id, 'Cumhurbaşkanlığı seçiminde yeni bir başkan çıkmadı; yeni cumhurbaşkanı seçilene kadar görevine devam ediyorsun.', t);
      end loop;
    end if;
    -- Yeni Meclis göreve başlayınca sonuçlanmamış kanun teklifleri kadük olur
    if s.tur = 'mv' then perform oyun.kanunlar_kaduk(t); end if;
    -- Yeni bir cumhurbaşkanlığı dönemi gerçekten başlayınca kabine yenilenir; seçimde kimse kazanamadıysa kabine yerinde kalır
    if s.tur in ('cb','cb2') and exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select id from oyun.makamlar where tur = 'bakan' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'kabine_yenilendi');
      end loop;
    end if;
  end if;
  update oyun.secimler set durum = 'tamam' where id = s.id;
end $function$
;

create or replace function oyun.gb_halef(t timestamptz) returns void language plpgsql as $$
declare pa record; aday uuid;
begin
  for pa in select id, ad from oyun.partiler where not kapali and gb is null loop
    select pr.id into aday from oyun.profiller pr
     where pr.parti_id = pa.id and not pr.yasakli
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur not in ('cb','mv'))
     order by oyun.kidem_puani(pr.id) desc, pr.parti_at, pr.id limit 1;
    continue when aday is null;
    delete from oyun.parti_gby where user_id = aday;       -- genel başkan aynı zamanda yardımcı olamaz
    update oyun.partiler set gb = aday where id = pa.id and gb is null;
    perform oyun.bildir(aday, format('%s kurultayda genel başkansız kaldığı için kıdemin en yüksek olduğu üye olarak genel başkan oldun. Bir sonraki kurultayda üyeler genel başkanı yeniden seçecek; 6 genel başkan yardımcını atayabilirsin.', pa.ad), t);
    perform oyun.olay('parti', format('%s genel başkansız kaldı; kıdemi en yüksek üye %s genel başkan oldu.', pa.ad, (select kad from oyun.profiller where id = aday)), null, pa.id, t);
  end loop;
end $$;
