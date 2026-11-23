-- 23.11.2026 · Bağış kıdemi bildirimi
-- İstek (Ercan): oyuncular "bir asgari ücret tutarındaki her bağış +1 kıdem" cümlesini "3 asgari ücret = 3 kıdem"
-- diye anladı. Kural değişmedi (parti, şehir ve hazine bağışlarından günde en çok +1 kıdem); bağış yapan oyuncuya
-- kazandığı kıdem ve günlük sınır anında bildirilir. Mağaza güncellemesi gerektirmez (bildirim sunucudan gider).
--   · Kıdem kazandıysa: "+0,93 kıdem (bugün 0,93 / 1)" — her bağışta.
--   · Günlük +1 dolduktan sonraki bağışta: "bu bağış kıdem getirmedi" — günde yalnız bir kez (akilli_bildir).
-- Bildirim hatası bağışı hiçbir koşulda engellemez (exception bloğu).
create or replace function oyun.bagis_kidem_bildir(u uuid, p_once numeric, p_tutar numeric, p_asgari numeric, t timestamptz)
returns void language plpgsql set search_path to '' as $f$
declare a numeric := greatest(1, coalesce(p_asgari, 1));
        b numeric := greatest(0, coalesce(p_once, 0));
        once numeric := least(1, b / a);
        sonra numeric := least(1, (b + greatest(0, coalesce(p_tutar, 0))) / a);
        kazanc numeric := greatest(0, sonra - once);
        ks text; ss text;
begin
  if u is null then return; end if;
  if kazanc >= 0.005 then
    ks := rtrim(rtrim(replace(to_char(round(kazanc, 2), 'FM990.00'), '.', ','), '0'), ',');
    ss := rtrim(rtrim(replace(to_char(round(sonra, 2), 'FM990.00'), '.', ','), '0'), ',');
    if sonra >= 1 then
      perform oyun.bildir(u, format('Bağışınla +%s kıdem puanı kazandın. Bugünkü bağış kıdemi tamamlandı (1 / 1): bağıştan günde en çok +1 kıdem gelir, bugün yapacağın yeni bağışlar kıdem getirmez. Sayaç gece yarısı sıfırlanır.', ks), t);
    else
      perform oyun.bildir(u, format('Bağışınla +%s kıdem puanı kazandın (bugün %s / 1). Bağıştan günde en çok +1 kıdem gelir; bugün %s ₺ daha bağışlarsan tamamlanır. Küsuratlı puan birikir, tam sayıya ulaşınca statünde görünür.',
        ks, ss, oyun.tl(ceil((1 - sonra) * a))), t);
    end if;
  elsif once >= 1 then
    perform oyun.akilli_bildir(u, 'bagis_kidem_tavan_' || to_char(t at time zone 'Europe/Istanbul', 'YYYYMMDD'),
      'Bu bağış kıdem puanı getirmedi: bağıştan günde en çok +1 kıdem gelir ve bugünkü puanını zaten aldın. Sayaç gece yarısı sıfırlanır. Bağışın hedefine ulaştı.');
  end if;
exception when others then
  return;
end $f$;
revoke all on function oyun.bagis_kidem_bildir(uuid, numeric, numeric, numeric, timestamptz) from public;

-- serbest_bagis: kıdem güncellemesinden hemen sonra bildirimi çağır (parti · şehir · hazine bağışları).
select oyun._yama('public.serbest_bagis(text,text,numeric,text)',
                  $d$bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;$d$,
                  $d$bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;
   /* bagis_kidem_bildir */ perform oyun.bagis_kidem_bildir(u, coalesce(c.bagis_bugun,0), m, v_min, t);$d$,
                  '/* bagis_kidem_bildir */', true);
