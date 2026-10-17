-- Bir partide yalnızca bir üye kaldığında o oyuncu otomatik genel başkan olur.
-- Diğer seçilmiş/atanmış makamlar, cüzdanlar, oylar ve üyelik geçmişi korunur.

create or replace function oyun.tek_uye_genel_baskan_duzelt(p_parti bigint)
returns void language plpgsql security definer
set search_path = oyun, public, pg_temp as $$
declare
  pa oyun.partiler;
  kalan oyun.profiller;
  adet integer;
  t timestamptz := oyun.simdi();
begin
  if p_parti is null then return; end if;

  -- Aynı partide eşzamanlı üyelik hareketleri birbirini geçmesin.
  select * into pa from oyun.partiler where id = p_parti for update;
  if pa.id is null or pa.kapali then return; end if;

  select count(*) into adet from oyun.profiller where parti_id = p_parti;
  if adet <> 1 then return; end if;
  select * into kalan from oyun.profiller where parti_id = p_parti limit 1;
  if kalan.id is null or kalan.yasakli or pa.gb is not distinct from kalan.id then return; end if;

  -- Genel başkan aynı zamanda kendi genel başkan yardımcısı olamaz.
  -- Milletvekilliği, belediye başkanlığı ve diğer makamlar değişmez.
  delete from oyun.parti_gby where user_id = kalan.id;
  update oyun.partiler set gb = kalan.id where id = p_parti;

  perform oyun.bildir(kalan.id,
    format('%s partisinde tek üye kaldığın için otomatik olarak genel başkan oldun.', pa.ad), t);
  perform oyun.olay('parti',
    format('%s partisinin tek üyesi %s otomatik olarak genel başkan oldu.', pa.ad, kalan.kad),
    null, pa.id, t);
end $$;

create or replace function oyun.tek_uye_profil_tg()
returns trigger language plpgsql security definer
set search_path = oyun, public, pg_temp as $$
declare
  eski bigint;
  yeni bigint;
begin
  if tg_op = 'INSERT' then
    yeni := new.parti_id;
  elsif tg_op = 'DELETE' then
    eski := old.parti_id;
  else
    eski := old.parti_id;
    yeni := new.parti_id;
    if eski is not distinct from yeni then return new; end if;
  end if;

  -- Kilitleri sabit sırayla al; karşılıklı parti değişiminde kilit çatışmasın.
  if eski is not null and yeni is not null and eski > yeni then
    perform oyun.tek_uye_genel_baskan_duzelt(yeni);
    perform oyun.tek_uye_genel_baskan_duzelt(eski);
  else
    perform oyun.tek_uye_genel_baskan_duzelt(eski);
    if yeni is distinct from eski then
      perform oyun.tek_uye_genel_baskan_duzelt(yeni);
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

drop trigger if exists tek_uye_profil on oyun.profiller;
create trigger tek_uye_profil
after insert or update of parti_id or delete on oyun.profiller
for each row execute function oyun.tek_uye_profil_tg();

revoke all on function oyun.tek_uye_genel_baskan_duzelt(bigint) from public, anon, authenticated;
revoke all on function oyun.tek_uye_profil_tg() from public, anon, authenticated;

-- Mevcut tek üyeli ve başkanlığı boş partileri de aynı kuralla onar.
do $$
declare pid bigint;
begin
  for pid in
    select pa.id from oyun.partiler pa
    join oyun.profiller p on p.parti_id = pa.id
    where not pa.kapali
    group by pa.id
    having count(*) = 1
  loop
    perform oyun.tek_uye_genel_baskan_duzelt(pid);
  end loop;
end $$;
