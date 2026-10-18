-- dev 환경 전용: 가짜 가게 장부 (Godot backend_fake 의 user://fake_iap/store.json 을 그대로 비춤)
--  stage·prod 에도 표는 생기지만 쓰이지 않음 — 가짜 가게는 ENV=dev · DEV_STORE=1 · 로컬 주소(127.0.0.1/localhost)에서만 켜짐
CREATE TABLE dev_ledger (
  order_id     TEXT PRIMARY KEY,
  pid          TEXT NOT NULL,
  spid         TEXT NOT NULL,
  acct         TEXT NOT NULL DEFAULT '',
  state        TEXT NOT NULL,             -- purchased | pending
  finished     INTEGER NOT NULL DEFAULT 0, -- 가게 finish (Google consume 흉내) → 재claim 의 already_delivered
  refunded     INTEGER NOT NULL DEFAULT 0,
  refund_seq   INTEGER,
  refunded_at  INTEGER,
  at           INTEGER NOT NULL DEFAULT 0  -- 구매 시각 (ms)
);
-- dev 환경 전용: 시험용 시계 밀기 (fake_server.gd 의 clock_offset_ms)
CREATE TABLE dev_meta (
  name   TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);
