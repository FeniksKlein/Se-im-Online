-- 2026.11.16-7 · Yönetici paneli: makamlar tablosunda olmayan kurum görevlerine atama / görevden alma
-- Görevler: Yüksek Mahkeme Başkanı (1. üye), Yüksek Mahkeme Üyesi (2. üye), Vali, Baro Başkanı,
-- İl Oda (TOBB) Başkanı, Parti İl Başkanı. Adalet Bakanı 3. üyedir ve bakanlık atamasıyla kendiliğinden belirlenir.
-- Oyunun mevcut atama yardımcıları kullanılır (mahkeme_oturt/mahkeme_indir, vali_gorevlendir/vali_gorev_bitir);
-- gerçek hukuk engelleri korunur: hâkim parti üyesi olamaz ve başka makam alamaz (Anayasa m.68/4, m.140),
-- vali seçilmiş/siyasi makamla birlikte görev yapamaz, baro başkanı ruhsatlı aktif baro üyesi olmalıdır.
-- "Tek görev kuralını uygula" açıksa bağdaşmayan görevler (ve hâkimlik için parti üyeliği) yönetici kararıyla sona erdirilir;
-- kapalıysa engel varsa atama yapılmaz ve nedeni gösterilir. Her işlem mod_log'a yazılır.

create or replace function oyun.yk_kurum_gorev_ad(p_tur text, p_il integer)
returns text language sql stable set search_path to '' as $$
  select case p_tur
    when 'ym_baskan' then 'Yüksek Mahkeme Başkanı'
    when 'ym_uye' then 'Yüksek Mahkeme Üyesi'
    when 'vali' then coalesce((select ad from oyun.iller where id=p_il),'?')||' Valisi'
    when 'baro_baskan' then 'Türkiye Barosu Başkanı'
    when 'oda_baskan' then coalesce((select ad from oyun.iller where id=p_il),'?')||' Ticaret ve Sanayi Odası Başkanı'
    when 'il_baskani' then coalesce((select ad from oyun.iller where id=p_il),'?')||' Parti İl Başkanı'
  end
$$;

create or replace function public.yk_kurum_gorev_ver(p_kad text, p_tur text, p_il integer default null, p_tek_gorev boolean default true)
returns jsonb language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $function$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi();
  m record; engel text; v_sira smallint; v_ad text;
