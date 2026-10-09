-- İl bazında emlak stoku, değerleme ve belediyeye haftalık emlak vergisi
-- Mevcut mülkleri ve kira kayıtlarını korur.
create table if not exists oyun.emlak_vergi_ayar (
 id smallint primary key check(id=1),
 oran numeric not null default 0.10 check(oran between 0 and 0.50),
 guncelleme timestamptz not null default now()
);
insert into oyun.emlak_vergi_ayar(id,oran) values (1,0.10) on conflict(id) do nothing;
create table if not exists oyun.emlak_vergi_il (
 il_id smallint primary key references oyun.iller(id),
 carpan numeric not null default 100 check (carpan between 50 and 200),
 baskan uuid references oyun.profiller(id),
 guncelleme timestamptz not null default now()
);
alter table oyun.emlak_vergi_ayar enable row level security;
alter table oyun.emlak_vergi_il enable row level security;
revoke all on oyun.emlak_vergi_ayar from public,anon,authenticated;
revoke all on oyun.emlak_vergi_il from public,anon,authenticated;

create or replace function oyun.emlak_stok(p_il smallint,p_tip text)
returns integer language sql stable security definer set search_path='' as $$
 with sehir as (select mv from oyun.iller where id=p_il)
 select case when p_tip='daire' then taban
   when p_tip='dukkan' then greatest(2,round(taban*.45)::int)
   when p_tip='villa' then greatest(1,round(taban*.20)::int)
   else 0 end
 from (select 8+round(92*(mv-1)::numeric/95)::int taban from sehir) z
$$;
create or replace function oyun.emlak_bedel(p_il smallint,p_tip text)
returns numeric language sql stable security definer set search_path='' as $$
 select round((case p_tip when 'daire' then 130000
    when 'dukkan' then 260000 when 'villa' then 520000 else 0 end) *
    greatest(.55,least(2.65,.65+1.45*sqrt(i.mv::numeric/96)
         +(coalesce(d.gelisim,50)-50)/200)),0)
 from oyun.iller i left join oyun.il_durum d on d.il_id=i.id where i.id=p_il
$$;
create or replace function oyun.emlak_oran(p_il smallint)
returns numeric language sql stable security definer set search_path='' as $$
 select round((select oran from oyun.emlak_vergi_ayar where id=1)*
  coalesce((select carpan from oyun.emlak_vergi_il where il_id=p_il),100)/100,4)
$$;
create or replace function public.emlak_piyasa()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Oturum açmalısın.'; end if;
 return jsonb_build_object(
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'ad',i.ad,
    'emlak_vergi',oyun.emlak_oran(i.id),'emlak_carpan',coalesce(t.carpan,100),
    'daire',jsonb_build_object('bedel',oyun.emlak_bedel(i.id,'daire'),'kira',round(oyun.emlak_bedel(i.id,'daire')*.025),
      'toplam',oyun.emlak_stok(i.id,'daire'),'kalan',greatest(0,oyun.emlak_stok(i.id,'daire')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='daire'))),
    'dukkan',jsonb_build_object('bedel',oyun.emlak_bedel(i.id,'dukkan'),'kira',round(oyun.emlak_bedel(i.id,'dukkan')*.025),
      'toplam',oyun.emlak_stok(i.id,'dukkan'),'kalan',greatest(0,oyun.emlak_stok(i.id,'dukkan')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='dukkan'))),
    'villa',jsonb_build_object('bedel',oyun.emlak_bedel(i.id,'villa'),'kira',round(oyun.emlak_bedel(i.id,'villa')*.025),
      'toplam',oyun.emlak_stok(i.id,'villa'),'kalan',greatest(0,oyun.emlak_stok(i.id,'villa')-(select count(*) from oyun.yatirim_mulkleri m where m.il_id=i.id and m.tip='villa')))
   ) order by i.ad) from oyun.iller i left join oyun.emlak_vergi_il t on t.il_id=i.id),'[]'::jsonb),
 'ulusal_emlak_vergi',(select oran from oyun.emlak_vergi_ayar where id=1));
