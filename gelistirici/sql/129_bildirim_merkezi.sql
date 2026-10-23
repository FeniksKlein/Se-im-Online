-- =====================================================================
--  129) BİLDİRİM MERKEZİ — 23 Ekim 2026
--  Uygulamadaki "Dikkat isteyen bildirim" bandı için: oyuncunun henüz
--  okumadığı kişisel bildirimleri döndürür. bildirim_kutusu'ndan farkı,
--  okundu İŞARETLEMEMESİDİR (salt okuma; hiçbir tabloya yazmaz).
--  Rozet sayısı arttığında çağrılır; düzenli sorgu yapılmaz.
--  bildirimler_user (user_id, zaman desc) dizinini kullanır.
--  Mevcut fonksiyon ve tablolar değişmez; oyunu sıfırlamaz.
-- =====================================================================
create or replace function public.bildirim_yeniler(p_limit int default 10) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); lim int := least(greatest(coalesce(p_limit, 10), 1), 20);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', b.id, 'zaman', b.zaman, 'metin', b.metin) order by b.zaman desc, b.id desc)
    from (select id, zaman, metin from oyun.bildirimler
          where user_id = p.id and zaman > p.bildirim_okundu and zaman <= t
          order by zaman desc, id desc limit lim) b
  ), '[]'::jsonb);
end $$;
revoke all on function public.bildirim_yeniler(int) from public, anon;
grant execute on function public.bildirim_yeniler(int) to authenticated;
