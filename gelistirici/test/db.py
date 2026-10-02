"""Yerel Postgres'e psql üzerinden konuşan küçük test yardımcısı."""
import json, subprocess, uuid

DB = ["psql", "-h", "/tmp", "-U", "postgres", "-d", "oyun_test", "-At", "-v", "ON_ERROR_STOP=1", "-q"]

class SqlHata(Exception):
    pass

def q(sql, uid=None):
    if uid:
        sql = f"select set_config('request.jwt.claim.sub', '{uid}', false);\n" + sql
    r = subprocess.run(DB + ["-c", sql], capture_output=True, text=True)
    if r.returncode != 0:
        msg = r.stderr.strip().split("\n")[0].replace("ERROR:  ", "")
        raise SqlHata(msg)
    lines = r.stdout.rstrip("\n").split("\n") if r.stdout.strip() else []
    if uid and lines: lines = lines[1:]
    return "\n".join(lines).strip()

def qj(sql, uid=None):
    o = q(sql, uid)
    return json.loads(o) if o else None

def rpc(uid, fn, *args):
    def lit(a):
        if a is None: return "null"
        if isinstance(a, (int, float)): return str(a)
        return "'" + str(a).replace("'", "''") + "'"
    return qj(f"select public.{fn}({', '.join(lit(a) for a in args)});", uid)

def saat(ts):
    """ts: '2026-10-06 10:00' Türkiye saati"""
    q(f"update oyun.ayarlar set test_simdi = '{ts}+03'; select oyun.tick();")

def kullanici_ekle(email):
    u = str(uuid.uuid4())
    q(f"insert into auth.users(id, email, email_confirmed_at) values ('{u}', '{email}', now());")
    return u

def hata_bekle(fonk, *args, icerir=None):
    try:
        fonk(*args)
    except SqlHata as e:
        if icerir and icerir not in str(e):
            raise AssertionError(f"Beklenen hata '{icerir}' değil: {e}")
        return str(e)
    raise AssertionError(f"Hata bekleniyordu ama olmadı: {args}")
