-- =====================================================================
-- 18) SİYASET + EKONOMİ GENİŞLETME (2026.10.07-6)
-- İl başkanlığı, saatlik mevduat faizi, parti adı/tüzüğü,
-- borç affı, doğrudan vergi kanunu ve ekonomik etkiler.
-- =====================================================================

-- ---------- PARTİ ADI + TÜZÜK ----------
alter table oyun.partiler add column if not exists son_ad_degis timestamptz;
alter table oyun.partiler add column if not exists tuzuk text;
alter table oyun.partiler add column if not exists tuzuk_at timestamptz;

create table if not exists oyun.parti_ad_gecmis(
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  eski_ad text not null,
  eski_kisa text not null,
  yeni_ad text not null,
  yeni_kisa text not null,
  degistiren uuid references oyun.profiller(id) on delete set null,
  zaman timestamptz not null
);
create index if not exists parti_ad_gecmis_idx on oyun.parti_ad_gecmis(parti_id,zaman desc);

create table if not exists oyun.parti_tuzuk_teklifleri(
  id bigserial primary key,
  parti_id bigint not null references oyun.partiler(id) on delete cascade,
  baslik text not null,
  metin text not null,
  teklif_eden uuid references oyun.profiller(id) on delete set null,
  bas timestamptz not null,
  bit timestamptz not null,
  durum text not null default 'oylama'
    check (durum in ('oylama','kabul','ret')),
  evet int not null default 0,
  hayir int not null default 0,
  katilim int not null default 0,
  sonuc_at timestamptz
);
create index if not exists parti_tuzuk_aktif_idx
  on oyun.parti_tuzuk_teklifleri(parti_id,durum,bit);

create table if not exists oyun.parti_tuzuk_oylari(
  teklif_id bigint not null references oyun.parti_tuzuk_teklifleri(id) on delete cascade,
  user_id uuid not null references oyun.profiller(id) on delete cascade,
  oy text not null check (oy in ('evet','hayir')),
  zaman timestamptz not null,
  primary key(teklif_id,user_id)
);

create or replace function public.parti_ad_degistir(p_ad text,p_kisa text)
returns jsonb
language plpgsql security definer
set search_path=''
as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  eski_ad text;
  eski_kisa text;
begin
  select * into pa
  from oyun.partiler
  where id=p.parti_id and not kapali
  for update;

  if pa.id is null or pa.gb is distinct from p.id then
    raise exception 'Partinin adını yalnızca genel başkan değiştirebilir.';
  end if;
  if pa.son_ad_degis is not null and pa.son_ad_degis + interval '7 days' > t then
    raise exception 'Parti adı 7 günde bir değiştirilebilir. En erken %.',
      to_char((pa.son_ad_degis + interval '7 days') at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI');
  end if;

  p_ad := btrim(regexp_replace(coalesce(p_ad,''),'\s+',' ','g'));
  p_kisa := upper(btrim(coalesce(p_kisa,'')));

  if length(p_ad)<5 or length(p_ad)>40 then raise exception 'Parti adı 5-40 karakter olmalı.'; end if;
  if p_ad !~ '^[A-Za-zçğıöşüÇĞİÖŞÜâîûÂÎÛ'' .-]+$' then raise exception 'Parti adında yalnızca harf kullanılabilir.'; end if;
  if p_kisa !~ '^[A-ZÇĞİÖŞÜ]{2,6}$' then raise exception 'Kısa ad 2-6 büyük harf olmalı.'; end if;
  if oyun.yasakli_ad(p_ad) or oyun.yasakli_kisa(p_kisa) then raise exception 'Gerçek bir partiyi çağrıştıran veya uygunsuz adlar kullanılamaz.'; end if;
  if exists(select 1 from oyun.partiler where id<>pa.id and not kapali and lower(ad)=lower(p_ad)) then raise exception 'Bu adla bir parti zaten var.'; end if;
  if exists(select 1 from oyun.partiler where id<>pa.id and not kapali and lower(kisa)=lower(p_kisa)) then raise exception 'Bu kısa ad kullanılıyor.'; end if;
  if lower(pa.ad)=lower(p_ad) and lower(pa.kisa)=lower(p_kisa) then raise exception 'Partinin adı zaten bu.'; end if;

  eski_ad := pa.ad; eski_kisa := pa.kisa;
  insert into oyun.parti_ad_gecmis(parti_id,eski_ad,eski_kisa,yeni_ad,yeni_kisa,degistiren,zaman)
  values(pa.id,eski_ad,eski_kisa,p_ad,p_kisa,p.id,t);

  update oyun.partiler set ad=p_ad,kisa=p_kisa,son_ad_degis=t where id=pa.id;

  insert into oyun.bildirimler(user_id,zaman,metin)
  select id,t,format('%s (%s) partisinin adı %s (%s) olarak değiştirildi.',eski_ad,eski_kisa,p_ad,p_kisa)
  from oyun.profiller where parti_id=pa.id and id<>p.id;

  perform oyun.olay('parti',format('%s (%s), adını %s (%s) olarak değiştirdi.',eski_ad,eski_kisa,p_ad,p_kisa),null,pa.id,t);
  return public.parti_detay(pa.id);
end $$;

create or replace function oyun.parti_tuzuk_tick(t timestamptz)
returns void language plpgsql
set search_path=''
as $$
declare x oyun.parti_tuzuk_teklifleri; e int; h int; k int; kabul boolean;
begin
  for x in
    select * from oyun.parti_tuzuk_teklifleri
    where durum='oylama' and bit<=t
    order by id for update
  loop
    select count(*) filter(where oy='evet'),
           count(*) filter(where oy='hayir'),
           count(*)
      into e,h,k
    from oyun.parti_tuzuk_oylari
    where teklif_id=x.id;

    kabul := e>h and e>0;
    update oyun.parti_tuzuk_teklifleri
       set durum=case when kabul then 'kabul' else 'ret' end,
           evet=e,hayir=h,katilim=k,sonuc_at=t
     where id=x.id;

    if kabul then
      update oyun.partiler set tuzuk=x.metin,tuzuk_at=t where id=x.parti_id;
    end if;

    insert into oyun.bildirimler(user_id,zaman,metin)
    select id,t,format('Parti tüzük oylaması sonuçlandı: %s — %s Evet, %s Hayır.',
      case when kabul then 'KABUL' else 'RET' end,e,h)
    from oyun.profiller where parti_id=x.parti_id;

    perform oyun.olay('parti',format('%s tüzük oylaması sonuçlandı: %s (%s Evet / %s Hayır).',
      (select kisa from oyun.partiler where id=x.parti_id),
      case when kabul then 'kabul' else 'ret' end,e,h),null,x.parti_id,t);
  end loop;
end $$;

create or replace function public.parti_tuzuk(p_parti bigint)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pa oyun.partiler;
begin
  perform oyun.parti_tuzuk_tick(t);
  select * into pa from oyun.partiler where id=p_parti and not kapali;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;

  return jsonb_build_object(
    'parti_id',pa.id,'parti',oyun.parti_json(pa.id),'mevcut',pa.tuzuk,'mevcut_at',pa.tuzuk_at,
    'uyeyim',p.parti_id=pa.id,'gb_mi',pa.gb=p.id,
    'aktif',(select jsonb_build_object(
      'id',x.id,'baslik',x.baslik,'metin',x.metin,'bas',x.bas,'bit',x.bit,'durum',x.durum,
      'katilim',(select count(*) from oyun.parti_tuzuk_oylari o where o.teklif_id=x.id),
      'uygun',(p.parti_id=x.parti_id and p.parti_at<=x.bas),
      'benim_oy',(select oy from oyun.parti_tuzuk_oylari o where o.teklif_id=x.id and o.user_id=p.id),
      'uye_sayisi',(select count(*) from oyun.profiller pr where pr.parti_id=x.parti_id and pr.parti_at<=x.bas and not pr.yasakli)
    ) from oyun.parti_tuzuk_teklifleri x where x.parti_id=pa.id and x.durum='oylama' order by x.id desc limit 1),
    'gecmis',coalesce((select jsonb_agg(jsonb_build_object(
      'id',x.id,'baslik',x.baslik,'durum',x.durum,'evet',x.evet,'hayir',x.hayir,'katilim',x.katilim,'sonuc_at',x.sonuc_at
    ) order by x.id desc) from (select * from oyun.parti_tuzuk_teklifleri where parti_id=pa.id and durum<>'oylama' order by id desc limit 10) x),'[]'::jsonb)
  );
end $$;

create or replace function public.parti_tuzuk_teklif(p_baslik text,p_metin text)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pa oyun.partiler; b text; m text;
begin
  perform oyun.parti_tuzuk_tick(t);
  select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Tüzük teklifini yalnızca genel başkan üyelerin oyuna sunabilir.'; end if;
  if exists(select 1 from oyun.parti_tuzuk_teklifleri where parti_id=pa.id and durum='oylama') then raise exception 'Partide zaten devam eden bir tüzük oylaması var.'; end if;

  b:=btrim(coalesce(p_baslik,''));
  if length(b)<5 or length(b)>100 then raise exception 'Tüzük başlığı 5-100 karakter olmalı.'; end if;
  if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
  m:=oyun.metin_temizle(p_metin,6000);
  if length(m)<50 then raise exception 'Parti tüzüğü en az 50 karakter olmalı.'; end if;

  insert into oyun.parti_tuzuk_teklifleri(parti_id,baslik,metin,teklif_eden,bas,bit)
  values(pa.id,b,m,p.id,t,t+interval '24 hours');

  insert into oyun.bildirimler(user_id,zaman,metin)
  select id,t,format('%s Genel Başkanı yeni parti tüzüğünü oylamaya sundu. Oylama 24 saat açık.',pa.kisa)
  from oyun.profiller where parti_id=pa.id and id<>p.id and parti_at<=t;

  perform oyun.olay('parti',format('%s yeni tüzük teklifini üyelerin oyuna sundu.',pa.kisa),null,pa.id,t);
  return public.parti_tuzuk(pa.id);
end $$;

create or replace function public.parti_tuzuk_oyla(p_teklif bigint,p_oy text)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); x oyun.parti_tuzuk_teklifleri;
begin
  perform oyun.parti_tuzuk_tick(t);
  select * into x from oyun.parti_tuzuk_teklifleri where id=p_teklif for update;
  if x.id is null or x.durum<>'oylama' or t<x.bas or t>=x.bit then raise exception 'Bu tüzük oylaması açık değil.'; end if;
  if p.parti_id is distinct from x.parti_id or p.parti_at>x.bas then raise exception 'Bu tüzük oylamasında oy hakkın yok.'; end if;
  if p_oy not in ('evet','hayir') then raise exception 'Oy Evet veya Hayır olmalı.'; end if;

  insert into oyun.parti_tuzuk_oylari(teklif_id,user_id,oy,zaman)
  values(x.id,p.id,p_oy,t)
  on conflict(teklif_id,user_id) do update set oy=excluded.oy,zaman=excluded.zaman;

  return public.parti_tuzuk(x.parti_id);
