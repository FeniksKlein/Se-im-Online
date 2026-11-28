-- 2026-11-28 · Bayilikten çıkış (Destek #294)
-- Sorun: Bayilik alan mağaza markanın kategorisine zorla geçiyordu (ör. fast food → market,
-- mutfak kapanıyordu) ve bayilikten çıkmanın hiçbir yolu yoktu.
-- Çözüm:
--   * Bayilik alınırken mağazanın önceki kategorisi saklanır.
--   * public.eko_bayilik_birak(p_sirket): şirket yöneticisi bayiliği sonlandırır;
--     isim hakkı iade edilmez, mağaza önceki kategorisine döner, marka sahibine bildirim gider.
--   * Çıkıştan sonra aynı mağaza 7 gün yeniden bayilik alamaz (bedava pazar genişliği / kategori
--     değiştirme döngüsünü önlemek için).
-- Eski uygulama sürümleri etkilenmez; mevcut RPC'ler değişmez.

alter table oyun.eko_isletmeler add column if not exists bayilik_onceki_kategori text;
alter table oyun.eko_isletmeler add column if not exists bayilik_bekleme timestamptz;

create or replace function oyun.eko_franchise_kategori_hatirla()
returns trigger language plpgsql security definer set search_path to '' as $$
declare e oyun.eko_isletmeler;
begin
  select * into e from oyun.eko_isletmeler where sirket_id = new.sube;
  if e.bayilik_bekleme is not null and e.bayilik_bekleme > oyun.simdi() then
    raise exception 'Bu mağaza bayilikten yeni çıktı; % tarihine kadar yeniden bayilik alamaz.',
      to_char(e.bayilik_bekleme at time zone 'Europe/Istanbul', 'DD.MM.YYYY HH24:MI');
  end if;
  update oyun.eko_isletmeler
     set bayilik_onceki_kategori = coalesce(e.magaza_kategori, 'market')
   where sirket_id = new.sube;
  return new;
end $$;

drop trigger if exists eko_franchise_kategori_hatirla on oyun.eko_franchise;
create trigger eko_franchise_kategori_hatirla before insert on oyun.eko_franchise
  for each row execute function oyun.eko_franchise_kategori_hatirla();

create or replace function public.eko_bayilik_birak(p_sirket bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
  u uuid := auth.uid(); t timestamptz := oyun.simdi();
  s oyun.sirketler; f oyun.eko_franchise; e oyun.eko_isletmeler; mk oyun.sirketler; k text;
begin
  if u is null or not exists(select 1 from oyun.profiller where id = u and not yasakli) then
    raise exception 'Giriş yapmalısın.'; end if;
  select * into s from oyun.sirketler where id = p_sirket for update;
  if s.id is null or not s.aktif or not oyun.sirket_yonetici_mi(p_sirket, u) then
    raise exception 'Bu şirketi yönetme yetkin yok.'; end if;
  select * into f from oyun.eko_franchise where sube = p_sirket for update;
  if f.id is null then raise exception 'Bu mağazanın bir bayiliği yok.'; end if;
  select * into e from oyun.eko_isletmeler where sirket_id = p_sirket;
  k := coalesce(e.bayilik_onceki_kategori, e.magaza_kategori, 'market');
  if k not in ('market', 'fastfood', 'kahve') then k := 'market'; end if;

  delete from oyun.eko_franchise where id = f.id;
  update oyun.eko_isletmeler
     set magaza_kategori = k, bayilik_onceki_kategori = null, bayilik_bekleme = t + interval '7 days'
   where sirket_id = p_sirket;

  select * into mk from oyun.sirketler where id = f.marka;
  insert into oyun.eko_islem_kayit(sirket_id, diger_sirket, oyuncu, tur, tutar, aciklama)
  values (p_sirket, f.marka, u, 'franchise', 0,
          format('%s bayiliği sona erdi (isim hakkı iade edilmez)', coalesce(mk.ad, 'Marka')));
  if mk.kurucu is not null and mk.kurucu <> u then
    perform oyun.bildir(mk.kurucu, format('%s mağazası %s markasının bayiliğinden çıktı.', s.ad, mk.ad), t);
  end if;

  return jsonb_build_object('tamam', true, 'kategori', k, 'bekleme', t + interval '7 days');
end $$;

revoke all on function public.eko_bayilik_birak(bigint) from public, anon;
grant execute on function public.eko_bayilik_birak(bigint) to authenticated;
revoke all on function oyun.eko_franchise_kategori_hatirla() from public, anon, authenticated;
