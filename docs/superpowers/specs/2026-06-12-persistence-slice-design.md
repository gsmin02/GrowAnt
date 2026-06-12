# ⑦ 영속성 슬라이스 설계 — PostgreSQL + JPA + per-user 분리

> 상태: 승인된 설계. 구현 계획은 `docs/superpowers/plans/`의 동명 계획 문서를 따른다.

## 1. 배경과 목표

거래 상태(현금·포지션·내역)와 사용자(UserStore)가 전부 in-memory라 서버 재시작 시 초기화되고, 어느 계정으로 로그인해도 같은 포트폴리오를 본다. 이 슬라이스는 **PostgreSQL 영속화 + 사용자별 상태 분리**를 도입한다.

**목표**
- users·positions·trades 3테이블 영속화(Flyway 마이그레이션, `ddl-auto: validate`)
- **per-user 분리**: 서비스가 JWT 사용자 기준으로 동작 — 프론트 API 계약 무변경
- 신규 가입 시 **깨끗한 1,000만 현금**(빈 포트폴리오·빈 내역)
- 동시성: `@Synchronized` → DB 트랜잭션(주문=비관적 잠금, 요약=REPEATABLE_READ 스냅샷 — 비원자 이중 읽기 해소)
- Testcontainers 통합 테스트(실 PostgreSQL + Flyway 실검증)
- `backend/Dockerfile` + `application-dev.yml` → `docker compose up` 경로 완성, local 프로파일 DB 필수 전환
- 내역 탭 빈 상태 문구(신규 유저 첫 화면 대응)

**비목표 (추후 슬라이스)**
- AI 포지션 영속화·AI 매매(⑤ — `NOTE(duel-ai)` 하드코딩 유지, userId 무관)
- Redis 사용(④ 실시세에서 — 의존성·compose 서비스만 준비 상태 유지)
- 대결 메타(D-day 등) 영속화(대결 슬라이스)
- 계정 탭 자산/보유 mock 정리(별도)

## 2. 확정 결정

| 결정 | 선택 | 근거 |
|---|---|---|
| 구현 방식 | **A안**: Spring Data JPA 직접 주입 + `@Transactional` | 프레임워크 정석, 추상화 0겹. 포트+어댑터(B안)는 초기 단계에 변경 지점만 이중화 — 대신 아래 DRY 보강으로 중복 차단 |
| per-user 분리 | 포함 | 인증 슬라이스 한계(계정 무관 동일 포트폴리오) 해소. JWT sub=DB id |
| 신규 시드 | **깨끗한 1,000만 현금** | 빈 포트폴리오·빈 내역으로 시작(진짜 신규 경험). 기존 데모 불변값(10,520,000/+5.2%)은 폐기 |
| 테스트 DB | Testcontainers | 실 PostgreSQL 방언·Flyway·잠금 실검증. Docker 가용 |
| local 프로파일 | DB 필수 전환 | compose로 postgres만 띄우고 bootRun — 단일 코드 경로, in-memory 폴백 이중 구현 없음 |

## 3. DRY 보강 원칙 (A안 채택 조건)

추상화 계층 없이 중복을 차단하는 지점을 명시한다. 구현·리뷰에서 이 5가지를 강제한다.

1. **스키마 단일 원천**: Flyway `V1__init.sql`만이 스키마를 정의. 엔티티는 매핑만 하고 `ddl-auto: validate`가 드리프트를 부팅 시점에 검출.
2. **매핑 단일 정의**: 엔티티→도메인/DTO 변환 함수(`PositionEntity.toDomain()`, `TradeEntity.toDto()`)는 엔티티 파일에 한 번만 — 서비스마다 매핑 코드 금지.
3. **시드 상수 단일화**: 가입 지급액 = 수익률 분모 = `INITIAL_CASH`(10,000,000) 상수 한 곳 — `com.growant.common.Seed`(top-level `const val INITIAL_CASH = 10_000_000L`). auth·account 어느 쪽에 둬도 반대 방향 의존이 생기므로 common에 둔다.
4. **userId 추출 단일화**: 확장 프로퍼티 `val Jwt.userId: Long get() = subject.toLong()` 한 곳 — 컨트롤러 4곳 재사용.
5. **테스트 인프라 단일화**: `PostgresIntegrationTest` 추상 베이스 1곳(컨테이너 1회 기동·재사용 + `@ServiceConnection`) — IT마다 컨테이너 설정 금지.

## 4. 스키마 (Flyway `V1__init.sql`)

