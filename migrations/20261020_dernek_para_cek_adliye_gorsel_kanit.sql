-- 20.10.2026 · Dernek serbest kasasından başkanın para çekmesi ve adliye görsel kanıtları.
-- Mevcut kasa, oyuncu, dava ve bağış kayıtlarına müdahale edilmez.

create or replace function public.dernek_para_cek(p_dernek bigint, p_tutar numeric, p_aciklama text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim();
  d oyun.dernekler;
  t timestamptz := oyun.simdi();
  tutar numeric := round(p_tutar);
  aciklama text := btrim(coalesce(p_aciklama, ''));
  serbest numeric;
begin
  if p.id is null then raise exception 'Oturum açmanız gerekiyor.'; end if;
  if p_tutar is null or p_tutar <> round(p_tutar) or p_tutar < 1 or p_tutar > 1000000000 then
    raise exception 'Çekilecek tutar 1 ile 1.000.000.000 TL arasında tam sayı olmalı.';
  end if;
  if char_length(aciklama) < 5 or char_length(aciklama) > 200 then
    raise exception 'Para çekme gerekçesi 5-200 karakter olmalı.';
  end if;
  if oyun.uyari(p,t) is not null then raise exception 'Hesabınız bu işlemi yapmaya uygun değil.'; end if;
  select * into d from oyun.dernekler where id = p_dernek and not kapali for update;
  if d.id is null then raise exception 'Aktif dernek bulunamadı.'; end if;
  if d.baskan is distinct from p.id or not exists (
    select 1 from oyun.dernek_uyeler where dernek_id=d.id and user_id=p.id and rol='baskan'
  ) then raise exception 'Dernek kasasından yalnız dernek başkanı para çekebilir.'; end if;
  serbest := oyun.dernek_serbest_kasa(d.id);
  if tutar > serbest then
    raise exception 'Serbest kasada % TL var. Yardım kampanyalarına ayrılan bağışlar çekilemez.',oyun.tl(serbest);
  end if;
  update oyun.dernekler set kasa = kasa - tutar where id = d.id;
  perform oyun.para_islem(p.id, tutar, 'dernek', format('%s kasasından para çekme: %s',d.ad,aciklama),t);
  insert into oyun.dernek_hareket(dernek_id,zaman,tutar,tur,aciklama,user_id)
  values (d.id,t,-tutar,'para_cekme',format('%s kasadan çekti: %s',p.kad,aciklama),p.id);
  perform oyun.olay('dernek',format('%s derneği başkanı %s dernek kasasından %s TL çekti. Gerekçe: %s',d.ad,p.kad,oyun.tl(tutar),aciklama),d.merkez_il,null,t);
  return jsonb_build_object('tamam',true,'cekilen',tutar,'kasa',d.kasa-tutar,'serbest',serbest-tutar);
end $$;
revoke all on function public.dernek_para_cek(bigint,numeric,text) from public,anon;
grant execute on function public.dernek_para_cek(bigint,numeric,text) to authenticated;

-- Adliye: özel dosya deposu, sadece kayıtlı oyunculara görüntüleme yetkisi.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('adliye-kanitlar','adliye-kanitlar',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create table if not exists oyun.adliye_kanit (
  id bigint generated always as identity primary key,
  dava_id bigint not null references oyun.adliye_davalar(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  dosya_yolu text not null unique,
  aciklama text not null default '',
  zaman timestamptz not null default now()
);
create index if not exists adliye_kanit_dava_idx on oyun.adliye_kanit(dava_id,zaman desc);
alter table oyun.adliye_kanit enable row level security;
revoke all on oyun.adliye_kanit from anon,authenticated;

create or replace function public.adliye_kanit_ekleyebilir(p_dava bigint)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from oyun.adliye_davalar d where d.id=p_dava and d.durum='acik' and (
      d.davaci=auth.uid() or d.davali=auth.uid()
      or exists (select 1 from oyun.mahkeme_uye m where m.user_id=auth.uid())
      or exists (select 1 from oyun.partiler pa where pa.id in (d.davaci_parti,d.davali_parti)
        and (pa.gb=auth.uid() or exists (
          select 1 from oyun.parti_sozcu s where s.parti_id=pa.id and s.user_id=auth.uid()
        )))
      or exists (select 1 from oyun.adliye_temsil izin
        join oyun.profiller davali on davali.id=d.davali
        join oyun.parti_sozcu sozcu on sozcu.parti_id=davali.parti_id and sozcu.user_id=auth.uid()
        where izin.dava_id=d.id and izin.yetki_veren=d.davali and izin.aktif)
    )
  )
$$;

create or replace function public.adliye_kanit_gorulebilir(p_yol text)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from oyun.adliye_kanit k where k.dosya_yolu=p_yol
  )
$$;

drop policy if exists adliye_kanit_ekle on storage.objects;
create policy adliye_kanit_ekle on storage.objects for insert to authenticated
with check (
  bucket_id='adliye-kanitlar'
  and name ~ '^[0-9]+/[0-9a-f-]{36}/[0-9a-f-]{36}\.(png|jpg|webp)$'
  and split_part(name,'/',2)=auth.uid()::text
  and public.adliye_kanit_ekleyebilir(split_part(name,'/',1)::bigint)
);
drop policy if exists adliye_kanit_gor on storage.objects;
create policy adliye_kanit_gor on storage.objects for select to authenticated
using (bucket_id='adliye-kanitlar' and
  (public.adliye_kanit_gorulebilir(name) or split_part(name,'/',2)=auth.uid()::text));
drop policy if exists adliye_kanit_tamamlanmayan_sil on storage.objects;
create policy adliye_kanit_tamamlanmayan_sil on storage.objects for delete to authenticated
using (bucket_id='adliye-kanitlar' and split_part(name,'/',2)=auth.uid()::text
  and not public.adliye_kanit_gorulebilir(name));

create or replace function public.adliye_kanit_kaydet(p_dava bigint,p_yol text,p_aciklama text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid();
  kayit bigint;
  aciklama text := btrim(coalesce(p_aciklama,''));
begin
  if not public.adliye_kanit_ekleyebilir(p_dava) then raise exception 'Açık davada kanıt ekleme yetkiniz yok.'; end if;
  if char_length(aciklama)>300 then raise exception 'Kanıt açıklaması en fazla 300 karakter olabilir.'; end if;
  if p_yol !~ '^[0-9]+/[0-9a-f-]{36}/[0-9a-f-]{36}\.(png|jpg|webp)$'
     or split_part(p_yol,'/',1)<>p_dava::text or split_part(p_yol,'/',2)<>u::text then
    raise exception 'Dosya yolu geçersiz.';
  end if;
  if not exists (select 1 from storage.objects where bucket_id='adliye-kanitlar' and name=p_yol)
  then raise exception 'Ekran resmi henüz yüklenmemiş.'; end if;
  if (select count(*) from oyun.adliye_kanit where dava_id=p_dava)>=20 then
    raise exception 'Bu davanın 20 dosyalık kanıt sınırına ulaşıldı.';
  end if;
  if (select count(*) from oyun.adliye_kanit where dava_id=p_dava and user_id=u)>=5 then
    raise exception 'Bu davaya en fazla 5 ekran resmi ekleyebilirsiniz.';
  end if;
  insert into oyun.adliye_kanit(dava_id,user_id,dosya_yolu,aciklama)
  values(p_dava,u,p_yol,aciklama) returning id into kayit;
  return jsonb_build_object('id',kayit,'tamam',true);
end $$;

create or replace function public.adliye_kanit_listele(p_dava bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Oturum açmalısınız.'; end if;
  if not exists(select 1 from oyun.adliye_davalar where id=p_dava) then raise exception 'Dava bulunamadı.'; end if;
  return jsonb_build_object(
    'ekleyebilirim',public.adliye_kanit_ekleyebilir(p_dava),
    'kanitlar',coalesce((select jsonb_agg(jsonb_build_object(
      'id',k.id,'yol',k.dosya_yolu,'aciklama',k.aciklama,'yukleyen',oyun.kad(k.user_id),'zaman',k.zaman
    ) order by k.zaman,k.id) from oyun.adliye_kanit k where k.dava_id=p_dava),'[]'::jsonb)
  );
end $$;

revoke all on function public.adliye_kanit_ekleyebilir(bigint) from public,anon;
revoke all on function public.adliye_kanit_gorulebilir(text) from public,anon;
revoke all on function public.adliye_kanit_kaydet(bigint,text,text) from public,anon;
revoke all on function public.adliye_kanit_listele(bigint) from public,anon;
grant execute on function public.adliye_kanit_ekleyebilir(bigint) to authenticated;
grant execute on function public.adliye_kanit_gorulebilir(text) to authenticated;
grant execute on function public.adliye_kanit_kaydet(bigint,text,text) to authenticated;
grant execute on function public.adliye_kanit_listele(bigint) to authenticated;
