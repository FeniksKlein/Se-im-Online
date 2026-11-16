-- Read-only live establishment fees and opening requirements.
-- All permissions, currency debits and quotas remain validated by existing write RPCs.
CREATE OR REPLACE FUNCTION public.kurulus_canli_kurallar()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object(
  'sektorler', coalesce((select jsonb_object_agg(k.kod, k.min_sermaye) from oyun.pazar_sektor k), '{}'::jsonb),
  'banka_min', oyun.tf('banka_min'),
  'ajans_min', oyun.tf('ajans_min'),
  'meslek_min', oyun.tf('meslek_min'),
  'dernek_ucret', oyun.dernek_harci(),
  'dergi_ucret', oyun.gazete_kur_ucreti(),
  'gazete_ucret', oyun.gazete_kur_ucreti(),
  'parti_harc', oyun.parti_kur_ucreti(),
  'parti_fon', oyun.tf_tl('parti_fon'),
  'tv_lisans_ucret', 250000,
  'hukuk_buro_ucret', 250000,
  'sendika_ucret', 50000,
  'sirket_statu', oyun.tf('sirket_statu'),
  'ajans_statu', oyun.tf('ajans_statu'),
  'banka_statu', oyun.tf('banka_statu'),
  'dernek_statu', oyun.tf('dernek_statu'),
  'gazete_statu', oyun.tf('gazete_statu'),
  'parti_kurucu_statu', oyun.tf('parti_kurucu_statu'),
  'parti_kurucu_sayi', oyun.parti_kurucu_gerekli(),
  'parti_hesap_gun', oyun.tf('parti_kurucu_hesap_gun'),
  'sirket_limiti', jsonb_build_object(
    '0', oyun.tf('slot_0'), '1', oyun.tf('slot_1'),
    '2', oyun.tf('slot_2'), '3', oyun.tf('slot_3'),
    '4', oyun.tf('slot_4'), '5', oyun.tf('slot_5')
  )
 )
$function$;
revoke all on function public.kurulus_canli_kurallar() from PUBLIC;
grant execute on function public.kurulus_canli_kurallar() to authenticated;
comment on function public.kurulus_canli_kurallar() is 'Read-only live establishment fee and restriction guide for clients; financial RPCs remain sole authority.';
