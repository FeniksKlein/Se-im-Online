
-- Dernek uye destekleri: gercek oyunculara, oyun ici gercek masraflar ve katilima dayanan karsilikli yardim.
-- Dernek kasalarina, onceki yardim ve kampanya kayitlarina geriye donuk dokunmaz.
create table if not exists oyun.dernek_uye_destek (
 id bigint generated always as identity primary key,
 dernek_id bigint not null references oyun.dernekler(id),
 basvuran uuid not null references oyun.profiller(id),
 tur text not null check (tur in ('ihtiyac','tasinma','hukuk','egitim','gonullu')),
 referans_id bigint,
 tutar numeric not null check (tutar between 100 and 4000 and tutar=trunc(tutar)),
 aciklama text not null check (char_length(aciklama) between 5 and 350),
 durum text not null default 'bekliyor' check (durum in ('bekliyor','onay','red','iptal')),
 basvuru timestamptz not null default now(),
 karartarihi timestamptz,
 karari_veren uuid references oyun.profiller(id),
 ret_gerekcesi text
);
create index if not exists dernek_uye_destek_durum on oyun.dernek_uye_destek(dernek_id,basvuru desc);
create index if not exists dernek_uye_destek_kisi on oyun.dernek_uye_destek(basvuran,basvuru desc);
create unique index if not exists dernek_uye_destek_kanit_uni on oyun.dernek_uye_destek(tur,referans_id,basvuran)
 where durum='onay' and referans_id is not null;
alter table oyun.dernek_uye_destek enable row level security;
revoke all on oyun.dernek_uye_destek from public,anon,authenticated;
do $body$ begin
 if to_regproc('oyun.bosaltma_korumasi') is not null then
  execute 'drop trigger if exists bosaltma_korumasi on oyun.dernek_uye_destek';
  execute 'create trigger bosaltma_korumasi before truncate on oyun.dernek_uye_destek for each statement execute function oyun.bosaltma_korumasi()';
 end if;
end $body$;

-- Adliye yargilama/dava harci, mevduat/servet, oynanmis gönüllülük ve tasinma kayitlari ile server-side kontrol.
create or replace function oyun.dernek_destek_kontrol(p_dernek bigint,p_kisi uuid,p_tur text,p_referans bigint default null)
returns jsonb language plpgsql stable set search_path='' as $$
declare d oyun.dernekler; u oyun.profiller; uye oyun.dernek_uyeler; t timestamptz := oyun.simdi();
 limit_tl numeric; nakit numeric; masraf numeric; x oyun.dernek_programlar; etkin oyun.dernek_etkinlikler;
