# DEADLINE 15 결제 확인 서버 — API 약속 (v1)

게임(Godot)과 결제 확인 서버 사이의 약속입니다. 서버는 **Cloudflare Workers + D1** (`server/`, 결제층 B — 배포 절차는 `server/README.md`).
이 문서가 기준이고, 게임 쪽 구현 · 가짜 서버 · 진짜 서버가 모두 이 약속을 따릅니다 (`godot/tests/check_iap_parity.gd` 가 가짜 ↔ 진짜 응답을 비교).

| 쪽 | 파일 |
|---|---|
| 게임 클라이언트 | `godot/scripts/core/billing/verifier.gd` (HTTPRequest) |
| 가짜 서버 (같은 약속의 GDScript 흉내, 디버그 빌드만) | `godot/scripts/core/billing/fake_server.gd` |
| 지급 순서 | `godot/scripts/core/billing.gd` (오토로드 `Billing`) |
| 지급 기록 | `godot/scripts/logic/iap_rules.gd` (세이브 키 `game_iap`) |
| 서버 주소 | `godot/data/iap.json` 의 `IAP_SERVER.{dev,stage,prod}.url` |
| 진짜 서버 | `server/` (Cloudflare Workers + D1, `src/purchases.ts` 판단 순서) |
| 시험 | `godot/tests/check_iap.gd` (가짜 서버로 모든 경우, `-- --server http://127.0.0.1:8951` 이면 로컬 Worker 로) · `godot/tests/check_iap_parity.gd` · `server/test/` (vitest) |

---

## 1. 환경과 주소

| env | 쓰는 빌드 | 주소 (`IAP_SERVER[env].url`) | 가게 |
|---|---|---|---|
| `dev` | 디버그 빌드 기본 | `fake://local` → 가짜 서버 (네트워크 없음) | 가짜 가게 (`store: "dev"`) |
| `stage` | 디버그 빌드 + `-- --iap-env stage` | (서버를 만들면 채움, 예: `https://iap-stage.<도메인>`) | STOVE 샌드박스 · Google 라이선스 시험 · Apple Sandbox |
| `prod` | 출시 빌드 | (서버를 만들면 채움, 예: `https://iap.<도메인>`) | 실제 결제 |
| `local` | 디버그 빌드 + `-- --iap-env local` | `http://127.0.0.1:8951` — 로컬 `wrangler dev` (server/, 서버 env 는 dev 라 요청의 `env` 도 `"dev"`: `IAP_SERVER.local.env`) | 가짜 가게 (`store: "dev"`) |

- 주소가 `""` 이면 게임은 '네트워크 오류'처럼 다룹니다 (지급하지 않고 미처리로 남김). 출시 빌드는 `fake://` · `http://` 를 쓰지 않습니다 (`https://` 만).
- 가짜 가게(`store: "dev"`)는 서버가 dev 환경 · `DEV_STORE=1` · 로컬 주소(127.0.0.1 · localhost)로 받은 요청에서만 받습니다. stage · prod 는 `400 bad_store`.
  로컬 서버는 게임의 가짜 가게 장부를 `PUT /v1/dev/ledger` 로 받아 대기 · 환불 · finish · 상품 · 구매 시각을 압니다 (dev 도구 `/v1/dev/*` 는 같은 조건에서만, 그 밖에는 404).
  '로컬'은 주소 이름이 루프백이고 **실제 연결 주소(`CF-Connecting-IP`)도 루프백**일 때. 상태를 바꾸는 dev 도구는 JSON 본문 + `Content-Type: application/json` 필수.
  dev 서버가 받는 가게는 `dev` · `stove`(STOVE 는 `501 not_implemented` — 가짜 서버도 같음).
  가짜 가게 영수증의 `oid`·`spid`·`sig` 는 글, `acct` 는 글 또는 없음(""), 장부의 상품과 영수증 상품이 다르면 `422 invalid_receipt`.
- 서버는 요청의 `env` 와 자기 환경이 다르면 `400 env_mismatch` 를 돌려줍니다 (샌드박스 영수증이 운영 서버에 들어오지 않게).
- 경로는 `/v1/...`. 응답에 필드를 **더하는 것**은 같은 판(v1) 안에서 해도 됩니다 — 게임은 모르는 필드를 무시합니다. 뜻을 바꾸거나 빼면 `/v2`.

## 2. 인증 — 게임이 보내는 것

