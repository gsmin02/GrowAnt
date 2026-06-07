# 마켓 REST 수직 슬라이스 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 Mock UI(마켓 대시보드·종목 상세)를 Spring Boot REST(`GET /api/market`, `GET /api/market/{ticker}`)에 연결하고, 이후 모든 기능이 복제할 프론트 표준 데이터 패턴(dio + Riverpod + repository + DTO + ErrorView)을 확립한다.

**Architecture:** 백엔드는 `com.growant.market`에 Controller→Service(결정적 카탈로그 스냅샷)→DTO를 추가하고 기존 `ApiResponse`/`ErrorCode`/`GlobalExceptionHandler`를 재사용한다(`MarketDataProvider` 포트·sim 미변경 — 실시간 슬라이스 몫). 프론트는 dio 에러 인터셉터가 envelope를 언랩해 `ApiException`으로 변환하고, repository→Riverpod provider→화면이 `AsyncValue.when`으로 바인딩한다. 에러 표시는 서버 envelope(message·retryable)를 권위로 쓰고 클라는 아이콘/제목 프리셋만 매핑한다.

**Tech Stack:** Backend = Spring Boot 4.0 / Kotlin 2.1 / JDK 21 (spring-web, security, jackson-kotlin; 전부 classpath). Frontend = Flutter (Dart ^3.5) + `flutter_riverpod ^2.5` + `dio ^5.4` (dev: `http_mock_adapter`).

**스펙:** `docs/superpowers/specs/2026-06-07-market-rest-slice-design.md` (결정 C1/C2/C4 + 에러 계약). 코드 앵커: `grep -rn "market-slice"`.

---

## File Structure

**Backend (신규)**
- `backend/src/main/kotlin/com/growant/market/dto/MarketRowDto.kt` — 목록 행 DTO
- `backend/src/main/kotlin/com/growant/market/dto/StockDetailDto.kt` — 상세 DTO(캔들+펀더멘털)
- `backend/src/main/kotlin/com/growant/market/MarketService.kt` — 결정적 카탈로그 + 캔들/펀더멘털 합성
- `backend/src/main/kotlin/com/growant/market/MarketController.kt` — `/api/market` 엔드포인트
- `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt` — `/api/market/**` permit
- `backend/src/main/resources/application-local.yml` — DataSource/JPA/Redis 오토컨피그 제외(Supabase 없이 부팅)
- `backend/src/test/kotlin/com/growant/market/MarketServiceTest.kt`
- `backend/src/test/kotlin/com/growant/market/MarketControllerTest.kt`

**Frontend (신규)**
- `frontend/lib/core/api/api_exception.dart`
- `frontend/lib/core/api/api_client.dart` — Dio + envelope 언랩 인터셉터
- `frontend/lib/core/error/error_view.dart` — Scaffold 없는 에러 본문 + `errorTypeFromEventType`
- `frontend/lib/features/market/data/market_models.dart` — `MarketRow`, `StockDetail`
- `frontend/lib/features/market/data/market_repository.dart`
- `frontend/lib/features/market/application/market_providers.dart`
- `frontend/test/features/market/market_repository_test.dart`
- `frontend/test/features/market/market_providers_test.dart`
- `frontend/test/features/market/market_dashboard_test.dart`

**Frontend (수정)**
- `frontend/pubspec.yaml` — deps 추가
- `frontend/lib/main.dart` — `ProviderScope`
- `frontend/lib/features/error/error_screen.dart` — `serviceUnavailable` 추가 + `ErrorView` 위임
- `frontend/lib/features/market/market_dashboard_screen.dart` — `ConsumerStatefulWidget` + provider 바인딩
- `frontend/lib/features/market/stock_detail_screen.dart` — `ticker` 기반 + provider + `detail.candles`

> 데이터 흐름 일관성을 위해 **백엔드(B1–B4) 먼저** 구현해 JSON 계약을 고정한 뒤 프론트(F1–F8)를 붙인다.

---

## Task B1: SecurityConfig + 로컬 부팅 프로파일

**Files:**
- Create: `backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt`
- Create: `backend/src/main/resources/application-local.yml`

- [ ] **Step 1: SecurityConfig 작성** (security starter가 classpath라 없으면 모든 엔드포인트 401)

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
class SecurityConfig {
    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        http
            .csrf { it.disable() }
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .authorizeHttpRequests {
                it.requestMatchers("/api/market/**").permitAll()
                it.anyRequest().authenticated()
            }
        return http.build()
    }
}
```

- [ ] **Step 2: 로컬 부팅 프로파일 작성** (마켓 슬라이스는 DB/Redis 불필요 — Supabase 없이 기동)

```yaml
# backend/src/main/resources/application-local.yml
# 마켓 REST 슬라이스 로컬 구동용: DB/Redis 오토컨피그 제외(Supabase 불필요). 영속성 기능 슬라이스에서 정비.
spring:
  autoconfigure:
    exclude:
      - org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration
      - org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration
      - org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration
      - org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration
```

- [ ] **Step 3: 부팅 확인**

Run: `cd backend && ./gradlew bootRun --args='--spring.profiles.active=local'`
Expected: 컨텍스트 기동 성공(Started GrowantApplication), 8080 리슨. (Ctrl+C로 종료. B4 후 실제 엔드포인트 확인.)

- [ ] **Step 4: Commit**

```bash
git add backend/src/main/kotlin/com/growant/common/config/SecurityConfig.kt backend/src/main/resources/application-local.yml
git commit -m "feat(market): add SecurityConfig + local boot profile (no Supabase)"
```

---

## Task B2: 응답 DTO

**Files:**
- Create: `backend/src/main/kotlin/com/growant/market/dto/MarketRowDto.kt`
- Create: `backend/src/main/kotlin/com/growant/market/dto/StockDetailDto.kt`

- [ ] **Step 1: DTO 작성** (가격은 Int(원) — `Stock.price=Int`/sim scale-0과 일치)

```kotlin
// MarketRowDto.kt
package com.growant.market.dto

data class MarketRowDto(
    val ticker: String,
    val name: String,
    val price: Int,
    val changeRate: Double,
)
```

```kotlin
// StockDetailDto.kt
package com.growant.market.dto

data class StockDetailDto(
    val ticker: String,
    val name: String,
    val price: Int,
    val changeRate: Double,
    val candles: List<Int>, // [0]=최근 ... [9]=오래된 (프론트 _MiniChart가 reversed 처리)
    val high52w: Int,
    val low52w: Int,
    val volume: Long,
    val marketCapEok: Long,
    val per: Double,
    val pbr: Double,
)
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/main/kotlin/com/growant/market/dto/
git commit -m "feat(market): add market DTOs"
```

---

## Task B3: MarketService (결정적 카탈로그·캔들·펀더멘털)

**Files:**
- Create: `backend/src/main/kotlin/com/growant/market/MarketService.kt`
- Test: `backend/src/test/kotlin/com/growant/market/MarketServiceTest.kt`

- [ ] **Step 1: 실패 테스트 작성**

```kotlin
package com.growant.market