```sql
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

- 닉네임=신원 데모 규칙이 `uq_users_provider_nickname`으로 DB 레벨 승격.
- `time "MM.dd HH:mm"` 문자열은 저장하지 않음 — `executed_at`에서 DTO 변환 시 Asia/Seoul로 포맷(프론트 계약 유지).
- trades는 `ticker`(식별)와 `name`(표시) 둘 다 저장 — 체결 시점 기록의 재현성.

## 5. 엔티티·리포지토리

- `UserEntity` / `PositionEntity` / `TradeEntity` — **연관관계 매핑 없음**: FK는 `userId: Long` 평컬럼(단순성 — lazy 프록시·open 클래스 이슈 원천 차단, 조인 필요 시 쿼리로). `kotlin("plugin.jpa")`는 이미 적용(no-arg).
- 리포지토리(Spring Data 인터페이스 — 이것이 곧 저장 경계):
  - `UserJpaRepository`: `findByProviderAndNickname(provider, nickname)`, `@Lock(PESSIMISTIC_WRITE) @Query("select u from UserEntity u where u.id = :id") findForUpdate(id)`
  - `PositionJpaRepository`: `findByUserId(userId)`, `findByUserIdAndTicker(userId, ticker)`
  - `TradeJpaRepository`: `findByUserIdOrderByExecutedAtDescIdDesc(userId)` — 동일 타임스탬프 동률은 id 역순으로 안정 정렬
- 매핑: §3-2 원칙대로 엔티티 파일의 변환 함수만 사용. 기존 소비 타입 `Position`(trading)·`TradeDto`·`UserDto`는 유지.

## 6. 서비스 전환

### 6.1 TradingService — 시그니처에 userId, 동시성은 잠금으로

```kotlin
fun getCash(userId: Long): Long
fun getMePositions(userId: Long): List<Position>
fun getTrades(userId: Long): List<TradeDto>
@Transactional
fun placeOrder(userId: Long, ticker: String, isBuy: Boolean, qty: Int): TradeDto
```

- `placeOrder`: `userRepo.findForUpdate(userId)`(비관적 잠금 — 동시 주문 잔고 레이스 차단; 미존재 시 `BusinessException(UNAUTHENTICATED)` — DB 리셋 후 옛 토큰 재로그인 유도) → 검증(qty<1 INVALID_ORDER → 카탈로그 INVALID_TICKER → 잔고 FUNDS/보유 HOLDINGS) → 현금 증감 + 포지션 upsert(가중평단 `roundToInt`)/차감·전량삭제 → trade insert. **검증 순서·에러 코드·계산식은 기존과 동일.**
- `@Synchronized`·in-memory 필드·시드 6건 전부 삭제.

### 6.2 AuthService — find-or-create를 DB로, 가입 시드 지급

- `UserStore` 삭제 → `login()`: `findByProviderAndNickname` ?: `save(UserEntity(cash = INITIAL_CASH))`. 동시 가입은 유니크 충돌(`DataIntegrityViolationException`) catch 후 재조회 — 멱등. **login에 바깥 `@Transactional`을 두지 않는다**: PostgreSQL은 제약 위반 시 트랜잭션을 중단시켜 같은 트랜잭션 내 재조회가 불가 — 각 repo 호출의 자체 트랜잭션으로 충분(쓰기 1회).
- JWT 발급·검증·클레임·`me`(클레임 기반, DB 조회 없음)는 무변경.

### 6.3 AccountService — 원자 요약

```kotlin
@Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
fun getSummary(userId: Long): AccountSummaryDto
```

- 단일 스냅샷에서 현금+me 포트폴리오 평가(READ COMMITTED로는 두 읽기 사이에 커밋된 체결이 끼면 여전히 어긋남 — 격리 수준까지 올려 진짜 해소). `seed` → `INITIAL_CASH` 상수 공유(§3-3).

### 6.4 PortfolioService

- `getPortfolio(owner, userId)` — ME만 userId 사용(TradingService 위임 유지), AI 하드코딩 + `NOTE(duel-ai)` 그대로.

## 7. 컨트롤러

- Trading·Portfolio·Account 컨트롤러: `@AuthenticationPrincipal jwt: Jwt` 추가, `jwt.userId`(§3-4 확장 프로퍼티)로 서비스 호출. URL·요청/응답 계약 무변경 — **프론트 데이터 레이어 수정 0**.

## 8. 테스트 전략

### 8.1 통합 테스트 (Testcontainers — §3-5 공용 베이스)

`@SpringBootTest` + `PostgresIntegrationTest` 베이스(컨테이너 정적 1회 기동·재사용, `@ServiceConnection`). Flyway가 부팅마다 실행되어 마이그레이션이 상시 검증된다.

- `AuthServiceIT`: 가입 시 cash=10,000,000·빈 포지션/내역 / 같은 (provider,nickname) 재로그인 멱등(id 동일) / INVALID_LOGIN 3종
- `TradingServiceIT`(신규 유저 기준 재작성): 매수 005930×1 → cash 9,923,700·포지션 (1, 76300) / 추가 매수 가중평단 / 매도·전량매도 삭제 / 에러 4종(미보유 매도 포함) / **체결 직후 (현금+평가) 불변** / 내역 최신순
- `AccountServiceIT`: 가입 직후 10,000,000/0.0% → 매수 후에도 totalAsset 불변·rate 0.0
- `ConcurrentOrderIT`: 같은 유저 동시 매수 2스레드 × N — 최종 현금 = 정확히 합산 차감(비관 잠금 검증)
- `MarketServiceTest`(무DB)·`PortfolioServiceTest`(TradingService 모킹으로 합산 로직 단위 유지)는 단위 테스트로 존속

### 8.2 컨트롤러 테스트 — `@MockitoBean` 전환

서비스가 DB 의존이 되므로 `@WebMvcTest`에서 실 서비스 import 불가 → Trading/Portfolio/Account/Auth 컨트롤러 테스트는 서비스를 `@MockitoBean`으로 모킹(슬라이스 테스트 본연). envelope·`jwt()`·401 단언은 유지, 수치 단언은 모킹 픽스처 기준으로 조정. Market 컨트롤러 테스트는 실 서비스 유지(무DB).

### 8.3 프론트

- 내역 탭: 빈 목록이면 "거래 내역이 없습니다" 중앙 문구(요약 바 생략) — 위젯 테스트 1케이스 추가. 그 외 프론트 무변경(API 계약 동일).

## 9. 의존성·인프라

### 9.1 build.gradle.kts 추가

```kotlin
implementation("org.flywaydb:flyway-core")
implementation("org.flywaydb:flyway-database-postgresql")
testImplementation("org.springframework.boot:spring-boot-testcontainers")
testImplementation("org.testcontainers:postgresql")
testImplementation("org.testcontainers:junit-jupiter")
```

(버전은 Boot 4 dependency management 위임.)

### 9.2 backend/Dockerfile (멀티스테이지)

gradle JDK21 빌드 스테이지 → `eclipse-temurin:21-jre` 런타임, bootJar 복사, `EXPOSE 8080`.

### 9.3 프로파일·compose

- `application.yml`: flyway 활성(기본값으로 충분 — locations classpath:db/migration), datasource/jpa 기존 유지.
- `application-local.yml`: DataSource/JPA/Hibernate exclude **제거**, Redis exclude만 유지(④까지 미사용). local 실행 전제 = `docker compose up -d postgres`.
- `application-dev.yml`(신규, compose 내부): 최소 구성 — datasource는 compose env(`DB_URL` 등)로 주입되므로 placeholder 그대로, 주석으로 용도 명시.
- `docker-compose.yml`: backend `environment`에 `REDIS_HOST: redis` 추가, postgres `healthcheck`(pg_isready) + backend `depends_on: postgres: condition: service_healthy`.
- README 실행 섹션: "백엔드 단독" → `docker compose up -d postgres` 선행 1줄 추가, docker 캐비앗 문구 제거(Dockerfile 생김).

### 9.4 검증 게이트

`docker compose up --build -d` → backend 컨테이너 healthy → `curl /api/trades` 401 envelope → `docker compose down`(볼륨 유지).

## 10. 첫 화면 변화 (시드 결정의 파급)

가입 직후: 자산 **10,000,000 / 0.0%**, 보유·내역 빈 상태, 대결 카드 내 0% vs AI +3.8%. 기존 데모 불변값(10,520,000/+5.2%/시드 내역 6건)은 폐기 — 관련 테스트는 "가입→주문→검증" 시나리오로 대체. README 스크린샷 갱신은 범위 외(거래 후 상태로 자연 재현 가능).

## 11. 알려진 한계 (PR 본문 기재)

- **AI 포지션 미영속**: 하드코딩 유지 — ⑤ AI 슬라이스에서 영속·실매매 전환
- **Redis 준비만**: 의존성·compose 서비스 존재, 미사용 — ④ 실시세에서
- **닉네임=신원 유지**: 비밀번호 없음(DB 유니크 제약으로 승격됐을 뿐)
- **데이터 수명 = postgres 볼륨**: `docker compose down -v` 시 초기화, 옛 JWT는 401 → 재로그인
