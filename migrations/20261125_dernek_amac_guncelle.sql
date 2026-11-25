-- Canlı Supabase migration adı: dernek_amac_guncelle_20261125
-- DURUM (25.11.2026 12:50): canlıya UYGULANDI. Bu dosya depo eşitlemesidir; tekrar çalıştırmak güvenlidir.
-- Kaynak: gelistirici/sql/zz_20261125_dernek_amac_guncelle.sql
begin;
select set_config('lock_timeout', '4s', true);

-- 25.11.2026 · DERNEK AÇIKLAMASINI (AMACINI) SONRADAN DÜZELTME (sürüm 2026.11.25-1)
-- İstek (Ercan): "Dernek kurarken oyuncu açıklamayı yanlış yazmış, onu değiştirebilecek hale getir."
-- Eskiden amaç yalnız kuruluşta (dernek_kur) yazılıyordu; yanlış yazan başkanın düzeltme yolu yoktu.
--   • public.dernek_amac_guncelle(p_dernek, p_amac): yalnız derneğin BAŞKANI, açık dernekte. Metin kuruluştaki
--     süzgeçten (oyun.metin_temizle, 2000 karakter) geçer; boş bırakılırsa açıklama kaldırılır.
--   • Yayın ölçeği: dernek başına 24 saatte en çok 3 değişiklik (vitrin sürekli değiştirilip süzgeç denenmesin).
--   • Yönetim kararıyla yayını durdurulmuş dernek (mod_kurum_durdurma) açıklamasını değiştiremez.
--   • Her değişikliğin eski ve yeni hâli oyun.dernek_amac_gecmis'te kalır (denetim: uygunsuz metin yazıp sonra
--     silen başkan iz bırakır). Tablo oyunculara açık değildir.
-- Oyuncu verisi değişmez; yeni tablo ve yeni işlev eklenir. Tekrar çalıştırmak güvenlidir.
-- Ekran: gelistirici/www/dernek_vitrini.js ("AÇIKLAMAYI DÜZENLE").

create table if not exists oyun.dernek_amac_gecmis(
  id        bigint generated always as identity primary key,
  dernek_id bigint not null references oyun.dernekler(id) on delete cascade,
  user_id   uuid,
  eski      text not null,
  yeni      text not null,
  zaman     timestamptz not null default now()
);
create index if not exists dernek_amac_gecmis_d on oyun.dernek_amac_gecmis(dernek_id, zaman desc);
alter table oyun.dernek_amac_gecmis enable row level security;
revoke all on oyun.dernek_amac_gecmis from public, anon, authenticated;

create or replace function public.dernek_amac_guncelle(p_dernek bigint, p_amac text) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.dernekler; v_amac text; ilk timestamptz; n int; dur bigint;
begin
  select * into d from oyun.dernekler where id = p_dernek for update;
  if d.id is null then raise exception 'Dernek bulunamadı.'; end if;
  if d.kapali then raise exception 'Kapanmış derneğin açıklaması değiştirilemez.'; end if;
  if d.baskan is distinct from p.id then raise exception 'Derneğin açıklamasını yalnız başkan değiştirebilir.'; end if;
  if to_regprocedure('oyun.kurum_durdurma_aktif(text,bigint)') is not null then
    execute 'select (oyun.kurum_durdurma_aktif($1, $2)).id' into dur using 'dernek', d.id;
    if dur is not null then
      raise exception 'Derneğin yayın ve faaliyetleri oyun yönetimi kararıyla durduruldu; açıklama şu an değiştirilemez. İtiraz için Yönetime Yaz''ı kullan.';
    end if;
  end if;
  v_amac := case when coalesce(btrim(p_amac), '') = '' then '' else oyun.metin_temizle(p_amac, 2000) end;
  if v_amac = coalesce(d.amac, '') then return public.dernek_detay(d.id); end if;
  select count(*), min(g.zaman) into n, ilk from oyun.dernek_amac_gecmis g where g.dernek_id = d.id and g.zaman > t - interval '24 hours';
  if n >= 3 then
    raise exception 'Açıklama 24 saatte en çok 3 kez değiştirilebilir. % saatinden sonra yeniden deneyebilirsin.',
      to_char((ilk + interval '24 hours') at time zone 'Europe/Istanbul', 'DD.MM HH24:MI');
  end if;
  insert into oyun.dernek_amac_gecmis(dernek_id, user_id, eski, yeni, zaman) values (d.id, p.id, coalesce(d.amac, ''), v_amac, t);
  update oyun.dernekler set amac = v_amac where id = d.id;
  return public.dernek_detay(d.id);
end $f$;

revoke all on function public.dernek_amac_guncelle(bigint, text) from public, anon;
grant execute on function public.dernek_amac_guncelle(bigint, text) to authenticated;

commit;
