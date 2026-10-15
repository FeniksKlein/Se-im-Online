-- Seçim Online 2026-10-15: CB yardımcısı kabine ve denetim, adliye ilgili taraflar, tazminat davası.
-- Eklemeli, geçmiş oyuncu bakiyelerine/davalara dokunmaz.
begin;
alter table oyun.adliye_davalar add column if not exists tazminat_talep numeric;
alter table oyun.adliye_davalar add column if not exists tazminat_tutar numeric;
alter table oyun.adliye_davalar add column if not exists tazminat_odenen numeric not null default 0;
alter table oyun.adliye_karar_oy add column if not exists tazminat_tutar numeric;
alter table oyun.adliye_davalar drop constraint if exists adliye_davalar_tur_check;
alter table oyun.adliye_davalar add constraint adliye_davalar_tur_check check (tur in ('hakaret','iftira','rusvet','yolsuzluk','usulsuzluk','dolandiricilik','diger','tazminat'));
alter table oyun.adliye_davalar drop constraint if exists adliye_davalar_karar_check;
alter table oyun.adliye_davalar add constraint adliye_davalar_karar_check check (karar in ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur','para_10b','para_50b','aday_yasagi','parti_para','dusme','tazminat'));
alter table oyun.adliye_karar_oy add constraint adliye_tazminat_oy_tutar_check check ((karar = 'tazminat' and tazminat_tutar between 1000 and 500000 and tazminat_tutar = trunc(tazminat_tutar)) or (karar <> 'tazminat' and tazminat_tutar is null));
alter table oyun.adliye_beyan drop constraint if exists adliye_beyan_rol_check;
alter table oyun.adliye_beyan add constraint adliye_beyan_rol_check check (rol in ('davaci','davali','sozcu','ilgili'));
create table if not exists oyun.adliye_ek_taraf (
  dava_id bigint not null references oyun.adliye_davalar(id),
  user_id uuid not null references oyun.profiller(id),
  ekleyen uuid not null references oyun.profiller(id),
  gerekce text not null check(char_length(gerekce) between 20 and 500),
  zaman timestamptz not null default now(),
  primary key(dava_id,user_id)
);
create index if not exists adliye_ek_taraf_oyuncu_idx on oyun.adliye_ek_taraf(user_id,dava_id);
alter table oyun.adliye_ek_taraf enable row level security;
revoke all on oyun.adliye_ek_taraf from public,anon,authenticated;

-- Güncel fonksiyon: kanal_coz
CREATE OR REPLACE FUNCTION oyun.kanal_coz(p oyun.profiller, p_kanal text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'belediye' then 'belediye:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (
      select 'ittifak:' || u.ittifak_id
      from oyun.ittifak_uyeler u
      join oyun.partiler pa on pa.id = u.parti_id
      where u.parti_id = p.parti_id
        and not pa.kapali
        and (
          pa.gb = p.id
          or exists (
            select 1 from oyun.parti_gby g
            where g.parti_id = pa.id and g.user_id = p.id
          )
          or exists (
            select 1 from oyun.parti_teskilat_gorev tg
            where tg.parti_id = pa.id and tg.user_id = p.id and tg.aktif
          )
          or exists (
            select 1 from oyun.makamlar m
            where m.user_id = p.id and m.tur = 'mv' and m.bit is null
          )
        )
    )
    when 'kabine' then case when exists (
      select 1 from oyun.makamlar
      where user_id = p.id and bit is null and tur in ('cb','bakan','cb_yardimcisi')
    ) then 'kabine' end
    when 'grup' then case
      when oyun.aktif_mv_parti(p.id) is not null then 'grup:' || oyun.aktif_mv_parti(p.id)
      when exists (
        select 1 from oyun.partiler pa where pa.gb = p.id and pa.id = p.parti_id
      ) then 'grup:' || p.parti_id end
    when 'divan' then case when exists (
      select 1 from oyun.makamlar
      where user_id = p.id and bit is null and tur in ('tbmm','bskv','grup_bskv')
    ) then 'divan' end
    when 'yonetim' then (
      select 'yonetim:' || pa.id from oyun.partiler pa
      where pa.id = p.parti_id and not pa.kapali
        and (pa.gb = p.id or exists (
          select 1 from oyun.parti_gby g
          where g.parti_id = pa.id and g.user_id = p.id
        ))
    )
    else null end;
end $function$


-- Güncel fonksiyon: unvan
CREATE OR REPLACE FUNCTION oyun.unvan(u uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce(
    (select 'Başbakan' from oyun.hukumetler h where h.basbakan=u and h.durum='gorevde' and h.bit is null limit 1),
    (select 'Cumhurbaşkanı' from oyun.makamlar where user_id=u and tur='cb' and bit is null limit 1),
    (select 'Cumhurbaşkanı Yardımcısı' from oyun.makamlar m where m.user_id=u and m.tur='cb_yardimcisi' and m.bit is null limit 1),
    (select replace(b.ad,'Bakanlığı','Bakanı') from oyun.makamlar m join oyun.bakanliklar b on b.kod=m.bakanlik
       where m.user_id=u and m.tur='bakan' and m.bit is null limit 1),
    (select pa.kisa||' Genel Başkanı' from oyun.partiler pa where pa.gb=u and not pa.kapali limit 1),
    (select i.ad||' Milletvekili' from oyun.makamlar m join oyun.iller i on i.id=m.il_id where m.user_id=u and m.tur='mv' and m.bit is null limit 1),
    (select i.ad||' Belediye Başkanı' from oyun.makamlar m join oyun.iller i on i.id=m.il_id where m.user_id=u and m.tur='bel' and m.bit is null limit 1),
    oyun.gby_unvan(u)
  )
$function$


-- Güncel fonksiyon: dava_heyeti
CREATE OR REPLACE FUNCTION oyun.dava_heyeti(d oyun.adliye_davalar)
 RETURNS uuid[]
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce(array_agg(user_id order by sira), '{}') from oyun.mahkeme_uye
   where user_id is not null and user_id is distinct from d.davaci and user_id is distinct from d.davali and not exists (select 1 from oyun.adliye_ek_taraf et where et.dava_id=d.id and et.user_id=oyun.mahkeme_uye.user_id)
$function$


-- Güncel fonksiyon: adliye_oy_say
CREATE OR REPLACE FUNCTION oyun.adliye_oy_say(p_dava bigint, t timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d oyun.adliye_davalar; heyet uuid[]; r record; bitis timestamptz; v_hakim uuid; v_ger text;
begin
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if d.durum <> 'acik' then return false; end if;
  heyet := oyun.dava_heyeti(d);
  if cardinality(heyet) = 0 then return false; end if;
  select o.karar, coalesce(o.tazminat_tutar,0) tutar, count(*) n, min(o.zaman) ilk into r from oyun.adliye_karar_oy o
   where o.dava_id = d.id and o.uye = any(heyet) group by o.karar,coalesce(o.tazminat_tutar,0) order by count(*) desc, min(o.zaman) limit 1;
  if r.karar is null or r.n < oyun.cogunluk(cardinality(heyet)) then return false; end if;
  select o.uye, o.gerekce into v_hakim, v_ger from oyun.adliye_karar_oy o where o.dava_id = d.id and o.karar = r.karar and coalesce(o.tazminat_tutar,0) = r.tutar and o.uye = any(heyet) order by o.zaman limit 1;
  update oyun.adliye_davalar set durum = 'karar', karar = r.karar, ilk_karar = r.karar, gerekce = v_ger, hakim = v_hakim, karar_at = t, tazminat_tutar = case when r.karar='tazminat' then r.tutar else null end,
         kesin = false, istinaf_son = t + make_interval(hours => (select istinaf_saat from oyun.mahkeme_ayar))
   where id = d.id returning * into d;
  bitis := oyun.adliye_hafif_ceza(d, t);
  update oyun.adliye_davalar set ceza_bitis = bitis where id = d.id;
  perform oyun.bildir(x.id, format('Adliye #%s: mahkeme kararını verdi (%s). %s saat içinde istinafa başvurabilirsin.', d.id, r.karar,
                                   (select istinaf_saat from oyun.mahkeme_ayar)), t)
    from (select d.davaci id union select d.davali where d.davali is not null) x;
  perform oyun.adliye_duyur(v_hakim, format('Yüksek Mahkeme kararı #%s: %s → %s davasında karar "%s" (%s/%s oy). İstinaf yolu açık. #Adliye',
     d.id, coalesce((select kisa from oyun.partiler where id = d.davaci_parti), oyun.kad(d.davaci)),
     coalesce(oyun.kad(d.davali), (select kisa from oyun.partiler where id = d.davali_parti)), r.karar, r.n, cardinality(heyet)), array['adliye'], t);
  return true;
end $function$


-- Güncel fonksiyon: adliye_kesinlestir
CREATE OR REPLACE FUNCTION oyun.adliye_kesinlestir(p_dava bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare d oyun.adliye_davalar; mv bigint; alinan numeric; gb uuid; davaci_kazandi boolean;
begin
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if d.id is null or d.kesin then return; end if;
  if not d.ceza_uygulandi and d.af_at is null then
    if d.karar = 'vekillik_dusur' and d.davali is not null then
      select id into mv from oyun.makamlar where user_id = d.davali and tur = 'mv' and bit is null order by bas desc limit 1;
      if mv is not null then
        update oyun.makamlar set bit = t, bitis_neden = 'Adliye #' || d.id || ' kararı' where user_id = d.davali and bit is null and tur in ('mv','tbmm','bskv','grup_bskv');
      end if;
    elsif d.karar in ('para_10b','para_50b') then
      alinan := oyun.adliye_tahsil(d.davali, case d.karar when 'para_10b' then 10000 else 50000 end, 'Adliye #' || d.id || ' para cezası', t);
    elsif d.karar = 'tazminat' and d.davali is not null then
      alinan := oyun.adliye_tahsil(d.davali, least(coalesce(d.tazminat_tutar,0),500000), 'Adliye #' || d.id || ' tazminat tahsili', t);
      if alinan > 0 then
        perform oyun.para_islem(d.davaci, alinan, 'adliye', 'Adliye #' || d.id || ' tazminat ödemesi', t);
        update oyun.adliye_davalar set tazminat_odenen = tazminat_odenen + alinan where id = d.id;
      end if;
    elsif d.karar = 'aday_yasagi' then
      update oyun.profiller set adaylik_yasagi_bitis = greatest(coalesce(adaylik_yasagi_bitis, t), t + interval '30 days') where id = d.davali;
    elsif d.karar = 'parti_para' and d.davali_parti is not null then
      update oyun.partiler set kasa = kasa - least(kasa, 25000) where id = d.davali_parti;
    end if;
  end if;
  -- harç: davacı kazandıysa iade + davalıdan tahsil; kaybettiyse hazineye kalır; düşmede iade
  davaci_kazandi := d.karar not in ('beraat','dusme');
  if d.harc > 0 and d.harc_durum = 'yatirildi' then
    if d.karar = 'dusme' or davaci_kazandi then
      perform oyun.para_islem(d.davaci, d.harc, 'adliye', 'Adliye #' || d.id || ' harç iadesi', t);
    end if;
    if davaci_kazandi then
      if d.davali is not null then perform oyun.adliye_tahsil(d.davali, d.harc, 'Adliye #' || d.id || ' yargılama harcı', t);
      elsif d.davali_parti is not null then update oyun.partiler set kasa = kasa - least(kasa, d.harc) where id = d.davali_parti; end if;
    end if;
  end if;
  update oyun.adliye_davalar set kesin = true, ceza_uygulandi = true, mv_makam_id = coalesce(mv, mv_makam_id),
         harc_durum = case when harc > 0 then case when karar = 'dusme' or davaci_kazandi then 'iade' else 'hazine' end end
   where id = d.id;
  perform oyun.bildir(x.id, format('Adliye #%s kararı kesinleşti: %s.', d.id, d.karar), t)
    from (select d.davaci id union select d.davali where d.davali is not null) x;
end $function$


-- Güncel fonksiyon: adliye_istinaf_sonuc
CREATE OR REPLACE FUNCTION oyun.adliye_istinaf_sonuc(p_dava bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare i oyun.adliye_istinaf; onay int; boz int; toplam int; d oyun.adliye_davalar;
begin
  select * into i from oyun.adliye_istinaf where dava_id = p_dava for update;
  if i.dava_id is null or i.durum <> 'acik' then return; end if;
  select count(*) filter (where oy = 'onay'), count(*) filter (where oy = 'boz'), count(*) into onay, boz, toplam from oyun.adliye_juri where dava_id = p_dava;
  -- erken bitiş: çoğunluk belli olduysa; yoksa süre bitince
  if not (onay >= oyun.cogunluk(toplam) or boz >= oyun.cogunluk(toplam) or t >= i.bit) then return; end if;
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if boz > onay then
    update oyun.adliye_istinaf set durum = 'bozuldu' where dava_id = p_dava;
    -- bozma: beraat bozulursa davalı uyarı alır (davacı kazanır); ceza bozulursa beraat
    update oyun.adliye_davalar set karar = case when d.karar = 'beraat' then 'uyari' else 'beraat' end, ceza_bitis = null, tazminat_tutar = null where id = p_dava;
    if d.davali is not null then perform oyun.adliye_susturma_yenile(d.davali, t); end if;
    perform oyun.adliye_duyur((select user_id from oyun.adliye_juri where dava_id = p_dava and oy = 'boz' order by zaman limit 1),
      format('İstinaf jürisi Adliye #%s kararını BOZDU (%s boz / %s onay). #Adliye', p_dava, boz, onay), array['adliye'], t);
  else
    update oyun.adliye_istinaf set durum = 'onaylandi' where dava_id = p_dava;
    perform oyun.olay('adliye', format('İstinaf jürisi Adliye #%s kararını onayladı (%s onay / %s boz).', p_dava, onay, boz), null, null, t);
  end if;
  perform oyun.adliye_kesinlestir(p_dava, t);
end $function$


-- Güncel fonksiyon: sohbet_ozet
CREATE OR REPLACE FUNCTION public.sohbet_ozet()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); liste jsonb := '[]'; kod text; k text; imlec bigint; okunmamis int; son jsonb; cev int; kilit text;
begin
  foreach kod in array array['genel','il','belediye','parti','yonetim','ittifak','meclis','grup','divan','kabine'] loop
    k := oyun.kanal_coz(p, kod);
    kilit := case when k is not null then null else case kod
      when 'parti' then 'Bir partiye katılınca açılır.' when 'yonetim' then 'Genel başkan ya da genel başkan yardımcısı olunca açılır.'
      when 'ittifak' then 'Partin bir ittifaka girince açılır.' when 'kabine' then 'Cumhurbaşkanı, yardımcısı veya bakan olunca açılır.'
      when 'grup' then 'Milletvekili olunca açılır.' when 'divan' then 'TBMM Başkanı, başkanvekili ya da grup başkanvekili olunca açılır.' end end;
    okunmamis := 0; son := null; cev := null;
    if k is not null then
      select son_id into imlec from oyun.kanal_okuma where user_id = p.id and kanal = k;
      select count(*) into okunmamis from (
        select 1 from oyun.mesajlar m where m.kanal = k and m.id > coalesce(imlec, 0) and m.user_id <> p.id and not m.gizli
           and m.zaman <= t and m.zaman > t - interval '3 days' and not oyun.engelli(p.id, m.user_id) limit 100) x;
      select jsonb_build_object('kad', coalesce(pr.kad, '(silinmiş)'), 'metin', m.metin, 'zaman', m.zaman) into son
        from oyun.mesajlar m left join oyun.profiller pr on pr.id = m.user_id
       where m.kanal = k and not m.gizli and m.zaman <= t and not oyun.engelli(p.id, m.user_id) order by m.id desc limit 1;
      cev := case kod
        when 'genel' then (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes')
        when 'il' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'belediye' then (select count(*) from oyun.profiller where not yasakli and il_id = p.il_id and son_gorulme > t - interval '5 minutes')
        when 'parti' then (select count(*) from oyun.profiller where not yasakli and parti_id = p.parti_id and son_gorulme > t - interval '5 minutes')
        end;
    end if;
    liste := liste || jsonb_build_object('kanal', kod, 'baslik', coalesce(oyun.kanal_baslik(p, kod), case kod when 'parti' then 'Parti sohbeti' when 'yonetim' then 'Parti Yönetim Kurulu'
                  when 'ittifak' then 'İttifak sohbeti' when 'kabine' then 'Bakanlar Kurulu' when 'grup' then 'Parti Meclis Grubu'
                  when 'divan' then 'TBMM Başkanlık Divanı' end),
      'kilit', kilit, 'yazabilir', k is not null and oyun.kanal_yazabilir(p, kod), 'okunmamis', okunmamis, 'son', son, 'cevrimici', cev);
  end loop;
  return jsonb_build_object('kanallar', liste,
    'cevrimici', (select count(*) from oyun.profiller where not yasakli and son_gorulme > t - interval '5 minutes'),
    'toplam_okunmamis', (select coalesce(sum((x ->> 'okunmamis')::int), 0) from jsonb_array_elements(liste) x));
end $function$


-- Güncel fonksiyon: adliye_beyan_ver
CREATE OR REPLACE FUNCTION public.adliye_beyan_ver(p_dava bigint, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; rol text; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Dava savunmaya açık değil.'; end if;
 if char_length(trim(coalesce(p_metin,''))) not between 10 and 2500 then raise exception 'Beyan 10–2500 karakter olmalı.'; end if;
 if d.davali=p.id then rol:='davali';
 elsif d.davali_parti is not null and exists(select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where pa.id=d.davali_parti
 and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))) then rol:='sozcu';
 elsif d.davali is not null and exists(
 select 1 from oyun.adliye_temsil y join oyun.profiller q on q.id=d.davali
 join oyun.parti_sozcu s on s.parti_id=q.parti_id and s.user_id=p.id
 where y.dava_id=d.id and y.yetki_veren=d.davali and y.aktif and p.parti_id=q.parti_id) then rol:='sozcu';
 elsif d.davaci=p.id then rol:='davaci';
 elsif exists (select 1 from oyun.adliye_ek_taraf e where e.dava_id=d.id and e.user_id=p.id) then rol:='ilgili';
 elsif d.davaci_parti is not null and exists(select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where pa.id=d.davaci_parti
 and (pa.gb=p.id or (s.user_id=p.id and p.parti_id=pa.id))) then rol:='davaci';
 else raise exception 'Bu davada konuşma yetkiniz yok.'; end if;
 if exists(select 1 from oyun.adliye_beyan where dava_id=d.id and yazar=p.id and zaman>t-interval '30 seconds') then raise exception 'Yeni beyan için 30 saniye bekleyin.'; end if;
 insert into oyun.adliye_beyan(dava_id,yazar,rol,metin,zaman) values(d.id,p.id,rol,trim(p_metin),t);
 if rol in ('davali','sozcu') then update oyun.adliye_davalar set savunma_geldi=true where id=d.id; end if;
 return jsonb_build_object('tamam',true);
end $function$


-- Güncel fonksiyon: adliye_detay
CREATE OR REPLACE FUNCTION public.adliye_detay(p_dava bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim();
begin
 if not exists(select 1 from oyun.adliye_davalar where id=p_dava) then raise exception 'Dava bulunamadı.'; end if;
 return jsonb_build_object(
 'beyanlar',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'yazar',oyun.kad(b.yazar),'rol',b.rol,'metin',b.metin,'zaman',b.zaman) order by b.id)
 from oyun.adliye_beyan b where b.dava_id=p_dava),'[]'::jsonb),
 'ilgili_miyim', exists(select 1 from oyun.adliye_ek_taraf et where et.dava_id=p_dava and et.user_id=p.id),
 'ilgililer',coalesce((select jsonb_agg(jsonb_build_object('kad',oyun.kad(et.user_id),'gerekce',et.gerekce,'ekleyen',oyun.kad(et.ekleyen),'zaman',et.zaman) order by et.zaman) from oyun.adliye_ek_taraf et where et.dava_id=p_dava),'[]'::jsonb),
 'yorumlar',coalesce((select jsonb_agg(jsonb_build_object('id',y.id,'yazar',oyun.kad(y.yazar),'metin',y.metin,'zaman',y.zaman) order by y.id)
 from (select * from oyun.adliye_yorum where dava_id=p_dava order by id desc limit 80) y),'[]'::jsonb)
 );
end $function$


-- Güncel fonksiyon: adliye_durum
CREATE OR REPLACE FUNCTION public.adliye_durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim();
begin
 return jsonb_build_object(
 'ben',p.kad,'parti_id',p.parti_id,
 'cb_miyim',exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb' and bit is null),
 'hakim',(select oyun.kad(hakim) from oyun.adliye_makam where id=1),
 'hakim_miyim',exists(select 1 from oyun.adliye_makam where id=1 and hakim=p.id),
 'partiler',coalesce((select jsonb_agg(jsonb_build_object('id',pa.id,'ad',pa.ad,'kisa',pa.kisa,'gb',oyun.kad(pa.gb),'sozcu',oyun.kad(s.user_id),
 'gb_miyim',pa.gb=p.id,'sozcu_muyum',s.user_id=p.id) order by pa.ad)
 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id=pa.id where not pa.kapali),'[]'::jsonb),
 'davalar',coalesce((select jsonb_agg(jsonb_build_object(
 'id',d.id,'davaci',oyun.kad(d.davaci),'davaci_parti',dp.ad,'davali',oyun.kad(d.davali),'davali_parti',hp.ad,
 'tur',d.tur,'iddia',d.iddia,'delil',d.delil,'acilis',d.acilis,'savunma_son',d.savunma_son,
 'savunma_geldi',d.savunma_geldi,'durum',d.durum,'hakim',oyun.kad(d.hakim),
 'karar',d.karar,'tazminat_talep',d.tazminat_talep,'tazminat_tutar',d.tazminat_tutar,'tazminat_odenen',d.tazminat_odenen,'gerekce',d.gerekce,'karar_at',d.karar_at,'ceza_bitis',d.ceza_bitis,
 'af_at',d.af_at,'af_veren',oyun.kad(d.af_veren),'af_gerekce',d.af_gerekce,
 'davalimiyim',d.davali=p.id,'davacimiyim',d.davaci=p.id,'temsil_iznim',exists(select 1 from oyun.adliye_temsil a where a.dava_id=d.id and a.yetki_veren=p.id and a.aktif),
 'sozcu_savunabilir',(
  (d.davali_parti is not null and exists(select 1 from oyun.parti_sozcu s join oyun.profiller pr on pr.id=p.id and pr.parti_id=s.parti_id where s.parti_id=d.davali_parti and s.user_id=p.id))
  or (d.davali is not null and exists(select 1 from oyun.adliye_temsil t join oyun.parti_sozcu s on s.user_id=p.id join oyun.profiller pr on pr.id=d.davali and pr.parti_id=s.parti_id where t.dava_id=d.id and t.aktif and t.yetki_veren=d.davali))
 )
 ) order by d.id desc)
 from (select * from oyun.adliye_davalar order by id desc limit 100) d
 left join oyun.partiler dp on dp.id=d.davaci_parti
 left join oyun.partiler hp on hp.id=d.davali_parti),'[]'::jsonb),
 'aflar',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'cb',oyun.kad(a.cb),'tur',a.tur,'dava_id',a.dava_id,'gerekce',a.gerekce,'affedilen',a.affedilen,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_aflar order by id desc limit 20) a),'[]'::jsonb),
 'atamalar',coalesce((select jsonb_agg(jsonb_build_object('yapan',oyun.kad(a.yapan),'eski',oyun.kad(a.eski),'yeni',oyun.kad(a.yeni),'gerekce',a.gerekce,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.adliye_atama_kayit order by id desc limit 15) a),'[]'::jsonb)
 );
