-- Bakanlara yazılı soru ve haftalık oyuncu anketi.
create table if not exists oyun.bakan_soru(
 id bigint generated always as identity primary key,
 soran uuid not null references oyun.profiller(id),
 bakanlik text not null,
 konu text not null check(length(konu) between 5 and 100),
 soru text not null check(length(soru) between 10 and 2000),
 zaman timestamptz not null default now(),
 yanit text, yanitlayan uuid references oyun.profiller(id), yanit_at timestamptz
);
create index if not exists bakan_soru_zaman on oyun.bakan_soru(zaman desc);
alter table oyun.bakan_soru enable row level security;
revoke all on oyun.bakan_soru from public,anon,authenticated;
create or replace function public.bakan_sorulari()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
 return jsonb_build_object('bakanliklar',coalesce((select jsonb_agg(jsonb_build_object('kod',kod,'ad',ad) order by ad) from oyun.bakanliklar),'[]'::jsonb),
 'sorular',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'soran',oyun.kad(s.soran),
 'bakanlik',coalesce(b.ad,s.bakanlik),'konu',s.konu,'soru',s.soru,'zaman',s.zaman,
 'yanit',s.yanit,'yanitlayan',oyun.kad(s.yanitlayan),'yanit_at',s.yanit_at,
 'cevaplayabilirim',s.yanit is null and exists(select 1 from oyun.makamlar m where m.user_id=auth.uid() and m.tur='bakan' and m.bakanlik=s.bakanlik and m.bit is null))
 order by s.id desc) from (select * from oyun.bakan_soru order by id desc limit 100) s left join oyun.bakanliklar b on b.kod=s.bakanlik),'[]'::jsonb),
 'vekilim',oyun.aktif_vekil(auth.uid()));
end $$;
create or replace function public.bakan_soru_sor(p_bakanlik text,p_konu text,p_soru text)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); bas text:=btrim(coalesce(p_konu,'')); msg text:=btrim(coalesce(p_soru,''));
begin
 if u is null or not oyun.aktif_vekil(u) then raise exception 'Yalnızca milletvekilleri soru sorabilir'; end if;
 if not exists(select 1 from oyun.bakanliklar where kod=p_bakanlik) then raise exception 'Geçersiz bakanlık'; end if;
 if length(bas) not between 5 and 100 or length(msg) not between 10 and 2000 then raise exception 'Konu 5-100, soru 10-2000 karakter olmalı'; end if;
 if (select count(*) from oyun.bakan_soru where soran=u and zaman>now()-interval '1 day')>=3 then raise exception '24 saatte en çok 3 soru sorabilirsin'; end if;
 insert into oyun.bakan_soru(soran,bakanlik,konu,soru) values(u,p_bakanlik,bas,msg);
 perform oyun.olay('meclis','Bir milletvekili hükümete yazılı soru yöneltti.',null,null,now());
 return public.bakan_sorulari();
end $$;
create or replace function public.bakan_soru_yanit(p_id bigint,p_yanit text)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); s oyun.bakan_soru%rowtype; msg text:=btrim(coalesce(p_yanit,''));
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if length(msg)<10 or length(msg)>3000 then raise exception 'Yanıt 10-3000 karakter olmalı'; end if;
 select * into s from oyun.bakan_soru where id=p_id for update;
 if not found or s.yanit is not null then raise exception 'Bu soru mevcut değil veya yanıtlanmış'; end if;
 if not exists(select 1 from oyun.makamlar where tur='bakan' and bakanlik=s.bakanlik and user_id=u and bit is null)
 then raise exception 'Bu bakanlığın yetkili bakanı değilsin'; end if;
 update oyun.bakan_soru set yanit=msg,yanitlayan=u,yanit_at=now() where id=s.id;
 perform oyun.bildir(s.soran,'Yazılı soru önergen bakan tarafından yanıtlandı.',now());
 return public.bakan_sorulari();
end $$;
revoke all on function public.bakan_sorulari(),public.bakan_soru_sor(text,text,text),
 public.bakan_soru_yanit(bigint,text) from public,anon;
grant execute on function public.bakan_sorulari(),public.bakan_soru_sor(text,text,text),
 public.bakan_soru_yanit(bigint,text) to authenticated;

-- Haftalık halk anketi: sadece kayıtlı oyuncuların oyu, bilimsel anket değildir.
create table if not exists oyun.haftalik_anket(hafta date primary key, olusturma timestamptz not null default now());
create table if not exists oyun.haftalik_anket_oy(
 hafta date not null references oyun.haftalik_anket(hafta),
 user_id uuid not null references oyun.profiller(id),
 parti_id bigint not null references oyun.partiler(id),
 zaman timestamptz not null default now(),
 primary key(hafta,user_id)
);
alter table oyun.haftalik_anket enable row level security;
alter table oyun.haftalik_anket_oy enable row level security;
revoke all on oyun.haftalik_anket,oyun.haftalik_anket_oy from public,anon,authenticated;
create or replace function public.anket_durum()
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); h date:=(date_trunc('week',now() at time zone 'Europe/Istanbul'))::date;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 insert into oyun.haftalik_anket(hafta) values(h) on conflict do nothing;
 return jsonb_build_object('hafta',h,'oyum',(select parti_id from oyun.haftalik_anket_oy where hafta=h and user_id=u),
 'toplam',(select count(*) from oyun.haftalik_anket_oy where hafta=h),
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'ad',p.ad,'kisa',p.kisa,'renk',p.renk,
 'oy',(select count(*) from oyun.haftalik_anket_oy o where o.hafta=h and o.parti_id=p.id))
 order by p.ad) from oyun.partiler p where not p.kapali),'[]'::jsonb));
end $$;
create or replace function public.anket_oyla(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare u uuid:=auth.uid(); h date:=(date_trunc('week',now() at time zone 'Europe/Istanbul'))::date;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if not exists(select 1 from oyun.partiler where id=p_parti and not kapali) then raise exception 'Parti bulunamadı'; end if;
 insert into oyun.haftalik_anket(hafta) values(h) on conflict do nothing;
 insert into oyun.haftalik_anket_oy(hafta,user_id,parti_id) values(h,u,p_parti)
 on conflict (hafta,user_id) do nothing;
 if not found then raise exception 'Bu haftaki anket oyunu zaten kullandın'; end if;
 return public.anket_durum();
end $$;
revoke all on function public.anket_durum(),public.anket_oyla(bigint) from public,anon;
grant execute on function public.anket_durum(),public.anket_oyla(bigint) to authenticated;
