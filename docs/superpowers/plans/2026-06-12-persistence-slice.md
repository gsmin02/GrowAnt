# ⑦ 영속성 슬라이스 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** in-memory 거래 상태·사용자를 PostgreSQL로 영속화하고 사용자별(per-user)로 분리 — 신규 가입은 깨끗한 1,000만 현금.

**Architecture:** Spring Data JPA 직접 주입(A안) + DRY 5원칙(스키마=Flyway 단일 원천 / 매핑=엔티티 파일 단일 정의 / INITIAL_CASH 상수 1곳 / Jwt.userId 확장 1곳 / Testcontainers 공용 베이스 1곳). 동시성은 주문=사용자 행 비관적 잠금, 요약=REPEATABLE_READ 스냅샷. 컨트롤러 테스트는 `@MockitoBean` 전환, 행위 검증은 Testcontainers IT.

**Tech Stack:** Spring Boot 4 / Kotlin / PostgreSQL 16 / Flyway / Testcontainers / Docker multi-stage

**Spec:** `docs/superpowers/specs/2026-06-12-persistence-slice-design.md`

**Branch:** 시작 전 `git checkout -b feat/persistence-slice` (main 기준). 완료 후 PR은 **open 상태로만**(병합 금지 — 사용자 검토).

**전제:** 로컬 Docker 데몬 가동(Testcontainers·compose 검증에 필요). 백엔드 명령은 `/Users/gsmin/GrowAnt/backend`, 프론트는 `/Users/gsmin/GrowAnt/frontend`, 커밋은 repo 루트.

---

## 테스트 수 추적

| 시점 | 백엔드 | 프론트 | 비고 |
|---|---|---|---|
| 시작(main) | 29 | 46 | |
| T1 후 | 32 | 46 | +RepositoryIT 3 |
| T2 후 | 23 | 46 | 단위 10 삭제(IT로 대체 예정), Portfolio 단위 +1, 컨트롤러 모킹 전환 |
| T3 후 | 35 | 46 | +TradingServiceIT 8, AuthServiceIT 4 |
| T4 후 | 38 | 46 | +AccountServiceIT 2, ConcurrentOrderIT 1 |
| T5 후 | 38 | 47 | +내역 빈 상태 1 |
| T6 후 | 38 | 47 | compose up 검증 게이트 |

---

### Task 1: 기반 — 의존성 + Flyway V1 + 엔티티·리포지토리 + Testcontainers 베이스

**Files:**
- Modify: `backend/build.gradle.kts`
- Create: `backend/src/main/resources/db/migration/V1__init.sql`
- Create: `backend/src/main/kotlin/com/growant/common/Seed.kt`
- Create: `backend/src/main/kotlin/com/growant/auth/UserEntity.kt`
- Create: `backend/src/main/kotlin/com/growant/auth/UserJpaRepository.kt`
- Create: `backend/src/main/kotlin/com/growant/trading/PositionEntity.kt`
- Create: `backend/src/main/kotlin/com/growant/trading/TradeEntity.kt`
- Create: `backend/src/main/kotlin/com/growant/trading/TradingRepositories.kt`
- Modify: `backend/src/test/resources/application.yml`
- Create: `backend/src/test/kotlin/com/growant/support/PostgresIntegrationTest.kt`
- Test: `backend/src/test/kotlin/com/growant/support/RepositoryIT.kt`

이 task에서 기존 서비스는 **건드리지 않는다** — 기존 29개 테스트가 그대로 그린이어야 한다.

- [ ] **Step 1: 의존성 추가** — `backend/build.gradle.kts`에서

```kotlin
    runtimeOnly("org.postgresql:postgresql")
```

를 다음으로 교체:

```kotlin
    runtimeOnly("org.postgresql:postgresql")
    implementation("org.flywaydb:flyway-core")
    runtimeOnly("org.flywaydb:flyway-database-postgresql")
```

그리고

```kotlin
    testImplementation("org.springframework.security:spring-security-test")
```

를 다음으로 교체:

```kotlin
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("org.testcontainers:junit-jupiter")
```

- [ ] **Step 2: Flyway V1 마이그레이션** — `backend/src/main/resources/db/migration/V1__init.sql` 생성 (스키마 단일 원천 — DRY §3-1):

```sql
-- GrowAnt 초기 스키마 — users·positions·trades (스펙 §4)
CREATE TABLE users (
    id          BIGSERIAL PRIMARY KEY,
    provider    VARCHAR(20)  NOT NULL,
    nickname    VARCHAR(20)  NOT NULL,
    cash        BIGINT       NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_users_provider_nickname UNIQUE (provider, nickname)
);

CREATE TABLE positions (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users (id),
    ticker     VARCHAR(10) NOT NULL,
    qty        INT         NOT NULL,
    avg_price  INT         NOT NULL,
    CONSTRAINT uq_positions_user_ticker UNIQUE (user_id, ticker)
);

CREATE TABLE trades (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT      NOT NULL REFERENCES users (id),
    ticker       VARCHAR(10) NOT NULL,
    name         VARCHAR(40) NOT NULL,
    is_buy       BOOLEAN     NOT NULL,
    price        INT         NOT NULL,
    qty          INT         NOT NULL,
    amount       BIGINT      NOT NULL,
    executed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_trades_user_executed ON trades (user_id, executed_at DESC);
```

- [ ] **Step 3: 시드 상수** — `backend/src/main/kotlin/com/growant/common/Seed.kt` 생성:

```kotlin
package com.growant.common

/** 가입 시 지급 현금 = 수익률 계산의 분모 — 단일 원천(스펙 DRY §3-3). auth·account가 공유한다. */
const val INITIAL_CASH: Long = 10_000_000L
```

- [ ] **Step 4: 엔티티 3개 생성** (연관관계 매핑 없음 — FK는 Long 평컬럼, 스펙 §5)

`backend/src/main/kotlin/com/growant/auth/UserEntity.kt`:

```kotlin
package com.growant.auth

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.time.OffsetDateTime

@Entity
@Table(name = "users")
class UserEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,
    @Column(nullable = false, length = 20)
    val provider: String,
    @Column(nullable = false, length = 20)
    val nickname: String,
    @Column(nullable = false)
    var cash: Long,
    @Column(name = "created_at", nullable = false)
    val createdAt: OffsetDateTime = OffsetDateTime.now(),
)
```

`backend/src/main/kotlin/com/growant/trading/PositionEntity.kt`:

```kotlin
package com.growant.trading

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Table

@Entity
@Table(name = "positions")
class PositionEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,
    @Column(name = "user_id", nullable = false)
    val userId: Long,
    @Column(nullable = false, length = 10)
    val ticker: String,
    @Column(nullable = false)
    var qty: Int,
    @Column(name = "avg_price", nullable = false)
    var avgPrice: Int,
)

/** 엔티티→도메인 매핑 단일 정의(스펙 DRY §3-2) — 서비스에서 직접 매핑 금지. */
fun PositionEntity.toDomain() = Position(ticker, qty, avgPrice)
```

`backend/src/main/kotlin/com/growant/trading/TradeEntity.kt`:

```kotlin
package com.growant.trading

import com.growant.trading.dto.TradeDto
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Entity
@Table(name = "trades")
class TradeEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,
    @Column(name = "user_id", nullable = false)
    val userId: Long,
    @Column(nullable = false, length = 10)
    val ticker: String,
    @Column(nullable = false, length = 40)
    val name: String,
    @Column(name = "is_buy", nullable = false)
    val isBuy: Boolean,
    @Column(nullable = false)
    val price: Int,
    @Column(nullable = false)
    val qty: Int,
    @Column(nullable = false)
    val amount: Long,
    @Column(name = "executed_at", nullable = false)
    val executedAt: OffsetDateTime = OffsetDateTime.now(),
)

private val TIME_FMT: DateTimeFormatter = DateTimeFormatter.ofPattern("MM.dd HH:mm")
private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")

/** 엔티티→DTO 매핑 단일 정의(스펙 DRY §3-2) — time "MM.dd HH:mm" 포맷은 여기서만. */
fun TradeEntity.toDto() = TradeDto(
    name = name,
    isBuy = isBuy,
    price = price,
    qty = qty,
    amount = amount,
    time = executedAt.atZoneSameInstant(SEOUL).format(TIME_FMT),
)
```

- [ ] **Step 5: 리포지토리 생성**

`backend/src/main/kotlin/com/growant/auth/UserJpaRepository.kt`:

```kotlin
package com.growant.auth

import jakarta.persistence.LockModeType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param

interface UserJpaRepository : JpaRepository<UserEntity, Long> {
    fun findByProviderAndNickname(provider: String, nickname: String): UserEntity?

    /** 주문 트랜잭션의 직렬화 지점 — 사용자 행 비관적 잠금(스펙 §6.1). */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from UserEntity u where u.id = :id")
    fun findForUpdate(@Param("id") id: Long): UserEntity?
}
```

`backend/src/main/kotlin/com/growant/trading/TradingRepositories.kt` (두 인터페이스가 함께 변하는 작은 단위 — 한 파일):

```kotlin
package com.growant.trading

import org.springframework.data.jpa.repository.JpaRepository

interface PositionJpaRepository : JpaRepository<PositionEntity, Long> {
    fun findByUserId(userId: Long): List<PositionEntity>
    fun findByUserIdAndTicker(userId: Long, ticker: String): PositionEntity?
}

interface TradeJpaRepository : JpaRepository<TradeEntity, Long> {
    /** 최신순 — 동일 타임스탬프 동률은 id 역순으로 안정 정렬. */
    fun findByUserIdOrderByExecutedAtDescIdDesc(userId: Long): List<TradeEntity>
}
```

- [ ] **Step 6: 테스트 application.yml 보강** — `backend/src/test/resources/application.yml` 전체 교체:

```yaml
# 테스트 전용 — main application.yml을 클래스패스에서 가린다(spring.config.import의 루트 .env 미로드).
# JWT_SECRET 등 환경 변수에 테스트가 좌우되지 않도록 고정한다.
auth:
  jwt:
    secret: test-secret-must-be-32-bytes-min!!

spring:
  jpa:
    hibernate:
      ddl-auto: validate   # Flyway 스키마와 엔티티 드리프트를 IT 부팅 시점에 검출(스펙 DRY §3-1)
```

- [ ] **Step 7: Testcontainers 공용 베이스** — `backend/src/test/kotlin/com/growant/support/PostgresIntegrationTest.kt` 생성 (DRY §3-5):

```kotlin
package com.growant.support

import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.testcontainers.containers.PostgreSQLContainer

/**
 * Testcontainers 공용 베이스(스펙 DRY §3-5) — 싱글턴 컨테이너를 모든 IT가 공유한다.
 * @Container 생명주기 대신 수동 start(JVM당 1회): IT 클래스마다 컨테이너 재기동을 막는다.
 * 컨테이너 정리는 testcontainers의 Ryuk이 JVM 종료 시 수행한다.
 * 데이터는 IT 간 공유되므로 각 테스트는 고유 닉네임으로 자체 사용자를 만든다(롤백에 기대지 않는 설계).
 */
@SpringBootTest
abstract class PostgresIntegrationTest {
    companion object {
        @JvmStatic
        @ServiceConnection
        val postgres: PostgreSQLContainer<*> =
            PostgreSQLContainer("postgres:16-alpine").also { it.start() }
    }
}
```

- [ ] **Step 8: 실패하는 RepositoryIT 작성** — `backend/src/test/kotlin/com/growant/support/RepositoryIT.kt`:

```kotlin
package com.growant.support

import com.growant.auth.UserEntity
import com.growant.auth.UserJpaRepository
import com.growant.trading.PositionEntity
import com.growant.trading.PositionJpaRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.dao.DataIntegrityViolationException

class RepositoryIT(
    @Autowired val users: UserJpaRepository,
    @Autowired val positions: PositionJpaRepository,
) : PostgresIntegrationTest() {

    @Test
    fun `Flyway 스키마에 사용자 저장·조회가 동작한다`() {
        val saved = users.save(UserEntity(provider = "kakao", nickname = "스모크-유저", cash = 10_000_000L))
        assertThat(saved.id).isPositive()
        assertThat(users.findByProviderAndNickname("kakao", "스모크-유저")!!.id).isEqualTo(saved.id)
    }

    @Test
    fun `같은 provider+nickname 중복 저장은 유니크 제약으로 거부된다`() {
        users.saveAndFlush(UserEntity(provider = "naver", nickname = "중복닉", cash = 0))
        assertThatThrownBy {
            users.saveAndFlush(UserEntity(provider = "naver", nickname = "중복닉", cash = 0))
        }.isInstanceOf(DataIntegrityViolationException::class.java)
    }

    @Test
    fun `같은 사용자 동일 티커 포지션 중복은 유니크 제약으로 거부된다`() {
        val u = users.save(UserEntity(provider = "google", nickname = "포지션닉", cash = 0))
        positions.saveAndFlush(PositionEntity(userId = u.id, ticker = "005930", qty = 1, avgPrice = 1))
        assertThatThrownBy {
            positions.saveAndFlush(PositionEntity(userId = u.id, ticker = "005930", qty = 2, avgPrice = 2))
        }.isInstanceOf(DataIntegrityViolationException::class.java)
    }
}
```

- [ ] **Step 9: 검증**

Run: `cd backend && ./gradlew test --tests 'com.growant.support.RepositoryIT'`
Expected: 3 PASS (최초 실행은 postgres:16-alpine pull 시간 소요 가능). Flyway 마이그레이션 로그 확인.

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 32 tests (기존 29 + 신규 3). 기존 서비스·컨트롤러 테스트 무영향.