begin
  perform oyun.korunan_hedef(p, h.id);
  if h.yasakli then raise exception 'Engelli hesaba görev verilemez. Önce engeli kaldır.'; end if;
  if p_tur not in ('ym_baskan','ym_uye','vali','baro_baskan','oda_baskan','il_baskani') then raise exception 'Geçersiz kurum görevi.'; end if;
  if p_tur in ('vali','oda_baskan','il_baskani') and (p_il is null or not exists(select 1 from oyun.iller where id=p_il)) then raise exception 'İl seçmelisin.'; end if;
  v_ad := oyun.yk_kurum_gorev_ad(p_tur,p_il);

  if p_tur in ('ym_baskan','ym_uye') then
    v_sira := case when p_tur='ym_baskan' then 1 else 2 end;
    if exists(select 1 from oyun.mahkeme_uye where user_id=h.id and sira=v_sira) then raise exception '% zaten %.', h.kad, v_ad; end if;
    if p_tek_gorev then
      -- Hâkim başka makam alamaz ve parti üyesi olamaz: yönetici kararıyla sona erer
      for m in select id from oyun.makamlar where user_id=h.id and bit is null loop
        perform oyun.makam_bitir(m.id,t,'yeni_gorev');
      end loop;
      if h.parti_id is not null then perform oyun._ayril(h.id,t); end if;
      -- diğer sıradaki üyeliği bırakır
      if exists(select 1 from oyun.mahkeme_uye where user_id=h.id and sira<>v_sira) then
        perform oyun.mahkeme_indir((select sira from oyun.mahkeme_uye where user_id=h.id and sira<>v_sira limit 1),p.id,'Oyun yönetimi kararıyla başka üyeliğe geçti',t);
      end if;
    end if;
    engel := oyun.yargic_uygunluk(h.id);
    if engel is not null then raise exception 'Atama yapılamadı: %', engel; end if;
    perform oyun.mahkeme_indir(v_sira,p.id,'Oyun yönetimi kararıyla görevden alındı',t);
    perform oyun.mahkeme_oturt(v_sira,h.id,p.id,t);

  elsif p_tur = 'vali' then
    engel := oyun.vali_siyasi_engel(h.id);
    if engel is not null then
      if not p_tek_gorev then raise exception 'Valilik, % göreviyle birlikte yürütülemez.', engel; end if;
      for m in select id from oyun.makamlar where user_id=h.id and bit is null and tur in ('cb','cb_yardimcisi','bakan','mv','bel') loop
        perform oyun.makam_bitir(m.id,t,'yeni_gorev');
      end loop;
    end if;
    -- Yönetici ataması: kişi vali havuzunda değilse havuza alınır (sınav yönetici kararıyla geçilmiş sayılır)
    insert into oyun.vali_havuz(user_id,giris,durum) values(h.id,t,'aday')
    on conflict (user_id) do update set durum='aday', cikis=null;
    perform oyun.vali_gorevlendir(h.id,p_il::smallint,p.id,'yonetim');

  elsif p_tur = 'baro_baskan' then
    if not exists(select 1 from oyun.baro_uyeleri b where b.user_id=h.id and b.durum='aktif') or not oyun.avukat_ruhsatli(h.id) then
      raise exception 'Baro başkanı ruhsatlı ve baroya aktif üye bir avukat olmalı.'; end if;
    engel := oyun.avukat_gorev_engeli(h.id);
    if engel is not null then raise exception 'Atama yapılamadı: %', engel; end if;
    if (select baskan from oyun.baro where id=1) is not distinct from h.id then raise exception '% zaten baro başkanı.', h.kad; end if;
    if (select baskan from oyun.baro where id=1) is not null then
      perform oyun.bildir((select baskan from oyun.baro where id=1),'Oyun yönetimi kararıyla Türkiye Barosu başkanlığın sona erdi.',t);
    end if;
    update oyun.baro set baskan=h.id, baskan_bas=t where id=1;

  elsif p_tur = 'oda_baskan' then
    if not exists(select 1 from oyun.oda where il_id=p_il) then raise exception 'Bu ilde oda kaydı yok.'; end if;
    if (select baskan from oyun.oda where il_id=p_il) is not distinct from h.id then raise exception '% zaten %.', h.kad, v_ad; end if;
    if (select baskan from oyun.oda where il_id=p_il) is not null then
      perform oyun.bildir((select baskan from oyun.oda where il_id=p_il), format('Oyun yönetimi kararıyla %s görevin sona erdi.', v_ad), t);
    end if;
    update oyun.oda set baskan=h.id, baskan_bas=t where il_id=p_il;

  elsif p_tur = 'il_baskani' then
    if h.parti_id is null then raise exception '% bir partiye üye değil. Önce partisini belirle.', h.kad; end if;
    if h.il_id is distinct from p_il::smallint then raise exception 'Parti il başkanı görev yapacağı ilde kayıtlı olmalı (önce ilini değiştir).'; end if;
    if not exists(select 1 from oyun.parti_teskilat where parti_id=h.parti_id and il_id=p_il) then raise exception 'Partinin bu ilde teşkilatı yok.'; end if;
    insert into oyun.parti_teskilat_gorev(parti_id,il_id,user_id,atayan,atama,aktif)
    values(h.parti_id,p_il,h.id,p.id,t,true)
    on conflict(parti_id,il_id) do update set user_id=excluded.user_id, atayan=excluded.atayan, atama=excluded.atama, aktif=true;
  end if;

  perform oyun.bildir(h.id, format('Oyun yönetimi seni %s görevine atadı.', v_ad), t);
  perform oyun.olay('makam', format('%s, %s görevine atandı.', h.kad, v_ad), case when p_tur in ('vali','oda_baskan','il_baskani') then p_il::smallint end, h.parti_id, t);
  perform oyun.mod_log(p, 'yk_kurum_gorev_ver', h.kad, v_ad);
  return public.yk_kurum_gorevleri(h.kad);
end $function$;

