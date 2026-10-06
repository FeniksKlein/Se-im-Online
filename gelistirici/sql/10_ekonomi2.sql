-- =====================================================================
--  SEÇİM SİMÜLASYONU ONLINE — 10) EKONOMİ 2 · SÖZ TUTMANIN KARŞILIĞI · SOHBET
--  Her şeyin bir karşılığı olsun:
--   · Vaat tutmak itibar ve kıdem puanı (→ statü → maaş) kazandırır; tutmamak kaybettirir.
--   · Her bakanlık icraatının, milletvekilliğinin ve genel başkanlığın ölçülebilir vaat karşılığı var.
--   · Şehir kalkınma bağışı: şehrin gelişmişliğini artırır, kıdem puanı kazandırır.
--   · Vergi karnesi: ödediğin verginin nereye gittiğini gösterir.
--   · Sohbet: Bakanlar Kurulu, Parti Yönetimi, Belediye Meclisi; okunmamış sayacı.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) İTİBAR (söz tutma karnesi)
-- ---------------------------------------------------------------------
create table if not exists oyun.itibar(
  user_id uuid primary key references oyun.profiller(id) on delete cascade,
  tutulan int not null default 0,
  bozulan int not null default 0
);

create or replace function oyun.kidem_ekle(u uuid, x numeric) returns void language plpgsql as $$
begin
  perform oyun.cuzdanim(u);
  update oyun.cuzdan set kidem = greatest(0, kidem + x) where user_id = u;
end $$;

-- Bir vaat sonuçlanınca: tutulan +5 kıdem puanı, tutulmayan −3 (0'ın altına inmez)
create or replace function oyun.itibar_isle(u uuid, tuttu boolean, p_ad text, t timestamptz) returns void language plpgsql as $$
begin
  if u is null or not exists (select 1 from oyun.profiller where id = u) then return; end if;
  insert into oyun.itibar(user_id, tutulan, bozulan) values (u, case when tuttu then 1 else 0 end, case when tuttu then 0 else 1 end)
  on conflict (user_id) do update set tutulan = oyun.itibar.tutulan + excluded.tutulan, bozulan = oyun.itibar.bozulan + excluded.bozulan;
  perform oyun.kidem_ekle(u, case when tuttu then 5 else -3 end);
  perform oyun.bildir(u, case when tuttu
      then format('Vaadini tuttun: "%s". Kıdem puanın +5 arttı, itibarın yükseldi.', p_ad)
      else format('Vaadini tutamadın: "%s". Kıdem puanın 3 azaldı, itibarın düştü.', p_ad) end, t);
end $$;

create or replace function oyun.itibar_json(u uuid) returns jsonb language sql stable as $$
  select jsonb_build_object('tutulan', coalesce(i.tutulan, 0), 'bozulan', coalesce(i.bozulan, 0), 'toplam', coalesce(i.tutulan + i.bozulan, 0),
    'oran', case when coalesce(i.tutulan + i.bozulan, 0) > 0 then round(100.0 * i.tutulan / (i.tutulan + i.bozulan)) end,
    'rozet', case when coalesce(i.tutulan + i.bozulan, 0) >= 3 and i.tutulan * 10 >= (i.tutulan + i.bozulan) * 7 then 'Sözünün Eri'
                  when coalesce(i.tutulan + i.bozulan, 0) >= 3 and i.tutulan * 10 < (i.tutulan + i.bozulan) * 3 then 'Lafta Kalan' end)
  from (select 1) x left join oyun.itibar i on i.user_id = u
$$;

-- ---------------------------------------------------------------------
-- 2) VAAT TÜRLERİ: her icraatın, her makamın bir vaat karşılığı olsun
-- ---------------------------------------------------------------------
create or replace function oyun.birim_yaz(x numeric, b text) returns text language sql immutable as $$
  select case b when 'tl_ay' then oyun.tl(x) || ' ₺/ay' when 'tl_gun' then oyun.tl(x) || ' ₺/gün' when 'tl' then oyun.tl(x) || ' ₺'
                when 'adet' then oyun.tl(x) || ' adet'
                when 'yuzde' then '%' || replace(regexp_replace(trim(to_char(x, 'FM990.0')), '\.0$', ''), '.', ',')
                when 'kat' then '×' || replace(regexp_replace(trim(to_char(x, 'FM990.00')), '\.?0+$', ''), '.', ',')
                else coalesce(x::text, '') end
