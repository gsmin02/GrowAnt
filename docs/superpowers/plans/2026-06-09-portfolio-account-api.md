# 포트폴리오·자산 요약 백엔드 슬라이스 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 대결 포트폴리오(내/AI 보유종목·수익률)와 홈 자산 요약을 mock에서 실 API(`GET /api/portfolio/{me|ai}`, `GET /api/account/summary`)로 이전한다.

**Architecture:** market 슬라이스 패턴 미러링. 백엔드는 `portfolio`/`account` 패키지 신설 — PortfolioService는 수량·평균단가만 보유하고 현재가·종목명은 MarketService 카탈로그에서 조회(가격 단일 원천), 합산(cost/value/profit/returnRate)은 서버가 계산(소수 1자리 반올림). 프론트는 models→repository→FutureProvider(.family)→화면. 홈 자산/대결 카드는 `AssetCard`/`DuelCard` 위젯으로 추출(컴팩트 인라인 로딩/에러), `PortfolioDetailScreen`은 owner 기반 ConsumerWidget(전체 ErrorView)으로 개편. 죽은 mock 제거(D-day는 유지·연기).

**Tech Stack:** Spring Boot 4 / Kotlin / JDK21 (`@WebMvcTest`는 `org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest`), Flutter + flutter_riverpod + dio + http_mock_adapter.

**Spec:** `docs/superpowers/specs/2026-06-09-portfolio-account-api-design.md`

**작업 디렉터리:** 백엔드 명령은 `backend/`, flutter 명령은 `frontend/`. 커밋은 repo 루트 기준 경로 사용.

**기대 수치(불변):** ME cost 2,739,200 / value 2,881,800 / profit +142,600 / rate 5.2 · AI cost 3,086,200 / value 3,203,400 / profit +117,200 / rate 3.8 · 자산 totalAsset 10,520,000 / rate 5.2

---

## File Structure

백엔드(신규):
- `backend/src/main/kotlin/com/growant/portfolio/PortfolioOwner.kt` — ME/AI enum
- `backend/src/main/kotlin/com/growant/portfolio/dto/PortfolioDto.kt` — HoldingDto + PortfolioDto
- `backend/src/main/kotlin/com/growant/portfolio/PortfolioService.kt` — 결정적 포지션 + 마켓가 조회 + 합산
- `backend/src/main/kotlin/com/growant/portfolio/PortfolioController.kt` — GET /me, /ai
- `backend/src/main/kotlin/com/growant/account/dto/AccountSummaryDto.kt`
- `backend/src/main/kotlin/com/growant/account/AccountService.kt` — 결정적 자산 요약
- `backend/src/main/kotlin/com/growant/account/AccountController.kt` — GET /summary
- 테스트 4: `portfolio/{PortfolioServiceTest,PortfolioControllerTest}.kt`, `account/{AccountServiceTest,AccountControllerTest}.kt`

백엔드(수정): `common/config/SecurityConfig.kt` — `/api/portfolio/**`, `/api/account/**` permitAll.

프론트(신규):
- `frontend/lib/features/duel/data/portfolio_models.dart` — PortfolioOwner enum + Holding + Portfolio
- `frontend/lib/features/duel/data/portfolio_repository.dart`
- `frontend/lib/features/duel/application/portfolio_providers.dart`
- `frontend/lib/features/account/data/account_models.dart`, `account_repository.dart`
- `frontend/lib/features/account/application/account_providers.dart`
- `frontend/lib/features/home/widgets/asset_card.dart`, `duel_card.dart`
- 테스트: `test/features/duel/portfolio_repository_test.dart`, `test/features/home/{asset_card_test,duel_card_test}.dart`

프론트(수정): `features/duel/portfolio_detail_screen.dart`(전면 개편), `features/home/home_screen.dart`, `data/mock/mock_data.dart`, `test/features/duel/portfolio_detail_screen_test.dart`(재작성).
프론트(삭제): `test/features/duel/portfolio_summary_test.dart`.

---

## Task 1: 백엔드 portfolio 슬라이스

**Files:**
- Create: `backend/src/main/kotlin/com/growant/portfolio/PortfolioOwner.kt`
- Create: `backend/src/main/kotlin/com/growant/portfolio/dto/PortfolioDto.kt`
- Create: `backend/src/main/kotlin/com/growant/portfolio/PortfolioService.kt`
- Create: `backend/src/main/kotlin/com/growant/portfolio/PortfolioController.kt`
- Modify: `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt`
- Test: `backend/src/test/kotlin/com/growant/portfolio/PortfolioServiceTest.kt`
- Test: `backend/src/test/kotlin/com/growant/portfolio/PortfolioControllerTest.kt`

- [ ] **Step 1: Write the failing service test**

Create `backend/src/test/kotlin/com/growant/portfolio/PortfolioServiceTest.kt`:

```kotlin
package com.growant.portfolio

import com.growant.market.MarketService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class PortfolioServiceTest {
    private val service = PortfolioService(MarketService())

    @Test
    fun `ME portfolio aggregates to plus 5_2 percent`() {
        val p = service.getPortfolio(PortfolioOwner.ME)
        assertThat(p.holdings).hasSize(4)
        assertThat(p.cost).isEqualTo(2_739_200L)
        assertThat(p.value).isEqualTo(2_881_800L)
        assertThat(p.profit).isEqualTo(142_600L)
        assertThat(p.returnRate).isEqualTo(5.2)
    }

    @Test
    fun `AI portfolio aggregates to plus 3_8 percent`() {
        val p = service.getPortfolio(PortfolioOwner.AI)
        assertThat(p.holdings).hasSize(4)
        assertThat(p.cost).isEqualTo(3_086_200L)
        assertThat(p.value).isEqualTo(3_203_400L)
        assertThat(p.profit).isEqualTo(117_200L)
        assertThat(p.returnRate).isEqualTo(3.8)
    }

    @Test
    fun `current prices and names come from market catalog`() {
        val market = MarketService().getMarket().associateBy { it.ticker }
        val all = service.getPortfolio(PortfolioOwner.ME).holdings +
            service.getPortfolio(PortfolioOwner.AI).holdings
        all.forEach { h ->
            assertThat(h.currentPrice).isEqualTo(market.getValue(h.ticker).price)
            assertThat(h.name).isEqualTo(market.getValue(h.ticker).name)
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && ./gradlew test --tests 'com.growant.portfolio.PortfolioServiceTest'`
Expected: 컴파일 실패(`PortfolioService`, `PortfolioOwner` 미정의).

