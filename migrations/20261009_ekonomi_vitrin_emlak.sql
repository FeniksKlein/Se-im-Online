-- Seçim Simülasyonu Online: Şirket keşfi ve gayrimenkul pazarlığı
-- Mevcut hesap, kasa, mülk ve tapu verilerini sıfırlamaz.
create table if not exists oyun.emlak_pazarlik (
 id bigint generated always as identity primary key,
 ilan_id bigint not null references oyun.mulk_ilan(id) on delete cascade,
 alici uuid not null references oyun.profiller(id),
 satici uuid not null references oyun.profiller(id),
 teklif numeric not null check (teklif between 10000 and 1000000000),
 karsi_teklif numeric check (karsi_teklif between 10000 and 1000000000),
 durum text not null default 'bekliyor' check (durum in ('bekliyor','karsi','kabul','red','iptal')),
 zaman timestamptz not null default now(), sonuc_at timestamptz
);
create index if not exists emlak_pazarlik_ilan on oyun.emlak_pazarlik(ilan_id);
create index if not exists emlak_pazarlik_satici on oyun.emlak_pazarlik(satici,durum);
create index if not exists emlak_pazarlik_alici on oyun.emlak_pazarlik(alici,durum);
alter table oyun.emlak_pazarlik enable row level security;
revoke all on oyun.emlak_pazarlik from public,anon,authenticated;

create or replace function public.sirket_vitrini()
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('sirketler',
 coalesce((select jsonb_agg(jsonb_build_object(
   'id',s.id,'ad',s.ad,'sektor',s.sektor,'sahip',p.kad,
   'sermaye',s.sermaye,'kasa',s.kasa,'kurulus',s.kurulus,
   'aktif',s.aktif,'satilik',s.satilik,
   'ortaklar',coalesce((select jsonb_agg(jsonb_build_object('kad',x.kad,'pay',o.pay) order by o.pay desc)
      from oyun.sirket_ortaklari o join oyun.profiller x on x.id=o.user_id where o.sirket_id=s.id),'[]'::jsonb),
   'toplam_gelir',coalesce((select sum(greatest(0,h.faaliyet_gelir)) from oyun.sirket_hareket h where h.sirket_id=s.id),0),
   'net_kazanc',coalesce((select sum(h.tutar) from oyun.sirket_hareket h where h.sirket_id=s.id and h.faaliyet_gelir is not null),0),
   'vergi',coalesce((select sum(h.vergi) from oyun.hesap_hareket h
      where h.tur='sirket' and h.vergi>0 and h.aciklama like 'Sirket #'||s.id::text||' %'),0)
 ) order by s.id) from oyun.sirketler s join oyun.profiller p on p.id=s.kurucu where s.aktif and s.sektor<>'banka'),'[]'::jsonb),
 'vergi_notu','Sadece kayda alınmış gerçek şirket kazancı vergileri gösterilir; eski faaliyetler için şirket vergisi kaydı bulunmayabilir.')
$$;
revoke all on function public.sirket_vitrini() from public,anon;
grant execute on function public.sirket_vitrini() to authenticated;

create or replace function public.emlak_pazarliklarim()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',z.id,'ilan_id',z.ilan_id,'teklif',z.teklif,'karsi_teklif',z.karsi_teklif,
   'durum',z.durum,'zaman',z.zaman,'alici',a.kad,'satici',s.kad,
   'ben_aliciyim',z.alici=auth.uid(),'ben_saticiyim',z.satici=auth.uid(),
   'ilan_acik',i.durum='acik','mulk_id',i.mulk_id,
   'tip',m.tip,'il',il.ad) order by z.zaman desc),'[]'::jsonb)
 from oyun.emlak_pazarlik z
 join oyun.mulk_ilan i on i.id=z.ilan_id
 join oyun.yatirim_mulkleri m on m.id=i.mulk_id
 join oyun.iller il on il.id=m.il_id
 join oyun.profiller a on a.id=z.alici join oyun.profiller s on s.id=z.satici
 where (z.alici=auth.uid() or z.satici=auth.uid())
   and z.zaman>oyun.simdi()-interval '60 days'
