-- 20.10.2026 | SPK: kanita dayali ve gerekceli karar, otomatik ceza yok.
-- Eski ceza/yasak kayitlarini degistirmez.
begin;

-- Bakanin serbest metin iddiasi delil sayilmaz. Ceza icin iki farkli,
-- ayni hisseye ait, ayni iki hesap arasinda ters yonlu gerceklesmis
-- ve 48 saat icinde kalmis borsa islemi sunucudan dogrulanir.
create or replace function oyun.spk_kanit_dogrula(p_id bigint)
returns jsonb language plpgsql stable set search_path to '' as $$
declare
  i oyun.spk_inceleme;
  r record;
begin
  select * into i from oyun.spk_inceleme where id=p_id;
  if i.id is null then
    return jsonb_build_object('yeterli',false,'aciklama','İnceleme bulunamadı.');
  end if;

  select a.id as id1, b.id as id2,
         a.zaman as zaman1, b.zaman as zaman2,
         a.alici as alici1, a.satici as satici1,
         b.alici as alici2, b.satici as satici2,
         a.tutar as tutar1, b.tutar as tutar2,
         a.birim as birim1, b.birim as birim2
    into r
    from oyun.borsa_islem a
    join oyun.borsa_islem b
      on b.sirket_id=a.sirket_id
     and b.id>a.id
     and b.alici=a.satici and b.satici=a.alici
     and b.zaman between a.zaman-interval '48 hours' and a.zaman+interval '48 hours'
    where a.sirket_id=i.sirket_id
      and a.alici<>a.satici
      and a.zaman between i.bas-interval '14 days' and i.bas
      and b.zaman between i.bas-interval '14 days' and i.bas
      and (
        (i.taraf2 is null and (a.alici=i.taraf1 or a.satici=i.taraf1))
        or (i.taraf2 is not null and
            ((a.alici=i.taraf1 and a.satici=i.taraf2)
             or (a.alici=i.taraf2 and a.satici=i.taraf1)))
      )
    order by greatest(a.zaman,b.zaman) desc, b.id desc
    limit 1;

  if not found then
    return jsonb_build_object(
      'yeterli',false,'toplam_tutar',0,'islem_idleri','[]'::jsonb,
      'aciklama','İnceleme açılana kadar aynı iki hesap arasında 48 saatte ters yönlü iki borsa işlemi doğrulanamadı. Yalnız iddia veya işlem hacmiyle ceza verilemez.'
    );
  end if;

  return jsonb_build_object(
    'yeterli',true,
    'toplam_tutar',r.tutar1+r.tutar2,
    'islem_idleri',jsonb_build_array(r.id1,r.id2),
    'islemler',jsonb_build_array(
      jsonb_build_object('id',r.id1,'zaman',r.zaman1,'alici',oyun.kad(r.alici1),
        'satici',oyun.kad(r.satici1),'tutar',r.tutar1,'birim',r.birim1),
      jsonb_build_object('id',r.id2,'zaman',r.zaman2,'alici',oyun.kad(r.alici2),
        'satici',oyun.kad(r.satici2),'tutar',r.tutar2,'birim',r.birim2)
    ),
    'aciklama','İki ters yönlü işlem doğrulandı. Bu somut inceleme delilidir; tek başına suçu ispatlamaz. Bakan ayrıntılı gerekçe yazmalıdır.'
  );
end $$;

-- Butun yollarin kullandigi tek ceza noktasinda kontrol yapilir.
create or replace function oyun.spk_sonuclandir(
  p_id bigint, p_ceza boolean, p_karar_veren uuid, p_not text, t timestamptz
) returns void language plpgsql set search_path to '' as $$
declare
  i oyun.spk_inceleme;
  delil jsonb;
  tutar numeric;
  c numeric;
  odenen numeric;
  u uuid;
  sad text;
  toplam numeric := 0;
