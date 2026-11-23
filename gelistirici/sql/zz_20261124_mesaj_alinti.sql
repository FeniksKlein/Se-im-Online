-- 24.11.2026 · SOHBETTE ALINTILI YANIT (sürüm 2026.11.24-2)
-- Canlıya 24.11.2026 00:06'da "mesaj_alinti_20261124" adıyla uygulanmıştı; kaynağı depoya alınmamıştı.
-- Bu dosya canlıdaki migration'ın aynısıdır (işlev gövdeleri canlıyla md5 eşleşir); tekrar çalıştırmak güvenlidir.
--   • oyun.mesajlar.yanit_id / oyun.ozel.yanit_id: yanıtlanan mesajın numarası (eski mesajlar boş kalır, geçmiş silinmez).
--   • sohbet_yanitla / ozel_yanitla: alıntı yalnız AYNI kanaldaki / aynı iki kişi arasındaki, kaldırılmamış mesaja yapılabilir;
--     yazma yetkisi, susturma, Genel Kurul söz hakkı vb. bütün denetimler sohbet_yaz / ozel_yaz içinde aynen çalışır.
--   • sohbet_oku / ozel_oku her mesajda `yanit` {id, kad, metin(160)} döner. Kaldırılmış mesaj: "Bu mesaj kaldırıldı.";
--     okuyanın engellediği oyuncunun mesajı: "Engellediğin bir oyuncunun mesajı."; özel mesaj alıntısı yalnız o konuşmanın
--     iki tarafına çözülür (başka sohbet üzerinden görülemez).
-- Ekran: gelistirici/www/sohbet_tasarim.js ("ALINTILI YANIT").

alter table oyun.mesajlar add column if not exists yanit_id bigint;
alter table oyun.ozel add column if not exists yanit_id bigint;

create or replace function oyun.mesaj_alinti(p oyun.profiller, p_yanit bigint) returns jsonb
language plpgsql stable set search_path to '' as $f$
declare y oyun.mesajlar; pr oyun.profiller;
begin
  if p_yanit is null then return null; end if;
  select * into y from oyun.mesajlar where id = p_yanit;
  if y.id is null then return null; end if;
  if y.gizli then return jsonb_build_object('id', y.id, 'kad', '', 'metin', 'Bu mesaj kaldırıldı.'); end if;
  select * into pr from oyun.profiller where id = y.user_id;
  if y.gorevli then return jsonb_build_object('id', y.id, 'kad', oyun.mod_imza(pr), 'metin', left(y.metin, 160)); end if;
  if oyun.engelli(p.id, y.user_id) then return jsonb_build_object('id', y.id, 'kad', '', 'metin', 'Engellediğin bir oyuncunun mesajı.'); end if;
  return jsonb_build_object('id', y.id, 'kad', case when y.user_id = p.id then 'Sen' else coalesce(pr.kad, '(silinmiş)') end, 'metin', left(y.metin, 160));
end $f$;

create or replace function oyun.ozel_alinti(p oyun.profiller, p_yanit bigint) returns jsonb
language plpgsql stable set search_path to '' as $f$
declare y oyun.ozel;
begin
  if p_yanit is null then return null; end if;
  select * into y from oyun.ozel where id = p_yanit and p.id in (gonderen, alici);
  if y.id is null then return null; end if;
  if y.gizli then return jsonb_build_object('id', y.id, 'kad', '', 'metin', 'Bu mesaj kaldırıldı.'); end if;
  return jsonb_build_object('id', y.id, 'kad', case when y.gonderen = p.id then 'Sen' else oyun.kad(y.gonderen) end, 'metin', left(y.metin, 160));
end $f$;
revoke all on function oyun.mesaj_alinti(oyun.profiller, bigint), oyun.ozel_alinti(oyun.profiller, bigint) from public, anon, authenticated;

create or replace function public.sohbet_yanitla(p_kanal text, p_metin text, p_yanit bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); k text; r jsonb; yeni bigint;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  if p_yanit is not null and not exists (select 1 from oyun.mesajlar y where y.id = p_yanit and y.kanal = k and not y.gizli) then
    raise exception 'Alıntılamak istediğin mesaj bu sohbette bulunamadı (kaldırılmış olabilir).';
  end if;
  r := public.sohbet_yaz(p_kanal, p_metin);
  if p_yanit is not null then
    yeni := currval(pg_get_serial_sequence('oyun.mesajlar', 'id'));
    update oyun.mesajlar set yanit_id = p_yanit where id = yeni and user_id = p.id and kanal = k;
  end if;
  return r;
