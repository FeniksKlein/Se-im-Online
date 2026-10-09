-- Genel başkan + milletvekili uyumunun seçim ve göreve başlama motorunda tamamlanması.
CREATE OR REPLACE FUNCTION oyun.goreve_baslat(p_sid bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare s oyun.secimler; k record; m record; t timestamptz; ilk oyun.secimler;
begin
  select * into s from oyun.secimler where id = p_sid for update;
  if s.durum <> 'sonuclandi' then return; end if;
  t := s.goreve_bas;

  if s.tur = 'kurultay' then
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id and parti_id = k.parti_id);
      if (select gb from oyun.partiler where id = k.parti_id) is distinct from k.user_id then
        delete from oyun.parti_gby where parti_id = k.parti_id;   -- yeni genel başkan kendi ekibini kurar
      end if;
      delete from oyun.parti_gby where user_id = k.user_id;       -- genel başkan aynı zamanda yardımcı olamaz
      -- Yeni genel başkanın milletvekilliği ve cumhurbaşkanlığı kalır; diğer makamları sona erer
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null and tur not in ('cb','mv') loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      update oyun.partiler set gb = k.user_id where id = k.parti_id;
      perform oyun.bildir(k.user_id, format('Kurultayı kazandın: %s Genel Başkanı oldun. 6 genel başkan yardımcını atayabilirsin.', (select ad from oyun.partiler where id = k.parti_id)), t);
    end loop;
    -- BOŞ MAKAM KURALI: kurultayda kimse aday olmadığı için genel başkansız kalan parti kıdemli üyesini genel başkan yapar
    perform oyun.gb_halef(t);
  elsif s.tur = 'cb' and coalesce((s.sonuc->>'ikinci_tur')::boolean, false) then
    null; -- 2. tur bekleniyor: görevdeki cumhurbaşkanı 2. tur sonucuna kadar devam eder
  else
    -- Milletvekilleri liste usulüyle seçilir: eski Meclis topluca biter. (Boş kalan sandalyeleri yedek listeler doldurur.)
    if s.tur = 'mv' then
      for m in select id from oyun.makamlar where tur = 'mv' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'donem_bitti');
      end loop;
    end if;
    -- BOŞ MAKAM KURALI: belediye başkanlığı ve cumhurbaşkanlığında eski görevli ancak yerine yenisi gerçekten başlayınca düşer.
    -- Seçimde aday çıkmadıysa (ya da kazanan göreve başlayamadıysa) görevdeki, yeni biri seçilene kadar görevine devam eder.
    for k in select * from oyun.kazananlar where secim_id = s.id loop
      continue when not exists (select 1 from oyun.profiller where id = k.user_id);   -- hesap silinmiş
      -- Genel başkan belediye başkanı olamaz; milletvekili olabilir (adaylığı zaten engellenir; yine de güvenceye al)
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) = 'bel'
         and exists (select 1 from oyun.partiler where gb = k.user_id) then
        perform oyun.bildir(k.user_id, 'Genel başkan olduğun için seçildiğin bu görevi üstlenemezsin.', t);
        if s.tur = 'mv' then perform oyun.yedek_getir(s.id, k.il_id, k.parti_id, t); end if;
        continue;
      end if;
      -- Yerine geçilen görevli (aynı ilin belediye başkanı / cumhurbaşkanı) görevi devreder
      if s.tur = 'bel' then
        for m in select id from oyun.makamlar where tur = 'bel' and il_id = k.il_id and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      elsif s.tur in ('cb','cb2') then
        for m in select id from oyun.makamlar where tur = 'cb' and bit is null loop
          perform oyun.makam_bitir(m.id, t, 'donem_bitti');
        end loop;
      end if;
      -- Milletvekili seçilen genel başkan partisini yönetmeye devam edebilir
      if (case when s.tur = 'cb2' then 'cb' else s.tur end) in ('bel','cb') then
        delete from oyun.parti_gby where user_id = k.user_id;
      end if;
      for m in select id from oyun.makamlar where user_id = k.user_id and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'yeni_gorev');
      end loop;
      insert into oyun.makamlar(tur, user_id, il_id, parti_id, secim_id, bas)
      values (case when s.tur = 'cb2' then 'cb' else s.tur end, k.user_id, k.il_id, k.parti_id, s.id, t);
      perform oyun.bildir(k.user_id, case when s.tur in ('cb','cb2') then 'Cumhurbaşkanı olarak göreve başladın. Kabineni kurmak için 12 bakanı atayabilirsin.'
        else format('%s olarak göreve başladın.', case s.tur when 'mv' then (select ad from oyun.iller where id = k.il_id) || ' Milletvekili'
                                                         else (select ad from oyun.iller where id = k.il_id) || ' Belediye Başkanı' end) end, t);
    end loop;
    -- Seçimde kimse kazanamadıysa görevde kalanlara haber ver
    if s.tur in ('cb','cb2') and not exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select user_id from oyun.makamlar where tur = 'cb' and bit is null loop
        perform oyun.bildir(m.user_id, 'Cumhurbaşkanlığı seçiminde yeni bir başkan çıkmadı; yeni cumhurbaşkanı seçilene kadar görevine devam ediyorsun.', t);
      end loop;
    end if;
    -- Yeni Meclis göreve başlayınca sonuçlanmamış kanun teklifleri kadük olur
    if s.tur = 'mv' then perform oyun.kanunlar_kaduk(t); end if;
    -- Yeni bir cumhurbaşkanlığı dönemi gerçekten başlayınca kabine yenilenir; seçimde kimse kazanamadıysa kabine yerinde kalır
    if s.tur in ('cb','cb2') and exists (select 1 from oyun.makamlar where tur = 'cb' and secim_id = s.id) then
      for m in select id from oyun.makamlar where tur = 'bakan' and bit is null loop
        perform oyun.makam_bitir(m.id, t, 'kabine_yenilendi');
      end loop;
    end if;
  end if;
  update oyun.secimler set durum = 'tamam' where id = s.id;
