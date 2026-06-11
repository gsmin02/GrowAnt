# ⑥ 인증 슬라이스 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** mock 로그인을 실제 인증으로 — 데모 로그인(provider+nickname) → JWT 발급, 전체 API 보호, 프론트 자동 로그인(AuthGate)·로그아웃·프로필 연동.

**Architecture:** 백엔드는 Spring 공식 `oauth2-resource-server`로 자체 서명 HS256 JWT(커스텀 필터 0개) — `UserStore`(in-memory find-or-create) + `AuthService`(발급) + 401 envelope `AuthenticationEntryPoint`. 프론트는 core `TokenStorage`(secure storage) + dio Authorization 인터셉터 + `AuthGate`(상태가 화면 결정). 기존 컨트롤러 테스트는 `jwt()` post-processor로 보정.

**Tech Stack:** Spring Boot 4 / Kotlin / spring-boot-starter-oauth2-resource-server / spring-security-test · Flutter / riverpod / dio / flutter_secure_storage / http_mock_adapter

**Spec:** `docs/superpowers/specs/2026-06-11-auth-slice-design.md`

**Branch:** 시작 전 `git checkout -b feat/auth-slice` (main 기준). 완료 후 PR은 **open 상태로만 두고 병합하지 않는다**(사용자 검토).

**검증 명령 위치:** 백엔드는 `/Users/gsmin/GrowAnt/backend`에서 `./gradlew test`, 프론트는 `/Users/gsmin/GrowAnt/frontend`에서 `flutter test`/`flutter analyze`. 커밋은 repo 루트에서.

---

## 테스트 수 추적

| 시점 | 백엔드 | 프론트 |
|---|---|---|
| 시작(main) | 22 | 33 |
| T1 후 | 25 (+AuthServiceTest 3) | 33 |
| T2 후 | 29 (+AuthControllerTest 4) | 33 |
| T3 후 | 29 | 33 (기존 그린 유지) |
| T4 후 | 29 | 35 (+인터셉터 2) |
| T5 후 | 29 | 38 (+auth repo 3) |
| T6 후 | 29 | 43 (+AuthGate 3, 로그인 2) |
| T7 후 | 29 | 45 (+계정탭 2) |

---

### Task 1: 백엔드 — 의존성 + ErrorCode + JwtConfig + auth 도메인(UserStore·AuthService)

**Files:**
- Modify: `backend/build.gradle.kts`
- Modify: `backend/src/main/kotlin/com/growant/common/error/ErrorCode.kt`
- Modify: `backend/src/main/resources/application.yml`
- Create: `backend/src/main/kotlin/com/growant/common/config/JwtConfig.kt`
- Create: `backend/src/main/kotlin/com/growant/auth/User.kt`
- Create: `backend/src/main/kotlin/com/growant/auth/UserStore.kt`
- Create: `backend/src/main/kotlin/com/growant/auth/dto/AuthDtos.kt`
- Create: `backend/src/main/kotlin/com/growant/auth/AuthService.kt`
- Test: `backend/src/test/kotlin/com/growant/auth/AuthServiceTest.kt`

이 task에서는 SecurityConfig를 **건드리지 않는다**(컨트롤러·보호 전환은 Task 2) — 기존 22개 테스트가 그대로 그린이어야 한다.

- [ ] **Step 1: 의존성 추가** — `backend/build.gradle.kts`에서

```kotlin
    implementation("org.springframework.boot:spring-boot-starter-security")
```

를 다음으로 교체:

```kotlin
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")
```

그리고

```kotlin
    testImplementation("org.springframework.boot:spring-boot-webmvc-test")
```

를 다음으로 교체:

```kotlin
    testImplementation("org.springframework.boot:spring-boot-webmvc-test")
    testImplementation("org.springframework.security:spring-security-test")
```

- [ ] **Step 2: ErrorCode 추가** — `ErrorCode.kt`에서

```kotlin
    INVALID_ORDER(3001, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "잘못된 주문입니다."),
```

를 다음으로 교체:

```kotlin
    INVALID_ORDER(3001, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "잘못된 주문입니다."),
    INVALID_LOGIN(3002, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "잘못된 로그인 요청입니다."),
```

- [ ] **Step 3: application.yml에 JWT 키 프로퍼티 추가** — `backend/src/main/resources/application.yml` 맨 아래(`market:` 블록 뒤)에 추가:

```yaml

# 데모 로그인 JWT 서명 키(HS256, 32자=256bit 이상 필수) — 운영은 루트 .env의 JWT_SECRET. 스펙 §3.3
auth:
  jwt:
    secret: ${JWT_SECRET:growant-dev-secret-please-override-32b!}
```

- [ ] **Step 4: 실패하는 서비스 테스트 작성** — `backend/src/test/kotlin/com/growant/auth/AuthServiceTest.kt` 생성:

```kotlin
package com.growant.auth

import com.growant.common.config.JwtConfig
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import java.time.Instant

class AuthServiceTest {
    private val jwtConfig = JwtConfig("test-secret-must-be-32-bytes-min!!")
    private val service = AuthService(UserStore(), jwtConfig.jwtEncoder())
    private val decoder = jwtConfig.jwtDecoder()

    @Test
    fun `같은 provider+nickname은 같은 사용자(멱등), 다른 provider는 다른 사용자`() {
        val a = service.login("kakao", "개미왕")
        val b = service.login("kakao", "개미왕")
        val c = service.login("naver", "개미왕")
        assertThat(b.user.id).isEqualTo(a.user.id)
        assertThat(c.user.id).isNotEqualTo(a.user.id)
    }

    @Test
    fun `발급 토큰은 디코딩되고 sub·nickname·provider 클레임을 담는다`() {
        val res = service.login("google", "  grow  ") // trim 검증 겸용
        assertThat(res.user.nickname).isEqualTo("grow")
        val jwt = decoder.decode(res.token)
        assertThat(jwt.subject).isEqualTo(res.user.id.toString())
        assertThat(jwt.getClaimAsString("nickname")).isEqualTo("grow")
        assertThat(jwt.getClaimAsString("provider")).isEqualTo("google")
        assertThat(jwt.expiresAt).isAfter(Instant.now())
    }

    @Test
    fun `잘못된 로그인 3종 - 불허 provider, 공백 닉네임, 21자 닉네임`() {
        listOf(
            { service.login("github", "grow") },
            { service.login("kakao", "   ") },
            { service.login("kakao", "가".repeat(21)) },
        ).forEach { call ->
            assertThatThrownBy { call() }
                .isInstanceOf(BusinessException::class.java)
                .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.INVALID_LOGIN) })
        }
    }
}
```

