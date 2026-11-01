#!/usr/bin/env python3
"""İstemcinin çağırdığı public RPC adlarını ve admin_* gövdelerini çıkarır."""
import re
from pathlib import Path

KOK = Path(__file__).resolve().parents[2]
AD = re.compile(r"^[a-z][a-z0-9_]{1,63}$")
HIZMET = {"push_al", "push_bitti", "odeme_isle", "meslek_kur_kaydet", "reklam_ssv_isle"}

def dosyalar():
    kokler = [
        KOK / "gelistirici/www",
        KOK / "www",
        KOK / "docs",
        KOK / "support",
        KOK / "gelistirici/supabase/functions",
        KOK / "supabase/functions",
    ]
    ekstra = [KOK / "push-gonder.ts", KOK / "odeme-webhook.ts"]
    gor = []
    for k in kokler:
        if not k.exists():
            continue
        for p in k.rglob("*"):
            if p.suffix.lower() in {".js", ".mjs", ".html", ".ts"} and p.is_file():
                if "/test/" in str(p):
                    continue
                gor.append(p)
    for p in ekstra:
        if p.exists():
            gor.append(p)
    return gor

def yorum_sil(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c in "'\"`":
            q = c
            out.append(c); i += 1
            while i < n:
                out.append(src[i])
                if src[i] == "\\":
                    if i + 1 < n:
                        out.append(src[i + 1]); i += 2; continue
                if src[i] == q:
                    i += 1; break
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            i += 2
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i = min(n, i + 2)
            out.append(" ")
            continue
        out.append(c); i += 1
    return "".join(out)

def metinler(expr):
    """Üçlü ifadenin sonuç dallarındaki stringler (koşul metinleri değil)."""
    return re.findall(r"""(?:^|[?:])\s*['"]([a-z][a-z0-9_]{1,63})['"]""", expr.strip())

def arg_ifadesi(src, par_ac):
    """par_ac, '(' konumudur. İlk argümanı (üst seviye virgüle kadar) döndürür."""
    i = par_ac + 1
    n = len(src)
    der = 0
    bas = i
    while i < n:
        c = src[i]
        if c in "'\"`":
            q = c; i += 1
            while i < n:
                if src[i] == "\\":
                    i += 2; continue
                if src[i] == q:
                    i += 1; break
                i += 1
            continue
        if c in "([{":
            der += 1
        elif c in ")]}":
            if der == 0:
                return src[bas:i]
            der -= 1
        elif c == "," and der == 0:
            return src[bas:i]
        i += 1
    return src[bas:n]

def cagri_bul(src, callee):
    """callee tam metin ('API.rpc' veya 'RPC'). Dönüş: (başlangıç, ilk_arg)."""
    bul = []
    i = 0
    while True:
        j = src.find(callee, i)
        if j < 0:
            break
        once = src[j - 1] if j else ""
        if callee[0].isalpha() and (once.isalnum() or once in "_.$"):
            i = j + 1
            continue
        k = j + len(callee)
        while k < len(src) and src[k] in " \t\r\n":
            k += 1
        if k < len(src) and src[k] == "(":
            bul.append((j, arg_ifadesi(src, k).strip()))
        i = j + len(callee)
    return bul

def _govde(src, bas, ok_ifadesi=True):
    i = bas
    while i < len(src) and src[i] in " \t\r\n":
        i += 1
    if i < len(src) and src[i] == "{":
        der, j = 0, i
        while j < len(src):
            c = src[j]
            if c in "'\"`":
                q = c; j += 1
                while j < len(src):
                    if src[j] == "\\":
                        j += 2; continue
                    if src[j] == q:
                        j += 1; break
                    j += 1
                continue
            if c == "{":
                der += 1
            elif c == "}":
                der -= 1
                if der == 0:
                    return src[i:j + 1]
            j += 1
        return src[i:]
    if ok_ifadesi:
        return src[i:i + 400]
    return ""

def sarmalayicilar(src):
    """İlk parametresini (doğrudan ya da başka bir sarmalayıcı üzerinden) RPC adına veren yerel fonksiyonlar."""
    tanim = []  # (ad, p0, govde)
    for m in re.finditer(
        r"(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:function\s*)?\(\s*([A-Za-z_$][\w$]*)",
        src,
    ):
        ok = src.find("=>", m.end())
        if ok < 0 or ok - m.end() > 80:
            continue
        tanim.append((m.group(1), m.group(2), _govde(src, ok + 2)))
    for m in re.finditer(r"(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(\s*([A-Za-z_$][\w$]*)", src):
        k = src.find("{", m.end())
        if k < 0 or k - m.end() > 40:
            continue
        tanim.append((m.group(1), m.group(2), _govde(src, k, ok_ifadesi=False)))
    kok = ["API.rpc", "sb.rpc", "supabase.rpc"]
    adlar = set()
    degisti = True
    while degisti:
        degisti = False
        hedefler = kok + sorted(adlar)
        for ad, p0, govde in tanim:
            if ad in adlar:
                continue
            for h in hedefler:
                # Parametre RPC adı olarak geçmeli (API.rpc(ad) / API.rpc(ad, ...) / API.rpc(ad.alan)).
                # API.rpc(ad === "hizmet" ? ...) gibi koşul kullanımı sarmalayıcı sayılmaz.
                if re.search(
                    rf"(?:^|[^\w$.]){re.escape(h)}\(\s*{re.escape(p0)}\b\s*(?:[),.]|\?\?|\|\|)",
                    govde,
                ):
                    adlar.add(ad)
                    degisti = True
                    break
    return adlar

def atama_metinleri(src, ad, konum, pencere=2500):
    """Çağrıdan hemen önceki atamalardaki dal stringleri."""
    bulunan = []
    bolge = src[max(0, konum - pencere): konum]
    for m in re.finditer(
        rf"(?:^|[^\w$])(?:const|let|var)?\s*{re.escape(ad)}\s*=\s*",
        bolge,
    ):
        k = m.end()
        i, n, der = k, len(bolge), 0
        while i < n:
            c = bolge[i]
            if c in "'\"`":
                q = c; i += 1
                while i < n:
                    if bolge[i] == "\\":
                        i += 2; continue
                    if bolge[i] == q:
                        i += 1; break
                    i += 1
                continue
            if c in "([{":
                der += 1
            elif c in ")]}":
                if der == 0:
                    break
                der -= 1
            elif c in ";\n" and der == 0:
                break
            i += 1
        bulunan.extend(metinler(bolge[k:i]))
    return bulunan

def yuk_listeleri(src):
    adlar = set()
    for m in re.finditer(r"new Set\(\s*[\"']([^\"']+)[\"']\s*\.split", src):
        for a in m.group(1).split(","):
            a = a.strip()
            if AD.match(a):
                adlar.add(a)
    # SURE nesnesinin anahtarları
    m = re.search(r"const SURE = \{", src)
    if m:
        i = src.find("{", m.start())
        der, j = 0, i
        while j < len(src):
            if src[j] == "{":
                der += 1
            elif src[j] == "}":
                der -= 1
                if der == 0:
                    break
            j += 1
        blok = src[i:j]
        for a in re.findall(r"\b([a-z][a-z0-9_]{1,63})\s*:", blok):
            if AD.match(a) and a not in {"true", "false", "null"}:
                adlar.add(a)
    return adlar

def public_fonksiyonlar():
    adlar = {}
    kok = KOK / "gelistirici/sql"
    for p in kok.glob("*.sql"):
        metin = p.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(
            r"create\s+(?:or\s+replace\s+)?function\s+public\.([a-z][a-z0-9_]{1,63})\s*\(",
            metin,
            re.I,
        ):
            adlar.setdefault(m.group(1).lower(), set()).add(p.name)
    return adlar

def admin_govdeler():
    """Son tanıma göre admin_* gövdesinde yetki kapısı var mı."""
    son = {}
    for p in (KOK / "gelistirici/sql").glob("*.sql"):
        metin = p.read_text(encoding="utf-8", errors="replace")
        # kaba: create function ... $$ ... $$
        for m in re.finditer(
            r"create\s+(?:or\s+replace\s+)?function\s+public\.(admin_[a-z0-9_]+)\s*\((.*?)\)\s*returns\b",
            metin,
            re.I | re.S,
        ):
            ad = m.group(1).lower()
            # gövde: sonraki $$ veya $tag$
            geri = metin[m.end(): m.end() + 8000]
            q = re.search(r"\$([A-Za-z0-9_]*)\$", geri)
            if not q:
                continue
            tag = q.group(0)
            a = q.end()
            b = geri.find(tag, a)
            if b < 0:
                continue
            govde = geri[a:b]
            bas = govde[:1800]
            kapi = bool(re.search(r"yetki_zorunlu\s*\(|yonetici_zorunlu\s*\(", bas))
            son[ad] = {"dosya": p.name, "kapi": kapi, "bas": " ".join(bas.split())[:240]}
    return son

def tara():
    public = public_fonksiyonlar()
    kanit = {}  # ad -> set of "kaynak: dosya"

    def ekle(ad, kaynak, dosya):
        if not AD.match(ad):
            return
        kanit.setdefault(ad, set()).add(f"{kaynak}:{dosya}")

    for p in dosyalar():
        ham = p.read_text(encoding="utf-8", errors="replace")
        src = yorum_sil(ham)
        goreli = str(p.relative_to(KOK))
        # kenar fonksiyonları ayrı etiket
        kenar = "supabase/functions" in goreli or p.name in {"push-gonder.ts", "odeme-webhook.ts"}
        sarm = sarmalayicilar(src)
        calleeler = ["API.rpc", "sb.rpc", "supabase.rpc"] + sorted(sarm, key=len, reverse=True)
        for cal in calleeler:
            for yer, arg in cagri_bul(src, cal):
                sabit = metinler(arg)
                if sabit:
                    for a in sabit:
                        ekle(a, "kenar" if kenar else "cagri", goreli)
                    if not re.match(r"^([A-Za-z_$][\w$]*)(?:\.([A-Za-z_$][\w$]*))?$", arg):
                        continue
                # düz kimlik veya kimlik.ozellik
                m = re.match(r"^([A-Za-z_$][\w$]*)(?:\.([A-Za-z_$][\w$]*))?$", arg)
                mb = re.match(r"^([A-Za-z_$][\w$]*)\s*\[", arg)
                if mb:
                    sozluk = mb.group(1)
                    for mm in re.finditer(
                        rf"(?:const|let|var)\s+{re.escape(sozluk)}\s*=\s*\{{",
                        src,
                    ):
                        blok = _govde(src, mm.end() - 1, ok_ifadesi=False)
                        for a in re.findall(r""":\s*['"]([a-z][a-z0-9_]{1,63})['"]""", blok):
                            ekle(a, "sozluk", goreli)
                if m and not m.group(2):
                    for a in atama_metinleri(src, m.group(1), yer):
                        ekle(a, "degisken", goreli)
                elif m and m.group(2):
                    # nesne özelliği: ad: "fonksiyon"
                    oz = m.group(2)
                    for a in re.findall(rf"""\b{re.escape(oz)}\s*:\s*['"]([a-z][a-z0-9_]{{1,63}})['"]""", src):
                        if a in public or not public:
                            ekle(a, "ozellik", goreli)
        # basinForm(..., 'rpc_adi',
        if "basinForm" in src:
            for _, arg in []:
                pass
            # 4. argüman string
            for m in re.finditer(r"\bbasinForm\s*\(", src):
                # tüm argümanları böl
                k = m.end() - 1
                gov = arg_ifadesi  # ilk
                # manuel böl
                i = k + 1
                parcalar = []
                n = len(src)
                der = 0
                bas = i
                while i < n:
                    c = src[i]
                    if c in "'\"`":
                        q = c; i += 1
                        while i < n:
                            if src[i] == "\\":
                                i += 2; continue
                            if src[i] == q:
                                i += 1; break
                            i += 1
                        continue
                    if c in "([{":
                        der += 1
                    elif c in ")]}":
                        if der == 0:
                            parcalar.append(src[bas:i].strip()); break
                        der -= 1
                    elif c == "," and der == 0:
                        parcalar.append(src[bas:i].strip()); bas = i + 1
                    i += 1
                if len(parcalar) >= 4:
                    for a in metinler(parcalar[3]):
                        ekle(a, "basinForm", goreli)
        for a in yuk_listeleri(src):
            ekle(a, "onbellek", goreli)
        # rest/v1/rpc/ad
        for a in re.findall(r"/rest/v1/rpc/([a-z][a-z0-9_]{1,63})", src):
            ekle(a, "kenar" if kenar else "rest", goreli)

    # Yalnızca public katalogda olan 'ozellik' kanıtlarını tut; katalogda yoksa da tut (canlıda olabilir)
    # ama çok genel Türkçe kelimeleri ele: katalog kesişimi olmayan özellik kanıtı şüpheli
    suphe = {}
    kesin = {}
    for ad, kaynaklar in kanit.items():
        turler = {k.split(":")[0] for k in kaynaklar}
        if turler <= {"ozellik", "sozluk", "degisken", "onbellek"} and ad not in public and "_" not in ad:
            suphe[ad] = kaynaklar
        elif turler <= {"onbellek"} and ad not in public:
            suphe[ad] = kaynaklar
        else:
            kesin[ad] = kaynaklar
    return public, kesin, suphe, admin_govdeler()

# Mağaza sürümündeki eski uygulamanın hâlâ çağırdığı, güncel kaynakta birebir yazılmayan adlar.
ESKI_UYGULAMA = {
    "mulk_satin_al": "gelistirici/sql/45_emlak_temizlik.sql (eski uygulamanın tek parametreli çağrısı)",
    "halka_arz_baslat": "gelistirici/sql/128_halka_arz_gercekci.sql (mağaza uygulamasının imzası korunur)",
}
# Bu dalda henüz yok. PR #40 istemciye ekliyor; kilit en sonda çalışınca grant'ı ezmesin.
PARALEL_PR = {
    "reklam_hazirla": "PR #40 public.reklam_hazirla() — yalnız authenticated",
}
ANON_IZIN = ("surum", "uygulama_ayar")

def sonuc():
    """authenticated izin listesi ve kanıtları. Hizmet rolüne özel adlar listede yoktur."""
    public, kesin, suphe, admin = tara()
    istemci, kenar = {}, {}
    for ad, k in kesin.items():
        if ad in HIZMET or all(x.startswith("kenar:") for x in k):
            kenar[ad] = k
        else:
            istemci[ad] = k
    for ad in HIZMET:
        kenar.setdefault(ad, {"kenar:edge"})
    onbellek = {a: k for a, k in suphe.items() if any(x.startswith("onbellek:") for x in k)}
    kanit = dict(istemci)
    kanit.update(onbellek)
    for ad, nerede in ESKI_UYGULAMA.items():
        kanit.setdefault(ad, set()).add("eski:" + nerede)
    for ad, nerede in PARALEL_PR.items():
        kanit.setdefault(ad, set()).add("paralel:" + nerede)
    izin = set(kanit) - set(HIZMET)
    return {
        "izin": izin,
        "kanit": {a: sorted(kanit[a]) for a in sorted(izin)},
        "hizmet": sorted(HIZMET),
        "anon": list(ANON_IZIN),
        "admin": admin,
        "public_katalog": public,
        "suphe_diger": {a: sorted(k) for a, k in suphe.items() if a not in onbellek},
    }

def main():
    s = sonuc()
    eksik = [a for a, b in s["admin"].items() if not b["kapi"]]
    print("izin", len(s["izin"]), "anon", s["anon"], "hizmet", s["hizmet"])
    print("admin kapi eksik", eksik or "yok")
    print("katalogda olmayan izin", sorted(a for a in s["izin"] if a not in s["public_katalog"]))

if __name__ == "__main__":
    main()
