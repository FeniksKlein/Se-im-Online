-- =====================================================================
--  187 (11.11.2026) · ŞİRKET ÇEKİ KURALLARI (Ercan)
--  1) Şirketler kişilere çek yazamaz; şirket çeki ciro yoluyla da bir kişiye geçemez.
--     Şirketten kişilere para maaş, kâr payı/temettü, sermaye azaltımı ya da ortaklar cari hesabıyla (188) çıkar.
--  2) Şirketten şirkete çek yalnız gerçek ticarete dayanır:
--     a) Ticari ilişki: son 60 günde borçlu şirket, lehtar şirketten mal/hizmet almış olmalı
--        (eko_b2b alımları + kabul edilmiş toptan sipariş çekleri). Toptan sipariş çekinin kendisi ticarettir.
--     b) Tutar sınırı: son 60 günde o şirkete yazılan serbest çeklerin toplamı aradaki ticaret hacmini aşamaz.
--     c) Karşılık: şirketin açık (ödenmemiş) çek borçları + yeni çek, şirket kasasını aşamaz (karşılıksız çek yazılamaz).
--     d) Bir şirkete ciro: ciro eden şirket, çeki devrettiği şirketten son 60 günde ticaret hacmi kadar mal almış olmalı.
--        Bankaya iskonto (hamil banka) serbesttir.
--  3) 186'daki karşılıklı çek engeli (kişi → şirketin ortağı) aynen sürer.
--  Etkilenmeyenler: kişisel çekler; daha önce düzenlenmiş çeklerin ödeme, ibraz, iade, takip işlemleri.
--  Yalnız tetikleyici ve yardımcı fonksiyon; tablo ve veri değişmez.
-- =====================================================================

-- Alıcı şirketin satıcı şirketten son p_gun gündeki alımları (₺)
create or replace function oyun.sirket_ticaret_hacmi(p_alici bigint, p_satici bigint, p_gun int default 60) returns numeric
language sql stable set search_path = '' as $$
  select coalesce((select sum(b.tutar) from oyun.eko_b2b b
                    where b.alici = p_alici and b.satici = p_satici and b.zaman > now() - make_interval(days => p_gun)), 0)
       + coalesce((select sum(c.tutar) from oyun.cekler c
                    where c.borclu_sirket = p_alici and c.ilk_lehtar_sirket = p_satici and c.durum <> 'iptal'
                      and c.aciklama like 'Toptan mal bedeli%' and c.keside_at > now() - make_interval(days => p_gun)), 0)
$$;

create or replace function oyun.cek_dongu_engel() returns trigger
language plpgsql set search_path = '' as $$
declare lehtar uuid; lehtar_s bigint; hacim numeric; kullanilan numeric; acik numeric; kasa numeric; kalan numeric;
begin
  if tg_op = 'INSERT' then
    if new.borclu_sirket is not null then
      lehtar_s := coalesce(new.ilk_lehtar_sirket, new.hamil_sirket);
      -- 1) şirket çeki yalnız şirkete
      if lehtar_s is null then
        raise exception 'Şirketler kişilere çek yazamaz. Şirket çeki yalnız bir şirkete düzenlenebilir; kişilere ödeme maaş, kâr payı, temettü, sermaye azaltımı ya da ortaklar cari hesabıyla yapılır.';
      end if;
      -- 2c) karşılık: açık çek borçları + yeni çek ≤ kasa
      select coalesce(s.kasa, 0) into kasa from oyun.sirketler s where s.id = new.borclu_sirket;
      select coalesce(sum(greatest(0, c.tutar - coalesce(c.odenen, 0))), 0) into acik
        from oyun.cekler c where c.borclu_sirket = new.borclu_sirket and c.durum in ('aktif', 'karsiliksiz');
      if acik + new.tutar > coalesce(kasa, 0) then
        raise exception 'Karşılıksız çek yazılamaz: şirketin açık çek borçları (% ₺) ile bu çek (% ₺) kasadaki parayı (% ₺) aşıyor.',
          oyun.tl(acik), oyun.tl(new.tutar), oyun.tl(coalesce(kasa, 0));
      end if;
      -- 2a/2b) ticari ilişki ve tutar sınırı (toptan sipariş çeki ticaretin kendisidir)
      if coalesce(new.aciklama, '') not like 'Toptan mal bedeli%' then
        hacim := oyun.sirket_ticaret_hacmi(new.borclu_sirket, lehtar_s, 60);
        if hacim <= 0 then
          raise exception 'Şirketler arası çek için ticari ilişki gerekir: son 60 günde bu şirketten mal ya da hizmet almadınız.';
        end if;
        select coalesce(sum(c.tutar), 0) into kullanilan from oyun.cekler c
         where c.borclu_sirket = new.borclu_sirket and c.ilk_lehtar_sirket = lehtar_s and c.durum <> 'iptal'
           and coalesce(c.aciklama, '') not like 'Toptan mal bedeli%' and c.keside_at > now() - interval '60 days';
        if kullanilan + new.tutar > hacim then
          raise exception 'Çek tutarı aradaki ticareti aşamaz: son 60 günde bu şirketten % ₺ alım yaptınız, % ₺ çek yazılabilir.',
            oyun.tl(hacim), oyun.tl(greatest(0, hacim - kullanilan));
        end if;
      end if;
    elsif new.ilk_lehtar_sirket is null and new.duzenleyen is not null then
      -- 3) 186: karşılıklı çek (kişi → şirketin ortağı/yöneticisi)
      lehtar := coalesce(new.ilk_lehtar, new.hamil);
      if exists (select 1 from oyun.cekler c
                  where c.borclu_sirket is not null and c.ilk_lehtar_sirket is null and c.durum <> 'iptal'
                    and coalesce(c.ilk_lehtar, c.hamil) = new.duzenleyen
                    and c.keside_at > now() - interval '7 days'
                    and oyun.cek_sirket_ilgilisi(c.borclu_sirket, lehtar)) then
        raise exception 'Karşılıklı çek engeli: son 7 günde bu kişinin şirketinden çek aldın. Şirket kasası çapraz çekle ortaklara aktarılamaz.';
      end if;
    end if;
  elsif tg_op = 'UPDATE' and new.borclu_sirket is not null then
    -- 1) şirket çeki kişiye ciro edilemez
    if new.hamil_sirket is null and new.hamil is not null and new.hamil is distinct from old.hamil then
      raise exception 'Şirket çeki ciro yoluyla bir kişiye geçemez; yalnız bir şirkete ciro edilebilir.';
    end if;
    -- 2d) şirketten şirkete ciro ticarete dayanır (bankaya iskonto serbest)
    if new.hamil_sirket is not null and old.hamil_sirket is not null and new.hamil_sirket is distinct from old.hamil_sirket
       and not exists (select 1 from oyun.sirketler s where s.id = new.hamil_sirket and s.sektor = 'banka') then
      kalan := greatest(0, new.tutar - coalesce(new.odenen, 0));
      if oyun.sirket_ticaret_hacmi(old.hamil_sirket, new.hamil_sirket, 60) < kalan then
        raise exception 'Çek ancak son 60 günde çek tutarı kadar mal/hizmet aldığınız bir şirkete ciro edilebilir.';
      end if;
    end if;
  end if;
  return new;
end $$;
revoke all on function oyun.cek_dongu_engel(), oyun.sirket_ticaret_hacmi(bigint, bigint, int) from public, anon, authenticated;
drop trigger if exists cek_dongu_engel_trg on oyun.cekler;
create trigger cek_dongu_engel_trg before insert or update of hamil, hamil_sirket on oyun.cekler
  for each row execute function oyun.cek_dongu_engel();
