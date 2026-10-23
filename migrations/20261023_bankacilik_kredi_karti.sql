-- Generated from live definitions on 2026-10-23; idempotent and additive.

-- No existing players, balances or properties are modified.

create schema if not exists oyun;

CREATE TABLE IF NOT EXISTS oyun."kart_basvurular" (
  "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "user_id" uuid NOT NULL,
  "banka_id" bigint,
  "istek" numeric(18,2) NOT NULL,
  "durum" text DEFAULT 'bekliyor'::text NOT NULL,
  "istenen" jsonb DEFAULT '["kredi_notu", "maas", "nakit", "mulk", "sirket"]'::jsonb NOT NULL,
  "izin" jsonb DEFAULT '[]'::jsonb NOT NULL,
  "bilgi" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "teklif_limit" numeric(18,2),
  "basvuru" timestamp with time zone DEFAULT now() NOT NULL,
  "karar_at" timestamp with time zone,
  CONSTRAINT "kart_basvurular_banka_id_fkey" FOREIGN KEY (banka_id) REFERENCES oyun.sirketler(id),
  CONSTRAINT "kart_basvurular_durum_check" CHECK ((durum = ANY (ARRAY['bekliyor'::text, 'onay'::text, 'red'::text]))),
  CONSTRAINT "kart_basvurular_istek_check" CHECK ((istek > (0)::numeric)),
  CONSTRAINT "kart_basvurular_pkey" PRIMARY KEY (id),
  CONSTRAINT "kart_basvurular_user_id_fkey" FOREIGN KEY (user_id) REFERENCES oyun.profiller(id)
);

CREATE INDEX IF NOT EXISTS kart_basvuru_banka_idx ON oyun.kart_basvurular USING btree (banka_id, durum);

CREATE INDEX IF NOT EXISTS kart_basvuru_kisi_idx ON oyun.kart_basvurular USING btree (user_id, durum);

ALTER TABLE oyun."kart_basvurular" ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON oyun."kart_basvurular" FROM public,anon,authenticated;

CREATE TABLE IF NOT EXISTS oyun."kredi_kartlari" (
  "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "user_id" uuid NOT NULL,
  "banka_id" bigint,
  "basvuru_id" bigint,
  "limit_tl" numeric(18,2) NOT NULL,
  "borc" numeric(18,2) DEFAULT 0 NOT NULL,
  "durum" text DEFAULT 'aktif'::text NOT NULL,
  "kesim_at" timestamp with time zone DEFAULT (now() + '7 days'::interval) NOT NULL,
  "gecikme_bas" timestamp with time zone,
  "ust_uste" integer DEFAULT 0 NOT NULL,
  "yil_eksik" integer DEFAULT 0 NOT NULL,
  "yil" integer DEFAULT (EXTRACT(year FROM now()))::integer NOT NULL,
  "acilis" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT "kredi_kartlari_banka_id_fkey" FOREIGN KEY (banka_id) REFERENCES oyun.sirketler(id),
  CONSTRAINT "kredi_kartlari_basvuru_id_fkey" FOREIGN KEY (basvuru_id) REFERENCES oyun.kart_basvurular(id),
  CONSTRAINT "kredi_kartlari_basvuru_id_key" UNIQUE (basvuru_id),
  CONSTRAINT "kredi_kartlari_borc_check" CHECK ((borc >= (0)::numeric)),
  CONSTRAINT "kredi_kartlari_durum_check" CHECK ((durum = ANY (ARRAY['aktif'::text, 'nakit_kapali'::text, 'kapali'::text, 'takip'::text]))),
  CONSTRAINT "kredi_kartlari_limit_tl_check" CHECK ((limit_tl > (0)::numeric)),
  CONSTRAINT "kredi_kartlari_pkey" PRIMARY KEY (id),
  CONSTRAINT "kredi_kartlari_user_id_fkey" FOREIGN KEY (user_id) REFERENCES oyun.profiller(id)
);

CREATE INDEX IF NOT EXISTS kart_banka_idx ON oyun.kredi_kartlari USING btree (banka_id);

CREATE INDEX IF NOT EXISTS kart_sahip_idx ON oyun.kredi_kartlari USING btree (user_id);

ALTER TABLE oyun."kredi_kartlari" ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON oyun."kredi_kartlari" FROM public,anon,authenticated;

