# DEADLINE 15 결제 확인 서버 (결제층 B)

Cloudflare Workers + D1 로 만든 결제 확인 서버입니다. 게임과의 약속은 [`docs/server/api.md`](../docs/server/api.md) 이고, 이 서버는 그 약속을 그대로 따릅니다.
게임 쪽 가짜 서버(`godot/scripts/core/billing/fake_server.gd`)와 같은 요청에 같은 HTTP 상태 · 같은 JSON 을 돌려줍니다 (`godot/tests/check_iap_parity.gd` 로 비교).

> **아직 배포하지 않았습니다.** 아래 '처음 배포하기'는 사용자가 직접 Cloudflare 에 로그인한 뒤 따라 하는 절차입니다.

## 구조

```
server/
  wrangler.jsonc          환경 dev(맨 위) · stage · prod — D1 · 요청 수 제한 · Cron · 설정값(vars)
  migrations/             D1 스키마 (0001 주문·환불·커서, 0002 dev 가짜 가게 장부, 0003 묘비 purged_orders)
  src/
    index.ts              Worker 입구 (fetch · scheduled)
    app.ts                경로 → 설치 식별자 → 요청 수 제한 → 본문 → 엔드포인트, 기록(영수증·비밀값은 남기지 않음)
    purchases.ts          verify · consume · refunds (판단 순서)
    db.ts                 D1 — 바꾸기는 모두 한 문장 UPDATE … WHERE (원자적)
    webhooks.ts           App Store Server Notifications V2
    cron.ts               Google Voided Purchases 수집 (24시간 겹침 · 20쪽마다 이어 읽기) · 5년 지난 기록 정리(묘비)
    devtools.ts           dev 전용 도구 (/v1/dev/*, 로컬 주소에서만)
    products.ts           상품표 = ../godot/data/iap.json 을 그대로 묶어 넣음
    stores/               가게별 확인기: dev · google · apple · stove
    crypto/               WebCrypto: base64 · HMAC · JWT(RS256 · ES256) · DER/X.509 · Apple JWS
  test/                   vitest + @cloudflare/vitest-plugin (Workers 런타임 안, 원격 없음)
  .dev.vars.example       로컬 비밀값 틀 (.dev.vars 는 git 제외)
```

## 엔드포인트

| 경로 | 하는 일 |
|---|---|
| `GET /v1/health` | `{"ok":true,"time":<서버 ms>,"env":"<env>"}` (설치 식별자 필요 없음) |
| `POST /v1/purchases/verify` | 영수증 확인. 판단 순서 consumed > refunded > pending > 재claim(가게 소모 → 1번 → 24시간) > valid |
| `POST /v1/purchases/consume` | `UPDATE … WHERE status='verified' AND install_id=?` — 주인만, 한 번만 |
| `GET /v1/refunds` | 주인(verify 때 기록한 install_id)의 환불 주문만, `refunds.seq` 커서 |
| `POST /v1/webhooks/apple` | App Store Server Notifications V2 (서명 확인) → REFUND · REVOKE 기록 |
| `/v1/dev/*` | dev 환경 · `DEV_STORE=1` · 로컬(주소 이름 127.0.0.1 · localhost **그리고** 실제 연결 주소 `CF-Connecting-IP` 가 루프백)에서만: 가짜 가게 장부 · 상태 · 시계 · 429 시험 훅 · 초기화. 바꾸는 도구는 JSON 본문 + `Content-Type: application/json` 필수 (웹 페이지의 단순 form 전송으로 못 부름) |

오류 코드와 JSON 모양은 api.md 3 의 표 그대로입니다. 추가: `501 not_implemented` (STOVE 확인 미구현 — 게임은 5xx 로 보고 다시 시도).

## 가게별 확인기

