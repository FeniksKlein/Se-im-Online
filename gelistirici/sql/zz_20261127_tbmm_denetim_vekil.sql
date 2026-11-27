-- =====================================================================
-- 27.11.2026 · TBMM: KOMİSYONLAR, DENETİM YOLLARI, VEKİL GÖREVLERİ (sürüm 2026.11.27-4)
-- İstek (Ercan): "Mecliste komisyonlar kurma, soru önergesi verme, gensoru verme gibi dinamikler ekle, altlarını doldur.
-- Milletvekili seçilenlere yeni görevler tahsis et, halk buluşması vs. düzenleyebilsinler."
--
-- Gerçek karşılığı:
--   • İhtisas komisyonları (İçtüzük m.20-21): 19 komisyon; üyelikler siyasi parti gruplarının sandalye oranına göre.
--     Teklif esas komisyona havale edilir, komisyon görüşür, oylar, rapor yazar. Komisyon toplantılarına Hükümet
--     temsilcileri ve teklif sahibi katılıp konuşabilir. Dilekçe Komisyonu vatandaş dilekçelerini inceler (Anayasa m.74).
--   • Denetim (Anayasa m.98, 2017 sonrası): yazılı soru (15 gün içinde cevap), genel görüşme, Meclis araştırması,
--     Meclis soruşturması. GENSORU 2017'de kaldırıldı; oyunda yalnız parlamenter sisteme geçilirse açılır (önceden vardı).
--   • Milletvekili seçim bölgesinde halkla buluşur ("bölge çalışması"); vatandaşın sorusunu yazılı soru önergesine çevirir.
-- Oyun kuralları:
--   • Mevcut 8 komisyona 11 komisyon eklenir (toplam 19 = TBMM). Üyelik, başkan seçimi, komisyon oyu ve raporu
--     sunucuda vardı ama oyunculara kapalıydı; artık açık. Komisyon salonu: üyeler, teklif sahibi ve Hükümet üyeleri
--     150 kelimelik konuşmalarla görüşür, herkes izler.
--   • Dilekçe: hesabı 3 günlük her oyuncu 48 saatte bir; Dilekçe Komisyonu 72 saatte karar vermezse dilekçe kendiliğinden
--     ilgili bakanlığa gider; bakanlık 15 günde cevaplamazsa "süresinde cevaplanmadı" olarak kapanır.
--   • Halk buluşması: milletvekili yalnız kendi seçim ilinde, 15 dk – 3 gün sonrası için, 45 dakika; günde 1, haftada 3;
--     Genel Kurul saatiyle (20.45–23.00) çakışamaz. İldeki oyunculara günde en çok bir buluşma bildirimi gider.
--     Katılan vatandaş soru sorar (3 soru), vekil yanıtlar ya da soruyu yazılı soru önergesine çevirir; bitince
--     katılanlar 1–5 puan verir. Vekile +1, katılana +0,5 kıdem (günlük tavanlı).
--   • Vekil Karnesi: Genel Kurul yoklamaları, konuşmalar, alkış, kanun teklifi, oylamalara katılım, soru önergesi,
--     halk buluşması ve memnuniyet; 10 dakikada bir hesaplanan Meclis sıralaması.
-- Tekrar çalıştırmak güvenlidir; oyuncu verisi değiştirilmez.
-- =====================================================================

-- ---------------------------------------------------------------- 19 İHTİSAS KOMİSYONU
insert into oyun.kom_tanim(kod, ad, kisa, sira, aciklama) values
  ('milli_savunma', 'Millî Savunma Komisyonu', 'Millî Savunma', 9, 'Silahlı kuvvetler, askerlik, savunma sanayii.'),
  ('bayindirlik', 'Bayındırlık, İmar, Ulaştırma ve Turizm Komisyonu', 'Bayındırlık ve Ulaştırma', 10, 'İmar, konut, yol, ulaşım, iletişim altyapısı ve turizm.'),
  ('tarim', 'Tarım, Orman ve Köyişleri Komisyonu', 'Tarım ve Orman', 11, 'Tarım, hayvancılık, ormancılık, su ve köy hizmetleri.'),
  ('cevre', 'Çevre Komisyonu', 'Çevre', 12, 'Çevre koruma, iklim, atık ve doğal varlıklar.'),
  ('insan_haklari', 'İnsan Haklarını İnceleme Komisyonu', 'İnsan Hakları', 13, 'Temel hak ve özgürlükler; başvuruları inceler, rapor yazar.'),
  ('kadin_erkek', 'Kadın Erkek Fırsat Eşitliği Komisyonu', 'Fırsat Eşitliği', 14, 'Kadın erkek eşitliği ve ayrımcılıkla mücadele.'),
  ('kit', 'Kamu İktisadi Teşebbüsleri Komisyonu', 'KİT', 15, 'Kamu işletmelerinin denetimi, Varlık Fonu ve kamu şirketleri.'),
  ('avrupa', 'Avrupa Birliği Uyum Komisyonu', 'AB Uyum', 16, 'Avrupa Birliği mevzuatına uyum ve ilişkiler.'),
  ('guvenlik', 'Güvenlik ve İstihbarat Komisyonu', 'Güvenlik ve İstihbarat', 17, 'Terörle mücadele, istihbarat ve iç güvenlik politikaları.'),
  ('dijital', 'Dijital Mecralar Komisyonu', 'Dijital Mecralar', 18, 'İnternet, sosyal medya, kişisel veriler ve dijital yayın.'),
  ('dilekce', 'Dilekçe Komisyonu', 'Dilekçe', 19, 'Vatandaşların TBMM''ye yazdığı dilekçeleri inceler, cevaplar ya da bakanlığa gönderir.')
on conflict (kod) do nothing;
update oyun.kom_tanim set aciklama = 'Şirketler, ticaret, sanayi, enerji, maden, bilgi ve teknoloji.' where kod = 'sanayi' and aciklama like 'Şirketler, ticaret, enerji, tarım%';
update oyun.kom_tanim set aciklama = 'Uluslararası anlaşmalar ve dış politika.' where kod = 'disisleri' and aciklama = 'Uluslararası anlaşmalar, dış politika ve savunma.';

-- Teklifi esas komisyona havale (konuya göre). Dilekçe Komisyonu teklif almaz.
create or replace function oyun.kom_sec(p_tur text, p_baslik text, p_veri jsonb)
returns text language sql immutable set search_path to '' as $f$
  with m as (select lower(coalesce(p_baslik, '') || ' ' || coalesce(p_veri::text, '')) x)
  select case
    when p_tur in ('anayasa', 'secim', 'iptal') then 'anayasa'
    when p_tur = 'butce' then 'plan_butce'
    when m.x ~ '(avrupa birliği|avrupa birligi|ab uyum|schengen)' then 'avrupa'
    when m.x ~ '(istihbarat|terör|teror|mit |kontr)' then 'guvenlik'
    when m.x ~ '(sosyal medya|internet|dijital|kişisel veri|kisisel veri|yapay zek|siber)' then 'dijital'
    when m.x ~ '(insan hak|ifade özgürlüğü|ifade ozgurlugu|işkence|iskence|ayrımcılık|ayrimcilik)' then 'insan_haklari'
    when m.x ~ '(kadın|kadin|fırsat eşitliği|firsat esitligi|şiddet|siddet)' then 'kadin_erkek'
    when m.x ~ '(kamu iktisadi|kit |varlık fonu|varlik fonu|kamu şirket|kamu sirket|özelleştirme|ozellestirme)' then 'kit'
    when m.x ~ '(vergi|bütçe|butce|faiz|borç|borc|maliye|hazine|kredi|harç|harc|kdv|gelir|enflasyon|merkez bankas|tahvil|emlak vergisi)' then 'plan_butce'
    when m.x ~ '(savunma|asker|silahlı|silahli|ordu|bedelli)' then 'milli_savunma'
    when m.x ~ '(tarım|tarim|çiftçi|ciftci|hayvancılık|hayvancilik|orman|köy|koy hizmet|sulama|gübre|gubre)' then 'tarim'
    when m.x ~ '(çevre|cevre|iklim|atık|atik|karbon|geri dönüşüm|geri donusum|kirlilik)' then 'cevre'
    when m.x ~ '(imar|konut|ulaşım|ulasim| yol|yolu|yolları|köprü|kopru|demiryolu|havaliman|turizm|otoyol|kentsel dönüşüm)' then 'bayindirlik'
    when m.x ~ '(sağlık|saglik|hastane|asgari|ücret|ucret|emek|işçi|isci|sendika|emekli|sosyal|aile|çalışma|calisma|istihdam|işsiz)' then 'saglik'
    when m.x ~ '(eğitim|egitim|okul|üniversite|universite|öğrenci|ogrenci|öğretmen|kültür|kultur|spor|gençlik|genclik|sanat)' then 'egitim'
    when m.x ~ '(şirket|sirket|ticaret|sanayi|enerji|elektrik|doğal gaz|teknoloji|borsa|piyasa|ihracat|ithalat|maden|esnaf|ruhsat)' then 'sanayi'
    when m.x ~ '(dış|dis politika|anlaşma|anlasma|nato|büyükelç|diplomasi|sınır|sinir)' then 'disisleri'
    when m.x ~ '(belediye|valilik|il |iller|polis|emniyet|güvenlik|guvenlik|afet|deprem|göç|goc|nüfus|nufus|yerel)' then 'icisleri'
    when m.x ~ '(seçim|secim|baraj|parti|anayasa|meclis|cumhurbaşkan)' then 'anayasa'
    else 'adalet' end
  from m
$f$;

