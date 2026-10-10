-- 2026-10-10 Dernek üyelerine özel sohbet kanalları
-- Var olan mesajlar, okuma işaretleri ve oyuncu bilgileri korunur.
-- Dernek sohbetine yalnızca halen üye olan kullanıcı erişebilir.
create or replace function oyun.dernek_sohbet_adi(p_dernek bigint, p_uye uuid)
returns text language plpgsql stable set search_path = '' as $$
declare v_ad text;
begin
  if p_dernek is null or p_uye is null then
    raise exception 'Sohbet için dernek üyesi olmalısın.';
  end if;
  select d.ad into v_ad
    from oyun.dernekler d
    join oyun.dernek_uyeler u on u.dernek_id=d.id
    where d.id=p_dernek and not d.kapali and u.user_id=p_uye;
  if v_ad is null then
    raise exception 'Bu dernek sohbetine yalnızca derneğin aktif üyeleri katılabilir.';
  end if;
  return v_ad;
end $$;

create or replace function public.dernek_sohbetler()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', d.id, 'ad', d.ad, 'rol', u.rol,
      'uye', (select count(*) from oyun.dernek_uyeler du where du.dernek_id=d.id),
      'okunmamis', (
        select count(*) from (
          select 1 from oyun.mesajlar m
          where m.kanal='dernek:'||d.id::text
            and m.id > coalesce((select ko.son_id from oyun.kanal_okuma ko where ko.user_id=p.id and ko.kanal='dernek:'||d.id::text),0)
            and m.user_id<>p.id and not m.gizli and m.zaman<=t
            and m.zaman>t-interval '3 days'
            and not oyun.engelli(p.id,m.user_id)
          limit 100
        ) okunmamislar
      ),
      'son', (
        select jsonb_build_object('kad',coalesce(pr.kad,'(silinmiş)'),'metin',m.metin,'zaman',m.zaman)
        from oyun.mesajlar m left join oyun.profiller pr on pr.id=m.user_id
        where m.kanal='dernek:'||d.id::text and not m.gizli and m.zaman<=t
          and not oyun.engelli(p.id,m.user_id)
        order by m.id desc limit 1
      )
    ) order by d.ad,d.id)
    from oyun.dernek_uyeler u join oyun.dernekler d on d.id=u.dernek_id
    where u.user_id=p.id and not d.kapali
  ),'[]'::jsonb);
end $$;

create or replace function public.dernek_sohbet_oku(
  p_dernek bigint,
  p_once bigint default null,
  p_sonra bigint default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
  ad text; kanal text; liste jsonb; son bigint;
begin
  ad := oyun.dernek_sohbet_adi(p_dernek,p.id);
  kanal := 'dernek:'||p_dernek::text;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',x.id,'kad',coalesce(pr.kad,'(silinmiş)'),'metin',x.metin,'zaman',x.zaman,
      'parti',oyun.parti_json(pr.parti_id),'unvan',oyun.unvan(x.user_id),
      'benim',x.user_id=p.id
  ) order by x.id),'[]'::jsonb) into liste
  from (
    select * from oyun.mesajlar m
    where m.kanal=kanal and not m.gizli and m.zaman<=t
      and not oyun.engelli(p.id,m.user_id)
      and (p_sonra is null or m.id>p_sonra)
      and (p_once is null or m.id<p_once)
    order by case when p_sonra is null then -m.id else m.id end
    limit case when p_sonra is null then 40 else 100 end
  ) x left join oyun.profiller pr on pr.id=x.user_id;
  if p_once is null then
    select max(id) into son from oyun.mesajlar m
      where m.kanal=kanal and not m.gizli and m.zaman<=t;
    if son is not null then
      insert into oyun.kanal_okuma(user_id,kanal,son_id) values(p.id,kanal,son)
      on conflict(user_id,kanal)
      do update set son_id=greatest(oyun.kanal_okuma.son_id,excluded.son_id);
    end if;
  end if;
  return jsonb_build_object('kanal',kanal,'baslik',ad||' · Dernek sohbeti',
                            'mesajlar',liste,'yazabilir',true);
end $$;

create or replace function public.dernek_sohbet_yaz(p_dernek bigint,p_metin text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi();
  ad text; metin text;
begin
  ad := oyun.dernek_sohbet_adi(p_dernek,p.id);
  perform oyun.yazabilir_mi(p,t);
  metin := oyun.metin_temizle(p_metin,500);
  insert into oyun.mesajlar(kanal,user_id,metin,zaman)
    values('dernek:'||p_dernek::text,p.id,metin,t);
  update oyun.profiller set son_mesaj=t where id=p.id;
  return jsonb_build_object('tamam',true);
end $$;

-- Mesajlara yalnızca üyelik kontrolü bulunan RPC'ler üzerinden erişilir.
revoke all on function oyun.dernek_sohbet_adi(bigint,uuid) from public, anon, authenticated;
revoke all on function public.dernek_sohbetler() from public, anon;
revoke all on function public.dernek_sohbet_oku(bigint,bigint,bigint) from public, anon;
revoke all on function public.dernek_sohbet_yaz(bigint,text) from public, anon;
grant execute on function public.dernek_sohbetler() to authenticated;
grant execute on function public.dernek_sohbet_oku(bigint,bigint,bigint) to authenticated;
grant execute on function public.dernek_sohbet_yaz(bigint,text) to authenticated;