| 가게 | 상태 | 확인 방법 |
|---|---|---|
| dev (가짜) | 완성 · 게임과 연결해 시험 | 영수증 `{"oid","spid","acct","sig"}`, `sig = SHA-256("dev-fake-store|oid|spid|acct")` (fake_files.gd 와 같음) + 가게 장부(dev_ledger). **dev · 로컬 주소에서만** 켜짐 — prod 는 설정과 상관없이 꺼짐 |
| Google Play | 코드 완성 · HTTP 흉내 시험만 (실제 키로는 아직) | 서비스 계정 JWT(RS256) → OAuth 토큰 → `purchases.products.get` · 환불은 Cron 으로 `voidedpurchases.list` |
| App Store | 코드 완성 · 시험용 인증서 사슬로 시험만 | `signedTransaction` JWS 를 x5c 사슬 → Apple Root CA - G3(SHA-256 고정값, 공식 인증서와 같음을 검수에서 확인)까지 확인 — 잎→중간 · 중간→루트 서명을 각각 확인 (이름만 같은 가짜 인증서 시험 있음). `.p8` 키가 있으면 Get Transaction Info 로 한 번 더. 환불은 Notifications V2 웹훅 (REFUND · REVOKE 기록, REFUND_REVERSED 는 기록 취소, CONSUMPTION_REQUEST 는 무시) |
| STOVE | 미구현 (인터페이스만, `501`) | 공식 문서에서 단건 확인 API 주소·인증을 확정하지 못함. 회원 번호 HMAC(`stoveAccountId`)만 있음 |

## 로컬에서 돌리기 (계정 필요 없음)

```sh
cd server
export PATH=/Users/2z/.nvm/versions/node/v22.16.0/bin:$PATH WRANGLER_SEND_METRICS=false
npm ci                                   # 처음 한 번 (node_modules 는 git 제외)
npm run migrate:local                    # = wrangler d1 migrations apply DB --local
npm run dev                              # = wrangler dev --port 8951 --ip 127.0.0.1 (맨 위 설정 = dev 환경, 127.0.0.1 에만, 원격 리소스 없음)
npm test                                 # 서버 시험 (vitest)
npm run typecheck
```

게임과 연결 (다른 터미널, 서버를 띄운 채):

```sh
# check_iap 의 모든 시나리오를 가짜 서버 대신 진짜 로컬 Worker 로
HOME=<임시 HOME> /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_iap.gd -- --server http://127.0.0.1:8951
# 가짜 서버 ↔ 로컬 Worker 응답 비교
HOME=<임시 HOME> /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/check_iap_parity.gd -- --server http://127.0.0.1:8951
# 디버그 빌드 게임을 로컬 서버로 (data/iap.json 의 IAP_SERVER.local)
/Applications/Godot.app/Contents/MacOS/Godot --path godot -- --iap-env local
```

`--iap-env local` 이면 게임의 가짜 가게 장부(`user://fake_iap/store.json`)가 서버의 `/v1/dev/ledger` 로도 비춰지고, 결제 요청(verify · consume · refunds)은 진짜 HTTPRequest 로 Worker 에 갑니다.

## 처음 배포하기 (사용자가 직접)

순서대로 따라 하면 됩니다. `<env>` 는 `stage` 또는 `prod`. 먼저 stage 로 끝까지 해 보고 prod 를 같은 순서로.

1. **로그인**: `cd server && npx wrangler login` (브라우저에서 snow2g86@gmail.com 계정 허락) → `npx wrangler whoami` 로 확인.
2. **D1 만들기**: `npx wrangler d1 create deadline15-iap-stage` (prod 는 `deadline15-iap-prod`).
   출력의 `database_id` 를 `wrangler.jsonc` 의 `env.<env>.d1_databases[0].database_id` (`REPLACE_WITH_…`) 에 넣습니다.
