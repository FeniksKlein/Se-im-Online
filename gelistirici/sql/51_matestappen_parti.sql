-- 10.10.2026 | MatesTappen: tek basina, 0 TL ve serbest parti adi.
-- Oyundaki diger oyuncularin sartlarini veya mevcut partilerini degistirmez.
-- Yetki sadece kayitli Auth UUID'si icindir; ayni adi sonradan alan alamaz.
insert into oyun_yonetim.ozel_parti_kurma_izni(user_id,aciklama)
select id,'matestappen - serbest adli parti istisnasi'
from oyun.profiller
where lower(kad)=lower('matestappen')
on conflict (user_id) do update set aciklama=excluded.aciklama;

create or replace function public.matestappen_parti_kur(
  p_ad text,p_kisa text,p_renk text,p_amblem text,p_ideolojiler text[] default null
) returns jsonb
language plpgsql security definer set search_path='' as $matestappen$
declare
  p oyun.profiller;
  t timestamptz := oyun.simdi();
  yeni bigint;
  v_ideolojiler text[];
begin
  if auth.uid() is null
    or not exists (
      select 1 from oyun_yonetim.ozel_parti_kurma_izni o
      where o.user_id=auth.uid()
        and o.aciklama='matestappen - serbest adli parti istisnasi'
    ) then
    raise exception 'Serbest parti kurma yetkisi bu hesapta yok.';
  end if;
  p := oyun.profilim(); -- Yasakli profil de burada reddedilir.
  if p.id is distinct from auth.uid() then
    raise exception 'Oturum kimligi eslesmiyor.';
  end if;

  -- Parti adi serbesttir: normalde yasakli sayilan gercek parti adlari,
  -- sayilar, semboller ve 5-40 karakter kisiti bu hesaba uygulanmaz.
  -- Bos ad/kontrol karakteri ve mevcut aktif partiyle ayni ad teknik olarak reddedilir.
  p_ad := btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
  if char_length(p_ad) not between 1 and 80 or p_ad ~ '[[:cntrl:]]' then
    raise exception 'Parti adi 1-80 gorunur karakter olmali.';
  end if;
  p_kisa := upper(btrim(coalesce(p_kisa,'')));
  if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' then
    raise exception 'Kisaltma 2-6 buyuk harften olusmali.';
  end if;
  if p_renk !~ '^#[0-9a-fA-F]{6}$' or p_amblem !~ '^[a-z_]{2,20}$' then
    raise exception 'Parti rengi ya da amblemi gecersiz.';
  end if;
  if exists (
    select 1 from oyun.partiler
    where not kapali
      and (lower(ad)=lower(p_ad) or lower(kisa)=lower(p_kisa))
  ) then
    raise exception 'Secilen parti adi veya kisaltmasi zaten kullaniliyor.';
  end if;
  v_ideolojiler := case when oyun.ideoloji_gecerli(p_ideolojiler)
                       then p_ideolojiler else array['karma']::text[] end;

  -- 25 bin TL, 3 kurucu, kidem, hesap yasi ve parti kurma beklemesi aranmaz.
  perform oyun._ayril(p.id,t);
  insert into oyun.partiler
    (ad,kisa,renk,amblem,gb,kurucu,kurulus,kurulus_bit,kurulus_ucret)
  values
    (p_ad,p_kisa,lower(p_renk),p_amblem,p.id,p.id,t,null,0)
  returning id into yeni;
  perform oyun.genel_merkez_ac(yeni,p,0,t);
  update oyun.profiller
     set parti_id=yeni,parti_at=t,son_parti_kur=t
   where id=p.id;
  insert into oyun.parti_kimlik(parti_id,ideolojiler,guncelleme)
  values(yeni,v_ideolojiler,t);
  update oyun.kurucu_basvuru
    set durum='iptal'
  where kurucu=p.id and durum='bekliyor';
  perform oyun.olay('parti',format('%s (%s) partisi %s tarafindan kuruldu.',p_ad,p_kisa,p.kad),p.il_id,yeni,t);
  return jsonb_build_object('parti_id',yeni,'kurucu_sayi',1,'sermaye',0,'tamam',true);
end
$matestappen$;

revoke all on function public.matestappen_parti_kur(text,text,text,text,text[]) from public,anon,authenticated;
grant execute on function public.matestappen_parti_kur(text,text,text,text,text[]) to authenticated;
