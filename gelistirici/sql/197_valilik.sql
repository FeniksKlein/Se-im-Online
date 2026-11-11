-- =====================================================================
--  197 (11.11.2026) · VALİLİK: SINAV, VALİ HAVUZU VE CUMHURBAŞKANI ATAMASI (Ercan)
--  • Avukatlıktaki düzenin aynısı: Mülki İdare Akademisi'ne başvuru (25.000 ₺ harç) → 24 saat eğitim →
--    20 soruluk sınav (en az 16 doğru; başarısızlıkta 24 saat sonra yeniden).
--  • Sınavı geçen oyuncu otomatik olarak VALİ HAVUZU'na girer. Havuzdaki aday dilediğinde havuzdan çıkar,
--    sınava yeniden girmeden geri dönebilir. Görevdeki vali havuzdan çıkmak için önce istifa eder.
--  • Cumhurbaşkanı havuzdan dilediğini dilediği ile atar (onay beklenmez; havuzda olmak rızadır), dilediğini
--    görevden alır ya da başka ile atar. Her ilin tek valisi olur.
--  • Vali, seçilmiş/siyasi makamla (CB, CB yardımcısı, bakan, milletvekili, belediye başkanı) birlikte
--    yürütülemez; böyle bir makama gelen vali görevinden düşer.
--  • Valilik kaydı mevcut oyun.icisleri_atama tablosunda tutulur (tur='vali', süresiz): valinin mevcut
--    yetkileri (il güvenlik emirleri, toplumsal olaylarda sert önlem) aynen çalışır. Vali günlük maaş alır
--    (milletvekili maaşı / 30).
--  • Mevcut iki atama yolu korunur ama artık havuza bağlıdır: İçişleri Bakanı'nın 7 günlük valilik teklifi ve
--    "Kamu kurumu atamaları"ndaki vali teklifi yalnız havuzdaki adaylara yapılabilir.
--  Mevcut işlevlere dokunulmaz (yalnız oyun.unvan'a vali ünvanı eklenir); veri değişmez.
-- =====================================================================

create table if not exists oyun.vali_sorulari(
  id int primary key, soru text not null, secenekler jsonb not null, dogru smallint not null check (dogru between 1 and 4));
create table if not exists oyun.vali_akademi(
  user_id uuid primary key, baslangic timestamptz not null, son_sinav timestamptz, son_puan int, sinav_gecildi timestamptz, deneme int not null default 0);
create table if not exists oyun.vali_havuz(
  user_id uuid primary key, giris timestamptz not null, durum text not null default 'aday' check (durum in ('aday','ayrildi')),
  cikis timestamptz, atama_sayisi int not null default 0, son_maas date);
create table if not exists oyun.vali_gecmis(
  id bigserial primary key, user_id uuid not null, olay text not null, il_id smallint, yapan uuid, aciklama text, zaman timestamptz not null);
create index if not exists vali_gecmis_u on oyun.vali_gecmis(user_id, id desc);
do $r$ declare x text; begin
  foreach x in array array['vali_sorulari','vali_akademi','vali_havuz','vali_gecmis'] loop
    execute format('alter table oyun.%I enable row level security', x);
    execute format('revoke all on oyun.%I from anon, authenticated', x);
  end loop;
end $r$;

insert into oyun.vali_sorulari(id, soru, secenekler, dogru) values
(1,'Türkiye''de kaç il vardır?','["67","77","81","85"]',3),
(2,'İlin genel idaresinin başı kimdir?','["Belediye başkanı","Vali","Kaymakam","İl emniyet müdürü"]',2),
(3,'Vali, ilde kimin temsilcisi ve idari yürütme vasıtasıdır?','["TBMM Başkanı''nın","Cumhurbaşkanı''nın","Belediye meclisinin","Yargıtay''ın"]',2),
(4,'Valileri kim atar ve görevden alır?','["İl genel meclisi","TBMM","Cumhurbaşkanı","Belediye başkanı"]',3),
(5,'İl yönetimini düzenleyen temel kanun hangisidir?','["5442 sayılı İl İdaresi Kanunu","5393 sayılı Belediye Kanunu","657 sayılı Devlet Memurları Kanunu","2820 sayılı Siyasi Partiler Kanunu"]',1),
(6,'Anayasa''ya göre illerin idaresi hangi esasa dayanır?','["Yetki genişliği","Federalizm","Kuvvetler birliği","Özerklik"]',1),
(7,'İlçenin genel idaresinin başı kimdir?','["Muhtar","Kaymakam","Belediye başkanı","İlçe emniyet müdürü"]',2),
(8,'Türkiye''de mülki idare bölümleri hangileridir?','["İl ve ilçe","Bölge ve eyalet","Belediye ve mahalle","Kanton ve komün"]',1),
(9,'İldeki genel kolluk (emniyet ve jandarma) kimin emrindedir?','["Belediye başkanının","Valinin","Baro başkanının","İl genel meclisi başkanının"]',2),
(10,'Vali aşağıdakilerden hangisini denetleyemez?','["İl millî eğitim müdürlüğünü","İl sağlık müdürlüğünü","Adli ve askerî kuruluşları","İl emniyet müdürlüğünü"]',3),
(11,'Anayasa''ya göre mahalli idareler hangileridir?','["Bakanlıklar ve valilikler","İl özel idaresi, belediye ve köy","Üniversiteler ve TRT","Kaymakamlıklar ve muhtarlıklar"]',2),
(12,'Merkezî idarenin mahalli idareler üzerindeki denetim yetkisine ne ad verilir?','["Hiyerarşi","İdari vesayet","Yetki genişliği","Yetki devri"]',2),
(13,'Vali, bir toplantı ya da gösteri yürüyüşünü en çok ne kadar süreyle erteleyebilir?','["48 saat","10 gün","Bir ay","Altı ay"]',3),
(14,'Vali, kamu düzeni için ildeki belirli yerlere giriş ve çıkışı en çok kaç gün sınırlayabilir?','["3 gün","7 gün","15 gün","60 gün"]',3),
(15,'Büyükşehir olan illerde kaldırılan il özel idaresinin yerine kurulan, valiye bağlı birim hangisidir?','["Kalkınma ajansı","Yatırım İzleme ve Koordinasyon Başkanlığı","İl encümeni","Büyükşehir belediye meclisi"]',2),
(16,'İlde afet ve acil durum yönetiminin sorumlusu kimdir?','["Belediye başkanı","Vali","İl sağlık müdürü","Garnizon komutanı"]',2),
(17,'İlde görevli bir memur hakkında soruşturma iznini kim verir?','["Vali","Belediye başkanı","Baro başkanı","İl genel meclisi"]',1),
(18,'Bir ilin kurulması, kaldırılması ya da adının değiştirilmesi nasıl yapılır?','["Vali kararıyla","Kanunla","Belediye meclisi kararıyla","İl genel meclisi kararıyla"]',2),
(19,'Olağanüstü hâli kim ilan eder?','["Vali","İçişleri Bakanı","Cumhurbaşkanı","Anayasa Mahkemesi"]',3),
(20,'Olağanüstü hâl en çok ne kadar süre için ilan edilebilir?','["Bir ay","Üç ay","Altı ay","İki yıl"]',3),
(21,'Olağanüstü hâl kararı kimin onayına sunulur?','["Yargıtay","TBMM","Danıştay","Sayıştay"]',2),
(22,'İl idare kuruluna kim başkanlık eder?','["Belediye başkanı","Vali","Defterdar","İl genel meclisi başkanı"]',2),
(23,'Anayasa''ya göre idarenin kuruluş ve görevleri hangi esaslara dayanır?','["Merkezden yönetim ve yerinden yönetim","Yalnız merkezden yönetim","Federal yönetim","Bölgesel özerklik"]',1),
(24,'Vali genel emir çıkarabilir mi?','["Hayır, hiçbir durumda","Evet; kanun ve Cumhurbaşkanlığı kararnamelerinin verdiği yetkiyi kullanmak için","Yalnız belediye meclisinin onayıyla","Yalnız seçim dönemlerinde"]',2),
(25,'Büyükşehir olmayan illerde il özel idaresinin başı kimdir?','["İl genel meclisi başkanı","Vali","Belediye başkanı","Defterdar"]',2),
(26,'Belediye başkanı göreve nasıl gelir?','["Cumhurbaşkanı atamasıyla","Seçimle","Vali atamasıyla","Sınavla"]',2),
(27,'Aşağıdakilerden hangisi valinin görevi değildir?','["İlin huzur ve güvenliğini sağlamak","Devlet dairelerini denetlemek","Kanun yapmak","Afetlerde koordinasyonu sağlamak"]',3),
(28,'Vali görevi başında olmadığında kendisine kim vekâlet eder?','["Belediye başkanı","Vali yardımcısı","İl emniyet müdürü","En kıdemli muhtar"]',2),
(29,'Köyün başında kim bulunur?','["Kaymakam","Muhtar","Vali yardımcısı","Belediye başkanı"]',2),
(30,'İllerde hükümet politikasının uygulanmasından ve kamu hizmetlerinin eşgüdümünden kim sorumludur?','["Vali","Baro başkanı","Ticaret odası başkanı","Milletvekili"]',1),
(31,'Bu oyunda vali olabilmenin ilk şartı nedir?','["Bir partiye üye olmak","Valilik sınavını geçip vali havuzuna girmek","Belediye başkanı seçilmek","En az üç şirket sahibi olmak"]',2),
(32,'Bu oyunda vali havuzundaki bir adayı valiliğe kim atar?','["Cumhurbaşkanı","Belediye başkanı","Baro başkanı","Ticaret odası başkanı"]',1),
(33,'Valilik sınavında başarılı sayılmak için 20 sorudan en az kaçı doğru yanıtlanmalıdır?','["10","12","14","16"]',4),
(34,'Sınavda başarısız olan aday ne kadar sonra yeniden sınava girebilir?','["1 saat","24 saat","7 gün","30 gün"]',2),
(35,'Aşağıdakilerden hangisi valiliğe atanmaya engeldir?','["Şirket sahibi olmak","Milletvekili, bakan ya da belediye başkanı olmak","Bir derneğe üye olmak","Gazete yazarı olmak"]',2),
(36,'Cumhurbaşkanı görevdeki bir valiyi başka bir ile atayabilir mi?','["Hayır, vali ömür boyu aynı ilde kalır","Evet, dilediği zaman","Yalnız TBMM onayıyla","Yalnız valinin dilekçesiyle"]',2),
(37,'Havuzda bekleyen bir aday havuzdan çıkabilir mi?','["Hayır","Evet; dilediğinde çıkar, sonra sınava yeniden girmeden geri dönebilir","Yalnız Cumhurbaşkanı izin verirse","Yalnız 30 gün sonra"]',2),
(38,'Bir ilde aynı anda kaç vali görev yapabilir?','["1","2","3","Sınır yoktur"]',1),
(39,'Akademiye başvurduktan sonra sınava girebilmek için ne kadar eğitim görülür?','["1 saat","24 saat","7 gün","Eğitim yoktur"]',2),
(40,'Görevdeki vali havuzdan çıkmak isterse önce ne yapmalıdır?','["Hiçbir şey; doğrudan çıkar","Valilik görevinden istifa etmelidir","Parti kurmalıdır","Yeniden sınava girmelidir"]',2),
(41,'Bu oyunda vali, ilindeki toplumsal olaylarda hangi yetkiye sahiptir?','["Kanun teklif etme","Kamu düzeni için sert önlem alma","Vergi oranı belirleme","Seçim sonucunu iptal etme"]',2),
(42,'Bu oyunda valiye hangi düzeyde maaş ödenir?','["Maaş ödenmez","Asgari ücret","Milletvekili maaşı düzeyinde günlük maaş","Şirket kârından pay"]',3)
on conflict (id) do update set soru = excluded.soru, secenekler = excluded.secenekler, dogru = excluded.dogru;

-- ---------------------------------------------------------------- yardımcılar
-- Boş metinde hata vermeyen temizleyici (metin_temizle boş metni reddeder)
create or replace function oyun.metin_ops(m text, n integer) returns text language sql set search_path = '' as $$
  select case when m is null or btrim(m) = '' then '' else oyun.metin_temizle(m, n) end
$$;
revoke all on function oyun.metin_ops(text, integer) from public, anon, authenticated;
create or replace function oyun.vali_atama(u uuid) returns oyun.icisleri_atama language sql stable set search_path = '' as $$
  select a from oyun.icisleri_atama a where a.hedef = u and a.tur = 'vali' and a.durum = 'aktif' and (a.bitis is null or a.bitis > oyun.simdi()) order by a.id desc limit 1
$$;
create or replace function oyun.il_valisi(p_il smallint) returns oyun.icisleri_atama language sql stable set search_path = '' as $$
  select a from oyun.icisleri_atama a where a.il_id = p_il and a.tur = 'vali' and a.durum = 'aktif' and (a.bitis is null or a.bitis > oyun.simdi()) order by a.id desc limit 1
$$;
create or replace function oyun.vali_siyasi_engel(u uuid) returns text language sql stable set search_path = '' as $$
  select oyun.makam_ad(m.tur, m.il_id, m.bakanlik) from oyun.makamlar m
   where m.user_id = u and m.bit is null and m.tur in ('cb','cb_yardimcisi','bakan','mv','bel') limit 1
$$;
create or replace function oyun.vali_kayit(u uuid, p_olay text, p_il smallint, p_yapan uuid, p_aciklama text) returns void language sql set search_path = '' as $$
  insert into oyun.vali_gecmis(user_id, olay, il_id, yapan, aciklama, zaman) values (u, p_olay, p_il, p_yapan, p_aciklama, oyun.simdi())
$$;
-- Her denemede değişen 20 soruluk set
create or replace function oyun.vali_sinav_seti(u uuid) returns int[] language sql stable set search_path = '' as $$
  with t as (select coalesce((select son_sinav::text from oyun.vali_akademi where user_id = u), 'ilk') tohum)
  select coalesce(array_agg(s.id order by s.sira), '{}'::int[]) from (
    select q.id, md5(q.id::text || u::text || t.tohum) sira from oyun.vali_sorulari q, t order by 2 limit 20) s
$$;

-- Görevlendirme çekirdeği (CB ataması ve kamu kurumu ataması buradan geçer)
create or replace function oyun.vali_gorevlendir(u uuid, p_il smallint, p_atayan uuid, p_kaynak text) returns bigint
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); r record; i bigint; ilad text; engel text;
begin
  select ad into ilad from oyun.iller where id = p_il;
  if ilad is null then raise exception 'İl bulunamadı.'; end if;
  if not exists (select 1 from oyun.vali_havuz h where h.user_id = u and h.durum = 'aday') then
    raise exception 'Bu oyuncu vali havuzunda değil. Vali olabilmek için valilik sınavını geçip havuza girmek gerekir.'; end if;
  if exists (select 1 from oyun.profiller where id = u and yasakli) then raise exception 'Bu oyuncu atanamaz.'; end if;
  engel := oyun.vali_siyasi_engel(u);
  if engel is not null then raise exception 'Valilik, seçilmiş ya da siyasi bir makamla birlikte yürütülemez (%).', engel; end if;
  perform pg_advisory_xact_lock(77118, 1);
  if exists (select 1 from oyun.icisleri_atama a where a.hedef = u and a.tur = 'vali' and a.il_id = p_il and a.durum = 'aktif' and (a.bitis is null or a.bitis > t)) then
    raise exception 'Bu oyuncu zaten % valisi.', ilad; end if;
  -- ilin mevcut valisi görevden alınır
  for r in update oyun.icisleri_atama a set durum = 'alindi', bitis = t, kapatma_gerekce = 'Yerine yeni vali atandı (Cumhurbaşkanı kararı).'
            where a.tur = 'vali' and a.il_id = p_il and a.durum = 'aktif' and a.hedef <> u returning a.hedef loop
    perform oyun.vali_kayit(r.hedef, 'alindi', p_il, p_atayan, 'Yerine yeni vali atandı');
    perform oyun.bildir(r.hedef, format('%s Valiliği görevinden alındın; yerine yeni vali atandı. Vali havuzunda aday olarak kalıyorsun.', ilad), t);
  end loop;
  -- kişinin başka ildeki valiliği sona erer (başka ile atama)
  for r in update oyun.icisleri_atama a set durum = 'alindi', bitis = t, kapatma_gerekce = format('%s Valiliğine atandı (Cumhurbaşkanı kararı).', ilad)
            where a.tur = 'vali' and a.hedef = u and a.durum = 'aktif' returning a.il_id loop
    perform oyun.vali_kayit(u, 'nakil', r.il_id, p_atayan, 'Başka ile atandı: ' || ilad);
  end loop;
  update oyun.icisleri_atama set durum = 'suresi_doldu' where tur = 'vali' and durum = 'teklif' and (il_id = p_il or hedef = u);
  insert into oyun.icisleri_atama(il_id, tur, hedef, bakan, gerekce, durum, olusturma, cevap_at, bas, bitis)
    values (p_il, 'vali', u, p_atayan, 'Cumhurbaşkanı kararıyla vali havuzundan valilik ataması.', 'aktif', t, t, t, null) returning id into i;
  update oyun.vali_havuz set atama_sayisi = atama_sayisi + 1, son_maas = (t at time zone 'Europe/Istanbul')::date where user_id = u;
  if p_kaynak <> 'kamu' then
    update oyun.kamu_kurum_atama set durum = 'gorevden_alindi', yanit_at = now()
     where gorev = 'vali' and durum = 'aktif' and (il_id = p_il or aday = u);
  end if;
  perform oyun.vali_kayit(u, 'atama', p_il, p_atayan, ilad || ' Valiliğine atandı');
  perform oyun.bildir(u, format('Cumhurbaşkanı seni %s Valiliğine atadı. Valilik makamı: Devlet › Valilik.', ilad), t);
  perform oyun.olay('makam', format('%s, Cumhurbaşkanı kararıyla %s Valiliğine atandı.', oyun.kad(u), ilad), p_il, null, t);
  perform oyun.gazete_ekle('duyuru', 'Valilik ataması #' || i, format('%s, %s Valiliğine atanmıştır.', oyun.kad(u), ilad), i, t);
  return i;
