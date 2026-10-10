-- Milletvekili, bakan olarak atandiginda vekilligi sona ermez.
-- Sadece mv/bakan rol eslesmesi acilir; diger gorev uyumsuzluklari korunur.
create or replace function oyun.rol_uyumlu(a text, b text)
returns boolean language sql immutable as $$
  select (a=b and a in ('gb','gby')) or (a,b) in
  (('mv','gby'),('gby','mv'),('gb','mv'),('mv','gb'),
   ('gb','cb'),('cb','gb'),('mv','tbmm'),('tbmm','mv'),
   ('mv','bskv'),('bskv','mv'),('mv','grup_bskv'),('grup_bskv','mv'),
   ('gby','grup_bskv'),('grup_bskv','gby'),
   ('mv','bakan'),('bakan','mv'))
$$;
