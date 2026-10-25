// Kuyumcu / Doviz burosu gercek referans fiyatlari. Sadece oturum acmis oyuncular cagirsin.
// Kaynak: TCMB'nin son yayimladigi gunluk doviz bulteni + Gold-API ons spot fiyat.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const j=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{"content-type":"application/json; charset=utf-8","cache-control":"no-store","access-control-allow-origin":"*","access-control-allow-headers":"authorization, apikey, content-type","access-control-allow-methods":"POST, OPTIONS"}});
const re=(s:string,r:RegExp)=>r.exec(s)?.[1]||"";
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return j({ok:true});
 if(req.method!=="POST")return j({error:"Yalniz POST"},405);
 const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/i,"");
 if(!token)return j({error:"Oyuncu girisi gerekli"},401);
 const url=Deno.env.get("SUPABASE_URL"),secret=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),anon=Deno.env.get("SUPABASE_ANON_KEY");
 if(!url||!secret||!anon)return j({error:"Sunucu piyasa ayarlari eksik"},503);
 const user=await fetch(url+"/auth/v1/user",{headers:{Authorization:"Bearer "+token,apikey:anon}}).catch(()=>null);
 if(!user?.ok)return j({error:"Gecerli oyuncu oturumu gerekli"},401);
 try{
  const current=await fetch(url+"/rest/v1/rpc/meslek_panel",{method:"POST",headers:{"content-type":"application/json",apikey:anon,Authorization:"Bearer "+token},body:"{}"});
  if(current.ok){
   const data=await current.json(),last=(data.kurlar||[]).map((x:{guncelleme:string})=>Date.parse(x.guncelleme)).filter(Number.isFinite);
   if(last.length===5&&Date.now()-Math.min(...last)<5*60*1000)return j({ok:true,cached:true,kurlar:data.kurlar});
  }
  const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),9000);
  let xml="",gold:Record<string,unknown>={};
  try{
   const res=await Promise.all([fetch("https://www.tcmb.gov.tr/kurlar/today.xml",{signal:controller.signal}),fetch("https://api.gold-api.com/price/XAU",{signal:controller.signal})]);
   if(!res[0].ok||!res[1].ok)throw new Error("Piyasa veri saglayicilarina erisilemiyor");
   [xml,gold]=await Promise.all([res[0].text(),res[1].json()]);
  }finally{clearTimeout(timeout);}
  const tarih=re(xml,/<Tarih_Date[^>]*Tarih="([^"]+)"/);
  const [day,month,year]=tarih.split(".").map(Number);
  const bulletin=new Date(Date.UTC(year,month-1,day,12,30));
  if(!year||!Number.isFinite(bulletin.getTime())||bulletin.getTime()>Date.now()+86400000||Date.now()-bulletin.getTime()>10*86400000)throw new Error("TCMB bulteni guncel degil");
  const rates:Record<string,number>={};
  for(const kod of ["USD","EUR","GBP","CHF"]){
   const tag=xml.match(new RegExp('<Currency\\b[^>]*(?:Kod|CurrencyCode)="'+kod+'"[^>]*>([\\s\\S]*?)<\\/Currency>'))?.[1]||"";
   const sell=Number(re(tag,/<ForexSelling>\s*([0-9.,]+)\s*<\/ForexSelling>/).replace(",","."));
   const unit=Number(re(tag,/<Unit>\s*(\d+)\s*<\/Unit>/))||1;
   if(!Number.isFinite(sell)||sell<=0||!Number.isFinite(unit)||unit<=0)throw new Error(kod+" kuru alinamadi");
   rates[kod]=sell/unit;
  }
  const ons=Number(gold.price),goldUpdated=Date.parse(String(gold.updatedAt||""));
  if(!Number.isFinite(ons)||ons<100||ons>30000||!Number.isFinite(goldUpdated)||Date.now()-goldUpdated>96*3600000)throw new Error("Altin ons fiyat verisi guncel degil");
  rates.ALTIN=ons*rates.USD/31.1034768;
  // Tek kaynaktan alinan veriler atomik olmayan ardil RPC'lerle kaydedilir;
  // ayni veri saatiyle islemeye alinmadan once tum kodlar basarili olmali.
  const saved=[];
  for(const kod of ["USD","EUR","GBP","CHF","ALTIN"]){
   const src=kod==="ALTIN"?"Gold-API/TCMB":"TCMB";
   const t=kod==="ALTIN"?new Date(goldUpdated).toISOString():bulletin.toISOString();
   const response=await fetch(url+"/rest/v1/rpc/meslek_kur_kaydet",{
    method:"POST",headers:{"content-type":"application/json",apikey:secret,Authorization:"Bearer "+secret},
    body:JSON.stringify({p_kod:kod,p_fiyat:Number(rates[kod].toFixed(8)),p_kaynak:src,p_veri_tarihi:t})
   });
   if(!response.ok)throw new Error("Sunucuda kur guncellenemedi: "+kod);
   saved.push({kod,fiyat:rates[kod],kaynak:src,veri_tarihi:t});
  }
  return j({ok:true,cached:false,kurlar:saved});
 }catch(err){return j({error:String(err instanceof Error?err.message:err)},503);}
});