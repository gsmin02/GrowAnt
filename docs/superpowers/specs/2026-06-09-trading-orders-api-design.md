# 거래(주문) 슬라이스 + env 구성 — 설계

**작성일:** 2026-06-09
**대상:** 백엔드(`backend/`) + Flutter 프론트엔드(`frontend/`) + env 구성

## 1. 목표

종목 상세의 매수/매도(`_OrderSheet`, 현재 mock 스낵바)와 내역 탭(`mockTrades`)을 실 API로 이전한다.
- `POST /api/orders` — 주문 체결(검증 + in-memory 상태 변동)
- `GET /api/trades` — 거래 내역(최신순)

추가로 API 설정의 env 관리를 구성한다(프론트 `.env` + 백엔드 `.env` 로딩 골격 + gitignore).

## 2. 범위 / 제약 (확정 사항)

- **상태 전체 반영:** 주문 체결은 in-memory 상태(현금·me 포지션·거래내역)를 변동시킨다.
  홈 자산 카드·대결 카드(me)·포트폴리오 상세(me)·내역 탭에 즉시 반영. **서버 재시작 시 초기화.**
- **자산 산식(동적):** `총 평가 자산 = 현금 + me 포트폴리오 평가액`. 정적 상수(cash 2.5M + stockValue 8.02M)를 폐기하고 이 식으로 교체.
- **매도 가능 보유 기준 = 대결 포트폴리오(me).** 계정 탭 화면(애플 포함 mock)은 이번에도 무변경 — 별개 세계 유지.
- **주문 검증:** 카탈로그 티커 / qty≥1 / 매수=현금 충분 / 매도=me 보유 충분. **장운영시간 체크는 스킵**(mock 거래소 항상 열림 — `ORDER_MARKET_CLOSED`는 실시세 슬라이스에서).
- **AI 영역 추후 구현 anchor:** AI 포지션은 하드코딩 유지하되, 코드에 `NOTE(duel-ai)` 주석으로 "AI 매매 슬라이스에서 TradingService 상태로 대체 후 삭제"를 명시한다.
- **env:** 프론트=`frontend/.env`(+example, dart-define-from-file 방식), 백엔드=루트 `.env`를 bootRun에서 로딩하는 골격(`spring.config.import`, 의존성 추가 없음). 루트 `.gitignore`의 베어 `.env` 패턴이 전 디렉터리를 커버함을 검증하고 유지.
- **TradeDto는 프론트 Trade 모델과 1:1 미러**(`name,isBuy,price,qty,amount,time` — time은 "MM.dd HH:mm" 문자열) → 프론트 변경 최소화.
- **수치 불변(부팅 시):** 자산 10,520,000원/+5.2% · me +5.2%(value 2,881,800) 유지.

## 3. 백엔드 설계

### 3.1 `com.growant.trading` (신규 패키지) — 상태 소유

**상태(초기값):**

| 항목 | 초기값 | 근거 |
|---|---|---|
| `cash` | **7,638,200** | 자산 10,520,000 − me 포트폴리오 평가 2,881,800 (부팅 불변값 유지) |
| me 포지션 | 기존 4종목(qty·평단) | PortfolioService에서 **이관** |
| 거래내역 | 기존 `mockTrades` 6건 시드 | 내역 탭 첫 화면 동일 |

**`TradingService`** — 유일한 가변 상태 소유자. `placeOrder`는 `@Synchronized`.

- `placeOrder(ticker: String, isBuy: Boolean, qty: Int): TradeDto`
  1. 검증: 카탈로그에 없는 티커 → `INVALID_TICKER` / `qty < 1` → `INVALID_ORDER`(신규) /
     매수: `price×qty > cash` → `ORDER_INSUFFICIENT_FUNDS` / 매도: 보유 qty 부족 → `ORDER_INSUFFICIENT_HOLDINGS`(신규)
  2. 체결: 현재가=마켓 카탈로그. 매수: `cash -= price×qty`, 포지션 가중평단 재계산
     `newAvg = round((avgPrice×heldQty + price×qty) / (heldQty+qty))`, 신규 종목이면 포지션 추가(avg=price).
     매도: `cash += price×qty`, qty 차감(평단 유지), 0이 되면 포지션 제거.
  3. 내역 prepend(최신이 [0]) 후 체결 `TradeDto` 반환. `time`은 Asia/Seoul "MM.dd HH:mm".
