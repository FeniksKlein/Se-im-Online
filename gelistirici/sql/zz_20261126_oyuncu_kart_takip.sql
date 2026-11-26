-- 26.11.2026 · Oyuncu kartında "Takip et" (sürüm 2026.11.26-11)
-- Oyuncu önerisi (X, Ercan: "Bunu da yayına sok"): oyuncu kartında Özel mesaj düğmesinin yanında takip et olsun.
-- Takip, Kürsü takibiyle aynıdır (oyun.kursu_takip; işlem public.kursu_takip_et). Kart, takip durumunu ve takipçi
-- sayısını döndürür; eski uygulama bu alanları yok sayar (düğme yalnız yeni istemcide görünür).
create or replace function public.oyuncu_kart(p_kad text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare p oyun.profiller := oyun.profilim(); h oyun.profiller;
begin
  h := oyun.profil_bul(p_kad);
  return jsonb_build_object('kad', h.kad, 'il_ad', (select ad from oyun.iller where id = h.il_id), 'il_id', h.il_id,
    'parti', oyun.parti_json(h.parti_id), 'unvan', oyun.unvan(h.id), 'katilim', h.olusturma,
    'ben', h.id = p.id, 'engelledim', oyun.engelli(p.id, h.id), 'rozetler', oyun.rozetler(h.id),
    'borclu', oyun.takipte(h.id),
    'karneler', oyun.karneler(h.id), 'statu', oyun.statu_json(h.id), 'itibar', oyun.itibar_json(h.id),
    'takip_ediyorum', exists (select 1 from oyun.kursu_takip t where t.takipci = p.id and t.takip_edilen = h.id),
    'takipci', (select count(*) from oyun.kursu_takip t where t.takip_edilen = h.id),
    'gecmis', coalesce((select jsonb_agg(jsonb_build_object('makam', oyun.makam_ad(m.tur, m.il_id, m.bakanlik), 'bas', m.bas, 'bit', m.bit) order by m.bas desc)
                        from (select * from oyun.makamlar where user_id = h.id order by bas desc limit 20) m), '[]'::jsonb));
end $function$;
