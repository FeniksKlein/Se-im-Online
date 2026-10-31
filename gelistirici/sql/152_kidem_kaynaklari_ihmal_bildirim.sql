-- 152 (31.10.2026) — YENİ KIDEM KAYNAKLARI ve ATANMIŞ GÖREVDE İHMAL: GÖREVDEN ALMA YERİNE ÜSTE BİLDİRİM
-- İstek (Ercan): kıdem miting, Meclis oylaması ve parti görevlerine de bağlansın. 3 gün oyuna girmeyen atanmış
-- görevli (bakan, genel başkan yardımcısı) görevden alınmasın; bağlı olduğu kişiye (bakan → cumhurbaşkanı) bildirim gitsin.
-- Seçilmiş görevlerdeki 7 günlük ihmal kuralı (cumhurbaşkanı, belediye başkanı, genel başkan) değişmedi.
-- Oyuncu verisini dönüştürmez.

-- ===================== KIDEM KAYNAKLARI =====================
create table if not exists oyun.kidem_kaynak (
  kod text primary key, ad text not null, puan numeric not null, gunluk_tavan numeric not null, sira int not null default 100);
alter table oyun.kidem_kaynak enable row level security;
revoke all on oyun.kidem_kaynak from public, anon, authenticated;
-- Değerler yalnız ilk kurulumda yazılır; yöneticinin ayarı korunur
insert into oyun.kidem_kaynak(kod, ad, puan, gunluk_tavan, sira) values
  ('miting_duzenle',  'Miting düzenlemek',                    1,   1, 10),
  ('miting_katil',    'Mitinge katılmak',                     0.5, 0.5, 11),
  ('meclis_oy',       'Meclis''te kanun oylamasına katılmak', 0.5, 1, 20),
  ('meclis_secim',    'Meclis içi seçimde oy kullanmak',      1,   1, 21),
  ('teskilat_ac',     'Parti il teşkilatı açmak',             1,   2, 30),
  ('stant_ac',        'Parti stantı açmak',                   1,   1, 31),
  ('stant_gonullu',   'Parti stantında gönüllü olmak',        0.5, 0.5, 32),
  ('parti_aciklama',  'Parti adına resmî açıklama yapmak',    0.5, 0.5, 33)
on conflict (kod) do update set ad = excluded.ad, sira = excluded.sira;

create table if not exists oyun.kidem_kazanc (
  user_id uuid not null, gun date not null, kaynak text not null, puan numeric not null default 0, primary key (user_id, gun, kaynak));
alter table oyun.kidem_kazanc enable row level security;
revoke all on oyun.kidem_kazanc from public, anon, authenticated;

-- Günlük tavana kadar kıdem ekler; hiçbir zaman asıl işlemi bozmaz
create or replace function oyun.kidem_ekle(u uuid, p_kaynak text) returns numeric
language plpgsql security definer set search_path = '' as $$
declare k oyun.kidem_kaynak; g date := (oyun.simdi() at time zone 'Europe/Istanbul')::date; once numeric; ek numeric;
begin
  if u is null then return 0; end if;
  select * into k from oyun.kidem_kaynak where kod = p_kaynak;
  if k.kod is null or k.puan <= 0 then return 0; end if;
  select coalesce((select puan from oyun.kidem_kazanc where user_id = u and gun = g and kaynak = p_kaynak), 0) into once;
  ek := least(k.puan, greatest(0, k.gunluk_tavan - once));
  if ek <= 0 then return 0; end if;
  perform oyun.cuzdanim(u);
  update oyun.cuzdan set kidem = kidem + ek where user_id = u;
  insert into oyun.kidem_kazanc(user_id, gun, kaynak, puan) values (u, g, p_kaynak, ek)
    on conflict (user_id, gun, kaynak) do update set puan = oyun.kidem_kazanc.puan + excluded.puan;
  return ek;
exception when others then
  return 0;
end $$;
revoke all on function oyun.kidem_ekle(uuid, text) from public, anon, authenticated;

create or replace function oyun.tg_kidem_kaynak() returns trigger
language plpgsql security definer set search_path = '' as $$
declare u uuid;
begin
  u := case tg_argv[1]
         when 'user_id' then (to_jsonb(new) ->> 'user_id')::uuid
         when 'vekil' then (to_jsonb(new) ->> 'vekil')::uuid
         when 'secmen' then (to_jsonb(new) ->> 'secmen')::uuid
         when 'kuran' then (to_jsonb(new) ->> 'kuran')::uuid
         when 'acan' then (to_jsonb(new) ->> 'acan')::uuid
         when 'yazar' then (to_jsonb(new) ->> 'yazar')::uuid end;
  perform oyun.kidem_ekle(u, tg_argv[0]);
  return null;
