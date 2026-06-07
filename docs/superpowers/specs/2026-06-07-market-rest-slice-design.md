# 마켓 시세 REST 수직 슬라이스 — 설계 (Spec)

- 날짜: 2026-06-07
- 상태: 승인 대기(사용자 검토)
- 접근법: Pragmatic (dio + Riverpod `AsyncNotifier` + repository + 수동 DTO + 에러 인터셉터) + 2보정
- 목적: 기존 Mock UI(마켓 대시보드·종목 상세)를 실제 백엔드 REST에 연결하는 **첫 수직 슬라이스**. 이후 모든 기능이 복제할 **프론트 표준 데이터 패턴(Riverpod + dio + repository + DTO + ApiException→ErrorView)**을 확립한다.

## 1. 범위

**In scope**
- 백엔드: `GET /api/market`(목록), `GET /api/market/{ticker}`(상세 + 캔들 + 펀더멘털)
- 프론트: `market_dashboard_screen`, `stock_detail_screen`를 실데이터로 연결
- 프론트 표준 계층 도입: `core/api`(dio 클라이언트 + 에러 인터셉터), repository, Riverpod providers, DTO 모델, `ErrorView` 추출

**Out of scope (이 슬라이스 아님)**
- WebSocket/실시간 스트리밍, Redis pub/sub
- DB/Supabase 영속성 (마켓 스냅샷은 DB 불필요)
- 인증(소셜 로그인) — security는 마켓 경로만 permit
- **매수/매도 주문**(`stock_detail`의 `_OrderSheet`)은 **mock 유지** (거래 기능 = 별도 슬라이스)
- 나머지 8개 기능 화면

## 2. 크로스체크 결과 (실제 코드 검증, 2026-06-07)

확인됨: `MarketDataProvider`(currentPrice/subscribe/unsubscribe + `Tick`), `SimulatedMarketDataProvider`(매 호출 random-walk, 시드 50,000~99,999, scale 0=정수원, `subscribe()`는 TODO 스텁, changeRate 미산출), `ApiResponse`/`ApiError`(ok()만), `ErrorCode`(INVALID_TICKER 3000/400/VALIDATION_ERROR/false, MARKET_DATA_UNAVAILABLE 3500/503/MARKET_ERROR/true; 7개 eventType), `BusinessException`, `GlobalExceptionHandler`, `build.gradle.kts`(security/web/websocket/data-jpa/data-redis/validation 존재), `Stock(ticker,name,price:Int,changeRate:Double)` + `mockMarket` 8종목, `mockCandleClose` 전역 공유(상세 버그), `ErrorScreen`(자체 Scaffold + AppBar, `ErrorType{network,serverError,notFound,unauthorized}`, `_configs` 프리셋 맵, `ErrorGalleryScreen`이 `ErrorType.values` 순회).

크로스체크로 추가된 보정:
- **C1 — 앱 부팅**: `application.yml`의 `spring.datasource.url=${SUPABASE_DB_URL}`(기본값 없음) + `data-jpa` 때문에 Supabase 환경변수 없이는 컨텍스트가 기동 실패한다. 마켓 슬라이스 로컬 구동을 위해 `local` 프로파일에서 DataSource/JPA 오토컨피그를 제외한다(§3.6).
- **C2 — 상세 화면 시그니처/주문시트**: `StockDetailScreen({required Stock stock})`로 전체 객체를 받고 내부에 `_OrderSheet`(mock 매수/매도)를 가진다. 상세를 `ticker`로 fetch하도록 바꾸되 `_OrderSheet`는 mock 그대로 둔다(§4.5).
- **C3 — ErrorType 확장**: enum 값 추가 시 `_configs` 프리셋 항목을 반드시 같이 추가(없으면 `_configs[type]!` 및 갤러리 순회가 크래시)(§5).
- **C4 — 스냅샷 가격 안정화**: sim의 random-walk `currentPrice()`를 스냅샷에 쓰면 목록↔상세 가격 불일치 + changeRate 노이즈가 생긴다. 스냅샷은 **서비스의 결정적 카탈로그**로 서빙하고, random-walk `currentPrice/subscribe`는 실시간 슬라이스 몫으로 보존한다(포트 미변경)(§3.2).

