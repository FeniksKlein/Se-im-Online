begin;
-- Genel başkanlık boşaldığında en düşük sıra numarasına sahip uygun yardımcısı vekâlet eder.
-- Eski hesap, parti, adaylık, oy, malvarlığı veya makam kayıtları sıfırlanmaz.
alter table oyun.partiler add column if not exists gb_vekil uuid references oyun.profiller(id);
alter table oyun.partiler add column if not exists gb_vekil_bas timestamptz;

create or replace function oyun.gb_vekil_atama(p_parti bigint, p_zaman timestamptz)
returns uuid language plpgsql security definer set search_path='' as $gb$
declare pa oyun.partiler; aday uuid;
begin
 select * into pa from oyun.partiler where id=p_parti for update;
 if pa.id is null or pa.kapali then return null; end if;
 if pa.gb is not null then return pa.gb; end if;
 select g.user_id into aday
 from oyun.parti_gby g
 join oyun.profiller pr on pr.id=g.user_id and pr.parti_id=g.parti_id
 where g.parti_id=pa.id and not pr.yasakli
   and not exists(
     select 1 from unnest(oyun.roller(g.user_id)) r
     where r<>'gby' and not oyun.rol_uyumlu(r,'gb'))
 order by g.sira,g.atama,g.user_id limit 1;
 if aday is null then return null; end if;

 -- Vekil genel başkan aynı zamanda GBY kontenjanında tutulmaz.
 delete from oyun.parti_gby where parti_id=pa.id and user_id=aday;
 update oyun.partiler
 set gb=aday,gb_vekil=aday,gb_vekil_bas=p_zaman
 where id=pa.id and gb is null;
 if not found then return null; end if;

 perform oyun.bildir(aday,format('%s partisinin kurultaya kadar VEKÂLETEN GENEL BAŞKANI oldun. Parti yönetimi yetkileri sende; genel başkan seçimle belirlenecek.',pa.ad),p_zaman);
 insert into oyun.bildirimler(user_id,zaman,metin)
 select pr.id,p_zaman,format('%s: %s, olağanüstü kurultaya kadar vekâleten genel başkan oldu.',pa.ad,oyun.kad(aday))
 from oyun.profiller pr where pr.parti_id=pa.id and pr.id<>aday;
 perform oyun.olay('parti',format('%s: %s vekâleten genel başkan oldu. Kurultayda yeni başkan seçilecek.',pa.ad,oyun.kad(aday)),null,pa.id,p_zaman);
 return aday;
end $gb$;
revoke all on function oyun.gb_vekil_atama(bigint,timestamptz) from public,anon,authenticated;

create or replace function oyun.gb_vekil_bosalma_tg()
returns trigger language plpgsql security definer set search_path='' as $gb$
begin
 if old.gb is not null and new.gb is null and not new.kapali then
   perform oyun.gb_vekil_atama(new.id,oyun.simdi());
   -- Olağan bir kurultay daha erken değilse olağanüstü kurultay açılır.
   perform oyun.ara_secim_olustur('gb',new.id,null,oyun.simdi());
 elsif old.gb_vekil is not null and new.gb is not null
       and new.gb is distinct from old.gb_vekil then
   update oyun.partiler set gb_vekil=null,gb_vekil_bas=null
    where id=new.id and gb_vekil is not null;
 end if;
 return null;
end $gb$;
revoke all on function oyun.gb_vekil_bosalma_tg() from public,anon,authenticated;
drop trigger if exists parti_gb_vekil_bosalma on oyun.partiler;
create trigger parti_gb_vekil_bosalma
after update of gb on oyun.partiler
for each row when (old.gb is distinct from new.gb)
execute function oyun.gb_vekil_bosalma_tg();

-- Aynı vekil genel başkan kurultayı kazansa dahi vekâlet kaydı seçimin
-- resmî göreve başlama anında sona erer. Aday çıkmadıysa vekâlet devam eder.
create or replace function oyun.gb_vekil_kurultay_tg()
returns trigger language plpgsql security definer set search_path='' as $gb$
begin
 if old.durum='sonuclandi' and new.durum='tamam' and new.tur='kurultay' then
   update oyun.partiler pa set gb_vekil=null,gb_vekil_bas=null
   where pa.gb_vekil is not null
     and exists(
       select 1 from oyun.kazananlar k
       join oyun.profiller pr on pr.id=k.user_id and pr.parti_id=k.parti_id
       where k.secim_id=new.id and k.parti_id=pa.id and k.user_id=pa.gb
     );
 end if;
 return null;
end $gb$;
revoke all on function oyun.gb_vekil_kurultay_tg() from public,anon,authenticated;
drop trigger if exists parti_gb_vekil_kurultay on oyun.secimler;
create trigger parti_gb_vekil_kurultay after update of durum on oyun.secimler
for each row when (old.durum='sonuclandi' and new.durum='tamam' and new.tur='kurultay')
execute function oyun.gb_vekil_kurultay_tg();