end $$;

-- ---------- PARTİ İL BAŞKANLIĞI ----------
-- Mevcut parti_teskilat_gorev kaydı İl Başkanlığı olarak kullanılır.
-- Bu görev makamlar/roller tablosuna eklenmez; dolayısıyla milletvekilliğiyle çakışmaz.
create or replace function public.teskilat_gorev_ver(p_il integer,p_kad text)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); h oyun.profiller; pa oyun.partiler; t timestamptz:=oyun.simdi(); ilad text;
begin
  select * into pa from oyun.partiler where id=p.parti_id and not kapali;
  if pa.id is null or pa.gb is distinct from p.id then raise exception 'Parti İl Başkanını yalnızca genel başkan atayabilir.'; end if;

  h:=oyun.profil_bul(p_kad);
  if h.parti_id is distinct from pa.id then raise exception 'Yalnızca kendi partinin üyesini İl Başkanı yapabilirsin.'; end if;
  if h.il_id is distinct from p_il::smallint then raise exception 'İl Başkanı, görev yapacağı ilde kayıtlı olmalı.'; end if;

  select ad into ilad from oyun.iller where id=p_il;
  if ilad is null then raise exception 'Geçersiz il.'; end if;

  insert into oyun.parti_teskilat_gorev(parti_id,il_id,user_id,atayan,atama,aktif)
  values(pa.id,p_il,h.id,p.id,t,true)
  on conflict(parti_id,il_id) do update
    set user_id=excluded.user_id,atayan=excluded.atayan,atama=excluded.atama,aktif=true;

  perform oyun.bildir(h.id,format(
    '%s Genel Başkanı %s seni %s Parti İl Başkanı yaptı. Milletvekilliği bu görevle birlikte yürütülebilir. İl teşkilatı henüz açılmadıysa kuruluş bedelini kendi cüzdanından ödeyebilirsin.',
    pa.kisa,p.kad,ilad),t);

  return oyun.teskilat_json(pa.id,p);
end $$;

-- ---------- BANKA: SAATLİK FAİZ ----------
update oyun.ayarlar set banka_reel_faiz=greatest(banka_reel_faiz,12) where id=1;

create or replace function oyun.banka_oranlar()
returns jsonb language sql stable
set search_path=''
as $$
  with x as (
    select greatest(15,round(u.enflasyon+a.banka_reel_faiz,1)) py
    from oyun.ulke u, oyun.ayarlar a where u.id=1 and a.id=1
  )
  select jsonb_build_object(
    'politika',py,'vadesiz',round(py/12*0.70,2),'vadeli7',round(py/12*1.05,2),
    'vadeli30',round(py/12*1.25,2),'kredi',round(py/12*1.60,2),'gecikme_gunluk',1
  ) from x
$$;

create or replace function oyun.vadesiz_isle(u uuid,t timestamptz)
returns oyun.banka_musteri language plpgsql
set search_path=''
as $$
declare m oyun.banka_musteri:=oyun.musteri(u,t); saat int; oran numeric; f numeric; yeni_son timestamptz;
begin
  saat:=greatest(0,floor(extract(epoch from (t-m.son_faiz))/3600))::int;
  if saat<=0 or m.vadesiz<=0 then return m; end if;

  oran:=(oyun.banka_oranlar()->>'vadesiz')::numeric;
  f:=round(m.vadesiz*oran/100/30/24*saat,4);
  yeni_son:=m.son_faiz+make_interval(hours=>saat);

  update oyun.banka_musteri
     set vadesiz=vadesiz+f,faiz_toplam=faiz_toplam+f,faiz_birikmis=0,son_faiz=yeni_son
   where user_id=u
   returning * into m;

  perform oyun.banka_kayit(u,'vadesiz',f,format('%s saatlik faiz geliri',saat),t);
  return m;
