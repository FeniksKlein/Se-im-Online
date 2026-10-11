-- 2026-10-11 | Emlak pazarliginda 'record m is not assigned yet' hatasi onarimi.
-- Dongu kaydi m ve tablo takma adi m arasindaki PL/pgSQL isim catismasi giderildi.
-- Sadece fonksiyon degisir; oyuncu bakiyeleri, tapular ve pazarlik verileri degismez.
CREATE OR REPLACE FUNCTION oyun.mulk_haftalik_vergi(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $yillik$
DECLARE m record; t timestamptz:=oyun.simdi(); v timestamptz;
  yil_vergi numeric; tahakkuk numeric; odeme numeric; hazir numeric; donem integer;
BEGIN
 FOR m IN SELECT ym.id,ym.il_id,ym.vergi_sonraki,ym.vergi_borc,ym.satin_alma,i.ad il_ad
          FROM oyun.yatirim_mulkleri ym JOIN oyun.iller i ON i.id=ym.il_id
          WHERE ym.user_id=p_user AND (ym.vergi_sonraki<=t OR ym.vergi_borc>0 OR ym.vergi_sonraki IS NULL)
          ORDER BY ym.id FOR UPDATE OF ym LOOP
   v:=coalesce(m.vergi_sonraki,oyun.mulk_vergi_ilk_vade(m.satin_alma));
   yil_vergi:=coalesce(oyun.mulk_yillik_vergi_tutar(m.id),0);
   tahakkuk:=0;donem:=0;
   WHILE v<=t AND donem<40 LOOP
     tahakkuk:=tahakkuk+round(yil_vergi/2,2);
     v:=oyun.mulk_vergi_sonraki_vade(v);
     donem:=donem+1;
   END LOOP;
   hazir:=greatest(0,coalesce((SELECT para FROM oyun.cuzdan WHERE user_id=p_user),0));
   odeme:=least(coalesce(m.vergi_borc,0)+tahakkuk,floor(hazir));
   UPDATE oyun.yatirim_mulkleri
      SET vergi_borc=greatest(0,coalesce(m.vergi_borc,0)+tahakkuk-odeme),vergi_sonraki=v
      WHERE id=m.id;
   IF odeme>0 THEN
     PERFORM oyun.para_islem(p_user,-odeme,'emlak_vergi',
       format('%s Belediyesi yıllık emlak vergisi (%s taksit) · mülk #%s',m.il_ad,donem,m.id),t,odeme);
     UPDATE oyun.il_durum SET kasa=coalesce(kasa,0)+odeme/1e9 WHERE il_id=m.il_id;
     INSERT INTO oyun.emlak_vergi_tahsilat(il_id,user_id,mulk_id,tutar,zaman)
        VALUES(m.il_id,p_user,m.id,odeme,t);
   END IF;
 END LOOP;
END $yillik$;