CREATE TABLE IF NOT EXISTS oyun."kart_ekstreler" (
  "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "kart_id" bigint NOT NULL,
  "kesim" timestamp with time zone NOT NULL,
  "son_odeme" timestamp with time zone NOT NULL,
  "toplam" numeric(18,2) NOT NULL,
  "asgari" numeric(18,2) NOT NULL,
  "odenen" numeric(18,2) DEFAULT 0 NOT NULL,
  "durum" text DEFAULT 'acik'::text NOT NULL,
  CONSTRAINT "kart_ekstreler_durum_check" CHECK ((durum = ANY (ARRAY['acik'::text, 'odendi'::text, 'devretti'::text]))),
  CONSTRAINT "kart_ekstreler_kart_id_fkey" FOREIGN KEY (kart_id) REFERENCES oyun.kredi_kartlari(id),
  CONSTRAINT "kart_ekstreler_kart_id_kesim_key" UNIQUE (kart_id, kesim),
  CONSTRAINT "kart_ekstreler_pkey" PRIMARY KEY (id)
);

ALTER TABLE oyun."kart_ekstreler" ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON oyun."kart_ekstreler" FROM public,anon,authenticated;

CREATE TABLE IF NOT EXISTS oyun."kart_hareketler" (
  "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "kart_id" bigint NOT NULL,
  "tur" text NOT NULL,
  "tutar" numeric(18,2) NOT NULL,
  "alici" uuid,
  "sirket_id" bigint,
  "aciklama" text,
  "zaman" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT "kart_hareketler_alici_fkey" FOREIGN KEY (alici) REFERENCES oyun.profiller(id),
  CONSTRAINT "kart_hareketler_kart_id_fkey" FOREIGN KEY (kart_id) REFERENCES oyun.kredi_kartlari(id),
  CONSTRAINT "kart_hareketler_pkey" PRIMARY KEY (id),
  CONSTRAINT "kart_hareketler_sirket_id_fkey" FOREIGN KEY (sirket_id) REFERENCES oyun.sirketler(id),
  CONSTRAINT "kart_hareketler_tur_check" CHECK ((tur = ANY (ARRAY['alisveris'::text, 'odeme'::text, 'faiz'::text, 'gecikme'::text, 'nakit_avans'::text, 'avans_masraf'::text]))),
  CONSTRAINT "kart_hareketler_tutar_check" CHECK ((tutar > (0)::numeric))
);

CREATE INDEX IF NOT EXISTS kart_hareket_idx ON oyun.kart_hareketler USING btree (kart_id, zaman DESC);

ALTER TABLE oyun."kart_hareketler" ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON oyun."kart_hareketler" FROM public,anon,authenticated;

CREATE TABLE IF NOT EXISTS oyun."kart_pos_talepleri" (
  "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "sirket_id" bigint NOT NULL,
  "musteri" uuid NOT NULL,
  "talep_eden" uuid NOT NULL,
  "tutar" numeric(18,2) NOT NULL,
  "aciklama" text NOT NULL,
  "durum" text DEFAULT 'bekliyor'::text NOT NULL,
  "olusturma" timestamp with time zone DEFAULT now() NOT NULL,
  "odendi" timestamp with time zone,
  "kart_id" bigint,
  CONSTRAINT "kart_pos_talepleri_durum_check" CHECK ((durum = ANY (ARRAY['bekliyor'::text, 'odendi'::text, 'reddedildi'::text, 'iptal'::text]))),
  CONSTRAINT "kart_pos_talepleri_kart_id_fkey" FOREIGN KEY (kart_id) REFERENCES oyun.kredi_kartlari(id),
  CONSTRAINT "kart_pos_talepleri_musteri_fkey" FOREIGN KEY (musteri) REFERENCES oyun.profiller(id),
  CONSTRAINT "kart_pos_talepleri_pkey" PRIMARY KEY (id),
  CONSTRAINT "kart_pos_talepleri_sirket_id_fkey" FOREIGN KEY (sirket_id) REFERENCES oyun.sirketler(id),
  CONSTRAINT "kart_pos_talepleri_talep_eden_fkey" FOREIGN KEY (talep_eden) REFERENCES oyun.profiller(id),
  CONSTRAINT "kart_pos_talepleri_tutar_check" CHECK ((tutar > (0)::numeric))
);

CREATE INDEX IF NOT EXISTS kart_pos_musteri_idx ON oyun.kart_pos_talepleri USING btree (musteri, durum);

ALTER TABLE oyun."kart_pos_talepleri" ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON oyun."kart_pos_talepleri" FROM public,anon,authenticated;

ALTER TABLE oyun.icra_takip DROP CONSTRAINT IF EXISTS icra_takip_kaynak_check;

ALTER TABLE oyun.icra_takip ADD CONSTRAINT icra_takip_kaynak_check CHECK (kaynak IN ('kredi','emlak_vergisi','kredi_karti'));

