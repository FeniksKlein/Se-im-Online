-- 13 Ekim Meclis Başkanlığı sonrasında iki Yüksek Mahkeme üyesinin seçimi.
BEGIN;
CREATE TABLE IF NOT EXISTS oyun.mahkeme_toplu_secim (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 mv_secim_id bigint NOT NULL UNIQUE REFERENCES oyun.secimler(id),
 meclis_secim_id bigint NOT NULL REFERENCES oyun.meclis_secim(id),
 bas timestamptz NOT NULL, aday_bit timestamptz NOT NULL,
 oy_bas timestamptz NOT NULL, oy_bit timestamptz NOT NULL,
 durum text NOT NULL DEFAULT 'aday' CHECK (durum IN ('aday','oylama','bitti')),
 sonuc jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS oyun.mahkeme_toplu_aday (
 secim_id bigint NOT NULL REFERENCES oyun.mahkeme_toplu_secim(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES oyun.profiller(id),
 zaman timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(secim_id,user_id)
);
CREATE TABLE IF NOT EXISTS oyun.mahkeme_toplu_oy (
 secim_id bigint NOT NULL REFERENCES oyun.mahkeme_toplu_secim(id) ON DELETE CASCADE,
 vekil uuid NOT NULL REFERENCES oyun.profiller(id),
 aday uuid NOT NULL REFERENCES oyun.profiller(id),
 zaman timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(secim_id,vekil),
 FOREIGN KEY(secim_id,aday) REFERENCES oyun.mahkeme_toplu_aday(secim_id,user_id)
);
CREATE INDEX IF NOT EXISTS mahkeme_toplu_oy_aday_idx ON oyun.mahkeme_toplu_oy(secim_id,aday);
ALTER TABLE oyun.mahkeme_toplu_secim ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.mahkeme_toplu_aday ENABLE ROW LEVEL SECURITY;
ALTER TABLE oyun.mahkeme_toplu_oy ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON oyun.mahkeme_toplu_secim,oyun.mahkeme_toplu_aday,oyun.mahkeme_toplu_oy FROM PUBLIC,anon,authenticated;
COMMIT;