$$;

-- Beyanname: vaadi olmayan bütün bakanlık icraatları (kod = icraat kodu; yapılınca vaat tutulmuş sayılır)
insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama)
select 'beyanname', v.kod, v.ad, 'yok', 'tek', null, null, null, 12 + row_number() over (order by b.sira, v.kod),
       b.ad || ' icraatı: ' || i.aciklama
from (values
  ('adl_harc','Tapu ve noter harçlarını kaldıracağız'), ('adl_ifade','İfade özgürlüğü paketi çıkaracağız'),
  ('dis_zirve','Uluslararası yatırım zirvesi düzenleyeceğiz'), ('dis_turizm','Turizm tanıtım kampanyası yapacağız'),
  ('ic_nufus','Nüfus işlemlerini kolaylaştıracağız'), ('ic_afad','Afet bölgelerine anında yardım ulaştıracağız'),
  ('mal_iade','Vergi iadesi yapacağız'), ('mal_varlik','Varlık barışı çıkaracağız'),
  ('sav_sanayi','Savunma sanayiine yatırım yapacağız'), ('sav_bedelli','Bedelli askerlik düzenlemesi getireceğiz'),
  ('egt_seferber','Hayat boyu öğrenme seferberliği başlatacağız'), ('sag_hastane','Şehir hastaneleri yapacağız'),
  ('san_osb','Organize sanayi bölgeleri kuracağız'), ('san_tesvik','Teknoloji teşvik paketi açıklayacağız'),
  ('tic_ihracat','İhracat seferberliği başlatacağız'), ('tar_sulama','Sulama ve kırsal kalkınma yatırımı yapacağız'),
  ('ula_tren','Hızlı tren hattı yapacağız'), ('cal_esnaf','Esnafa ucuz kredi vereceğiz')) v(kod, ad)
join oyun.icraatlar i on i.kod = v.kod join oyun.bakanliklar b on b.kod = i.bakanlik
on conflict (kapsam, kod) do update set ad = excluded.ad, aciklama = excluded.aciklama, sira = excluded.sira;

insert into oyun.vaat_turleri(kapsam, kod, ad, birim, tip, yon, min, max, sira, aciklama) values
 ('mv','katilim','Meclis oylamalarının en az bu kadarına katılacağım','yuzde','surekli','>=',50,100,5,'Görev süresince biten kanun oylamalarının kaçına oy verdiğin her gün ölçülür. Çekimser oy da katılımdır.'),
 ('mv','teklif','Meclise kanun teklifi vereceğim','adet','tek','>=',1,5,6,'Görev süresince verdiğin (geri çekmediğin) kanun teklifi sayısı.'),
 ('gb','uye','Partinin üye sayısını artıracağım','adet','tek','>=',2,1000,3,'Partine kayıtlı oyuncu sayısı bu sayıya ulaşınca vaat tutulur.'),
 ('gb','kasa','Parti kasasını büyüteceğim','tl','tek','>=',1000,10000000,4,'Parti kasasındaki para bu tutara ulaşınca vaat tutulur. Üyelerin bağışları kasaya girer.')
on conflict (kapsam, kod) do update set ad = excluded.ad, birim = excluded.birim, tip = excluded.tip, yon = excluded.yon,
  min = excluded.min, max = excluded.max, sira = excluded.sira, aciklama = excluded.aciklama;

