-- Etkinlik maliyetlerini kalem kalem sakla; eski organizasyonlari geri odeneksiz aynen koru.
ALTER TABLE oyun.uc_etkinlik
 ADD COLUMN IF NOT EXISTS personel_gider numeric,
 ADD COLUMN IF NOT EXISTS biletleme_gider numeric,
 ADD COLUMN IF NOT EXISTS kdv_gider numeric,
 ADD COLUMN IF NOT EXISTS kar_vergisi numeric;

-- Sadece eski bitmis etkinliklerin kesinlesen hesap dokumunu arsivle.
-- Oyun kasalarina/oyuncu bakiyelerine dokunulmaz.
UPDATE oyun.uc_etkinlik e
SET personel_gider=round(e.bilet_ciro*.15),
    biletleme_gider=0,
    kdv_gider=coalesce((select sum(h.tutar) from oyun.eko_vergi_hareket h
      where h.sirket_id=e.sirket_id and h.kaynak='uc_etkinlik_satis' and h.kaynak_id=e.id),0),
    kar_vergisi=coalesce((select sum(h.tutar) from oyun.eko_vergi_hareket h
      where h.sirket_id=e.sirket_id and h.kaynak='uc_etkinlik_kar' and h.kaynak_id=e.id),0)
WHERE e.durum='bitti' AND e.personel_gider IS NULL;

CREATE OR REPLACE FUNCTION oyun.uc_etkinlik_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 t timestamptz:=oyun.simdi();
 v record;
 guest integer;
 npc numeric;
 gross numeric;
 staff numeric;
 ticket_fee numeric;
 kdv numeric;
 matrah numeric;
 kv numeric;
 demand numeric;
 cnt integer:=0;
begin
 if not pg_try_advisory_xact_lock(927615) then
   return jsonb_build_object('kilitli',true);
 end if;
 for v in
  select x.*,s.aktif
  from oyun.uc_etkinlik x
  join oyun.sirketler s on s.id=x.sirket_id
  where x.durum='planlandi' and x.zaman<=t
  order by x.zaman,x.id
  limit 100 for update of x skip locked
 loop
   -- Bilet fiyati, turu ve organizasyon kimligine gore degisken NPC talebi;
   -- gercek oyuncu satislarinin uzerine kapasiteyi asmayacak sekilde eklenir.
   demand:=least(.78,greatest(.06,
     .48*sqrt(900.0/greatest(100,v.bilet))
     * case v.tur when 'konser' then 1.10 when 'fuar' then .95
       when 'forum' then .90 else 1.00 end
     * (.82+mod(abs(hashtext(v.id::text||'/'||v.il_id::text)::bigint),39)::numeric/100)
   ));
   guest:=case when v.aktif then
      least(greatest(0,v.kapasite-v.satilan),
         greatest(0,round(v.kapasite*demand)::integer))
      else 0 end;
   npc:=guest*v.bilet;
   gross:=v.bilet_ciro+npc;
   -- Salon bedeli daha once organizator kasasindan kesildi.
   -- Iscilik ve etkinlik ekibi gideri turune gore farkli oranlarda.
   staff:=round(gross*case v.tur
      when 'konser' then .09
      when 'fuar' then .07
      when 'forum' then .05
      else .06 end);
   -- Oyun ici biletleme/odeme kanali komisyonu: oran gercek bir
   -- platforma atfedilmez; organizatorun ustlendigi acik %3 oyun tarifi.
   ticket_fee:=round(gross*.03);
   -- KDV dahil bilet + sponsorluk cirosu, KDV haric kâr matrahi.
   kdv:=oyun.eko_vergi_hesap('satis',gross+v.sponsor_toplam);
   matrah:=greatest(0,gross+v.sponsor_toplam
       -v.mekan_gider-staff-ticket_fee-kdv);
   kv:=oyun.eko_vergi_hesap('kar',matrah);
   update oyun.sirketler
      set kasa=kasa+npc-staff-ticket_fee-kdv-kv
    where id=v.sirket_id;
   if oyun.eko_vergi_tahsil(v.sirket_id,'satis',gross+v.sponsor_toplam,
        'uc_etkinlik_satis',v.id)<>kdv then
      raise exception 'Etkinlik satis vergisi uyusmadi';
   end if;
   if oyun.eko_vergi_tahsil(v.sirket_id,'kar',matrah,
        'uc_etkinlik_kar',v.id)<>kv then
      raise exception 'Etkinlik kar vergisi uyusmadi';
   end if;
   update oyun.uc_etkinlik
      set satilan=satilan+guest,
          npc_satis=guest,
          bilet_ciro=gross,
          personel_gider=staff,
          biletleme_gider=ticket_fee,
          kdv_gider=kdv,
          kar_vergisi=kv,
          son_kar=gross+v.sponsor_toplam-v.mekan_gider-staff-ticket_fee-kdv-kv,
          durum='bitti'
    where id=v.id;
   cnt:=cnt+1;
 end loop;
 return jsonb_build_object('tamamlanan_etkinlik',cnt);
end $function$
;
CREATE OR REPLACE FUNCTION public.uc_etkinlik_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid();
begin
 perform oyun.profilim();
 return jsonb_build_object(
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad,'kasa',oyun.kasa_goster('sirket', s.id, s.kasa),'sektor',s.sektor))
 from oyun.sirketler s join oyun.sirket_ortaklari o on o.sirket_id=s.id
 where s.aktif and o.user_id=u and o.pay>=50),'[]'::jsonb),
 'iller',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad) order by ad) from oyun.iller),'[]'::jsonb),
 'etkinlikler',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'baslik',v.baslik,'tur',v.tur,
  'sirket',v.sirket_id,'sirket_ad',s.ad,'il',v.il_id,'zaman',v.zaman,'bilet',v.bilet,
  'kapasite',v.kapasite,'satilan',v.satilan,'npc_satis',v.npc_satis,
  'gercek_bilet',greatest(0,v.satilan-v.npc_satis),'ciro',v.bilet_ciro,
  'sponsor',v.sponsor_toplam,'mekan',v.mekan_gider,
  'personel',v.personel_gider,'biletleme',v.biletleme_gider,
  'kdv',v.kdv_gider,'kar_vergisi',v.kar_vergisi,
  'kar',v.son_kar,'durum',v.durum,
  'biletim',exists(select 1 from oyun.uc_etkinlik_bilet b where b.etkinlik_id=v.id and b.alici=u)))
  from oyun.uc_etkinlik v join oyun.sirketler s on s.id=v.sirket_id
  where v.durum='planlandi' or v.zaman>oyun.simdi()-interval '7 days'),'[]'::jsonb));
end $function$
;

-- Tek ve zaten aktif olan merkezi zamanlayicidan 10 dk yerine her dakika
-- tamamla; ayrica kapatilmis pg_cron isini ikinci kez etkinlestirme.
UPDATE oyun.zamanlayici_adim
SET periyot_dk=1,ofset_dk=0
WHERE adim='uc_etkinlik_bitir' AND aktif;
