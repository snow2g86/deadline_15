-- DEADLINE 15 결제 확인 서버 — docs/server/api.md 5. D1 표
-- 주문: (store, order_id) 가 기본 키 — 한 주문은 한 줄 (중복 지급 방지)
CREATE TABLE orders (
  store          TEXT NOT NULL,
  order_id       TEXT NOT NULL,
  product_id     TEXT NOT NULL,
  gold           INTEGER NOT NULL,
  install_id     TEXT NOT NULL,              -- 지금 주인 (처음 확인받은 설치, 24시간 재claim 으로 바뀔 수 있음)
  claimed_at     INTEGER NOT NULL,           -- 지금 주인이 claim 한 시각 (ms, 24시간 규칙)
  reclaims       INTEGER NOT NULL DEFAULT 0, -- 재claim 횟수 (최대 1)
  reclaimed_from TEXT,                       -- 재claim 로그: 옛 주인 install_id
  reclaimed_at   INTEGER,                    -- 재claim 로그: 시각
  account_id     TEXT NOT NULL DEFAULT '',   -- 가게 확인 결과의 계정 값 (2.1) — 권한 판단에는 쓰지 않음
  env            TEXT NOT NULL,
  status         TEXT NOT NULL CHECK (status IN ('verified', 'consumed', 'refunded')),
  receipt_sha    TEXT NOT NULL,              -- 영수증 원본은 저장하지 않고 SHA-256 만
  verified_at    INTEGER NOT NULL,
  consumed_at    INTEGER,
  refunded_at    INTEGER,
  PRIMARY KEY (store, order_id)
);
CREATE INDEX orders_install ON orders(install_id);
CREATE INDEX orders_receipt ON orders(store, receipt_sha);
CREATE INDEX orders_verified_at ON orders(verified_at);

-- 환불·취소: seq 가 /v1/refunds 의 cursor
CREATE TABLE refunds (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,
  store        TEXT NOT NULL,
  order_id     TEXT NOT NULL,
  product_id   TEXT NOT NULL,
  gold         INTEGER NOT NULL,
  refunded_at  INTEGER NOT NULL,
  source       TEXT NOT NULL,   -- google_voided | google_rtdn | apple_notif | stove | manual | dev
  UNIQUE (store, order_id)
);

-- 주기 수집(Cron)의 진행 위치 (예: google_voided = 다음 startTime ms)
CREATE TABLE cursors (
  name        TEXT PRIMARY KEY,
  value       TEXT NOT NULL,
  updated_at  INTEGER NOT NULL
);
