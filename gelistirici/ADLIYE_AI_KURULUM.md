# Adliye ceza öneri servisi

Supabase Edge Function: `adliye-ceza-oner`. JWT zorunludur; fonksiyon ayrıca `adliye_durum` RPC'sinden görevdeki Yüksek Yargıç yetkisini ve açık dosya bilgilerini doğrular. Yalnız dosya numarası istenir, davacı içeriği istemciden alınmaz. Bu servis asla karar veya ceza uygulamaz.

## Yapay zekâ bağlantısı

Supabase Dashboard > Edge Functions > Secrets bölümünde `OPENAI_API_KEY` değişkenini **sunucu sırrı** olarak tanımlayın. İsteğe bağlı `ADLIYE_AI_MODEL` değişkeni model adını belirler (varsayılan `gpt-4.1-mini`). Sır asla GitHub'a veya tarayıcı koduna yazılmamalıdır. OpenAI API kullanılabilir ve bütçe aktifse model dosyayı ve savunmaları inceleyerek gerekçeli bir öneri üretir. Ulaşılamazsa aynı servis açıkça **Kurallı ön değerlendirme** gösterir. Kullanıcılara otomatik hüküm verildiği söylenmez.

## Suç tanımları

Oyun içi: hakaret, iftira, rüşvet, yolsuzluk, usulsüz işlem, dolandırıcılık ve diğer (somut oyun kuralı ihlali). Uyarı, 1 saat/1 gün/1 hafta sohbetten susturma, milletvekilliğinin düşürülmesi ve beraat seçeneklerinden kararı Yüksek Yargıç verir. Parti davasında yalnız uyarı/beraat uygulanabilir.