-- Vaat koşulları (mv ve gb'ye yeni türler eklendi)
create or replace function oyun.vaat_kosul(v oyun.vaatler, t timestamptz) returns boolean language plpgsql stable as $$
declare u oyun.ulke; d oyun.il_durum; v_cb uuid; bas timestamptz := coalesce(v.aktif_bas, t); toplam int; katildi int;
begin
  select * into u from oyun.ulke where id = 1;
  if v.kapsam = 'beyanname' then
    case v.kod
      when 'asgari' then return u.asgari >= v.hedef;
      when 'vergi' then return case when v.yon = '<=' then u.vergi <= v.hedef else u.vergi >= v.hedef end;
      when 'kidem' then return u.kidem_primi >= v.hedef;
      when 'destek' then return u.destek >= v.hedef;
      when 'tasinma' then return u.tasinma_destek >= v.hedef;
      when 'ikramiye' then
        v_cb := (select user_id from oyun.makamlar where id = v.makam_id);
        return exists (select 1 from oyun.kararnameler k where k.tur = 'ikramiye' and k.cb = v_cb and k.zaman >= bas and (k.veri ->> 'miktar')::numeric >= v.hedef);
      when 'ozellestirme' then
        v_cb := (select user_id from oyun.makamlar where id = v.makam_id);
        return exists (select 1 from oyun.kararnameler k where k.tur = 'ozellestirme' and k.cb = v_cb and k.zaman >= bas);
      when 'referandum' then return exists (select 1 from oyun.referandumlar r where r.olusturma >= bas);
      else
        if exists (select 1 from oyun.duzenleme_tanim where kod = v.kod) then
          return case when v.yon = '<=' then oyun.duz(v.kod) <= v.hedef else oyun.duz(v.kod) >= v.hedef end;
        end if;
        return exists (select 1 from oyun.icraat_kayit k where k.kod = v.kod and k.zaman >= bas);
    end case;
  elsif v.kapsam = 'mv' then
    if v.kod = 'katilim' then
      select count(*) into toplam from oyun.kanunlar k where k.oy_bit <= t and k.oy_bit >= bas and k.durum not in ('geri_cekildi','gorusmede','oylamada');
      select count(*) into katildi from oyun.kanun_oylari o join oyun.kanunlar k on k.id = o.kanun_id
       where o.vekil = v.user_id and o.asama = 'ilk' and k.oy_bit <= t and k.oy_bit >= bas and k.durum not in ('geri_cekildi','gorusmede','oylamada');
      return toplam < 3 or katildi * 100 >= v.hedef * toplam;     -- henüz yeterli oylama yoksa vaat tutulmuş sayılır
    elsif v.kod = 'teklif' then
      return (select count(*) from oyun.kanunlar where teklif_eden = v.user_id and teklif_at >= bas and durum <> 'geri_cekildi') >= v.hedef;
    elsif v.kod = 'anayasa_imza' then
      return exists (select 1 from oyun.kanun_oylari o join oyun.kanunlar k on k.id = o.kanun_id
                     where o.vekil = v.user_id and o.asama = 'imza' and k.teklif_at >= bas and k.durum <> 'geri_cekildi');
    end if;
    return exists (select 1 from oyun.kanunlar k where k.durum = 'yururlukte' and k.sonuc_at >= bas
      and exists (select 1 from oyun.kanun_oylari o where o.kanun_id = k.id and o.vekil = v.user_id and o.oy = 'kabul')
      and case v.kod
            when 'vergi_tavan' then k.tur = 'butce' and (k.veri ->> 'vergi_ust')::numeric <= v.hedef
            when 'belediye_payi' then k.tur = 'butce' and (k.veri ->> 'belediye_payi')::numeric >= v.hedef
            when 'parti_yardim' then k.tur = 'butce' and (k.veri ->> 'parti_yardim')::numeric <= v.hedef
            when 'baraj' then k.tur = 'secim' and (k.veri ->> 'baraj')::numeric <= v.hedef
            else k.tur in ('duzenleme','anayasa') and k.veri ->> 'kod' = v.kod
                 and case when v.yon = '<=' then (k.veri ->> 'deger')::numeric <= v.hedef else (k.veri ->> 'deger')::numeric >= v.hedef end end);
  elsif v.kapsam = 'bel' then
    select * into d from oyun.il_durum where il_id = v.il_id;
    case v.kod
      when 'kent_vergisi' then return d.kent_vergisi <= v.hedef;
      when 'hemsehri' then return d.hemsehri >= v.hedef;
      when 'emlak', 'hosgeldin' then
        return case when v.yon = '<=' then oyun.il_duz(v.il_id, v.kod) <= v.hedef else oyun.il_duz(v.il_id, v.kod) >= v.hedef end;
      when 'altyapi', 'rayli', 'imar_barisi' then
        return exists (select 1 from oyun.belediye_proje_kayit k where k.kod = v.kod and k.il_id = v.il_id and k.baskan = v.user_id and k.zaman >= bas);
      else return exists (select 1 from oyun.il_hizmet h where h.il_id = v.il_id and h.kod = v.kod);
    end case;
  elsif v.kapsam = 'gb' then
    case v.kod
      when 'aday_ucret' then
        return (select max(value::numeric) from oyun.partiler pa, jsonb_each_text(pa.aday_ucret) where pa.id = v.parti_id) <= v.hedef;
      when 'uye' then return (select count(*) from oyun.profiller where parti_id = v.parti_id) >= v.hedef;
      when 'kasa' then return coalesce((select kasa from oyun.partiler where id = v.parti_id), 0) >= v.hedef;
      else
        return coalesce((select -sum(tutar) from oyun.parti_hareket where parti_id = v.parti_id and tur = 'destek' and zaman >= bas), 0) >= v.hedef;
    end case;
  end if;
  return false;
end $$;

-- Her gece: vaatlerin durumu. Sonuçlanan vaat itibar ve kıdem puanına işlenir.
create or replace function oyun.vaat_degerlendir(g date, t timestamptz) returns void language plpgsql as $$
declare v oyun.vaatler; m oyun.makamlar; tip text; vad text; bitti boolean; secim_bitti boolean; sorumlu uuid;
begin
  -- 1) seçim sonuçlanınca: seçildiyse aktif, seçilmediyse kapanır
  for v in select * from oyun.vaatler where durum = 'bekliyor' loop
    m := null;
    if v.kapsam in ('mv','bel') then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.user_id = v.user_id and x.tur = v.kapsam and s.donem = v.donem and x.bit is null order by x.bas limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = v.kapsam and s.durum <> 'tamam');
    elsif v.kapsam = 'beyanname' then
      select x.* into m from oyun.makamlar x join oyun.secimler s on s.id = x.secim_id
       where x.tur = 'cb' and x.parti_id = v.parti_id and s.donem = v.donem and x.bit is null limit 1;
      secim_bitti := not exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur in ('cb','cb2') and s.durum <> 'tamam');
    else
      secim_bitti := exists (select 1 from oyun.secimler s where s.donem = v.donem and s.tur = 'kurultay' and s.durum = 'tamam');
    end if;
    if m.id is not null then
      update oyun.vaatler set durum = 'aktif', makam_id = m.id, aktif_bas = m.bas where id = v.id;
    elsif v.kapsam = 'gb' and secim_bitti and exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id) then
      update oyun.vaatler set durum = 'aktif', aktif_bas = (select goreve_bas from oyun.secimler where donem = v.donem and tur = 'kurultay') where id = v.id;
    elsif secim_bitti then
      update oyun.vaatler set durum = 'secilmedi', bitis = t where id = v.id;
    end if;
  end loop;
  -- 2) görevdekilerin vaatleri her gün kontrol edilir
  for v in select * from oyun.vaatler where durum = 'aktif' loop
    select x.tip, x.ad into tip, vad from oyun.vaat_turleri x where x.kapsam = v.kapsam and x.kod = v.kod;
    sorumlu := coalesce(v.user_id, (select user_id from oyun.makamlar where id = v.makam_id));
    bitti := case when v.kapsam = 'gb' then not exists (select 1 from oyun.partiler where id = v.parti_id and gb = v.user_id)
                  else exists (select 1 from oyun.makamlar where id = v.makam_id and bit is not null) end;
    if bitti then
      update oyun.vaatler set durum = 'bitti', bitis = coalesce((select bit from oyun.makamlar where id = v.makam_id), t) where id = v.id;
      -- dönem sonu: tek seferlik vaat yapılmadıysa, sürekli vaat günlerin yarısından azında tutulduysa söz bozulmuştur
      if tip = 'tek' then
        if not v.tamam then perform oyun.itibar_isle(sorumlu, false, vad, t); end if;
      elsif v.gun_toplam > 0 then
        perform oyun.itibar_isle(sorumlu, v.gun_tutuldu * 2 >= v.gun_toplam, vad, t);
      end if;
      continue;
    end if;
    if tip = 'tek' then
      if not v.tamam and oyun.vaat_kosul(v, t) then
        update oyun.vaatler set tamam = true where id = v.id;
        perform oyun.itibar_isle(sorumlu, true, vad, t);
      end if;
    else
      update oyun.vaatler set gun_toplam = gun_toplam + 1, gun_tutuldu = gun_tutuldu + case when oyun.vaat_kosul(v, t) then 1 else 0 end where id = v.id;
    end if;
  end loop;
