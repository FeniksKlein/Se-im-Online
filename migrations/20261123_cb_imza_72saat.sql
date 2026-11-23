-- Canlıya 23.11.2026'da Supabase migration'ı olarak uygulandı: cb_imza_72saat_20261123
-- Kaynak: gelistirici/sql/zz_20261123_cb_imza_72saat.sql · tekrar çalıştırmak güvenlidir.
begin;

-- 23.11.2026 · Bağımsız Cumhurbaşkanı adaylığı: gerçek 72 saat imza süresi + aday gösteremeyen parti üyeleri
-- İstek (Ercan): "ikisini de düzelt".
--  1) İmza kampanyası adaylık başvurusu kapanınca bitiyordu (açılışta en çok 32, normal ayda en çok 48 saat).
--     Artık imza toplama başvuru süresinden bağımsızdır: kampanya açıldığı andan itibaren 72 saat sürer,
--     en geç Cumhurbaşkanı seçimi sandığından 6 saat önce kapanır (oyun kuralı: pusula kesinleşsin).
--     Kampanya AÇMA yine yalnız adaylık başvurusu süresinde yapılır (sıra: adaylık → ön seçim → seçim).
--  2) Partisi Cumhurbaşkanı adayı gösteremeyen (TBMM grubu / %5 şartı yok) üye sunucuda bağımsız aday
--     olabiliyordu ama istemci düğmeyi yalnız partisizlere gösteriyordu. Takvim özetine istemcinin
--     kullanacağı alanlar eklendi (eski uygulamalar bu alanları görmezden gelir).
--  3) Uzayan sürenin açığı kapatıldı: imza toplarken aday gösterme hakkı olan bir partiye katılan adayın
--     kampanyası geçersiz sayılır (imza alamaz, liste okunurken iptal edilir; teminat iade edilmez).
-- Tekrar çalıştırmak güvenlidir. zz_20261121_00_yama'daki oyun._yama yardımcısını kullanır.

-- 1) Kampanya bitişi: 72 saat, en geç asıl seçim sandığından 6 saat önce (eski kuraldan kısa olamaz).
select oyun._yama('public.bagimsiz_aday_ol(bigint)',
  $d$least(o.basvuru_bit,t+interval '72 hours')$d$,
  $d$/* cb_imza_72saat */ greatest(least(o.basvuru_bit,t+interval '72 hours'),least(t+interval '72 hours',h.oy_bas-interval '6 hours'))$d$,
  'cb_imza_72saat', true);

-- 2) İmza verme: başvuru penceresine değil kampanya süresine ve asıl seçimin başlamamış olmasına bağlı.
create or replace function public.cb_bagimsiz_imzala(p_kampanya bigint) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); k oyun.cb_bagimsiz_kampanya; pr oyun.profiller; n int;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 select * into pr from oyun.profiller where id=u;
 if pr.id is null or pr.yasakli or pr.olusturma>t-interval '1 day'
    or pr.son_gorulme<t-interval '7 days'
 then raise exception 'İmza için kısıtsız, en az bir günlük ve aktif hesap gerekir.'; end if;
 select * into k from oyun.cb_bagimsiz_kampanya where id=p_kampanya for update;
 if k.id is null or k.durum<>'imza' or t<k.bas or t>=k.bit then raise exception 'İmza kampanyası kapalı.'; end if;
 /* cb_imza_72saat */
 if not exists(select 1 from oyun.secimler where id=k.secim_id and durum='bekliyor' and t<oy_bas)
 then raise exception 'Seçim başladığı için imza toplama sona erdi.'; end if;
 if exists(select 1 from oyun.profiller ap join oyun.secimler hs on hs.id=k.secim_id
           where ap.id=k.aday and ap.parti_id is not null
             and oyun.cb_parti_aday_gosterebilir(ap.parti_id,hs.donem))
 then raise exception 'Aday, Cumhurbaşkanı adayı gösterebilen bir partiye katıldığı için bu imza kampanyası geçersiz.'; end if;
 if exists(select 1 from oyun.cb_bagimsiz_destek where secim_id=k.secim_id and secmen=u)
 then raise exception 'Bu seçimde zaten bir aday için imza verdin.'; end if;
 insert into oyun.cb_bagimsiz_destek(secim_id,kampanya_id,secmen,zaman) values(k.secim_id,k.id,u,t);
 select count(*) into n from oyun.cb_bagimsiz_destek where kampanya_id=k.id;
 if n>=k.hedef then
   if exists(select 1 from oyun.adaylar where secim_id=k.secim_id and user_id=k.aday)
     then raise exception 'Adayın zaten aynı seçimde kaydı var.'; end if;
   insert into oyun.adaylar(secim_id,user_id,parti_id,basvuru_at) values(k.secim_id,k.aday,null,t);
   update oyun.cb_bagimsiz_kampanya set durum='onay' where id=k.id;
   perform oyun.para_islem(k.aday,k.teminat,'aday','Bağımsız Cumhurbaşkanı imza teminatı iadesi',t);
   perform oyun.bildir(k.aday,format('Bağımsız Cumhurbaşkanı adaylığın %s imzayla kesinleşti; teminatın iade edildi.',n),t);
   perform oyun.olay('secim',format('%s, %s imzayla bağımsız Cumhurbaşkanı adayı oldu.',oyun.kad(k.aday),n),null,null,t);
 end if;
 return public.cb_bagimsiz_kampanyalar(k.on_secim_id);