end $$;

create or replace function oyun.vadeli_biriken(v oyun.vadeli,t timestamptz)
returns numeric language sql stable
set search_path=''
as $$
  select round(
    v.anapara*v.oran/100/30/24 *
    least(v.gun*24,greatest(0,floor(extract(epoch from (t-v.acilis))/3600))),
    2
  )
$$;

create or replace function oyun.vadeli_kapat(v oyun.vadeli,t timestamptz)
returns void language plpgsql
set search_path=''
as $$
declare g numeric:=oyun.vadeli_biriken(v,greatest(t,v.vade));
begin
  update oyun.vadeli set durum='vade',getiri=g,kapanis=t where id=v.id and durum='acik';
  if not found then return; end if;

  perform oyun.para_islem(v.user_id,v.anapara+g,'banka',
    format('Vadeli hesap vadesi doldu: %s ₺ anapara + %s ₺ saatlik işleyen faiz',oyun.tl(v.anapara),oyun.tl(g)),t);
  perform oyun.banka_kayit(v.user_id,'vadeli',-(v.anapara+g),
    format('%s günlük vadeli hesap kapandı (faiz %s ₺)',v.gun,oyun.tl(g)),t);
  perform oyun.bildir(v.user_id,format(
    '%s günlük vadeli hesabının vadesi doldu: %s ₺ anapara ve %s ₺ faiz cüzdanına yattı.',
    v.gun,oyun.tl(v.anapara),oyun.tl(g)),t);
end $$;

create or replace function public.vadeli_boz(p_id bigint)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); v oyun.vadeli; g numeric; saat int;
begin
  select * into v from oyun.vadeli where id=p_id and user_id=p.id for update;
  if v.id is null or v.durum<>'acik' then raise exception 'Açık bir vadeli hesap bulunamadı.'; end if;

  saat:=greatest(0,floor(extract(epoch from (t-v.acilis))/3600))::int;
  g:=round(v.anapara*(oyun.banka_oranlar()->>'vadesiz')::numeric/100/30/24*saat,2);

  update oyun.vadeli set durum='bozuldu',getiri=g,kapanis=t where id=v.id;
  perform oyun.para_islem(p.id,v.anapara+g,'banka',
    format('Vadeli hesap bozuldu: %s ₺ anapara + %s ₺ saatlik faiz',oyun.tl(v.anapara),oyun.tl(g)),t);
  perform oyun.banka_kayit(p.id,'vadeli',-(v.anapara+g),'Vadeli hesap vadeden önce bozuldu',t);
  return public.banka();
end $$;

create or replace function oyun.banka_gunluk(g date,t timestamptz)
returns void language plpgsql
set search_path=''
as $$
declare r record; k oyun.krediler; borc numeric; odenen numeric; acik numeric; ceza numeric; gun_bas timestamptz:=oyun.tr_an(g,0);
begin
  for r in
    select id from oyun.krediler
    where durum in ('aktif','takip') and acilis<gun_bas and son_tahsil is distinct from g
    order by id
  loop
    select * into k from oyun.krediler where id=r.id for update;
    borc:=least(k.kalan,k.gecikmis+k.taksit);
    odenen:=oyun.tahsil_et(k.user_id,borc,k.durum='takip','Kredi taksiti ('||to_char(g,'DD.MM')||')',t);
    acik:=borc-odenen;

    if odenen>0 then perform oyun.banka_kayit(k.user_id,'kredi',-odenen,'Taksit tahsil edildi',t); end if;

    if acik>0 then
      ceza:=ceil(acik*0.01);
      update oyun.krediler
         set kalan=kalan-odenen+ceza,gecikmis=acik+ceza,gecikme_gun=gecikme_gun+1,
             hic_gecikmedi=false,son_tahsil=g
       where id=k.id returning * into k;
      update oyun.banka_musteri set kredi_notu=greatest(0,kredi_notu-40) where user_id=k.user_id;
      perform oyun.banka_kayit(k.user_id,'kredi',ceza,'Gecikme faizi',t);

      if k.durum='aktif' and k.gecikme_gun>=3 then
        update oyun.krediler set durum='takip' where id=k.id returning * into k;
        update oyun.banka_musteri set kredi_notu=greatest(0,kredi_notu-250) where user_id=k.user_id;
        perform oyun.kidem_ekle(k.user_id,-5);
        odenen:=oyun.tahsil_et(k.user_id,k.gecikmis,true,'Yasal takip: gecikmiş borç',t);
        if odenen>0 then
          update oyun.krediler
             set kalan=kalan-odenen,gecikmis=greatest(0,gecikmis-odenen)
           where id=k.id returning * into k;
          perform oyun.banka_kayit(k.user_id,'kredi',-odenen,'Takip: hesaplardan tahsil',t);
        end if;
        perform oyun.bildir(k.user_id,format(
          'Kredin 3 gündür ödenmediği için yasal takibe düştü. Kalan borç: %s ₺. Toplanan maaşının yarısına haciz uygulanacak, kıdemin 5 puan düştü; borç bitene kadar para gönderemez, bağış yapamaz, yeni kredi alamazsın.',
          oyun.tl(k.kalan)),t);
        perform oyun.olay('banka',format('%s adlı oyuncunun kredisi yasal takibe düştü.',oyun.kad(k.user_id)),null,null,t);
      elsif k.durum='aktif' then
        perform oyun.bildir(k.user_id,format(
          'Kredi taksitin ödenemedi: %s ₺ gecikmede (%s. gün). Cüzdanına ya da vadesiz hesabına para koy; 3. günde kredin yasal takibe düşer.',
          oyun.tl(k.gecikmis),k.gecikme_gun),t);
      else
        perform oyun.bildir(k.user_id,format('Takipteki kredi borcun: %s ₺. Gecikme faizi işliyor.',oyun.tl(k.kalan)),t);
      end if;
    else
      update oyun.krediler
         set kalan=kalan-odenen,gecikmis=0,gecikme_gun=0,son_tahsil=g
       where id=k.id returning * into k;
    end if;

    if k.kalan<=0 then perform oyun.kredi_kapat(k,t); end if;
  end loop;
  delete from oyun.banka_hareket where zaman<t-interval '90 days';
end $$;

create or replace function oyun.banka_tick(t timestamptz)
returns void language plpgsql
set search_path=''
as $$
declare bugun date:=(t at time zone 'Europe/Istanbul')::date; son date; v oyun.vadeli; r record;
begin
  for r in
    select user_id from oyun.banka_musteri
    where vadesiz>0 and son_faiz<=t-interval '1 hour'
    order by son_faiz limit 1000
  loop
    perform oyun.vadesiz_isle(r.user_id,t);
  end loop;

  for v in
    select * from oyun.vadeli
    where durum='acik' and vade<=t
    order by vade limit 500
  loop
    perform oyun.vadeli_kapat(v,t);
  end loop;

  select banka_son_gun into son from oyun.ayarlar where id=1 for update;
  if son is null then update oyun.ayarlar set banka_son_gun=bugun where id=1; return; end if;
  if son>=bugun then return; end if;

  son:=greatest(son,bugun-31);
  while son<bugun loop
    son:=son+1;
    perform oyun.banka_gunluk(son,t);
  end loop;
  update oyun.ayarlar set banka_son_gun=bugun where id=1;
end $$;