end $$;

create or replace function oyun.vali_gorev_bitir(p_atama bigint, p_durum text, p_gerekce text, p_yapan uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); x oyun.icisleri_atama; ilad text;
begin
  select * into x from oyun.icisleri_atama where id = p_atama and tur = 'vali' and durum = 'aktif' for update;
  if x.id is null then return; end if;
  select ad into ilad from oyun.iller where id = x.il_id;
  update oyun.icisleri_atama set durum = p_durum, bitis = t, kapatma_gerekce = p_gerekce where id = x.id;
  update oyun.kamu_kurum_atama set durum = 'gorevden_alindi', yanit_at = now() where gorev = 'vali' and durum = 'aktif' and il_id = x.il_id and aday = x.hedef;
  perform oyun.vali_kayit(x.hedef, p_durum, x.il_id, p_yapan, p_gerekce);
  perform oyun.olay('makam', format('%s Valisi %s %s.', ilad, oyun.kad(x.hedef),
    case p_durum when 'istifa' then 'görevinden istifa etti' when 'alindi' then 'görevden alındı' else 'görevinden ayrıldı' end), x.il_id, null, t);
end $$;

-- Kapı: valilik teklifi/ataması yalnız havuzdaki adaya; il başına tek vali
create or replace function oyun.vali_atama_kapi() returns trigger language plpgsql set search_path = '' as $$
begin
  if new.tur = 'vali' and new.durum in ('teklif', 'aktif') and (tg_op = 'INSERT' or old.durum is distinct from new.durum) then
    if not exists (select 1 from oyun.vali_havuz h where h.user_id = new.hedef and h.durum = 'aday') then
      raise exception 'Valilik için oyuncunun valilik sınavını geçip vali havuzunda bulunması gerekir (Devlet › Valilik).'; end if;
    if new.durum = 'aktif' and exists (select 1 from oyun.icisleri_atama a where a.id <> new.id and a.tur = 'vali' and a.durum = 'aktif'
         and (a.bitis is null or a.bitis > oyun.simdi()) and (a.il_id = new.il_id or a.hedef = new.hedef)) then
      raise exception 'Bu ilin görevde bir valisi var ya da oyuncu başka bir ilin valisi.'; end if;
  end if;
  return new;
