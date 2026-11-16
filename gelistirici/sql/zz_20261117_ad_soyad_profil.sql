-- 17.11.2026 · Ad soyad profilde görünür
-- Kayıtta onaylanan ad soyad oyuncunun profilinde ve oyuncu kartında görünür.
-- Kayıt onayı sisteminden önce katılmış (ad soyadı olmayan) oyuncular bir kez kendisi ekleyebilir;
-- gerçek siyasetçi/bilinen kişi adına benzeyen isimler otomatik reddedilir. Sonraki değişiklik yalnız
-- "makam" ya da "kayit" yetkili moderatör/yönetici tarafından yapılır.

create or replace function public.oyuncu_ad_soyad(p_kad text)
returns text language sql stable security definer set search_path to '' as $$
  select p.ad_soyad from oyun.profiller p where lower(p.kad)=lower(btrim(coalesce(p_kad,''))) and not coalesce(p.yasakli,false)
$$;

create or replace function public.ad_soyad_belirle(p_ad_soyad text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim(); a text; u text;
begin
  if p.id is null then raise exception 'Giriş yapmalısın.'; end if;
  if p.ad_soyad is not null then raise exception 'Ad soyadın zaten kayıtlı; değiştirmek için moderatöre başvur.'; end if;
  a := oyun_yonetim.ad_soyad_kontrol(p_ad_soyad);
  u := oyun_yonetim.isim_uyari(a);
  if u is not null then raise exception 'Gerçek siyasetçi ya da kamuoyunca bilinen kişi adı kullanılamaz (%).', u; end if;
  update oyun.profiller set ad_soyad=a where id=p.id;
  return jsonb_build_object('tamam',true,'ad_soyad',a);
end $$;

create or replace function public.yk_ad_soyad_degistir(p_kad text, p_ad_soyad text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare m oyun.profiller; h oyun.profiller := oyun.profil_bul(p_kad); a text;
begin
  begin m := oyun.yetki_zorunlu('kayit'); exception when others then m := oyun.yetki_zorunlu('makam'); end;
  a := case when nullif(btrim(coalesce(p_ad_soyad,'')),'') is null then null else oyun_yonetim.ad_soyad_kontrol(p_ad_soyad) end;
  update oyun.profiller set ad_soyad=a where id=h.id;
  perform oyun.mod_log(m,'ad_soyad',h.kad,coalesce(a,'silindi'));
  perform oyun.bildir(h.id, case when a is null then 'Ad soyadın moderatör tarafından kaldırıldı; profilinden yeniden ekleyebilirsin.' else 'Ad soyadın moderatör tarafından güncellendi: '||a||'.' end, oyun.simdi());
  return jsonb_build_object('tamam',true,'kad',h.kad,'ad_soyad',a);
end $$;

do $g$
declare f text;
begin
  foreach f in array array['public.oyuncu_ad_soyad(text)','public.ad_soyad_belirle(text)','public.yk_ad_soyad_degistir(text,text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $g$;
