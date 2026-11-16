-- 16.11.2026 · Moderatör ana görevleri ve Finans denetim masası
-- Binlerce oyunculu ekonomiyi tek kişinin denetlemesi mümkün değil. Her moderatöre bir ANA GÖREV
-- (sorumluluk alanı) verilir; görevin gerektirdiği yetkiler otomatik eklenir, moderatör panelinde
-- kendi alanının iş kuyruğunu görür. Finans görevlisi için kredi, sermaye, servet artışı ve davet
-- ödüllerini tek ekranda gösteren Finans denetim masası eklenir. Karar yetkisi (el koyma vb.)
-- mevcut MASAK yetkisiyle sınırlıdır; her işlem moderatör günlüğüne yazılır.

alter table oyun.moderatorler add column if not exists ana_gorev text;
alter table oyun.moderatorler add column if not exists gorev_notu text;

create or replace function oyun.mod_ana_gorev_tanim()
returns table(kod text, ad text, aciklama text, yetkiler text[], sira integer)
language sql immutable set search_path to '' as $$
  values
  ('genel',    'Genel moderasyon',          'Şikâyetleri karara bağlar, sohbet ve yayın düzenini korur.', array['sikayet','sustur','oyuncu_ara']::text[], 1),
  ('finans',   'Finans denetimi (MASAK)',   'Kredi, sermaye, ani servet, transfer ve davet ödüllerini izler; şüpheli işlemleri MASAK''ta karara bağlar.', array['ekonomi','oyuncu_ara','ozet']::text[], 2),
  ('siyaset',  'Seçim ve siyaset gözetimi', 'Seçim dönemlerinde çoklu hesap, oy ve parti hareketlerini izler; bulguları yöneticiye iletir.', array['oyuncu_ara','coklu_hesap']::text[], 3),
  ('hukuk',    'Kural ihlali ve yaptırım',  'Kural ihlali yapan hesaplara süreli engel ve susturma uygular.', array['sustur','hesap_kapat','oyuncu_ara']::text[], 4),
  ('topluluk', 'Topluluk ve duyuru',        'Duyuruları yayımlar, etkinlikleri ve topluluk iletişimini yürütür.', array['duyuru','sikayet']::text[], 5),
  ('destek',   'Yeni oyuncu desteği',       'Yeni oyunculara yardım eder, hesap ve çoklu hesap sorunlarını inceler.', array['oyuncu_ara','coklu_hesap']::text[], 6)
$$;

create or replace function public.admin_moderator_gorev(p_kad text, p_ana_gorev text, p_not text default null)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yonetici_zorunlu(); t timestamptz := oyun.simdi(); h oyun.profiller := oyun.profil_bul(p_kad);
  g record; m oyun.moderatorler; yeni text[];
begin
  select * into m from oyun.moderatorler where user_id=h.id for update;
  if m.user_id is null then raise exception '% moderatör değil; önce moderatör olarak ekle.', h.kad; end if;
  if p_ana_gorev is null or btrim(p_ana_gorev)='' then
    update oyun.moderatorler set ana_gorev=null, gorev_notu=null where user_id=h.id;
    perform oyun.mod_log(p,'moderator_gorev',h.kad,'ana görev kaldırıldı');
    return public.admin_moderatorler();
  end if;
  select * into g from oyun.mod_ana_gorev_tanim() x where x.kod=p_ana_gorev;
  if g.kod is null then raise exception 'Geçersiz ana görev.'; end if;
  select array_agg(distinct x order by x) into yeni from unnest(m.yetkiler || g.yetkiler) x;
  update oyun.moderatorler set ana_gorev=g.kod, gorev_notu=nullif(left(btrim(coalesce(p_not,'')),300),''), yetkiler=yeni where user_id=h.id;
  perform oyun.bildir(h.id, format('Moderatör ana görevin: %s. %s%s', g.ad, g.aciklama,
     case when nullif(btrim(coalesce(p_not,'')),'') is not null then ' Yönetici notu: '||left(btrim(p_not),300) else '' end), t);
  perform oyun.mod_log(p,'moderator_gorev',h.kad,g.ad);
  return public.admin_moderatorler();
end $$;

do $m$
declare s text := pg_get_functiondef('public.admin_moderatorler()'::regprocedure);
begin
  if position('ana_gorev' in s)=0 then
    s := replace(s, $x$'yetkiler', to_jsonb(m.yetkiler),$x$, $x$'yetkiler', to_jsonb(m.yetkiler), 'ana_gorev', m.ana_gorev, 'gorev_notu', m.gorev_notu,$x$);
    s := replace(s, $x$'tanim', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad, 'aciklama', aciklama) order by sira) from oyun.mod_yetki_tanim()),$x$,
      $x$'tanim', (select jsonb_agg(jsonb_build_object('kod', kod, 'ad', ad, 'aciklama', aciklama) order by sira) from oyun.mod_yetki_tanim()),
    'gorevler', (select jsonb_agg(jsonb_build_object('kod', g.kod, 'ad', g.ad, 'aciklama', g.aciklama, 'yetkiler', to_jsonb(g.yetkiler)) order by g.sira) from oyun.mod_ana_gorev_tanim() g),$x$);
    if position('ana_gorev' in s)=0 or position('gorevler' in s)=0 then raise exception 'admin_moderatorler yaması uygulanamadı'; end if;
    execute s;
  end if;
