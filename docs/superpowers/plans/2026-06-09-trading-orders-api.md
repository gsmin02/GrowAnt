# 거래(주문) 슬라이스 + env 구성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 종목 상세의 매수/매도와 내역 탭을 실 API(`POST /api/orders`, `GET /api/trades`)로 이전하고, API 설정의 env 관리(프론트 `.env` + 백엔드 로딩 골격)를 구성한다.

**Architecture:** 신규 `trading` 패키지의 `TradingService`가 유일한 가변 상태(현금 7,638,200·me 포지션·거래내역, in-memory)를 소유하고, `PortfolioService`(me)·`AccountService`(자산=현금+me평가)가 이를 조회하도록 개편. 프론트는 market 패턴(models→repo→provider)으로 내역 탭·주문 시트를 연동하고 성공 시 관련 provider를 invalidate. AI 포지션은 `NOTE(duel-ai)` anchor와 함께 하드코딩 유지.

**Tech Stack:** Spring Boot 4/Kotlin(JDK21, `@WebMvcTest`=`org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest`), Flutter+riverpod+dio+http_mock_adapter, `--dart-define-from-file`.

**Spec:** `docs/superpowers/specs/2026-06-09-trading-orders-api-design.md`

**작업 디렉터리:** 백엔드=`backend/`, flutter=`frontend/`, 커밋=repo 루트.

**핵심 수치(불변):** 초기 현금 **7,638,200** · me 평가 2,881,800 · 자산 10,520,000/+5.2% · 체결 직후 `현금+me평가` 불변 · 삼성전자 1주 매수 후 평단 round(916,300/13)=**70,485**

---

## File Structure

백엔드 — 신규: `trading/{TradingService.kt(Position 포함), TradingController.kt, dto/{TradeDto,OrderRequestDto}.kt}` + 테스트 2.
수정: `common/error/ErrorCode.kt`(+2), `common/config/SecurityConfig.kt`(+2 permit), `portfolio/PortfolioService.kt`(me 이관+AI anchor), `account/AccountService.kt`(동적 산식), 기존 테스트 4(생성자/Import 보정), `resources/application.yml`(config.import — Task 7).

프론트 — 신규: `features/trading/data/{trade_models,trade_repository}.dart`, `features/trading/application/trading_providers.dart`, 테스트 3(`trade_repository_test`, `trade_history_screen_test`, `stock_detail_order_test`).
수정: `features/market/stock_detail_screen.dart`(_OrderSheet), `features/trading/trade_history_screen.dart`(전면), `features/trading/trade_detail_screen.dart`(import), `data/mock/mock_data.dart`(Trade·mockTrades 제거), `frontend/.gitignore`(+.env).
env — 신규: `frontend/.env.example`. 수정: `README.md`.

---

## Task 1: 백엔드 TradingService (상태 소유) + ErrorCode

**Files:**
- Modify: `backend/src/main/kotlin/com/growant/common/error/ErrorCode.kt`
- Create: `backend/src/main/kotlin/com/growant/trading/dto/TradeDto.kt`
- Create: `backend/src/main/kotlin/com/growant/trading/TradingService.kt`
- Test: `backend/src/test/kotlin/com/growant/trading/TradingServiceTest.kt`

- [ ] **Step 1: ErrorCode 2개 추가**

In `ErrorCode.kt`, find:

```kotlin
    INVALID_TICKER(3000, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "존재하지 않는 종목입니다."),
```

Replace with:

```kotlin
    INVALID_TICKER(3000, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "존재하지 않는 종목입니다."),
    INVALID_ORDER(3001, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "잘못된 주문입니다."),
```

Then find:

```kotlin
    ORDER_MARKET_CLOSED(4001, HttpStatus.CONFLICT, "ORDER_ERROR", false, "장 운영 시간이 아닙니다."),
```

Replace with:

```kotlin
    ORDER_MARKET_CLOSED(4001, HttpStatus.CONFLICT, "ORDER_ERROR", false, "장 운영 시간이 아닙니다."),
    ORDER_INSUFFICIENT_HOLDINGS(4002, HttpStatus.CONFLICT, "ORDER_ERROR", false, "보유 수량이 부족합니다."),
```

- [ ] **Step 2: Write the failing service test**

Create `backend/src/test/kotlin/com/growant/trading/TradingServiceTest.kt`:

```kotlin
package com.growant.trading

import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import com.growant.market.MarketService
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class TradingServiceTest {
    private val market = MarketService()
    private val service = TradingService(market)

    private fun meValue(): Long {
        val prices = market.getMarket().associateBy { it.ticker }
        return service.getMePositions().sumOf { prices.getValue(it.ticker).price.toLong() * it.qty }
    }

    @Test
    fun `초기 상태 - 현금과 me평가 합이 자산 불변값`() {
        assertThat(service.getCash()).isEqualTo(7_638_200L)
        assertThat(meValue()).isEqualTo(2_881_800L)
        assertThat(service.getCash() + meValue()).isEqualTo(10_520_000L)
        assertThat(service.getTrades()).hasSize(6)
        assertThat(service.getTrades().first().name).isEqualTo("삼성전자")
        assertThat(service.getTrades().first().isBuy).isFalse()
    }

    @Test
    fun `매수 체결 - 현금 차감, 가중평단, 내역 prepend, 자산 불변`() {
        val before = service.getCash() + meValue()
        val t = service.placeOrder("005930", true, 1)
        assertThat(service.getCash()).isEqualTo(7_561_900L)
        val pos = service.getMePositions().first { it.ticker == "005930" }
        assertThat(pos.qty).isEqualTo(13)
        assertThat(pos.avgPrice).isEqualTo(70_485) // round(916,300/13)
        assertThat(t.name).isEqualTo("삼성전자")
        assertThat(t.isBuy).isTrue()
        assertThat(t.amount).isEqualTo(76_300L)
        assertThat(t.time).matches("""\d{2}\.\d{2} \d{2}:\d{2}""")
        assertThat(service.getTrades().first()).isEqualTo(t)
        assertThat(service.getTrades()).hasSize(7)
        assertThat(service.getCash() + meValue()).isEqualTo(before)
    }

    @Test
    fun `매도 체결 - 현금 증가, 수량 차감, 평단 유지`() {
        service.placeOrder("000270", false, 2) // 기아 109,500 × 2
        assertThat(service.getCash()).isEqualTo(7_857_200L)
        val pos = service.getMePositions().first { it.ticker == "000270" }
        assertThat(pos.qty).isEqualTo(4)
        assertThat(pos.avgPrice).isEqualTo(98_700)
    }

    @Test
    fun `전량 매도 시 포지션 제거`() {
        service.placeOrder("035420", false, 3) // NAVER 전량
        assertThat(service.getMePositions().none { it.ticker == "035420" }).isTrue()
    }

    @Test
    fun `신규 종목 매수 시 포지션 추가`() {
        service.placeOrder("005380", true, 1) // 현대차 247,000
        val pos = service.getMePositions().first { it.ticker == "005380" }
        assertThat(pos.qty).isEqualTo(1)
        assertThat(pos.avgPrice).isEqualTo(247_000)
        assertThat(service.getCash()).isEqualTo(7_391_200L)
    }

    @Test
    fun `검증 에러 4종`() {
        assertThatThrownBy { service.placeOrder("999999", true, 1) }
            .isInstanceOf(BusinessException::class.java)
            .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.INVALID_TICKER) })
        assertThatThrownBy { service.placeOrder("005930", true, 0) }
            .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.INVALID_ORDER) })
        assertThatThrownBy { service.placeOrder("005380", true, 31) } // 7,657,000 > 7,638,200
            .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.ORDER_INSUFFICIENT_FUNDS) })
        assertThatThrownBy { service.placeOrder("000660", false, 5) } // 보유 4
            .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.ORDER_INSUFFICIENT_HOLDINGS) })
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd backend && ./gradlew test --tests 'com.growant.trading.TradingServiceTest'`
Expected: 컴파일 실패(`TradingService`, `TradeDto` 미정의).

- [ ] **Step 4: Create TradeDto + TradingService**

Create `backend/src/main/kotlin/com/growant/trading/dto/TradeDto.kt`:

```kotlin
package com.growant.trading.dto

/** 프론트 Trade 모델과 1:1 미러 — time은 "MM.dd HH:mm" 문자열. */
data class TradeDto(
    val name: String,
    val isBuy: Boolean,
    val price: Int,
    val qty: Int,
    val amount: Long,
    val time: String,
)
```

Create `backend/src/main/kotlin/com/growant/trading/TradingService.kt`:

```kotlin
package com.growant.trading

import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import com.growant.market.MarketService
import com.growant.trading.dto.TradeDto
import org.springframework.stereotype.Service
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

/** 보유 포지션(수량·평균단가). 현재가·종목명은 마켓 카탈로그가 원천. */
data class Position(val ticker: String, val qty: Int, val avgPrice: Int)

/**
 * 거래 상태의 유일한 소유자 — 현금·me 포지션·거래내역(in-memory, 재시작 시 초기화).
 * 자산 불변식: 체결 직후 (현금 + me 평가액)은 체결 전과 같다(현금 증감 = 평가 증감).
 * 초기 현금 7,638,200 = 자산 10,520,000 − me 평가 2,881,800.
 * 영속성 슬라이스에서 내부 저장만 JPA로 교체한다(인터페이스 유지).
 */
@Service
class TradingService(private val marketService: MarketService) {

    private var cash: Long = 7_638_200L

    private val mePositions = mutableListOf(
        Position("005930", 12, 70_000),
        Position("000660", 4, 185_000),
        Position("035420", 3, 189_000),
        Position("000270", 6, 98_700),
    )

    // 기존 mock 내역 시드 — 내역 탭 첫 화면 동일(최신이 [0])
    private val trades = mutableListOf(
        TradeDto("삼성전자", false, 76_300, 10, 763_000L, "05.10 14:32"),
        TradeDto("애플", true, 252_000, 2, 504_000L, "05.10 10:08"),
        TradeDto("SK하이닉스", true, 180_700, 5, 903_500L, "05.09 15:18"),
        TradeDto("카카오", false, 41_200, 10, 412_000L, "05.09 11:45"),
        TradeDto("삼성전자", true, 72_000, 10, 720_000L, "05.08 09:35"),
        TradeDto("NAVER", false, 198_400, 1, 198_400L, "05.07 16:01"),
    )

    fun getCash(): Long = cash
    fun getMePositions(): List<Position> = mePositions.toList()
    fun getTrades(): List<TradeDto> = trades.toList()

    @Synchronized
    fun placeOrder(ticker: String, isBuy: Boolean, qty: Int): TradeDto {
        if (qty < 1) throw BusinessException(ErrorCode.INVALID_ORDER)
        val row = marketService.getMarket().associateBy { it.ticker }[ticker]
            ?: throw BusinessException(ErrorCode.INVALID_TICKER)
        val amount = row.price.toLong() * qty

        if (isBuy) {
            if (amount > cash) throw BusinessException(ErrorCode.ORDER_INSUFFICIENT_FUNDS)
            cash -= amount
            val idx = mePositions.indexOfFirst { it.ticker == ticker }
            if (idx >= 0) {
                val p = mePositions[idx]
                val newQty = p.qty + qty
                val newAvg =
                    ((p.avgPrice.toLong() * p.qty + row.price.toLong() * qty).toDouble() / newQty).roundToInt()
                mePositions[idx] = p.copy(qty = newQty, avgPrice = newAvg)
            } else {
                mePositions.add(Position(ticker, qty, row.price))
            }
        } else {
            val idx = mePositions.indexOfFirst { it.ticker == ticker }
            val held = if (idx >= 0) mePositions[idx].qty else 0
            if (qty > held) throw BusinessException(ErrorCode.ORDER_INSUFFICIENT_HOLDINGS)
            cash += amount
            val p = mePositions[idx]
            if (p.qty == qty) mePositions.removeAt(idx) else mePositions[idx] = p.copy(qty = p.qty - qty)
        }

        val trade = TradeDto(
            name = row.name, isBuy = isBuy, price = row.price, qty = qty, amount = amount,
            time = LocalDateTime.now(ZoneId.of("Asia/Seoul")).format(TIME_FMT),
        )
        trades.add(0, trade)
        return trade
    }

    companion object {
        private val TIME_FMT: DateTimeFormatter = DateTimeFormatter.ofPattern("MM.dd HH:mm")
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd backend && ./gradlew test --tests 'com.growant.trading.TradingServiceTest'`
Expected: 6 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/main/kotlin/com/growant/trading backend/src/test/kotlin/com/growant/trading backend/src/main/kotlin/com/growant/common/error/ErrorCode.kt
git commit -m "feat(trading): TradingService — 주문 체결 상태 소유(현금·포지션·내역) + ErrorCode 2종"
```

---

## Task 2: PortfolioService(me 이관 + AI anchor)·AccountService(동적 산식) 개편

**Files:**
- Modify: `backend/src/main/kotlin/com/growant/portfolio/PortfolioService.kt`
- Modify: `backend/src/main/kotlin/com/growant/account/AccountService.kt`
- Modify: `backend/src/test/kotlin/com/growant/portfolio/PortfolioServiceTest.kt`
- Modify: `backend/src/test/kotlin/com/growant/account/AccountServiceTest.kt`
- Modify: `backend/src/test/kotlin/com/growant/portfolio/PortfolioControllerTest.kt`
- Modify: `backend/src/test/kotlin/com/growant/account/AccountControllerTest.kt`

- [ ] **Step 1: PortfolioService 전체 교체**

Overwrite `backend/src/main/kotlin/com/growant/portfolio/PortfolioService.kt`:

```kotlin
package com.growant.portfolio

import com.growant.market.MarketService
import com.growant.portfolio.dto.HoldingDto
import com.growant.portfolio.dto.PortfolioDto
import com.growant.trading.Position
import com.growant.trading.TradingService
import org.springframework.stereotype.Service
import kotlin.math.roundToLong

/**
 * 대결 포트폴리오 조회 — ME 포지션은 TradingService 상태(주문 반영), 현재가·종목명은 MarketService.
 * 합산(cost/value/profit/returnRate)은 서버 권위로 계산해 내려준다.
 */
