-- CANLIDA UYGULANMIS, TEK SEFERLIK SEÇIM TAKVIMI DÜZELTMESI
-- Supabase migration: 20261116053423 / gecersiz_erken_secim_6_iptal_aralik_2026_geri_ac
-- Tarih: 16 Kasim 2026. Bu dosya SQL kurulum birlestiricisine EKLENMEZ.
-- Neden: Önerge #6 yalnız 6 kabul oyuyla geçti (600 üyelik TBMM'de yasal eşik 360).
-- Hedef: Erken-genel-6-20261115234022 dört kaydı (mv_on/cb_on/mv/cb) iptal,
-- normal 2026-12 dört kaydı eski erken-seçim iptalinden geri yükle.
-- Tarihsel aday, oy, seçmen, makam, parti, cüzdan verisini silmez.
-- ÖNEMLİ: Yalnız hedef olay ve önceki durum doğrulandıktan sonra çalışır.
-- Oyun/DB sıfırlaması için kullanılmaz; kalıcı kaynak / denetim kopyasıdır.

create table if not exists oyun_yonetim.secim_takvim_iptal_audit (
  operasyon text primary key,
  kayit_zamani timestamptz not null default now(),
  aciklama text not null,
  onceki_secimler jsonb not null,
  onceki_teklif jsonb not null
);
revoke all on oyun_yonetim.secim_takvim_iptal_audit from public, anon, authenticated;
alter table oyun_yonetim.secim_takvim_iptal_audit enable row level security;

do $iptal$
declare
 v_onay integer;
 v_gerekli integer;
 v_erken integer;
 v_normal integer;
 v_satir integer;
 v_nomal_oylar integer;
 v_tarih timestamptz:=oyun.simdi();
 v_erken_donem text:='erken-genel-6-20261115234022';
begin
 perform 1 from oyun.ayarlar where id=1 for update;
 perform 1 from oyun.erken_secim_teklifleri where id=6 for update;
 perform 1 from oyun.secimler where donem in (v_erken_donem,'2026-12') and tur in ('mv_on','cb_on','mv','cb') order by id for update;
 select count(*) into v_onay from oyun.erken_secim_oylari where teklif_id=6 and oy='kabul';
 v_gerekli:=oyun.erken_secim_gerekli_oy();
 if not oyun.gercekci_siyaset() or v_gerekli<>360 or v_onay<>6 then
   raise exception 'Hukuk dogrulama basarisiz. Onay: %, gerekli: %',v_onay,v_gerekli;
 end if;
 if not exists(select 1 from oyun.erken_secim_teklifleri where id=6 and durum='kabul' and secim_donem=v_erken_donem) then
   raise exception 'Hedef erken secim onergesi beklenen durumda degil; islem geri alindi.';
 end if;
 select count(*) into v_erken from oyun.secimler
  where donem=v_erken_donem and tur in ('mv_on','cb_on','mv','cb') and durum='bekliyor'
    and ara and ara_neden='erken_secim' and sonuc is null;
 select count(*) into v_normal from oyun.secimler
  where donem='2026-12' and tur in ('mv_on','cb_on','mv','cb')
    and durum='tamam' and sonuc->>'iptal'='erken_secim' and not ara;
 if v_erken<>4 or v_normal<>4 then
    raise exception 'Hedef secim sayilari beklenmedik: erken %, Aralik %, islem geri alindi.',v_erken,v_normal;
 end if;
 select count(*) into v_nomal_oylar from oyun.oylar where secim_id in (
   select id from oyun.secimler where donem='2026-12' and tur in ('mv_on','cb_on','mv','cb'));
 if v_nomal_oylar<>0 then raise exception 'Normal Aralik seciminde oylar var, otomatik geri yukleme guvenli degil.'; end if;

 insert into oyun_yonetim.secim_takvim_iptal_audit(operasyon,aciklama,onceki_secimler,onceki_teklif)
 values('20261116_gecersiz_erken_secim_6',
  'Eski kurala gore 6 kabul ile gecmis erken secimin iptali ve 1 Aralik normal seciminin geri acilmasi',
  (select coalesce(jsonb_agg(to_jsonb(s) order by s.id),'[]'::jsonb) from oyun.secimler s
   where s.donem in (v_erken_donem,'2026-12') and s.tur in ('mv_on','cb_on','mv','cb')),
  (select to_jsonb(o) from oyun.erken_secim_teklifleri o where o.id=6));
 if not found then raise exception 'Bu secim iptal islemi onceden uygulanmis; tekrar denenmiyor.'; end if;

 update oyun.secimler
  set durum='tamam',sonuc=jsonb_build_object('iptal','gerekli_360_oy_saglanmadi','kabul',v_onay,'gerekli',v_gerekli,
    'aciklama','Eski beta kuraliyla acilan erken secim iptal edildi; 1 Aralik normal genel secimi gecerlidir.'),
    sonuc_at=v_tarih
  where donem=v_erken_donem and tur in ('mv_on','cb_on','mv','cb') and durum='bekliyor';
 get diagnostics v_satir = row_count;
 if v_satir<>4 then raise exception 'Erken secimde beklenmedik degisiklik: %',v_satir; end if;

 update oyun.erken_secim_teklifleri set durum='ret'
  where id=6 and durum='kabul' and secim_donem=v_erken_donem;
 if not found then raise exception 'Gecersiz onerge durum degisimi basarisiz'; end if;

 update oyun.secimler
  set durum='bekliyor',sonuc=null
  where donem='2026-12' and tur in ('mv_on','cb_on','mv','cb')
    and durum='tamam' and sonuc->>'iptal'='erken_secim' and not ara;
 get diagnostics v_satir=row_count;
 if v_satir<>4 then raise exception 'Normal Aralik secimi geri acilmadi: %',v_satir; end if;

 perform oyun.olay('secim',
   '6 kabul oyuyla alinan erken secim karari, 360 oy sarti saglanmadigi icin iptal edildi. 17 Kasim on secim ve 18 Kasim genel secim yapilmayacak. Bir sonraki genel secim 1 Aralik 2026 tarihindedir.',
   null,null,v_tarih);
end $iptal$;