end $m$;

create or replace function public.mod_gorevim()
returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare u uuid := auth.uid(); m oyun.moderatorler; g record; yon boolean;
begin
  select coalesce(yonetici,false) into yon from oyun.profiller where id=u;
  select * into m from oyun.moderatorler where user_id=u;
  if not yon and m.user_id is null then raise exception 'Yalnız moderatörler içindir.'; end if;
  select * into g from oyun.mod_ana_gorev_tanim() x where x.kod=m.ana_gorev;
  return jsonb_build_object('yonetici',yon,'ana_gorev',m.ana_gorev,'ad',g.ad,'aciklama',g.aciklama,'not',m.gorev_notu,
    'kuyruk',jsonb_build_object(
      'masak_yeni',(select count(*) from oyun.masak where durum='yeni'),
      'kredi_sermaye_7g',(select count(*) from oyun.masak where tur='kredi_sermaye' and zaman > oyun.simdi()-interval '7 days'),
      'davet_suistimal_7g',(select count(*) from oyun.masak where tur='davet_suistimal' and zaman > oyun.simdi()-interval '7 days')),
    'ekip',coalesce((select jsonb_agg(jsonb_build_object('kad',pr.kad,'ana_gorev',x.ana_gorev) order by x.ana_gorev nulls last, pr.kad)
        from oyun.moderatorler x join oyun.profiller pr on pr.id=x.user_id),'[]'::jsonb));
end $$;

create or replace function public.finans_denetim_ozet(p_gun integer default 7)
returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $$
declare p oyun.profiller := oyun.yetki_zorunlu('ekonomi'); t timestamptz := oyun.simdi(); g int := greatest(1, least(30, coalesce(p_gun,7)));
begin
  return jsonb_build_object('gun', g, 'zaman', t,
    'kredi_toplam', jsonb_build_object(
       'devlet_acik', coalesce((select sum(kalan) from oyun.krediler where durum in ('aktif','takip')),0),
       'oyb_acik', coalesce((select sum(kalan) from oyun.oyb_kredi where durum in ('aktif','takip')),0),
       'sirket_acik', coalesce((select sum(kalan) from oyun.yatirim_kredisi where durum <> 'kapandi'),0),
       'donem_kullanim', coalesce((select sum(tutar) from oyun.hesap_hareket where tur='kredi' and tutar>0 and zaman > t - make_interval(days=>g)),0)),
    'buyuk_krediler', coalesce((select jsonb_agg(x order by (x->>'kalan')::numeric desc) from (
        select jsonb_build_object('kaynak','Devlet bankası','kad',oyun.kad(k.user_id),'anapara',k.anapara,'kalan',k.kalan,'vade_gun',k.gun,'taksit',k.taksit,'acilis',k.acilis,'durum',k.durum) x
          from oyun.krediler k where k.durum in ('aktif','takip') order by k.kalan desc limit 15) z),'[]'::jsonb),
    'kredi_sermaye', coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'kad',oyun.kad(m.user_id),'tutar',m.tutar,'aciklama',m.aciklama,'zaman',m.zaman,'durum',m.durum) order by m.zaman desc)
        from (select * from oyun.masak where tur='kredi_sermaye' and zaman > t - make_interval(days=>g) order by zaman desc limit 30) m),'[]'::jsonb),
    'servet_artisi', coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(h.user_id),'giris',h.giris,'kredi',h.kredi) order by h.giris desc)
        from (select user_id, sum(tutar) giris, sum(tutar) filter (where tur='kredi') kredi from oyun.hesap_hareket
               where tutar>0 and tur not in ('yonetici','iade') and zaman > t - make_interval(days=>g)
               group by user_id order by sum(tutar) desc limit 15) h),'[]'::jsonb),
    'davet_odulleri', jsonb_build_object(
       'aktiflik', coalesce((select sum(tutar) from oyun.davet_aktiflik_odul where zaman > t - make_interval(days=>g)),0),
       'kayit', coalesce((select sum(coalesce(odul_eden,0)+coalesce(odul_edilen,0)) from oyun.davet where durum='odendi' and odul_at > t - make_interval(days=>g)),0),
       'en_cok', coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(o.alan),'tutar',o.s) order by o.s desc)
          from (select alan, sum(tutar) s from oyun.davet_aktiflik_odul where zaman > t - make_interval(days=>g) group by alan order by sum(tutar) desc limit 10) o),'[]'::jsonb)),
    'masak_bekleyen', (select count(*) from oyun.masak where durum='yeni'));
end $$;

do $g$
declare f text;
begin
  foreach f in array array['public.admin_moderator_gorev(text,text,text)','public.mod_gorevim()','public.finans_denetim_ozet(integer)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $g$;