end $function$
;

create or replace function oyun.gb_halef(t timestamptz) returns void language plpgsql as $$
declare pa record; aday uuid;
begin
  for pa in select id, ad from oyun.partiler where not kapali and gb is null loop
    select pr.id into aday from oyun.profiller pr
     where pr.parti_id = pa.id and not pr.yasakli
       and not exists (select 1 from oyun.makamlar m where m.user_id = pr.id and m.bit is null and m.tur not in ('cb','mv'))
     order by oyun.kidem_puani(pr.id) desc, pr.parti_at, pr.id limit 1;
    continue when aday is null;
    delete from oyun.parti_gby where user_id = aday;       -- genel başkan aynı zamanda yardımcı olamaz
    update oyun.partiler set gb = aday where id = pa.id and gb is null;
    perform oyun.bildir(aday, format('%s kurultayda genel başkansız kaldığı için kıdemin en yüksek olduğu üye olarak genel başkan oldun. Bir sonraki kurultayda üyeler genel başkanı yeniden seçecek; 6 genel başkan yardımcını atayabilirsin.', pa.ad), t);
    perform oyun.olay('parti', format('%s genel başkansız kaldı; kıdemi en yüksek üye %s genel başkan oldu.', pa.ad, (select kad from oyun.profiller where id = aday)), null, pa.id, t);
  end loop;
end $$;

