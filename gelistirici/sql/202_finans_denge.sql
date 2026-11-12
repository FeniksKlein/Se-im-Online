-- 202 · Finans dengesi (2026-11-12) — Ercan'ın onayladığı üç öneri. 201'den sonra çalışır.
--  1) Banka, sermayesinin en fazla yarısı kadar devlet tahvili (DİBS) tutabilir.
--  2) Devlet Bankası kredisi birikime (teminata) dayanıyorsa, o kısım borç bitene kadar
--     başka oyunculara aktarılamaz (havale, EFT, FAST, hediye, kişisel çek). Harcama serbesttir.
--     Yalnız bu modülden sonra çekilen krediler için geçerlidir; borç ödendikçe bloke azalır.
--  3) Banka kasasından reklam panosu ödemesi yalnız dağıtılabilir kârdan yapılır
--     (siyasi bağış ve TV reklamı bankalara zaten kapalı).

-- ───────── 1) DİBS üst sınırı ─────────
select oyun.fn_yama('public.banka_dibs_al(bigint,numeric,integer)'::regprocedure, '/*202*/', array[
  'ora := oyun.banka_dibs_orani(p_gun);',
  'if p_tutar + coalesce((b->>''dibs'')::numeric, 0) > floor(s.sermaye * 0.5) then /*202*/
    raise exception ''Bir banka sermayesinin en fazla yarısı kadar devlet tahvili tutabilir (üst sınır % ₺, elindeki % ₺).'',
      oyun.tl(floor(s.sermaye * 0.5)), oyun.tl(coalesce((b->>''dibs'')::numeric, 0));
  end if;
  ora := oyun.banka_dibs_orani(p_gun);'
]);

-- ───────── 2) Kredi teminatı blokesi ─────────
alter table oyun.krediler add column if not exists teminat_bloke numeric not null default 0;
select oyun.sonlu_kisit_kur();

create or replace function oyun.teminat_bloke_kalan(u uuid) returns numeric language sql stable as $f$
  select coalesce(sum(k.teminat_bloke * k.kalan / nullif(k.toplam, 0)), 0)
    from oyun.krediler k where k.user_id = u and k.durum in ('aktif','takip') and k.teminat_bloke > 0
$f$;

create or replace function oyun.teminat_engel(u uuid, p_tutar numeric) returns void language plpgsql as $f$
declare bloke numeric := oyun.teminat_bloke_kalan(u); likit numeric;
begin
  if bloke <= 0 then return; end if;
  likit := coalesce((select greatest(0, para) from oyun.cuzdan where user_id = u), 0)
         + coalesce((select greatest(0, vadesiz) from oyun.banka_musteri where user_id = u), 0)
         + coalesce((select sum(anapara) from oyun.vadeli where user_id = u and durum = 'acik'), 0)
         + coalesce((select sum(anapara) from oyun.banka_mevduat where user_id = u and not kapandi), 0)
         + coalesce((select sum(greatest(0, bakiye)) from oyun.ib_vadesiz where user_id = u), 0);
  if likit - coalesce(p_tutar, 0) < bloke then
    raise exception 'Kredin birikimine dayanıyor: borç bitene kadar hesaplarında toplam en az % ₺ kalmalı (şu an % ₺). Bu parayı harcayabilirsin ama başka oyuncuya aktaramazsın; borcu ödedikçe tutar azalır.',
      oyun.tl(ceil(bloke)), oyun.tl(floor(likit));
  end if;
end $f$;
revoke all on function oyun.teminat_bloke_kalan(uuid) from public, anon, authenticated;
revoke all on function oyun.teminat_engel(uuid, numeric) from public, anon, authenticated;

-- Kredi çekilirken gelirin karşılamadığı (teminata dayanan) kısım kaydedilir.
select oyun.fn_yama('public.kredi_cek(numeric,integer)'::regprocedure, 'teminat_bloke', array[
  'INSERT INTO oyun.krediler(user_id,anapara,oran,gun,toplam,taksit,kalan,acilis)',
  'INSERT INTO oyun.krediler(user_id,anapara,oran,gun,toplam,taksit,kalan,acilis,teminat_bloke)',
  'VALUES(p.id,m,oran,p_gun,top,tak,top,t);',
  'VALUES(p.id,m,oran,p_gun,top,tak,top,t,greatest(0,m-coalesce((risk->>''gelir_limiti'')::numeric,0)));'
]);

select oyun.fn_yama('public.para_gonder(text,numeric,text)'::regprocedure, '/*202*/', array[
  'perform oyun.takip_engel(p.id,''banka transferi yapamazsın'');',
  'perform oyun.takip_engel(p.id,''banka transferi yapamazsın'');
  perform oyun.teminat_engel(p.id,m); /*202*/'
]);
select oyun.fn_yama('public.banka_fast(text,text,text,numeric,text)'::regprocedure, '/*202*/', array[
  'perform oyun.takip_engel(u, ''banka transferi yapamazsın'');',
  'perform oyun.takip_engel(u, ''banka transferi yapamazsın'');
  perform oyun.teminat_engel(u, m); /*202*/'
]);
select oyun.fn_yama('public.serbest_bagis(text,text,numeric,text)'::regprocedure, '/*202*/', array[
  'perform oyun.takip_engel(u,''bağış yapamazsın'');',
  'perform oyun.takip_engel(u,''bağış yapamazsın'');
 if kisisel then perform oyun.teminat_engel(u,p_tutar); end if; /*202*/'
]);
select oyun.fn_yama('public.ib_havale(bigint,text,numeric)'::regprocedure, '/*202*/', array[
  'perform oyun.takip_engel(u,''banka transferi yapamazsın'');',
  'perform oyun.takip_engel(u,''banka transferi yapamazsın'');
 perform oyun.teminat_engel(u,t); /*202*/'
]);
select oyun.fn_yama('public.ib_eft(bigint,bigint,text,numeric)'::regprocedure, '/*202*/', array[
  'perform oyun.takip_engel(u,''banka transferi yapamazsın'');',
  'perform oyun.takip_engel(u,''banka transferi yapamazsın'');
   perform oyun.teminat_engel(u,t); /*202*/'
]);
-- Kişisel çek de bir aktarma yoludur: teminatı çekle boşaltmak engellenir (tutar ve adet sınırı yoktur).
select oyun.fn_yama('oyun.cek_guvenlik_201()'::regprocedure, '/*202*/', array[
  'raise exception ''Servet vergisi borcun ödenmeden çek yazamazsın.''; end if;',
  'raise exception ''Servet vergisi borcun ödenmeden çek yazamazsın.''; end if;
      perform oyun.teminat_engel(new.duzenleyen, new.tutar); /*202*/'
]);

-- ───────── 3) Banka kasasından pano ödemesi ─────────
select oyun.fn_yama('oyun.pano_odeme(text,text,bigint,uuid,numeric,text)'::regprocedure, '/*202*/', array[
  'elsif p_tur = ''sirket'' then',
  'elsif p_tur = ''sirket'' then
    if p_tutar < 0 and exists(select 1 from oyun.sirketler s where s.id = p_id and s.sektor = ''banka'')
       and -p_tutar > floor(coalesce((oyun.banka_bilanco(p_id)->>''dagitilabilir_kar'')::numeric, 0)) then /*202*/
      raise exception ''Banka kasasında mevduat sahiplerinin parası da durur; banka bu ödemeyi yalnız dağıtılabilir kârından yapabilir.'';
    end if;'
]);
