-- 150 (30.10.2026) — EKONOMİ BİLGİLENDİRME
-- Oyuncu sorusu: "Bu kadar kazandım, param nereye gitti?" Amaç: her kesinti görünür ve açıklanmış olsun.
--   • public.vergi_rehberi(): güncel vergi oranları ve kimin belirlediği + kişisel 7 günlük döküm
--     (kaynakta kesilen gelir vergisi, kâr payı stopajı, tapu harcı, emlak ve servet vergisi, haciz, fon desteği)
--     + paranın şu an durduğu yerler (cüzdan, banka, vadeli, oyuncu bankası, hisse, mülk, borçlar).
--   • Bir kerelik tanıtım ekranı için sunucuda kalıcı işaret: oyun.tanitim_okundu + public.tanitim_tamam().
--   • denge_tick: vergi bildirimi neden ve nasıl kesildiğini anlatır; Fırsat Eşitliği Fonu ödemesi artık
--     'fon' türüyle yazılır ve alana haftada bir özet bildirim gider.
--   • Herkese bir kerelik resmî duyuru (bildirim + Resmî Gazete + Gündem); bu gece vergi kapsamına girecek
--     oyunculara kişisel ön bilgi ve tahmini tutar.
-- Oyuncu verisini dönüştürmez; yalnız tablo, sütun ve fonksiyon ekler.

create table if not exists oyun.tanitim_okundu (
  user_id uuid not null, anahtar text not null, zaman timestamptz not null default now(), primary key (user_id, anahtar));
alter table oyun.tanitim_okundu enable row level security;
create table if not exists oyun.tek_seferlik (anahtar text primary key, zaman timestamptz not null default now());
alter table oyun.tek_seferlik enable row level security;
alter table oyun.firsat_fonu_odeme add column if not exists bildirildi boolean not null default false;

create or replace function public.tanitim_tamam(p_anahtar text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if p.id is null or p_anahtar is null or length(p_anahtar) > 40 then return false; end if;
  insert into oyun.tanitim_okundu(user_id, anahtar, zaman) values (p.id, p_anahtar, oyun.simdi()) on conflict do nothing;
  return true;
end $$;

-- ===================== VERGİ REHBERİ + KİŞİSEL DÖKÜM =====================
create or replace function public.vergi_rehberi()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); bas timestamptz := oyun.simdi() - interval '7 days';
        u oyun.ulke; dn oyun.denge_ayar; g jsonb; sa jsonb; kv numeric; h record; med numeric; e numeric[];
        snet numeric; kent_t numeric := 0; gecim_t numeric := 0; sv numeric; borc numeric;
        c_para numeric; c_vadesiz numeric; c_vadeli numeric; c_ibv numeric; c_ibm numeric; c_hisse numeric; c_mulk numeric;
        c_kredi numeric; c_oyb numeric; c_kasa numeric;
