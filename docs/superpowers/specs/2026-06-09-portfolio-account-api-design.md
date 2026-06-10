# 포트폴리오·자산 요약 백엔드 슬라이스 — 설계

**작성일:** 2026-06-09
**대상:** 백엔드(`backend/`) + Flutter 프론트엔드(`frontend/`)

## 1. 목표

대결 포트폴리오(내/AI 보유종목·수익률)와 홈 자산 요약 카드를 mock에서 실 API로 이전한다.
- `PortfolioDetailScreen`(보유종목·따라사기)과 홈 대결 카드의 내/AI 수익률 → `GET /api/portfolio/{me|ai}`
- 홈 최상단 자산 카드(총 평가 자산·수익률) → `GET /api/account/summary`

market 슬라이스에서 확립한 패턴(백엔드 Controller→Service→DTO, 프론트 models→repository→provider→화면)을 미러링한다.

## 2. 범위 / 제약 (확정 사항)

- **API 형태:** 포트폴리오는 **2개 엔드포인트**(`/api/portfolio/me`, `/api/portfolio/ai`). 대결 단일 엔드포인트는 채택하지 않음.
- **서버 권위 합산:** 합산 cost/value/profit/returnRate는 **백엔드가 계산**해 응답에 포함. 클라 순수함수 4개(`portfolioCost/Value/Profit/ReturnRate`)는 제거하고 검증 책임을 백엔드 ServiceTest로 이동.
- **현재가 단일 원천:** 포트폴리오 보유종목의 currentPrice는 **MarketService 카탈로그에서 조회**(중복 저장 금지) → 마켓/홈/포트폴리오 가격 자동 일치.
- **자산 카드 포함:** 파생 이슈(자산 배지가 mockMyReturn 사용) 해결을 위해 홈 자산 카드도 이번에 API 이전. 단, **계정 탭 화면은 제외**(mockTotalAsset/mockCash/mockStockValue/mockSeed 유지 — 거래 슬라이스에서 다룸).
- **D-day 연기:** `mockDuelDDay`는 대결 메타 — 이번에 유지하고 **다음(대결) 슬라이스로 연기**.
- **죽은 mock 제거:** `mockAsset`, `mockMyReturn`, `mockAiReturn`, `mockMyHoldings`, `mockAiHoldings`, mock `Holding` 클래스 제거. `Holding`은 `features/duel/data/portfolio_models.dart`의 타입드 모델(fromJson)로 대체.
- **홈 카드 UX:** 자산 카드·대결 카드 모두 WatchlistCard와 동일한 **컴팩트 인라인** 로딩/에러(+재시도). 상세 화면(`PortfolioDetailScreen`)은 StockDetailScreen과 동일한 **전체 ErrorView**.
- **수치 보존:** 기존 검증된 수치 유지 — 내 +5.2% / AI +3.8% / 자산 10,520,000원 +5.2%.

## 3. 백엔드 설계

### 3.1 `com.growant.portfolio` (신규 패키지)

**`PortfolioController`**
```kotlin
@RestController
@RequestMapping("/api/portfolio")
class PortfolioController(private val service: PortfolioService) {
    @GetMapping("/me") fun me(): ApiResponse<PortfolioDto> = ApiResponse.ok(service.getPortfolio(PortfolioOwner.ME))
    @GetMapping("/ai") fun ai(): ApiResponse<PortfolioDto> = ApiResponse.ok(service.getPortfolio(PortfolioOwner.AI))
}
```

**`PortfolioService`** — 결정적 보유종목 카탈로그(수량·평균단가만 보유):

| owner | 종목 | qty | avgPrice |
|---|---|---:|---:|
| ME | 삼성전자 005930 | 12 | 70,000 |
| ME | SK하이닉스 000660 | 4 | 185,000 |
| ME | NAVER 035420 | 3 | 189,000 |
| ME | 기아 000270 | 6 | 98,700 |
| AI | 삼성전자 005930 | 8 | 73,500 |
| AI | LG화학 051910 | 3 | 272,000 |
| AI | 셀트리온 068270 | 5 | 192,000 |
| AI | 카카오 035720 | 20 | 36,110 |

