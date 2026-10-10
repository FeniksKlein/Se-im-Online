BEGIN;
-- Eklemeli: Yüksek Yargıç istifa, siyasi aday önerisi ve seçim sonucu itirazı
ALTER TABLE oyun.adliye_makam ADD COLUMN IF NOT EXISTS oneri_donemi integer NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS oyun.adliye_yargic_onerileri (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 parti_id bigint NOT NULL REFERENCES oyun.partiler(id),
 oneri_donemi integer NOT NULL,
 aday uuid NOT NULL REFERENCES oyun.profiller(id),
 yapan uuid NOT NULL REFERENCES oyun.profiller(id),
 aciklama text NOT NULL DEFAULT '',
 zaman timestamptz NOT NULL DEFAULT now(),
 UNIQUE(parti_id,oneri_donemi)
);
CREATE TABLE IF NOT EXISTS oyun.adliye_secim_itirazlari (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 secim_id bigint NOT NULL REFERENCES oyun.secimler(id),
 parti_id bigint NOT NULL REFERENCES oyun.partiler(id),
 yapan uuid NOT NULL REFERENCES oyun.profiller(id),
 gerekce text NOT NULL,
 deliller text NOT NULL DEFAULT '',
 zaman timestamptz NOT NULL DEFAULT now(),
 durum text NOT NULL DEFAULT 'bekliyor' CHECK (durum IN ('bekliyor','kabul','ret')),
 karar_veren uuid REFERENCES oyun.profiller(id),
 karar_gerekce text,
 karar_at timestamptz,
 UNIQUE(secim_id,parti_id)
);
CREATE INDEX IF NOT EXISTS adliye_itiraz_secim_idx ON oyun.adliye_secim_itirazlari(secim_id);

CREATE OR REPLACE FUNCTION public.adliye_hakim_istifa()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); eski uuid; t timestamptz:=oyun.simdi();
begin
 select hakim into eski from oyun.adliye_makam where id=1 for update;
 if eski is null or eski<>p.id then raise exception 'Yalnız görevdeki Yüksek Yargıç istifa edebilir.'; end if;
 update oyun.adliye_makam set hakim=null,atama_at=null,degistirme_at=t where id=1;
 insert into oyun.adliye_atama_kayit(yapan,eski,yeni,gerekce,zaman)
 values(p.id,p.id,null,'Yüksek Yargıç kendi isteğiyle istifa etti.',t);
 insert into oyun.bildirimler(user_id,zaman,metin)
 select distinct m.user_id,t,'Yüksek Yargıç istifa etti. Partiler yeni yargıç adaylarını önerebilir; son atama Cumhurbaşkanına aittir.'
 from oyun.makamlar m where m.tur='cb' and m.bit is null;
 return jsonb_build_object('tamam',true);
end; $function$;

CREATE OR REPLACE FUNCTION public.adliye_secim_itiraz_ac(p_secim bigint, p_parti bigint, p_gerekce text, p_deliller text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); s oyun.secimler; t timestamptz:=oyun.simdi(); yeni_id bigint;
begin
 if not exists(select 1 from oyun.partiler pa
 left join oyun.parti_sozcu ps on ps.parti_id=pa.id
 where pa.id=p_parti and not pa.kapali and (pa.gb=p.id or ps.user_id=p.id))
 then raise exception 'Partinin genel başkanı veya sözcüsü itiraz edebilir.'; end if;
 select * into s from oyun.secimler where id=p_secim;
 if s.id is null then raise exception 'Seçim bulunamadı.'; end if;
 if s.sonuc is null or s.sonuc_at is null or t<s.sonuc_at then
 raise exception 'Yalnız sonuçlanmış seçimlere itiraz edilebilir.'; end if;
 if t>s.sonuc_at+interval '48 hours' then raise exception '48 saatlik itiraz süresi doldu.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 30 and 1600
 then raise exception 'İtiraz gerekçesi 30-1600 karakter olmalı.'; end if;
 if char_length(coalesce(p_deliller,''))>3000 then raise exception 'Deliller en fazla 3000 karakter olabilir.'; end if;
 insert into oyun.adliye_secim_itirazlari(secim_id,parti_id,yapan,gerekce,deliller,zaman)
 values(s.id,p_parti,p.id,trim(p_gerekce),trim(coalesce(p_deliller,'')),t) returning id into yeni_id;
 return jsonb_build_object('tamam',true,'id',yeni_id);
end; $function$;

CREATE OR REPLACE FUNCTION public.adliye_secim_itiraz_karar(p_itiraz bigint, p_karar text, p_gerekce text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); it oyun.adliye_secim_itirazlari; t timestamptz:=oyun.simdi(); gb uuid;
begin
 if not exists(select 1 from oyun.adliye_makam where id=1 and hakim=p.id)
 then raise exception 'İtiraza yalnız Yüksek Yargıç karar verebilir.'; end if;
 if p_karar not in ('kabul','ret') then raise exception 'Geçersiz itiraz kararı.'; end if;
 if char_length(trim(coalesce(p_gerekce,''))) not between 25 and 1600
 then raise exception 'Karar gerekçesi 25-1600 karakter olmalı.'; end if;
 select * into it from oyun.adliye_secim_itirazlari where id=p_itiraz for update;
 if it.id is null or it.durum<>'bekliyor' then raise exception 'Bekleyen itiraz bulunamadı.'; end if;
 if exists(select 1 from oyun.profiller where id=p.id and parti_id=it.parti_id)
 then raise exception 'Yargıç kendi partisinin itirazını inceleyemez.'; end if;
 update oyun.adliye_secim_itirazlari
 set durum=p_karar,karar_veren=p.id,karar_gerekce=trim(p_gerekce),karar_at=t where id=it.id;
 select gb into gb from oyun.partiler where id=it.parti_id;
 if gb is not null then insert into oyun.bildirimler(user_id,zaman,metin)
 values(gb,t,'Adliye seçim itirazı #'||it.id||': '||case when p_karar='kabul' then 'İnceleme talebi kabul edildi.' else 'İtiraz reddedildi.' end); end if;
 return jsonb_build_object('tamam',true,'uyari','İtiraz kararı seçimin açıklanan sonuçlarını veya makamları kendiliğinden değiştirmez.');
