-- =====================================================================
-- SEÇİM SİMÜLASYONU ONLINE — 21) BANKA TRANSFERLERİ
-- Oyuncular arası transfer yalnızca vadesiz hesaptan vadesiz hesaba.
-- Yönetici tüm transferleri denetleyebilir.
-- =====================================================================

create table if not exists oyun.banka_transfer(
  id bigserial primary key,
  gonderen uuid not null references oyun.profiller(id) on delete restrict,
  alici uuid not null references oyun.profiller(id) on delete restrict,
  tutar numeric not null check (tutar > 0),
  aciklama text,
  zaman timestamptz not null,
  check (gonderen <> alici)
);
create index if not exists banka_transfer_gonderen on oyun.banka_transfer(gonderen,zaman desc);
create index if not exists banka_transfer_alici on oyun.banka_transfer(alici,zaman desc);
create index if not exists banka_transfer_zaman on oyun.banka_transfer(zaman desc);

create or replace function public.para_gonder(p_kad text,p_miktar numeric,p_aciklama text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  h oyun.profiller;
  m numeric:=round(coalesce(p_miktar,0));
  ack text;
  bugun numeric;
  tavan numeric;
  gm oyun.banka_musteri;
  am oyun.banka_musteri;
  tid bigint;
begin
  perform oyun.banka_acik_mi();
  h:=oyun.profil_bul(p_kad);
  if h.id=p.id then raise exception 'Kendine para gönderemezsin.'; end if;
  if h.yasakli then raise exception 'Bu oyuncunun hesabı kapatılmış.'; end if;
  if m<100 then raise exception 'En az 100 ₺ gönderebilirsin.'; end if;
  if oyun.uyari(p,t) is not null then raise exception 'Para göndermek için seçmen kartın hazır olmalı: %',oyun.uyari(p,t); end if;
  if (select coklu_kontrol from oyun.ayarlar where id=1)
     and exists(select 1 from oyun.bagli_hesaplar(p.id) b where b=h.id) then
    raise exception 'Aynı cihazda açılmış hesaplar arasında banka transferi yapılamaz.';
  end if;
  if oyun.engelli(h.id,p.id) then raise exception 'Bu oyuncu seni engellediği için ona para gönderemezsin.'; end if;
  perform oyun.takip_engel(p.id,'banka transferi yapamazsın');

  bugun:=coalesce((select sum(tutar) from oyun.banka_transfer where gonderen=p.id and zaman>=oyun.bugun_bas(t)),0);
  tavan:=round((select asgari from oyun.ulke where id=1)*(select havale_sinir from oyun.ayarlar where id=1));
  if bugun+m>tavan then
    raise exception 'Günlük banka transferi sınırı % ₺ (bugün % ₺ gönderdin).',oyun.tl(tavan),oyun.tl(bugun);
  end if;

  if nullif(btrim(coalesce(p_aciklama,'')),'') is not null then ack:=oyun.metin_temizle(p_aciklama,100); end if;

  gm:=oyun.vadesiz_isle(p.id,t);
  am:=oyun.vadesiz_isle(h.id,t);
  if gm.vadesiz<m then
    raise exception 'Transfer için vadesiz hesabında yeterli para yok. Bakiye: % ₺.',oyun.tl(gm.vadesiz);
  end if;

  update oyun.banka_musteri set vadesiz=vadesiz-m where user_id=p.id;
  update oyun.banka_musteri set vadesiz=vadesiz+m where user_id=h.id;

  insert into oyun.banka_transfer(gonderen,alici,tutar,aciklama,zaman)
  values(p.id,h.id,m,ack,t) returning id into tid;

  perform oyun.banka_kayit(p.id,'vadesiz',-m,
    format('%s adlı oyuncuya banka transferi%s',h.kad,coalesce(': '||ack,'')),t);
  perform oyun.banka_kayit(h.id,'vadesiz',m,
    format('%s adlı oyuncudan banka transferi%s',p.kad,coalesce(': '||ack,'')),t);

  perform oyun.bildir(h.id,format('%s sana banka yoluyla %s ₺ gönderdi.%s',
    p.kad,oyun.tl(m),coalesce(' Not: “'||ack||'”','')),t);

  return jsonb_build_object(
    'tamam',true,'transfer_id',tid,'alici',h.kad,'miktar',m,
    'bakiye',(select vadesiz from oyun.banka_musteri where user_id=p.id),
    'bugun',bugun+m,'tavan',tavan
  );
end $$;

create or replace function public.banka() returns jsonb
language plpgsql security definer set search_path='oyun','public','pg_temp' as $$
declare
  p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
  m oyun.banka_musteri; k oyun.krediler; o jsonb:=oyun.banka_oranlar();
  c oyun.cuzdan:=oyun.cuzdanim(p.id); hb numeric; ul oyun.ulke;
begin
  m:=oyun.vadesiz_isle(p.id,t);
  k:=oyun.aktif_kredi(p.id);
  select * into ul from oyun.ulke where id=1;
  hb:=coalesce((select sum(tutar) from oyun.banka_transfer where gonderen=p.id and zaman>=oyun.bugun_bas(t)),0);
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
      'bozma',round(v.anapara*(o->>'vadesiz')::numeric/100/30/24*greatest(0,floor(extract(epoch from(t-v.acilis))/3600)),2)
    ) order by v.durum<>'acik',v.acilis desc)
      from (select * from oyun.vadeli where user_id=p.id and (durum='acik' or kapanis>t-interval '14 days') order by acilis desc limit 10)v),'[]'::jsonb),
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
    'havale',jsonb_build_object(
      'bugun',hb,'tavan',round(ul.asgari*(select havale_sinir from oyun.ayarlar where id=1)),
      'engel',oyun.uyari(p,t),'kaynak','vadesiz'
    ),
    'transferler',coalesce((select jsonb_agg(jsonb_build_object(
      'id',x.id,'zaman',x.zaman,'yon',case when x.gonderen=p.id then 'giden' else 'gelen' end,
      'karsi',case when x.gonderen=p.id then oyun.kad(x.alici) else oyun.kad(x.gonderen) end,
      'tutar',x.tutar,'aciklama',x.aciklama
    ) order by x.zaman desc,x.id desc)
      from (select * from oyun.banka_transfer where gonderen=p.id or alici=p.id order by zaman desc,id desc limit 20)x),'[]'::jsonb),
    'hareketler',coalesce((select jsonb_agg(jsonb_build_object(
      'zaman',h.zaman,'hesap',h.hesap,'tutar',h.tutar,'aciklama',h.aciklama
    ) order by h.zaman desc,h.id desc)
      from (select * from oyun.banka_hareket where user_id=p.id order by zaman desc,id desc limit 25)h),'[]'::jsonb)
  );
