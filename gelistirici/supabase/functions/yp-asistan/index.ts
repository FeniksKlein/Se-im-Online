// Süper yönetici portalı · yapay zekâ asistanı (Aşama 6)
//
// Güvenlik:
//  • Yalnız oyunun sahibi kullanabilir: her istekte sahibin kendi oturumuyla public.yp_ben() çağrılır;
//    yönetici değilse veritabanı reddeder. Service role anahtarı KULLANILMAZ.
//  • Asistan yalnız aşağıdaki yp_* okuma fonksiyonlarını ve yp_onizle'yi çağırabilir. Serbest SQL yok.
//  • yp_uygula'yı asla çağırmaz: değişiklik gerekiyorsa ön izleme hazırlar, portal bunu sahibine gösterir,
//    uygulamaya sahibi kendi karar verir (kritik işlemlerde "ONAYLIYORUM" yazarak).
//  • Her soru / yanıt / araç / ön izleme public.yp_asistan_kaydet ile oyun.yp_asistan_kayit'a yazılır.
//
// Gereken gizli ayar: ANTHROPIC_API_KEY (Supabase › Edge Functions › Secrets). İsteğe bağlı: ASISTAN_MODEL.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
};
const j = (v: unknown, status = 200) =>
  new Response(JSON.stringify(v), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...CORS } });

const ISLEMLER = [
  "secim_takvim", "secim_simdi_baslat", "secim_uzat", "secim_oylamayi_bitir", "genel_secim_olustur", "mv_toplu_adaylik",
  "adaylik_iptal", "cb_adaylari_mv_den_cikar", "oyuncu_para", "oyuncu_kidem", "oyuncu_il", "oyuncu_parti", "makam_ver",
  "makam_al", "hesap_engelle", "engel_kaldir", "sustur", "oyuncu_bildirim", "ayar_degistir", "kurum_kasa", "parti_duzenle",
  "duyuru_yayinla", "olay_baslat", "sikayet_karar", "destek_yanitla", "yedek_al", "geri_al",
];