end $$;
revoke all on function public.emlak_piyasa() from public,anon;
grant execute on function public.emlak_piyasa() to authenticated;

-- Emlak varlıklarının şehirler arasında alımı mümkündür. Satışlar kilitlenerek stok aşımı önlenir.
create or replace function public.mulk_satin_al(p_tip text,p_il smallint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); p oyun.profiller; bedel numeric; kira numeric;
  t timestamptz:=oyun.simdi(); yeni bigint; stok int; alinmis int;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into p from oyun.profiller where id=u for update;
 if p.id is null or p.yasakli then raise exception 'Aktif oyuncu hesabı gerekli.'; end if;
 if p_tip not in ('daire','dukkan','villa') or p_tip is null then raise exception 'Geçersiz mülk türü.'; end if;
 if not exists(select 1 from oyun.iller where id=p_il) then raise exception 'İl bulunamadı.'; end if;
 perform pg_advisory_xact_lock(68742,hashtext(p_il::text||':'||p_tip));
 stok:=oyun.emlak_stok(p_il,p_tip);
 select count(*) into alinmis from oyun.yatirim_mulkleri where il_id=p_il and tip=p_tip;
 if alinmis>=stok then raise exception 'Bu ilde % stoku tükendi. Oyuncuların satış ilanlarına bakabilirsin.',p_tip; end if;
 bedel:=oyun.emlak_bedel(p_il,p_tip);
 kira:=round(bedel*.025);
 perform oyun.mulk_kira_tahsil(u);
 perform oyun.para_islem(u,-bedel,'emlak',format('%s ilinde %s alımı', (select ad from oyun.iller where id=p_il),p_tip),t);
 insert into oyun.yatirim_mulkleri(user_id,il_id,tip,alis_bedeli,haftalik_kira,satin_alma,sonraki_kira)
 values(u,p_il,p_tip,bedel,kira,t,t+interval '7 days') returning id into yeni;
 insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,zaman,aciklama)
 values('mulk_devlet',yeni,null,u,bedel,t,p_tip||' devlet gayrimenkul alimi');
 return public.mulk_liste();
end $$;
-- Eski istemciyle yapılan satın alımlar da şehir stokuna ve yeni fiyatlara tabidir.
create or replace function public.mulk_satin_al(p_tip text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare sehir smallint;
begin
 select il_id into sehir from oyun.profiller where id=auth.uid();
 if sehir is null then raise exception 'Önce profil oluşturmalısın.'; end if;
 return public.mulk_satin_al(p_tip,sehir);
end $$;
revoke all on function public.mulk_satin_al(text,smallint) from public,anon;
grant execute on function public.mulk_satin_al(text,smallint) to authenticated;

-- Biriken 7 günlük kirayı tahsil ederken her hafta için emlak vergisini belediyeye aktar.
create or replace function oyun.mulk_kira_tahsil(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare m record;n int;gross numeric;tax numeric;emlak_tax numeric; t timestamptz:=oyun.simdi();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,78113));
 for m in select * from oyun.yatirim_mulkleri where user_id=p_user and sonraki_kira<=t order by id for update loop
   n:=least(520,floor(extract(epoch from (t-m.sonraki_kira))/604800)::int+1);
   gross:=round(m.haftalik_kira*n,2);
   tax:=case when (select count(*) from oyun.yatirim_mulkleri x where x.user_id=p_user
             and (x.satin_alma<m.satin_alma or (x.satin_alma=m.satin_alma and x.id<=m.id)))>=3
      then round(gross*oyun.yasa_oran('coklu_mulk_vergi')/100,2) else 0 end;
   emlak_tax:=round(m.alis_bedeli*oyun.emlak_oran(m.il_id)/100*n,2);
   -- Eski mülklerde de kira bakiyesi korunur. Vergi negatif cüzdan oluşturmaz.
   perform oyun.para_islem(p_user,gross-tax-emlak_tax,'kira',
      format('Mülk #%s: %s haftalık kira, gelir vergisi %s, belediye emlak vergisi %s TL',m.id,n,tax,emlak_tax),
      t,tax+emlak_tax);
   if tax>0 then update oyun.ulke set hazine=hazine+tax/1000000.0 where id=1;end if;
   if emlak_tax>0 then
     update oyun.il_durum set kasa=coalesce(kasa,0)+emlak_tax/1000000.0 where il_id=m.il_id;
   end if;
   update oyun.yatirim_mulkleri set sonraki_kira=sonraki_kira+n*interval '7 days',
        toplam_kira=toplam_kira+gross-tax-emlak_tax,kira_sayisi=kira_sayisi+n where id=m.id;
 end loop;
