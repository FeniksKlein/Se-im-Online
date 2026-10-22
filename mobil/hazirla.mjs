// Capacitor yerel projelerini mağazaya hazırlar (npx cap add/sync'ten SONRA çalışır; iki kez çalışması güvenlidir).
// Android: AdMob uygulama kimliği, reklam kimliği izni, satın alma için launchMode, sürüm numaraları.
// iOS: AdMob kimliği, izleme izni metni, SKAdNetwork, şifreleme beyanı, ekran adı, sürüm numaraları.
import fs from "node:fs";
import path from "node:path";

const kok = path.dirname(new URL(import.meta.url).pathname);
const ayar = JSON.parse(fs.readFileSync(path.join(kok, "magaza.json"), "utf8"));
const ortam = (k, v) => (process.env[k] && process.env[k].trim()) || v;
const surumAdi = ortam("SURUM_ADI", ayar.surumAdi);
const surumKodu = parseInt(ortam("SURUM_KODU", String(ayar.surumKodu)), 10);
const admobAndroid = ortam("ADMOB_ANDROID_UYGULAMA", ayar.admobAndroidUygulama);
const admobIos = ortam("ADMOB_IOS_UYGULAMA", ayar.admobIosUygulama);
const kimlikDogru = (x) => /^ca-app-pub-\d{16}~\d{10}$/.test(x);
if (!kimlikDogru(admobAndroid) || !kimlikDogru(admobIos)) throw new Error("AdMob uygulama kimliği biçimi hatalı (ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY olmalı).");
const testMi = (x) => x.includes("3940256099942544");
const degistir = (dosya, fn) => { const d = fs.readFileSync(dosya, "utf8"); const y = fn(d); if (y !== d) fs.writeFileSync(dosya, y); return y !== d; };
const xmlKac = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// ---------------- Android ----------------
const and = path.join(kok, "android");
if (fs.existsSync(and)) {
  const manifest = path.join(and, "app/src/main/AndroidManifest.xml");
  degistir(manifest, (m) => {
    m = m.replace(/\s*<meta-data android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"[^>]*\/>/g, "");
    m = m.replace(/(<application\b[^>]*>)/, `$1\n        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="${admobAndroid}"/>`);
    if (!m.includes("com.google.android.gms.permission.AD_ID"))
      m = m.replace(/(<\/manifest>)/, `    <uses-permission android:name="com.google.android.gms.permission.AD_ID" />\n$1`);
    if (!m.includes("android.permission.INTERNET"))
      m = m.replace(/(<\/manifest>)/, `    <uses-permission android:name="android.permission.INTERNET" />\n$1`);
    // RevenueCat: banka doğrulaması için uygulama arka plana geçince satın alma iptal olmasın
    m = m.replace(/android:launchMode="singleTask"/g, 'android:launchMode="singleTop"');
    // Oyun dikey ekran için tasarlandı
    if (!/android:screenOrientation=/.test(m)) m = m.replace(/(<activity\b)/, '$1 android:screenOrientation="portrait"');
    return m;
  });
  const gradle = path.join(and, "app/build.gradle");
  degistir(gradle, (g) => g.replace(/versionCode\s+\d+/, `versionCode ${surumKodu}`).replace(/versionName\s+"[^"]*"/, `versionName "${surumAdi}"`));
  // Yayın derlemesinde küçültme kapalı (WebView uygulaması; eklentilerin yansıma kullanımı bozulmasın)
  degistir(gradle, (g) => g.replace(/minifyEnabled\s+true/g, "minifyEnabled false"));
  console.log(`Android hazır: ${surumAdi} (${surumKodu}) · AdMob ${admobAndroid}${testMi(admobAndroid) ? " [TEST KİMLİĞİ]" : ""}`);
}

// ---------------- iOS ----------------
const ios = path.join(kok, "ios/App");
if (fs.existsSync(ios)) {
  const plist = path.join(ios, "App/Info.plist");
  const anahtarSil = (p, k) => p.replace(new RegExp(`\\s*<key>${k}</key>\\s*(<string>[^<]*</string>|<true/>|<false/>|<array>[\\s\\S]*?</array>)`, "g"), "");
  degistir(plist, (p) => {
    for (const k of ["GADApplicationIdentifier", "NSUserTrackingUsageDescription", "SKAdNetworkItems", "ITSAppUsesNonExemptEncryption", "CFBundleDisplayName", "UISupportedInterfaceOrientations", "UISupportedInterfaceOrientations~ipad"]) p = anahtarSil(p, k);
    const ek = `
	<key>CFBundleDisplayName</key>
	<string>Seçim Online</string>
	<key>GADApplicationIdentifier</key>
	<string>${admobIos}</string>
	<key>NSUserTrackingUsageDescription</key>
	<string>${xmlKac(ayar.izlemeAciklamasi)}</string>
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
	<key>SKAdNetworkItems</key>
	<array>
		<dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
	</array>`;
    return p.replace(/<dict>/, "<dict>" + ek);
  });
  const pbx = path.join(ios, "App.xcodeproj/project.pbxproj");
  // Yalnız iPhone (iPad ekran görüntüsü zorunluluğu olmasın), sürüm numaraları
  degistir(pbx, (x) => x.replace(/MARKETING_VERSION = [^;]+;/g, `MARKETING_VERSION = ${surumAdi};`).replace(/CURRENT_PROJECT_VERSION = [^;]+;/g, `CURRENT_PROJECT_VERSION = ${surumKodu};`)
    .replace(/TARGETED_DEVICE_FAMILY = [^;]+;/g, "TARGETED_DEVICE_FAMILY = 1;"));
  console.log(`iOS hazır: ${surumAdi} (${surumKodu}) · AdMob ${admobIos}${testMi(admobIos) ? " [TEST KİMLİĞİ]" : ""}`);
}