3. **마이그레이션**: `npx wrangler d1 migrations apply DB --env <env> --remote`
4. **요청 수 제한 namespace_id**: `ratelimits` 의 `namespace_id`(2501·2502·3501·3502)는 계정 안에서 겹치지 않는 아무 숫자 글이면 됩니다. 다른 Worker 가 같은 번호를 쓰면 바꿉니다.
5. **Apple 루트 고정값**: `wrangler.jsonc` 의 `APPLE_ROOT_SHA256` (`63343abf…3e9179`) 은 검수에서 공식 인증서(`https://www.apple.com/certificateauthority/AppleRootCA-G3.cer`)의 SHA-256 과 같음을 확인함. Apple 이 루트를 바꾸면 `curl -s <그 주소> | shasum -a 256` 값으로 바꿈.
6. **비밀값 넣기** (값은 프롬프트에 붙여 넣음 — 명령줄 인자·파일 커밋 금지):
   ```sh
   npx wrangler secret put GOOGLE_SERVICE_ACCOUNT_JSON --env <env> < 서비스계정.json   # 파일에서 (git 밖에 둔 파일)
   npx wrangler secret put APPLE_API_KEY_P8 --env <env> < AuthKey_XXXX.p8                # 선택
   npx wrangler secret put APPLE_KEY_ID --env <env>                                       # 선택
   npx wrangler secret put APPLE_ISSUER_ID --env <env>                                    # 선택
   npx wrangler secret put STOVE_ACCT_KEY --env <env>       # openssl rand -hex 32 로 만든 값 (한 번 정하면 바꾸지 않음)
   npx wrangler secret put STOVE_API_KEY --env <env>        # STOVE 확인 API 를 구현할 때
   ```
7. **미리 확인**: `npx wrangler deploy --env <env> --dry-run` → 오류 없으면
8. **배포**: `npx wrangler deploy --env <env>` → 출력의 주소 `https://deadline15-iap-<env>.<계정>.workers.dev` (prod 는 `deadline15-iap.<계정>.workers.dev`)
   - 사용자 도메인을 쓰려면 Cloudflare 대시보드 → Workers → 이 Worker → Settings → Domains & Routes → Custom Domain (예: `iap.<도메인>`), 그 뒤 `workers_dev: false` 로 바꿔도 됨.
9. **확인**: `curl https://<주소>/v1/health` → `{"ok":true,"time":…,"env":"<env>"}`
10. **게임에 주소 넣기**: `godot/data/iap.json` 의 `IAP_SERVER.<env>.url` 에 `https://…` (끝 `/` 없이) → `Godot --headless --path godot --script res://tools/data_tool.gd -- --write` → 시험 → 빌드 다시 내보내기.
    출시 빌드는 `https://` 만 씁니다 (`http://` · `fake://` 는 디버그 빌드만).
11. **Google Play 권한**:
    - Google Cloud 콘솔에서 프로젝트 → *Google Play Android Developer API* 사용 설정 → 서비스 계정 만들기 → 키(JSON) 만들기.
    - Play Console → 사용자 및 권한 → 서비스 계정 이메일 초대 → 앱 권한: **재무 데이터 보기**, **주문 및 구독 관리** (purchases.products.get · voidedpurchases 용).
    - 권한이 퍼지는 데 하루쯤 걸릴 수 있음 (그동안 401/403 → 서버는 503 store_unavailable, 게임은 다시 시도).
    - `GOOGLE_PACKAGE_NAME`(지금 `xyz.show4you.deadline15`)이 실제 Android 패키지 이름과 같은지 확인.
    - stage 는 라이선스 시험 결제(`purchaseType=0`)를 받고, prod 는 거절 (`GOOGLE_ALLOW_TEST_PURCHASES`).
