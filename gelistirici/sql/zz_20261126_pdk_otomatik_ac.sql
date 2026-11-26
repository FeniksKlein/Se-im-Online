-- 26.11.2026 · Disiplin Kurulu seçimlerinin KENDİLİĞİNDEN açılması (sürüm 2026.11.26-10)
-- Ercan: "Unuturum ben bunu demeyi" → seçimleri açmak için elle komut beklenmez.
-- Yeni istemci (bu sürüm ve sonrası) açılışta bir kez sürümünü bildirir (oyun.istemci_surum). Son 24 saatte aktif
-- oyuncuların en az %70'i yeni istemciyi kullanıyorsa (en az 50 aktif oyuncu varken) oyun.pdk_tick seçimleri açar
-- (ayarlar.pdk_secim_acik = true) ve yöneticilere bildirim gider. Eski mağaza uygulaması sürüm bildirmez.
-- Bu tablo ayrıca "oyuncular hangi sürümde / hangi cihazda" sorusunun cevabıdır.

create table if not exists oyun.istemci_surum(
  user_id uuid primary key,
  surum text not null,
  platform text not null,
  zaman timestamptz not null default now()
);
create index if not exists istemci_surum_zaman on oyun.istemci_surum(zaman);
alter table oyun.istemci_surum enable row level security;
revoke all on oyun.istemci_surum from public, anon, authenticated;

create or replace function public.istemci_bildir(p_surum text, p_platform text) returns void
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare u uuid := auth.uid();
begin
  if u is null then return; end if;
  insert into oyun.istemci_surum(user_id, surum, platform, zaman)
  values (u, left(coalesce(p_surum, '?'), 40), left(coalesce(p_platform, '?'), 20), now())
  on conflict (user_id) do update set surum = excluded.surum, platform = excluded.platform, zaman = excluded.zaman
    where oyun.istemci_surum.zaman < now() - interval '1 hour'
       or oyun.istemci_surum.surum is distinct from excluded.surum
       or oyun.istemci_surum.platform is distinct from excluded.platform;
end $$;
revoke all on function public.istemci_bildir(text, text) from public, anon;
grant execute on function public.istemci_bildir(text, text) to authenticated;

-- Seçimler kapalıysa ve yeni istemci oranı yeterliyse açar. pdk_tick her çalıştığında çağrılır (2 sayım, ucuz).
create or replace function oyun.pdk_secim_otomatik_ac() returns boolean
language plpgsql set search_path = 'oyun','public','pg_temp' as $$
declare n int; r int;
begin
  if coalesce((select pdk_secim_acik from oyun.ayarlar where id = 1), false) then return false; end if;
  select count(*) into n from oyun.profiller where son_gorulme > now() - interval '24 hours';
  if n < 50 then return false; end if;
  select count(*) into r from oyun.profiller p join oyun.istemci_surum s on s.user_id = p.id
   where p.son_gorulme > now() - interval '24 hours' and s.zaman > now() - interval '7 days';
  if r * 100 < n * 70 then return false; end if;
  update oyun.ayarlar set pdk_secim_acik = true where id = 1;
  insert into oyun.bildirimler(user_id, zaman, metin)
  select id, now(), '⚖️ Son 24 saatte aktif oyuncuların %' || round(r * 100.0 / n) || '''i yeni uygulama sürümünde. Disiplin Kurulu seçimleri kendiliğinden açıldı; partilerde adaylık başlıyor.'
  from oyun.profiller where coalesce(yonetici, false);
  return true;
end $$;
revoke all on function oyun.pdk_secim_otomatik_ac() from public, anon, authenticated;

-- pdk_tick: seçim adımından önce otomatik açma denetimi
create or replace function oyun.pdk_tick() returns jsonb
language plpgsql security definer set search_path = 'oyun','public','pg_temp' as $$
declare t timestamptz := oyun.simdi(); r record; s jsonb;
begin
  if not pg_try_advisory_xact_lock(77250031) then return jsonb_build_object('atlandi', true); end if;
  for r in select id from oyun.pdk_dosya where durum = 'myk' and myk_son <= t order by id limit 200 loop
    begin perform oyun.pdk_myk_kapat(r.id, t, true);
    exception when others then raise warning 'pdk myk %: %', r.id, sqlerrm; end;
  end loop;
  for r in select id, heyet, hedef from oyun.pdk_dosya where durum = 'savunma' and savunma_son <= t order by id limit 200 loop
    update oyun.pdk_dosya set durum = 'kurul', karar_son = t + make_interval(hours => oyun.pdk_s('kurul_saat')::int) where id = r.id;
    perform oyun.pdk_toplu_bildir(r.heyet, '⚖️ ' || oyun.kad(r.hedef) || ' dosyasında savunma süresi doldu; kurul oylaması açıldı (' || oyun.pdk_s('kurul_saat') || ' saat).', t);
  end loop;
  for r in select id from oyun.pdk_dosya where durum = 'kurul' and karar_son <= t order by id limit 200 loop
    begin perform oyun.pdk_kurul_sonuc(r.id, t, true);
    exception when others then raise warning 'pdk kurul %: %', r.id, sqlerrm; end;
  end loop;
  update oyun.pdk_dosya set durum = 'kesin', kapandi = t where durum = 'karar' and itiraz_son <= t;
  for r in select id from oyun.pdk_dosya where durum = 'itiraz' and itiraz_karar_son <= t order by id limit 200 loop
    begin perform oyun.pdk_itiraz_sonuc(r.id, t, true);
    exception when others then raise warning 'pdk itiraz %: %', r.id, sqlerrm; end;
  end loop;
  begin perform oyun.pdk_secim_otomatik_ac();
  exception when others then raise warning 'pdk otomatik ac: %', sqlerrm; end;
  s := oyun.pdk_secim_tick(t);
  begin perform oyun.disiplin_sonuclandir();
  exception when others then raise warning 'eski disiplin: %', sqlerrm; end;
  return s;
end $$;
revoke all on function oyun.pdk_tick() from public, anon, authenticated;