end $$;

create or replace function public.admin_transferler(p_limit int default 100,p_ara text default null,p_min numeric default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  p oyun.profiller:=oyun.yonetici_zorunlu();
  lim int:=least(greatest(coalesce(p_limit,100),1),500);
  ara text:=lower(btrim(coalesce(p_ara,'')));
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',t.id,
      'zaman',t.zaman,
      'gonderen',g.kad,
      'alici',a.kad,
      'tutar',t.tutar,
      'aciklama',t.aciklama,
      'gonderen_olusturma',g.olusturma,
      'alici_olusturma',a.olusturma,
      'ikili_30gun',(select count(*) from oyun.banka_transfer z
         where z.zaman>oyun.simdi()-interval '30 days'
           and ((z.gonderen=t.gonderen and z.alici=t.alici) or (z.gonderen=t.alici and z.alici=t.gonderen))),
      'ikili_tutar_30gun',(select coalesce(sum(z.tutar),0) from oyun.banka_transfer z
         where z.zaman>oyun.simdi()-interval '30 days'
           and ((z.gonderen=t.gonderen and z.alici=t.alici) or (z.gonderen=t.alici and z.alici=t.gonderen))),
      'bagli_hesap',exists(select 1 from oyun.bagli_hesaplar(t.gonderen)b where b=t.alici)
    ) order by t.zaman desc,t.id desc)
    from (
      select bt.* from oyun.banka_transfer bt
      join oyun.profiller gp on gp.id=bt.gonderen
      join oyun.profiller ap on ap.id=bt.alici
      where (ara='' or lower(gp.kad) like '%'||ara||'%' or lower(ap.kad) like '%'||ara||'%')
        and (p_min is null or bt.tutar>=p_min)
      order by bt.zaman desc,bt.id desc
      limit lim
    )t
    join oyun.profiller g on g.id=t.gonderen
    join oyun.profiller a on a.id=t.alici
  ),'[]'::jsonb);
end $$;

revoke all on function public.admin_transferler(int,text,numeric) from public,anon;
grant execute on function public.admin_transferler(int,text,numeric) to authenticated;
