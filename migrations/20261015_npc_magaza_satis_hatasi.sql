-- 15.10.2026 — sanal müşteri satış motorunda satilan isim çakışmasını giderir.
-- Gözlenen hata: column reference "satilan" is ambiguous (cron.job 21).
-- Fonksiyonun mevcut iş kurallarını, stokları, kasaları, fiyatları ve geçmiş satışları korur.
-- Tekrar çalıştırılabilir; önceki sürümle beklenen eşleşme yoksa sessizce değiştirmez.

do $patch$
declare d text;
begin
  d := pg_get_functiondef('oyun.eko_ticaret_tick()'::regprocedure);
  if position('select greatest(0,lim.ust_sinir-lim.satilan)' in d)>0
      and position('set satilan=oyun.eko_sehir_musteri_limiti.satilan+siparis' in d)>0 then
    raise notice 'NPC sales function already corrected';
    return;
  end if;
  if position('select greatest(0,ust_sinir-satilan)' in d)=0
      or position('set satilan=satilan+siparis' in d)=0
      or position('and satilan+siparis<=ust_sinir' in d)=0
      or position('from oyun.eko_sehir_musteri_limiti where il_id=mag.il_id' in d)=0 then
    raise exception 'Unexpected NPC sales function body: manual review needed.';
  end if;
  d:=replace(d,'select greatest(0,ust_sinir-satilan)','select greatest(0,lim.ust_sinir-lim.satilan)');
  d:=replace(d,'from oyun.eko_sehir_musteri_limiti where il_id=mag.il_id','from oyun.eko_sehir_musteri_limiti lim where lim.il_id=mag.il_id');
  d:=replace(d,'set satilan=satilan+siparis','set satilan=oyun.eko_sehir_musteri_limiti.satilan+siparis');
  d:=replace(d,'and satilan+siparis<=ust_sinir','and oyun.eko_sehir_musteri_limiti.satilan+siparis<=oyun.eko_sehir_musteri_limiti.ust_sinir');
  execute d;
end $patch$;

-- Canlı doğrulama (bu dosya finansal işlem başlatmaz):
-- select status, return_message from cron.job_run_details where jobid=21 order by runid desc limit 3;
-- select * from oyun.eko_npc_satis order by id desc limit 5;