-- ---------------------------------------------------------------- KOMİSYON SALONU
create or replace function public.kom_salon(p_kom text, p_son bigint default 0)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); k oyun.kom_tanim; v_yaz boolean;
begin
  select * into k from oyun.kom_tanim where kod = p_kom;
  if k.kod is null then raise exception 'Komisyon bulunamadı.'; end if;
  v_yaz := oyun.kom_gecerli_uye(k.kod, p.id) or oyun.gk_hukumet(p.id)
    or exists (select 1 from oyun.kom_kanun kk join oyun.kanunlar kn on kn.id = kk.kanun_id where kk.kom_kod = k.kod and kk.karar is null and kn.durum = 'gorusmede' and kn.teklif_eden = p.id);
  return oyun.kom_json(k.kod, p) || jsonb_build_object(
    'boyut', oyun.kom_boyut(), 'yazabilirim', v_yaz, 'vekilim', oyun.gk_vekil(p.id),
    'uyeliklerim', (select count(*) from oyun.kom_uye u join oyun.makamlar m on m.id = u.makam_id and m.bit is null where u.user_id = p.id),
    'grup_yetkili', oyun.kom_grup_yetkili(p.id, p.parti_id),
    'kontenjan', coalesce((select jsonb_agg(jsonb_build_object('parti', coalesce(pa.kisa, 'Bağımsızlar'), 'renk', pa.renk, 'mv', kq.mv, 'kontenjan', kq.kontenjan,
                     'dolu', (select count(*) from oyun.kom_uyeler(k.kod) x where coalesce(x.parti_id, 0) = kq.parti_id and x.gecerli)) order by kq.mv desc)
                   from oyun.kom_kontenjan() kq left join oyun.partiler pa on pa.id = nullif(kq.parti_id, 0)), '[]'::jsonb),
    'dilekce_bekleyen', case when k.kod = 'dilekce' then (select count(*) from oyun.tbmm_dilekce d where d.durum = 'komisyonda') end,
    'tutanak', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'z', x.zaman, 'tur', x.tur, 'ad', x.ad, 'kad', x.kad, 'il', x.il, 'kisa', x.parti_kisa,
                  'renk', x.renk, 'rol', x.rol, 'm', case when x.gizli then '(Bu bölüm Oyun Yönetimince tutanaktan çıkarıldı.)' else x.metin end, 'gz', x.gizli) order by x.id)
               from (select * from oyun.gk_tutanak t where t.salon = 'kom:' || k.kod and t.id > coalesce(p_son, 0) order by t.id desc limit 60) x), '[]'::jsonb));
end $f$;

create or replace function public.kom_konus(p_kom text, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k oyun.kom_tanim; m text; n int; v_son timestamptz; v_id bigint; kj jsonb;
begin
  select * into k from oyun.kom_tanim where kod = p_kom;
  if k.kod is null then raise exception 'Komisyon bulunamadı.'; end if;
  if not (oyun.kom_gecerli_uye(k.kod, p.id) or oyun.gk_hukumet(p.id)
          or exists (select 1 from oyun.kom_kanun kk join oyun.kanunlar kn on kn.id = kk.kanun_id where kk.kom_kod = k.kod and kk.karar is null and kn.durum = 'gorusmede' and kn.teklif_eden = p.id)) then
    raise exception 'Komisyonda asıl üyeler, Hükümet üyeleri ve görüşülen teklifin sahibi konuşur; sen izleyebilirsin.';
  end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(coalesce(p_metin, ''), 1200);
  n := oyun.gk_kelime(m);
  if n = 0 then raise exception 'Boş konuşma gönderilemez.'; end if;
  if n > 150 then raise exception 'Komisyonda bir konuşma en çok 150 kelime olabilir (yazdığın: %).', n; end if;
  select max(zaman) into v_son from oyun.gk_tutanak where salon = 'kom:' || k.kod and user_id = p.id;
  if v_son > t - interval '20 seconds' then raise exception 'Komisyonda 20 saniyede bir konuşabilirsin.'; end if;
  if (select count(*) from oyun.gk_tutanak where salon = 'kom:' || k.kod and user_id = p.id and zaman > t - interval '1 day') >= 30 then
    raise exception 'Bu komisyonda bugünkü konuşma hakkın doldu.'; end if;
  kj := oyun.gk_kimlik(p.id);
  insert into oyun.gk_tutanak(birlesim_id, salon, zaman, tur, user_id, ad, kad, il, parti_id, parti_kisa, renk, rol, metin)
  values (null, 'kom:' || k.kod, t, case when oyun.kom_baskan(k.kod) = p.id then 'baskan' else 'konusma' end, p.id, kj ->> 'ad', kj ->> 'kad', kj ->> 'il',
          (kj ->> 'parti_id')::bigint, kj ->> 'kisa', kj ->> 'renk', coalesce(case when oyun.kom_baskan(k.kod) = p.id then 'Komisyon Başkanı' end, kj ->> 'rol'), m)
  returning id into v_id;
  update oyun.profiller set son_mesaj = t where id = p.id;
  perform oyun.canli_sinyal('miting:kom.' || k.kod);
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

-- ---------------------------------------------------------------- DİLEKÇE
create table if not exists oyun.tbmm_dilekce (
  id bigserial primary key,
  no int not null,
  user_id uuid not null,
  konu text not null,
  metin text not null,
  bakanlik text,
  zaman timestamptz not null,
  durum text not null default 'komisyonda' check (durum in ('komisyonda', 'bakanlikta', 'cevaplandi', 'reddedildi', 'cevapsiz')),
  cevap text, cevaplayan uuid, cevap_tur text, cevap_at timestamptz,
  havale_at timestamptz, havale_eden uuid,
  gizli boolean not null default false
);
create index if not exists tbmm_dilekce_durum on oyun.tbmm_dilekce (durum, zaman);
create index if not exists tbmm_dilekce_kisi on oyun.tbmm_dilekce (user_id, zaman);
alter table oyun.tbmm_dilekce enable row level security;
revoke all on oyun.tbmm_dilekce from public, anon, authenticated;
drop trigger if exists bolucu_metin on oyun.tbmm_dilekce;
create trigger bolucu_metin before insert or update of konu, metin, cevap on oyun.tbmm_dilekce for each row execute function oyun.bolucu_metin_trg('konu', 'metin', 'cevap');

create or replace function oyun.tbmm_dilekce_json(d oyun.tbmm_dilekce, u uuid, p_tam boolean) returns jsonb
language sql stable set search_path to '' as $f$
  select jsonb_build_object('id', d.id, 'no', d.no, 'konu', d.konu, 'metin', case when p_tam then d.metin else left(d.metin, 280) end, 'durum', d.durum,
    'zaman', d.zaman, 'bakanlik', d.bakanlik, 'bakanlik_ad', (select ad from oyun.bakanliklar b where b.kod = d.bakanlik),
    'cevap', d.cevap, 'cevap_tur', d.cevap_tur, 'cevap_at', d.cevap_at, 'cevaplayan', case when d.cevaplayan is not null then oyun.gk_kimlik(d.cevaplayan) end,
    'havale_at', d.havale_at, 'sahibi', d.user_id = u,
    'kisi', case when p_tam then oyun.gk_kimlik(d.user_id) end,
    'son', case d.durum when 'komisyonda' then d.zaman + interval '72 hours' when 'bakanlikta' then coalesce(d.havale_at, d.zaman) + interval '15 days' end)
$f$;

create or replace function public.tbmm_dilekce_ver(p_konu text, p_metin text, p_bakanlik text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; m text; v_id bigint; v_no int;
begin
  if p.yasakli then raise exception 'Hesabın kısıtlı.'; end if;
  if p.olusturma > t - interval '3 days' then raise exception 'TBMM''ye dilekçe vermek için hesabının en az 3 günlük olması gerekir.'; end if;
  perform oyun.yazabilir_mi(p, t);
  k := btrim(regexp_replace(coalesce(p_konu, ''), '\s+', ' ', 'g')); m := btrim(coalesce(p_metin, ''));
  if char_length(k) not between 5 and 120 then raise exception 'Konu 5–120 karakter olmalı.'; end if;
  if char_length(m) not between 30 and 2500 then raise exception 'Dilekçe metni 30–2500 karakter olmalı.'; end if;
  if oyun.kufurlu(k || ' ' || m) then raise exception 'Dilekçede uygunsuz bir ifade var.'; end if;
  if p_bakanlik is not null and not exists (select 1 from oyun.bakanliklar where kod = p_bakanlik) then raise exception 'Bakanlık bulunamadı.'; end if;
  if exists (select 1 from oyun.tbmm_dilekce where user_id = p.id and zaman > t - interval '48 hours') then raise exception 'TBMM''ye 48 saatte bir dilekçe verebilirsin.'; end if;
  select coalesce(max(no), 0) + 1 into v_no from oyun.tbmm_dilekce;
  insert into oyun.tbmm_dilekce(no, user_id, konu, metin, bakanlik, zaman) values (v_no, p.id, k, m, p_bakanlik, t) returning id into v_id;
  insert into oyun.bildirimler(user_id, zaman, metin)
  select x.user_id, t, format('Dilekçe Komisyonu: %s numaralı yeni dilekçe — "%s".', v_no, left(k, 80)) from oyun.kom_uyeler('dilekce') x where x.gecerli limit 40;
  return jsonb_build_object('tamam', true, 'id', v_id, 'no', v_no);
end $f$;

create or replace function public.tbmm_dilekceler(p_kapsam text default 'benim')
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); uye boolean := oyun.kom_gecerli_uye('dilekce', p.id);
  bk text[] := array(select m.bakanlik from oyun.makamlar m where m.user_id = p.id and m.tur = 'bakan' and m.bit is null);
begin
  perform oyun.tbmm_dilekce_tick(t);
  return jsonb_build_object('uye', uye, 'bakanliklarim', to_jsonb(bk),
    'bakanliklar', coalesce((select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad) order by ad) from oyun.bakanliklar), '[]'::jsonb),
    'son_verdigim', (select max(zaman) from oyun.tbmm_dilekce where user_id = p.id),
    'hesap_gun', extract(day from t - p.olusturma),
    'benim', coalesce((select jsonb_agg(oyun.tbmm_dilekce_json(d, p.id, true) order by d.id desc) from (select * from oyun.tbmm_dilekce where user_id = p.id order by id desc limit 30) d), '[]'::jsonb),
    'komisyon', case when uye or coalesce(p.yonetici, false) then coalesce((select jsonb_agg(oyun.tbmm_dilekce_json(d, p.id, true) order by d.id)
                  from (select * from oyun.tbmm_dilekce where durum = 'komisyonda' and not gizli order by id limit 60) d), '[]'::jsonb) end,
    'bakanlik', case when cardinality(bk) > 0 then coalesce((select jsonb_agg(oyun.tbmm_dilekce_json(d, p.id, true) order by d.id)
                  from (select * from oyun.tbmm_dilekce where durum = 'bakanlikta' and bakanlik = any(bk) and not gizli order by id limit 60) d), '[]'::jsonb) end,
    'son_cevaplar', coalesce((select jsonb_agg(oyun.tbmm_dilekce_json(d, p.id, false) order by d.cevap_at desc)
                  from (select * from oyun.tbmm_dilekce where durum = 'cevaplandi' and not gizli order by cevap_at desc limit 15) d), '[]'::jsonb));
