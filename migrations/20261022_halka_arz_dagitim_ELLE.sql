-- Halka arz dağıtım fonksiyonu (eşit dağıtım sonrası payları, masrafları ve borsa ilk fiyatını işler).
-- Supabase bağlantı aracı bu dosyayı otomatik yüklemeyi iptal ettiği için Supabase SQL Editor'den elle çalıştırılır.
-- Tekrar çalıştırmak güvenlidir; oyuncu verisini değiştirmez (yalnız fonksiyon tanımlar).
create or replace function oyun.halka_arz_dagitim(p_id bigint)
returns text language plpgsql security definer set search_path to '' as $$
declare a oyun.halka_arz; s oyun.sirketler; t timestamptz := oyun.simdi(); kisi int;
  v_toplam numeric; v_T numeric; v_Tn numeric; v_Ts numeric; v_post numeric; v_sat numeric; v_masraf numeric; v_ilk boolean;
begin
  select * into a from oyun.halka_arz where id = p_id for update;
  if a.id is null or a.durum <> 'acik' then return coalesce(a.durum, 'yok'); end if;
  select * into s from oyun.sirketler where id = a.sirket_id for update;
  select count(*), coalesce(sum(tutar), 0) into kisi, v_toplam from oyun.halka_arz_talep where arz_id = a.id;
  select coalesce(sum(z.tahsis), 0) into v_T from oyun.halka_arz_tahsis(a.id) z;
  select pay into v_sat from oyun.sirket_ortaklari where sirket_id = a.sirket_id and user_id = a.baslatan;
  v_Ts := least(case when coalesce(a.ortak_satis, 0) > 0 then round(v_T * a.ortak_satis / a.hedef) else 0 end,
                floor(coalesce(v_sat, 0) * a.deger / 100));
  v_Tn := v_T - v_Ts;
  v_ilk := not coalesce(s.halka_acik, false);
  perform oyun.sirket_hesapla(a.sirket_id);
  v_post := a.deger + v_Tn;
  perform oyun.halka_arz_dagitim_paylar(a.id, v_post, v_Ts);
  v_masraf := oyun.halka_arz_dagitim_finans(a.id, v_Tn, v_Ts);
  if v_ilk and not exists (select 1 from oyun.borsa_fiyat_referans where sirket_id = a.sirket_id)
     and not exists (select 1 from oyun.borsa_fiyat_gecmis where sirket_id = a.sirket_id) then
    insert into oyun.borsa_fiyat_gecmis(sirket_id, fiyat, zaman, gerekce)
    values (a.sirket_id, greatest(1, round(v_post / 100)), t, 'Halka arz fiyatı (borsada ilk işlem referansı)');
  end if;
  update oyun.halka_arz set durum = 'tamam', sonuc_zaman = t, talep_toplam = v_toplam, toplanan = v_T, satilan = v_T,
    yeni_sermaye = v_Tn, ortak_gelir = v_Ts, masraf = v_masraf, ilk_arz = v_ilk, kilit_bit = t + interval '7 days',
    aciklama = format('%s yatırımcı, %s ₺ talep (%s kat), %s ₺ satış; satılan pay %%%s%s', kisi, oyun.tl(v_toplam),
      replace(to_char(round(v_toplam / a.hedef, 2), 'FM9990.00'), '.', ','),
      oyun.tl(v_T), round(v_T / v_post * 100, 2), case when v_toplam > a.hedef then ', eşit dağıtım' else '' end)
   where id = a.id;
  perform oyun.halka_arz_sonuc_bildir(a.id);
  return 'tamam';
end $$;
revoke all on function oyun.halka_arz_dagitim(bigint) from public, anon, authenticated;
select 'Halka arz dağıtımı kuruldu' as sonuc;