end $$;

create or replace function public.emlak_vergi_belediye_ayarla(p_carpan numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); m oyun.makamlar;
  son timestamptz; t timestamptz:=oyun.simdi();
begin
 select * into m from oyun.makamlar where user_id=p.id and tur='bel' and bit is null order by bas desc limit 1;
 if m.id is null then raise exception 'Yalnızca görevdeki belediye başkanı oran değiştirebilir.'; end if;
 if p_carpan is null or p_carpan<50 or p_carpan>200 or p_carpan<>round(p_carpan) then
  raise exception 'Emlak vergisi katsayısı %50–%200 arasında olmalı.'; end if;
 select guncelleme into son from oyun.emlak_vergi_il where il_id=m.il_id;
 if son is not null and son>t-interval '24 hours' then
   raise exception 'Emlak vergisi oranı 24 saatte bir değiştirilebilir.'; end if;
 insert into oyun.emlak_vergi_il(il_id,carpan,baskan,guncelleme)
 values(m.il_id,p_carpan,p.id,t)
 on conflict(il_id) do update set carpan=excluded.carpan,baskan=excluded.baskan,guncelleme=excluded.guncelleme;
 perform oyun.olay('belediye',format('%s Belediyesi emlak vergisi yerel katsayısını %%%s yaptı.',(select ad from oyun.iller where id=m.il_id),p_carpan),m.il_id,p.parti_id,t);
 return jsonb_build_object('carpan',p_carpan,'toplam_oran',oyun.emlak_oran(m.il_id),'il_id',m.il_id);
end $$;
revoke all on function public.emlak_vergi_belediye_ayarla(numeric) from public,anon;
grant execute on function public.emlak_vergi_belediye_ayarla(numeric) to authenticated;

-- Milletvekili teklif eder; olağan TBMM oylamasından geçince ulusal emlak vergisi değişir.
create or replace function public.emlak_vergi_kanun_teklif(p_oran numeric,p_baslik text,p_metin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi(); s record; yeni bigint;
begin
 if not oyun.aktif_vekil(p.id) then raise exception 'Kanun teklifini milletvekilleri verebilir.'; end if;
 if p_oran is null or p_oran<0 or p_oran>0.50 then raise exception 'Haftalık emlak vergisi %%0–%%0,50 arasında olmalı.'; end if;
 if length(btrim(coalesce(p_baslik,''))) not between 5 and 120 then raise exception 'Kanun başlığı 5–120 karakter olmalı.'; end if;
 if exists(select 1 from oyun.kanunlar where teklif_eden=p.id and durum in ('gorusmede','oylamada','cb_onayinda','israr')) then
   raise exception 'Önceki kanun teklifin henüz sonuçlanmadı.'; end if;
 select * into s from oyun.kanun_suresi();
 insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,teklif_at,oy_bas,oy_bit)
 values('serbest',btrim(p_baslik),oyun.metin_temizle(p_metin,3000),
   jsonb_build_object('ozel_tur','emlak_vergi','deger',round(p_oran,2)),
   p.id,p.parti_id,t,t+s.gorusme,t+s.gorusme+s.oylama) returning id into yeni;
 return jsonb_build_object('id',yeni,'oran',round(p_oran,2));
end $$;
create or replace function oyun.emlak_vergi_kanun_yururluk()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_oran numeric;
begin
 if new.durum='yururlukte' and old.durum is distinct from 'yururlukte'
    and new.veri->>'ozel_tur'='emlak_vergi' then
    v_oran:=(new.veri->>'deger')::numeric;
    if v_oran is null or v_oran<0 or v_oran>0.50 then raise exception 'Geçersiz emlak vergisi kanunu.';end if;
    update oyun.emlak_vergi_ayar set oran=v_oran,guncelleme=oyun.simdi() where id=1;
    perform oyun.olay('ekonomi',format('Meclis ulusal haftalık emlak vergisini %%%s olarak belirledi.',v_oran),null,new.teklif_parti,oyun.simdi());
 end if;
 return new;
