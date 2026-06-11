# ⑥ 인증 슬라이스 설계 — 데모 로그인 + JWT 전체 보호

> 상태: 승인된 설계. 구현 계획은 `docs/superpowers/plans/`의 동명 계획 문서를 따른다.

## 1. 배경과 목표

현재 로그인 화면은 소셜 버튼 4개가 전부 무조건 `AppShell`로 이동하는 mock이고, 백엔드는 모든 API가 `permitAll`이다. 이 슬라이스는 **사용자 개념과 실제 인증 게이트**를 도입한다.

**목표**
- 데모 로그인: 소셜 버튼 탭 → 닉네임 입력 → 서버 find-or-create 가입·로그인
- JWT 발급·검증(Spring 공식 oauth2-resource-server 자체 서명, HS256)
- 전체 API 보호: `/api/auth/**`만 공개, 나머지는 Bearer 토큰 필수
- 프론트 자동 로그인(AuthGate + secure storage), 로그아웃, 프로필 표시 연동
- 기술부채: `_asApiException` 4벌 중복을 공용 함수로 추출(5번째 복제 방지)

**비목표 (추후 슬라이스)**
- 실제 소셜 OAuth(카카오 SDK 등) — login 엔드포인트 내부 교체 지점만 마련
- 사용자별 거래 상태 분리 — 인증은 게이트만, per-user는 ⑦ 영속성에서 userId 컬럼과 함께
- 토큰 자동 갱신(refresh token), 비밀번호, 회원 탈퇴
- 계정 탭의 자산/보유종목 mock 정리(요금제 tier 포함 — 각자 해당 슬라이스에서)

## 2. 확정 결정

| 결정 | 선택 | 근거 |
|---|---|---|
| 로그인 수준 | 데모 로그인(provider+nickname) | 외부 키 불필요, 기존 소셜 UI 유지 |
| 토큰 | JWT (자체 서명 HS256) | 현 STATELESS 유지, 모바일 표준 |
| 구현 방식 | **A안**: `spring-boot-starter-oauth2-resource-server` | 커스텀 필터 0개, Spring 정석 |
| 상태 범위 | 단일 공유 상태 유지 | per-user는 ⑦에서 DB와 함께 |
| 보호 범위 | 전체 보호(`/api/auth/**`만 공개) | 앱이 로그인 후에만 화면 진입 |

## 3. 백엔드 설계

### 3.1 의존성 (build.gradle.kts)

```kotlin
implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")
testImplementation("org.springframework.security:spring-security-test")
```

### 3.2 `com.growant.auth` 패키지

- `User(id: Long, nickname: String, provider: String)` — data class.
- `UserStore` — in-memory find-or-create: `ConcurrentHashMap<String /* "provider:nickname" */, User>` + `AtomicLong` id 발급. 같은 (provider, nickname) 재로그인 시 동일 User 반환(멱등). `@Component`.
- `AuthService(userStore, jwtEncoder)`:
  - `login(provider, nickname): AuthResponseDto`
  - 검증: provider ∉ {kakao, naver, apple, google} 또는 nickname.trim() 빈 문자열/20자 초과 → `BusinessException(INVALID_LOGIN)`
  - JWT 클레임: `sub`=user.id 문자열, `nickname`, `provider`, issuer `growant`, 만료 24h(`Instant.now() + Duration.ofHours(24)`)
- `AuthController`:
  - `POST /api/auth/login` body `LoginRequestDto(provider, nickname)` → `ApiResponse<AuthResponseDto>`
  - `GET /api/auth/me` → `ApiResponse<UserDto>` — **`@AuthenticationPrincipal jwt: Jwt` 클레임에서 직접 구성**(스토어 조회 없음). 서버가 재시작돼도 유효 토큰이면 me가 동작하는 stateless 설계.
- DTO: `LoginRequestDto(provider: String, nickname: String)`, `UserDto(id: Long, nickname: String, provider: String)`, `AuthResponseDto(token: String, user: UserDto)`.

### 3.3 JwtConfig

`com.growant.common.config.JwtConfig` — `JwtEncoder`/`JwtDecoder` 빈. 키는 `auth.jwt.secret` 프로퍼티(`application.yml`: `${JWT_SECRET:growant-dev-secret-please-override-32b!}` — HS256 최소 256bit=32자 이상 보장). `SecretKeySpec(secret.toByteArray(), "HmacSHA256")` 기반 `NimbusJwtEncoder(ImmutableSecret(...))` / `NimbusJwtDecoder.withSecretKey(...)`. 루트 `.env.example`의 `JWT_SECRET=__change_me__` 항목은 이미 존재(변경 없음).

### 3.4 SecurityConfig 개편