type Arac = { ad: string; rpc: string; aciklama: string; girdi: Record<string, unknown>; esle: (g: any) => Record<string, unknown> };
const nesne = (props: Record<string, unknown> = {}, gerekli: string[] = []) => ({ type: "object", properties: props, required: gerekli });
const ARACLAR: Arac[] = [
  { ad: "pano", rpc: "yp_pano", aciklama: "Kontrol merkezi özeti: oyuncu sayıları, yaklaşan/süren seçimler, boş pusula uyarısı.", girdi: nesne(), esle: () => ({}) },
  { ad: "sozluk", rpc: "yp_sozluk", aciklama: "İl, parti ve bakanlık kimlik listesi (id ↔ ad).", girdi: nesne(), esle: () => ({}) },
  { ad: "oyuncu_ara", rpc: "yp_oyuncu_ara", aciklama: "Kullanıcı adına göre oyuncu ara; user_id döner.", girdi: nesne({ ara: { type: "string" } }, ["ara"]), esle: (g) => ({ p_ara: g.ara, p_limit: 20 }) },
  { ad: "oyuncu_listesi", rpc: "yp_oyuncular", aciklama: "Filtreli oyuncu listesi. filtre: {ara, il_id, parti_id (0=bağımsız), durum: tum|herkes|cevrimici|aktif|pasif|yeni|makamli|susturulmus|engelli}. sira: kad|para|kidem|son_gorulme|olusturma.",
    girdi: nesne({ filtre: { type: "object" }, limit: { type: "integer" }, sira: { type: "string" } }), esle: (g) => ({ p_filtre: g.filtre || {}, p_limit: Math.min(g.limit || 50, 200), p_offset: 0, p_sira: g.sira || "kad" }) },
  { ad: "oyuncu_dosyasi", rpc: "yp_oyuncu", aciklama: "Tek oyuncunun dosyası: profil, para, görevler, adaylıklar, son işlemler.", girdi: nesne({ user_id: { type: "string" } }, ["user_id"]), esle: (g) => ({ p_user: g.user_id }) },
  { ad: "secimler", rpc: "yp_secimler", aciklama: "Seçim listesi (tumu=true geçmişi de getirir).", girdi: nesne({ tumu: { type: "boolean" } }), esle: (g) => ({ p_tumu: !!g.tumu }) },
  { ad: "secim", rpc: "yp_secim", aciklama: "Tek seçimin takvimi, adayları, katılım sayıları.", girdi: nesne({ id: { type: "integer" } }, ["id"]), esle: (g) => ({ p_id: g.id }) },
  { ad: "oy_teshis", rpc: "yp_oy_teshis", aciklama: "Bir seçimde oy kullanamayan oyuncuları ve nedenini gösterir (kime oy verildiği asla gösterilmez).",
    girdi: nesne({ secim_id: { type: "integer" }, kad: { type: "string" }, il_id: { type: "integer" } }, ["secim_id"]), esle: (g) => ({ p_secim: g.secim_id, p_kad: g.kad || null, p_il: g.il_id || null, p_sadece_sorunlu: !g.kad }) },
  { ad: "siyaset", rpc: "yp_siyaset", aciklama: "Partiler, ittifaklar, devlet görevlileri, meclis dağılımı, 81 il belediyesi.", girdi: nesne(), esle: () => ({}) },
  { ad: "parti", rpc: "yp_parti", aciklama: "Tek partinin dosyası.", girdi: nesne({ id: { type: "integer" } }, ["id"]), esle: (g) => ({ p_id: g.id }) },
  { ad: "ekonomi", rpc: "yp_ekonomi", aciklama: "Ekonomi göstergeleri, para arzı, bakanlık kasaları, büyük transferler, MASAK.", girdi: nesne(), esle: () => ({}) },
  { ad: "sirketler", rpc: "yp_sirketler", aciklama: "Şirket listesi (ad/sektör/kurucu ile aranabilir).", girdi: nesne({ ara: { type: "string" } }), esle: (g) => ({ p_ara: g.ara || null, p_limit: 50 }) },
  { ad: "ayarlar", rpc: "yp_ayarlar", aciklama: "Canlı ayar kataloğu: anahtar, şu anki değer, sınırlar, risk; planlı değişiklikler.", girdi: nesne(), esle: () => ({}) },
  { ad: "ayar_gecmisi", rpc: "yp_ayar_gecmis", aciklama: "Portal üzerinden yapılmış ayar değişiklikleri.", girdi: nesne({ anahtar: { type: "string" } }), esle: (g) => ({ p_anahtar: g.anahtar || null, p_limit: 30 }) },
  { ad: "duyurular", rpc: "yp_duyurular", aciklama: "Duyuru arşivi, planlı duyurular, duyuru bandı, telefon bildirimi durumu.", girdi: nesne(), esle: () => ({}) },
  { ad: "olaylar", rpc: "yp_olaylar", aciklama: "Kriz şablonları, süren krizler, kriz geçmişi, haber akışı.", girdi: nesne(), esle: () => ({}) },
  { ad: "destek", rpc: "yp_destek", aciklama: "Şikâyetler, yönetime gelen özel mesajlar, destek talepleri.", girdi: nesne({ tumu: { type: "boolean" } }), esle: (g) => ({ p_durum: g.tumu ? "tum" : "acik" }) },
  { ad: "sistem", rpc: "yp_sistem", aciklama: "Sürüm, veritabanı boyutu, yedekler, zamanlanmış işler, motor hataları.", girdi: nesne(), esle: () => ({}) },
  { ad: "tutarlilik", rpc: "yp_tutarlilik", aciklama: "Veri tutarlılık kontrolleri ve bulunan sorunlar.", girdi: nesne(), esle: () => ({}) },
  { ad: "islem_gecmisi", rpc: "yp_islemler", aciklama: "Portaldan yapılan son yönetici işlemleri.", girdi: nesne({ limit: { type: "integer" } }), esle: (g) => ({ p_limit: Math.min(g.limit || 30, 100), p_offset: 0 }) },
];
const ONIZLE = {
  name: "islem_onizle",
  description: "Bir yönetici işleminin ÖN İZLEMESİNİ hazırlar (hiçbir şeyi değiştirmez). Sonuç sahibine kart olarak gösterilir; uygulamaya o karar verir. Ön izleme 15 dakika geçerlidir.",
  input_schema: nesne({ islem: { type: "string", enum: ISLEMLER }, parametre: { type: "object" } }, ["islem", "parametre"]),
};