begin
  select * into u from oyun.ulke where id = 1;
  select * into dn from oyun.denge_ayar where id = 1;
  kv := coalesce((select kent_vergisi from oyun.il_durum where il_id = p.il_id), 0);
  g := oyun.gelir_hesap(p.id, t); sa := g -> 'saatlik';
  med := coalesce((select d.medyan from oyun.denge_gun d order by d.gun desc limit 1),
                  (select percentile_cont(.5) within group (order by z.toplam) from oyun.net_servet_tablo() z)::numeric);
  med := greatest(coalesce(med, 1), 1);
  e := oyun.servet_esikler(med);

  select
    coalesce(sum(x.tutar) filter (where x.tur = 'maas'), 0) maas_net,
    coalesce(sum(x.vergi) filter (where x.tur = 'maas'), 0) gelir_vergisi,
    coalesce(sum(x.vergi) filter (where x.tur = 'sirket' and x.aciklama like '%stopaj%'), 0) stopaj,
    coalesce(-sum(x.tutar) filter (where x.aciklama like '%devir işlemi vergisi%'), 0) damga,
    coalesce(sum(x.vergi) filter (where x.tur = 'emlak' and x.aciklama like '%tapu harc%'), 0) tapu,
    coalesce(-sum(x.tutar) filter (where x.tur = 'emlak' and x.aciklama like '%emlak vergisi%'), 0) emlak,
    coalesce(-sum(x.tutar) filter (where x.tur = 'servet'), 0) servet_kanun,
    coalesce(-sum(x.tutar) filter (where x.tur in ('haciz', 'icra_haciz')), 0) haciz,
    coalesce(sum(x.tutar) filter (where x.tur = 'fon' or (x.tur = 'yardim' and x.aciklama like 'Fırsat Eşitliği Fonu%')), 0) fon,
    coalesce(sum(x.tutar) filter (where x.tur in ('destek', 'hemsehri', 'hosgeldin', 'ikramiye')), 0) destek,
    coalesce(sum(x.tutar) filter (where x.tutar > 0), 0) giris,
    coalesce(-sum(x.tutar) filter (where x.tutar < 0), 0) cikis,
    count(*) adet
  into h from oyun.hesap_hareket x where x.user_id = p.id and x.zaman > bas;

  -- Kent vergisi ve geçim masrafı maaş kumbarasında net hesaplanır; bugünkü bordro oranıyla tahmin edilir.
  snet := coalesce((sa ->> 'net')::numeric, 0);
  if snet > 0 and h.maas_net > 0 then
    kent_t := round(h.maas_net * coalesce((sa ->> 'kent')::numeric, 0) / snet);
    gecim_t := round(h.maas_net * coalesce((sa ->> 'gecim')::numeric, 0) / snet);
  end if;
  sv := coalesce((select sum(s.tahsil) from oyun.servet_vergi s where s.user_id = p.id and s.gun > (bas at time zone 'Europe/Istanbul')::date), 0);
  borc := coalesce((select b.borc from oyun.servet_vergi_borc b where b.user_id = p.id), 0);

  c_para := coalesce((select c.para from oyun.cuzdan c where c.user_id = p.id), 0);
  c_vadesiz := coalesce((select b.vadesiz from oyun.banka_musteri b where b.user_id = p.id), 0);
  c_vadeli := coalesce((select sum(v.anapara) from oyun.vadeli v where v.user_id = p.id and v.durum = 'acik'), 0);
  c_ibv := coalesce((select sum(i.bakiye) from oyun.ib_vadesiz i where i.user_id = p.id), 0);
  c_ibm := coalesce((select sum(m.anapara) from oyun.banka_mevduat m where m.user_id = p.id and not m.kapandi), 0);
  c_hisse := coalesce((select sum(o.pay / 100.0 * oyun.sirket_deger(o.sirket_id)) from oyun.sirket_ortaklari o
                        join oyun.sirketler s on s.id = o.sirket_id and s.aktif where o.user_id = p.id), 0);
  c_kasa := coalesce((select sum(o.pay / 100.0 * greatest(s.kasa, 0)) from oyun.sirket_ortaklari o
                        join oyun.sirketler s on s.id = o.sirket_id and s.aktif where o.user_id = p.id), 0);
  c_mulk := coalesce((select sum(m.bedel) from oyun.mulkler m where m.user_id = p.id), 0);
  c_kredi := coalesce((select sum(k.kalan) from oyun.krediler k where k.user_id = p.id and k.durum = 'aktif'), 0);
  c_oyb := coalesce((select sum(k.kalan) from oyun.oyb_kredi k where k.borclu = p.id and k.durum = 'aktif'), 0);

  return jsonb_build_object(
    'oranlar', jsonb_build_object(
      'gelir', u.vergi, 'gelir_alt', u.vergi_alt, 'gelir_ust', u.vergi_ust, 'asgari', u.asgari,
      'kent', kv, 'il', (select i.ad from oyun.iller i where i.id = p.il_id),
      'gecim_gunluk', g -> 'gecim_gunluk', 'gecim_indirim', g -> 'gecim_indirim',
      'emlak_gunluk', round(oyun.il_duz(p.il_id::smallint, 'emlak') * u.endeks),
      'kanuni_servet', oyun.duz('servet_vergisi'), 'kanuni_servet_muaf', round(250000 * u.endeks),
      'kdv', oyun.eko_vergi_oran('kdv'), 'kurumlar', oyun.eko_vergi_oran('kurumlar'),
      'stopaj', oyun.eko_vergi_oran('stopaj'), 'damga', oyun.eko_vergi_oran('damga'), 'tapu', 2,
      'denge_aktif', dn.aktif, 'medyan', round(med), 'esikler', to_jsonb(e),
      'denge_oranlar', jsonb_build_array(dn.oran1 * 100, dn.oran2 * 100, dn.oran3 * 100),
      'fon_pay', round(dn.fon_pay * 100), 'fon_tavan', round(u.asgari * dn.kisi_tavan_asgari),
      'havale_sinir', (select a.havale_sinir from oyun.ayarlar a where a.id = 1)),
    'bordro', jsonb_build_object('brut', round(coalesce((sa ->> 'brut')::numeric, 0) * 24), 'vergi', round(coalesce((sa ->> 'vergi')::numeric, 0) * 24),
      'kent', round(coalesce((sa ->> 'kent')::numeric, 0) * 24), 'gecim', round(coalesce((sa ->> 'gecim')::numeric, 0) * 24),
      'net', round(snet * 24)),
    'yedi_gun', jsonb_build_object(
      'giris', h.giris, 'cikis', h.cikis, 'adet', h.adet, 'maas_net', h.maas_net,
      'gelir_vergisi', h.gelir_vergisi, 'kent_tahmini', kent_t, 'gecim_tahmini', gecim_t,
      'stopaj', h.stopaj, 'damga', h.damga, 'tapu', h.tapu, 'emlak', h.emlak,
      'servet_denge', sv, 'servet_kanun', h.servet_kanun, 'haciz', h.haciz, 'fon', h.fon, 'destek', h.destek,
      'gelirler', coalesce((select jsonb_agg(jsonb_build_object('tur', q.tur, 'tutar', q.s, 'adet', q.n) order by q.s desc)
          from (select x.tur, sum(x.tutar) s, count(*) n from oyun.hesap_hareket x where x.user_id = p.id and x.zaman > bas and x.tutar > 0
                group by x.tur order by 2 desc limit 8) q), '[]'::jsonb),
      'giderler', coalesce((select jsonb_agg(jsonb_build_object('tur', q.tur, 'tutar', q.s, 'adet', q.n) order by q.s desc)
          from (select x.tur, -sum(x.tutar) s, count(*) n from oyun.hesap_hareket x where x.user_id = p.id and x.zaman > bas and x.tutar < 0
                  and x.tur not in ('servet', 'vergi', 'haciz', 'icra_haciz') and not (x.tur = 'emlak' and x.aciklama like '%emlak vergisi%')
                  and x.aciklama not like '%devir işlemi vergisi%'
                group by x.tur order by 2 desc limit 8) q), '[]'::jsonb)),
    'nerede', jsonb_build_object('cuzdan', c_para, 'vadesiz', c_vadesiz, 'vadeli', c_vadeli, 'oyb_vadesiz', c_ibv, 'oyb_vadeli', c_ibm,
      'hisse', round(c_hisse), 'sirket_kasa', round(c_kasa), 'mulk', c_mulk, 'kredi', c_kredi, 'oyb_kredi', c_oyb, 'vergi_borcu', borc),
    'tanitim', exists(select 1 from oyun.tanitim_okundu o where o.user_id = p.id and o.anahtar = 'ekonomik_denge_1'));