-- Eski otomatik haleflik yerine yalnız uygun genel başkan yardımcıları
-- seçilir; sıradan bir üye kurultaysız kesin genel başkan yapılmaz.
create or replace function oyun.gb_halef(t timestamptz)
returns void language plpgsql set search_path='' as $gb$
declare pa record;
begin
 for pa in select id from oyun.partiler where not kapali and gb is null loop
   if oyun.gb_vekil_atama(pa.id,t) is not null then
     perform oyun.ara_secim_olustur('gb',pa.id,null,t);
   end if;
 end loop;
end $gb$;

CREATE OR REPLACE FUNCTION public.durum()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  u uuid := auth.uid();
  p oyun.profiller;
  t timestamptz := oyun.simdi();
  pa oyun.partiler;
  gun int := oyun.il_bekleme_gun(oyun.simdi());
begin
  if u is null then raise exception 'Giriş yapmalısın.'; end if;
  select * into p from oyun.profiller where id = u;

  if p.id is null then
    return jsonb_build_object('simdi',t,'profil',null, 'kayit_durumu', (select b.durum from oyun_yonetim.kayit_basvurulari b where b.user_id=u), 'kayit_basvuru_at', (select b.basvuru_at from oyun_yonetim.kayit_basvurulari b where b.user_id=u));
  end if;

  if p.yasakli then
    raise exception 'Hesabın kural ihlali nedeniyle kapatıldı. İtiraz için oyun yönetimine e-posta gönderebilirsin.';
  end if;

  if p.son_gorulme is null or p.son_gorulme < t - interval '5 minutes' then
    update oyun.profiller
    set son_gorulme = t
    where id = p.id;
  end if;

  select * into pa
  from oyun.partiler
  where id = p.parti_id;

  return jsonb_build_object(
    'simdi', t,

    'profil', jsonb_build_object(
      'id', p.id,
      'kad', p.kad,
      'il_id', p.il_id,
      'il_ad', (select ad from oyun.iller where id = p.il_id),
      'olusturma', p.olusturma,
      'parti', oyun.parti_json(p.parti_id),
      'parti_at', p.parti_at,
      'gb', pa.gb = p.id,'gb_vekaleten',pa.gb_vekil = p.id,
      'gby', exists(
        select 1 from oyun.parti_gby g where g.user_id = p.id
      ),
      'il_kilit', oyun.il_kilit_nedeni(t),
      'il_serbest', case
        when p.son_il_degis is null then null
        else p.son_il_degis + make_interval(days => gun)
      end,
      'makamlar', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'tur',m.tur,
            'il_id',m.il_id,
            'il_ad',i.ad,
            'bas',m.bas,
            'kaynak',m.kaynak,
            'bakanlik',m.bakanlik,
            'bakanlik_ad',(
              select ad from oyun.bakanliklar b where b.kod = m.bakanlik
            )
          )
        )
        from oyun.makamlar m
        left join oyun.iller i on i.id = m.il_id
        where m.user_id = p.id and m.bit is null
      ), '[]'::jsonb),
      'hesap_engeli', oyun.uyari(p,t),
      'cb_mi', exists(
        select 1 from oyun.makamlar m
        where m.user_id = p.id
          and m.tur = 'cb'
          and m.bit is null
      ),
      'yonetici', p.yonetici,
      'bildirim_ayar', p.bildirim_ayar,
      'yetkiler', oyun.yetkilerim(p.id),
      'kredi_uyari', oyun.kredi_uyari(p.id),
      'cuzdan', oyun.cuzdan_ozet(p.id,t)
    ),

    'okunmamis', oyun.okunmamis(p),

    'takvim', coalesce((
      select jsonb_agg(
        oyun.secim_ozet(s,p,t)
        order by coalesce(s.basvuru_bas,s.oy_bas), oyun.oncelik(s.tur)
      )
      from oyun.secimler s
      where coalesce(s.goreve_bas,s.sonuc_at) >= t - interval '3 days'
        and coalesce(s.basvuru_bas,s.oy_bas) <= t + interval '40 days'
        and (
          not s.ara
          or s.tur in ('cb','cb_on','cb2')
          or s.hedef_il_id = p.il_id
          or s.hedef_parti_id = p.parti_id
        )
    ), '[]'::jsonb),

    'cb', (
      select jsonb_build_object(
        'kad', oyun.kad(m.user_id),
        'parti', oyun.parti_json(m.parti_id),
        'bas', m.bas
      )
      from oyun.makamlar m
      where m.tur = 'cb' and m.bit is null
      limit 1
    ),

    'cb_karar', case
      when pa.gb = p.id then (
        select jsonb_build_object(
          'secim_id',s.id,
          'donem',s.donem,
          'acik',t >= s.basvuru_bas and t < s.basvuru_bit,
          'yontem',k.yontem,
          'aday',oyun.kad(k.aday),
          'son',s.basvuru_bit,
          'destek',(select kisa from oyun.partiler where id = k.destek_parti),
          'ara',s.ara
        )
        from oyun.secimler s
        left join oyun.cb_kararlar k
          on k.donem = s.donem
         and k.parti_id = pa.id
        where s.tur = 'cb'
          and s.durum = 'bekliyor'
        order by s.ara desc, s.oy_bas
        limit 1
      )
    end
  );