## 3. 백엔드 설계 (`com.growant.market`)

### 3.1 패키지 구조
```
com.growant.market
  MarketController.kt           # @RestController /api/market
  MarketService.kt              # 스냅샷 카탈로그 + 캔들/펀더멘털 합성
  dto/MarketRowDto.kt
  dto/StockDetailDto.kt
com.growant.common.config
  SecurityConfig.kt             # 신규 (security starter가 classpath라 필수)
```
기존 `market/port`, `market/sim`은 **변경하지 않는다**.

### 3.2 MarketService — 결정적 스냅샷 (보정 C4)
- **티커 카탈로그**(서버 소유, 현재 Flutter mock과 동일 8종목): `005930 삼성전자 76300 +5.97`, `000660 SK하이닉스 178500 +3.41`, `035720 카카오 41200 -2.10`, `035420 NAVER 198400 +1.55`, `005380 현대차 247000 -0.81`, `000270 기아 109500 +0.37`, `068270 셀트리온 187000 -1.24`, `051910 LG화학 278000 +2.08`.
- `getMarket(): List<MarketRowDto>` — 카탈로그를 그대로 반환(가격 정수원, changeRate 그대로). 목록·상세·요청 간 **일관·안정**.
- `getDetail(ticker): StockDetailDto` — 카탈로그에 없으면 `BusinessException(INVALID_TICKER)`. 있으면 행 + **종목별 결정적 10포인트 캔들**(시드 = `ticker.hashCode`, 마지막=현재가 근처) + **서버 계산 펀더멘털**(현 위젯 공식 이식: 52주최고=price×1.18, 52주최저=price×0.72, 시가총액=price×5,969,783,300/1,000,000 억원, 거래량/PER/PBR은 현 하드코딩 값 유지).
- 예외: 카탈로그 조회/합성 중 예기치 못한 오류는 `BusinessException(MARKET_DATA_UNAVAILABLE)`로 감싼다.
- `MarketDataProvider` 포트는 호출하지 않는다(스냅샷은 라이브 데이터가 아니므로). 포트는 실시간 슬라이스에서 사용.

### 3.3 MarketController
- `GET /api/market` → `ApiResponse.ok(service.getMarket())`
- `GET /api/market/{ticker}` → `ApiResponse.ok(service.getDetail(ticker))`
- 에러는 던지기만 하면 `GlobalExceptionHandler`가 envelope로 변환(기존 재사용).

### 3.4 DTO
- `MarketRowDto(ticker: String, name: String, price: Int, changeRate: Double)`
- `StockDetailDto(ticker, name, price: Int, changeRate: Double, candles: List<Int>, high52w: Int, low52w: Int, volume: Long, marketCapEok: Long, per: Double, pbr: Double)`
- 가격은 **Int(원)** — `Stock.price=Int` 및 sim scale-0과 일치, BigDecimal↔JSON↔Dart double 정밀도 마찰 회피.

### 3.5 에러
- `INVALID_TICKER` (3000/400) — 미존재 ticker
- `MARKET_DATA_UNAVAILABLE` (3500/503) — 합성/조회 실패
- 신규 ErrorCode 추가 없음(기존 시드 재사용).

### 3.6 SecurityConfig (신규, 보정 C1 포함)
- `SecurityFilterChain`: `requestMatchers("/api/market/**").permitAll()`, `anyRequest().authenticated()`, `csrf.disable()`, `sessionManagement = STATELESS`. (마켓만 좁게 개방; 다른 경로는 각 기능 슬라이스가 자기 permit 추가.)
- **부팅(C1)**: `application-local.yml` 추가 — `spring.autoconfigure.exclude: [DataSourceAutoConfiguration, DataSourceTransactionManagerAutoConfiguration, HibernateJpaAutoConfiguration]` 로 Supabase 없이 기동 가능. 실행: `./gradlew bootRun --args='--spring.profiles.active=local'`. (영속성 필요한 첫 기능 슬라이스에서 프로파일 정비.) 메인 `application.yml`은 변경하지 않는다.
- CORS: Flutter **모바일 네이티브는 CORS 무관**. Flutter Web으로 띄울 경우에만 마켓 경로 CORS 허용 추가(현재 범위에선 불필요, 메모만).