begin
 select * into d from oyun.dernekler where id=p_dernek and not kapali;
 if d.id is null then raise exception 'Dernek bulunamadı veya kapalı.'; end if;
 select * into uye from oyun.dernek_uyeler where dernek_id=p_dernek and user_id=p_kisi;
 if uye.user_id is null then raise exception 'Bu derneğin üyesi değilsin.'; end if;
 if uye.katilim>t-interval '24 hours' then raise exception 'Destek için en az 24 saatlik üyelik gerekir.'; end if;
 select * into u from oyun.profiller where id=p_kisi and not yasakli;
 if u.id is null or u.olusturma>t-interval '48 hours' then raise exception 'Hesap en az 48 saatlik ve aktif olmalı.'; end if;
 if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and durum='onay' and karartarihi>t-interval '7 days') then
  raise exception 'Son 7 günde dernek desteği aldın; yeniden başvuru zamanı gelmedi.'; end if;
 if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and tur=p_tur and durum='onay' and karartarihi>t-interval '21 days') then
  raise exception 'Aynı destek türüne 21 gün içinde tekrar başvurulamaz.'; end if;
 if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and durum='bekliyor') then
  raise exception 'Önce bekleyen destek başvurunun sonuçlanması gerekir.'; end if;
 case p_tur
 when 'ihtiyac' then
  select coalesce((select para from oyun.cuzdan where user_id=p_kisi),0)
   +coalesce((select vadesiz from oyun.banka_musteri where user_id=p_kisi),0)
   +coalesce((select sum(anapara) from oyun.banka_mevduat where user_id=p_kisi and not kapandi and not iptal),0)
   into nakit;
  if nakit>12000 then raise exception 'İhtiyaç desteği için cüzdan ve banka birikimin toplamı 12.000 TL veya daha az olmalı.'; end if;
  if exists(select 1 from oyun.mulkler where user_id=p_kisi)
  or exists(select 1 from oyun.yatirim_mulkleri where user_id=p_kisi)
  or exists(select 1 from oyun.sirket_ortaklari where user_id=p_kisi and pay>0)
  or exists(select 1 from oyun.sirketler where kurucu=p_kisi and aktif)
  or exists(select 1 from oyun.piyasa_pozisyon where user_id=p_kisi and miktar>0) then
   raise exception 'İhtiyaç desteği, mülkü, şirket ortaklığı veya yatırımı bulunmayan üyelere yöneliktir.'; end if;
  if p_referans is not null then raise exception 'İhtiyaç desteği için kayıt seçme.'; end if;
  limit_tl := 2000;
 when 'tasinma' then
  if p_referans is not null then raise exception 'Taşınma için kayıt seçme.'; end if;
  if u.son_il_degis is null or u.son_il_degis<t-interval '14 days' or u.son_il_degis>t then
   raise exception 'Son 14 gün içinde şehir değiştirmiş olmalısın.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and tur='tasinma'
    and durum='onay' and karartarihi>u.son_il_degis) then
   raise exception 'Bu taşınma için zaten destek aldın.'; end if;
  limit_tl := 1500;
 when 'hukuk' then
  if p_referans is null then raise exception 'Ödenmiş dava harcı kaydını seç.'; end if;
  select abs(h.tutar) into masraf from oyun.hesap_hareket h
   where h.id=p_referans and h.user_id=p_kisi and h.tur='adliye' and h.tutar<0
   and h.zaman>=t-interval '14 days' and h.zaman<=t
   and (h.aciklama ilike '%harç%' or h.aciklama ilike '%harc%');
  if masraf is null then raise exception 'Son 14 günde gerçekten ödenmiş bir dava harcı bulunamadı.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and tur='hukuk'
      and referans_id=p_referans and durum='onay') then
   raise exception 'Bu dava harcı için daha önce destek ödendi.'; end if;
  limit_tl := least(4000,floor(masraf*0.60));
 when 'egitim' then
  if p_referans is null then raise exception 'Katıldığın eğitim programını seç.'; end if;
  select z.* into x from oyun.dernek_programlar z join oyun.dernek_program_katilim k
   on k.program_id=z.id and k.user_id=p_kisi
   where z.id=p_referans and z.dernek_id=p_dernek and z.tur in ('etut','meslek')
     and z.bas<=t-interval '2 hours' and z.bit>=t-interval '14 days'
     and k.zaman<=t-interval '2 hours';
  if x.id is null then raise exception 'En az 2 saattir katıldığın uygun eğitim programı yok.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where tur='egitim' and referans_id=p_referans
      and basvuran=p_kisi and durum='onay') then
   raise exception 'Bu eğitim için burs desteği ödendi.'; end if;
  limit_tl := 1800;
 when 'gonullu' then
  if p_referans is null then raise exception 'Katıldığın gönüllü etkinliğini seç.'; end if;
  select z.* into etkin from oyun.dernek_etkinlikler z join oyun.dernek_gonulluler k
   on k.etkinlik_id=z.id and k.user_id=p_kisi
   where z.id=p_referans and z.dernek_id=p_dernek and z.bit<=t
    and z.bit>=t-interval '14 days' and k.zaman<=z.bit;
  if etkin.id is null then raise exception 'Katıldığın ve tamamlanmış bir gönüllü etkinliği olmalı.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where tur='gonullu' and referans_id=p_referans
     and basvuran=p_kisi and durum='onay') then
    raise exception 'Bu etkinlik için daha önce ödeme yapıldı.'; end if;
  limit_tl := 1200;
 else raise exception 'Geçersiz destek türü.';
 end case;
 if limit_tl<100 then raise exception 'Kanıtlanan gider için destek üst sınırı 100 TL altındadır.'; end if;
 return jsonb_build_object('ust_limit',limit_tl,'uygun',true);
