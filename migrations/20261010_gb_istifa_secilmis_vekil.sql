-- Genel başkan istifasında seçilmiş vekil genel başkan ve kurultay devri.
-- Oyuncu, bakiye, parti, seçim, mülk veya makam kayıtları sıfırlanmaz.
begin;
alter table oyun.partiler add column if not exists gb_vekil uuid references oyun.profiller(id);
alter table oyun.partiler add column if not exists gb_vekil_bas timestamptz;

-- Uygun GBy varsa yalnızca GBY'ler, hiç uygun GBY yoksa diğer üyeler.
create or replace function oyun.gb_vekil_adaylari(p_parti bigint, p_haric uuid)
returns table(user_id uuid, kad text, kaynak text, sira smallint)
language sql stable set search_path='' as $aday$
with uygun as (
  select pr.id as user_id, pr.kad, g.sira
  from oyun.profiller pr
  left join oyun.parti_gby g on g.parti_id=pr.parti_id and g.user_id=pr.id
  where pr.parti_id=p_parti and not coalesce(pr.yasakli,false)
    and (p_haric is null or pr.id<>p_haric)
    and not exists(
      select 1 from unnest(oyun.roller(pr.id)) r
      where r<>'gby' and not oyun.rol_uyumlu(r,'gb')
    )
)
select u.user_id,u.kad,
       (case when u.sira is not null then 'gby' else 'uye' end)::text as kaynak,
       u.sira
from uygun u
where u.sira is not null or not exists(select 1 from uygun where sira is not null)
order by u.sira nulls last,u.kad,u.user_id
$aday$;
revoke all on function oyun.gb_vekil_adaylari(bigint,uuid) from public,anon,authenticated;

-- Seçilen kişiye vekâlet devri; oyuncunun başka makamları/parti geçmişi korunur.
create or replace function oyun.gb_vekil_otomatik(p_parti bigint, p_haric uuid, p_zaman timestamptz)
returns uuid language plpgsql security definer set search_path='' as $otomatik$
declare pa oyun.partiler; h record;
begin
 select * into pa from oyun.partiler where id=p_parti and not kapali for update;
 if pa.id is null or pa.gb is not null then return null; end if;
 select * into h from oyun.gb_vekil_adaylari(pa.id,p_haric) limit 1;
 if h.user_id is null then return null; end if;
 delete from oyun.parti_gby where parti_id=pa.id and user_id=h.user_id;
 update oyun.partiler set gb=h.user_id,gb_vekil=h.user_id,gb_vekil_bas=p_zaman where id=pa.id and gb is null;
 if not found then return null; end if;
 perform oyun.bildir(h.user_id,format('%s partisinde yeni genel başkan seçilene kadar VEKÂLETEN genel başkan oldun.',pa.ad),p_zaman);
 perform oyun.olay('parti',format('%s: %s kurultaya kadar vekâleten genel başkan oldu.',pa.ad,h.kad),null,pa.id,p_zaman);
 return h.user_id;
end $otomatik$;
revoke all on function oyun.gb_vekil_otomatik(bigint,uuid,timestamptz) from public,anon,authenticated;

-- Başka göreve seçilme, üyelikten ayrılma veya ihmal gibi seçim dışı düşmelerde otomatik geçiş.
create or replace function oyun.gb_degisimi_koru_tg()
returns trigger language plpgsql set search_path='' as $degisim$
begin
 if new.gb is distinct from old.gb and new.gb is distinct from new.gb_vekil then
   new.gb_vekil:=null;
   new.gb_vekil_bas:=null;
 end if;
 return new;
end $degisim$;
drop trigger if exists gb_degisimi_koru on oyun.partiler;
create trigger gb_degisimi_koru before update of gb on oyun.partiler
for each row execute function oyun.gb_degisimi_koru_tg();

create or replace function oyun.gb_bosalma_vekil_tg()
returns trigger language plpgsql set search_path='' as $bosalma$
begin
 if old.gb is not null and new.gb is null and not new.kapali then
   perform oyun.gb_vekil_otomatik(new.id,old.gb,oyun.simdi());
   perform oyun.ara_secim_olustur('gb',new.id,null,oyun.simdi());
 end if;
 return null;
end $bosalma$;
drop trigger if exists gb_bosalma_vekil on oyun.partiler;
create trigger gb_bosalma_vekil after update of gb on oyun.partiler
for each row when (old.gb is not null and new.gb is null)
execute function oyun.gb_bosalma_vekil_tg();

-- Olağan veya olağanüstü kurultayda bir kişi seçilip göreve başladığında vekâlet biter.
create or replace function oyun.gb_kurultay_vekalet_bitir_tg()
returns trigger language plpgsql set search_path='' as $bitir$
begin
 if old.durum='sonuclandi' and new.durum='tamam' and new.tur='kurultay' then
   update oyun.partiler pa
   set gb_vekil=null,gb_vekil_bas=null
   where pa.gb_vekil is not null and exists (
     select 1 from oyun.kazananlar k
     join oyun.profiller pr on pr.id=k.user_id and pr.parti_id=k.parti_id
     where k.secim_id=new.id and k.parti_id=pa.id and k.user_id=pa.gb
   );
 end if;
 return null;
