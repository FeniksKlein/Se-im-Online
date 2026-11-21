-- 21.11.2026 · Cumhurbaşkanına vekâlet (canlı migration: cumhurbaskanina_vekalet_anayasa_106)
-- Anayasa m.106: Cumhurbaşkanlığı makamı boşalırsa yenisi göreve başlayana kadar Cumhurbaşkanı yardımcısı vekâlet eder
-- ve Cumhurbaşkanına ait yetkileri kullanır. Oyunda sıra: 1. yardımcı → 2. yardımcı → TBMM Başkanı.
-- Eskiden istifada yardımcılar da düşüyor, yürütme boş kalıyordu.
-- Vekil, makamlar tablosunda tur='cb', kaynak='vekalet' satırıyla tutulur: bütün Cumhurbaşkanı yetki denetimleri
-- (116 işlev) kendiliğinden çalışır. Korunacak işaretler: kaynak='vekalet', 'vekalet_bitti', cb_vekil_adayi.
alter table oyun.makamlar drop constraint if exists makamlar_kaynak_check;
alter table oyun.makamlar add constraint makamlar_kaynak_check
  check (kaynak = any (array['secim'::text,'yedek'::text,'atama'::text,'vekalet'::text]));

create or replace function oyun.cb_vekil_adayi()
returns uuid language sql stable set search_path to '' as $fn$
  select x.user_id from (
    select m.user_id,
           case when m.tur = 'cb_yardimcisi' then m.bakanlik::int else 9 end as oncelik
      from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
     where m.bit is null and m.tur in ('cb_yardimcisi','tbmm')
       and not coalesce(p.yasakli, false)
  ) x order by x.oncelik limit 1
$fn$;

-- Tutarlılık denetimi: işlem sonunda (commit anında) çalışır
create or replace function oyun.cb_vekalet_denetle()
returns void language plpgsql security definer set search_path to '' as $fn$
declare
  t timestamptz := oyun.simdi();
  v record;
  aday uuid;
  mevcut uuid;
  unvan text;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('cb_vekalet'));

  -- 1) Parlamenter sistemde ya da seçilmiş/atanmış bir Cumhurbaşkanı varken vekâlet olmaz
  if oyun.hukumet_sistemi() <> 0
     or exists (select 1 from oyun.makamlar where tur = 'cb' and bit is null and kaynak is distinct from 'vekalet') then
    for v in select id, user_id from oyun.makamlar where tur = 'cb' and bit is null and kaynak = 'vekalet' loop
      perform oyun.makam_bitir(v.id, t, 'vekalet_bitti');
      perform oyun.bildir(v.user_id, 'Cumhurbaşkanı göreve başladığı için Cumhurbaşkanlığına vekâlet görevin sona erdi.', t);
    end loop;
    return;
  end if;

  -- 2) Makam boş: vekil, vekâlete esas görevini sürdürdükçe değişmez
  for v in select m.id, m.user_id from oyun.makamlar m
            where m.tur = 'cb' and m.bit is null and m.kaynak = 'vekalet' order by m.bas, m.id loop
    if mevcut is null and exists (
         select 1 from oyun.makamlar q join oyun.profiller p on p.id = q.user_id
          where q.user_id = v.user_id and q.bit is null and q.tur in ('cb_yardimcisi','tbmm')
            and not coalesce(p.yasakli, false)) then
      mevcut := v.user_id;
    else
      perform oyun.makam_bitir(v.id, t, 'vekalet_bitti');
      perform oyun.bildir(v.user_id, 'Vekâlete esas görevin sona erdiği için Cumhurbaşkanlığına vekâletin de sona erdi.', t);
    end if;
  end loop;
  if mevcut is not null then return; end if;

  -- 3) Vekil yok: sıradaki göreve gelir
  aday := oyun.cb_vekil_adayi();
  if aday is null then return; end if;
  select case when m.tur = 'tbmm' then 'TBMM Başkanı' else m.bakanlik || '. Cumhurbaşkanı Yardımcısı' end
    into unvan
    from oyun.makamlar m
   where m.user_id = aday and m.bit is null and m.tur in ('cb_yardimcisi','tbmm')
   order by case when m.tur = 'cb_yardimcisi' then 0 else 1 end limit 1;

  insert into oyun.makamlar(tur, user_id, il_id, parti_id, bakanlik, kaynak, bas)
  values ('cb', aday, null, (select parti_id from oyun.profiller where id = aday), null, 'vekalet', t);

  perform oyun.bildir(aday, 'Cumhurbaşkanlığı makamı boşaldı. Anayasa m.106 gereği yeni Cumhurbaşkanı göreve başlayana kadar Cumhurbaşkanına vekâlet ediyor ve Cumhurbaşkanına ait yetkileri kullanıyorsun.', t);
  perform oyun.olay('makam', format('Cumhurbaşkanlığı makamı boş. %s %s, yeni Cumhurbaşkanı göreve başlayana kadar Cumhurbaşkanına vekâlet ediyor (Anayasa m.106).', unvan, oyun.kad(aday)), null, null, t);
