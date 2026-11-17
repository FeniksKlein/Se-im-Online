-- 17.11.2026: Kürsü kurumsal gönderileri. Eski oyuncu ve gönderi verileri korunur.
alter table oyun.akis add column if not exists kurum_tur text;
alter table oyun.akis add column if not exists kurum_id text;
alter table oyun.akis add column if not exists kurum_ad text;
alter table oyun.akis add column if not exists kurum_rol text;
create index if not exists akis_kurum_kimlik_idx on oyun.akis (kurum_tur, kurum_id, id desc) where kurum_tur is not null;

-- Kurum ve makamlar adına sadece o an yetkili olan oyuncu paylaşabilir.
-- Bu yordam public API değil, yalnızca güvenilir public RPC tarafından çağrılır.
create or replace function oyun.kursu_kurum_yetkileri(p_user uuid)
returns table (tur text, kimlik text, ad text, rol text)
language sql stable set search_path = '' as $kurum$
  select 'cb'::text, 'turkiye'::text, 'Cumhurbaşkanlığı'::text, 'Cumhurbaşkanı'::text
  from oyun.makamlar m where m.user_id=p_user and m.tur='cb' and m.bit is null
  union all
  select 'tbmm'::text, 'turkiye'::text, 'Türkiye Büyük Millet Meclisi'::text, 'TBMM Başkanı'::text
  from oyun.makamlar m where m.user_id=p_user and m.tur='tbmm' and m.bit is null
  union all
  select 'bakanlik'::text, m.bakanlik::text, coalesce(b.ad, m.bakanlik || ' Bakanlığı'), 'Bakan'::text
  from oyun.makamlar m left join oyun.bakanliklar b on b.kod=m.bakanlik
  where m.user_id=p_user and m.tur='bakan' and m.bit is null and nullif(btrim(m.bakanlik),'') is not null
  union all
  select 'belediye'::text, m.il_id::text,
    i.ad || case when i.ad in ('Adana','Ankara','Antalya','Aydın','Balıkesir','Bursa','Denizli','Diyarbakır','Erzurum','Eskişehir','Gaziantep','Hatay','İstanbul','İzmir','Kahramanmaraş','Kayseri','Kocaeli','Konya','Malatya','Manisa','Mardin','Mersin','Muğla','Ordu','Sakarya','Samsun','Şanlıurfa','Tekirdağ','Trabzon','Van')
      then ' Büyükşehir Belediyesi' else ' Belediyesi' end, 'Belediye Başkanı'::text
  from oyun.makamlar m join oyun.iller i on i.id=m.il_id
  where m.user_id=p_user and m.tur='bel' and m.bit is null
  union all
  select 'parti'::text, p.id::text, p.ad,
    case when p.gb=p_user then 'Genel Başkan' else 'Genel Başkan Vekili' end::text
  from oyun.partiler p
  where not coalesce(p.kapali,false) and (p.gb=p_user or p.gb_vekil=p_user)
  union all
  select 'dernek'::text, d.id::text, d.ad, 'Dernek Başkanı'::text
  from oyun.dernekler d where d.baskan=p_user and not coalesce(d.kapali,false)
  union all
  select 'tv'::text, k.id::text, k.ad, 'Kanal Sahibi'::text
  from oyun.tv_kanal k where k.sahip=p_user and coalesce(k.aktif,false)
  union all
  select 'gazete'::text, g.id::text, g.ad, 'Gazete Sahibi'::text
  from oyun.oyuncu_gazeteleri g where g.sahip=p_user and coalesce(g.aktif,false)
  union all
  select 'sirket'::text, s.id::text, s.ad, 'Şirket Yetkilisi'::text
  from oyun.sirketler s
  where coalesce(s.aktif,false) and (s.yonetici=p_user or (s.yonetici is null and s.kurucu=p_user))
$kurum$;

