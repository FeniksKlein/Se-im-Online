-- 2026.11.13-7 · CB yardımcısı: "Tüm bakanlıklar"a toplu görev/proje, toplu dosya ilerlemesi, hatırlatma
-- Sorun (beta): Yeni dosya penceresinde "Tüm bakanlıklar / seçilmedi" seçeneği vardı ama görev ve
-- projede sunucu ve arayüz "Bakanlık seçmelisin" diyordu; tüm bakanlıklara görev göndermek imkânsızdı.
-- Çözüm: p_bakanlik='*' → yardımcının görev alanındaki her bakanlığa ayrı dosya (her bakan kendi
-- dosyasını yanıtlar). Toplu dosyalar veri.toplu ile gruplanır ve günlük 8 işlem sınırında TEK işlem sayılır.
-- Kriz masasında '*' = bütün kabine (eski boş seçim). Kararname ödeneğinde '*' kabul edilmez.
-- Yeni RPC cb_yrd_dosya_hatirlat: yardımcı veya CB, yanıt bekleyen dosya için bakana 12 saatte bir hatırlatma.
-- Yalnız fonksiyon değişir; oyuncu verisine dokunulmaz.

create or replace function public.cb_yrd_dosya_ac(
 p_tur text,p_baslik text,p_aciklama text,p_bakanlik text default null,p_il integer default null,
 p_gun integer default 3,p_veri jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); s smallint:=oyun.cb_yrd_aktif_sira(p.id);
 c uuid:=oyun.aktif_cb(); t timestamptz:=oyun.simdi(); v_id bigint; v_hedef uuid; v_durum text;
 v_baslik text; v_aciklama text; v_bakan text; v_tum boolean:=false; v_ilk bigint; v_say int:=0; r record;
