-- =====================================================================
--  114 · HESAP SİLME (App Store 5.1.1(v) ve Google Play hesap silme şartı)
--  Eski hesabimi_sil, oyun geçmişinde iz bırakmış oyuncularda (gazete yazısı, anket oyu, erken seçim oyu,
--  şirket, kanun teklifi…) yabancı anahtar kısıtına takılıp HİÇ SİLMİYORDU (22.10.2026: denenen 6 aktif
--  oyuncunun 6'sında hata). Yeni sürüm:
--   1) görevleri bitirir, partiden ayırır, bekleyen adaylıkları siler, oyların kimliğini koparır,
--      mesaj/özel mesaj/yayın/bildirim/engelleme, push anahtarı, cihaz-IP izi, biyografi ve portreyi siler;
--   2) profili tamamen silmeyi dener; oyun kayıtları buna izin vermiyorsa profili KİMLİKSİZLEŞTİRİR:
--      kullanıcı adı "Silinmis_XXXXXX" olur, hesap kapanır; giriş hesabının e-postası, şifresi, kimlik
--      sağlayıcı kayıtları ve oturumları silinir — kişiyi tanımlayan hiçbir veri kalmaz.
-- =====================================================================
create or replace function public.hesabimi_sil() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare u uuid := oyun.ben(); t timestamptz := oyun.simdi(); m record; tam boolean := false;
begin
  for m in select id from oyun.makamlar where user_id = u and bit is null loop
    perform oyun.makam_bitir(m.id, t, 'hesap_silindi');
  end loop;
  perform oyun._ayril(u, t);
  delete from oyun.adaylar a using oyun.secimler s where a.secim_id = s.id and a.user_id = u and s.durum = 'bekliyor';
  update oyun.oylar set secmen = gen_random_uuid() where secmen = u;   -- oy sayısı korunur, kimlik kopar
  delete from oyun.mesajlar where user_id = u;
  delete from oyun.ozel where gonderen = u or alici = u;
  delete from oyun.yayinlar where gonderen = u;
  delete from oyun.bildirimler where user_id = u;
  delete from oyun.engellemeler where engelleyen = u or engellenen = u;
  delete from oyun.cihazlar where user_id = u;
  delete from oyun.moderatorler where user_id = u;
  if to_regclass('oyun.oturumlar') is not null then execute 'delete from oyun.oturumlar where user_id = $1' using u; end if;
  if to_regclass('oyun.oyuncu_kimlik') is not null then execute 'delete from oyun.oyuncu_kimlik where user_id = $1' using u; end if;
  if to_regclass('oyun_yonetim.kayit_basvurulari') is not null then execute 'delete from oyun_yonetim.kayit_basvurulari where user_id = $1' using u; end if;
  -- Tam silme (oyun kayıtlarına bağlı değilse)
  begin
    delete from oyun.profiller where id = u;
    delete from auth.users where id = u;
    tam := true;
  exception when foreign_key_violation then tam := false;
  end;
  if not tam then
    -- Kimliksizleştirme: kayıtlar (şirket, gazete, kanun, oy geçmişi) "Silinmis_…" adına kalır
    update oyun.profiller
       set kad = 'Silinmis_' || upper(substr(md5(u::text || clock_timestamp()::text), 1, 6)),
           yasakli = true, engel_bitis = null, engel_neden = 'Hesap sahibi tarafından silindi',
           susturma_bitis = null, son_gorulme = null,
           bildirim_ayar = '{"secim":false,"ozel":false,"propaganda":false,"kisisel":false}'::jsonb
     where id = u;
    update auth.users
       set email = u::text || '@silindi.invalid', phone = null, encrypted_password = md5(gen_random_uuid()::text),
           raw_user_meta_data = '{}'::jsonb, banned_until = 'infinity', email_change = '', email_change_token_new = '',
           recovery_token = '', confirmation_token = ''
     where id = u;
    delete from auth.identities where user_id = u;
    delete from auth.sessions where user_id = u;
  end if;
  return jsonb_build_object('silindi', true, 'tam', tam);
end $$;
revoke all on function public.hesabimi_sil() from public, anon;
grant execute on function public.hesabimi_sil() to authenticated;
