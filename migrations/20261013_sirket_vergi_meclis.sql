-- Vergi yasama: sadece milletvekili teklif eder, normal Meclis/CB asamalarindan gecen kanun yururluge girer.
create or replace function public.eko_vergi_kanun_teklif(
 p_kod text,p_islem text,p_oran numeric,p_ad text,p_matrah text,p_baslik text,p_metin text
) returns jsonb language plpgsql security definer set search_path to '' as $$
declare
 p oyun.profiller:=oyun.profilim();t timestamptz:=oyun.simdi();
 mevcut oyun.eko_vergi_turleri;
 b text:=btrim(coalesce(p_baslik,''));m text; yeni bigint;s record;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Vergi kanunu teklifini yalniz milletvekilleri verebilir.';end if;
 if exists(select 1 from oyun.makamlar where user_id=p.id and tur='tbmm' and bit is null)
 then raise exception 'Meclis Baskani kanun teklifi veremez.';end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id
 and durum in ('gorusmede','oylamada','cb_onayinda','israr'))
 then raise exception 'Devam eden teklifini sonuclandir.';end if;
 if p_kod is null or p_kod !~ '^[a-z_]{3,35}$' or p_islem not in ('oran','kaldir','yeni')
 then raise exception 'Vergi kodu veya islem gecersiz.';end if;
 select * into mevcut from oyun.eko_vergi_turleri where kod=p_kod;
 if p_islem='yeni' then
   if mevcut.kod is not null then raise exception 'Bu vergi zaten var; oran degistirilebilir.';end if;
   if length(btrim(coalesce(p_ad,''))) not between 3 and 70
       or p_matrah not in ('satis','kar','dagitim','sozlesme','genel_gelir')
   then raise exception 'Vergi adi ve matrah turu gerekli.';end if;
 else
   if mevcut.kod is null then raise exception 'Degistirilecek vergi bulunamadi.';end if;
   if p_islem='kaldir' and p_kod='gelir' then
      raise exception 'Genel gelir vergisini kaldirmak yerine oranini sifira indir veya mevcut Meclis yasasini kullan.';end if;
 end if;
 if p_islem<>'kaldir' and (p_oran is null or p_oran<0 or p_oran>50)
 then raise exception 'Vergi orani %%0-%%50 olmali.';end if;
 if p_kod='gelir' and p_islem='oran'
 and p_oran>least(45,oyun.anayasa_deger('vergi_tavani'))
 then raise exception 'Gelir vergisi anayasal tavani asamaz.';end if;
 if length(b) not between 5 and 120 or oyun.kufurlu(b)
 then raise exception 'Kanun basligi gecersiz.';end if;
 m:=oyun.metin_temizle(p_metin,3000);
 if length(m)<10 then raise exception 'En az 10 karakter gerekce gir.';end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',b,m,jsonb_build_object('ozel_tur','sirket_vergisi','kod',p_kod,'islem',p_islem,
   'oran',case when p_islem='kaldir' then 0 else round(p_oran,2) end,
   'ad',case when p_islem='yeni' then btrim(p_ad) else mevcut.ad end,
   'matrah',case when p_islem='yeni' then p_matrah else mevcut.matrah end),
  p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama) returning id into yeni;
 insert into oyun.bildirimler(user_id,zaman,metin)
 select mv.user_id,t,format('Yeni vergi kanunu teklifi: "%s". Oylama %s.',
 b,to_char((t+s.gorusme) at time zone 'Europe/Istanbul','DD.MM HH24:MI'))
 from oyun.makamlar mv where mv.tur='mv' and mv.bit is null and mv.user_id<>p.id;
 perform oyun.olay('meclis',format('%s vergi kanunu teklif etti: %s',p.kad,b),null,p.parti_id,t);
 return jsonb_build_object('id',yeni,'durum','gorusmede','kod',p_kod,'islem',p_islem);
end $$;
revoke all on function public.eko_vergi_kanun_teklif(text,text,numeric,text,text,text,text) from public,anon;
grant execute on function public.eko_vergi_kanun_teklif(text,text,numeric,text,text,text,text) to authenticated;

-- Mevcut Meclis surecini kullan; re'sen vergi degistirmek mumkun degil.
create or replace function oyun.eko_sirket_vergi_kanun_yururluk()
returns trigger language plpgsql security definer set search_path to '' as $$
declare v jsonb; k text; islem text; x numeric; eski numeric; eski_ad text; nowt timestamptz;
begin
 if new.durum<>'yururlukte' or old.durum='yururlukte'
    or new.veri->>'ozel_tur'<>'sirket_vergisi'
 then return new;end if;
 v:=new.veri;k:=v->>'kod';islem:=v->>'islem';
 x:=(v->>'oran')::numeric;nowt:=coalesce(new.sonuc_at,oyun.simdi());
 if islem='yeni' then
  if exists(select 1 from oyun.eko_vergi_turleri where kod=k)
  then raise exception 'Vergi kanunu yasalasti ama kod zaten mevcut.';end if;
  insert into oyun.eko_vergi_turleri(kod,ad,matrah,oran,aktif,kaynak_kanun,guncelleme)
  values(k,v->>'ad',v->>'matrah',x,true,new.id,nowt);
 elsif islem in ('oran','kaldir') then
  select oran,ad into eski,eski_ad from oyun.eko_vergi_turleri where kod=k for update;
  if not found then raise exception 'Degistirilecek vergi kayitli degil.';end if;
  update oyun.eko_vergi_turleri
    set oran=case when islem='kaldir' then 0 else x end,
        aktif=case when islem='kaldir' then false else true end,
        kaynak_kanun=new.id,guncelleme=nowt where kod=k;
 else raise exception 'Bilinmeyen vergi kanunu islemi.';end if;
 if k='gelir' and islem='oran' then
  if x>least(45,oyun.anayasa_deger('vergi_tavani')) then
   raise exception 'Yururluge giren oran anayasa tavanini asiyor.';end if;
  update oyun.ulke set vergi=x,vergi_kanun=x,
    vergi_alt=least(vergi_alt,x),vergi_ust=greatest(vergi_ust,x) where id=1;
 end if;
 perform oyun.olay('ekonomi',format('Meclis karari: %s vergisi (%s).',
  coalesce(v->>'ad',eski_ad),islem),null,new.teklif_parti,nowt);
 return new;
end $$;
drop trigger if exists eko_sirket_vergi_kanun_yururluk on oyun.kanunlar;
create trigger eko_sirket_vergi_kanun_yururluk
after update of durum on oyun.kanunlar for each row
execute function oyun.eko_sirket_vergi_kanun_yururluk();