end $bitir$;
drop trigger if exists gb_kurultay_vekalet_bitir on oyun.secimler;
create trigger gb_kurultay_vekalet_bitir after update of durum on oyun.secimler
for each row when (old.durum='sonuclandi' and new.durum='tamam' and new.tur='kurultay')
execute function oyun.gb_kurultay_vekalet_bitir_tg();

-- Kurultayda kimse seçilemediğinde de yardımcı/üyeden vekil gelir (kalıcı atama yapılmaz).
create or replace function oyun.gb_halef(t timestamptz)
returns void language plpgsql set search_path='' as $halef$
declare pa record;
begin
 for pa in select id from oyun.partiler where not kapali and gb is null loop
   perform oyun.gb_vekil_otomatik(pa.id,null,t);
 end loop;
end $halef$;
revoke all on function oyun.gb_halef(timestamptz) from public,anon,authenticated;

-- İstifa ekranındaki adaylar: sadece görevdeki genel başkan görür.
create or replace function public.gb_istifa_adaylar()
returns jsonb language plpgsql security definer set search_path='' as $liste$
declare u uuid:=auth.uid(); pa oyun.partiler;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into pa from oyun.partiler where gb=u and not kapali;
 if pa.id is null then raise exception 'Yalnızca görevdeki genel başkan vekil belirleyebilir.'; end if;
 return jsonb_build_object(
   'parti_id',pa.id,'parti',pa.ad,
   'adaylar',coalesce((
     select jsonb_agg(jsonb_build_object('id',a.user_id,'kad',a.kad,
                'kaynak',a.kaynak,'sira',a.sira)
                order by a.sira nulls last,a.kad,a.user_id)
     from oyun.gb_vekil_adaylari(pa.id,u) a
   ),'[]'::jsonb)
 );
end $liste$;
revoke all on function public.gb_istifa_adaylar() from public,anon,authenticated;
grant execute on function public.gb_istifa_adaylar() to authenticated;

-- İstifa ve vekâlet tek atomik işlem: başkan kimin geçeceğini kendi belirler.
create or replace function public.gb_istifa_vekil_sec(p_vekil uuid)
returns jsonb language plpgsql security definer set search_path='' as $istifa$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi(); pa oyun.partiler; h record; sec jsonb;
begin
 if u is null then raise exception 'Oturum açmalısın.'; end if;
 select * into pa from oyun.partiler where gb=u and not kapali for update;
 if pa.id is null then raise exception 'Genel başkan değilsin.'; end if;
 if p_vekil is not null then
   select * into h from oyun.gb_vekil_adaylari(pa.id,u) a where a.user_id=p_vekil;
   if h.user_id is null then raise exception 'Bu kişi vekâlet için uygun değil. Yardımcıların varsa birini seçmelisin.'; end if;
   delete from oyun.parti_gby where parti_id=pa.id and user_id=h.user_id;
   update oyun.partiler set gb=h.user_id,gb_vekil=h.user_id,gb_vekil_bas=t where id=pa.id and gb=u;
   if not found then raise exception 'Genel başkanlık bu sırada değişmiş; yeniden dene.'; end if;
 else
   if exists (select 1 from oyun.gb_vekil_adaylari(pa.id,u)) then
     raise exception 'Kurultaya kadar görev yapacak vekil genel başkanı seçmelisin.';
   end if;
   -- Partide başka uygun oyuncu yoksa genel başkanlık boşalır, kurultay açılır.
   update oyun.partiler set gb=null,gb_vekil=null,gb_vekil_bas=null where id=pa.id and gb=u;
 end if;

 sec:=oyun.ara_secim_olustur('gb',pa.id,null,t);
 perform oyun.bildir(u,
   format('%s Genel Başkanlığından istifa ettin. %s. Kurultay takvimi açıldı.',
     pa.ad,case when h.user_id is not null then 'Seçtiğin vekil: '||h.kad else 'Partide uygun vekil bulunamadı' end),t);
 if h.user_id is not null then
   perform oyun.bildir(h.user_id,format('%s partisinin kurultaya kadar VEKÂLETEN genel başkanı olarak seçildin. Tüm genel başkan yetkileri sende.',pa.ad),t);
 end if;
 insert into oyun.bildirimler(user_id,zaman,metin)
 select pr.id,t,format('%s Genel Başkanı %s istifa etti. %s Olağanüstü kurultay açıldı.',
   pa.ad,oyun.kad(u),
   case when h.user_id is not null then h.kad||' vekâleten genel başkan oldu.' else 'Henüz vekil başkan bulunmuyor.' end)
 from oyun.profiller pr where pr.parti_id=pa.id and pr.id<>u and (h.user_id is null or pr.id<>h.user_id);
 perform oyun.olay('parti',format('%s Genel Başkanı %s istifa etti. %s Kurultay takvimi açıldı.',
   pa.ad,oyun.kad(u),
   case when h.user_id is not null then h.kad||' vekâleten göreve başladı.' else 'Vekâlet boş kaldı.' end),null,pa.id,t);
 return public.durum();