end $$;

-- Vaat seçenekleri ekranı (yeni türlerin "bugünkü değeri" eklendi)
create or replace function public.vaat_secenekleri(p_kapsam text, p_il int default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); u oyun.ulke; d oyun.il_durum; il smallint := coalesce(p_il, p.il_id)::smallint;
begin
  select * into u from oyun.ulke where id = 1;
  select * into d from oyun.il_durum where il_id = il;
  return jsonb_build_object('kapsam', p_kapsam, 'il_id', il, 'il_ad', (select ad from oyun.iller where id = il),
    'en_fazla', case p_kapsam when 'beyanname' then 5 when 'bel' then 4 when 'mv' then 3 else 2 end,
    'alan', oyun.vaat_alani(p_kapsam, il, p.parti_id), 'birim', case p_kapsam when 'gb' then 'tl' else 'milyar' end,
    'turler', (select jsonb_agg(jsonb_build_object('kod', t.kod, 'ad', t.ad, 'birim', t.birim, 'tip', t.tip, 'min', t.min, 'max', t.max, 'aciklama', t.aciklama,
                 'mevcut', oyun.vaat_mevcut(t.kapsam, t.kod, il, p.parti_id),
                 'acik', case when t.kod in ('lokanta','ulasim','kira','istihdam') then exists (select 1 from oyun.il_hizmet h where h.il_id = il and h.kod = t.kod) end)
               order by t.sira) from oyun.vaat_turleri t where t.kapsam = p_kapsam));
