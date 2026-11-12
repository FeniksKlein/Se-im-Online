-- =====================================================================
--  13.11.2026 · Gözaltı iletişim kısıtı, her gözaltıda avukat/baro,
--  CB/İçişleri gözaltısında günlük kota ve kısa süre
--
--  İstek (Ercan):
--   • Sebepsiz (CB/İçişleri) gözaltı ya da herhangi bir sebeple gözaltı
--     olunca baro avukat görevlendirebilsin ya da oyuncu avukat çağırabilsin.
--   • Bu gözaltılar için günlük makul bir kişi kotası olsun.
--   • Süre makul olsun, aşırı uzun olmasın.
--   • Gözaltı süresince oyuncu hiçbir sohbete/paylaşıma yazamasın; yalnız
--     avukatıyla oyun içi özel mesajlaşabilsin ve bu kendisine söylensin.
--   • Onun adına yalnız avukatı açıklama yapsın.
--   • Gözaltıyı süre bitene kadar CB ve İçişleri Bakanı dışında kimse
--     kaldıramasın.
--
--  Kapsanan üç gözaltı türü:
--    sokak    → oyun.sokak_gozalti (eylemde polis gözaltısı)
--    icisleri → oyun.icisleri_tedbir_v2 tur='gozalti' (mahkeme onaylı)
--    yonetim  → oyun.yonetim_tutuklama (CB / İçişleri Bakanı kararı)
--
--  Oyuncu verisi değişmez: yalnız yeni sütun (varsayılanlı), yeni tablo,
--  yeni işlev, tetikleyici ve tarife satırı (on conflict do nothing).
-- =====================================================================

-- ---------- Ayarlar (Süper Yönetici değiştirebilir) ----------
insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira) values
 ('yonetim_gozalti_saat',6,'saat','kural','CB/İçişleri gözaltı süresi','Cumhurbaşkanı veya İçişleri Bakanının verdiği gözaltının süresi (saat).',900),
 ('yonetim_gozalti_gunluk_kota',3,'kişi','kural','CB/İçişleri günlük gözaltı kotası','Cumhurbaşkanı ve İçişleri Bakanı her biri bir günde (TSİ) en çok bu kadar kişiyi gözaltına aldırabilir.',901),
 ('yonetim_gozalti_ara_saat',24,'saat','kural','Aynı kişiye yeniden gözaltı arası','Bir oyuncunun CB/İçişleri gözaltısı bittikten sonra aynı türden yeniden gözaltına alınabilmesi için geçmesi gereken süre (saat).',902)
on conflict (kod) do nothing;

-- ---------- Şema ----------
alter table oyun.yonetim_tutuklama add column if not exists avukat uuid references oyun.profiller(id);
alter table oyun.yonetim_tutuklama add column if not exists avukat_durum text;
create index if not exists yonetim_tutuklama_yetkili_idx on oyun.yonetim_tutuklama(yetkili, baslangic desc);
create index if not exists yonetim_tutuklama_avukat_idx on oyun.yonetim_tutuklama(avukat) where avukat is not null;
create index if not exists sokak_gozalti_avukat_idx on oyun.sokak_gozalti(avukat) where avukat is not null;
create index if not exists ic_tedbir_avukat_idx on oyun.icisleri_tedbir_v2(avukat) where avukat is not null;

-- Barodan müdafi talebi (icisleri + yonetim; sokak kendi tablosunu kullanır)
create table if not exists oyun.gozalti_baro_talep (
  kaynak text not null check (kaynak in ('icisleri','yonetim')),
  dosya_id bigint not null,
  talep_eden uuid not null references oyun.profiller(id),
  durum text not null default 'bekliyor' check (durum in ('bekliyor','gorevlendirildi')),
  zaman timestamptz not null default now(),
  avukat uuid references oyun.profiller(id),
  gorevlendiren uuid references oyun.profiller(id),
  karar_zamani timestamptz,
  primary key (kaynak, dosya_id)
);
alter table oyun.gozalti_baro_talep enable row level security;

-- Avukatın müvekkili adına yaptığı açıklamalar
create table if not exists oyun.gozalti_aciklama (
  id bigint generated always as identity primary key,
  kaynak text not null check (kaynak in ('sokak','icisleri','yonetim')),
  dosya_id bigint not null,
  avukat uuid not null references oyun.profiller(id),
  hedef uuid not null references oyun.profiller(id),
  metin text not null check (char_length(metin) between 1 and 1000),
  akis_id bigint,
  zaman timestamptz not null default now()
);
create index if not exists gozalti_aciklama_dosya_idx on oyun.gozalti_aciklama(kaynak, dosya_id, zaman desc);
alter table oyun.gozalti_aciklama enable row level security;

-- ---------- Ortak yardımcılar ----------
create or replace function oyun.gozalti_ayar(p_kod text, p_varsayilan numeric)
returns numeric language sql stable set search_path='' as $$
  select coalesce((select t.deger from oyun.tarife t where t.kod=p_kod), p_varsayilan)
$$;