create or replace function public.banka()
returns jsonb language plpgsql security definer
set search_path='oyun','public','pg_temp'
as $$
declare
  p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
  m oyun.banka_musteri; k oyun.krediler; o jsonb:=oyun.banka_oranlar();
  c oyun.cuzdan:=oyun.cuzdanim(p.id); hb numeric; ul oyun.ulke;
begin
  m:=oyun.vadesiz_isle(p.id,t);
  k:=oyun.aktif_kredi(p.id);
  select * into ul from oyun.ulke where id=1;

  hb:=coalesce((select sum(-tutar) from oyun.hesap_hareket
    where user_id=p.id and tur='havale' and tutar<0 and zaman>=oyun.bugun_bas(t)),0);

  return jsonb_build_object(
    'acik',(select banka_acik from oyun.ayarlar where id=1),
    'cuzdan',c.para,'oranlar',o,'enflasyon',round(ul.enflasyon,1),
    'vadesiz',jsonb_build_object(
      'bakiye',round(m.vadesiz,2),'birikmis',0,'faiz_toplam',round(m.faiz_toplam,2),
      'saatlik',round(m.vadesiz*(o->>'vadesiz')::numeric/100/30/24,2),
      'gunluk',round(m.vadesiz*(o->>'vadesiz')::numeric/100/30,2)
    ),
    'vadeliler',coalesce((select jsonb_agg(jsonb_build_object(
      'id',v.id,'anapara',v.anapara,'oran',v.oran,'gun',v.gun,'acilis',v.acilis,'vade',v.vade,'durum',v.durum,
      'getiri',coalesce(v.getiri,round(v.anapara*v.oran/100*v.gun/30)),
      'biriken',case when v.durum='acik' then oyun.vadeli_biriken(v,t) else v.getiri end,
      'saatlik',round(v.anapara*v.oran/100/30/24,2),
      'bozma',round(v.anapara*(o->>'vadesiz')::numeric/100/30/24*greatest(0,floor(extract(epoch from (t-v.acilis))/3600)),2)
    ) order by v.durum<>'acik',v.acilis desc)
      from (select * from oyun.vadeli where user_id=p.id and (durum='acik' or kapanis>t-interval '14 days') order by acilis desc limit 10) v),'[]'::jsonb),
    'kredi',case when k.id is not null then jsonb_build_object(
      'id',k.id,'anapara',k.anapara,'oran',k.oran,'gun',k.gun,'toplam',k.toplam,'taksit',k.taksit,
      'kalan',k.kalan,'gecikmis',k.gecikmis,'gecikme_gun',k.gecikme_gun,'durum',k.durum,'acilis',k.acilis,
      'erken_kapama',oyun.erken_kapama(k),'kalan_gun',ceil(greatest(0,k.kalan-k.gecikmis)/k.taksit)
    ) end,
    'kredi_notu',m.kredi_notu,'not_ad',oyun.not_ad(m.kredi_notu),
    'kredi_oran',oyun.kredi_orani(p.id),'kredi_limit',oyun.kredi_limiti(p.id),
    'kara_liste',case when m.kara_liste>t then m.kara_liste end,
    'kredi_engel',oyun.uyari(p,t),'tavan',oyun.banka_tavani(),'mevduat',oyun.mevduat_toplam(p.id),
    'uyari',oyun.kredi_uyari(p.id),
    'havale',jsonb_build_object('bugun',hb,'tavan',round(ul.asgari*(select havale_sinir from oyun.ayarlar where id=1)),'engel',oyun.uyari(p,t)),
    'hareketler',coalesce((select jsonb_agg(jsonb_build_object(
      'zaman',h.zaman,'hesap',h.hesap,'tutar',h.tutar,'aciklama',h.aciklama
    ) order by h.zaman desc,h.id desc)
      from (select * from oyun.banka_hareket where user_id=p.id order by zaman desc,id desc limit 25) h),'[]'::jsonb)
  );
end $$;

-- ---------- BORÇ AFFI + VERGİ ----------
create table if not exists oyun.borc_aflari(
  id bigserial primary key,
  kaynak text not null check (kaynak in ('kanun','kararname')),
  ref_id bigint not null,
  oran numeric not null check (oran between 10 and 100),
  etkilenen int not null default 0,
  toplam_silinen numeric not null default 0,
  maliyet numeric not null default 0,
  parti_id bigint references oyun.partiler(id) on delete set null,
  yapan uuid references oyun.profiller(id) on delete set null,
  zaman timestamptz not null
);
create index if not exists borc_aflari_zaman_idx on oyun.borc_aflari(zaman desc);

create or replace function oyun.borc_affi_etki(p_oran numeric)
returns jsonb language plpgsql immutable
set search_path=''
as $$
begin
  p_oran:=round(p_oran,1);
  if p_oran<10 or p_oran>100 then raise exception 'Borç affı oranı %%10-%%100 arasında olmalı.'; end if;
  return jsonb_build_object(
    'oran',p_oran,'maliyet',round(p_oran*0.50,2),'enflasyon',round(p_oran*0.025,2),
    'buyume',round(p_oran*0.010,2),'issizlik',round(-p_oran*0.004,2),'memnuniyet',round(p_oran*0.070,2)
  );
end $$;

create or replace function public.borc_affi_onizle(p_oran numeric)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); e jsonb;
begin
  e:=oyun.borc_affi_etki(p_oran);
  return e || jsonb_build_object(
    'borclu_oyuncu',(select count(*) from oyun.krediler where durum in ('aktif','takip') and kalan>0),
    'oyuncu_borcu',round(coalesce((select sum(kalan) from oyun.krediler where durum in ('aktif','takip') and kalan>0),0),2),
    'oyuncu_silinecek',round(coalesce((select sum(kalan)*p_oran/100 from oyun.krediler where durum in ('aktif','takip') and kalan>0),0),2)
  );
end $$;

create or replace function oyun.borc_affi_uygula(
  p_oran numeric,p_kaynak text,p_ref bigint,p_parti bigint,p_yapan uuid,t timestamptz
)
returns jsonb language plpgsql
set search_path=''
as $$
declare k oyun.krediler; once numeric; sonra numeric; sil numeric; toplam numeric:=0; n int:=0; e jsonb;
begin
  e:=oyun.borc_affi_etki(p_oran);
  p_oran:=(e->>'oran')::numeric;
  if p_kaynak not in ('kanun','kararname') then raise exception 'Geçersiz af kaynağı.'; end if;

  for k in
    select * from oyun.krediler where durum in ('aktif','takip') and kalan>0 order by id for update
  loop
    once:=k.kalan;
    sonra:=round(greatest(0,k.kalan*(100-p_oran)/100),2);
    sil:=once-sonra; toplam:=toplam+sil; n:=n+1;

    if sonra<=0.01 then
      update oyun.krediler
         set kalan=0,gecikmis=0,gecikme_gun=0,durum='kapandi',kapanis=t
       where id=k.id;
    else
      update oyun.krediler
         set kalan=sonra,
             gecikmis=round(greatest(0,least(sonra,gecikmis*(100-p_oran)/100)),2),
             gecikme_gun=0,durum='aktif'
       where id=k.id;
    end if;

    update oyun.banka_musteri
       set kredi_notu=least(1900,kredi_notu+least(250,round(p_oran*2)::int)),kara_liste=null
     where user_id=k.user_id;

    perform oyun.banka_kayit(k.user_id,'kredi',-sil,format('Borç affı: borcun %%%s''i silindi',p_oran),t);
    perform oyun.bildir(k.user_id,format(
      'Borç affı yürürlüğe girdi: kredi borcunun %%%s''i silindi. %s ₺ borcun kaldı.',
      p_oran,oyun.tl(sonra)),t);
  end loop;

  perform oyun.etki_uygula(jsonb_build_object(
    'hazine',-(e->>'maliyet')::numeric,'enflasyon',(e->>'enflasyon')::numeric,
    'buyume',(e->>'buyume')::numeric,'issizlik',(e->>'issizlik')::numeric,
    'memnuniyet',(e->>'memnuniyet')::numeric
  ),null);

  insert into oyun.borc_aflari(kaynak,ref_id,oran,etkilenen,toplam_silinen,maliyet,parti_id,yapan,zaman)
  values(p_kaynak,p_ref,p_oran,n,round(toplam,2),(e->>'maliyet')::numeric,p_parti,p_yapan,t);

  return e || jsonb_build_object('etkilenen',n,'toplam_silinen',round(toplam,2));
