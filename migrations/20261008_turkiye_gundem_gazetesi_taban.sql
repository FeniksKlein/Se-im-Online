-- Türkiye Gündem / oyun olaylarindan beslenen otomatik, ucretsiz haber gazetesi.
-- Oyuncu gazetelerinin sahibi, yazarlari, abonelikleri degismez.
create table if not exists oyun.ajans_haberleri(
 id bigint generated always as identity primary key,
 kaynak_anahtar text not null unique,
 kategori text not null check(kategori in ('siyaset','secim','adaylar','ittifak','ekonomi','meclis','yerel','gundem','bulten')),
 baslik text not null,
 ozet text not null,
 metin text not null,
 oncelik integer not null default 40 check(oncelik between 0 and 100),
 parti_id bigint references oyun.partiler(id) on delete set null,
 il_id smallint references oyun.iller(id) on delete set null,
 zaman timestamptz not null default now(),
 olusturma timestamptz not null default now()
);
create index if not exists ajans_haberleri_zaman_idx on oyun.ajans_haberleri (zaman desc,id desc);
create index if not exists ajans_haberleri_kategori_idx on oyun.ajans_haberleri (kategori,zaman desc);
alter table oyun.ajans_haberleri enable row level security;
revoke all on oyun.ajans_haberleri from public,anon,authenticated;

create or replace function oyun.ajans_yayinla(
 p_anahtar text,p_kategori text,p_baslik text,p_ozet text,p_metin text,
 p_oncelik integer default 50,p_parti bigint default null,p_il smallint default null,
 p_zaman timestamptz default null
) returns void language plpgsql set search_path='' as $f$
begin
 if p_anahtar is null or length(p_anahtar) not between 3 and 220 then return;end if;
 if p_kategori not in ('siyaset','secim','adaylar','ittifak','ekonomi','meclis','yerel','gundem','bulten')
 or p_baslik is null or btrim(p_baslik)='' then return;end if;
 insert into oyun.ajans_haberleri
 (kaynak_anahtar,kategori,baslik,ozet,metin,oncelik,parti_id,il_id,zaman)
 values(p_anahtar,p_kategori,left(btrim(p_baslik),170),
  left(btrim(coalesce(p_ozet,'')),360),left(btrim(coalesce(p_metin,'')),5000),
  greatest(0,least(100,coalesce(p_oncelik,50))),p_parti,p_il,
  coalesce(p_zaman,oyun.simdi()))
 on conflict(kaynak_anahtar) do nothing;
end $f$;
revoke all on function oyun.ajans_yayinla(text,text,text,text,text,integer,bigint,smallint,timestamptz) from public,anon,authenticated;

create or replace function public.ajans_haberler(
 p_limit integer default 40,p_kategori text default null,p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path='' as $f$
declare uid uuid:=auth.uid(); n int:=least(60,greatest(1,coalesce(p_limit,40)));
 o int:=least(500,greatest(0,coalesce(p_offset,0)));
begin
 if uid is null then raise exception 'Gazeteyi görmek için oturum açmalısın';end if;
 if p_kategori is not null and p_kategori not in
 ('siyaset','secim','adaylar','ittifak','ekonomi','meclis','yerel','gundem','bulten')
 then raise exception 'Geçersiz haber kategorisi';end if;
 return jsonb_build_object(
  'gazete','TÜRKİYE GÜNDEM','slogan','Oyundaki gerçek olayların bağımsız haber akışı',
  'otomatik',true,'ucretsiz',true,'yayin_tarihi',oyun.simdi(),
  'toplam',(select count(*) from oyun.ajans_haberleri
    where p_kategori is null or kategori=p_kategori),
  'manset',(select jsonb_build_object('id',id,'kategori',kategori,'baslik',baslik,
    'ozet',ozet,'metin',metin,'zaman',zaman,'oncelik',oncelik)
    from oyun.ajans_haberleri
    where zaman>=oyun.simdi()-interval '48 hours'
      and (p_kategori is null or kategori=p_kategori)
    order by oncelik desc,zaman desc,id desc limit 1),
  'haberler',coalesce((
   select jsonb_agg(jsonb_build_object('id',h.id,'kategori',h.kategori,
     'baslik',h.baslik,'ozet',h.ozet,'metin',h.metin,'zaman',h.zaman,
     'oncelik',h.oncelik,'il',i.ad,
     'parti',pa.kisa) order by h.zaman desc,h.id desc)
   from (select * from oyun.ajans_haberleri
         where p_kategori is null or kategori=p_kategori
         order by zaman desc,id desc limit n offset o) h
   left join oyun.partiler pa on pa.id=h.parti_id
   left join oyun.iller i on i.id=h.il_id
  ),'[]'::jsonb));
end $f$;
revoke all on function public.ajans_haberler(integer,text,integer) from public,anon;
grant execute on function public.ajans_haberler(integer,text,integer) to authenticated;
