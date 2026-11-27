-- 27.11.2026 — Ortak inşaat şirketi kurulamıyordu: "Ruhsat için şirket yönetim yetkisi gerekli." (oyuncu bildirimi, İME İnşaat, 3 ortak)
-- Kök neden: inşaat şirketinin işletme kaydı (oyun.eko_insaat_sirket_tanit) işlem sonunda (DEFERRABLE INITIALLY DEFERRED) eklenir.
--   O anda ortak_sirket_kur_tamamla pay dağılımını yazmış olur; kurucunun payı en büyük ortaktan küçükse
--   oyun.sirket_yonetici_mi(kurucu) false döner ve oyun.bel_ruhsat_kapi işlemi geri çevirir. Kurucu en büyük paya sahipse sorun çıkmıyordu.
-- Düzeltme: ortak_sirket_kur_tamamla, kurduğu şirketin kimliğini işlem-yerel bir ayara yazar (set_config(..., true));
--   ruhsat kapısı yalnız bu işlem içinde, yalnız o şirket ve yalnız kuruluşun kurucusu için yönetim şartını geçer.
--   İşlem bitince ayar kendiliğinden silinir; sonraki yatırımlarda yetki eskisi gibi sirket_yonetici_mi ile belirlenir.
--   Oyuncu verisine dokunulmaz.
do $y$
begin
  perform oyun._yama('public.ortak_sirket_kur_tamamla(bigint)',
    'sid:=\(sonuc->>''id''\)::bigint;',
    'sid:=(sonuc->>''id'')::bigint; /*ORTAK_KURULUS_RUHSAT*/ perform set_config(''oyun.ortak_kurulus_sirket'', sid::text, true);',
    'ORTAK_KURULUS_RUHSAT', false);
  perform oyun._yama('oyun.bel_ruhsat_kapi()',
    'not oyun\.sirket_yonetici_mi\(sid,u\)',
    'not (oyun.sirket_yonetici_mi(sid,u) or /*ORTAK_KURULUS_RUHSAT*/ (coalesce(current_setting(''oyun.ortak_kurulus_sirket'', true), '''') = sid::text and exists(select 1 from oyun.ortak_sirket_kurulus ok where ok.sirket_id=sid and ok.kurucu=u and ok.durum=''kuruldu'')))',
    'ORTAK_KURULUS_RUHSAT', false);
end $y$;