import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class MarketServiceTest {
    private val service = MarketService()

    @Test
    fun `getMarket returns 8 catalog rows starting with Samsung`() {
        val rows = service.getMarket()
        assertThat(rows).hasSize(8)
        assertThat(rows.first().ticker).isEqualTo("005930")
        assertThat(rows.first().name).isEqualTo("삼성전자")
        assertThat(rows.first().price).isEqualTo(76300)
    }

    @Test
    fun `getDetail returns deterministic 10-point candles ending(recent) at price`() {
        val a = service.getDetail("005930")
        val b = service.getDetail("005930")
        assertThat(a.candles).hasSize(10)
        assertThat(a.candles.first()).isEqualTo(76300) // [0]=최근=현재가
        assertThat(a.candles).isEqualTo(b.candles)     // 결정적(동일)
        assertThat(a.high52w).isEqualTo(90034)         // 76300*1.18 반올림
        assertThat(a.low52w).isEqualTo(54936)          // 76300*0.72 반올림
    }

    @Test
    fun `getDetail throws INVALID_TICKER for unknown ticker`() {
        assertThatThrownBy { service.getDetail("999999") }
            .isInstanceOf(BusinessException::class.java)
            .satisfies({ assertThat((it as BusinessException).code).isEqualTo(ErrorCode.INVALID_TICKER) })
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd backend && ./gradlew test --tests com.growant.market.MarketServiceTest`
Expected: 컴파일 실패(MarketService 미존재).

- [ ] **Step 3: MarketService 구현**

```kotlin
package com.growant.market

import com.growant.common.error.BusinessException
import com.growant.common.error.ErrorCode
import com.growant.market.dto.MarketRowDto
import com.growant.market.dto.StockDetailDto
import org.springframework.stereotype.Service
import kotlin.math.roundToInt
import kotlin.random.Random

@Service
class MarketService {
    // 결정적 스냅샷 카탈로그(현 Flutter mock과 동일). sim random-walk 미사용(스펙 C4).
    private val catalog: Map<String, MarketRowDto> = listOf(
        MarketRowDto("005930", "삼성전자", 76300, 5.97),
        MarketRowDto("000660", "SK하이닉스", 178500, 3.41),
        MarketRowDto("035720", "카카오", 41200, -2.10),
        MarketRowDto("035420", "NAVER", 198400, 1.55),
        MarketRowDto("005380", "현대차", 247000, -0.81),
        MarketRowDto("000270", "기아", 109500, 0.37),
        MarketRowDto("068270", "셀트리온", 187000, -1.24),
        MarketRowDto("051910", "LG화학", 278000, 2.08),
    ).associateBy { it.ticker }

    fun getMarket(): List<MarketRowDto> = catalog.values.toList()

    fun getDetail(ticker: String): StockDetailDto {
        val row = catalog[ticker] ?: throw BusinessException(ErrorCode.INVALID_TICKER)
        return StockDetailDto(
            ticker = row.ticker,
            name = row.name,
            price = row.price,
            changeRate = row.changeRate,
            candles = candles(row.ticker, row.price),
            high52w = (row.price * 1.18).roundToInt(),
            low52w = (row.price * 0.72).roundToInt(),
            volume = 14_823_410L,
            marketCapEok = row.price.toLong() * 5_969_783_300L / 1_000_000L,
            per = 12.4,
            pbr = 1.2,
        )
    }

    // 종목별 결정적 10포인트. [0]=최근(=현재가), 뒤로 갈수록 과거. 시드=ticker 해시.
    private fun candles(ticker: String, price: Int): List<Int> {
        val rnd = Random(ticker.hashCode())
        val out = mutableListOf(price)
        var p = price
        repeat(9) {
            val delta = (p * rnd.nextDouble(-0.02, 0.02)).toInt()
            p = (p - delta).coerceAtLeast(1)
            out.add(p)
        }
        return out
    }
}
```

> 참고: `MARKET_DATA_UNAVAILABLE`는 실데이터 제공자 실패용으로 예약(이 결정적 슬라이스에선 트리거 경로 없음). 예기치 못한 예외는 `GlobalExceptionHandler`가 500으로 처리.

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd backend && ./gradlew test --tests com.growant.market.MarketServiceTest`
Expected: PASS (3 tests). high52w/low52w 기대값이 다르면 실제 `roundToInt()` 결과로 맞춘다.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/kotlin/com/growant/market/MarketService.kt backend/src/test/kotlin/com/growant/market/MarketServiceTest.kt
git commit -m "feat(market): add MarketService with deterministic snapshot catalog"
```

---

## Task B4: MarketController (+ @WebMvcTest)

**Files:**
- Create: `backend/src/main/kotlin/com/growant/market/MarketController.kt`
- Test: `backend/src/test/kotlin/com/growant/market/MarketControllerTest.kt`

- [ ] **Step 1: 실패 테스트 작성** (`@WebMvcTest`로 풀 컨텍스트 회피 → DataSource/Redis 안 띄움. SecurityConfig는 `@Import`로 permit 적용)

```kotlin
package com.growant.market

import com.growant.common.config.SecurityConfig
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

@WebMvcTest(MarketController::class)
@Import(SecurityConfig::class, MarketService::class)
class MarketControllerTest(@Autowired val mockMvc: MockMvc) {

    @Test
    fun `GET market returns success envelope with 8 rows`() {
        mockMvc.get("/api/market")
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.success") { value(true) } }
            .andExpect { jsonPath("$.data.length()") { value(8) } }
            .andExpect { jsonPath("$.data[0].ticker") { value("005930") } }
    }

    @Test
    fun `GET market detail returns candles and fundamentals`() {
        mockMvc.get("/api/market/005930")
            .andExpect { status { isOk() } }
            .andExpect { jsonPath("$.data.candles.length()") { value(10) } }
            .andExpect { jsonPath("$.data.per") { value(12.4) } }
    }

    @Test
    fun `GET market detail unknown ticker returns INVALID_TICKER 400`() {
        mockMvc.get("/api/market/999999")
            .andExpect { status { isBadRequest() } }
            .andExpect { jsonPath("$.success") { value(false) } }
            .andExpect { jsonPath("$.error.code") { value("INVALID_TICKER") } }
            .andExpect { jsonPath("$.error.eventType") { value("VALIDATION_ERROR") } }
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd backend && ./gradlew test --tests com.growant.market.MarketControllerTest`
Expected: 컴파일 실패(MarketController 미존재).

- [ ] **Step 3: MarketController 구현**

```kotlin
package com.growant.market

import com.growant.common.web.ApiResponse
import com.growant.market.dto.MarketRowDto
import com.growant.market.dto.StockDetailDto
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/market")
class MarketController(private val service: MarketService) {

    @GetMapping
    fun list(): ApiResponse<List<MarketRowDto>> = ApiResponse.ok(service.getMarket())

    @GetMapping("/{ticker}")
    fun detail(@PathVariable ticker: String): ApiResponse<StockDetailDto> =
        ApiResponse.ok(service.getDetail(ticker))
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd backend && ./gradlew test --tests com.growant.market.MarketControllerTest`
Expected: PASS (3 tests). 401이 나오면 `@Import(SecurityConfig::class)` 누락 확인.

- [ ] **Step 5: 엔드포인트 수동 확인**

Run: `cd backend && ./gradlew bootRun --args='--spring.profiles.active=local'` 후 별 터미널에서 `curl -s localhost:8080/api/market | head` / `curl -s -o /dev/null -w "%{http_code}" localhost:8080/api/market/999999` (→ 400).

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/kotlin/com/growant/market/MarketController.kt backend/src/test/kotlin/com/growant/market/MarketControllerTest.kt
git commit -m "feat(market): add MarketController GET /api/market(+/{ticker})"
```

---

## Task F1: 프론트 의존성 + ProviderScope

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/main.dart`

- [ ] **Step 1: deps 추가** (`pubspec.yaml`의 `intl: ^0.19.0` 줄 + 앵커 주석을 아래로 교체)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  intl: ^0.19.0
  flutter_riverpod: ^2.5.1
  dio: ^5.4.3+1

dev_dependencies:
  flutter_lints: ^4.0.0
  http_mock_adapter: ^0.6.1
```

Run: `cd frontend && flutter pub get`
Expected: 의존성 해결 성공.

- [ ] **Step 2: ProviderScope 적용** (`main.dart`의 앵커 주석 + `void main()` 줄 교체)

```dart
void main() => runApp(const ProviderScope(child: GrowAntApp()));
```

상단 import 추가:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

- [ ] **Step 3: analyze**

Run: `cd frontend && flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/main.dart
git commit -m "feat(market): add riverpod+dio deps and ProviderScope"
```

---

## Task F2: ApiException + ApiClient(에러 인터셉터)

**Files:**
- Create: `frontend/lib/core/api/api_exception.dart`
- Create: `frontend/lib/core/api/api_client.dart`

- [ ] **Step 1: ApiException 작성**

```dart
// api_exception.dart
class ApiException implements Exception {
  final String eventType; // 서버 eventType 또는 클라 'NETWORK'
  final String code;
  final String message; // 사용자 노출(서버 envelope 권위)
  final bool retryable;
  const ApiException({
    required this.eventType,
    required this.code,
    required this.message,
    required this.retryable,
  });

  @override
  String toString() => 'ApiException($code/$eventType: $message)';
}
```

- [ ] **Step 2: ApiClient 작성** (성공 envelope→data 언랩, 실패 envelope/연결오류→ApiException)

```dart
// api_client.dart
import 'package:dio/dio.dart';
import 'api_exception.dart';

/// 개발용 baseUrl. iOS 시뮬레이터=localhost, Android 에뮬레이터=10.0.2.2 (스펙 §8).
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

Dio createApiClient({String baseUrl = kApiBaseUrl}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onResponse: (response, handler) {
      final data = response.data;
      if (data is Map && data['success'] == true) {
        handler.resolve(Response(
          requestOptions: response.requestOptions,
          statusCode: response.statusCode,
          data: data['data'],
        ));
      } else {
        handler.reject(_toDioError(response.requestOptions, data, response));
      }
    },
    onError: (err, handler) {
      handler.reject(_toDioError(err.requestOptions, err.response?.data, err.response, err));
    },
  ));
  return dio;
}

DioException _toDioError(RequestOptions req, dynamic data, Response? res, [DioException? src]) {
  if (data is Map && data['success'] == false && data['error'] is Map) {
    final e = data['error'] as Map;
    return DioException(
      requestOptions: req,
      response: res,
      error: ApiException(
        eventType: (e['eventType'] ?? 'SYSTEM_ERROR').toString(),
        code: (e['code'] ?? 'UNKNOWN').toString(),
        message: (e['message'] ?? '오류가 발생했습니다.').toString(),
        retryable: e['retryable'] == true,
      ),
    );
  }
  return DioException(
    requestOptions: req,
    response: res,
    error: const ApiException(
      eventType: 'NETWORK',
      code: 'ERR_NETWORK',
      message: '인터넷 연결을 확인해주세요.',
      retryable: true,
    ),
  );
}
```

- [ ] **Step 3: analyze + Commit**

Run: `cd frontend && flutter analyze` → No issues.
```bash
git add frontend/lib/core/api/
git commit -m "feat(market): add Dio api client with envelope-unwrapping error interceptor"
```

---

## Task F3: 모델 (MarketRow, StockDetail)

**Files:**
- Create: `frontend/lib/features/market/data/market_models.dart`

- [ ] **Step 1: 모델 작성** (수동 fromJson, codegen 없음 — DTO 필드명과 1:1)

```dart
// market_models.dart
class MarketRow {
  final String ticker;
  final String name;
  final int price;
  final double changeRate;
  const MarketRow({required this.ticker, required this.name, required this.price, required this.changeRate});

  factory MarketRow.fromJson(Map<String, dynamic> j) => MarketRow(
        ticker: j['ticker'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        changeRate: (j['changeRate'] as num).toDouble(),
      );
}

class StockDetail {
  final String ticker;
  final String name;
  final int price;
  final double changeRate;
  final List<int> candles;
  final int high52w;
  final int low52w;
  final int volume;
  final int marketCapEok;
  final double per;
  final double pbr;
  const StockDetail({
    required this.ticker, required this.name, required this.price, required this.changeRate,
    required this.candles, required this.high52w, required this.low52w,
    required this.volume, required this.marketCapEok, required this.per, required this.pbr,
  });

  factory StockDetail.fromJson(Map<String, dynamic> j) => StockDetail(
        ticker: j['ticker'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        changeRate: (j['changeRate'] as num).toDouble(),
        candles: (j['candles'] as List).map((e) => (e as num).toInt()).toList(),
        high52w: (j['high52w'] as num).toInt(),
        low52w: (j['low52w'] as num).toInt(),
        volume: (j['volume'] as num).toInt(),
        marketCapEok: (j['marketCapEok'] as num).toInt(),
        per: (j['per'] as num).toDouble(),
        pbr: (j['pbr'] as num).toDouble(),
      );
}
```

- [ ] **Step 2: analyze + Commit**

```bash
git add frontend/lib/features/market/data/market_models.dart
git commit -m "feat(market): add MarketRow/StockDetail models"
```

---

## Task F4: Repository (+ MockAdapter 테스트)

**Files:**
- Create: `frontend/lib/features/market/data/market_repository.dart`
- Test: `frontend/test/features/market/market_repository_test.dart`

- [ ] **Step 1: 실패 테스트 작성**

```dart
// market_repository_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/market/data/market_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late MarketRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = MarketRepository(dio);
  });

  test('fetchMarket unwraps envelope into rows', () async {
    adapter.onGet('/api/market', (s) => s.reply(200, {
          'success': true,
          'data': [
            {'ticker': '005930', 'name': '삼성전자', 'price': 76300, 'changeRate': 5.97}
          ],
        }));
    final rows = await repo.fetchMarket();
    expect(rows, hasLength(1));
    expect(rows.first.ticker, '005930');
  });

  test('fetchDetail on error envelope throws mapped ApiException', () async {
    adapter.onGet('/api/market/999999', (s) => s.reply(400, {
          'success': false,
          'error': {'code': 'INVALID_TICKER', 'eventType': 'VALIDATION_ERROR', 'message': '존재하지 않는 종목입니다.', 'retryable': false}
        }));
    expect(
      () => repo.fetchDetail('999999'),
      throwsA(isA<ApiException>()
          .having((e) => e.eventType, 'eventType', 'VALIDATION_ERROR')
          .having((e) => e.retryable, 'retryable', false)),
    );
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd frontend && flutter test test/features/market/market_repository_test.dart`
Expected: 컴파일 실패(MarketRepository 미존재).

- [ ] **Step 3: Repository 구현**

```dart
// market_repository.dart
import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'market_models.dart';

class MarketRepository {
  final Dio _dio;
  const MarketRepository(this._dio);

  Future<List<MarketRow>> fetchMarket() async {
    try {
      final res = await _dio.get('/api/market');
      return (res.data as List).map((e) => MarketRow.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<StockDetail> fetchDetail(String ticker) async {
    try {
      final res = await _dio.get('/api/market/$ticker');
      return StockDetail.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : const ApiException(eventType: 'NETWORK', code: 'ERR_NETWORK', message: '인터넷 연결을 확인해주세요.', retryable: true);
}
```

- [ ] **Step 4: 테스트 통과 + Commit**

Run: `cd frontend && flutter test test/features/market/market_repository_test.dart` → PASS.
```bash
git add frontend/lib/features/market/data/market_repository.dart frontend/test/features/market/market_repository_test.dart
git commit -m "feat(market): add MarketRepository with envelope/error handling + tests"
```

---

## Task F5: Riverpod providers (+ override 테스트)

**Files:**
- Create: `frontend/lib/features/market/application/market_providers.dart`
- Test: `frontend/test/features/market/market_providers_test.dart`

- [ ] **Step 1: providers 작성**

```dart
// market_providers.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/market_models.dart';
import '../data/market_repository.dart';

final dioProvider = Provider<Dio>((ref) => createApiClient());

final marketRepositoryProvider =
    Provider<MarketRepository>((ref) => MarketRepository(ref.watch(dioProvider)));

class MarketListNotifier extends AsyncNotifier<List<MarketRow>> {
  @override
  Future<List<MarketRow>> build() => ref.watch(marketRepositoryProvider).fetchMarket();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(marketRepositoryProvider).fetchMarket());
  }
}

final marketListProvider =
    AsyncNotifierProvider<MarketListNotifier, List<MarketRow>>(MarketListNotifier.new);

final stockDetailProvider = FutureProvider.family<StockDetail, String>(
  (ref, ticker) => ref.watch(marketRepositoryProvider).fetchDetail(ticker),
);
```

- [ ] **Step 2: 테스트 작성 + 실패 확인** (repository를 override한 fake로 AsyncValue 상태 검증)

```dart
// market_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/features/market/application/market_providers.dart';
import 'package:growant/features/market/data/market_models.dart';
import 'package:growant/features/market/data/market_repository.dart';

class _FakeRepo implements MarketRepository {
  @override
  Future<List<MarketRow>> fetchMarket() async =>
      const [MarketRow(ticker: '005930', name: '삼성전자', price: 76300, changeRate: 5.97)];
  @override
  Future<StockDetail> fetchDetail(String ticker) async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('marketListProvider resolves to rows', () async {
    final container = ProviderContainer(overrides: [
      marketRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);

    final rows = await container.read(marketListProvider.future);
    expect(rows, hasLength(1));
    expect(rows.first.name, '삼성전자');
  });
}
```

Run: `cd frontend && flutter test test/features/market/market_providers_test.dart`
Expected: 먼저 실패(providers 미존재) → Step 1 후 PASS.

- [ ] **Step 3: 통과 + Commit**

```bash
git add frontend/lib/features/market/application/market_providers.dart frontend/test/features/market/market_providers_test.dart
git commit -m "feat(market): add riverpod providers (list AsyncNotifier + detail family)"
```

---

## Task F6: ErrorView 추출 + serviceUnavailable + eventType 매핑

**Files:**
- Create: `frontend/lib/core/error/error_view.dart`
- Modify: `frontend/lib/features/error/error_screen.dart`

- [ ] **Step 1: ErrorView + 매핑 작성** (Scaffold 없음 — 탭 본문 임베드용)

```dart
// error_view.dart
import 'package:flutter/material.dart';

enum ErrorKind { network, serverError, notFound, unauthorized, serviceUnavailable }

ErrorKind errorKindFromEventType(String eventType) {
  switch (eventType) {
    case 'NETWORK':
      return ErrorKind.network;
    case 'AUTH_ERROR':
      return ErrorKind.unauthorized;
    case 'VALIDATION_ERROR':
      return ErrorKind.notFound;
    case 'MARKET_ERROR':
      return ErrorKind.serviceUnavailable;
    case 'SYSTEM_ERROR':
    default:
      return ErrorKind.serverError;
  }
}

class _Preset {
  final IconData icon;
  final String title;
  const _Preset(this.icon, this.title);
}

const _presets = <ErrorKind, _Preset>{
  ErrorKind.network: _Preset(Icons.wifi_off_outlined, '네트워크 오류'),
  ErrorKind.serverError: _Preset(Icons.cloud_off_outlined, '서버 오류'),
  ErrorKind.notFound: _Preset(Icons.search_off_outlined, '찾을 수 없음'),
  ErrorKind.unauthorized: _Preset(Icons.lock_outline, '접근 권한 없음'),
  ErrorKind.serviceUnavailable: _Preset(Icons.hourglass_empty_outlined, '일시적 오류'),
};

/// Scaffold 없는 에러 본문. 메시지는 서버 envelope 값을 권위로 사용.
class ErrorView extends StatelessWidget {
  final ErrorKind kind;
  final String? message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.kind, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = _presets[kind]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(p.icon, size: 64, color: const Color(0xFFCCCCCC)),
            const SizedBox(height: 24),
            Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              message ?? '잠시 후 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            if (onRetry != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 시도'),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: ErrorScreen이 ErrorView에 위임하도록 수정** (`error_screen.dart` 전체를 아래로 교체 — 기존 ErrorType→ErrorKind 위임, 갤러리 유지)

```dart
import 'package:flutter/material.dart';
import '../../core/error/error_view.dart';

/// 라우트형 에러 화면(자체 Scaffold). 본문은 ErrorView에 위임.
class ErrorScreen extends StatelessWidget {
  final ErrorKind kind;
  final String? message;
  final VoidCallback? onRetry;
  const ErrorScreen({super.key, this.kind = ErrorKind.network, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오류')),
      body: ErrorView(
        kind: kind,
        message: message,
        onRetry: onRetry ?? () => Navigator.pop(context),
      ),
    );
  }
}

// 에러 종류 미리보기 갤러리 (Mock 탐색용)
class ErrorGalleryScreen extends StatelessWidget {
  const ErrorGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('에러/예외 화면')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final kind in ErrorKind.values)
            ListTile(
              title: Text(kind.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ErrorScreen(kind: kind)),
              ),
            ),
        ],
      ),
    );
  }
}
```

> 주의: 기존 `ErrorScreen(type: ErrorType.x)` 참조처가 있으면 `kind: ErrorKind.x`로 갱신. 현재 `error_screen.dart` 외부에서 `ErrorScreen`/`ErrorType`을 쓰는 곳은 없음(grep으로 확인: `grep -rn "ErrorType\|ErrorScreen(" frontend/lib`).

- [ ] **Step 3: analyze + Commit**

Run: `cd frontend && flutter analyze` → No issues.
```bash
git add frontend/lib/core/error/error_view.dart frontend/lib/features/error/error_screen.dart
git commit -m "feat(market): extract Scaffold-less ErrorView + serviceUnavailable + eventType mapping"
```

---

## Task F7: 대시보드 화면 연결 (+ 위젯 테스트)

**Files:**
- Modify: `frontend/lib/features/market/market_dashboard_screen.dart`
- Test: `frontend/test/features/market/market_dashboard_test.dart`

- [ ] **Step 1: 대시보드를 ConsumerStatefulWidget + provider 바인딩으로 교체**

`market_dashboard_screen.dart` 전체 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/error/error_view.dart';
import '../../core/theme.dart';
import '../application/market_providers.dart';
import '../data/market_models.dart';
import 'stock_detail_screen.dart';

class MarketDashboardScreen extends ConsumerStatefulWidget {
  const MarketDashboardScreen({super.key});

  @override
  ConsumerState<MarketDashboardScreen> createState() => _MarketDashboardScreenState();
}

class _MarketDashboardScreenState extends ConsumerState<MarketDashboardScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marketListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final api = e is ApiException ? e : null;
        return ErrorView(
          kind: errorKindFromEventType(api?.eventType ?? 'NETWORK'),
          message: api?.message,
          onRetry: (api?.retryable ?? true) ? () => ref.read(marketListProvider.notifier).refresh() : null,
        );
      },
      data: (rows) {
        final filtered = rows.where((s) => s.name.contains(_query) || s.ticker.contains(_query)).toList();
        final upCount = filtered.where((s) => s.changeRate >= 0).length;
        final downCount = filtered.length - upCount;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(children: [
                    _MarketStat(label: '상승', count: upCount, color: upColor),
                    const SizedBox(width: 16),
                    _MarketStat(label: '하락', count: downCount, color: downColor),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: '종목명 또는 코드 검색',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (_, i) => _StockTile(row: filtered[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarketStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MarketStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text('$label $count', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _StockTile extends StatelessWidget {
  final MarketRow row;
  const _StockTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final isUp = row.changeRate >= 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: row.ticker)),
      ),
      title: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(row.ticker, style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${fmt.format(row.price)}원', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          Text('${isUp ? '+' : ''}${row.changeRate.toStringAsFixed(2)}%',
              style: TextStyle(color: isUp ? upColor : downColor, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 위젯 테스트 작성**

```dart
// market_dashboard_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/features/market/application/market_providers.dart';
import 'package:growant/features/market/data/market_models.dart';
import 'package:growant/features/market/data/market_repository.dart';
import 'package:growant/features/market/market_dashboard_screen.dart';