end $$;

-- Aday kartı: bildirge + ölçülebilir vaatler + söz tutma karnesi
create or replace function oyun.aday_json(p_aday_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object('aday_id', a.id, 'user_id', a.user_id, 'kad', coalesce(pr.kad, '(silinmiş)'),
                            'parti_id', a.parti_id, 'kisa', pa.kisa, 'renk', pa.renk, 'il_id', a.il_id, 'oy', coalesce(a.oy,0), 'sira', a.sira,
                            'vaat', a.vaat, 'vaatler', oyun.aday_vaatleri(a.user_id, a.secim_id), 'itibar', oyun.itibar_json(a.user_id))
  from oyun.adaylar a left join oyun.profiller pr on pr.id = a.user_id left join oyun.partiler pa on pa.id = a.parti_id
  where a.id = p_aday_id
$$;

-- ---------------------------------------------------------------------
-- 3) PARANIN KARŞILIĞI: şehir kalkınma bağışı + vergi karnesi
-- ---------------------------------------------------------------------
create table if not exists oyun.il_bagis_kayit(
  id      bigserial primary key,
  il_id   smallint not null references oyun.iller(id),
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  tutar   numeric not null,
  zaman   timestamptz not null
);
create index if not exists il_bagis_il on oyun.il_bagis_kayit(il_id, zaman desc);

