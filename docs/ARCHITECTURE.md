# GrowAnt — Architecture (Track A 기저)

## Stack
- Frontend: Flutter 3.44 / Dart 3 (크로스플랫폼)
- Backend: Spring Boot 4.0.x + Kotlin (JDK 21)
- DB: PostgreSQL (자체 호스팅 — docker compose `postgres` 컨테이너)
- Cache / 실시간 fan-out: Redis
- Reverse proxy: nginx
- AI sidecar (추후): Python FastAPI (백테스터·연구)

## Monorepo
```
GrowAnt/
  backend/    Spring Boot (Kotlin)
  frontend/   Flutter
  infra/      nginx
  docs/       Track A 설계 문서
  docker-compose.yml
```

## 모듈 (패키지 by 기능 + 내부 레이어드)
`auth · market · trading · duel · ai · subscription · notification`
각 모듈 내부: controller → service → repository

## 포트(교체 지점)
- `MarketDataProvider` — 시세 소스. 현재 `SimulatedMarketDataProvider`, 추후 `KisMarketDataProvider`
- `AiClient` — LLM 호출(Gemini Flash/Pro), 추후 멀티벤더(Claude/GPT)
- `StrategyEngine` — 대결 전략 생성·백테스트, 추후 FastAPI 사이드카로 추출

## 시세 데이터 (현재 결정)
KIS PoC 보류 → `MarketDataProvider = sim`. 랜덤워크 기반 가격 스트림(옵션: 변동성·추세·뉴스를 LLM이 시나리오로 생성). KIS는 동일 포트의 구현체로 후속 교체.

## 실시간 경로
(sim 또는 KIS) → Spring `market` → Redis pub/sub → Flutter(STOMP/WebSocket).
실시간 현재가 = Redis 캐시, DB = 1분봉 요약만.

## PostgreSQL 운영 메모
- 자체 호스팅(docker compose `postgres:16-alpine`, 도커 볼륨 영속) — 매니지드 무료 티어 제약(자동 일시정지·용량 한도) 없음, 오프라인 개발 가능.
- 인증·접근통제 경계는 **Spring**. 실시간은 Redis. (DB 고유 부가기능 비의존 — 변동 없음)
- 백업은 필요 시 `pg_dump`. 매니지드(Supabase/RDS 등) 전환은 JDBC URL 교체만으로 가능하도록 표준 Postgres 기능만 사용.

## nginx 라우팅
`/api/**` → backend · `/ws/**` → backend(WebSocket upgrade) · `/ai/**` → 현재 backend, 추후 FastAPI 사이드카
