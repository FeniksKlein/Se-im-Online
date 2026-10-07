const fs=require("fs"),path=require("path"),assert=require("assert");
const kok=path.join(__dirname,"..");
const html=fs.readFileSync(path.join(kok,"www/index.html"),"utf8");
const sql=fs.readFileSync(path.join(kok,"sql","18_ara_secim_istifa.sql"),"utf8");
const surum=fs.readFileSync(path.join(kok,"SURUM"),"utf8").trim();
assert.strictEqual(surum,"2026.10.07-5");
for(const s of ["makamIstifa(\'gb\')","&quot;cb&quot;","&quot;tbmm&quot;","gorevIstifa(\'bel\')","s_il_","Olağanüstü"]) assert(html.includes(s),"arayüz eksik: "+s);
for(const s of ["oyun.ara_secim_olustur","public.istifa","oyun.tbmm_ara_secim","hedef_parti_id","hedef_il_id","oyun.push_hatirlatmalar"]) assert(sql.includes(s),"SQL eksik: "+s);
console.log("istifa + olağanüstü seçim kaynak testi geçti");
