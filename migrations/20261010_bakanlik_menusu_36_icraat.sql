-- Bakanlık teklif görünürlüğü ve role özel icraatlar, 2026-10-10.
-- Mevcut oyuncu, makam ve teklif kayıtlarına dokunmaz.
create or replace function public.bakanlik_teklif_durumlari()
returns jsonb language sql stable security definer set search_path = '' as $fn$
 select coalesce(jsonb_agg(
  jsonb_build_object('id',t.id,'bakanlik',t.bakanlik,'aday',p.kad,'zaman',t.zaman)
  order by t.zaman desc),'[]'::jsonb)
 from oyun.bakan_teklifleri t
 join oyun.profiller p on p.id=t.aday
 where t.durum='bekliyor' and t.teklif_eden=oyun.yurutme_user();
$fn$;
revoke all on function public.bakanlik_teklif_durumlari() from public,anon;
grant execute on function public.bakanlik_teklif_durumlari() to authenticated;

create or replace function public.bakanlik_panellerim()
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare p oyun.profiller:=oyun.profilim(); t timestamptz:=oyun.simdi();
begin
 return coalesce((
  select jsonb_agg(
    oyun.bakanlik_panel_json(m.bakanlik,t) ||
      jsonb_build_object('politikalar',oyun.politika_listesi(m.bakanlik,t))
    order by b.sira)
  from oyun.makamlar m
  join oyun.bakanliklar b on b.kod=m.bakanlik
  where m.tur='bakan' and m.bit is null and m.user_id=p.id
 ),'[]'::jsonb);
end $fn$;
revoke all on function public.bakanlik_panellerim() from public,anon;
grant execute on function public.bakanlik_panellerim() to authenticated;

insert into oyun.icraatlar
 (kod,bakanlik,ad,aciklama,maliyet,bekleme_saat,il_gerekli,etki,oyuncu,sure_gun)