create or replace function public.il_bagis_durum() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan;
begin
  c := oyun.cuzdanim(p.id);
  return jsonb_build_object('il_ad', (select ad from oyun.iller where id = p.il_id), 'gelisim', (select round(gelisim, 2) from oyun.il_durum where il_id = p.il_id),
    'bugun', c.bagis_bugun, 'tavan', (select asgari from oyun.ulke where id = 1),
    'ay_toplam', coalesce((select sum(tutar) from oyun.il_bagis_kayit where il_id = p.il_id and zaman > t - interval '30 days'), 0),
    'benim_toplam', coalesce((select sum(tutar) from oyun.il_bagis_kayit where il_id = p.il_id and user_id = p.id), 0),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('kad', x.kad, 'toplam', x.s) order by x.s desc), '[]'::jsonb)
            from (select pr.kad, sum(b.tutar) s from oyun.il_bagis_kayit b join oyun.profiller pr on pr.id = b.user_id
                  where b.il_id = p.il_id and b.zaman > t - interval '30 days' group by pr.kad order by sum(b.tutar) desc limit 5) x));
end $$;

-- Her asgari ücret tutarındaki bağış: şehrin gelişmişliği +0,005 (maaşları ve belediye gelirini artırır) ve 1 kıdem puanı.
-- Parti bağışıyla birlikte günlük sınır: asgari ücret.
create or replace function public.il_bagis(p_miktar numeric) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); m numeric := round(coalesce(p_miktar, 0)); c oyun.cuzdan; tavan numeric; il_ad text;
begin
  if m < 100 then raise exception 'En az 100 ₺ bağışlayabilirsin.'; end if;
  c := oyun.cuzdanim(p.id);
  tavan := (select asgari from oyun.ulke where id = 1);
  if c.bagis_bugun + m > tavan then
    raise exception 'Bağış sınırı: kişi başı günde en fazla % ₺ (parti ve şehir bağışları birlikte sayılır; bugün % ₺ bağışladın).', oyun.tl(tavan), oyun.tl(c.bagis_bugun);
  end if;
  il_ad := (select ad from oyun.iller where id = p.il_id);
  perform oyun.para_islem(p.id, -m, 'bagis', format('%s kalkınma bağışı', il_ad), t);
  update oyun.cuzdan set bagis_bugun = bagis_bugun + m, kidem = kidem + m / tavan where user_id = p.id;
  update oyun.il_durum set gelisim = least(100, gelisim + 0.005 * m / tavan) where il_id = p.il_id;
  insert into oyun.il_bagis_kayit(il_id, user_id, tutar, zaman) values (p.il_id, p.id, m, t);
  return public.il_bagis_durum();
end $$;

-- Verginin nereye gittiği: son 7 günde ödediğin gelir vergisi, bütçe payları oranında
create or replace function public.vergi_karnem() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.ulke; h jsonb; v numeric; gider numeric; kalem jsonb;
begin
  select * into u from oyun.ulke where id = 1;
  h := oyun.ulke_hesap(u);
  gider := greatest(0.0001, (h ->> 'gider')::numeric);
  v := coalesce((select sum(vergi) from oyun.hesap_hareket where user_id = p.id and tur = 'maas' and zaman > t - interval '7 days'), 0);
  select coalesce(jsonb_agg(z.x order by (z.x ->> 'tl')::numeric desc), '[]'::jsonb) into kalem from (
    select jsonb_build_object('ad', b.ad, 'tl', round(v * ((h ->> 'cari')::numeric / gider) * coalesce((u.butce ->> b.kod)::numeric, 0) / 100, 2)) x from oyun.bakanliklar b
    union all select jsonb_build_object('ad', 'Belediyeler', 'tl', round(v * (h ->> 'belediye')::numeric / gider, 2))
    union all select jsonb_build_object('ad', 'Yeni vatandaşlara sosyal destek', 'tl', round(v * (h ->> 'destek')::numeric / gider, 2))) z;
  return jsonb_build_object('vergi_7gun', round(v), 'vergi_oran', u.vergi, 'kalemler', kalem,
    'destek_gunluk', u.destek, 'etkiler', oyun.etkilerim(p.il_id, t));
