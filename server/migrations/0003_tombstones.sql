-- 보관 기간(5년)이 지나 지운 주문의 묘비 — (store, order_id) 의 SHA-256 만 남김 (개인 정보·영수증 없음)
--  같은 영수증이 다시 와도 consumed 로 답해 다시 지급하지 않음
CREATE TABLE purged_orders (
  key_sha    TEXT PRIMARY KEY,   -- SHA-256("<store>\n<order_id>")
  purged_at  INTEGER NOT NULL
);