begin
 if s is null or c is null then raise exception 'Bu işlem için görevde Cumhurbaşkanı Yardımcısı olmalısın.'; end if;
 if oyun.hukumet_sistemi()=1 then
  raise exception 'Parlamenter sistemde yürütme koordinasyonu Başbakana aittir.'; end if;
 if p_tur is null or p_tur not in ('gorev','proje','kriz','kararname','toplanti','aciklama','yerel','ekonomi') then
  raise exception 'Geçersiz görev türü.'; end if;
 v_baslik:=oyun.metin_temizle(p_baslik,120);
 v_aciklama:=oyun.metin_temizle(p_aciklama,5000);
 if length(v_baslik)<5 or length(v_aciklama)<15 then raise exception 'Başlık en az 5, açıklama en az 15 karakter olmalı.'; end if;
 if p_gun is null or p_gun<1 or p_gun>14 then raise exception 'Görev süresi 1-14 gün olmalı.'; end if;
 if p_veri is null or jsonb_typeof(p_veri)<>'object' then raise exception 'İşlem verisi geçersiz.'; end if;
 p_veri:=p_veri-'toplu'-'hatirlatma'-'toplu_sayi';
 v_bakan:=nullif(btrim(coalesce(p_bakanlik,'')),'');
 if v_bakan='*' then
  if p_tur in ('gorev','proje') then v_tum:=true; v_bakan:=null;
  elsif p_tur='kriz' then v_bakan:=null;
  else raise exception 'Tüm bakanlıklar seçeneği yalnız bakanlık görevi, devlet projesi ve kriz masasında kullanılabilir.'; end if;
 end if;
 if v_bakan is not null and not exists(select 1 from oyun.bakanliklar where kod=v_bakan) then raise exception 'Bakanlık bulunamadı.'; end if;
 if v_bakan is not null and not oyun.cb_yrd_bakanlik_uygun(s,v_bakan) then raise exception 'Bu bakanlık görev alanının dışında.'; end if;
 if p_tur in ('gorev','proje') and v_bakan is null and not v_tum then raise exception 'Bakanlık görevi ve proje için bakanlık ya da "Tüm bakanlıklar" seçmelisin.'; end if;
 if p_tur='yerel' and p_il is null then raise exception 'Yerel görüşme için il seçmelisin.'; end if;
 if p_il is not null and not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl bulunamadı.'; end if;
 if p_tur='kararname' and coalesce(p_veri->>'tur','') not in ('serbest','il_destek','odenek','ikramiye','duzenleme','tahvil','ozellestirme') then
  raise exception 'Kararname türü belirtilmeli.'; end if;
 -- toplu dosya günlük sınırda tek işlem sayılır
 if (select count(distinct coalesce(d.veri->>'toplu',d.id::text)) from oyun.cb_yrd_dosya d
     where d.yardimci=p.id and d.olusturma >= oyun.bugun_bas(t))>=8 then
  raise exception 'Bir yardımcı günde en fazla 8 yeni işlem açabilir.'; end if;
 if p_tur='aciklama' and exists(select 1 from oyun.cb_yrd_dosya where yardimci=p.id and tur='aciklama' and olusturma>=oyun.bugun_bas(t)) then
  raise exception 'Günde yalnız bir resmî basın açıklaması yapabilirsin.'; end if;

 if v_tum then
  for r in select b.kod, (select m.user_id from oyun.makamlar m where m.tur='bakan' and m.bakanlik=b.kod and m.bit is null
                          order by m.bas desc limit 1) hedef
           from oyun.bakanliklar b where oyun.cb_yrd_bakanlik_uygun(s,b.kod) order by b.kod loop
   insert into oyun.cb_yrd_dosya(cb,yardimci,sira,tur,baslik,aciklama,bakanlik,il_id,hedef,veri,durum,son_tarih,olusturma,guncelleme)
   values(c,p.id,s,p_tur,v_baslik,v_aciklama,r.kod,p_il,r.hedef,
          p_veri||jsonb_build_object('toplu',coalesce(v_ilk::text,'?')),'bekliyor',t+make_interval(days=>p_gun),t,t)
   returning id into v_id;
   if v_ilk is null then
    v_ilk:=v_id;
    update oyun.cb_yrd_dosya set veri=veri||jsonb_build_object('toplu',v_ilk::text) where id=v_id;
   end if;
   v_say:=v_say+1;
   if r.hedef is not null and r.hedef<>p.id then
    perform oyun.bildir(r.hedef,format('Cumhurbaşkanı Yardımcısı %s tüm bakanlıklara görev gönderdi: %s (#%s). Yanıtını Devlet > Hükümet bölümünden ver.',p.kad,v_baslik,v_id),t);
   end if;
  end loop;
  if v_say=0 then raise exception 'Görev alanında bakanlık bulunamadı.'; end if;
  perform oyun.bildir(c,format('%s. yardımcın %s %s bakanlığa toplu %s gönderdi: %s.',s,p.kad,v_say,
    case when p_tur='proje' then 'proje' else 'görev' end,v_baslik),t);
  return jsonb_build_object('tamam',true,'id',v_ilk,'durum','bekliyor','adet',v_say);
 end if;

 if v_bakan is not null then
  select user_id into v_hedef from oyun.makamlar where tur='bakan' and bakanlik=v_bakan and bit is null order by bas desc limit 1;
 elsif p_tur='yerel' then
  select user_id into v_hedef from oyun.makamlar where tur='bel' and il_id=p_il and bit is null order by bas desc limit 1;
 end if;
 v_durum:=case when p_tur in ('kararname','ekonomi') then 'onay_bekliyor'
  when p_tur='aciklama' then 'yayimlandi' else 'bekliyor' end;
 insert into oyun.cb_yrd_dosya(cb,yardimci,sira,tur,baslik,aciklama,bakanlik,il_id,hedef,veri,durum,son_tarih,olusturma,guncelleme)
 values(c,p.id,s,p_tur,v_baslik,v_aciklama,v_bakan,p_il,v_hedef,p_veri,v_durum,t+make_interval(days=>p_gun),t,t)
 returning id into v_id;
 perform oyun.bildir(c,format('%s. yardımcın %s bir işlem açtı: %s (#%s).',s,p.kad,v_baslik,v_id),t);
 if v_hedef is not null then
  perform oyun.bildir(v_hedef,format('Cumhurbaşkanı Yardımcısı %s: %s (#%s). Yanıtını Devlet > Hükümet bölümünden ver.',p.kad,v_baslik,v_id),t);
 end if;
 if p_tur='toplanti' then
  perform oyun.bildir(m.user_id,format('Bakanlar Kurulu gündemi: %s. Toplantı çağrısı %s. Cumhurbaşkanı Yardımcısı %s.',v_baslik,v_aciklama,p.kad),t)
  from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.user_id<>p.id and m.user_id<>c;
 elsif p_tur='kriz' and v_bakan is null then
  perform oyun.bildir(m.user_id,format('Kriz masası açıldı: %s. Detay: %s',v_baslik,v_aciklama),t)
  from oyun.makamlar m where m.tur='bakan' and m.bit is null and m.user_id<>p.id and m.user_id<>c;
 elsif p_tur='aciklama' then
  perform oyun.olay('duyuru',format('Cumhurbaşkanı Yardımcısı %s: %s — %s',p.kad,v_baslik,left(v_aciklama,300)),null,p.parti_id,t);
  perform oyun.gazete_ekle('duyuru',format('Cumhurbaşkanı Yardımcısı: %s',v_baslik),v_aciklama,v_id,t);
 end if;
 return jsonb_build_object('tamam',true,'id',v_id,'durum',v_durum);
