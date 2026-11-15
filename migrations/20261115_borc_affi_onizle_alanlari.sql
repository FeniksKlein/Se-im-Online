-- 2026-11-15: Borç affı önizlemesinde "undefined borçlu oyuncu · NaN ₺" hatası.
-- oyun.borc_affi_etki yeni alan adları döndürüyor (borclu, silinecek, hazine_maliyet);
-- istemci eski adları okuyordu. Önizleme iki adı da döndürür (geriye uyumlu, veri değiştirmez).
create or replace function public.borc_affi_onizle(p_oran numeric)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); e jsonb;
begin
  e:=oyun.borc_affi_etki(p_oran);
  return e || jsonb_build_object(
    'borclu_oyuncu',coalesce((e->>'borclu')::int,0),
    'oyuncu_borcu',coalesce((e->>'toplam_borc')::numeric,0),
    'oyuncu_silinecek',coalesce((e->>'silinecek')::numeric,0),
    'maliyet',coalesce((e->>'hazine_maliyet')::numeric,0)
  );
end $$;
revoke all on function public.borc_affi_onizle(numeric) from public,anon;
grant execute on function public.borc_affi_onizle(numeric) to authenticated;