- [ ] **Step 3: Create enum + DTO + Service**

Create `backend/src/main/kotlin/com/growant/portfolio/PortfolioOwner.kt`:

```kotlin
package com.growant.portfolio

enum class PortfolioOwner { ME, AI }
```

Create `backend/src/main/kotlin/com/growant/portfolio/dto/PortfolioDto.kt`:

```kotlin
package com.growant.portfolio.dto

data class HoldingDto(
    val ticker: String,
    val name: String,
    val qty: Int,
    val avgPrice: Int,
    val currentPrice: Int,
)

data class PortfolioDto(
    val returnRate: Double, // 소수 1자리 반올림 (표시값과 일치)
    val profit: Long,
    val cost: Long,
    val value: Long,
    val holdings: List<HoldingDto>,
)
```

Create `backend/src/main/kotlin/com/growant/portfolio/PortfolioService.kt`:

```kotlin
package com.growant.portfolio

import com.growant.market.MarketService
import com.growant.portfolio.dto.HoldingDto
import com.growant.portfolio.dto.PortfolioDto
import org.springframework.stereotype.Service
import kotlin.math.roundToLong

/**
 * 결정적 대결 포트폴리오 — 수량·평균단가만 보유한다.
 * 현재가·종목명은 MarketService 카탈로그가 단일 원천(가격 불일치 원천 차단).
 * 합산(cost/value/profit/returnRate)은 서버 권위로 계산해 내려준다.
 */
@Service
class PortfolioService(private val marketService: MarketService) {

    private data class Position(val ticker: String, val qty: Int, val avgPrice: Int)

    private val positions: Map<PortfolioOwner, List<Position>> = mapOf(
        PortfolioOwner.ME to listOf(
            Position("005930", 12, 70_000),
            Position("000660", 4, 185_000),
            Position("035420", 3, 189_000),
            Position("000270", 6, 98_700),
        ),
        PortfolioOwner.AI to listOf(
            Position("005930", 8, 73_500),
            Position("051910", 3, 272_000),
            Position("068270", 5, 192_000),
            Position("035720", 20, 36_110),
        ),
    )

    fun getPortfolio(owner: PortfolioOwner): PortfolioDto {
        val market = marketService.getMarket().associateBy { it.ticker }
        val holdings = positions.getValue(owner).map { p ->
            val row = checkNotNull(market[p.ticker]) { "ticker ${p.ticker} not in market catalog" }
            HoldingDto(p.ticker, row.name, p.qty, p.avgPrice, row.price)
        }
        val cost = holdings.sumOf { it.avgPrice.toLong() * it.qty }
        val value = holdings.sumOf { it.currentPrice.toLong() * it.qty }
        val profit = value - cost
        val returnRate = if (cost == 0L) 0.0 else (profit * 1000.0 / cost).roundToLong() / 10.0
        return PortfolioDto(returnRate, profit, cost, value, holdings)
    }
}
```

- [ ] **Step 4: Run service test to verify it passes**

Run: `cd backend && ./gradlew test --tests 'com.growant.portfolio.PortfolioServiceTest'`
Expected: BUILD SUCCESSFUL, 3 tests pass.

- [ ] **Step 5: Write the failing controller test**

Create `backend/src/test/kotlin/com/growant/portfolio/PortfolioControllerTest.kt`:

```kotlin
package com.growant.portfolio

import com.growant.common.config.SecurityConfig
import com.growant.market.MarketService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

@WebMvcTest(PortfolioController::class)
@Import(SecurityConfig::class, PortfolioService::class, MarketService::class)
class PortfolioControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `GET portfolio me returns envelope with aggregates and 4 holdings`() {
        mockMvc.get("/api/portfolio/me")
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.returnRate") { value(5.2) } }
            .andExpect { jsonPath("$.data.profit") { value(142600) } }
            .andExpect { jsonPath("$.data.holdings.length()") { value(4) } }
            .andExpect { jsonPath("$.data.holdings[0].ticker") { value("005930") } }
    }

    @Test
    fun `GET portfolio ai returns envelope with aggregates`() {
        mockMvc.get("/api/portfolio/ai")
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.returnRate") { value(3.8) } }
            .andExpect { jsonPath("$.data.holdings.length()") { value(4) } }
    }
}
```

- [ ] **Step 6: Run to verify it fails**

Run: `cd backend && ./gradlew test --tests 'com.growant.portfolio.PortfolioControllerTest'`
Expected: 컴파일 실패(`PortfolioController` 미정의).

- [ ] **Step 7: Create controller + SecurityConfig permit**

Create `backend/src/main/kotlin/com/growant/portfolio/PortfolioController.kt`:

```kotlin
package com.growant.portfolio

import com.growant.common.web.ApiResponse
import com.growant.portfolio.dto.PortfolioDto
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/portfolio")
class PortfolioController(private val service: PortfolioService) {

    @GetMapping("/me")
    fun me(): ApiResponse<PortfolioDto> = ApiResponse.ok(service.getPortfolio(PortfolioOwner.ME))

    @GetMapping("/ai")
    fun ai(): ApiResponse<PortfolioDto> = ApiResponse.ok(service.getPortfolio(PortfolioOwner.AI))
}
```

In `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt`, find:

```kotlin
                it.requestMatchers("/api/market/**").permitAll()
```

Replace with:

```kotlin
                it.requestMatchers("/api/market/**").permitAll()
                it.requestMatchers("/api/portfolio/**").permitAll()
```