- `currentPrice`·`name`은 `MarketService.getMarket()` 결과에서 ticker로 조회.
- 합산: `cost = Σ(avgPrice×qty)`, `value = Σ(currentPrice×qty)`, `profit = value−cost`, `returnRate = profit/cost×100`.
- 기대값(마켓 카탈로그 가격 기준): ME profit +142,600 / rate 5.2% · AI profit +117,200 / rate 3.8%.

**DTO**
```kotlin
data class HoldingDto(val ticker: String, val name: String, val qty: Int, val avgPrice: Int, val currentPrice: Int)
data class PortfolioDto(val returnRate: Double, val profit: Long, val cost: Long, val value: Long, val holdings: List<HoldingDto>)
```
(returnRate는 소수 1자리 반올림으로 내려 표시값과 일치시킨다: 5.2 / 3.8)

### 3.2 `com.growant.account` (신규 패키지)

**`AccountController`** — `GET /api/account/summary` → `ApiResponse.ok(AccountSummaryDto)`

**`AccountService`** — 결정적 자산 요약: `seed=10,000,000`, `cash=2,500,000`, `stockValue=8,020,000` → `totalAsset=10,520,000`, `returnRate=(totalAsset−seed)/seed×100=5.2`. MarketService 의존 없음(계정 보유종목엔 카탈로그 외 종목(애플)이 있어 실연동은 거래 슬라이스에서).

**DTO**
```kotlin
data class AccountSummaryDto(val totalAsset: Long, val returnRate: Double)
```

### 3.3 공통
- `SecurityConfig`: `/api/portfolio/**`, `/api/account/**` permitAll 추가.
- 신규 ErrorCode 없음(결정적 데이터 — 404/검증 시나리오 없음, YAGNI). 예외 시 기존 GlobalExceptionHandler 동작.

### 3.4 백엔드 테스트
- `PortfolioServiceTest`: ME/AI 합산 returnRate=5.2/3.8, profit=142600/117200, currentPrice가 MarketService 카탈로그와 일치.
- `PortfolioControllerTest`(@WebMvcTest): `/me`·`/ai` 200 + envelope(success/data) + holdings 4개.
- `AccountServiceTest`: totalAsset=10,520,000, returnRate=5.2.
- `AccountControllerTest`(@WebMvcTest): `/summary` 200 + envelope.

## 4. 프론트 설계

### 4.1 duel 데이터 레이어 (market 패턴 미러)
- `features/duel/data/portfolio_models.dart`: `Holding`(ticker,name,qty,avgPrice,currentPrice + fromJson), `Portfolio`(returnRate,profit,cost,value,holdings + fromJson)
- `features/duel/data/portfolio_repository.dart`: `fetchPortfolio(PortfolioOwner owner)` — `/api/portfolio/${owner.path}` GET, DioException→ApiException 변환(기존과 동일)
- `features/duel/application/portfolio_providers.dart`: `portfolioRepositoryProvider` + `portfolioProvider = FutureProvider.family<Portfolio, PortfolioOwner>` (`PortfolioOwner { me, ai }` enum도 여기 또는 models에 정의)

### 4.2 account 데이터 레이어
- `features/account/data/account_models.dart`: `AccountSummary(totalAsset, returnRate + fromJson)`
- `features/account/data/account_repository.dart`: `fetchSummary()` — `/api/account/summary`
- `features/account/application/account_providers.dart`: `accountRepositoryProvider` + `accountSummaryProvider = FutureProvider<AccountSummary>`

### 4.3 `PortfolioDetailScreen` 개편
- 시그니처: `{title, holdings, isAi}` → `PortfolioDetailScreen({required PortfolioOwner owner})`. 타이틀('내 포트폴리오'/'AI 포트폴리오')과 따라사기 여부(ai만)는 owner에서 파생.
- `ConsumerWidget`으로 전환, `portfolioProvider(owner)` watch. 로딩=중앙 스피너, 에러=전체 `ErrorView`(+retryable 시 재시도→invalidate) — StockDetailScreen과 동일.
- 요약 카드는 서버 합산값(`portfolio.profit/returnRate/cost/value`) 표시. 행별 손익은 기존 인라인 계산 유지(avgPrice==0 가드 포함). 클라 순수함수 4개 제거.