**게임 안에는 비밀 키가 없습니다.** 게임을 뜯어도 서버를 속일 수 있는 값이 나오지 않게, 영수증의 진위는 서버가 **가게 API 에 직접** 물어 확인합니다.

모든 요청의 머리:

| 머리 | 값 | 설명 |
|---|---|---|
| `Content-Type` | `application/json` | |
| `X-D15-Install` | 32자 소문자 16진수 | **설치 식별자** — 게임이 처음 결제·확인할 때 무작위로 만들어 세이브 `game_iap.iid` 에 저장. 개인 정보가 아님. 없거나 모양이 틀리면 `401 no_install_id` |
| `X-D15-Client` | `deadline15/<게임 버전> (<가게>; <OS>)` | 예: `deadline15/0.4.2 (stove; Windows)`. 통계·차단용 (믿지 않음) |

서버만 갖는 비밀 (Workers secret — `wrangler secret put`, 저장소에 넣지 않음):

| 가게 | 비밀 |
|---|---|
| STOVE | STOVE 결제 확인 API 키 (STOVE 개발자 센터에서 발급) · `STOVE_ACCT_KEY` (회원 번호 HMAC 용, 서버가 만든 무작위 값) |
| Google Play | Android Publisher API 서비스 계정 JSON |
| App Store | App Store Server API 키(.p8) · Key ID · Issuer ID (JWS 확인 자체는 Apple 루트 인증서로 — 키 불필요) |

남용 막기: 설치 식별자 + IP 별 요청 수 제한 (설치 식별자 분당 60회 · IP 분당 600회, IPv6 는 /64 묶음, 넘으면 `429 rate_limited` + `Retry-After: 60`).
IP 제한은 설치 식별자 검사보다 먼저 합니다 (모양이 틀린 요청도 셈 — 그래서 429 가 401 보다 먼저 나올 수 있음).

### 2.1 계정 값 — 서버는 클라이언트가 보낸 값을 믿지 않음

게임은 `account_id` 를 보내지 않습니다 (보내도 서버는 무시). 서버가 쓰는 계정 값은 **가게 확인 결과에서 얻은 것뿐**입니다.

| 가게 | 서버가 쓰는 계정 값 | 어디서 |
|---|---|---|
| STOVE | `HMAC-SHA256(서버 비밀 STOVE_ACCT_KEY, memberNo)` 16진수 | TID 로 STOVE 결제 조회 → 결과의 회원 번호 (원래 번호는 저장하지 않음) |
| Google | `obfuscatedExternalAccountId` | `purchases.products.get` 결과 — 게임이 구매 때 넣은 값 |
| Apple | `appAccountToken` | 확인한 JWS 의 필드 — 게임이 구매 때 넣은 값 |
| dev | 영수증의 `acct` | 가짜 가게가 서명한 값 |

- Google·Apple 에 넣는 토큰은 게임이 정함: **`SHA-256(iid)` 의 앞 32자** (`Billing.account_token`, Apple 은 이것을 UUID 모양으로 — 모바일 작업 때). 재설치하면 iid 가 바뀌어 토큰도 바뀝니다 → 3.2 의 '24시간 재claim' 규칙으로 복구 (그 전에 iid 를 앱 밖에 보존하는 것이 우선 — 3.6).
- 계정 값은 기록·분쟁 대응용입니다. **권한 판단(누가 consume·환불 목록을 볼 수 있나)은 계정 값이 아니라 verify 때 서버가 기록한 `install_id ↔ 주문` 연결로만** 합니다.
- 영수증의 계정 값은 영수증을 가진 사람이면 누구나 똑같이 내밀 수 있으므로 "같은 계정이면 바로 넘겨줌" 같은 규칙은 두지 않습니다.
  (STOVE 는 요청자의 STOVE 로그인 토큰을 서버가 확인하면 '요청자 = 구매자'를 증명할 수 있음 — 그 경우 즉시 이전 허용 여부는 **확인 필요**, STOVE SDK 작업 때)

## 3. 엔드포인트

공통 응답: 성공 `200 {"ok": true, ...}`, 실패 `4xx/5xx {"ok": false, "error": {"code": "...", "message": "..."}}`.
모든 요청에 `env` (POST 는 본문, GET 은 쿼리). 서버 환경과 다르거나 없으면 `400 env_mismatch`.

### 3.1 `GET /v1/health`