@Service
class PortfolioService(
    private val marketService: MarketService,
    private val tradingService: TradingService,
) {

    // NOTE(duel-ai): AI 포지션은 임시 하드코딩 — AI 매매 로직 슬라이스에서
    //   TradingService 상태로 대체하고 이 블록을 삭제한다.
    private val aiPositions = listOf(
        Position("005930", 8, 73_500),
        Position("051910", 3, 272_000),
        Position("068270", 5, 192_000),
        Position("035720", 20, 36_110),
    )

    fun getPortfolio(owner: PortfolioOwner): PortfolioDto {
        val positions = when (owner) {
            PortfolioOwner.ME -> tradingService.getMePositions()
            PortfolioOwner.AI -> aiPositions
        }
        val market = marketService.getMarket().associateBy { it.ticker }
        val holdings = positions.map { p ->
            // 포지션은 카탈로그 기반 — 불일치는 사용자 입력이 아닌 프로그래머 오류라 의도적으로 500(IllegalStateException).
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

- [ ] **Step 2: AccountService 전체 교체**

Overwrite `backend/src/main/kotlin/com/growant/account/AccountService.kt`:

```kotlin
package com.growant.account

import com.growant.account.dto.AccountSummaryDto
import com.growant.portfolio.PortfolioOwner
import com.growant.portfolio.PortfolioService
import com.growant.trading.TradingService
import org.springframework.stereotype.Service
import kotlin.math.roundToLong

/**
 * 자산 요약 — 동적 산식: 총 평가 자산 = 현금(TradingService) + me 포트폴리오 평가액.
 * 수익률은 시드(1,000만) 대비. 초기값은 10,520,000 / +5.2%로 기존 불변값과 동일.
 */
@Service
class AccountService(
    private val tradingService: TradingService,
    private val portfolioService: PortfolioService,
) {
    private val seed = 10_000_000L

    fun getSummary(): AccountSummaryDto {
        val totalAsset = tradingService.getCash() +
            portfolioService.getPortfolio(PortfolioOwner.ME).value
        val returnRate = ((totalAsset - seed) * 1000.0 / seed).roundToLong() / 10.0
        return AccountSummaryDto(totalAsset = totalAsset, returnRate = returnRate)
    }
}
```

- [ ] **Step 3: 기존 테스트 4개 보정 (단언값은 전부 그대로)**

(a) `PortfolioServiceTest.kt` — 필드 선언부:

```kotlin
    private val service = PortfolioService(MarketService())
```

→

```kotlin
    private val market = MarketService()
    private val service = PortfolioService(market, TradingService(market))
```

파일 상단 import에 `import com.growant.trading.TradingService` 추가.

(b) `AccountServiceTest.kt` — 필드 선언부:

```kotlin
    private val service = AccountService()
```

→

```kotlin
    private val market = MarketService()
    private val trading = TradingService(market)
    private val service = AccountService(trading, PortfolioService(market, trading))
```

import 추가: `import com.growant.market.MarketService`, `import com.growant.portfolio.PortfolioService`, `import com.growant.trading.TradingService`.

(c) `PortfolioControllerTest.kt` — `@Import(...)`:

```kotlin
@Import(SecurityConfig::class, PortfolioService::class, MarketService::class)
```

→

```kotlin
@Import(SecurityConfig::class, PortfolioService::class, MarketService::class, TradingService::class)
```

import 추가: `import com.growant.trading.TradingService`.

(d) `AccountControllerTest.kt` — `@Import(...)`:

```kotlin
@Import(SecurityConfig::class, AccountService::class)
```

→

```kotlin
@Import(SecurityConfig::class, AccountService::class, PortfolioService::class, MarketService::class, TradingService::class)
```

import 추가: `import com.growant.market.MarketService`, `import com.growant.portfolio.PortfolioService`, `import com.growant.trading.TradingService`.

- [ ] **Step 4: Run full backend test**

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 기존 단언값(ME 5.2/profit 142,600·AI 3.8·자산 10,520,000/5.2) 전부 유지 통과 (총 19 tests: market 6 + portfolio 5 + account 2 + trading 6).

- [ ] **Step 5: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/main/kotlin/com/growant/portfolio/PortfolioService.kt backend/src/main/kotlin/com/growant/account/AccountService.kt backend/src/test/kotlin/com/growant/portfolio backend/src/test/kotlin/com/growant/account
git commit -m "refactor(portfolio,account): me 포지션=TradingService 조회 + 자산=현금+me평가 동적 산식 (AI는 NOTE(duel-ai) anchor)"
```

---

## Task 3: TradingController + OrderRequestDto + SecurityConfig

**Files:**
- Create: `backend/src/main/kotlin/com/growant/trading/dto/OrderRequestDto.kt`
- Create: `backend/src/main/kotlin/com/growant/trading/TradingController.kt`
- Modify: `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt`
- Test: `backend/src/test/kotlin/com/growant/trading/TradingControllerTest.kt`

- [ ] **Step 1: Write the failing controller test**

Create `backend/src/test/kotlin/com/growant/trading/TradingControllerTest.kt`:

```kotlin
package com.growant.trading

import com.growant.common.config.SecurityConfig
import com.growant.market.MarketService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@WebMvcTest(TradingController::class)
@Import(SecurityConfig::class, TradingService::class, MarketService::class)
class TradingControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `POST orders executes and returns trade envelope`() {
        mockMvc.post("/api/orders") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"ticker":"005930","isBuy":true,"qty":1}"""
        }.andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.name") { value("삼성전자") } }
            .andExpect { jsonPath("$.data.isBuy") { value(true) } }
            .andExpect { jsonPath("$.data.amount") { value(76300) } }
    }

    @Test
    fun `POST orders insufficient funds returns 409 error envelope`() {
        mockMvc.post("/api/orders") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"ticker":"005380","isBuy":true,"qty":1000}"""
        }.andExpect { status { isConflict() } }
            .andExpect { jsonPath("$.success") { value(false) } }
            .andExpect { jsonPath("$.error.code") { value("ORDER_INSUFFICIENT_FUNDS") } }
            .andExpect { jsonPath("$.error.eventType") { value("ORDER_ERROR") } }
    }

    @Test
    fun `GET trades returns history envelope`() {
        mockMvc.get("/api/trades")
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data[0].name") { isNotEmpty() } }
    }
}
```

(컨텍스트 공유로 테스트 간 상태가 누적되므로 GET 테스트는 정확한 개수 대신 형태만 단언한다.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd backend && ./gradlew test --tests 'com.growant.trading.TradingControllerTest'`
Expected: 컴파일 실패(`TradingController`, `OrderRequestDto` 미정의).

- [ ] **Step 3: Create DTO + Controller + SecurityConfig permit**

Create `backend/src/main/kotlin/com/growant/trading/dto/OrderRequestDto.kt`:

```kotlin
package com.growant.trading.dto

data class OrderRequestDto(
    val ticker: String,
    val isBuy: Boolean,
    val qty: Int,
)
```

Create `backend/src/main/kotlin/com/growant/trading/TradingController.kt`:

```kotlin
package com.growant.trading

import com.growant.common.web.ApiResponse
import com.growant.trading.dto.OrderRequestDto
import com.growant.trading.dto.TradeDto
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController

@RestController
class TradingController(private val service: TradingService) {

    @PostMapping("/api/orders")
    fun placeOrder(@RequestBody req: OrderRequestDto): ApiResponse<TradeDto> =
        ApiResponse.ok(service.placeOrder(req.ticker, req.isBuy, req.qty))

    @GetMapping("/api/trades")
    fun trades(): ApiResponse<List<TradeDto>> = ApiResponse.ok(service.getTrades())
}
```

In `SecurityConfig.kt`, find:

```kotlin
                it.requestMatchers("/api/account/**").permitAll()
```

Replace with:

```kotlin
                it.requestMatchers("/api/account/**").permitAll()
                it.requestMatchers("/api/orders").permitAll()
                it.requestMatchers("/api/trades").permitAll()
```

- [ ] **Step 4: Run tests + full backend**

Run: `cd backend && ./gradlew test --tests 'com.growant.trading.*'` → 9 pass.
Run: `cd backend && ./gradlew test` → BUILD SUCCESSFUL (22 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/main/kotlin/com/growant/trading backend/src/test/kotlin/com/growant/trading backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt
git commit -m "feat(trading): POST /api/orders + GET /api/trades — 주문 체결·내역 API"
```

---

## Task 4: 프론트 trading 데이터 레이어

**Files:**
- Create: `frontend/lib/features/trading/data/trade_models.dart`
- Create: `frontend/lib/features/trading/data/trade_repository.dart`
- Create: `frontend/lib/features/trading/application/trading_providers.dart`
- Test: `frontend/test/features/trading/trade_repository_test.dart`

- [ ] **Step 1: Write the failing repository test**

Create `frontend/test/features/trading/trade_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/trading/data/trade_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TradeRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = TradeRepository(dio);
  });

  test('placeOrder는 주문 body를 보내고 체결 Trade를 파싱한다', () async {
    adapter.onPost(
      '/api/orders',
      (s) => s.reply(200, {
        'success': true,
        'data': {
          'name': '삼성전자', 'isBuy': true, 'price': 76300, 'qty': 2,
          'amount': 152600, 'time': '06.09 12:00',
        },
      }),
      data: {'ticker': '005930', 'isBuy': true, 'qty': 2},
    );
    final t = await repo.placeOrder(ticker: '005930', isBuy: true, qty: 2);
    expect(t.name, '삼성전자');
    expect(t.isBuy, true);
    expect(t.amount, 152600);
    expect(t.time, '06.09 12:00');
  });

  test('fetchTrades는 내역 리스트를 파싱한다', () async {
    adapter.onGet('/api/trades', (s) => s.reply(200, {
          'success': true,
          'data': [
            {'name': 'NAVER', 'isBuy': false, 'price': 198400, 'qty': 1, 'amount': 198400, 'time': '05.07 16:01'}
          ],
        }));
    final list = await repo.fetchTrades();
    expect(list, hasLength(1));
    expect(list.first.name, 'NAVER');
    expect(list.first.isBuy, false);
  });

  test('에러 envelope는 ApiException으로 매핑된다', () async {
    adapter.onPost(
      '/api/orders',
      (s) => s.reply(409, {
        'success': false,
        'error': {'code': 'ORDER_INSUFFICIENT_FUNDS', 'eventType': 'ORDER_ERROR', 'message': '잔고가 부족합니다.', 'retryable': false}
      }),
      data: {'ticker': '005380', 'isBuy': true, 'qty': 1000},
    );
    await expectLater(
      repo.placeOrder(ticker: '005380', isBuy: true, qty: 1000),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', '잔고가 부족합니다.')
          .having((e) => e.retryable, 'retryable', false)),
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd frontend && flutter test test/features/trading/trade_repository_test.dart`
Expected: 컴파일 에러(파일 미존재).

- [ ] **Step 3: Create models + repository + providers**

Create `frontend/lib/features/trading/data/trade_models.dart`:

```dart
/// 체결 내역 — 서버 TradeDto와 1:1 (time은 "MM.dd HH:mm" 문자열).
class Trade {
  final String name;
  final bool isBuy;
  final int price;
  final int qty;
  final int amount;
  final String time;
  const Trade({
    required this.name,
    required this.isBuy,
    required this.price,
    required this.qty,
    required this.amount,
    required this.time,
  });

  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
        name: j['name'] as String,
        isBuy: j['isBuy'] as bool,
        price: (j['price'] as num).toInt(),
        qty: (j['qty'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        time: j['time'] as String,
      );
}
```

Create `frontend/lib/features/trading/data/trade_repository.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'trade_models.dart';

class TradeRepository {
  final Dio _dio;
  const TradeRepository(this._dio);

  Future<Trade> placeOrder({required String ticker, required bool isBuy, required int qty}) async {
    try {
      final res = await _dio.post('/api/orders', data: {'ticker': ticker, 'isBuy': isBuy, 'qty': qty});
      return Trade.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<List<Trade>> fetchTrades() async {
    try {
      final res = await _dio.get('/api/trades');
      return (res.data as List).map((e) => Trade.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : const ApiException(eventType: 'NETWORK', code: 'ERR_NETWORK', message: '인터넷 연결을 확인해주세요.', retryable: true);
}
```

Create `frontend/lib/features/trading/application/trading_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../market/application/market_providers.dart';
import '../data/trade_models.dart';
import '../data/trade_repository.dart';

final tradeRepositoryProvider =
    Provider<TradeRepository>((ref) => TradeRepository(ref.watch(dioProvider)));

class TradesNotifier extends AsyncNotifier<List<Trade>> {
  @override
  Future<List<Trade>> build() => ref.watch(tradeRepositoryProvider).fetchTrades();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(tradeRepositoryProvider).fetchTrades());
  }
}

final tradesProvider =
    AsyncNotifierProvider<TradesNotifier, List<Trade>>(TradesNotifier.new);
```

- [ ] **Step 4: Verify + commit**

Run: `cd frontend && flutter test test/features/trading/trade_repository_test.dart` → 3 pass.
Run: `cd frontend && flutter analyze` → No issues found!

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/trading/data frontend/lib/features/trading/application frontend/test/features/trading/trade_repository_test.dart
git commit -m "feat(trading): Trade 모델·repository·tradesProvider (POST /api/orders, GET /api/trades)"
```

---

## Task 5: 내역 탭·거래 상세 연동 + mock 정리

**Files:**
- Modify(전면): `frontend/lib/features/trading/trade_history_screen.dart`
- Modify: `frontend/lib/features/trading/trade_detail_screen.dart`
- Modify: `frontend/lib/data/mock/mock_data.dart`
- Test: `frontend/test/features/trading/trade_history_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `frontend/test/features/trading/trade_history_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/core/error/error_view.dart';
import 'package:growant/features/trading/application/trading_providers.dart';
import 'package:growant/features/trading/data/trade_models.dart';
import 'package:growant/features/trading/data/trade_repository.dart';
import 'package:growant/features/trading/trade_history_screen.dart';

const _trades = [
  Trade(name: '삼성전자', isBuy: false, price: 76300, qty: 10, amount: 763000, time: '05.10 14:32'),
  Trade(name: '카카오', isBuy: true, price: 41200, qty: 10, amount: 412000, time: '05.09 11:45'),
];

class _FakeRepo implements TradeRepository {
  final Object? error;
  _FakeRepo({this.error});

  @override
  Future<List<Trade>> fetchTrades() async {
    if (error != null) throw error!;
    return _trades;
  }

  @override
  Future<Trade> placeOrder({required String ticker, required bool isBuy, required int qty}) async =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(TradeRepository repo) => ProviderScope(
      overrides: [tradeRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: TradeHistoryScreen())),
    );

void main() {
  testWidgets('내역 목록과 매수/매도 요약을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pump();
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('카카오'), findsOneWidget);
    expect(find.text('총 매수'), findsOneWidget);
    expect(find.text('총 매도'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('로딩 중에는 스피너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // 보류된 future 정리
  });

  testWidgets('에러 시 ErrorView와 재시도 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'SYSTEM_ERROR', code: 'SERVICE_UNAVAILABLE', message: '잠시 후 다시 시도해 주세요.', retryable: true),
    )));
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('retryable=false 에러는 재시도 버튼을 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'AUTH_ERROR', code: 'UNAUTHENTICATED', message: '로그인이 필요합니다.', retryable: false),
    )));
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd frontend && flutter test test/features/trading/trade_history_screen_test.dart`
Expected: FAIL (TradeHistoryScreen이 아직 mock 기반 — provider 미사용으로 컴파일은 되지만 단언 실패하거나, import 충돌로 컴파일 에러).

- [ ] **Step 3: trade_history_screen.dart 전면 교체**

Overwrite the imports + `TradeHistoryScreen` class (keep `_SummaryBar`/`_StatCell`/`_TradeTile` exactly as-is below them):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/error/error_view.dart';
import '../../core/theme.dart';
import 'application/trading_providers.dart';
import 'data/trade_models.dart';
import 'trade_detail_screen.dart';

class TradeHistoryScreen extends ConsumerWidget {
  const TradeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tradesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final api = e is ApiException ? e : null;
        return ErrorView(
          kind: errorKindFromEventType(api?.eventType ?? 'NETWORK'),
          message: api?.message,
          onRetry: (api?.retryable ?? true)
              ? () => ref.read(tradesProvider.notifier).refresh()
              : null,
        );
      },
      data: (trades) {
        final fmt = NumberFormat('#,###');
        return Column(
          children: [
            _SummaryBar(trades: trades),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: trades.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (_, i) => _TradeTile(trade: trades[i], fmt: fmt),
              ),
            ),
          ],
        );
      },
    );
  }
}
```

(아래의 `_SummaryBar`, `_StatCell`, `_TradeTile` 클래스는 수정하지 않는다 — `Trade` 타입이 새 모델로 자연 해석된다.)

- [ ] **Step 4: trade_detail_screen.dart import 교체**

In `frontend/lib/features/trading/trade_detail_screen.dart`, replace:

```dart
import '../../data/mock/mock_data.dart';
```

with:

```dart
import 'data/trade_models.dart';
```

- [ ] **Step 5: mock 정리**

In `frontend/lib/data/mock/mock_data.dart`:

(a) `class Trade { ... }` 블록 전체 삭제(파일 상단, `class DividendEvent` 앞):

```dart
class Trade {
  final String name;
  final bool isBuy;
  final int amount; // 체결 금액
  final int price; // 단가
  final int qty;
  final String time;
  const Trade(this.name, this.isBuy, this.amount, this.price, this.qty, this.time);
}

```

(b) `// ── 거래 내역 ──` 주석 + `mockTrades` 상수 블록 전체 삭제(시드는 백엔드로 이동).

- [ ] **Step 6: Verify**

Run: `cd frontend && flutter test test/features/trading/` → 7 pass (repo 3 + history 4).
Run: `cd frontend && grep -rn "mockTrades" lib/ test/ || echo CLEAN` → CLEAN.
Run: `cd frontend && flutter analyze` → No issues found!
Run: `cd frontend && flutter test` → 전부 통과.

- [ ] **Step 7: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/trading frontend/lib/data/mock/mock_data.dart frontend/test/features/trading/trade_history_screen_test.dart
git commit -m "feat(trading): 내역 탭 API 연동(ErrorView 풀패턴) + mock Trade·mockTrades 제거"
```

---

## Task 6: 주문 시트 실연동 (stock_detail `_OrderSheet`)

**Files:**
- Modify: `frontend/lib/features/market/stock_detail_screen.dart`
- Test: `frontend/test/features/market/stock_detail_order_test.dart`

- [ ] **Step 1: Write the failing order-flow test**

Create `frontend/test/features/market/stock_detail_order_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/market/application/market_providers.dart';
import 'package:growant/features/market/data/market_models.dart';
import 'package:growant/features/market/data/market_repository.dart';
import 'package:growant/features/market/stock_detail_screen.dart';
import 'package:growant/features/trading/application/trading_providers.dart';
import 'package:growant/features/trading/data/trade_models.dart';
import 'package:growant/features/trading/data/trade_repository.dart';

const _detail = StockDetail(
  ticker: '005930', name: '삼성전자', price: 76300, changeRate: 5.97,
  candles: [76300, 76100, 75900, 76000, 75800, 75600, 75900, 76200, 76100, 76300],
  high52w: 90034, low52w: 54936, volume: 14823410, marketCapEok: 455494465, per: 12.4, pbr: 1.2,
);

class _FakeMarketRepo implements MarketRepository {
  @override
  Future<StockDetail> fetchDetail(String ticker) async => _detail;
  @override
  Future<List<MarketRow>> fetchMarket() async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTradeRepo implements TradeRepository {
  final Object? error;
  ({String ticker, bool isBuy, int qty})? last;
  _FakeTradeRepo({this.error});

  @override
  Future<Trade> placeOrder({required String ticker, required bool isBuy, required int qty}) async {
    last = (ticker: ticker, isBuy: isBuy, qty: qty);
    if (error != null) throw error!;
    return Trade(name: '삼성전자', isBuy: isBuy, price: 76300, qty: qty, amount: 76300 * qty, time: '06.09 12:00');
  }

  @override
  Future<List<Trade>> fetchTrades() async => [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(_FakeTradeRepo tradeRepo) => ProviderScope(
      overrides: [
        marketRepositoryProvider.overrideWithValue(_FakeMarketRepo()),
        tradeRepositoryProvider.overrideWithValue(tradeRepo),
      ],
      child: const MaterialApp(home: StockDetailScreen(ticker: '005930')),
    );

void main() {
  testWidgets('매수 주문 성공 - repo 호출, 시트 닫힘, 체결 스낵바', (tester) async {
    final repo = _FakeTradeRepo();
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '매수'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '매수 주문'));
    await tester.pumpAndSettle();
    expect(repo.last, (ticker: '005930', isBuy: true, qty: 1));
    expect(find.text('매수 체결: 삼성전자 1주'), findsOneWidget);
    expect(find.text('주문 금액'), findsNothing); // 시트 닫힘
  });

  testWidgets('주문 실패 - 에러 메시지 스낵바, 시트 유지', (tester) async {
    final repo = _FakeTradeRepo(
      error: const ApiException(
          eventType: 'ORDER_ERROR', code: 'ORDER_INSUFFICIENT_FUNDS', message: '잔고가 부족합니다.', retryable: false),
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '매수'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '매수 주문'));
    await tester.pumpAndSettle();
    expect(find.text('잔고가 부족합니다.'), findsOneWidget);
    expect(find.text('주문 금액'), findsOneWidget); // 시트 유지
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd frontend && flutter test test/features/market/stock_detail_order_test.dart`
Expected: FAIL — 현재 `_OrderSheet`은 mock 스낵바('주문 완료 (Mock)')라 `repo.last`가 null / '매수 체결' 미발견.

- [ ] **Step 3: stock_detail_screen.dart 수정**

(a) import 4개 추가 — 기존 `import 'widgets/order_book.dart';` 줄 아래:

```dart
import '../account/application/account_providers.dart';
import '../duel/application/portfolio_providers.dart';
import '../duel/data/portfolio_models.dart';
import '../trading/application/trading_providers.dart';
```

(b) `_DetailBody._showOrderSheet`의 builder 줄을 교체:

```dart
      builder: (_) => _OrderSheet(name: detail.name, price: detail.price, isBuy: isBuy),
```

→

```dart
      builder: (_) =>
          _OrderSheet(ticker: detail.ticker, name: detail.name, price: detail.price, isBuy: isBuy),
```

(c) 파일 하단의 `// NOTE(market-slice)...` 주석 + `_OrderSheet` + `_OrderSheetState` 클래스 전체를 다음으로 교체:

```dart
/// 주문 시트 — POST /api/orders 실연동. 성공 시 서버 상태(현금·보유·내역)가
/// 변하므로 관련 provider를 invalidate해 홈/상세/내역을 갱신한다.
class _OrderSheet extends ConsumerStatefulWidget {
  final String ticker;
  final String name;
  final int price;
  final bool isBuy;
  const _OrderSheet(
      {required this.ticker, required this.name, required this.price, required this.isBuy});
  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  int _qty = 1;
  bool _submitting = false;

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      final trade = await ref
          .read(tradeRepositoryProvider)
          .placeOrder(ticker: widget.ticker, isBuy: widget.isBuy, qty: _qty);
      ref.invalidate(portfolioProvider(PortfolioOwner.me));
      ref.invalidate(accountSummaryProvider);
      ref.invalidate(tradesProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('${widget.isBuy ? '매수' : '매도'} 체결: ${trade.name} ${trade.qty}주'),
        duration: const Duration(seconds: 2),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final total = widget.price * _qty;
    final color = widget.isBuy ? upColor : downColor;
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.isBuy ? '매수 주문' : '매도 주문',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(widget.name, style: const TextStyle(color: Color(0xFF888888))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('단가'),
            Text('${fmt.format(widget.price)}원', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('수량'),
            const Spacer(),
            IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove_circle_outline)),
            SizedBox(
                width: 40,
                child: Text('$_qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
                onPressed: () => setState(() => _qty++),
                icon: const Icon(Icons.add_circle_outline)),
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('주문 금액', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${fmt.format(total)}원',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.isBuy ? '매수 주문' : '매도 주문',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify**

Run: `cd frontend && flutter test test/features/market/stock_detail_order_test.dart` → 2 pass.
Run: `cd frontend && flutter analyze` → No issues found!
Run: `cd frontend && flutter test` → 전부 통과.

- [ ] **Step 5: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/market/stock_detail_screen.dart frontend/test/features/market/stock_detail_order_test.dart
git commit -m "feat(trading): 주문 시트 실연동 — 체결 시 포트폴리오·자산·내역 provider 갱신"
```

---

## Task 7: env 구성 + README + 전체 검증

**Files:**
- Create: `frontend/.env.example`
- Modify: `frontend/.gitignore`
- Modify: `backend/src/main/resources/application.yml`
- Modify: `README.md`

- [ ] **Step 1: frontend/.env.example 생성**

```
# API 서버 주소 — iOS 시뮬레이터=localhost, Android 에뮬레이터=10.0.2.2, 실기기=Mac의 LAN IP
API_BASE_URL=http://localhost:8080
```

- [ ] **Step 2: frontend/.gitignore에 .env 추가**

파일 끝에 추가:

```
# Env (API_BASE_URL 등) — .env.example 참고
.env
```

- [ ] **Step 3: application.yml에 config.import 골격 추가**

`backend/src/main/resources/application.yml`에서:

```yaml
spring:
  # TODO(market-slice): 마켓 슬라이스는 DB 불필요. DB 없이 로컬 기동하려면 application-local.yml에서
```

→

```yaml
spring:
  # 루트 .env(KEY=VALUE)를 있으면 로드 — 시크릿 주입 골격(없으면 무시). 스펙 §5.2
  config:
    import: "optional:file:../.env[.properties]"
  # TODO(market-slice): 마켓 슬라이스는 DB 불필요. DB 없이 로컬 기동하려면 application-local.yml에서
```

- [ ] **Step 4: README 실행 섹션 갱신**

`README.md`에서:

```bash
# 백엔드 단독
cd backend && ./gradlew bootRun

# 프론트
cd frontend && flutter pub get && flutter run
```

→

```bash
# 백엔드 단독 (local 프로파일 — DB 불필요. 루트 .env가 있으면 자동 로드)
cd backend && ./gradlew bootRun --args='--spring.profiles.active=local'

# 프론트 — API 주소는 frontend/.env로 관리
cd frontend && cp .env.example .env   # 최초 1회, 환경에 맞게 수정
flutter pub get && flutter run --dart-define-from-file=.env
```

- [ ] **Step 5: 전체 검증**

Run: `cd /Users/gsmin/GrowAnt && git check-ignore frontend/.env && echo IGNORED` → IGNORED.
Run: `cd backend && ./gradlew test` → BUILD SUCCESSFUL (22 tests — config.import는 optional이라 무영향).
Run: `cd frontend && flutter analyze` → No issues found!
Run: `cd frontend && flutter test` → 전부 통과 (기존 24 + 신규 9 = 33).

- [ ] **Step 6: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/.env.example frontend/.gitignore backend/src/main/resources/application.yml README.md
git commit -m "chore(env): frontend/.env(dart-define-from-file) + 백엔드 루트 .env 로딩 골격 + README 실행법"
```

---

## Self-Review

**1. Spec coverage:**
- §3.1 TradingService 상태(초기 현금/포지션/시드6)·placeOrder 검증·체결·가중평단·prepend → Task 1. ✓
- §3.2 ErrorCode 2종 → Task 1 Step 1. ✓
- §3.3 Controller/DTO/Security → Task 3. ✓ (TradeDto는 service가 반환하므로 Task 1에 배치)
- §3.4 Portfolio(me 이관+NOTE(duel-ai) anchor)/Account(동적 산식) 개편 + 기존 테스트 4 보정 → Task 2. ✓
- §3.5 백엔드 테스트(불변식 포함) → Task 1·3. ✓
- §4.1 데이터 레이어 → Task 4. §4.2 주문 시트(+anchor 제거) → Task 6. §4.3 내역·상세 → Task 5. §4.4 mock 정리 → Task 5. ✓
- §5.1 프론트 env / §5.2 백엔드 골격 / README → Task 7. ✓
- §7 프론트 테스트(repo3·history4·주문2) → Task 4·5·6. ✓

**2. Placeholder scan:** TBD/TODO 없음(기존 코드의 TODO(market-slice) 주석 보존은 의도). 모든 단계 완전한 코드. ✓

**3. Type consistency:** `Position(ticker,qty,avgPrice)`(trading 패키지, Portfolio가 import) · `TradeDto/Trade(name,isBuy,price,qty,amount,time)` 1:1 · `placeOrder(ticker,isBuy,qty)` 시그니처가 backend/frontend/test 전체 일관 · `tradeRepositoryProvider`/`tradesProvider`/`TradesNotifier.refresh` 명칭 일관 · 수치(7,638,200/7,561,900/70,485/7,857,200/7,391,200/76,300×31=7,657,000) 검산 일치. Dart record `({String ticker, bool isBuy, int qty})` 비교는 record 동등성으로 유효(Dart 3). ✓