-- Bir oyuncunun devam eden gözaltısı (birden çoksa en geç biteni)
create or replace function oyun.gozalti_aktif(u uuid)
returns jsonb language sql stable set search_path='' as $$
  select to_jsonb(x) from (
    select 'sokak'::text as kaynak, g.id, g.hedef, g.baslangic, g.bitis, g.avukat, g.avukat_durum
      from oyun.sokak_gozalti g where u is not null and g.hedef=u and g.durum='aktif' and g.bitis>oyun.simdi()
    union all
    select 'icisleri', k.id, k.hedef, coalesce(k.karar_at,k.acilis), k.bitis, k.avukat, k.avukat_durum
      from oyun.icisleri_tedbir_v2 k where u is not null and k.hedef=u and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>oyun.simdi()
    union all
    select 'yonetim', y.id, y.hedef, y.baslangic, y.bitis, y.avukat, y.avukat_durum
      from oyun.yonetim_tutuklama y where u is not null and y.hedef=u and y.durum='aktif' and y.bitis>oyun.simdi()
    order by bitis desc limit 1) x
$$;

-- Bir gözaltı dosyası (tür + numara) → ortak biçim
create or replace function oyun.gozalti_dosya(p_kaynak text, p_id bigint)
returns jsonb language plpgsql stable set search_path='' as $$
declare r jsonb; t timestamptz:=oyun.simdi();
begin
  if p_kaynak='sokak' then
    select jsonb_build_object('kaynak','sokak','id',g.id,'hedef',g.hedef,'baslangic',g.baslangic,'bitis',g.bitis,
      'aktif',(g.durum='aktif' and g.bitis>t),'avukat',g.avukat,'avukat_durum',g.avukat_durum,
      'yetkili',(select p.yapan from oyun.sokak_polis p where p.id=g.polis_id),
      'tur_ad','Eylem gözaltısı','gerekce','Eylem #'||g.eylem_id||' sırasında polis müdahalesi','eylem_id',g.eylem_id,
      'baro_talep',exists(select 1 from oyun.sokak_baro_talep b where b.gozalti_id=g.id and b.durum='bekliyor'))
      into r from oyun.sokak_gozalti g where g.id=p_id;
  elsif p_kaynak='icisleri' then
    select jsonb_build_object('kaynak','icisleri','id',k.id,'hedef',k.hedef,'baslangic',coalesce(k.karar_at,k.acilis),'bitis',k.bitis,
      'aktif',(k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>t),'avukat',k.avukat,'avukat_durum',k.avukat_durum,
      'yetkili',k.bakan,'tur_ad','İçişleri gözaltısı (mahkeme onaylı)','gerekce',k.gerekce,
      'baro_talep',exists(select 1 from oyun.gozalti_baro_talep b where b.kaynak='icisleri' and b.dosya_id=k.id and b.durum='bekliyor'))
      into r from oyun.icisleri_tedbir_v2 k where k.id=p_id and k.tur='gozalti';
  elsif p_kaynak='yonetim' then
    select jsonb_build_object('kaynak','yonetim','id',y.id,'hedef',y.hedef,'baslangic',y.baslangic,'bitis',y.bitis,
      'aktif',(y.durum='aktif' and y.bitis>t),'avukat',y.avukat,'avukat_durum',y.avukat_durum,
      'yetkili',y.yetkili,'tur_ad',case y.makam when 'cumhurbaskani' then 'Cumhurbaşkanlığı gözaltı kararı' else 'İçişleri Bakanlığı gözaltı kararı' end,
      'gerekce',y.gerekce,
      'baro_talep',exists(select 1 from oyun.gozalti_baro_talep b where b.kaynak='yonetim' and b.dosya_id=y.id and b.durum='bekliyor'))
      into r from oyun.yonetim_tutuklama y where y.id=p_id;
  else
    raise exception 'Geçersiz gözaltı türü';
  end if;
  if r is null then raise exception 'Gözaltı dosyası bulunamadı'; end if;
  return r;
end $$;

-- Gözaltındaki oyuncu bu kişiye özel mesaj yazabilir mi? (çağrılmış ya da kabul etmiş avukatı)
create or replace function oyun.gozalti_dm_izinli(u uuid, p_alici uuid)
returns boolean language sql stable set search_path='' as $$
  select u is not null and p_alici is not null and (
    exists(select 1 from oyun.sokak_gozalti g where g.hedef=u and g.avukat=p_alici and g.avukat_durum in ('cagrildi','kabul') and g.durum='aktif' and g.bitis>oyun.simdi())
    or exists(select 1 from oyun.icisleri_tedbir_v2 k where k.hedef=u and k.avukat=p_alici and k.avukat_durum in ('cagrildi','kabul') and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>oyun.simdi())
    or exists(select 1 from oyun.yonetim_tutuklama y where y.hedef=u and y.avukat=p_alici and y.avukat_durum in ('cagrildi','kabul') and y.durum='aktif' and y.bitis>oyun.simdi()))
$$;

-- Gözaltındakinin özel mesaj yazabileceği avukat(lar)ın adları
create or replace function oyun.gozalti_avukat_adlari(u uuid)
returns text[] language sql stable set search_path='' as $$
  select coalesce(array_agg(distinct oyun.kad(a)), '{}') from (
    select g.avukat a from oyun.sokak_gozalti g where g.hedef=u and g.avukat is not null and g.avukat_durum in ('cagrildi','kabul') and g.durum='aktif' and g.bitis>oyun.simdi()
    union select k.avukat from oyun.icisleri_tedbir_v2 k where k.hedef=u and k.avukat is not null and k.avukat_durum in ('cagrildi','kabul') and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>oyun.simdi()
    union select y.avukat from oyun.yonetim_tutuklama y where y.hedef=u and y.avukat is not null and y.avukat_durum in ('cagrildi','kabul') and y.durum='aktif' and y.bitis>oyun.simdi()) s