end $$;
drop trigger if exists emlak_vergi_kanun_yururluk on oyun.kanunlar;
create trigger emlak_vergi_kanun_yururluk after update of durum on oyun.kanunlar
 for each row execute function oyun.emlak_vergi_kanun_yururluk();
revoke all on function public.emlak_vergi_kanun_teklif(numeric,text,text) from public,anon;
grant execute on function public.emlak_vergi_kanun_teklif(numeric,text,text) to authenticated;

-- Oyunda 600 TBMM sandalyesi. Yalnızca fiilen seçilmiş vekiller oy kullanabilir.
update oyun.ayarlar set meclis_olcek=0 where id=1;
select oyun.dagit_mv_sandalye(600);
create or replace function oyun.meclis_olcek_hesap(t timestamptz)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('aktif',
   (select count(*) from oyun.profiller where not yasakli and son_gorulme>t-interval '14 days'),
   'sandalye',600,'anayasal',600,'olcek',0)
$$;

-- Kanunların geçmesi için toplantıda bulunan değil görevde olan vekillerin salt çoğunluğu gerekir.
CREATE OR REPLACE FUNCTION oyun.kanun_tick(t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare k oyun.kanunlar; c record; dolu int; cb uuid; s record;
begin
  select * into s from oyun.kanun_suresi();
  -- anayasa değişikliği: görüşme bitince imza sayısı dolu sandalyelerin üçte birine ulaşmadıysa teklif düşer
  for k in select * from oyun.kanunlar where durum = 'gorusmede' and tur = 'anayasa' and t >= oy_bas order by oy_bas loop
    dolu := oyun.dolu_sandalye();
    if (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza') < ceil(dolu / 3.0) then
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bas,
        sonuc_metin = format('Yeterli imza toplanamadı: %s imza, en az %s gerekliydi (dolu sandalyelerin üçte biri).',
                             (select count(*) from oyun.kanun_oylari where kanun_id = k.id and asama = 'imza'), ceil(dolu / 3.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin yeterli imza toplayamadı.', k.baslik), k.oy_bas);
    end if;
  end loop;
  update oyun.kanunlar set durum = 'oylamada' where durum = 'gorusmede' and t >= oy_bas;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur = 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    cb := oyun.aktif_cb();
    if dolu > 0 and c.kabul >= ceil(dolu * 2 / 3.0) and cb is not null then
      update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
        sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: üçte iki çoğunluk sağlandı.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.bildir(cb, format('"%s" anayasa değişikliği Meclis''ten üçte iki çoğunlukla geçti. 48 saat içinde yayımla ya da halkoyuna sun.', k.baslik), k.oy_bit);
      perform oyun.olay('meclis', format('"%s" anayasa değişikliği üçte iki çoğunlukla kabul edildi (%s kabul). Cumhurbaşkanına sunuldu.', k.baslik, c.kabul), null, k.teklif_parti, k.oy_bit);
    elsif dolu > 0 and c.kabul >= ceil(dolu * 3 / 5.0) then
      update oyun.kanunlar set sonuc_metin = format('Gizli oylamada %s kabul, %s ret, %s çekimser: beşte üç çoğunlukla kabul edildi, halkoyuna sunuluyor.', c.kabul, c.ret, c.cekimser) where id = k.id;
      perform oyun.referandum_baslat(k.id, k.oy_bit);
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = format('Reddedildi: gizli oylamada %s kabul oyu çıktı; halkoyuna sunulması için en az %s (beşte üç) gerekliydi.', c.kabul, ceil(dolu * 3 / 5.0)) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" anayasa değişikliği teklifin Meclis''te gerekli çoğunluğu alamadı.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'oylamada' and tur <> 'anayasa' and t >= oy_bit order by oy_bit loop
    select * into c from oyun.kanun_say(k.id, 'ilk');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul + c.ret + c.cekimser >= ceil(dolu / 3.0) and c.kabul > c.ret and c.kabul >= floor(dolu / 2.0) + 1 then
      cb := oyun.aktif_cb();
      if cb is null then
        perform oyun.kanun_yururluk(k.id, k.oy_bit, format('Meclis''te %s kabul, %s ret oyla kabul edildi (cumhurbaşkanı makamı boş).', c.kabul, c.ret));
      else
        update oyun.kanunlar set durum = 'cb_onayinda', cb_bit = k.oy_bit + s.cb,
          sonuc_metin = format('Meclis''te %s kabul, %s ret, %s çekimser oyla kabul edildi.', c.kabul, c.ret, c.cekimser) where id = k.id;
        perform oyun.bildir(cb, format('"%s" kanunu Meclis''ten geçti ve onayınızı bekliyor. 48 saat içinde onaylayın ya da veto edin.', k.baslik), k.oy_bit);
        perform oyun.olay('meclis', format('"%s" Meclis''te kabul edildi (%s kabul, %s ret). Cumhurbaşkanının onayına sunuldu.', k.baslik, c.kabul, c.ret), null, k.teklif_parti, k.oy_bit);
      end if;
    else
      update oyun.kanunlar set durum = 'ret', sonuc_at = k.oy_bit,
        sonuc_metin = case when c.kabul + c.ret + c.cekimser < ceil(dolu / 3.0) then format('Toplantı yeter sayısı sağlanamadı (%s vekil katıldı, en az %s gerekliydi).', c.kabul + c.ret + c.cekimser, ceil(dolu / 3.0))
                           else format('Reddedildi: %s kabul, %s ret, %s çekimser (kabul için en az %s ve retten fazla oy gerekliydi).', c.kabul, c.ret, c.cekimser, floor(dolu / 2.0) + 1) end
      where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" teklifin Meclis''te kabul edilmedi.', k.baslik), k.oy_bit);
    end if;
  end loop;
  for k in select * from oyun.kanunlar where durum = 'cb_onayinda' and t >= cb_bit order by cb_bit loop
    perform oyun.kanun_yururluk(k.id, k.cb_bit, case when k.tur = 'anayasa' then 'Cumhurbaşkanı süresi içinde halkoyuna sunmadığı için yayımlanarak yürürlüğe girdi.'
                                                    else 'Cumhurbaşkanı süresi içinde karar vermediği için kendiliğinden yürürlüğe girdi.' end);
  end loop;
  for k in select * from oyun.kanunlar where durum = 'israr' and t >= israr_bit order by israr_bit loop
    select * into c from oyun.kanun_say(k.id, 'israr');
    dolu := oyun.dolu_sandalye();
    if dolu > 0 and c.kabul >= floor(dolu / 2.0) + 1 then
      perform oyun.kanun_yururluk(k.id, k.israr_bit, format('Veto sonrası Meclis %s oyla ısrar etti.', c.kabul));
    else
      update oyun.kanunlar set durum = 'dustu', sonuc_at = k.israr_bit,
        sonuc_metin = format('Veto sonrası ısrar için %s oy gerekiyordu, %s kabul oyu çıktı. Kanun düştü.', floor(dolu / 2.0) + 1, c.kabul) where id = k.id;
      perform oyun.bildir(k.teklif_eden, format('"%s" veto sonrası ısrar oylamasında düştü.', k.baslik), k.israr_bit);
    end if;
  end loop;
  -- seçim döneminde kabul edilen baraj, seçim bitince uygulanır
  if (select bekleyen_baraj from oyun.ulke where id = 1) is not null
     and not exists (select 1 from oyun.secimler o join oyun.secimler g on g.donem = o.donem and g.tur = 'mv'
                     where o.tur = 'mv_on' and t >= o.basvuru_bas and g.durum = 'bekliyor') then
    update oyun.ayarlar set baraj = (select bekleyen_baraj from oyun.ulke where id = 1) where id = 1;
    update oyun.ulke set bekleyen_baraj = null where id = 1;
  end if;
end $function$
;