$$;
revoke all on function public.emlak_pazarliklarim() from public,anon;
grant execute on function public.emlak_pazarliklarim() to authenticated;

create or replace function public.emlak_pazarlik_teklif(p_ilan bigint,p_fiyat numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();i oyun.mulk_ilan; idd bigint; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then raise exception 'Oyuncu hesabı gerekli.'; end if;
 if p_fiyat is null or p_fiyat<10000 or p_fiyat>1000000000 or p_fiyat<>trunc(p_fiyat) then raise exception 'Teklif tutarı 10.000 ile 1 milyar ₺ arasında tam sayı olmalı.'; end if;
 select * into i from oyun.mulk_ilan where id=p_ilan for update;
 if i.id is null or i.durum<>'acik' then raise exception 'Bu ilan artık satılık değil.'; end if;
 if i.satici=u then raise exception 'Kendi mülküne teklif veremezsin.'; end if;
 if not exists(select 1 from oyun.yatirim_mulkleri where id=i.mulk_id and user_id=i.satici) then raise exception 'Mülk artık satıcının değil.'; end if;
 if exists(select 1 from oyun.emlak_pazarlik where ilan_id=p_ilan and alici=u and durum in ('bekliyor','karsi')) then raise exception 'Bu ilan için önceki pazarlığın sürüyor.'; end if;
 insert into oyun.emlak_pazarlik(ilan_id,alici,satici,teklif,zaman) values(p_ilan,u,i.satici,p_fiyat,t) returning id into idd;
 perform oyun.bildir(i.satici,format('%s mülk #%s için %s ₺ teklif verdi. Gayrimenkul > Pazarlıklarım bölümünden yanıtla.',
 (select kad from oyun.profiller where id=u),i.mulk_id,oyun.tl(p_fiyat)),t);
 return jsonb_build_object('id',idd,'durum','bekliyor');
end $$;
revoke all on function public.emlak_pazarlik_teklif(bigint,numeric) from public,anon;
grant execute on function public.emlak_pazarlik_teklif(bigint,numeric) to authenticated;

-- Gerçek satış, eski satış mantığıyla aynı biçimde kaydedilir. Yalnızca güvenli RPC çağırabilir.
create or replace function oyun._emlak_pazarlik_tamamla(p_teklif bigint,p_fiyat numeric)
returns void language plpgsql security definer set search_path='' as $$
declare z oyun.emlak_pazarlik;i oyun.mulk_ilan; m oyun.yatirim_mulkleri;
  vergi numeric;t timestamptz:=oyun.simdi();
begin
 select * into z from oyun.emlak_pazarlik where id=p_teklif for update;
 if z.id is null or z.durum not in ('bekliyor','karsi') then raise exception 'Teklif artık geçerli değil.'; end if;
 if p_fiyat is null or p_fiyat<10000 or p_fiyat>1000000000 then raise exception 'Geçersiz teklif bedeli.'; end if;
 select * into i from oyun.mulk_ilan where id=z.ilan_id for update;
 if i.id is null or i.durum<>'acik' or i.satici<>z.satici then raise exception 'İlan artık geçerli değil.'; end if;
 select * into m from oyun.yatirim_mulkleri where id=i.mulk_id for update;
 if m.id is null or m.user_id<>i.satici then raise exception 'Mülk artık satışta değil.'; end if;
 if z.alici=z.satici then raise exception 'Kendi mülkünü alamazsın.'; end if;
 perform oyun.mulk_kira_tahsil(z.satici);
 vergi:=round(p_fiyat*0.02);
 perform oyun.para_islem(z.alici,-p_fiyat,'emlak','Pazarlıkla mülk satın alındı #'||i.mulk_id,t);
 perform oyun.para_islem(z.satici,p_fiyat-vergi,'emlak','Pazarlıkla mülk satışı #'||i.mulk_id,t);
 update oyun.ulke set hazine=hazine+vergi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=z.alici,satin_alma=t,alis_bedeli=p_fiyat,sonraki_kira=t+interval '7 days',
   toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=z.alici,kapanma=t where id=i.id;
 update oyun.emlak_pazarlik set durum='kabul',sonuc_at=t where id=z.id;
 update oyun.emlak_pazarlik set durum='iptal',sonuc_at=t where ilan_id=i.id and id<>z.id and durum in ('bekliyor','karsi');
 perform oyun.bildir(z.alici,format('Pazarlık kabul edildi! Mülk #%s %s ₺ karşılığında senin.',i.mulk_id,oyun.tl(p_fiyat)),t);
 perform oyun.bildir(z.satici,format('Mülk #%s %s ₺ karşılığında satıldı; %%2 işlem vergisi kesildi.',i.mulk_id,oyun.tl(p_fiyat)),t);
end $$;
revoke all on function oyun._emlak_pazarlik_tamamla(bigint,numeric) from public,anon,authenticated;

create or replace function public.emlak_pazarlik_satici_yanit(p_teklif bigint,p_karar text,p_karsi numeric default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); z oyun.emlak_pazarlik; t timestamptz:=oyun.simdi();
begin
 select * into z from oyun.emlak_pazarlik where id=p_teklif for update;
 if z.id is null or z.satici is distinct from u or z.durum<>'bekliyor' then raise exception 'Yanıt verebileceğin açık teklif yok.'; end if;
 if p_karar not in ('kabul','red','karsi') then raise exception 'Geçersiz yanıt.'; end if;
 if p_karar='kabul' then
    perform oyun._emlak_pazarlik_tamamla(z.id,z.teklif);
 elsif p_karar='red' then
    update oyun.emlak_pazarlik set durum='red',sonuc_at=t where id=z.id;
    perform oyun.bildir(z.alici,'Mülk teklifin satıcı tarafından reddedildi.',t);
 else
    if p_karsi is null or p_karsi<10000 or p_karsi>1000000000 or p_karsi<>trunc(p_karsi) then raise exception 'Geçerli bir karşı teklif tutarı gir.'; end if;
    update oyun.emlak_pazarlik set durum='karsi',karsi_teklif=p_karsi where id=z.id;
    perform oyun.bildir(z.alici,format('Mülk teklifine karşı %s ₺ istendi. Gayrimenkul > Pazarlıklarım bölümünden yanıtla.',oyun.tl(p_karsi)),t);
 end if;
 return jsonb_build_object('durum',p_karar);
end $$;
revoke all on function public.emlak_pazarlik_satici_yanit(bigint,text,numeric) from public,anon;
grant execute on function public.emlak_pazarlik_satici_yanit(bigint,text,numeric) to authenticated;

create or replace function public.emlak_pazarlik_alici_yanit(p_teklif bigint,p_kabul boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare z oyun.emlak_pazarlik;t timestamptz:=oyun.simdi();
begin
 select * into z from oyun.emlak_pazarlik where id=p_teklif for update;
 if z.id is null or z.alici is distinct from auth.uid() or z.durum<>'karsi' then raise exception 'Karşı teklif bulunamadı.'; end if;
 if p_kabul is null then raise exception 'Kabul veya ret seçmelisin.'; end if;
 if p_kabul then perform oyun._emlak_pazarlik_tamamla(z.id,z.karsi_teklif);
 else
   update oyun.emlak_pazarlik set durum='red',sonuc_at=t where id=z.id;
   perform oyun.bildir(z.satici,'Alıcı karşı teklifini reddetti.',t);
 end if;
 return jsonb_build_object('durum',case when p_kabul then 'kabul' else 'red' end);
end $$;
revoke all on function public.emlak_pazarlik_alici_yanit(bigint,boolean) from public,anon;
grant execute on function public.emlak_pazarlik_alici_yanit(bigint,boolean) to authenticated;