- [ ] **Step 5: 실패 확인**

Run: `cd backend && ./gradlew test --tests 'com.growant.auth.AuthServiceTest'`
Expected: 컴파일 실패(`JwtConfig`, `AuthService`, `UserStore` 미정의)

- [ ] **Step 6: JwtConfig 생성** — `backend/src/main/kotlin/com/growant/common/config/JwtConfig.kt`:

```kotlin
package com.growant.common.config

import com.nimbusds.jose.jwk.source.ImmutableSecret
import com.nimbusds.jose.proc.SecurityContext
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.oauth2.jose.jws.MacAlgorithm
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.oauth2.jwt.JwtEncoder
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder
import javax.crypto.spec.SecretKeySpec

/** 데모 로그인용 자체 서명 HS256 JWT 인코더/디코더. 키는 JWT_SECRET(루트 .env) — 32자 미만이면 부팅 실패가 정상. 스펙 §3.3 */
@Configuration
class JwtConfig(@Value("\${auth.jwt.secret}") private val secret: String) {

    private val key = SecretKeySpec(secret.toByteArray(), "HmacSHA256")

    @Bean
    fun jwtEncoder(): JwtEncoder = NimbusJwtEncoder(ImmutableSecret<SecurityContext>(key))

    @Bean
    fun jwtDecoder(): JwtDecoder =
        NimbusJwtDecoder.withSecretKey(key).macAlgorithm(MacAlgorithm.HS256).build()
}
```

- [ ] **Step 7: auth 도메인 생성**

`backend/src/main/kotlin/com/growant/auth/User.kt`:

```kotlin
package com.growant.auth

/** 데모 사용자 — (provider, nickname) 조합이 신원(비밀번호 없음). 영속성 슬라이스에서 DB로 이관. */
data class User(val id: Long, val nickname: String, val provider: String)
```

`backend/src/main/kotlin/com/growant/auth/UserStore.kt`:

```kotlin
package com.growant.auth

import org.springframework.stereotype.Component
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/** in-memory find-or-create — 같은 (provider, nickname) 재로그인이면 같은 User(멱등). 재시작 시 초기화. */
@Component
class UserStore {
    private val seq = AtomicLong(0)
    private val users = ConcurrentHashMap<String, User>()

    fun findOrCreate(provider: String, nickname: String): User =
        users.computeIfAbsent("$provider:$nickname") {
            User(seq.incrementAndGet(), nickname, provider)
        }
}
```

`backend/src/main/kotlin/com/growant/auth/dto/AuthDtos.kt`:

```kotlin
package com.growant.auth.dto

data class LoginRequestDto(val provider: String, val nickname: String)

data class UserDto(val id: Long, val nickname: String, val provider: String)

data class AuthResponseDto(val token: String, val user: UserDto)
```

`backend/src/main/kotlin/com/growant/auth/AuthService.kt`:

```kotlin
package com.growant.auth

import com.growant.auth.dto.AuthResponseDto
import com.growant.auth.dto.UserDto
import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import org.springframework.security.oauth2.jose.jws.MacAlgorithm
import org.springframework.security.oauth2.jwt.JwsHeader
import org.springframework.security.oauth2.jwt.JwtClaimsSet
import org.springframework.security.oauth2.jwt.JwtEncoder
import org.springframework.security.oauth2.jwt.JwtEncoderParameters
import org.springframework.stereotype.Service
import java.time.Duration
import java.time.Instant

/**
 * 데모 로그인 — 비밀번호 없이 (provider, nickname) find-or-create 후 HS256 JWT 발급.
 * 실제 소셜 OAuth 전환 시 이 login 내부(인가코드 검증)만 교체한다. 스펙 §3.2
 */
@Service
class AuthService(private val userStore: UserStore, private val jwtEncoder: JwtEncoder) {

    fun login(provider: String, nickname: String): AuthResponseDto {
        val name = nickname.trim()
        if (provider !in PROVIDERS || name.isEmpty() || name.length > 20) {
            throw BusinessException(ErrorCode.INVALID_LOGIN)
        }
        val user = userStore.findOrCreate(provider, name)
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

    companion object {
        private val PROVIDERS = setOf("kakao", "naver", "apple", "google")
        private val TOKEN_TTL: Duration = Duration.ofHours(24)
    }
}
```

- [ ] **Step 8: 통과 확인 + 전체 회귀**

Run: `cd backend && ./gradlew test --tests 'com.growant.auth.AuthServiceTest'`
Expected: 3 tests PASS

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 25 tests (기존 22 + 신규 3). SecurityConfig 무변경이라 기존 컨트롤러 테스트 영향 없음.

- [ ] **Step 9: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/build.gradle.kts backend/src/main/kotlin/com/growant/common backend/src/main/kotlin/com/growant/auth backend/src/test/kotlin/com/growant/auth backend/src/main/resources/application.yml
git commit -m "feat(auth): UserStore·AuthService — 데모 로그인 + HS256 JWT 발급(JwtConfig)"
```

---

### Task 2: 백엔드 — AuthController + 401 EntryPoint + SecurityConfig 전체 보호 전환 + 기존 테스트 보정

SecurityConfig 전환과 기존 테스트 보정은 분리 불가능한 **원자 변경**(전환만 하면 기존 9케이스가 401로 깨짐) — 한 커밋으로 묶는다.

**Files:**
- Create: `backend/src/main/kotlin/com/growant/auth/AuthController.kt`
- Create: `backend/src/main/kotlin/com/growant/common/config/ApiAuthEntryPoint.kt`
- Modify: `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt` (전체 교체)
- Test: `backend/src/test/kotlin/com/growant/auth/AuthControllerTest.kt` (신규)
- Modify: `backend/src/test/kotlin/com/growant/market/MarketControllerTest.kt` (전체 교체)
- Modify: `backend/src/test/kotlin/com/growant/portfolio/PortfolioControllerTest.kt` (전체 교체)
- Modify: `backend/src/test/kotlin/com/growant/account/AccountControllerTest.kt` (전체 교체)
- Modify: `backend/src/test/kotlin/com/growant/trading/TradingControllerTest.kt` (전체 교체)

- [ ] **Step 1: 실패하는 컨트롤러 테스트 작성** — `backend/src/test/kotlin/com/growant/auth/AuthControllerTest.kt`:

```kotlin
package com.growant.auth

