# GrowAnt 백로그 — 실사용 테스트 피드백

> 마켓 REST 슬라이스 병합(PR #3) 후 iPhone 17 시뮬레이터 실사용 테스트에서 도출 (2026-06-07).
> 구현은 추후 진행 — 각 신규 기능은 brainstorming → spec → plan → 구현 사이클을 따른다. 버그는 바로 수정 가능.

## 🐞 버그
- **B1. 홈 '관심 종목' 탭 진입 안 됨**
  - 원인: `frontend/lib/features/home/home_screen.dart`의 `_StockRow`에 `onTap` 없음.
  - 수정: `_StockRow`를 탭 가능하게 → `StockDetailScreen(ticker: stock.ticker)` 연결. (간단)
- **B2. 배당금 일정 화면 UI 깨짐**
  - 원인: `frontend/lib/features/trading/dividend_screen.dart`가 `Scaffold`/`AppBar` 없이 `ListView`만 반환. push 라우트인데 tab-body 스타일이라 앱바·백버튼이 없고 콘텐츠가 상태바에 물림.
  - 수정: `Scaffold(appBar: AppBar(title: Text('배당금 일정')), body: ListView(...))`로 래핑.
  - 점검: 같은 방식으로 push되는 형제 화면 `exchange_screen.dart`, `subscription_screen.dart`도 동일 누락인지 확인.

## ✨ 개선
- **E1. 모든 화면 상단 폰트 개선**
  - 위치: `frontend/lib/core/theme.dart` (AppBarTheme + 타이틀). 폰트 TODO 주석 존재(제주고딕/프리텐다드).
  - 결정 필요: 폰트 선택(Pretendard / Noto Sans KR 등) + 도입 방식(`google_fonts` 패키지 vs 번들 asset).

## 🆕 신규 화면 / 기능
- **N1. 주식 상세 → '상세정보' 페이지**
  - 현재 상세 본문의 52주 최고/최저·거래량·시가총액·PER·PBR(`_InfoRow` 6개)을 상세 화면 **우상단 액션 → 별도 '상세정보' 페이지**로 이동, 본문에서는 제거.
  - 데이터: `StockDetail`에 이미 존재. 신규 페이지 + AppBar 액션 + 네비게이션만. (중간)
- **N2. 내역 항목 → 거래 상세 페이지**
  - `frontend/lib/features/trading/trade_history_screen.dart`의 `_TradeTile`에 onTap + 신규 거래 상세 화면.
  - 데이터: `Trade`(종목/매수매도/단가/수량/금액/시각) mock + 파생 계산값. (중간)
- **N3. AI 피드백 → 피드백 상세 페이지**
  - `frontend/lib/features/ai/ai_feedback_screen.dart`의 `_FeedbackCard` 탭 → 상세.
  - 결정 필요: 상세 콘텐츠 — 현재 `AiFeedbackItem`은 1줄 `content`만. 확장 설명/근거/관련 거래 등 상세 내용을 mock으로 정의 필요(사용자 메모: "따로 구현 필요").
- **N4. 주식 상세 캔들 차트 기능**
  - 현재: `_MiniChart` 라인 차트(`detail.candles` = close 10개).
  - 결정 필요: 진짜 캔들스틱(OHLC)은 Open/High/Low/Close 필요한데 백엔드는 close만 제공 → ① 백엔드 OHLC 확장 ② 클라 mock 합성 ③ 라인 유지 + 기간선택/인터랙션. (차트 패키지 도입 여부도)
- **N5. 주식 상세 호가창**
  - 백엔드에 호가(bid/ask) 데이터 없음.
  - 결정 필요: ① mock 합성(현재가 ± 호가단위 N단계) ② 백엔드 신규 엔드포인트.

## 열린 결정 요약
1. 폰트 선택 + 도입 방식 (E1)
2. 피드백 상세 콘텐츠 정의 (N3)
3. 캔들 OHLC 데이터 출처 + 차트 패키지 (N4)
4. 호가 데이터 출처 (N5)
5. 백엔드 확장 범위: 현재 백엔드는 마켓 스냅샷만 — 캔들/호가/펀더멘털 확장 시 백엔드 작업 동반 여부.

## 우선순위 제안 (참고)
1순위(버그·빠름): B1, B2 → 2순위(개선): E1 → 3순위(데이터 있는 신규): N1, N2 → 4순위(설계 큰 신규): N3, N4, N5.
