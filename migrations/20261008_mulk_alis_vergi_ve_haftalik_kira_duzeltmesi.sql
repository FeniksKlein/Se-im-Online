-- Gayrimenkul pazarindaki ambiguous "vergi" SQL degiskeni duzeltildi.
-- Alim/satim, ilgili odeme ve %2 satis vergisi ayni kalir.
CREATE OR REPLACE FUNCTION public.mulk_ilan_satin_al(p_ilan bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); a oyun.mulk_ilan%rowtype; m oyun.yatirim_mulkleri%rowtype;
 v_satis_vergisi numeric; t timestamptz:=oyun.simdi();
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 select * into a from oyun.mulk_ilan where id=p_ilan for update;
 if not found or a.durum<>'acik' then raise exception 'İlan artık açık değil'; end if;
 if a.satici=u then raise exception 'Kendi mülkünü satın alamazsın'; end if;
 select * into m from oyun.yatirim_mulkleri where id=a.mulk_id for update;
 if not found or m.user_id<>a.satici then raise exception 'Satıcı artık mülkün sahibi değil'; end if;
 perform oyun.mulk_kira_tahsil(a.satici);
 v_satis_vergisi:=round(a.fiyat*0.02);
 perform oyun.para_islem(u,-a.fiyat,'emlak','Oyuncudan mülk satın alındı #'||a.mulk_id,t);
 perform oyun.para_islem(a.satici,a.fiyat-v_satis_vergisi,'emlak','Mülk satışı #'||a.mulk_id,t);
 update oyun.ulke set hazine=hazine+v_satis_vergisi/1000000.0 where id=1;
 update oyun.yatirim_mulkleri set user_id=u,satin_alma=t,alis_bedeli=a.fiyat,
   sonraki_kira=t+interval '7 days',toplam_kira=0,kira_sayisi=0 where id=m.id;
 update oyun.mulk_ilan set durum='satildi',alici=u,kapanma=t where id=a.id;
 perform oyun.bildir(a.satici,'Satıştaki mülkün satıldı. Satış vergisi %2.',t);
 return public.mulk_pazar();
end $function$
;

-- Yeni gayrimenkul haftalik kira getirisi %2,5.
CREATE OR REPLACE FUNCTION public.mulk_satin_al(p_tip text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric; t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum açmalısın'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null then raise exception 'Önce profil oluşturmalısın'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü'; end if;
 bedel:=case p_tip when 'daire' then 130000 when 'dukkan' then 260000 when 'villa' then 520000 end;
 kira:=round(bedel*0.025,2); -- %2,5 / hafta: sabit emlak kira dengesi
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s satın alındı',p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p.il_id,p_tip,bedel,kira,t,t+interval '7 days');
 return public.mulk_liste();
end $function$
;

-- Eski mulklerde yalnizca gelecek kira tutarlari olceklenir.
-- Kazanilmis/toplanmis kira, oyuncu cuzdanlari, sahiplik, sonraki_kira ve mevcut ilanlar degismez.
create table if not exists oyun.mulk_kira_denge_kayit (
 mulk_id bigint primary key references oyun.yatirim_mulkleri(id),
 eski_haftalik numeric not null,
 yeni_haftalik numeric not null,
 degisim_zamani timestamptz not null default now()
);
insert into oyun.mulk_kira_denge_kayit(mulk_id,eski_haftalik,yeni_haftalik)
 select id, haftalik_kira, round(alis_bedeli*0.025,2)
 from oyun.yatirim_mulkleri
 where haftalik_kira is distinct from round(alis_bedeli*0.025,2)
 on conflict(mulk_id) do nothing;
update oyun.yatirim_mulkleri m
set haftalik_kira=round(m.alis_bedeli*0.025,2)
where m.haftalik_kira is distinct from round(m.alis_bedeli*0.025,2);
alter table oyun.mulk_kira_denge_kayit enable row level security;
revoke all on oyun.mulk_kira_denge_kayit from public,anon,authenticated;
