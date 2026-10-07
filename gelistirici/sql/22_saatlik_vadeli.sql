-- =====================================================================
-- SEÇİM SİMÜLASYONU ONLINE — 22) SAATLİK VADELİ / FAİZSİZ VADESİZ
-- Vadesiz yalnız para tutma ve oyuncular arası transfer içindir.
-- Yeni vadeli hesaplar yalnız saatlik açılır ve vade sonunda yüksek getiri verir.
-- Eski açık 7/30 günlük hesapların mevcut vade tarihleri korunur.
-- =====================================================================

alter table oyun.vadeli add column if not exists vade_saat integer;
alter table oyun.vadeli add column if not exists oran_tur text not null default 'aylik';
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='oyun.vadeli'::regclass and conname='vadeli_oran_tur_check'
  ) then
    alter table oyun.vadeli
      add constraint vadeli_oran_tur_check check (oran_tur in ('aylik','vade'));
  end if;
end $$;

-- Vadesiz faiz sıfırdır. Saatlik vadeli oranları vadenin toplam getiri yüzdesidir.
create or replace function oyun.banka_oranlar() returns jsonb
language sql stable set search_path='' as $$
  with x as (
    select greatest(15,round(u.enflasyon+a.banka_reel_faiz,1)) py
    from oyun.ulke u, oyun.ayarlar a
    where u.id=1 and a.id=1
  ), b as (
    select py, greatest(0.25,round(py/200,2)) taban from x
  )
  select jsonb_build_object(
    'politika',py,
    'vadesiz',0,
    'vadeli1s',round(taban,2),
    'vadeli3s',round(taban*3.20,2),
    'vadeli6s',round(taban*7.00,2),
    'vadeli12s',round(taban*16.00,2),
    'vadeli24s',round(taban*36.00,2),
    -- Eski açık hesaplar yalnız bilgi/uyumluluk için.
    'vadeli7',round(py/12*1.05,2),
    'vadeli30',round(py/12*1.25,2),
    'kredi',round(py/12*1.60,2),
    'gecikme_gunluk',1
  )
  from b
$$;

-- Eski sürümde birikmiş faiz varsa bir kez hesaba aktar; bundan sonra vadesiz faiz üretmez.
create or replace function oyun.vadesiz_isle(u uuid,t timestamptz)
returns oyun.banka_musteri
language plpgsql set search_path='' as $$
declare m oyun.banka_musteri:=oyun.musteri(u,t);
begin
  if coalesce(m.faiz_birikmis,0)>0 then
    update oyun.banka_musteri
       set vadesiz=vadesiz+faiz_birikmis,
           faiz_toplam=faiz_toplam+faiz_birikmis,
           faiz_birikmis=0,
           son_faiz=t
     where user_id=u
     returning * into m;
  elsif m.son_faiz is distinct from t then
    update oyun.banka_musteri set son_faiz=t where user_id=u returning * into m;
  end if;
  return m;
end $$;

-- Yeni hesaplarda oran, vadenin tamamı için toplam kazanç yüzdesidir.
-- Eski hesaplarda eski aylık/saatlik hesap aynen korunur.
create or replace function oyun.vadeli_biriken(v oyun.vadeli,t timestamptz)
returns numeric
language sql stable set search_path='' as $$
  select case
    when v.oran_tur='vade' and v.vade_saat is not null then
      round(v.anapara*v.oran/100 *
        least(1::numeric,
          greatest(0::numeric,extract(epoch from (t-v.acilis))/nullif(v.vade_saat*3600.0,0))),2)
    else
      round(v.anapara*v.oran/100/30/24 *
        least(v.gun*24,greatest(0,floor(extract(epoch from (t-v.acilis))/3600))),2)
  end
$$;

create or replace function public.vadeli_ac(p_miktar numeric,p_gun integer)
returns jsonb
language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  m numeric:=round(coalesce(p_miktar,0));
  oran numeric;
  tav numeric:=oyun.banka_tavani();
  anahtar text;
