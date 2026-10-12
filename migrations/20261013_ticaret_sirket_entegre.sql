-- Mağaza kategorileri ve mevcut inşaat şirketlerinin tek emlak sistemine entegrasyonu.
alter table oyun.eko_isletmeler add column if not exists magaza_kategori text not null default 'market';
alter table oyun.eko_isletmeler add column if not exists son_perakende timestamptz not null default now();
alter table oyun.eko_markalar drop constraint if exists eko_markalar_kategori_check;
alter table oyun.eko_markalar add constraint eko_markalar_kategori_check check (kategori in ('market','fastfood','kahve'));
alter table oyun.eko_markalar drop constraint if exists eko_markalar_kar_payi_check;
alter table oyun.eko_markalar add constraint eko_markalar_kar_payi_check check (kar_payi between 0 and 20);
alter table oyun.eko_franchise drop constraint if exists eko_franchise_kar_payi_check;
alter table oyun.eko_franchise add constraint eko_franchise_kar_payi_check check (kar_payi between 0 and 20);
alter table oyun.eko_isletmeler drop constraint if exists eko_isletmeler_magaza_kategori_check;
alter table oyun.eko_isletmeler add constraint eko_isletmeler_magaza_kategori_check check (magaza_kategori in ('market','fastfood','kahve'));
-- Önceden kurulmuş inşaat şirketlerini yine aynı şirket ID'si ile belediye arsası modülüne tanıt.
insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat)
select s.id,'insaat',coalesce(p.il_id,1),null,0,0
from oyun.sirketler s join oyun.profiller p on p.id=s.kurucu
where s.sektor='insaat' and s.aktif
on conflict(sirket_id) do nothing;
create or replace function oyun.eko_insaat_sirket_tanit()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
 if new.sektor='insaat' and new.aktif then
  insert into oyun.eko_isletmeler(sirket_id,tur,il_id,urun,uretim_fiyat,perakende_fiyat)
  values(new.id,'insaat',coalesce((select il_id from oyun.profiller where id=new.kurucu),1),null,0,0)
  on conflict (sirket_id) do nothing;
 end if;
 return new;
end $$;
drop trigger if exists eko_insaat_sirket_tanit on oyun.sirketler;
create trigger eko_insaat_sirket_tanit after insert or update of sektor on oyun.sirketler
for each row execute function oyun.eko_insaat_sirket_tanit();
-- İlgili şirketin ürün bazlı fiyatı fabrika tarafından değiştirilebilir; eski stok değişmez.
