-- Applied after the initial loan migration to prevent related-party credit.
create or replace function public.oyb_kredi_karar(p_id bigint,p_onay boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();k oyun.oyb_kredi;s oyun.sirketler;t timestamptz:=oyun.simdi();r jsonb;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 if p_onay is null then raise exception 'Karar eksik';end if;
 select * into k from oyun.oyb_kredi where id=p_id;
 if not found then raise exception 'Kredi basvurusu bulunamadi';end if;
 if not exists(select 1 from oyun.sirket_ortaklari o
  where o.sirket_id=k.banka_id and o.user_id=u and o.pay>=50)
 then raise exception 'Bu bankanin kredi yonetim yetkin yok';end if;
 select * into s from oyun.sirketler where id=k.banka_id and aktif and sektor='banka' for update;
 if not found then raise exception 'Banka artik faal degil';end if;
 select * into k from oyun.oyb_kredi where id=p_id for update;
 if k.durum<>'basvuru' then raise exception 'Bu basvuru zaten karara baglandi';end if;
 if exists(select 1 from oyun.sirket_ortaklari where sirket_id=k.banka_id and user_id=k.borclu and pay>0)
 then raise exception 'Banka ortaklarina veya yoneticilerine kredi kullandirilamaz';end if;
 if not p_onay then
   update oyun.oyb_kredi set durum='reddedildi',kapanis=t where id=k.id;
   return jsonb_build_object('tamam',true,'onay',false);
 end if;
 if exists(select 1 from oyun.banka_mevduat where banka_id=s.id and not kapandi and vade<=t)
 then raise exception 'Gecikmis mevduat odemeleri varken kredi verilemez';end if;
 r:=oyun.oyb_saglik(s.id);
 if k.anapara>(r->>'kredi_verilebilir')::numeric
 then raise exception 'Bankanin kredilendirmeye ayirabilecegi guvenli likidite yetersiz';end if;
 update oyun.sirketler set kasa=kasa-k.anapara where id=s.id and kasa>=k.anapara;
 if not found then raise exception 'Banka kasasinda para yok';end if;
 update oyun.oyb_kredi set durum='aktif',acilis=t,
   vade=t+make_interval(hours=>k.saat)
   where id=k.id;
 perform oyun.para_islem(k.borclu,k.anapara,'oyb_kredi','Oyuncu bankasindan kredi #'||k.id,t);
 insert into oyun.sirket_hareket(sirket_id,tutar,aciklama)
 values(s.id,0,'Oyuncu kredisi #'||k.id||' verildi: '||k.anapara||' TL');
 perform oyun.bildir(k.borclu,'Oyuncu bankasi kredi basvurun kabul edildi. Geri odeme tutari: '||k.toplam||' TL.',t);
 return jsonb_build_object('tamam',true,'onay',true,'vade',t+make_interval(hours=>k.saat));
end $$;

