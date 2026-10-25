// Kuyumcu/doviz burosu referans fiyatlari: TCMB (gunluk) ve Gold API (spot).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const out=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json",...cors}});
const url=Deno.env.get("SUPABASE_URL")||"",service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
async function rpc(name:string, data:unknown){
 const r=await fetch(url+"/rest/v1/rpc/"+name,{method:"POST",headers:{"apikey":service,"Authorization":"Bearer "+service,"Content-Type":"application/json"},body:JSON.stringify(data)});
 if(!r.ok) throw new Error("Kur kaydetme basarisiz: "+(await r.text()).slice(0,350));
 return r.json();
}
function currency(xml:string,code:string):number{
 const match=xml.match(new RegExp('<Currency\\b[^>]*(?:Kod|CurrencyCode)="'+code+'"[^>]*>([\\s\\S]*?)<\\/Currency>','i'));
 if(!match) throw new Error("TCMB "+code+" kuru bulunamadi");
 const val=(tag:string)=>Number((match[1].match(new RegExp("<"+tag+">([^<]+)</"+tag+">","i"))||[])[1]);
 const b=val("ForexBuying"),s=val("ForexSelling"),unit=val("Unit")||1;
 if(!Number.isFinite(b)||!Number.isFinite(s)||b<=0||s<=0) throw new Error("TCMB "+code+" degeri gecersiz");
 return (b+s)/(2*unit);
}
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("",{headers:cors});
 if(req.method!=="POST")return out({hata:"Yalniz POST desteklenir"},405);
 const token=(req.headers.get("authorization")||"").replace(/^Bearer /i,"");
 if(!token)return out({hata:"Giris gerekli"},401);
 try{
  // Edge JWT dogrulamasina ek olarak oturumu dogrula.
  const auth=await fetch(url+"/auth/v1/user",{headers:{"Authorization":"Bearer "+token,"apikey":service}});
  if(!auth.ok)return out({hata:"Oturum gecersiz"},401);
  const timeoutMs=12000;
  const load=async(u:string)=>{
   const controller=new AbortController();
   const tm=setTimeout(()=>controller.abort(),timeoutMs);
   try{const r=await fetch(u,{headers:{"Accept":"application/json,application/xml,text/xml,*/*"},signal:controller.signal});if(!r.ok)throw new Error("Piyasa veri saglayicisi yanit vermedi ("+r.status+")");return r;}finally{clearTimeout(tm)}
  };
  const [fx,metal]=await Promise.all([load("https://www.tcmb.gov.tr/kurlar/today.xml"),load("https://api.gold-api.com/price/XAU")]);
  const xml=await fx.text(),gold=await metal.json();
  const date=(xml.match(/Tarih="(\d{2})\.(\d{2})\.(\d{4})"/)||[]);
  const fxWhen=date.length===4?new Date(Date.UTC(Number(date[3]),Number(date[2])-1,Number(date[1]),12,30)):new Date(fx.headers.get("last-modified")||Date.now());
  if(!Number.isFinite(fxWhen.getTime()))throw new Error("TCMB tarih bilgisi gecersiz");
  const spotWhen=new Date(gold.updatedAt||"");
  if(!Number.isFinite(spotWhen.getTime()))throw new Error("Altin fiyat saati gecersiz");
  const usd=currency(xml,"USD");
  const ounce=Number(gold.price);
  if(!Number.isFinite(ounce)||ounce<=0||String(gold.currency).toUpperCase()!=="USD")throw new Error("Altin veri formatı gecersiz");
  const entries=[["USD",usd,"TCMB",fxWhen],["EUR",currency(xml,"EUR"),"TCMB",fxWhen],["GBP",currency(xml,"GBP"),"TCMB",fxWhen],["CHF",currency(xml,"CHF"),"TCMB",fxWhen],["ALTIN",ounce*usd/31.1034768,"Gold-API/TCMB",spotWhen]];
  await Promise.all(entries.map(async([kod,fiyat,kaynak,when])=>rpc("meslek_kur_kaydet",{p_kod:kod,p_fiyat:fiyat,p_kaynak:kaynak,p_veri_tarihi:(when as Date).toISOString()})));
  return out({ok:true,adet:entries.length,guncelleme:new Date().toISOString(),kaynak:"TCMB ve Gold API",uyari:"TCMB kuru gunluk gostergedir; ALTIN ons spot fiyatindan turetilmistir."});
 }catch(e){return out({ok:false,hata:String(e instanceof Error?e.message:e).slice(0,220)},503)}
});