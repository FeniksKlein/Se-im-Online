-- =====================================================================
--  52 · GENEL BAŞKAN YARDIMCILARINA GÖREV + MİTİNG TEPKİSİNDE KENDİLİĞİNDEN KATILIM
--
--  1) Genel başkan, her yardımcısına bir görev alanı verir:
--     "Teşkilattan Sorumlu", "Seçim İşlerinden Sorumlu", … ya da kendi yazdığı bir alan (en fazla 60 karakter).
--     Unvan her yerde görünür: "CYP Teşkilattan Sorumlu Genel Başkan Yardımcısı".
--     Yardımcı değişince görev de sıfırlanır (yeni kişiye yeniden verilir).
--  2) Mitinge katılmamış ama o ilde yaşayan oyuncu bir söze tepki verirse önce mitinge katılmış sayılır
--     (eskiden "önce mitinge katıl" hatası veriyordu).
--  Oyuncu verisi değişmez; yalnız sütun ve fonksiyon eklenir.
-- =====================================================================

alter table oyun.parti_gby add column if not exists gorev text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'parti_gby_gorev_uzunluk') then
    alter table oyun.parti_gby add constraint parti_gby_gorev_uzunluk check (gorev is null or char_length(gorev) between 2 and 60);
  end if;
end $$;

-- "Teşkilattan Sorumlu" → "CYP Teşkilattan Sorumlu Genel Başkan Yardımcısı"
create or replace function oyun.gby_unvan(u uuid) returns text language sql stable set search_path = '' as $$
  select pa.kisa || ' ' || coalesce(nullif(btrim(g.gorev), '') || ' ', '') || 'Genel Başkan Yardımcısı'
  from oyun.parti_gby g join oyun.partiler pa on pa.id = g.parti_id where g.user_id = u limit 1
$$;

-- 20_siyasi_sistem'deki unvanın aynısı; yalnız yardımcı satırı görev alanını gösterir
create or replace function oyun.unvan(u uuid) returns text
language sql stable set search_path='' as $body$
  select coalesce(
    (select 'Başbakan' from oyun.hukumetler h where h.basbakan=u and h.durum='gorevde' and h.bit is null limit 1),
    (select 'Cumhurbaşkanı' from oyun.makamlar where user_id=u and tur='cb' and bit is null limit 1),
    (select replace(b.ad,'Bakanlığı','Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod=m.bakanlik
       where m.user_id=u and m.tur='bakan' and m.bit is null limit 1),
    (select pa.kisa||' Genel Başkanı' from oyun.partiler pa where pa.gb=u and not pa.kapali limit 1),
    (select i.ad||' Milletvekili' from oyun.makamlar m join oyun.iller i on i.id=m.il_id where m.user_id=u and m.tur='mv' and m.bit is null limit 1),
    (select i.ad||' Belediye Başkanı' from oyun.makamlar m join oyun.iller i on i.id=m.il_id where m.user_id=u and m.tur='bel' and m.bit is null limit 1),
    oyun.gby_unvan(u)
  )
$body$;

-- Partinin yardımcıları, görevleri ve miting yetkileri (parti ekranı için; herkes görebilir)
create or replace function public.gby_gorevleri(p_parti bigint) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('sira', g.sira, 'kad', x.kad, 'gorev', g.gorev, 'miting', g.miting_yetkisi) order by g.sira), '[]'::jsonb)
  from oyun.parti_gby g join oyun.profiller x on x.id = g.user_id where g.parti_id = p_parti
$$;

-- Genel başkan bir yardımcısına görev alanı verir (boş = görevi kaldır)
create or replace function public.gby_gorev_ver(p_kad text, p_gorev text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); pa oyun.partiler; h oyun.profiller; gv text;
begin
  select * into pa from oyun.partiler where id = p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Yardımcılara görevi yalnız genel başkan verebilir.'; end if;
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if h.id is null or not exists (select 1 from oyun.parti_gby where parti_id = pa.id and user_id = h.id) then
    raise exception 'Bu oyuncu partinin genel başkan yardımcısı değil.';
  end if;
  if coalesce(btrim(p_gorev), '') = '' then
    update oyun.parti_gby set gorev = null where parti_id = pa.id and user_id = h.id;
    perform oyun.bildir(h.id, format('Genel Başkan %s görev alanını kaldırdı; %s genel başkan yardımcısı olarak devam ediyorsun.', p.kad, pa.kisa), t);
    return public.gby_gorevleri(pa.id);
  end if;
  gv := regexp_replace(oyun.metin_temizle(p_gorev, 60), '\s+', ' ', 'g');
  gv := regexp_replace(gv, '\s*genel başkan yardımcı(sı|lığı)?\s*$', '', 'i');   -- "… Genel Başkan Yardımcısı" yazıldıysa tekrarlanmasın
  if char_length(gv) < 2 then raise exception 'Görev alanı en az 2 karakter olmalı.'; end if;
  update oyun.parti_gby set gorev = gv where parti_id = pa.id and user_id = h.id;
  perform oyun.bildir(h.id, format('Genel Başkan %s sana görev verdi: artık %s %s Genel Başkan Yardımcısısın.', p.kad, pa.kisa, gv), t);
  perform oyun.olay('parti', format('%s, %s %s Genel Başkan Yardımcısı oldu.', h.kad, pa.kisa, gv), null, pa.id, t);
  return public.gby_gorevleri(pa.id);
end $$;

-- 46'daki tepki; katılmamış ama o ilde yaşayan oyuncu tepki verince önce mitinge katılır
create or replace function public.miting_tepki(p_konusma bigint, p_tur text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.miting_konusma; m oyun.mitingler;
begin
  if p_tur not in ('alkis','tezahurat','islik','yuh') then raise exception 'Geçersiz tepki.'; end if;
  select * into k from oyun.miting_konusma where id = p_konusma and not silindi;
  if k.id is null then raise exception 'Konuşma bulunamadı.'; end if;
  select * into m from oyun.mitingler where id = k.miting_id;
  if t < m.bas or t >= m.bit then raise exception 'Miting canlı değil; tepki verilemez.'; end if;
  if m.user_id = p.id then raise exception 'Kendi konuşmana tepki veremezsin.'; end if;
  if not exists (select 1 from oyun.miting_katilim where miting_id = m.id and user_id = p.id) then
    if p.il_id is distinct from m.il_id then
      raise exception 'Tepki vermek için % ilinde yaşamalısın; başka ilden mitingi yalnız izleyebilirsin.', (select ad from oyun.iller where id = m.il_id);
    end if;
    perform public.miting_katil(m.id);
  end if;
  insert into oyun.miting_tepki(konusma_id, miting_id, user_id, tur, zaman) values (k.id, m.id, p.id, p_tur, t)
  on conflict (konusma_id, user_id) do update set tur = excluded.tur, zaman = excluded.zaman;
  return public.miting_meydan(m.id);
end $$;

revoke all on function public.gby_gorevleri(bigint), public.gby_gorev_ver(text, text) from public, anon;
grant execute on function public.gby_gorevleri(bigint), public.gby_gorev_ver(text, text) to authenticated;