exception when others then
  return null;
end $$;

create or replace trigger tg_kidem_miting after insert on oyun.mitingler for each row execute function oyun.tg_kidem_kaynak('miting_duzenle', 'user_id');
create or replace trigger tg_kidem_miting_katil after insert on oyun.miting_katilim for each row execute function oyun.tg_kidem_kaynak('miting_katil', 'user_id');
create or replace trigger tg_kidem_meclis_oy after insert on oyun.kanun_oylari for each row execute function oyun.tg_kidem_kaynak('meclis_oy', 'vekil');
create or replace trigger tg_kidem_meclis_secim after insert on oyun.meclis_oy for each row execute function oyun.tg_kidem_kaynak('meclis_secim', 'secmen');
create or replace trigger tg_kidem_teskilat after insert on oyun.parti_teskilat for each row execute function oyun.tg_kidem_kaynak('teskilat_ac', 'kuran');
create or replace trigger tg_kidem_stant after insert on oyun.stant for each row execute function oyun.tg_kidem_kaynak('stant_ac', 'acan');
create or replace trigger tg_kidem_stant_gonullu after insert on oyun.stant_gonullu for each row execute function oyun.tg_kidem_kaynak('stant_gonullu', 'user_id');
create or replace trigger tg_kidem_parti_aciklama after insert on oyun.parti_aciklamalar for each row execute function oyun.tg_kidem_kaynak('parti_aciklama', 'yazar');

-- ===================== ATANMIŞ GÖREVDE İHMAL: ÜSTE BİLDİRİM =====================
create or replace function oyun.ihmal_tick(t timestamp with time zone)
 returns void language plpgsql set search_path to '' as $function$
