-- 23 Ekim 2026: Insaati belediyeden pesin ruhsat harci odeyerek tek onayla baslat.
-- Eski RPC'ler ve basvurular korunur. Mevcut ruhsat tetikleyicisi harci
-- sirketten tahsil edip belediyeye aktarir; burada ikinci bir kesinti yapilmaz.

create or replace function public.sirket_insaat_ruhsat_teklif(
  p_sirket bigint, p_arsa bigint, p_daire integer, p_dukkan integer
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  q jsonb;
  a oyun.eko_arsalar%rowtype;
  s oyun.sirketler%rowtype;
  r oyun.bel_yatirim_ruhsat%rowtype;
  v_harc numeric;
  v_maliyet numeric;
  v_kasa numeric;
begin
  q := public.sirket_insaat_teklif(p_sirket,p_arsa,p_daire,p_dukkan);
  if coalesce((q->>'gecerli')::boolean,false)=false then return q; end if;

  select * into a from oyun.eko_arsalar where id=p_arsa;
  select * into s from oyun.sirketler where id=p_sirket;
  select * into r from oyun.bel_yatirim_ruhsat br
   where br.oyuncu=auth.uid() and br.il_id=a.il_id
     and br.tur='arsa_insaat' and br.durum='onay'
     and (br.sirket_id=p_sirket or (br.sirket_id is null and br.sirket_adi=s.ad))
     and (br.hedef_id is null or br.hedef_id=p_arsa)
     and (br.sektor is null or br.sektor=s.sektor)
     and br.karar_zamani>now()-interval '72 hours'
   order by br.id asc limit 1;

  v_maliyet := (q->>'toplam_maliyet')::numeric;
  v_kasa := s.kasa;
  v_harc := oyun.bel_ruhsat_tutar(
    case when r.id is not null then r.onay_oran else oyun.bel_ruhsat_oran(a.il_id,'arsa_insaat') end,
    case when r.id is not null then r.onay_taban else oyun.bel_ruhsat_taban(a.il_id,'arsa_insaat') end,
    v_maliyet
  );
  return q || jsonb_build_object(
    'ruhsat_harci',v_harc,
    'belediye',(select ad from oyun.iller where id=a.il_id),
    'belediye_il_id',a.il_id,
    'toplam_odeme',v_maliyet+v_harc,
    'uygun',v_kasa>=v_maliyet+v_harc,
    'eksik',greatest(0,v_maliyet+v_harc-v_kasa),
    'kalan_kasa',greatest(0,v_kasa-v_maliyet-v_harc),
    'ruhsat_uygulamasi','Tek onayla otomatik ruhsat ve insaat'
  );
end;
$$;

create or replace function public.sirket_insaat_ruhsatli_baslat(
  p_sirket bigint, p_arsa bigint, p_ad text,
  p_daire integer, p_dukkan integer,
  p_beklenen_maliyet numeric, p_beklenen_ruhsat numeric
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  a oyun.eko_arsalar%rowtype;
  s oyun.sirketler%rowtype;
  q jsonb;
  r oyun.bel_yatirim_ruhsat%rowtype;
  v_id bigint;
  v_sonuc jsonb;
  v_maliyet numeric;
  v_harc numeric;
begin
  if u is null or not exists(select 1 from oyun.profiller where id=u and not yasakli) then
    raise exception 'Giris yapmalisin.';
  end if;
  if p_ad is null or length(btrim(p_ad)) not between 1 and 70 then
    raise exception 'Proje adini 1-70 karakter yaz.';
  end if;

  -- Kilit sirasi eski emlak RPC ile ayni: arsa, sonra sirket.
  select * into a from oyun.eko_arsalar where id=p_arsa for update;
  if a.id is null or a.durum<>'satildi' or a.sahibi_sirket is distinct from p_sirket then
    raise exception 'Arsa bu sirketin insaata hazir arsasi degil.';
  end if;
  select * into s from oyun.sirketler where id=p_sirket for update;
  if s.id is null or not s.aktif or not oyun.sirket_yonetici_mi(p_sirket,u) then
    raise exception 'Sirketi yonetme yetkin yok.';
  end if;

  q := public.sirket_insaat_ruhsat_teklif(p_sirket,p_arsa,p_daire,p_dukkan);
  if not coalesce((q->>'gecerli')::boolean,false) then
    raise exception '%',coalesce(q->>'hata','Daire ve dukkan adetlerini kontrol et.');
  end if;
  v_maliyet := (q->>'toplam_maliyet')::numeric;
  v_harc := (q->>'ruhsat_harci')::numeric;
  if p_beklenen_maliyet is null or p_beklenen_ruhsat is null
     or p_beklenen_maliyet<>v_maliyet or p_beklenen_ruhsat<>v_harc then
    raise exception 'Maliyet veya ruhsat bedeli degisti. Yeniden fiyat alarak onayla.';
  end if;
  if s.kasa<v_maliyet+v_harc then
    raise exception 'Sirket kasasi yetersiz. Insaat: % TL, ruhsat: % TL, toplam: % TL, eksik: % TL.',
      v_maliyet,v_harc,v_maliyet+v_harc,v_maliyet+v_harc-s.kasa;
  end if;

  -- Var olan onayli ruhsat varsa tekrar ruhsat olusturma.
  select * into r from oyun.bel_yatirim_ruhsat br
    where br.oyuncu=u and br.il_id=a.il_id and br.tur='arsa_insaat'
      and br.durum='onay'
      and (br.sirket_id=p_sirket or (br.sirket_id is null and br.sirket_adi=s.ad))
      and (br.hedef_id is null or br.hedef_id=p_arsa)
      and (br.sektor is null or br.sektor=s.sektor)
      and br.karar_zamani>now()-interval '72 hours'
    order by br.id asc limit 1 for update;
  if r.id is not null then
    v_id := r.id;
  else
    -- Bir onceki bekleyen basvuruyu kullan, yoksa otomatik ruhsat kaydi ac.
    select id into v_id from oyun.bel_yatirim_ruhsat
     where oyuncu=u and il_id=a.il_id and tur='arsa_insaat'
       and sirket_id=p_sirket and hedef_id=p_arsa and durum='bekliyor'
     order by id desc limit 1 for update;
    if v_id is not null then
      update oyun.bel_yatirim_ruhsat set
        durum='onay', karar_zamani=now(),baskan=null,
        onay_oran=oyun.bel_ruhsat_oran(a.il_id,'arsa_insaat'),
        onay_taban=oyun.bel_ruhsat_taban(a.il_id,'arsa_insaat'),
        tahmini_yatirim=v_maliyet,
        gerekce='Oyuncu ruhsat harcini pesin odeyerek otomatik onayladi.'
       where id=v_id;
    else
      insert into oyun.bel_yatirim_ruhsat(
        il_id,tur,oyuncu,sirket_id,hedef_id,tahmini_yatirim,
        durum,karar_zamani,onay_oran,onay_taban,gerekce
      ) values (
        a.il_id,'arsa_insaat',u,p_sirket,p_arsa,v_maliyet,
        'onay',now(),oyun.bel_ruhsat_oran(a.il_id,'arsa_insaat'),
        oyun.bel_ruhsat_taban(a.il_id,'arsa_insaat'),
        'Oyuncu ruhsat harcini pesin odeyerek otomatik onayladi.'
      ) returning id into v_id;
    end if;
  end if;

  -- Eski inşaat RPC: yapim bedelini keser, BEFORE INSERT ruhsat tetikleyicisi
  -- ruhsat harcini ayrica sirketten kesip belediye kasasina aktarir.
  -- Her sey ayni SQL isleminde: hata olursa butun degisiklikler geri alinir.
  v_sonuc := public.eko_emlak_islem(
    'insaata_basla',
    jsonb_build_object('arsa',p_arsa,'ad',btrim(p_ad),'daire',p_daire,'dukkan',p_dukkan)
  );

  select * into r from oyun.bel_yatirim_ruhsat where id=v_id;
  if r.durum<>'kullanildi' or r.odenen_tl is distinct from v_harc then
    raise exception 'Ruhsat tahsilati dogrulanamadi. Islem iptal edildi.';
  end if;
  return v_sonuc || jsonb_build_object(
    'ruhsat_harci',r.odenen_tl,
    'ruhsat_id',r.id,
    'belediye',(select ad from oyun.iller where id=a.il_id),
    'toplam_odeme',v_maliyet+r.odenen_tl,
    'kalan_kasa',(select kasa from oyun.sirketler where id=p_sirket)
  );
end;
$$;

revoke all on function public.sirket_insaat_ruhsat_teklif(bigint,bigint,integer,integer) from public,anon;
revoke all on function public.sirket_insaat_ruhsatli_baslat(bigint,bigint,text,integer,integer,numeric,numeric) from public,anon;
grant execute on function public.sirket_insaat_ruhsat_teklif(bigint,bigint,integer,integer) to authenticated;
grant execute on function public.sirket_insaat_ruhsatli_baslat(bigint,bigint,text,integer,integer,numeric,numeric) to authenticated;