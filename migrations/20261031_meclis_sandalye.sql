-- 156 (31.10.2026) — MECLİS SANDALYE DAĞILIMI ve MİLLETVEKİLİ ÖZ GEÇMİŞİ (TBMM sitesi düzeninde)
-- İstek (Ercan): Meclis'te gerçek TBMM sitesindeki gibi partilerin sandalye dağılımı (her an güncel); partiye tıklayınca
-- vekillerin adı, portresi ve ili; vekile tıklayınca öz geçmişi, Kürsü hesabı vb.
--  * Dönemler: sonucu açıklanmış ve vekil çıkarmış her genel/erken milletvekili seçimi bir yasama dönemi başlatır (1., 2. ...).
--  * Güncel dönem anlık hesaplanır: vekilin bugünkü partisi sayılır (parti değiştiren, istifa eden anında yansır).
--  * Geçmiş dönemler: o dönemde görev yapan vekiller, seçildikleri partiye göre.
-- Yalnız okuma fonksiyonları; oyuncu verisine dokunmaz.

create or replace function oyun.mv_donemleri() returns table(no int, secim_id bigint, bas timestamptz, bitis timestamptz)
language sql stable set search_path = '' as $$
  with s as (
    select s.id, coalesce(s.goreve_bas, s.sonuc_at) as b from oyun.secimler s
    where s.tur = 'mv' and coalesce(s.goreve_bas, s.sonuc_at) <= oyun.simdi()
      and exists(select 1 from oyun.makamlar m where m.secim_id = s.id and m.tur = 'mv'))
  select (row_number() over (order by s.b))::int, s.id, s.b, lead(s.b) over (order by s.b) from s
$$;

-- Bir milletvekilliği kaydının dönemi (seçimle gelen: seçimin dönemi; sonradan gelen: başladığı tarihe göre; ilk seçimden önce 0)
create or replace function oyun.mv_donem_no(p_secim bigint, p_bas timestamptz) returns int
language sql stable set search_path = '' as $$
  select coalesce((select d.no from oyun.mv_donemleri() d where d.secim_id = p_secim),
                  (select max(d.no) from oyun.mv_donemleri() d where d.bas <= p_bas + interval '6 hours'), 0)
$$;

create or replace function oyun.vekil_gorevleri(u uuid) returns jsonb
language sql stable set search_path = '' as $$
  select coalesce(jsonb_agg(x.g order by x.s), '[]'::jsonb) from (
    select 1 as s, 'TBMM Başkanı' as g where exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'tbmm' and m.bit is null)
    union all select 2, 'TBMM Başkanvekili' where exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'bskv' and m.bit is null)
    union all select 3, 'Genel Başkan' where exists (select 1 from oyun.partiler pa where pa.gb = u and not pa.kapali)
    union all select 3, 'Grup Başkanı' where exists (select 1 from oyun.profiller pr where pr.id = u and pr.parti_id is not null and oyun.grup_baskani(pr.parti_id) = u)
    union all select 4, 'Grup Başkanvekili' where exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'grup_bskv' and m.bit is null)
    union all select 5, coalesce(b.ad, 'Bakan') from oyun.makamlar m left join oyun.bakanliklar b on b.kod = m.bakanlik where m.user_id = u and m.tur = 'bakan' and m.bit is null
    union all select 5, 'Cumhurbaşkanı Yardımcısı' where exists (select 1 from oyun.makamlar m where m.user_id = u and m.tur = 'cb_yardimcisi' and m.bit is null)
    union all select 6, 'Genel Başkan Yardımcısı' where exists (select 1 from oyun.parti_gby y where y.user_id = u)
  ) x
$$;