end $fn$;

create or replace function public.cb_yrd_dosya_hatirlat(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.cb_yrd_dosya; t timestamptz:=oyun.simdi(); son timestamptz; v_h uuid;
begin
 select * into d from oyun.cb_yrd_dosya where id=p_id for update;
 if d.id is null or d.cb is distinct from oyun.aktif_cb() then raise exception 'Görev dosyası bulunamadı veya hükümet değişti.'; end if;
 if not (p.id=d.cb or (p.id=d.yardimci and oyun.cb_yrd_aktif_sira(p.id)=d.sira)) then
  raise exception 'Hatırlatmayı yalnız dosyayı açan yardımcı veya Cumhurbaşkanı gönderebilir.'; end if;
 if d.durum not in ('bekliyor','calisiliyor') then raise exception 'Bu dosya artık yanıt beklemiyor.'; end if;
 select m.user_id into v_h from oyun.makamlar m where m.bit is null
   and ((d.bakanlik is not null and m.tur='bakan' and m.bakanlik=d.bakanlik) or (d.tur='yerel' and m.tur='bel' and m.il_id=d.il_id))
   order by m.bas desc limit 1;
 if v_h is null then raise exception 'Bu dosyanın muhatabı olan makam şu an boş; önce atama yapılmalı.'; end if;
 son:=nullif(d.veri->>'hatirlatma','')::timestamptz;
 if son is not null and son>t-interval '12 hours' then
  raise exception 'Bu dosya için 12 saatte bir hatırlatma gönderilebilir.'; end if;
 update oyun.cb_yrd_dosya set veri=coalesce(veri,'{}'::jsonb)||jsonb_build_object('hatirlatma',t) where id=p_id;
 perform oyun.bildir(v_h,format('Hatırlatma (%s): #%s %s görev dosyası yanıtını bekliyor. Son tarih %s.',p.kad,d.id,d.baslik,
   to_char(d.son_tarih at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI')),t);
 return jsonb_build_object('tamam',true);
end $fn$;

-- Bakanlık değişince (yeni bakan atanınca) toplu/boş makamlı dosyaların muhatabı panelde güncel görünsün diye
-- dosyanın hedefi boşsa yanıt yetkisi zaten makam üzerinden denetleniyor: cb_yrd_dosya_yanitla p.id=d.hedef ister.
-- Boş makama gönderilmiş dosyayı sonradan atanan bakan da yanıtlayabilsin:
create or replace function public.cb_yrd_dosya_yanitla(p_id bigint,p_durum text,p_yanit text)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); d oyun.cb_yrd_dosya; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.cb_yrd_dosya where id=p_id for update;
 if d.id is null or d.cb is distinct from oyun.aktif_cb() then raise exception 'Görev dosyası bulunamadı veya hükümet değişti.'; end if;
 if d.tur not in ('gorev','proje','kriz','yerel','toplanti') or d.durum not in ('bekliyor','calisiliyor') then
  raise exception 'Bu dosyaya yanıt verilemez.'; end if;
 if not (
  ((p.id=d.hedef or d.hedef is null or not exists(select 1 from oyun.makamlar h where h.user_id=d.hedef and h.bit is null
      and ((d.tur='yerel' and h.tur='bel' and h.il_id=d.il_id) or (h.tur='bakan' and h.bakanlik=d.bakanlik))))
   and exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null
   and ((d.tur='yerel' and m.tur='bel' and m.il_id=d.il_id) or (d.bakanlik is not null and m.tur='bakan' and m.bakanlik=d.bakanlik))))
  or (p.id=d.yardimci and d.tur in ('toplanti','kriz','yerel') and oyun.cb_yrd_aktif_sira(p.id)=d.sira)
  or (d.tur='toplanti' and exists(select 1 from oyun.makamlar where user_id=p.id and tur='bakan' and bit is null))
  or (d.tur='kriz' and d.bakanlik is null and exists(select 1 from oyun.makamlar where user_id=p.id and tur='bakan' and bit is null))) then
  raise exception 'Bu görev sana ait değil.'; end if;
 if p_durum not in ('calisiliyor','tamamlandi') or p_durum is null then raise exception 'Geçersiz görev durumu.'; end if;
 if char_length(btrim(coalesce(p_yanit,'')))<10 or char_length(p_yanit)>3000 then raise exception 'Yanıt 10-3000 karakter olmalı.'; end if;
 update oyun.cb_yrd_dosya set durum=p_durum,yanit=btrim(p_yanit),hedef=case when exists(select 1 from oyun.makamlar m where m.user_id=p.id and m.bit is null
   and ((d.tur='yerel' and m.tur='bel' and m.il_id=d.il_id) or (d.bakanlik is not null and m.tur='bakan' and m.bakanlik=d.bakanlik))) then p.id else hedef end,guncelleme=t where id=p_id;
 if d.yardimci<>p.id then perform oyun.bildir(d.yardimci,format('%s, #%s %s görevine yanıt verdi: %s',p.kad,p_id,d.baslik,p_durum),t); end if;
 if d.cb<>p.id then perform oyun.bildir(d.cb,format('%s, #%s %s görevini %s olarak bildirdi.',p.kad,p_id,d.baslik,p_durum),t); end if;
 return jsonb_build_object('tamam',true,'durum',p_durum);
end $fn$;

revoke all on function public.cb_yrd_dosya_hatirlat(bigint) from public, anon;
grant execute on function public.cb_yrd_dosya_hatirlat(bigint) to authenticated;

-- Panel: bakanlığa gönderilmiş dosyayı o bakanlıkta şu an görevli bakan görür (toplu dosya, boş makam, bakan değişimi)
do $do$
declare d text := pg_get_functiondef('public.cb_yrd_panel()'::regprocedure); y text;
begin
 if position('d.bakanlik=(select m2.bakanlik' in d)>0 then return; end if;
 y := replace(d, '(cb_mi or s is not null or d.hedef=p.id or',
  '(cb_mi or s is not null or d.hedef=p.id or (d.bakanlik is not null and d.bakanlik=(select m2.bakanlik from oyun.makamlar m2 where m2.user_id=p.id and m2.tur=''bakan'' and m2.bit is null limit 1)) or');
 if y = d then raise exception 'cb_yrd_panel çapası bulunamadı'; end if;
 execute y;
end $do$;

-- Panel: oyuncunun şu anki bakanlığı (yeni atanan bakan eski dosyaları yanıtlayabilsin diye arayüze)
do $do$
declare d text := pg_get_functiondef('public.cb_yrd_panel()'::regprocedure); y text;
begin
 if position('''bakanligim''' in d)>0 then return; end if;
 y := replace(d, '''cb_miyim'',cb_mi,',
  '''cb_miyim'',cb_mi,''bakanligim'',(select m3.bakanlik from oyun.makamlar m3 where m3.user_id=p.id and m3.tur=''bakan'' and m3.bit is null limit 1),');
 if y = d then raise exception 'cb_yrd_panel cb_miyim çapası bulunamadı'; end if;
 execute y;
end $do$;