import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@WebMvcTest(AuthController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class, AuthService::class, UserStore::class)
class AuthControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `POST login returns token and user envelope`() {
        mockMvc.post("/api/auth/login") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"provider":"kakao","nickname":"개미왕"}"""
        }.andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.token") { isString() } }
            .andExpect { jsonPath("$.data.user.nickname") { value("개미왕") } }
            .andExpect { jsonPath("$.data.user.provider") { value("kakao") } }
    }

    @Test
    fun `POST login with unknown provider returns 400 INVALID_LOGIN envelope`() {
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

- [ ] **Step 2: 실패 확인**

Run: `cd backend && ./gradlew test --tests 'com.growant.auth.AuthControllerTest'`
Expected: 컴파일 실패(`AuthController`, `ApiAuthEntryPoint` 미정의)

- [ ] **Step 3: AuthController 생성** — `backend/src/main/kotlin/com/growant/auth/AuthController.kt`:

```kotlin
package com.growant.auth

import com.growant.auth.dto.AuthResponseDto
import com.growant.auth.dto.LoginRequestDto
import com.growant.auth.dto.UserDto
import com.growant.common.web.ApiResponse
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/auth")
class AuthController(private val service: AuthService) {

    @PostMapping("/login")
    fun login(@RequestBody req: LoginRequestDto): ApiResponse<AuthResponseDto> =
        ApiResponse.ok(service.login(req.provider, req.nickname))

    /** 클레임 기반 — 스토어 조회 없음. 서버가 재시작돼도 유효 토큰이면 동작한다. 스펙 §3.2 */
    @GetMapping("/me")
    fun me(@AuthenticationPrincipal jwt: Jwt): ApiResponse<UserDto> = ApiResponse.ok(
        UserDto(jwt.subject.toLong(), jwt.getClaimAsString("nickname"), jwt.getClaimAsString("provider")),
    )
}
```

- [ ] **Step 4: ApiAuthEntryPoint 생성** — `backend/src/main/kotlin/com/growant/common/config/ApiAuthEntryPoint.kt`:

```kotlin
package com.growant.common.config

import com.fasterxml.jackson.databind.ObjectMapper
import com.growant.common.error.ErrorCode
import com.growant.common.web.ApiError
import com.growant.common.web.ApiResponse
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.MediaType
import org.springframework.security.core.AuthenticationException
import org.springframework.security.web.AuthenticationEntryPoint
import org.springframework.stereotype.Component
import java.util.UUID

/** 보호 API의 401을 ApiResponse 에러 envelope로 통일 — 토큰 부재·만료·서명 오류 동일 취급(스펙 §3.4). */
@Component
class ApiAuthEntryPoint(private val objectMapper: ObjectMapper) : AuthenticationEntryPoint {
    override fun commence(
        request: HttpServletRequest,
        response: HttpServletResponse,
        authException: AuthenticationException,
    ) {
        val c = ErrorCode.UNAUTHENTICATED
        response.status = c.status.value()
        response.contentType = MediaType.APPLICATION_JSON_VALUE
        response.characterEncoding = "UTF-8"
        val body = ApiResponse<Nothing>(
            success = false,
            error = ApiError(
                code = c.name,
                errorCode = c.errorCode,
                eventType = c.eventType,
                message = c.defaultMessage,
                retryable = c.retryable,
                traceId = UUID.randomUUID().toString(),
            ),
        )
        response.writer.write(objectMapper.writeValueAsString(body))
    }
}
```

- [ ] **Step 5: SecurityConfig 전체 교체** — `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt`:

```kotlin
package com.growant.common.config

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.web.SecurityFilterChain

@Configuration
@EnableWebSecurity
class SecurityConfig(private val authEntryPoint: ApiAuthEntryPoint) {
    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        http
            .csrf { it.disable() }
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .authorizeHttpRequests {
                it.requestMatchers("/api/auth/login").permitAll() // me는 보호(JWT 클레임 필요)
                it.anyRequest().authenticated()
            }
            .oauth2ResourceServer {
                it.jwt { } // JwtConfig의 JwtDecoder 빈 사용
                it.authenticationEntryPoint(authEntryPoint)
            }
        return http.build()
    }
}
```

- [ ] **Step 6: 기존 컨트롤러 테스트 4파일 보정 (전체 교체)**

공통 변경: `@Import`에 `JwtConfig::class, ApiAuthEntryPoint::class` 추가 + 모든 요청에 `with(jwt())` + import 3줄 추가.

`backend/src/test/kotlin/com/growant/market/MarketControllerTest.kt` 전체 교체:

```kotlin
package com.growant.market

import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

@WebMvcTest(MarketController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class, MarketService::class)
class MarketControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `GET market returns success envelope with 8 rows`() {
        mockMvc.get("/api/market") { with(jwt()) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.length()") { value(8) } }
            .andExpect { jsonPath("$.data[0].ticker") { value("005930") } }
    }

    @Test
    fun `GET market detail returns candles and fundamentals`() {
        mockMvc.get("/api/market/005930") { with(jwt()) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.data.candles.length()") { value(10) } }
            .andExpect { jsonPath("$.data.per") { value(12.4) } }
    }

    @Test
    fun `GET market detail unknown ticker returns INVALID_TICKER 400`() {
        mockMvc.get("/api/market/999999") { with(jwt()) }
            .andExpect { status { isBadRequest() } }
            .andExpect { jsonPath("$.success") { value(false) } }
            .andExpect { jsonPath("$.error.code") { value("INVALID_TICKER") } }
            .andExpect { jsonPath("$.error.eventType") { value("VALIDATION_ERROR") } }
    }
}
```

`backend/src/test/kotlin/com/growant/portfolio/PortfolioControllerTest.kt` 전체 교체:

```kotlin
package com.growant.portfolio

import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import com.growant.market.MarketService
import com.growant.trading.TradingService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

@WebMvcTest(PortfolioController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class, PortfolioService::class, MarketService::class, TradingService::class)
class PortfolioControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `GET portfolio me returns envelope with aggregates and 4 holdings`() {
        mockMvc.get("/api/portfolio/me") { with(jwt()) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.returnRate") { value(5.2) } }
            .andExpect { jsonPath("$.data.profit") { value(142600) } }
            .andExpect { jsonPath("$.data.holdings.length()") { value(4) } }
            .andExpect { jsonPath("$.data.holdings[0].ticker") { value("005930") } }
    }

    @Test
    fun `GET portfolio ai returns envelope with aggregates`() {
        mockMvc.get("/api/portfolio/ai") { with(jwt()) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.returnRate") { value(3.8) } }
            .andExpect { jsonPath("$.data.holdings.length()") { value(4) } }
    }
}
```

`backend/src/test/kotlin/com/growant/account/AccountControllerTest.kt` 전체 교체:

```kotlin
package com.growant.account

import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import com.growant.market.MarketService
import com.growant.portfolio.PortfolioService
import com.growant.trading.TradingService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

@WebMvcTest(AccountController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class, AccountService::class, PortfolioService::class, MarketService::class, TradingService::class)
class AccountControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `GET account summary returns envelope`() {
        mockMvc.get("/api/account/summary") { with(jwt()) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.totalAsset") { value(10520000) } }
            .andExpect { jsonPath("$.data.returnRate") { value(5.2) } }
    }
}
```

`backend/src/test/kotlin/com/growant/trading/TradingControllerTest.kt` 전체 교체:

```kotlin
// NOTE: @WebMvcTest 컨텍스트가 테스트 간 공유되어 TradingService 상태가 누적되므로 GET 테스트는 정확한 개수 대신 형태만 단언한다.
package com.growant.trading

import com.growant.common.config.ApiAuthEntryPoint
import com.growant.common.config.JwtConfig
import com.growant.common.config.SecurityConfig
import com.growant.market.MarketService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@WebMvcTest(TradingController::class)
@Import(SecurityConfig::class, JwtConfig::class, ApiAuthEntryPoint::class, TradingService::class, MarketService::class)
class TradingControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `POST orders executes and returns trade envelope`() {
        mockMvc.post("/api/orders") {
            with(jwt())
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
            with(jwt())
            contentType = MediaType.APPLICATION_JSON
            content = """{"ticker":"005380","isBuy":true,"qty":1000}"""
        }.andExpect { status { isConflict() } }
            .andExpect { jsonPath("$.success") { value(false) } }
            .andExpect { jsonPath("$.error.code") { value("ORDER_INSUFFICIENT_FUNDS") } }
            .andExpect { jsonPath("$.error.eventType") { value("ORDER_ERROR") } }
    }

    @Test
    fun `GET trades returns history envelope`() {
        mockMvc.get("/api/trades") { with(jwt()) }
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data[0].name") { isString() } }
    }
}
```

- [ ] **Step 7: 전체 통과 확인**

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 29 tests (25 + AuthControllerTest 4), 0 failures

- [ ] **Step 8: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add backend/src/main/kotlin/com/growant/auth backend/src/main/kotlin/com/growant/common/config backend/src/test/kotlin
git commit -m "feat(auth): /api/auth/login·me + 전체 API JWT 보호 전환(401 envelope) — 기존 테스트 jwt() 보정"
```

---

### Task 3: 프론트 — asApiException 공용 추출 + 4개 repo 교체

**Files:**
- Modify: `frontend/lib/core/api/api_exception.dart`
- Modify: `frontend/lib/features/market/data/market_repository.dart`
- Modify: `frontend/lib/features/duel/data/portfolio_repository.dart`
- Modify: `frontend/lib/features/account/data/account_repository.dart`
- Modify: `frontend/lib/features/trading/data/trade_repository.dart`

신규 테스트 없음 — 기존 repo 테스트 4벌이 회귀 가드(동작 무변경 리팩터).

- [ ] **Step 1: 공용 함수 추가** — `frontend/lib/core/api/api_exception.dart` 맨 위에 import 추가:

```dart
import 'package:dio/dio.dart';
```

파일 맨 아래에 추가:

```dart

/// DioException → ApiException 매핑 — envelope 인터셉터가 심은 ApiException을 우선, 그 외는 네트워크 오류.
ApiException asApiException(DioException e) => e.error is ApiException
    ? e.error as ApiException
    : const ApiException(
        eventType: 'NETWORK',
        code: 'ERR_NETWORK',
        message: '인터넷 연결을 확인해주세요.',
        retryable: true,
      );
```

- [ ] **Step 2: 4개 repo 교체** — 4개 파일 각각에서 (a) private 메서드 블록 삭제(4벌 모두 동일한 아래 블록 — 들여쓰기·줄바꿈이 파일마다 한 줄/멀티라인일 수 있으니 `_asApiException` 메서드 전체를 찾아 삭제):

```dart
  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : const ApiException(eventType: 'NETWORK', code: 'ERR_NETWORK', message: '인터넷 연결을 확인해주세요.', retryable: true);
```

(b) 각 호출부 `throw _asApiException(e);` → `throw asApiException(e);` (파일당 1~2곳). `core/api/api_exception.dart` import는 4개 파일 모두 이미 있음 — 추가 불필요.

- [ ] **Step 3: 검증**

Run: `cd frontend && grep -rn "_asApiException" lib/ test/ || echo CLEAN`
Expected: `CLEAN`

Run: `cd frontend && flutter analyze`
Expected: No issues found!

Run: `cd frontend && flutter test`
Expected: 33 tests 전부 통과(동작 무변경 — repo 테스트 4벌이 가드)

- [ ] **Step 4: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/core/api/api_exception.dart frontend/lib/features/market/data/market_repository.dart frontend/lib/features/duel/data/portfolio_repository.dart frontend/lib/features/account/data/account_repository.dart frontend/lib/features/trading/data/trade_repository.dart
git commit -m "refactor(core): asApiException 공용 추출 — repo 4벌 중복 제거(auth가 5번째 복제 되기 전)"
```

---

### Task 4: 프론트 — flutter_secure_storage + TokenStorage + Authorization 인터셉터

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/core/api/token_storage.dart`
- Modify: `frontend/lib/core/api/api_client.dart`
- Modify: `frontend/lib/features/market/application/market_providers.dart`
- Test: `frontend/test/core/api_client_token_test.dart`

- [ ] **Step 1: 의존성 추가** — `frontend/pubspec.yaml`에서

```yaml
  dio: ^5.4.3+1
```

를 다음으로 교체:

```yaml
  dio: ^5.4.3+1
  flutter_secure_storage: ^9.2.2
```

Run: `cd frontend && flutter pub get`
Expected: 성공

- [ ] **Step 2: 실패하는 인터셉터 테스트 작성** — `frontend/test/core/api_client_token_test.dart` 생성:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';

void main() {
  // 토큰 인터셉터 뒤에 검사용 인터셉터를 붙여 실제 부착된 헤더를 캡처한다(헤더 매처 의존 회피).
  Future<String?> capturedAuthHeader({required Future<String?> Function() getToken}) async {
    final dio = createApiClient(baseUrl: 'http://test', getToken: getToken);
    String? seen;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      seen = o.headers['Authorization'] as String?;
      h.next(o);
    }));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/ping', (s) => s.reply(200, {'success': true, 'data': 'pong'}));
    await dio.get('/ping');
    return seen;
  }

  test('getToken이 토큰을 주면 Authorization Bearer 헤더를 부착한다', () async {
    final header = await capturedAuthHeader(getToken: () async => 'jwt-123');
    expect(header, 'Bearer jwt-123');
  });

  test('토큰이 null이면 Authorization 헤더를 부착하지 않는다', () async {
    final header = await capturedAuthHeader(getToken: () async => null);
    expect(header, isNull);
  });
}
```

- [ ] **Step 3: 실패 확인**

Run: `cd frontend && flutter test test/core/api_client_token_test.dart`
Expected: 컴파일 에러(`getToken` named parameter 미존재)

- [ ] **Step 4: api_client.dart 수정** — `createApiClient` 함수 시그니처와 본문 앞부분을 다음으로 교체(envelope 인터셉터 블록은 그대로 유지):

```dart
Dio createApiClient({String baseUrl = kApiBaseUrl, Future<String?> Function()? getToken}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  // 인증 토큰 부착 — 주입된 경우에만(테스트·비로그인 경로 영향 0). 스펙 §4.3
  if (getToken != null) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
  }
  dio.interceptors.add(InterceptorsWrapper(
```

(이후 기존 `onResponse:`/`onError:` 블록과 `return dio;`는 무수정.)

- [ ] **Step 5: TokenStorage 생성** — `frontend/lib/core/api/token_storage.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT 보관(iOS Keychain). dioProvider와 auth feature가 함께 쓰는 core 계층 — feature 간 순환 import 방지. 스펙 §4.2
class TokenStorage {
  static const _key = 'auth_token';
  final FlutterSecureStorage _storage;
  const TokenStorage([this._storage = const FlutterSecureStorage()]);

  Future<String?> read() => _storage.read(key: _key);
  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => const TokenStorage());
```

- [ ] **Step 6: dioProvider 연결** — `frontend/lib/features/market/application/market_providers.dart`에서

```dart
import '../../../core/api/api_client.dart';
```

를 다음으로 교체:

```dart
import '../../../core/api/api_client.dart';
import '../../../core/api/token_storage.dart';
```

그리고

```dart
final dioProvider = Provider<Dio>((ref) => createApiClient());
```

를 다음으로 교체:

```dart
final dioProvider = Provider<Dio>(
  (ref) => createApiClient(getToken: () => ref.read(tokenStorageProvider).read()),
);
```

- [ ] **Step 7: 검증**

Run: `cd frontend && flutter test test/core/api_client_token_test.dart`
Expected: 2 tests 통과

Run: `cd frontend && flutter analyze && flutter test`
Expected: No issues found! / 35 tests 통과(33+2). 기존 위젯 테스트는 repo provider를 override하므로 실 TokenStorage 경로를 타지 않음.

- [ ] **Step 8: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/core/api frontend/lib/features/market/application/market_providers.dart frontend/test/core/api_client_token_test.dart
git commit -m "feat(auth): TokenStorage(secure storage) + dio Authorization 인터셉터"
```

---

### Task 5: 프론트 — auth 모델·repository·AuthController(providers)

**Files:**
- Create: `frontend/lib/features/auth/data/auth_models.dart`
- Create: `frontend/lib/features/auth/data/auth_repository.dart`
- Create: `frontend/lib/features/auth/application/auth_providers.dart`
- Test: `frontend/test/features/auth/auth_repository_test.dart`

- [ ] **Step 1: 실패하는 repo 테스트 작성** — `frontend/test/features/auth/auth_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/auth/data/auth_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AuthRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = AuthRepository(dio);
  });

  test('login은 provider·nickname body를 보내고 토큰+사용자를 파싱한다', () async {
    adapter.onPost(
      '/api/auth/login',
      (s) => s.reply(200, {
        'success': true,
        'data': {
          'token': 'jwt-abc',
          'user': {'id': 1, 'nickname': '개미왕', 'provider': 'kakao'},
        },
      }),
      data: {'provider': 'kakao', 'nickname': '개미왕'},
    );
    final res = await repo.login(provider: 'kakao', nickname: '개미왕');
    expect(res.token, 'jwt-abc');
    expect(res.user.id, 1);
    expect(res.user.nickname, '개미왕');
    expect(res.user.provider, 'kakao');
  });

  test('me는 사용자를 파싱한다', () async {
    adapter.onGet('/api/auth/me', (s) => s.reply(200, {
          'success': true,
          'data': {'id': 7, 'nickname': 'grow', 'provider': 'google'},
        }));
    final user = await repo.me();
    expect(user.id, 7);
    expect(user.nickname, 'grow');
  });

  test('에러 envelope는 ApiException으로 매핑된다', () async {
    adapter.onPost(
      '/api/auth/login',
      (s) => s.reply(400, {
        'success': false,
        'error': {'code': 'INVALID_LOGIN', 'eventType': 'VALIDATION_ERROR', 'message': '잘못된 로그인 요청입니다.', 'retryable': false}
      }),
      data: {'provider': 'github', 'nickname': '개미왕'},
    );
    await expectLater(
      repo.login(provider: 'github', nickname: '개미왕'),
      throwsA(isA<ApiException>()
          .having((e) => e.eventType, 'eventType', 'VALIDATION_ERROR')
          .having((e) => e.message, 'message', '잘못된 로그인 요청입니다.')
          .having((e) => e.retryable, 'retryable', false)),
    );
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd frontend && flutter test test/features/auth/auth_repository_test.dart`
Expected: 컴파일 에러(파일 미존재)

- [ ] **Step 3: 모델 생성** — `frontend/lib/features/auth/data/auth_models.dart`:

```dart
/// 로그인 사용자 — 서버 UserDto와 1:1.
class AuthUser {
  final int id;
  final String nickname;
  final String provider;
  const AuthUser({required this.id, required this.nickname, required this.provider});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] as num).toInt(),
        nickname: j['nickname'] as String,
        provider: j['provider'] as String,
      );
}

/// POST /api/auth/login 응답 — 토큰 + 사용자.
class AuthResponse {
  final String token;
  final AuthUser user;
  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['token'] as String,
        user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}
```

- [ ] **Step 4: repository 생성** — `frontend/lib/features/auth/data/auth_repository.dart`:

```dart
import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'auth_models.dart';

class AuthRepository {
  final Dio _dio;
  const AuthRepository(this._dio);

  Future<AuthResponse> login({required String provider, required String nickname}) async {
    try {
      final res = await _dio
          .post('/api/auth/login', data: {'provider': provider, 'nickname': nickname});
      return AuthResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }

  Future<AuthUser> me() async {
    try {
      final res = await _dio.get('/api/auth/me');
      return AuthUser.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }
}
```

- [ ] **Step 5: providers 생성** — `frontend/lib/features/auth/application/auth_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/token_storage.dart';
import '../../market/application/market_providers.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));

/// 로그인 상태의 단일 소유자 — null이면 비로그인. AuthGate가 watch해 첫 화면을 결정한다.
class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final storage = ref.watch(tokenStorageProvider);
    final token = await storage.read();
    if (token == null) return null;
    try {
      return await ref.read(authRepositoryProvider).me();
    } on ApiException {
      await storage.clear(); // 만료·무효 토큰 정리 → 로그인 화면으로
      return null;
    }
  }

  /// 성공 시 토큰 저장 + 상태 전환. 실패(ApiException)는 호출부(시트)가 스낵바로 처리 — 상태는 건드리지 않는다.
  Future<void> login(String provider, String nickname) async {
    final res =
        await ref.read(authRepositoryProvider).login(provider: provider, nickname: nickname);
    await ref.read(tokenStorageProvider).save(res.token);
    state = AsyncValue.data(res.user);
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
```

- [ ] **Step 6: 검증**

Run: `cd frontend && flutter test test/features/auth/auth_repository_test.dart`
Expected: 3 tests 통과

Run: `cd frontend && flutter analyze && flutter test`
Expected: No issues found! / 38 tests 통과(35+3)

- [ ] **Step 7: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/auth frontend/test/features/auth
git commit -m "feat(auth): AuthUser 모델·repository·AuthController — 로그인 상태 단일 소유"
```

---

### Task 6: 프론트 — AuthGate + main.dart + LoginScreen 닉네임 시트

**Files:**
- Create: `frontend/lib/app/auth_gate.dart`
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/features/auth/login_screen.dart`
- Test: `frontend/test/features/auth/auth_gate_test.dart`
- Test: `frontend/test/features/auth/login_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 2파일 작성**

`frontend/test/features/auth/auth_gate_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/app/app_shell.dart';
import 'package:growant/app/auth_gate.dart';
import 'package:growant/core/api/token_storage.dart';
import 'package:growant/features/auth/data/auth_models.dart';
import 'package:growant/features/auth/data/auth_repository.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/login_screen.dart';

class _FakeStorage implements TokenStorage {
  String? token;
  _FakeStorage(this.token);
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

class _FakeAuthRepo implements AuthRepository {
  final AuthUser? user; // null이면 me가 401 ApiException을 던지는 시나리오
  _FakeAuthRepo({this.user});

  @override
  Future<AuthUser> me() async {
    final u = user;
    if (u == null) {
      throw const ApiException(
          eventType: 'AUTH_ERROR',
          code: 'UNAUTHENTICATED',
          message: '로그인이 필요합니다.',
          retryable: false);
    }
    return u;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap({required TokenStorage storage, AuthRepository? repo}) => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        if (repo != null) authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: AuthGate()),
    );

void main() {
  testWidgets('토큰이 없으면 LoginScreen을 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(storage: _FakeStorage(null)));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });

  testWidgets('토큰이 있고 me가 성공하면 AppShell을 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(
      storage: _FakeStorage('jwt-abc'),
      repo: _FakeAuthRepo(user: const AuthUser(id: 1, nickname: '개미왕', provider: 'kakao')),
    ));
    await tester.pump(); // build future resolve
    await tester.pump();
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('부트스트랩 중에는 스피너를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(storage: _FakeStorage(null)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // 보류 future 정리
  });
}
```

(위 `_FakeAuthRepo`의 `ApiException` 사용을 위해 import 목록에 `import 'package:growant/core/api/api_exception.dart';` 한 줄을 추가한다.)

`frontend/test/features/auth/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/core/api/token_storage.dart';
import 'package:growant/features/auth/data/auth_models.dart';
import 'package:growant/features/auth/data/auth_repository.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/login_screen.dart';

class _FakeStorage implements TokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

class _FakeAuthRepo implements AuthRepository {
  final Object? error;
  ({String provider, String nickname})? last;
  _FakeAuthRepo({this.error});

  @override
  Future<AuthResponse> login({required String provider, required String nickname}) async {
    last = (provider: provider, nickname: nickname);
    if (error != null) throw error!;
    return AuthResponse(
        token: 'jwt-1', user: AuthUser(id: 1, nickname: nickname, provider: provider));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakeStorage storage;

  Widget wrap(_FakeAuthRepo repo) {
    storage = _FakeStorage();
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  testWidgets('소셜 버튼 → 닉네임 시트 → 로그인 호출·토큰 저장·시트 닫힘', (tester) async {
    final repo = _FakeAuthRepo();
    await tester.pumpWidget(wrap(repo));
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('카카오 데모 로그인'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '개미왕');
    await tester.tap(find.widgetWithText(FilledButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(repo.last, (provider: 'kakao', nickname: '개미왕'));
    expect(storage.token, 'jwt-1');
    expect(find.text('카카오 데모 로그인'), findsNothing); // 시트 닫힘
  });

  testWidgets('로그인 실패 - 에러 스낵바, 시트 유지', (tester) async {
    final repo = _FakeAuthRepo(
      error: const ApiException(
          eventType: 'VALIDATION_ERROR', code: 'INVALID_LOGIN', message: '잘못된 로그인 요청입니다.', retryable: false),
    );
    await tester.pumpWidget(wrap(repo));
    await tester.tap(find.text('Google로 시작하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '개미왕');
    await tester.tap(find.widgetWithText(FilledButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('잘못된 로그인 요청입니다.'), findsOneWidget);
    expect(find.text('Google 데모 로그인'), findsOneWidget); // 시트 유지
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd frontend && flutter test test/features/auth/`
Expected: auth_gate_test·login_screen_test 컴파일 에러(AuthGate 미존재, 시트 미구현)

- [ ] **Step 3: AuthGate 생성** — `frontend/lib/app/auth_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/login_screen.dart';
import 'app_shell.dart';

/// 로그인 상태가 첫 화면을 결정 — 부트스트랩(저장 토큰 → me) 동안 스플래시. 스펙 §4.5
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(authControllerProvider);
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const LoginScreen(), // 부트스트랩 예외는 비로그인 취급
      data: (user) => user == null ? const LoginScreen() : const AppShell(),
    );
  }
}
```

- [ ] **Step 4: main.dart 수정** — `frontend/lib/main.dart`에서

```dart
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
```

를 다음으로 교체:

```dart
import 'app/auth_gate.dart';
import 'core/theme.dart';
```

그리고

```dart
      home: const LoginScreen(),
```

를 다음으로 교체:

```dart
      home: const AuthGate(),
```

- [ ] **Step 5: LoginScreen 개편** — `frontend/lib/features/auth/login_screen.dart`에서 (a) 파일 상단 imports를 다음으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import 'application/auth_providers.dart';
```

(`app_shell.dart` import 제거 — 수동 네비게이션 폐기.)

(b) `class LoginScreen ...`의 `_onLogin` 메서드와 4개 버튼 `onTap`을 교체 — `LoginScreen` 클래스 전체를 다음으로 교체(`_Logo`·`_SocialButton` 클래스는 무수정 유지):

```dart
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _startLogin(BuildContext context, String provider, String label) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NicknameSheet(provider: provider, providerLabel: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const _Logo(),
              const Spacer(),
              _SocialButton(
                label: '카카오로 시작하기',
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: const Color(0xFF191919),
                onTap: () => _startLogin(context, 'kakao', '카카오'),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: '네이버로 시작하기',
                backgroundColor: const Color(0xFF03C75A),
                foregroundColor: Colors.white,
                onTap: () => _startLogin(context, 'naver', '네이버'),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: 'Apple로 시작하기',
                backgroundColor: const Color(0xFF000000),
                foregroundColor: Colors.white,
                onTap: () => _startLogin(context, 'apple', 'Apple'),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: 'Google로 시작하기',
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: const Color(0xFF111111),
                onTap: () => _startLogin(context, 'google', 'Google'),
                border: Border.all(color: const Color(0xFFCCCCCC)),
              ),
              const SizedBox(height: 48),
              Text(
                '로그인하면 이용약관 및 개인정보처리방침에 동의하는 것으로 간주됩니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF999999),
                    ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// 데모 로그인 닉네임 시트 — 성공 시 pop(AuthGate가 AppShell로 전환), 실패 시 스낵바+시트 유지.
class _NicknameSheet extends ConsumerStatefulWidget {
  final String provider;
  final String providerLabel;
  const _NicknameSheet({required this.provider, required this.providerLabel});

  @override
  ConsumerState<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends ConsumerState<_NicknameSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).login(widget.provider, nickname);
      if (mounted) navigator.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.providerLabel} 데모 로그인',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('닉네임만 입력하면 시작됩니다 (비밀번호 없음).',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLength: 20,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: '닉네임', border: OutlineInputBorder(), counterText: ''),
            onSubmitted: (_) => _submitting ? null : _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('시작하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 검증**

Run: `cd frontend && flutter test test/features/auth/`
Expected: 8 tests 통과(repo 3 + gate 3 + login 2)

Run: `cd frontend && flutter analyze && flutter test`
Expected: No issues found! / 43 tests 통과(38+5)

(auth_gate_test의 AppShell 케이스에서 홈 위젯들이 실 API 호출을 시도하지만, flutter_test의 기본 HttpOverrides가 모든 HTTP를 즉시 400으로 끊어 인라인 에러 카드로 렌더된다 — `find.byType(AppShell)` 단언에는 영향 없음. **pumpAndSettle은 쓰지 말 것** — 홈 카드 스피너가 무한 애니메이션이라 hang한다. `pump()` 2회로 충분.)

- [ ] **Step 7: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/app/auth_gate.dart frontend/lib/main.dart frontend/lib/features/auth/login_screen.dart frontend/test/features/auth
git commit -m "feat(auth): AuthGate 자동 로그인 + 닉네임 시트 데모 로그인 — 수동 네비게이션 제거"
```

---

### Task 7: 프론트 — 프로필 실연동(계정탭·홈) + 로그아웃 + mock 제거 + 전체 검증

**Files:**
- Modify: `frontend/lib/features/account/account_screen.dart`
- Modify: `frontend/lib/features/home/widgets/asset_card.dart`
- Modify: `frontend/lib/data/mock/mock_data.dart`
- Modify: `frontend/test/features/home/asset_card_test.dart` (auth override 추가)
- Test: `frontend/test/features/account/account_screen_test.dart` (신규)

- [ ] **Step 1: 실패하는 계정탭 테스트 작성** — `frontend/test/features/account/account_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/features/account/account_screen.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/data/auth_models.dart';

class _FakeAuth extends AuthController {
  final AuthUser? user;
  bool loggedOut = false;
  _FakeAuth(this.user);

  @override
  Future<AuthUser?> build() async => user;

  @override
  Future<void> logout() async {
    loggedOut = true;
    state = const AsyncValue.data(null);
  }
}

Widget _wrap(_FakeAuth fake) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: Scaffold(body: AccountScreen())),
    );

void main() {
  testWidgets('로그인 사용자의 닉네임과 provider 라벨을 표시한다', (tester) async {
    final fake = _FakeAuth(const AuthUser(id: 1, nickname: '개미왕', provider: 'kakao'));
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();
    expect(find.text('개미왕'), findsOneWidget);
    expect(find.text('카카오 로그인'), findsOneWidget);
  });

  testWidgets('로그아웃 탭 시 logout이 호출된다', (tester) async {
    final fake = _FakeAuth(const AuthUser(id: 1, nickname: '개미왕', provider: 'google'));
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();
    await tester.ensureVisible(find.text('로그아웃'));
    await tester.tap(find.text('로그아웃'));
    await tester.pump();
    expect(fake.loggedOut, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd frontend && flutter test test/features/account/account_screen_test.dart`
Expected: FAIL('개미왕' 미발견 — 현재는 mockUserName '민지성' 표시, 로그아웃 onTap 빈 클로저)

- [ ] **Step 3: account_screen.dart 수정** — (a) 상단을 다음으로 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/mock/mock_data.dart';
import '../auth/application/auth_providers.dart';
import '../subscription/subscription_screen.dart';
import '../exchange/exchange_screen.dart';
import '../trading/dividend_screen.dart';

/// provider id → 사용자 노출 라벨. AuthGate 뒤에서는 user가 항상 있지만 위젯 단독 사용 대비 null 허용.
String providerLoginLabel(String? provider) => switch (provider) {
      'kakao' => '카카오 로그인',
      'naver' => '네이버 로그인',
      'apple' => 'Apple 로그인',
      'google' => 'Google 로그인',
      _ => '데모 계정',
    };

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,###');
    final user = ref.watch(authControllerProvider).value;
    final nickname = user?.nickname ?? '투자자';
    final totalReturn =
        (mockTotalAsset - mockSeed) / mockSeed * 100;
```

(b) 사용자 헤더의 아바타·이름·이메일 3곳 교체:

```dart
              child: Text(
                mockUserName[0],
```

→

```dart
              child: Text(
                nickname[0],
```

그리고

```dart
                Text(mockUserName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(mockUserEmail,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13)),
```

→

```dart
                Text(nickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(providerLoginLabel(user?.provider),
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13)),
```

(c) 로그아웃 메뉴 교체:

```dart
        _MenuItem(
          icon: Icons.logout,
          label: '로그아웃',
          onTap: () {},
        ),
```

→

```dart
        _MenuItem(
          icon: Icons.logout,
          label: '로그아웃',
          onTap: () => ref.read(authControllerProvider.notifier).logout(),
        ),
```

(자산 요약·보유 종목의 `mockTotalAsset`/`mockStockValue`/`mockCash`/`mockHoldings`/`mockUserTier`는 범위 외 — 무수정 유지.)

- [ ] **Step 4: asset_card.dart 수정** — (a) import 추가(`account_providers` import 아래):

```dart
import '../../auth/application/auth_providers.dart';
```

(b) 클래스 주석과 이름 Row 교체:

```dart
/// 홈 자산 요약 카드 — accountSummaryProvider(GET /api/account/summary).
/// 프로필(이름·티어)은 auth 도메인이라 mock 유지. 로딩/에러는 컴팩트 인라인.
```

→

```dart
/// 홈 자산 요약 카드 — accountSummaryProvider(GET /api/account/summary).
/// 이름은 로그인 사용자(authControllerProvider), 티어는 요금제 도메인이라 mock 유지. 로딩/에러는 컴팩트 인라인.
```

그리고

```dart
              Text(mockUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
```

→

```dart
              Text(ref.watch(authControllerProvider).value?.nickname ?? '투자자',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
```

- [ ] **Step 5: mock 제거** — `frontend/lib/data/mock/mock_data.dart`에서

```dart
// ── 사용자 프로필 ──
const String mockUserName = '민지성';
const String mockUserTier = 'Standard'; // Free / Standard / Premium
const String mockUserEmail = 'gsmin5202@gmail.com';
```

를 다음으로 교체:

```dart
// ── 사용자 프로필 ──
// 이름·이메일은 auth 슬라이스에서 로그인 사용자로 대체됨. tier는 요금제 슬라이스에서 이전 예정.
const String mockUserTier = 'Standard'; // Free / Standard / Premium
```

- [ ] **Step 6: asset_card_test 보정** — `frontend/test/features/home/asset_card_test.dart`를 읽고:
  (a) 파일 상단에 import 2줄 추가:

```dart
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/data/auth_models.dart';
```

  (b) 파일에 fake 클래스 추가(기존 fake들 옆):

```dart
class _FakeAuth extends AuthController {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 1, nickname: '개미왕', provider: 'kakao');
}
```

  (c) 테스트 헬퍼의 `ProviderScope(overrides: [...])` 목록(모든 케이스가 공유하는 wrap 함수)에 한 줄 추가:

```dart
        authControllerProvider.overrideWith(() => _FakeAuth()),
```

  (d) 데이터 성공 케이스에 단언 1줄 추가(기존 자산 단언 옆):

```dart
    expect(find.text('개미왕'), findsOneWidget);
```

  (만약 기존 테스트가 `'민지성'`(mockUserName)을 단언하고 있으면 그 단언을 위 줄로 교체한다.)

- [ ] **Step 7: 전체 검증**

Run: `cd frontend && grep -rn "mockUserName\|mockUserEmail" lib/ test/ || echo CLEAN`
Expected: `CLEAN`

Run: `cd frontend && flutter analyze`
Expected: No issues found!

Run: `cd frontend && flutter test`
Expected: 45 tests 통과(43 + 계정탭 2)

Run: `cd backend && ./gradlew test`
Expected: BUILD SUCCESSFUL — 29 tests

- [ ] **Step 8: Commit**

```bash
cd /Users/gsmin/GrowAnt && git add frontend/lib/features/account/account_screen.dart frontend/lib/features/home/widgets/asset_card.dart frontend/lib/data/mock/mock_data.dart frontend/test/features/account frontend/test/features/home/asset_card_test.dart
git commit -m "feat(auth): 프로필 실연동(계정탭·홈 닉네임) + 로그아웃 — mockUserName·mockUserEmail 제거"
```

---

## 완료 후

1. push + PR 생성(`gh pr create`) — base `main`, head `feat/auth-slice`. **병합하지 않고 OPEN 유지**(사용자 검토).
2. PR 본문에 알려진 한계 기재(스펙 §8): 닉네임=신원(비밀번호 없음) / 토큰 24h 만료 시 자동 갱신 없음 / UserStore 휘발 / 거래 상태 단일 공유.
3. 수동 확인 안내(검토자용): 백엔드 기동 → 앱 실행 → 로그인 → 홈/계정탭 닉네임 → 로그아웃 → 재로그인 → 앱 재시작 시 자동 로그인.