$$;

create or replace function oyun.gozalti_kullanici(p_kad text)
returns uuid language plpgsql stable set search_path='' as $$
declare v uuid;
begin
  select p.id into v from oyun.profiller p where lower(p.kad)=lower(btrim(coalesce(p_kad,''))) limit 1;
  if v is null then raise exception 'Bu kullanıcı adına ait oyuncu bulunamadı'; end if;
  return v;
end $$;

-- ---------- İletişim kısıtı: tetikleyici ----------
-- Yalnız oyuncunun kendi oturumuyla yazdığı satırlara bakar (zamanlayıcı ve sistem kayıtları etkilenmez).
create or replace function oyun.gozalti_yazi_engel_trg()
returns trigger language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid(); j jsonb; g jsonb; av text[];
begin
  if u is null then return new; end if;
  j := to_jsonb(new);
  if (j->>tg_argv[0]) is distinct from u::text then return new; end if;
  if coalesce(j->>'rol','') in ('sistem','reklam','bilgi') then return new; end if;
  g := oyun.gozalti_aktif(u);
  if g is null then return new; end if;
  if tg_table_name='ozel' and oyun.gozalti_dm_izinli(u, (j->>'alici')::uuid) then return new; end if;
  av := oyun.gozalti_avukat_adlari(u);
  raise exception '🔒 Gözaltındasınız (bitiş: %). Gözaltı süresince sohbet, paylaşım, açıklama ve mesaj yazamazsınız. %',
    to_char((g->>'bitis')::timestamptz at time zone 'Europe/Istanbul','DD.MM HH24:MI'),
    case when cardinality(av)>0 then 'Yalnız avukatınız '||array_to_string(av,', ')||' ile özel mesajlaşabilirsiniz; sizin adınıza açıklamayı avukatınız yapar.'
         else 'Avukat çağırabilir ya da barodan müdafi isteyebilirsiniz (Gözaltı ve Avukat ekranı); sonra yalnız avukatınızla özel mesajlaşabilirsiniz.' end
    using errcode='P0001';
end $$;

do $$
declare r record;
begin
  for r in select * from (values
    ('mesajlar','user_id'),('ozel','gonderen'),('akis','user_id'),('yayinlar','gonderen'),
    ('canli_yayin_mesaj','user_id'),('tv_mesaj','user_id'),('miting_konusma','user_id'),('miting_slogan','user_id'),
    ('gazete_kose_yorum','user_id'),('gazete_yayinlari','yazar'),('parti_aciklamalar','yazar'),('bakanlik_aciklama','user_id'),
    ('balkon','user_id'),('kapi_ziyaret','gonderen'),('tebrik','gonderen'),('adliye_yorum','yazar'),('baro_mesajlar','yazar'),
    ('sokak_aciklama','yapan'),('sokak_basin','user_id'),('sokak_mektup','yazar'),('sos_duello_soz','konusan'),
    ('kol_duyuru','yazan'),('parti_grup_duyuru','yazan'),('resmi_gun_mesaj','user_id'),('sendika_bildiri','yazar'),
    ('dernek_eylem','yazan'),('golge_rapor','yazar'),('parti_aday_tanitim','yayinlayan'),('sokak_seslenis','yapan')) v(tb,col)
  loop
    if to_regclass('oyun.'||r.tb) is not null then
      execute format('drop trigger if exists gozalti_yazi_engel on oyun.%I', r.tb);
      execute format('create trigger gozalti_yazi_engel before insert on oyun.%I for each row execute function oyun.gozalti_yazi_engel_trg(%L)', r.tb, r.col);
    end if;
  end loop;
end $$;

-- ---------- Gözaltı başlayınca oyuncuya ve baroya bilgi ----------
create or replace function oyun.gozalti_basladi_bildir(p_hedef uuid, p_kaynak text, p_id bigint, p_bitis timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare bas uuid := oyun.baro_baskan();
begin
  perform oyun.bildir(p_hedef, format('🔒 Gözaltı dosyası #%s · bitiş %s. Gözaltı süresince hiçbir sohbete, paylaşıma ya da açıklamaya yazamazsınız; yalnız avukatınızla özel mesajlaşabilirsiniz. Avukat çağırmak ya da barodan müdafi istemek için: Menü › Gözaltı ve Avukat.',
    p_id, to_char(p_bitis at time zone 'Europe/Istanbul','DD.MM HH24:MI')));
  if bas is not null and bas<>p_hedef then
    perform oyun.bildir(bas, format('⚖️ Yeni gözaltı: %s (dosya #%s). Baro olarak müdafi gönderebilirsiniz: Menü › Gözaltı ve Avukat › Baro.', oyun.kad(p_hedef), p_id));
  end if;
end $$;

create or replace function oyun.gozalti_sokak_bas_trg()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.durum='aktif' and new.bitis>oyun.simdi() then
    perform oyun.gozalti_basladi_bildir(new.hedef,'sokak',new.id,new.bitis);
  end if;
  return new;
end $$;
drop trigger if exists gozalti_bas_bildir on oyun.sokak_gozalti;
create trigger gozalti_bas_bildir after insert on oyun.sokak_gozalti for each row execute function oyun.gozalti_sokak_bas_trg();

create or replace function oyun.gozalti_icisleri_bas_trg()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.tur='gozalti' and new.durum='onay' and old.durum is distinct from 'onay' and new.hedef is not null and new.bitis>oyun.simdi() then
    perform oyun.gozalti_basladi_bildir(new.hedef,'icisleri',new.id,new.bitis);
  end if;
  return new;
end $$;
drop trigger if exists gozalti_bas_bildir on oyun.icisleri_tedbir_v2;
create trigger gozalti_bas_bildir after update of durum on oyun.icisleri_tedbir_v2 for each row execute function oyun.gozalti_icisleri_bas_trg();

-- ---------- CB / İçişleri gözaltı kararı: kota, süre, aralık ----------
create or replace function oyun.yonetim_gozalti_kota_bilgi(u uuid)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'kota', oyun.gozalti_ayar('yonetim_gozalti_gunluk_kota',3)::int,
    'kullanilan', (select count(*) from oyun.yonetim_tutuklama y where y.yetkili=u
                   and (y.baslangic at time zone 'Europe/Istanbul')::date = (oyun.simdi() at time zone 'Europe/Istanbul')::date)::int,
    'sure_saat', oyun.gozalti_ayar('yonetim_gozalti_saat',6),
    'ara_saat', oyun.gozalti_ayar('yonetim_gozalti_ara_saat',24))