end $$;

-- ===================== GÜNLÜK DENGE (açıklayıcı bildirimlerle) =====================
create or replace function oyun.denge_tick()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare t timestamptz := oyun.simdi(); g date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; a oyun.denge_ayar;
        med numeric; gin numeric; top numeric; ez numeric; u10 numeric; r record; vg numeric; kalan numeric; al numeric;
        c numeric; v numeric; tvergi numeric := 0; ttahsil numeric := 0; havuz numeric; kisi numeric; n int := 0; tlm numeric; asg numeric;
        pr oyun.profiller; alicilar uuid[] := '{}'; au uuid; es numeric[]; hafta numeric;
begin
  if not pg_try_advisory_xact_lock(hashtext('denge_tick')) then return null; end if;
  select * into a from oyun.denge_ayar where id = 1;
  if not a.aktif or exists(select 1 from oyun.denge_gun where gun = g) then return null; end if;
  select percentile_cont(.5) within group (order by toplam), sum(toplam) into med, top from oyun.net_servet_tablo();
  med := greatest(coalesce(med, 0), 1);
  es := oyun.servet_esikler(med);
  select round((sum((2 * rn - cnt - 1) * v2) / nullif(cnt * sum(v2), 0))::numeric, 3) into gin
    from (select greatest(toplam, 0) v2, row_number() over (order by toplam) rn, count(*) over () cnt from oyun.net_servet_tablo()) z group by cnt;
  select round(100 * max(toplam) / nullif(top, 0), 1) into ez from oyun.net_servet_tablo();
  select round(100 * sum(toplam) / nullif(top, 0), 1) into u10 from (select toplam from oyun.net_servet_tablo() order by toplam desc limit greatest(1, (select count(*) from oyun.net_servet_tablo()) / 10)) q;
  tlm := oyun.pazar_tl_milyar(); asg := (select asgari from oyun.ulke where id = 1);

  -- 1) önce eski borçlar, sonra bugünkü vergi: cüzdandan, sonra devlet bankası vadesiz hesabından
  for r in select s.user_id, s.toplam, coalesce(b.borc, 0) borc from oyun.net_servet_tablo() s left join oyun.servet_vergi_borc b on b.user_id = s.user_id
           where coalesce(b.borc, 0) > 0 or s.toplam > es[1] loop
    vg := oyun.servet_vergisi(r.toplam, med);
    kalan := vg + r.borc; al := 0;
    if kalan <= 0 then continue; end if;
    select para into c from oyun.cuzdan where user_id = r.user_id for update;
    c := least(greatest(coalesce(c, 0), 0), kalan);
    if c > 0 then perform oyun.para_islem(r.user_id, -c, 'vergi', 'Servet vergisi (kademeli, günlük)', t); al := al + c; kalan := kalan - c; end if;
    if kalan > 0 then
      select vadesiz into v from oyun.banka_musteri where user_id = r.user_id for update;
      v := least(greatest(coalesce(v, 0), 0), kalan);
      if v > 0 then
        update oyun.banka_musteri set vadesiz = vadesiz - v where user_id = r.user_id;
        perform oyun.banka_kayit(r.user_id, 'vadesiz', -v, 'Servet vergisi (kademeli, günlük)', t);
        al := al + v; kalan := kalan - v;
      end if;
    end if;
    insert into oyun.servet_vergi_borc(user_id, borc, guncelleme) values (r.user_id, kalan, t)
      on conflict (user_id) do update set borc = excluded.borc, guncelleme = t;
    if vg > 0 then
      insert into oyun.servet_vergi(user_id, gun, servet, vergi, tahsil) values (r.user_id, g, r.toplam, vg, al)
        on conflict (user_id, gun) do update set vergi = excluded.vergi, tahsil = excluded.tahsil;
      perform oyun.bildir(r.user_id, format(
        'Servet vergisi (Ekonomik Denge): net servetin %s ₺, medyan servetin %s katı. Vergi yalnız %s ₺ eşiğini aşan kısma kademeli uygulanır; bugünkü vergin %s ₺, tahsil edilen %s ₺%s. Toplananın yarısı medyanın altındaki oyunculara Fırsat Eşitliği Fonu olarak dağıtılır, yarısı Hazine''ye gider. Hesaplama: Ekonomi › Ekonomik Denge.',
        oyun.tl(r.toplam), replace(round(r.toplam / med, 1)::text, '.', ','), oyun.tl(es[1]), oyun.tl(vg), oyun.tl(al),
        case when kalan > 0 then '. Kalan ' || oyun.tl(kalan) || ' ₺ vergi borcu olarak yazıldı; borç kapanana kadar para aktaramaz ve şirket kuramazsın' else '' end), t);
    elsif al > 0 then
      perform oyun.bildir(r.user_id, format('Servet vergisi borcundan %s ₺ tahsil edildi%s.', oyun.tl(al),
        case when kalan > 0 then ', kalan borç ' || oyun.tl(kalan) || ' ₺' else '; borcun kapandı, para aktarımı ve şirket kuruluşu yeniden serbest' end), t);
    end if;
    tvergi := tvergi + vg; ttahsil := ttahsil + al;
  end loop;

  -- 2) Fırsat Eşitliği Fonu: medyanın altındaki aktif, şartları tamam oyunculara eşit pay
  havuz := floor(ttahsil * a.fon_pay);
  kisi := 0;
  for pr in select p.* from oyun.profiller p  join oyun.net_servet_tablo() s on s.user_id = p.id
            where not p.yasakli and s.toplam < med and p.son_gorulme > t - interval '3 days' and p.olusturma < t - interval '3 days' loop
    if oyun.uyari(pr, t) is null and not exists(select 1 from oyun.servet_vergi_borc b where b.user_id = pr.id and b.borc > 0) then
      alicilar := alicilar || pr.id; n := n + 1;
    end if;
  end loop;
  if n > 0 and havuz > 0 then
    kisi := least(floor(havuz / n), round(asg * a.kisi_tavan_asgari));
    if kisi >= 1 then
      foreach au in array alicilar loop
        perform oyun.para_islem(au, kisi, 'fon', 'Fırsat Eşitliği Fonu (servet vergisinden)', t);
        insert into oyun.firsat_fonu_odeme(user_id, gun, tutar) values (au, g, kisi) on conflict do nothing;
        -- haftada bir özet bildirim (ilk ödemede hemen)
        if not exists(select 1 from oyun.firsat_fonu_odeme f where f.user_id = au and f.bildirildi and f.gun > g - 7) then
          hafta := coalesce((select sum(f.tutar) from oyun.firsat_fonu_odeme f where f.user_id = au and f.gun > g - 7), kisi);
          perform oyun.bildir(au, format(
            'Fırsat Eşitliği Fonu: servet vergisinden cüzdanına bugün %s ₺ yatırıldı (son 7 günde toplam %s ₺). Fon, büyük servetlerden alınan verginin yarısını medyanın altındaki aktif oyunculara eşit dağıtır; oyuna girdikçe her gün pay alırsın. Ayrıntı: Ekonomi › Ekonomik Denge.',
            oyun.tl(kisi), oyun.tl(hafta)), t);
          update oyun.firsat_fonu_odeme set bildirildi = true where user_id = au and gun = g;
        end if;
      end loop;
    end if;
  end if;
  -- kalan her şey Hazine'ye
  if ttahsil - kisi * n > 0 then update oyun.ulke set hazine = hazine + (ttahsil - kisi * n) / tlm where id = 1; end if;
  insert into oyun.denge_gun(gun, medyan, gini, toplam, en_zengin_pay, ust10_pay, vergi, tahsil, fon, alici, zaman)
    values (g, med, gin, top, ez, u10, tvergi, ttahsil, kisi * n, case when kisi >= 1 then n else 0 end, t);
  if ttahsil > 0 then
    perform oyun.olay('ekonomi', format('Ekonomik Denge: servet vergisinden %s ₺ toplandı; Fırsat Eşitliği Fonu %s oyuncuya kişi başı %s ₺ ödedi, kalan %s ₺ Hazine''ye gelir yazıldı.',
      oyun.tl(ttahsil), case when kisi >= 1 then n else 0 end, oyun.tl(kisi), oyun.tl(greatest(0, ttahsil - kisi * n))), null, null, t);
  end if;
  return jsonb_build_object('medyan', med, 'gini', gin, 'vergi', tvergi, 'tahsil', ttahsil, 'alici', n, 'kisi', kisi);
