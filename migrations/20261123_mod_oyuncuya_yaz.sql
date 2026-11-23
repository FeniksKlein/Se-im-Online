-- Canlı Supabase migration adı: mod_oyuncuya_yaz_20261123
-- DURUM (23.11.2026 18:10): canlıya UYGULANDI. Önce canlıda geri alınan işlemle denendi (mesaj, karşılık, aynı yazışmaya
--   ekleme, yazılı uyarı, yetkisiz/kurucuya/kendine/engelliye/kısa mesaj retleri, kurucu imzası); işlev gövdesi md5 ile eşleşti.
-- Kaynak: gelistirici/sql/zz_20261123_mod_oyuncuya_yaz.sql · tekrar çalıştırmak güvenlidir.
begin;
select set_config('lock_timeout', '4s', true);

-- 23.11.2026 · MODERATÖRDEN OYUNCUYA ÖZEL MESAJ VE YAZILI UYARI (sürüm 2026.11.23-8)
-- İstek (Ercan): "Moderatörlere oyunculara özel mesaj atma, uyarma özelliği getir."
-- Mevcut durum: yönetim oyuncuya yalnız oyuncu önce Yönetime Yaz'dan yazarsa karşılık verebiliyordu; tek yönlü bildirim
-- (yk_bildirim) yalnız 'duyuru' yetkisinde, Resmî uyarı (mod_uyari; 24 saatte 3. uyarıda otomatik susturma) yalnız
-- 'sustur' yetkisinde (İçerik ve Oyuncu masaları).
-- Bu dosya: her oyun yöneticisi (bütün masalar + kurucu) bir oyuncuya kendiliğinden yazabilir.
--   · Yazışma Yönetime Yaz altyapısını kullanır (oyun.destek_talep + oyun.destek_mesaj): oyuncu mesajı
--     Ben › Yönetime Yaz'da görür ve karşılık yazabilir; karşılık yazanın masasının Talep kutusu'na düşer.
--     Mağazadaki uygulamalarda da çalışır (yeni ekran gerekmez); oyuncuya ayrıca bildirim gider.
--   · Yazanın adı görünmez: imza "Oyun Yöneticisi G-xx" / "Oyun Kurucusu" (oyun.mod_imza).
--   · İki tür: mesaj (konu 'yonetim') ve yazılı uyarı (konu 'yonetim_uyari'). Yazılı uyarı yaptırım değildir, kısıt
--     uygulamaz ve otomatik susturma sayacına girmez; oyuncunun dosyasında (denetim günlüğü) görünür.
--   · Aynı masanın aynı oyuncuyla kapanmamış aynı türde yazışması varsa yenisi açılmaz, ona eklenir.
--   · Kurucuya ve diğer yöneticilere yazılamaz (oyun.mod_koruma); engelli oyuncuya yazılamaz; yönetici başına saatte
--     en çok 30 mesaj (toplu bilgilendirme duyuruyla yapılır). Kurucuda sınır yok.
-- Yama yardımcısı oyun._yama bu dosyadan önce gelmelidir. Tekrar çalıştırmak güvenlidir.

create or replace function public.mod_oyuncuya_yaz(p_kad text, p_metin text, p_uyari boolean default false) returns jsonb
language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller := oyun.mod_uye_zorunlu(); h oyun.profiller; t timestamptz := oyun.simdi();
        m text := btrim(regexp_replace(coalesce(p_metin, ''), '[\r\n]{3,}', E'\n\n', 'g'));
        v_uyari boolean := coalesce(p_uyari, false); v_konu text; v_masa text; v_id bigint; v_yeni boolean := false; n integer;
begin
  select * into h from oyun.profiller where lower(kad) = lower(btrim(coalesce(p_kad, '')));
  if h.id is null then raise exception 'Oyuncu bulunamadı.'; end if;
  if h.id = p.id then raise exception 'Kendine yazamazsın.'; end if;
  perform oyun.mod_koruma(p, h.id);
  if coalesce(h.yasakli, false) and (h.engel_bitis is null or h.engel_bitis > t) then
    raise exception 'Bu oyuncu engelli; oyuna giremediği için mesajı okuyamaz.';
  end if;
  if char_length(m) < 10 or char_length(m) > 1000 then raise exception 'Mesaj 10-1000 karakter olmalı.'; end if;
  if not coalesce(p.yonetici, false) then
    select count(*) into n from oyun.mod_kayit k
     where k.user_id = p.id and k.islem in ('mod_mesaj', 'mod_yazili_uyari') and k.zaman > t - interval '1 hour';
    if n >= 30 then raise exception 'Bir saatte en çok 30 mesaj gönderebilirsin. Toplu bilgilendirme için duyuru kullan.'; end if;
  end if;
  v_konu := case when v_uyari then 'yonetim_uyari' else 'yonetim' end;
  v_masa := case when coalesce(p.yonetici, false) then 'kurucu'
                 else coalesce((select mm.ana_gorev from oyun.moderatorler mm where mm.user_id = p.id), 'oyuncu') end;
  select d.id into v_id from oyun.destek_talep d
   where d.user_id = h.id and d.konu = v_konu and coalesce(d.masa, 'oyuncu') = v_masa and d.durum <> 'kapali'
   order by d.id desc limit 1 for update;
  if v_id is null then
    insert into oyun.destek_talep (user_id, kategori, metin, masa, konu, zaman, son_hareket, durum, yanit, yanit_zaman, yanitlayan, okundu)
    values (h.id, 'diger', m, v_masa, v_konu, t, t, 'yanitlandi', m, t, p.id, false)
    returning id into v_id;
    v_yeni := true;
  else
    update oyun.destek_talep set durum = 'yanitlandi', yanit = m, yanit_zaman = t, yanitlayan = p.id, okundu = false, son_hareket = t where id = v_id;
  end if;
  insert into oyun.destek_mesaj (talep_id, yazan, gorevli, metin, zaman) values (v_id, p.id, true, m, t);
  perform oyun.bildir(h.id, format('%s (%s): %s · Karşılık yazmak için: Ben › Yönetime Yaz (#%s).',
    case when v_uyari then 'Oyun yönetiminden uyarı' else 'Oyun yönetiminden mesaj' end, oyun.mod_imza(p), left(m, 400), v_id), t);
  perform oyun.mod_log(p, case when v_uyari then 'mod_yazili_uyari' else 'mod_mesaj' end, h.kad, format('#%s %s', v_id, left(m, 200)));
  return jsonb_build_object('tamam', true, 'id', v_id, 'yeni', v_yeni, 'uyari', v_uyari);
end $f$;
revoke all on function public.mod_oyuncuya_yaz(text, text, boolean) from public, anon;
grant execute on function public.mod_oyuncuya_yaz(text, text, boolean) to authenticated;

-- Yönetimin başlattığı yazışmanın başlığı (oyuncunun Yönetime Yaz ekranı ve Talep kutusu)
select oyun._yama('oyun.destek_talep_json(oyun.destek_talep,boolean)',
  $d$initcap(x.kategori))$d$,
  $y$/* mod_oyuncuya_yaz */ case x.konu when 'yonetim' then 'Oyun yönetiminden mesaj' when 'yonetim_uyari' then 'Oyun yönetiminden uyarı' else initcap(x.kategori) end)$y$,
  '/* mod_oyuncuya_yaz */', true);

commit;
