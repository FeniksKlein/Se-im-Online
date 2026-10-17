-- Cumhurbaşkanının TBMM oylaması gerektirmeyen erken genel seçim kararı.
-- Mevcut Meclis teklifleri korunur; yakın olağan seçim takvimini bozmayan
-- 80 numaralı koruma kuralı hem Meclis hem Cumhurbaşkanı kararlarında geçerlidir.
create table if not exists oyun.cb_erken_secim_kararlari (
  id bigserial primary key,
  cumhurbaskani uuid not null references oyun.profiller(id),
  gerekce text not null,
  karar_at timestamptz not null,
  secim_donem text not null,
  takvim_degisti boolean not null
);
alter table oyun.cb_erken_secim_kararlari enable row level security;
revoke all on oyun.cb_erken_secim_kararlari from public, anon, authenticated;

-- Negatif kimlikler CB kararlarına aittir; TBMM tekliflerindeki pozitif ID'lerle
-- çakışmaz. Var olan iki parametreli fonksiyon imzası aynı kalır.
create or replace function oyun.erken_genel_secim_olustur(t timestamptz, p_teklif bigint) returns text
language plpgsql set search_path='' as $$
declare
  ilk date; ongun date; secgun date; dm text; eski text; eski_oy timestamptz;
  karar_sahibi text := case when p_teklif < 0 then 'Cumhurbaşkanı' else 'TBMM' end;