$$;

create or replace function public.yonetim_tutuklama_yap(p_kullanici_adi text,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); h uuid; m text; yeni_id bigint; t timestamptz:=oyun.simdi();
  kb jsonb; sure interval; ara interval; son timestamptz;
begin
 if u is null then raise exception 'Giriş yapmalısınız'; end if;
 if oyun.cb_mi(u) then m:='cumhurbaskani';
 elsif oyun.bm_yetki(u,'icisleri') is not null then m:='icisleri_bakani';
 else raise exception 'Gözaltı kararı yetkisi yalnızca Cumhurbaşkanı ve İçişleri Bakanındadır'; end if;
 if char_length(btrim(coalesce(p_gerekce,''))) not between 10 and 800 then raise exception 'Gerekçe 10-800 karakter olmalıdır'; end if;
 if char_length(btrim(coalesce(p_kullanici_adi,''))) not between 2 and 60 then raise exception 'Geçerli oyuncu adı giriniz'; end if;
 select id into h from oyun.profiller where lower(kad)=lower(btrim(p_kullanici_adi)) and not yasakli limit 1;
 if h is null then raise exception 'Bu kullanıcı adına ait oyuncu bulunamadı'; end if;
 if h=u then raise exception 'Kendinizi gözaltına alamazsınız'; end if;
 if oyun.cb_mi(h) then raise exception 'Görevdeki Cumhurbaşkanı hakkında gözaltı kararı verilemez'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('yonetim_gozalti_kota'));
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(h::text));
 kb := oyun.yonetim_gozalti_kota_bilgi(u);
 if (kb->>'kullanilan')::int >= (kb->>'kota')::int then
   raise exception 'Günlük gözaltı kotanız doldu (bugün % / %). Yeni karar yarın (TSİ 00:00) verilebilir.', kb->>'kullanilan', kb->>'kota';
 end if;
 if oyun.gozalti_aktif(h) is not null then raise exception 'Oyuncu zaten gözaltında'; end if;
 ara := make_interval(secs => (kb->>'ara_saat')::numeric*3600);
 select max(bitis) into son from oyun.yonetim_tutuklama where hedef=h;
 if son is not null and son > t-ara then
   raise exception 'Bu oyuncunun son gözaltısı biteli % saat olmadan yeniden gözaltı kararı verilemez (yeniden mümkün: %).',
     kb->>'ara_saat', to_char((son+ara) at time zone 'Europe/Istanbul','DD.MM HH24:MI');
 end if;
 sure := make_interval(secs => greatest(0.5, least(48, (kb->>'sure_saat')::numeric))*3600);
 insert into oyun.yonetim_tutuklama(hedef,yetkili,makam,gerekce,baslangic,bitis)
 values(h,u,m,btrim(p_gerekce),t,t+sure) returning id into yeni_id;
 perform oyun.bildir(h,format('%s gözaltı kararı (#%s) verildi. Gerekçe: %s',
   case m when 'cumhurbaskani' then 'Cumhurbaşkanlığı' else 'İçişleri Bakanlığı' end, yeni_id, btrim(p_gerekce)),t);
 perform oyun.gozalti_basladi_bildir(h,'yonetim',yeni_id,t+sure);
 return pg_catalog.jsonb_build_object('tamam',true,'id',yeni_id,'hedef',p_kullanici_adi,'bitis',t+sure,
   'kota',(kb->>'kota')::int,'kalan',(kb->>'kota')::int-(kb->>'kullanilan')::int-1);
end $$;

create or replace function public.yonetim_gozalti_kota()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); kb jsonb;
begin
  if u is null or not (oyun.cb_mi(u) or oyun.bm_yetki(u,'icisleri') is not null) then
    return jsonb_build_object('yetkili',false);
  end if;
  kb := oyun.yonetim_gozalti_kota_bilgi(u);
  return kb || jsonb_build_object('yetkili',true,'kalan',greatest(0,(kb->>'kota')::int-(kb->>'kullanilan')::int));
end $$;

