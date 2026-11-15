-- TBMM resmi kaynaklarina gore secim yenileme onergesi bir MV imzasi ile verilebilir.
-- 600 tam uye icin gereken olumlu oy ayrica 360'tir.
alter table oyun.erken_secim_teklifleri alter column parti_id drop not null;
CREATE OR REPLACE FUNCTION public.erken_secim_teklif(p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); pid bigint; iktidar boolean:=false; g text;
begin
  select id into pid from oyun.partiler where gb=p.id and not kapali limit 1;
  if oyun.gercekci_siyaset() then
  if not oyun.aktif_vekil(p.id) then raise exception 'Seçimlerin yenilenmesi önergesini yalnızca milletvekilleri verebilir.'; end if;
  pid := p.parti_id;
 elsif pid is null then
  raise exception 'Erken seçim kararı/çağrısını yalnızca parti genel başkanı başlatabilir.';
 end if;
  if oyun.aktif_vekil_sayi()=0 then raise exception 'Görevde TBMM yok.'; end if;
  if exists(select 1 from oyun.erken_secim_teklifleri where durum='oylamada') then raise exception 'Zaten Meclis gündeminde bir erken seçim önerisi var.'; end if;
  if exists(select 1 from oyun.secimler where ara and ara_neden='erken_secim' and durum='bekliyor') then raise exception 'Erken seçim takvimi zaten açık.'; end if;
  if oyun.genel_secim_sureci_aktif(t) then
    raise exception 'Genel seçim süreci başladı. Adaylıktan yeni seçilenlerin göreve başlamasına kadar erken seçim önerisi verilemez.';
  end if;
  if oyun.hukumet_sistemi()=0 then
    iktidar:=exists(select 1 from oyun.makamlar where tur='cb' and bit is null and parti_id=pid);
  else
    iktidar:=exists(select 1 from oyun.hukumet_partileri hp join oyun.hukumetler h on h.id=hp.hukumet_id
      where h.durum='gorevde' and h.bit is null and hp.parti_id=pid and hp.rol='ortak' and hp.aktif);
  end if;
  g:=oyun.metin_temizle(coalesce(p_gerekce,''),3000);
  if length(btrim(g))<5 then g:='Ülkenin erken seçime gitmesi önerilmektedir.'; end if;
  insert into oyun.erken_secim_teklifleri(teklif_eden,parti_id,tur,gerekce,bas,bit)
  values(p.id,pid,case when iktidar then 'iktidar_karari' else 'muhalefet_cagrisi' end,g,t,t+interval '12 hours');
  perform oyun.olay('secim',format('%s %s başlattı; karar TBMM oylamasında.',p.kad,case when iktidar then 'erken seçim kararı' else 'erken seçim çağrısı' end),null,pid,t);
  return public.siyasi_sistem();
end $function$
;