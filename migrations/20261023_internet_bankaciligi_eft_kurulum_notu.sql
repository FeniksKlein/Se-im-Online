-- Secure cross-bank EFT. Applied in Supabase 2026-10-23.
-- The canonical function is public.ib_eft(bigint,bigint,text,numeric).
-- Full definition is preserved in the live database; this marker records the schema change.
select 'Internet bankaciligi EFT function installed' as durum;