end; $function$;

CREATE OR REPLACE FUNCTION public.adliye_siyasi_bilgi()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object(
 'oneri_donemi',(select oneri_donemi from oyun.adliye_makam where id=1),
 'oneriler',coalesce((select jsonb_agg(jsonb_build_object(
 'parti_id',o.parti_id,'parti',pa.ad,'aday',oyun.kad(o.aday),'aciklama',o.aciklama,'zaman',o.zaman)
 order by pa.ad)
 from oyun.adliye_yargic_onerileri o join oyun.partiler pa on pa.id=o.parti_id
 where o.oneri_donemi=(select oneri_donemi from oyun.adliye_makam where id=1)),'[]'::jsonb),
 'secimler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'tur',s.tur,'donem',s.donem,
 'sonuc_at',s.sonuc_at,'itiraz_son',s.sonuc_at+interval '48 hours') order by s.sonuc_at desc)
 from (select * from oyun.secimler
 where sonuc is not null and sonuc_at <= oyun.simdi()
 and sonuc_at+interval '48 hours'>oyun.simdi() order by sonuc_at desc limit 20) s),'[]'::jsonb),
 'itirazlar',coalesce((select jsonb_agg(jsonb_build_object(
 'id',i.id,'secim_id',i.secim_id,'secim_tur',s.tur,'secim_donem',s.donem,
 'parti_id',i.parti_id,'parti',pa.ad,'basvuran',oyun.kad(i.yapan),
 'gerekce',i.gerekce,'deliller',i.deliller,'basvuru_at',i.zaman,
 'durum',i.durum,'karar_veren',oyun.kad(i.karar_veren),'karar_gerekce',i.karar_gerekce,'karar_at',i.karar_at)
 order by i.id desc)
 from (select * from oyun.adliye_secim_itirazlari order by id desc limit 100) i
 join oyun.partiler pa on pa.id=i.parti_id join oyun.secimler s on s.id=i.secim_id),'[]'::jsonb)
 );
$function$;

CREATE OR REPLACE FUNCTION public.adliye_yargic_oner(p_parti bigint, p_kad text, p_aciklama text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); u oyun.profiller; d integer; t timestamptz:=oyun.simdi();
begin
 if not exists(select 1 from oyun.partiler where id=p_parti and gb=p.id and not kapali)
 then raise exception 'Yargıç adayını parti adına yalnız genel başkan önerebilir.'; end if;
 select * into u from oyun.profiller where lower(kad)=lower(trim(coalesce(p_kad,''))) and not yasakli;
 if u.id is null then raise exception 'Önerilen oyuncu bulunamadı.'; end if;
 if char_length(trim(coalesce(p_aciklama,'')))>450 then raise exception 'Açıklama en fazla 450 karakter olmalı.'; end if;
 select oneri_donemi into d from oyun.adliye_makam where id=1 for share;
 if exists(select 1 from oyun.adliye_makam where id=1 and hakim=u.id)
 then raise exception 'Görevdeki yargıç kendisi için önerilemez.'; end if;
 insert into oyun.adliye_yargic_onerileri(parti_id,oneri_donemi,aday,yapan,aciklama,zaman)
 values(p_parti,d,u.id,p.id,trim(coalesce(p_aciklama,'')),t)
 on conflict(parti_id,oneri_donemi) do update
 set aday=excluded.aday,yapan=excluded.yapan,aciklama=excluded.aciklama,zaman=excluded.zaman;
 return jsonb_build_object('tamam',true,'aday',u.kad,'oneri_donemi',d);
end; $function$;

CREATE OR REPLACE FUNCTION oyun.adliye_yeni_donem()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if new.hakim is distinct from old.hakim then
    new.oneri_donemi := old.oneri_donemi + 1;
 end if;
 return new;
end; $function$;
DROP TRIGGER IF EXISTS adliye_oneri_turu_tr ON oyun.adliye_makam;
CREATE TRIGGER adliye_oneri_turu_tr BEFORE UPDATE OF hakim ON oyun.adliye_makam
 FOR EACH ROW EXECUTE FUNCTION oyun.adliye_yeni_donem();
REVOKE ALL ON FUNCTION public.adliye_hakim_istifa() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.adliye_yargic_oner(bigint,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.adliye_secim_itiraz_ac(bigint,bigint,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.adliye_secim_itiraz_karar(bigint,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.adliye_siyasi_bilgi() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.adliye_hakim_istifa() TO authenticated;
GRANT EXECUTE ON FUNCTION public.adliye_yargic_oner(bigint,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adliye_secim_itiraz_ac(bigint,bigint,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adliye_secim_itiraz_karar(bigint,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adliye_siyasi_bilgi() TO authenticated;

COMMIT;