12. **Apple 키 (선택 — 없으면 JWS 서명 확인만)**: App Store Connect → 사용자 및 액세스 → 통합 → *인앱 구매* 키 생성 → `.p8` 다운로드(한 번만 받을 수 있음) · Key ID · Issuer ID.
13. **Apple 웹훅 URL 등록**: App Store Connect → 앱 → App 정보 → *App Store 서버 알림* → 버전 2 →
    - 프로덕션 서버 URL: `https://<prod 주소>/v1/webhooks/apple`
    - 샌드박스 서버 URL: `https://<stage 주소>/v1/webhooks/apple`
    - 등록 뒤 App Store Server API 의 *Request a Test Notification* 으로 `TEST` 가 200 인지 확인 (`npx wrangler tail --env <env>` 에 `apple_notification` 기록).
14. **Cron**: stage · prod 는 30분마다 (`*/30 * * * *`). 대시보드 → Worker → Settings → Triggers 에서 보임. 직접 시험: `npx wrangler dev --env stage --test-scheduled` 는 원격 키가 필요하므로 배포 뒤 로그로 확인.

## 출시 전 결정 (사용자)

- **prod 가 Apple Sandbox 영수증을 받음** (`APPLE_ENVIRONMENTS = "Production,Sandbox"`): App Review 가 출시 빌드로 Sandbox 결제를 하기 때문 (Apple 권장).
  Sandbox 계정은 App Store Connect 에서 개발자만 만들 수 있지만, 심사가 끝난 뒤 `"Production"` 만 두는 것도 고를 수 있음.
- **요금제 · WAF**: 아래 '요청 수 제한과 남용 막기'. 권장은 Workers Paid + 사용자 도메인 + WAF 요청 제한 규칙.
- **환불 취소(Apple REFUND_REVERSED) 정책**: 서버는 환불 기록을 지우고 주문 상태를 되돌리지만, 게임이 이미 회수한 골드는 **돌려주지 않음** (고객 문의로 수동 보상). 바꾸려면 api.md 부터.

## 요청 수 제한과 남용 막기

- 서버 안: Workers Rate Limiting 바인딩 — IP 별(IPv6 는 /64 묶음) 분당 600 · 설치 식별자별 분당 60. IP 제한은 설치 식별자 검사보다 먼저라 모양이 틀린 요청(401)도 셈.
  제한기 자체가 고장 나면 결제 확인을 막지 않고 통과시키되 `rate_limit_error` 를 기록함.
  이 바인딩은 Cloudflare 위치(colo)마다 따로 세고 '대략'이라, 정확한 상한이 아니라 남용을 늦추는 장치임.
- **권장 (사용자 결정): Workers Paid + 사용자 도메인 + WAF 요청 제한 규칙**. `*.workers.dev` 주소에는 WAF(Rate limiting rules)를 걸 수 없음 — 사용자 도메인(Custom Domain)에 붙여야 함.
  예: `/v1/` 경로에 IP 당 10초 50회 넘으면 막기 (Free 플랜도 규칙 1개는 쓸 수 있으나 기간·동작 선택이 좁음 — 배포 때 대시보드에서 확인).
- 무료 한도 계산 (Workers Free 하루 100,000 요청 — 넘으면 그날은 오류, 게임은 다시 시도):
  - 정상 이용: 결제 1건 ≈ verify 1 + consume 1 + refunds 1~2 = 4요청. refunds 는 결제 기록이 있는 설치만, 60초 간격, 앱 시작·복귀·상점 진입·전투 끝 때.
    하루 활성 1만 명 중 결제 기록이 있는 사람 2천 명 × 하루 10번 = 2만 + 결제 500건 × 4 = 2천 → 약 2.2만/일 (한도의 22%).
  - 남용: 한 IP 가 분당 600 까지 통과 → 한 IP 가 쉬지 않고 보내면 하루 86만 요청으로 무료 한도를 혼자 다 씀. 무료 판에서는 이것을 막을 수 없음 → 출시 때 Workers Paid(월 5달러, 1천만 요청 포함) 권장.
  - D1 Free: 하루 읽기 500만 줄 · 쓰기 10만 줄. verify 1번 ≈ 읽기 3~5 · 쓰기 0~1.

