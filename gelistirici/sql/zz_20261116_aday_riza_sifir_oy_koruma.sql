-- Parti CB adayi: aday muvafakati; kurultay oz adaylik; sifir oyla secim kazanilamaz.
create table if not exists oyun.cb_aday_teklifleri (
 donem text not null,parti_id bigint not null references oyun.partiler(id),
 aday uuid not null references oyun.profiller(id),teklif_eden uuid not null references oyun.profiller(id),
 durum text not null default 'bekliyor' check(durum in('bekliyor','kabul','ret')),
 teklif_at timestamptz not null default now(),yanit_at timestamptz,
 primary key(donem,parti_id)
);
revoke all on oyun.cb_aday_teklifleri from public,anon,authenticated;

create or replace function public.cb_aday_tekliflerim() returns jsonb language sql stable security definer set search_path to '' as $f$
 select coalesce(jsonb_agg(jsonb_build_object('donem',t.donem,'parti_id',t.parti_id,'parti',(select kisa from oyun.partiler where id=t.parti_id),'durum',t.durum,'teklif_at',t.teklif_at) order by t.teklif_at desc),'[]'::jsonb)
 from oyun.cb_aday_teklifleri t where t.aday=auth.uid() and t.durum='bekliyor';
$f$;
revoke all on function public.cb_aday_tekliflerim() from public,anon;
grant execute on function public.cb_aday_tekliflerim() to authenticated;

create or replace function public.cb_aday_teklif_cevap(p_donem text,p_parti bigint,p_kabul boolean) returns jsonb
 language plpgsql security definer set search_path to '' as $f$
declare u uuid:=auth.uid(); x oyun.cb_aday_teklifleri; s oyun.secimler; pa oyun.partiler; p oyun.profiller;
begin
 if u is null then raise exception 'Giris gerekli.';end if;
 select * into x from oyun.cb_aday_teklifleri where donem=p_donem and parti_id=p_parti for update;
 if x.durum is distinct from 'bekliyor' or x.aday is distinct from u then raise exception 'Bekleyen kendi teklifin bulunamadi.';end if;
 select * into pa from oyun.partiler where id=p_parti;
 select * into p from oyun.profiller where id=u;
 select * into s from oyun.secimler where donem=p_donem and tur='cb' and durum='bekliyor' and oyun.simdi()<basvuru_bit;
 if s.id is null or pa.gb is distinct from x.teklif_eden or pa.kapali or p.parti_id is distinct from p_parti then
   raise exception 'Adaylik teklifi artik gecerli degil.';end if;
 if p_kabul is not true then
  update oyun.cb_aday_teklifleri set durum='ret',yanit_at=oyun.simdi() where donem=p_donem and parti_id=p_parti;
  perform oyun.bildir(pa.gb,'CB adaylik teklifin reddedildi: '||oyun.kad(u));
  return jsonb_build_object('tamam',true,'durum','ret');
 end if;
 if oyun.uyari(p,oyun.simdi()) is not null then raise exception 'Adaylik engeli: %',oyun.uyari(p,oyun.simdi());end if;
 update oyun.cb_aday_teklifleri set durum='kabul',yanit_at=oyun.simdi() where donem=p_donem and parti_id=p_parti;
 insert into oyun.cb_kararlar(donem,parti_id,yontem,aday,zaman) values(p_donem,p_parti,'baskasi',u,oyun.simdi())
 on conflict(donem,parti_id) do update set yontem='baskasi',aday=u,destek_parti=null,zaman=excluded.zaman;
 delete from oyun.adaylar where secim_id=s.id and parti_id=p_parti;
 insert into oyun.adaylar(secim_id,user_id,parti_id,basvuru_at) values(s.id,u,p_parti,oyun.simdi());
 perform oyun.bildir(pa.gb,format('%s CB adayligi teklifini kabul etti.',oyun.kad(u)));
 return jsonb_build_object('tamam',true,'durum','kabul','aday',oyun.kad(u));
end $f$;
revoke all on function public.cb_aday_teklif_cevap(text,bigint,boolean) from public,anon;
grant execute on function public.cb_aday_teklif_cevap(text,bigint,boolean) to authenticated;

create or replace function oyun.aday_muvafakat_koruma() returns trigger language plpgsql set search_path to '' as $f$
declare s oyun.secimler;
begin
 select * into s from oyun.secimler where id=new.secim_id;
 if s.tur='kurultay' and auth.uid() is distinct from new.user_id then
   raise exception 'Genel baskan adayi oyuncunun kendi basvurusuyla riza vermesi gerekir.';
 end if;
 if s.tur='cb' and new.parti_id is not null and auth.uid() is distinct from new.user_id
  and not exists(select 1 from oyun.cb_aday_teklifleri t where t.donem=s.donem and t.parti_id=new.parti_id and t.aday=new.user_id and t.durum='kabul')
  and not exists(select 1 from oyun.adaylar a join oyun.secimler sn on sn.id=a.secim_id where a.user_id=new.user_id and a.parti_id=new.parti_id and sn.donem=s.donem and sn.tur='cb_on')
 then raise exception 'Oyuncunun onayi veya kendi on secim adayligi olmadan CB adayligi kesinlestirilemez.'; end if;
 return new;