```kotlin
.authorizeHttpRequests {
    it.requestMatchers("/api/auth/**").permitAll()   // 기존 permitAll 5줄 전부 제거
    it.anyRequest().authenticated()
}
.oauth2ResourceServer {
    it.jwt { }                                        // JwtDecoder 빈 사용
    it.authenticationEntryPoint(apiAuthEntryPoint)    // 401 envelope 통일
}
```

- `ApiAuthEntryPoint`(`AuthenticationEntryPoint` 구현, `@Component`): 401 응답을 기존 `ApiResponse` 에러 envelope으로 — `ErrorCode.UNAUTHENTICATED`(이미 존재: 2000/AUTH_ERROR/retryable=false/"로그인이 필요합니다.") 사용, `ObjectMapper` 주입해 JSON 직렬화. 토큰 만료·서명 오류·토큰 부재 전부 동일 401 envelope(만료 구분은 YAGNI — `TOKEN_EXPIRED` 코드는 미사용 유지).
- 403(authorities 부족)은 역할 개념이 없어 발생 경로 없음 — accessDeniedHandler 미구현.

### 3.5 ErrorCode 추가 (1개)

```kotlin
INVALID_LOGIN(3002, HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", false, "잘못된 로그인 요청입니다."),
```

(`UNAUTHENTICATED` 2000은 기존 코드 재사용.)

### 3.6 기존 컨트롤러 테스트 보정 — 전체 보호의 필연 비용

- 모든 `@WebMvcTest` 4개 파일(케이스 수: Market 3 · Portfolio 2 · Account 1 · Trading 3)에:
  - `@Import`에 `JwtConfig::class` 추가(oauth2ResourceServer DSL이 컨텍스트 기동 시 `JwtDecoder` 빈 요구)
  - 각 요청에 `with(jwt())` post-processor 추가(Kotlin DSL: `mockMvc.get("/api/market") { with(jwt()) }`)
- 미인증 401 envelope 검증은 AuthControllerTest에 1케이스로 집중(보호 자체의 회귀 가드).

## 4. 프론트 설계

### 4.1 의존성

`flutter_secure_storage` (pubspec) — JWT 보관(iOS Keychain).

### 4.2 `core/api/token_storage.dart` (core 계층 — 순환 의존 방지)

```dart
class TokenStorage {
  // FlutterSecureStorage 래핑: read()/save(token)/clear(), key 'auth_token'
}
final tokenStorageProvider = Provider<TokenStorage>(...);
```

`dioProvider`(market_providers)가 이걸 읽고, auth feature도 이걸 읽는다 — feature 간 순환 import 없음.

### 4.3 `api_client.dart` 확장

```dart
Dio createApiClient({String baseUrl = kApiBaseUrl, Future<String?> Function()? getToken})
```

- `onRequest` 인터셉터: `getToken` 주입 시 토큰 읽어 `Authorization: Bearer <token>` 부착(null이면 헤더 없음). 미주입 시 기존과 동일(기존 repo 테스트 영향 0).
- `dioProvider`: `createApiClient(getToken: () => ref.read(tokenStorageProvider).read())`.

### 4.4 `features/auth/` 레이어

- `data/auth_models.dart`: `AuthUser(id, nickname, provider)` + fromJson, `AuthResponse(token, user)` + fromJson.
- `data/auth_repository.dart`: `login({provider, nickname})` POST `/api/auth/login`, `me()` GET `/api/auth/me` — 에러 매핑은 **추출된 공용 `asApiException`** 사용(§5).
- `application/auth_providers.dart`: `authRepositoryProvider`, `AuthController extends AsyncNotifier<AuthUser?>`:
  - `build()`: 저장 토큰 없으면 `null`, 있으면 `me()` 시도 — 실패(401 포함) 시 토큰 clear 후 `null`
  - `login(provider, nickname)`: repo.login → 토큰 save → state=AsyncData(user)
  - `logout()`: 토큰 clear → state=AsyncData(null)
  - `authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>`

### 4.5 AuthGate + main.dart

`app/auth_gate.dart` — `ConsumerWidget`: `authControllerProvider`를 watch,
- loading → 로고+스피너 스플래시(간단한 Center)
- `AuthUser` 존재 → `AppShell`
- `null` → `LoginScreen`

`main.dart`: `home: AuthGate()`. (LoginScreen의 `pushReplacement` 수동 네비게이션 제거 — 상태 전환이 화면을 결정.)

### 4.6 LoginScreen 개편

- 4개 버튼 유지, 탭 → `showModalBottomSheet` 닉네임 입력 시트(TextField maxLength 20, '시작하기' FilledButton).
- 시트 제출: `authController.login(provider, nickname)` — 성공 시 시트 pop(AuthGate가 AppShell로 전환), `ApiException` 실패 시 스낵바 + 시트 유지, 제출 중 버튼 비활성+스피너(주문 시트와 동일 패턴: messenger/navigator 캡처, mounted 가드).
- provider 매핑: 카카오→`kakao`, 네이버→`naver`, Apple→`apple`, Google→`google`.

