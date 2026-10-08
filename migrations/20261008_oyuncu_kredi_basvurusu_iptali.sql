-- Oyuncunun bekleyen kredi başvurusunu iptal etmesi.
-- Onay/ret işlemiyle aynı kilit sırası kullanılır: banka -> başvuru.
alter table oyun.oyb_kredi drop constraint if exists oyb_kredi_durum_check;
alter table oyun.oyb_kredi add constraint oyb_kredi_durum_check
 check (durum in ('basvuru','aktif','reddedildi','odendi','iptal'));

create or replace function public.oyb_kredi_basvuru_iptal(p_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_uid uuid:=auth.uid(); v_kredi oyun.oyb_kredi; v_banka oyun.sirketler; v_t timestamptz:=oyun.simdi();
begin
 if v_uid is null then raise exception 'Oturum açmalısın'; end if;
 if p_id is null then raise exception 'Başvuru seçilmedi'; end if;
 select * into v_kredi from oyun.oyb_kredi
 where id=p_id and borclu=v_uid;
 if not found then raise exception 'Bu kredi başvurusu sana ait değil'; end if;
 select * into v_banka from oyun.sirketler where id=v_kredi.banka_id for update;
 if not found then raise exception 'Banka bulunamadı'; end if;
 select * into v_kredi from oyun.oyb_kredi where id=p_id and borclu=v_uid for update;
 if v_kredi.durum<>'basvuru' then
  raise exception 'Başvuru artık beklemede değil. Onaylanan, reddedilen veya iptal edilen başvurular iptal edilemez.';
 end if;
 update oyun.oyb_kredi
 set durum='iptal',kapanis=v_t
 where id=p_id and borclu=v_uid and durum='basvuru';
 if not found then raise exception 'Başvuru artık beklemede değil'; end if;
 -- Kredi henüz kullandırılmadığı için cüzdan veya banka kasası değişmez.
 return jsonb_build_object('tamam',true,'id',p_id,'durum','iptal','tarih',v_t);
end $function$;

revoke all on function public.oyb_kredi_basvuru_iptal(bigint) from public,anon;
grant execute on function public.oyb_kredi_basvuru_iptal(bigint) to authenticated;
