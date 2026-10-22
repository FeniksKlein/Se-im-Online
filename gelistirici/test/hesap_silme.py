"""Hesap silme (modül 114): oyun kaydı olmayan hesap tamamen silinir; oyun geçmişine bağlı hesap
kimliksizleştirilir (ad, e-posta, giriş bilgisi, oturum, cihaz izi, biyografi silinir)."""
from db import q, rpc, kullanici_ekle, hata_bekle

def ok(m): print("  ✓", m)
# Yerel auth taklidine Supabase'deki sütun ve tabloları ekle
q("""alter table auth.users add column if not exists phone text, add column if not exists encrypted_password text,
       add column if not exists raw_user_meta_data jsonb, add column if not exists banned_until timestamptz,
       add column if not exists email_change text, add column if not exists email_change_token_new text,
       add column if not exists recovery_token text, add column if not exists confirmation_token text;
     create table if not exists auth.identities(id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade, provider text);
     create table if not exists auth.sessions(id uuid primary key default gen_random_uuid(), user_id uuid references auth.users(id) on delete cascade);""")
q("update oyun.ayarlar set test_simdi = null")
IL = lambda ad: int(q(f"select id from oyun.iller where ad='{ad}'"))

def oyuncu(kad):
    u = kullanici_ekle(f"{kad.lower()}@t.com"); rpc(u, "profil_olustur", kad, IL("İzmir"))
    q(f"insert into auth.identities(user_id, provider) values ('{u}', 'email'); insert into auth.sessions(user_id) values ('{u}')")
    return u

temiz = oyuncu("TemizHesap")
rpc(temiz, "hesabimi_sil")
assert q(f"select count(*) from oyun.profiller where id='{temiz}'") == "0" and q(f"select count(*) from auth.users where id='{temiz}'") == "0"
ok("Oyun kaydı olmayan hesap tamamen siliniyor")

bagli = oyuncu("BagliHesap")
pa = q("select id from oyun.partiler where not kapali order by id limit 1")
q(f"insert into oyun.erken_secim_teklifleri(teklif_eden, parti_id, tur, gerekce, bas, bit) values ('{bagli}', {pa}, 'muhalefet_cagrisi', 'deneme', now(), now() + interval '1 day')")
q(f"insert into oyun.mesajlar(kanal, user_id, metin, zaman) values ('meydan', '{bagli}', 'merhaba', now())")
r = rpc(bagli, "hesabimi_sil")
assert r["silindi"] is True and r["tam"] is False, r
kad, yasakli = q(f"select kad || '|' || yasakli from oyun.profiller where id='{bagli}'").split("|")
assert kad.startswith("Silinmis_") and yasakli == "true", kad
assert q(f"select email from auth.users where id='{bagli}'") == f"{bagli}@silindi.invalid"
assert q(f"select banned_until = 'infinity' from auth.users where id='{bagli}'") == "t"
assert q(f"select count(*) from auth.identities where user_id='{bagli}'") == "0" and q(f"select count(*) from auth.sessions where user_id='{bagli}'") == "0"
assert q(f"select count(*) from oyun.mesajlar where user_id='{bagli}'") == "0"
assert q(f"select count(*) from oyun.erken_secim_teklifleri where teklif_eden='{bagli}'") == "1"   # oyun kaydı kalır
hata_bekle(rpc, bagli, "durum", icerir="Hesap sahibi tarafından silindi")
ok("Oyun geçmişine bağlı hesap kimliksizleştiriliyor; e-posta, oturum ve mesajlar siliniyor, giriş kapanıyor")
print("hesap_silme: hepsi geçti")
