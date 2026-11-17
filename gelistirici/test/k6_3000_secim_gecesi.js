// k6: 500 -> 1000 -> 3000 eszamanli sanal oyuncu, SADECE TEST ORTAMI.
// Kurulum: https://grafana.com/docs/k6/latest/set-up/install-k6/
// test-tokens.local.json: TEST ORTAMINDA URETILMIS ayri oyuncu JWT'leri. Git'e EKLEMEYIN.
// RUN_APPROVED=EVET zorunlu; canli projeye yonlendirmeyi bilincli olarak yasaklar.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';

const url = __ENV.TEST_RPC_URL || '';
const apiKey = __ENV.TEST_PUBLISHABLE_KEY || '';
if (__ENV.RUN_APPROVED !== 'EVET') throw new Error('Yuk testi icin RUN_APPROVED=EVET gerekli');
if (!url.startsWith('https://') || !url.endsWith('/rest/v1/rpc/durum')) throw new Error('Yalniz read-only durum RPC adresi');
if (!apiKey) throw new Error('Test publishable key gerekli');
if (url.includes('viewlouzlzxteygtnsgd.supabase.co')) throw new Error('Canli secim-online projesine yuk testi engellendi');
const jwt = new SharedArray('testing-tokens',()=>JSON.parse(open(__ENV.TEST_TOKENS_FILE || './test-tokens.local.json')));
if (jwt.length<3000) throw new Error('3000 farkli TEST hesabi JWT tokeni gereklidir');

export const options = {
  scenarios: {
    secim_gecesi: {
      executor:'ramping-vus',
      startVUs:0,
      stages:[
        { duration:'2m', target:500 },
        { duration:'3m', target:500 },
        { duration:'2m', target:1000 },
        { duration:'3m', target:1000 },
        { duration:'2m', target:3000 },
        { duration:'3m', target:3000 },
        { duration:'2m', target:0 }
      ],
      gracefulRampDown:'30s'
    }
  },
  thresholds:{
    http_req_failed:['rate<0.01'],
    http_req_duration:['p(95)<1500','p(99)<3000']
  }
};
export default function() {
  const token = jwt[(__VU-1)%jwt.length];
  const response = http.post(url, JSON.stringify({}), {
    headers:{
      apikey:apiKey,
      Authorization:'Bearer '+token,
      'Content-Type':'application/json'
    },
    tags:{endpoint:'durum_read_only'},
    timeout:'10s'
  });
  check(response,{ 'success 200':r=>r.status===200,'response JSON':r=>r.json()!==null });
  sleep(1+Math.random()*2);
}