end $function$


-- Güncel fonksiyon: adliye_oy_ver
CREATE OR REPLACE FUNCTION public.adliye_oy_ver(p_dava bigint, p_karar text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; t timestamptz := oyun.simdi(); karar_cikti boolean;
begin
  if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verebilir.'; end if;
  select * into d from oyun.adliye_davalar where id = p_dava;
  if d.id is null or d.durum <> 'acik' then raise exception 'Açık bir dava bulunamadı.'; end if;
  if d.davaci = p.id or d.davali = p.id or exists(select 1 from oyun.adliye_ek_taraf et where et.dava_id=d.id and et.user_id=p.id) then raise exception 'Yargıç kendi davasında oy kullanamaz.'; end if;
  if not d.savunma_geldi and t < d.savunma_son then raise exception 'Savunma süresinin dolmasını bekleyin.'; end if;
  if p_karar not in ('beraat','uyari','sustur_1s','sustur_1g','sustur_1h','vekillik_dusur','para_10b','para_50b','aday_yasagi','parti_para') then raise exception 'Geçersiz karar.'; end if;
  if d.davali is null and p_karar not in ('beraat','uyari','parti_para') then raise exception 'Partiye yalnız beraat, uyarı veya hazine yardımı kesintisi verilebilir.'; end if;
  if d.davali is not null and p_karar = 'parti_para' then raise exception 'Hazine yardımı kesintisi yalnız partilere verilir.'; end if;
  if p_karar = 'vekillik_dusur' and not exists (select 1 from oyun.makamlar where user_id = d.davali and tur = 'mv' and bit is null) then
    raise exception 'Davalının aktif milletvekilliği yok.';
  end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 2000 then raise exception 'Gerekçeli oy 20–2000 karakter olmalı.'; end if;
  insert into oyun.adliye_karar_oy(dava_id, uye, karar, gerekce, zaman) values (d.id, p.id, p_karar, trim(p_gerekce), t)
  on conflict (dava_id, uye) do update set karar = excluded.karar, tazminat_tutar = null, gerekce = excluded.gerekce, zaman = excluded.zaman;
  karar_cikti := oyun.adliye_oy_say(d.id, t);
  return jsonb_build_object('tamam', true, 'karar_cikti', karar_cikti);
end $function$


-- Güncel fonksiyon: adliye_dava_ek
CREATE OR REPLACE FUNCTION public.adliye_dava_ek(p_dava bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; i oyun.adliye_istinaf; heyet uuid[];
begin
  select * into d from oyun.adliye_davalar where id = p_dava;
  if d.id is null then raise exception 'Dava bulunamadı.'; end if;
  select * into i from oyun.adliye_istinaf where dava_id = p_dava;
  heyet := oyun.dava_heyeti(d);
  return jsonb_build_object(
    'kesin', d.kesin, 'karar_son', d.karar_son, 'istinaf_son', d.istinaf_son, 'harc', d.harc, 'harc_durum', d.harc_durum, 'ilk_karar', d.ilk_karar,
    'heyet_sayi', cardinality(heyet), 'gerekli', oyun.cogunluk(cardinality(heyet)),
    'oy_sayi', (select count(*) from oyun.adliye_karar_oy o where o.dava_id = d.id and o.uye = any(heyet)),
    'oyum', (select jsonb_build_object('karar', o.karar, 'tazminat_tutar',o.tazminat_tutar,'gerekce', o.gerekce) from oyun.adliye_karar_oy o where o.dava_id = d.id and o.uye = p.id),
    'oy_verebilirim', d.durum = 'acik' and p.id = any(heyet),
    -- oylar karar çıkana kadar gizli; sonra herkes görür (karşı oy dahil)
    'oylar', case when d.durum = 'karar' then (select jsonb_agg(jsonb_build_object('uye', oyun.kad(o.uye), 'karar', o.karar, 'tazminat_tutar',o.tazminat_tutar,'gerekce', o.gerekce) order by o.zaman)
               from oyun.adliye_karar_oy o where o.dava_id = d.id) end,
    'istinaf', case when i.dava_id is not null then jsonb_build_object('basvuran', oyun.kad(i.basvuran), 'gerekce', i.gerekce, 'bas', i.bas, 'bit', i.bit, 'durum', i.durum,
        'onay', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id and j.oy = 'onay'),
        'boz', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id and j.oy = 'boz'),
        'juri_sayi', (select count(*) from oyun.adliye_juri j where j.dava_id = d.id),
        'juri', case when i.durum <> 'acik' then (select jsonb_agg(jsonb_build_object('kad', oyun.kad(j.user_id), 'oy', j.oy, 'gerekce', j.gerekce)) from oyun.adliye_juri j where j.dava_id = d.id) end,
        'juri_miyim', exists (select 1 from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = p.id),
        'juri_oyum', (select j.oy from oyun.adliye_juri j where j.dava_id = d.id and j.user_id = p.id)) end,
    'istinaf_hakkim', d.durum = 'karar' and not d.kesin and i.dava_id is null and oyun.simdi() < d.istinaf_son and (
        (d.karar = 'beraat' and (d.davaci = p.id or exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id where pa.id = d.davaci_parti and (pa.gb = p.id or s.user_id = p.id))))
     or (d.karar not in ('beraat','dusme') and (d.davali = p.id or exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id where pa.id = d.davali_parti and (pa.gb = p.id or s.user_id = p.id))))));
