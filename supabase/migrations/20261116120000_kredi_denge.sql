-- 16.11.2026 · Kredi dengesi (yayın ölçeği)
-- Sorun: Kredi limiti "haftalık gelir × vade" ile hesaplanıyordu. 365 günlük vadede bir yıllık
-- gelir peşin kredi olarak alınabiliyordu (ör. 6 milyon ₺ kredi, günde 30 bin ₺ taksit); bu para
-- ile kurulan şirket günde 80-90 bin ₺ kazandırdığı için kredi sınırsız bir para makinesine dönüyordu.
-- Çözüm (gerçek bankacılıktaki borç/gelir oranı mantığı):
--  1) Gelire dayalı limit en çok 30 günlük (şirkette 60 günlük) gelire göre hesaplanır. Uzun vade
--     yalnız taksiti küçültür, limiti büyütmez. Teminata (nakit, mevduat, mülk, pay) dayalı kısım aynen kalır.
--  2) Kredili sermaye sınırı: açık kredi borcu olan oyuncu şirkete sermaye koyarken (kuruluş,
--     sermaye artırımı, kasaya para yatırma) koyduğu tutarın en az %50'si kadar borçtan arındırılmış
--     öz kaynağa sahip olmalı. Krediyle alınan parayla doğrudan şirket kurulamaz.
--  3) Kredi kullandıktan sonraki 72 saat içinde şirkete büyük sermaye konursa MASAK'a bildirim düşer.
-- Mevcut krediler, bakiyeler ve şirketler değişmez; kural yalnız yeni işlemlere uygulanır.

insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira) values
 ('kredi_gelir_ufku_gun',30,'gun','ekonomi','Kredi gelir ufku','Bireysel kredi limitinde en çok kaç günlük düzenli gelirin hesaba katılacağı. Uzun vade limiti büyütmez, yalnız taksiti küçültür.',540),
 ('sirket_kredi_ufku_gun',60,'gun','ekonomi','Şirket kredisi gelir ufku','İşletme kredisi limitinde en çok kaç günlük şirket kârının hesaba katılacağı.',541),
 ('kredi_ozkaynak_orani',50,'yuzde','ekonomi','Kredili sermaye öz kaynak oranı','Açık kredi borcu varken şirkete konan sermayenin en az bu yüzdesi borçtan arındırılmış öz kaynak olmalı.',542),
 ('kredi_masak_sermaye_esik',100000,'tl','ekonomi','Kredi sonrası sermaye MASAK eşiği','Kredi kullanımından sonraki 72 saatte bu tutarın üstünde şirkete sermaye konursa MASAK bildirimi oluşur.',543)
on conflict (kod) do nothing;

create or replace function oyun.kredi_gelir_ufku_saat()
returns integer language sql stable set search_path to '' as $$
  select greatest(7, least(365, coalesce((select deger from oyun.tarife where kod='kredi_gelir_ufku_gun'),30)))::int * 24
$$;
create or replace function oyun.sirket_kredi_ufku_gun()
returns integer language sql stable set search_path to '' as $$
  select greatest(7, least(365, coalesce((select deger from oyun.tarife where kod='sirket_kredi_ufku_gun'),60)))::int
$$;

-- 1) Bireysel limit: gelir projeksiyonu ufukla sınırlı
do $k$
declare s text := pg_get_functiondef('oyun.kredi_risk_ozeti(uuid,integer)'::regprocedure);
begin
  if position('kredi_gelir_ufku_saat' in s) = 0 then
    s := replace(s, 'haftalik_gelir * p_saat / 168', 'haftalik_gelir * least(p_saat, oyun.kredi_gelir_ufku_saat()) / 168');
    s := replace(s, 'devlet_gunluk_borc * p_saat / 24', 'devlet_gunluk_borc * least(p_saat, oyun.kredi_gelir_ufku_saat()) / 24');
    if position('kredi_gelir_ufku_saat' in s) = 0 then raise exception 'kredi_risk_ozeti yaması uygulanamadı'; end if;
    execute s;
  end if;
end $k$;

