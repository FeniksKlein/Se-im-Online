// node gelistirici/test/meydan_ui.js
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const dosya=path.join(__dirname,'../../docs/halk-org-davet.js');
const www=path.join(__dirname,'../../www/halk-org-davet.js');
const src=fs.readFileSync(dosya,'utf8');
assert.equal(src,fs.readFileSync(www,'utf8'));
for(const s of ['Eylem sohbeti','Muhbir teklifi','İfşa et','İçeriden bilgi','Kırmızı hat','Canlı Türkiye kriz haritası','Meydanın hafızası','Halk jürisi','Boykot','Güvenilir','Taraflı','İstifa','Gensoru','Meşale','İmzasız destek mektubu','sokak_sohbet_yaz','sokak_meydan_islem','sokak_kriz_harita','postgres_changes']){
 assert.ok(src.includes(s),s);
}
const sql=fs.readFileSync(path.join(__dirname,'../../supabase/migrations/20261109183000_meydan_sohbet_muhbir.sql'),'utf8');
for(const s of ['sokak_sohbet_uye','create policy sokak_sohbet_oku','Eylem alanında bir muhbir var','Yanlış ifşa','BELGE','salt_cogunluk','kufurlu','sokak_denetim']) assert.ok(sql.includes(s),s);
console.log('PASS: meydan arayüzü ve şema metinleri');