declare ga int; gs int; r record; sec jsonb;
begin
  select ihmal_gun_atama, ihmal_gun_secim into ga, gs from oyun.ayarlar where id = 1;
  -- Kayıt yalnız oyuncunun son görülmesinden sonra yazılmışsa geçerlidir (geri dönen oyuncu sonraki ihmalde yeniden bildirilir)

  -- 152: Atanmış görevler (bakan, cumhurbaşkanı yardımcısı, genel başkan yardımcısı) görevden ALINMAZ.
  -- ga gün oyuna girmeyenin bağlı olduğu kişiye bir kez bildirim gider; görevli de bilgilendirilir.
  if ga > 0 then
    for r in select m.user_id, m.tur, m.bakanlik, p.kad, p.son_gorulme from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
             where m.tur in ('bakan', 'cb_yardimcisi') and m.bit is null
               and coalesce(p.son_gorulme, m.bas) < t - make_interval(days => ga) and m.bas < t - make_interval(days => ga)
               and not exists (select 1 from oyun.ihmal_uyari u where u.user_id = m.user_id and u.tur = 'atama' and u.zaman > coalesce(p.son_gorulme, '-infinity')) loop
      perform oyun.bildir(m2.user_id, format('%s (%s) %s gündür oyuna girmiyor. Görevden alınmadı; dilersen yerine başka birini atayabilirsin.',
          r.kad, case when r.tur = 'bakan' then oyun.makam_ad('bakan', null, r.bakanlik) else 'Cumhurbaşkanı Yardımcısı' end, ga), t)
        from oyun.makamlar m2 where m2.tur = 'cb' and m2.bit is null and m2.user_id <> r.user_id;
      perform oyun.bildir(r.user_id, format('%s gündür oyuna girmediğin için cumhurbaşkanına bilgi verildi. Görevin devam ediyor.', ga), t);
      insert into oyun.ihmal_uyari(user_id, tur, zaman) values (r.user_id, 'atama', t) on conflict (user_id, tur) do update set zaman = excluded.zaman;
    end loop;
    for r in select g.parti_id, g.user_id, p.kad, pa.gb, pa.ad from oyun.parti_gby g join oyun.profiller p on p.id = g.user_id join oyun.partiler pa on pa.id = g.parti_id
             where coalesce(p.son_gorulme, g.atama) < t - make_interval(days => ga) and g.atama < t - make_interval(days => ga)
               and not exists (select 1 from oyun.ihmal_uyari u where u.user_id = g.user_id and u.tur = 'atama' and u.zaman > coalesce(p.son_gorulme, '-infinity')) loop
      if r.gb is not null and r.gb <> r.user_id then
        perform oyun.bildir(r.gb, format('Genel başkan yardımcın %s %s gündür oyuna girmiyor. Görevden alınmadı; dilersen yerine başka birini atayabilirsin.', r.kad, ga), t);
      end if;
      perform oyun.bildir(r.user_id, format('%s gündür oyuna girmediğin için %s genel başkanına bilgi verildi. Görevin devam ediyor.', ga, r.ad), t);
      insert into oyun.ihmal_uyari(user_id, tur, zaman) values (r.user_id, 'atama', t) on conflict (user_id, tur) do update set zaman = excluded.zaman;
    end loop;
  end if;

  -- Seçilmiş görevler: cumhurbaşkanı, belediye başkanı, genel başkan (değişmedi)
  if gs > 0 then
    for r in select m.id, m.tur, m.user_id, m.il_id, p.kad, p.parti_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
             where m.tur in ('cb','bel') and m.bit is null and coalesce(p.son_gorulme, m.bas) < t - make_interval(days => gs)
               and m.bas < t - make_interval(days => gs)
               and exists (select 1 from oyun.ihmal_uyari u where u.user_id = m.user_id and u.tur = 'secim' and u.zaman <= t - interval '2 days' and u.zaman > coalesce(p.son_gorulme, '-infinity')) loop
      perform oyun.makam_bitir(r.id, t, 'ihmal');
      sec := oyun.ara_secim_olustur(r.tur, null, case when r.tur = 'bel' then r.il_id end, t);
      perform oyun.bildir(r.user_id, format('%s gündür oyuna girmediğin için %s görevin sona erdi.', gs, oyun.makam_ad(r.tur, r.il_id, null)), t);
      perform oyun.olay('makam', format('%s, %s gündür ortada olmadığı için %s görevinden düştü. Olağanüstü seçim takvimi oluşturuldu.',
        r.kad, gs, oyun.makam_ad(r.tur, r.il_id, null)), r.il_id, r.parti_id, t);
    end loop;
    for r in select pa.id, pa.ad, pa.gb, p.kad from oyun.partiler pa join oyun.profiller p on p.id = pa.gb
             where not pa.kapali and coalesce(p.son_gorulme, p.olusturma) < t - make_interval(days => gs)
               and exists (select 1 from oyun.ihmal_uyari u where u.user_id = pa.gb and u.tur = 'secim' and u.zaman <= t - interval '2 days' and u.zaman > coalesce(p.son_gorulme, '-infinity')) loop
      update oyun.partiler set gb = null where id = r.id;
      sec := oyun.ara_secim_olustur('gb', r.id, null, t);
      perform oyun.bildir(r.gb, format('%s gündür oyuna girmediğin için %s Genel Başkanlığın sona erdi.', gs, r.ad), t);
      insert into oyun.bildirimler(user_id, zaman, metin)
        select id, t, format('%s Genel Başkanı %s gündür ortada olmadığı için görevden düştü. Olağanüstü kurultay başladı; genel başkanlığı üstlenebilir ya da aday olabilirsin.', r.ad, gs)
        from oyun.profiller where parti_id = r.id and id <> r.gb;
      perform oyun.olay('parti', format('%s, %s Genel Başkanlığından ihmal nedeniyle düştü. Olağanüstü kurultay takvimi oluşturuldu.', r.kad, r.ad), null, r.id, t);
    end loop;
    insert into oyun.ihmal_uyari(user_id, tur, zaman)
      select x.user_id, 'secim', t from (
        select m.user_id from oyun.makamlar m join oyun.profiller p on p.id = m.user_id
          where m.tur in ('cb','bel') and m.bit is null and coalesce(p.son_gorulme, m.bas) < t - make_interval(days => gs) + interval '2 days'
        union select pa.gb from oyun.partiler pa join oyun.profiller p on p.id = pa.gb
          where not pa.kapali and coalesce(p.son_gorulme, p.olusturma) < t - make_interval(days => gs) + interval '2 days') x
      where not exists (select 1 from oyun.ihmal_uyari u join oyun.profiller p on p.id = u.user_id where u.user_id = x.user_id and u.tur = 'secim' and u.zaman > coalesce(p.son_gorulme, '-infinity'))
      on conflict (user_id, tur) do update set zaman = excluded.zaman;
  end if;
end $function$;