end $$;

create or replace function oyun.ozel_kanun_teklif(
  p oyun.profiller,p_eylem text,p_deger numeric,p_baslik text,p_metin text,t timestamptz
)
returns bigint language plpgsql
set search_path=''
as $$
declare b text; m text; yeni bigint; s record; veri jsonb;
begin
  if not oyun.aktif_vekil(p.id) then raise exception 'Kanun teklifini yalnızca milletvekilleri verebilir.'; end if;
  if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null) then raise exception 'Meclis Başkanı kanun teklifi veremez; tarafsız kalmalıdır.'; end if;
  if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then raise exception 'Sonuçlanmamış bir teklifin varken yeni teklif veremezsin.'; end if;

  b:=btrim(coalesce(p_baslik,''));
  if length(b)<5 or length(b)>120 then raise exception 'Kanun başlığı 5-120 karakter olmalı.'; end if;
  if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;
  m:=oyun.metin_temizle(p_metin,3000);
  if length(m)<10 then raise exception 'Gerekçe en az 10 karakter olmalı.'; end if;

  if p_eylem='borc_affi' then
    perform oyun.borc_affi_etki(p_deger);
    veri:=jsonb_build_object('eylem','borc_affi','oran',round(p_deger,1));
  elsif p_eylem='vergi' then
    p_deger:=round(p_deger,1);
    if p_deger<0 or p_deger>45 then raise exception 'Gelir vergisi %%0-%%45 arasında olmalı.'; end if;
    if p_deger>oyun.anayasa_deger('vergi_tavani') then
      raise exception 'Anayasa gelir vergisinin tavanını %%% olarak belirlemiştir.',oyun.anayasa_deger('vergi_tavani');
    end if;
    veri:=jsonb_build_object('eylem','vergi','oran',p_deger);
  else
    raise exception 'Geçersiz özel kanun.';
  end if;

  select * into s from oyun.kanun_suresi();
  insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
  values('serbest',b,m,veri,p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama)
  returning id into yeni;

  insert into oyun.bildirimler(user_id,zaman,metin)
  select m2.user_id,t,format('Yeni kanun teklifi: "%s" (%s). Oylama %s''da başlıyor.',
    b,p.kad,to_char((t+s.gorusme) at time zone 'Europe/Istanbul','DD.MM HH24:MI'))
  from oyun.makamlar m2 where m2.tur='mv' and m2.bit is null and m2.user_id<>p.id;

  perform oyun.olay('meclis',format('%s Meclis''e kanun teklifi verdi: %s',p.kad,b),null,p.parti_id,t);
  return yeni;
end $$;

create or replace function public.borc_affi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); yeni bigint;
begin
  yeni:=oyun.ozel_kanun_teklif(p,'borc_affi',p_oran,p_baslik,p_metin,t);
  return jsonb_build_object('id',yeni);
end $$;

create or replace function public.vergi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); yeni bigint;
begin
  yeni:=oyun.ozel_kanun_teklif(p,'vergi',p_oran,p_baslik,p_metin,t);
  return jsonb_build_object('id',yeni);
end $$;

create or replace function public.borc_affi_karar(p_oran numeric,p_metin text default null)
returns jsonb language plpgsql security definer
set search_path=''
as $$
declare
  p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
  sinir int:=coalesce(oyun.anayasa_deger('kararname_sinir'),3)::int;
  v_no int; yeni bigint; b text; m text; uygulama jsonb;
begin
  perform oyun.cb_zorunlu(p);
  if sinir=0 then raise exception 'Anayasa cumhurbaşkanının kararname yetkisini kaldırdı.'; end if;
  if (select count(*) from oyun.kararnameler k where k.cb=p.id and k.zaman>=oyun.bugun_bas(t))>=sinir then
    raise exception 'Bugün en fazla % kararname çıkarabilirsin (anayasal sınır).',sinir;
  end if;

  perform oyun.borc_affi_etki(p_oran);
  if exists(select 1 from oyun.borc_aflari where kaynak='kararname' and zaman>t-interval '7 days') then
    raise exception 'Cumhurbaşkanlığı kararıyla borç affı 7 günde bir çıkarılabilir.';
  end if;

  m:=nullif(btrim(coalesce(p_metin,'')),'');
  if m is not null then m:=oyun.metin_temizle(m,3000); end if;
  b:=format('Banka Kredi Borçlarının %%%s Oranında Affedilmesi Hakkında Karar',round(p_oran,1));
  v_no:=nextval('oyun.kararname_no');

  insert into oyun.kararnameler(no,tur,baslik,metin,veri,cb,zaman)
  values(v_no,'serbest',b,m,jsonb_build_object('eylem','borc_affi','oran',round(p_oran,1)),p.id,t)
  returning id into yeni;

  uygulama:=oyun.borc_affi_uygula(p_oran,'kararname',yeni,p.parti_id,p.id,t);
  update oyun.kararnameler set veri=veri || jsonb_build_object('uygulama',uygulama) where id=yeni;

  perform oyun.gazete_ekle('kararname',format('%s sayılı Cumhurbaşkanlığı Kararı: %s',v_no,b),
    coalesce(m,'') || ' ' || format(
      'Hazine etkisi -%s milyar ₺; enflasyon +%s, büyüme +%s, memnuniyet +%s puan.',
      uygulama->>'maliyet',uygulama->>'enflasyon',uygulama->>'buyume',uygulama->>'memnuniyet'
    ),yeni,t);
  perform oyun.olay('kararname',format('Cumhurbaşkanı %s, %s sayılı kararla %%%s borç affı çıkardı.',
    p.kad,v_no,round(p_oran,1)),null,p.parti_id,t);

  return jsonb_build_object('tamam',true,'no',v_no,'baslik',b,'veri',
    jsonb_build_object('oran',round(p_oran,1),'uygulama',uygulama));
end $$;

-- Mevcut kanun akışına özel ekonomik eylemler eklenir.
create or replace function oyun.kanun_yururluk(p_id bigint,t timestamptz,p_not text)
returns void language plpgsql
set search_path='oyun','public','pg_temp'
as $$
declare
  k oyun.kanunlar; v_no int; kr oyun.kararnameler; pencere boolean;
  uygulama jsonb; oran numeric; eski numeric;
