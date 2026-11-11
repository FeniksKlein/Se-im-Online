#!/bin/bash
# 189 şirketten kişiye ticari ödeme + 190 yatırım kredisi (yerel PG; tamamı geri alınır)
psql -h /tmp -U postgres -d oyun_test -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 | sed 's/^psql:<stdin>:[0-9]*: //' | grep -v "^CONTEXT\|^SAVEPOINT\|^ROLLBACK\|^BEGIN\|^INSERT\|^UPDATE\|^DO\|^[0-9a-f-]\{36\}"
begin;
select set_config('t.a', (select id::text from oyun.profiller order by kad limit 1), true), set_config('t.b', (select id::text from oyun.profiller order by kad offset 1 limit 1), true);
insert into oyun.sirketler(id, ad, sektor, kurucu, sermaye, kasa, kurulus, yonetici) overriding system value values
  (900101,'Deneme Yayınevi A.Ş.','tarim',current_setting('t.a')::uuid,200000,900000, now()-interval '10 days', current_setting('t.a')::uuid);
insert into oyun.sirket_ortaklari(sirket_id,user_id,pay) values (900101,current_setting('t.a')::uuid,100);
insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama,faaliyet_gelir) values (900101, now()-interval '2 days', 400000, 'Günlük faaliyet deneme', 400000);
update oyun.cuzdan set para = para + 0 where user_id = current_setting('t.b')::uuid;
select oyun.cuzdanim(current_setting('t.b')::uuid);
select set_config('t.cuz0', (select para::text from oyun.cuzdan where user_id=current_setting('t.b')::uuid), true);
-- ===== 189 =====
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
savepoint s; select public.sirket_fatura_kes(900101,'telif',50000,'Kendi şirketime telif faturası'); rollback to s;
select set_config('request.jwt.claim.sub', current_setting('t.b'), true);
select 'fatura: ' || public.sirket_fatura_kes(900101,'telif',100000,'"Cumhuriyetin İlk Yılları" kitabının telif bedeli')::text;
select 'fatura2: ' || public.sirket_fatura_kes(900101,'danismanlik',200000,'Pazarlama danışmanlığı, 4 haftalık proje')::text;
select set_config('request.jwt.claim.sub', current_setting('t.a'), true);
savepoint s; select public.sirket_kisi_ode(900101,(select kad from oyun.profiller where id=current_setting('t.b')::uuid),1000); rollback to s;
select 'tavan: ' || (public.sirket_fatura_panel(900101) - 'bekleyen' - 'bakiyeler')::text;
select 'onay1: ' || public.sirket_fatura_karar((select min(id) from oyun.sirket_fatura where sirket_id=900101), true)::text;
savepoint s; select public.sirket_fatura_karar((select max(id) from oyun.sirket_fatura where sirket_id=900101), true); rollback to s;
select 'ödeme: ' || public.sirket_kisi_ode(900101,(select kad from oyun.profiller where id=current_setting('t.b')::uuid),null)::text;
select 'kişinin cüzdan artışı: ' || ((select para from oyun.cuzdan where user_id=current_setting('t.b')::uuid) - current_setting('t.cuz0')::numeric);
select 'kasa: ' || kasa from oyun.sirketler where id=900101;
savepoint s; select public.sirket_kisi_ode(900101,(select kad from oyun.profiller where id=current_setting('t.b')::uuid),1); rollback to s;
-- ===== 190 =====
select 'uygunluk+şube: ' || (public.yatirim_kredisi_panel(900101, 35) - 'krediler')::text;
savepoint s; select public.sirket_sube_ac_kredili(900101, 35, 99999999, 60); rollback to s;
select set_config('t.azami', (public.yatirim_kredisi_panel(900101, 35)->'sube'->>'azami_kredi'), true);
select 'kredili şube: ' || (public.sirket_sube_ac_kredili(900101, 35, current_setting('t.azami')::numeric, 60) - 'dekorasyon_donanim' - 'depozito' - 'ilk_stok' - 'personel_hazirlik' - 'izin_ruhsat')::text;
select 'kasa sonrası: ' || kasa || ' şube: ' || (select count(*) from oyun.sirket_il_subeleri where sirket_id=900101) from oyun.sirketler where id=900101;
-- 3 gün sonra tahsilat
update oyun.yatirim_kredisi set son_tahsil = son_tahsil - 3 where sirket_id=900101;
select 'tick: ' || oyun.yatirim_kredisi_tick();
select 'kredi: ' || row_to_json(k)::text from (select taksit, toplam, kalan, gecikmis, durum from oyun.yatirim_kredisi where sirket_id=900101) k;
-- kasa boşalırsa gecikme
update oyun.sirketler set kasa = 1000 where id=900101;
update oyun.yatirim_kredisi set son_tahsil = son_tahsil - 2 where sirket_id=900101;
select 'tick2: ' || oyun.yatirim_kredisi_tick();
select 'gecikme: ' || row_to_json(k)::text from (select kalan, gecikmis, durum from oyun.yatirim_kredisi where sirket_id=900101) k;
select 'cari kapalı: ' || (public.ortak_cari_panel(900101)->>'neden');
savepoint s; select public.sirket_sube_ac_kredili(900101, 6, 10000, 30); rollback to s;
update oyun.sirketler set kasa = 5000000 where id=900101;
select 'kapat: ' || public.yatirim_kredisi_ode((select id from oyun.yatirim_kredisi where sirket_id=900101), null)::text;
select 'son: ' || row_to_json(k)::text from (select kalan, gecikmis, durum from oyun.yatirim_kredisi where sirket_id=900101) k;
rollback;
SQL