-- Şirket kredisi: kâr projeksiyonu ufukla sınırlı
do $k$
declare s text := pg_get_functiondef('oyun.sirket_kredi_kapasite(bigint,integer)'::regprocedure);
begin
  if position('sirket_kredi_ufku_gun' in s) = 0 then
    s := replace(s, 'gelir_kap := haftalik * p_gun / 7.0 * 0.60;', 'gelir_kap := haftalik * least(p_gun, oyun.sirket_kredi_ufku_gun()) / 7.0 * 0.60;');
    if position('sirket_kredi_ufku_gun' in s) = 0 then raise exception 'sirket_kredi_kapasite yaması uygulanamadı'; end if;
    execute s;
  end if;
end $k$;

-- 2) Kredili sermaye sınırı
alter table oyun.masak drop constraint if exists masak_tur_check;
alter table oyun.masak add constraint masak_tur_check check (tur in ('ani_servet','tekrarlayan_ticaret','parti_harcama','ihale_kayirma','kredi_sermaye','davet_suistimal'));
create or replace function oyun.kredi_ozkaynak_durum(p_user uuid)
returns jsonb language sql stable set search_path to '' as $$
  with v as (
    select
      coalesce((select greatest(0,coalesce(c.para,0)) from oyun.cuzdan c where c.user_id=p_user),0)
      + coalesce((select greatest(0,coalesce(b.vadesiz,0)) from oyun.banka_musteri b where b.user_id=p_user),0) as nakit,
      coalesce((select sum(k.kalan) from oyun.krediler k where k.user_id=p_user and k.durum in ('aktif','takip')),0)
      + coalesce((select sum(k.kalan) from oyun.oyb_kredi k where k.borclu=p_user and k.durum in ('aktif','takip')),0)
      + coalesce((select sum(greatest(0,coalesce(kk.borc,0))) from oyun.kredi_kartlari kk where kk.user_id=p_user and kk.durum not in ('kapali','iptal')),0) as borc
  )
  select jsonb_build_object('nakit',round(nakit),'borc',round(borc),'ozkaynak',round(nakit-borc),
     'oran',coalesce((select deger from oyun.tarife where kod='kredi_ozkaynak_orani'),50)) from v
$$;

create or replace function oyun.kredi_ozkaynak_engel(p_user uuid, p_tutar numeric, p_islem text)
returns text language plpgsql security definer set search_path to '' as $$
declare d jsonb := oyun.kredi_ozkaynak_durum(p_user); oran numeric; gerek numeric; t timestamptz := oyun.simdi(); kredi_son numeric;
begin
  if p_tutar is null or p_tutar <= 0 then return null; end if;
  oran := (d->>'oran')::numeric;
  -- MASAK: kredi kullanımından hemen sonra şirkete büyük sermaye
  select coalesce(sum(h.tutar),0) into kredi_son from oyun.hesap_hareket h
   where h.user_id=p_user and h.tur='kredi' and h.tutar>0 and h.zaman > t - interval '72 hours';
  if (d->>'borc')::numeric <= 0 then return null; end if;
  gerek := ceil(p_tutar * oran / 100);
  if (d->>'ozkaynak')::numeric < gerek then
    return format('Kredili sermaye sınırı: açık kredi borcun (%s ₺) varken şirkete koyduğun sermayenin en az %%%s''i borçtan arındırılmış kendi paran olmalı. Nakdin %s ₺, borcun %s ₺, öz kaynağın %s ₺; bu %s için en az %s ₺ öz kaynak gerekiyor. Önce borcunu azalt ya da daha küçük tutar gir.',
      oyun.tl((d->>'borc')::numeric), oran, oyun.tl((d->>'nakit')::numeric), oyun.tl((d->>'borc')::numeric),
      oyun.tl((d->>'ozkaynak')::numeric), p_islem, oyun.tl(gerek));
  end if;
  if kredi_son > 0 and p_tutar >= coalesce((select deger from oyun.tarife where kod='kredi_masak_sermaye_esik'),100000) then
    perform oyun.masak_ekle('kredi_sermaye', p_user, null, null, p_tutar,
      format('%s son 72 saatte %s ₺ kredi kullandıktan sonra %s için %s ₺ şirket sermayesi koydu (öz kaynak %s ₺, borç %s ₺).',
        oyun.kad(p_user), oyun.tl(kredi_son), p_islem, oyun.tl(p_tutar), oyun.tl((d->>'ozkaynak')::numeric), oyun.tl((d->>'borc')::numeric)));
  end if;
  return null;