end $$;
drop trigger if exists vali_atama_kapi_trg on oyun.icisleri_atama;
create trigger vali_atama_kapi_trg before insert or update of durum on oyun.icisleri_atama
  for each row execute function oyun.vali_atama_kapi();

-- "Kamu kurumu atamaları"ndaki vali teklifi de havuza bağlıdır; kabul edilince gerçek valilik kaydı açılır
create or replace function oyun.vali_kamu_kopru() returns trigger language plpgsql security definer set search_path = '' as $$
declare x oyun.icisleri_atama;
begin
  if new.gorev <> 'vali' then return new; end if;
  if tg_op = 'INSERT' then
    if not exists (select 1 from oyun.vali_havuz h where h.user_id = new.aday and h.durum = 'aday') then
      raise exception 'Valilik için oyuncunun valilik sınavını geçip vali havuzunda bulunması gerekir (Devlet › Valilik).'; end if;
    return new;
  end if;
  if new.durum = 'aktif' and old.durum is distinct from 'aktif' then
    perform oyun.vali_gorevlendir(new.aday, new.il_id, new.atayan, 'kamu');
  elsif new.durum = 'gorevden_alindi' and old.durum = 'aktif' then
    select * into x from oyun.icisleri_atama a where a.tur = 'vali' and a.il_id = new.il_id and a.hedef = new.aday and a.durum = 'aktif' limit 1;
    if x.id is not null then
      update oyun.icisleri_atama set durum = 'alindi', bitis = oyun.simdi(), kapatma_gerekce = 'Cumhurbaşkanı kararıyla görevden alındı.' where id = x.id;
      perform oyun.vali_kayit(new.aday, 'alindi', new.il_id, null, 'Kamu kurumu atamaları ekranından görevden alındı');
    end if;
  end if;
  return new;