- [ ] **Step 10: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/build.gradle.kts backend/src/main/resources/db backend/src/main/kotlin/com/growant/common/Seed.kt backend/src/main/kotlin/com/growant/auth backend/src/main/kotlin/com/growant/trading backend/src/test/resources/application.yml backend/src/test/kotlin/com/growant/support
git commit -m "feat(persistence): Flyway V1 스키마 + 엔티티·리포지토리 + Testcontainers 공용 베이스"
```

---

### Task 2: 백엔드 전환(원자) — 서비스 4종 JPA화 + userId 시그니처 + 컨트롤러·테스트 전환

서비스 시그니처(userId)·의존이 바뀌면 컨트롤러와 테스트가 같은 커밋에서 함께 바뀌어야 컴파일된다 — **원자 변경**.

**Files:**
- Create: `backend/src/main/kotlin/com/growant/common/web/JwtExtensions.kt`
- Modify(전체 교체): `backend/src/main/kotlin/com/growant/trading/TradingService.kt`
- Modify(전체 교체): `backend/src/main/kotlin/com/growant/auth/AuthService.kt`
- Delete: `backend/src/main/kotlin/com/growant/auth/UserStore.kt`, `backend/src/main/kotlin/com/growant/auth/User.kt`
- Modify: `backend/src/main/kotlin/com/growant/portfolio/PortfolioService.kt` (메서드 시그니처)
- Modify(전체 교체): `backend/src/main/kotlin/com/growant/account/AccountService.kt`
- Modify(전체 교체): `backend/src/main/kotlin/com/growant/trading/TradingController.kt`
- Modify(전체 교체): `backend/src/main/kotlin/com/growant/portfolio/PortfolioController.kt`
- Modify(전체 교체): `backend/src/main/kotlin/com/growant/account/AccountController.kt`
- Modify(전체 교체): 컨트롤러 테스트 4파일(Trading/Portfolio/Account/Auth — `@MockitoBean` 전환)
- Modify(전체 교체): `backend/src/test/kotlin/com/growant/portfolio/PortfolioServiceTest.kt` (mockito 전환 + 빈 포지션 케이스)
- Delete: `backend/src/test/kotlin/com/growant/trading/TradingServiceTest.kt`, `backend/src/test/kotlin/com/growant/auth/AuthServiceTest.kt`, `backend/src/test/kotlin/com/growant/account/AccountServiceTest.kt` (T3·T4의 IT가 대체)

- [ ] **Step 1: Jwt.userId 확장** — `backend/src/main/kotlin/com/growant/common/web/JwtExtensions.kt` 생성 (DRY §3-4):

```kotlin
package com.growant.common.web

import org.springframework.security.oauth2.jwt.Jwt

/** JWT sub → userId 추출 단일 정의(스펙 DRY §3-4) — 컨트롤러 공용. sub는 AuthService가 DB id로 발급한다. */
val Jwt.userId: Long
    get() = subject.toLong()
```

- [ ] **Step 2: TradingService 전체 교체**:

```kotlin
package com.growant.trading

import com.growant.auth.UserJpaRepository
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import com.growant.market.MarketService
import com.growant.trading.dto.TradeDto
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import kotlin.math.roundToInt

/** 보유 포지션(수량·평균단가). 현재가·종목명은 마켓 카탈로그가 원천. */
data class Position(val ticker: String, val qty: Int, val avgPrice: Int)

/**
 * 거래 상태 소유자 — 현금·포지션·내역을 PostgreSQL에 영속(per-user). 스펙 §6.1
 * 동시성: placeOrder는 사용자 행 비관적 잠금(findForUpdate)으로 직렬화 — @Synchronized 대체.
 */
@Service
class TradingService(
    private val marketService: MarketService,
    private val userRepository: UserJpaRepository,
    private val positionRepository: PositionJpaRepository,
    private val tradeRepository: TradeJpaRepository,
) {

    @Transactional(readOnly = true)
    fun getCash(userId: Long): Long = requireUser(userId).cash

    @Transactional(readOnly = true)
    fun getMePositions(userId: Long): List<Position> =
        positionRepository.findByUserId(userId).map { it.toDomain() }

    @Transactional(readOnly = true)
    fun getTrades(userId: Long): List<TradeDto> =
        tradeRepository.findByUserIdOrderByExecutedAtDescIdDesc(userId).map { it.toDto() }

    @Transactional
    fun placeOrder(userId: Long, ticker: String, isBuy: Boolean, qty: Int): TradeDto {
        if (qty < 1) throw BusinessException(ErrorCode.INVALID_ORDER)
        val row = marketService.getMarket().associateBy { it.ticker }[ticker]
            ?: throw BusinessException(ErrorCode.INVALID_TICKER)
        // DB 리셋 후 옛 토큰의 sub가 미존재할 수 있다 — 401로 재로그인 유도(스펙 §6.1)
        val user = userRepository.findForUpdate(userId)
            ?: throw BusinessException(ErrorCode.UNAUTHENTICATED)
        val amount = row.price.toLong() * qty

        if (isBuy) {
            if (amount > user.cash) throw BusinessException(ErrorCode.ORDER_INSUFFICIENT_FUNDS)
            user.cash -= amount
            val held = positionRepository.findByUserIdAndTicker(userId, ticker)
            if (held != null) {
                val newQty = held.qty + qty
                held.avgPrice =
                    ((held.avgPrice.toLong() * held.qty + row.price.toLong() * qty).toDouble() / newQty)
                        .roundToInt()
                held.qty = newQty
            } else {
                positionRepository.save(
                    PositionEntity(userId = userId, ticker = ticker, qty = qty, avgPrice = row.price),
                )
            }
        } else {
            val held = positionRepository.findByUserIdAndTicker(userId, ticker)
            if (held == null || qty > held.qty) {
                throw BusinessException(ErrorCode.ORDER_INSUFFICIENT_HOLDINGS)
            }
            user.cash += amount
            if (held.qty == qty) positionRepository.delete(held) else held.qty -= qty
        }

        return tradeRepository.save(
            TradeEntity(
                userId = userId, ticker = ticker, name = row.name, isBuy = isBuy,
                price = row.price, qty = qty, amount = amount,
            ),
        ).toDto()
    }

    private fun requireUser(userId: Long): com.growant.auth.UserEntity =
        userRepository.findById(userId).orElseThrow { BusinessException(ErrorCode.UNAUTHENTICATED) }
}
```

(검증 순서 qty→ticker→잔고/보유, 가중평단 식, 에러 코드는 기존과 동일 — 회귀 없음.)

- [ ] **Step 3: AuthService 전체 교체 + UserStore·User 삭제**:

`backend/src/main/kotlin/com/growant/auth/AuthService.kt`:

```kotlin
package com.growant.auth

import com.growant.auth.dto.AuthResponseDto
import com.growant.auth.dto.UserDto
import com.growant.common.INITIAL_CASH
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.security.oauth2.jose.jws.MacAlgorithm
import org.springframework.security.oauth2.jwt.JwsHeader
import org.springframework.security.oauth2.jwt.JwtClaimsSet
import org.springframework.security.oauth2.jwt.JwtEncoder
import org.springframework.security.oauth2.jwt.JwtEncoderParameters
import org.springframework.stereotype.Service
import java.time.Duration
import java.time.Instant

/**
 * 데모 로그인 — (provider, nickname) find-or-create 후 HS256 JWT 발급. 스펙 §6.2
 * 가입 시 INITIAL_CASH 지급(빈 포트폴리오·빈 내역 시작). 실제 소셜 OAuth 전환 시 login 내부만 교체.
 *
 * login에 바깥 @Transactional을 두지 않는다: PostgreSQL은 제약 위반 시 트랜잭션을 중단시키므로
 * 같은 트랜잭션 안에서는 동시 가입 충돌 후 재조회가 불가하다 — repo 호출별 자체 트랜잭션으로 충분(쓰기 1회).
 */