create or replace function public.yk_kurum_gorev_al(p_kad text, p_tur text, p_il integer default null)
returns jsonb language plpgsql security definer set search_path to 'oyun','public','pg_temp' as $function$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); h oyun.profiller := oyun.profil_bul(p_kad); t timestamptz := oyun.simdi(); v_ad text; x bigint;
begin
  perform oyun.korunan_hedef(p, h.id);
  v_ad := oyun.yk_kurum_gorev_ad(p_tur,p_il);
  if v_ad is null then raise exception 'Geçersiz kurum görevi.'; end if;
  if p_tur in ('ym_baskan','ym_uye') then
    if not exists(select 1 from oyun.mahkeme_uye where user_id=h.id and sira=case when p_tur='ym_baskan' then 1 else 2 end) then raise exception '% bu görevde değil.', h.kad; end if;
    perform oyun.mahkeme_indir((case when p_tur='ym_baskan' then 1 else 2 end)::smallint,p.id,'Oyun yönetimi kararıyla görevden alındı',t);
  elsif p_tur='vali' then
    select id into x from oyun.icisleri_atama where tur='vali' and durum='aktif' and hedef=h.id and (p_il is null or il_id=p_il) limit 1;
    if x is null then raise exception '% görevde bir vali değil.', h.kad; end if;
    perform oyun.vali_gorev_bitir(x,'alindi','Oyun yönetimi kararıyla görevden alındı',p.id);
  elsif p_tur='baro_baskan' then
    update oyun.baro set baskan=null, baskan_bas=null where id=1 and baskan=h.id;
    if not found then raise exception '% baro başkanı değil.', h.kad; end if;
  elsif p_tur='oda_baskan' then
    update oyun.oda set baskan=null, baskan_bas=null where baskan=h.id and (p_il is null or il_id=p_il);
    if not found then raise exception '% oda başkanı değil.', h.kad; end if;
  elsif p_tur='il_baskani' then
    update oyun.parti_teskilat_gorev set aktif=false where user_id=h.id and aktif and (p_il is null or il_id=p_il);
    if not found then raise exception '% parti il başkanı değil.', h.kad; end if;
  end if;
  perform oyun.bildir(h.id, format('Oyun yönetimi kararıyla %s görevin sona erdi.', v_ad), t);
  perform oyun.mod_log(p, 'yk_kurum_gorev_al', h.kad, v_ad);
  return public.yk_kurum_gorevleri(h.kad);
end $function$;

-- Kişinin (p_kad) ya da tüm oyunun (p_kad boş) kurum görevleri
create or replace function public.yk_kurum_gorevleri(p_kad text default null)
returns jsonb language plpgsql stable security definer set search_path to 'oyun','public','pg_temp' as $function$
declare p oyun.profiller := oyun.yetki_zorunlu('makam'); u uuid;
begin
  if nullif(btrim(coalesce(p_kad,'')),'') is not null then u := (oyun.profil_bul(p_kad)).id; end if;
  return coalesce((select jsonb_agg(x order by x->>'sira', x->>'ad') from (
      select jsonb_build_object('tur',case when m.sira=1 then 'ym_baskan' else 'ym_uye' end,'il_id',null,'kad',oyun.kad(m.user_id),'bas',m.bas,'sira','1',
        'ad',case when m.sira=1 then 'Yüksek Mahkeme Başkanı' when m.sira=2 then 'Yüksek Mahkeme Üyesi' else 'Yüksek Mahkeme Üyesi (Adalet Bakanı)' end,
        'kaldirilabilir',m.sira in (1,2)) x
        from oyun.mahkeme_uye m where m.user_id is not null and (u is null or m.user_id=u)
      union all
      select jsonb_build_object('tur','vali','il_id',a.il_id,'kad',oyun.kad(a.hedef),'bas',a.bas,'sira','2','ad',oyun.yk_kurum_gorev_ad('vali',a.il_id),'kaldirilabilir',true)
        from oyun.icisleri_atama a where a.tur='vali' and a.durum='aktif' and (u is null or a.hedef=u)
      union all
      select jsonb_build_object('tur','baro_baskan','il_id',null,'kad',oyun.kad(b.baskan),'bas',b.baskan_bas,'sira','3','ad','Türkiye Barosu Başkanı','kaldirilabilir',true)
        from oyun.baro b where b.baskan is not null and (u is null or b.baskan=u)
      union all
      select jsonb_build_object('tur','oda_baskan','il_id',o.il_id,'kad',oyun.kad(o.baskan),'bas',o.baskan_bas,'sira','4','ad',oyun.yk_kurum_gorev_ad('oda_baskan',o.il_id),'kaldirilabilir',true)
        from oyun.oda o where o.baskan is not null and (u is null or o.baskan=u)
      union all
      select jsonb_build_object('tur','il_baskani','il_id',g.il_id,'kad',oyun.kad(g.user_id),'bas',g.atama,'sira','5',
          'ad',coalesce((select kisa from oyun.partiler where id=g.parti_id),'')||' '||oyun.yk_kurum_gorev_ad('il_baskani',g.il_id),'kaldirilabilir',true)
        from oyun.parti_teskilat_gorev g where g.aktif and (u is null or g.user_id=u)
    ) s(x)),'[]'::jsonb);
end $function$;

do $g$
declare f text;
begin
  foreach f in array array['public.yk_kurum_gorev_ver(text,text,integer,boolean)','public.yk_kurum_gorev_al(text,text,integer)','public.yk_kurum_gorevleri(text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  revoke all on function oyun.yk_kurum_gorev_ad(text,integer) from public, anon, authenticated;
end $g$;