-- BEGIN 2026-10-08 GAZETE KOSE YORUM & BANKA TAAHHUT KORUMA (kalici)
-- Existing records are untouched; new newspaper-comments table is private.
create table if not exists oyun.gazete_kose_yorum(
 id bigint generated by default as identity primary key,
 yayin_id bigint not null references oyun.gazete_yayinlari(id) on delete cascade,
 user_id uuid not null references oyun.profiller(id) on delete cascade,
 metin text not null check(char_length(metin) between 2 and 500),
 zaman timestamptz not null default now(),
 silindi boolean not null default false
);
create index if not exists gazete_kose_yorum_yayin on oyun.gazete_kose_yorum(yayin_id,zaman desc,id desc) where not silindi;
create index if not exists gazete_kose_yorum_user on oyun.gazete_kose_yorum(user_id,zaman desc);
alter table oyun.gazete_kose_yorum enable row level security;
revoke all on oyun.gazete_kose_yorum from public,anon,authenticated;
revoke all on sequence oyun.gazete_kose_yorum_id_seq from public,anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.sirket_hesapla(p_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare s oyun.sirketler;n int;i int;net numeric;income numeric;cost numeric;w numeric;t timestamptz:=oyun.simdi();x record;distributed numeric;rate numeric;v_taahhut numeric;v_mevduat numeric;
begin
 perform pg_advisory_xact_lock(98763,hashtext(p_id::text));
 select * into s from oyun.sirketler where id=p_id for update;
 if s.id is null or not s.aktif or s.sonraki_kazanc>t then return;end if;
 n:=least(52,floor(extract(epoch from (t-s.sonraki_kazanc))/604800)::int+1);
 w:=(select asgari from oyun.ulke where id=1);
 rate:=case s.sektor when 'tarim' then .12 when 'sanayi' then .15 when 'teknoloji' then .20 when 'ticaret' then .14 when 'insaat' then .18 when 'medya' then .16 else .08 end;
 for i in 1..n loop
  income:=round(s.sermaye*rate*(0.6+random()*.8),2);
  cost:=round(s.sermaye*(.025+random()*.055)+w*(.5+random()),2);
  net:=income-cost;
  -- Zararda sirket kasasi erir. Karda dagitilabilir para ortaklara aktarilir.
  if net<0 then
   if s.sektor='banka' then
     select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0) into v_taahhut,v_mevduat from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi;
     net:=greatest(net,-greatest(0,(select kasa from oyun.sirketler where id=p_id)-v_taahhut-greatest(s.sermaye*0.10,v_mevduat*0.10)));
   end if;
   update oyun.sirketler set kasa=kasa+net where id=p_id;
  else
   distributed:=case when s.sektor='banka' then least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net-s.sermaye-coalesce((select sum(round(m.anapara*(1+m.faiz/100),2)) from oyun.banka_mevduat m where m.banka_id=p_id and not m.kapandi),0))) else least(net,greatest(0,(select kasa from oyun.sirketler where id=p_id)+net)) end;
   for x in select * from oyun.sirket_ortaklari where sirket_id=p_id loop
    perform oyun.para_islem(x.user_id,round(distributed*x.pay/100,2),'sirket',format('Sirket #%s haftalik net kar payi',p_id),t);
   end loop;
   update oyun.sirketler set kasa=kasa+net-distributed where id=p_id;
  end if;
  insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama) values(p_id,t,net,'7 gunluk faaliyet net sonucu; pozitif tutar ortaklara aktarildi');
 end loop;
 update oyun.sirketler set sonraki_kazanc=sonraki_kazanc+n*interval '7 days',son_islem=t where id=p_id;
end $function$;

CREATE OR REPLACE FUNCTION public.banka_mevduat_teklif(p_banka bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();s oyun.sirketler;v_borc numeric;v_anapara numeric;v_odeme numeric;v_guvence numeric;v_uygun boolean;v_ortak boolean;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into s from oyun.sirketler where id=p_banka and aktif and sektor='banka';
 if s.id is null then raise exception 'Banka bulunamadi';end if;
 if p_tutar is null or p_tutar<>round(p_tutar) or p_tutar<1000 or p_tutar>10000000 then
  raise exception 'Mevduat tutari 1.000 - 10.000.000 TL olmali';end if;
 select coalesce(sum(round(m.anapara*(1+m.faiz/100),2)),0),coalesce(sum(m.anapara),0)
 into v_borc,v_anapara from oyun.banka_mevduat m where m.banka_id=p_banka and not m.kapandi;
 v_odeme:=round(p_tutar*(1+s.banka_faiz/100),2);
 v_guvence:=greatest(s.sermaye*0.10,(v_anapara+p_tutar)*0.10);
 v_ortak:=exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=p_banka and o.user_id=u and o.pay>0);
 v_uygun:=not v_ortak and s.banka_faiz between 0 and 3
       and s.kasa >= v_borc+(v_odeme-p_tutar)+v_guvence;
 return jsonb_build_object(
  'banka',s.ad,'tutar',p_tutar,'haftalik_faiz',s.banka_faiz,
  'vade_sonu_odeme',v_odeme,'faiz_kazanci',v_odeme-p_tutar,
  'kasa',s.kasa,'acik_taahhut',v_borc,'zorunlu_tampon',v_guvence,
  'bankam',v_ortak,'odeme_garantisi_icin_yeterli',v_uygun,
  'uyari',case when v_ortak then 'Kendi bankana mevduat yatiramazsin'
              when not v_uygun then 'Bu tutarin vade sonu faizi kasada guvenceye alinmis degil'
              else 'Vade sonu odeme tutari bankanin kasasinda guvenceye alindi' end);
end $function$;

