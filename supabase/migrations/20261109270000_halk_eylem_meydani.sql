-- 2026-11-09 · HALK HAREKETLERİ 4.0 — EYLEM MEYDANI (sunucu eki)
-- Canlı kayıt adı: halk_eylem_meydani · Sürüm: 20261109270000
--
-- Yeni ekranın ihtiyacı olan üç şey:
--  1) Eylem akışı: eylemin bütün kamuya açık gelişmeleri tek zaman çizgisinde (duyurular, katılan/ayrılan,
--     pankartlar, nöbet ve çağrılar, kaynak aktarımları). Gizli işler (muhbir, kırmızı hat, sızma) girmez.
--  2) Canlı sinyal: her eylem duyurusu 'halk:<id>' (herkese açık) ve 'eylem:<id>' (yalnız katılımcı)
--     anahtarlarını tetikler; ekranlar yoklama yerine anında tazelenir.
--  3) Sohbet 2.0: yalnız eylemin içindekiler. Rozetler (organizatör, gözaltında, ayrıldı), ✊ tepkisi,
--     organizatörün sabitlediği mesaj, yazma durumu ve nedeni. Yazma eski sokak_sohbet_yaz ile sürer
--     (süzgeç, hız sınırı, sanal gözaltı kontrolü aynen).
-- Ek: boykot için şirket arama (ad ya da numara).
--
-- Oyun hiç sıfırlanmaz: yalnız "if not exists" ve "create or replace"; mevcut kayıt silinmez.

create index if not exists olaylar_il_zaman on oyun.olaylar(il_id, zaman desc);

-- ── canlı sinyal: halk:<id> herkese açık eylem anahtarı ──
do $$ begin
 if to_regclass('public.canli_sinyal') is not null then
  alter table public.canli_sinyal drop constraint if exists canli_sinyal_anahtar_bicim;
  alter table public.canli_sinyal add constraint canli_sinyal_anahtar_bicim
   check (anahtar ~ '^(sohbet|kutu|miting|secim|yayin|muzayede|kursu|eylem|halk):[A-Za-z0-9_.:-]{1,72}$');
 end if;
end $$;

create or replace function oyun.canli_sinyal(p_anahtar text) returns void
language plpgsql security definer set search_path='' as $$
declare k text := left(btrim(coalesce(p_anahtar, '')), 80);
begin
 if to_regclass('public.canli_sinyal') is null then return; end if;
 if k !~ '^(sohbet|kutu|miting|secim|yayin|muzayede|kursu|eylem|halk):[A-Za-z0-9_.:-]{1,72}$' then return; end if;
 if current_setting('oyun.csig_' || md5(k), true) = '1' then return; end if;
 perform set_config('oyun.csig_' || md5(k), '1', true);
 insert into public.canli_sinyal(anahtar, rev, zaman) values (k, 1, now())
  on conflict (anahtar) do update set rev = public.canli_sinyal.rev + 1, zaman = now();
end $$;

create or replace function oyun.canli_sinyal_gorur(p_anahtar text) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare p oyun.profiller; kod text; eid bigint;
begin
 if auth.uid() is null or p_anahtar is null then return false; end if;
 if p_anahtar like 'kutu:%' then return p_anahtar = 'kutu:' || (select auth.uid())::text; end if;
 if p_anahtar ~ '^(miting|secim|yayin|muzayede|kursu|halk):' then return true; end if;
 if p_anahtar like 'eylem:%' then
  begin eid := substr(p_anahtar, 7)::bigint; exception when others then return false; end;
  return oyun.sokak_sohbet_uye(eid);
 end if;
 if p_anahtar like 'sohbet:%' then
  select * into p from oyun.profiller where id = (select auth.uid());
  if p.id is null then return false; end if;
  kod := substr(p_anahtar, 8);
  return exists (
   select 1 from unnest(array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine']::text[]) c
   where oyun.kanal_coz(p, c) = kod);
 end if;
 return false;
end $$;

-- Her eylem duyurusu canlı sinyal üretir (metin ve alıcılar değişmedi).
create or replace function oyun.sokak_duyur(p_id bigint, p_metin text) returns void
language plpgsql set search_path='' as $$
declare x oyun.sokak_eylem;
begin
 select * into x from oyun.sokak_eylem where id=p_id;
 perform oyun.olay('siyaset',p_metin,x.il_id,x.parti_id);
 insert into oyun.bildirimler(user_id,zaman,metin) select distinct p.id,oyun.simdi(),p_metin from oyun.profiller p where not p.yasakli and (p.id=x.baslatan or exists(select 1 from oyun.sokak_eylem_destek d where d.eylem_id=x.id and d.temsilci=p.id) or exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null and m.tur in ('cb','bakan','cb_yardimcisi')));
 if x.id is not null then
  perform oyun.canli_sinyal('halk:'||x.id::text);
  perform oyun.canli_sinyal('eylem:'||x.id::text);
 end if;