begin
  select * into i from oyun.spk_inceleme where id=p_id and durum='acik' for update;
  if i.id is null then return; end if;
  if p_ceza is null then raise exception 'SPK karar türü belirtilmeli.'; end if;
  if p_karar_veren is not null and char_length(btrim(coalesce(p_not,'')))<40 then
    raise exception 'SPK kararı için en az 40 karakterlik somut gerekçe zorunludur.';
  end if;
  select ad into sad from oyun.sirketler where id=i.sirket_id;

  if p_ceza then
    if p_karar_veren is null then
      raise exception 'SPK otomatik ceza veremez; yetkili bakanın gerekçeli kararı gerekir.';
    end if;
    delil := oyun.spk_kanit_dogrula(i.id);
    if not coalesce((delil->>'yeterli')::boolean,false) then
      raise exception 'Somut borsa işlem kanıtı yok. Yalnız ihbar, iddia veya hacimle ceza verilemez.';
    end if;

    -- Sadece dogrulanmis supheli islem ciftinin hacmi dikkate alinir.
    tutar := coalesce((delil->>'toplam_tutar')::numeric,0);
    c := greatest(10000,round(tutar*0.20));
    foreach u in array array_remove(array[i.taraf1,i.taraf2],null) loop
      odenen := oyun.tahsil_et(u,c,false,
        format('SPK idari para cezası (%s, inceleme #%s)',coalesce(sad,'borsa'),i.id),t);
      toplam := toplam + coalesce(odenen,0);
      insert into oyun.spk_yasak(user_id,bit,neden)
        values(u,t+interval '7 days',format('SPK inceleme #%s',i.id))
        on conflict(user_id) do update
          set bit=greatest(oyun.spk_yasak.bit,excluded.bit),neden=excluded.neden;
      perform oyun.bildir(u,format(
        'SPK kararı: %s işlemleri için %s ₺ ceza ve 7 gün borsa yasağı. Kararı veren: %s. Gerekçe: %s',
        coalesce(sad,'—'),oyun.tl(c),oyun.kad(p_karar_veren),left(p_not,180)),t);
    end loop;
    if toplam>0 then
      update oyun.ulke set hazine=hazine+toplam/oyun.pazar_tl_milyar() where id=1;
    end if;
    update oyun.spk_inceleme
      set durum='ceza',ceza=c,karar_veren=p_karar_veren,
          karar_not=p_not,karar_zaman=t,
          kanit=kanit||jsonb_build_object('karara_esas_delil',delil)
      where id=i.id;
    perform oyun.olay('ekonomi',format(
      'SPK, %s hisselerinde işlem yapan %s hakkında gerekçeli karar verdi: kişi başı %s ₺ ve 7 gün yasak.',
      coalesce(sad,'—'),concat_ws(' ve ',oyun.kad(i.taraf1),
      case when i.taraf2 is not null then oyun.kad(i.taraf2) end),oyun.tl(c)),null,null,t);
    perform oyun.gazete_ekle('icraat','SPK''dan borsa cezası',
      format('SPK, %s hisselerindeki doğrulanmış ters yönlü işlemlerle ilgili gerekçeli ceza kararı verdi.',coalesce(sad,'—')),i.id,t);
  else
    update oyun.spk_inceleme
      set durum='beraat',karar_veren=p_karar_veren,karar_not=p_not,karar_zaman=t
      where id=i.id;
    foreach u in array array_remove(array[i.taraf1,i.taraf2],null) loop
      perform oyun.bildir(u,format(
        'SPK, %s hisseleri hakkındaki incelemeyi ceza vermeden kapattı. %s',
        coalesce(sad,'—'),coalesce(left(p_not,180),'')),t);
    end loop;
  end if;
end $$;

