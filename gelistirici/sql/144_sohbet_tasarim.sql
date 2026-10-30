-- =====================================================================
--  30.10.2026 · Sohbet yeniden tasarımı (Mesajlar)
--  Konuşma listesinde karşı tarafın çevrimiçi durumu ve son mesajın okunup okunmadığı;
--  konuşma ekranında karşı tarafın durumu ve "okundu" çift tiki için son okunan mesaj.
--  Yalnızca yeni JSON alanları eklenir; parametreler ve eski alanlar aynen kalır
--  (mağazadaki eski uygulama çalışmaya devam eder). Oyuncu verisine dokunmaz.
-- =====================================================================
create or replace function oyun.aktif_yazi(p_son timestamptz) returns text
language sql stable set search_path = '' as $$
  select case when p_son > oyun.simdi() - interval '10 minutes' then 'cevrimici'
              when p_son > oyun.simdi() - interval '1 day' then 'bugun'
              when p_son > oyun.simdi() - interval '7 days' then 'hafta' else 'uzun' end
$$;

create or replace function public.ozel_liste() returns jsonb
language sql security definer set search_path = oyun, public, pg_temp as $$
  with ben as (select oyun.ben() id),
  m as (
    select o.*, case when o.gonderen = (select id from ben) then o.alici else o.gonderen end diger
    from oyun.ozel o where (o.gonderen = (select id from ben) or o.alici = (select id from ben)) and not o.gizli
  ),
  son as (select distinct on (diger) * from m order by diger, id desc)
  select coalesce(jsonb_agg(jsonb_build_object('kad', pr.kad, 'parti', oyun.parti_json(pr.parti_id), 'unvan', oyun.unvan(pr.id),
           'son', s.metin, 'zaman', s.zaman, 'benden', s.gonderen = (select id from ben),
           'okunmamis', (select count(*) from m where m.diger = s.diger and m.alici = (select id from ben) and not m.okundu),
           'okundu', s.okundu, 'son_id', s.id, 'aktif', oyun.aktif_yazi(pr.son_gorulme)) order by s.id desc), '[]'::jsonb)
  from son s join oyun.profiller pr on pr.id = s.diger
  where not oyun.engelli((select id from ben), s.diger)
$$;

create or replace function public.ozel_oku(p_kad text, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; liste jsonb;
begin
  h := oyun.profil_bul(p_kad);
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'metin', x.metin, 'zaman', x.zaman, 'benim', x.gonderen = p.id) order by x.id), '[]'::jsonb) into liste
  from (select * from oyun.ozel o
        where ((o.gonderen = p.id and o.alici = h.id) or (o.gonderen = h.id and o.alici = p.id)) and not o.gizli
          and (p_sonra is null or o.id > p_sonra)
        order by o.id desc limit 60) x;
  update oyun.ozel set okundu = true where alici = p.id and gonderen = h.id and not okundu;
  return jsonb_build_object('kad', h.kad, 'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'mesajlar', liste,
                            'engelledim', oyun.engelli(p.id, h.id),
                            'aktif', oyun.aktif_yazi(h.son_gorulme),
                            'okundu_son', (select max(o.id) from oyun.ozel o where o.gonderen = p.id and o.alici = h.id and o.okundu));
end $$;