end $$;

-- ── eylem akışı ──
create or replace function oyun.sokak_akis_tur(m text) returns text
language sql immutable set search_path='' as $$
 select case
  when m ~* 'kırmızı seviye|KIRMIZI' then 'kritik'
  when m ~ '^\[(muhalefet|hukumet|hukuk|basin)\]' then 'aciklama'
  when m ~* '(mahkeme|avukat|hâkim|hakim|baro|tazminat|itiraz)' then 'hukuk'
  when m ~* '(TL [a-zçğıöşü]* ?desteği|fon |kaynak aktar)' then 'para'
  when m ~* '(hükümet|Hükümet|cumhurbaşkanı|Cumhurbaşkanı|içişleri|İçişleri|vali|Vali|polis|yasak|gözaltı|OHAL|ohal|operasyon|kuşatma|tahliye|görev başında|brifing|kısıt|yavaşlatma|jest|sesleniş|heyet|elebaşı|propaganda)' then 'devlet'
  when m ~* '(barikat|grev|işgal|meşale|açlık|nöbet|pankart|duran|zincir|oturma|yol kapat|kalkan|boykot|meydan)' then 'meydan'
  when m ~* '(başlattı|sona erdi|yatıştı|süresi doldu|bitti)' then 'durum'
  else 'genel' end
$$;

create or replace function public.sokak_eylem_akis(p_eylem bigint, p_sinir integer default 80) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); bas timestamptz; son timestamptz;
 lim integer:=least(150,greatest(10,coalesce(p_sinir,80))); desen text;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if x.id is null then raise exception 'Eylem bulunamadı'; end if;
 bas:=x.baslangic-interval '2 minutes';
 son:=coalesce(x.kapandi, case when x.bitis<t then x.bitis end, t)+interval '2 minutes';
 desen:='#'||x.id::text||'([^0-9]|$)';
 return coalesce((select jsonb_agg(jsonb_build_object('zaman',z.zaman,'tur',z.tur,'metin',z.metin,'kim',z.kim) order by z.zaman desc) from (
   select * from (
    select o.zaman, oyun.sokak_akis_tur(o.metin) tur, o.metin, null::text kim
      from oyun.olaylar o
     where o.il_id=x.il_id and o.zaman between bas and son and o.tur='siyaset'
       and (o.metin ~ desen or o.metin ~ '^\[(muhalefet|hukumet|hukuk|basin)\]'
            or o.metin ~* '(eylem|meydan|protesto|gözaltı|OHAL|kuşatma|tahliye|grev|işgal)')
    union all
    select d.zaman, case when d.taraf='iktidar' then 'karsi' else 'katil' end,
           oyun.kad(d.temsilci)||case when d.taraf='iktidar' then ' karşı tarafta yer aldı' else ' meydana katıldı' end, oyun.kad(d.temsilci)
      from oyun.sokak_eylem_destek d
     where d.eylem_id=x.id and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.zaman is not null
    union all
    select a.zaman, 'ayril',
           oyun.kad(a.user_id)||case a.rol when 'gorevli' then ' görevden ayrıldı' when 'karsi' then ' karşı taraftan ayrıldı' else ' meydandan ayrıldı' end, oyun.kad(a.user_id)
      from oyun.sokak_ayrilma a where a.eylem_id=x.id
    union all
    select k.zaman, 'pankart', oyun.kad(k.user_id)||' pankart açtı: “'||k.metin||'”', oyun.kad(k.user_id)
      from oyun.sokak_taktik k where k.eylem_id=x.id and k.tur='pankart' and k.metin is not null
    union all
    select k.zaman, 'meydan', oyun.kad(k.user_id)||case k.tur when 'nobet' then ' nöbete başladı' when 'cagri' then ' çevresini meydana çağırdı' else ' greve katıldı' end, oyun.kad(k.user_id)
      from oyun.sokak_taktik k where k.eylem_id=x.id and k.tur in ('nobet','cagri','grev')
    union all
    select s.zaman, 'para', coalesce(oyun.kad(s.user_id),'Bir destekçi')||' eyleme kaynak aktardı: '||case s.kalem when 'ses' then 'ses sistemi' when 'ulasim' then 'ulaşım' when 'yemek' then 'yemek' when 'pankart' then 'pankart' else s.kalem end||' · '||to_char(s.tutar,'FM999G999G999')||' TL', oyun.kad(s.user_id)
      from oyun.sokak_kaynak s where s.eylem_id=x.id
   ) h order by h.zaman desc limit lim) z), '[]'::jsonb);
