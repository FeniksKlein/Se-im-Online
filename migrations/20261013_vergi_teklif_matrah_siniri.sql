-- Ayni vergi matrahina asiri sayida oran yigilmasini ve uygulanmayan genel gelir vergi turunu engelle.
do $patch$
declare src text;
begin
 select pg_get_functiondef('public.eko_vergi_kanun_teklif(text,text,numeric,text,text,text,text)'::regprocedure) into src;
 if position('v_toplam numeric' in src)>0 then return;end if;
 src:=replace(src,'b text:=btrim(coalesce(p_baslik,''));m text; yeni bigint;s record;',
 'b text:=btrim(coalesce(p_baslik,''));m text; yeni bigint;s record;v_toplam numeric;v_matrah text;');
 src:=replace(src,
 'if p_islem=''yeni'' then',
 'if p_islem=''yeni'' and p_matrah=''genel_gelir'' then
 raise exception ''Genel gelir vergisi mevcut Meclis gelir vergisi yasasindan yonetilir.'';end if;
 if p_islem=''yeni'' then');
 src:=replace(src,'select * into s from oyun.kanun_suresi();',
 'if p_islem<>''kaldir'' then
  v_matrah:=case when p_islem=''yeni'' then p_matrah else mevcut.matrah end;
  select coalesce(sum(oran),0) into v_toplam from oyun.eko_vergi_turleri
   where matrah=v_matrah and aktif and kod<>p_kod;
  if v_toplam+p_oran>70 then
   raise exception ''Ayni matrahtaki toplam vergi oranlari %%70 sinirini asamaz.'';end if;
 end if;
 select * into s from oyun.kanun_suresi();');
 execute src;
end $patch$;