```json
200 {"ok": true, "time": 1792300000000, "env": "prod"}
```
`time` = 서버 시각(ms). (나중에 광고 하루 횟수의 시계 확인에 쓸 수 있음.)
health 는 설치 식별자 · `env` 쿼리가 없어도 됩니다 (IP 별 요청 수 제한만).

### 3.2 `POST /v1/purchases/verify` — 영수증 확인

게임이 가게에서 '구매됨'을 받으면 **지급하기 전에** 부릅니다.

요청:
```json
{
  "store": "stove" | "google" | "apple" | "dev",
  "product_id": "gold_1200",                         // 게임 안 상품 id
  "store_product_id": "gold_1200",                   // 가게 상품 id (Apple: "xyz.show4you.deadline15.gold_1200")
  "order_id": "GPA.3312-4410-2981-55523",            // 아래 '4. 가게별 영수증'
  "receipt": "<가게 원본 — 게임은 해석하지 않음>",
  "env": "prod"
}
```

**판단 순서** (형 검사 → 가게 확인 → 아래 순서, 먼저 맞는 것):

| 순서 | 조건 | 응답 |
|---|---|---|
| 0 | 요청 형이 틀림 · env 다름 · 상품 모름 · 영수증 가짜/불일치 | `400` / `422` (아래 오류 표) |
| 1 | 이 주문이 이미 **consumed** | `200 status: consumed` — 누가 물어도 (주인이 아니어도) |
| 0b | 보관 기간(5년)이 지나 지운 주문 (묘비 `purged_orders` 에 `SHA-256("<store>\n<order_id>")`) | `200 status: consumed` |
| 1 | (보충) consume 된 뒤 환불 기록이 붙은 주문 (`status = refunded` 이고 `consumed_at` 있음) 도 consumed | `200 status: consumed` |
| 2 | 가게 확인 결과 환불·취소됨, 또는 서버 기록이 refunded (refunds 표에 있음) | `422 refunded` (verify 전에 환불된 주문 포함 — 주인 기록을 만들지 않음). 이미 주인 기록이 있는 주문을 가게가 환불이라 하면 서버가 그 자리에서 환불을 기록 (`source: verify`) → 주인의 환불 목록에 나옴 |
| 3 | 가게 확인 결과 결제 대기 | `200 status: pending` (주인 기록을 만들지 않음) |
| 4 | 다른 `install_id` 가 주인 (claim) | 아래 순서로: ① 가게 쪽에서 이미 소모·확인됨(Google `consumptionState=1` 또는 `acknowledgementState=1`, Apple 은 해당 없음 — **확인 필요**, STOVE 는 소모 개념 없음) → `403 already_delivered` (원래 주인이 이미 받음) ② 이 주문이 이미 한 번 재claim 됨 → `403 reclaim_limit` (주문당 **1번**) ③ 주인의 `claimed_at` 으로부터 **24시간 안** → `403 order_claimed` ④ 그 밖 → 주인을 요청한 설치로 바꾸고 `reclaimed_from`·`reclaimed_at`·`reclaims` 를 기록, `200 valid` (`reclaimed: true`) — 재설치 복구 |
| 5 | 그 밖 | `200 status: valid` (처음이면 주인 기록 `INSERT`, `first: true`) — 처음 보는 주문인데 가게의 구매 시각이 5년보다 오래되면 `422 invalid_receipt` |

```json
200 {"ok": true, "status": "valid", "order_id": "GPA.3312-...", "product_id": "gold_1200", "gold": 1200, "first": true}
```
- `first`: 이 주문을 서버가 처음 봤는지 (같은 주문을 다시 확인하면 `false` — 결과는 같음, **멱등**).
- `order_id`·`product_id` 는 요청과 같아야 합니다. 다르면 게임은 응답을 믿지 않고 오류로 다룹니다.
- 골드 양은 서버 상품표(게임 `data/iap.json` 과 같은 표)에서. 게임은 자기 표의 골드를 지급합니다 (서버 값은 확인용).

게임이 하는 일: `valid` → 지급·저장 → consume → 가게 finish, `pending` → 기다림, `consumed` → 지급 없이 가게 finish 만.

오류:

| HTTP | `code` | 뜻 | 게임 |
|---|---|---|---|
| 400 | `bad_request` · `bad_store` · `env_mismatch` | 요청이 틀림 | 지급 안 함 (invalid) |
| 401 | `no_install_id` | 설치 식별자 없음 | invalid |
| 403 | `order_claimed` | 다른 설치가 24시간 안에 확인받은 주문 | invalid (지급·finish 안 함 — 24시간 뒤 다음 restore 에서 다시) |
| 403 | `reclaim_limit` · `already_delivered` | 이미 한 번 재claim 됨 · 가게에서 이미 소모됨 | invalid (고객 문의로 처리) |
| 422 | `invalid_receipt` · `unknown_product` · `product_mismatch` · `refunded` | 가짜·틀린 영수증, 환불된 주문 | invalid |
| 429 | `rate_limited` | 요청 과다 | **다시 시도** (미처리로 남김) |
| 5xx | `store_unavailable` · `internal` | 가게 API·서버 장애 | **다시 시도** |
| 501 | `not_implemented` | 이 가게의 확인을 서버가 아직 못 함 (지금 STOVE — 4 의 '확인 필요') | **다시 시도** (5xx — 지급 없이 미처리로 남음) |
| (없음) | 네트워크 실패·시간 초과 | | **다시 시도** |

#### 두 설치가 같은 주문을 받는 경우 (24시간 재claim 의 경합)

- consume 은 원자적입니다: `UPDATE orders SET status='consumed', consumed_at=? WHERE store=? AND order_id=? AND status='verified' AND install_id=?` — 바뀐 줄이 1이면 성공.
  주인(`install_id`)만 consume 할 수 있으므로 **한 주문의 consume 은 한 설치만** 성공합니다.
- 게임은 '지급 → 저장 → consume' 순서라, 옛 주인 A 가 지급만 하고 consume 전에 24시간 넘게 사라졌다가 새 주인 B 가 다시 claim 하면 두 설치에 잠깐 골드가 있을 수 있습니다.
  이때 A 가 돌아와 consume 하면 `403 order_claimed` 를 받고, **A 는 자기 지급을 회수**합니다 (`IapRules.revoke`, 0 바닥, 기록 `revoked`). B 는 consume 성공.
  → 최종적으로 한 설치만 골드를 가집니다. A 가 끝내 돌아오지 않으면(앱 삭제 등) A 의 골드는 A 의 세이브와 함께 사라지므로 중복이 남지 않습니다.
- A 와 B 가 같은 24시간 안에 오면 B 는 403 → 지급 없음. 24시간 뒤 다시 (단 주문당 재claim 1번).
- A 의 회수도 A 가 전투 중(또는 전투로 들어가는 중)이면 미뤘다가 전투 뒤에 합니다 (세이브 덮어쓰기 위험).
- consume 된 뒤에는 누구에게도 다시 `valid` 를 주지 않습니다 (판단 순서 1).

### 3.3 `POST /v1/purchases/consume` — 소모 기록

게임이 **지급이 디스크에 저장된 것을 확인한 뒤**(`Store` 가 파일을 다시 읽어 기록을 봄), 가게 `finish` 와 함께 부릅니다.
STOVE 는 소모 API 가 없으므로 이 기록이 서버 쪽 재지급 방지의 근거입니다 (그 뒤 같은 주문을 `verify` 하면 `consumed`).

요청: `{"store": "dev", "order_id": "FAKE.1792300000.3", "env": "dev"}` (계정 값 없음)
응답: `200 {"ok": true, "status": "consumed", "order_id": "FAKE.1792300000.3"}` — 이미 소모면 같은 응답 (멱등).

| HTTP | `code` | 뜻 | 게임 |
|---|---|---|---|
| 400 | `bad_request` · `env_mismatch` | | 다음 restore 때 다시 |
| 403 | `order_claimed` | 요청한 설치가 주인이 아님 (다른 설치가 claim) | **자기 지급을 회수** (위 경합) |
| 404 | `unknown_order` | verify 전 | 다음 restore 때 다시 |
| 409 | `refunded` | 환불된 주문 — 소모하지 않음 (이미 consumed 였다가 환불돼도) | 기록은 `granted` 로 남고, 환불 목록에서 회수됨 |

실패하면 게임의 기록은 `st: "granted"` 로 남고, 다음 `restore` 때 consume 만 다시 합니다 (골드는 다시 주지 않음).

### 3.4 `GET /v1/refunds?cursor=<글>&limit=100&env=<env>` — 환불 목록