begin
  select * into k from oyun.kanunlar where id=p_id for update;
  v_no:=nextval('oyun.kanun_no');
  update oyun.kanunlar set durum='yururlukte',no=v_no,sonuc_at=t,sonuc_metin=p_not where id=k.id;

  if k.tur='serbest' and k.veri->>'eylem'='borc_affi' then
    uygulama:=oyun.borc_affi_uygula((k.veri->>'oran')::numeric,'kanun',k.id,k.teklif_parti,k.teklif_eden,t);
    update oyun.kanunlar set veri=veri || jsonb_build_object('uygulama',uygulama) where id=k.id;

  elsif k.tur='serbest' and k.veri->>'eylem'='vergi' then
    oran:=(k.veri->>'oran')::numeric;
    select vergi into eski from oyun.ulke where id=1;
    update oyun.ulke
       set vergi_kanun=oran,vergi=oran,
           vergi_alt=least(vergi_alt,oran),vergi_ust=greatest(vergi_ust,oran)
     where id=1;
    update oyun.kanunlar set veri=veri || jsonb_build_object('onceki_vergi',eski) where id=k.id;

    insert into oyun.bildirimler(user_id,zaman,metin)
    select id,t,format(
      'Meclis gelir vergisini %%%s olarak belirledi. Vergi maaş ve gelirlerinden yapılan kesintiyi, hazine gelirini, büyümeyi ve memnuniyeti etkiler.',oran)
    from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days';

  elsif k.tur='butce' then
    update oyun.kanunlar set veri=veri || jsonb_build_object('onceki',
      (select jsonb_build_object('vergi_alt',vergi_alt,'vergi_ust',vergi_ust,'belediye_payi',belediye_payi,
        'parti_yardim',parti_yardim,'vergi',vergi) from oyun.ulke where id=1))
    where id=k.id;
    update oyun.ulke
       set vergi_alt=(k.veri->>'vergi_alt')::numeric,
           vergi_ust=(k.veri->>'vergi_ust')::numeric,
           vergi=oyun.sinir(vergi,(k.veri->>'vergi_alt')::numeric,(k.veri->>'vergi_ust')::numeric),
           belediye_payi=(k.veri->>'belediye_payi')::numeric,
           parti_yardim=(k.veri->>'parti_yardim')::numeric,
           butce=k.veri->'paylar'
     where id=1;

  elsif k.tur='secim' then
    select exists(select 1 from oyun.secimler o join oyun.secimler g on g.donem=o.donem and g.tur='mv'
      where o.tur='mv_on' and t>=o.basvuru_bas and g.durum='bekliyor') into pencere;
    if pencere then
      update oyun.ulke set bekleyen_baraj=(k.veri->>'baraj')::numeric where id=1;
    else
      update oyun.ayarlar set baraj=(k.veri->>'baraj')::numeric where id=1;
    end if;

  elsif k.tur='iptal' then
    update oyun.kararnameler set durum='iptal'
    where id=(k.veri->>'kararname_id')::bigint returning * into kr;

    if kr.tur='vergi' and not exists(select 1 from oyun.kararnameler
      where tur='vergi' and durum='yururlukte' and zaman>kr.zaman) then
      update oyun.ulke set vergi=vergi_kanun where id=1;
    end if;

    if kr.tur='duzenleme' and exists(select 1 from oyun.duzenlemeler
      where kod=kr.veri->>'kod' and kaynak='kararname' and ref_id=kr.id) then
      if kr.veri->'onceki'->>'kaynak' is null then
        delete from oyun.duzenlemeler where kod=kr.veri->>'kod';
      else
        update oyun.duzenlemeler
           set deger=(kr.veri->'onceki'->>'deger')::numeric,
               kaynak=kr.veri->'onceki'->>'kaynak',
               ref_id=(kr.veri->'onceki'->>'ref_id')::bigint,zaman=t
         where kod=kr.veri->>'kod';
      end if;
    end if;

  elsif k.tur='duzenleme' then
    if not oyun.duzenleme_uygula(k.veri->>'kod',(k.veri->>'deger')::numeric,'kanun',k.id,t) then
      update oyun.kanunlar set sonuc_metin=p_not || ' Ancak kural bu arada anayasaya bağlandığı için uygulanamadı.' where id=k.id;
    end if;

  elsif k.tur='anayasa' then
    perform oyun.anayasa_uygula(k,t);
  end if;

  perform oyun.gazete_ekle(case when k.tur='anayasa' then 'anayasa' else 'kanun' end,
    format('%s sayılı %s',v_no,k.baslik),
    coalesce(case when k.tur='anayasa' then oyun.anayasa_aciklama(k.veri) || ' ' end,'') || k.metin,k.id,t);
  perform oyun.bildir(k.teklif_eden,format('Teklifin yasalaştı: %s sayılı "%s" yürürlüğe girdi.',v_no,k.baslik),t);
  perform oyun.olay('meclis',format('%s sayılı "%s" yürürlüğe girdi. %s',v_no,k.baslik,p_not),null,k.teklif_parti,t);
end $$;

-- ---------- VERGİ ETKİSİ + BORÇ AFFI VAADİ ----------
create or replace function oyun.politika_etki(p_kod text,p_deger numeric)
returns jsonb language plpgsql stable
set search_path=''
as $$
declare u oyun.ulke; u2 oyun.ulke; enf numeric:=0; buy numeric:=0; mem numeric:=0; vf numeric:=0;
begin
  select * into u from oyun.ulke where id=1; u2:=u;
  if p_kod='asgari' then
    u2.asgari:=p_deger;
    enf:=(greatest(0,p_deger/u.asgari_ref-1)-greatest(0,u.asgari/u.asgari_ref-1))*40;
  elsif p_kod='vergi' then
    u2.vergi:=p_deger; vf:=p_deger-u.vergi; buy:=-vf*0.15; mem:=-vf*0.60;
  elsif p_kod='destek' then
    u2.destek:=p_deger; enf:=(p_deger-u.destek)/100;
  elsif p_kod='kidem_primi' then
    enf:=(p_deger-u.kidem_primi)*0.15;
  end if;

  return jsonb_build_object(
    'gunluk',round((oyun.ulke_hesap(u)->>'denge')::numeric-(oyun.ulke_hesap(u2)->>'denge')::numeric,3),
    'enflasyon',round(enf,2),'buyume',round(buy,2),'memnuniyet',round(mem,2),'oyuncu_vergi_farki',round(vf,1)
  );
end $$;

insert into oyun.vaat_turleri(kapsam,kod,ad,birim,tip,yon,min,max,sira,aciklama)
values('beyanname','borc_affi','Kredi borçlarına af getireceğiz','yuzde','tek','>=',10,100,49,
  'Oyuncuların açık banka kredi borçlarının vaat edilen oranı silinir. Borçlular rahatlar; hazine maliyeti ve enflasyon baskısı oluşur.')
on conflict(kapsam,kod) do update
set ad=excluded.ad,birim=excluded.birim,tip=excluded.tip,yon=excluded.yon,min=excluded.min,max=excluded.max,
    sira=excluded.sira,aciklama=excluded.aciklama;

update oyun.vaat_turleri
set aciklama='Gelir vergisini indirebilir ya da artırabilirsin. İndirmek oyuncunun eline geçen parayı ve memnuniyeti artırır ama hazine gelirini azaltır; artırmak bütçeyi güçlendirir fakat büyüme ve memnuniyeti baskılar.'
where kapsam='beyanname' and kod='vergi';