CREATE OR REPLACE FUNCTION oyun.kart_donem_isle(p_kart bigint DEFAULT NULL::bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c oyun.kredi_kartlari; e oyun.kart_ekstreler; zaman timestamptz:=oyun.simdi(); kalan numeric;
 a numeric; f numeric; gc numeric; tarihsayi integer:=0;
begin
 for c in select * from oyun.kredi_kartlari where (p_kart is null or id=p_kart)
 order by id for update loop
   tarihsayi:=0;
   if c.yil<>extract(year from zaman)::int then
     update oyun.kredi_kartlari set yil=extract(year from zaman)::int,yil_eksik=0 where id=c.id;
     c.yil_eksik:=0;
   end if;
   -- Birikmis son odeme tarihini kapat; kart limiti / asgari hesabini ekstre aninda dondur.
   for e in select * from oyun.kart_ekstreler
    where kart_id=c.id and durum='acik' and son_odeme<=zaman order by son_odeme for update loop
     if e.odenen<e.asgari and e.toplam>e.odenen then
       update oyun.kredi_kartlari set ust_uste=ust_uste+1, yil_eksik=yil_eksik+1,
       gecikme_bas=coalesce(gecikme_bas,e.son_odeme),
       durum=case when ust_uste+1>=3 then 'kapali'
                    when yil_eksik+1>=3 then 'nakit_kapali' else durum end
       where id=c.id;
       -- Gecikmeye dusen asgari kisma gecikme faizi, kalan kisma akdi faiz.
       kalan:=greatest(0,e.toplam-e.odenen);
       f:=case when e.toplam<30000 then 3.25 when e.toplam<=180000 then 3.75 else 4.25 end;
       gc:=f+0.30;
       a:=round((least(kalan,greatest(0,e.asgari-e.odenen))*gc+
                  greatest(0,kalan-greatest(0,e.asgari-e.odenen))*f)*7/3000,2);
       if a>0 then
         update oyun.kredi_kartlari set borc=borc+a where id=c.id;
         insert into oyun.kart_hareketler(kart_id,tur,tutar,aciklama,zaman)
         values(c.id,'gecikme',a,'Haftalik akdi/gecikme faizi (aylik tavanin 7/30 oranli karsiligi)',zaman);
       end if;
       insert into oyun.bildirimler(user_id,metin)
       values(c.user_id,format('💳 Asgari kart odemen gecikti. Eksik %s TL. Kredi notun etkilenir; kart kisitlanabilir.',greatest(0,e.asgari-e.odenen)));
       update oyun.banka_musteri set kredi_notu=greatest(0,coalesce(kredi_notu,1100)-35) where user_id=c.user_id;
     else
       update oyun.kredi_kartlari set ust_uste=0 where id=c.id;
       if e.toplam>e.odenen then
         kalan:=e.toplam-e.odenen;
         f:=case when e.toplam<30000 then 3.25 when e.toplam<=180000 then 3.75 else 4.25 end;
         a:=round(kalan*f*7/3000,2);
         if a>0 then
           update oyun.kredi_kartlari set borc=borc+a where id=c.id;
           insert into oyun.kart_hareketler(kart_id,tur,tutar,aciklama,zaman)
             values(c.id,'faiz',a,'Asgari odendi; kalan borca 7 gunluk akdi faiz',zaman);
         end if;
       end if;
     end if;
     update oyun.kart_ekstreler set durum=case when toplam<=odenen then 'odendi' else 'devretti' end where id=e.id;
   end loop;
   -- Yasal takip ancak uzun sureli odenmeyen borc ve odeme firsati sonrasi.
   select * into c from oyun.kredi_kartlari where id=c.id;
   if c.gecikme_bas is not null and c.gecikme_bas<=zaman-interval '90 days' and c.borc>0 then
     update oyun.kredi_kartlari set durum='takip' where id=c.id;
     insert into oyun.icra_takip(kaynak,kaynak_id,borclu,alacakli_sirket,durum,baslangic_borc,teblig,odeme_son)
     values('kredi_karti',c.id,c.user_id,c.banka_id,'teblig',c.borc,zaman,zaman+interval '7 days')
     on conflict (kaynak,kaynak_id) do nothing;
   end if;
   -- Gecmis hafta ekstrelerini olustur (idempotent) ve devir borcunu tek bir yeni ekstreye tasir.
   while c.kesim_at<=zaman and tarihsayi<60 loop
     select borc into kalan from oyun.kredi_kartlari where id=c.id;
     if kalan>0 then
       insert into oyun.kart_ekstreler(kart_id,kesim,son_odeme,toplam,asgari)
       values(c.id,c.kesim_at,c.kesim_at+interval '7 days',kalan,
         round(kalan*case when c.limit_tl<=100000 then 0.20 else 0.40 end,2))
       on conflict do nothing;
     end if;
     c.kesim_at:=c.kesim_at+interval '7 days';
     update oyun.kredi_kartlari set kesim_at=c.kesim_at where id=c.id;
     tarihsayi:=tarihsayi+1;
   end loop;
 end loop;
end $function$;

REVOKE ALL ON FUNCTION oyun."kart_donem_isle"(p_kart bigint) FROM public,anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.kart_harca(p_kart bigint, p_tutar numeric, p_alici uuid DEFAULT NULL::uuid, p_sirket bigint DEFAULT NULL::bigint, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); k oyun.kredi_kartlari; b oyun.sirketler; n numeric; alici uuid;
begin
 if u is null or p_tutar is null or p_tutar<=0 or p_tutar>100000000 then raise exception 'Gecersiz odeme';end if;
 if (p_alici is null)=(p_sirket is null) then raise exception 'Bir alici oyuncu veya sirket sec';end if;
 perform oyun.kart_donem_isle(p_kart);
 select * into k from oyun.kredi_kartlari where id=p_kart and user_id=u for update;
 if not found or k.durum<>'aktif' then raise exception 'Kart aktif degil';end if;
 n:=round(p_tutar,2);
 if k.limit_tl-k.borc<n then raise exception 'Kullanilabilir kart limiti yetersiz';end if;
 if p_sirket is not null then
   select * into b from oyun.sirketler where id=p_sirket and aktif for update;
   if not found then raise exception 'Alici sirket bulunamadi';end if;
   if b.kurucu=u then raise exception 'Kendi sirketine kartla fon aktaramazsin';end if;
 else
   if p_alici=u then raise exception 'Kendine kartla para gonderemezsin';end if;
   if not exists(select 1 from oyun.profiller where id=p_alici) then raise exception 'Alici oyuncu bulunamadi';end if;
 end if;
 if k.banka_id is null then
   update oyun.ulke set hazine=hazine-n where id=1 and hazine>=n;
 else
   update oyun.sirketler set kasa=kasa-n where id=k.banka_id and sektor='banka' and aktif and kasa>=n;
 end if;
 if not found then raise exception 'Banka kasasinda odemeyi karsilayacak para yok';end if;
 if p_sirket is not null then
   update oyun.sirketler set kasa=kasa+n where id=p_sirket;
 else
   insert into oyun.cuzdan(user_id,para) values(p_alici,n)
   on conflict(user_id) do update set para=oyun.cuzdan.para+excluded.para;
 end if;
 update oyun.kredi_kartlari set borc=borc+n where id=k.id;
 insert into oyun.kart_hareketler(kart_id,tur,tutar,alici,sirket_id,aciklama,zaman)
 values(k.id,'alisveris',n,p_alici,p_sirket,left(coalesce(p_aciklama,'Kart ile odeme'),240),oyun.simdi());
 insert into oyun.bildirimler(user_id,metin)
 values(u,format('💳 %s TL kartla odendi. Kalan kullanilabilir limitin guncellendi.',n));
 return jsonb_build_object('ok',true,'borc',k.borc+n);
end $function$;

REVOKE ALL ON FUNCTION oyun."kart_harca"(p_kart bigint, p_tutar numeric, p_alici uuid, p_sirket bigint, p_aciklama text) FROM public,anon,authenticated;

CREATE OR REPLACE FUNCTION oyun.kart_onayla_ic(p_basvuru bigint, p_limit numeric)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b oyun.kart_basvurular; kaynak numeric; ayrilmis numeric; risk jsonb; ust numeric; kim bigint;
begin
 select * into b from oyun.kart_basvurular where id=p_basvuru for update;
 if not found or b.durum<>'bekliyor' then raise exception 'Bekleyen basvuru bulunamadi'; end if;
 if not b.izin ? 'kredi_notu' then raise exception 'Oyuncunun kredi notu bilgi izni gerekli'; end if;
 risk:=oyun.kredi_risk_ozeti(b.user_id,168);
 if coalesce((risk->>'kredi_notu')::numeric,0)<650 then raise exception 'Kredi notu kart verilmesine uygun degil'; end if;
 if b.banka_id is null then
   select hazine into kaynak from oyun.ulke where id=1 for update;
 else
   select kasa into kaynak from oyun.sirketler where id=b.banka_id and aktif and sektor='banka' for update;
 end if;
 if kaynak is null then raise exception 'Banka mevcut degil'; end if;
 select coalesce(sum(greatest(limit_tl-borc,0)),0) into ayrilmis
 from oyun.kredi_kartlari where banka_id is not distinct from b.banka_id and durum not in ('kapali','takip');
 ust:=least(b.istek,coalesce(p_limit,0),
   greatest(0,coalesce((risk->>'haftalik_gelir')::numeric,0)*3+coalesce((risk->>'nakit')::numeric,0)*0.08),
   greatest(0,kaynak*0.45-ayrilmis));
 ust:=floor(ust);
 if ust<1000 then raise exception 'Banka likiditesi veya oyuncu geliri limit icin yetersiz'; end if;
 insert into oyun.kredi_kartlari(user_id,banka_id,basvuru_id,limit_tl,kesim_at)
 values(b.user_id,b.banka_id,b.id,ust,oyun.simdi()+interval '7 days') returning id into kim;
 update oyun.kart_basvurular set durum='onay',teklif_limit=ust,karar_at=oyun.simdi() where id=b.id;
 insert into oyun.bildirimler(user_id,metin) values(b.user_id,format('💳 Kredi kartin onaylandi! Limit: %s TL. Ilk hesap kesimi 7 gun sonra.',ust));
 return kim;
end $function$;

REVOKE ALL ON FUNCTION oyun."kart_onayla_ic"(p_basvuru bigint, p_limit numeric) FROM public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.kart_basvur(p_banka bigint, p_limit numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); kim bigint; acik bigint;
begin
 if u is null then raise exception 'Giris yapmalisin'; end if;
 if p_limit is null or p_limit<1000 or p_limit>50000000 then raise exception 'Kart talebi 1.000 ile 50 milyon TL arasinda olmali'; end if;
 if p_banka is not null and not exists(select 1 from oyun.sirketler where id=p_banka and sektor='banka' and aktif) then
   raise exception 'Banka bulunamadi';end if;
 if exists(select 1 from oyun.kart_basvurular where user_id=u and banka_id is not distinct from p_banka and durum='bekliyor') then
   raise exception 'Bu bankada bekleyen kart basvurun var';end if;
 insert into oyun.kart_basvurular(user_id,banka_id,istek)
 values(u,p_banka,p_limit) returning id into kim;
 if p_banka is null then
   update oyun.kart_basvurular set istenen='["kredi_notu","maas","nakit"]'::jsonb where id=kim;
 end if;
 return jsonb_build_object('id',kim,'durum','bekliyor','mesaj','Mali bilgi izni verdikten sonra basvuru degerlendirilecek');
end $function$;

REVOKE ALL ON FUNCTION public."kart_basvur"(p_banka bigint, p_limit numeric) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_basvur"(p_banka bigint, p_limit numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_basvuru_karar(p_basvuru bigint, p_onay boolean, p_limit numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b oyun.kart_basvurular; kim bigint; u uuid:=auth.uid();
begin
 if u is null then raise exception 'Giris yapmalisin';end if;
 select * into b from oyun.kart_basvurular where id=p_basvuru and durum='bekliyor' for update;
 if not found or b.banka_id is null then raise exception 'Oyuncu bankasina ait bekleyen basvuru yok';end if;
 if not exists(select 1 from oyun.sirketler s where s.id=b.banka_id and s.yonetici=u and s.sektor='banka') and
    not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=b.banka_id and o.user_id=u and o.pay>=50)
 then raise exception 'Banka yoneticisi degilsin';end if;
 if not p_onay then
   update oyun.kart_basvurular set durum='red',karar_at=oyun.simdi() where id=p_basvuru;
   insert into oyun.bildirimler(user_id,metin) values(b.user_id,'💳 Kredi karti basvurun banka tarafindan reddedildi.');
   return jsonb_build_object('durum','red');
 end if;
 if b.izin='[]'::jsonb then raise exception 'Musteri henuz mali belge izni vermedi';end if;
 kim:=oyun.kart_onayla_ic(b.id,least(coalesce(p_limit,b.istek),b.istek));
 return jsonb_build_object('durum','onay','kart_id',kim);