**verify 때 서버가 기록한 주인(`install_id`)이 요청한 설치인 주문** 중 환불·취소된 것. 쿼리의 계정 값은 무시합니다.
게임은 받은 주문을 `IapRules.revoke` 합니다 (골드를 0 까지만 회수, 기록 `st: "revoked"`).

```json
200 {"ok": true,
     "orders": [{"store": "google", "order_id": "GPA.3312-...", "product_id": "gold_1200", "gold": 1200, "refunded_at": 1792390000000}],
     "cursor": "42", "more": false}
```
- `cursor`: 서버가 정하는 글 (D1 `refunds.seq`). 게임은 해석하지 않고 저장(`game_iap.rf`)했다가 다음 요청에 그대로 보냄. 처음은 `""`.
- `more: true` 면 게임은 곧바로 다음 쪽을 부름 (한 번에 최대 20쪽).
- 같은 주문이 다시 와도 게임은 두 번 회수하지 않음 (`revoked` 기록).
- 게임은 결제 기록이 하나도 없으면 부르지 않고, 성공한 뒤 60초 안에는 다시 부르지 않음 (상점 진입·결제 직후 등 강제 때 제외).
- verify 전에 환불된 주문은 주인이 없으므로 목록에 나오지 않음 (게임도 지급한 적이 없음).

### 3.4b `POST /v1/webhooks/apple` — App Store Server Notifications V2 (게임은 부르지 않음)

Apple 이 보내는 `{"signedPayload": "<JWS>"}`. 서버는 JWS(와 안의 `signedTransactionInfo`)를 4 의 App Store 줄과 같은 방법으로 확인하고,
`REFUND` · `REVOKE` 면 `refunds` 에 기록 (`source: apple_notif`).
`REFUND_REVERSED` 면 그 환불 기록을 지우고 주문 상태를 되돌림 (consume 됐으면 consumed, 아니면 verified). **게임이 이미 회수한 골드는 돌려주지 않음** (정책 — 필요하면 고객 문의로 보상).
`CONSUMPTION_REQUEST`(Apple 의 환불 심사용 소비 정보 요청)는 응답하지 않고 받기만. 그 밖의 알림도 `200 {"ok": true}` 로 받기만. 서명이 틀리면 `422 invalid_receipt`, 번들이 다르면 422, 환경이 다르면 `400 env_mismatch`.
설치 식별자 · `env` 는 받지 않음 (IP 별 요청 수 제한만).

### 3.5 재시도 간격 (게임)

'다시 시도'(네트워크·5xx·429)는 게임이 지금 아래 때에 다시 합니다: 앱 시작 · 앱 복귀 · 상점 진입 · 전투가 끝남 (`Billing.restore`).
진짜 서버를 붙일 때 더할 것: 같은 주문의 연속 실패에 **지수 백오프** (2초 → 4 → 8 … **상한 5분**, ±20% 흔들기), 429 의 `Retry-After` 머리를 따름. (지금의 가짜 서버 단계에는 자동 타이머 재시도가 없음 — 남은 일)

### 3.6 iid 보존과 기록 손상 (남은 경우)

- **iid 를 앱 밖에 보존 (모바일·STOVE 작업에서 구현)**: Android Block Store · iOS Keychain · STOVE 클라우드 세이브에 iid 를 두고, 재설치 때 그 값을 다시 씀.
  게임 쪽 확장 지점은 `Billing.set_iid_store(load_fn, save_fn)` (세이브에 iid 가 없으면 `load_fn` 값을 쓰고, 새로 만든 iid 는 `save_fn` 으로 넘김). 이것이 되면 재claim 은 거의 필요 없음.
- **기록 손상**: `game_iap` 글이 잘려 깨지면 sanitize 가 iid·주문을 건지고, 번호만 보이고 내용이 잘린 주문은 `{st:"done", lost:true}` 로 남겨 다시 지급하지 않습니다.
  - 그 주문이 서버에서 `consumed` → verify 를 하지 않아도 이미 '끝남'. 다른 길로 verify 해도 `consumed` → 지급 없음.
  - 서버에서 `verified`(지급 뒤 consume 전) 이고 iid 가 남음 → '이미 받은 주문' 길로 consume·finish 만 (지급 없음) — `check_iap 5b)`.
  - iid 까지 잘림 → 새 iid 라 consume 이 `order_claimed` → 지급 없음(중복 0). 주문은 `verified` 로 남아 가게에 미처리 (Google 은 3일 안에 소모·확인하지 않으면 자동 환불될 수 있음 — **확인 필요**). iid 바깥 보존으로 막을 일.
  - 주문 번호까지 잘림 → 기록이 없어 보통 길(verify): iid 가 남았으면 `valid` 로 **한 번 더 지급될 수 있음**(최대 1회). 남은 위험으로 둠.