end $f$;
drop trigger if exists aday_muvafakat_koruma_tg on oyun.adaylar;
create trigger aday_muvafakat_koruma_tg before insert on oyun.adaylar for each row execute function oyun.aday_muvafakat_koruma();

CREATE OR REPLACE FUNCTION public.cb_aday_belirle(p_yontem text, p_kad text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  s oyun.secimler;
  pa oyun.partiler;
  hedef oyun.profiller;
begin
  select * into pa from oyun.partiler where id = p.parti_id;
  if pa.gb is distinct from p.id then
    raise exception 'Bu kararı yalnızca genel başkan verebilir.';
  end if;

  select * into s
  from oyun.secimler
  where tur = 'cb'
    and t >= basvuru_bas
    and t < basvuru_bit
  order by ara desc, basvuru_bit
  limit 1;

  if s.id is null then
    raise exception 'Cumhurbaşkanı adayı belirleme dönemi şu anda açık değil.';
  end if;

  if p_yontem not in ('kendisi','baskasi','onsecim') then
    raise exception 'Geçersiz yöntem.';
  end if;

  if p_yontem = 'kendisi' then
    hedef := p;
  elsif p_yontem = 'baskasi' then
    select * into hedef
    from oyun.profiller
    where lower(kad) = lower(btrim(coalesce(p_kad,'')));

    if hedef.id is null or hedef.parti_id is distinct from pa.id then
      raise exception 'Aday partinin üyesi olmalı.';
    end if;
  end if;

  if hedef.id is not null and oyun.uyari(hedef,t) is not null then
    raise exception 'Aday için: %', oyun.uyari(hedef,t);
  end if;

  if p_yontem='baskasi' and hedef.id is distinct from p.id then
    insert into oyun.cb_aday_teklifleri(donem,parti_id,aday,teklif_eden,durum,teklif_at,yanit_at)
    values(s.donem,pa.id,hedef.id,p.id,'bekliyor',t,null)
    on conflict(donem,parti_id) do update set aday=excluded.aday,teklif_eden=excluded.teklif_eden,durum='bekliyor',teklif_at=t,yanit_at=null;
    perform oyun.bildir(hedef.id,format('%s seni Cumhurbaşkanı adayı gösterme teklifi gönderdi. Kabul etmedikçe adaylık kesinleşmez.',pa.kisa),t);
    return jsonb_build_object('tamam',true,'onay_bekliyor',true,'donem',s.donem,'aday',hedef.kad);
  end if;

  insert into oyun.cb_kararlar(
    donem, parti_id, yontem, aday, zaman
  )
  values (
    s.donem, pa.id, p_yontem, hedef.id, t
  )
  on conflict(donem,parti_id) do update
    set yontem = excluded.yontem,
        aday = excluded.aday,
        destek_parti = null,
        zaman = excluded.zaman;

  delete from oyun.adaylar
  where secim_id = s.id and parti_id = pa.id;

  if hedef.id is not null then
    insert into oyun.adaylar(
      secim_id,user_id,parti_id,basvuru_at
    )
    values (
      s.id,hedef.id,pa.id,t
    );
  end if;

  return public.durum();
end $function$


CREATE OR REPLACE FUNCTION oyun._sonuc_cok_alanli(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
declare r record; liste jsonb := '[]'::jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  for r in
    select distinct on (case when s.tur = 'bel' then il_id::bigint else parti_id end) *
    from oyun.adaylar where secim_id = s.id and coalesce(oy,0) > 0
    order by (case when s.tur = 'bel' then il_id::bigint else parti_id end), oy desc, basvuru_at, id
  loop
    insert into oyun.kazananlar(secim_id, user_id, il_id, parti_id) values (s.id, r.user_id, r.il_id, r.parti_id)
    on conflict do nothing;
    liste := liste || oyun.aday_json(r.id);
  end loop;
  if s.tur = 'bel' then
    perform oyun.olay('secim', format('Belediye seçimleri sonuçlandı: %s ilde başkan seçildi.', jsonb_array_length(liste)), null, null, s.sonuc_at);
  else
    perform oyun.olay('secim', format('Kurultaylar sonuçlandı: %s partide genel başkan seçildi.', jsonb_array_length(liste)), null, null, s.sonuc_at);
  end if;
  return jsonb_build_object('katilim', (select count(*) from oyun.oylar where secim_id = s.id),
                            'kazananlar', liste,
                            'adaylar', coalesce((select jsonb_agg(oyun.aday_json(a.id) order by a.il_id, a.parti_id, a.oy desc) from oyun.adaylar a where a.secim_id = s.id), '[]'::jsonb));
end $function$


CREATE OR REPLACE FUNCTION oyun._sonuc_cb(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  toplam bigint;
  n int;
  birinci record;
  ikinci record;
  t2 oyun.secimler;
  gun date := (s.oy_bas at time zone 'Europe/Istanbul')::date;
  adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);

  select count(*) into toplam
  from oyun.oylar
  where secim_id = s.id;

  select count(*) into n
  from oyun.adaylar
  where secim_id = s.id;

  select coalesce(
    jsonb_agg(
      oyun.aday_json(a.id)
      order by a.oy desc, a.basvuru_at
    ),
    '[]'::jsonb
  )
  into adaylar_j
  from oyun.adaylar a
  where a.secim_id = s.id;

  if n = 0 then
    perform oyun.olay(
      'secim',
      'Cumhurbaşkanlığı seçiminde aday yoktu; makam boş kalacak.',
      null, null, s.sonuc_at
    );

    return jsonb_build_object(
      'toplam', toplam,
      'adaylar', adaylar_j,
      'ikinci_tur', false
    );
  end if;

  select * into birinci
  from oyun.adaylar
  where secim_id = s.id
  order by oy desc, basvuru_at, id
  limit 1;

  if toplam > 0 and birinci.oy * 2 > toplam then
    insert into oyun.kazananlar
    values (s.id, birinci.user_id, null, birinci.parti_id)
    on conflict do nothing;

    perform oyun.olay(
      'secim',
      format(
        'Cumhurbaşkanı ilk turda seçildi: %s (%%%s).',
        (select kad from oyun.profiller where id = birinci.user_id),
        case
          when toplam > 0 then round(birinci.oy * 100.0 / toplam,1)
          else 100
        end
      ),
      null, birinci.parti_id, s.sonuc_at
    );

    return jsonb_build_object(
      'toplam', toplam,
      'adaylar', adaylar_j,
      'ikinci_tur', false,
      'kazanan', oyun.aday_json(birinci.id)
    );
  end if;

  if n=1 then
    return jsonb_build_object('toplam',toplam,'adaylar',adaylar_j,'ikinci_tur',false,'kazanan',null);
  end if;

  select * into ikinci
  from oyun.adaylar
  where secim_id = s.id
    and id <> birinci.id
  order by oy desc, basvuru_at, id
  limit 1;

  insert into oyun.secimler(
    tur, donem, oy_bas, oy_bit, sonuc_at, goreve_bas,
    ara, ara_neden
  )
  values (
    'cb2',
    s.donem,
    oyun.tr_an(gun+1,8),
    oyun.tr_an(gun+1,22),
    oyun.tr_an(gun+1,22,30),
    oyun.tr_an(gun+2,0),
    s.ara,
    s.ara_neden
  )
  on conflict(tur,donem) do nothing
  returning * into t2;

  if t2.id is not null then
    insert into oyun.adaylar(
      secim_id,user_id,parti_id,il_id,basvuru_at,vaat
    )
    values
      (
        t2.id,birinci.user_id,birinci.parti_id,null,
        birinci.basvuru_at,birinci.vaat
      ),
      (
        t2.id,ikinci.user_id,ikinci.parti_id,null,
        ikinci.basvuru_at,ikinci.vaat
      );
  end if;

  perform oyun.olay(
    'secim',
    format(
      'Cumhurbaşkanlığı seçimi ikinci tura kaldı: %s ve %s yarın sandıkta.',
      (select kad from oyun.profiller where id = birinci.user_id),
      (select kad from oyun.profiller where id = ikinci.user_id)
    ),
    null, null, s.sonuc_at
  );

  return jsonb_build_object(
    'toplam', toplam,
    'adaylar', adaylar_j,
    'ikinci_tur', true
  );
end $function$


CREATE OR REPLACE FUNCTION oyun._sonuc_cb2(s oyun.secimler)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
declare k record; ilk bigint; toplam bigint; adaylar_j jsonb;
begin
  perform oyun.aday_oylarini_say(s.id);
  select id into ilk from oyun.secimler where tur = 'cb' and donem = s.donem;
  select count(*) into toplam from oyun.oylar where secim_id = s.id;
  select a.* into k from oyun.adaylar a
    left join oyun.adaylar a1 on a1.secim_id = ilk and a1.user_id = a.user_id
    where a.secim_id = s.id order by a.oy desc, a1.oy desc nulls last, a.basvuru_at limit 1;
  select coalesce(jsonb_agg(oyun.aday_json(a.id) order by a.oy desc), '[]'::jsonb) into adaylar_j from oyun.adaylar a where a.secim_id = s.id;
  if k.id is not null and toplam > 0 and coalesce(k.oy,0) > 0 then
    insert into oyun.kazananlar values (s.id, k.user_id, null, k.parti_id) on conflict do nothing;
    perform oyun.olay('secim', format('Cumhurbaşkanı ikinci turda seçildi: %s.', (select kad from oyun.profiller where id = k.user_id)), null, k.parti_id, s.sonuc_at);
  end if;
  return jsonb_build_object('toplam', toplam, 'adaylar', adaylar_j, 'kazanan', case when k.id is null or toplam=0 or coalesce(k.oy,0)=0 then null else oyun.aday_json(k.id) end);
end $function$

