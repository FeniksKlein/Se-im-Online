-- 23.11.2026 · ÖZEL GRUPLARDA ÜYE SINIRI KALDIRILDI (sürüm 2026.11.23-9)
-- İstek (Ercan): "Oyunda özel gruplarda kişi sınırı olmasın."
-- Önceki durum: bir özel grupta en fazla 100 üye olabiliyordu (oyun.sgrup_sinir('uye') = 100).
-- Bu dosya:
--   · oyun.sgrup_sinir('uye') artık NULL döner = sınırsız. sohbet_grup_detay ve sohbet_ozet 'uye_sinir' alanını
--     null gönderir; yeni uygulama "x üye" yazar, sınır göstermez.
--   · Üye ekleme / katılma isteği kabulünde (oyun.sgrup_uye_ekle_ic) üye sayısı denetimi kaldırıldı.
--   · Grup kurarken seçilen üye listesi artık 100'de kesilmiyor.
-- Değişmeyen (kötüye kullanım ve sunucu yükü için) sınırlar: kişi başı en çok 10 açık grup kurma, günde 5 grup kurma,
-- bir oyuncunun en çok 50 gruba üye olması, en çok 10 bekleyen katılma isteği. Grup mesajlarının canlı sinyali kanal
-- başına tek sinyaldir (üye başına değil); binlerce üyeli grup sunucuyu üye sayısıyla orantılı yormaz.
-- Mağazadaki eski uygulamalar: kurarken ekranda 99 kişi seçme sınırı kalır ama sonradan "Üye ekle" ve katılma
-- istekleriyle sınırsız üye eklenebilir (sınır sunucuda kalktı).

create or replace function oyun.sgrup_sinir(k text) returns int language sql immutable set search_path = '' as $$
  select case k when 'kurucu_aktif' then 10 when 'gunluk_kurma' then 5 when 'uye' then null when 'katildigi' then 50 else 0 end
$$;

create or replace function oyun.sgrup_uye_ekle_ic(p oyun.profiller, s oyun.sohbet_grup, h oyun.profiller) returns void
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi();
begin
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  if h.id = p.id then return; end if;
  if h.yasakli then raise exception '% şu anda oyundan uzaklaştırılmış; gruba eklenemez.', h.kad; end if;
  if oyun.engelli(h.id, p.id) or oyun.engelli(p.id, h.id) then raise exception '% ile aranızda engelleme olduğu için gruba eklenemez.', h.kad; end if;
  if oyun.sgrup_uye_mi(s.id, h.id) then raise exception '% zaten bu grubun üyesi.', h.kad; end if;
  -- Grup üye sayısında sınır yok (23.11.2026).
  if (select count(*) from oyun.sohbet_grup_uye x join oyun.sohbet_grup g on g.id = x.grup_id where x.user_id = h.id and x.aktif and not g.kapali) >= oyun.sgrup_sinir('katildigi') then
    raise exception '% en fazla % gruba üye olabilir; daha fazla gruba eklenemez.', h.kad, oyun.sgrup_sinir('katildigi');
  end if;
  insert into oyun.sohbet_grup_uye(grup_id, user_id, ekleyen, katilma, aktif, ayrilma, cikaran)
  values (s.id, h.id, p.id, t, true, null, null)
  on conflict (grup_id, user_id) do update set aktif = true, ekleyen = excluded.ekleyen, katilma = excluded.katilma, ayrilma = null, cikaran = null;
  update oyun.sohbet_grup_istek set durum = 'kabul', karar_zaman = t, karar_veren = p.id
   where grup_id = s.id and user_id = h.id and durum = 'bekliyor';
  perform oyun.bildir(h.id, p.kad || ' seni "' || s.ad || '" sohbet grubuna ekledi. Mesajlar › Kanallar › Özel Gruplar', t);
  perform oyun.canli_sinyal('kutu:' || h.id::text);
end $$;

create or replace function public.sohbet_grup_kur(p_ad text, p_uyeler text[] default null) returns jsonb
language plpgsql security definer set search_path = 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a text; s oyun.sohbet_grup; k text; h oyun.profiller; eklenen int := 0; atlanan jsonb := '[]';
begin
  perform oyun.sgrup_gozalti_kontrol(p);
  a := oyun.sgrup_ad_temizle(p_ad);
  if (select count(*) from oyun.sohbet_grup where kurucu = p.id and not kapali) >= oyun.sgrup_sinir('kurucu_aktif') then
    raise exception 'En fazla % açık sohbet grubun olabilir. Yeni grup için eskilerden birini kapat.', oyun.sgrup_sinir('kurucu_aktif');
  end if;
  if (select count(*) from oyun.sohbet_grup where kurucu = p.id and olusturma > t - interval '24 hours') >= oyun.sgrup_sinir('gunluk_kurma') then
    raise exception 'Bir günde en fazla % grup kurabilirsin; biraz sonra tekrar dene.', oyun.sgrup_sinir('gunluk_kurma');
  end if;
  if (select count(*) from oyun.sohbet_grup_uye x join oyun.sohbet_grup g on g.id = x.grup_id where x.user_id = p.id and x.aktif and not g.kapali) >= oyun.sgrup_sinir('katildigi') then
    raise exception 'En fazla % gruba üye olabilirsin.', oyun.sgrup_sinir('katildigi');
  end if;
  insert into oyun.sohbet_grup(ad, kurucu, olusturma) values (a, p.id, t) returning * into s;
  insert into oyun.sohbet_grup_uye(grup_id, user_id, ekleyen, katilma) values (s.id, p.id, p.id, t);
  if p_uyeler is not null then
    -- Seçilen üyelerin hepsi eklenir (üye sınırı yok).
    foreach k in array p_uyeler loop
      if k is null or btrim(k) = '' then continue; end if;
      begin
        h := oyun.profil_bul(btrim(k));
        if h.id = p.id then continue; end if;
        perform oyun.sgrup_uye_ekle_ic(p, s, h);
        eklenen := eklenen + 1;
      exception when others then
        atlanan := atlanan || jsonb_build_object('kad', k, 'neden', sqlerrm);
      end;
    end loop;
  end if;
  perform oyun.canli_sinyal('kutu:' || p.id::text);
  return jsonb_build_object('tamam', true, 'id', s.id, 'kanal', 'og:' || s.id, 'ad', s.ad, 'eklenen', eklenen, 'atlanan', atlanan);
end $$;
