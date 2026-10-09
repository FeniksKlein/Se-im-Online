begin;
-- 2026-10-09 · Eyetkin hesabina ozel ucretsiz ve tek kisilik parti kurma.
-- Genel kurucu daveti ve 25.000 TL kurallari diger oyuncular icin degismez.
-- Yetki kullanici adina degil, mevcut Supabase Auth kullanici kimligine baglidir.

create table if not exists oyun_yonetim.ozel_parti_kurma_izni (
  user_id uuid primary key references auth.users(id) on delete cascade,
  aciklama text not null default 'Eyetkin - test istisnasi',
  tanimlama timestamptz not null default now()
);
alter table oyun_yonetim.ozel_parti_kurma_izni enable row level security;
revoke all on oyun_yonetim.ozel_parti_kurma_izni from public, anon, authenticated;

do $eyetkin_kimlik$
begin
  if (select count(*) from oyun.profiller where lower(kad)=lower('Eyetkin'))<>1 then
    raise exception 'Eyetkin profili tekil bulunamadi. Istisna yetkisi tanimlanmadi.';
  end if;
  insert into oyun_yonetim.ozel_parti_kurma_izni(user_id)
  select id from oyun.profiller where lower(kad)=lower('Eyetkin')
  on conflict (user_id) do nothing;
end
$eyetkin_kimlik$;

create or replace function public.eyetkin_parti_kur(
  p_ad text, p_kisa text, p_renk text, p_amblem text, p_ideolojiler text[]
) returns jsonb
language plpgsql security definer set search_path='' as $eyetkin$
declare
  p oyun.profiller;
  t timestamptz:=oyun.simdi();
  yeni bigint;
begin
  if auth.uid() is null or not exists (
      select 1 from oyun_yonetim.ozel_parti_kurma_izni k where k.user_id=auth.uid()
  ) then
    raise exception 'Bu parti kurma istisnasi sadece yetkili hesaba aciktir.';
  end if;
  p:=oyun.profilim();
  if p.id is distinct from auth.uid() then
    raise exception 'Hesap dogrulanamadi.';
  end if;

  -- Normal parti kurma akisi ile ayni ad, kisa ad, renk ve amblem kontrolleri.
  p_ad:=btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
  p_kisa:=upper(btrim(coalesce(p_kisa,'')));
  if length(p_ad) not between 5 and 40
      or p_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then
    raise exception 'Parti adi 5-40 harften olusmali.';
  end if;
  if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$'
      or p_renk !~ '^#[0-9a-fA-F]{6}$'
      or p_amblem !~ '^[a-z_]{2,20}$' then
    raise exception 'Parti kisaltmasi, rengi veya amblemi gecersiz.';
  end if;
  if not oyun.ideoloji_gecerli(p_ideolojiler) then
    raise exception '1 ile 3 arasinda gecerli ideoloji secmelisin.';
  end if;
  if oyun.yasakli_ad(p_ad) or oyun.yasakli_kisa(p_kisa) then
    raise exception 'Yasakli veya gercek siyasi partiyle karisabilecek ad kullanilamaz.';
  end if;
  if exists (
      select 1 from oyun.partiler
      where not kapali and (lower(ad)=lower(p_ad) or lower(kisa)=lower(p_kisa))
  ) then
    raise exception 'Bu parti adi veya kisaltmasi kullanimda.';
  end if;
  if oyun.uyari(p,t) is not null then
    raise exception 'Parti kurma sarti: %', oyun.uyari(p,t);
  end if;
  if oyun.kidem_puani(p.id)<(select parti_kurucu_kidem from oyun.ayarlar where id=1) then
    raise exception 'Parti kurma kidemin yetersiz.';
  end if;
  if p.son_parti_kur is not null
      and p.son_parti_kur + make_interval(days=>(select parti_kur_gun from oyun.ayarlar where id=1))>t then
    raise exception 'Parti kurma bekleme suren dolmadi.';
  end if;

  -- Yalnizca bu hesap icin: kurucu davetlerini ve para kesintisini atla.
  perform oyun._ayril(p.id,t);
  insert into oyun.partiler(ad,kisa,renk,amblem,gb,kurucu,kurulus,kurulus_bit,kurulus_ucret)
  values(p_ad,p_kisa,lower(p_renk),p_amblem,p.id,p.id,t,null,0)
  returning id into yeni;
  perform oyun.genel_merkez_ac(yeni,p,0,t);
  update oyun.profiller
     set parti_id=yeni,parti_at=t,son_parti_kur=t
   where id=p.id;
  insert into oyun.parti_kimlik(parti_id,ideolojiler,guncelleme)
  values(yeni,p_ideolojiler,t);
  update oyun.kurucu_basvuru
     set durum='iptal'
   where kurucu=p.id and durum='bekliyor';
  perform oyun.olay(
    'parti', format('%s (%s) partisi %s tarafindan kuruldu.',p_ad,p_kisa,p.kad),
    p.il_id,yeni,t
  );
  return jsonb_build_object('parti_id',yeni,'kurucu_sayi',1,'sermaye',0,'tamam',true);
end
$eyetkin$;

revoke all on function public.eyetkin_parti_kur(text,text,text,text,text[]) from public, anon, authenticated;
grant execute on function public.eyetkin_parti_kur(text,text,text,text,text[]) to authenticated;

commit;