end $$;
do $k$ begin
  if to_regclass('oyun.kamu_kurum_atama') is not null then
    drop trigger if exists vali_kamu_kopru_ekle on oyun.kamu_kurum_atama;
    create trigger vali_kamu_kopru_ekle before insert on oyun.kamu_kurum_atama for each row execute function oyun.vali_kamu_kopru();
    drop trigger if exists vali_kamu_kopru_guncel on oyun.kamu_kurum_atama;
    create trigger vali_kamu_kopru_guncel after update of durum on oyun.kamu_kurum_atama for each row execute function oyun.vali_kamu_kopru();
  end if;
end $k$;

-- ---------------------------------------------------------------- oyuncu RPC'leri
create or replace function public.vali_durum() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.vali_akademi; h oyun.vali_havuz; x oyun.icisleri_atama; sset int[];
  cb boolean;
begin
  select * into a from oyun.vali_akademi where user_id = p.id;
  select * into h from oyun.vali_havuz where user_id = p.id;
  x := oyun.vali_atama(p.id);
  cb := exists (select 1 from oyun.makamlar where tur = 'cb' and user_id = p.id and bit is null);
  if a.user_id is not null and a.baslangic + interval '24 hours' <= t and a.sinav_gecildi is null
     and (a.son_sinav is null or a.son_sinav <= t - interval '24 hours') then sset := oyun.vali_sinav_seti(p.id); end if;
  return jsonb_build_object('simdi', t, 'harc', 25000, 'hesap_uygun', p.olusturma <= t - interval '7 days', 'cb', cb,
    'siyasi_engel', oyun.vali_siyasi_engel(p.id), 'gunluk_maas', round(oyun.makam_maasi('mv', null) / 30),
    'akademi', case when a.user_id is null then null else jsonb_build_object('baslangic', a.baslangic, 'egitim_bitti', a.baslangic + interval '24 hours',
      'son_sinav', a.son_sinav, 'son_puan', a.son_puan, 'sinav_gecildi', a.sinav_gecildi, 'deneme', a.deneme) end,
    'sorular', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'soru', q.soru, 'secenekler', q.secenekler) order by array_position(sset, q.id)), '[]'::jsonb)
                  from oyun.vali_sorulari q where q.id = any (sset)),
    'havuz', case when h.user_id is null then null else jsonb_build_object('durum', h.durum, 'giris', h.giris, 'atama_sayisi', h.atama_sayisi) end,
    'gorevim', case when x.id is null then null else jsonb_build_object('atama_id', x.id, 'il_id', x.il_id, 'il', (select ad from oyun.iller where id = x.il_id),
      'bas', x.bas, 'bitis', x.bitis, 'son_karar', x.son_karar, 'atayan', oyun.kad(x.bakan)) end,
    'adaylar', (select coalesce(jsonb_agg(oyun.sm_kisi(v.user_id) || jsonb_build_object('giris', v.giris, 'atama_sayisi', v.atama_sayisi,
        'il', (select i.ad from oyun.iller i where i.id = (oyun.vali_atama(v.user_id)).il_id),
        'engel', oyun.vali_siyasi_engel(v.user_id), 'ev_il', (select i.ad from oyun.profiller pr join oyun.iller i on i.id = pr.il_id where pr.id = v.user_id)) order by v.giris), '[]'::jsonb)
      from oyun.vali_havuz v where v.durum = 'aday'),
    'valiler', (select coalesce(jsonb_agg(jsonb_build_object('il_id', a2.il_id, 'il', i.ad, 'vali', oyun.kad(a2.hedef), 'bas', a2.bas, 'bitis', a2.bitis,
        'sureli', a2.bitis is not null) order by i.ad), '[]'::jsonb)
      from oyun.icisleri_atama a2 join oyun.iller i on i.id = a2.il_id where a2.tur = 'vali' and a2.durum = 'aktif' and (a2.bitis is null or a2.bitis > t)),
    'iller', (select jsonb_agg(jsonb_build_object('id', i.id, 'ad', i.ad) order by i.ad) from oyun.iller i),
    'gecmis', (select coalesce(jsonb_agg(jsonb_build_object('olay', g.olay, 'il', (select ad from oyun.iller where id = g.il_id), 'aciklama', g.aciklama, 'zaman', g.zaman,
        'kisi', oyun.kad(g.user_id)) order by g.id desc), '[]'::jsonb)
      from (select * from oyun.vali_gecmis where olay in ('atama','alindi','istifa','nakil','dustu') order by id desc limit 15) g));