create or replace function public.kursu_kurumsal_kimlikler()
returns jsonb language sql stable security definer set search_path = '' as $kurum$
  select coalesce(jsonb_agg(jsonb_build_object('tur', x.tur, 'kimlik', x.kimlik, 'ad', x.ad, 'rol', x.rol) order by x.ad, x.tur), '[]'::jsonb)
  from oyun.kursu_kurum_yetkileri((oyun.profilim()).id) x
$kurum$;

-- Mevcut akis_yaz doğrulamaları (susturma, tekrar, bağlantı/kelime filtresi vb.) aynen çalışır.
-- Oyuncunun seçtiği kurum adı değil, sunucudaki anlık yetki kaydı esas alınır.
create or replace function public.kursu_kurumsal_yaz(p_metin text, p_tur text, p_kimlik text)
returns jsonb language plpgsql security definer set search_path = '' as $kurum$
declare
  p oyun.profiller := oyun.profilim();
  v record;
  sonuc jsonb;
  v_id bigint;
begin
  if nullif(btrim(coalesce(p_tur,'')),'') is null or nullif(btrim(coalesce(p_kimlik,'')),'') is null then
    raise exception 'Paylaşım yapacağın kurumu seç.';
  end if;
  select * into v from oyun.kursu_kurum_yetkileri(p.id) y
  where y.tur=p_tur and y.kimlik=p_kimlik limit 1;
  if not found then raise exception 'Bu kurum adına paylaşım yapma yetkin yok veya görevin sona ermiş.'; end if;
  sonuc := public.akis_yaz(p_metin);
  v_id := (sonuc->>'id')::bigint;
  update oyun.akis a
     set kurum_tur=v.tur, kurum_id=v.kimlik, kurum_ad=v.ad, kurum_rol=v.rol,
         parti_id=case when v.tur='parti' then v.kimlik::bigint else a.parti_id end,
         il_id=case when v.tur='belediye' then v.kimlik::smallint else a.il_id end
   where a.id=v_id and a.user_id=p.id;
  if not found then raise exception 'Kurumsal gönderi kaydedilemedi.'; end if;
  return sonuc || jsonb_build_object('kurum', v.ad);
end $kurum$;

-- Var olan Kürsü RPC'leri bozulmadan tüm akışlar aynı JSON'a kurumsal kimliği ekler.
create or replace function oyun.kursu_json(a oyun.akis, ben uuid) returns jsonb
language sql stable set search_path = '' as $kurum$
  select oyun.akis_json(a, ben) || jsonb_build_object(
    'kurum', case when a.kurum_tur is not null then jsonb_build_object(
      'tur', a.kurum_tur, 'kimlik', a.kurum_id, 'ad', a.kurum_ad, 'rol', a.kurum_rol) else null end,
    'yp', (select count(*) from oyun.kursu_yp y where y.akis_id = a.id),
    'ypledim', exists (select 1 from oyun.kursu_yp y where y.akis_id = a.id and y.user_id = ben),
    'alinti_sayi', (select count(*) from oyun.akis q where q.alinti_id = a.id and not q.gizli),
    'alinti', case when a.alinti_id is not null then oyun.kursu_alinti_json(a.alinti_id) end,
    'yanit_kad', case when a.yanit_id is not null then (select pr.kad from oyun.akis u join oyun.profiller pr on pr.id = u.user_id where u.id = a.yanit_id) end,
    'takip_ediyorum', exists (select 1 from oyun.kursu_takip t where t.takipci = ben and t.takip_edilen = a.user_id))
$kurum$;

revoke all on function oyun.kursu_kurum_yetkileri(uuid) from public, anon, authenticated;
revoke all on function public.kursu_kurumsal_kimlikler() from public, anon;
revoke all on function public.kursu_kurumsal_yaz(text,text,text) from public, anon;
grant execute on function public.kursu_kurumsal_kimlikler() to authenticated;
grant execute on function public.kursu_kurumsal_yaz(text,text,text) to authenticated;