end $$;

revoke all on function oyun.denge_tick() from public, anon, authenticated;
revoke all on function public.vergi_rehberi() from public, anon;
revoke all on function public.tanitim_tamam(text) from public, anon;
grant execute on function public.vergi_rehberi() to authenticated;
grant execute on function public.tanitim_tamam(text) to authenticated;

-- ===================== BİR KERELİK RESMÎ DUYURU =====================
do $$
declare t timestamptz := oyun.simdi(); med numeric; e numeric[]; r record; genel text; a oyun.denge_ayar; asg numeric; n int := 0; k int := 0;
begin
  insert into oyun.tek_seferlik(anahtar, zaman) values ('ekonomik_denge_duyuru_1', t) on conflict do nothing;
  if not found then return; end if;
  select * into a from oyun.denge_ayar where id = 1;
  if a.id is null or not a.aktif then return; end if;
  if not exists(select 1 from oyun.profiller where not yasakli) then return; end if;
  asg := (select asgari from oyun.ulke where id = 1);
  select percentile_cont(.5) within group (order by toplam) into med from oyun.net_servet_tablo();
  med := greatest(coalesce(med, 1), 1); e := oyun.servet_esikler(med);
  genel := format(
    'Resmî duyuru · Ekonomik Denge düzenlemesi yürürlükte. Net serveti %s ₺ eşiğini (medyan servetin 10 katı) aşan oyunculardan her gece 03:20''de yalnız aşan kısım üzerinden günlük binde 1 ile binde 3,5 arasında kademeli servet vergisi alınır; oyuncuların büyük çoğunluğu bu vergiyi ödemez. Toplananın yarısı medyanın altındaki aktif oyunculara Fırsat Eşitliği Fonu olarak eşit dağıtılır. Maaşından ve kazancından yapılan her kesintiyi kalem kalem görmek için üst çubuktaki cüzdan tutarına dokun.',
    oyun.tl(e[1]));
  for r in select p.id, s.toplam from oyun.profiller p left join oyun.net_servet_tablo() s on s.user_id = p.id where not p.yasakli loop
    if coalesce(r.toplam, 0) > e[1] then
      perform oyun.bildir(r.id, format(
        'Ekonomik Denge · kişisel ön bilgi: net servetin %s ₺ (medyan servetin %s katı) olduğu için yeni servet vergisi kapsamına giriyorsun. İlk kesinti bu gece 03:20''de; tahmini günlük vergin %s ₺. Vergi yalnız %s ₺ eşiğini aşan kısma uygulanır, önce cüzdandan, yetmezse devlet bankası vadesiz hesabından alınır. Net servet: nakit + banka mevduatı + şirket payların + mülklerin. Hesaplama: Ekonomi › Ekonomik Denge.',
        oyun.tl(r.toplam), replace(round(r.toplam / med, 1)::text, '.', ','), oyun.tl(oyun.servet_vergisi(r.toplam, med)), oyun.tl(e[1])), t);
      k := k + 1;
    else
      perform oyun.bildir(r.id, genel, t);
    end if;
    n := n + 1;
  end loop;

  perform oyun.gazete_ekle('duyuru', 'Ekonomik Denge ve Rekabetin Korunması Düzenlemesi yürürlüğe girdi', format(
    'Servetin birkaç elde toplanmasını önlemek ve oyuncuların birbirinin şirketini ya da bankasını bilerek batırmasını engellemek için aşağıdaki kurallar yürürlüğe girmiştir. '
    || '(1) Kademeli servet vergisi: Net servet (nakit, banka mevduatı, şirket payları ve mülkler) medyan servetin 10 katını aşarsa yalnız aşan kısımdan günlük binde 1, 25 katını aşan kısımdan binde 2, 50 katını aşan kısımdan binde 3,5 vergi alınır. Eşikler ekonomiyle birlikte her gün kendiliğinden güncellenir; bugünkü ilk eşik %s ₺. '
    || '(2) Fırsat Eşitliği Fonu: Toplanan verginin yarısı aynı gün, serveti medyanın altında kalan, son 3 günde oyuna girmiş, en az 3 günlük ve vergi borcu olmayan oyunculara eşit dağıtılır (kişi başı günlük en çok %s ₺); kalanı Hazine''ye gelir yazılır. '
    || '(3) Rekabet Kurumu: Serveti medyanın 10 katını aşan bir oyuncunun şirketi pazarın en az %%30''unu tutarken zararına en düşük fiyattan satarsa her saat otomatik incelenir; kasasının %%10''u ceza olarak mağdur rakiplere ödenir, fiyatı 72 saat ortaya çekilir. '
    || '(4) Paravan yasağı: Aynı kişi ya da aynı cihazdaki hesapları aynı il ve sektöre ikinci şirket kuramaz. '
    || '(5) Banka hücumu kalkanı: Bir oyuncunun bir bankaya yatırabileceği mevduat o bankanın ödeme gücüyle sınırlıdır. '
    || '(6) Vergi borcu: Tahsil edilemeyen vergi borç yazılır; borç kapanana kadar para aktarımı ve şirket kuruluşu yapılamaz. '
    || 'Kazançtan yapılan bütün kesintiler (gelir vergisi, kent vergisi, geçim masrafı, emlak vergisi, kâr payı stopajı, tapu harcı ve servet vergisi) üst çubuktaki cüzdan tutarına dokunarak açılan "Param nereye gitti?" ekranında kalem kalem gösterilir.',
    oyun.tl(e[1]), oyun.tl(round(asg * a.kisi_tavan_asgari))), null, t);

  perform oyun.olay('ekonomi', format(
    'Ekonomik Denge düzenlemesi yürürlüğe girdi: net serveti %s ₺ eşiğini aşan %s oyuncudan bu geceden itibaren kademeli servet vergisi alınacak; verginin yarısı Fırsat Eşitliği Fonu ile medyanın altındaki oyunculara dağıtılacak.',
    oyun.tl(e[1]), k), null, null, t);
end $$;