create or replace function public.yonetim_tutuklama_liste()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null or not (oyun.cb_mi(u) or oyun.bm_yetki(u,'icisleri') is not null)
 then raise exception 'Yetkisiz erişim'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'oyuncu',p.kad,'gerekce',v.gerekce,
   'makam',v.makam,'yetkili',oyun.kad(v.yetkili),'baslangic',v.baslangic,'bitis',v.bitis,
   'durum',case when v.durum='aktif' and v.bitis>oyun.simdi() then 'aktif' else 'sona_erdi' end,
   'avukat',oyun.kad(v.avukat),'avukat_durum',v.avukat_durum,'serbest_gerekce',v.serbest_gerekce) order by v.id desc)
   from (select * from oyun.yonetim_tutuklama order by id desc limit 30) v
   join oyun.profiller p on p.id=v.hedef),'[]'::jsonb);
end $$;

create or replace function public.yonetim_tutuklama_serbest(p_id bigint,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); v oyun.yonetim_tutuklama;
begin
 if u is null or not (oyun.cb_mi(u) or oyun.bm_yetki(u,'icisleri') is not null)
 then raise exception 'Gözaltını süresinden önce yalnız Cumhurbaşkanı veya İçişleri Bakanı sonlandırabilir'; end if;
 if char_length(btrim(coalesce(p_gerekce,''))) not between 10 and 800 then raise exception 'Gerekçe 10-800 karakter olmalıdır'; end if;
 select * into v from oyun.yonetim_tutuklama where id=p_id for update;
 if v.id is null or v.durum <> 'aktif' or v.bitis<=oyun.simdi() then raise exception 'Devam eden gözaltı bulunamadı'; end if;
 update oyun.yonetim_tutuklama set durum='serbest',bitis=oyun.simdi(),serbest_birakan=u,
   serbest_gerekce=btrim(p_gerekce),serbest_zaman=oyun.simdi() where id=p_id;
 perform oyun.bildir(v.hedef,format('Gözaltınız (#%s) %s kararıyla sona erdi: %s',p_id,
   case when oyun.cb_mi(u) then 'Cumhurbaşkanı' else 'İçişleri Bakanı' end,btrim(p_gerekce)),oyun.simdi());
 if v.avukat is not null and v.avukat_durum in ('cagrildi','kabul') then
   perform oyun.bildir(v.avukat,format('Müvekkiliniz %s serbest bırakıldı (gözaltı #%s).',oyun.kad(v.hedef),p_id));
 end if;
 return pg_catalog.jsonb_build_object('tamam',true,'id',p_id);
end $$;

-- ---------- Erken tahliye: CB ve İçişleri Bakanı (başka kimse) ----------
select oyun.fn_yama('public.sokak_cb_serbest_birak(bigint,text)'::regprocedure, 'gozalti_icisleri_serbest_20261113', array[
  $a$IF NOT oyun.cb_mi(u) THEN RAISE EXCEPTION 'Bu işlem yalnızca görevdeki Cumhurbaşkanına aittir'; END IF;$a$,
  $b$IF NOT (oyun.cb_mi(u) OR oyun.bm_yetki(u,'icisleri') IS NOT NULL) THEN RAISE EXCEPTION 'Gözaltını süresinden önce yalnız Cumhurbaşkanı veya İçişleri Bakanı sonlandırabilir'; END IF; -- gozalti_icisleri_serbest_20261113$b$,
  $c$PERFORM oyun.bildir(g.hedef, format('Cumhurbaşkanlığı kararıyla gözaltın (#%s) derhal sonlandırıldı. %s', g.id, sebep), t);$c$,
  $d$PERFORM oyun.bildir(g.hedef, format('%s kararıyla gözaltın (#%s) derhal sonlandırıldı. %s', CASE WHEN oyun.cb_mi(u) THEN 'Cumhurbaşkanlığı' ELSE 'İçişleri Bakanlığı' END, g.id, sebep), t);$d$
]);
select oyun.fn_yama('public.cb_icisleri_gozalti_serbest(bigint,text)'::regprocedure, 'gozalti_icisleri_serbest_20261113', array[
  $a$IF NOT oyun.cb_mi(u) THEN RAISE EXCEPTION 'Bu işlem yalnızca görevdeki Cumhurbaşkanına aittir'; END IF;$a$,
  $b$IF NOT (oyun.cb_mi(u) OR oyun.bm_yetki(u,'icisleri') IS NOT NULL) THEN RAISE EXCEPTION 'Gözaltını süresinden önce yalnız Cumhurbaşkanı veya İçişleri Bakanı sonlandırabilir'; END IF; -- gozalti_icisleri_serbest_20261113$b$
]);