end $f$;

create or replace function public.tbmm_dilekce_karar(p_id bigint, p_karar text, p_metin text default null, p_bakanlik text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.tbmm_dilekce; m text := btrim(coalesce(p_metin, '')); bk text;
begin
  if not (oyun.kom_gecerli_uye('dilekce', p.id) or coalesce(p.yonetici, false)) then raise exception 'Dilekçeler hakkında Dilekçe Komisyonunun asıl üyeleri karar verir.'; end if;
  select * into d from oyun.tbmm_dilekce where id = p_id for update;
  if d.id is null or d.durum <> 'komisyonda' then raise exception 'Bu dilekçe artık komisyonda değil.'; end if;
  if p_karar = 'cevapla' then
    if char_length(m) not between 20 and 3000 then raise exception 'Cevap 20–3000 karakter olmalı.'; end if;
    update oyun.tbmm_dilekce set durum = 'cevaplandi', cevap = m, cevaplayan = p.id, cevap_tur = 'komisyon', cevap_at = t where id = d.id;
    perform oyun.bildir(d.user_id, format('TBMM Dilekçe Komisyonu %s numaralı dilekçeni cevapladı.', d.no), t);
  elsif p_karar = 'bakanliga' then
    bk := coalesce(p_bakanlik, d.bakanlik);
    if bk is null or not exists (select 1 from oyun.bakanliklar where kod = bk) then raise exception 'Dilekçenin gönderileceği bakanlığı seç.'; end if;
    update oyun.tbmm_dilekce set durum = 'bakanlikta', bakanlik = bk, havale_at = t, havale_eden = p.id, cevap = nullif(m, '') where id = d.id;
    perform oyun.bildir(d.user_id, format('%s numaralı dilekçen Dilekçe Komisyonunca %s''na gönderildi.', d.no, (select ad from oyun.bakanliklar where kod = bk)), t);
    insert into oyun.bildirimler(user_id, zaman, metin)
    select m2.user_id, t, format('TBMM Dilekçe Komisyonu bakanlığına bir vatandaş dilekçesi gönderdi: "%s". 15 gün içinde cevaplayın.', left(d.konu, 80))
    from oyun.makamlar m2 where m2.tur = 'bakan' and m2.bakanlik = bk and m2.bit is null;
  elsif p_karar = 'reddet' then
    if char_length(m) not between 10 and 500 then raise exception 'Ret gerekçesi 10–500 karakter olmalı.'; end if;
    update oyun.tbmm_dilekce set durum = 'reddedildi', cevap = m, cevaplayan = p.id, cevap_tur = 'komisyon', cevap_at = t where id = d.id;
    perform oyun.bildir(d.user_id, format('TBMM Dilekçe Komisyonu %s numaralı dilekçeni işleme koymadı. Gerekçe: %s', d.no, left(m, 200)), t);
  else raise exception 'Geçersiz karar.';
  end if;
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.tbmm_dilekce_bakan_cevap(p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); d oyun.tbmm_dilekce; m text := btrim(coalesce(p_metin, ''));
begin
  select * into d from oyun.tbmm_dilekce where id = p_id for update;
  if d.id is null or d.durum <> 'bakanlikta' then raise exception 'Bu dilekçe bakanlıkta değil.'; end if;
  if not exists (select 1 from oyun.makamlar m2 where m2.user_id = p.id and m2.tur = 'bakan' and m2.bakanlik = d.bakanlik and m2.bit is null) then
    raise exception 'Bu dilekçeyi ilgili bakan cevaplar.'; end if;
  if char_length(m) not between 20 and 3000 then raise exception 'Cevap 20–3000 karakter olmalı.'; end if;
  update oyun.tbmm_dilekce set durum = 'cevaplandi', cevap = m, cevaplayan = p.id, cevap_tur = 'bakanlik', cevap_at = t where id = d.id;
  perform oyun.bildir(d.user_id, format('%s numaralı TBMM dilekçen %s tarafından cevaplandı.', d.no, (select ad from oyun.bakanliklar where kod = d.bakanlik)), t);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function oyun.tbmm_dilekce_tick(t timestamptz default null) returns int
language plpgsql security definer set search_path to '' as $f$
declare d oyun.tbmm_dilekce; n int := 0;
begin
  t := coalesce(t, oyun.simdi());
  for d in select * from oyun.tbmm_dilekce x where x.durum = 'komisyonda' and x.zaman <= t - interval '72 hours' order by x.id limit 100 loop
    update oyun.tbmm_dilekce set durum = 'bakanlikta', bakanlik = coalesce(d.bakanlik, 'adalet'), havale_at = t where id = d.id;
    perform oyun.bildir(d.user_id, format('%s numaralı dilekçen 72 saat içinde komisyonda karara bağlanmadığı için %s''na gönderildi.', d.no,
      (select ad from oyun.bakanliklar where kod = coalesce(d.bakanlik, 'adalet'))), t);
    n := n + 1;
  end loop;
  for d in select * from oyun.tbmm_dilekce x where x.durum = 'bakanlikta' and coalesce(x.havale_at, x.zaman) <= t - interval '15 days' order by x.id limit 100 loop
    update oyun.tbmm_dilekce set durum = 'cevapsiz' where id = d.id;
    perform oyun.bildir(d.user_id, format('%s numaralı dilekçen bakanlıkça 15 gün içinde cevaplanmadı; kayda "süresinde cevaplanmadı" olarak geçti.', d.no), t);
    n := n + 1;
  end loop;
  return n;
end $f$;

-- ---------------------------------------------------------------- YAZILI SORU ÖNERGESİ (Anayasa m.98: 15 gün)
alter table oyun.bakan_soru add column if not exists no int;
alter table oyun.bakan_soru add column if not exists son timestamptz;
alter table oyun.bakan_soru add column if not exists vatandas uuid;
alter table oyun.bakan_soru add column if not exists kaynak text;
create index if not exists bakan_soru_bakanlik on oyun.bakan_soru (bakanlik, id desc);
create index if not exists bakan_soru_soran on oyun.bakan_soru (soran, id desc);

create or replace function oyun.tbmm_soru_hedef_ad(k text) returns text
language sql stable set search_path to '' as $f$
  select case when k = 'cby' then 'Cumhurbaşkanı Yardımcılığı' else coalesce((select ad from oyun.bakanliklar where kod = k), k) end
$f$;

create or replace function oyun.tbmm_soru_json(s oyun.bakan_soru, u uuid) returns jsonb
language sql stable set search_path to '' as $f$
  select jsonb_build_object('id', s.id, 'no', coalesce(s.no, s.id), 'bakanlik', s.bakanlik, 'hedef', oyun.tbmm_soru_hedef_ad(s.bakanlik),
    'konu', s.konu, 'soru', s.soru, 'zaman', s.zaman, 'son', coalesce(s.son, s.zaman + interval '15 days'),
    'yanit', s.yanit, 'yanit_at', s.yanit_at, 'yanitlayan', case when s.yanitlayan is not null then oyun.gk_kimlik(s.yanitlayan) end,
    'soran', oyun.gk_kimlik(s.soran), 'vatandas', case when s.vatandas is not null then oyun.gk_kimlik(s.vatandas) ->> 'ad' end, 'kaynak', s.kaynak,
    'gecikti', s.yanit is null and oyun.simdi() > coalesce(s.son, s.zaman + interval '15 days'),
    'benim', s.soran = u,
    'cevaplayabilirim', s.yanit is null and ((s.bakanlik = 'cby' and exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'cb_yardimcisi' and m.bit is null))
       or exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bakan' and m.bakanlik = s.bakanlik and m.bit is null)))
$f$;

create or replace function public.tbmm_soru_ver(p_bakanlik text, p_konu text, p_soru text, p_hb_soru bigint default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text := btrim(coalesce(p_konu, '')); m text := btrim(coalesce(p_soru, ''));
  v_id bigint; v_no int; v_vat uuid; v_vekil uuid; v_onerge bigint;
begin
  if not oyun.gk_vekil(p.id) then raise exception 'Yazılı soru önergesini milletvekilleri verir.'; end if;
  if oyun.tbmm_baskani() is not distinct from p.id then raise exception 'Meclis Başkanı soru önergesi veremez.'; end if;
  if p_bakanlik is null or (p_bakanlik <> 'cby' and not exists (select 1 from oyun.bakanliklar where kod = p_bakanlik)) then raise exception 'Soru önergesinin muhatabını seç.'; end if;
  if char_length(k) not between 5 and 100 then raise exception 'Konu 5–100 karakter olmalı.'; end if;
  if char_length(m) not between 10 and 5000 then raise exception 'Soru 10–5000 karakter olmalı.'; end if;
  if oyun.kufurlu(k || ' ' || m) then raise exception 'Önergede uygunsuz bir ifade var.'; end if;
  if (select count(*) from oyun.bakan_soru where soran = p.id and zaman > t - interval '1 day') >= 3 then raise exception '24 saatte en çok 3 soru önergesi verebilirsin.'; end if;
  if p_hb_soru is not null then
    select q.user_id, b.vekil, q.onerge_id into v_vat, v_vekil, v_onerge from oyun.hb_soru q join oyun.hb_bulusma b on b.id = q.bulusma_id where q.id = p_hb_soru;
    if v_vekil is distinct from p.id then raise exception 'Bu soru senin halk buluşmanda sorulmadı.'; end if;
    if v_onerge is not null then raise exception 'Bu soru zaten önergeye çevrildi.'; end if;
  end if;
  select coalesce(max(no), 0) + 1 into v_no from oyun.bakan_soru;
  insert into oyun.bakan_soru(soran, bakanlik, konu, soru, zaman, no, son, vatandas, kaynak)
  values (p.id, p_bakanlik, k, m, t, v_no, t + interval '15 days', v_vat, case when p_hb_soru is not null then 'halk_bulusmasi' end)
  returning id into v_id;
  if p_hb_soru is not null then
    update oyun.hb_soru set onerge_id = v_id where id = p_hb_soru;
    perform oyun.bildir(v_vat, format('Halk buluşmasında sorduğun soru milletvekili %s tarafından %s''na yazılı soru önergesi olarak verildi.',
      oyun.gk_kimlik(p.id) ->> 'ad', oyun.tbmm_soru_hedef_ad(p_bakanlik)), t);
  end if;
  insert into oyun.bildirimler(user_id, zaman, metin)
  select m2.user_id, t, format('%s numaralı yazılı soru önergesi: "%s" — %s. 15 gün içinde cevaplanmalı.', v_no, left(k, 80), oyun.gk_kimlik(p.id) ->> 'ad')
  from oyun.makamlar m2 where m2.bit is null and ((p_bakanlik = 'cby' and m2.tur = 'cb_yardimcisi') or (m2.tur = 'bakan' and m2.bakanlik = p_bakanlik));
  perform oyun.olay('meclis', format('%s, %s''na yazılı soru önergesi verdi: "%s".', oyun.gk_kimlik(p.id) ->> 'ad', oyun.tbmm_soru_hedef_ad(p_bakanlik), k), null, p.parti_id, t);
  return jsonb_build_object('tamam', true, 'id', v_id, 'no', v_no);
end $f$;

create or replace function public.tbmm_soru_cevapla(p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); s oyun.bakan_soru; m text := btrim(coalesce(p_metin, ''));
begin
  select * into s from oyun.bakan_soru where id = p_id for update;
  if s.id is null or s.yanit is not null then raise exception 'Bu soru bulunamadı ya da cevaplanmış.'; end if;
  if not ((s.bakanlik = 'cby' and exists (select 1 from oyun.makamlar m2 where m2.user_id = p.id and m2.tur = 'cb_yardimcisi' and m2.bit is null))
          or exists (select 1 from oyun.makamlar m2 where m2.user_id = p.id and m2.tur = 'bakan' and m2.bakanlik = s.bakanlik and m2.bit is null)) then
    raise exception 'Soruyu muhatap bakan ya da Cumhurbaşkanı Yardımcısı cevaplar.'; end if;
  if char_length(m) not between 10 and 8000 then raise exception 'Cevap 10–8000 karakter olmalı.'; end if;
  update oyun.bakan_soru set yanit = m, yanitlayan = p.id, yanit_at = t where id = s.id;
  perform oyun.bildir(s.soran, format('%s numaralı yazılı soru önergen %s tarafından cevaplandı.', coalesce(s.no, s.id), oyun.tbmm_soru_hedef_ad(s.bakanlik)), t);
  if s.vatandas is not null then
    perform oyun.bildir(s.vatandas, format('Halk buluşmasında sorduğun soru (%s) %s tarafından cevaplandı. TBMM › Soru önergeleri''nden okuyabilirsin.', left(s.konu, 60), oyun.tbmm_soru_hedef_ad(s.bakanlik)), t);
  end if;
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.tbmm_sorular(p_filtre text default 'hepsi', p_bakanlik text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
  bk text[] := array(select m.bakanlik from oyun.makamlar m where m.user_id = p.id and m.tur = 'bakan' and m.bit is null)
            || case when exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb_yardimcisi' and m.bit is null) then array['cby'] else '{}'::text[] end;
begin
  return jsonb_build_object('vekilim', oyun.gk_vekil(p.id), 'muhataplarim', to_jsonb(bk),
    'hedefler', (select jsonb_agg(x order by x ->> 'ad') from (select jsonb_build_object('kod', kod, 'ad', ad) x from oyun.bakanliklar
                 union all select jsonb_build_object('kod', 'cby', 'ad', 'Cumhurbaşkanı Yardımcılığı')) z),
    'bugun', (select count(*) from oyun.bakan_soru where soran = p.id and zaman > t - interval '1 day'),
    'liste', coalesce((select jsonb_agg(oyun.tbmm_soru_json(s, p.id) order by s.id desc) from (
       select * from oyun.bakan_soru s
       where (p_bakanlik is null or s.bakanlik = p_bakanlik)
         and case coalesce(p_filtre, 'hepsi')
               when 'benim' then s.soran = p.id
               when 'bana' then s.bakanlik = any(bk)
               when 'bekleyen' then s.yanit is null
               when 'cevaplanan' then s.yanit is not null
               else true end
       order by s.id desc limit 80) s), '[]'::jsonb),
    'karne', coalesce((select jsonb_agg(jsonb_build_object('kod', z.bakanlik, 'ad', oyun.tbmm_soru_hedef_ad(z.bakanlik), 'soru', z.n, 'cevap', z.c, 'gecikmis', z.g,
         'ort_saat', z.ort, 'oran', case when z.n > 0 then round(100.0 * z.c / z.n) end,
         'muhatap', (select oyun.gk_kimlik(m.user_id) ->> 'ad' from oyun.makamlar m where m.bit is null and ((z.bakanlik = 'cby' and m.tur = 'cb_yardimcisi') or (m.tur = 'bakan' and m.bakanlik = z.bakanlik)) limit 1))
         order by z.n desc)
       from (select s.bakanlik, count(*) n, count(*) filter (where s.yanit is not null) c,
                    count(*) filter (where s.yanit is null and t > coalesce(s.son, s.zaman + interval '15 days')) g,
                    round(avg(extract(epoch from (s.yanit_at - s.zaman)) / 3600) filter (where s.yanit_at is not null)) ort
             from oyun.bakan_soru s where s.zaman > t - interval '60 days' group by s.bakanlik) z), '[]'::jsonb));
end $f$;

-- ---------------------------------------------------------------- HALK BULUŞMASI
create table if not exists oyun.hb_bulusma (
  id bigserial primary key,
  vekil uuid not null,
  il_id smallint not null,
  parti_id bigint,
  baslik text not null,
  metin text,
  bas timestamptz not null,
  bit timestamptz not null,
  durum text not null default 'planli' check (durum in ('planli', 'iptal', 'kaldirildi')),
  duyuruldu boolean not null default false,
  ozet_yazildi boolean not null default false,
  olusturma timestamptz not null
);
create index if not exists hb_bulusma_zaman on oyun.hb_bulusma (bas, bit) where durum = 'planli';
create index if not exists hb_bulusma_il on oyun.hb_bulusma (il_id, bas desc);
create index if not exists hb_bulusma_vekil on oyun.hb_bulusma (vekil, bas desc);
create table if not exists oyun.hb_katilim (
  bulusma_id bigint not null, user_id uuid not null, hatirlat boolean not null default false, katildi timestamptz, puan smallint check (puan between 1 and 5),
  primary key (bulusma_id, user_id)
);
create table if not exists oyun.hb_soru (
  id bigserial primary key, bulusma_id bigint not null, user_id uuid not null, metin text not null, zaman timestamptz not null,
  yanit text, yanit_at timestamptz, begeni int not null default 0, gizli boolean not null default false, onerge_id bigint
);
create index if not exists hb_soru_b on oyun.hb_soru (bulusma_id, id);
create table if not exists oyun.hb_soru_begeni (soru_id bigint not null, user_id uuid not null, primary key (soru_id, user_id));
create table if not exists oyun.hb_bildirim_gun (user_id uuid not null, gun date not null, primary key (user_id, gun));
do $rls$
declare t text;
begin
  foreach t in array array['hb_bulusma', 'hb_katilim', 'hb_soru', 'hb_soru_begeni', 'hb_bildirim_gun'] loop
    execute format('alter table oyun.%I enable row level security', t);
    execute format('revoke all on oyun.%I from public, anon, authenticated', t);
  end loop;
end $rls$;
drop trigger if exists bolucu_metin on oyun.hb_bulusma;
create trigger bolucu_metin before insert or update of baslik, metin on oyun.hb_bulusma for each row execute function oyun.bolucu_metin_trg('baslik', 'metin');
drop trigger if exists bolucu_metin on oyun.hb_soru;
create trigger bolucu_metin before insert or update of metin, yanit on oyun.hb_soru for each row execute function oyun.bolucu_metin_trg('metin', 'yanit');
drop trigger if exists gozalti_yazi_engel on oyun.hb_soru;
create trigger gozalti_yazi_engel before insert on oyun.hb_soru for each row execute function oyun.gozalti_yazi_engel_trg('user_id');

create or replace function oyun.hb_ozet(b oyun.hb_bulusma, u uuid, t timestamptz) returns jsonb
language sql stable set search_path to '' as $f$
  select jsonb_build_object('id', b.id, 'baslik', b.baslik, 'metin', b.metin, 'bas', b.bas, 'bit', b.bit, 'durum', b.durum,
    'canli', b.durum = 'planli' and t >= b.bas and t < b.bit, 'bitti', b.durum = 'planli' and t >= b.bit,
    'il_id', b.il_id, 'il', (select ad from oyun.iller where id = b.il_id), 'vekil', oyun.gk_kimlik(b.vekil),
    'katilim', (select count(*) from oyun.hb_katilim k where k.bulusma_id = b.id and k.katildi is not null),
    'hatirlat', (select count(*) from oyun.hb_katilim k where k.bulusma_id = b.id and k.hatirlat),
    'soru', (select count(*) from oyun.hb_soru q where q.bulusma_id = b.id and not q.gizli),
    'yanit', (select count(*) from oyun.hb_soru q where q.bulusma_id = b.id and not q.gizli and q.yanit is not null),
    'puan', (select round(avg(k.puan), 1) from oyun.hb_katilim k where k.bulusma_id = b.id and k.puan is not null),
    'puan_sayi', (select count(*) from oyun.hb_katilim k where k.bulusma_id = b.id and k.puan is not null),
    'benim', b.vekil = u)
$f$;

create or replace function public.hb_planla(p_bas timestamptz, p_baslik text, p_metin text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m oyun.makamlar; v_bas timestamptz := date_trunc('minute', p_bas);
  bs text := btrim(regexp_replace(coalesce(p_baslik, ''), '\s+', ' ', 'g')); mt text := nullif(btrim(coalesce(p_metin, '')), ''); v_id bigint; yerel time; il_ad text;
begin
  select * into m from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null order by bas desc limit 1;
  if m.id is null then raise exception 'Halk buluşmasını milletvekilleri düzenler.'; end if;
  if m.il_id is null then raise exception 'Seçim ilin bulunamadı.'; end if;
  if char_length(bs) not between 5 and 100 then raise exception 'Başlık 5–100 karakter olmalı.'; end if;
  if mt is not null and char_length(mt) > 1200 then raise exception 'Açıklama en çok 1200 karakter olabilir.'; end if;
  if oyun.kufurlu(bs || ' ' || coalesce(mt, '')) then raise exception 'Metinde uygunsuz bir ifade var.'; end if;
  if v_bas < t + interval '15 minutes' or v_bas > t + interval '3 days' then raise exception 'Buluşma en erken 15 dakika, en geç 3 gün sonrası için planlanır.'; end if;
  yerel := (v_bas at time zone 'Europe/Istanbul')::time;
  if (yerel >= time '20:00' and yerel < time '23:00') or ((v_bas + interval '45 minutes') at time zone 'Europe/Istanbul')::time between time '20:45' and time '23:00' then
    raise exception 'Genel Kurul akşam 21.00''de toplanır; buluşmayı 20.00–23.00 dışına planla.'; end if;
  if exists (select 1 from oyun.hb_bulusma x where x.vekil = p.id and x.durum = 'planli' and (x.bas at time zone 'Europe/Istanbul')::date = (v_bas at time zone 'Europe/Istanbul')::date) then
    raise exception 'Bir günde tek halk buluşması düzenleyebilirsin.'; end if;
  if (select count(*) from oyun.hb_bulusma x where x.vekil = p.id and x.durum = 'planli' and x.bas > v_bas - interval '7 days' and x.bas < v_bas + interval '7 days') >= 3 then
    raise exception 'Bir haftada en çok 3 halk buluşması düzenleyebilirsin.'; end if;
  if (select count(*) from oyun.hb_bulusma x where x.il_id = m.il_id and x.durum = 'planli' and tstzrange(x.bas, x.bit) && tstzrange(v_bas, v_bas + interval '45 minutes')) >= 3 then
    raise exception 'Bu saatte ilinde 3 buluşma var; başka bir saat seç.'; end if;
  insert into oyun.hb_bulusma(vekil, il_id, parti_id, baslik, metin, bas, bit, olusturma) values (p.id, m.il_id, p.parti_id, bs, mt, v_bas, v_bas + interval '45 minutes', t)
  returning id into v_id;
  select ad into il_ad from oyun.iller where id = m.il_id;
  perform oyun.olay('yerel', format('%s Milletvekili %s halk buluşması düzenliyor: "%s" (%s).', il_ad, oyun.gk_kimlik(p.id) ->> 'ad', bs,
    to_char(v_bas at time zone 'Europe/Istanbul', 'DD.MM HH24.MI')), m.il_id, p.parti_id, t);
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

create or replace function public.hb_iptal(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.hb_bulusma;
begin
  select * into b from oyun.hb_bulusma where id = p_id for update;
  if b.id is null or b.vekil <> p.id or b.durum <> 'planli' or t >= b.bas then raise exception 'Buluşma iptal edilemez (başlamadan iptal edilir).'; end if;
  update oyun.hb_bulusma set durum = 'iptal' where id = b.id;
  insert into oyun.bildirimler(user_id, zaman, metin) select k.user_id, t, format('"%s" halk buluşması iptal edildi.', b.baslik) from oyun.hb_katilim k where k.bulusma_id = b.id and k.hatirlat;
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.hb_liste(p_il int default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); v_il int := coalesce(p_il, p.il_id);
begin
  perform oyun.hb_tick(t);
  return jsonb_build_object('il_id', v_il, 'il', (select ad from oyun.iller where id = v_il), 'vekilim', oyun.gk_vekil(p.id),
    'secim_ilim', (select m.il_id from oyun.makamlar m where m.user_id = p.id and m.tur = 'mv' and m.bit is null limit 1),
    'canli', coalesce((select jsonb_agg(oyun.hb_ozet(b, p.id, t) order by b.bas) from oyun.hb_bulusma b where b.durum = 'planli' and t >= b.bas and t < b.bit), '[]'::jsonb),
    'ilimde', coalesce((select jsonb_agg(oyun.hb_ozet(b, p.id, t) || jsonb_build_object('hatirlatiyorum', exists (select 1 from oyun.hb_katilim k where k.bulusma_id = b.id and k.user_id = p.id and k.hatirlat)) order by b.bas)
                        from oyun.hb_bulusma b where b.durum = 'planli' and b.il_id = v_il and b.bit > t), '[]'::jsonb),
    'benim', coalesce((select jsonb_agg(oyun.hb_ozet(b, p.id, t) order by b.bas desc) from (select * from oyun.hb_bulusma x where x.vekil = p.id order by x.bas desc limit 12) b), '[]'::jsonb),
    'gecmis', coalesce((select jsonb_agg(oyun.hb_ozet(b, p.id, t) order by b.bas desc) from (select * from oyun.hb_bulusma x where x.durum = 'planli' and x.bit <= t and x.il_id = v_il order by x.bas desc limit 10) b), '[]'::jsonb));
end $f$;

create or replace function public.hb_detay(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.hb_bulusma; k oyun.hb_katilim;
begin
  select * into b from oyun.hb_bulusma where id = p_id;
  if b.id is null or b.durum = 'kaldirildi' then raise exception 'Buluşma bulunamadı.'; end if;
  select * into k from oyun.hb_katilim where bulusma_id = b.id and user_id = p.id;
  return oyun.hb_ozet(b, p.id, t) || jsonb_build_object('simdi', t,
    'katildim', k.katildi is not null, 'hatirlatiyorum', coalesce(k.hatirlat, false), 'puanim', k.puan,
    'puanlayabilirim', k.katildi is not null and b.vekil <> p.id and k.puan is null and t >= b.bit - interval '10 minutes' and t < b.bit + interval '48 hours',
    'sorularim', (select count(*) from oyun.hb_soru q where q.bulusma_id = b.id and q.user_id = p.id),
    'mod', coalesce(p.yonetici, false) or coalesce(oyun.yetkili(p.id, 'sikayet'), false),
    'sorular', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'metin', q.metin, 'zaman', q.zaman, 'yanit', q.yanit, 'yanit_at', q.yanit_at,
         'begeni', q.begeni, 'onerge', q.onerge_id is not null, 'kisi', oyun.gk_kimlik(q.user_id), 'benim', q.user_id = p.id,
         'begendim', exists (select 1 from oyun.hb_soru_begeni x where x.soru_id = q.id and x.user_id = p.id)) order by (q.yanit is null) desc, q.begeni desc, q.id)
       from (select * from oyun.hb_soru x where x.bulusma_id = b.id and not x.gizli order by x.id limit 200) q), '[]'::jsonb),
    'katilanlar', coalesce((select jsonb_agg(oyun.gk_kimlik(z.user_id) ->> 'ad' order by z.katildi) from (select * from oyun.hb_katilim x where x.bulusma_id = b.id and x.katildi is not null order by x.katildi limit 60) z), '[]'::jsonb));
end $f$;

create or replace function public.hb_katil(p_id bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.hb_bulusma; ek numeric := 0;
begin
  select * into b from oyun.hb_bulusma where id = p_id;
  if b.id is null or b.durum <> 'planli' or t >= b.bit then raise exception 'Buluşma bitti ya da yok.'; end if;
  if t < b.bas then
    insert into oyun.hb_katilim(bulusma_id, user_id, hatirlat) values (b.id, p.id, true)
    on conflict (bulusma_id, user_id) do update set hatirlat = not oyun.hb_katilim.hatirlat;
    return jsonb_build_object('tamam', true, 'hatirlat', (select hatirlat from oyun.hb_katilim where bulusma_id = b.id and user_id = p.id));
  end if;
  insert into oyun.hb_katilim(bulusma_id, user_id, katildi) values (b.id, p.id, t)
  on conflict (bulusma_id, user_id) do update set katildi = coalesce(oyun.hb_katilim.katildi, excluded.katildi);
  if found and b.vekil <> p.id and (select katildi from oyun.hb_katilim where bulusma_id = b.id and user_id = p.id) = t then
    begin ek := oyun.kidem_ekle(p.id, 'halk_bulusma_katil'); exception when others then ek := 0; end;
  end if;
  perform oyun.canli_sinyal('miting:hb.' || b.id);
  return jsonb_build_object('tamam', true, 'katildi', true, 'kidem', ek);
end $f$;

create or replace function public.hb_soru_sor(p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.hb_bulusma; m text := btrim(regexp_replace(coalesce(p_metin, ''), '\s+', ' ', 'g')); v_id bigint;
begin
  select * into b from oyun.hb_bulusma where id = p_id;
  if b.id is null or b.durum <> 'planli' or t < b.bas or t >= b.bit then raise exception 'Sorular buluşma canlıyken sorulur.'; end if;
  if b.vekil = p.id then raise exception 'Kendi buluşmana soru soramazsın; soruları yanıtla.'; end if;
  perform oyun.yazabilir_mi(p, t);
  if char_length(m) not between 10 and 280 then raise exception 'Soru 10–280 karakter olmalı.'; end if;
  if oyun.kufurlu(m) then raise exception 'Soruda uygunsuz bir ifade var.'; end if;
  if (select count(*) from oyun.hb_soru where bulusma_id = b.id and user_id = p.id) >= 3 then raise exception 'Bir buluşmada en çok 3 soru sorabilirsin.'; end if;
  if exists (select 1 from oyun.hb_soru where bulusma_id = b.id and user_id = p.id and zaman > t - interval '2 minutes') then raise exception 'İki dakikada bir soru sorabilirsin.'; end if;
  if (select count(*) from oyun.hb_soru where bulusma_id = b.id) >= 200 then raise exception 'Bu buluşmada soru sınırı doldu.'; end if;
  insert into oyun.hb_katilim(bulusma_id, user_id, katildi) values (b.id, p.id, t) on conflict (bulusma_id, user_id) do update set katildi = coalesce(oyun.hb_katilim.katildi, t);
  insert into oyun.hb_soru(bulusma_id, user_id, metin, zaman) values (b.id, p.id, m, t) returning id into v_id;
  update oyun.profiller set son_mesaj = t where id = p.id;
  perform oyun.canli_sinyal('miting:hb.' || b.id);
  return jsonb_build_object('tamam', true, 'id', v_id);
end $f$;

create or replace function public.hb_soru_begen(p_soru bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); q oyun.hb_soru; b oyun.hb_bulusma;
begin
  select * into q from oyun.hb_soru where id = p_soru; select * into b from oyun.hb_bulusma where id = q.bulusma_id;
  if q.id is null or q.gizli or t >= b.bit then raise exception 'Soru bulunamadı.'; end if;
  insert into oyun.hb_soru_begeni(soru_id, user_id) values (q.id, p.id) on conflict do nothing;
  if found then update oyun.hb_soru set begeni = begeni + 1 where id = q.id;
  else delete from oyun.hb_soru_begeni where soru_id = q.id and user_id = p.id; update oyun.hb_soru set begeni = greatest(0, begeni - 1) where id = q.id; end if;
  perform oyun.canli_sinyal('miting:hb.' || b.id);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.hb_yanitla(p_soru bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); q oyun.hb_soru; b oyun.hb_bulusma; m text := btrim(coalesce(p_metin, ''));
begin
  select * into q from oyun.hb_soru where id = p_soru for update; select * into b from oyun.hb_bulusma where id = q.bulusma_id;
  if q.id is null or q.gizli then raise exception 'Soru bulunamadı.'; end if;
  if b.vekil <> p.id then raise exception 'Soruları buluşmayı düzenleyen milletvekili yanıtlar.'; end if;
  if t >= b.bit + interval '24 hours' then raise exception 'Buluşmanın üzerinden 24 saat geçti.'; end if;
  if char_length(m) not between 5 and 600 then raise exception 'Yanıt 5–600 karakter olmalı.'; end if;
  if oyun.kufurlu(m) then raise exception 'Yanıtta uygunsuz bir ifade var.'; end if;
  update oyun.hb_soru set yanit = m, yanit_at = t where id = q.id;
  if q.yanit is null then perform oyun.bildir(q.user_id, format('%s halk buluşmasında soruna yanıt verdi.', oyun.gk_kimlik(p.id) ->> 'ad'), t); end if;
  perform oyun.canli_sinyal('miting:hb.' || b.id);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.hb_puanla(p_id bigint, p_puan int)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.hb_bulusma; k oyun.hb_katilim;
begin
  if p_puan not between 1 and 5 then raise exception 'Puan 1–5 arasında olmalı.'; end if;
  select * into b from oyun.hb_bulusma where id = p_id;
  select * into k from oyun.hb_katilim where bulusma_id = p_id and user_id = p.id for update;
  if b.id is null or k.katildi is null then raise exception 'Yalnız buluşmaya katılanlar puan verir.'; end if;
  if b.vekil = p.id then raise exception 'Kendi buluşmanı puanlayamazsın.'; end if;
  if t < b.bit - interval '10 minutes' or t >= b.bit + interval '48 hours' then raise exception 'Puan buluşmanın son 10 dakikasından itibaren 48 saat içinde verilir.'; end if;
  if k.puan is not null then raise exception 'Bu buluşmaya zaten puan verdin.'; end if;
  update oyun.hb_katilim set puan = p_puan where bulusma_id = b.id and user_id = p.id;
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.hb_kaldir(p_id bigint, p_gerekce text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); b oyun.hb_bulusma;
begin
  if not coalesce(p.yonetici, false) then perform oyun.yetki_zorunlu('sikayet'); end if;
  select * into b from oyun.hb_bulusma where id = p_id for update;
  if b.id is null then raise exception 'Buluşma bulunamadı.'; end if;
  update oyun.hb_bulusma set durum = 'kaldirildi' where id = b.id;
  perform oyun.bildir(b.vekil, format('Oyun Yönetimi "%s" halk buluşmasını kaldırdı.%s', b.baslik, coalesce(' Gerekçe: ' || left(p_gerekce, 200), '')), oyun.simdi());
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function public.hb_soru_kaldir(p_soru bigint)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); q oyun.hb_soru;
begin
  select * into q from oyun.hb_soru where id = p_soru for update;
  if q.id is null then raise exception 'Soru bulunamadı.'; end if;
  if not (coalesce(p.yonetici, false) or coalesce(oyun.yetkili(p.id, 'sikayet'), false)
          or exists (select 1 from oyun.hb_bulusma b where b.id = q.bulusma_id and b.vekil = p.id)) then
    raise exception 'Soruyu buluşmanın sahibi ya da İçerik Masası kaldırır.'; end if;
  update oyun.hb_soru set gizli = true where id = q.id;
  perform oyun.canli_sinyal('miting:hb.' || q.bulusma_id);
  return jsonb_build_object('tamam', true);
end $f$;

create or replace function oyun.hb_tick(t timestamptz default null) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare b oyun.hb_bulusma; n_b int := 0; n_s int := 0; il_ad text; vad text; z jsonb; v_gun date;
begin
  t := coalesce(t, oyun.simdi());
  if not pg_try_advisory_xact_lock(hashtext('hb_tick')) then return jsonb_build_object('mesgul', true); end if;
  for b in select * from oyun.hb_bulusma x where x.durum = 'planli' and not x.duyuruldu and x.bas <= t order by x.bas limit 50 loop
    begin
      update oyun.hb_bulusma set duyuruldu = true where id = b.id;
      if t < b.bit then
        select ad into il_ad from oyun.iller where id = b.il_id; vad := oyun.gk_kimlik(b.vekil) ->> 'ad'; v_gun := oyun.gk_gun(t);
        insert into oyun.bildirimler(user_id, zaman, metin)
        select k.user_id, t, format('Canlı: %s Milletvekili %s halk buluşmasında — "%s". Katıl, sorunu sor.', il_ad, vad, b.baslik)
        from oyun.hb_katilim k where k.bulusma_id = b.id and k.hatirlat;
        with alicilar as (
          select pr.id from oyun.profiller pr
          where pr.il_id = b.il_id and not pr.yasakli and pr.id <> b.vekil and pr.son_gorulme > t - interval '7 days'
            and not exists (select 1 from oyun.hb_katilim k where k.bulusma_id = b.id and k.user_id = pr.id and k.hatirlat)
            and not exists (select 1 from oyun.hb_bildirim_gun g where g.user_id = pr.id and g.gun = v_gun)
          limit 3000),
        kayit as (insert into oyun.hb_bildirim_gun(user_id, gun) select id, v_gun from alicilar on conflict do nothing returning user_id)
        insert into oyun.bildirimler(user_id, zaman, metin)
        select user_id, t, format('Canlı: %s Milletvekili %s halkla buluşuyor — "%s". Katıl, sorunu sor.', il_ad, vad, b.baslik) from kayit;
      end if;
      n_b := n_b + 1;
    exception when others then raise warning 'hb_tick baş %: %', b.id, sqlerrm;
    end;
  end loop;
  for b in select * from oyun.hb_bulusma x where x.durum = 'planli' and not x.ozet_yazildi and x.bit <= t order by x.bit limit 50 loop
    begin
      update oyun.hb_bulusma set ozet_yazildi = true, duyuruldu = true where id = b.id;
      z := oyun.hb_ozet(b, null, t);
      select ad into il_ad from oyun.iller where id = b.il_id; vad := oyun.gk_kimlik(b.vekil) ->> 'ad';
      if (z ->> 'katilim')::int >= 3 then
        begin perform oyun.kidem_ekle(b.vekil, 'halk_bulusma'); exception when others then null; end;
      end if;
      perform oyun.ajans_yayinla('hb-' || b.id, 'yerel',
        format('%s Milletvekili %s halkla buluştu: %s katılımcı, %s soru', il_ad, vad, z ->> 'katilim', z ->> 'soru'),
        format('"%s" · %s soruya yanıt verildi%s', b.baslik, z ->> 'yanit', coalesce(' · memnuniyet ' || replace(z ->> 'puan', '.', ',') || '/5', '')),
        format('%s Milletvekili %s, "%s" başlıklı halk buluşmasında %s vatandaşla bir araya geldi. Buluşmada %s soru soruldu, %s soruya yanıt verildi.',
               il_ad, vad, b.baslik, z ->> 'katilim', z ->> 'soru', z ->> 'yanit'), 48, b.parti_id, b.il_id, t);
      perform oyun.bildir(b.vekil, format('Halk buluşman bitti: %s katılımcı, %s soru. Yanıtlamadığın soruları 24 saat içinde yanıtlayabilirsin.', z ->> 'katilim', z ->> 'soru'), t);
      insert into oyun.bildirimler(user_id, zaman, metin)
      select k.user_id, t, format('"%s" buluşması bitti. Milletvekilini 1–5 arası puanlayabilirsin (48 saat).', b.baslik)
      from oyun.hb_katilim k where k.bulusma_id = b.id and k.katildi is not null and k.puan is null and k.user_id <> b.vekil limit 1000;
      n_s := n_s + 1;
    exception when others then raise warning 'hb_tick son %: %', b.id, sqlerrm;
    end;
  end loop;
  delete from oyun.hb_bildirim_gun where gun < oyun.gk_gun(t) - 2;
  return jsonb_build_object('baslayan', n_b, 'biten', n_s);
end $f$;

-- ---------------------------------------------------------------- VEKİL KARNESİ
create or replace function oyun.tbmm_karne_hesap(t timestamptz) returns jsonb
language sql stable set search_path to '' as $f$
  with v as (select m.id mk, m.user_id u, m.bas, m.il_id, coalesce(pr.parti_id, 0) pid from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
             where m.tur = 'mv' and m.bit is null and not coalesce(pr.yasakli, false)),
  b as (select count(*)::numeric n from oyun.gk_birlesim x where x.acilis is not null and x.acilis >= (select min(bas) from v)),
  k as (select v.u,
          (select count(distinct y.birlesim_id) from oyun.gk_yoklama_kayit r join oyun.gk_yoklama y on y.id = r.yoklama_id where r.user_id = v.u and r.zaman >= v.bas) yok,
          (select count(*) from oyun.gk_birlesim x where x.acilis >= v.bas) bir,
          (select count(distinct t2.soz_id) from oyun.gk_tutanak t2 where t2.user_id = v.u and t2.tur = 'konusma' and t2.zaman >= v.bas and not t2.gizli) kon,
          (select count(*) from oyun.gk_tepki x join oyun.gk_tutanak t2 on t2.id = x.tutanak_id where t2.user_id = v.u and t2.zaman >= v.bas and x.tur = 'alkis' and x.vekil) alk,
          (select count(*) from oyun.kanunlar kn where kn.teklif_eden = v.u and kn.teklif_at >= v.bas) tek,
          (select count(*) from oyun.kanunlar kn where kn.teklif_eden = v.u and kn.teklif_at >= v.bas and kn.durum = 'yururlukte') yas,
          (select count(*) from oyun.kanunlar kn where kn.oy_bas >= v.bas and kn.oy_bit <= t) oyl,
          (select count(distinct o.kanun_id) from oyun.kanun_oylari o join oyun.kanunlar kn on kn.id = o.kanun_id where o.vekil = v.u and o.asama = 'ilk' and kn.oy_bas >= v.bas and kn.oy_bit <= t) oyk,
          (select count(*) from oyun.bakan_soru s where s.soran = v.u and s.zaman >= v.bas) sor,
          (select count(*) from oyun.hb_bulusma h where h.vekil = v.u and h.durum = 'planli' and h.bit <= t and h.bas >= v.bas) hb,
          (select round(avg(c.puan), 2) from oyun.hb_katilim c join oyun.hb_bulusma h on h.id = c.bulusma_id where h.vekil = v.u and h.bas >= v.bas and c.puan is not null) hbp,
          (select count(*) from oyun.gk_disiplin d where d.user_id = v.u and d.durum = 'uygulandi' and d.zaman >= v.bas) dis
        from v)
  select coalesce(jsonb_object_agg(z.u::text, jsonb_build_object('puan', z.puan, 'sira', z.sira)), '{}'::jsonb)
  from (select k.u, least(100, round(
            35 * case when k.bir > 0 then k.yok::numeric / k.bir else 0 end
          + 2 * least(k.kon, 10) + 0.05 * least(k.alk, 200)
          + 4 * least(k.tek, 3) + 4 * least(k.yas, 2)
          + 15 * case when k.oyl > 0 then k.oyk::numeric / k.oyl else 0 end
          + 1 * least(k.sor, 10) + 3 * least(k.hb, 5) + 2 * coalesce(k.hbp, 0)
          - 4 * k.dis)) puan,
          rank() over (order by least(100, round(35 * case when k.bir > 0 then k.yok::numeric / k.bir else 0 end + 2 * least(k.kon, 10) + 0.05 * least(k.alk, 200)
            + 4 * least(k.tek, 3) + 4 * least(k.yas, 2) + 15 * case when k.oyl > 0 then k.oyk::numeric / k.oyl else 0 end + 1 * least(k.sor, 10) + 3 * least(k.hb, 5)
            + 2 * coalesce(k.hbp, 0) - 4 * k.dis)) desc) sira
        from k) z
$f$;

create or replace function oyun.tbmm_karne_tablo(t timestamptz) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare c oyun.gk_onbellek; j jsonb;
begin
  select * into c from oyun.gk_onbellek where anahtar = 'karne';
  if c.anahtar is not null and c.zaman > t - interval '10 minutes' then return c.veri; end if;
  if not pg_try_advisory_xact_lock(hashtext('tbmm_karne')) then return coalesce(c.veri, '{}'::jsonb); end if;
  j := oyun.tbmm_karne_hesap(t);
  insert into oyun.gk_onbellek(anahtar, surum, veri, zaman) values ('karne', 0, j, t) on conflict (anahtar) do update set veri = excluded.veri, zaman = excluded.zaman;
  return j;
end $f$;

create or replace function public.tbmm_vekil_karne(p_kad text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); h oyun.profiller; m oyun.makamlar; tb jsonb;
begin
  if p_kad is null then h := p; else select * into h from oyun.profiller where kad = p_kad; end if;
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  select * into m from oyun.makamlar where user_id = h.id and tur = 'mv' and bit is null order by bas desc limit 1;
  if m.id is null then raise exception 'Bu oyuncu şu an milletvekili değil.'; end if;
  tb := oyun.tbmm_karne_tablo(t);
  return jsonb_build_object('kisi', oyun.gk_kimlik(h.id), 'bas', m.bas, 'puan', tb -> h.id::text -> 'puan', 'sira', tb -> h.id::text -> 'sira',
    'toplam', (select count(*) from jsonb_object_keys(tb)),
    'birlesim', (select count(*) from oyun.gk_birlesim x where x.acilis >= m.bas),
    'yoklama', (select count(distinct y.birlesim_id) from oyun.gk_yoklama_kayit r join oyun.gk_yoklama y on y.id = r.yoklama_id where r.user_id = h.id and r.zaman >= m.bas),
    'konusma', (select count(distinct t2.soz_id) from oyun.gk_tutanak t2 where t2.user_id = h.id and t2.tur = 'konusma' and t2.zaman >= m.bas and not t2.gizli),
    'kelime', (select coalesce(sum(s.kelime_kullanilan), 0) from oyun.meclis_soz s where s.user_id = h.id and s.gk and s.istek >= m.bas),
    'alkis', (select count(*) from oyun.gk_tepki x join oyun.gk_tutanak t2 on t2.id = x.tutanak_id where t2.user_id = h.id and t2.zaman >= m.bas and x.tur = 'alkis' and x.vekil),
    'laf', (select count(*) from oyun.gk_tutanak t2 where t2.user_id = h.id and t2.tur = 'laf' and t2.zaman >= m.bas),
    'kanun_teklif', (select count(*) from oyun.kanunlar kn where kn.teklif_eden = h.id and kn.teklif_at >= m.bas),
    'kanunlasan', (select count(*) from oyun.kanunlar kn where kn.teklif_eden = h.id and kn.teklif_at >= m.bas and kn.durum = 'yururlukte'),
    'oylama', (select count(*) from oyun.kanunlar kn where kn.oy_bas >= m.bas and kn.oy_bit <= t),
    'oy_kullandi', (select count(distinct o.kanun_id) from oyun.kanun_oylari o join oyun.kanunlar kn on kn.id = o.kanun_id where o.vekil = h.id and o.asama = 'ilk' and kn.oy_bas >= m.bas and kn.oy_bit <= t),
    'soru', (select count(*) from oyun.bakan_soru s where s.soran = h.id and s.zaman >= m.bas),
    'soru_cevap', (select count(*) from oyun.bakan_soru s where s.soran = h.id and s.zaman >= m.bas and s.yanit is not null),
    'gg', (select count(*) from oyun.gk_genel_gorusme g where g.veren = h.id and g.olusturma >= m.bas),
    'hb', (select count(*) from oyun.hb_bulusma b where b.vekil = h.id and b.durum = 'planli' and b.bit <= t and b.bas >= m.bas),
    'hb_katilim', (select count(*) from oyun.hb_katilim c join oyun.hb_bulusma b on b.id = c.bulusma_id where b.vekil = h.id and b.bas >= m.bas and c.katildi is not null),
    'hb_puan', (select round(avg(c.puan), 1) from oyun.hb_katilim c join oyun.hb_bulusma b on b.id = c.bulusma_id where b.vekil = h.id and b.bas >= m.bas and c.puan is not null),
    'komisyonlar', coalesce((select jsonb_agg(jsonb_build_object('kod', u.kom_kod, 'ad', kt.kisa, 'baskan', oyun.kom_baskan(u.kom_kod) = h.id))
                             from oyun.kom_uye u join oyun.kom_tanim kt on kt.kod = u.kom_kod where u.user_id = h.id and u.makam_id = m.id), '[]'::jsonb),
    'disiplin', coalesce((select jsonb_agg(jsonb_build_object('tur', d.tur, 'gerekce', d.gerekce, 'zaman', d.zaman) order by d.zaman desc)
                          from oyun.gk_disiplin d where d.user_id = h.id and d.durum = 'uygulandi' and d.zaman >= m.bas), '[]'::jsonb),
    'ihtar', (select count(*) from oyun.meclis_ihtar x where x.user_id = h.id and x.bas >= m.bas),
    'son_konusmalar', coalesce((select jsonb_agg(jsonb_build_object('z', x.zaman, 'm', left(x.metin, 200), 'st', x.soz_tur, 'birlesim', x.birlesim_id) order by x.zaman desc)
                                from (select * from oyun.gk_tutanak t2 where t2.user_id = h.id and t2.tur = 'konusma' and not t2.gizli and t2.zaman >= m.bas order by t2.id desc limit 5) x), '[]'::jsonb));
end $f$;

create or replace function public.tbmm_meclis_siralama(p_limit int default 20)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); tb jsonb := oyun.tbmm_karne_tablo(t);
begin
  return coalesce((select jsonb_agg(oyun.gk_kimlik(x.key::uuid) || jsonb_build_object('puan', x.value -> 'puan', 'sira', x.value -> 'sira') order by (x.value ->> 'sira')::int, x.key)
                   from (select * from jsonb_each(tb) order by (value ->> 'sira')::int limit least(greatest(coalesce(p_limit, 20), 1), 60)) x), '[]'::jsonb);
end $f$;

-- ---------------------------------------------------------------- MECLİS ÖZETİ (Meclis ekranının başı)
create or replace function public.tbmm_ozet()
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); b oyun.gk_birlesim := oyun.gk_su_an(); nx oyun.gk_birlesim; v boolean := oyun.gk_vekil(p.id);
  bk text[] := array(select m.bakanlik from oyun.makamlar m where m.user_id = p.id and m.tur = 'bakan' and m.bit is null);
begin
  select * into nx from oyun.gk_birlesim x where x.durum = 'planli' and x.plan_bit > t order by x.plan_bas limit 1;
  return jsonb_build_object('simdi', t, 'vekil', v, 'yonetebilir', oyun.gk_yonetebilir(p.id), 'hukumet', oyun.gk_hukumet(p.id),
    'birlesim', case when b.id is not null then jsonb_build_object('id', b.id, 'no', b.no, 'durum', b.durum, 'tur', b.tur, 'bitis', oyun.gk_bitis(b),
        'kursu', (select oyun.gk_kimlik(s.user_id) ->> 'ad' from oyun.meclis_soz s where s.birlesim_id = b.id and s.gk and s.durum = 'verildi' limit 1),
        'salonda', (select count(*) from oyun.gk_salonda x where x.birlesim_id = b.id and x.son > t - interval '90 seconds' and x.vekil),
        'izleyici', (select count(*) from oyun.gk_salonda x where x.birlesim_id = b.id and x.son > t - interval '90 seconds' and not x.vekil)) end,
    'sonraki', case when nx.id is not null then jsonb_build_object('bas', nx.plan_bas, 'tur', nx.tur, 'gerekce', nx.gerekce) end,
    'dolu', oyun.dolu_sandalye(),
    'gensoru_acik', oyun.hukumet_sistemi() = 1,
    'sayilar', jsonb_build_object(
      'komisyonlarim', (select count(*) from oyun.kom_uye u join oyun.makamlar m on m.id = u.makam_id and m.bit is null where u.user_id = p.id),
      'komisyon_gundem', (select count(*) from oyun.kom_kanun kk join oyun.kanunlar kn on kn.id = kk.kanun_id where kk.karar is null and kn.durum = 'gorusmede'
                            and oyun.kom_gecerli_uye(kk.kom_kod, p.id) and not exists (select 1 from oyun.kom_oy o where o.kanun_id = kn.id and o.uye = p.id)),
      'soru_bana', (select count(*) from oyun.bakan_soru s where s.yanit is null and (s.bakanlik = any(bk)
                      or (s.bakanlik = 'cby' and exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.tur = 'cb_yardimcisi' and m.bit is null)))),
      'soru_benim', (select count(*) from oyun.bakan_soru s where s.soran = p.id),
      'gg_imza', (select count(*) from oyun.gk_genel_gorusme g where g.durum = 'imza'),
      'arastirma', (select count(*) from oyun.meclis_arastirma a where a.durum in ('imza', 'oylamada', 'kurulus', 'calisma', 'rapor_oylama')),
      'dilekce_kom', case when oyun.kom_gecerli_uye('dilekce', p.id) then (select count(*) from oyun.tbmm_dilekce d where d.durum = 'komisyonda') end,
      'dilekce_bakanlik', case when cardinality(bk) > 0 then (select count(*) from oyun.tbmm_dilekce d where d.durum = 'bakanlikta' and d.bakanlik = any(bk)) end,
      'hb_ilimde', (select count(*) from oyun.hb_bulusma h where h.durum = 'planli' and h.il_id = p.il_id and h.bit > t),
      'hb_canli', (select count(*) from oyun.hb_bulusma h where h.durum = 'planli' and t >= h.bas and t < h.bit)));
end $f$;

-- Kıdem kaynakları
do $k$
begin
  if to_regclass('oyun.kidem_kaynak') is not null then
    insert into oyun.kidem_kaynak(kod, ad, puan, gunluk_tavan, sira) values
      ('halk_bulusma', 'Halk buluşması düzenlemek (en az 3 katılımcı)', 1, 1, 24),
      ('halk_bulusma_katil', 'Milletvekilinin halk buluşmasına katılmak', 0.5, 0.5, 25)
    on conflict (kod) do nothing;
  end if;
end $k$;

-- Zamanlayıcı
do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, komut, periyot_dk, ofset_dk, sira, aktif) values
      ('halk_bulusmasi', 'select oyun.hb_tick(oyun.simdi())', 5, 1, 132, true),
      ('tbmm_dilekce', 'select oyun.tbmm_dilekce_tick(oyun.simdi())', 30, 9, 133, true)
    on conflict (adim) do nothing;
  end if;
