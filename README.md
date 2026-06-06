# GrowAnt 🐜

AI와 투자 대결하는 모의투자 앱 — 초보 투자자의 매매 타이밍 연습 + AI 피드백.

## 구조
- `backend/` Spring Boot 4 (Kotlin, JDK 21)
- `frontend/` Flutter 3.44
- `infra/` nginx
- `docs/` 설계 문서 (Track A)

## 사전 준비 (팀 PC)
- JDK 21, Flutter 3.44, Docker
- (선택) Supabase 프로젝트 — `.env`는 `.env.example` 참고해 작성

## 실행
```bash
# 인프라 + 백엔드 + Redis
docker compose up -d

# 백엔드 단독
cd backend && ./gradlew bootRun

# 프론트
cd frontend && flutter pub get && flutter run
```

시세는 현재 **시뮬레이션**(`MARKET_PROVIDER=sim`)으로 동작합니다. KIS 전환은 `MarketDataProvider` 구현 교체만으로 가능합니다.

## 문서
`docs/ARCHITECTURE.md` · `docs/ENTITLEMENT.md` · `docs/AI_ROLES.md` · `docs/SCREENS.md`