end $f$;

-- 3) Liste: süresi dolanı kapat, partiye geçen adayın kampanyasını iptal et (aday bilgilendirilir).
create or replace function public.cb_bagimsiz_kampanyalar(p_on_secim bigint default null) returns jsonb
language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); r record;
begin
 if u is null then raise exception 'Oturum gerekli.'; end if;
 update oyun.cb_bagimsiz_kampanya set durum='sure_doldu' where durum='imza' and bit<=t;
 /* cb_imza_72saat */
 for r in update oyun.cb_bagimsiz_kampanya k set durum='iptal'
          from oyun.profiller ap, oyun.secimler hs
          where k.durum='imza' and ap.id=k.aday and hs.id=k.secim_id and ap.parti_id is not null
            and oyun.cb_parti_aday_gosterebilir(ap.parti_id,hs.donem)
          returning k.aday loop
   perform oyun.bildir(r.aday,'Cumhurbaşkanı adayı gösterebilen bir partiye katıldığın için bağımsız adaylık imza kampanyan iptal edildi. Teminat iade edilmez.',t);
 end loop;
 return jsonb_build_object('gercekci',oyun.gercekci_siyaset(),
   'liste',coalesce((select jsonb_agg(jsonb_build_object(
      'id',k.id,'on_secim_id',k.on_secim_id,'aday',p.kad,
      'hedef',k.hedef,'toplanan',(select count(*) from oyun.cb_bagimsiz_destek d where d.kampanya_id=k.id),
      'bas',k.bas,'bit',k.bit,'durum',k.durum,'benim',k.aday=u,
      'imzaladim',exists(select 1 from oyun.cb_bagimsiz_destek d where d.secim_id=k.secim_id and d.secmen=u),
      'imza_verebilirim',k.durum='imza' and k.bit>t and not exists(select 1 from oyun.cb_bagimsiz_destek d where d.secim_id=k.secim_id and d.secmen=u)
    ) order by k.id desc)
    from oyun.cb_bagimsiz_kampanya k join oyun.profiller p on p.id=k.aday
    where (p_on_secim is null or k.on_secim_id=p_on_secim)
      and exists(select 1 from oyun.secimler s where s.id=k.secim_id and s.durum='bekliyor' and t<s.oy_bas)
  ),'[]'::jsonb));
end $f$;
revoke all on function public.cb_bagimsiz_kampanyalar(bigint),public.cb_bagimsiz_imzala(bigint) from public,anon;
grant execute on function public.cb_bagimsiz_kampanyalar(bigint),public.cb_bagimsiz_imzala(bigint) to authenticated;

-- 4) Takvim özeti: istemcinin düğme ve imza kartı için kullandığı alanlar (yalnız cb_on / cb satırlarında dolu).
--    bagimsiz_acik : partili ama partisi aday gösteremeyen oyuncu, başvuru açıkken bağımsız aday olabilir.
--    cb_bagimsiz   : (cb_on) kendi bağımsız adaylığım / süren imza kampanyam.
--    cb_imza       : (cb)    süren imza kampanyası sayısı, son imza anı ve imza ekranının açılacağı ön seçim.
do $yama$
declare fn text; ek text := $e$/* cb_imza_72saat */
    'bagimsiz_acik', case when s.tur='cb_on' and p.parti_id is not null and s.durum='bekliyor'
        and s.basvuru_bas is not null and t>=s.basvuru_bas and t<s.basvuru_bit and oyun.gercekci_siyaset()
      then not oyun.cb_parti_aday_gosterebilir(p.parti_id,s.donem) else false end,
    'cb_bagimsiz', case when s.tur='cb_on' and s.durum='bekliyor' then (
      select jsonb_build_object(
        'adayim', exists(select 1 from oyun.adaylar ba where ba.secim_id=bh.id and ba.user_id=p.id and ba.parti_id is null),
        'kampanyam', exists(select 1 from oyun.cb_bagimsiz_kampanya bk where bk.secim_id=bh.id and bk.aday=p.id and bk.durum='imza' and bk.bit>t))
      from oyun.secimler bh where bh.donem=s.donem and bh.tur='cb' limit 1) end,
    'cb_imza', case when s.tur='cb' and s.durum='bekliyor' and t<s.oy_bas then (
      select jsonb_build_object('on_secim_id', bo.id,
        'acik', (select count(*) from oyun.cb_bagimsiz_kampanya bk where bk.secim_id=s.id and bk.durum='imza' and bk.bit>t),
        'son', (select max(bk.bit) from oyun.cb_bagimsiz_kampanya bk where bk.secim_id=s.id and bk.durum='imza' and bk.bit>t),
        'kampanyam', exists(select 1 from oyun.cb_bagimsiz_kampanya bk where bk.secim_id=s.id and bk.aday=p.id and bk.durum='imza' and bk.bit>t))
      from oyun.secimler bo where bo.donem=s.donem and bo.tur='cb_on' limit 1) end,
    'oy_verdim',$e$;
begin
  foreach fn in array array['oyun.secim_ozet(oyun.secimler,oyun.profiller,timestamptz)',
                            'oyun.secim_ozet_takvim(oyun.secimler,oyun.profiller,timestamptz)'] loop
    perform oyun._yama(fn, $d$'oy_verdim',$d$, ek, 'cb_imza_72saat', true);
  end loop;
end $yama$;

commit;