create or replace function oyun.vaat_mevcut(p_kapsam text,p_kod text,p_il smallint,p_parti bigint)
returns numeric language sql stable
set search_path=''
as $$
  select case
    when p_kod='borc_affi' then 0
    when p_kod in (select kod from oyun.duzenleme_tanim where kapsam='ulke') then oyun.duz(p_kod)
    when p_kod in (select kod from oyun.duzenleme_tanim where kapsam='il') then oyun.il_duz(p_il,p_kod)
    else (select case p_kod
      when 'asgari' then u.asgari when 'vergi' then u.vergi when 'kidem' then u.kidem_primi
      when 'destek' then u.destek when 'tasinma' then u.tasinma_destek
      when 'vergi_tavan' then u.vergi_ust when 'belediye_payi' then u.belediye_payi
      when 'baraj' then (select baraj from oyun.ayarlar where id=1)
      when 'parti_yardim' then u.parti_yardim
      when 'kent_vergisi' then (select kent_vergisi from oyun.il_durum where il_id=p_il)
      when 'hemsehri' then (select hemsehri from oyun.il_durum where il_id=p_il)
      when 'uye' then (select count(*) from oyun.profiller where parti_id=p_parti)
      when 'kasa' then (select round(kasa) from oyun.partiler where id=p_parti)
      when 'aday_ucret' then (select max(value::numeric) from oyun.partiler pa,jsonb_each_text(pa.aday_ucret) where pa.id=p_parti)
    end from oyun.ulke u where u.id=1) end
$$;

create or replace function oyun.vaat_maliyet(p_kapsam text,p_kod text,p_hedef numeric,p_il smallint,p_parti bigint)
returns jsonb language plpgsql stable
set search_path=''
as $$
declare u oyun.ulke; d oyun.il_durum; m numeric:=0; enf numeric:=0; e jsonb; mal numeric;
begin
  select * into u from oyun.ulke where id=1;
  if p_kapsam='beyanname' then
    if p_kod in ('asgari','vergi','destek','kidem','tasinma') then
      e:=oyun.politika_etki(case p_kod when 'kidem' then 'kidem_primi' when 'tasinma' then 'tasinma_destek' else p_kod end,p_hedef);
      m:=(e->>'gunluk')::numeric; enf:=(e->>'enflasyon')::numeric;
    elsif p_kod='borc_affi' then
      e:=oyun.borc_affi_etki(p_hedef); m:=(e->>'maliyet')::numeric/30; enf:=(e->>'enflasyon')::numeric;
    elsif p_kod='ikramiye' then
      m:=p_hedef*oyun.nufus('ikramiye')/1e9/30;
    elsif exists(select 1 from oyun.duzenleme_tanim where kod=p_kod and kapsam='ulke') then
      e:=oyun.duzenleme_etki(p_kod,p_hedef); m:=(e->>'gunluk')::numeric; enf:=(e->>'enflasyon')::numeric;
    elsif p_kod='ozellestirme' then m:=-10.0/30;
    elsif p_kod='referandum' then m:=0;
    else
      select maliyet into mal from oyun.icraatlar where kod=p_kod; m:=coalesce(mal,0)/7;
    end if;

  elsif p_kapsam='mv' then
    if p_kod='vergi_tavan' and p_hedef<u.vergi then
      m:=(oyun.politika_etki('vergi',p_hedef)->>'gunluk')::numeric;
    elsif p_kod='belediye_payi' and p_hedef>u.belediye_payi then
      m:=(oyun.ulke_hesap(u)->>'belediye')::numeric*(p_hedef-u.belediye_payi)/u.belediye_payi;
    elsif exists(select 1 from oyun.duzenleme_tanim where kod=p_kod and kapsam='ulke') then
      e:=oyun.duzenleme_etki(p_kod,p_hedef); m:=(e->>'gunluk')::numeric; enf:=(e->>'enflasyon')::numeric;
    end if;

  elsif p_kapsam='bel' then
    select * into d from oyun.il_durum where il_id=p_il;
    if p_kod='kent_vergisi' and p_hedef<d.kent_vergisi then
      m:=oyun.il_gelir(p_il)*(1-(1+p_hedef/10)/(1+d.kent_vergisi/10));
    elsif p_kod='kent_vergisi' and p_hedef>d.kent_vergisi then
      m:=-oyun.il_gelir(p_il)*((1+p_hedef/10)/(1+d.kent_vergisi/10)-1);
    elsif p_kod='hemsehri' and p_hedef>d.hemsehri then
      m:=oyun.hemsehri_gider(p_il,p_hedef-d.hemsehri);
    elsif p_kod in ('lokanta','ulasim','kira','istihdam')
      and not exists(select 1 from oyun.il_hizmet where il_id=p_il and kod=p_kod) then
      m:=oyun.hizmet_gider(p_il,p_kod);
    elsif p_kod='emlak' then
      m:=-(p_hedef-oyun.il_duz(p_il,'emlak'))*u.endeks*oyun.nufus('il_hane')*(select mv from oyun.iller where id=p_il)/600/1e9;
    elsif p_kod='hosgeldin' then
      m:=greatest(0,p_hedef-oyun.il_duz(p_il,'hosgeldin'))*2000/1e9;
    elsif p_kod='imar_barisi' then
      m:=-4*oyun.il_gunluk_gelir((select mv from oyun.iller where id=p_il))*u.endeks/30;
    elsif p_kod in ('altyapi','rayli') then
      m:=(select gun from oyun.belediye_yatirimlari where kod=p_kod)*
        oyun.il_gunluk_gelir((select mv from oyun.iller where id=p_il))*u.endeks/30;
    end if;

  elsif p_kapsam='gb' then
    if p_kod='kampanya' then m:=p_hedef/30; end if;
  end if;
  return jsonb_build_object('gunluk',round(m,4),'enflasyon',round(enf,2));
end $$;

