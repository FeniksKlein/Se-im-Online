-- 26.11.2026 · Yönetim adına yazılan sohbet mesajını silme
--   * Moderatör, "Oyun Yöneticisi G-xx" imzasıyla yazdığı KENDİ mesajını silebilir (yanlış/yarım gönderim).
--   * Oyun kurucusu (yonetici) yönetim adına yazılmış HER mesajı silebilir.
--   * Silme yumuşaktır (gizli = true): kayıt denetim için durur, oyunculardan kalkar. Kurucu geri açabilir.
--   * Her işlem mod_kayit denetim günlüğüne yazılır.
--   * sohbet_oku dönüşündeki 'silebilir' (mesaj başına) ve 'gizlenen' (kanalda son gizlenen mesajlar)
--     alanları zz_20261125_yuk_hizlandirma.sql içindedir; açık sohbet ekranları silinen mesajı anında düşer.

-- Yalnız gizli satırları tutan küçük dizin: sohbet_oku'nun 'gizlenen' listesi her yoklamada birkaç satır okur.
create index if not exists mesajlar_kanal_gizli on oyun.mesajlar (kanal, id desc) where gizli;

create or replace function public.mod_sohbet_sil(p_mesaj bigint, p_geri boolean default false)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.profilim(); m oyun.mesajlar; kurucu boolean;
begin
  if p.id is null or coalesce(p.yasakli, false) then raise exception 'Bu işlem için yetkin yok.'; end if;
  kurucu := coalesce(p.yonetici, false);
  select * into m from oyun.mesajlar where id = p_mesaj for update;
  if m.id is null then raise exception 'Mesaj bulunamadı.'; end if;
  if not m.gorevli then raise exception 'Bu yalnız yönetim adına yazılmış mesajlar içindir. Oyuncu mesajları Mod › Sohbet nöbeti üzerinden gizlenir.'; end if;
  if not (m.user_id = p.id or kurucu) then raise exception 'Yalnız kendi yazdığın yönetim mesajını silebilirsin.'; end if;
  if coalesce(p_geri, false) then
    if not kurucu then raise exception 'Silinen yönetim mesajını yalnız oyun kurucusu geri açabilir.'; end if;
    if not m.gizli then return jsonb_build_object('tamam', true, 'gizli', false); end if;
    update oyun.mesajlar set gizli = false where id = m.id;
  else
    if m.gizli then return jsonb_build_object('tamam', true, 'gizli', true); end if;
    update oyun.mesajlar set gizli = true where id = m.id;
  end if;
  perform oyun.mod_log(p, case when coalesce(p_geri, false) then 'sohbet_resmi_geri' else 'sohbet_resmi_sil' end, m.kanal,
                       oyun.mod_kanal_ad(m.kanal) || ': ' || m.metin);
  -- açık ekranlara haber (canlı sinyal varsa); yoksa bir sonraki yoklamada düşer
  begin perform oyun.canli_sinyal('sohbet:' || m.kanal); exception when others then null; end;
  return jsonb_build_object('tamam', true, 'gizli', not coalesce(p_geri, false), 'kanal', m.kanal);
end $function$;

revoke all on function public.mod_sohbet_sil(bigint, boolean) from public, anon;
grant execute on function public.mod_sohbet_sil(bigint, boolean) to authenticated, service_role;