end $$;

-- ── sohbet 2.0 ──
create table if not exists oyun.sokak_sohbet_sabit(
 eylem_id bigint primary key references oyun.sokak_eylem,
 mesaj_id bigint not null references public.sokak_eylem_sohbet,
 sabitleyen uuid not null references oyun.profiller,
 zaman timestamptz not null
);
create table if not exists oyun.sokak_sohbet_tepki(
 mesaj_id bigint not null references public.sokak_eylem_sohbet,
 user_id uuid not null references oyun.profiller,
 zaman timestamptz not null,
 primary key(mesaj_id,user_id)
);
alter table oyun.sokak_sohbet_sabit enable row level security;
alter table oyun.sokak_sohbet_tepki enable row level security;
revoke all on oyun.sokak_sohbet_sabit from public,anon,authenticated;
revoke all on oyun.sokak_sohbet_tepki from public,anon,authenticated;

create or replace function public.sokak_sohbet_akis(p_eylem bigint) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; t timestamptz:=oyun.simdi(); gz boolean; sus boolean; ses boolean; neden text;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if not oyun.sokak_katilimci(p_eylem,u) then raise exception 'Bu sohbet yalnız eylemin içindeki oyunculara açık'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 gz:=exists(select 1 from oyun.sokak_gozalti g where g.eylem_id=p_eylem and g.hedef=u and g.durum='aktif' and g.bitis>t);
 sus:=exists(select 1 from oyun.profiller p where p.id=u and p.susturma_bitis is not null and p.susturma_bitis>t);
 ses:=oyun.sokak_sesi_kapali(u,p_eylem);
 neden:=case when x.durum<>'aktif' or x.bitis<=t then 'Eylem sona erdi; sohbet yalnız okunur'
             when gz then 'Gözaltındayken eylem sohbetine yazamazsın'
             when ses then 'Sanal gözaltındasın: bu eylemde sohbet ve oy kapalı'
             when sus then 'Hesabının mesaj yasağı sürüyor' end;
 return jsonb_build_object(
  'mesajlar',coalesce((select jsonb_agg(jsonb_build_object(
     'id',s.id,'ad',oyun.kad(s.user_id),'metin',s.metin,'zaman',s.zaman,'ben',s.user_id=u,
     'rol',case when s.user_id=x.baslatan then 'organizator'
                when exists(select 1 from oyun.sokak_gozalti g where g.eylem_id=p_eylem and g.hedef=s.user_id and g.durum='aktif' and g.bitis>t) then 'gozalti'
                when not oyun.sokak_katilimci(p_eylem,s.user_id) then 'ayrildi' end,
     'tepki',(select count(*) from oyun.sokak_sohbet_tepki k where k.mesaj_id=s.id),
     'tepkim',exists(select 1 from oyun.sokak_sohbet_tepki k where k.mesaj_id=s.id and k.user_id=u)) order by s.id)
    from (select * from public.sokak_eylem_sohbet where eylem_id=p_eylem order by id desc limit 60) s),'[]'::jsonb),
  'sabit',(select jsonb_build_object('id',s.id,'ad',oyun.kad(s.user_id),'metin',s.metin,'zaman',s.zaman,'sabitleyen',oyun.kad(b.sabitleyen))
    from oyun.sokak_sohbet_sabit b join public.sokak_eylem_sohbet s on s.id=b.mesaj_id where b.eylem_id=p_eylem),
  'uye',(select count(*) from oyun.sokak_eylem_destek d where d.eylem_id=p_eylem and d.destekci_tur='oyuncu' and d.destek_turu='katilim' and d.taraf='muhalefet'),
  'yazabilir',neden is null,'neden',neden,
  'sabitleyebilir',u=x.baslatan,
  'son_id',(select max(id) from public.sokak_eylem_sohbet where eylem_id=p_eylem));