## 비용 예상 (Workers Free · D1 Free 기준)

| 항목 | 무료 범위 | 이 서버 사용량 (어림) |
|---|---|---|
| Workers 요청 | 하루 100,000 | 결제 1건 ≈ verify 1 + consume 1 + refunds 1~2, 앱 시작·복귀·상점 진입마다 refunds(60초 간격 · 결제 기록이 있을 때만). 하루 활성 1만 명이어도 수만 건 |
| Workers CPU | 요청당 10ms | 보통 1~3ms. Apple JWS 확인(ECDSA 3번)이 가장 무거움 — 넘으면 유료(Workers Paid, 월 5달러) |
| D1 | 저장 5GB · 하루 읽기 500만 줄 · 쓰기 10만 줄 | 주문 1건 ≈ 300바이트. 5년 보관해도 수백 MB 안쪽 |
| Cron | 무료 (계정당 개수 제한) | 2개 (stage · prod) |
| Rate Limiting 바인딩 | 무료 | |

※ 무료 범위 수치는 Cloudflare 가 바꿀 수 있으니 배포 때 가격 페이지를 확인하세요. 무료 한도를 넘으면 요청이 실패(게임은 다시 시도)하므로, 출시 때는 Workers Paid 를 권합니다.

## 운영 점검 항목

- **매일/매주**: `npx wrangler tail --env prod` 또는 대시보드 Observability 에서 `"s":5xx` · `store_unavailable` · `google_oauth` · `cron_google` 기록이 늘지 않는지.
- **Cron**: 로그 `{"at":"cron","google":{…}}` 의 `skipped` 가 `error` 면 서비스 계정 권한 · 키 만료 확인. `bad` 가 0 이 아니면 `google_voided_item` 기록을 봄 (이상한 항목은 건너뜀).
  `more: true` 는 20쪽을 다 못 읽어 다음 실행에서 이어 읽는다는 뜻 (커서에 `token` 이 저장됨). `cursors.google_voided` 가 30분마다 앞으로 가는지:
  `npx wrangler d1 execute DB --env prod --remote --command "SELECT * FROM cursors"`
- **Google 환불 수집의 한계 — 30일**: Voided Purchases API 는 최근 30일만 줌. 수집은 지난 끝보다 24시간 앞에서 다시 읽고(겹침, `INSERT OR IGNORE` 라 안전), 새로 시작할 때는 29일 전부터.
  서버(Cron)가 **30일 넘게 멈추면** 그 사이 오래된 환불은 API 로 다시 받을 수 없음. 대처(수동 백필):
  1. Play Console → 주문 관리(또는 재무 보고서 → 판매 보고서)에서 그 기간의 환불·취소 주문 번호(`GPA.…`)를 내려받음.
  2. 주문마다 (주인 기록이 있는 것만 게임에 나타남):
     ```sh
     npx wrangler d1 execute DB --env prod --remote --command "INSERT OR IGNORE INTO refunds (store, order_id, product_id, gold, refunded_at, source) SELECT store, order_id, product_id, gold, <환불 ms>, 'manual' FROM orders WHERE store='google' AND order_id='GPA.…'; UPDATE orders SET status='refunded', refunded_at=<환불 ms> WHERE store='google' AND order_id='GPA.…' AND status!='refunded';"
     ```
  3. 게임은 다음 환불 조회 때 그 주문을 회수함. 멈춤을 빨리 알도록 Cron 로그 알림(대시보드 Observability → 알림)을 걸어 둠.