-- ---------- Oyuncu / avukat / baro RPC'leri (üç gözaltı türü için ortak) ----------
create or replace function public.gozalti_durumum()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); g jsonb; d jsonb; mv jsonb; t timestamptz:=oyun.simdi();
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  g := oyun.gozalti_aktif(u);
  if g is not null then
    d := oyun.gozalti_dosya(g->>'kaynak',(g->>'id')::bigint);
    d := (d - 'hedef' - 'yetkili' - 'avukat') || jsonb_build_object(
      'avukat_kad', oyun.kad((d->>'avukat')::uuid),
      'yetkili_kad', case when g->>'kaynak'='yonetim' then oyun.kad((d->>'yetkili')::uuid) end,
      'yazabilecegi', to_jsonb(oyun.gozalti_avukat_adlari(u)),
      'aciklamalar', coalesce((select jsonb_agg(jsonb_build_object('metin',a.metin,'zaman',a.zaman,'avukat',oyun.kad(a.avukat)) order by a.zaman desc)
          from oyun.gozalti_aciklama a where a.kaynak=g->>'kaynak' and a.dosya_id=(g->>'id')::bigint),'[]'::jsonb));
  end if;
  select coalesce(jsonb_agg((x.j - 'avukat' - 'yetkili' - 'hedef') || jsonb_build_object(
      'hedef_kad', oyun.kad((x.j->>'hedef')::uuid),
      'aciklama_sayisi', (select count(*) from oyun.gozalti_aciklama a where a.kaynak=x.j->>'kaynak' and a.dosya_id=(x.j->>'id')::bigint))
      order by (x.j->>'bitis')),'[]'::jsonb)
    into mv from (
      select oyun.gozalti_dosya('sokak',s.id) j from oyun.sokak_gozalti s where s.avukat=u and s.avukat_durum in ('cagrildi','kabul') and s.durum='aktif' and s.bitis>t
      union all select oyun.gozalti_dosya('icisleri',k.id) from oyun.icisleri_tedbir_v2 k where k.avukat=u and k.avukat_durum in ('cagrildi','kabul') and k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>t
      union all select oyun.gozalti_dosya('yonetim',y.id) from oyun.yonetim_tutuklama y where y.avukat=u and y.avukat_durum in ('cagrildi','kabul') and y.durum='aktif' and y.bitis>t) x;
  return jsonb_build_object('simdi',t,'gozalti',d,'muvekkiller',mv,
    'avukat_mi', oyun.avukat_ruhsatli(u),
    'baro_baskani', u = oyun.baro_baskan(),
    'tahliye_yetkisi', (oyun.cb_mi(u) or oyun.bm_yetki(u,'icisleri') is not null));
end $$;

create or replace function public.gozalti_avukat_ara(p_ara text default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); q text:=lower(btrim(coalesce(p_ara,'')));
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('kad',x.kad,'il',x.il,'baro',x.baro) order by x.baro desc, x.kad) from (
    select p.kad, (select i.ad from oyun.iller i where i.id=p.il_id) il,
      exists(select 1 from oyun.baro_uyeleri b where b.user_id=p.id and b.durum='aktif') baro
    from oyun.avukat_ruhsat r join oyun.profiller p on p.id=r.user_id
    where r.durum='aktif' and r.user_id<>u and not coalesce(p.yasakli,false)
      and oyun.avukat_gorev_engeli(r.user_id) is null
      and (q='' or lower(p.kad) like '%'||q||'%')
    order by 3 desc, p.kad limit 25) x),'[]'::jsonb);
end $$;

create or replace function public.gozalti_avukat_cagir2(p_kaynak text, p_id bigint, p_avukat_kad text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); av uuid; d jsonb; y oyun.yonetim_tutuklama;
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  av := oyun.gozalti_kullanici(p_avukat_kad);
  if av=u then raise exception 'Kendinizi avukat olarak çağıramazsınız'; end if;
  if not oyun.avukat_ruhsatli(av) then raise exception 'Seçtiğiniz oyuncunun aktif avukatlık ruhsatı yok'; end if;
  if oyun.avukat_gorev_engeli(av) is not null then raise exception 'Seçtiğiniz avukat görevi nedeniyle avukatlık yapamıyor: %', oyun.avukat_gorev_engeli(av); end if;
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if (d->>'hedef')::uuid is distinct from u then raise exception 'Yalnız gözaltındaki oyuncu kendi dosyası için avukat çağırabilir'; end if;
  if not (d->>'aktif')::boolean then raise exception 'Bu gözaltı sona ermiş'; end if;
  if (d->>'yetkili')::uuid = av then raise exception 'Gözaltı kararını veren kişi avukatınız olamaz'; end if;
  if p_kaynak='sokak' then return public.sokak_avukat_cagir(p_id, av);
  elsif p_kaynak='icisleri' then return public.icisleri_avukat_cagir(p_id, av);
  end if;
  select * into y from oyun.yonetim_tutuklama where id=p_id for update;
  if y.avukat_durum='kabul' then raise exception 'Görevdeki bir avukatınız zaten var'; end if;
  update oyun.yonetim_tutuklama set avukat=av, avukat_durum='cagrildi' where id=p_id;
  perform oyun.bildir(av, format('⚖️ %s gözaltında (dosya #%s) ve sizi avukat olarak çağırıyor. Menü › Gözaltı ve Avukat ekranından kabul edin; müvekkilinizle özel mesajlaşabilir ve onun adına açıklama yapabilirsiniz.', oyun.kad(u), p_id));
  return jsonb_build_object('tamam',true);
end $$;