-- Sandalye dağılımı
create or replace function public.meclis_sandalye(p_donem int default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare guncel int := coalesce((select max(no) from oyun.mv_donemleri()), 0); d int; toplam int := coalesce((select sum(i.mv)::int from oyun.iller i), 600); r jsonb;
begin
  d := coalesce(p_donem, guncel);
  if d = guncel then
    with v as (select m.user_id, pr.parti_id from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id where m.tur = 'mv' and m.bit is null and not pr.yasakli)
    select jsonb_build_object(
      'partiler', coalesce((select jsonb_agg(oyun.parti_json(q.parti_id) || jsonb_build_object('n', q.n) order by q.n desc, q.parti_id)
                  from (select parti_id, count(distinct user_id)::int n from v where parti_id is not null group by parti_id) q), '[]'::jsonb),
      'bagimsiz', (select count(distinct user_id)::int from v where parti_id is null),
      'dolu', (select count(distinct user_id)::int from v)) into r;
  else
    with v as (select distinct on (m.user_id) m.user_id, m.parti_id from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
               where m.tur = 'mv' and not pr.yasakli and oyun.mv_donem_no(m.secim_id, m.bas) = d order by m.user_id, m.bas)
    select jsonb_build_object(
      'partiler', coalesce((select jsonb_agg(coalesce(oyun.parti_json(q.parti_id), jsonb_build_object('id', q.parti_id, 'ad', 'Kapanmış parti', 'kisa', '—', 'renk', '#8E97B5')) || jsonb_build_object('n', q.n) order by q.n desc, q.parti_id)
                  from (select parti_id, count(*)::int n from v where parti_id is not null group by parti_id) q), '[]'::jsonb),
      'bagimsiz', (select count(*)::int from v where parti_id is null),
      'dolu', (select count(*)::int from v)) into r;
  end if;
  return r || jsonb_build_object('donem', d, 'guncel', d = guncel, 'toplam', toplam,
    'bos', case when d = guncel then greatest(0, toplam - (r ->> 'dolu')::int) else null end,
    'guncelleme', oyun.simdi(),
    'donemler', coalesce((select jsonb_agg(jsonb_build_object('no', x.no, 'bas', x.bas, 'bit', x.bitis) order by x.no desc) from oyun.mv_donemleri() x), '[]'::jsonb));
end $$;

-- Vekil listesi: p_donem null = güncel dönem, 0 = tüm dönemler; p_parti / p_bagimsiz süzgeci
create or replace function public.meclis_vekiller(p_donem int default null, p_parti bigint default null, p_bagimsiz boolean default false) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare guncel int := coalesce((select max(no) from oyun.mv_donemleri()), 0); d int := coalesce(p_donem, guncel);
begin
  if d = guncel and p_donem is distinct from 0 then
    return coalesce((select jsonb_agg(jsonb_build_object('kad', pr.kad, 'il', i.ad, 'il_id', m.il_id, 'parti', oyun.parti_json(pr.parti_id),
        'secildigi', case when m.parti_id is distinct from pr.parti_id then oyun.parti_json(m.parti_id) end,
        'gorevler', oyun.vekil_gorevleri(pr.id), 'aktif', true) order by pr.kad collate "tr-TR-x-icu")
      from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id left join oyun.iller i on i.id = m.il_id
      where m.tur = 'mv' and m.bit is null and not pr.yasakli
        and (p_parti is null or pr.parti_id = p_parti) and (not p_bagimsiz or pr.parti_id is null)), '[]'::jsonb);
  elsif d = 0 then
    return coalesce((select jsonb_agg(z.j order by z.kad collate "tr-TR-x-icu") from (
      select pr.kad, jsonb_build_object('kad', pr.kad,
        'il', (select i.ad from oyun.makamlar m2 left join oyun.iller i on i.id = m2.il_id where m2.user_id = pr.id and m2.tur = 'mv' order by m2.bas desc limit 1),
        'parti', oyun.parti_json(pr.parti_id), 'aktif', exists(select 1 from oyun.makamlar m3 where m3.user_id = pr.id and m3.tur = 'mv' and m3.bit is null),
        'donemler', (select jsonb_agg(distinct oyun.mv_donem_no(m4.secim_id, m4.bas)) from oyun.makamlar m4 where m4.user_id = pr.id and m4.tur = 'mv'),
        'gorevler', '[]'::jsonb) j
      from oyun.profiller pr where not pr.yasakli and exists(select 1 from oyun.makamlar m where m.user_id = pr.id and m.tur = 'mv')
        and (p_parti is null or pr.parti_id = p_parti) and (not p_bagimsiz or pr.parti_id is null)) z), '[]'::jsonb);
  else
    return coalesce((select jsonb_agg(z.j order by z.kad collate "tr-TR-x-icu") from (
      select distinct on (m.user_id) pr.kad, jsonb_build_object('kad', pr.kad, 'il', i.ad, 'il_id', m.il_id,
        'parti', oyun.parti_json(m.parti_id), 'aktif', m.bit is null, 'gorevler', '[]'::jsonb) j
      from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id left join oyun.iller i on i.id = m.il_id
      where m.tur = 'mv' and not pr.yasakli and oyun.mv_donem_no(m.secim_id, m.bas) = d
        and (p_parti is null or m.parti_id = p_parti) and (not p_bagimsiz or m.parti_id is null)
      order by m.user_id, m.bas) z), '[]'::jsonb);
  end if;
end $$;

-- Milletvekili öz geçmişi
create or replace function public.milletvekili_ozgecmis(p_kad text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare pr oyun.profiller; t timestamptz := oyun.simdi(); mvm oyun.makamlar; oy_n int; oylanabilir int;
begin
  select * into pr from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, ''))) and not yasakli;
  if pr.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  select * into mvm from oyun.makamlar where user_id = pr.id and tur = 'mv' and bit is null order by bas desc limit 1;
  select count(*) into oy_n from oyun.kanun_oylari where vekil = pr.id;
  select count(distinct k.id) into oylanabilir from oyun.kanunlar k join oyun.makamlar m on m.user_id = pr.id and m.tur = 'mv'
   where k.oy_bas is not null and k.oy_bas < t and k.oy_bas >= m.bas and (m.bit is null or k.oy_bas < m.bit);
  return jsonb_build_object(
    'kad', pr.kad, 'ben', pr.id = auth.uid(),
    'biyografi', (select k.biyografi from oyun.oyuncu_kimlik k where k.user_id = pr.id),
    'il', (select i.ad from oyun.iller i where i.id = pr.il_id),
    'parti', oyun.parti_json(pr.parti_id),
    'katilim', pr.olusturma,
    'kidem', (select c.kidem from oyun.cuzdan c where c.user_id = pr.id),
    'aktif', case when pr.son_gorulme > t - interval '10 minutes' then 'cevrimici' when pr.son_gorulme > t - interval '1 day' then 'bugun'
                  when pr.son_gorulme > t - interval '7 days' then 'hafta' else 'uzun' end,
    'mv', case when mvm.id is not null then jsonb_build_object('il', (select i.ad from oyun.iller i where i.id = mvm.il_id), 'bas', mvm.bas,
            'donem', oyun.mv_donem_no(mvm.secim_id, mvm.bas), 'secildigi', oyun.parti_json(mvm.parti_id),
            'nasil', case when mvm.secim_id is not null then 'Seçimle' else 'Sıradaki aday olarak' end) end,
    'gorevler', oyun.vekil_gorevleri(pr.id),
    'donemler', coalesce((select jsonb_agg(jsonb_build_object('no', oyun.mv_donem_no(m.secim_id, m.bas), 'il', i.ad, 'parti', oyun.parti_json(m.parti_id),
          'bas', m.bas, 'bit', m.bit, 'neden', m.bitis_neden) order by m.bas desc)
        from oyun.makamlar m left join oyun.iller i on i.id = m.il_id where m.user_id = pr.id and m.tur = 'mv'), '[]'::jsonb),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('makam', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'bit', m.bit) order by m.bas desc)
        from oyun.makamlar m where m.user_id = pr.id and m.tur <> 'mv'), '[]'::jsonb),
    'meclis', jsonb_build_object(
      'teklif', (select count(*) from oyun.kanunlar k where k.teklif_eden = pr.id),
      'yasalasan', (select count(*) from oyun.kanunlar k where k.teklif_eden = pr.id and k.durum = 'yururlukte'),
      'teklifler', coalesce((select jsonb_agg(jsonb_build_object('no', k.no, 'baslik', k.baslik, 'durum', k.durum) order by k.id desc)
          from (select * from oyun.kanunlar where teklif_eden = pr.id order by id desc limit 5) k), '[]'::jsonb),
      'oy', oy_n, 'oylanabilir', oylanabilir,
      'yoklama', (select count(*) from oyun.meclis_yoklama y where y.user_id = pr.id),
      'soru', (select count(*) from oyun.bakan_soru s where s.soran = pr.id),
      'gensoru', (select count(*) from oyun.gensorular g where g.teklif_eden = pr.id)),
    'kursu', jsonb_build_object(
      'bio', (select kp.bio from oyun.kursu_profil kp where kp.user_id = pr.id),
      'takipci', (select count(*) from oyun.kursu_takip kt where kt.takip_edilen = pr.id),
      'takip', (select count(*) from oyun.kursu_takip kt where kt.takipci = pr.id),
      'gonderi', (select count(*) from oyun.akis a where a.user_id = pr.id and a.yanit_id is null and not coalesce(a.gizli, false)),
      'son', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'metin', left(a.metin, 280), 'zaman', a.zaman,
            'begeni', (select count(*) from oyun.akis_begeni b where b.akis_id = a.id),
            'yanit', (select count(*) from oyun.akis y where y.yanit_id = a.id)) order by a.zaman desc)
          from (select * from oyun.akis where user_id = pr.id and yanit_id is null and not coalesce(gizli, false) order by zaman desc limit 3) a), '[]'::jsonb)),
    'rozetler', oyun.rozetler(pr.id));