end $function$;

REVOKE ALL ON FUNCTION public."kart_basvuru_karar"(p_basvuru bigint, p_onay boolean, p_limit numeric) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_basvuru_karar"(p_basvuru bigint, p_onay boolean, p_limit numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_belge_iste(p_basvuru bigint, p_alanlar jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); b oyun.kart_basvurular; x text;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into b from oyun.kart_basvurular where id=p_basvuru for update;
 if not found or b.durum<>'bekliyor' or b.banka_id is null then raise exception 'Basvuru uygun degil'; end if;
 if not exists(select 1 from oyun.sirketler s where s.id=b.banka_id and s.yonetici=u and s.sektor='banka') and
    not exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=b.banka_id and o.user_id=u and o.pay>=50)
 then raise exception 'Banka yoneticisi degilsin';end if;
 if jsonb_typeof(p_alanlar)<>'array' then raise exception 'Istenen belge listesi hatali';end if;
 for x in select jsonb_array_elements_text(p_alanlar) loop
    if x not in ('kredi_notu','maas','nakit','mulk','sirket') then raise exception 'Taninmayan bilgi alani';end if;
 end loop;
 update oyun.kart_basvurular set istenen=p_alanlar, izin='[]'::jsonb,bilgi='{}'::jsonb where id=p_basvuru;
 insert into oyun.bildirimler(user_id,metin) values(b.user_id,'💳 Banka kredi karti basvurun icin mali belge izni istedi. Bankacilik > Basvurular sayfasindan yanitla.');
 return jsonb_build_object('ok',true);
