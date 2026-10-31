-- =====================================================================
--  159 · AdMob sunucu tarafı doğrulama (SSV)
--  Ödüllü reklam parası artık istemcinin reklam_odul() çağrısıyla yazılmaz.
--  Akış:
--    1) Oyuncu reklam_hazirla() çağırır. Günlük 5 ve 60 sn sınırları burada da
--       bakılır. Reklamsız hak (Siyaset Kartı / reklamsiz) varsa yol='reklamsiz'
--       döner ve mevcut reklam_odul() ödemeyi yapar.
--    2) Diğer oyunculara tek kullanımlık token verilir. Uygulama bunu AdMob
--       SSV custom_data, profil kimliğini user_id olarak gönderir.
--    3) Google, imzalı GET ile edge function admob-ssv'yi çağırır. İmza
--       Google açık anahtarıyla doğrulanır; sonra yalnız service_role
--       reklam_ssv_isle çağrılır.
--    4) Aynı transaction_id ikinci kez para yazmaz. Token 20 dakika geçerlidir.
--  YETKİLER (eşzamanlı grant/search_path PR'si bunları ezmemeli):
--    public.reklam_hazirla()          → authenticated (anon/public değil)
--    public.reklam_odul()             → authenticated (yalnız reklamsız hak öder)
--    public.reklam_ssv_isle(jsonb)    → YALNIZ service_role
--  reklam_ssv_isle ek olarak oyun.uygulama_ayar.admob_ssv_gizli ile karşılaştırır
--  (herkese_acik = false). EXECUTE yanlışlıkla authenticated'a açılsa bile
--  gizli bilinmeden ödeme yapılmaz. Gizli bu dosyaya yazılmaz; kurulum notu aşağıda.
--  search_path fonksiyonlarda sabittir (oyun, public, pg_temp).
-- =====================================================================

create table if not exists oyun.reklam_ssv_bekleyen (
  token         text primary key,
  user_id       uuid not null references oyun.profiller(id),
  olusturma     timestamptz not null default now(),
  son_kullanma  timestamptz not null,
  transaction_id text,
  durum         text not null default 'bekliyor'
    check (durum in ('bekliyor', 'verildi', 'reddedildi'))
);
create unique index if not exists reklam_ssv_bekleyen_islem_idx
  on oyun.reklam_ssv_bekleyen (transaction_id) where transaction_id is not null;
create index if not exists reklam_ssv_bekleyen_kullanici_idx
  on oyun.reklam_ssv_bekleyen (user_id, durum);

create table if not exists oyun.reklam_ssv_islem (
  transaction_id text primary key,
  user_id        uuid,
  token          text,
  durum          text not null,
  odul           numeric,
  zaman          timestamptz not null default now(),
  ham            jsonb
);

alter table oyun.reklam_ssv_bekleyen enable row level security;
alter table oyun.reklam_ssv_islem enable row level security;
revoke all on oyun.reklam_ssv_bekleyen, oyun.reklam_ssv_islem from public, anon, authenticated;

-- İstemci: reklam göstermeden önce. Para yazmaz.
create or replace function public.reklam_hazirla() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  c oyun.cuzdan;
  tok text;
begin
  c := oyun.cuzdanim(p.id);
  if c.izle_n >= 5 then raise exception 'Bugünkü reklam ödüllerini aldın. Yarın yeniden gel.'; end if;
  if c.son_izle is not null and c.son_izle > t - interval '60 seconds' then
    raise exception 'Bir sonraki reklam için biraz bekle.';
  end if;
  if oyun.reklamsiz(p.id, t) then
    return jsonb_build_object('yol', 'reklamsiz', 'user_id', p.id, 'kalan', greatest(0, 5 - c.izle_n));
  end if;
  delete from oyun.reklam_ssv_bekleyen
   where user_id = p.id and durum = 'bekliyor' and son_kullanma < t;
  select token into tok from oyun.reklam_ssv_bekleyen
   where user_id = p.id and durum = 'bekliyor' and son_kullanma > t
   order by olusturma desc limit 1;
  if tok is null then
    tok := replace(gen_random_uuid()::text, '-', '');
    insert into oyun.reklam_ssv_bekleyen(token, user_id, son_kullanma)
    values (tok, p.id, t + interval '20 minutes');
  end if;
  return jsonb_build_object('yol', 'ssv', 'user_id', p.id, 'token', tok, 'kalan', greatest(0, 5 - c.izle_n));
end $$;

-- Doğrulanmış geri çağrı. Edge function imzayı doğruladıktan sonra çağırır.
-- p_olay.gizli, edge ortamındaki ADMOB_SSV_GIZLI ile aynı olmalıdır.
create or replace function public.reklam_ssv_isle(p_olay jsonb) returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare
  p jsonb := coalesce(p_olay, '{}'::jsonb);
  tid text := left(btrim(coalesce(p->>'transaction_id', '')), 128);
  jeton text := left(btrim(coalesce(p->>'custom_data', '')), 128);
  gelen text := coalesce(p->>'gizli', '');
  beklenen text;
  uid uuid;
  t timestamptz := oyun.simdi();
  b oyun.reklam_ssv_bekleyen;
  c oyun.cuzdan;
  odul numeric;
  mevcut oyun.reklam_ssv_islem;
  ham jsonb := p - 'gizli';
  sonuc text;
begin
  select deger #>> '{}' into beklenen from oyun.uygulama_ayar where anahtar = 'admob_ssv_gizli';
  if beklenen is null or length(beklenen) < 24 or gelen is distinct from beklenen then
    return jsonb_build_object('durum', 'yetkisiz');
  end if;
  if tid = '' then
    return jsonb_build_object('durum', 'gecersiz');
  end if;
  perform pg_advisory_xact_lock(481516, hashtext(tid));
  select * into mevcut from oyun.reklam_ssv_islem where transaction_id = tid;
  if found then
    return jsonb_build_object('durum', 'zaten_islendi', 'sonuc_durum', mevcut.durum, 'odul', mevcut.odul);
  end if;
  begin
    uid := nullif(btrim(coalesce(p->>'user_id', '')), '')::uuid;
  exception when others then
    uid := null;
  end;
  if uid is null or not exists (select 1 from oyun.profiller where id = uid) then
    insert into oyun.reklam_ssv_islem(transaction_id, durum, ham) values (tid, 'kullanici_yok', ham);
    return jsonb_build_object('durum', 'kullanici_yok');
  end if;
  select * into b from oyun.reklam_ssv_bekleyen where reklam_ssv_bekleyen.token = jeton for update;
  if not found then
    insert into oyun.reklam_ssv_islem(transaction_id, user_id, token, durum, ham)
    values (tid, uid, nullif(jeton, ''), 'token_yok', ham);
    return jsonb_build_object('durum', 'token_yok');
  end if;
  if b.user_id <> uid or b.durum <> 'bekliyor' or b.son_kullanma < t then
    sonuc := case
      when b.user_id is distinct from uid then 'token_yok'
      when b.durum <> 'bekliyor' then 'token_kullanildi'
      else 'suresi_doldu' end;
    if b.user_id = uid and b.durum = 'bekliyor' then
      update oyun.reklam_ssv_bekleyen set durum = 'reddedildi', transaction_id = tid where reklam_ssv_bekleyen.token = b.token;
    end if;
    insert into oyun.reklam_ssv_islem(transaction_id, user_id, token, durum, ham)
    values (tid, uid, nullif(jeton, ''), sonuc, ham);
    return jsonb_build_object('durum', sonuc);
  end if;
  c := oyun.cuzdanim(uid);
  if c.izle_n >= 5 or (c.son_izle is not null and c.son_izle > t - interval '60 seconds') then
    sonuc := case when c.izle_n >= 5 then 'limit' else 'bekleme' end;
    update oyun.reklam_ssv_bekleyen set durum = 'reddedildi', transaction_id = tid where reklam_ssv_bekleyen.token = b.token;
    insert into oyun.reklam_ssv_islem(transaction_id, user_id, token, durum, ham)
    values (tid, uid, b.token, sonuc, ham);
    return jsonb_build_object('durum', sonuc);
  end if;
  odul := (oyun.gelir_hesap(uid, t) ->> 'reklam_odul')::numeric;
  update oyun.cuzdan set izle_n = izle_n + 1, son_izle = t where user_id = uid;
  perform oyun.para_islem(uid, odul, 'reklam_odul', 'Reklam izleme ödülü', t);
  update oyun.reklam_ssv_bekleyen set durum = 'verildi', transaction_id = tid where reklam_ssv_bekleyen.token = b.token;
  insert into oyun.reklam_ssv_islem(transaction_id, user_id, token, durum, odul, ham)
  values (tid, uid, b.token, 'verildi', odul, ham);
  return jsonb_build_object('durum', 'verildi', 'odul', odul);
end $$;

-- Eski istemci hâlâ bunu çağırır. Parasız izleme yolu kapatıldı; reklamsız hak durur.
create or replace function public.reklam_odul() returns jsonb
language plpgsql security definer set search_path = oyun, public, pg_temp as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); c oyun.cuzdan; odul numeric;
begin
  if not oyun.reklamsiz(p.id, t) then
    raise exception 'Reklam ödülü yalnızca Google tarafından doğrulanmış izlemeden sonra verilir.';
  end if;
  c := oyun.cuzdanim(p.id);
  if c.izle_n >= 5 then raise exception 'Bugünkü reklam ödüllerini aldın. Yarın yeniden gel.'; end if;
  if c.son_izle is not null and c.son_izle > t - interval '60 seconds' then raise exception 'Bir sonraki reklam için biraz bekle.'; end if;
  odul := (oyun.gelir_hesap(p.id, t) ->> 'reklam_odul')::numeric;
  update oyun.cuzdan set izle_n = izle_n + 1, son_izle = t where user_id = p.id;
  perform oyun.para_islem(p.id, odul, 'reklam_odul', 'Reklam izleme ödülü', t);
  return public.hayat() || jsonb_build_object('sonuc', jsonb_build_object('odul', odul));
end $$;

revoke all on function public.reklam_hazirla() from public, anon;
grant execute on function public.reklam_hazirla() to authenticated;

revoke all on function public.reklam_odul() from public, anon;
grant execute on function public.reklam_odul() to authenticated;

revoke all on function public.reklam_ssv_isle(jsonb) from public, anon, authenticated;
grant execute on function public.reklam_ssv_isle(jsonb) to service_role;

-- Gizli kurulum (çalıştırılmaz; değeri repoya yazmayın):
--   insert into oyun.uygulama_ayar(anahtar, deger, aciklama, herkese_acik)
--   values ('admob_ssv_gizli', to_jsonb('<en az 24 karakter rastgele>'::text),
--           'AdMob SSV edge fonksiyonu ile paylaşılan gizli', false)
--   on conflict (anahtar) do update
--     set deger = excluded.deger, herkese_acik = false, aciklama = excluded.aciklama, guncelleme = now();
-- Aynı metin Supabase Edge Function sırrı ADMOB_SSV_GIZLI olmalıdır.
