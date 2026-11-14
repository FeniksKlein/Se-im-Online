-- Seçim Simülasyonu Online: Meclis tarafından azledilen kişiye 7 günlük
-- Yüksek Mahkeme Başkanlığı yeniden atanma yasağı.
--
-- Azil gerekçesinin metni ve kabul edilmiş Meclis kararı birlikte doğrulanır.
-- Süre Meclis kararının uygulandığı gerçek tarihten başlar.
-- Atama bir RPC'den veya doğrudan mahkeme_uye güncellemesinden gelse de engellenir.
-- 2. üye seçiminde, kişilerin başka makamlarda bulunmasında ve istifada kural değişmez.

create or replace function oyun.mahkeme_baskan_bekleme_bitis(p_u uuid)
returns timestamptz
language sql stable
set search_path = ''
as $function$
  select max(k.zaman + interval '7 days')
  from oyun.adliye_atama_kayit k
  where k.eski = p_u
    and k.yeni is null
    and k.gerekce like 'Meclis 3/5 oyla görevden aldı%'
    and exists (
      select 1
      from oyun.mahkeme_azil a
      where a.uye = p_u
        and a.durum = 'kabul'
        and a.bas <= k.zaman
    )
$function$;

create or replace function oyun.tg_mahkeme_baskan_tekrar_atama_koru()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare v_bitis timestamptz;
begin
  if new.sira <> 1 or new.user_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.user_id is not distinct from old.user_id then
    return new;
  end if;
  v_bitis := oyun.mahkeme_baskan_bekleme_bitis(new.user_id);
  if v_bitis is not null and v_bitis > oyun.simdi() then
    raise exception 'Meclisin görevden aldığı bu kişi 7 gün geçmeden yeniden Yüksek Mahkeme Başkanı atanamaz. Bekleme süresi % tarihinde dolacak.',
      to_char(v_bitis at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI');
  end if;
  return new;
end
$function$;

drop trigger if exists mahkeme_baskan_tekrar_atama_koru on oyun.mahkeme_uye;
create trigger mahkeme_baskan_tekrar_atama_koru
before insert or update of user_id on oyun.mahkeme_uye
for each row
execute function oyun.tg_mahkeme_baskan_tekrar_atama_koru();