end $$;
revoke execute on function oyun.dernek_destek_kontrol(bigint,uuid,text,bigint) from public,anon,authenticated;

create or replace function public.dernek_uye_destek_basvur(p_dernek bigint,p_tur text,p_tutar numeric,p_aciklama text,p_referans bigint default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz:=oyun.simdi(); uygun jsonb; azami numeric; yeni bigint;
begin
 if oyun.uyari(p,t) is not null then raise exception 'Destek başvurusu kısıtlandı.'; end if;
 -- Seri basvurulari ayni kullanici temelinde siraya sok.
 perform pg_advisory_xact_lock(hashtextextended(p.id::text,651201));
 uygun:=oyun.dernek_destek_kontrol(p_dernek,p.id,p_tur,p_referans);
 azami:=(uygun->>'ust_limit')::numeric;
 if p_tutar is null or p_tutar<>trunc(p_tutar) or p_tutar<100 or p_tutar>azami then
  raise exception 'Başvurabileceğin tutar 100-% TL arasında tam sayı olmalı.',oyun.tl(azami); end if;
 if coalesce(length(btrim(p_aciklama)),0)<5 or length(p_aciklama)>350 then
  raise exception 'Başvuru gerekçesini 5-350 karakterle açıkla.'; end if;
 insert into oyun.dernek_uye_destek(dernek_id,basvuran,tur,referans_id,tutar,aciklama,basvuru)
 values(p_dernek,p.id,p_tur,p_referans,p_tutar,oyun.metin_temizle(p_aciklama,350),t)
 returning id into yeni;
 return jsonb_build_object('id',yeni,'durum','bekliyor','tutar',p_tutar);
end $$;

create or replace function public.dernek_uye_destek_karar(p_basvuru bigint,p_onay boolean,p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz:=oyun.simdi();
 d oyun.dernekler; a oyun.dernek_uye_destek; uygun jsonb; harcanan numeric; haftalik_limit numeric;
begin
 if oyun.uyari(p,t) is not null then raise exception 'Destek karar işlemi kısıtlandı.'; end if;
 select dernek_id into d.id from oyun.dernek_uye_destek where id=p_basvuru;
 if d.id is null then raise exception 'Başvuru bulunamadı.'; end if;
 -- Kilit: once dernek, sonra kullanici, sonra basvuru.
 perform oyun.dernek_yetkili(d.id,p.id);
 select * into d from oyun.dernekler where id=d.id and not kapali for update;
 if d.id is null then raise exception 'Dernek kapalı.'; end if;
 select * into a from oyun.dernek_uye_destek where id=p_basvuru and dernek_id=d.id for update;
 if a.id is null or a.durum<>'bekliyor' then raise exception 'Başvuru artık beklemede değil.'; end if;
 if a.basvuran=p.id then raise exception 'Kendi destek başvurunu onaylayamaz veya değerlendiremezsin.'; end if;
 if a.basvuru<t-interval '7 days' then raise exception 'Süresi dolan başvuruyu üye yeniden açmalı.'; end if;
 if p_onay is distinct from true then
  update oyun.dernek_uye_destek set durum='red',karari_veren=p.id,karartarihi=t,
   ret_gerekcesi=left(coalesce(nullif(btrim(p_gerekce),''),'Dernek yönetimi başvuruyu reddetti.'),250)
  where id=a.id;
  perform oyun.bildir(a.basvuran,format('%s üyelik destek başvurun reddedildi.',d.ad),t);
  return jsonb_build_object('tamam',true,'durum','red');
 end if;
 perform pg_advisory_xact_lock(hashtextextended(a.basvuran::text,651201));
 -- Basvuru var diye uygunlukta bekleyen basvuru kontrolunu gecici olarak ayir:
 -- uyelik/kanit/sure/tutar kontrollerinin hepsi asagidaki fonksiyonla tekrar edilir.
 -- Kontrol bekleyen kaydi dislamasi icin sadece bu basvuruyu tanimlayan baglam kullanilir.
 perform set_config('oyun.dernek_destek_karar_id',a.id::text,true);
 uygun:=oyun.dernek_destek_kontrol(d.id,a.basvuran,a.tur,a.referans_id);
 if a.tutar>(uygun->>'ust_limit')::numeric then raise exception 'Kanıt/limit güncellendi; artık bu tutar ödenemez.'; end if;
 select coalesce(sum(tutar),0) into harcanan from oyun.dernek_uye_destek
   where dernek_id=d.id and durum='onay' and karartarihi>t-interval '7 days';
 haftalik_limit:=least(15000, greatest(2000, floor((oyun.dernek_serbest_kasa(d.id)+harcanan)*0.35)));
 if harcanan+a.tutar>haftalik_limit then
  raise exception 'Derneğin son 7 günlük üye destek kotası % TL, kullanılmış % TL.',oyun.tl(haftalik_limit),oyun.tl(harcanan);
 end if;
 if oyun.dernek_serbest_kasa(d.id)<a.tutar then
  raise exception 'Serbest dernek kasası yetersiz. Kampanya bağışları üyeye nakit dağıtılamaz.';
 end if;
 update oyun.dernekler set kasa=kasa-a.tutar where id=d.id and kasa>=a.tutar;
 if not found then raise exception 'Dernek bakiyesi yetersiz.'; end if;
 perform oyun.para_islem(a.basvuran,a.tutar,'dernek',
   format('%s üye desteği (%s), başvuru #%s',d.ad,a.tur,a.id),t);
 update oyun.dernek_uye_destek set durum='onay',karari_veren=p.id,karartarihi=t where id=a.id;
 insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id)
 values(d.id,t,-a.tutar,'uye_destek',format('Üye desteği #%s · %s · onaylayan %s',a.id,a.tur,p.kad),a.basvuran);
 perform oyun.bildir(a.basvuran,format('%s %s TL tutarındaki %s desteğini onayladı. Para cüzdanına aktarıldı.',
 d.ad,oyun.tl(a.tutar),a.tur),t);
 return jsonb_build_object('tamam',true,'durum','onay','tutar',a.tutar,'basvuru',a.id);
end $$;

-- Yukaridaki onay kontrolunde yalniz karar verilen basvuru bekleyenler arasindan dislanir.
create or replace function oyun.dernek_destek_kontrol(p_dernek bigint,p_kisi uuid,p_tur text,p_referans bigint default null)
returns jsonb language plpgsql stable set search_path='' as $$
declare d oyun.dernekler; u oyun.profiller; uye oyun.dernek_uyeler; t timestamptz := oyun.simdi();
 limit_tl numeric; nakit numeric; masraf numeric; x oyun.dernek_programlar; etkin oyun.dernek_etkinlikler;
 disla_id bigint:=nullif(current_setting('oyun.dernek_destek_karar_id',true),'')::bigint;
begin
 select * into d from oyun.dernekler where id=p_dernek and not kapali;
 if d.id is null then raise exception 'Dernek bulunamadı veya kapalı.'; end if;
 select * into uye from oyun.dernek_uyeler where dernek_id=p_dernek and user_id=p_kisi;
 if uye.user_id is null then raise exception 'Bu derneğin üyesi değilsin.'; end if;
 if uye.katilim>t-interval '24 hours' then raise exception 'Destek için en az 24 saatlik üyelik gerekir.'; end if;
 select * into u from oyun.profiller where id=p_kisi and not yasakli;
 if u.id is null or u.olusturma>t-interval '48 hours' then raise exception 'Hesap en az 48 saatlik ve aktif olmalı.'; end if;
 if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and durum='onay' and karartarihi>t-interval '7 days') then
  raise exception 'Son 7 günde dernek desteği aldın; yeniden başvuru zamanı gelmedi.'; end if;
 if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and tur=p_tur and durum='onay' and karartarihi>t-interval '21 days') then
  raise exception 'Aynı destek türüne 21 gün içinde tekrar başvurulamaz.'; end if;
 if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and durum='bekliyor'
    and (disla_id is null or id<>disla_id)) then raise exception 'Önce bekleyen destek başvurun sonuçlanmalı.'; end if;
 case p_tur
 when 'ihtiyac' then
  select coalesce((select para from oyun.cuzdan where user_id=p_kisi),0)
   +coalesce((select vadesiz from oyun.banka_musteri where user_id=p_kisi),0)
   +coalesce((select sum(anapara) from oyun.banka_mevduat where user_id=p_kisi and not kapandi and not iptal),0)
   into nakit;
  if nakit>12000 then raise exception 'İhtiyaç desteği için cüzdan ve banka toplamın en fazla 12.000 TL olmalı.'; end if;
  if exists(select 1 from oyun.mulkler where user_id=p_kisi)
  or exists(select 1 from oyun.yatirim_mulkleri where user_id=p_kisi)
  or exists(select 1 from oyun.sirket_ortaklari where user_id=p_kisi and pay>0)
  or exists(select 1 from oyun.sirketler where kurucu=p_kisi and aktif)
  or exists(select 1 from oyun.piyasa_pozisyon where user_id=p_kisi and miktar>0) then
   raise exception 'İhtiyaç desteği için mülkün, şirket ortaklığın veya yatırımın bulunmamalı.'; end if;
  if p_referans is not null then raise exception 'İhtiyaç desteği için kanıt kaydı seçme.'; end if;
  limit_tl:=2000;
 when 'tasinma' then
  if p_referans is not null then raise exception 'Taşınma için kanıt kaydı seçme.'; end if;
  if u.son_il_degis is null or u.son_il_degis<t-interval '14 days' or u.son_il_degis>t then
   raise exception 'Son 14 gün içinde şehir değiştirmiş olmalısın.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where basvuran=p_kisi and tur='tasinma'
   and durum='onay' and karartarihi>u.son_il_degis) then raise exception 'Bu taşınma için destek aldın.'; end if;
  limit_tl:=1500;
 when 'hukuk' then
  if p_referans is null then raise exception 'Ödenmiş dava harcı seç.'; end if;
  select abs(h.tutar) into masraf from oyun.hesap_hareket h where h.id=p_referans and h.user_id=p_kisi
   and h.tur='adliye' and h.tutar<0 and h.zaman>=t-interval '14 days' and h.zaman<=t
   and (h.aciklama ilike '%harç%' or h.aciklama ilike '%harc%');
  if masraf is null then raise exception 'Son 14 günde ödenmiş dava harcı bulunamadı.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where tur='hukuk' and referans_id=p_referans
    and basvuran=p_kisi and durum='onay') then raise exception 'Bu harç için zaten destek ödendi.'; end if;
  limit_tl:=least(4000,floor(masraf*.60));
 when 'egitim' then
  if p_referans is null then raise exception 'Eğitim programını seç.'; end if;
  select z.* into x from oyun.dernek_programlar z join oyun.dernek_program_katilim k
   on k.program_id=z.id and k.user_id=p_kisi
   where z.id=p_referans and z.dernek_id=p_dernek and z.tur in ('etut','meslek')
   and z.bas<=t-interval '2 hours' and z.bit>=t-interval '14 days' and k.zaman<=t-interval '2 hours';
  if x.id is null then raise exception 'En az iki saatlik eğitim programı katılımı gerekir.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where tur='egitim' and referans_id=p_referans
    and basvuran=p_kisi and durum='onay') then raise exception 'Bu eğitim için zaten ödeme yapıldı.'; end if;
  limit_tl:=1800;
 when 'gonullu' then
  if p_referans is null then raise exception 'Gönüllü etkinliğini seç.'; end if;
  select z.* into etkin from oyun.dernek_etkinlikler z join oyun.dernek_gonulluler k
   on k.etkinlik_id=z.id and k.user_id=p_kisi
   where z.id=p_referans and z.dernek_id=p_dernek and z.bit<=t
   and z.bit>=t-interval '14 days' and k.zaman<=z.bit;
  if etkin.id is null then raise exception 'Katıldığın ve tamamlanmış gönüllü etkinliği bulunamadı.'; end if;
  if exists(select 1 from oyun.dernek_uye_destek where tur='gonullu' and referans_id=p_referans
    and basvuran=p_kisi and durum='onay') then raise exception 'Bu etkinlik için zaten ödeme yapıldı.'; end if;
  limit_tl:=1200;
 else raise exception 'Geçersiz destek türü.';
 end case;
 if limit_tl<100 then raise exception 'Harcamanın destek limiti 100 TL altında.'; end if;
 return jsonb_build_object('ust_limit',limit_tl,'uygun',true);
