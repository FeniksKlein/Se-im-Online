-- Eyleme kaynak aktarmak gücü artırır ama karekök kadar. Patlamaz.
-- Hazine bedeli değişmez. Sayılar mevcut ayar satırına eklenir, eskiler silinmez.
-- Canlı açılış fonksiyonuna yama yok. İkinci kez çalıştırılabilir.

alter table oyun.sokak_denge_ayar add column if not exists kaynak_min numeric not null default 10000;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_max_kurum numeric not null default 150000;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_max_kisi numeric not null default 25000;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_olcek numeric not null default 40000;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_ivme_carpan numeric not null default 2;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_ivme_tavan numeric not null default 6;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_sinyal numeric not null default 150000;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_bekleme_dakika integer not null default 30;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_ivme_zayif numeric not null default 25;
alter table oyun.sokak_denge_ayar add column if not exists kaynak_yorgunluk_esik numeric not null default 50;

create table if not exists oyun.sokak_kaynak(
 id bigint generated always as identity primary key,
 eylem_id bigint not null references oyun.sokak_eylem,
 kaynak text not null check(kaynak in ('parti','dernek','oyuncu')),
 kaynak_id bigint, user_id uuid not null,
 kalem text not null check(kalem in ('ses','ulasim','yemek','pankart')),
 tutar numeric not null check(tutar>0),
 guc numeric not null, ivme numeric not null,
 zaman timestamptz not null
);
create index if not exists sokak_kaynak_eylem on oyun.sokak_kaynak(eylem_id,zaman desc);
alter table oyun.sokak_kaynak enable row level security;
revoke all on oyun.sokak_kaynak from public,anon,authenticated;

create or replace function oyun.sokak_kaynak_toplam(e bigint) returns numeric
language sql stable set search_path='' as $$
 select coalesce(sum(tutar),0) from oyun.sokak_kaynak where eylem_id=e
$$;

create or replace function oyun.sokak_kaynak_etki(eski numeric, yeni numeric, iv numeric, yor numeric) returns numeric
language plpgsql stable set search_path='' as $$
declare a oyun.sokak_denge_ayar; ham numeric; verim numeric;
begin
 select * into a from oyun.sokak_denge_ayar where id=1;
 ham:=sqrt(greatest(yeni,0)/greatest(a.kaynak_olcek,1)) - sqrt(greatest(eski,0)/greatest(a.kaynak_olcek,1));
 verim:=1;
 if coalesce(iv,0)<a.kaynak_ivme_zayif then verim:=verim*0.35; end if;
 if coalesce(yor,0)>a.kaynak_yorgunluk_esik then verim:=verim*greatest(0.3, 1-(yor-a.kaynak_yorgunluk_esik)/80.0); end if;
 return round(greatest(ham,0)*verim, 2);
end $$;

-- Kaynak puanı burada hesaplanır. Akıllı-hamle süzgeci bunu yeniden ezmesin.
create or replace function oyun.sokak_etki_dizgin() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.tur in ('kaynak','kaynak_baski') then return new; end if;
 if new.puan is not null and new.puan>0 then
  new.puan:=oyun.sokak_ivme_uygula(new.eylem_id, new.tur, new.puan);
 end if;
 return new;
end $$;

create or replace function oyun.sokak_kaynak_sinyal_besle() returns trigger
language plpgsql set search_path='' as $$
declare a oyun.sokak_denge_ayar; t timestamptz:=oyun.simdi();
begin
 if new.tur not in ('mali','ihale') then return new; end if;
 select * into a from oyun.sokak_denge_ayar where id=1;
 if oyun.sokak_kaynak_toplam(new.eylem_id)>=a.kaynak_sinyal then
  insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis)
   values(new.eylem_id,'kaynak_baski',-4,t+interval '12 hours');
 end if;
 return new;
end $$;