begin
  perform oyun.banka_acik_mi();
  perform oyun.takip_engel(p.id,'vadeli hesap açamazsın');

  -- Parametre adı geriye dönük API uyumluluğu için p_gun kaldı; artık saat ifade eder.
  if p_gun not in (1,3,6,12,24) then
    raise exception 'Vade 1, 3, 6, 12 ya da 24 saat olabilir.';
  end if;
  if m<1000 then raise exception 'Vadeli hesap en az 1.000 ₺ ile açılır.'; end if;
  if (select count(*) from oyun.vadeli where user_id=p.id and durum='acik')>=3 then
    raise exception 'Aynı anda en fazla 3 vadeli hesabın olabilir.';
  end if;

  perform oyun.musteri(p.id,t);
  if oyun.mevduat_toplam(p.id)+m>tav then
    raise exception 'Bankada en fazla % ₺ tutabilirsin (şu an % ₺ var).',
      oyun.tl(tav),oyun.tl(oyun.mevduat_toplam(p.id));
  end if;

  anahtar:=case p_gun
    when 1 then 'vadeli1s'
    when 3 then 'vadeli3s'
    when 6 then 'vadeli6s'
    when 12 then 'vadeli12s'
    else 'vadeli24s' end;
  oran:=(oyun.banka_oranlar()->>anahtar)::numeric;

  perform oyun.para_islem(p.id,-m,'banka',
    format('Vadeli hesap açıldı (%s saat, vade getirisi %%%s)',p_gun,replace(oran::text,'.',',')),t);

  -- gun=7 yalnız eski tablo kısıtını bozmadan saklama uyumluluğu içindir.
  insert into oyun.vadeli(user_id,anapara,oran,gun,acilis,vade,vade_saat,oran_tur)
  values(p.id,m,oran,7,t,t+make_interval(hours=>p_gun),p_gun,'vade');

  perform oyun.banka_kayit(p.id,'vadeli',m,
    format('%s saatlik vadeli hesap açıldı · vade getirisi %%%s',p_gun,replace(oran::text,'.',',')),t);
  return public.banka();
end $$;

create or replace function oyun.vadeli_kapat(v oyun.vadeli,t timestamptz)
returns void
language plpgsql set search_path='' as $$
declare g numeric:=oyun.vadeli_biriken(v,greatest(t,v.vade)); etiket text;
begin
  update oyun.vadeli set durum='vade',getiri=g,kapanis=t
  where id=v.id and durum='acik';
  if not found then return; end if;

  etiket:=case when v.oran_tur='vade' and v.vade_saat is not null
    then format('%s saatlik',v.vade_saat)
    else format('%s günlük',v.gun) end;

  perform oyun.para_islem(v.user_id,v.anapara+g,'banka',
    format('Vadeli hesap vadesi doldu: %s ₺ anapara + %s ₺ faiz',oyun.tl(v.anapara),oyun.tl(g)),t);
  perform oyun.banka_kayit(v.user_id,'vadeli',-(v.anapara+g),
    format('%s vadeli hesap kapandı (faiz %s ₺)',etiket,oyun.tl(g)),t);
  perform oyun.bildir(v.user_id,
    format('%s vadeli hesabının vadesi doldu: %s ₺ anapara ve %s ₺ faiz cüzdanına yattı.',
      etiket,oyun.tl(v.anapara),oyun.tl(g)),t);
end $$;

create or replace function public.vadeli_boz(p_id bigint)
returns jsonb
language plpgsql security definer
set search_path='' as $$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  v oyun.vadeli;
  g numeric:=0;
  saat int;
begin
  select * into v from oyun.vadeli where id=p_id and user_id=p.id for update;
  if v.id is null or v.durum<>'acik' then raise exception 'Açık bir vadeli hesap bulunamadı.'; end if;

  if v.oran_tur='vade' and v.vade_saat is not null then
    -- Yeni saatlik vadede erken bozma faizsizdir.
    g:=0;
  else
    -- Eski 7/30 günlük hesaplar eski sözleşme koşulunu korur.
    saat:=greatest(0,floor(extract(epoch from (t-v.acilis))/3600))::int;
    g:=round(v.anapara*greatest(0.01,(oyun.banka_oranlar()->>'politika')::numeric/12*0.70)/100/30/24*saat,2);
  end if;

  update oyun.vadeli set durum='bozuldu',getiri=g,kapanis=t where id=v.id;
  perform oyun.para_islem(p.id,v.anapara+g,'banka',
    format('Vadeli hesap bozuldu: %s ₺ anapara + %s ₺ faiz',oyun.tl(v.anapara),oyun.tl(g)),t);
  perform oyun.banka_kayit(p.id,'vadeli',-(v.anapara+g),
    case when v.oran_tur='vade' then 'Saatlik vadeli hesap erken bozuldu · faiz ödenmedi'
         else 'Eski vadeli hesap vadeden önce bozuldu' end,t);
  return public.banka();
end $$;

create or replace function oyun.banka_tick(t timestamptz)
returns void
language plpgsql set search_path='' as $$
declare bugun date:=(t at time zone 'Europe/Istanbul')::date; son date; v oyun.vadeli;
begin
  -- Vadesiz faiz yoktur; yalnız eski birikmiş faizi olan hesaplar temizlenir.
  update oyun.banka_musteri
     set vadesiz=vadesiz+faiz_birikmis,
         faiz_toplam=faiz_toplam+faiz_birikmis,
         faiz_birikmis=0,
         son_faiz=t
   where faiz_birikmis>0;

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