end $function$;

REVOKE ALL ON FUNCTION public."kart_belge_iste"(p_basvuru bigint, p_alanlar jsonb) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_belge_iste"(p_basvuru bigint, p_alanlar jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_belge_yanit(p_basvuru bigint, p_onay boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare b oyun.kart_basvurular; r jsonb; j jsonb:='{}'::jsonb; anahtar text; kart bigint;
begin
 select * into b from oyun.kart_basvurular where id=p_basvuru and user_id=auth.uid() and durum='bekliyor' for update;
 if not found then raise exception 'Basvuru bulunamadi';end if;
 if not p_onay then
   update oyun.kart_basvurular set izin='[]'::jsonb,bilgi='{}'::jsonb where id=b.id;
   return jsonb_build_object('ok',true,'izin',false);
 end if;
 r:=oyun.kredi_risk_ozeti(b.user_id,168);
 for anahtar in select jsonb_array_elements_text(b.istenen) loop
   j:=j||case anahtar
     when 'kredi_notu' then jsonb_build_object('kredi_notu',r->'kredi_notu','risk',r->'not_ad')
     when 'maas' then jsonb_build_object('haftalik_gelir',r->'haftalik_gelir','haftalik_maas',r->'haftalik_maas')
     when 'nakit' then jsonb_build_object('nakit',r->'nakit')
     when 'mulk' then jsonb_build_object('mulk_sayisi',(select count(*) from oyun.yatirim_mulkleri where user_id=b.user_id))
     when 'sirket' then jsonb_build_object('sirket_hissesi',(select count(*) from oyun.sirket_ortaklari where user_id=b.user_id and pay>0))
     else '{}'::jsonb end;
 end loop;
 update oyun.kart_basvurular set izin=istenen,bilgi=j where id=b.id;
 if b.banka_id is null then
   kart:=oyun.kart_onayla_ic(b.id,b.istek);
 end if;
 return jsonb_build_object('ok',true,'izin',true,'kart_id',kart,'bilgi',j);