begin
  ilk:=(t at time zone 'Europe/Istanbul')::date;
  if oyun.tr_an(ilk,8)<t+interval '8 hours' then ilk:=ilk+1; end if;
  ongun:=ilk; secgun:=ilk+1;
  dm:='erken-genel-'||p_teklif||'-'||to_char(t at time zone 'Europe/Istanbul','YYYYMMDDHH24MISS');
  select donem,oy_bas into eski,eski_oy from oyun.secimler
  where tur='mv' and not ara and durum='bekliyor' and oy_bas>t order by oy_bas limit 1;

  -- Erken seçim, birkaç gün sonraki olağan seçimi ileriye taşıyamaz.
  if eski is not null and eski_oy <= oyun.tr_an(secgun,8)+interval '7 days' then
    perform oyun.olay('secim',format('%s erken seçim kararı aldı. Genel seçim zaten %s günü yapılacağı için takvim değişmedi; başvurular geçerli.',
      karar_sahibi,to_char(eski_oy at time zone 'Europe/Istanbul','DD.MM.YYYY')),null,null,t);
    return eski;
  end if;
  if eski is not null then
    update oyun.secimler set durum='tamam',
      sonuc=coalesce(sonuc,'{}'::jsonb)||jsonb_build_object('iptal','erken_secim')
    where donem=eski and durum='bekliyor' and tur in ('mv_on','mv','cb_on','cb','cb2');
  end if;
  insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
    ('mv_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
    ('mv',dm,null,null,oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  if oyun.hukumet_sistemi()=0 then
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,ara_neden) values
      ('cb_on',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(ongun,8),oyun.tr_an(ongun,22),oyun.tr_an(ongun,22,30),null,true,'erken_secim'),
      ('cb',dm,t,oyun.tr_an(ongun,8),oyun.tr_an(secgun,8),oyun.tr_an(secgun,22),oyun.tr_an(secgun,22,30),oyun.tr_an(secgun+1,0),true,'erken_secim');
  end if;
  perform oyun.olay('secim',format('%s erken seçim kararı aldı. Erken genel seçim %s günü yapılacak.',
    karar_sahibi,to_char(secgun,'DD.MM.YYYY')),null,null,t);
  return dm;
end $$;

-- TBMM'deki oylama CB kararıyla aynı anda devam edebilir. Meclis de kabul
-- ederse, önceden açılmış erken seçim takvimi tekrar oluşturulmaz.
create or replace function oyun.erken_secim_sonuc(p_id bigint,t timestamptz) returns void
language plpgsql set search_path='' as $$
declare x oyun.erken_secim_teklifleri; evet int; hayir int; gerek int; dm text;
begin
  perform 1 from oyun.ayarlar where id=1 for update;
  select * into x from oyun.erken_secim_teklifleri where id=p_id for update;
  if x.id is null or x.durum<>'oylamada' then return; end if;
  select count(*) filter(where oy='kabul'),count(*) filter(where oy='ret')
    into evet,hayir from oyun.erken_secim_oylari where teklif_id=p_id;
  gerek:=oyun.erken_secim_gerekli_oy();
  if evet>=gerek then
    select donem into dm from oyun.secimler where tur='mv' and ara
      and ara_neden='erken_secim' and durum='bekliyor' order by oy_bas limit 1;
    if dm is null then dm:=oyun.erken_genel_secim_olustur(t,p_id); end if;
    update oyun.erken_secim_teklifleri set durum='kabul',secim_donem=dm where id=p_id;
  elsif t>=x.bit then
    update oyun.erken_secim_teklifleri set durum='ret' where id=p_id;
    perform oyun.olay('secim',format('Erken seçim önerisi reddedildi (%s kabul, %s ret; gerekli %s).',
      evet,hayir,gerek),null,x.parti_id,t);
  end if;
end $$;

create or replace function public.cb_erken_secim_karar(p_gerekce text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  g text; karar_id bigint; dm text; degisti boolean; secim_bas timestamptz;
begin
  -- Aynı anda iki karar verilerek iki ayrı seçim açılmasını engelle.
  perform 1 from oyun.ayarlar where id=1 for update;
  if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null) then
    raise exception 'Erken seçime yalnızca görevdeki Cumhurbaşkanı karar verebilir.';
  end if;
  if exists(select 1 from oyun.secimler where ara and ara_neden='erken_secim' and durum='bekliyor') then
    raise exception 'Önceden kararlaştırılmış bir erken seçim takvimi zaten var.';
  end if;
  if exists(select 1 from oyun.secimler where tur in ('mv_on','mv','cb_on','cb','cb2')
    and durum='bekliyor' and oy_bas<=t and oy_bit>t) then
    raise exception 'Devam eden seçim veya ön seçim oylaması sırasında erken seçim kararı alınamaz.';
  end if;
  if exists(select 1 from oyun.cb_erken_secim_kararlari where karar_at>t-interval '24 hours') then
    raise exception 'Cumhurbaşkanı 24 saat içinde yeniden erken seçim kararı alamaz.';
  end if;
  g:=oyun.metin_temizle(coalesce(p_gerekce,''),1000);
  if length(btrim(g))<10 then raise exception 'Karar gerekçesi en az 10 karakter olmalı.'; end if;

  -- Karar ve seçim takvimi tek veritabanı işleminde oluşur; bir hata ikisini de geri alır.
  insert into oyun.cb_erken_secim_kararlari(cumhurbaskani,gerekce,karar_at,secim_donem,takvim_degisti)
  values(p.id,g,t,'beklemede',false) returning id into karar_id;
  dm:=oyun.erken_genel_secim_olustur(t,-karar_id);
  degisti:=left(dm,12)='erken-genel-';
  update oyun.cb_erken_secim_kararlari set secim_donem=dm,takvim_degisti=degisti where id=karar_id;
  select oy_bas into secim_bas from oyun.secimler where tur='mv' and donem=dm limit 1;
  return jsonb_build_object('donem',dm,'takvim_degisti',degisti,'oy_bas',secim_bas,
    'mesaj',case when degisti then 'Cumhurbaşkanının erken seçim kararı alındı; seçim takvimi açıldı.'
      else 'Karar kaydedildi; yakın olağan seçim tarihi ve mevcut adaylıklar korundu.' end);
end $$;
revoke all on function public.cb_erken_secim_karar(text) from public, anon;
grant execute on function public.cb_erken_secim_karar(text) to authenticated;