end $istifa$;
revoke all on function public.gb_istifa_vekil_sec(uuid) from public,anon,authenticated;
grant execute on function public.gb_istifa_vekil_sec(uuid) to authenticated;

-- Eski istemciler de vekil seçimini atlayamaz; diğer istifa işlemleri değişmez.
CREATE OR REPLACE FUNCTION public.istifa(p_gorev text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller := oyun.profilim();
  t timestamptz := oyun.simdi();
  m oyun.makamlar;
  cb uuid;
  pa oyun.partiler;
  sec jsonb;
begin
  if p_gorev = 'bakan' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'bakan' and bit is null;

    if m.id is null then raise exception 'Bakan değilsin.'; end if;

    perform oyun.makam_bitir(m.id,t,'istifa');

    select user_id into cb
    from oyun.makamlar
    where tur = 'cb' and bit is null
    limit 1;

    if cb is not null then
      perform oyun.bildir(
        cb,
        format(
          '%s, %s görevinden istifa etti.',
          p.kad,
          oyun.makam_ad('bakan',null,m.bakanlik)
        ),
        t
      );
    end if;

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti.',
        p.kad,
        oyun.makam_ad('bakan',null,m.bakanlik)
      ),
      null, p.parti_id, t
    );

  elsif p_gorev = 'mv' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'mv' and bit is null;

    if m.id is null then raise exception 'Milletvekili değilsin.'; end if;

    perform oyun.makam_bitir(m.id,t,'istifa');

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti.',
        p.kad,
        oyun.makam_ad(m.tur,m.il_id,null)
      ),
      m.il_id, p.parti_id, t
    );

  elsif p_gorev = 'bel' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'bel' and bit is null
    for update;

    if m.id is null then
      raise exception 'Belediye başkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    sec := oyun.ara_secim_olustur('bel',null,m.il_id,t);

    perform oyun.olay(
      'makam',
      format(
        '%s, %s görevinden istifa etti. Yeni başkan en yakın seçimde belirlenecek.',
        p.kad,
        oyun.makam_ad(m.tur,m.il_id,null)
      ),
      m.il_id, p.parti_id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      id,
      t,
      format(
        '%s Belediye Başkanı istifa etti. Yeni başkan için seçim takvimi oluşturuldu.',
        (select ad from oyun.iller where id = m.il_id)
      )
    from oyun.profiller
    where il_id = m.il_id and id <> p.id;

  elsif p_gorev = 'cb' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'cb' and bit is null
    for update;

    if m.id is null then
      raise exception 'Cumhurbaşkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    sec := oyun.ara_secim_olustur('cb',null,null,t);

    perform oyun.olay(
      'makam',
      format(
        '%s Cumhurbaşkanlığı görevinden istifa etti. Olağanüstü seçim takvimi oluşturuldu.',
        p.kad
      ),
      null, p.parti_id, t
    );

    insert into oyun.bildirimler(user_id,zaman,metin)
    select
      pa2.gb,
      t,
      'Cumhurbaşkanı istifa etti. Olağanüstü seçim için aday belirleme süreci başladı.'
    from oyun.partiler pa2
    where pa2.gb is not null
      and not pa2.kapali
      and pa2.gb <> p.id;

  elsif p_gorev = 'gb' then
    raise exception 'Genel başkanlığı bırakmadan önce parti ekranından vekil genel başkanı seçmelisin.';

  elsif p_gorev = 'tbmm' then
    select * into m
    from oyun.makamlar
    where user_id = p.id and tur = 'tbmm' and bit is null
    for update;

    if m.id is null then
      raise exception 'TBMM Başkanı değilsin.';
    end if;

    perform oyun.makam_bitir(m.id,t,'istifa');
    perform oyun.tbmm_ara_secim(t);

    perform oyun.olay(
      'meclis',
      format(
        '%s TBMM Başkanlığı görevinden istifa etti. Ara seçim süreci başladı.',
        p.kad
      ),
      null, p.parti_id, t
    );

  elsif p_gorev = 'gby' then
    delete from oyun.parti_gby where user_id = p.id;

    if not found then
      raise exception 'Genel başkan yardımcısı değilsin.';
    end if;

    perform oyun.bildir(
      (select gb from oyun.partiler where id = p.parti_id),
      format(
        '%s genel başkan yardımcılığından istifa etti.',
        p.kad
      ),
      t
    );

  else
    raise exception 'Geçersiz görev.';
  end if;

  return public.durum();
end $function$;


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
end $function$;


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
$function$;


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
end $function$;

commit;
