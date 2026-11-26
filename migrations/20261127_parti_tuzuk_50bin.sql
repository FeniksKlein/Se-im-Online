-- 2026-11-27: Parti tüzüğü metin sınırı 12.000 → 50.000 karakter.
-- Ön koşul: bölücü içerik süzgecindeki '(.)\1+' (geri başvurulu) düzenli ifadesi uzun metinlerde
-- karesel yavaşlıyordu (12.000 karakterde ~7 sn, 50.000 karakterde ~100 sn). Aynı sonucu veren,
-- doğrusal çalışan oyun.tekrar_tekle() ile değiştirildi. Süzgecin yakaladığı/yakalamadığı içerik değişmedi.
-- Ek: oyun.kufurlu() metni her küfür kelimesi için yeniden sadeleştiriyordu (18 kez); artık bir kez.
-- Sonuç: 50.000 karakterlik tüzük ~0,4 sn'de denetlenir (önce ~100 sn); kısa sohbet mesajları da hızlandı.
-- Canlı veritabanına uygulandı (Supabase migration: tekrar_tekle_yardimci, parti_tuzuk_50bin, kufurlu_tek_sade).

-- Art arda tekrar eden aynı karakterleri teke indirir ("kuuurdiiistan" → "kurdistan").
-- Girdi süzgeçte yalnız [a-z0-9] içerir; diğer karakterlere dokunmaz.
CREATE OR REPLACE FUNCTION oyun.tekrar_tekle(s text)
 RETURNS text LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE SET search_path TO ''
AS $function$
declare c text;
begin
  foreach c in array regexp_split_to_array('abcdefghijklmnopqrstuvwxyz0123456789', '') loop
    if strpos(s, c || c) > 0 then
      s := regexp_replace(s, c || '{2,}', c, 'g');
    end if;
  end loop;
  return s;
end $function$;
revoke all on function oyun.tekrar_tekle(text) from public, anon, authenticated;

CREATE OR REPLACE FUNCTION oyun.bolucu_eslesen2(t text)
 RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$
  with s as (select oyun.sade_siki(t) sd,
                    regexp_split_to_array(btrim(regexp_replace(oyun.katla(t), '[^a-z0-9]+', ' ', 'g')), ' ') tk),
       g as (select sd, tk, translate(sd, '013457', 'oieast') lt from s),
       h as (select sd, tk, lt, oyun.tekrar_tekle(lt) tek from g)
  select coalesce(
    (select y from h, unnest(array[
      'kurdistan','pkk','pjak','qandil','kongragel','berxwedanjiyane','sehidnamirin','gerilla',
      'rojava','rojhilat','ozyonetim',
      'fetullah','fethullah','gulenist','bylock',
      'dhkpc','mlkp','tikko','devrimcikarargah','maoistkomunist',
      'elkaide','hilafetgelsin','hizbullah','ibdac','siegheil',
      'serokapo','bijiserok','apoyaozgurluk',
      'kahrolsunturkiye','kahrolsunlaik','kahrolsuncumhuriyet','seriatgelecek','seriatgelsin'
    ]) y
      where h.sd like '%' || y || '%' or h.lt like '%' || y || '%'
         or (char_length(oyun.tekrar_tekle(y)) >= 7 and h.tek like '%' || oyun.tekrar_tekle(y) || '%')
      limit 1),
    (select k from h, unnest(h.tk) k
      where k = any (array['apo','biji','kck','ypg','ypj','yja','pyd','hpg','feto',
                           'isid','deas','daes','dais','nazi','1488','bakur','gerila'])
         or translate(k, '013457', 'oieast') = any (array['apo','biji','feto','isid','nazi','bakur'])
         or k ~ '^(ocalan|hitler)' limit 1))
$function$;

CREATE OR REPLACE FUNCTION public.parti_tuzuk_teklif(p_baslik text, p_metin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'oyun', 'public', 'pg_temp'
AS $function$
declare
  p oyun.profiller:=oyun.profilim();
  t timestamptz:=oyun.simdi();
  pa oyun.partiler;
  b text;
  m text;
begin
  perform oyun.parti_tuzuk_tick(t);
  select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
  if pa.id is null or pa.gb is distinct from p.id then
    raise exception 'Tüzük teklifini yalnızca genel başkan üyelerin oyuna sunabilir.';
  end if;
  if exists(select 1 from oyun.parti_tuzuk_teklifleri where parti_id=pa.id and durum='oylama') then
    raise exception 'Partide zaten devam eden bir tüzük oylaması var.';
  end if;

  b:=btrim(coalesce(p_baslik,''));
  if length(b)<5 or length(b)>100 then raise exception 'Tüzük başlığı 5-100 karakter olmalı.'; end if;
  if oyun.kufurlu(b) then raise exception 'Başlıkta uygunsuz ifade var.'; end if;

  m:=oyun.metin_temizle(p_metin,50000);
  if length(m)<50 then raise exception 'Parti tüzüğü en az 50 karakter olmalı.'; end if;

  insert into oyun.parti_tuzuk_teklifleri(parti_id,baslik,metin,teklif_eden,bas,bit)
  values(pa.id,b,m,p.id,t,t+interval '24 hours');

  insert into oyun.bildirimler(user_id,zaman,metin)
  select id,t,format('%s Genel Başkanı yeni parti tüzüğünü oylamaya sundu. Oylama 24 saat açık.',pa.kisa)
  from oyun.profiller where parti_id=pa.id and id<>p.id and parti_at<=t;

  perform oyun.olay('parti',format('%s yeni tüzük teklifini üyelerin oyuna sundu.',pa.kisa),null,pa.id,t);
  return public.parti_tuzuk(pa.id);
end $function$;

CREATE OR REPLACE FUNCTION oyun.kufurlu(t text)
 RETURNS boolean LANGUAGE sql IMMUTABLE
 SET search_path TO 'oyun', 'public', 'extensions', 'pg_temp'
AS $function$
  select oyun.bolucu(t) or exists (select 1 from (select oyun.sade(t) sd) q, unnest(array[
    'orospu','yarrak','pezevenk','kahpe','amcik','surtuk','serefsiz','yavsak','ibne','gavat','siktir',
    'aminakoy','sikerim','sikeyim','pust','kaltak','dalyarak','gerizekali'
  ]) y where q.sd like '%' || y || '%')
$function$;
