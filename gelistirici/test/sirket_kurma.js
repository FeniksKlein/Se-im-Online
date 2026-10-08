const fs=require('fs'),path=require('path'),assert=require('assert');
const kok=path.join(__dirname,'..');
const ui=fs.readFileSync(path.join(kok,'www','index.html'),'utf8'),sql=fs.readFileSync(path.join(kok,'sql','28_sirket_banka_asgari.sql'),'utf8');
for(const s of ['function sirketOnizleme(','id="sir_kazanc_onizleme"','id="sir_alt_limit"','id="sir_sermaye_uyari"','Olası net kâr / zarar','sirketOnizleme();']) assert(ui.includes(s),'UI eksik '+s);
for(const s of ['v_yeni_id','pr.id=u','s2.id','st.id',"'sirket_asgari_sermaye',100000","'banka_asgari_sermaye',1000000"])assert(sql.includes(s),'SQL eksik '+s);
assert(!sql.includes('end $;'),'SQL dolar ayiricisi bozuk');
console.log('Sirket kurma kaynak kontrolleri basarili.');
