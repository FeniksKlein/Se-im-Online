-- =====================================================================
--  186 (11.11.2026) · ŞİRKET KASASINI ÇAPRAZ ÇEKLE ORTAĞA AKTARMA DÖNGÜSÜ KAPATILDI
--  Görülen yöntem: şirket, ortağının arkadaşına çek yazar; arkadaş aynı gün ortağa kişisel çek yazar.
--  Böylece kâr payı stopajı ve sermaye azaltımı usulü atlanıp şirket kasası kişisel cüzdana aktarılıyordu.
--  Kurallar (yalnız YENİ çekler ve cirolar; ödenmiş/eski çeklere ve bakiyelere dokunulmaz):
--   1) Şirket çeki o şirketin ortağına ya da yöneticisine düzenlenemez, ciro yoluyla da ona geçemez.
--      Ortaklara para aktarımı kâr payı dağıtımı, temettü ya da sermaye azaltımıyla yapılır.
--   2) Karşılıklı çek: Son 7 günde X kişisine çek yazan bir şirketin ortağına/yöneticisine X kişisel çek
--      yazamaz; X son 7 günde o şirketin ortağına/yöneticisine kişisel çek yazdıysa şirket de X'e çek yazamaz.
--  İptal edilmiş çekler sayılmaz.
-- =====================================================================
create or replace function oyun.cek_sirket_ilgilisi(p_sirket bigint, p_user uuid) returns boolean
language sql stable set search_path = '' as $$
  select p_sirket is not null and p_user is not null and (
         exists (select 1 from oyun.sirket_ortaklari o where o.sirket_id = p_sirket and o.user_id = p_user and o.pay > 0)
      or coalesce(oyun.sirket_yonetici_mi(p_sirket, p_user), false))
$$;

create or replace function oyun.cek_dongu_engel() returns trigger
language plpgsql set search_path = '' as $$
declare lehtar uuid;
begin
  if tg_op = 'INSERT' then
    lehtar := case when new.ilk_lehtar_sirket is null then coalesce(new.ilk_lehtar, new.hamil) end;
    if new.borclu_sirket is not null and lehtar is not null then
      if oyun.cek_sirket_ilgilisi(new.borclu_sirket, lehtar) then
        raise exception 'Şirket çeki şirketin ortağına ya da yöneticisine düzenlenemez. Ortaklara ödeme kâr payı dağıtımı, temettü ya da sermaye azaltımıyla yapılır.';
      end if;
      if exists (select 1 from oyun.cekler c
                  where c.borclu_sirket is null and c.duzenleyen = lehtar and c.durum <> 'iptal'
                    and c.keside_at > now() - interval '7 days'
                    and oyun.cek_sirket_ilgilisi(new.borclu_sirket, coalesce(c.ilk_lehtar, c.hamil))) then
        raise exception 'Karşılıklı çek engeli: bu kişi son 7 günde şirketin ortağına/yöneticisine çek yazdı. Şirket kasası çapraz çekle ortaklara aktarılamaz.';
      end if;
    elsif new.borclu_sirket is null and new.ilk_lehtar_sirket is null and new.duzenleyen is not null then
      lehtar := coalesce(new.ilk_lehtar, new.hamil);
      if exists (select 1 from oyun.cekler c
                  where c.borclu_sirket is not null and c.ilk_lehtar_sirket is null and c.durum <> 'iptal'
                    and coalesce(c.ilk_lehtar, c.hamil) = new.duzenleyen
                    and c.keside_at > now() - interval '7 days'
                    and oyun.cek_sirket_ilgilisi(c.borclu_sirket, lehtar)) then
        raise exception 'Karşılıklı çek engeli: son 7 günde bu kişinin şirketinden çek aldın. Şirket kasası çapraz çekle ortaklara aktarılamaz.';
      end if;
    end if;
  elsif tg_op = 'UPDATE' and new.borclu_sirket is not null and new.hamil_sirket is null
        and new.hamil is distinct from old.hamil and oyun.cek_sirket_ilgilisi(new.borclu_sirket, new.hamil) then
    raise exception 'Şirket çeki ciro yoluyla şirketin ortağına ya da yöneticisine geçemez.';
  end if;
  return new;
end $$;
revoke all on function oyun.cek_sirket_ilgilisi(bigint, uuid), oyun.cek_dongu_engel() from public, anon, authenticated;
drop trigger if exists cek_dongu_engel_trg on oyun.cekler;
create trigger cek_dongu_engel_trg before insert or update of hamil on oyun.cekler
  for each row execute function oyun.cek_dongu_engel();
