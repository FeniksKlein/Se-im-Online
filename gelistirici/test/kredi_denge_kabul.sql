-- Kabul testi (canlıda geri alınan alt işlem): kredi ufku ve kredili sermaye sınırı
create table if not exists oyun.migration_test_sonuc(ad text not null, sonuc jsonb, zaman timestamptz not null default now());
do $kabul$
declare res jsonb := '{}'; u uuid; e text; l30 numeric; l365 numeric; sid bigint;
begin
  begin
    select p.id into u from oyun.profiller p where not coalesce(p.yasakli,false)
      and not exists(select 1 from oyun.krediler k where k.user_id=p.id and k.durum in ('aktif','takip'))
      and not exists(select 1 from oyun.oyb_kredi k where k.borclu=p.id and k.durum in ('aktif','takip'))
      and not exists(select 1 from oyun.kredi_kartlari k where k.user_id=p.id and coalesce(k.borc,0)>0 and k.durum not in ('kapali','iptal'))
     order by (oyun.gelir_hesap(p.id, oyun.simdi())->>'gunluk_net')::numeric desc nulls last limit 1;
    perform set_config('request.jwt.claim.sub', u::text, true);
    l30 := (oyun.kredi_risk_ozeti(u, 30*24)->>'azami_kredi')::numeric;
    l365 := (oyun.kredi_risk_ozeti(u, 365*24)->>'azami_kredi')::numeric;
    res := res || jsonb_build_object('K1_limit30', l30, 'limit365', l365, 'K1_ufuk', l365 <= l30 + 100);
    update oyun.cuzdan set para = 6000000 where user_id = u;
    insert into oyun.krediler(user_id,anapara,oran,gun,toplam,taksit,kalan,acilis) values (u,6000000,3,365,6300000,17260,6300000,oyun.simdi());
    begin perform public.sirket_kur('Kabul Test Şirketi A','ticaret',1000000); e := 'kuruldu'; exception when others then e := left(sqlerrm,60); end;
    res := res || jsonb_build_object('K2_kredili_engel', e);
    update oyun.krediler set kalan = 100000 where user_id = u and durum='aktif';
    perform oyun.para_islem(u, 1000, 'kredi', 'kabul testi', oyun.simdi());
    begin sid := (public.sirket_kur('Kabul Test Şirketi B','ticaret',1000000)->>'id')::bigint; e := 'kuruldu'; exception when others then e := left(sqlerrm,60); end;
    res := res || jsonb_build_object('K3_ozkaynakla_kurulur', e,
      'K4_masak', exists(select 1 from oyun.masak where tur='kredi_sermaye' and user_id=u));
    raise exception using errcode='P0099', message=res::text;
  exception when sqlstate 'P0099' then res := sqlerrm::jsonb;
  end;
  insert into oyun.migration_test_sonuc(ad,sonuc) values('kredi_denge_20261116',res);
  if not (coalesce((res->>'K1_ufuk')::boolean,false) and res->>'K2_kredili_engel' like 'Kredili sermaye%'
          and res->>'K3_ozkaynakla_kurulur'='kuruldu' and coalesce((res->>'K4_masak')::boolean,false)) then
    raise exception 'KABUL TESTI BASARISIZ: %', res;
  end if;
end $kabul$;
