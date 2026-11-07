-- 08.11.2026 · İstemci hata kaydı
-- Oyuncunun telefonunda bir ekran açılamadığında asıl teknik hata (yığın izi dahil) buraya yazılır.
-- Oyuncu yalnızca sade bir mesaj görür; geliştirici/yönetici gerçek nedeni buradan okur.
create table if not exists oyun.istemci_hata (
  id bigserial primary key,
  zaman timestamptz not null default now(),
  oyuncu uuid,
  ekran text,
  mesaj text,
  yigin text,
  tarayici text
);
create index if not exists istemci_hata_zaman_idx on oyun.istemci_hata (zaman desc);
alter table oyun.istemci_hata enable row level security;

create or replace function public.istemci_hata_kaydet(p_ekran text, p_mesaj text, p_yigin text default null, p_tarayici text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare v_uid uuid := auth.uid(); v_say int;
begin
  if v_uid is null then return jsonb_build_object('tamam', false); end if;
  -- Kötüye kullanım sınırı: oyuncu başına saatte en çok 30 kayıt
  select count(*) into v_say from oyun.istemci_hata where oyuncu = v_uid and zaman > now() - interval '1 hour';
  if v_say >= 30 then return jsonb_build_object('tamam', false, 'sinir', true); end if;
  insert into oyun.istemci_hata (oyuncu, ekran, mesaj, yigin, tarayici)
  values (v_uid, left(coalesce(p_ekran, ''), 80), left(coalesce(p_mesaj, ''), 500), left(p_yigin, 3000), left(p_tarayici, 300));
  -- Tablo şişmesin: 14 günden eski kayıtları temizle
  delete from oyun.istemci_hata where zaman < now() - interval '14 days';
  return jsonb_build_object('tamam', true);
end $function$;

revoke all on function public.istemci_hata_kaydet(text, text, text, text) from public, anon;
grant execute on function public.istemci_hata_kaydet(text, text, text, text) to authenticated;
