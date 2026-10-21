-- Adayın kendi kesin adaylığından vazgeçmesi; mevcut API imzası korunur.
-- Seçim sandığı açıldıktan sonra çekilme yasaktır.
create or replace function public.adaylik_geri_cek(p_secim bigint)
returns jsonb
language plpgsql
security definer
set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  a oyun.adaylar;
  gorev text;
begin
  if p.id is null or auth.uid() is distinct from p.id then
    raise exception 'Adaylıktan çekilmek için kendi hesabınla giriş yapmalısın.';
  end if;
  select * into s from oyun.secimler where id = p_secim;
  if s.id is null or s.durum <> 'bekliyor' or t >= s.oy_bas then
    raise exception 'Oylama başladıktan sonra adaylıktan çekilemezsin.';
  end if;

  delete from oyun.adaylar
   where secim_id = s.id and user_id = p.id
   returning * into a;
  if a.id is null then
    raise exception 'Bu seçimde adaylığın yok.';
  end if;

  -- Asıl seçimden vazgeçen kişi, o seçimin henüz sandığı açılmamış
  -- ön seçiminde de artık yarışmasın; ön seçim oylamasındaki oylar korunur.
  if s.tur in ('mv', 'cb') then
    delete from oyun.adaylar b
    using oyun.secimler onsecim
    where b.secim_id = onsecim.id
      and b.user_id = p.id
      and onsecim.donem = s.donem
      and onsecim.tur = case s.tur when 'mv' then 'mv_on' else 'cb_on' end
      and onsecim.durum = 'bekliyor'
      and t < onsecim.oy_bas;
  end if;

  -- Parti başkanının doğrudan gösterdiği CB adayı çekildiğinde
  -- geçersiz aday kararı ekranda kalmasın; parti yeni aday belirleyebilsin.
  if s.tur = 'cb' and a.parti_id is not null then
    delete from oyun.cb_kararlar k
    where k.donem = s.donem
      and k.parti_id = a.parti_id
      and k.aday = p.id
      and k.yontem in ('kendisi', 'baskasi');
  end if;

  gorev := case
    when s.tur in ('mv', 'mv_on') then 'milletvekilliği'
    when s.tur in ('cb', 'cb_on', 'cb2') then 'cumhurbaşkanlığı'
    when s.tur in ('bel', 'bel_on') then 'belediye başkanlığı'
    else 'seçim' end;

  perform oyun.olay('secim', format('%s, %s adaylığından kendi isteğiyle çekildi.', p.kad, gorev),
                    a.il_id, a.parti_id, t);
  perform oyun.bildir(p.id, format('%s adaylığından çekilmen tamamlandı. Başvuru ücreti iade edilmez.', initcap(gorev)), t);

  return public.durum();
end
$function$;
