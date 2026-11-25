-- Canlı Supabase migration adı: dernek_il_baskani_kitap_yayinevi_20261125
-- DURUM (25.11.2026 13:45): canlıya UYGULANDI. Bu dosya depo eşitlemesidir; tekrar çalıştırmak güvenlidir.
-- Kaynak: gelistirici/sql/zz_20261125_dernek_il_baskani.sql + zz_20261125_kitap_yayinevi_degistir.sql
begin;
select set_config('lock_timeout', '4s', true);

-- 25.11.2026 · DERNEKLERDE İL BAŞKANLIĞI (sürüm 2026.11.25-2)
-- İstek (destek talebi #69, Ercan "ekle"): "Derneklere il başkanlığı getirilmeli, üyeleri il başkanı yapabilmeliyiz."
--   • Derneğin şubesi olan her ile bir İL BAŞKANI atanabilir. Atamayı yalnız dernek başkanı yapar.
--   • İl başkanı derneğin üyesi olmalı ve O İLDE kayıtlı olmalı (şube o ilde yaşayanlarca yürütülür); başkanın kendisi olamaz.
--   • Yetki: il başkanı KENDİ İLİNDE dernek adına protesto düzenleyebilir (derneğin günlük/il başına protesto sınırları aynen geçerli).
--     Açıklama, şube açma, kasa ve üyelik işleri başkan ve yönetim kurulunda kalır.
--   • Görev kendiliğinden düşer: üye dernekten ayrılırsa, başka ile taşınırsa ya da derneğin başkanı olursa.
--   • Yayın ölçeği: aynı şubeye 10 dakikada bir atama (bildirimle rahatsız etme yolu olmasın); görev değişikliği Gündem'e haber
--     yazmaz (81 şubeli derneklerde akışı doldurmasın), yalnız ilgili oyuncuya bildirim gider.
-- Oyuncu verisi değişmez: dernek_sube'ye iki boş sütun eklenir. Tekrar çalıştırmak güvenlidir. oyun._yama kullanır.
-- Ekran: gelistirici/www/dernek_vitrini.js ("İL BAŞKANLIĞI").

alter table oyun.dernek_sube add column if not exists il_baskani uuid;
alter table oyun.dernek_sube add column if not exists il_baskani_at timestamptz;
create index if not exists dernek_sube_il_baskani on oyun.dernek_sube(il_baskani) where il_baskani is not null;

create or replace function public.dernek_il_baskani_ata(p_dernek bigint, p_il integer, p_kad text) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; s oyun.dernek_sube; h oyun.profiller; ilad text;
begin
  select * into d from oyun.dernekler where id = p_dernek and not kapali for update;
  if d.id is null or d.baskan is distinct from p.id then raise exception 'İl başkanını yalnız derneğin başkanı belirler.'; end if;
  select ad into ilad from oyun.iller where id = p_il;
  select * into s from oyun.dernek_sube where dernek_id = d.id and il_id = p_il for update;
  if s.dernek_id is null then raise exception 'Derneğin % ilinde şubesi yok; önce şube açmalısın.', coalesce(ilad, 'bu'); end if;

  if coalesce(btrim(p_kad), '') = '' then                                   -- görevden alma
    if s.il_baskani is null then raise exception '% şubesinin il başkanı zaten yok.', ilad; end if;
    update oyun.dernek_sube set il_baskani = null where dernek_id = d.id and il_id = p_il;
    perform oyun.bildir(s.il_baskani, format('%s %s il başkanlığı görevin sona erdi.', d.ad, ilad), t);
    return public.dernek_detay(d.id);
  end if;

  h := oyun.profil_bul(p_kad);
  if h.id = d.baskan then raise exception 'Dernek başkanı ayrıca il başkanı olamaz.'; end if;
  if not exists (select 1 from oyun.dernek_uyeler where dernek_id = d.id and user_id = h.id) then raise exception 'Bu oyuncu derneğin üyesi değil.'; end if;
  if h.il_id is distinct from p_il then raise exception '% % ilinde kayıtlı değil. İl başkanı o ilde yaşayan üyelerden seçilir.', h.kad, ilad; end if;
  if s.il_baskani = h.id then raise exception '% zaten % il başkanı.', h.kad, ilad; end if;
  if s.il_baskani_at is not null and s.il_baskani_at > t - interval '10 minutes' then
    raise exception '% il başkanı az önce atandı; yeni atama için % saatini bekle.', ilad, to_char((s.il_baskani_at + interval '10 minutes') at time zone 'Europe/Istanbul', 'HH24:MI');
  end if;
  update oyun.dernek_sube set il_baskani = null where dernek_id = d.id and il_baskani = h.id;
  update oyun.dernek_sube set il_baskani = h.id, il_baskani_at = t where dernek_id = d.id and il_id = p_il;
  if s.il_baskani is not null then
    perform oyun.bildir(s.il_baskani, format('%s %s il başkanlığı görevin sona erdi.', d.ad, ilad), t);
  end if;
  perform oyun.bildir(h.id, format('%s %s il başkanlığına atandın. Artık %s ilinde dernek adına protesto düzenleyebilirsin.', d.ad, ilad, ilad), t);
  return public.dernek_detay(d.id);
end $f$;

revoke all on function public.dernek_il_baskani_ata(bigint, integer, text) from public, anon;
grant execute on function public.dernek_il_baskani_ata(bigint, integer, text) to authenticated;

-- Görev kendiliğinden düşer: üyelik bitince, il değişince, kişi derneğin başkanı olunca.
create or replace function oyun.dernek_ilb_uye_tg() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  update oyun.dernek_sube set il_baskani = null where dernek_id = old.dernek_id and il_baskani = old.user_id;
  return old;
end $f$;
drop trigger if exists dernek_ilb_uye on oyun.dernek_uyeler;
create trigger dernek_ilb_uye after delete on oyun.dernek_uyeler for each row execute function oyun.dernek_ilb_uye_tg();

create or replace function oyun.dernek_ilb_profil_tg() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  update oyun.dernek_sube set il_baskani = null where il_baskani = new.id and il_id is distinct from new.il_id;
  return new;
end $f$;
drop trigger if exists dernek_ilb_profil on oyun.profiller;
create trigger dernek_ilb_profil after update of il_id on oyun.profiller for each row when (new.il_id is distinct from old.il_id)
  execute function oyun.dernek_ilb_profil_tg();

create or replace function oyun.dernek_ilb_baskan_tg() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  update oyun.dernek_sube set il_baskani = null where dernek_id = new.id and il_baskani = new.baskan;
  return new;
end $f$;
drop trigger if exists dernek_ilb_baskan on oyun.dernekler;
create trigger dernek_ilb_baskan after update of baskan on oyun.dernekler for each row when (new.baskan is not null and new.baskan is distinct from old.baskan)
  execute function oyun.dernek_ilb_baskan_tg();

revoke all on function oyun.dernek_ilb_uye_tg(), oyun.dernek_ilb_profil_tg(), oyun.dernek_ilb_baskan_tg() from public, anon, authenticated;

-- dernek_detay: şubede il başkanı, üyede il başkanlığı işareti, okuyanın kendi il başkanlığı.
select oyun._yama('public.dernek_detay(bigint)',
  $a$'harc', oyun.dernek_harci(),$a$,
  $b$'harc', oyun.dernek_harci(),
    'il_baskanligim', (select sb.il_id from oyun.dernek_sube sb where sb.dernek_id = d.id and sb.il_baskani = u limit 1),$b$,
  'il_baskanligim', true);
select oyun._yama('public.dernek_detay(bigint)',
  $a$jsonb_build_object('kad', pr.kad, 'il', i.ad, 'rol', x.rol)$a$,
  $b$jsonb_build_object('kad', pr.kad, 'il', i.ad, 'rol', x.rol, 'il_id', pr.il_id, 'il_baskani', exists (select 1 from oyun.dernek_sube sb where sb.dernek_id = d.id and sb.il_baskani = x.user_id))$b$,
  $c$'il_baskani', exists$c$, true);
select oyun._yama('public.dernek_detay(bigint)',
  $a$jsonb_build_object('il_id', s.il_id, 'il', i.ad, 'merkez', s.il_id = d.merkez_il)$a$,
  $b$jsonb_build_object('il_id', s.il_id, 'il', i.ad, 'merkez', s.il_id = d.merkez_il, 'il_baskani', oyun.kad(s.il_baskani))$b$,
  $c$'il_baskani', oyun.kad$c$, true);

-- dernek_eylem: il başkanı kendi ilinde protesto düzenleyebilir.
select oyun._yama('public.dernek_eylem(bigint,text,text,text,text,text,integer,timestamp with time zone)',
  $a$  d := oyun.dernek_yetkili(p_dernek, p.id);$a$,
  $b$  if p_tur = 'protesto' and p_il is not null and exists (select 1 from oyun.dernek_sube sb where sb.dernek_id = p_dernek and sb.il_id = p_il and sb.il_baskani = p.id) then
    select * into d from oyun.dernekler where id = p_dernek and not kapali;   -- il başkanı: yalnız kendi ilinde protesto
    if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  else
    d := oyun.dernek_yetkili(p_dernek, p.id);
  end if;$b$,
  'sb.il_baskani = p.id', true);

-- 25.11.2026 · KİTAP: YAYINEVİ SAHİBİ, İNCELEME SÜRESİ, YAYINEVİ DEĞİŞTİRME (sürüm 2026.11.25-2)
-- İstek (destek talebi #71, Ercan "ekle"): "Yayınevlerinin sahiplerini görmek istiyoruz. Kitabı yayınevine gönderdiğimizde
-- inceleme sürelerini görüp belli şartlarda yayınevi değiştirebilme hakkı olursa iyi olabilir."
--   • uc_kitap_panel › yayinevleri: sahip (payı en yüksek yönetici ortak), bekleyen dosya ve yayımlanan kitap sayısı.
--   • uc_kitap_panel › kitaplar: gonderim (dosyanın bu yayınevine ulaştığı an), degisim_saat (24), yayinevi_sahip.
--   • uc_kitap_islem 'yayinevi_degistir' {yayinevi}: yalnız yazar. Şartlar:
--       - yayımlanmış kitap taşınamaz;
--       - REDDEDİLEN dosya hemen başka yayınevine gönderilebilir;
--       - BEKLEYEN dosya, yayınevine 24 saat inceleme süresi tanındıktan sonra taşınabilir (süre her taşımada yeniden başlar);
--       - en çok 5 bekleyen dosya kuralı reddedilen dosyayı yeniden gönderirken de geçerli;
--       - yönetimce yayını durdurulmuş yayınevine dosya taşınamaz.
-- Oyuncu verisi değişmez: uc_kitap'a boş bir sütun eklenir. Tekrar çalıştırmak güvenlidir. oyun._yama kullanır.
-- Ekran: gelistirici/www/uc_ekonomi_yeni.js ("YAYINEVİ DEĞİŞTİR").

alter table oyun.uc_kitap add column if not exists gonderim timestamptz;

select oyun._yama('public.uc_kitap_panel()',
  $a$jsonb_build_object('id',id,'ad',ad,'kasa',oyun.kasa_goster('sirket',id,kasa))$a$,
  $b$jsonb_build_object('id',id,'ad',ad,'kasa',oyun.kasa_goster('sirket',id,kasa),
    'sahip',(select oyun.kad(so.user_id) from oyun.sirket_ortaklari so where so.sirket_id=sirketler.id and so.pay>=50 order by so.pay desc, so.user_id limit 1),
    'bekleyen',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='teklif'),
    'yayinlanan',(select count(*) from oyun.uc_kitap bk where bk.yayinevi=sirketler.id and bk.durum='yayinda'))$b$,
  $c$'sahip',(select oyun.kad$c$, true);
select oyun._yama('public.uc_kitap_panel()',
  $a$'fiyat_son_degisim',k.fiyat_son_degisim$a$,
  $b$'fiyat_son_degisim',k.fiyat_son_degisim,
  'gonderim',coalesce(k.gonderim,k.olusturma),'degisim_saat',24,
  'yayinevi_sahip',(select oyun.kad(so.user_id) from oyun.sirket_ortaklari so where so.sirket_id=k.yayinevi and so.pay>=50 order by so.pay desc, so.user_id limit 1)$b$,
  $c$'degisim_saat',24$c$, true);

select oyun._yama('public.uc_kitap_islem(text,bigint,jsonb)',
  $a$  select * into s from oyun.sirketler
    where id=k.yayinevi and aktif for update;$a$,
  $b$  if p_islem = 'yayinevi_degistir' then
    if k.yazar <> u then raise exception 'Yayınevini yalnızca kitabın yazarı değiştirebilir'; end if;
    if k.durum not in ('teklif','reddedildi') then raise exception 'Yayımlanmış kitabın yayınevi değiştirilemez'; end if;
    if k.durum = 'teklif' and coalesce(k.gonderim, k.olusturma) > t - interval '24 hours' then
      raise exception 'Yayınevinin dosyanı incelemesi için 24 saati var. Kitabını % saatinden sonra başka yayınevine taşıyabilirsin',
        to_char((coalesce(k.gonderim, k.olusturma) + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
    end if;
    bid := case when coalesce(p_veri->>'yayinevi','') ~ '^[0-9]{1,15}$' then (p_veri->>'yayinevi')::bigint end;
    if bid is null or bid = k.yayinevi then raise exception 'Farklı bir yayınevi seç'; end if;
    select * into s from oyun.sirketler where id = bid and sektor = 'medya' and aktif;
    if s.id is null then raise exception 'Yayınevi bulunamadı'; end if;
    if to_regprocedure('oyun.kurum_durdurma_aktif(text,bigint)') is not null then
      execute 'select (oyun.kurum_durdurma_aktif($1, $2)).id' into expense using 'sirket', s.id;
      if expense is not null then raise exception 'Bu yayınevinin yayın ve faaliyetleri oyun yönetimi kararıyla durduruldu; başka bir yayınevi seç'; end if;
    end if;
    if k.durum = 'reddedildi' and (select count(*) from oyun.uc_kitap where yazar=u and durum='teklif') >= 5
    then raise exception 'En fazla 5 bekleyen kitap teklifi olabilir'; end if;
    update oyun.uc_kitap set yayinevi = s.id, durum = 'teklif', gonderim = t where id = k.id;
    return jsonb_build_object('durum','teklif','yayinevi',s.id,'yayinevi_ad',s.ad);
  end if;

  select * into s from oyun.sirketler
    where id=k.yayinevi and aktif for update;$b$,
  $c$p_islem = 'yayinevi_degistir'$c$, true);

commit;
