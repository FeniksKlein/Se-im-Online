-- 25.11.2026 · DERNEKLERDE İL BAŞKANLIĞI (sürüm 2026.11.25-2)
-- İstek (destek talebi #69, Ercan "ekle"): "Derneklere il başkanlığı getirilmeli, üyeleri il başkanı yapabilmeliyiz."
--   • Derneğin şubesi olan her ile bir İL BAŞKANI atanabilir. Atamayı yalnız dernek başkanı yapar.
--   • İl başkanı derneğin üyesi olmalı ve O İLDE kayıtlı olmalı (şube o ilde yaşayanlarca yürütülür); başkanın kendisi olamaz.
--   • Yetki: il başkanı KENDİ İLİNDE dernek adına protesto düzenleyebilir (derneğin günlük/il başına protesto sınırları aynen geçerli).
--     Açıklama, şube açma, kasa ve üyelik işleri başkan ve yönetim kurulunda kalır.
--   • Görev kendiliğinden düşer: üye dernekten ayrılırsa, başka ile taşınırsa ya da derneğin başkanı olursa.
--   • Yayın ölçeği: aynı şubeye 10 dakikada bir atama (bildirimle rahatsız etme yolu olmasın); görev değişikliği Gündem'e haber
--     yazmaz (81 şubeli derneklerde akışı doldurmasın), yalnız ilgili oyuncuya bildirim gider.
-- Oyuncu verisi değişmez: dernek_sube'ye iki boş sütun eklenir. Tekrar çalıştırmak güvenlidir. oyun._yama kullanır.
-- Ekran: gelistirici/www/dernek_vitrini.js ("İL BAŞKANLIĞI").

alter table oyun.dernek_sube add column if not exists il_baskani uuid;
alter table oyun.dernek_sube add column if not exists il_baskani_at timestamptz;
create index if not exists dernek_sube_il_baskani on oyun.dernek_sube(il_baskani) where il_baskani is not null;

create or replace function public.dernek_il_baskani_ata(p_dernek bigint, p_il integer, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; s oyun.dernek_sube; h oyun.profiller; ilad text;
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali for update;
  if d.id is null or d.baskan is distinct from p.id then raise exception 'İl başkanını yalnız derneğin başkanı belirler.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  select * into s from oyun.dernek_sube where dernek_id = d.id and il_id = p_il for update;
  if s.dernek_id is null then raise exception 'Derneğin % ilinde şubesi yok; önce şube açmalısın.', coalesce(ilad, 'bu'); end if;

  if coalesce(btrim(p_kad), '') = '' then                                   -- görevden alma
    if s.il_baskani is null then raise exception '% şubesinin il başkanı zaten yok.', ilad; end if;
    update oyun.dernek_sube set il_baskani = null where dernek_id = d.id and il_id = p_il;
    perform oyun.bildir(s.il_baskani, format('%s %s il başkanlığı görevin sona erdi.', d.ad, ilad), t);
    return public.dernek_detay(d.id);
  end if;

  h := oyun.profil_bul(p_kad);
  if h.id = d.baskan then raise exception 'Dernek başkanı ayrıca il başkanı olamaz.'; end if;
  if not exists (select 1 from oyun.dernek_uyeler where dernek_id = d.id and user_id = h.id) then raise exception 'Bu oyuncu derneğin üyesi değil.'; end if;
  if h.il_id is distinct from p_il then raise exception '% % ilinde kayıtlı değil. İl başkanı o ilde yaşayan üyelerden seçilir.', h.kad, ilad; end if;
  if s.il_baskani = h.id then raise exception '% zaten % il başkanı.', h.kad, ilad; end if;
  if s.il_baskani_at is not null and s.il_baskani_at > t - interval '10 minutes' then
    raise exception '% il başkanı az önce atandı; yeni atama için % saatini bekle.', ilad, to_char((s.il_baskani_at + interval '10 minutes') at time zone 'Europe/Istanbul', 'HH24:MI');
  end if;
  update oyun.dernek_sube set il_baskani = null where dernek_id = d.id and il_baskani = h.id;
  update oyun.dernek_sube set il_baskani = h.id, il_baskani_at = t where dernek_id = d.id and il_id = p_il;
  if s.il_baskani is not null then
    perform oyun.bildir(s.il_baskani, format('%s %s il başkanlığı görevin sona erdi.', d.ad, ilad), t);
  end if;
  perform oyun.bildir(h.id, format('%s %s il başkanlığına atandın. Artık %s ilinde dernek adına protesto düzenleyebilirsin.', d.ad, ilad, ilad), t);
  return public.dernek_detay(d.id);
end $f$;

revoke all on function public.dernek_il_baskani_ata(bigint, integer, text) from public, anon;
grant execute on function public.dernek_il_baskani_ata(bigint, integer, text) to authenticated;

-- Görev kendiliğinden düşer: üyelik bitince, il değişince, kişi derneğin başkanı olunca.
create or replace function oyun.dernek_ilb_uye_tg() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  update oyun.dernek_sube set il_baskani = null where dernek_id = old.dernek_id and il_baskani = old.user_id;
  return old;
end $f$;
drop trigger if exists dernek_ilb_uye on oyun.dernek_uyeler;
create trigger dernek_ilb_uye after delete on oyun.dernek_uyeler for each row execute function oyun.dernek_ilb_uye_tg();

create or replace function oyun.dernek_ilb_profil_tg() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  update oyun.dernek_sube set il_baskani = null where il_baskani = new.id and il_id is distinct from new.il_id;
  return new;
end $f$;
drop trigger if exists dernek_ilb_profil on oyun.profiller;
create trigger dernek_ilb_profil after update of il_id on oyun.profiller for each row when (new.il_id is distinct from old.il_id)
  execute function oyun.dernek_ilb_profil_tg();

create or replace function oyun.dernek_ilb_baskan_tg() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  update oyun.dernek_sube set il_baskani = null where dernek_id = new.id and il_baskani = new.baskan;
  return new;
end $f$;
drop trigger if exists dernek_ilb_baskan on oyun.dernekler;
create trigger dernek_ilb_baskan after update of baskan on oyun.dernekler for each row when (new.baskan is not null and new.baskan is distinct from old.baskan)
  execute function oyun.dernek_ilb_baskan_tg();

revoke all on function oyun.dernek_ilb_uye_tg(), oyun.dernek_ilb_profil_tg(), oyun.dernek_ilb_baskan_tg() from public, anon, authenticated;

-- dernek_detay: şubede il başkanı, üyede il başkanlığı işareti, okuyanın kendi il başkanlığı.
select oyun._yama('public.dernek_detay(bigint)',
  $a$'harc', oyun.dernek_harci(),$a$,
  $b$'harc', oyun.dernek_harci(),
    'il_baskanligim', (select sb.il_id from oyun.dernek_sube sb where sb.dernek_id = d.id and sb.il_baskani = u limit 1),$b$,
  'il_baskanligim', true);
select oyun._yama('public.dernek_detay(bigint)',
  $a$jsonb_build_object('kad', pr.kad, 'il', i.ad, 'rol', x.rol)$a$,
  $b$jsonb_build_object('kad', pr.kad, 'il', i.ad, 'rol', x.rol, 'il_id', pr.il_id, 'il_baskani', exists (select 1 from oyun.dernek_sube sb where sb.dernek_id = d.id and sb.il_baskani = x.user_id))$b$,
  $c$'il_baskani', exists$c$, true);
select oyun._yama('public.dernek_detay(bigint)',
  $a$jsonb_build_object('il_id', s.il_id, 'il', i.ad, 'merkez', s.il_id = d.merkez_il)$a$,
  $b$jsonb_build_object('il_id', s.il_id, 'il', i.ad, 'merkez', s.il_id = d.merkez_il, 'il_baskani', oyun.kad(s.il_baskani))$b$,
  $c$'il_baskani', oyun.kad$c$, true);

-- dernek_eylem: il başkanı kendi ilinde protesto düzenleyebilir.
select oyun._yama('public.dernek_eylem(bigint,text,text,text,text,text,integer,timestamp with time zone)',
  $a$  d := oyun.dernek_yetkili(p_dernek, p.id);$a$,
  $b$  if p_tur = 'protesto' and p_il is not null and exists (select 1 from oyun.dernek_sube sb where sb.dernek_id = p_dernek and sb.il_id = p_il and sb.il_baskani = p.id) then
    select * into d from oyun.dernekler where id = p_dernek and not kapali;   -- il başkanı: yalnız kendi ilinde protesto
    if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  else
    d := oyun.dernek_yetkili(p_dernek, p.id);
  end if;$b$,
  'sb.il_baskani = p.id', true);