end $$;

-- Kıdemli Vekil: aynı dönemdeki tekrar girişler değil, farklı yasama dönemleri sayılır
create or replace function oyun.rozetler(u uuid)
 returns jsonb language sql stable as $function$
  select coalesce(jsonb_agg(r order by r ->> 'sira'), '[]'::jsonb) from (
    select jsonb_build_object('sira', '01', 'ad', 'Cumhurbaşkanı', 'aciklama', 'Cumhurbaşkanlığı yaptı') r where exists (select 1 from oyun.makamlar where user_id = u and tur = 'cb')
    union all select jsonb_build_object('sira', '02', 'ad', 'Bakan', 'aciklama', 'Kabinede görev aldı') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bakan')
    union all select jsonb_build_object('sira', '03', 'ad', 'Genel Başkan', 'aciklama', 'Bir partinin genel başkanı oldu')
      where exists (select 1 from oyun.partiler where gb = u) or exists (select 1 from oyun.kazananlar k join oyun.secimler s on s.id = k.secim_id where k.user_id = u and s.tur = 'kurultay')
    union all select jsonb_build_object('sira', '04', 'ad', 'Milletvekili', 'aciklama', 'Meclis''e girdi') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'mv')
    union all select jsonb_build_object('sira', '05', 'ad', 'Belediye Başkanı', 'aciklama', 'Bir ili yönetti') where exists (select 1 from oyun.makamlar where user_id = u and tur = 'bel')
    union all select jsonb_build_object('sira', '06', 'ad', 'Kanun Yapıcı', 'aciklama', 'Teklifi yasalaştı') where exists (select 1 from oyun.kanunlar where teklif_eden = u and durum = 'yururlukte')
    union all select jsonb_build_object('sira', '07', 'ad', 'Parti Kurucusu', 'aciklama', 'Yeni bir parti kurdu') where exists (select 1 from oyun.partiler where kurucu = u)
    union all select jsonb_build_object('sira', '08', 'ad', 'Hatip', 'aciklama', '10+ propaganda yayını') where (select count(*) from oyun.yayinlar where gonderen = u) >= 10
    union all select jsonb_build_object('sira', '09', 'ad', 'Demokrasi Emektarı', 'aciklama', '20+ seçimde oy kullandı') where (select count(*) from oyun.oylar where secmen = u) >= 20
    union all select jsonb_build_object('sira', '10', 'ad', 'Sandık Neferi', 'aciklama', 'İlk oyunu kullandı') where (select count(*) from oyun.oylar where secmen = u) between 1 and 19
    union all select jsonb_build_object('sira', '11', 'ad', 'Kurucu Vatandaş', 'aciklama', 'Oyunun ilk vatandaşlarından')
      where exists (select 1 from oyun.profiller p, oyun.ayarlar a where p.id = u and a.id = 1 and p.olusturma <= coalesce(a.kurucu_rozet_bitis, '2026-12-31 23:59:59+03'))
    union all select jsonb_build_object('sira', '12', 'ad', 'Sandık Görevlisi', 'aciklama', 'Müşahit olarak sandık başında görev yaptı') where exists (select 1 from oyun.musahit where user_id = u and sandik_at is not null)
    union all select jsonb_build_object('sira', '13', 'ad', 'Yol Arkadaşı', 'aciklama', 'Yeni bir oyuncuya oyunda eşlik etti') where exists (select 1 from oyun.mentor_bag where mentor = u and odul_at is not null)
    union all select jsonb_build_object('sira', '14', 'ad', 'Kıdemli Vekil', 'aciklama', 'En az 3 dönem milletvekilliği') where (select count(distinct oyun.mv_donem_no(secim_id, bas)) from oyun.makamlar where user_id = u and tur = 'mv') >= 3
    union all select jsonb_build_object('sira', '15', 'ad', 'Üç Dönem Başkan', 'aciklama', 'En az 3 dönem belediye başkanlığı') where (select count(*) from oyun.makamlar where user_id = u and tur = 'bel') >= 3
    union all select jsonb_build_object('sira', '16', 'ad', 'Gölge Bakan', 'aciklama', 'Ana muhalefetin gölge kabinesinde görev aldı') where exists (select 1 from oyun.golge_gecmis where user_id = u)
    union all select jsonb_build_object('sira', '17', 'ad', 'Meclis Müdavimi', 'aciklama', '20+ akşam oturumuna katıldı') where (select count(*) from oyun.meclis_yoklama where user_id = u) >= 20
    union all select jsonb_build_object('sira', '2' || o.kod, 'ad', o.ad || case when o.adet > 1 then ' ×' || o.adet else '' end, 'aciklama', o.aciklama)
      from (select kod, max(ad) ad, max(aciklama) aciklama, count(*) adet from oyun.arena_odul where user_id = u group by kod) o
  ) x
$function$;

do $$ declare s text; begin
  foreach s in array array['meclis_sandalye(integer)', 'meclis_vekiller(integer,bigint,boolean)', 'milletvekili_ozgecmis(text)'] loop
    execute format('revoke all on function public.%s from public, anon', s);
    execute format('grant execute on function public.%s to authenticated', s);
  end loop;
end $$;