end $function$;

REVOKE ALL ON FUNCTION public."kart_belge_yanit"(p_basvuru bigint, p_onay boolean) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_belge_yanit"(p_basvuru bigint, p_onay boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_nakit_avans(p_kart bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); k oyun.kredi_kartlari; n numeric; masraf numeric;
begin
 if u is null or p_tutar is null or p_tutar<100 then raise exception 'Nakit avans en az 100 TL';end if;
 perform oyun.kart_donem_isle(p_kart);
 select * into k from oyun.kredi_kartlari where id=p_kart and user_id=u for update;
 if not found or k.durum<>'aktif' or k.yil_eksik>=3 then raise exception 'Kart nakit avansa kapali';end if;
 n:=round(p_tutar,2); masraf:=round(n*0.02,2);
 if k.limit_tl-k.borc<n+masraf then raise exception 'Limit yetersiz';end if;
 if k.banka_id is null then update oyun.ulke set hazine=hazine-n where id=1 and hazine>=n;
 else update oyun.sirketler set kasa=kasa-n where id=k.banka_id and kasa>=n;end if;
 if not found then raise exception 'Bankanin nakit kaynagi yetersiz';end if;
 update oyun.cuzdan set para=para+n where user_id=u;
 update oyun.kredi_kartlari set borc=borc+n+masraf where id=k.id;
 insert into oyun.kart_hareketler(kart_id,tur,tutar,aciklama)
 values(k.id,'nakit_avans',n,'Nakit avans - kullanim anindan faiz uygulamasi baslar'),
 (k.id,'avans_masraf',masraf,'Nakit avans %2 islem masrafi');
 return jsonb_build_object('ok',true,'nakit',n,'masraf',masraf);
end $function$;