end $$;

-- ---------------------------------------------------------------------
-- 4) SOHBET: yeni kanallar (kabine · yonetim · belediye), okunmamış sayacı
-- ---------------------------------------------------------------------
create table if not exists oyun.kanal_okuma(
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  kanal   text not null,
  son_id  bigint not null default 0,
  primary key (user_id, kanal)
);

create or replace function oyun.kanal_coz(p oyun.profiller, p_kanal text) returns text language plpgsql stable as $$
begin
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'belediye' then 'belediye:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (select 'ittifak:' || u.ittifak_id from oyun.ittifak_uyeler u where u.parti_id = p.parti_id)
    when 'kabine' then case when exists (select 1 from oyun.makamlar where user_id = p.id and bit is null and tur in ('cb','bakan')) then 'kabine' end
    when 'yonetim' then (select 'yonetim:' || pa.id from oyun.partiler pa
                         where pa.id = p.parti_id and not pa.kapali
                           and (pa.gb = p.id or exists (select 1 from oyun.parti_gby g where g.parti_id = pa.id and g.user_id = p.id)))
    else null end;
end $$;

create or replace function oyun.kanal_baslik(p oyun.profiller, kod text) returns text language sql stable as $$
  select case kod
    when 'genel' then 'Türkiye Meydanı'
    when 'il' then (select ad from oyun.iller where id = p.il_id) || ' Kahvesi'
    when 'belediye' then (select ad from oyun.iller where id = p.il_id) || ' Belediye Meclisi'
    when 'parti' then (select ad from oyun.partiler where id = p.parti_id)
    when 'yonetim' then (select kisa from oyun.partiler where id = p.parti_id) || ' Yönetim Kurulu'
    when 'meclis' then 'TBMM Genel Kurulu'
    when 'kabine' then 'Bakanlar Kurulu'
    when 'ittifak' then (select i.ad from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id = u.ittifak_id where u.parti_id = p.parti_id)
  end
$$;

create or replace function oyun.kanal_yazabilir(p oyun.profiller, kod text) returns boolean language sql stable as $$
  select case kod
    when 'meclis' then oyun.meclis_yazabilir(p.id)
    when 'belediye' then exists (select 1 from oyun.makamlar m where m.user_id = p.id and m.bit is null and m.tur in ('bel','mv') and m.il_id = p.il_id)
    else true end
$$;

create or replace function oyun.kanal_hata(kod text) returns text language sql immutable as $$
  select case kod
    when 'ittifak' then 'Partin bir ittifakta değil.'
    when 'kabine' then 'Bakanlar Kurulu sohbetine yalnızca cumhurbaşkanı ve bakanlar girebilir.'
    when 'yonetim' then 'Parti yönetimi sohbetine yalnızca genel başkan ve genel başkan yardımcıları girebilir.'
    else 'Parti sohbeti için bir partiye üye olmalısın.' end
$$;

create or replace function oyun.kanal_yaz_hata(kod text) returns text language sql immutable as $$
  select case kod
    when 'belediye' then 'Belediye meclisinde yalnızca o ilin belediye başkanı ve milletvekilleri söz alabilir; herkes izleyebilir.'
    else 'Genel Kurul''da yalnızca milletvekilleri, bakanlar ve cumhurbaşkanı söz alabilir.' end
$$;