- `getTrades(): List<TradeDto>` — 최신순.
- `getMePositions()`, `getCash()` — Portfolio/Account 조회용.

**불변식(테스트로 고정):** 체결 직후 `cash + me평가액`은 체결 전과 동일(현금 증감 = 평가 증감).
예: 삼성전자 1주 매수 → cash 7,561,900 / me value 2,958,100 / 합 10,520,000 유지, 평단 round(916,300/13)=70,485.

### 3.2 ErrorCode 추가 (`common/error/ErrorCode.kt`)

```kotlin
// VALIDATION / MARKET 그룹에 추가
INVALID_ORDER(3001, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "잘못된 주문입니다."),
// ORDER 그룹에 추가
ORDER_INSUFFICIENT_HOLDINGS(4002, HttpStatus.CONFLICT, "ORDER_ERROR", false, "보유 수량이 부족합니다."),
```

### 3.3 API / DTO

- `TradingController`: `POST /api/orders` (body `OrderRequestDto`) → `ApiResponse<TradeDto>` /
  `GET /api/trades` → `ApiResponse<List<TradeDto>>`
- `OrderRequestDto(ticker: String, isBuy: Boolean, qty: Int)`
- `TradeDto(name: String, isBuy: Boolean, price: Int, qty: Int, amount: Long, time: String)` — amount=price×qty
- `SecurityConfig`: `/api/orders`, `/api/trades` permitAll 추가.

### 3.4 기존 서비스 개편

- **`PortfolioService`**: ME 포지션을 `TradingService`에서 조회(하드코딩 이관). AI 포지션은 하드코딩 유지 + anchor:
  ```kotlin
  // NOTE(duel-ai): AI 포지션은 임시 하드코딩 — AI 매매 로직 슬라이스에서
  //   TradingService 상태로 대체하고 이 블록을 삭제한다.
  ```
- **`AccountService`**: `totalAsset = trading.cash + portfolio(ME).value`, `returnRate`는 기존 seed(1,000만) 공식 유지.
  의존: AccountService(tradingService, portfolioService). 순환 없음(Trading→Market, Portfolio→Trading+Market, Account→Trading+Portfolio).

### 3.5 백엔드 테스트

- `TradingServiceTest`: 매수 체결(현금/평단/포지션/내역), 매도 체결(현금/수량/0이면 제거), 가중평단 수치(70,485),
  자산 불변식, 신규 종목 매수, 에러 4종(INVALID_TICKER·INVALID_ORDER·FUNDS·HOLDINGS), 내역 최신순+시드 6건.
- `TradingControllerTest`(@WebMvcTest): 주문 성공 envelope, 잔고 부족 409+에러 envelope, GET trades.
- 기존 `PortfolioServiceTest`/`AccountServiceTest`/`PortfolioControllerTest`/`AccountControllerTest`: 생성자(의존) 변경 반영 — 초기 상태 단언값은 전부 동일하게 유지됨.

## 4. 프론트 설계

### 4.1 trading 데이터 레이어 (market 패턴)

- `features/trading/data/trade_models.dart`: `Trade(name,isBuy,price,qty,amount,time)` + fromJson — **mock Trade 대체**(필드 동일).
- `features/trading/data/trade_repository.dart`: `placeOrder({ticker, isBuy, qty})` POST `/api/orders` → `Trade` / `fetchTrades()` GET `/api/trades`. DioException→ApiException 변환(기존 패턴).
- `features/trading/application/trading_providers.dart`: `tradeRepositoryProvider` + `tradesProvider`
  (`AsyncNotifierProvider<TradesNotifier, List<Trade>>`, `refresh()` — market list 패턴).

### 4.2 주문 시트 연동 (`stock_detail_screen.dart` `_OrderSheet`)

- `ConsumerStatefulWidget`으로 전환. 주문 버튼: 로딩 중 비활성+스피너.
- 성공: `Navigator.pop` + 스낵바 "매수 체결: {name} {qty}주" + **상태 invalidate**:
  `portfolioProvider(PortfolioOwner.me)`, `accountSummaryProvider`, `tradesProvider`(refresh) — 홈/상세/내역 즉시 갱신.
- 실패(`ApiException`): 시트 유지 + 스낵바에 `e.message`(예: "잔고가 부족합니다.").
- 기존 `NOTE(market-slice): _OrderSheet은 mock 유지` anchor 주석 제거(이행 완료).