end $$;

create or replace function public.vali_basvur() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); harc numeric := 25000;
begin
  if p.yasakli then raise exception 'Hesabın kısıtlı.'; end if;
  if p.olusturma > t - interval '7 days' then raise exception 'Mülki İdare Akademisi için hesabın en az 7 günlük olmalı.'; end if;
  if exists (select 1 from oyun.vali_akademi where user_id = p.id) then raise exception 'Akademiye zaten kayıtlısın.'; end if;
  perform oyun.para_islem(p.id, -harc, 'vergi', 'Mülki İdare Akademisi kayıt harcı', t);
  perform oyun.hazine_kaydet('diger_gelir', harc / oyun.pazar_tl_milyar(), 'Mülki İdare Akademisi kayıt harcı');
  insert into oyun.vali_akademi(user_id, baslangic) values (p.id, t);
  perform oyun.vali_kayit(p.id, 'basvuru', null, null, 'Mülki İdare Akademisi''ne kaydoldu');
  return public.vali_durum();
end $$;

create or replace function public.vali_sinav_gonder(p_cevaplar jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); a oyun.vali_akademi; puan int; sset int[]; adet int; gecti boolean;
begin
  select * into a from oyun.vali_akademi where user_id = p.id for update;
  if a.user_id is null then raise exception 'Önce Mülki İdare Akademisi''ne kaydol.'; end if;
  if a.baslangic + interval '24 hours' > t then raise exception '24 saatlik eğitimi tamamlamadan sınava giremezsin.'; end if;
  if a.sinav_gecildi is not null then raise exception 'Sınavı zaten geçtin.'; end if;
  if a.son_sinav > t - interval '24 hours' then raise exception 'Yeniden sınav için 24 saat beklemelisin.'; end if;
  if p_cevaplar is null or jsonb_typeof(p_cevaplar) <> 'object' then raise exception 'Cevapları gönder.'; end if;
  sset := oyun.vali_sinav_seti(p.id); adet := coalesce(array_length(sset, 1), 0);
  if exists (select 1 from unnest(sset) i where not (p_cevaplar ? i::text) or (p_cevaplar->>i::text) not in ('1','2','3','4')) then
    raise exception 'Soru seti yenilenmiş ya da eksik cevap var; sınavı yeniden açıp % sorunun tamamını cevapla.', adet; end if;
  select count(*) into puan from oyun.vali_sorulari q where q.id = any (sset) and (p_cevaplar->>q.id::text) = q.dogru::text;
  gecti := puan >= 16;
  update oyun.vali_akademi set son_sinav = t, son_puan = puan, deneme = deneme + 1, sinav_gecildi = case when gecti then t end where user_id = p.id;
  perform oyun.vali_kayit(p.id, 'sinav', null, null, format('Valilik sınavı: %s/%s · %s', puan, adet, case when gecti then 'başarılı' else 'başarısız' end));
  if gecti then
    insert into oyun.vali_havuz(user_id, giris, durum) values (p.id, t, 'aday')
      on conflict (user_id) do update set durum = 'aday', giris = excluded.giris, cikis = null;
    perform oyun.vali_kayit(p.id, 'havuz_giris', null, null, 'Vali havuzuna girdi');
    perform oyun.bildir(u.user_id, format('%s valilik sınavını geçti ve vali havuzuna girdi. Devlet › Valilik ekranından bir ile atayabilirsin.', p.kad), t)
       from oyun.makamlar u where u.tur = 'cb' and u.bit is null and u.user_id <> p.id;
  end if;
  return jsonb_build_object('puan', puan, 'gecti', gecti, 'toplam', adet,
    'yanlislar', (select coalesce(jsonb_agg(q.soru order by array_position(sset, q.id)), '[]'::jsonb)
                    from oyun.vali_sorulari q where q.id = any (sset) and (p_cevaplar->>q.id::text) <> q.dogru::text));