create or replace function public.sohbet_oku(p_kanal text, p_once bigint default null, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb; son bigint;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'kad', coalesce(pr.kad, '(silinmiş)'), 'metin', x.metin, 'zaman', x.zaman,
            'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(x.user_id), 'benim', x.user_id = p.id) order by x.id), '[]'::jsonb)
    into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal = k and not m.gizli and m.zaman <= oyun.simdi() and not oyun.engelli(p.id, m.user_id)
      and (p_sonra is null or m.id > p_sonra) and (p_once is null or m.id < p_once)
    order by case when p_sonra is null then -m.id else m.id end
    limit case when p_sonra is null then 40 else 100 end
  ) x left join oyun.profiller pr on pr.id = x.user_id;
  -- okundu işareti: kanalın en son görünen mesajına kadar
  if p_once is null then
    select max(id) into son from oyun.mesajlar where kanal = k and not gizli and zaman <= oyun.simdi();
    if son is not null then
      insert into oyun.kanal_okuma(user_id, kanal, son_id) values (p.id, k, son)
      on conflict (user_id, kanal) do update set son_id = greatest(oyun.kanal_okuma.son_id, excluded.son_id);
    end if;
  end if;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste, 'yazabilir', oyun.kanal_yazabilir(p, p_kanal), 'baslik', oyun.kanal_baslik(p, p_kanal));
end $$;

create or replace function public.sohbet_yaz(p_kanal text, p_metin text) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); k text; m text;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  if not oyun.kanal_yazabilir(p, p_kanal) then raise exception '%', oyun.kanal_yaz_hata(p_kanal); end if;
  perform oyun.yazabilir_mi(p, t);
  m := oyun.metin_temizle(p_metin, 500);
  insert into oyun.mesajlar(kanal, user_id, metin, zaman) values (k, p.id, m, t);
  update oyun.profiller set son_mesaj = t where id = p.id;
  return jsonb_build_object('tamam', true);
end $$;

-- Sohbet listesi: erişebildiğin ve kilitli kanallar, son mesaj, okunmamış sayısı, çevrimiçi oyuncu
create or replace function public.sohbet_ozet() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); liste jsonb := '[]'; kod text; k text; imlec bigint; okunmamis int; son jsonb; cev int; kilit text;
begin
  foreach kod in array array['genel','il','belediye','parti','yonetim','ittifak','meclis','kabine'] loop
    k := oyun.kanal_coz(p, kod);
    kilit := case when k is not null then null else case kod
      when 'parti' then 'Bir partiye katılınca açılır.' when 'yonetim' then 'Genel başkan ya da genel başkan yardımcısı olunca açılır.'
      when 'ittifak' then 'Partin bir ittifaka girince açılır.' when 'kabine' then 'Cumhurbaşkanı ya da bakan olunca açılır.' end end;
    okunmamis := 0; son := null; cev := null;
    if k is not null then
      select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = k;
      select count(*) into okunmamis from (
        select 1 from oyun.mesajlar m where m.kanal = k and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
           and m.zaman <= t and m.zaman > t - interval '3 days' and not oyun.engelli(p.id, m.user_id) limit 100) x;
      select jsonb_build_object('kad', coalesce(pr.kad, '(silinmiş)'), 'metin', m.metin, 'zaman', m.zaman) into son
        from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
       where m.kanal = k and not m.gizli and m.zaman <= t and not oyun.engelli(p.id, m.user_id) order by m.id desc limit 1;
      cev := case kod
        when 'genel' then (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes')
        when 'il' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'belediye' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'parti' then (select count(*) from oyun.profiller where not yasakli and parti_id = p.parti_id and son_gorulme > t - interval '5 minutes')
        end;
    end if;
    liste := liste || jsonb_build_object('kanal', kod, 'baslik', coalesce(oyun.kanal_baslik(p, kod), case kod when 'parti' then 'Parti sohbeti' when 'yonetim' then 'Parti Yönetim Kurulu'
                  when 'ittifak' then 'İttifak sohbeti' when 'kabine' then 'Bakanlar Kurulu' end),
      'kilit', kilit, 'yazabilir', k is not null and oyun.kanal_yazabilir(p, kod), 'okunmamis', okunmamis, 'son', son, 'cevrimici', cev);
  end loop;
  return jsonb_build_object('kanallar', liste,
    'cevrimici', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes'),
    'toplam_okunmamis', (select coalesce(sum((x ->> 'okunmamis')::int), 0) from jsonb_array_elements(liste) x));
end $$;
