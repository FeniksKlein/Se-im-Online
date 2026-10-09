-- 2026-10-10 · Gazete: propaganda türünde 600 karakterden uzun yazı "Mesaj en fazla 600 karakter" hatası veriyordu.
-- Yazı 5.000 karaktere kadar yayımlanır; oyun yayın akışına giden özet 600 karakterde kesilir. Kaynak: gelistirici/sql/17_basin_teskilat.sql
begin;
create or replace function public.gazete_yayinla(
  p_gazete bigint,
  p_tur text,
  p_baslik text,
  p_metin text,
  p_hedef_parti bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p oyun.profiller := oyun.profilim();
  g oyun.oyuncu_gazeteleri;
  t timestamptz := oyun.simdi();
  u numeric := 0;
  gunluk int := (
    select gazete_gunluk_yayin from oyun.ayarlar where id = 1
  );
  hedef_kisa text;
  ozet text;
begin
  select * into g
  from oyun.oyuncu_gazeteleri
  where id = p_gazete and aktif
  for update;

  if g.id is null then raise exception 'Gazete bulunamadı.'; end if;

  if g.sahip is distinct from p.id then
    select ucret_yazi into u
    from oyun.gazete_yazarlar
    where gazete_id = g.id
      and user_id = p.id
      and aktif;

    if u is null then
      raise exception 'Bu gazetede yazı yayımlama yetkin yok.';
    end if;
  end if;

  if (
    select count(*)
    from oyun.gazete_yayinlari
    where gazete_id = g.id
      and zaman >= oyun.bugun_bas(t)
  ) >= gunluk then
    raise exception 'Gazetenin bugünkü yayın sınırı doldu (% yazı).', gunluk;
  end if;

  if p_tur not in ('haber','kose','propaganda') then
    raise exception 'Yayın türü geçersiz.';
  end if;

  p_baslik := btrim(coalesce(p_baslik, ''));
  p_metin := btrim(coalesce(p_metin, ''));

  if char_length(p_baslik) < 4 or char_length(p_baslik) > 100 then
    raise exception 'Başlık 4-100 karakter olmalı.';
  end if;
  if char_length(p_metin) < 20 or char_length(p_metin) > 5000 then
    raise exception 'Yazı 20-5000 karakter olmalı.';
  end if;

  if p_tur = 'propaganda' then
    select kisa into hedef_kisa
    from oyun.partiler
    where id = p_hedef_parti and not kapali;

    if hedef_kisa is null then
      raise exception 'Propaganda yazısında hedef parti seçmelisin.';
    end if;
  else
    p_hedef_parti := null;
  end if;

  if u > 0 then
    if g.kasa < u then
      raise exception 'Gazete kasasında yazar ücretini ödeyecek kadar para yok (% ₺ gerekli).',
                      oyun.tl(u);
    end if;

    update oyun.oyuncu_gazeteleri
    set kasa = kasa - u
    where id = g.id;

    insert into oyun.gazete_hareket(
      gazete_id, zaman, tutar, tur, aciklama
    ) values (
      g.id, t, -u, 'yazar_ucreti', format('%s yazı ücreti', p.kad)
    );

    perform oyun.para_islem(
      p.id, u, 'gazete_yazar', format('%s yazı ücreti', g.ad), t
    );
  end if;

  insert into oyun.gazete_yayinlari(
    gazete_id, yazar, tur, baslik, metin, hedef_parti, zaman
  ) values (
    g.id, p.id, p_tur, p_baslik, p_metin, p_hedef_parti, t
  );

  insert into oyun.bildirimler(user_id, zaman, metin)
  select
    a.user_id,
    t,
    format('%s: “%s” yayımlandı.', g.ad, p_baslik)
  from oyun.gazete_abonelik a
  where a.gazete_id = g.id
    and a.bitis > t
    and a.user_id <> p.id;

  if p_tur = 'propaganda' then
    -- Yazının kendisi 5.000 karaktere kadar gazetede yayımlanır; oyun yayın akışına
    -- (en fazla 600 karakter) yalnız başlık ve yazının başından bir özet gider.
    ozet := format(E'📰 %s · PROPAGANDA · %s\n%s\n', g.ad, hedef_kisa, p_baslik);
    ozet := ozet || case
      when char_length(ozet) + char_length(p_metin) <= 600 then p_metin
      else rtrim(left(p_metin, greatest(0, 599 - char_length(ozet)))) || '…'
    end;
    ozet := oyun.metin_temizle(left(ozet, 600), 600);

    insert into oyun.yayinlar(
      tur, gonderen, metin, zaman, hedef_il,
      hedef_parti, secim_id, unvan, gizli
    ) values (
      'sistem',
      p.id,
      ozet,
      t,
      null,
      null,
      null,
      'Oyuncu gazetesi · propaganda',
      false
    );
  end if;

  return public.gazete_detay(g.id);
end $$;
commit;