create or replace function public.spk_karar(
  p_id bigint, p_ceza boolean, p_not text default null
) returns jsonb language plpgsql security definer set search_path to '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  if oyun.bakanlik_yetkilisi('maliye') is distinct from p.id then
    raise exception 'SPK kararını Hazine ve Maliye Bakanı verir.';
  end if;
  if not exists(select 1 from oyun.spk_inceleme where id=p_id and durum='acik') then
    raise exception 'Açık inceleme bulunamadı.';
  end if;
  if exists(select 1 from oyun.spk_inceleme where id=p_id and (taraf1=p.id or taraf2=p.id)) then
    raise exception 'Taraf olduğun incelemede karar veremezsin.';
  end if;
  if p_ceza is null or char_length(btrim(coalesce(p_not,'')))<40 then
    raise exception 'Ceza veya beraat kararı için en az 40 karakterlik gerekçe yazmalısın.';
  end if;
  perform oyun.spk_sonuclandir(p_id,p_ceza,p.id,left(btrim(p_not),500),oyun.simdi());
  return public.spk_ekrani();
end $$;

create or replace function public.spk_ekrani()
returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := oyun.ben();
begin
  return jsonb_build_object(
    'yetkili',oyun.bakanlik_yetkilisi('maliye') is not distinct from me and me is not null,
    'yasagim',(select bit from oyun.spk_yasak where user_id=me and bit>oyun.simdi()),
    'sirketler',coalesce((select jsonb_agg(jsonb_build_object('id',id,'ad',ad) order by ad)
      from oyun.sirketler where aktif and halka_acik),'[]'::jsonb),
    'incelemeler',coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id,'sirket',s.ad,'sirket_id',i.sirket_id,
      'taraf1',oyun.kad(i.taraf1),
      'taraf2',case when i.taraf2 is null then null else oyun.kad(i.taraf2) end,
      'tur',i.tur,'tur_ad',case i.tur when 'bagli_hesap' then 'Bağlantılı hesap işlemleri'
        when 'karsilikli_islem' then 'Karşılıklı al-sat şüphesi' else 'Manipülasyon iddiası' end,
      'tutar',i.kanit->>'iliskili_tutar','iddia',i.kanit->>'iddia',
      'acan',case when i.acan is null then 'Otomatik gözetim' else oyun.kad(i.acan) end,
      'taraf_benim',i.taraf1=me or i.taraf2=me,
      'bas',i.bas,'bit',i.bit,'durum',i.durum,'ceza',i.ceza,
      'karar_not',i.karar_not,'karar_zaman',i.karar_zaman,
      'karar_veren',case when i.karar_veren is null then 'Oyun sistemi' else oyun.kad(i.karar_veren) end,
      'delil',coalesce(i.kanit->'karara_esas_delil',oyun.spk_kanit_dogrula(i.id))
    ) order by i.bas desc)
      from (select * from oyun.spk_inceleme order by bas desc limit 40) i
      left join oyun.sirketler s on s.id=i.sirket_id),'[]'::jsonb),
    'kural','SPK şüpheli işlemleri incelemeye alır; iddia tek başına ceza gerekçesi olamaz. Ceza için 48 saatte aynı hesaplar arasında ters yönlü iki gerçek borsa işlemi ve Hazine ve Maliye Bakanının en az 40 karakterlik gerekçeli kararı gerekir. Ceza doğrulanan işlem tutarının %20''si (en az 10.000 ₺) ve 7 gün işlem yasağıdır. 72 saatte karar verilmezse dosya cezasız kapanır.'
  );
end $$;

create or replace function oyun.spk_tick(t timestamptz)
returns void language plpgsql set search_path to '' as $$
declare r record;
begin
  for r in select id from oyun.spk_inceleme where durum='acik' and bit<=t
    order by bit limit 100 loop
    perform oyun.spk_sonuclandir(r.id,false,null,
      '72 saat doldu; somut delil ve gerekçeli insan kararı olmadan otomatik ceza verilmedi.',t);
  end loop;
  delete from oyun.spk_yasak where bit<t-interval '30 days';
end $$;

-- Ic fonksiyonlar web istemcisi tarafindan dogrudan cagrilarak atlatilamaz.
revoke all on function oyun.spk_kanit_dogrula(bigint) from public,anon,authenticated;
revoke all on function oyun.spk_sonuclandir(bigint,boolean,uuid,text,timestamptz) from public,anon,authenticated;
revoke all on function oyun.spk_tick(timestamptz) from public,anon,authenticated;

commit;