end $function$


-- Güncel fonksiyon: adliye_istinaf
CREATE OR REPLACE FUNCTION public.adliye_istinaf(p_dava bigint, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); d oyun.adliye_davalar; t timestamptz := oyun.simdi(); yetkili boolean; r record; n int := 0; juri_bit timestamptz;
begin
  select * into d from oyun.adliye_davalar where id = p_dava for update;
  if d.id is null or d.durum <> 'karar' or d.kesin then raise exception 'Bu karar istinafa açık değil.'; end if;
  if t > d.istinaf_son then raise exception 'İstinaf süresi doldu.'; end if;
  if exists (select 1 from oyun.adliye_istinaf where dava_id = d.id) then raise exception 'Bu karara zaten istinaf başvurusu yapıldı.'; end if;
  if d.karar = 'beraat' then
    yetkili := d.davaci = p.id or (d.davaci_parti is not null and exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id
                 where pa.id = d.davaci_parti and (pa.gb = p.id or s.user_id = p.id)));
  else
    yetkili := d.davali = p.id or (d.davali_parti is not null and exists (select 1 from oyun.partiler pa left join oyun.parti_sozcu s on s.parti_id = pa.id
                 where pa.id = d.davali_parti and (pa.gb = p.id or s.user_id = p.id)));
  end if;
  if not yetkili then raise exception 'İstinafa yalnız kararı kaybeden taraf başvurabilir.'; end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 1500 then raise exception 'İstinaf gerekçesi 20–1500 karakter olmalı.'; end if;
  juri_bit := t + make_interval(hours => (select juri_saat from oyun.mahkeme_ayar));
  insert into oyun.adliye_istinaf(dava_id, basvuran, gerekce, bas, bit) values (d.id, p.id, trim(p_gerekce), t, juri_bit);
  -- Kura: davayla ilgisi olmayan partilerin aktif vekilleri; yetmezse son 7 günde görülen tarafsız oyuncular
  for r in
    select x.id from (
      select pr.id, 0 o, random() rnd from oyun.makamlar m join oyun.profiller pr on pr.id = m.user_id
       where m.tur = 'mv' and m.bit is null and not pr.yasakli
      union all
      select pr.id, 1, random() from oyun.profiller pr where not pr.yasakli and pr.son_gorulme > t - interval '7 days') x
    join oyun.profiller q on q.id = x.id
    where x.id is distinct from d.davaci and x.id is distinct from d.davali and not oyun.mahkeme_uyesi_mi(x.id) and not exists(select 1 from oyun.adliye_ek_taraf et where et.dava_id=d.id and et.user_id=x.id)
      and not exists (select 1 from oyun.makamlar cbm where cbm.user_id = x.id and cbm.tur = 'cb' and cbm.bit is null)
      and (q.parti_id is null or (q.parti_id is distinct from d.davaci_parti and q.parti_id is distinct from d.davali_parti
           and q.parti_id is distinct from (select parti_id from oyun.profiller where id = d.davaci)
           and q.parti_id is distinct from (select parti_id from oyun.profiller where id = d.davali)))
    group by x.id order by min(x.o), min(x.rnd) limit 3
  loop
    insert into oyun.adliye_juri(dava_id, user_id) values (d.id, r.id) on conflict do nothing;
    perform oyun.bildir(r.id, format('Kura ile Adliye #%s istinaf jürisine seçildin. %s saat içinde kararı onayla ya da boz.', d.id,
                                     (select juri_saat from oyun.mahkeme_ayar)), t);
    n := n + 1;
  end loop;
  if n = 0 then
    delete from oyun.adliye_istinaf where dava_id = d.id;
    raise exception 'Şu anda tarafsız jüri oluşturulamadı; daha sonra tekrar dene.';
  end if;
  update oyun.adliye_davalar set istinaf_son = juri_bit where id = d.id;
  perform oyun.olay('adliye', format('Adliye #%s kararı istinafa taşındı; %s kişilik jüri kurayla belirlendi.', d.id, n), null, null, t);
  return jsonb_build_object('tamam', true, 'juri', n);