function sistemMetni(): string {
  const simdi = new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", dateStyle: "full", timeStyle: "short" }).format(new Date());
  return `Sen "Seçim Simülasyonu Online" oyununun sahibine yardım eden yönetim asistanısın. Şu an Türkiye saatiyle ${simdi}.

KURALLAR
1. Oyun verisini yalnız araçlarla öğren. Tahmin etme, sayı ya da isim uydurma. Bilgi yoksa açıkça söyle.
2. Hiçbir değişikliği kendin uygulayamazsın. Değişiklik gerekiyorsa islem_onizle ile ön izleme hazırla. Portal bunu sahibine kart olarak gösterir; "Uygula" (kritik işlemlerde ONAYLIYORUM yazarak) sahibin kararıdır. Asla "yaptım", "uyguladım", "gönderdim" deme; "ön izlemesini hazırladım, kartı açıp kontrol ettikten sonra uygulayabilirsin" de.
3. Gizli oy ilkesi: kimin kime oy verdiğini öğrenmeye ya da tahmin etmeye çalışma. Araçlar yalnız katılım sayısı verir.
4. İsteği netleştir: hangi oyuncu, ne kadar, ne zaman belli değilse önce sor. Oyuncu kimliğini (user_id) oyuncu_ara ile bul; il/parti kimliğini sozluk ile bul.
5. Ön izleme "engel" döndürürse nedenini sade dille açıkla; düzeltilebiliyorsa parametreyi düzeltip yeniden dene.
6. Kritik ve geri alınamaz işlemlerde (kriz başlatma, parti değiştirme, görev verme/alma, toplu para, seçim başlatma/bitirme) riskleri ve geri alınıp alınamayacağını yaz.
7. Kısa ve sade Türkçe yaz; teknik terim, SQL ya da kod gösterme. Oyuncu parası ₺, Hazine ve bakanlık kasaları milyar ₺'dir.
8. Portaldan yapılamayan şeyleri (telefon bildirimi açmak, uygulamaya yeni düğme eklemek, yedekten geri dönmek, kod değişikliği) yapılabilirmiş gibi gösterme; teknik destek gerektiğini söyle.

İŞLEMLER VE PARAMETRELERİ (islem_onizle)
Oyuncu hedefi şunlardan biri: user_id | kullanicilar: [user_id…] | filtre: {ara, il_id, parti_id (0=bağımsız), durum}. Filtre yöneticiyi hiç kapsamaz; en fazla 2000 oyuncu.
- oyuncu_para: hedef + tutar (tam sayı ₺, eksi düşer), aciklama, bildir (bool)
- oyuncu_kidem: hedef + miktar (±, 2 ondalık), aciklama?, bildir
- oyuncu_bildirim: hedef + metin (3-500)
- sustur: hedef + saat (0 = kaldır), neden
- hesap_engelle: hedef + gun (0 = kalıcı), neden · engel_kaldir: hedef
- oyuncu_il: user_id + il_id, mod (duzeltme|tasinma), adaylik (tasi|iptal), bildir
- oyuncu_parti: user_id + parti_id (0 = bağımsız) — geri alınamaz
- makam_ver: user_id + tur (cb|cb_yardimcisi|bakan|tbmm|mv|bel|bskv|grup_bskv|gb|gby), il_id (mv/bel), bakanlik (bakan), sira (cb_yardimcisi 1-2, gby 1-6), tek_gorev (bool) — geri alınamaz
- makam_al: makam_id, neden? — geri alınamaz
- ayar_degistir: degisiklikler [{anahtar, deger}], neden (3-300), baslangic? (ISO), bitis? (ISO, süreli değişiklikte eski değere dönüş). Anahtarları ayarlar aracından al.
- kurum_kasa: tur (hazine|bakanlik|il|parti|sirket|dernek), id (hazine için yok; bakanlık için kod; il için il_id), tutar (hazine/bakanlık milyar ₺ ondalıklı, diğerleri tam ₺), aciklama
- parti_duzenle: parti_id + ad? kisa? renk? (#rrggbb)
- duyuru_yayinla: metin (3-600), kanallar ["kutu","haber"], hedef_il?, hedef_parti?, zaman? (ISO, en az 2 dk sonrası). Duyuru bandı için ayar_degistir ile uygulama.duyuru_bandi kullan.
- olay_baslat: tur (ulusal|ulke|belediye), kod (olaylar aracındaki şablon kodu), il_id (il kapsamlı ulusal kriz ve belediye krizinde) — geri alınamaz
- sikayet_karar: tur (mesaj|yayin|ozel|oyuncu), kayit_id, hedef (user_id), karar (yok_say|gizle|gizle_sustur1|gizle_sustur7)
- destek_yanitla: kaynak (talep|ozel), id (talep id ya da gelen mesajın id'si = destek aracındaki son_gelen), metin, kapat? (talep)
- yedek_al: aciklama
- secim_takvim: secim_id + değişecek alanlar: basvuru_bas, basvuru_bit, oy_bas, oy_bit, sonuc_at, goreve_bas (ISO); duyur (bool)
- secim_simdi_baslat / secim_oylamayi_bitir / cb_adaylari_mv_den_cikar: secim_id
- secim_uzat: secim_id, dakika
- genel_secim_olustur: on_gun, secim_gun (YYYY-AA-GG)
- mv_toplu_adaylik: secim_id + kullanicilar ya da il_id/parti_id filtresi, bagimsiz_dahil, cb_haric
- adaylik_iptal: aday_id
- geri_al: islem_id (İşlem geçmişindeki numara)`;
}

