-- 2026-10-13 · Genel başkan yardımcılığı parti içi ek bir görevdir.
-- Belediye başkanı, milletvekili, bakan, cumhurbaşkanı ve CB yardımcısı
-- mevcut makamını kaybetmeden kendi partisinin GBY'si atanabilir.
-- TBMM Başkanı ve TBMM Başkanvekili için mevcut ayrılık kuralı korunur.
-- Bu migration oyunculara yeni görev ATAMAZ; yalnız atama kuralını düzeltir.

create or replace function oyun.rol_uyumlu(a text, b text)
returns boolean language sql immutable set search_path = '' as $$
  select (a='bakan' or b='bakan')
    or (a=b and a in ('gb','gby'))
    or (a,b) in (
       ('mv','gby'),('gby','mv'),
       ('gb','mv'),('mv','gb'),
       ('gb','cb'),('cb','gb'),
       ('mv','tbmm'),('tbmm','mv'),
       ('mv','bskv'),('bskv','mv'),
       ('mv','grup_bskv'),('grup_bskv','mv'),
       ('gby','grup_bskv'),('grup_bskv','gby'),
       ('bel','gby'),('gby','bel'),
       ('cb','gby'),('gby','cb'),
       ('cb_yardimcisi','gby'),('gby','cb_yardimcisi')
    );
$$;

-- Yetkiyi sadece mevcut parti genel başkanı kullanabilir.
-- Aynı kullanıcı iki GBY sırasını dolduramaz; mevcut makamına dokunulmaz.
create or replace function public.gby_ata(p_sira integer, p_kad text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  p oyun.profiller := oyun.profilim();
  hedef oyun.profiller;
  pa oyun.partiler;
  eski uuid;
  cakisma text;
begin
  select * into pa from oyun.partiler where id=p.parti_id for update;
  if pa.id is null or pa.kapali or pa.gb is distinct from p.id then
    raise exception 'Yalnızca görevdeki parti genel başkanı yardımcı atayabilir.';
  end if;
  if p_sira is null or p_sira not between 1 and 6 then
    raise exception 'Geçersiz sıra (1-6).';
  end if;

  select user_id into eski
  from oyun.parti_gby where parti_id=pa.id and sira=p_sira;

  if coalesce(btrim(p_kad),'')='' then
    delete from oyun.parti_gby where parti_id=pa.id and sira=p_sira;
    if eski is not null then
      perform oyun.bildir(eski,format('%s genel başkan yardımcılığı görevin sona erdi.',pa.kisa));
    end if;
    return public.durum();
  end if;

  select * into hedef from oyun.profiller
  where lower(kad)=lower(btrim(p_kad));
  if hedef.id is null or hedef.parti_id is distinct from pa.id then
    raise exception 'Bu kişi partinin üyesi değil.';
  end if;
  if hedef.id=p.id then raise exception 'Kendini yardımcı atayamazsın.'; end if;
  if coalesce(hedef.yasakli,false) then
    raise exception 'Kısıtlanmış oyuncu genel başkan yardımcısı atanamaz.';
  end if;
  cakisma:=oyun.rol_cakisma(hedef.id,'gby');
  if cakisma is not null then
    raise exception '% şu anda % görevinde; bu görev genel başkan yardımcılığıyla birleştirilemez.',hedef.kad,cakisma;
  end if;
  if eski=hedef.id then return public.durum(); end if;

  delete from oyun.parti_gby
  where parti_id=pa.id and (sira=p_sira or user_id=hedef.id);
  insert into oyun.parti_gby(parti_id,sira,user_id,atama)
  values(pa.id,p_sira,hedef.id,oyun.simdi());

  if eski is not null then
    perform oyun.bildir(eski,format('%s genel başkan yardımcılığı görevin sona erdi.',pa.kisa));
  end if;
  perform oyun.bildir(hedef.id,format('%s Genel Başkanı seni genel başkan yardımcısı olarak atadı.',pa.kisa));
  perform oyun.olay('parti',format('%s, %s genel başkan yardımcılığına atandı.',hedef.kad,pa.kisa),null,pa.id);
  return public.durum();
end $$;

-- İşlem içi regresyon kontrolleri: makam uyumu ve korunacak istisnalar.
do $$
begin
  if not oyun.rol_uyumlu('bel','gby')
     or not oyun.rol_uyumlu('gby','bel')
     or not oyun.rol_uyumlu('mv','gby')
     or not oyun.rol_uyumlu('bakan','gby')
     or not oyun.rol_uyumlu('cb','gby')
     or not oyun.rol_uyumlu('cb_yardimcisi','gby') then
    raise exception 'GBY makam uyumluluğu testi başarısız';
  end if;
  if oyun.rol_uyumlu('gb','gby') or oyun.rol_uyumlu('tbmm','gby')
     or oyun.rol_uyumlu('bskv','gby') or oyun.rol_uyumlu('bel','mv') then
    raise exception 'GBY ayrı tutulacak makam kontrolü başarısız';
  end if;
end $$;