end $$;

create or replace function public.vali_havuz_cik() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if (oyun.vali_atama(p.id)).id is not null then raise exception 'Görevdeki vali havuzdan çıkamaz. Önce valilik görevinden istifa et.'; end if;
  update oyun.vali_havuz set durum = 'ayrildi', cikis = t where user_id = p.id and durum = 'aday';
  if not found then raise exception 'Vali havuzunda değilsin.'; end if;
  update oyun.icisleri_atama set durum = 'red', cevap_at = t where tur = 'vali' and hedef = p.id and durum = 'teklif';
  perform oyun.vali_kayit(p.id, 'havuz_cikis', null, null, 'Vali havuzundan kendi isteğiyle çıktı');
  return public.vali_durum();
end $$;

create or replace function public.vali_havuz_gir() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  if not exists (select 1 from oyun.vali_akademi where user_id = p.id and sinav_gecildi is not null) then raise exception 'Havuza girmek için önce valilik sınavını geçmelisin.'; end if;
  insert into oyun.vali_havuz(user_id, giris, durum) values (p.id, t, 'aday')
    on conflict (user_id) do update set durum = 'aday', giris = excluded.giris, cikis = null where oyun.vali_havuz.durum = 'ayrildi';
  if not found then raise exception 'Zaten vali havuzundasın.'; end if;
  perform oyun.vali_kayit(p.id, 'havuz_giris', null, null, 'Vali havuzuna yeniden girdi');
  return public.vali_durum();