end $function$



-- Sadece mevcut Yüksek Mahkeme üyeleri açık davaya gerekçeli ilgili taraf ekleyebilir.
create or replace function public.adliye_taraf_ekle(p_dava bigint,p_kad text,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; u oyun.profiller; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' then raise exception 'Yalnız açık davaya taraf eklenebilir.'; end if;
 if not oyun.mahkeme_uyesi_mi(p.id) or not (p.id=any(oyun.dava_heyeti(d))) then raise exception 'Bu davaya taraf eklemek için tarafsız görevli yargıç olmalısınız.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 500 then raise exception 'İlgililik gerekçesi 20–500 karakter olmalı.'; end if;
 select * into u from oyun.profiller where lower(kad)=lower(trim(p_kad)) and not yasakli;
 if u.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
 if u.id in (d.davaci,d.davali) or u.id=p.id then raise exception 'Oyuncu zaten esas taraf veya dosyanın yargıcı.'; end if;
 if (select count(*) from oyun.adliye_ek_taraf where dava_id=d.id)>=10 then raise exception 'Bir dosyaya en fazla 10 ilgili taraf eklenebilir.'; end if;
 insert into oyun.adliye_ek_taraf(dava_id,user_id,ekleyen,gerekce,zaman) values(d.id,u.id,p.id,trim(p_gerekce),t);
 perform oyun.bildir(u.id,format('Adliye #%s dosyasına ilgili taraf olarak eklendin. Gerekçe: %s. Adliye ekranından beyan verebilirsin.',d.id,left(trim(p_gerekce),200)),t);
 return jsonb_build_object('tamam',true,'kad',u.kad);
end $$;

-- Yalnız kişiye karşı ve kendi adına açılabilen, tutarı açık tazminat davası.
create or replace function public.adliye_tazminat_davasi_ac(p_hedef text,p_talep numeric,p_iddia text,p_delil text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); r jsonb; yeni bigint;
begin
 if p_talep is null or p_talep < 1000 or p_talep > 500000 or p_talep <> trunc(p_talep) then
   raise exception 'Tazminat talebi 1.000–500.000 TL arasında tam sayı olmalı.'; end if;
 r:=public.adliye_dava_ac('oyuncu',p_hedef,'diger',p_iddia,p_delil,null);
 yeni:=(r->>'id')::bigint;
 update oyun.adliye_davalar set tur='tazminat',tazminat_talep=p_talep where id=yeni and davaci=p.id;
 return r || jsonb_build_object('tur','tazminat','talep',p_talep);
end $$;

-- Davayı gören tarafsız yargıcın tazminat kararı; heyet aynı tutarda çoğunluğa ulaşmalı.
create or replace function public.adliye_tazminat_oy(p_dava bigint,p_tutar numeric,p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; t timestamptz:=oyun.simdi(); cikti boolean;
begin
 if not oyun.mahkeme_uyesi_mi(p.id) then raise exception 'Yalnız Yüksek Mahkeme üyeleri oy verebilir.'; end if;
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.durum<>'acik' or d.tur<>'tazminat' or d.davali is null then raise exception 'Bu dosyada tazminata hükmedilemez.'; end if;
 if not (p.id=any(oyun.dava_heyeti(d))) then raise exception 'Dava tarafı hâkim oy kullanamaz.'; end if;
 if not d.savunma_geldi and t<d.savunma_son then raise exception 'Savunma süresini bekleyin.'; end if;
 if p_tutar is null or p_tutar<1000 or p_tutar>least(coalesce(d.tazminat_talep,0),500000) or p_tutar<>trunc(p_tutar) then
   raise exception 'Karar tutarı 1.000 TL ile davacının talebi arasında tam sayı olmalı.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 20 and 2000 then raise exception 'Gerekçeli oy 20–2000 karakter olmalı.'; end if;
 insert into oyun.adliye_karar_oy(dava_id,uye,karar,tazminat_tutar,gerekce,zaman)
 values(d.id,p.id,'tazminat',p_tutar,trim(p_gerekce),t)
 on conflict(dava_id,uye) do update set karar='tazminat',tazminat_tutar=excluded.tazminat_tutar,gerekce=excluded.gerekce,zaman=excluded.zaman;
 cikti:=oyun.adliye_oy_say(d.id,t);
 return jsonb_build_object('tamam',true,'karar_cikti',cikti,'tutar',p_tutar);
end $$;

-- Kesinleşmiş ve henüz ödenmemiş tazminat bakiyesini borçlu isteğe bağlı kapatabilir.
create or replace function public.adliye_tazminat_ode(p_dava bigint,p_tutar numeric default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); d oyun.adliye_davalar; kalan numeric; alinan numeric; t timestamptz:=oyun.simdi();
begin
 select * into d from oyun.adliye_davalar where id=p_dava for update;
 if d.id is null or d.davali<>p.id or d.durum<>'karar' or not d.kesin or d.karar<>'tazminat' then
   raise exception 'Ödenebilir kesinleşmiş bir tazminat borcun bulunamadı.'; end if;
 kalan:=greatest(0,coalesce(d.tazminat_tutar,0)-d.tazminat_odenen);
 if kalan=0 then raise exception 'Tazminat borcu tamamen ödenmiş.'; end if;
 if p_tutar is not null and (p_tutar<=0 or p_tutar<>trunc(p_tutar)) then raise exception 'Ödeme tutarı pozitif tam sayı olmalı.'; end if;
 alinan:=oyun.adliye_tahsil(p.id,least(kalan,coalesce(p_tutar,kalan)),format('Adliye #%s tazminat borç ödemesi',d.id),t);
 if alinan<=0 then raise exception 'Cüzdanda ödemeye uygun para yok.'; end if;
 perform oyun.para_islem(d.davaci,alinan,'adliye',format('Adliye #%s tazminat alacağı',d.id),t);
 update oyun.adliye_davalar set tazminat_odenen=tazminat_odenen+alinan where id=d.id;
 perform oyun.bildir(d.davaci,format('Adliye #%s tazminatından %s TL daha hesabına yatırıldı.',d.id,alinan),t);
 return jsonb_build_object('tamam',true,'odenen',alinan,'kalan',kalan-alinan);
end $$;

-- CB yardımcısına bütün bakanlıkların kamu icraat ve bütçe kayıtları için salt okuma.
create or replace function public.cb_yardimcisi_bakan_denetim()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p oyun.profiller:=oyun.profilim(); sonuc jsonb;
begin
 if not exists(select 1 from oyun.makamlar where user_id=p.id and tur='cb_yardimcisi' and bit is null) then
   raise exception 'Bu inceleme yalnız görevdeki Cumhurbaşkanı yardımcılarına açıktır.'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('bakanlik',b.ad,'kod',b.kod,
   'bakan',oyun.kad(m.user_id),'kasa',coalesce(k.kasa,0),
   'icraatlar',coalesce((select jsonb_agg(jsonb_build_object('ad',z.ad,'yapan',z.yapan,'zaman',z.zaman,'maliyet',z.maliyet,'il',z.il_ad) order by z.zaman desc)
     from (select i.ad,oyun.kad(ik.bakan) yapan,ik.zaman,ik.maliyet,il.ad il_ad
       from oyun.icraat_kayit ik join oyun.icraatlar i on i.kod=ik.kod left join oyun.iller il on il.id=ik.il_id
       where i.bakanlik=b.kod order by ik.zaman desc limit 30) z),'[]'::jsonb)) order by b.sira),'[]'::jsonb)
 into sonuc from oyun.bakanliklar b
 left join lateral (select user_id from oyun.makamlar where tur='bakan' and bakanlik=b.kod and bit is null order by bas desc limit 1) m on true
 left join oyun.bakanlik_kasa k on k.kod=b.kod;
 return sonuc;
end $$;

revoke all on function public.adliye_taraf_ekle(bigint,text,text),
 public.adliye_tazminat_davasi_ac(text,numeric,text,text),
 public.adliye_tazminat_oy(bigint,numeric,text),
 public.adliye_tazminat_ode(bigint,numeric),
 public.cb_yardimcisi_bakan_denetim() from public,anon;
grant execute on function public.adliye_taraf_ekle(bigint,text,text),
 public.adliye_tazminat_davasi_ac(text,numeric,text,text),
 public.adliye_tazminat_oy(bigint,numeric,text),
 public.adliye_tazminat_ode(bigint,numeric),
 public.cb_yardimcisi_bakan_denetim() to authenticated;
commit;