### 4.7 프로필 표시 연동 + mock 정리

- 계정 탭 헤더: `mockUserName`/`mockUserEmail` → 로그인 사용자 `nickname` + provider 라벨("카카오 로그인" 등). `_TierChip(mockUserTier)`는 유지(요금제 영역). `로그아웃` 메뉴 `onTap` → `authController.logout()`.
- 홈 `asset_card.dart`: `mockUserName` → 로그인 사용자 `nickname`(`_TierChip(mockUserTier)` 유지).
- `mock_data.dart`: `mockUserName`·`mockUserEmail` 상수 제거(사용처 소멸). `mockUserTier`는 유지.
- AuthGate 뒤에서는 user가 항상 존재하지만 위젯 단독 테스트 대비 null 폴백은 `'투자자'`로 표기.

## 5. 기술부채: `asApiException` 추출

`core/api/api_exception.dart`에 공용 함수 추가:

```dart
ApiException asApiException(DioException e) => e.error is ApiException
    ? e.error as ApiException
    : const ApiException(eventType: 'NETWORK', code: 'ERR_NETWORK',
        message: '인터넷 연결을 확인해주세요.', retryable: true);
```

market/portfolio/account/trading 4개 repo의 private `_asApiException` 제거·교체, auth repo는 처음부터 사용. 동작 동일(기존 repo 테스트가 회귀 가드).

## 6. API 계약

### POST /api/auth/login

요청: `{"provider": "kakao", "nickname": "개미왕"}`

200: `{"success": true, "data": {"token": "<jwt>", "user": {"id": 1, "nickname": "개미왕", "provider": "kakao"}}}`

400 (provider 불허/닉네임 공백·20자 초과): `{"success": false, "error": {"code": "INVALID_LOGIN", "eventType": "VALIDATION_ERROR", "message": "잘못된 로그인 요청입니다.", "retryable": false}}`

### GET /api/auth/me (Bearer 필수)

200: `{"success": true, "data": {"id": 1, "nickname": "개미왕", "provider": "kakao"}}`

### 보호된 API 미인증/무효 토큰 (공통 401)

`{"success": false, "error": {"code": "UNAUTHENTICATED", "eventType": "AUTH_ERROR", "message": "로그인이 필요합니다.", "retryable": false}}`

## 7. 테스트 계획

**백엔드** (기존 22 + 신규 ~8)
- `AuthServiceTest`: find-or-create 멱등(같은 입력=같은 id, 다른 provider=다른 id) / 토큰 클레임(sub·nickname·provider) 디코딩 검증 / INVALID_LOGIN 3종(잘못된 provider·공백·21자)
- `AuthControllerTest`(@WebMvcTest): 로그인 성공 envelope / 잘못된 provider 400 envelope / `with(jwt())` me 응답 / **무토큰 보호 API 401 UNAUTHENTICATED envelope**
- 기존 컨트롤러 테스트 전부 `with(jwt())` 보정 후 그린

**프론트** (기존 33 + 신규 ~11)
- `auth_repository_test`: login 파싱(요청 body 매처) / me 파싱 / 400 envelope → ApiException
- `token interceptor`: getToken 주입 시 Authorization 헤더 부착, null 토큰이면 미부착
- `AuthGate` 위젯: 토큰 없음→LoginScreen / me 성공→AppShell / 로딩 스피너
- `LoginScreen` 플로우: 버튼 탭→시트→닉네임 제출→FakeRepo 호출 인자 검증 / 실패 스낵바+시트 유지
- 계정 탭: 닉네임·provider 라벨 표시, 로그아웃 탭→logout 호출
- 기존 4벌 repo 테스트는 `asApiException` 추출 후에도 무수정 그린(회귀 가드)

## 8. 알려진 한계 (PR 본문 기재)

- **닉네임 = 신원**: 같은 (provider, nickname)이면 같은 계정(비밀번호 없음) — 데모 의도.
- **토큰 24h 만료 후 자동 갱신 없음**: 만료 시 401 → 다음 앱 재시작 시 AuthGate가 로그인 화면으로. 사용 중 만료의 즉시 리다이렉트는 미구현(화면별 ErrorView가 "접근 권한 없음" 표시).
- **UserStore 휘발**: 서버 재시작 시 id 채번 초기화 — 단일 공유 거래 상태라 실영향 없음, ⑦에서 DB 이관.
- **거래 상태는 여전히 단일 공유**: 어느 계정으로 로그인해도 같은 포트폴리오.

## 9. 실행

백엔드 변화 없음(local 프로파일 그대로 — JWT_SECRET은 기본값 폴백). 프론트 실행법 변화 없음(`--dart-define-from-file=.env`).