## 4. 프론트엔드 설계 (표준 패턴 확립)

### 4.1 구조
```
lib/core/api/api_client.dart        # Dio 인스턴스(baseUrl) + 에러 인터셉터
lib/core/api/api_exception.dart     # ApiException(eventType, code, message, retryable)
lib/core/error/error_view.dart      # Scaffold 없는 ErrorView (ErrorScreen에서 추출)
lib/features/market/data/market_models.dart      # MarketRow, StockDetail (+ fromJson)
lib/features/market/data/market_repository.dart  # dio 호출 → 모델
lib/features/market/application/market_providers.dart
```

### 4.2 API 클라이언트 / 에러 인터셉터
- `Dio(BaseOptions(baseUrl: ...))`. 응답 인터셉터가 `ApiResponse` envelope를 언랩: `success==true`면 `data` 통과, `success==false`면 `ApiException(error.eventType, error.code, error.message, error.retryable)` throw. dio 연결/타임아웃 오류 → `ApiException(eventType='NETWORK', retryable=true)`.

### 4.3 모델 (수동 fromJson, codegen 없음)
- `MarketRow(ticker, name, price:int, changeRate:double)`
- `StockDetail(ticker, name, price, changeRate, candles:List<int>, high52w, low52w, volume, marketCapEok, per, pbr)`

### 4.4 Providers (Riverpod)
- `marketListProvider`: `AsyncNotifier<List<MarketRow>>` — `build()`에서 `repo.fetchMarket()`, `refresh()` 액션 제공.
- `stockDetailProvider`: `FutureProvider.family<StockDetail, String>((ref, ticker) => repo.fetchDetail(ticker))`.
- `main.dart`를 `ProviderScope`로 감싼다.

### 4.5 화면 연결
- `market_dashboard_screen`: `ref.watch(marketListProvider).when(loading: 스피너, error: ErrorView(매핑), data: 기존 목록 렌더)`. 상승/하락 집계는 데이터의 changeRate 부호(기존 로직 유지). 검색 필터도 유지.
- 타일 `onTap`: `StockDetailScreen(ticker: row.ticker)`로 변경(기존엔 `Stock` 객체 전달 → **C2**: ticker 전달로 변경).
- `stock_detail_screen`: `StockDetailScreen({required String ticker})`. `ref.watch(stockDetailProvider(ticker)).when(...)`. 차트는 `detail.candles`(종목별 — 전역 `mockCandleClose` 버그 수정). 펀더멘털은 `detail`의 서버 값 사용.
  - **`_OrderSheet`는 mock 유지(C2)**: 로드된 `detail`(name/price)로 동작하되 주문 자체는 기존 SnackBar mock 그대로(거래 슬라이스에서 실연동).

## 5. 에러 처리 계약 (보정 산출물)

- 권위는 **서버 envelope**: 사용자 메시지와 재시도 여부(`retryable`)는 서버 값을 그대로 사용. 클라 매핑은 **아이콘/제목 프리셋 선택만** 담당(→ lossy 매핑 문제 제거).
- `ErrorView(eventType, message, retryable, onRetry)`: `eventType`으로 프리셋(아이콘/제목) 선택, `message`는 서버 값 표시, `retryable && onRetry!=null`일 때만 "다시 시도" 버튼.
- `ErrorScreen`은 `ErrorView`를 Scaffold로 감싸 위임(라우트형 사용 유지). 대시보드 탭 본문에는 `ErrorView`(Scaffold 없음)를 직접 사용(중첩 회피).
- `ErrorType`에 `serviceUnavailable` 1개 추가 + **`_configs` 항목 동반(C3)**.
- eventType → 프리셋 매핑(이 슬라이스가 실제로 만나는 것 위주, 나머지는 기본값 + 해당 기능 슬라이스에서 보강):

  | eventType (서버) | ErrorView 프리셋 |
  |---|---|
  | `NETWORK`(클라 dio 오류) | network |
  | `AUTH_ERROR` | unauthorized |
  | `VALIDATION_ERROR` (INVALID_TICKER) | notFound("존재하지 않는 종목") |
  | `MARKET_ERROR` / `SYSTEM_ERROR`(503) | serviceUnavailable |
  | `SYSTEM_ERROR`(500) | serverError |
  | 기타(ORDER/AI/PAYMENT) | serverError(기본) — 해당 기능 슬라이스에서 정교화 |

