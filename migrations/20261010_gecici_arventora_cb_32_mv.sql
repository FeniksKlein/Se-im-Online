-- 2026-10-10: Tek seferlik canli oyun yonetici atamasi.
-- Supabase'de uygulanma ve dogrulama: 32 mevcut oyuncu = 32 aktif MV.
-- ArvenTora, Istanbul MV + CB. Yeni oyunculara otomatik MV atamasi YOK.
-- Secimle gorev devri, mevcut oyun.goreve_baslat(bigint) tarafindan yapilir.
-- Yeniden calistirma guvenligi: sadece ilk atamanin baslangicindan onceki profiller.
begin;
do $$
declare
  u uuid;
  part bigint;
  ist smallint;
  siradaki_mv bigint;
  don text;
begin
  perform pg_advisory_xact_lock(hashtext('20261010_gecici_makam'));
  select id,parti_id into u,part from oyun.profiller where kad='ArvenTora';
  select id into ist from oyun.iller where ad='İstanbul';
  if u is null or ist is null then raise exception 'ArvenTora veya Istanbul bulunamadi'; end if;
  select id,donem into siradaki_mv,don from oyun.secimler
  where tur='mv' and durum in ('bekliyor','sonuclandi') and goreve_bas>oyun.simdi()
  order by goreve_bas,id limit 1;

  -- Ilk kurulum icin 2026-10-12 genel secimine kadar gecerlidir.
  -- Eski donem bitmisse daha sonraki bir secim icin tekrar atama YAPMA.
  if siradaki_mv is null or don<>'2026-11' or not exists
    (select 1 from oyun.secimler where tur='cb' and donem=don
     and durum in ('bekliyor','sonuclandi') and goreve_bas>oyun.simdi()) then
    raise exception '2026-10-12 genel secim donemi aktif degil; atama yapilmadi';
  end if;

  if exists(select 1 from oyun.makamlar
            where tur='cb' and bit is null and user_id<>u) then
    raise exception 'Baska bir cumhurbaskani gorevde'; end if;

  insert into oyun.makamlar(tur,user_id,parti_id,kaynak,bas)
  select 'cb',u,part,'atama',oyun.simdi()
  where not exists(select 1 from oyun.makamlar
                   where tur='cb' and bit is null);

  insert into oyun.makamlar(tur,user_id,il_id,parti_id,kaynak,bas)
  select 'mv',p.id,p.il_id,p.parti_id,'atama',oyun.simdi()
  from oyun.profiller p
  where p.olusturma <= '2026-10-10 12:14:04.120955+00'::timestamptz
    and p.il_id is not null
    and not exists(select 1 from oyun.makamlar m
                   where m.tur='mv' and m.user_id=p.id and m.bit is null);
end $$;
commit;

-- Canli dogrulama (10 Ekim 2026, 15:14 TSİ):
-- toplam_oyuncu=32, aktif_mv=32, eslesen_mv=32.
-- ArvenTora hem 'cb', hem İstanbul ilindeki 'mv' kaydina sahiptir.
-- Secim sonucundan sonra MV'ler topluca sona erer;
-- yeni CB secilip goreve baslayinca onceki CB devreder.