end $$;

create or replace function public.vali_istifa() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x oyun.icisleri_atama;
begin
  x := oyun.vali_atama(p.id);
  if x.id is null then raise exception 'Görevde olduğun bir valilik yok.'; end if;
  perform oyun.vali_gorev_bitir(x.id, 'istifa', 'Vali kendi isteğiyle görevinden ayrıldı.', p.id);
  perform oyun.bildir(m.user_id, format('%s Valisi %s görevinden istifa etti. Havuzdan yeni bir vali atayabilirsin.', (select ad from oyun.iller where id = x.il_id), p.kad))
     from oyun.makamlar m where m.tur = 'cb' and m.bit is null;
  return public.vali_durum();
end $$;

-- ---------------------------------------------------------------- Cumhurbaşkanı RPC'leri
create or replace function public.vali_ata(p_kad text, p_il integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  if not exists (select 1 from oyun.makamlar where tur = 'cb' and user_id = p.id and bit is null) then raise exception 'Valileri yalnız Cumhurbaşkanı atar.'; end if;
  h := oyun.profil_bul(p_kad);
  if h.id = p.id then raise exception 'Kendini vali atayamazsın.'; end if;
  perform oyun.vali_gorevlendir(h.id, p_il::smallint, p.id, 'cb');
  return public.vali_durum();
end $$;

create or replace function public.vali_gorevden_al(p_il integer, p_gerekce text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); x oyun.icisleri_atama; g text;
begin
  if not exists (select 1 from oyun.makamlar where tur = 'cb' and user_id = p.id and bit is null) then raise exception 'Valileri yalnız Cumhurbaşkanı görevden alır.'; end if;
  x := oyun.il_valisi(p_il::smallint);
  if x.id is null then raise exception 'Bu ilin görevde bir valisi yok.'; end if;
  g := coalesce(nullif(oyun.metin_ops(p_gerekce, 300), ''), 'Cumhurbaşkanı kararıyla görevden alındı.');
  perform oyun.vali_gorev_bitir(x.id, 'alindi', g, p.id);
  perform oyun.bildir(x.hedef, format('Cumhurbaşkanı seni %s Valiliği görevinden aldı. Vali havuzunda aday olarak kalıyorsun. Gerekçe: %s', (select ad from oyun.iller where id = x.il_id), g));
  return public.vali_durum();
end $$;

-- ---------------------------------------------------------------- günlük: maaş ve siyasi makam çakışması
create or replace function oyun.vali_tick() returns int language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); bugun date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; x record; n int := 0; maas numeric; gun int; engel text;
begin
  if not pg_try_advisory_xact_lock(hashtext('oyun.vali_tick')) then return 0; end if;
  for x in select a.* from oyun.icisleri_atama a where a.tur = 'vali' and a.durum = 'aktif' and (a.bitis is null or a.bitis > t) loop
    engel := oyun.vali_siyasi_engel(x.hedef);
    if engel is not null or exists (select 1 from oyun.profiller where id = x.hedef and yasakli) then
      perform oyun.vali_gorev_bitir(x.id, 'alindi', coalesce('Siyasi makama geldiği için valilik görevi sona erdi: ' || engel, 'Hesap kısıtlandığı için valilik görevi sona erdi.'), null);
      perform oyun.bildir(x.hedef, 'Valilik, seçilmiş ya da siyasi bir makamla birlikte yürütülemediği için valilik görevin sona erdi.', t);
      n := n + 1; continue;
    end if;
    select least(7, bugun - coalesce(h.son_maas, bugun)) into gun from oyun.vali_havuz h where h.user_id = x.hedef;
    if coalesce(gun, 0) > 0 then
      maas := round(oyun.makam_maasi('mv', null) / 30) * gun;
      perform oyun.para_islem(x.hedef, maas, 'maas', format('%s Valiliği maaşı (%s gün)', (select ad from oyun.iller where id = x.il_id), gun), t);
      update oyun.vali_havuz set son_maas = bugun where user_id = x.hedef;
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------- ünvan, yetki, zamanlayıcı
do $u$
declare d text; y text; ek text := E'    (select i.ad || '' Valisi'' from oyun.icisleri_atama a join oyun.iller i on i.id = a.il_id\n       where a.hedef = u and a.tur = ''vali'' and a.durum = ''aktif'' and (a.bitis is null or a.bitis > oyun.simdi()) limit 1),\n';
begin
  d := pg_get_functiondef('oyun.unvan(uuid)'::regprocedure);
  if position(''' Valisi''' in d) > 0 then return; end if;
  y := replace(d, E'    oyun.gby_unvan(u)\n', ek || E'    oyun.gby_unvan(u)\n');
  if y = d then raise notice '197: oyun.unvan beklenen biçimde değil; vali ünvanı eklenmedi'; return; end if;
  execute y;