## 6. 데이터 흐름

1. 앱 시작 → `ProviderScope`.
2. 대시보드 mount → `marketListProvider` → `repo.fetchMarket()` → dio `GET /api/market` → 인터셉터 언랩 → `List<MarketRow>` → 렌더. 로딩=스피너, 실패=`ErrorView`(retry→`ref.refresh`).
3. 타일 탭 → `StockDetailScreen(ticker)` → `stockDetailProvider(ticker)` → `GET /api/market/{ticker}` → `StockDetail` → 가격/등락/**종목별 캔들**/펀더멘털 렌더. 미존재 ticker → `INVALID_TICKER` → notFound 프리셋.

## 7. 테스트 (goal-driven: 먼저 실패 테스트 → 통과)

**백엔드**
- `@WebMvcTest(MarketController)` (full context 회피 → Supabase/Redis 안 띄움):
  - `GET /api/market` → 200, `success=true`, 8개 행, 첫 행 005930/삼성전자.
  - `GET /api/market/005930` → 200, candles 10개, 펀더멘털 필드 존재.
  - `GET /api/market/999999` → 400, `success=false`, `error.code=INVALID_TICKER`, `error.eventType=VALIDATION_ERROR`.
- `MarketService` 단위: 같은 ticker로 두 번 호출 시 캔들/가격 **결정적 동일**(안정성 회귀 방지).

**프론트**
- `market_repository_test`: dio `MockAdapter`로 envelope 언랩(성공), 실패 envelope → `ApiException`(eventType/retryable 매핑), 연결오류 → NETWORK.
- `market_providers_test`: `marketListProvider` AsyncValue loading→data, 오류→error.
- 위젯 테스트: 대시보드 loading/data/error 3상태 렌더.

## 8. 새 의존성 & 설정

- 프론트: `flutter_riverpod ^2.5`, `dio ^5.4`; (dev) dio `http_mock_adapter`(또는 dio 내장 MockAdapter).
- 백엔드: **추가 의존성 없음**(전부 classpath). 신규 코드 파일만(Controller/Service/DTO/SecurityConfig) + `application-local.yml`.
- 프론트 baseUrl(설정 1곳, `--dart-define` 또는 상수): iOS 시뮬레이터 `http://localhost:8080`, Android 에뮬레이터 `http://10.0.2.2:8080`.

## 9. 성공 기준 (Acceptance)

1. `./gradlew bootRun --args='--spring.profiles.active=local'`로 **Supabase 없이 백엔드 기동**, 위 3개 엔드포인트 동작.
2. Flutter 앱에서 마켓 탭이 **실제 API 데이터**로 목록 렌더(로딩 스피너 → 데이터), 백엔드 down 시 `ErrorView` + 재시도.
3. 종목 탭 시 상세가 API로 로드되고 **종목별 캔들**이 보임(전역 공유 아님). 미존재 ticker는 notFound.
4. 백엔드·프론트 테스트 그린, `flutter analyze` 무경고.
5. 도입한 `core/api` + repository + provider + DTO + ErrorView 패턴이 이후 기능에 복제 가능한 형태로 문서화.

## 10. 실시간 슬라이스로의 확장(미구현, 차단 없음 확인)
- 백엔드: `SimulatedMarketDataProvider.subscribe()`(현 TODO)에 스케줄러로 `onTick(Tick)` 발행 → market에서 Redis pub/sub → STOMP(`/ws/**`, nginx 라우팅 기존) 브로드캐스트. REST 스냅샷은 초기 로드로 유지. `Tick.price/changeRate` 필드는 이미 존재.
- 프론트: 동일 `MarketRepository` 뒤에 `web_socket_channel`/STOMP + `StreamProvider` 추가, `AsyncNotifier`가 스냅샷 초기화 후 틱 병합. 화면/DTO/ErrorView 변경 없음.
- KIS 전환: `@ConditionalOnProperty(market.provider=kis)` 드롭인, Controller/Service/DTO/프론트 무변경.
