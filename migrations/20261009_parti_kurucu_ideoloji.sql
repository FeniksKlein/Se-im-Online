-- 2026-10-09 | Seçmen ilk görevleri, ideolojiler, davetli kurucular kurulu
-- Canlı verileri sıfırlamaz. Eski partiler korunur. Tekrar çalıştırılabilir.
begin;
alter table oyun.ayarlar add column if not exists ilk_gorev_oy_bas timestamptz not null default now();
alter table oyun.parti_kimlik add column if not exists ideolojiler text[] not null default '{}';

create or replace function oyun.ideoloji_gecerli(v text[]) returns boolean
language sql immutable set search_path = '' as $$
 select v is not null and cardinality(v) between 1 and 3
 and not exists (select 1 from unnest(v) x where x not in
 ('merkez_sag','merkez_sol','sosyal_demokrat','muhafazakar','liberal','milliyetci','turk_milliyetcisi','sosyalist','kemalist','islamci','demokratik_sol','yesil_siyaset','populist','karma'))
 and cardinality(v)=(select count(distinct x) from unnest(v) x)
$$;
create table if not exists oyun.kurucu_basvuru(
 id bigint generated always as identity primary key,
 kurucu uuid not null references oyun.profiller(id),
 ad text not null, kisa text not null, renk text not null, amblem text not null,
 ideolojiler text[] not null check (oyun.ideoloji_gecerli(ideolojiler)),
 bas timestamptz not null default now(), bit timestamptz not null,
 durum text not null default 'bekliyor' check(durum in ('bekliyor','kuruldu','iptal','suresi_doldu')),
 parti_id bigint references oyun.partiler(id)
);
create unique index if not exists kurucu_aktif_tek on oyun.kurucu_basvuru(kurucu) where durum='bekliyor';
create unique index if not exists kurucu_aktif_ad on oyun.kurucu_basvuru(lower(ad)) where durum='bekliyor';
create unique index if not exists kurucu_aktif_kisa on oyun.kurucu_basvuru(lower(kisa)) where durum='bekliyor';
create table if not exists oyun.kurucu_davet(
 basvuru_id bigint not null references oyun.kurucu_basvuru(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 durum text not null default 'bekliyor' check (durum in ('bekliyor','evet','hayir')),
 zaman timestamptz not null default now(), cevap_at timestamptz,
 primary key (basvuru_id,user_id)
);
create index if not exists kurucu_davet_user on oyun.kurucu_davet(user_id,durum);
create table if not exists oyun.ideoloji_teklif(
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id) on delete cascade,
 kurucu uuid not null references oyun.profiller(id),
 ideolojiler text[] not null check (oyun.ideoloji_gecerli(ideolojiler)),
 bas timestamptz not null default now(), bit timestamptz not null,
 durum text not null default 'acik' check (durum in ('acik','kabul','red'))
);
create table if not exists oyun.ideoloji_secmen(
 teklif_id bigint not null references oyun.ideoloji_teklif(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 oy boolean,
 zaman timestamptz,
 primary key (teklif_id,user_id)
);
do $$ declare t text; begin
 foreach t in array array['kurucu_basvuru','kurucu_davet','ideoloji_teklif','ideoloji_secmen'] loop
  execute format('alter table oyun.%I enable row level security', t);
  execute format('revoke all on oyun.%I from public, anon, authenticated', t);
 end loop;
end $$;

-- Eski hesaplar etkilenmez; bu güncellemeden sonra gelenler ilk 3 görevi tamamlar.
create or replace function oyun.ilk_uc_gorev(p oyun.profiller)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object(
  'gerekli',p.olusturma >= (select ilk_gorev_oy_bas from oyun.ayarlar where id=1),
  'maas', exists (select 1 from oyun.hesap_hareket h where h.user_id=p.id and h.tur='maas'),
  'kimlik', exists (select 1 from oyun.oyuncu_kimlik k where k.user_id=p.id and k.avatar is not null and nullif(btrim(coalesce(k.biyografi,'')),'') is not null),
  'kahve', exists (select 1 from oyun.mesajlar m where m.user_id=p.id and m.kanal like 'il:%'))
$$;
create or replace function oyun.ilk_uc_gorev_engel(p oyun.profiller)
returns text language plpgsql stable set search_path='' as $$
declare d jsonb := oyun.ilk_uc_gorev(p); eksik text[] := '{}';
begin
 if not (d->>'gerekli')::boolean then return null; end if;
 if not (d->>'maas')::boolean then eksik:=array_append(eksik,'ilk maaşını toplamak'); end if;
 if not (d->>'kimlik')::boolean then eksik:=array_append(eksik,'portre ve biyografi hazırlamak'); end if;
 if not (d->>'kahve')::boolean then eksik:=array_append(eksik,'il kahvesine mesaj yazmak'); end if;
 if cardinality(eksik)>0 then return 'İlk oyun için 3 başlangıç görevini tamamla: '||array_to_string(eksik,', ')||'.'; end if;
 return null;
end $$;

-- Ana seçim ön koşulu: sunucuda denetlenir, istemci tarafından atlanamaz.
create or replace function oyun.oy_engeli(p oyun.profiller,s oyun.secimler)
returns text language sql stable set search_path='' as $$
 select coalesce(
  oyun.uyari(p,s.oy_bas),
  oyun.ilk_uc_gorev_engel(p),
  case when s.ara and s.hedef_il_id is not null and p.il_id is distinct from s.hedef_il_id
    then format('Bu olağanüstü seçim yalnızca %s ili içindir.',(select ad from oyun.iller where id=s.hedef_il_id)) end,
  case when s.ara and s.hedef_parti_id is not null and p.parti_id is distinct from s.hedef_parti_id
    then format('Bu olağanüstü kurultay yalnızca %s üyeleri içindir.',(select kisa from oyun.partiler where id=s.hedef_parti_id)) end,
  case when s.tur in ('mv','bel','mv_on','bel_on') and p.son_il_degis is not null
    and p.il_at > s.oy_bas - make_interval(days=>(select oy_il_gun from oyun.ayarlar where id=1))
    then format('Seçmen kütüğü: bu ilde en az %s gün kayıtlı olmalısın.',(select oy_il_gun from oyun.ayarlar where id=1)) end,
  case when s.tur in ('mv_on','bel_on','kurultay','cb_on') then
    case when p.parti_id is null then 'Bu parti içi seçimde parti üyesi olmalısın.'
      when p.parti_at > s.basvuru_bas then 'Başvurular açılmadan önce parti üyesi olmalısın.' end end)
$$;

create or replace function public.ilk_adimlar() returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); d jsonb:=oyun.ilk_uc_gorev(p); u text;
adimlar jsonb;
begin
 u:=coalesce(oyun.uyari(p,t),oyun.ilk_uc_gorev_engel(p));
 adimlar:=jsonb_build_array(
 jsonb_build_object('kod','maas','ad','İlk maaşını topla','tamam',(d->>'maas')::boolean),
 jsonb_build_object('kod','kimlik','ad','Portreni ve kısa biyografini hazırla','tamam',(d->>'kimlik')::boolean),
 jsonb_build_object('kod','parti','ad','Bir partiye katıl','tamam',p.parti_id is not null),
 jsonb_build_object('kod','sohbet','ad','İl kahvesinde kendini tanıt','tamam',(d->>'kahve')::boolean),
 jsonb_build_object('kod','anket','ad','Haftalık siyasi ankete katıl','tamam',exists(select 1 from oyun.haftalik_anket_oy where user_id=p.id)),
 jsonb_build_object('kod','oy','ad','İlk oyunu kullan','tamam',exists(select 1 from oyun.oylar where secmen=p.id),'not',u));
 return jsonb_build_object('adimlar',adimlar,'secmen_karti',u is null,'engel',u,
 'oy_gorevleri',d,'yeni',p.olusturma > t-interval '14 days',
 'bitti',not exists(select 1 from jsonb_array_elements(adimlar) x where not (x->>'tamam')::boolean));