- **묘비**: 5년이 지나 지운 주문은 `purged_orders` 에 `SHA-256("<store>\n<order_id>")` 만 남음 — 같은 영수증이 다시 오면 consumed. 구매 시각이 5년보다 오래된 처음 보는 영수증은 422.
- **재claim**: `SELECT COUNT(*) FROM orders WHERE reclaims > 0` 이 갑자기 늘면 영수증 공유·남용 의심 (기록 `{"at":"reclaim","order_sha":…}` — 주문 번호 대신 해시 앞 16자).
- **429 · 제한기**: `rate_limited` 와 `rate_limit_error`(제한기 장애로 통과시킴) 기록.
- **환불**: `SELECT source, COUNT(*) FROM refunds GROUP BY source`.
- **429**: `rate_limited` 가 정상 이용자에게 나오면 `ratelimits` 의 limit 을 올림 (period 은 10 또는 60초만).
- **비밀값 교체**: 서비스 계정 키 · Apple 키를 바꿀 때 `wrangler secret put` 뒤 바로 반영 (다시 배포 필요 없음). `STOVE_ACCT_KEY` 는 바꾸면 계정 값이 달라지므로 바꾸지 않음.
- **보관**: Cron 이 5년 지난 주문·환불 기록을 지움 (api.md 7).
- **백업**: D1 Time Travel(30일) — 사고 때 `npx wrangler d1 time-travel restore DB --env prod --timestamp …`.
- **compatibility_date** 는 분기마다 올리고 `npm test` 로 확인.

## 보안 메모

- 게임에는 비밀 키가 없음. 서버 비밀은 `wrangler secret` · `.dev.vars`(git 제외)만.
- 클라이언트가 보낸 `account_id` 는 읽지 않음. 권한은 verify 때 기록한 `install_id ↔ 주문` 으로만.
- 요청 본문 16KB (웹훅 64KB) 상한, 필드 형·길이 검사, 설치 식별자 32자 소문자 16진수.
- 요청 수 제한: 설치 식별자별 분당 60, IP 별(IPv6 /64) 분당 600 (stage · prod), IP 를 먼저. 넘으면 `429 rate_limited` + `Retry-After: 60`.
- verify 와 환불 기록 사이 경합: 첫 주인 기록 INSERT 는 `WHERE NOT EXISTS (refunds …) AND NOT EXISTS (purged_orders …)` 한 문장.
- 가게가 '환불·취소'라고 답한 주문이 이미 지급된 것이면 그 자리에서 환불 기록(`source: verify`) → 주인의 환불 목록에 나옴.
- CORS 머리를 보내지 않음 (브라우저에서 부를 수 없음).
- 기록에는 경로 · 상태 · 오류 코드 · 걸린 시간만 (영수증 · 토큰 · 비밀값 · 본문은 남기지 않음). 영수증은 SHA-256 만 저장.
- 시각은 모두 서버 시각 (`Date.now()`) — dev 의 시계 밀기는 dev · 로컬에서만.
- 가짜 가게 · dev 도구는 `ENV=dev` + `DEV_STORE=1` + 로컬(주소 이름 + 실제 연결 주소가 루프백)일 때만. `npm run dev` 는 127.0.0.1 에만 띄움. dev 설정은 `workers_dev: false` 라 배포해도 공개 주소가 생기지 않음.
- Apple JWS: x5c 사슬을 고정한 Apple Root CA - G3 까지 · Apple 확장 OID · 유효 기간 · ES256 서명. 온라인 OCSP(인증서 폐기) 확인은 하지 않음 (남은 일).

## 남은 일

- STOVE: 결제 확인 API(TID 조회) · 환불 내역 API 확정 후 `stores/stove.ts` 채우기 (STOVE 개발자 센터 문서, 인디 계정 필요).
- Google RTDN(Pub/Sub 푸시) 웹훅 — 지금은 Voided Purchases Cron(30분) 만. 필요하면 Pub/Sub OIDC 토큰 확인을 붙여서.
- Apple Get Refund History 로 놓친 알림 메우기 · OCSP 확인.
- 실제 키로 stage 끝까지 시험 (Google 라이선스 시험 · Apple Sandbox).
- `purchases.products.get` 은 Google 이 `purchases.productsv2` 로 옮기는 중 — 출시 전 문서 확인.