exception when others then raise notice '197: ünvan yaması atlandı: %', sqlerrm;
end $u$;

revoke all on function oyun.vali_atama(uuid), oyun.il_valisi(smallint), oyun.vali_siyasi_engel(uuid), oyun.vali_kayit(uuid, text, smallint, uuid, text),
  oyun.vali_sinav_seti(uuid), oyun.vali_gorevlendir(uuid, smallint, uuid, text), oyun.vali_gorev_bitir(bigint, text, text, uuid),
  oyun.vali_atama_kapi(), oyun.vali_kamu_kopru(), oyun.vali_tick() from public, anon, authenticated;
do $g$ declare f text; begin
  foreach f in array array['vali_durum()','vali_basvur()','vali_sinav_gonder(jsonb)','vali_havuz_cik()','vali_havuz_gir()','vali_istifa()',
    'vali_ata(text,integer)','vali_gorevden_al(integer,text)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $g$;

do $z$
begin
  if to_regclass('oyun.zamanlayici_adim') is not null then
    insert into oyun.zamanlayici_adim(adim, sira, periyot_dk, ofset_dk, komut, aktif)
    values ('valilik', 82, 60, 23, 'select oyun.vali_tick()', true)
    on conflict (adim) do nothing;
  end if;
exception when others then raise notice 'valilik zamanlanamadı: %', sqlerrm;
end $z$;