end $$;

-- Herkese açık seçimler için siyasi kimlik listesi; eski eko/toplum alanları korunur.
create or replace function public.parti_kimlikleri() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('parti',oyun.parti_json(pa.id),
  'ideolojiler',coalesce(k.ideolojiler,'{}'::text[]),
  'eko',coalesce(k.eko,0),'toplum',coalesce(k.toplum,0),'belirlendi',k.parti_id is not null,
  'slogan',k.slogan,
  'uye',(select count(*) from oyun.profiller pr where pr.parti_id=pa.id and not pr.yasakli),
  'vekil',(select count(*) from oyun.makamlar m where m.tur='mv' and m.bit is null and m.parti_id=pa.id),
  'gb',oyun.kad(pa.gb)) order by pa.id),'[]'::jsonb)
 from oyun.partiler pa left join oyun.parti_kimlik k on k.parti_id=pa.id where not pa.kapali
$$;

-- Genel başkan tüm mevcut üyelere 48 saatlik ideoloji değişikliği teklifi sunar.
create or replace function public.ideoloji_teklif_ver(p_ideolojiler text[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); pa oyun.partiler; idd bigint; t timestamptz:=oyun.simdi(); k uuid;
begin
 if not oyun.ideoloji_gecerli(p_ideolojiler) then raise exception 'En az 1, en çok 3 farklı ideoloji seçmelisin.'; end if;
 select * into pa from oyun.partiler where gb=p.id and not kapali and kurulus_bit is null for update;
 if pa.id is null then raise exception 'Yalnızca aktif partinin genel başkanı ideoloji oylaması açabilir.'; end if;
 if exists(select 1 from oyun.ideoloji_teklif where parti_id=pa.id and durum='acik' and bit>t) then
  raise exception 'Partinin devam eden bir ideoloji oylaması var.'; end if;
 if coalesce((select ideolojiler from oyun.parti_kimlik where parti_id=pa.id),'{}'::text[])=p_ideolojiler then
  raise exception 'Bu ideolojiler partide zaten geçerli.'; end if;
 insert into oyun.ideoloji_teklif(parti_id,kurucu,ideolojiler,bas,bit)
  values(pa.id,p.id,p_ideolojiler,t,t+interval '48 hours') returning id into idd;
 insert into oyun.ideoloji_secmen(teklif_id,user_id)
  select idd,id from oyun.profiller where parti_id=pa.id and not yasakli;
 for k in select user_id from oyun.ideoloji_secmen where teklif_id=idd loop
  perform oyun.bildir(k,format('%s genel başkanı parti ideolojilerini oylamaya sundu. 48 saat içinde oyunu kullan.',pa.ad),t);
 end loop;
 return jsonb_build_object('teklif_id',idd);
end $$;
create or replace function public.ideoloji_oyla(p_teklif bigint,p_evet boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); o oyun.ideoloji_teklif; uyeler int; evetler int; hayirlar int; t timestamptz:=oyun.simdi();
begin
 select * into o from oyun.ideoloji_teklif where id=p_teklif for update;
 if o.id is null or o.durum<>'acik' or o.bit<=t then raise exception 'Bu oylama kapanmış.'; end if;
 if p.parti_id is distinct from o.parti_id then raise exception 'Yalnızca parti üyesi oy kullanabilir.'; end if;
 update oyun.ideoloji_secmen set oy=p_evet,zaman=t
  where teklif_id=o.id and user_id=p.id and oy is null;
 if not found then raise exception 'Bu oylamada oy hakkın yok veya oyunu zaten kullandın.'; end if;
 select count(*),count(*) filter(where oy is true),count(*) filter(where oy is false)
 into uyeler,evetler,hayirlar from oyun.ideoloji_secmen where teklif_id=o.id;
 if evetler>uyeler/2 then
  insert into oyun.parti_kimlik(parti_id,ideolojiler,guncelleme)
   values(o.parti_id,o.ideolojiler,t)
   on conflict(parti_id) do update set ideolojiler=excluded.ideolojiler,guncelleme=t;
  update oyun.ideoloji_teklif set durum='kabul' where id=o.id;
  perform oyun.olay('parti',format('%s üyelerinin çoğunluk oyuyla yeni ideolojilerini kabul etti.',(select ad from oyun.partiler where id=o.parti_id)),null,o.parti_id,t);
 elsif hayirlar>=ceil(uyeler/2.0) then
  update oyun.ideoloji_teklif set durum='red' where id=o.id;
 end if;
 return jsonb_build_object('evet',evetler,'hayir',hayirlar,'gerekli',floor(uyeler/2.0)+1,'durum',(select durum from oyun.ideoloji_teklif where id=o.id));
end $$;
create or replace function public.ideoloji_durum(p_parti bigint) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
 'ideolojiler',coalesce((select ideolojiler from oyun.parti_kimlik where parti_id=p_parti),'{}'::text[]),
 'teklif',(select jsonb_build_object('id',o.id,'ideolojiler',o.ideolojiler,'bit',o.bit,
   'gerekli',(select floor(count(*)/2.0)::int+1 from oyun.ideoloji_secmen v where v.teklif_id=o.id),
   'evet',(select count(*) from oyun.ideoloji_secmen v where v.teklif_id=o.id and v.oy=true),
   'hayir',(select count(*) from oyun.ideoloji_secmen v where v.teklif_id=o.id and v.oy=false),
   'benim_oyum',(select v.oy from oyun.ideoloji_secmen v where v.teklif_id=o.id and v.user_id=auth.uid()),
   'oy_hakkim',exists(select 1 from oyun.ideoloji_secmen v where v.teklif_id=o.id and v.user_id=auth.uid()),
   'durum',case when o.durum='acik' and o.bit<=oyun.simdi() then 'red' else o.durum end)
  from oyun.ideoloji_teklif o where o.parti_id=p_parti order by o.id desc limit 1))