CREATE OR REPLACE FUNCTION public.gazete_kose_yorumlar(p_yayin bigint, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();y oyun.gazete_yayinlari;g oyun.oyuncu_gazeteleri;t timestamptz:=oyun.simdi();er boolean;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into y from oyun.gazete_yayinlari where id=p_yayin and tur='kose';
 if y.id is null then raise exception 'Kose yazisi bulunamadi';end if;
 select * into g from oyun.oyuncu_gazeteleri where id=y.gazete_id and aktif;
 if g.id is null then raise exception 'Gazete bulunamadi';end if;
 er:=oyun.gazete_erisim(g.id,u,t);
 if not er then raise exception 'Yorumlari gormek icin gazeteye abone olmalisin';end if;
 return jsonb_build_object('yayin_id',y.id,'gazete_id',g.id,'baslik',y.baslik,
 'yorumlar',coalesce((
   select jsonb_agg(jsonb_build_object('id',x.id,'kad',oyun.kad(x.user_id),'metin',x.metin,
   'zaman',x.zaman,'benim',x.user_id=u,'silebilir',x.user_id=u or g.sahip=u)
     order by x.zaman,x.id)
   from (select * from oyun.gazete_kose_yorum where yayin_id=y.id and not silindi order by zaman desc,id desc
         limit least(greatest(coalesce(p_limit,50),1),100)) x
 ),'[]'::jsonb),'yorum_sayisi',(select count(*) from oyun.gazete_kose_yorum where yayin_id=y.id and not silindi));
end $function$;

CREATE OR REPLACE FUNCTION public.gazete_kose_yorum_yaz(p_yayin bigint, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();y oyun.gazete_yayinlari;g oyun.oyuncu_gazeteleri;t timestamptz:=oyun.simdi();m text:=btrim(coalesce(p_metin,''));
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli';end if;
 if char_length(m) not between 2 and 500 then raise exception 'Yorum 2-500 karakter olmali';end if;
 select * into y from oyun.gazete_yayinlari where id=p_yayin and tur='kose';
 if y.id is null then raise exception 'Kose yazisi bulunamadi';end if;
 select * into g from oyun.oyuncu_gazeteleri where id=y.gazete_id and aktif;
 if g.id is null or not oyun.gazete_erisim(g.id,u,t) then
   raise exception 'Yorum icin gazeteye abone olmalisin';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,553125));
 if exists(select 1 from oyun.gazete_kose_yorum where user_id=u and zaman>t-interval '30 seconds')
 then raise exception 'Yeni yorum icin 30 saniye beklemelisin';end if;
 if (select count(*) from oyun.gazete_kose_yorum where user_id=u and zaman>=t-interval '24 hours')>=25
 then raise exception '24 saatlik yorum sinirina ulastin';end if;
 insert into oyun.gazete_kose_yorum(yayin_id,user_id,metin,zaman) values(y.id,u,m,t);
 return public.gazete_kose_yorumlar(y.id,50);
end $function$;

CREATE OR REPLACE FUNCTION public.gazete_kose_yorum_sil(p_yorum bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();x oyun.gazete_kose_yorum;y oyun.gazete_yayinlari;g oyun.oyuncu_gazeteleri;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into x from oyun.gazete_kose_yorum where id=p_yorum for update;
 if x.id is null or x.silindi then raise exception 'Yorum bulunamadi';end if;
 select * into y from oyun.gazete_yayinlari where id=x.yayin_id;
 select * into g from oyun.oyuncu_gazeteleri where id=y.gazete_id;
 if x.user_id<>u and g.sahip is distinct from u then raise exception 'Yorumu silme yetkin yok';end if;
 update oyun.gazete_kose_yorum set silindi=true where id=x.id;
 return jsonb_build_object('tamam',true,'yayin_id',x.yayin_id);
end $function$;
revoke all on function public.gazete_kose_yorumlar(bigint,integer) from public,anon;
revoke all on function public.gazete_kose_yorum_yaz(bigint,text) from public,anon;
revoke all on function public.gazete_kose_yorum_sil(bigint) from public,anon;
revoke all on function public.banka_mevduat_teklif(bigint,numeric) from public,anon;
grant execute on function public.gazete_kose_yorumlar(bigint,integer) to authenticated;
grant execute on function public.gazete_kose_yorum_yaz(bigint,text) to authenticated;
grant execute on function public.gazete_kose_yorum_sil(bigint) to authenticated;
grant execute on function public.banka_mevduat_teklif(bigint,numeric) to authenticated;
-- END 2026-10-08 GAZETE KOSE YORUM & BANKA TAAHHUT KORUMA