REVOKE ALL ON FUNCTION public."kart_nakit_avans"(p_kart bigint, p_tutar numeric) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_nakit_avans"(p_kart bigint, p_tutar numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_ode(p_kart bigint, p_tutar numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); k oyun.kredi_kartlari; o numeric; tak oyun.kart_ekstreler; karsilanan numeric; dis numeric;
begin
 if u is null or p_tutar is null or p_tutar<=0 then raise exception 'Gecersiz tutar';end if;
 perform oyun.kart_donem_isle(p_kart);
 select * into k from oyun.kredi_kartlari where id=p_kart and user_id=u for update;
 if not found then raise exception 'Kart bulunamadi';end if;
 o:=least(round(p_tutar,2),k.borc);
 if o<=0 then raise exception 'Odenecek kart borcu bulunmuyor';end if;
 update oyun.cuzdan set para=para-o where user_id=u and para>=o;
 if not found then raise exception 'Sahsi cuzdan bakiyesi yetersiz';end if;
 if k.banka_id is null then
   update oyun.ulke set hazine=hazine+o where id=1;
 else
   update oyun.sirketler set kasa=kasa+o where id=k.banka_id;
 end if;
 update oyun.kredi_kartlari set borc=greatest(0,borc-o) where id=k.id;
 dis:=o;
 for tak in select * from oyun.kart_ekstreler where kart_id=k.id and durum='acik' order by id asc for update loop
   karsilanan:=least(dis,greatest(0,tak.toplam-tak.odenen));
   update oyun.kart_ekstreler set odenen=odenen+karsilanan,
     durum=case when odenen+karsilanan>=toplam then 'odendi' else durum end where id=tak.id;
   dis:=dis-karsilanan;
   if dis<=0 then exit;end if;
 end loop;
 update oyun.kredi_kartlari set ust_uste=case when borc=0 then 0 else ust_uste end,
   gecikme_bas=case when borc=0 then null else gecikme_bas end,
   durum=case when borc=0 and durum in ('kapali','nakit_kapali') then 'aktif' else durum end
 where id=k.id;
 insert into oyun.kart_hareketler(kart_id,tur,tutar,aciklama,zaman)
 values(k.id,'odeme',o,'Kart borc odemesi',oyun.simdi());
 return jsonb_build_object('ok',true,'odenen',o,'kalan',k.borc-o);
end $function$;

REVOKE ALL ON FUNCTION public."kart_ode"(p_kart bigint, p_tutar numeric) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_ode"(p_kart bigint, p_tutar numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); j jsonb; liste jsonb; kart oyun.kredi_kartlari;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 for kart in select * from oyun.kredi_kartlari where user_id=u loop
   perform oyun.kart_donem_isle(kart.id);
 end loop;
 select coalesce(jsonb_agg(jsonb_build_object('id',k.id,'banka_id',k.banka_id,
 'banka',coalesce(s.ad,'Devlet Bankasi'),'limit',k.limit_tl,'borc',k.borc,
 'kullanilabilir',greatest(k.limit_tl-k.borc,0),'durum',k.durum,'kesim_at',k.kesim_at,
 'gecikme_bas',k.gecikme_bas,'son_dort',lpad((k.id%10000)::text,4,'0'),
 'ekstreler',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'kesim',a.kesim,
 'son_odeme',a.son_odeme,'toplam',a.toplam,'asgari',a.asgari,'odenen',a.odenen,'durum',a.durum)
 order by a.id desc) from (select * from oyun.kart_ekstreler where kart_id=k.id order by id desc limit 10)a),'[]'::jsonb),
 'hareketler',coalesce((select jsonb_agg(jsonb_build_object('tur',a.tur,'tutar',a.tutar,
 'aciklama',a.aciklama,'zaman',a.zaman) order by a.id desc)
 from (select * from oyun.kart_hareketler where kart_id=k.id order by id desc limit 30)a),'[]'::jsonb)
 ) order by k.id desc),'[]'::jsonb) into liste
 from oyun.kredi_kartlari k left join oyun.sirketler s on s.id=k.banka_id where k.user_id=u;
 select jsonb_build_object(
 'kartlar',liste,
 'basvurular',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'banka_id',b.banka_id,
 'banka',coalesce(s.ad,'Devlet Bankasi'),'istek',b.istek,'durum',b.durum,'istenen',b.istenen,
 'izin',b.izin,'teklif_limit',b.teklif_limit,'basvuru',b.basvuru) order by b.id desc)
 from oyun.kart_basvurular b left join oyun.sirketler s on s.id=b.banka_id where b.user_id=u),'[]'::jsonb),
 'bankalar',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad,'kasa',kasa)
 order by id) from oyun.sirketler where sektor='banka' and aktif),'[]'::jsonb),
 'yonetilen',coalesce((select jsonb_agg(jsonb_build_object('id',b.id,'banka_id',b.banka_id,
 'banka',s.ad,'oyuncu',p.kad,'istek',b.istek,'istenen',b.istenen,'izin',b.izin,
 'bilgi',case when b.izin<>'[]'::jsonb then b.bilgi else '{}'::jsonb end)
 order by b.id desc)
 from oyun.kart_basvurular b join oyun.sirketler s on s.id=b.banka_id
 left join oyun.profiller p on p.id=b.user_id
 where b.durum='bekliyor' and
 (s.yonetici=u or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=u and o.pay>=50))),'[]'::jsonb)) into j;
 return j;
end $function$;

