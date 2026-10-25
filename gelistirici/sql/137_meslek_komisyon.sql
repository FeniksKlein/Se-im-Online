-- 2026-10-25 | Seffaf islem komisyonu, kasa ve stok korumasini bozmaz.
alter table oyun.meslek_dukkan add column if not exists komisyon_orani numeric(5,3) not null default 0.35
 check (komisyon_orani between 0 and 2);
alter table oyun.meslek_islemler add column if not exists komisyon numeric(24,2) not null default 0
 check (komisyon>=0);

create or replace function public.meslek_komisyon_ayarla(p_dukkan bigint,p_oran numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_oran is null or p_oran<0 or p_oran>2 then raise exception 'Komisyon orani 0 ile 2 yuzde arasinda olmali';end if;
 update oyun.meslek_dukkan set komisyon_orani=round(p_oran,3)
 where id=p_dukkan and sahibi=auth.uid() and aktif;
 if not found then raise exception 'Bu dukkan sana ait degil';end if;
 return jsonb_build_object('komisyon',round(p_oran,3));
end; $$;
revoke all on function public.meslek_komisyon_ayarla(bigint,numeric) from public,anon;
grant execute on function public.meslek_komisyon_ayarla(bigint,numeric) to authenticated;

create or replace function public.meslek_panel()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oturum gerekli';end if;
 select para into c from oyun.cuzdan where user_id=u;
 return jsonb_build_object(
  'cuzdan',coalesce(c,0),
  'kurlar',coalesce((select jsonb_agg(jsonb_build_object('kod',kod,'fiyat',fiyat,'kaynak',kaynak,'veri_tarihi',veri_tarihi,'guncelleme',guncelleme) order by kod) from oyun.meslek_kur),'[]'::jsonb),
  'dukkanlar',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'ad',d.ad,'tur',d.tur,'il_id',d.il_id,'makas',d.makas,'komisyon',d.komisyon_orani,'benim',d.sahibi=u,'kasa',case when d.sahibi=u then d.kasa else null end,'stok',(select coalesce(jsonb_object_agg(st.kod,st.miktar),'{}'::jsonb) from oyun.meslek_stok st where st.dukkan_id=d.id)) order by d.id desc) from oyun.meslek_dukkan d where d.aktif),'[]'::jsonb),
  'portfoy',coalesce((select jsonb_object_agg(kod,miktar) from oyun.meslek_portfoy where user_id=u),'{}'::jsonb),
  'islemler',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'dukkan_id',q.dukkan_id,'kod',q.kod,'yon',q.yon,'tutar',q.tutar,'miktar',q.miktar,'tarih',q.tarih)) from (select * from oyun.meslek_islemler where user_id=u or dukkan_id in(select id from oyun.meslek_dukkan where sahibi=u) order by tarih desc limit 30) q),'[]'::jsonb));
end; $$;

create or replace function public.meslek_ticaret(p_dukkan bigint,p_kod text,p_yon text,p_miktar numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d oyun.meslek_dukkan%rowtype; fiyat numeric; birim numeric; tutar numeric; mevcut numeric; brut numeric; kom numeric;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Giris gerekli';end if;
 if p_yon not in ('al','sat') or p_miktar is null or p_miktar<=0 or p_miktar>100000 or p_miktar<>round(p_miktar,4) then raise exception 'Gecersiz islem miktari';end if;
 select * into d from oyun.meslek_dukkan where id=p_dukkan and aktif for update;
 if not found then raise exception 'Dukkan bulunamadi';end if;
 if d.sahibi=u then raise exception 'Kendi dukkanindan kendine alis-satis yapamazsin';end if;
 if not ((d.tur='doviz' and p_kod in ('USD','EUR','GBP','CHF')) or (d.tur='kuyumcu' and p_kod='ALTIN')) then raise exception 'Urun bu dukkanda islem gormuyor';end if;
 fiyat:=oyun.meslek_kur_kontrol(p_kod);
 birim:=round(fiyat*(case when p_yon='al' then 1+d.makas/100 else 1-d.makas/100 end),8);
 brut:=case when p_yon='al' then ceil(birim*p_miktar) else floor(birim*p_miktar) end;
 kom:=ceil(brut*d.komisyon_orani/100);
 tutar:=case when p_yon='al' then brut+kom else greatest(0,brut-kom) end;
 if tutar<100 then raise exception 'Islem tutari en az 100 TL olmali';end if;
 insert into oyun.meslek_stok(dukkan_id,kod,miktar) values(d.id,p_kod,0) on conflict do nothing;
 insert into oyun.meslek_portfoy(user_id,kod,miktar) values(u,p_kod,0) on conflict do nothing;
 select miktar into mevcut from oyun.meslek_stok where dukkan_id=d.id and kod=p_kod for update;
 perform 1 from oyun.meslek_portfoy where user_id=u and kod=p_kod for update;
 if p_yon='al' then
  if mevcut<p_miktar then raise exception 'Dukkanda yeterli stok yok';end if;
  perform oyun.para_islem(u,-tutar,'meslek','Dukkandan '||p_kod||' alimi',now());
  update oyun.meslek_stok set miktar=miktar-p_miktar where dukkan_id=d.id and kod=p_kod;
  update oyun.meslek_portfoy set miktar=miktar+p_miktar where user_id=u and kod=p_kod;
  update oyun.meslek_dukkan set kasa=kasa+tutar where id=d.id;
 else
  if (select miktar from oyun.meslek_portfoy where user_id=u and kod=p_kod)<p_miktar then raise exception 'Portfoyunde yeterli varlik yok';end if;
  if d.kasa<tutar then raise exception 'Dukkan kasasi bu alim icin yetersiz';end if;
  update oyun.meslek_portfoy set miktar=miktar-p_miktar where user_id=u and kod=p_kod;
  update oyun.meslek_stok set miktar=miktar+p_miktar where dukkan_id=d.id and kod=p_kod;
  update oyun.meslek_dukkan set kasa=kasa-tutar where id=d.id;
  perform oyun.para_islem(u,tutar,'meslek','Dukkana '||p_kod||' satisi',now());
 end if;
 insert into oyun.meslek_islemler(dukkan_id,user_id,kod,yon,miktar,birim_fiyat,tutar,komisyon) values(d.id,u,p_kod,p_yon,p_miktar,birim,tutar,kom);
 return jsonb_build_object('yon',p_yon,'kod',p_kod,'miktar',p_miktar,'birim',birim,'tutar',tutar,'komisyon',kom,'dukkan',d.ad);
end; $$;