async function rpc(url: string, anon: string, token: string, fn: string, args: Record<string, unknown>) {
  const r = await fetch(`${url}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { "content-type": "application/json", apikey: anon, Authorization: "Bearer " + token },
    body: JSON.stringify(args),
  });
  const metin = await r.text();
  let veri: unknown = null;
  try { veri = metin ? JSON.parse(metin) : null; } catch { veri = metin; }
  if (!r.ok) {
    const m = (veri && typeof veri === "object" && "message" in (veri as any)) ? String((veri as any).message) : metin;
    throw new Error(m.replace(/^YP_[A-Z]+:\s*/, ""));
  }
  return veri;
}
const kisalt = (v: unknown, n = 14000) => { const s = JSON.stringify(v); return s.length > n ? s.slice(0, n) + `…(kısaltıldı; toplam ${s.length} karakter)` : s; };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return j({ hata: "Yalnız POST" }, 405);
  const token = (req.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");
  const url = Deno.env.get("SUPABASE_URL") || "", anon = Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!token || !url || !anon) return j({ hata: "Oturum gerekli." }, 401);

  // 1) Yalnız oyunun sahibi (yp_ben giriş yapan herkese yanıt verir; yönetici bayrağı ayrıca denetlenir)
  let ben: any = null;
  try { ben = await rpc(url, anon, token, "yp_ben", {}); } catch { ben = null; }
  if (!ben || ben.giris !== true || ben.yonetici !== true) return j({ hata: "Bu asistan yalnız oyunun sahibine açıktır." }, 403);

  let govde: any;
  try { govde = await req.json(); } catch { return j({ hata: "Geçersiz istek." }, 400); }
  const soru = String(govde?.soru || "").trim().slice(0, 4000);
  if (!soru) return j({ hata: "Soru boş." }, 400);
  const anahtar = Deno.env.get("ANTHROPIC_API_KEY");
  if (!anahtar) return j({ anahtar_yok: true, hata: "Asistanın çalışması için Anthropic API anahtarı henüz tanımlanmadı." }, 200);
  const model = Deno.env.get("ASISTAN_MODEL") || "claude-sonnet-5-5";

  const gecmis = (Array.isArray(govde?.gecmis) ? govde.gecmis : []).slice(-12)
    .filter((m: any) => (m?.rol === "user" || m?.rol === "assistant") && typeof m?.metin === "string" && m.metin.trim())
    .map((m: any) => ({ role: m.rol, content: m.metin.slice(0, 6000) }));
  while (gecmis.length && gecmis[0].role !== "user") gecmis.shift();
  const mesajlar: any[] = [...gecmis, { role: "user", content: soru }];
  const araclar = [...ARACLAR.map((a) => ({ name: a.ad, description: a.aciklama, input_schema: a.girdi })), ONIZLE];
  const kullanilan: { ad: string; girdi: unknown; hata?: string }[] = [];
  const onizlemeler: any[] = [];
  let yanit = "", girdiT = 0, ciktiT = 0, hata: string | null = null;

  try {
    for (let tur = 0; tur < 8; tur++) {
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "content-type": "application/json", "x-api-key": anahtar, "anthropic-version": "2023-06-01" },
        body: JSON.stringify({ model, max_tokens: 2000, system: sistemMetni(), tools: araclar, messages: mesajlar }),
      });
      const c: any = await r.json();
      if (!r.ok) throw new Error(c?.error?.message || `Yapay zekâ servisi hata verdi (${r.status}).`);
      girdiT += c.usage?.input_tokens || 0; ciktiT += c.usage?.output_tokens || 0;
      const metinler = (c.content || []).filter((b: any) => b.type === "text").map((b: any) => b.text);
      if (metinler.length) yanit = metinler.join("\n").trim();
      const istekler = (c.content || []).filter((b: any) => b.type === "tool_use");
      if (c.stop_reason !== "tool_use" || !istekler.length) break;
      mesajlar.push({ role: "assistant", content: c.content });
      const sonuclar: any[] = [];
      for (const b of istekler) {
        try {
          let veri: unknown;
          if (b.name === "islem_onizle") {
            const islem = String(b.input?.islem || "");
            if (!ISLEMLER.includes(islem)) throw new Error("Bu işlem asistana açık değil.");
            const o: any = await rpc(url, anon, token, "yp_onizle", { p_islem: islem, p_param: b.input?.parametre || {} });
            onizlemeler.push({ ...o, islem, parametre: b.input?.parametre || {} });
            const { etkilenen, haric, ...kisa } = o || {};
            veri = { ...kisa, etkilenen_sayisi: Array.isArray(etkilenen) ? etkilenen.length : undefined, etkilenen_ornek: Array.isArray(etkilenen) ? etkilenen.slice(0, 15) : undefined,
              not: o?.engel ? "Ön izleme engellendi; uygulanamaz." : "Ön izleme sahibine kart olarak gösterilecek. Uygulamak onun kararı." };
          } else {
            const a = ARACLAR.find((x) => x.ad === b.name);
            if (!a) throw new Error("Bilinmeyen araç.");
            veri = await rpc(url, anon, token, a.rpc, a.esle(b.input || {}));
          }
          kullanilan.push({ ad: b.name, girdi: b.input });
          sonuclar.push({ type: "tool_result", tool_use_id: b.id, content: kisalt(veri) });
        } catch (e) {
          const m = e instanceof Error ? e.message : String(e);
          kullanilan.push({ ad: b.name, girdi: b.input, hata: m });
          sonuclar.push({ type: "tool_result", tool_use_id: b.id, content: "Hata: " + m, is_error: true });
        }
      }
      mesajlar.push({ role: "user", content: sonuclar });
      if (tur === 7) yanit = (yanit ? yanit + "\n\n" : "") + "(Çok fazla adım gerekti; soruyu daha dar sorarsan daha iyi yanıt verebilirim.)";
    }
  } catch (e) {
    hata = e instanceof Error ? e.message : String(e);
  }

  const kart = onizlemeler.map((o) => ({ islem_id: o.islem_id, islem: o.islem, ozet: o.ozet, engel: o.engel || null }));
  let kayit: unknown = null;
  try {
    kayit = await rpc(url, anon, token, "yp_asistan_kaydet", { p_soru: soru, p_yanit: yanit || null, p_araclar: kullanilan.map((k) => ({ ad: k.ad, hata: k.hata || null })),
      p_onizlemeler: kart, p_model: model, p_girdi_token: girdiT, p_cikti_token: ciktiT, p_hata: hata });
  } catch { /* kayıt yazılamazsa yanıtı yine döndür */ }
  if (hata && !yanit) return j({ hata, kayit }, 200);
  return j({ yanit, onizlemeler, araclar: kullanilan.map((k) => k.ad), kayit, model, token: { girdi: girdiT, cikti: ciktiT }, hata });
});