end $z$;

-- ---------------------------------------------------------------- YETKİLER
revoke all on function oyun.kom_sec(text, text, jsonb), oyun.tbmm_dilekce_json(oyun.tbmm_dilekce, uuid, boolean), oyun.tbmm_dilekce_tick(timestamptz),
  oyun.tbmm_soru_hedef_ad(text), oyun.tbmm_soru_json(oyun.bakan_soru, uuid), oyun.hb_ozet(oyun.hb_bulusma, uuid, timestamptz), oyun.hb_tick(timestamptz),
  oyun.tbmm_karne_hesap(timestamptz), oyun.tbmm_karne_tablo(timestamptz)
  from public, anon, authenticated;
do $g$
declare f text;
begin
  foreach f in array array[
    -- daha önce sunucuda olup istemciye kapalı kalanlar (14.10.2026 siyasi kurumlar)
    'komisyonlar()', 'komisyon_katil(text)', 'komisyon_ayril(text)', 'komisyon_baskan_oy(text, text)', 'komisyon_kanun(bigint)',
    'komisyon_oy(bigint, text, text)', 'komisyon_rapor(bigint, text)', 'komisyon_uye_cikar(text, text)', 'komisyon_havale(bigint, text)',
    'meclis_arastirmalar(integer)', 'meclis_arastirma_detay(bigint)', 'meclis_arastirma_ver(text, text)', 'meclis_arastirma_imza(bigint, boolean)',
    'meclis_arastirma_geri_cek(bigint)', 'meclis_arastirma_oy(bigint, text)', 'meclis_arastirma_uye_ol(bigint, boolean)', 'meclis_arastirma_baskan_oy(bigint, text)',
    'meclis_arastirma_davet(bigint, text, text)', 'meclis_arastirma_cevap(bigint, text)', 'meclis_arastirma_rapor(bigint, text, text)', 'meclis_arastirma_serh(bigint, text)',
    'vekil_oy_kaydi(text, integer)',
    -- yeni
    'kom_salon(text, bigint)', 'kom_konus(text, text)',
    'tbmm_dilekce_ver(text, text, text)', 'tbmm_dilekceler(text)', 'tbmm_dilekce_karar(bigint, text, text, text)', 'tbmm_dilekce_bakan_cevap(bigint, text)',
    'tbmm_soru_ver(text, text, text, bigint)', 'tbmm_soru_cevapla(bigint, text)', 'tbmm_sorular(text, text)',
    'hb_planla(timestamptz, text, text)', 'hb_iptal(bigint)', 'hb_liste(integer)', 'hb_detay(bigint)', 'hb_katil(bigint)', 'hb_soru_sor(bigint, text)',
    'hb_soru_begen(bigint)', 'hb_yanitla(bigint, text)', 'hb_puanla(bigint, integer)', 'hb_kaldir(bigint, text)', 'hb_soru_kaldir(bigint)',
    'tbmm_vekil_karne(text)', 'tbmm_meclis_siralama(integer)', 'tbmm_ozet()'] loop
    if to_regprocedure('public.' || f) is not null then
      execute format('revoke all on function public.%s from public, anon', f);
      execute format('grant execute on function public.%s to authenticated', f);
    end if;
  end loop;
end $g$;