create or replace function public.gozalti_avukat_yanit2(p_kaynak text, p_id bigint, p_kabul boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); y oyun.yonetim_tutuklama; bas uuid;
begin
  if u is null or p_kabul is null then raise exception 'Oturum ve cevap gerekli'; end if;
  if p_kaynak='sokak' then return public.sokak_avukat_cevap(p_id, p_kabul);
  elsif p_kaynak='icisleri' then return public.icisleri_avukat_yanit(p_id, p_kabul);
  elsif p_kaynak<>'yonetim' then raise exception 'Geçersiz gözaltı türü'; end if;
  select * into y from oyun.yonetim_tutuklama where id=p_id for update;
  if y.id is null or y.avukat is distinct from u or y.avukat_durum<>'cagrildi' then raise exception 'Sizin için bekleyen avukat çağrısı bulunmuyor'; end if;
  if p_kabul and (y.durum<>'aktif' or y.bitis<=oyun.simdi()) then raise exception 'Gözaltı sona ermiş'; end if;
  update oyun.yonetim_tutuklama set avukat_durum=case when p_kabul then 'kabul' else 'red' end where id=p_id;
  perform oyun.bildir(y.hedef, 'Avukat '||oyun.kad(u)||' gözaltı #'||p_id||' için '||case when p_kabul
    then 'savunmanızı üstlendi. Gözaltı süresince yalnız onunla özel mesajlaşabilirsiniz; adınıza açıklamayı o yapar.' else 'görevi reddetti. Başka avukat çağırabilir ya da barodan müdafi isteyebilirsiniz.' end);
  if not p_kabul and exists(select 1 from oyun.gozalti_baro_talep b where b.kaynak='yonetim' and b.dosya_id=p_id and b.gorevlendiren is not null) then
    bas := oyun.baro_baskan();
    update oyun.gozalti_baro_talep set durum='bekliyor', avukat=null where kaynak='yonetim' and dosya_id=p_id;
    if bas is not null then perform oyun.bildir(bas,'Gözaltı #'||p_id||': gönderilen avukat görevi reddetti, başka avukat gönderin.'); end if;
  end if;
  return jsonb_build_object('tamam',true);
end $$;