end $$;
revoke all on function oyun.kredi_ozkaynak_engel(uuid,numeric,text) from public, anon, authenticated;

do $k$
declare s text;
begin
  s := pg_get_functiondef('public.sirket_kur(text,text,numeric)'::regprocedure);
  if position('kredi_ozkaynak_engel' in s) = 0 then
    s := replace(s, $x$ perform oyun.para_islem(u,-p_sermaye,'sirket','Sirket kurulus sermayesi',t);$x$,
      $x$ if oyun.kredi_ozkaynak_engel(u,p_sermaye,'şirket kuruluşu') is not null then raise exception '%', oyun.kredi_ozkaynak_engel(u,p_sermaye,'şirket kuruluşu'); end if;
 perform oyun.para_islem(u,-p_sermaye,'sirket','Sirket kurulus sermayesi',t);$x$);
    if position('kredi_ozkaynak_engel' in s) = 0 then raise exception 'sirket_kur yaması uygulanamadı'; end if;
    execute s;
  end if;
  s := pg_get_functiondef('public.sirket_sermaye_artir(bigint,numeric)'::regprocedure);
  if position('kredi_ozkaynak_engel' in s) = 0 then
    s := replace(s, $x$  PERFORM oyun.para_islem(u,-p_tutar,'sirket','Sirket sermaye katkisi$x$,
      $x$  IF oyun.kredi_ozkaynak_engel(u,p_tutar,'sermaye artırımı') IS NOT NULL THEN RAISE EXCEPTION '%', oyun.kredi_ozkaynak_engel(u,p_tutar,'sermaye artırımı'); END IF;
  PERFORM oyun.para_islem(u,-p_tutar,'sirket','Sirket sermaye katkisi$x$);
    if position('kredi_ozkaynak_engel' in s) = 0 then raise exception 'sirket_sermaye_artir yaması uygulanamadı'; end if;
    execute s;
  end if;
  s := pg_get_functiondef('public.sirket_kasa_yatir(bigint,numeric)'::regprocedure);
  if position('kredi_ozkaynak_engel' in s) = 0 then
    s := replace(s, $x$  perform oyun.para_islem(v_user,-p_tutar,'sirket',$x$,
      $x$  if oyun.kredi_ozkaynak_engel(v_user,p_tutar,'şirket kasasına sermaye') is not null then raise exception '%', oyun.kredi_ozkaynak_engel(v_user,p_tutar,'şirket kasasına sermaye'); end if;
  perform oyun.para_islem(v_user,-p_tutar,'sirket',$x$);
    if position('kredi_ozkaynak_engel' in s) = 0 then raise exception 'sirket_kasa_yatir yaması uygulanamadı'; end if;
    execute s;
  end if;
end $k$;

-- Oyuncunun kendi durumunu görebilmesi (kredi ekranında bilgi)
create or replace function public.kredi_ozkaynak_bilgim()
returns jsonb language sql stable security definer set search_path to '' as $$
  select oyun.kredi_ozkaynak_durum(auth.uid()) || jsonb_build_object(
    'gelir_ufku_gun', oyun.kredi_gelir_ufku_saat()/24, 'sirket_ufku_gun', oyun.sirket_kredi_ufku_gun(),
    'aciklama', 'Kredi limiti en çok '||(oyun.kredi_gelir_ufku_saat()/24)||' günlük düzenli gelirine ve teminatına göre hesaplanır; uzun vade yalnız taksiti küçültür. Açık kredi borcun varken şirkete koyduğun sermayenin en az yarısı kendi paran olmalı.')
$$;
revoke all on function public.kredi_ozkaynak_bilgim() from public, anon;
grant execute on function public.kredi_ozkaynak_bilgim() to authenticated;