values
('adl_dijital','adalet','Dijital adliye ağı','Dava ve başvuru süreçlerini hızlandıran dijital adliye yatırımı.',7,72,true,'{"gelisim":2,"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('adl_hukuk_destek','adalet','Ücretsiz hukuk danışmanlığı','Dar gelirli yurttaşlara hukuki danışmanlık desteği.',3,168,false,'{"memnuniyet":0.8}'::jsonb,'[{"tur":"gecim","deger":4}]'::jsonb,7),
('adl_arabuluculuk','adalet','Arabuluculuk merkezleri','Hukuki uyuşmazlıklarda uzlaşmayı teşvik eden merkezler.',5,72,true,'{"gelisim":1,"memnuniyet":0.5}'::jsonb,'[]'::jsonb,null),
('dis_kultur','disisleri','Kültürel diplomasi haftası','Ülkenin dış tanıtımını ve turizm ilgisini güçlendirir.',4,168,false,'{"buyume":0.2,"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('dis_yatirim','disisleri','Yabancı yatırım heyeti','Seçilen ilde uluslararası yatırım heyeti ve iş forumu.',9,72,true,'{"gelisim":2,"buyume":0.2}'::jsonb,'[]'::jsonb,null),
('dis_egitim','disisleri','Uluslararası öğrenci değişimi','Öğrenci değişimi ve uluslararası ortak eğitim projeleri.',5,168,false,'{"memnuniyet":0.5}'::jsonb,'[{"tur":"kidem_x","deger":10}]'::jsonb,7),
('ic_trafik','icisleri','Trafik güvenliği seferberliği','Seçilen ilde yol güvenliği ve denetim çalışması.',4,72,true,'{"memnuniyet":0.5,"gelisim":1}'::jsonb,'[]'::jsonb,null),
('ic_afet_egitim','icisleri','Afet hazırlık tatbikatı','Afetlere hazırlık ve yerel koordinasyon kapasitesini güçlendirir.',3,72,true,'{"gelisim":1,"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('ic_kamu','icisleri','Kamu hizmet noktası','Seçilen ilde erişilebilir kamu hizmet noktaları açılır.',5,72,true,'{"gelisim":2,"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('mal_kobi','maliye','KOBİ finansman desteği','Küçük işletmelerin finansmana erişimini kolaylaştıran program.',6,168,false,'{"buyume":0.3,"hazine":-1}'::jsonb,'[]'::jsonb,null),
('mal_verim','maliye','Kamu harcama denetimi','Harcamalarda verimlilik sağlayan mali inceleme.',2,168,false,'{"hazine":5,"memnuniyet":0.2}'::jsonb,'[]'::jsonb,null),
('mal_esnaf','maliye','Esnaf vergi uyum desteği','Küçük işletmeler için muhasebe ve uyum destek programı.',4,168,false,'{"buyume":0.2,"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('sav_siber','savunma','Ulusal siber güvenlik ağı','Siber savunma ve kritik altyapı güvenliği yatırımı.',9,168,false,'{"buyume":0.1,"memnuniyet":0.4}'::jsonb,'[]'::jsonb,null),
('sav_egitim','savunma','Savunma teknolojileri eğitimi','Savunma sanayii alanında yeni uzmanlık programı.',6,168,false,'{"buyume":0.2}'::jsonb,'[{"tur":"kidem_x","deger":10}]'::jsonb,7),
('sav_lojistik','savunma','Savunma lojistik üssü','Seçilen ilde savunma lojistik yatırımı.',12,72,true,'{"gelisim":3,"buyume":0.1}'::jsonb,'[]'::jsonb,null),
('egt_tablet','egitim','Okullara teknoloji desteği','Seçilen ildeki okullara teknoloji altyapısı sağlanır.',7,72,true,'{"gelisim":2,"memnuniyet":0.5}'::jsonb,'[]'::jsonb,null),
('egt_ogretmen','egitim','Öğretmen gelişim programı','Eğitim kalitesine yönelik öğretmen gelişim programı.',5,168,false,'{"memnuniyet":0.5}'::jsonb,'[{"tur":"kidem_x","deger":10}]'::jsonb,7),
('egt_meslek','egitim','Mesleki eğitim merkezleri','Seçilen ilde mesleki eğitim merkezleri kurulması.',8,72,true,'{"gelisim":2,"issizlik":-0.1}'::jsonb,'[]'::jsonb,null),
('sag_mobil','saglik','Mobil sağlık ekipleri','Seçilen ilde sağlık hizmetlerine erişim artırılır.',5,72,true,'{"memnuniyet":0.6,"gelisim":1}'::jsonb,'[{"tur":"gecim","deger":4}]'::jsonb,7),
('sag_personel','saglik','Sağlık personeli destek paketi','Sağlık personeli ve hizmet kapasitesini güçlendirir.',6,168,false,'{"memnuniyet":0.7}'::jsonb,'[]'::jsonb,null),
('sag_tarama','saglik','Ücretsiz sağlık taraması','Ülke çapında koruyucu sağlık taramaları düzenlenir.',4,168,false,'{"memnuniyet":0.5}'::jsonb,'[{"tur":"gecim","deger":4}]'::jsonb,7),
('san_arge','sanayi','Ar-Ge teşvik fonu','Yeni teknolojilerin geliştirilmesi için Ar-Ge fonu.',9,168,false,'{"buyume":0.4,"hazine":-1}'::jsonb,'[]'::jsonb,null),
('san_yesil','sanayi','Yeşil üretim tesisleri','Seçilen ilde çevreci üretim altyapısı kurulur.',10,72,true,'{"gelisim":3,"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('san_modern','sanayi','Sanayi modernizasyon desteği','Verimlilik artırıcı üretim yatırımlarını destekler.',7,168,false,'{"buyume":0.3}'::jsonb,'[]'::jsonb,null),
('tic_tuketici','ticaret','Tüketici hakları denetimi','Piyasa denetimleri ve tüketici şikâyetleri için ekipler kurulur.',3,168,false,'{"memnuniyet":0.5,"enflasyon":-0.1}'::jsonb,'[]'::jsonb,null),
('tic_eticaret','ticaret','KOBİ e-ticaret programı','Esnafın çevrimiçi ticarete katılması desteklenir.',5,168,false,'{"buyume":0.3}'::jsonb,'[]'::jsonb,null),
('tic_lojistik','ticaret','Ticaret lojistik merkezi','Seçilen ilde lojistik kapasitesi artırılır.',9,72,true,'{"gelisim":3,"buyume":0.2}'::jsonb,'[]'::jsonb,null),
('tar_gubre','tarim','Çiftçiye girdi desteği','Tarımsal üretimde maliyetleri azaltan destek programı.',6,168,false,'{"enflasyon":-0.1,"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('tar_kooperatif','tarim','Tarımsal kooperatif tesisi','Seçilen ilde üretici kooperatifini destekleyen tesis.',8,72,true,'{"gelisim":2,"buyume":0.1}'::jsonb,'[]'::jsonb,null),
('tar_hayvan','tarim','Hayvancılık destek programı','Hayvancılık üretimi ve veteriner hizmetleri güçlendirilir.',6,168,false,'{"buyume":0.2,"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('ula_yol','ulastirma','Bölgesel yol yenileme','Seçilen ilde yolların ve ulaşım altyapısının yenilenmesi.',9,72,true,'{"gelisim":3,"memnuniyet":0.3}'::jsonb,'[]'::jsonb,null),
('ula_internet','ulastirma','Genişbant internet altyapısı','Seçilen ilde internet altyapısına yatırım.',8,72,true,'{"gelisim":2,"buyume":0.2}'::jsonb,'[]'::jsonb,null),
('ula_lojistik','ulastirma','Ulaşım güvenliği paketi','Ülke çapında toplu taşıma güvenliği ve verimlilik çalışması.',5,168,false,'{"memnuniyet":0.6}'::jsonb,'[]'::jsonb,null),
('cal_istihdam_fuar','calisma','İstihdam fuarları','Seçilen ilde iş arayanlar ve işverenler buluşturulur.',6,72,true,'{"issizlik":-0.1,"gelisim":1}'::jsonb,'[]'::jsonb,null),
('cal_ciraklik','calisma','Çıraklık ve meslek programı','Genç oyuncuların mesleki gelişimi desteklenir.',5,168,false,'{"issizlik":-0.1}'::jsonb,'[{"tur":"ucret_yeni","deger":5}]'::jsonb,7),
('cal_isguvenligi','calisma','İş güvenliği denetimi','İşyerlerinde çalışma koşulları denetimini güçlendirir.',4,168,false,'{"memnuniyet":0.6}'::jsonb,'[]'::jsonb,null)
on conflict (kod) do nothing;