end $fn$;
revoke all on function oyun.cb_vekalet_denetle() from public;
grant execute on function oyun.cb_vekalet_denetle() to service_role;

create or replace function oyun.cb_vekalet_denetle_tg()
returns trigger language plpgsql security definer set search_path to '' as $fn$
begin
  begin
    perform oyun.cb_vekalet_denetle();
  exception when others then
    -- Vekâlet denetimindeki bir hata hiçbir görev değişimini (istifa, seçim, atama) engellemesin
    begin
      perform oyun.tick_hata_yaz('cb_vekalet_denetle', sqlerrm, null);
    exception when others then null;
    end;
  end;
  return null;
end $fn$;
revoke all on function oyun.cb_vekalet_denetle_tg() from public;
grant execute on function oyun.cb_vekalet_denetle_tg() to service_role;

drop trigger if exists cb_vekalet_denetle_bit on oyun.makamlar;
create constraint trigger cb_vekalet_denetle_bit
  after update of "bit" on oyun.makamlar
  deferrable initially deferred
  for each row
  when (old.tur in ('cb','cb_yardimcisi','tbmm') and old."bit" is null and new."bit" is not null)
  execute function oyun.cb_vekalet_denetle_tg();
drop trigger if exists cb_vekalet_denetle_ins on oyun.makamlar;
create constraint trigger cb_vekalet_denetle_ins
  after insert on oyun.makamlar
  deferrable initially deferred
  for each row
  when (new.tur in ('cb','cb_yardimcisi','tbmm') and new."bit" is null)
  execute function oyun.cb_vekalet_denetle_tg();

-- Makam boşalınca yardımcılar görevde kalır; yalnız yeni Cumhurbaşkanı göreve başladığında (donem_bitti) düşerler
select oyun._yama('oyun.cb_yardimcisi_cb_degisti_tg()',
  $re$(for\s+m\s+in\s+select\s+id\s+from\s+oyun\.makamlar\s+where\s+tur\s*=\s*'cb_yardimcisi'\s+and\s+bit\s+is\s+null\s+loop\s+perform\s+oyun\.makam_bitir\(m\.id,\s*t,\s*'kabine_yenilendi'\);\s*end\s+loop;)$re$,
  $new$if oyun.hukumet_sistemi() <> 0 or new.bitis_neden = 'donem_bitti' then
    \1
  end if;$new$,
  'or new.bitis_neden = ''donem_bitti'' then');
-- Vekâlet eden kişinin esas görevi bağdaşmazlıktan düşmesin
select oyun._yama('oyun_yonetim.makam_bagdasmazlik_tg()',
  $re$ELSIF\s+NEW\.tur\s*=\s*'cb'\s+THEN$re$,
  $new$ELSIF NEW.tur='cb' AND NEW.kaynak IS DISTINCT FROM 'vekalet' THEN$new$,
  'NEW.kaynak IS DISTINCT FROM ''vekalet''');