- [ ] **Step 8: Run controller test to verify it passes**

Run: `cd backend && ./gradlew test --tests 'com.growant.portfolio.*'`
Expected: 5 tests pass (Service 3 + Controller 2).

- [ ] **Step 9: Full backend test + commit**

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL (기존 market 테스트 포함 전부 통과).

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/main/kotlin/com/growant/portfolio backend/src/test/kotlin/com/growant/portfolio backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt
git commit -m "feat(portfolio): GET /api/portfolio/{me|ai} — 서버 권위 합산, 현재가=마켓 카탈로그"
```

---

## Task 2: 백엔드 account 슬라이스

**Files:**
- Create: `backend/src/main/kotlin/com/growant/account/dto/AccountSummaryDto.kt`
- Create: `backend/src/main/kotlin/com/growant/account/AccountService.kt`
- Create: `backend/src/main/kotlin/com/growant/account/AccountController.kt`
- Modify: `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt`
- Test: `backend/src/test/kotlin/com/growant/account/AccountServiceTest.kt`
- Test: `backend/src/test/kotlin/com/growant/account/AccountControllerTest.kt`

- [ ] **Step 1: Write the failing tests**

Create `backend/src/test/kotlin/com/growant/account/AccountServiceTest.kt`:

```kotlin
package com.growant.account

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class AccountServiceTest {
    private val service = AccountService()

    @Test
    fun `summary returns deterministic total asset and return rate`() {
        val s = service.getSummary()
        assertThat(s.totalAsset).isEqualTo(10_520_000L)
        assertThat(s.returnRate).isEqualTo(5.2)
    }
}
```

Create `backend/src/test/kotlin/com/growant/account/AccountControllerTest.kt`:

```kotlin
package com.growant.account

import com.growant.common.config.SecurityConfig
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

@WebMvcTest(AccountController::class)
@Import(SecurityConfig::class, AccountService::class)
class AccountControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `GET account summary returns envelope`() {
        mockMvc.get("/api/account/summary")
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.totalAsset") { value(10520000) } }
            .andExpect { jsonPath("$.data.returnRate") { value(5.2) } }
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd backend && ./gradlew test --tests 'com.growant.account.*'`
Expected: 컴파일 실패(`AccountService` 등 미정의).

- [ ] **Step 3: Create DTO + Service + Controller + SecurityConfig permit**

Create `backend/src/main/kotlin/com/growant/account/dto/AccountSummaryDto.kt`:

```kotlin
package com.growant.account.dto

data class AccountSummaryDto(
    val totalAsset: Long,
    val returnRate: Double, // 소수 1자리 반올림
)
```

Create `backend/src/main/kotlin/com/growant/account/AccountService.kt`:

```kotlin
package com.growant.account

import com.growant.account.dto.AccountSummaryDto
import org.springframework.stereotype.Service
import kotlin.math.roundToLong

/**
 * 결정적 자산 요약(시드 1,000만 · 현금 250만 · 주식 802만).
 * 계정 보유종목엔 카탈로그 외 종목(애플)이 있어 마켓 연동은 거래 슬라이스에서 대체한다.
 */
@Service
class AccountService {
    private val seed = 10_000_000L
    private val cash = 2_500_000L
    private val stockValue = 8_020_000L

    fun getSummary(): AccountSummaryDto {
        val totalAsset = cash + stockValue
        val returnRate = ((totalAsset - seed) * 1000.0 / seed).roundToLong() / 10.0
        return AccountSummaryDto(totalAsset = totalAsset, returnRate = returnRate)
    }
}
```

Create `backend/src/main/kotlin/com/growant/account/AccountController.kt`:

```kotlin
package com.growant.account

import com.growant.account.dto.AccountSummaryDto
import com.growant.common.web.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/account")
class AccountController(private val service: AccountService) {