$$;

-- Doğrudan eski parti_kur yolunu kapat: davetsiz kuruluş mümkün olmasın.
create or replace function public.parti_kur(p_ad text,p_kisa text,p_renk text,p_amblem text)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 raise exception 'Yeni parti kurmak için önce kurucu davetleri gönder, en az 3 onay al.';
end $$;

create or replace function public.parti_kur_baslat(p_ad text,p_kisa text,p_renk text,p_amblem text,
  p_ideolojiler text[],p_kadlar text[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); idd bigint; nick text; hedef oyun.profiller; sayi int:=0;
begin
 p_ad:=btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
 p_kisa:=upper(btrim(coalesce(p_kisa,'')));
 if length(p_ad) not between 5 and 40 or p_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then raise exception 'Parti adı 5-40 harften oluşmalı.'; end if;
 if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' or p_renk !~ '^#[0-9a-fA-F]{6}$' or p_amblem !~ '^[a-z_]{2,20}$' then raise exception 'Kısaltma, renk veya amblem geçersiz.'; end if;
 if not oyun.ideoloji_gecerli(p_ideolojiler) then raise exception 'En az 1 en çok 3 ideoloji seç.'; end if;
 if coalesce(cardinality(p_kadlar),0) not between 3 and 20 then raise exception 'En az 3, en çok 20 farklı kurucu adayı davet et.'; end if;
 if oyun.yasakli_ad(p_ad) or oyun.yasakli_kisa(p_kisa) then raise exception 'Gerçek bir partiyi çağrıştıran ad kullanılamaz.'; end if;
 if exists(select 1 from oyun.partiler where not kapali and (lower(ad)=lower(p_ad) or lower(kisa)=lower(p_kisa))) then raise exception 'Parti adı veya kısaltması kullanımda.'; end if;
 if oyun.uyari(p,t) is not null then raise exception 'Parti kurma şartı: %',oyun.uyari(p,t); end if;
 if oyun.kidem_puani(p.id)<(select parti_kurucu_kidem from oyun.ayarlar where id=1) then raise exception 'Parti kurma kıdemin yetersiz.'; end if;
 if p.son_parti_kur is not null and p.son_parti_kur+make_interval(days=>(select parti_kur_gun from oyun.ayarlar where id=1))>t then
   raise exception 'Yeni parti kurmak için bekleme süren dolmalı.'; end if;
 if (select para from oyun.cuzdanim(p.id))<greatest(25000,oyun.parti_kur_ucreti()) then raise exception 'Parti için en az % ₺ sermaye gerekli.', oyun.tl(greatest(25000,oyun.parti_kur_ucreti())); end if;
 insert into oyun.kurucu_basvuru(kurucu,ad,kisa,renk,amblem,ideolojiler,bas,bit)
 values(p.id,p_ad,p_kisa,lower(p_renk),p_amblem,p_ideolojiler,t,t+interval '7 days')
 returning id into idd;
 foreach nick in array p_kadlar loop
  nick:=btrim(nick);
  select * into hedef from oyun.profiller where lower(kad)=lower(nick) and not yasakli;
  if hedef.id is null or hedef.id=p.id then raise exception 'Kurucu adayı bulunamadı veya kendini davet ettin: %',nick; end if;
  insert into oyun.kurucu_davet(basvuru_id,user_id,zaman) values(idd,hedef.id,t)
   on conflict do nothing;
  if found then
   sayi:=sayi+1;
   perform oyun.bildir(hedef.id,format('%s seni %s (%s) partisinin kurucular kuruluna davet etti. Partiler > Kurucu davetleri ekranından evet/hayır yanıtla. Onay verirsen kuruluşta partiye katılırsın.',p.kad,p_ad,p_kisa),t);
  end if;
 end loop;
 if sayi<3 then raise exception 'En az 3 farklı kayıtlı oyuncuyu kurucular kuruluna davet etmelisin.'; end if;
 return jsonb_build_object('basvuru_id',idd,'davet',sayi,'gerekli',3,'sermaye',greatest(25000,oyun.parti_kur_ucreti()));
end $$;
create or replace function public.kurucu_davet_yanit(p_basvuru bigint,p_kabul boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); b oyun.kurucu_basvuru; n int;
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru for update;
 if b.id is null or b.durum<>'bekliyor' or b.bit<=oyun.simdi() then raise exception 'Bu kurucu daveti geçerli değil.'; end if;
 update oyun.kurucu_davet set durum=case when p_kabul then 'evet' else 'hayir' end,cevap_at=oyun.simdi()
 where basvuru_id=b.id and user_id=p.id and durum='bekliyor';
 if not found then raise exception 'Davetin yok veya daha önce yanıtladın.'; end if;
 select count(*) into n from oyun.kurucu_davet where basvuru_id=b.id and durum='evet';
 perform oyun.bildir(b.kurucu,format('%s kurucu davetine %s yanıtı verdi. Onaylar: %s/3.',p.kad,case when p_kabul then 'EVET' else 'HAYIR' end,n));
 return jsonb_build_object('kabul',p_kabul,'onay',n,'gerekli',3);
end $$;
create or replace function public.kurucu_davetlerim() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
  'gelen',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'ad',b.ad,'kisa',b.kisa,
    'kurucu',p.kad,'ideolojiler',b.ideolojiler,'bit',b.bit,'durum',d.durum) order by b.id desc)
    from oyun.kurucu_davet d join oyun.kurucu_basvuru b on b.id=d.basvuru_id
    join oyun.profiller p on p.id=b.kurucu
    where d.user_id=auth.uid() and d.durum='bekliyor' and b.durum='bekliyor' and b.bit>oyun.simdi()),'[]'::jsonb),
  'basvurum',(select jsonb_build_object('id',b.id,'ad',b.ad,'kisa',b.kisa,'bit',b.bit,
    'ideolojiler',b.ideolojiler,'onay',(select count(*) from oyun.kurucu_davet d where d.basvuru_id=b.id and d.durum='evet'),
    'davetler',(select coalesce(jsonb_agg(jsonb_build_object('kad',p.kad,'durum',d.durum) order by p.kad),'[]'::jsonb)
      from oyun.kurucu_davet d join oyun.profiller p on p.id=d.user_id where d.basvuru_id=b.id))
   from oyun.kurucu_basvuru b where b.kurucu=auth.uid() and b.durum='bekliyor' and b.bit>oyun.simdi() order by b.id desc limit 1))