### 4.3 내역 탭 연동 (`trade_history_screen.dart`)

- `ConsumerWidget` 전환, `tradesProvider` watch — 로딩=중앙 스피너 / 에러=전체 `ErrorView`(+재시도 refresh) / data=기존 `_SummaryBar`+리스트(마켓 대시보드 패턴).
- `trade_detail_screen.dart`: `Trade` import만 mock→`trade_models.dart`로 교체(필드 동일).

### 4.4 mock 정리

`mock_data.dart`에서 `class Trade` + `mockTrades` 제거(이전 후 사용처 없음 — 시드는 백엔드로 이동).

## 5. env 구성

### 5.1 프론트 (`frontend/`)

- **`frontend/.env.example`(커밋):**
  ```
  # API 서버 주소 — iOS 시뮬레이터=localhost, Android 에뮬레이터=10.0.2.2, 실기기=Mac LAN IP
  API_BASE_URL=http://localhost:8080
  ```
- **`frontend/.env`(비커밋)**: `.env.example` 복사 후 환경에 맞게 수정.
- 실행: `flutter run --dart-define-from-file=.env` — 기존 `String.fromEnvironment('API_BASE_URL')` 코드 무변경.
- gitignore: 루트 `.gitignore`의 베어 `.env` 패턴이 `frontend/.env`를 커버(검증). `frontend/.gitignore`에도 명시적 `.env` 1줄 추가(Flutter 단독 사용 대비).

### 5.2 백엔드 (루트 `.env` 로딩 골격)

- `backend/src/main/resources/application.yml` 최상단에 추가(의존성 없음, Spring 내장):
  ```yaml
  spring:
    config:
      import: "optional:file:../.env[.properties]"
  ```
  → `bootRun`(작업 디렉터리 `backend/`) 시 루트 `.env`의 KEY=VALUE가 프로퍼티로 주입(없으면 무시).
  기존 `${SUPABASE_DB_URL}` 등 placeholder가 이 골격과 연결되며, 지금은 local 프로파일이 DB/Redis 자동설정을 제외하므로 no-op.
- 루트 `.env.example`은 이미 포괄적(Supabase·Redis·Gemini·JWT·OAuth·MARKET_PROVIDER) — 무변경.
- README 실행 섹션 갱신: 프론트 `cp .env.example .env` + `--dart-define-from-file=.env`, 백엔드 루트 `.env` 자동 로딩 한 줄.

## 6. 데이터 흐름 / 에러

주문: `_OrderSheet` → `tradeRepository.placeOrder` → `POST /api/orders` → TradingService 검증·체결 →
성공 시 프론트가 관련 provider invalidate(서버 상태 변경 전파). 에러는 기존 envelope→ApiException→스낵바.
내역: `tradesProvider` → `GET /api/trades`. 거래 상세는 목록에서 받은 `Trade` 객체 그대로(추가 호출 없음).

## 7. 프론트 테스트

- `trade_repository_test.dart`(DioAdapter): placeOrder 요청 body·응답 파싱 / fetchTrades 파싱 / 에러 envelope(ORDER_INSUFFICIENT_FUNDS)→ApiException.
- `trade_history_screen_test.dart`(FakeRepo): 목록+요약 렌더 / 로딩 스피너 / 에러 ErrorView+재시도 / (4-케이스 컨벤션).
- 주문 플로우 위젯 테스트: StockDetailScreen(Fake market+trading repo)에서 매수 시트 → 주문 → FakeRepo 호출·스낵바 확인 + 실패 시 에러 스낵바.
- 기존 22개 전부 유지.

## 8. 파일 변경 요약

백엔드 — 신규: `trading/{TradingService,TradingController,dto/{OrderRequestDto,TradeDto}}`, 테스트 2.
수정: `ErrorCode`(+2), `SecurityConfig`(+2 permit), `PortfolioService`(me 이관+AI anchor), `AccountService`(동적 산식), 기존 테스트 4(생성자), `application.yml`(config.import).
프론트 — 신규: `features/trading/{data 2, application 1}`, 테스트 2(+주문 플로우). 수정: `stock_detail_screen.dart`(_OrderSheet), `trade_history_screen.dart`, `trade_detail_screen.dart`(import), `mock_data.dart`(Trade/mockTrades 제거), `frontend/.gitignore`(+.env).
env — 신규: `frontend/.env.example`. 수정: `README.md`(실행 섹션).