    @GetMapping("/summary")
    fun summary(): ApiResponse<AccountSummaryDto> = ApiResponse.ok(service.getSummary())
}
```

In `SecurityConfig.kt`, find:

```kotlin
                it.requestMatchers("/api/portfolio/**").permitAll()
```

Replace with:

```kotlin
                it.requestMatchers("/api/portfolio/**").permitAll()
                it.requestMatchers("/api/account/**").permitAll()
```

- [ ] **Step 4: Run to verify pass + full backend test**

Run: `cd backend && ./gradlew test --tests 'com.growant.account.*'` → 2 tests pass.
Run: `cd backend && ./gradlew test` → BUILD SUCCESSFUL 전체 통과.

- [ ] **Step 5: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/main/kotlin/com/growant/account backend/src/test/kotlin/com/growant/account backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt
git commit -m "feat(account): GET /api/account/summary — 결정적 자산 요약(총평가·수익률)"
```

---

## Task 3: 프론트 duel 데이터 레이어 (models·repository·providers)

**Files:**
- Create: `frontend/lib/features/duel/data/portfolio_models.dart`
- Create: `frontend/lib/features/duel/data/portfolio_repository.dart`
- Create: `frontend/lib/features/duel/application/portfolio_providers.dart`
- Test: `frontend/test/features/duel/portfolio_repository_test.dart`

- [ ] **Step 1: Write the failing repository test**

Create `frontend/test/features/duel/portfolio_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/duel/data/portfolio_models.dart';
import 'package:growant/features/duel/data/portfolio_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late PortfolioRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = PortfolioRepository(dio);
  });

  test('fetchPortfolio(me)는 envelope를 풀어 서버 합산값과 보유종목을 파싱한다', () async {
    adapter.onGet('/api/portfolio/me', (s) => s.reply(200, {
          'success': true,
          'data': {
            'returnRate': 5.2,
            'profit': 142600,
            'cost': 2739200,
            'value': 2881800,
            'holdings': [
              {'ticker': '005930', 'name': '삼성전자', 'qty': 12, 'avgPrice': 70000, 'currentPrice': 76300}
            ],
          },
        }));
    final p = await repo.fetchPortfolio(PortfolioOwner.me);
    expect(p.returnRate, 5.2);
    expect(p.profit, 142600);
    expect(p.holdings, hasLength(1));
    expect(p.holdings.first.ticker, '005930');
  });

  test('fetchPortfolio(ai)는 /api/portfolio/ai를 호출한다', () async {
    adapter.onGet('/api/portfolio/ai', (s) => s.reply(200, {
          'success': true,
          'data': {'returnRate': 3.8, 'profit': 117200, 'cost': 3086200, 'value': 3203400, 'holdings': []},
        }));
    final p = await repo.fetchPortfolio(PortfolioOwner.ai);
    expect(p.returnRate, 3.8);
  });

  test('에러 envelope는 ApiException으로 매핑된다', () async {
    adapter.onGet('/api/portfolio/me', (s) => s.reply(503, {
          'success': false,
          'error': {'code': 'SERVICE_UNAVAILABLE', 'eventType': 'SYSTEM_ERROR', 'message': '잠시 후 다시 시도해 주세요.', 'retryable': true}
        }));
    await expectLater(
      repo.fetchPortfolio(PortfolioOwner.me),
      throwsA(isA<ApiException>()
          .having((e) => e.eventType, 'eventType', 'SYSTEM_ERROR')
          .having((e) => e.retryable, 'retryable', true)),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd frontend && flutter test test/features/duel/portfolio_repository_test.dart`
Expected: 컴파일 에러(파일 미존재).

- [ ] **Step 3: Create models + repository + providers**

Create `frontend/lib/features/duel/data/portfolio_models.dart`:

```dart
/// 대결 포트폴리오 주체. path=API 경로 세그먼트, title=상세 화면 타이틀.
enum PortfolioOwner {
  me('me', '내 포트폴리오'),
  ai('ai', 'AI 포트폴리오');

  final String path;
  final String title;
  const PortfolioOwner(this.path, this.title);

  bool get isAi => this == PortfolioOwner.ai;
}

class Holding {
  final String ticker;
  final String name;
  final int qty;
  final int avgPrice;
  final int currentPrice;
  const Holding({
    required this.ticker,
    required this.name,
    required this.qty,
    required this.avgPrice,
    required this.currentPrice,
  });

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        ticker: j['ticker'] as String,
        name: j['name'] as String,
        qty: (j['qty'] as num).toInt(),
        avgPrice: (j['avgPrice'] as num).toInt(),
        currentPrice: (j['currentPrice'] as num).toInt(),
      );
}

/// 서버 권위 합산값 포함(returnRate는 소수 1자리 반올림되어 내려온다).
class Portfolio {
  final double returnRate;
  final int profit;
  final int cost;
  final int value;
  final List<Holding> holdings;
  const Portfolio({
    required this.returnRate,
    required this.profit,
    required this.cost,
    required this.value,
    required this.holdings,
  });

  factory Portfolio.fromJson(Map<String, dynamic> j) => Portfolio(
        returnRate: (j['returnRate'] as num).toDouble(),
        profit: (j['profit'] as num).toInt(),
        cost: (j['cost'] as num).toInt(),
        value: (j['value'] as num).toInt(),
        holdings: (j['holdings'] as List)
            .map((e) => Holding.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

Create `frontend/lib/features/duel/data/portfolio_repository.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'portfolio_models.dart';

class PortfolioRepository {
  final Dio _dio;
  const PortfolioRepository(this._dio);

  Future<Portfolio> fetchPortfolio(PortfolioOwner owner) async {
    try {
      final res = await _dio.get('/api/portfolio/${owner.path}');
      return Portfolio.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : const ApiException(eventType: 'NETWORK', code: 'ERR_NETWORK', message: '인터넷 연결을 확인해주세요.', retryable: true);
}
```

Create `frontend/lib/features/duel/application/portfolio_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../market/application/market_providers.dart';
import '../data/portfolio_models.dart';
import '../data/portfolio_repository.dart';

final portfolioRepositoryProvider =
    Provider<PortfolioRepository>((ref) => PortfolioRepository(ref.watch(dioProvider)));

final portfolioProvider = FutureProvider.family<Portfolio, PortfolioOwner>(
  (ref, owner) => ref.watch(portfolioRepositoryProvider).fetchPortfolio(owner),
);
```

- [ ] **Step 4: Run test to verify it passes + analyze**

Run: `cd frontend && flutter test test/features/duel/portfolio_repository_test.dart` → 3 tests pass.
Run: `cd frontend && flutter analyze` → `No issues found!`

- [ ] **Step 5: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/duel/data frontend/lib/features/duel/application frontend/test/features/duel/portfolio_repository_test.dart
git commit -m "feat(duel): 포트폴리오 모델·repository·provider (GET /api/portfolio/{me|ai})"
```

---

## Task 4: 프론트 account 데이터 레이어 + AssetCard + 홈 자산 섹션 교체

**Files:**
- Create: `frontend/lib/features/account/data/account_models.dart`
- Create: `frontend/lib/features/account/data/account_repository.dart`
- Create: `frontend/lib/features/account/application/account_providers.dart`
- Create: `frontend/lib/features/home/widgets/asset_card.dart`
- Modify: `frontend/lib/features/home/home_screen.dart`
- Test: `frontend/test/features/home/asset_card_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `frontend/test/features/home/asset_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/account/application/account_providers.dart';
import 'package:growant/features/account/data/account_models.dart';
import 'package:growant/features/account/data/account_repository.dart';
import 'package:growant/features/home/widgets/asset_card.dart';

class _FakeRepo implements AccountRepository {
  final AccountSummary? summary;
  final Object? error;
  _FakeRepo({this.summary, this.error});

  @override
  Future<AccountSummary> fetchSummary() async {
    if (error != null) throw error!;
    return summary!;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(AccountRepository repo) => ProviderScope(
      overrides: [accountRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: AssetCard())),
    );

void main() {
  testWidgets('자산 요약(총평가·수익률 배지)을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
        summary: const AccountSummary(totalAsset: 10520000, returnRate: 5.2))));
    await tester.pump();
    expect(find.text('10,520,000원'), findsOneWidget);
    expect(find.text('+5.20%'), findsOneWidget);
  });

