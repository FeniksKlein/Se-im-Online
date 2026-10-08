-- 10 secilebilir Meclis ekonomi yasasi. Mevcut gorusme/oy/veto akisi korunur.
create table if not exists oyun.yasa_ekonomi_ayar (
 kod text primary key, deger numeric not null, guncelleme timestamptz not null default now()
);
insert into oyun.yasa_ekonomi_ayar(kod,deger) values
('artan_vergi',0),('ilk_konut_muaf',0),('coklu_mulk_vergi',0),('faiz_stopaj',0),
('piyango_stopaj',0),('tahvil_faiz',0),('vergi_affi',0),('yeni_parti_destek',0),
('parti_yardim_carpan',100),('belediye_payi',10)
on conflict do nothing;
alter table oyun.yasa_ekonomi_ayar enable row level security;
revoke all on oyun.yasa_ekonomi_ayar from public,anon,authenticated;
create table if not exists oyun.devlet_tahvil (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id),
 anapara numeric not null check(anapara>0),
 faiz numeric not null,
 alis timestamptz not null,
 vade timestamptz not null,
 odendi boolean not null default false
);
alter table oyun.devlet_tahvil enable row level security;
revoke all on oyun.devlet_tahvil from public,anon,authenticated;

create or replace function oyun.yasa_oran(p_kod text)
returns numeric language sql stable set search_path='' as $$
 select coalesce((select deger from oyun.yasa_ekonomi_ayar where kod=p_kod),0)
$$;

create or replace function oyun.yasa_ekonomi_uygula()
returns trigger language plpgsql security definer set search_path='' as $$
declare kod text; val numeric; oldval numeric; t timestamptz:=oyun.simdi();
begin
 if new.durum<>'yururlukte' or old.durum='yururlukte' or new.veri->>'ekonomi_yasa' is null then return new; end if;
 kod:=new.veri->>'ekonomi_yasa';val:=(new.veri->>'deger')::numeric;
 select deger into oldval from oyun.yasa_ekonomi_ayar where kod=kod for update;
 if oldval is null then raise exception 'Bilinmeyen ekonomi yasasi: %',kod; end if;
 update oyun.yasa_ekonomi_ayar set deger=val,guncelleme=t where kod=kod;
 if kod='belediye_payi' then update oyun.ulke set belediye_payi=val where id=1;
 elsif kod='parti_yardim_carpan' then update oyun.ulke set parti_yardim=round(parti_yardim*val/greatest(oldval,1)) where id=1;
 elsif kod='vergi_affi' and val>0 then
   -- Vergi borcu modeli yoksa oyuncu cuzdanlarina keyfi para eklenmez.
   null;
 end if;
 update oyun.kanunlar set veri=veri||jsonb_build_object('onceki_deger',oldval,'uygulandi',true) where id=new.id;
 perform oyun.olay('ekonomi',format('%s yasasi yururluge girdi: %s -> %s',new.baslik,oldval,val),null,new.teklif_parti,t);
 return new;
end $$;
drop trigger if exists yasa_ekonomi_yururluk on oyun.kanunlar;
create trigger yasa_ekonomi_yururluk after update of durum on oyun.kanunlar
for each row execute function oyun.yasa_ekonomi_uygula();

create or replace function public.ekonomi_yasa_teklif(p_no int,p_deger numeric)
returns jsonb language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();kod text; baslik text; acik text; mn numeric;mx numeric; yeni bigint;s record;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Yalnizca milletvekilleri teklif verebilir.'; end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then raise exception 'Meclis Baskani teklif veremez.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then raise exception 'Bekleyen kanun teklifin var.'; end if;
 select x.kod,x.baslik,x.acik,x.mn,x.mx into kod,baslik,acik,mn,mx from (values
 (3,'artan_vergi','Artan Oranli Gelir Vergisi','Gelir vergisinde ust dilime ilave yuzde puan',0::numeric,20::numeric),
 (5,'ilk_konut_muaf','Ilk Konut Vergi Muafiyeti','Ilk gayrimenkul aliminda islem vergisi muafiyeti',0::numeric,1::numeric),
 (9,'coklu_mulk_vergi','Coklu Gayrimenkul Vergisi','Ucuncu ve sonraki mulklerde haftalik kira stopaji yuzdesi',0::numeric,40::numeric),
 (11,'faiz_stopaj','Mevduat Faizi Vergisi','Vadeli faiz kazanci stopaj yuzdesi',0::numeric,40::numeric),
 (21,'piyango_stopaj','Piyango Ikramiyesi Vergisi','Buyuk ikramiye stopaj yuzdesi',0::numeric,40::numeric),
 (23,'tahvil_faiz','Devlet Tahvili Kanunu','30 gunluk tahvil faiz getirisi yuzdesi',0::numeric,30::numeric),
 (29,'vergi_affi','Vergi Affi Kanunu','Vergi borcu ceza affi yuzdesi',0::numeric,100::numeric),
 (33,'yeni_parti_destek','Yeni Parti Kurulus Destegi','Yeni parti kurulusunda tek seferlik destek TL',0::numeric,50000::numeric),
 (41,'parti_yardim_carpan','Partilere Hazine Yardimi','Mevcut parti yardimina uygulanacak oran yuzdesi',0::numeric,200::numeric),
 (51,'belediye_payi','Belediyelere Vergi Payi','Merkezi vergi gelirinden belediye payi yuzdesi',2::numeric,30::numeric)
 ) x(no,kod,baslik,acik,mn,mx) where x.no=p_no;
 if kod is null then raise exception 'Gecersiz yasa numarasi'; end if;
 if p_deger is null or p_deger<mn or p_deger>mx then raise exception 'Deger % ile % arasinda olmali',mn,mx; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',baslik,acik||'. Onerilen deger: '||p_deger||'. Kabul edilirse oyun ekonomisine uygulanir.',
 jsonb_build_object('ekonomi_yasa',kod,'deger',p_deger,'numara',p_no),
 p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama) returning id into yeni;
 perform oyun.olay('meclis',format('%s Meclise ekonomi yasa teklifi sundu: %s',p.kad,baslik),null,p.parti_id,t);
 return jsonb_build_object('id',yeni);
end $$;
revoke all on function public.ekonomi_yasa_teklif(int,numeric) from public,anon;
grant execute on function public.ekonomi_yasa_teklif(int,numeric) to authenticated;

create or replace function public.ekonomi_yasa_durum()
returns jsonb language sql security definer set search_path='' as $$
 select coalesce(jsonb_object_agg(kod,deger),'{}'::jsonb) from oyun.yasa_ekonomi_ayar
$$;
revoke all on function public.ekonomi_yasa_durum() from public,anon;
grant execute on function public.ekonomi_yasa_durum() to authenticated;