end $function$


CREATE OR REPLACE FUNCTION public.parti_detay(p_parti bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  pa oyun.partiler;
begin
  select * into pa from oyun.partiler where id=p_parti;
  if pa.id is null then raise exception 'Parti bulunamadı.'; end if;

  return oyun.parti_json(pa.id)||jsonb_build_object(
    'kapali',pa.kapali,'sistem',pa.sistem,'kurulus',pa.kurulus,'kurucu',oyun.kad(pa.kurucu),
    'kurulus_bit',pa.kurulus_bit,
    'kurucu_gecerli',case when pa.kurulus_bit is not null then oyun.kurucu_say(pa.id,oyun.simdi()) end,
    'kurucu_gerekli',case when pa.kurulus_bit is not null then (select parti_kurucu_sayi from oyun.ayarlar where id=1) end,
    'kurucu_engelim',case when pa.kurulus_bit is not null and p.parti_id=pa.id then oyun.uyari(p,oyun.simdi()) end,
    'gb',oyun.kad(pa.gb),'gb_vekaleten',pa.gb_vekil is not null,'gb_vekil_bas',pa.gb_vekil_bas,
    'gby',coalesce((
      select jsonb_agg(jsonb_build_object('sira',g.sira,'kad',oyun.kad(g.user_id)) order by g.sira)
      from oyun.parti_gby g where g.parti_id=pa.id
    ),'[]'::jsonb),
    'uye',(select count(*) from oyun.profiller where parti_id=pa.id),
    'uyeler',coalesce((
      select jsonb_agg(jsonb_build_object(
        'kad',pr.kad,'il',i.ad,
        'makam',(select string_agg(m.tur,',') from oyun.makamlar m where m.user_id=pr.id and m.bit is null),
        'il_baskani',exists(select 1 from oyun.parti_teskilat_gorev g where g.parti_id=pa.id and g.user_id=pr.id and g.aktif)
      ) order by (pr.id=pa.gb) desc,exists(select 1 from oyun.parti_gby g where g.user_id=pr.id) desc,pr.parti_at)
      from (
        select * from oyun.profiller where parti_id=pa.id order by parti_at limit 300
      ) pr
      join oyun.iller i on i.id=pr.il_id
    ),'[]'::jsonb),
    'vekil',(select count(*) from oyun.makamlar m where m.tur='mv' and m.bit is null and m.parti_id=pa.id),
    'belediye',(select count(*) from oyun.makamlar m where m.tur='bel' and m.bit is null and m.parti_id=pa.id),
    'teskilat',(select count(*) from oyun.parti_teskilat t where t.parti_id=pa.id),
    'uyesiyim',p.parti_id=pa.id,
    'tuzuk',pa.tuzuk,
    'tuzuk_at',pa.tuzuk_at,
    'son_ad_degis',pa.son_ad_degis
  );
end $function$


CREATE OR REPLACE FUNCTION public.partiler()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
  select coalesce(jsonb_agg(oyun.parti_json(pa.id) || jsonb_build_object(
    'uye',(select count(*) from oyun.profiller where parti_id=pa.id),
    'gb',oyun.kad(pa.gb),'gb_vekaleten',pa.gb_vekil is not null,'sistem',pa.sistem,'kurulus_bit',pa.kurulus_bit,
    'vekil',(select count(*) from oyun.makamlar m where m.tur='mv' and m.bit is null and m.parti_id=pa.id),
    'belediye',(select count(*) from oyun.makamlar m where m.tur='bel' and m.bit is null and m.parti_id=pa.id),
    'test_baraj_kapali',coalesce((select her_aday_vekil from oyun.mv_secim_modu where id=1),false),
    'ittifak',(select jsonb_build_object('id',i.id,'ad',i.ad,
      'uyeler',coalesce((select jsonb_agg(jsonb_build_object(
        'id',p2.id,'ad',p2.ad,'kisa',p2.kisa,'renk',p2.renk) order by p2.kisa,p2.id)
        from oyun.ittifak_uyeler u2 join oyun.partiler p2 on p2.id=u2.parti_id
        where u2.ittifak_id=i.id and not p2.kapali),'[]'::jsonb))
      from oyun.ittifak_uyeler u join oyun.ittifaklar i on i.id=u.ittifak_id
      where u.parti_id=pa.id)
  ) order by (select count(*) from oyun.profiller where parti_id=pa.id) desc,pa.id),'[]'::jsonb)
  from oyun.partiler pa where not pa.kapali
$function$


commit;