## 4. 가게별 영수증 (`order_id` · `receipt`)

| 가게 | `order_id` | `receipt` | 서버 확인 | 환불 알기 |
|---|---|---|---|---|
| STOVE (PC, Windows 64비트) | 결제 **TID** | TID (+ SDK 결제 결과 원본) | STOVE 서버 API 로 TID 조회 → 상태·아이템 id·회원 번호 — **API 이름·인증 방식 확인 필요** (STOVE 개발자 센터 문서 — 2026-10 studio-docs 가 developers-beta.onstove.com 으로 옮겨져 확정 못 함). 서버는 지금 `501 not_implemented` | 환불 내역 조회 API 또는 알림 — **확인 필요** |
| Google Play | `orderId` (`GPA.…`) — 없으면(시험 결제) `purchaseToken` | `purchaseToken` | Android Publisher `purchases.products.get(packageName, productId, token)`: `purchaseState` 0=구매 1=취소 2=대기, `consumptionState`, `acknowledgementState`, `orderId`, `obfuscatedExternalAccountId` | **Voided Purchases API** (`purchases.voidedpurchases.list`, Cron 주기 조회) + **RTDN**(Pub/Sub, 일회성 상품 `ONE_TIME_PRODUCT_CANCELED`/voided 알림 — 종류 확인 필요) |
| App Store (StoreKit 2) | `transactionId` | `signedTransaction` (JWS) | **기준: JWS 서명을 x5c 사슬로 Apple Root CA G3(SHA-256 고정값)까지 확인** (Apple 확장 OID · 유효 기간 · ES256) → `bundleId`·`productId`·`transactionId`·`environment`(서버가 받는 목록 `APPLE_ENVIRONMENTS`, 아니면 `400 env_mismatch`)·`type`(Consumable)·`appAccountToken`·`revocationDate`. `.p8` 키가 설정되면 App Store Server API `Get Transaction Info` 로 한 번 더 (환불 여부 최신화) | **App Store Server Notifications V2** `REFUND` (+ `REVOKE`) 웹훅, 놓친 것은 `Get Refund History` API |
| dev (가짜) | `FAKE.<초>.<번호>` | `{"oid","spid","acct","sig"}` 가짜 서명 JSON | 가짜 서버가 가짜 가게 장부로 확인 | 가짜 장부의 `refunded` |

## 5. D1 표 (안)

```sql
CREATE TABLE orders (
  store        TEXT NOT NULL,
  order_id     TEXT NOT NULL,
  product_id   TEXT NOT NULL,
  gold         INTEGER NOT NULL,
  install_id   TEXT NOT NULL,          -- 지금 주인 (처음 확인받은 설치, 24시간 재claim 으로 바뀔 수 있음)
  claimed_at   INTEGER NOT NULL,       -- 지금 주인이 claim 한 시각 (24시간 규칙)
  reclaims     INTEGER NOT NULL DEFAULT 0,  -- 재claim 횟수 (최대 1)
  reclaimed_from TEXT,                 -- 재claim 로그: 옛 주인 install_id
  reclaimed_at INTEGER,                -- 재claim 로그: 시각
  account_id   TEXT NOT NULL DEFAULT '', -- 가게 확인 결과의 계정 값 (2.1) — 권한 판단에는 쓰지 않음
  env          TEXT NOT NULL,
  status       TEXT NOT NULL,          -- verified | consumed | refunded
  receipt_sha  TEXT NOT NULL,          -- 영수증 원본은 저장하지 않고 해시만
  verified_at  INTEGER NOT NULL,
  consumed_at  INTEGER,
  refunded_at  INTEGER,
  PRIMARY KEY (store, order_id)        -- 중복 방지: 주문 id UNIQUE
);
CREATE INDEX orders_install ON orders(install_id);

CREATE TABLE refunds (
  seq          INTEGER PRIMARY KEY AUTOINCREMENT,   -- /v1/refunds 의 cursor
  store        TEXT NOT NULL,
  order_id     TEXT NOT NULL,
  product_id   TEXT NOT NULL,
  gold         INTEGER NOT NULL,
  refunded_at  INTEGER NOT NULL,
  source       TEXT NOT NULL,                       -- google_voided | google_rtdn | apple_notif | stove | manual
  UNIQUE (store, order_id)
);
```