  testWidgets('에러 시 메시지와 재시도 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'SYSTEM_ERROR', code: 'SERVICE_UNAVAILABLE', message: '잠시 후 다시 시도해 주세요.', retryable: true),
    )));
    await tester.pump();
    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '재시도'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd frontend && flutter test test/features/home/asset_card_test.dart`
Expected: 컴파일 에러(파일 미존재).

- [ ] **Step 3: Create account data layer**

Create `frontend/lib/features/account/data/account_models.dart`:

```dart
class AccountSummary {
  final int totalAsset;
  final double returnRate;
  const AccountSummary({required this.totalAsset, required this.returnRate});

  factory AccountSummary.fromJson(Map<String, dynamic> j) => AccountSummary(
        totalAsset: (j['totalAsset'] as num).toInt(),
        returnRate: (j['returnRate'] as num).toDouble(),
      );
}
```

Create `frontend/lib/features/account/data/account_repository.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'account_models.dart';

class AccountRepository {
  final Dio _dio;
  const AccountRepository(this._dio);

  Future<AccountSummary> fetchSummary() async {
    try {
      final res = await _dio.get('/api/account/summary');
      return AccountSummary.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : const ApiException(eventType: 'NETWORK', code: 'ERR_NETWORK', message: '인터넷 연결을 확인해주세요.', retryable: true);
}
```

Create `frontend/lib/features/account/application/account_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../market/application/market_providers.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository(ref.watch(dioProvider)));

final accountSummaryProvider = FutureProvider<AccountSummary>(
  (ref) => ref.watch(accountRepositoryProvider).fetchSummary(),
);
```

- [ ] **Step 4: Create AssetCard**

Create `frontend/lib/features/home/widgets/asset_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../data/mock/mock_data.dart';
import '../../account/application/account_providers.dart';

/// 홈 자산 요약 카드 — accountSummaryProvider(GET /api/account/summary).
/// 프로필(이름·티어)은 auth 도메인이라 mock 유지. 로딩/에러는 컴팩트 인라인.
class AssetCard extends ConsumerWidget {
  const AssetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,###');
    final async = ref.watch(accountSummaryProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(mockUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              _TierChip(tier: mockUserTier),
            ],
          ),
          const SizedBox(height: 16),
          Text('총 평가 자산',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF888888))),
          const SizedBox(height: 4),
          async.when(
            loading: () => const SizedBox(
              height: 58,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (e, _) => _AssetError(
              message: e is ApiException ? e.message : '자산 정보를 불러오지 못했어요',
              onRetry: (e is ApiException ? e.retryable : true)
                  ? () => ref.invalidate(accountSummaryProvider)
                  : null,
            ),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmt.format(s.totalAsset)}원',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _ReturnBadge(rate: s.returnRate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 내부 컴팩트 에러(메시지 + 재시도). retryable=false면 메시지만.
class _AssetError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _AssetError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('재시도'),
            ),
        ],
      ),
    );
  }
}

class _ReturnBadge extends StatelessWidget {
  final double rate;
  const _ReturnBadge({required this.rate});

  @override
  Widget build(BuildContext context) {
    final isUp = rate >= 0;
    return Text(
      '${isUp ? '+' : ''}${rate.toStringAsFixed(2)}%',
      style: TextStyle(
        color: isUp ? upColor : downColor,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String tier;
  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tier,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
```

- [ ] **Step 5: home_screen.dart — 자산 섹션 교체**

In `frontend/lib/features/home/home_screen.dart`:

(a) import 추가 — `import 'widgets/watchlist_card.dart';` 줄 바로 아래:

```dart
import 'widgets/asset_card.dart';
```

(b) build 안의 자산 `_SectionCard` 블록(아래 전체)을:

```dart
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(mockUserName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  _TierChip(tier: mockUserTier),
                ],
              ),
              const SizedBox(height: 16),
              Text('총 평가 자산',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF888888))),
              const SizedBox(height: 4),
              Text(
                '${fmt.format(mockAsset)}원',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _ReturnBadge(rate: mockMyReturn),
            ],
          ),
        ),
```

다음 한 줄로 교체:

```dart
        const AssetCard(),
```

(c) `final fmt = NumberFormat('#,###');` 줄 삭제(자산 블록이 유일한 사용처였음) + `import 'package:intl/intl.dart';` 삭제.

(d) 파일 하단의 `_TierChip` 클래스와 `_ReturnBadge` 클래스 전체 삭제(AssetCard로 이동).

- [ ] **Step 6: Verify**

Run: `cd frontend && flutter test test/features/home/asset_card_test.dart` → 2 tests pass.
Run: `cd frontend && flutter analyze` → `No issues found!`
Run: `cd frontend && flutter test` → 전부 통과.

- [ ] **Step 7: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/account frontend/lib/features/home/widgets/asset_card.dart frontend/lib/features/home/home_screen.dart frontend/test/features/home/asset_card_test.dart
git commit -m "feat(home): 자산 요약 카드 AssetCard — GET /api/account/summary 연동"
```

---

## Task 5: PortfolioDetailScreen owner 개편 + DuelCard + 홈 대결 섹션 교체

**Files:**
- Modify(전면 재작성): `frontend/lib/features/duel/portfolio_detail_screen.dart`
- Create: `frontend/lib/features/home/widgets/duel_card.dart`
- Modify: `frontend/lib/features/home/home_screen.dart`
- Test(재작성): `frontend/test/features/duel/portfolio_detail_screen_test.dart`
- Test: `frontend/test/features/home/duel_card_test.dart`
- Delete: `frontend/test/features/duel/portfolio_summary_test.dart`

- [ ] **Step 1: Rewrite the failing widget tests**