end $f$;

create or replace function public.ozel_yanitla(p_kad text, p_metin text, p_yanit bigint) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; r jsonb; yeni bigint;
begin
  h := oyun.profil_bul(p_kad);
  if p_yanit is not null and not exists (select 1 from oyun.ozel y where y.id = p_yanit and not y.gizli
       and ((y.gonderen = p.id and y.alici = h.id) or (y.gonderen = h.id and y.alici = p.id))) then
    raise exception 'Alıntılamak istediğin mesaj bu konuşmada bulunamadı.';
  end if;
  r := public.ozel_yaz(p_kad, p_metin);
  if p_yanit is not null then
    yeni := currval(pg_get_serial_sequence('oyun.ozel', 'id'));
    update oyun.ozel set yanit_id = p_yanit where id = yeni and gonderen = p.id;
  end if;
  return r;
end $f$;

create or replace function public.sohbet_oku(p_kanal text, p_once bigint default null, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); k text; liste jsonb; son bigint;
begin
  k := oyun.kanal_coz(p, p_kanal);
  if k is null then raise exception '%', oyun.kanal_hata(p_kanal); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id,
            'kad', case when x.gorevli then oyun.mod_imza(pr) else coalesce(pr.kad, '(silinmiş)') end,
            'metin', x.metin, 'zaman', x.zaman,
            'parti', case when x.gorevli then null else oyun.parti_json(pr.parti_id) end,
            'unvan', case when x.gorevli then 'Oyun Yönetimi' else oyun.unvan(x.user_id) end,
            'benim', x.user_id = p.id, 'gorevli', x.gorevli,
            'yanit', case when x.yanit_id is not null then oyun.mesaj_alinti(p, x.yanit_id) end) order by x.id), '[]'::jsonb)
    into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal = k and not m.gizli and m.zaman <= oyun.simdi() and (m.gorevli or not oyun.engelli(p.id, m.user_id))
      and (p_sonra is null or m.id > p_sonra) and (p_once is null or m.id < p_once)
    order by case when p_sonra is null then -m.id else m.id end
    limit case when p_sonra is null then 40 else 100 end
  ) x left join oyun.profiller pr on pr.id = x.user_id;
  if p_once is null then
    select max(id) into son from oyun.mesajlar where kanal = k and not gizli and zaman <= oyun.simdi();
    if son is not null then
      insert into oyun.kanal_okuma(user_id, kanal, son_id) values (p.id, k, son)
      on conflict (user_id, kanal) do update set son_id = greatest(oyun.kanal_okuma.son_id, excluded.son_id);
    end if;
  end if;
  return jsonb_build_object('kanal', p_kanal, 'mesajlar', liste, 'yazabilir', oyun.kanal_yazabilir(p, p_kanal),
    'baslik', oyun.kanal_baslik(p, p_kanal), 'sinyal', 'sohbet:' || k,
    'gorevli_yazabilir', k = 'yardim' and oyun.yardim_gorevli_mi(p), 'resmi_yazabilir', oyun.sohbet_resmi_yazabilir(p, k), 'kanal_kod', k);
end $f$;

create or replace function public.ozel_oku(p_kad text, p_sonra bigint default null) returns jsonb
language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp' as $f$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller; liste jsonb;
begin
  h := oyun.profil_bul(p_kad);
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'metin', x.metin, 'zaman', x.zaman, 'benim', x.gonderen = p.id,
           'yanit', case when x.yanit_id is not null then oyun.ozel_alinti(p, x.yanit_id) end) order by x.id), '[]'::jsonb) into liste
  from (select * from oyun.ozel o
        where ((o.gonderen = p.id and o.alici = h.id) or (o.gonderen = h.id and o.alici = p.id)) and not o.gizli
          and (p_sonra is null or o.id > p_sonra)
        order by o.id desc limit 60) x;
  update oyun.ozel set okundu = true where alici = p.id and gonderen = h.id and not okundu;
  return jsonb_build_object('kad', h.kad, 'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'mesajlar', liste,
                            'engelledim', oyun.engelli(p.id, h.id),
                            'aktif', oyun.aktif_yazi(h.son_gorulme),
                            'okundu_son', (select max(o.id) from oyun.ozel o where o.gonderen = p.id and o.alici = h.id and o.okundu));
end $f$;

revoke all on function public.sohbet_yanitla(text, text, bigint), public.ozel_yanitla(text, text, bigint) from public, anon;
grant execute on function public.sohbet_yanitla(text, text, bigint), public.ozel_yanitla(text, text, bigint) to authenticated;