$$;
create or replace function public.parti_kur_iptal(p_basvuru bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim();
begin
 update oyun.kurucu_basvuru set durum='iptal' where id=p_basvuru and kurucu=p.id and durum='bekliyor';
 if not found then raise exception 'İptal edilecek başvuru yok.'; end if;
 return jsonb_build_object('tamam',true);
end $$;
create or replace function public.parti_kur_tamamla(p_basvuru bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); b oyun.kurucu_basvuru; t timestamptz:=oyun.simdi();
 n int; yeni bigint; ucret numeric; uy uuid;
begin
 select * into b from oyun.kurucu_basvuru where id=p_basvuru for update;
 if b.id is null or b.kurucu is distinct from p.id or b.durum<>'bekliyor' or b.bit<=t then raise exception 'Aktif kurucu başvurun yok.'; end if;
 select count(*) into n from oyun.kurucu_davet where basvuru_id=b.id and durum='evet';
 if n<3 then raise exception 'Parti için senden başka en az 3 kişinin onayı gerekli. Şu an: %.',n; end if;
 if oyun.uyari(p,t) is not null then raise exception 'Kurucu şartı: %',oyun.uyari(p,t); end if;
 if p.son_parti_kur is not null and p.son_parti_kur+make_interval(days=>(select parti_kur_gun from oyun.ayarlar where id=1))>t then raise exception 'Parti kurma bekleme süren dolmadı.'; end if;
 if exists(select 1 from oyun.partiler where not kapali and (lower(ad)=lower(b.ad) or lower(kisa)=lower(b.kisa))) then raise exception 'Bu isim veya kısaltma artık kullanılıyor.'; end if;
 ucret:=greatest(25000,oyun.parti_kur_ucreti());
 if (select para from oyun.cuzdanim(p.id))<ucret then raise exception 'Partiyi kurmak için % ₺ nakit sermaye gerekiyor.',oyun.tl(ucret); end if;
 -- Davet verilen onay, kuruluşta partiye katılma iznini içerir.
 perform oyun.para_islem(p.id,-ucret,'parti_kur',format('%s kuruluş sermayesi',b.ad),t);
 perform oyun._ayril(p.id,t);
 insert into oyun.partiler(ad,kisa,renk,amblem,gb,kurucu,kurulus,kurulus_bit)
 values(b.ad,b.kisa,b.renk,b.amblem,p.id,p.id,t,null) returning id into yeni;
 perform oyun.genel_merkez_ac(yeni,p,ucret,t);
 update oyun.profiller set parti_id=yeni,parti_at=t,son_parti_kur=t where id=p.id;
 for uy in select user_id from oyun.kurucu_davet where basvuru_id=b.id and durum='evet' loop
  perform oyun._ayril(uy,t);
  update oyun.profiller set parti_id=yeni,parti_at=t where id=uy and not yasakli;
  perform oyun.bildir(uy,format('%s kuruluşuna verdiğin onay kabul edildi. Kurucular kuruluna katıldın!',b.ad),t);
 end loop;
 insert into oyun.parti_kimlik(parti_id,ideolojiler,guncelleme) values(yeni,b.ideolojiler,t);
 update oyun.kurucu_basvuru set durum='kuruldu',parti_id=yeni where id=b.id;
 perform oyun.olay('parti',format('%s (%s), %s kurucunun onayı ve %s ₺ sermayeyle kuruldu.',b.ad,b.kisa,n+1,oyun.tl(ucret)),p.il_id,yeni,t);
 return jsonb_build_object('parti_id',yeni,'kurucu_sayi',n+1,'sermaye',ucret);
end $$;
do $$ declare s text; begin
 foreach s in array array[
 'ilk_adimlar()','parti_kimlikleri()',
 'ideoloji_teklif_ver(text[])','ideoloji_oyla(bigint,boolean)','ideoloji_durum(bigint)',
 'parti_kur_baslat(text,text,text,text,text[],text[])','kurucu_davet_yanit(bigint,boolean)',
 'kurucu_davetlerim()','parti_kur_iptal(bigint)','parti_kur_tamamla(bigint)'] loop
  execute format('revoke all on function public.%s from public,anon',s);
  execute format('grant execute on function public.%s to authenticated',s);
 end loop;
end $$;
commit;