- `verify`: `INSERT ... ON CONFLICT(store, order_id) DO NOTHING` 후 다시 읽어 판단 순서(3.2)대로. 동시에 두 번 와도 주인은 하나.
  재claim 도 `UPDATE ... SET install_id=?, claimed_at=?, reclaims=reclaims+1, reclaimed_from=install_id, reclaimed_at=? WHERE ... AND install_id=<옛 주인> AND status='verified' AND reclaims=0 AND claimed_at <= now-86400000` 로 원자적 (가게 소모 상태 확인은 그 전에).
- 환불 목록: `refunds JOIN orders USING(store, order_id) WHERE orders.install_id = ? AND refunds.seq > ?` — 주인의 iid 로만.
- 환불 수집: Workers Cron Trigger 로 Google Voided Purchases · STOVE 환불 내역을 주기 조회, Apple/Google 알림은 웹훅 → `refunds` 에 `INSERT OR IGNORE`, `orders.status = 'refunded'` (이미 consumed 여도 기록, `consumed_at` 은 남김 — 판단 순서상 verify 는 consumed 를 먼저 답함).
- 첫 주인 INSERT 는 `INSERT … SELECT … WHERE NOT EXISTS (refunds …) AND NOT EXISTS (purged_orders …) ON CONFLICT DO NOTHING` — verify 와 환불 기록 사이 경합이 없음.
- 보관 기간이 지난 주문은 지우면서 묘비(`purged_orders.key_sha`)를 같은 batch 에 남김 (0003).
- 실제 표: `server/migrations/0001_init.sql` (위 표 + `status` CHECK · `orders(store, receipt_sha)` 색인(Google 시험 결제처럼 order_id 가 purchaseToken 인 주문을 Voided 목록과 맞춤) · `cursors(name, value, updated_at)` (Cron 진행 위치)).
  dev 전용: `0002_dev_store.sql` (`dev_ledger` 가짜 가게 장부 · `dev_meta` 시험 시계).

## 6. 게임의 지급 순서 (요약 — 자세히는 `billing.gd` 머리말)

1. 가게가 '구매됨'을 알림 (구매 직후, 또는 `query_unfinished` 로 다시)
2. 세이브 `game_iap.orders["<store>:<order_id>"]` 에 이미 있으면 지급하지 않음 — 그 기록이 **디스크에 있는지** 확인된 뒤에만 7) (환불·회수한 주문이면 아무것도 안 함)
3. `POST /v1/purchases/verify` — `valid` 일 때만 계속. 네트워크·5xx·429 면 아무것도 하지 않음 (미처리로 남음)
4. 전투 중이거나 전투로 들어가는 중이면 미룸 (전투가 끝날 때 세이브를 덮어쓰므로) — 가게에 미처리로 남아 있어 전투 뒤 다시 처리
5. `IapRules.grant` — 골드와 주문 기록을 같은 세이브에 한 번에
6. `Store.flush()` 성공 **그리고** 저장 파일을 다시 읽어 기록이 있음을 확인한 뒤에만
7. `POST /v1/purchases/consume` → 가게 `finish` (Google consume · Apple finish · STOVE 는 할 일 없음) → 기록 `st: "done"`. consume 이 `order_claimed` 면 자기 지급 회수

환불: `GET /v1/refunds` → `IapRules.revoke` (0 바닥). 전투 중(또는 응답을 기다리는 사이 전투로 들어감)에는 하지 않음.

'모든 데이터 초기화'는 `game_iap`(iid · 주문 기록 · 환불 커서)와 보관함 `game_iap_bak` 을 지우지 않습니다.

## 7. 개인 정보

- 설치 식별자: 무작위 128비트 (`Crypto.generate_random_bytes(16)`). 계정 값: HMAC 해시(STOVE) 또는 게임이 iid 로 만든 값(Google·Apple). 이름·이메일·기기 번호는 보내지 않습니다.
- 영수증 원본은 확인에만 쓰고 저장하지 않습니다 (해시만).
- 보관 기간: 주문 기록은 환불·분쟁 대응을 위해 5년 (전자상거래법 기록 보존 기준), 그 뒤 지움.