-- Vekâlet tek başına bırakılamaz; istifa metinleri seçim durumuna göre doğru olsun
select oyun._yama('public.istifa(text)',
  $re$(raise\s+exception\s+'Cumhurbaşkanı değilsin\.';\s*end\s+if;)$re$,
  $new$\1

    if m.kaynak = 'vekalet' then
      raise exception 'Vekâlet görevi tek başına bırakılamaz. Vekâlet, esas görevin (Cumhurbaşkanı Yardımcılığı ya da TBMM Başkanlığı) sona erdiğinde biter; o görevden istifa edebilirsin.';
    end if;$new$,
  'Vekâlet görevi tek başına bırakılamaz');
select oyun._yama('public.istifa(text)',
  $old$'%s Cumhurbaşkanlığı görevinden istifa etti. Olağanüstü seçim takvimi oluşturuldu.'$old$,
  $new$case when coalesce((sec->>'ara')::boolean, true)
          then '%s Cumhurbaşkanlığı görevinden istifa etti. Olağanüstü seçim takvimi oluşturuldu.'
          else '%s Cumhurbaşkanlığı görevinden istifa etti. Olağan seçim yakın olduğu için ayrı seçim yapılmayacak; yeni Cumhurbaşkanı olağan seçimde belirlenecek.' end$new$,
  'yeni Cumhurbaşkanı olağan seçimde belirlenecek', true);
select oyun._yama('public.istifa(text)',
  $old$'Cumhurbaşkanı istifa etti. Olağanüstü seçim için aday belirleme süreci başladı.'$old$,
  $new$case when coalesce((sec->>'ara')::boolean, true)
        then 'Cumhurbaşkanı istifa etti. Olağanüstü seçim için aday belirleme süreci başladı.'
        else 'Cumhurbaşkanı istifa etti. Olağan seçim yakın olduğu için ayrı seçim yapılmayacak; makama vekâlet ediliyor.' end$new$,
  'makama vekâlet ediliyor', true);
-- m.106 ölçeği: olağan seçime görev süresinin beşte biri ya da daha az kalmışsa (gerçekte "bir yıl veya daha az")
-- ve vekâlet edecek biri varsa ayrı seçim yapılmaz
select oyun._yama('oyun.ara_secim_olustur(text,bigint,smallint,timestamptz)',
  $re$(tur\s+in\s+\('cb',\s*'cb2'\)\s+and\s+not\s+ara\s+and\s+durum\s*<>\s*'tamam'\s+and\s+goreve_bas\s*>\s*t\s+order\s+by\s+goreve_bas\s+limit\s+1;\s*)if\s+o\.id\s+is\s+not\s+null\s+and\s+o\.goreve_bas\s*<=\s*asil_bas\s+then$re$,
  $new$\1if o.id is not null and (
         o.goreve_bas <= asil_bas
         or (oyun.cb_vekil_adayi() is not null
             and o.goreve_bas <= t + make_interval(hours => ceil(720 * coalesce((select deger from oyun.anayasa where kod = 'cb_gorev_suresi'), 1) * 0.2)::int))
       ) then$new$,
  'oyun.cb_vekil_adayi() is not null');
-- Kabine ekranı verisine "vekil" bilgisi (eski uygulama sürümleri bu alanı yok sayar)
select oyun._yama('public.kabine()',
  $re$('cb'\s*,\s*\(\s*SELECT\s+jsonb_build_object\(\s*'kad'\s*,\s*oyun\.kad\(m\.user_id\)\s*,\s*'parti'\s*,\s*oyun\.parti_json\(m\.parti_id\)\s*,\s*'bas'\s*,\s*m\.bas)\)$re$,
  $new$\1,'vekil',m.kaynak='vekalet')$new$,
  '''vekil'',m.kaynak=''vekalet''');
