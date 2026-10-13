-- Ruhsat tetikleyicisi tüm yatırım kayıt türlerinde ortak JSON maliyet alanı kullanır.
begin;
CREATE OR REPLACE FUNCTION oyun.bel_ruhsat_kapi()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); sid bigint; il smallint; hedef bigint; tip text;
 s oyun.sirketler; r oyun.bel_yatirim_ruhsat; tutar numeric; matrah numeric; il_ad text;
begin
 if u is null then raise exception 'Yatırım işlemi için oyuncu oturumu gerekli.';end if;
 if tg_table_name='eko_isletmeler' then
   sid:=new.sirket_id; il:=new.il_id; tip:='kur_'||new.tur;
 elsif tg_table_name='pazar_sirket' then
   sid:=new.sirket_id; il:=new.il_id; tip:='kur_pazar';
 elsif tg_table_name='eko_yapilar' then
   sid:=new.sirket_id; il:=new.il_id; tip:='arsa_insaat'; hedef:=new.arsa_id;
 elsif tg_table_name='eko_projeler' then
   sid:=new.sirket_id; il:=new.il_id; tip:='yeni_proje';
 elsif tg_table_name='eko_subeler' then
   sid:=new.sirket_id; tip:='sube'; hedef:=new.bolum_id;
   select y.il_id into il from oyun.eko_bolumler b join oyun.eko_yapilar y on y.id=b.yapi_id where b.id=hedef;
 else return new; end if;
 select * into s from oyun.sirketler where id=sid;
 if s.id is null or not s.aktif or not oyun.sirket_yonetici_mi(sid,u) then raise exception 'Ruhsat için şirket yönetim yetkisi gerekli.';end if;
 select * into r from oyun.bel_yatirim_ruhsat br
 where br.oyuncu=u and br.il_id=il and br.tur=tip and br.durum='onay'
 and (br.sirket_id=sid or (br.sirket_id is null and br.sirket_adi=s.ad))
 and (br.hedef_id is null or br.hedef_id=hedef)
 and (br.sektor is null or br.sektor=s.sektor)
 and br.karar_zamani>now()-interval '72 hours'
 order by br.id asc limit 1 for update;
 if r.id is null then
  raise exception 'Bu yatırım için % belediyesinden onaylı ruhsat gerekli. Ekonomi veya Belediye menüsündeki Ruhsat Merkezi üzerinden başvur.',(select ad from oyun.iller where id=il);
 end if;
 matrah:=case when tg_table_name in ('eko_yapilar','eko_projeler')
   then coalesce((to_jsonb(new)->>'maliyet')::numeric,0)
   when tg_table_name='eko_subeler' then greatest(0,s.sermaye*0.10)
   else s.sermaye end;
 tutar:=oyun.bel_ruhsat_tutar(r.onay_oran,r.onay_taban,matrah);
 update oyun.sirketler set kasa=kasa-tutar where id=sid and kasa>=tutar;
 if not found then raise exception 'Ruhsat harcı için şirket kasasında % TL gerekli.',tutar;end if;
 update oyun.il_durum set kasa=kasa+tutar/nullif(oyun.pazar_tl_milyar(),0) where il_id=il;
 update oyun.bel_yatirim_ruhsat set durum='kullanildi',odenen_tl=tutar,kullanma=now() where id=r.id;
 insert into oyun.belediye_sehir_hareket(il_id,tur,tutar,aciklama,zaman)
 values(il,'ruhsat_geliri',tutar/nullif(oyun.pazar_tl_milyar(),0),format('%s ruhsatı (#%s) - %s TL belediye geliri',tip,r.id,tutar),oyun.simdi());
 return new;
end $function$
;
commit;