REVOKE ALL ON FUNCTION public."kart_panel"() FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_panel"() TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_pos_bekleyen()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
select jsonb_build_object(
 'gelen',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'sirket_id',t.sirket_id,
 'sirket',s.ad,'tutar',t.tutar,'aciklama',t.aciklama,'olusturma',t.olusturma)
 order by t.id desc)
 from oyun.kart_pos_talepleri t join oyun.sirketler s on s.id=t.sirket_id
 where t.musteri=auth.uid() and t.durum='bekliyor'),'[]'::jsonb),
 'giden',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'sirket_id',t.sirket_id,
 'musteri',p.kad,'tutar',t.tutar,'aciklama',t.aciklama,'durum',t.durum)
 order by t.id desc)
 from (select * from oyun.kart_pos_talepleri where talep_eden=auth.uid() order by id desc limit 30)t
 join oyun.profiller p on p.id=t.musteri),'[]'::jsonb),
 'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'ad',s.ad) order by s.id)
 from oyun.sirketler s where s.aktif and s.sektor<>'banka' and
 (s.yonetici=auth.uid() or exists(select 1 from oyun.sirket_ortaklari o where o.sirket_id=s.id and o.user_id=auth.uid() and o.pay>=50))),'[]'::jsonb))
$function$;

REVOKE ALL ON FUNCTION public."kart_pos_bekleyen"() FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_pos_bekleyen"() TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_pos_talep(p_sirket bigint, p_oyuncu text, p_tutar numeric, p_aciklama text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); m uuid; s oyun.sirketler; kim bigint;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into s from oyun.sirketler where id=p_sirket and aktif and sektor<>'banka' for update;
 if not found then raise exception 'Aktif satis sirketi bulunamadi';end if;
 if s.yonetici is distinct from u and
 not exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=u and pay>=50)
 then raise exception 'Sirket yetkilisi degilsin';end if;
 select id into m from oyun.profiller where lower(kad)=lower(trim(p_oyuncu)) limit 1;
 if m is null then raise exception 'Oyuncu adi bulunamadi';end if;
 if m=u or exists(select 1 from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=m and pay>0)
 then raise exception 'Kendi sirketin icin POS talebi acamazsin';end if;
 if p_tutar is null or p_tutar<1 or p_tutar>100000000 then raise exception 'Gecersiz satis tutari';end if;
 if length(trim(coalesce(p_aciklama,'')))<4 then raise exception 'Mal veya hizmet aciklamasi gerekli';end if;
 insert into oyun.kart_pos_talepleri(sirket_id,musteri,talep_eden,tutar,aciklama)
 values(p_sirket,m,u,round(p_tutar,2),left(p_aciklama,240)) returning id into kim;
 insert into oyun.bildirimler(user_id,metin)
 values(m,format('💳 %s sirketi %s TL POS odemesi talep ediyor (%s). Bankacilik > POS Talepleri bolumunden kabul veya reddet.',s.ad,round(p_tutar,2),left(p_aciklama,60)));
 return jsonb_build_object('id',kim,'durum','bekliyor');
end $function$;

REVOKE ALL ON FUNCTION public."kart_pos_talep"(p_sirket bigint, p_oyuncu text, p_tutar numeric, p_aciklama text) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_pos_talep"(p_sirket bigint, p_oyuncu text, p_tutar numeric, p_aciklama text) TO authenticated;

CREATE OR REPLACE FUNCTION public.kart_pos_yanit(p_pos bigint, p_kart bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t oyun.kart_pos_talepleri; res jsonb;
begin
 select * into t from oyun.kart_pos_talepleri
 where id=p_pos and musteri=auth.uid() and durum='bekliyor' for update;
 if not found then raise exception 'Bekleyen POS talebin bulunamadi';end if;
 if p_kart is null then
   update oyun.kart_pos_talepleri set durum='reddedildi' where id=t.id;
   return jsonb_build_object('durum','reddedildi');
 end if;
 -- Alici sadece kendi kartiyla banka destekli odemeyi yapar; POS tekrar kullanilamaz.
 res:=oyun.kart_harca(p_kart,t.tutar,null,t.sirket_id,'POS # '||t.id||' - '||t.aciklama);
 update oyun.kart_pos_talepleri set durum='odendi',odendi=oyun.simdi(),kart_id=p_kart where id=t.id;
 insert into oyun.bildirimler(user_id,metin)
 values(t.talep_eden,format('💳 POS #%s kart ile odendi. %s TL sirket kasasina gecti.',t.id,t.tutar));
 return res || jsonb_build_object('pos',t.id);
end $function$;

REVOKE ALL ON FUNCTION public."kart_pos_yanit"(p_pos bigint, p_kart bigint) FROM public,anon,authenticated;

GRANT EXECUTE ON FUNCTION public."kart_pos_yanit"(p_pos bigint, p_kart bigint) TO authenticated;

-- pg_cron was configured in live DB as job #39:

-- SELECT cron.schedule('oyun-kredi-karti-donem-kontrol','5 * * * *','select oyun.kart_donem_isle(null);');