### 4.4 홈 위젯 추출 (WatchlistCard 전례)
- **`features/home/widgets/asset_card.dart`** — `AssetCard`(ConsumerWidget): 프로필(이름·티어 — mock 유지) + `accountSummaryProvider` watch. data=총 평가 자산·수익률 배지 / loading=고정 높이 컴팩트 스피너 / error=메시지+재시도. `_ReturnBadge`는 이 파일로 이동.
- **`features/home/widgets/duel_card.dart`** — `DuelCard`(ConsumerWidget): `portfolioProvider(me)`+`portfolioProvider(ai)` 둘 다 watch. 둘 다 data면 나/AI 수익률 박스(탭→`PortfolioDetailScreen(owner)`) + 차이 배너 + D-day(`mockDuelDDay` 유지). 하나라도 loading=컴팩트 스피너, 하나라도 error=컴팩트 메시지+재시도(두 provider invalidate). `_DuelStat`은 이 파일로 이동.
- `home_screen.dart`: 자산/대결 인라인 섹션을 `const AssetCard()`/`const DuelCard()`로 교체. 두 카드 추출 후 `_SectionCard`는 미사용이 되므로 제거(카드 컨테이너 스타일은 각 위젯이 자체 보유 — WatchlistCard와 동일 방식).

### 4.5 mock 정리 (`mock_data.dart`)
- 제거: `mockAsset`, `mockMyReturn`, `mockAiReturn`, `mockMyHoldings`, `mockAiHoldings`, `class Holding`.
- 유지: `mockDuelDDay`(D-day — 대결 슬라이스로 연기), `mockUserName`/`mockUserTier`(auth 도메인), 계정 탭 mock(`mockTotalAsset`/`mockCash`/`mockStockValue`/`mockSeed`), 기타 무관 mock 전부.

## 5. 데이터 흐름

홈 `AssetCard` → `accountSummaryProvider` → `GET /api/account/summary`.
홈 `DuelCard`·상세 → `portfolioProvider(owner)` → `GET /api/portfolio/{me|ai}` → 서버가 마켓 카탈로그 가격으로 합산. 캐시는 Riverpod가 공유(홈↔상세 재요청 없음). 따라사기 → `StockDetailScreen(ticker)`(기존).

## 6. 에러 처리

- 백엔드: 기존 envelope(`ApiResponse`/`ApiError`) 그대로.
- 프론트: repository에서 DioException→ApiException(기존 헬퍼와 동일 로직). 홈 카드=컴팩트 인라인(+retryable 시 재시도), 상세=전체 ErrorView.

## 7. 테스트 (프론트)

- `test/features/duel/portfolio_repository_test.dart`: http_mock_adapter — me/ai 경로·파싱, 에러 envelope→ApiException.
- `test/features/duel/portfolio_detail_screen_test.dart`(재작성): FakeRepo+ProviderScope — ai=따라사기 N개·서버 returnRate 표시, me=따라사기 0개, 에러=ErrorView.
- `test/features/home/duel_card_test.dart`: 양측 수익률·차이 배너 표시, 에러 시 재시도 버튼.
- `test/features/home/asset_card_test.dart`: 총 자산·배지 표시, 에러 시 재시도.
- 기존 `test/features/duel/portfolio_summary_test.dart` 제거(검증 책임은 백엔드 ServiceTest로).

## 8. 파일 변경 요약

백엔드(신규): `portfolio/{PortfolioController,PortfolioService,dto/PortfolioDto}`(+`PortfolioOwner`), `account/{AccountController,AccountService,dto/AccountSummaryDto}`, 테스트 4개. 수정: `SecurityConfig`.
프론트(신규): `features/duel/{data,application}` 3파일, `features/account/{data,application}` 3파일, `features/home/widgets/{asset_card,duel_card}.dart`, 테스트 4개. 수정: `portfolio_detail_screen.dart`, `home_screen.dart`, `mock_data.dart`. 제거: `portfolio_summary_test.dart`.