class _FakeRepo implements MarketRepository {
  @override
  Future<List<MarketRow>> fetchMarket() async =>
      const [MarketRow(ticker: '005930', name: '삼성전자', price: 76300, changeRate: 5.97)];
  @override
  Future<StockDetail> fetchDetail(String ticker) async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('dashboard renders rows from provider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [marketRepositoryProvider.overrideWithValue(_FakeRepo())],
      child: const MaterialApp(home: Scaffold(body: MarketDashboardScreen())),
    ));
    await tester.pump(); // loading -> data
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('76,300원'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 실행/통과 확인**

Run: `cd frontend && flutter test test/features/market/market_dashboard_test.dart`
Expected: PASS. (`flutter analyze`도 No issues.)

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/market/market_dashboard_screen.dart frontend/test/features/market/market_dashboard_test.dart
git commit -m "feat(market): wire market dashboard to marketListProvider"
```

---

## Task F8: 종목 상세 화면 연결

**Files:**
- Modify: `frontend/lib/features/market/stock_detail_screen.dart`

- [ ] **Step 1: 상세를 ticker 기반 + provider로 교체** (가격/등락/펀더멘털/캔들=서버 `StockDetail`, `_OrderSheet`는 mock 유지)

`stock_detail_screen.dart`에서 변경 사항:
1. import에 riverpod/providers/models/api_exception/error_view 추가, `mock_data.dart` 제거.
2. `StockDetailScreen`을 `ConsumerWidget`으로, 생성자를 `{required String ticker}`로.
3. `build`에서 `ref.watch(stockDetailProvider(ticker)).when(loading/error/data)` — data일 때 기존 본문 위젯을 `StockDetail`로 렌더하는 `_DetailBody(detail)`로 분리.
4. `_MiniChart(prices: detail.candles)` 사용(전역 mockCandleClose 제거).
5. 펀더멘털은 `detail.high52w/low52w/volume/marketCapEok/per/pbr` 사용.
6. `_OrderSheet`는 그대로 두되 시그니처를 `({required String name, required int price, required bool isBuy})`로 바꿔 `StockDetail`에서 값 주입(매수/매도 동작은 기존 SnackBar mock 유지).

전체 교체 코드:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/error/error_view.dart';
import '../../core/theme.dart';
import '../application/market_providers.dart';
import '../data/market_models.dart';

class StockDetailScreen extends ConsumerWidget {
  final String ticker;
  const StockDetailScreen({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockDetailProvider(ticker));
    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?.name ?? ticker)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final api = e is ApiException ? e : null;
          return ErrorView(
            kind: errorKindFromEventType(api?.eventType ?? 'NETWORK'),
            message: api?.message,
            onRetry: (api?.retryable ?? true) ? () => ref.invalidate(stockDetailProvider(ticker)) : null,
          );
        },
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final StockDetail detail;
  const _DetailBody({required this.detail});

  void _showOrderSheet(BuildContext context, bool isBuy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OrderSheet(name: detail.name, price: detail.price, isBuy: isBuy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final isUp = detail.changeRate >= 0;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt.format(detail.price)}원', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${isUp ? '+' : ''}${detail.changeRate.toStringAsFixed(2)}%',
                        style: TextStyle(color: isUp ? upColor : downColor, fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(detail.ticker, style: const TextStyle(color: Color(0xFF999999), fontSize: 13)),
              const SizedBox(height: 24),
              const Text('가격 추이 (최근 10일)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              _MiniChart(prices: detail.candles),
              const SizedBox(height: 24),
              _InfoRow(label: '52주 최고', value: '${fmt.format(detail.high52w)}원'),
              _InfoRow(label: '52주 최저', value: '${fmt.format(detail.low52w)}원'),
              _InfoRow(label: '거래량', value: '${fmt.format(detail.volume)}주'),
              _InfoRow(label: '시가총액', value: '${fmt.format(detail.marketCapEok)}억원'),
              _InfoRow(label: 'PER', value: '${detail.per}x'),
              _InfoRow(label: 'PBR', value: '${detail.pbr}x'),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(child: _OrderButton(label: '매수', color: upColor, onTap: () => _showOrderSheet(context, true))),
                const SizedBox(width: 12),
                Expanded(child: _OrderButton(label: '매도', color: downColor, onTap: () => _showOrderSheet(context, false))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OrderButton({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}

class _MiniChart extends StatelessWidget {
  final List<int> prices;
  const _MiniChart({required this.prices});
  @override
  Widget build(BuildContext context) {
    final reversed = prices.reversed.toList();
    final minP = reversed.reduce((a, b) => a < b ? a : b);
    final maxP = reversed.reduce((a, b) => a > b ? a : b);
    final range = (maxP - minP).toDouble();
    return SizedBox(
      height: 100,
      child: CustomPaint(painter: _LinePainter(prices: reversed, min: minP, range: range), size: const Size(double.infinity, 100)),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<int> prices;
  final int min;
  final double range;
  const _LinePainter({required this.prices, required this.min, required this.range});
  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty || range == 0) return;
    final paint = Paint()..color = upColor..strokeWidth = 2..style = PaintingStyle.stroke;
    final n = prices.length;
    final pts = List.generate(n, (i) {
      final x = size.width * i / (n - 1);
      final y = size.height - (size.height * (prices[i] - min) / range);
      return Offset(x, y);
    });
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(_LinePainter old) => false;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(label, style: const TextStyle(color: Color(0xFF888888))),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

// NOTE(market-slice): _OrderSheet은 mock 유지 — 거래(trading) 슬라이스에서 실연동. 스펙 §1
class _OrderSheet extends StatefulWidget {
  final String name;
  final int price;
  final bool isBuy;
  const _OrderSheet({required this.name, required this.price, required this.isBuy});
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  int _qty = 1;
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final total = widget.price * _qty;
    final color = widget.isBuy ? upColor : downColor;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.isBuy ? '매수 주문' : '매도 주문', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
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
            IconButton(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
            SizedBox(width: 40, child: Text('$_qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add_circle_outline)),
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('주문 금액', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${fmt.format(total)}원', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${widget.isBuy ? '매수' : '매도'} 주문 완료 (Mock): ${widget.name} $_qty주'),
                duration: const Duration(seconds: 2),
              ));
            },
            child: Text(widget.isBuy ? '매수 주문' : '매도 주문', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 전체 analyze + 테스트**

Run: `cd frontend && flutter analyze && flutter test`
Expected: No issues + 모든 테스트 PASS. (대시보드 타일 onTap이 `StockDetailScreen(ticker:)`를 쓰는지 확인.)

- [ ] **Step 3: E2E 수동 확인**

`./gradlew bootRun --args='--spring.profiles.active=local'` 기동 후 `flutter run`(에뮬레이터면 `--dart-define=API_BASE_URL=http://10.0.2.2:8080`). 마켓 탭 목록 로드 → 종목 탭 → 상세(종목별 캔들) 확인. 백엔드 끄고 재시도 → ErrorView + 다시 시도.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/market/stock_detail_screen.dart
git commit -m "feat(market): wire stock detail to stockDetailProvider (ticker-based, per-ticker candles)"
```

---

## Self-Review (작성자 체크)

- **스펙 커버리지**: §3.2 카탈로그/캔들/펀더멘털→B3; §3.3 엔드포인트→B4; §3.4 DTO→B2; §3.6 Security+local 부팅→B1; §4.1~4.4 api/repository/providers→F2~F5; §4.5 화면 연결→F7/F8; §5 에러 계약(ErrorView+serviceUnavailable+매핑)→F6; §7 테스트→B3/B4/F4/F5/F7. 누락 없음.
- **placeholder**: 없음(모든 step에 실제 코드/명령/기대값).
- **타입 일관성**: DTO 필드명(ticker,name,price,changeRate,candles,high52w,low52w,volume,marketCapEok,per,pbr)이 Kotlin DTO ↔ Dart 모델 ↔ 테스트 JSON에서 동일. `MarketRow`/`StockDetail`/`MarketRepository.fetchMarket|fetchDetail`/`marketListProvider`/`stockDetailProvider`/`ErrorKind`/`errorKindFromEventType` 명칭이 정의처와 사용처에서 일치.
- **알려진 보정**: `MARKET_DATA_UNAVAILABLE`는 이 슬라이스에서 트리거 경로 없음(실데이터 슬라이스 예약) — 스펙 §3.5 대비 의도된 축소. high52w/low52w 기대값은 실제 `roundToInt()` 출력으로 확정(B3 Step4).
