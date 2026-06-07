# GrowAnt 백로그 — 실사용 테스트 피드백

> 마켓 REST 슬라이스 병합(PR #3) 후 iPhone 17 시뮬레이터 실사용 테스트에서 도출 (2026-06-07).
> **상태: 8건 전부 구현 완료** (브랜치 `feat/backlog-batch`). 전부 프론트엔드, 백엔드 무변경, mock 일관. `flutter analyze` 무경고 · 프론트 테스트 4/4 통과.

## ✅ 구현 완료

### 🐞 버그
- **B1. 홈 '관심 종목' 탭 진입** — `home_screen` `_StockRow`에 onTap + chevron → `StockDetailScreen(ticker:)` 진입.
- **B2. 배당금 화면 UI 깨짐** — `dividend_screen`을 `Scaffold(AppBar '배당금 일정')`로 래핑. (형제 화면 `exchange`/`subscription`은 이미 Scaffold 보유 → 수정 불필요 확인.)

### ✨ 개선
- **E1. 상단/본문 폰트** — `google_fonts`의 **Noto Sans KR**를 `theme.dart` textTheme + AppBar titleTextStyle에 적용.

### 🆕 신규 화면 / 기능 (전부 mock, 백엔드 무변경)
- **N1. 주식 상세 → '상세 정보' 페이지** — 상세 화면 우상단 `info` 액션 → `stock_info_screen.dart`(52주·거래량·시총·PER·PBR). 본문에선 펀더멘털 제거.
- **N2. 내역 항목 → 거래 상세** — `trade_history` `_TradeTile` onTap → `trade_detail_screen.dart`(단가·수량·금액·mock 수수료·정산금액).
- **N3. AI 피드백 → 피드백 상세** — `AiFeedbackItem.detail` mock 추가 + `_FeedbackCard` onTap → `feedback_detail_screen.dart`(상세 분석).
- **N4. 주식 상세 캔들 차트** — `widgets/candle_chart.dart`: close 시계열에서 종목별 **결정적 OHLC 합성** → 캔들스틱(커스텀 페인터, 양봉 빨강/음봉 파랑). 기존 라인 미니차트 대체.
- **N5. 주식 상세 호가창** — `widgets/order_book.dart`: 현재가 ± 호가단위로 매도 5단/매수 5단 + mock 잔량 바(매도 파랑·매수 빨강, 한국 관습).

## 결정 사항 (구현 시 확정)
- 폰트 = **google_fonts Noto Sans KR** (asset 번들 불필요).
- 캔들 OHLC = **클라이언트 mock 합성**(결정적). 실제 OHLC 연동 시 `CandleChart` 입력만 교체.
- 호가 = **클라이언트 mock**. 실시간 연동 시 `OrderBook` 입력만 교체.
- 피드백 상세 = mock 텍스트(`AiFeedbackItem.detail`).

## 향후 (이 배치 범위 밖)
- 캔들/호가의 실데이터(백엔드 OHLC·실시간 호가) 연동.
- AI 피드백 상세를 실제 LLM 결과로 대체.
- 거래 상세의 실제 체결 내역 연동.