end $$;
revoke execute on function oyun.dernek_destek_kontrol(bigint,uuid,text,bigint) from public,anon,authenticated;

create or replace function public.dernek_uye_destek_liste(p_dernek bigint)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); d oyun.dernekler; yetkili boolean; uyelik boolean; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into d from oyun.dernekler where id=p_dernek;
 if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
 select exists(select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=u) into uyelik;
 select exists(select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=u and rol in ('baskan','yonetim')) into yetkili;
 if not uyelik then raise exception 'Üye olmadığın derneğin desteklerini göremezsin.'; end if;
 return jsonb_build_object(
  'yetkili',yetkili,
  'kasa',d.kasa,
  'serbest',oyun.dernek_serbest_kasa(d.id),
  'talepler',coalesce((select jsonb_agg(jsonb_build_object(
    'id',a.id,'tur',a.tur,'tutar',a.tutar,'aciklama',a.aciklama,'durum',a.durum,
    'basvuru',a.basvuru,'karar',a.karartarihi,'uye',k.kad,'benim',a.basvuran=u,
    'degerlendirebilirim',yetkili and a.basvuran<>u and a.durum='bekliyor' and a.basvuru>=t-interval '7 days',
    'ret_gerekcesi',a.ret_gerekcesi
  ) order by a.basvuru desc)
  from (select * from oyun.dernek_uye_destek
    where dernek_id=d.id and (basvuran=u or yetkili)
    order by basvuru desc limit 45) a
  join oyun.profiller k on k.id=a.basvuran),'[]'::jsonb),
  'kanitlar',jsonb_build_object(
   'hukuk',coalesce((select jsonb_agg(jsonb_build_object('id',h.id,'ad',left(h.aciklama,120),
     'tutar',abs(h.tutar),'zaman',h.zaman) order by h.zaman desc)
     from (select * from oyun.hesap_hareket where user_id=u and tur='adliye' and tutar<0
       and zaman>=t-interval '14 days' and (aciklama ilike '%harç%' or aciklama ilike '%harc%')
       order by zaman desc limit 15) h),'[]'::jsonb),
   'egitim',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'ad',p.tur,'zaman',k.zaman)
     order by k.zaman desc) from oyun.dernek_program_katilim k
     join oyun.dernek_programlar p on p.id=k.program_id
     where p.dernek_id=d.id and p.tur in ('etut','meslek')
      and p.bas<=t-interval '2 hours' and k.zaman<=t-interval '2 hours' and p.bit>=t-interval '14 days'
      and k.user_id=u),'[]'::jsonb),
   'gonullu',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'ad',e.baslik,'zaman',e.bit)
     order by e.bit desc) from oyun.dernek_gonulluler k
     join oyun.dernek_etkinlikler e on e.id=k.etkinlik_id
     where e.dernek_id=d.id and e.bit<=t and e.bit>=t-interval '14 days'
      and k.zaman<=e.bit and k.user_id=u),'[]'::jsonb)
  )
 );
end $$;

revoke execute on function public.dernek_uye_destek_basvur(bigint,text,numeric,text,bigint) from public,anon;
revoke execute on function public.dernek_uye_destek_karar(bigint,boolean,text) from public,anon;
revoke execute on function public.dernek_uye_destek_liste(bigint) from public,anon;
grant execute on function public.dernek_uye_destek_basvur(bigint,text,numeric,text,bigint) to authenticated;
grant execute on function public.dernek_uye_destek_karar(bigint,boolean,text) to authenticated;
grant execute on function public.dernek_uye_destek_liste(bigint) to authenticated;
