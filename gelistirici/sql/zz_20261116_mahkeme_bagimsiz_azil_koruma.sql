-- Oyun gercekci modunda TBMM siyasi oyla mahkeme uyelerini keyfi azledemez.
CREATE OR REPLACE FUNCTION public.mahkeme_azil_teklif(p_sira integer, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u uuid; yeni bigint;
begin
 if oyun.gercekci_siyaset() then raise exception 'Bagimsiz mahkeme uyeleri siyasi Meclis azliyla gorevden alinamaz; kadro sure ve tarafsiz mahkeme usulune tabidir.'; end if;
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null) then raise exception 'Görevden alma teklifini yalnız milletvekilleri verebilir.'; end if;
  select user_id into u from oyun.mahkeme_uye where sira = p_sira;
  if u is null then raise exception 'Bu koltukta üye yok.'; end if;
  if exists (select 1 from oyun.mahkeme_azil where uye = u and durum = 'acik') then raise exception 'Bu üye için zaten açık bir teklif var.'; end if;
  if exists (select 1 from oyun.mahkeme_azil where teklif_eden = p.id and bas > t - interval '24 hours') then raise exception 'Günde bir görevden alma teklifi verebilirsin.'; end if;
  if char_length(trim(coalesce(p_gerekce, ''))) not between 20 and 3000 then raise exception 'Gerekçe 20–3000 karakter olmalı.'; end if;
  insert into oyun.mahkeme_azil(sira, uye, teklif_eden, gerekce, bas, bit) values (p_sira, u, p.id, trim(p_gerekce), t, t + interval '48 hours') returning id into yeni;
  insert into oyun.mahkeme_azil_oy(azil_id, vekil, oy, zaman) values (yeni, p.id, 'kabul', t);
  perform oyun.bildir(u, 'Meclis''te Yüksek Mahkeme üyeliğinden görevden alınman için teklif verildi. 3/5 oy gerekir.', t);
  perform oyun.olay('meclis', format('%s, Yüksek Mahkeme üyesi %s için görevden alma teklifi verdi (3/5 oy gerekli).', p.kad, oyun.kad(u)), null, null, t);
  return jsonb_build_object('tamam', true, 'id', yeni);
end $function$;


CREATE OR REPLACE FUNCTION oyun.mahkeme_azil_say(p_id bigint, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a oyun.mahkeme_azil; kabul int; ret int; aktif int := oyun.aktif_vekil_sayi(); gerek int := oyun.mahkeme_azil_gerekli();
begin
 if oyun.gercekci_siyaset() then
  update oyun.mahkeme_azil set durum='ret' where id=p_id and durum='acik';
  return;
 end if;
  select * into a from oyun.mahkeme_azil where id = p_id for update;
  if a.id is null or a.durum <> 'acik' then return; end if;
  select count(*) filter (where o.oy = 'kabul'), count(*) filter (where o.oy = 'ret') into kabul, ret
    from oyun.mahkeme_azil_oy o join oyun.makamlar m on m.user_id = o.vekil and m.tur = 'mv' and m.bit is null where o.azil_id = p_id;
  if kabul >= gerek then
    update oyun.mahkeme_azil set durum = 'kabul' where id = p_id;
    if exists (select 1 from oyun.mahkeme_uye where sira = a.sira and user_id = a.uye) then
      perform oyun.mahkeme_indir(a.sira, a.teklif_eden, format('Meclis 3/5 oyla görevden aldı (%s kabul).', kabul), t);
    end if;
  elsif t >= a.bit or ret > aktif - gerek then
    update oyun.mahkeme_azil set durum = 'ret' where id = p_id;
    perform oyun.olay('meclis', format('Yüksek Mahkeme üyesi %s hakkındaki görevden alma teklifi reddedildi (%s kabul, %s gerekli).', oyun.kad(a.uye), kabul, gerek), null, null, t);
  end if;
end $function$;