end $$;

create or replace function public.sokak_sohbet_sabitle(p_eylem bigint, p_mesaj bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into x from oyun.sokak_eylem where id=p_eylem;
 if x.id is null or x.baslatan is distinct from u then raise exception 'Mesajı yalnız eylemin organizatörü sabitler'; end if;
 if not oyun.sokak_katilimci(p_eylem,u) then raise exception 'Sabitlemek için meydanda olmalısın'; end if;
 if p_mesaj is null then
  delete from oyun.sokak_sohbet_sabit where eylem_id=p_eylem;
 else
  if not exists(select 1 from public.sokak_eylem_sohbet where id=p_mesaj and eylem_id=p_eylem) then raise exception 'Mesaj bu eylemin sohbetinde değil'; end if;
  insert into oyun.sokak_sohbet_sabit(eylem_id,mesaj_id,sabitleyen,zaman) values(p_eylem,p_mesaj,u,oyun.simdi())
   on conflict(eylem_id) do update set mesaj_id=excluded.mesaj_id,sabitleyen=excluded.sabitleyen,zaman=excluded.zaman;
 end if;
 perform oyun.canli_sinyal('eylem:'||p_eylem::text);
 return jsonb_build_object('tamam',true,'sabit',p_mesaj);
end $$;

create or replace function public.sokak_sohbet_tepki(p_mesaj bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); e bigint; n integer;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select eylem_id into e from public.sokak_eylem_sohbet where id=p_mesaj;
 if e is null then raise exception 'Mesaj bulunamadı'; end if;
 if not oyun.sokak_katilimci(e,u) then raise exception 'Bu sohbet yalnız eylemin içindeki oyunculara açık'; end if;
 if oyun.sokak_sesi_kapali(u,e) then raise exception 'Sanal gözaltındayken tepki veremezsin'; end if;
 delete from oyun.sokak_sohbet_tepki where mesaj_id=p_mesaj and user_id=u;
 get diagnostics n=row_count;
 if n=0 then insert into oyun.sokak_sohbet_tepki(mesaj_id,user_id,zaman) values(p_mesaj,u,oyun.simdi()); end if;
 perform oyun.canli_sinyal('eylem:'||e::text);
 return jsonb_build_object('tamam',true,'tepkim',n=0,'tepki',(select count(*) from oyun.sokak_sohbet_tepki where mesaj_id=p_mesaj));
end $$;

-- ── boykot için şirket arama ──
create or replace function public.sokak_sirket_ara(p_q text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); q text:=btrim(coalesce(p_q,''));
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if char_length(q)<2 then return '[]'::jsonb; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'sektor',s.sektor) order by s.ad)
  from (select id,ad,sektor from oyun.sirketler where coalesce(aktif,true)
         and (ad ilike '%'||replace(replace(q,'%',''),'_','')||'%' or id::text=q) order by ad limit 12) s),'[]'::jsonb);
end $$;

revoke all on function oyun.sokak_akis_tur(text) from public,anon,authenticated;
revoke all on function public.sokak_eylem_akis(bigint,integer),public.sokak_sohbet_akis(bigint),public.sokak_sohbet_sabitle(bigint,bigint),
 public.sokak_sohbet_tepki(bigint),public.sokak_sirket_ara(text) from public,anon;
grant execute on function public.sokak_eylem_akis(bigint,integer),public.sokak_sohbet_akis(bigint),public.sokak_sohbet_sabitle(bigint,bigint),
 public.sokak_sohbet_tepki(bigint),public.sokak_sirket_ara(text) to authenticated;