create or replace function oyun.vaat_kosul(v oyun.vaatler,t timestamptz)
returns boolean language plpgsql stable
set search_path=''
as $$
declare u oyun.ulke; d oyun.il_durum; v_cb uuid; bas timestamptz:=coalesce(v.aktif_bas,t); toplam int; katildi int;
begin
  select * into u from oyun.ulke where id=1;

  if v.kapsam='beyanname' then
    case v.kod
      when 'asgari' then return u.asgari>=v.hedef;
      when 'vergi' then return case when v.yon='<=' then u.vergi<=v.hedef else u.vergi>=v.hedef end;
      when 'kidem' then return u.kidem_primi>=v.hedef;
      when 'destek' then return u.destek>=v.hedef;
      when 'tasinma' then return u.tasinma_destek>=v.hedef;
      when 'borc_affi' then
        return exists(select 1 from oyun.borc_aflari a
          where a.zaman>=bas and a.parti_id=v.parti_id and a.oran>=v.hedef);
      when 'ikramiye' then
        v_cb:=(select user_id from oyun.makamlar where id=v.makam_id);
        return exists(select 1 from oyun.kararnameler k
          where k.tur='ikramiye' and k.cb=v_cb and k.zaman>=bas and (k.veri->>'miktar')::numeric>=v.hedef);
      when 'ozellestirme' then
        v_cb:=(select user_id from oyun.makamlar where id=v.makam_id);
        return exists(select 1 from oyun.kararnameler k where k.tur='ozellestirme' and k.cb=v_cb and k.zaman>=bas);
      when 'referandum' then return exists(select 1 from oyun.referandumlar r where r.olusturma>=bas);
      else
        if exists(select 1 from oyun.duzenleme_tanim where kod=v.kod) then
          return case when v.yon='<=' then oyun.duz(v.kod)<=v.hedef else oyun.duz(v.kod)>=v.hedef end;
        end if;
        return exists(select 1 from oyun.icraat_kayit k where k.kod=v.kod and k.zaman>=bas);
    end case;

  elsif v.kapsam='mv' then
    if v.kod='katilim' then
      select count(*) into toplam from oyun.kanunlar k
      where k.oy_bit<=t and k.oy_bit>=bas and k.durum not in ('geri_cekildi','gorusmede','oylamada');
      select count(*) into katildi from oyun.kanun_oylari o join oyun.kanunlar k on k.id=o.kanun_id
      where o.vekil=v.user_id and o.asama='ilk' and k.oy_bit<=t and k.oy_bit>=bas
        and k.durum not in ('geri_cekildi','gorusmede','oylamada');
      return toplam<3 or katildi*100>=v.hedef*toplam;
    elsif v.kod='teklif' then
      return (select count(*) from oyun.kanunlar where teklif_eden=v.user_id and teklif_at>=bas and durum<>'geri_cekildi')>=v.hedef;
    elsif v.kod='anayasa_imza' then
      return exists(select 1 from oyun.kanun_oylari o join oyun.kanunlar k on k.id=o.kanun_id
        where o.vekil=v.user_id and o.asama='imza' and k.teklif_at>=bas and k.durum<>'geri_cekildi');
    end if;

    return exists(select 1 from oyun.kanunlar k
      where k.durum='yururlukte' and k.sonuc_at>=bas
        and exists(select 1 from oyun.kanun_oylari o where o.kanun_id=k.id and o.vekil=v.user_id and o.oy='kabul')
        and case v.kod
          when 'vergi_tavan' then k.tur='butce' and (k.veri->>'vergi_ust')::numeric<=v.hedef
          when 'belediye_payi' then k.tur='butce' and (k.veri->>'belediye_payi')::numeric>=v.hedef
          when 'parti_yardim' then k.tur='butce' and (k.veri->>'parti_yardim')::numeric<=v.hedef
          when 'baraj' then k.tur='secim' and (k.veri->>'baraj')::numeric<=v.hedef
          else k.tur in ('duzenleme','anayasa') and k.veri->>'kod'=v.kod
            and case when v.yon='<=' then (k.veri->>'deger')::numeric<=v.hedef else (k.veri->>'deger')::numeric>=v.hedef end
        end);

  elsif v.kapsam='bel' then
    select * into d from oyun.il_durum where il_id=v.il_id;
    case v.kod
      when 'kent_vergisi' then return d.kent_vergisi<=v.hedef;
      when 'hemsehri' then return d.hemsehri>=v.hedef;
      when 'emlak','hosgeldin' then
        return case when v.yon='<=' then oyun.il_duz(v.il_id,v.kod)<=v.hedef else oyun.il_duz(v.il_id,v.kod)>=v.hedef end;
      when 'altyapi','rayli','imar_barisi' then
        return exists(select 1 from oyun.belediye_proje_kayit k
          where k.kod=v.kod and k.il_id=v.il_id and k.baskan=v.user_id and k.zaman>=bas);
      else return exists(select 1 from oyun.il_hizmet h where h.il_id=v.il_id and h.kod=v.kod);
    end case;

  elsif v.kapsam='gb' then
    case v.kod
      when 'aday_ucret' then
        return (select max(value::numeric) from oyun.partiler pa,jsonb_each_text(pa.aday_ucret) where pa.id=v.parti_id)<=v.hedef;
      when 'uye' then return (select count(*) from oyun.profiller where parti_id=v.parti_id)>=v.hedef;
      when 'kasa' then return coalesce((select kasa from oyun.partiler where id=v.parti_id),0)>=v.hedef;
      else return coalesce((select -sum(tutar) from oyun.parti_hareket
        where parti_id=v.parti_id and tur='destek' and zaman>=bas),0)>=v.hedef;
    end case;
  end if;
  return false;
end $$;

-- ---------- TICK ----------
create or replace function oyun.tick()
returns integer language plpgsql
set search_path='oyun','public','pg_temp'
as $$
declare t timestamptz:=oyun.simdi(); ay date; r record; n int:=0;
begin
  if not pg_try_advisory_xact_lock(424242) then return 0; end if;
  ay:=date_trunc('month',t at time zone 'Europe/Istanbul')::date;
  perform oyun.donem_olustur(ay);
  perform oyun.donem_olustur((ay+interval '1 month')::date);

  if (select son_temizlik from oyun.ayarlar where id=1)
     is distinct from (t at time zone 'Europe/Istanbul')::date then
    delete from oyun.mesajlar where zaman<t-interval '30 days';
    delete from oyun.yayinlar where zaman<t-interval '30 days';
    delete from oyun.bildirimler where zaman<t-interval '60 days';
    delete from oyun.ozel where zaman<t-interval '90 days';
    delete from oyun.push_kuyruk where olusturma<now()-interval '7 days';
    update oyun.ayarlar set son_temizlik=(t at time zone 'Europe/Istanbul')::date where id=1;
  end if;

  loop
    select * into r from (
      select id,sonuc_at as zaman,0 as asama,oyun.oncelik(tur) o
      from oyun.secimler where durum='bekliyor' and sonuc_at<=t
      union all
      select id,goreve_bas,1,oyun.oncelik(tur)
      from oyun.secimler where durum='sonuclandi' and goreve_bas<=t
    ) x order by zaman,asama,o limit 1;
    exit when not found;

    if r.asama=0 then perform oyun.sonuclandir(r.id);
    else perform oyun.goreve_baslat(r.id); end if;
    n:=n+1;
    exit when n>200;
  end loop;

  perform oyun.kanun_tick(t);
  perform oyun.mevzuat_tick(t);
  perform oyun.meclis_tick(t);
  perform oyun.parti_tuzuk_tick(t);
  perform oyun.guvenlik_tick(t);
  perform oyun.gunluk_ekonomi(t);
  perform oyun.banka_tick(t);
  perform oyun.push_hatirlatmalar(t);
  perform oyun.push_tetikle();
  return n;
end $$;

-- Bu modül tek başına da güvenli olsun; 06_yetkiler.sql sonunda tekrar uygular.
revoke all on function public.parti_ad_degistir(text,text) from public,anon;
grant execute on function public.parti_ad_degistir(text,text) to authenticated;
revoke all on function public.parti_tuzuk(bigint) from public,anon;
grant execute on function public.parti_tuzuk(bigint) to authenticated;
revoke all on function public.parti_tuzuk_teklif(text,text) from public,anon;
grant execute on function public.parti_tuzuk_teklif(text,text) to authenticated;
revoke all on function public.parti_tuzuk_oyla(bigint,text) from public,anon;
grant execute on function public.parti_tuzuk_oyla(bigint,text) to authenticated;
revoke all on function public.borc_affi_onizle(numeric) from public,anon;
grant execute on function public.borc_affi_onizle(numeric) to authenticated;
revoke all on function public.borc_affi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.borc_affi_kanun_teklif(numeric,text,text) to authenticated;
revoke all on function public.vergi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.vergi_kanun_teklif(numeric,text,text) to authenticated;
revoke all on function public.borc_affi_karar(numeric,text) from public,anon;
grant execute on function public.borc_affi_karar(numeric,text) to authenticated;