Overwrite `frontend/test/features/duel/portfolio_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/core/error/error_view.dart';
import 'package:growant/features/duel/application/portfolio_providers.dart';
import 'package:growant/features/duel/data/portfolio_models.dart';
import 'package:growant/features/duel/data/portfolio_repository.dart';
import 'package:growant/features/duel/portfolio_detail_screen.dart';

const _myPortfolio = Portfolio(
  returnRate: 5.2, profit: 142600, cost: 2739200, value: 2881800,
  holdings: [
    Holding(ticker: '005930', name: '삼성전자', qty: 12, avgPrice: 70000, currentPrice: 76300),
    Holding(ticker: '000660', name: 'SK하이닉스', qty: 4, avgPrice: 185000, currentPrice: 178500),
  ],
);

const _aiPortfolio = Portfolio(
  returnRate: 3.8, profit: 117200, cost: 3086200, value: 3203400,
  holdings: [
    Holding(ticker: '005930', name: '삼성전자', qty: 8, avgPrice: 73500, currentPrice: 76300),
    Holding(ticker: '051910', name: 'LG화학', qty: 3, avgPrice: 272000, currentPrice: 278000),
    Holding(ticker: '068270', name: '셀트리온', qty: 5, avgPrice: 192000, currentPrice: 187000),
    Holding(ticker: '035720', name: '카카오', qty: 20, avgPrice: 36110, currentPrice: 41200),
  ],
);

class _FakeRepo implements PortfolioRepository {
  final Object? error;
  _FakeRepo({this.error});

  @override
  Future<Portfolio> fetchPortfolio(PortfolioOwner owner) async {
    if (error != null) throw error!;
    return owner == PortfolioOwner.me ? _myPortfolio : _aiPortfolio;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(PortfolioRepository repo, PortfolioOwner owner) => ProviderScope(
      overrides: [portfolioRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: PortfolioDetailScreen(owner: owner)),
    );

void main() {
  testWidgets('AI 화면은 따라사기 버튼을 종목 수만큼 렌더하고 서버 합산 +3.8% 표시', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(), PortfolioOwner.ai));
    await tester.pump();
    expect(find.widgetWithText(OutlinedButton, '따라사기'), findsNWidgets(4));
    expect(find.text('+3.8%'), findsOneWidget);
    expect(find.text('AI 포트폴리오'), findsOneWidget);
  });

  testWidgets('나 화면은 따라사기 버튼이 없고 서버 합산 +5.2% 표시', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(), PortfolioOwner.me));
    await tester.pump();
    expect(find.widgetWithText(OutlinedButton, '따라사기'), findsNothing);
    expect(find.text('+5.2%'), findsOneWidget);
    expect(find.text('내 포트폴리오'), findsOneWidget);
  });

  testWidgets('에러 시 ErrorView를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(
        _FakeRepo(
            error: const ApiException(
                eventType: 'SYSTEM_ERROR', code: 'SERVICE_UNAVAILABLE', message: '잠시 후 다시 시도해 주세요.', retryable: true)),
        PortfolioOwner.me));
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);
  });
}
```

Create `frontend/test/features/home/duel_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/duel/application/portfolio_providers.dart';
import 'package:growant/features/duel/data/portfolio_models.dart';
import 'package:growant/features/duel/data/portfolio_repository.dart';
import 'package:growant/features/home/widgets/duel_card.dart';

const _my = Portfolio(returnRate: 5.2, profit: 142600, cost: 2739200, value: 2881800, holdings: []);
const _ai = Portfolio(returnRate: 3.8, profit: 117200, cost: 3086200, value: 3203400, holdings: []);

class _FakeRepo implements PortfolioRepository {
  final Object? error;
  _FakeRepo({this.error});

  @override
  Future<Portfolio> fetchPortfolio(PortfolioOwner owner) async {
    if (error != null) throw error!;
    return owner == PortfolioOwner.me ? _my : _ai;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(PortfolioRepository repo) => ProviderScope(
      overrides: [portfolioRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: DuelCard())),
    );

void main() {
  testWidgets('양측 수익률과 차이 배너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pump();
    expect(find.text('+5.2%'), findsOneWidget);
    expect(find.text('+3.8%'), findsOneWidget);
    expect(find.text('내가 AI보다 +1.4% 앞서는 중'), findsOneWidget);
  });

  testWidgets('에러 시 메시지와 재시도 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'SYSTEM_ERROR', code: 'SERVICE_UNAVAILABLE', message: '잠시 후 다시 시도해 주세요.', retryable: true),
    )));
    await tester.pump();
    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '재시도'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd frontend && flutter test test/features/duel/portfolio_detail_screen_test.dart test/features/home/duel_card_test.dart`
Expected: 컴파일 에러(`PortfolioDetailScreen(owner:)` 미정의, `DuelCard` 미존재).

- [ ] **Step 3: Rewrite portfolio_detail_screen.dart (전체 교체)**