@Service
class AuthService(
    private val userRepository: UserJpaRepository,
    private val jwtEncoder: JwtEncoder,
) {

    fun login(provider: String, nickname: String): AuthResponseDto {
        val name = nickname.trim()
        if (provider !in PROVIDERS || name.isEmpty() || name.length > 20) {
            throw BusinessException(ErrorCode.INVALID_LOGIN)
        }
        val user = findOrCreate(provider, name)
        val now = Instant.now()
        val claims = JwtClaimsSet.builder()
            .issuer("growant")
            .subject(user.id.toString())
            .claim("nickname", user.nickname)
            .claim("provider", user.provider)
            .issuedAt(now)
            .expiresAt(now.plus(TOKEN_TTL))
            .build()
        val token = jwtEncoder
            .encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
            .tokenValue
        return AuthResponseDto(token, UserDto(user.id, user.nickname, user.provider))
    }

    private fun findOrCreate(provider: String, name: String): UserEntity =
        userRepository.findByProviderAndNickname(provider, name)
            ?: try {
                userRepository.saveAndFlush(UserEntity(provider = provider, nickname = name, cash = INITIAL_CASH))
            } catch (e: DataIntegrityViolationException) {
                // 동시 가입 레이스 — 유니크 제약이 한쪽만 통과시키므로 재조회로 멱등 처리(스펙 §6.2)
                userRepository.findByProviderAndNickname(provider, name) ?: throw e
            }

    companion object {
        private val PROVIDERS = setOf("kakao", "naver", "apple", "google")
        private val TOKEN_TTL: Duration = Duration.ofHours(24)
    }
}
```

삭제: `backend/src/main/kotlin/com/growant/auth/UserStore.kt`, `backend/src/main/kotlin/com/growant/auth/User.kt` (도메인 User는 UserEntity로 대체).

- [ ] **Step 4: PortfolioService 시그니처 변경** — `getPortfolio` 선언부만 교체:

```kotlin
    fun getPortfolio(owner: PortfolioOwner): PortfolioDto {
        val positions = when (owner) {
            PortfolioOwner.ME -> tradingService.getMePositions()
            PortfolioOwner.AI -> aiPositions
        }
```

→

```kotlin
    fun getPortfolio(owner: PortfolioOwner, userId: Long): PortfolioDto {
        val positions = when (owner) {
            PortfolioOwner.ME -> tradingService.getMePositions(userId)
            PortfolioOwner.AI -> aiPositions // NOTE(duel-ai): userId 무관 — AI 매매 슬라이스에서 대체
        }
```

(파일의 나머지 — aiPositions·합산·NOTE(duel-ai) 블록 — 무수정.)

- [ ] **Step 5: AccountService 전체 교체**:

```kotlin
package com.growant.account

import com.growant.account.dto.AccountSummaryDto
import com.growant.common.INITIAL_CASH
import com.growant.portfolio.PortfolioOwner
import com.growant.portfolio.PortfolioService
import com.growant.trading.TradingService
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Isolation
import org.springframework.transaction.annotation.Transactional
import kotlin.math.roundToLong

/**
 * 자산 요약 — 총 평가 자산 = 현금 + me 포트폴리오 평가, 수익률은 INITIAL_CASH 대비. 스펙 §6.3
 * REPEATABLE_READ 단일 스냅샷: 현금·포지션 읽기 사이에 커밋된 체결이 끼어도 합산이 어긋나지 않는다
 * (READ COMMITTED로는 두 읽기가 서로 다른 스냅샷을 볼 수 있다).
 */
@Service
class AccountService(
    private val tradingService: TradingService,
    private val portfolioService: PortfolioService,
) {

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    fun getSummary(userId: Long): AccountSummaryDto {
        val totalAsset = tradingService.getCash(userId) +
            portfolioService.getPortfolio(PortfolioOwner.ME, userId).value
        val returnRate = ((totalAsset - INITIAL_CASH) * 1000.0 / INITIAL_CASH).roundToLong() / 10.0
        return AccountSummaryDto(totalAsset = totalAsset, returnRate = returnRate)
    }
}
```

- [ ] **Step 6: 컨트롤러 3개 전체 교체**

`backend/src/main/kotlin/com/growant/trading/TradingController.kt`:

```kotlin
package com.growant.trading

import com.growant.common.web.ApiResponse
import com.growant.common.web.userId
import com.growant.trading.dto.OrderRequestDto
import com.growant.trading.dto.TradeDto
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController

@RestController
class TradingController(private val service: TradingService) {

    @PostMapping("/api/orders")
    fun placeOrder(
        @AuthenticationPrincipal jwt: Jwt,
        @RequestBody req: OrderRequestDto,
    ): ApiResponse<TradeDto> =
        ApiResponse.ok(service.placeOrder(jwt.userId, req.ticker, req.isBuy, req.qty))

    @GetMapping("/api/trades")
    fun trades(@AuthenticationPrincipal jwt: Jwt): ApiResponse<List<TradeDto>> =
        ApiResponse.ok(service.getTrades(jwt.userId))
}
```

`backend/src/main/kotlin/com/growant/portfolio/PortfolioController.kt`:

```kotlin
package com.growant.portfolio

import com.growant.common.web.ApiResponse
import com.growant.common.web.userId
import com.growant.portfolio.dto.PortfolioDto
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/portfolio")
class PortfolioController(private val service: PortfolioService) {

    @GetMapping("/me")
    fun me(@AuthenticationPrincipal jwt: Jwt): ApiResponse<PortfolioDto> =
        ApiResponse.ok(service.getPortfolio(PortfolioOwner.ME, jwt.userId))

    @GetMapping("/ai")
    fun ai(@AuthenticationPrincipal jwt: Jwt): ApiResponse<PortfolioDto> =
        ApiResponse.ok(service.getPortfolio(PortfolioOwner.AI, jwt.userId))
}
```

`backend/src/main/kotlin/com/growant/account/AccountController.kt`:

```kotlin
package com.growant.account

import com.growant.account.dto.AccountSummaryDto
import com.growant.common.web.ApiResponse
import com.growant.common.web.userId
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/account")
class AccountController(private val service: AccountService) {

    @GetMapping("/summary")
    fun summary(@AuthenticationPrincipal jwt: Jwt): ApiResponse<AccountSummaryDto> =
        ApiResponse.ok(service.getSummary(jwt.userId))
}
```

- [ ] **Step 7: 컨트롤러 테스트 4파일 전체 교체 (`@MockitoBean`)**

공통: `@Import`에서 서비스 제거(SecurityConfig·JwtConfig·ApiAuthEntryPoint만 유지 — Market 제외), `jwt()`에 숫자 subject 필수(`jwt.userId`가 `toLong()` 하므로 기본 subject "user"는 500을 유발).

`backend/src/test/kotlin/com/growant/trading/TradingControllerTest.kt`:

```kotlin
package com.growant.trading

import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import com.growant.trading.dto.TradeDto
import org.junit.jupiter.api.Test
import org.mockito.BDDMockito.given
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@WebMvcTest(TradingController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class)
class TradingControllerTest(@Autowired val mockMvc: MockMvc) {

    @MockitoBean
    lateinit var service: TradingService

    @Test
    fun `POST orders executes and returns trade envelope`() {
        given(service.placeOrder(1L, "005930", true, 1))
            .willReturn(TradeDto("삼성전자", true, 76_300, 1, 76_300L, "06.12 10:00"))
        mockMvc.post("/api/orders") {
            with(jwt().jwt { it.subject("1") })
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
        given(service.placeOrder(1L, "005380", true, 1000))
            .willThrow(BusinessException(ErrorCode.ORDER_INSUFFICIENT_FUNDS))
        mockMvc.post("/api/orders") {
            with(jwt().jwt { it.subject("1") })
            contentType = MediaType.APPLICATION_JSON
            content = """{"ticker":"005380","isBuy":true,"qty":1000}"""
        }.andExpect { status { isConflict() } }
            .andExpect { jsonPath("$.success") { value(false) } }
            .andExpect { jsonPath("$.error.code") { value("ORDER_INSUFFICIENT_FUNDS") } }
            .andExpect { jsonPath("$.error.eventType") { value("ORDER_ERROR") } }
    }

    @Test
    fun `GET trades returns history envelope for the jwt user`() {
        given(service.getTrades(1L))
            .willReturn(listOf(TradeDto("NAVER", false, 198_400, 1, 198_400L, "06.12 09:00")))
        mockMvc.get("/api/trades") { with(jwt().jwt { it.subject("1") }) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data[0].name") { value("NAVER") } }
    }
}
```

`backend/src/test/kotlin/com/growant/portfolio/PortfolioControllerTest.kt`:

```kotlin
package com.growant.portfolio

import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import com.growant.portfolio.dto.HoldingDto
import com.growant.portfolio.dto.PortfolioDto
import org.junit.jupiter.api.Test
import org.mockito.BDDMockito.given
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

@WebMvcTest(PortfolioController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class)
class PortfolioControllerTest(@Autowired val mockMvc: MockMvc) {

    @MockitoBean
    lateinit var service: PortfolioService

    @Test
    fun `GET portfolio me returns envelope for the jwt user`() {
        given(service.getPortfolio(PortfolioOwner.ME, 1L)).willReturn(
            PortfolioDto(
                5.2, 142_600L, 2_739_200L, 2_881_800L,
                listOf(HoldingDto("005930", "삼성전자", 12, 70_000, 76_300)),
            ),
        )
        mockMvc.get("/api/portfolio/me") { with(jwt().jwt { it.subject("1") }) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.returnRate") { value(5.2) } }
            .andExpect { jsonPath("$.data.holdings[0].ticker") { value("005930") } }
    }

    @Test
    fun `GET portfolio ai returns envelope`() {
        given(service.getPortfolio(PortfolioOwner.AI, 1L)).willReturn(
            PortfolioDto(3.8, 117_200L, 3_086_200L, 3_203_400L, emptyList()),
        )
        mockMvc.get("/api/portfolio/ai") { with(jwt().jwt { it.subject("1") }) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.data.returnRate") { value(3.8) } }
    }
}
```

`backend/src/test/kotlin/com/growant/account/AccountControllerTest.kt`:

```kotlin
package com.growant.account

import com.growant.account.dto.AccountSummaryDto
import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import org.junit.jupiter.api.Test
import org.mockito.BDDMockito.given
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

@WebMvcTest(AccountController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class)
class AccountControllerTest(@Autowired val mockMvc: MockMvc) {

    @MockitoBean
    lateinit var service: AccountService

    @Test
    fun `GET account summary returns envelope for the jwt user`() {
        given(service.getSummary(1L)).willReturn(AccountSummaryDto(10_000_000L, 0.0))
        mockMvc.get("/api/account/summary") { with(jwt().jwt { it.subject("1") }) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.totalAsset") { value(10000000) } }
            .andExpect { jsonPath("$.data.returnRate") { value(0.0) } }
    }
}
```

`backend/src/test/kotlin/com/growant/auth/AuthControllerTest.kt`:

```kotlin
package com.growant.auth

import com.growant.auth.dto.AuthResponseDto
import com.growant.auth.dto.UserDto
import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import org.junit.jupiter.api.Test
import org.mockito.BDDMockito.given
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@WebMvcTest(AuthController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class)
class AuthControllerTest(@Autowired val mockMvc: MockMvc) {

    @MockitoBean
    lateinit var service: AuthService

    @Test
    fun `POST login returns token and user envelope`() {
        given(service.login("kakao", "개미왕"))
            .willReturn(AuthResponseDto("jwt-token", UserDto(1, "개미왕", "kakao")))
        mockMvc.post("/api/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"provider":"kakao","nickname":"개미왕"}"""
        }.andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.token") { value("jwt-token") } }
            .andExpect { jsonPath("$.data.user.nickname") { value("개미왕") } }
            .andExpect { jsonPath("$.data.user.provider") { value("kakao") } }
    }

    @Test
    fun `POST login with unknown provider returns 400 INVALID_LOGIN envelope`() {
        given(service.login("github", "개미왕"))
            .willThrow(BusinessException(ErrorCode.INVALID_LOGIN))
        mockMvc.post("/api/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"provider":"github","nickname":"개미왕"}"""
        }.andExpect { status { isBadRequest() } }
            .andExpect { jsonPath("$.success") { value(false) } }
            .andExpect { jsonPath("$.error.code") { value("INVALID_LOGIN") } }
            .andExpect { jsonPath("$.error.eventType") { value("VALIDATION_ERROR") } }
    }

    @Test
    fun `GET me returns user from jwt claims`() {
        mockMvc.get("/api/auth/me") {
            with(jwt().jwt { it.subject("7").claim("nickname", "개미왕").claim("provider", "kakao") })
        }.andExpect { status { isOk() } }
            .andExpect { jsonPath("$.data.id") { value(7) } }
            .andExpect { jsonPath("$.data.nickname") { value("개미왕") } }
            .andExpect { jsonPath("$.data.provider") { value("kakao") } }
    }

    @Test
    fun `GET me without token returns 401 UNAUTHENTICATED envelope`() {
        mockMvc.get("/api/auth/me")
            .andExpect { status { isUnauthorized() } }
            .andExpect { jsonPath("$.success") { value(false) } }
            .andExpect { jsonPath("$.error.code") { value("UNAUTHENTICATED") } }
            .andExpect { jsonPath("$.error.eventType") { value("AUTH_ERROR") } }
            .andExpect { jsonPath("$.error.retryable") { value(false) } }
    }
}
```

(MarketControllerTest는 무수정 — MarketService는 무DB라 실 서비스 유지.)

- [ ] **Step 8: PortfolioServiceTest 전체 교체** (mockito 전환 — 기존 단언값 유지 + 빈 포지션 케이스):

```kotlin
package com.growant.portfolio

import com.growant.market.MarketService
import com.growant.trading.Position
import com.growant.trading.TradingService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.BDDMockito.given
import org.mockito.Mockito.mock

class PortfolioServiceTest {
    private val market = MarketService()
    private val trading: TradingService = mock(TradingService::class.java)
    private val service = PortfolioService(market, trading)

    private val mePositions = listOf(
        Position("005930", 12, 70_000),
        Position("000660", 4, 185_000),
        Position("035420", 3, 189_000),
        Position("000270", 6, 98_700),
    )

    @Test
    fun `ME portfolio aggregates from trading positions`() {
        given(trading.getMePositions(1L)).willReturn(mePositions)
        val p = service.getPortfolio(PortfolioOwner.ME, 1L)
        assertThat(p.holdings).hasSize(4)
        assertThat(p.cost).isEqualTo(2_739_200L)
        assertThat(p.value).isEqualTo(2_881_800L)
        assertThat(p.profit).isEqualTo(142_600L)
        assertThat(p.returnRate).isEqualTo(5.2)
    }

    @Test
    fun `AI portfolio aggregates to plus 3_8 percent`() {
        val p = service.getPortfolio(PortfolioOwner.AI, 1L)
        assertThat(p.holdings).hasSize(4)
        assertThat(p.cost).isEqualTo(3_086_200L)
        assertThat(p.value).isEqualTo(3_203_400L)
        assertThat(p.profit).isEqualTo(117_200L)
        assertThat(p.returnRate).isEqualTo(3.8)
    }

    @Test
    fun `빈 포지션이면 비용·수익률 0에 빈 보유 목록`() {
        given(trading.getMePositions(2L)).willReturn(emptyList())
        val p = service.getPortfolio(PortfolioOwner.ME, 2L)
        assertThat(p.cost).isEqualTo(0L)
        assertThat(p.returnRate).isEqualTo(0.0)
        assertThat(p.holdings).isEmpty()
    }

    @Test
    fun `current prices and names come from market catalog`() {
        given(trading.getMePositions(1L)).willReturn(mePositions)
        val catalog = MarketService().getMarket().associateBy { it.ticker }
        val all = service.getPortfolio(PortfolioOwner.ME, 1L).holdings +
            service.getPortfolio(PortfolioOwner.AI, 1L).holdings
        all.forEach { h ->
            assertThat(h.currentPrice).isEqualTo(catalog.getValue(h.ticker).price)
            assertThat(h.name).isEqualTo(catalog.getValue(h.ticker).name)
        }
    }
}
```

- [ ] **Step 9: 구 단위 테스트 삭제**

```bash
cd /Users/gsmin/GrowAnt && git rm backend/src/test/kotlin/com/growant/trading/TradingServiceTest.kt backend/src/test/kotlin/com/growant/auth/AuthServiceTest.kt backend/src/test/kotlin/com/growant/account/AccountServiceTest.kt
```

(시드 전제 단언이라 무의미해짐 — T3·T4의 IT가 신규 유저 시나리오로 대체. 삭제 사유를 커밋 메시지에 명시.)

- [ ] **Step 10: 전체 검증**

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 23 tests (Market 3+3, Portfolio 컨트롤러 2+단위 4, Account 1, Trading 3, Auth 4, RepositoryIT 3), 0 failures

- [ ] **Step 11: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add -A backend/src && git commit -m "feat(persistence): 서비스 4종 JPA 전환 + per-user(userId) — 컨트롤러·테스트 MockitoBean 전환, 시드 전제 단위 테스트는 IT로 대체 예정"
```

---

### Task 3: TradingServiceIT + AuthServiceIT — 신규 유저 시나리오 행위 검증

**Files:**
- Test: `backend/src/test/kotlin/com/growant/trading/TradingServiceIT.kt`
- Test: `backend/src/test/kotlin/com/growant/auth/AuthServiceIT.kt`

- [ ] **Step 1: AuthServiceIT 작성**:

```kotlin
package com.growant.auth

import com.growant.common.INITIAL_CASH
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import com.growant.support.PostgresIntegrationTest
import com.growant.trading.PositionJpaRepository
import com.growant.trading.TradeJpaRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.oauth2.jwt.JwtDecoder

class AuthServiceIT(
    @Autowired val service: AuthService,
    @Autowired val users: UserJpaRepository,
    @Autowired val positions: PositionJpaRepository,
    @Autowired val trades: TradeJpaRepository,
    @Autowired val decoder: JwtDecoder,
) : PostgresIntegrationTest() {

    @Test
    fun `가입 시 INITIAL_CASH 지급 - 빈 포트폴리오·빈 내역으로 시작`() {
        val res = service.login("kakao", "잇-신규")
        val u = users.findById(res.user.id).orElseThrow()
        assertThat(u.cash).isEqualTo(INITIAL_CASH)
        assertThat(positions.findByUserId(u.id)).isEmpty()
        assertThat(trades.findByUserIdOrderByExecutedAtDescIdDesc(u.id)).isEmpty()
    }

    @Test
    fun `같은 provider+nickname 재로그인은 같은 사용자(멱등)`() {
        val a = service.login("naver", "잇-멱등")
        val b = service.login("naver", "잇-멱등")
        assertThat(b.user.id).isEqualTo(a.user.id)
    }

    @Test
    fun `발급 토큰 클레임 - sub는 DB id, nickname은 trim 적용`() {
        val res = service.login("google", "  잇-클레임  ")
        val jwt = decoder.decode(res.token)
        assertThat(jwt.subject).isEqualTo(res.user.id.toString())
        assertThat(jwt.getClaimAsString("nickname")).isEqualTo("잇-클레임")
        assertThat(jwt.getClaimAsString("provider")).isEqualTo("google")
    }

    @Test
    fun `잘못된 로그인 3종 거부 + 20자 경계 통과`() {
        listOf(
            { service.login("github", "잇-검증") },
            { service.login("kakao", "   ") },
            { service.login("kakao", "가".repeat(21)) },
        ).forEach { call ->
            assertThatThrownBy { call() }
                .isInstanceOf(BusinessException::class.java)
                .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.INVALID_LOGIN) })
        }
        assertThat(service.login("kakao", "잇".repeat(10)).user.nickname).hasSize(20)
    }
}
```

- [ ] **Step 2: TradingServiceIT 작성**:

```kotlin
package com.growant.trading

import com.growant.auth.UserEntity
import com.growant.auth.UserJpaRepository
import com.growant.common.INITIAL_CASH
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import com.growant.market.MarketService
import com.growant.support.PostgresIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class TradingServiceIT(
    @Autowired val service: TradingService,
    @Autowired val users: UserJpaRepository,
    @Autowired val positions: PositionJpaRepository,
    @Autowired val market: MarketService,
) : PostgresIntegrationTest() {

    private fun newUser(nick: String): Long =
        users.save(UserEntity(provider = "kakao", nickname = nick, cash = INITIAL_CASH)).id

    private fun assets(userId: Long): Long {
        val prices = market.getMarket().associateBy { it.ticker }
        return service.getCash(userId) +
            service.getMePositions(userId).sumOf { prices.getValue(it.ticker).price.toLong() * it.qty }
    }

    @Test
    fun `신규 매수 - 현금 차감·포지션 생성·내역 기록`() {
        val u = newUser("잇-매수")
        val t = service.placeOrder(u, "005930", true, 1) // 삼성전자 76,300
        assertThat(service.getCash(u)).isEqualTo(INITIAL_CASH - 76_300L)
        val pos = service.getMePositions(u).single()
        assertThat(pos.ticker).isEqualTo("005930")
        assertThat(pos.qty).isEqualTo(1)
        assertThat(pos.avgPrice).isEqualTo(76_300)
        assertThat(t.name).isEqualTo("삼성전자")
        assertThat(t.amount).isEqualTo(76_300L)
        assertThat(t.time).matches("""\d{2}\.\d{2} \d{2}:\d{2}""")
        assertThat(service.getTrades(u)).hasSize(1)
    }

    @Test
    fun `추가 매수 - 가중평단 재계산`() {
        val u = newUser("잇-평단")
        positions.save(PositionEntity(userId = u, ticker = "005930", qty = 12, avgPrice = 70_000))
        service.placeOrder(u, "005930", true, 1) // 76,300
        val pos = service.getMePositions(u).single()
        assertThat(pos.qty).isEqualTo(13)
        assertThat(pos.avgPrice).isEqualTo(70_485) // round(916,300/13)
    }

    @Test
    fun `매도 - 현금 증가·수량 차감·평단 유지`() {
        val u = newUser("잇-매도")
        positions.save(PositionEntity(userId = u, ticker = "000270", qty = 6, avgPrice = 98_700))
        service.placeOrder(u, "000270", false, 2) // 기아 109,500 × 2
        assertThat(service.getCash(u)).isEqualTo(INITIAL_CASH + 219_000L)
        val pos = service.getMePositions(u).single()
        assertThat(pos.qty).isEqualTo(4)
        assertThat(pos.avgPrice).isEqualTo(98_700)
    }

    @Test
    fun `전량 매도 - 포지션 삭제`() {
        val u = newUser("잇-전량")
        positions.save(PositionEntity(userId = u, ticker = "035420", qty = 3, avgPrice = 189_000))
        service.placeOrder(u, "035420", false, 3)
        assertThat(service.getMePositions(u)).isEmpty()
    }

    @Test
    fun `검증 에러 - 수량·티커·잔고·보유·미보유`() {
        val u = newUser("잇-에러")
        positions.save(PositionEntity(userId = u, ticker = "000660", qty = 4, avgPrice = 178_500))
        listOf(
            { service.placeOrder(u, "005930", true, 0) } to ErrorCode.INVALID_ORDER,
            { service.placeOrder(u, "999999", true, 1) } to ErrorCode.INVALID_TICKER,
            { service.placeOrder(u, "005380", true, 41) } to ErrorCode.ORDER_INSUFFICIENT_FUNDS, // 247,000×41 = 10,127,000 > 10,000,000
            { service.placeOrder(u, "000660", false, 5) } to ErrorCode.ORDER_INSUFFICIENT_HOLDINGS, // 보유 4
            { service.placeOrder(u, "005380", false, 1) } to ErrorCode.ORDER_INSUFFICIENT_HOLDINGS, // 미보유
        ).forEach { (call, code) ->
            assertThatThrownBy { call() }
                .isInstanceOf(BusinessException::class.java)
                .satisfies({ assertThat((it as BusinessException).code).isEqualTo(code) })
        }
    }

    @Test
    fun `체결 직후 자산 불변 - 현금 증감 = 평가 증감`() {
        val u = newUser("잇-불변")
        val before = assets(u)
        service.placeOrder(u, "005930", true, 2)
        assertThat(assets(u)).isEqualTo(before)
        service.placeOrder(u, "005930", false, 1)
        assertThat(assets(u)).isEqualTo(before)
    }

    @Test
    fun `내역은 최신순`() {
        val u = newUser("잇-내역")
        service.placeOrder(u, "005930", true, 1)
        service.placeOrder(u, "000660", true, 1)
        val trades = service.getTrades(u)
        assertThat(trades).hasSize(2)
        assertThat(trades.first().name).isEqualTo("SK하이닉스")
    }

    @Test
    fun `미존재 사용자 주문은 UNAUTHENTICATED - DB 리셋 후 옛 토큰 시나리오`() {
        assertThatThrownBy { service.placeOrder(999_999L, "005930", true, 1) }
            .isInstanceOf(BusinessException::class.java)
            .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.UNAUTHENTICATED) })
    }
}
```

- [ ] **Step 3: 검증**

Run: `cd backend && ./gradlew test --tests 'com.growant.trading.TradingServiceIT' --tests 'com.growant.auth.AuthServiceIT'`
Expected: 12 PASS (8+4)

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 35 tests

- [ ] **Step 4: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/test/kotlin/com/growant/trading/TradingServiceIT.kt backend/src/test/kotlin/com/growant/auth/AuthServiceIT.kt
git commit -m "test(persistence): TradingServiceIT·AuthServiceIT — 신규 유저 시나리오 행위 검증(Testcontainers)"
```

---

### Task 4: AccountServiceIT + ConcurrentOrderIT — 원자 요약·비관적 잠금 검증

**Files:**
- Test: `backend/src/test/kotlin/com/growant/account/AccountServiceIT.kt`
- Test: `backend/src/test/kotlin/com/growant/trading/ConcurrentOrderIT.kt`

- [ ] **Step 1: AccountServiceIT 작성**:

```kotlin
package com.growant.account

import com.growant.auth.UserEntity
import com.growant.auth.UserJpaRepository
import com.growant.common.INITIAL_CASH
import com.growant.support.PostgresIntegrationTest
import com.growant.trading.TradingService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class AccountServiceIT(
    @Autowired val service: AccountService,
    @Autowired val trading: TradingService,
    @Autowired val users: UserJpaRepository,
) : PostgresIntegrationTest() {

    @Test
    fun `가입 직후 요약 - 1,000만 - 0_0 퍼센트`() {
        val u = users.save(UserEntity(provider = "kakao", nickname = "잇-요약신규", cash = INITIAL_CASH)).id
        val s = service.getSummary(u)
        assertThat(s.totalAsset).isEqualTo(INITIAL_CASH)
        assertThat(s.returnRate).isEqualTo(0.0)
    }

    @Test
    fun `매수 직후에도 총자산 불변 - 현금이 평가로 이동했을 뿐`() {
        val u = users.save(UserEntity(provider = "kakao", nickname = "잇-요약매수", cash = INITIAL_CASH)).id
        trading.placeOrder(u, "005930", true, 3)
        val s = service.getSummary(u)
        assertThat(s.totalAsset).isEqualTo(INITIAL_CASH)
        assertThat(s.returnRate).isEqualTo(0.0)
    }
}
```

- [ ] **Step 2: ConcurrentOrderIT 작성**:

```kotlin
package com.growant.trading

import com.growant.auth.UserEntity
import com.growant.auth.UserJpaRepository
import com.growant.common.INITIAL_CASH
import com.growant.support.PostgresIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ConcurrentOrderIT(
    @Autowired val service: TradingService,
    @Autowired val users: UserJpaRepository,
) : PostgresIntegrationTest() {

    @Test
    fun `동시 매수에도 현금이 정확히 차감된다 - 사용자 행 비관적 잠금`() {
        val u = users.save(UserEntity(provider = "kakao", nickname = "잇-동시", cash = INITIAL_CASH)).id
        val pool = Executors.newFixedThreadPool(2)
        val start = CountDownLatch(1)
        val futures = (1..10).map {
            pool.submit {
                start.await()
                service.placeOrder(u, "005930", true, 1) // 76,300
            }
        }
        start.countDown()
        futures.forEach { it.get(30, TimeUnit.SECONDS) }
        pool.shutdown()

        assertThat(service.getCash(u)).isEqualTo(INITIAL_CASH - 10 * 76_300L)
        assertThat(service.getMePositions(u).single().qty).isEqualTo(10)
        assertThat(service.getTrades(u)).hasSize(10)
    }
}
```

- [ ] **Step 3: 검증**

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 38 tests

- [ ] **Step 4: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/test/kotlin/com/growant/account/AccountServiceIT.kt backend/src/test/kotlin/com/growant/trading/ConcurrentOrderIT.kt
git commit -m "test(persistence): 원자 요약(REPEATABLE_READ)·동시 주문(비관적 잠금) IT"
```

---

### Task 5: 프론트 — 내역 탭 빈 상태 (신규 유저 첫 화면)

**Files:**
- Modify: `frontend/lib/features/trading/trade_history_screen.dart`
- Modify: `frontend/test/features/trading/trade_history_screen_test.dart`

- [ ] **Step 1: 실패하는 테스트 추가** — `trade_history_screen_test.dart`의 `_FakeRepo`를 다음으로 교체(목록 주입 가능하게):

```dart
class _FakeRepo implements TradeRepository {
  final Object? error;
  final List<Trade> trades;
  _FakeRepo({this.error, this.trades = _trades});

  @override
  Future<List<Trade>> fetchTrades() async {
    if (error != null) throw error!;
    return trades;
  }

  @override
  Future<Trade> placeOrder({required String ticker, required bool isBuy, required int qty}) async =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
```

그리고 `main()` 마지막에 케이스 추가:

```dart
  testWidgets('내역이 없으면 빈 상태 문구를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(trades: const [])));
    await tester.pump();
    expect(find.text('거래 내역이 없습니다'), findsOneWidget);
    expect(find.text('총 매수'), findsNothing); // 요약 바 생략
  });
```

- [ ] **Step 2: 실패 확인**

Run: `cd frontend && flutter test test/features/trading/trade_history_screen_test.dart`
Expected: 신규 케이스 FAIL('거래 내역이 없습니다' 미발견)

- [ ] **Step 3: 화면 수정** — `trade_history_screen.dart`의 `data:` 분기 시작부를 교체:

```dart
      data: (trades) {
        final fmt = NumberFormat('#,###');
```

→

```dart
      data: (trades) {
        if (trades.isEmpty) {
          return const Center(
            child: Text('거래 내역이 없습니다',
                style: TextStyle(color: Color(0xFF888888), fontSize: 14)),
          );
        }
        final fmt = NumberFormat('#,###');
```

- [ ] **Step 4: 검증**

Run: `cd frontend && flutter test && flutter analyze`
Expected: 47 tests 통과(46+1) / No issues found!

- [ ] **Step 5: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/trading/trade_history_screen.dart frontend/test/features/trading/trade_history_screen_test.dart
git commit -m "feat(trading): 내역 탭 빈 상태 문구 — 신규 가입(빈 내역) 첫 화면 대응"
```

---

### Task 6: 인프라 — Dockerfile + 프로파일 + compose 완성 + README + 검증 게이트

**Files:**
- Create: `backend/Dockerfile`
- Create: `backend/src/main/resources/application-dev.yml`
- Modify(전체 교체): `backend/src/main/resources/application-local.yml`
- Modify: `docker-compose.yml`
- Modify: `README.md`

- [ ] **Step 1: Dockerfile 생성** — `backend/Dockerfile`:

```dockerfile
# 빌드 스테이지 — gradle 래퍼로 프로젝트 고정 버전(9.5.1) 사용
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
COPY src ./src
RUN ./gradlew bootJar --no-daemon

# 런타임 스테이지
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

- [ ] **Step 2: application-dev.yml 생성** — `backend/src/main/resources/application-dev.yml`:

```yaml
# compose 내부 실행용 프로파일 — datasource(DB_URL 등)·REDIS_HOST는 compose environment가 주입한다.
# dev 전용으로 분기할 설정이 생기면 여기에 추가한다(현재는 기본 application.yml로 충분).
```

- [ ] **Step 3: application-local.yml 전체 교체** (DB 필수 전환 — 스펙 §9.3):

```yaml
# 로컬 bootRun용 — DB는 docker compose의 postgres를 사용한다: 먼저 `docker compose up -d postgres`.
# Redis는 ④ 실시세 슬라이스까지 미사용 — 오토컨피그만 제외한다.
spring:
  autoconfigure:
    exclude:
      - org.springframework.boot.data.redis.autoconfigure.DataRedisAutoConfiguration
  datasource:
    url: jdbc:postgresql://localhost:5432/growant
    username: growant
    password: growant
```

- [ ] **Step 4: docker-compose.yml 수정** — postgres 서비스에 healthcheck 추가:

```yaml
  # 자체 호스팅 PostgreSQL — 데이터는 도커 볼륨(postgres-data)에 영속
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: growant
      POSTGRES_USER: ${DB_USER:-growant}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-growant}
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U growant -d growant"]
      interval: 5s
      timeout: 3s
      retries: 10
```

backend 서비스의 `environment`와 `depends_on`을 다음으로 교체:

```yaml
    environment:
      SPRING_PROFILES_ACTIVE: dev
      # 컨테이너 내부에서는 서비스명으로 접속(.env의 localhost 값을 덮어씀)
      DB_URL: jdbc:postgresql://postgres:5432/growant
      REDIS_HOST: redis
    expose:
      - "8080"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
```

- [ ] **Step 5: README 실행 섹션 갱신** — `README.md`에서

```bash
# 인프라 + 백엔드 + Redis + PostgreSQL
# (백엔드 Dockerfile·dev 프로파일은 영속성 슬라이스에서 정비 예정 — 현재는 아래 '백엔드 단독' 사용)
docker compose up -d

# 백엔드 단독 (local 프로파일 — DB 불필요. 루트 .env가 있으면 자동 로드)
cd backend && ./gradlew bootRun --args='--spring.profiles.active=local'
```

를 다음으로 교체:

```bash
# 전체 스택 (nginx + 백엔드 + Redis + PostgreSQL)
docker compose up --build -d

# 백엔드 단독 (local 프로파일 — DB는 compose의 postgres 사용)
docker compose up -d postgres
cd backend && ./gradlew bootRun --args='--spring.profiles.active=local'
```

그리고 사전 준비 섹션의

```markdown
- `.env`는 `.env.example` 참고해 작성 — DB는 docker compose의 **PostgreSQL 컨테이너**(자체 호스팅)
```

를 다음으로 교체:

```markdown
- `.env`는 `.env.example` 참고해 작성(선택 — 없으면 dev 기본값으로 동작) — DB는 docker compose의 **PostgreSQL 컨테이너**(자체 호스팅, 데이터는 도커 볼륨에 영속)
```

- [ ] **Step 6: compose 검증 게이트**

```bash
cd /Users/gsmin/GrowAnt && docker compose up --build -d
# backend 기동 대기(빌드 수 분 소요 가능) 후:
for i in $(seq 1 60); do curl -s -o /dev/null -w "%{http_code}" http://localhost:80/api/trades 2>/dev/null | grep -q 401 && echo NGINX-OK && break; sleep 3; done
docker compose ps   # backend Up, postgres healthy 확인
docker compose logs backend | grep -i "flyway\|Started"   # Flyway 마이그레이션 + 기동 로그 확인
docker compose down   # 볼륨은 유지(-v 금지)
```

Expected: `NGINX-OK`(nginx 경유 401 envelope — 전체 스택 관통), Flyway `Successfully applied 1 migration` 로그. nginx 80 포트가 막혀 있으면 `curl http://localhost:8080`이 아닌 compose 내부라 직접 접근 불가 — 이 경우 `docker compose exec backend wget -qO- http://localhost:8080/api/trades`로 대체하고 보고에 명시.

- [ ] **Step 7: 백엔드·프론트 최종 회귀**

Run: `cd backend && ./gradlew test` → 38 tests / `cd frontend && flutter test` → 47 / `flutter analyze` → clean

- [ ] **Step 8: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/Dockerfile backend/src/main/resources/application-dev.yml backend/src/main/resources/application-local.yml docker-compose.yml README.md
git commit -m "chore(persistence): Dockerfile·dev/local 프로파일·compose healthcheck — docker compose up 경로 완성"
```

---

## 완료 후

1. push + `gh pr create` — base `main`, head `feat/persistence-slice`. **병합하지 않고 OPEN 유지**(사용자 검토).
2. PR 본문에 알려진 한계(스펙 §11): AI 포지션 미영속(⑤) / Redis 준비만(④) / 닉네임=신원 유지 / 데이터 수명=postgres 볼륨(`down -v` 시 초기화, 옛 JWT는 401→재로그인).
3. 수동 확인 안내: `docker compose up -d postgres` → bootRun → 앱 로그인(신규 닉네임) → 자산 10,000,000/0.0%·빈 내역 확인 → 매수 → **서버 재시작** → 자동 로그인 후 포트폴리오·내역 유지 확인(영속성의 핵심 데모).