create or replace function public.sokak_kaynak_aktar(p_eylem bigint, p_kaynak text, p_kaynak_id bigint, p_kalem text, p_tutar numeric) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); x oyun.sokak_eylem; a oyun.sokak_denge_ayar; t timestamptz:=oyun.simdi();
 eski numeric; yeni numeric; guc numeric; iv numeric:=0; yor numeric:=0; artis numeric; n int; tavan int; cekim int;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 if p_kaynak not in ('parti','dernek','oyuncu') then raise exception 'Kaynak parti, dernek ya da oyuncu olmalı'; end if;
 if p_kalem not in ('ses','ulasim','yemek','pankart') then raise exception 'Kalem ses, ulaşım, yemek ya da pankart olmalı'; end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<=0 then raise exception 'Tutar tam TL olmalı'; end if;
 select * into a from oyun.sokak_denge_ayar where id=1;
 select * into x from oyun.sokak_eylem where id=p_eylem for update;
 if x.id is null or x.durum<>'aktif' or x.bitis<=t then raise exception 'Aktif eylem gerekli'; end if;
 if p_tutar<a.kaynak_min then raise exception 'En az % TL aktarılır', a.kaynak_min; end if;
 if p_kaynak='oyuncu' and p_tutar>a.kaynak_max_kisi then raise exception 'Kişisel aktarım en çok % TL', a.kaynak_max_kisi; end if;
 if p_kaynak<>'oyuncu' and p_tutar>a.kaynak_max_kurum then raise exception 'Kurumsal aktarım en çok % TL', a.kaynak_max_kurum; end if;
 if exists(select 1 from oyun.sokak_kaynak k where k.eylem_id=x.id and k.user_id=u and k.zaman>t-make_interval(mins=>a.kaynak_bekleme_dakika)) then
  raise exception 'Aynı kişi % dakika bekler', a.kaynak_bekleme_dakika; end if;
 if p_kaynak='oyuncu' then
  if not oyun.sokak_katilimci(x.id,u) then raise exception 'Kendi paranı aktarmak için eylemde olmalısın'; end if;
  update oyun.cuzdan c set para=c.para-p_tutar where c.user_id=u and c.para>=p_tutar;
  if not found then raise exception 'Cüzdanda yeterli para yok'; end if;
  if to_regclass('oyun.hesap_hareket') is not null then
   insert into oyun.hesap_hareket(user_id,zaman,tutar,tur,aciklama) values(u,t,-p_tutar,'gider','Eylem #'||x.id||' kaynak');
  end if;
 elsif p_kaynak='parti' then
  if x.parti_id is distinct from p_kaynak_id and not (x.org_tur='parti' and x.org_id=p_kaynak_id) then raise exception 'Yalnız eylemi açan parti aktarır'; end if;
  if not exists(select 1 from oyun.partiler where id=p_kaynak_id and gb=u and not kapali) then raise exception 'Parti kasasını genel başkan aktarır'; end if;
  perform oyun.sokak_kurulus_ode('parti',p_kaynak_id,p_tutar,'Eylem #'||x.id||' kaynak / '||p_kalem);
 else
  if not (x.org_tur='dernek' and x.org_id=p_kaynak_id) then raise exception 'Yalnız eylemi açan dernek aktarır'; end if;
  if not exists(select 1 from oyun.dernekler where id=p_kaynak_id and baskan=u and not kapali) then raise exception 'Dernek kasasını başkan aktarır'; end if;
  perform oyun.sokak_kurulus_ode('dernek',p_kaynak_id,p_tutar,'Eylem #'||x.id||' kaynak / '||p_kalem);
 end if;
 eski:=oyun.sokak_kaynak_toplam(x.id);
 yeni:=eski+p_tutar;
 if to_regclass('oyun.sokak_ivme') is not null then
  select ivme,yorgunluk into iv,yor from oyun.sokak_ivme where eylem_id=x.id;
 end if;
 guc:=oyun.sokak_kaynak_etki(eski,yeni,iv,yor);
 artis:=least(a.kaynak_ivme_tavan, round(guc*a.kaynak_ivme_carpan,2));
 insert into oyun.sokak_kaynak(eylem_id,kaynak,kaynak_id,user_id,kalem,tutar,guc,ivme,zaman)
  values(x.id,p_kaynak,p_kaynak_id,u,p_kalem,p_tutar,guc,artis,t);
 if guc>0 and to_regclass('oyun.sokak_meydan_etki') is not null then
  insert into oyun.sokak_meydan_etki(eylem_id,tur,puan,bitis) values(x.id,'kaynak',guc,t+interval '12 hours');
 end if;
 if to_regclass('oyun.sokak_ivme') is not null then
  update oyun.sokak_ivme set ivme=least(100,ivme+artis), son_not='Kaynak aktarıldı: güç +'||guc||', ivme +'||artis where eylem_id=x.id;
 end if;
 if to_regprocedure('oyun.sokak_yenile(bigint)') is not null then perform oyun.sokak_yenile(x.id); end if;
 select count(*) into n from oyun.sokak_eylem_destek d where d.eylem_id=x.id and d.destek_turu='katilim' and d.taraf='muhalefet' and d.destekci_tur='oyuncu';
 tavan:=oyun.sokak_il_tavan(x.il_id);
 cekim:=least(greatest(floor(guc)::int,0), greatest(tavan-coalesce(n,0),0));
 return jsonb_build_object('tamam',true,'guc',guc,'ivme',artis,'toplam',yeni,'sinyal',yeni>=a.kaynak_sinyal,'cekim',cekim,'iade',false);
end $$;

create or replace function public.sokak_kaynak_ozet() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); a oyun.sokak_denge_ayar;
begin
 if u is null then raise exception 'Oturum gerekli'; end if;
 select * into a from oyun.sokak_denge_ayar where id=1;
 return jsonb_build_object('tamam',true,'sinyal_esik',a.kaynak_sinyal,'min',a.kaynak_min,'max_kurum',a.kaynak_max_kurum,'max_kisi',a.kaynak_max_kisi,
  'eylemler',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'toplam',oyun.sokak_kaynak_toplam(e.id),'sinyal',oyun.sokak_kaynak_toplam(e.id)>=a.kaynak_sinyal))
    from oyun.sokak_eylem e where e.durum='aktif' and e.bitis>oyun.simdi()),'[]'::jsonb));
end $$;

do $$ begin
 if to_regclass('oyun.sokak_sert') is not null then
  drop trigger if exists sokak_kaynak_sinyal_besle on oyun.sokak_sert;
  create trigger sokak_kaynak_sinyal_besle after insert on oyun.sokak_sert
   for each row execute function oyun.sokak_kaynak_sinyal_besle();
 end if;
end $$;

revoke all on function oyun.sokak_kaynak_toplam(bigint),oyun.sokak_kaynak_etki(numeric,numeric,numeric,numeric),oyun.sokak_kaynak_sinyal_besle(),
 public.sokak_kaynak_aktar(bigint,text,bigint,text,numeric),public.sokak_kaynak_ozet()
 from public,anon,authenticated;
grant execute on function public.sokak_kaynak_aktar(bigint,text,bigint,text,numeric),public.sokak_kaynak_ozet() to authenticated;