Overwrite `frontend/lib/features/duel/portfolio_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/error/error_view.dart';
import '../../core/theme.dart';
import '../market/stock_detail_screen.dart';
import 'application/portfolio_providers.dart';
import 'data/portfolio_models.dart';

/// 나/AI 공용 대결 포트폴리오 상세 — portfolioProvider(owner) 구독.
/// 합산(수익률·손익·매입/평가금액)은 서버 권위 값을 표시. AI면 각 행에 따라사기.
class PortfolioDetailScreen extends ConsumerWidget {
  final PortfolioOwner owner;
  const PortfolioDetailScreen({super.key, required this.owner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioProvider(owner));
    return Scaffold(
      appBar: AppBar(title: Text(owner.title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final api = e is ApiException ? e : null;
          return ErrorView(
            kind: errorKindFromEventType(api?.eventType ?? 'NETWORK'),
            message: api?.message,
            onRetry: (api?.retryable ?? true)
                ? () => ref.invalidate(portfolioProvider(owner))
                : null,
          );
        },
        data: (p) => _DetailBody(portfolio: p, isAi: owner.isAi),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Portfolio portfolio;
  final bool isAi;
  const _DetailBody({required this.portfolio, required this.isAi});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(portfolio: portfolio, fmt: fmt),
        const SizedBox(height: 16),
        const Text('보유 종목',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        for (final h in portfolio.holdings) _HoldingCard(holding: h, fmt: fmt, isAi: isAi),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Portfolio portfolio;
  final NumberFormat fmt;
  const _SummaryCard({required this.portfolio, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isUp = portfolio.profit >= 0;
    final color = isUp ? upColor : downColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('평가손익',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isUp ? '+' : ''}${fmt.format(portfolio.profit)}원',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${isUp ? '+' : ''}${portfolio.returnRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryChip(label: '매입금액', value: '${fmt.format(portfolio.cost)}원'),
              const SizedBox(width: 16),
              _SummaryChip(label: '평가금액', value: '${fmt.format(portfolio.value)}원'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HoldingCard extends StatelessWidget {
  final Holding holding;
  final NumberFormat fmt;
  final bool isAi;
  const _HoldingCard({required this.holding, required this.fmt, required this.isAi});

  @override
  Widget build(BuildContext context) {
    final h = holding;
    final value = h.currentPrice * h.qty;
    final profit = (h.currentPrice - h.avgPrice) * h.qty;
    final rate = h.avgPrice == 0 ? 0.0 : (h.currentPrice - h.avgPrice) / h.avgPrice * 100;
    final isUp = profit >= 0;
    final color = isUp ? upColor : downColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${h.qty}주 · 평균 ${fmt.format(h.avgPrice)}원',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt.format(value)}원',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${isUp ? '+' : ''}${fmt.format(profit)}원 (${rate.toStringAsFixed(1)}%)',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          if (isAi) ...[
            const SizedBox(width: 10),
            _FollowBuyButton(ticker: h.ticker),
          ],
        ],
      ),
    );
  }
}

/// AI 종목 따라사기 → 해당 종목 상세 화면.
class _FollowBuyButton extends StatelessWidget {
  final String ticker;
  const _FollowBuyButton({required this.ticker});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: upColor,
        side: const BorderSide(color: upColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: ticker)),
      ),
      child: const Text('따라사기',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
```

(기존 순수함수 4개와 mock_data import는 이 재작성으로 제거된다.)

- [ ] **Step 4: Create DuelCard**

Create `frontend/lib/features/home/widgets/duel_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../data/mock/mock_data.dart';
import '../../duel/application/portfolio_providers.dart';
import '../../duel/data/portfolio_models.dart';
import '../../duel/portfolio_detail_screen.dart';

/// 홈 '진행 중인 대결' 카드 — 내/AI 포트폴리오 수익률(서버 합산) 비교.
/// D-day는 대결 메타라 mock 유지(대결 슬라이스에서 이전). 로딩/에러는 컴팩트 인라인.
class DuelCard extends ConsumerWidget {
  const DuelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAsync = ref.watch(portfolioProvider(PortfolioOwner.me));
    final aiAsync = ref.watch(portfolioProvider(PortfolioOwner.ai));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('진행 중인 대결',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _body(context, ref, myAsync, aiAsync),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref,
      AsyncValue<Portfolio> myAsync, AsyncValue<Portfolio> aiAsync) {
    if (myAsync.hasError || aiAsync.hasError) {
      final e = myAsync.error ?? aiAsync.error;
      final api = e is ApiException ? e : null;
      return _DuelError(
        message: api?.message ?? '대결 정보를 불러오지 못했어요',
        onRetry: (api?.retryable ?? true)
            ? () {
                ref.invalidate(portfolioProvider(PortfolioOwner.me));
                ref.invalidate(portfolioProvider(PortfolioOwner.ai));
              }
            : null,
      );
    }
    final my = myAsync.valueOrNull;
    final ai = aiAsync.valueOrNull;
    if (my == null || ai == null) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final returnDiff = my.returnRate - ai.returnRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _DuelStat(
                label: '나',
                value: my.returnRate,
                isMe: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const PortfolioDetailScreen(owner: PortfolioOwner.me),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: _DuelStat(
                label: '대결 AI',
                value: ai.returnRate,
                isMe: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const PortfolioDetailScreen(owner: PortfolioOwner.ai),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: returnDiff >= 0 ? upColor.withAlpha(20) : downColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              returnDiff >= 0
                  ? '내가 AI보다 +${returnDiff.toStringAsFixed(1)}% 앞서는 중'
                  : 'AI가 나보다 +${(-returnDiff).toStringAsFixed(1)}% 앞서는 중',
              style: TextStyle(
                color: returnDiff >= 0 ? upColor : downColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('종료까지 D-$mockDuelDDay일',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
      ],
    );
  }
}

/// 카드 내부 컴팩트 에러(메시지 + 재시도). retryable=false면 메시지만.
class _DuelError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _DuelError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('재시도'),
            ),
        ],
      ),
    );
  }
}

class _DuelStat extends StatelessWidget {
  final String label;
  final double value;
  final bool isMe;
  final VoidCallback? onTap;
  const _DuelStat({required this.label, required this.value, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUp = value >= 0;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, size: 15, color: Color(0xFFBBBBBB)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isUp ? upColor : downColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: content);
  }
}
```

- [ ] **Step 5: home_screen.dart — 대결 섹션 교체 + 잔여 정리**

In `frontend/lib/features/home/home_screen.dart`:

(a) import 추가 — `import 'widgets/asset_card.dart';` 줄 바로 아래:

```dart
import 'widgets/duel_card.dart';
```

(b) 대결 `_SectionCard(...)` 블록 전체(`_SectionCard(` 부터 `진행 중인 대결`·`_DuelStat`·배너·`종료까지 D-` 를 포함해 닫는 `),` 까지)를 다음 한 줄로 교체:

```dart
        const DuelCard(),
```

(c) `final returnDiff = mockMyReturn - mockAiReturn;` 줄 삭제.

(d) 이제 미사용이 된 것 제거: `_SectionCard` 클래스, `_DuelStat` 클래스, import `'../../core/theme.dart'`, import `'../../data/mock/mock_data.dart'`, import `'../duel/portfolio_detail_screen.dart'`.

