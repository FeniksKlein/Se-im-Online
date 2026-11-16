-- Bos baskanlikta tek kisinin kendi kendini genel baskan atamasi yasaktir; uyeler kurultay oylamasiyla secer.
create or replace function public.genel_baskanlik_uslen() returns jsonb language plpgsql security definer set search_path to '' as $f$
declare p oyun.profiller:=oyun.profilim(); pa oyun.partiler; s jsonb;
begin
 if p.id is null then raise exception 'Giris gerekli.';end if;
 select * into pa from oyun.partiler where id=p.parti_id and not kapali for update;
 if pa.id is null then raise exception 'Partiye uye olmalisin.';end if;
 if pa.gb is not null then raise exception 'Partinin genel baskani zaten bulunuyor.';end if;
 s:=oyun.ara_secim_olustur('gb',pa.id,null,oyun.simdi());
 return jsonb_build_object('tamam',true,'mesaj','Genel baskanlik kurultayda uyelerin oyu ile belirlenecek.','secim',s);
end $f$;