create or replace function public.gozalti_baro_iste2(p_kaynak text, p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d jsonb; bas uuid;
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  if p_kaynak='sokak' then return public.sokak_baro_iste(p_id); end if;
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if (d->>'hedef')::uuid is distinct from u then raise exception 'Yalnız kendi gözaltı dosyanız için talep yapabilirsiniz'; end if;
  if not (d->>'aktif')::boolean then raise exception 'Bu gözaltı sona ermiş'; end if;
  if d->>'avukat_durum'='kabul' then raise exception 'Görevdeki bir avukatınız zaten var'; end if;
  if (d->>'baro_talep')::boolean then raise exception 'Baro talebiniz zaten beklemede'; end if;
  bas := oyun.baro_baskan();
  if bas is null then raise exception 'Baroda görevlendirme yapabilecek yetkili yok; listeden bir avukat çağırın'; end if;
  insert into oyun.gozalti_baro_talep(kaynak,dosya_id,talep_eden,durum,zaman) values(p_kaynak,p_id,u,'bekliyor',oyun.simdi())
  on conflict (kaynak,dosya_id) do update set durum='bekliyor', talep_eden=u, zaman=excluded.zaman, avukat=null, gorevlendiren=null, karar_zamani=null;
  perform oyun.bildir(bas, format('⚖️ %s gözaltında (dosya #%s) ve barodan müdafi istiyor. Menü › Gözaltı ve Avukat › Baro bölümünden avukat gönderin.', oyun.kad(u), p_id));
  return jsonb_build_object('tamam',true,'durum','bekliyor');
end $$;

create or replace function public.gozalti_baro_liste2()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  if u is distinct from oyun.baro_baskan() then return jsonb_build_object('baro_baskani',false,'gozaltilar','[]'::jsonb); end if;
  return jsonb_build_object('baro_baskani',true,'gozaltilar',coalesce((select jsonb_agg(
      x.j - 'avukat' - 'yetkili' - 'hedef' || jsonb_build_object('hedef_kad',oyun.kad((x.j->>'hedef')::uuid),'avukat_kad',oyun.kad((x.j->>'avukat')::uuid))
      order by (x.j->>'baro_talep')::boolean desc, (x.j->>'bitis')) from (
    select oyun.gozalti_dosya('sokak',s.id) j from oyun.sokak_gozalti s where s.durum='aktif' and s.bitis>t
    union all select oyun.gozalti_dosya('icisleri',k.id) from oyun.icisleri_tedbir_v2 k where k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>t
    union all select oyun.gozalti_dosya('yonetim',y.id) from oyun.yonetim_tutuklama y where y.durum='aktif' and y.bitis>t) x),'[]'::jsonb));
end $$;

create or replace function public.gozalti_baro_gonder2(p_kaynak text, p_id bigint, p_avukat_kad text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); av uuid; d jsonb;
begin
  if u is null or u is distinct from oyun.baro_baskan() then raise exception 'Yalnız baro başkanı müdafi gönderebilir'; end if;
  av := oyun.gozalti_kullanici(p_avukat_kad);
  if p_kaynak='sokak' then return public.sokak_baro_gonder(p_id, av); end if;
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if not (d->>'aktif')::boolean then raise exception 'Devam eden gözaltı yok'; end if;
  if d->>'avukat_durum'='kabul' then raise exception 'Bu dosyanın avukatı zaten görevde'; end if;
  if av=(d->>'hedef')::uuid or not oyun.avukat_ruhsatli(av)
     or not exists(select 1 from oyun.baro_uyeleri b where b.user_id=av and b.durum='aktif')
     or oyun.avukat_gorev_engeli(av) is not null then
    raise exception 'Baroya kayıtlı, ruhsatı aktif ve görev engeli olmayan başka bir avukat seçin'; end if;
  if av=(d->>'yetkili')::uuid then raise exception 'Gözaltı kararını veren kişi müdafi olamaz'; end if;
  if p_kaynak='icisleri' then
    update oyun.icisleri_tedbir_v2 set avukat=av, avukat_durum='cagrildi' where id=p_id;
  else
    update oyun.yonetim_tutuklama set avukat=av, avukat_durum='cagrildi' where id=p_id;
  end if;
  insert into oyun.gozalti_baro_talep(kaynak,dosya_id,talep_eden,durum,zaman,avukat,gorevlendiren,karar_zamani)
  values(p_kaynak,p_id,u,'gorevlendirildi',oyun.simdi(),av,u,oyun.simdi())
  on conflict (kaynak,dosya_id) do update set durum='gorevlendirildi', avukat=av, gorevlendiren=u, karar_zamani=oyun.simdi();
  perform oyun.bildir(av, format('⚖️ Baro sizi gözaltındaki %s için (dosya #%s) müdafi olarak gönderdi. Menü › Gözaltı ve Avukat ekranından kabul edin.', oyun.kad((d->>'hedef')::uuid), p_id));
  perform oyun.bildir((d->>'hedef')::uuid, format('⚖️ Baro gözaltı #%s için size avukat gönderdi: %s. Gözaltı süresince yalnız onunla özel mesajlaşabilirsiniz.', p_id, oyun.kad(av)));
  return jsonb_build_object('tamam',true,'durum','gorevlendirildi');
end $$;

create or replace function public.gozalti_avukat_aciklama(p_kaynak text, p_id bigint, p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d jsonb; m text; t timestamptz:=oyun.simdi(); hk text; p oyun.profiller; aid bigint; govde text;
begin
  if u is null then raise exception 'Oturum gerekli'; end if;
  d := oyun.gozalti_dosya(p_kaynak,p_id);
  if (d->>'avukat')::uuid is distinct from u or d->>'avukat_durum' is distinct from 'kabul' then
    raise exception 'Müvekkil adına yalnız bu dosyada görevi kabul etmiş avukat açıklama yapabilir'; end if;
  if not (d->>'aktif')::boolean then raise exception 'Gözaltı sona erdi; müvekkiliniz artık kendisi açıklama yapabilir'; end if;
  m := btrim(coalesce(p_metin,''));
  if char_length(m) not between 15 and 850 then raise exception 'Açıklama 15–850 karakter olmalı'; end if;
  m := oyun.metin_temizle(m, 850);
  if m ~* '(https?://|www\.|t\.me/)' then raise exception 'Açıklamada bağlantı kullanılamaz'; end if;
  if exists(select 1 from oyun.gozalti_aciklama a where a.kaynak=p_kaynak and a.dosya_id=p_id and a.zaman>t-interval '10 minutes') then
    raise exception 'Bu dosya için 10 dakikada bir açıklama yapılabilir'; end if;
  if (select count(*) from oyun.gozalti_aciklama a where a.kaynak=p_kaynak and a.dosya_id=p_id) >= 12 then
    raise exception 'Bu gözaltı dosyası için açıklama sınırına (12) ulaşıldı'; end if;
  hk := oyun.kad((d->>'hedef')::uuid);
  select * into p from oyun.profiller where id=u;
  govde := left('⚖️ Avukat açıklaması · Gözaltındaki müvekkilim @'||hk||' adına: '||m, 1000);
  insert into oyun.akis(user_id,metin,zaman,il_id,parti_id) values(u,govde,t,p.il_id,p.parti_id) returning id into aid;
  insert into oyun.gozalti_aciklama(kaynak,dosya_id,avukat,hedef,metin,akis_id,zaman) values(p_kaynak,p_id,u,(d->>'hedef')::uuid,m,aid,t);
  perform oyun.bildir((d->>'hedef')::uuid, format('⚖️ Avukatınız %s sizin adınıza Kürsü''de açıklama yaptı: %s', oyun.kad(u), left(m,140)));
  return jsonb_build_object('tamam',true,'akis_id',aid);
end $$;

-- ---------- Yetkiler ----------
do $$
declare f text;
begin
  foreach f in array array[
    'public.gozalti_durumum()','public.gozalti_avukat_ara(text)','public.gozalti_avukat_cagir2(text,bigint,text)',
    'public.gozalti_avukat_yanit2(text,bigint,boolean)','public.gozalti_baro_iste2(text,bigint)','public.gozalti_baro_liste2()',
    'public.gozalti_baro_gonder2(text,bigint,text)','public.gozalti_avukat_aciklama(text,bigint,text)','public.yonetim_gozalti_kota()',
    'public.yonetim_tutuklama_yap(text,text)','public.yonetim_tutuklama_liste()','public.yonetim_tutuklama_serbest(bigint,text)']
  loop
    execute 'revoke all on function '||f||' from public, anon';
    execute 'grant execute on function '||f||' to authenticated';
  end loop;
  foreach f in array array['oyun.gozalti_ayar(text,numeric)','oyun.gozalti_aktif(uuid)','oyun.gozalti_dosya(text,bigint)',
    'oyun.gozalti_dm_izinli(uuid,uuid)','oyun.gozalti_avukat_adlari(uuid)','oyun.gozalti_kullanici(text)','oyun.gozalti_yazi_engel_trg()',
    'oyun.gozalti_basladi_bildir(uuid,text,bigint,timestamptz)','oyun.gozalti_sokak_bas_trg()','oyun.gozalti_icisleri_bas_trg()',
    'oyun.yonetim_gozalti_kota_bilgi(uuid)']
  loop
    execute 'revoke all on function '||f||' from public, anon, authenticated';
  end loop;
end $$;

select oyun.sonlu_kisit_kur();
