#!/bin/bash
# 197 valilik sınavı, vali havuzu, Cumhurbaşkanı ataması (yerel PG; tamamı geri alınır)
cd "$(dirname "$0")/.."
psql -h /tmp -U postgres -d oyun_test -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | sed 's/^psql:[^ ]*:[0-9]*: //' | grep -v "^CONTEXT\|^SAVEPOINT\|^ROLLBACK\|^BEGIN\|^INSERT\|^UPDATE\|^DELETE\|^DO\|^SET\|^CREATE\|^ALTER\|^REVOKE\|^GRANT\|^NOTICE\|^DROP\|^[0-9a-f-]\{36\}$\|^$"
begin;
\i sql/197_valilik.sql
select set_config('t.cb', (select user_id::text from oyun.makamlar where tur = 'cb' and bit is null limit 1), true);
-- siyasi makamı olmayan, 7 günden eski üç oyuncu
select set_config('t.a', (select id::text from oyun.profiller p where not yasakli and olusturma < now() - interval '8 days' and not exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null) order by kad limit 1), true);
select set_config('t.b', (select id::text from oyun.profiller p where not yasakli and olusturma < now() - interval '8 days' and not exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null) order by kad offset 1 limit 1), true);
select set_config('t.m', (select user_id::text from oyun.makamlar where tur = 'mv' and bit is null and user_id::text <> current_setting('t.cb') limit 1), true);
update oyun.cuzdan set para = para + 100000 where user_id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid, current_setting('t.m')::uuid);
update oyun.profiller set olusturma = now() - interval '30 days' where id = current_setting('t.m')::uuid;
select 'soru sayısı: ' || count(*) || ' · unvan yaması: ' || (position(' Valisi' in pg_get_functiondef('oyun.unvan(uuid)'::regprocedure)) > 0) from oyun.vali_sorulari;
-- a: başvuru, eğitim, sınav
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select set_config('t.c0', (select para::text from oyun.cuzdan where user_id = current_setting('t.a')::uuid), true);
select 'başvuru: ' || (public.vali_durum()->>'akademi') is null || ' → ' || (public.vali_basvur()->'akademi'->>'deneme') || ' · harç ' || (current_setting('t.c0')::numeric - (select para from oyun.cuzdan where user_id = current_setting('t.a')::uuid));
savepoint s; select public.vali_basvur(); rollback to s;
savepoint s; select public.vali_sinav_gonder('{}'); rollback to s;
select 'eğitimde soru yok: ' || jsonb_array_length(public.vali_durum()->'sorular');
update oyun.vali_akademi set baslangic = now() - interval '25 hours';
select 'sınav açıldı, soru: ' || jsonb_array_length(public.vali_durum()->'sorular');
-- yanlış cevaplarla: başarısız
select 'başarısız: ' || (r->>'puan') || ' geçti ' || (r->>'gecti') from (select public.vali_sinav_gonder((select jsonb_object_agg(q->>'id', '1') from jsonb_array_elements(public.vali_durum()->'sorular') q)) r) x;
savepoint s; select public.vali_sinav_gonder('{"1":1}'); rollback to s;
update oyun.vali_akademi set son_sinav = now() - interval '25 hours';
select 'yeni set farklı mı: ' || (oyun.vali_sinav_seti(current_setting('t.a')::uuid) is not null);
select 'başarılı: ' || (r->>'puan') || ' geçti ' || (r->>'gecti') from (select public.vali_sinav_gonder((select jsonb_object_agg(q.id::text, q.dogru::text) from oyun.vali_sorulari q where q.id = any (oyun.vali_sinav_seti(current_setting('t.a')::uuid)))) r) x;
select 'havuz: ' || (public.vali_durum()->'havuz'->>'durum') || ' · aday sayısı ' || jsonb_array_length(public.vali_durum()->'adaylar');
-- b ve m (milletvekili) doğrudan havuza (sınav geçmiş sayılır)
insert into oyun.vali_akademi(user_id, baslangic, sinav_gecildi) values (current_setting('t.b')::uuid, now() - interval '3 days', now()), (current_setting('t.m')::uuid, now() - interval '3 days', now());
insert into oyun.vali_havuz(user_id, giris) values (current_setting('t.b')::uuid, now()), (current_setting('t.m')::uuid, now());
-- yetkisiz atama, havuz dışı atama, siyasi engel
savepoint s; select public.vali_ata((select kad from oyun.profiller where id = current_setting('t.b')::uuid), 6); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.cb'), true);
savepoint s; select public.vali_ata((select kad from oyun.profiller p where not exists (select 1 from oyun.vali_havuz h where h.user_id = p.id) and id::text <> current_setting('t.cb') limit 1), 6); rollback to s;
savepoint s; select public.vali_ata((select kad from oyun.profiller where id = current_setting('t.m')::uuid), 6); rollback to s;
-- CB atar: a → Ankara(6); b → İstanbul(34); sonra b → Ankara (a görevden alınır), a → İzmir(35)
select 'a→6: ' || (public.vali_ata((select kad from oyun.profiller where id = current_setting('t.a')::uuid), 6)->'valiler')::text;
select 'ünvan a: ' || oyun.unvan(current_setting('t.a')::uuid);
select 'b→34, valiler: ' || jsonb_array_length(public.vali_ata((select kad from oyun.profiller where id = current_setting('t.b')::uuid), 34)->'valiler');
select 'b→6 (nakil): ' || (select string_agg(v->>'il' || '=' || (v->>'vali'), ', ') from jsonb_array_elements(public.vali_ata((select kad from oyun.profiller where id = current_setting('t.b')::uuid), 6)->'valiler') v);
select 'a→35: ' || (select string_agg(v->>'il' || '=' || (v->>'vali'), ', ') from jsonb_array_elements(public.vali_ata((select kad from oyun.profiller where id = current_setting('t.a')::uuid), 35)->'valiler') v);
select 'kayıtlar: ' || string_agg(durum || ':' || il_id, ' ' order by id) from oyun.icisleri_atama where tur = 'vali';
-- a: görevdeyken havuzdan çıkamaz; maaş; istifa; havuzdan çıkış ve dönüş
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select 'görevim: ' || (public.vali_durum()->'gorevim'->>'il');
savepoint s; select public.vali_havuz_cik(); rollback to s;
update oyun.vali_havuz set son_maas = son_maas - 2 where user_id = current_setting('t.a')::uuid;
select set_config('t.c1', (select para::text from oyun.cuzdan where user_id = current_setting('t.a')::uuid), true);
select 'tick: ' || oyun.vali_tick();
select 'maaş (2 gün): ' || ((select para from oyun.cuzdan where user_id = current_setting('t.a')::uuid) - current_setting('t.c1')::numeric) || ' · günlük ' || (public.vali_durum()->>'gunluk_maas');
select 'istifa: ' || coalesce(public.vali_istifa()->>'gorevim', 'görev yok');
select 'çıkış: ' || (public.vali_havuz_cik()->'havuz'->>'durum');
select set_config('request.jwt.claim.sub', current_setting('t.cb'), true);
savepoint s; select public.vali_ata((select kad from oyun.profiller where id = current_setting('t.a')::uuid), 35); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
select 'dönüş: ' || (public.vali_havuz_gir()->'havuz'->>'durum');
-- CB görevden alır
select set_config('request.jwt.claim.sub', current_setting('t.cb'), true);
select 'görevden al (6): ' || jsonb_array_length(public.vali_gorevden_al(6, 'Görev değişikliği')->'valiler');
savepoint s; select public.vali_gorevden_al(6); rollback to s;
-- İçişleri/Kamu yolu: havuz dışı oyuncuya vali teklifi engellenir; havuzdakine serbest
savepoint s; insert into oyun.icisleri_atama(il_id, tur, hedef, bakan, gerekce) select 1, 'vali', p.id, current_setting('t.cb')::uuid, 'Deneme teklifi: havuz dışı oyuncu' from oyun.profiller p where not exists (select 1 from oyun.vali_havuz h where h.user_id = p.id) limit 1; rollback to s;
insert into oyun.icisleri_atama(il_id, tur, hedef, bakan, gerekce) values (1, 'vali', current_setting('t.b')::uuid, current_setting('t.cb')::uuid, 'Deneme teklifi: havuzdaki oyuncu');
select 'İçişleri teklifi (havuzdaki): ' || durum from oyun.icisleri_atama where il_id = 1 and tur = 'vali';
savepoint s; insert into oyun.kamu_kurum_atama(gorev, il_id, aday, atayan) select 'vali', 2::smallint, p.id, current_setting('t.cb')::uuid from oyun.profiller p where not exists (select 1 from oyun.vali_havuz h where h.user_id = p.id) and p.id::text <> current_setting('t.cb') limit 1; rollback to s;
insert into oyun.kamu_kurum_atama(gorev, il_id, aday, atayan) values ('vali', 2, current_setting('t.b')::uuid, current_setting('t.cb')::uuid);
update oyun.kamu_kurum_atama set durum = 'aktif' where gorev = 'vali' and il_id = 2 and aday = current_setting('t.b')::uuid;
select 'kamu kabul → gerçek valilik: ' || (select string_agg(il_id || ':' || durum, ' ' order by id) from oyun.icisleri_atama where hedef = current_setting('t.b')::uuid);
update oyun.kamu_kurum_atama set durum = 'gorevden_alindi' where gorev = 'vali' and il_id = 2 and durum = 'aktif';
select 'kamu görevden al → ' || (select durum from oyun.icisleri_atama where hedef = current_setting('t.b')::uuid and il_id = 2);
-- siyasi makama gelen vali düşer
select public.vali_ata((select kad from oyun.profiller where id = current_setting('t.b')::uuid), 7) is not null;
insert into oyun.makamlar(tur, user_id, il_id, kaynak, bas) values ('mv', current_setting('t.b')::uuid, 7, 'atama', now());
select 'tick: ' || oyun.vali_tick();
select 'vekil olan vali: ' || (select durum from oyun.icisleri_atama where hedef = current_setting('t.b')::uuid and il_id = 7);
rollback;
SQL