create or replace function public.banka() returns jsonb
language plpgsql security definer
set search_path='oyun','public','pg_temp' as $$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  m oyun.banka_musteri;
  k oyun.krediler;
  o jsonb:=oyun.banka_oranlar();
  c oyun.cuzdan:=oyun.cuzdanim(p.id);
  hb numeric;
  ul oyun.ulke;
begin
  m:=oyun.vadesiz_isle(p.id,t);
  k:=oyun.aktif_kredi(p.id);
  select * into ul from oyun.ulke where id=1;
  hb:=coalesce((select sum(tutar) from oyun.banka_transfer where gonderen=p.id and zaman>=oyun.bugun_bas(t)),0);

  return jsonb_build_object(
    'acik',(select banka_acik from oyun.ayarlar where id=1),
    'cuzdan',c.para,'oranlar',o,'enflasyon',round(ul.enflasyon,1),
    'vadesiz',jsonb_build_object(
      'bakiye',round(m.vadesiz,2),
      'faiz_yok',true,
      'amac','transfer'
    ),
    'vadeliler',coalesce((select jsonb_agg(jsonb_build_object(
      'id',v.id,'anapara',v.anapara,'oran',v.oran,'gun',v.gun,
      'vade_saat',v.vade_saat,'oran_tur',v.oran_tur,
      'acilis',v.acilis,'vade',v.vade,'durum',v.durum,
      'getiri',coalesce(v.getiri,case when v.oran_tur='vade'
        then round(v.anapara*v.oran/100,2)
        else round(v.anapara*v.oran/100*v.gun/30,2) end),
      'biriken',case when v.durum='acik' then oyun.vadeli_biriken(v,t) else v.getiri end,
      'bozma',case when v.oran_tur='vade' then 0
        else round(v.anapara*greatest(0.01,(o->>'politika')::numeric/12*0.70)/100/30/24*
          greatest(0,floor(extract(epoch from(t-v.acilis))/3600)),2) end
    ) order by v.durum<>'acik',v.acilis desc)
      from (select * from oyun.vadeli
            where user_id=p.id and (durum='acik' or kapanis>t-interval '14 days')
            order by acilis desc limit 10)v),'[]'::jsonb),
    'kredi',case when k.id is not null then jsonb_build_object(
      'id',k.id,'anapara',k.anapara,'oran',k.oran,'gun',k.gun,'toplam',k.toplam,
      'taksit',k.taksit,'kalan',k.kalan,'gecikmis',k.gecikmis,'gecikme_gun',k.gecikme_gun,
      'durum',k.durum,'acilis',k.acilis,'erken_kapama',oyun.erken_kapama(k),
      'kalan_gun',ceil(greatest(0,k.kalan-k.gecikmis)/k.taksit)
    ) end,
    'kredi_notu',m.kredi_notu,'not_ad',oyun.not_ad(m.kredi_notu),
    'kredi_oran',oyun.kredi_orani(p.id),'kredi_limit',oyun.kredi_limiti(p.id),
    'kara_liste',case when m.kara_liste>t then m.kara_liste end,
    'kredi_engel',oyun.uyari(p,t),'tavan',oyun.banka_tavani(),
    'mevduat',oyun.mevduat_toplam(p.id),'uyari',oyun.kredi_uyari(p.id),
    'havale',jsonb_build_object(
      'bugun',hb,'tavan',round(ul.asgari*(select havale_sinir from oyun.ayarlar where id=1)),
      'engel',oyun.uyari(p,t),'kaynak','vadesiz'
    ),
    'transferler',coalesce((select jsonb_agg(jsonb_build_object(
      'id',x.id,'zaman',x.zaman,'yon',case when x.gonderen=p.id then 'giden' else 'gelen' end,
      'karsi',case when x.gonderen=p.id then oyun.kad(x.alici) else oyun.kad(x.gonderen) end,
      'tutar',x.tutar,'aciklama',x.aciklama
    ) order by x.zaman desc,x.id desc)
      from (select * from oyun.banka_transfer where gonderen=p.id or alici=p.id
            order by zaman desc,id desc limit 20)x),'[]'::jsonb),
    'hareketler',coalesce((select jsonb_agg(jsonb_build_object(
      'zaman',h.zaman,'hesap',h.hesap,'tutar',h.tutar,'aciklama',h.aciklama
    ) order by h.zaman desc,h.id desc)
      from (select * from oyun.banka_hareket where user_id=p.id
            order by zaman desc,id desc limit 25)h),'[]'::jsonb)
  );
end $$;

revoke all on function public.vadeli_ac(numeric,integer) from public,anon;
grant execute on function public.vadeli_ac(numeric,integer) to authenticated;
revoke all on function public.vadeli_boz(bigint) from public,anon;
grant execute on function public.vadeli_boz(bigint) to authenticated;
revoke all on function public.banka() from public,anon;
grant execute on function public.banka() to authenticated;
