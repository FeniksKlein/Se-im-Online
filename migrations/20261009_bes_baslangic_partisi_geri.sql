-- 2026-10-09: Oyun sifirlamasindan sonra varsayilan bes kurgusal partiyi yeniden kur.
-- Sadece sistem partileri ve 81 ildeki baslangic teskilatlari eklenir.
-- Oyunculara, mevcut parti uyeliklerine, bakiyelere ve secim takvimine dokunulmaz.
-- Tekrar calistirildiginda oyuncu degisikliklerini ezmez.
begin;

select pg_advisory_xact_lock(2026100905);

do $parti_oncesi$
declare adet int;
begin
  select count(*) into adet from oyun.partiler where sistem and not kapali;
  if adet not in (0, 5) then
    raise exception 'Sistem partileri beklenmeyen durumda (% adet); otomatik ekleme iptal.', adet;
  end if;

  if adet=0 then
    insert into oyun.partiler(ad,kisa,renk,amblem,sistem,kapali,gb,kurucu,kasa,kurulus)
    values
      ('Cumhuriyet Yolu Partisi','CYP','#c62828','a_ayyildiz',true,false,null,null,0,oyun.simdi()),
      ('Anadolu Birlik Partisi','ABP','#ef8f00','a_basak',true,false,null,null,0,oyun.simdi()),
      ('Yeni Demokrasi Partisi','YDP','#1565c0','a_guvercin',true,false,null,null,0,oyun.simdi()),
      ('Millî Kalkınma Partisi','MKP','#2e7d32','a_cinar',true,false,null,null,0,oyun.simdi()),
      ('Emek ve Özgürlük Partisi','EÖP','#6a1b9a','a_mesale',true,false,null,null,0,oyun.simdi());
  end if;
end
$parti_oncesi$;

-- Eski oyun bu bes sistem partisine 81 il teskilati tanimliyordu.
-- Ankara (06) genel merkez, diger 80 il teskilat; kurucusu yok, ucretsiz.
insert into oyun.parti_teskilat(parti_id,il_id,kurulus,kuran,bedel,genel_merkez)
select p.id, i.id, oyun.simdi(), null::uuid, 0, i.id=6
from oyun.partiler p cross join oyun.iller i
where p.sistem and not p.kapali
  and p.kisa in ('CYP','ABP','YDP','MKP','EÖP')
on conflict (parti_id,il_id) do nothing;

select setval(pg_get_serial_sequence('oyun.partiler','id'),
  greatest(coalesce((select max(id) from oyun.partiler),1),1), true);

do $parti_sonrasi$
begin
  if (select count(*) from oyun.partiler where sistem and not kapali) <> 5
    or (select count(*) from oyun.parti_teskilat t
        join oyun.partiler p on p.id=t.parti_id
        where p.sistem and not p.kapali) <> 405
    or (select count(*) from oyun.parti_teskilat t
        join oyun.partiler p on p.id=t.parti_id
        where p.sistem and t.genel_merkez) <> 5 then
    raise exception 'Parti / teskilat dogrulama basarisiz. Islem geri alinacak.';
  end if;
end
$parti_sonrasi$;

commit;