최종 home_screen.dart의 import는 다음 5개만 남는다:

```dart
import 'package:flutter/material.dart';

import '../ai/ai_feedback_screen.dart';
import '../ai/psychology_screen.dart';
import 'widgets/watchlist_card.dart';
import 'widgets/asset_card.dart';
import 'widgets/duel_card.dart';
```

(클래스는 `HomeScreen`과 `_ShortcutCard`만 남는다.)

- [ ] **Step 6: Delete obsolete test**

```bash
cd /Users/gsmin/GrowAnt && git rm frontend/test/features/duel/portfolio_summary_test.dart
```

- [ ] **Step 7: Verify**

Run: `cd frontend && flutter test test/features/duel/portfolio_detail_screen_test.dart test/features/home/duel_card_test.dart` → 5 tests pass.
Run: `cd frontend && flutter analyze` → `No issues found!`
Run: `cd frontend && flutter test` → 전부 통과.

- [ ] **Step 8: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/duel/portfolio_detail_screen.dart frontend/lib/features/home/widgets/duel_card.dart frontend/lib/features/home/home_screen.dart frontend/test/features/duel/portfolio_detail_screen_test.dart frontend/test/features/home/duel_card_test.dart
git commit -m "feat(duel): 포트폴리오 상세 owner 개편(API) + 홈 DuelCard — 서버 합산 수익률"
```

---

## Task 6: 죽은 mock 제거 + 전체 검증

**Files:**
- Modify: `frontend/lib/data/mock/mock_data.dart`

- [ ] **Step 1: Remove dead mock**

In `frontend/lib/data/mock/mock_data.dart`:

(a) 파일 상단의 `Holding` 클래스 전체 삭제:

```dart
class Holding {
  final String ticker;
  final String name;
  final int qty;
  final int avgPrice;     // 평균 매입 단가
  final int currentPrice; // 현재가 (홈 마켓 시세와 일치)
  const Holding(this.ticker, this.name, this.qty, this.avgPrice, this.currentPrice);
}

```

(b) `// ── 홈 / 대결 ──` 블록을 다음으로 교체 (mockAsset·mockMyReturn·mockAiReturn 제거, mockSeed·mockDuelDDay 유지):

기존:

```dart
// ── 홈 / 대결 ──
const int mockAsset = 10520000;
const int mockSeed = 10000000;
const double mockMyReturn = 5.2;
const double mockAiReturn = 3.8;
const int mockDuelDDay = 18;
```

교체:

```dart
// ── 홈 / 대결 ──
// mockDuelDDay: 대결 메타 — 대결 슬라이스에서 API 이전 예정.
const int mockSeed = 10000000;
const int mockDuelDDay = 18;
```

(c) `// ── 대결 포트폴리오 (보유 종목 상세) ──` 주석 블록 + `mockMyHoldings` + `mockAiHoldings` 상수 전체 삭제.

- [ ] **Step 2: Verify no dangling references**

Run: `cd frontend && grep -rn "mockAsset\|mockMyReturn\|mockAiReturn\|mockMyHoldings\|mockAiHoldings" lib/ test/ || echo CLEAN`
Expected: `CLEAN`.
Run: `cd frontend && grep -rn "class Holding" lib/`
Expected: `lib/features/duel/data/portfolio_models.dart`의 1건만.

- [ ] **Step 3: Full verification (backend + frontend)**

Run: `cd backend && ./gradlew test` → BUILD SUCCESSFUL.
Run: `cd frontend && flutter analyze` → `No issues found!`
Run: `cd frontend && flutter test` → 전부 통과.

- [ ] **Step 4: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/data/mock/mock_data.dart
git commit -m "refactor(mock): 죽은 대결/자산 mock 제거 — Holding·mockAsset·수익률·보유종목 (D-day 유지)"
```

---

## Self-Review

**1. Spec coverage:**
- §3.1 portfolio Controller/Service/DTO/Owner + 서버 합산·마켓가 조회 → Task 1. ✓
- §3.2 account Service/Controller/DTO → Task 2. ✓
- §3.3 SecurityConfig 2경로 permitAll → Task 1 Step 7 + Task 2 Step 3. ✓ / 신규 ErrorCode 없음 ✓
- §3.4 백엔드 테스트 4종 → Task 1·2. ✓
- §4.1 duel 데이터 레이어 → Task 3. ✓
- §4.2 account 데이터 레이어 → Task 4. ✓
- §4.3 PortfolioDetailScreen owner 개편 + 순수함수 제거 → Task 5 Step 3. ✓
- §4.4 AssetCard/DuelCard 추출 + home 교체 + _SectionCard 제거 → Task 4 Step 5 + Task 5 Step 4·5. ✓
- §4.5 mock 정리(mockSeed·mockDuelDDay·계정탭 mock 유지) → Task 6. ✓
- §7 프론트 테스트 4종 + summary_test 제거 → Task 3·4·5. ✓

**2. Placeholder scan:** TBD/TODO/“적절히” 없음. 모든 코드 단계 완전한 코드 포함. ✓

**3. Type consistency:**
- `PortfolioOwner.me/.ai`(front, path/title/isAi) vs `PortfolioOwner.ME/AI`(backend) — 각 언어 관례, API 경로는 `owner.path`로 소문자 일치. ✓
- `Portfolio(returnRate,profit,cost,value,holdings)` = `PortfolioDto` 필드와 1:1, `Holding`(named ctor) = `HoldingDto` 1:1. ✓
- `portfolioRepositoryProvider`/`portfolioProvider(owner)`/`accountSummaryProvider` 명칭이 Task 3·4·5의 테스트·위젯에서 일관. ✓
- `dioProvider`는 `market_providers.dart`의 공개 provider 재사용. ✓
- 합산 검증값(5.2/3.8/142600/117200/2,739,200/2,881,800/3,086,200/3,203,400/10,520,000)이 backend 테스트·front 테스트·기대수치 표에서 동일. ✓
