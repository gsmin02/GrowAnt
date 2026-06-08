# 홈 관심 종목 → 마켓 API 이전 — 설계

**작성일:** 2026-06-07
**대상:** Flutter 프론트엔드 (`frontend/`)

## 1. 목표

홈 화면 "관심 종목" 섹션을 mock(`mockMarket.take(3)`) 대신 기존 `marketListProvider`
(GET /api/market) 기반으로 이전한다. 마켓 대시보드가 이미 쓰는 동일 provider를 재사용하여
홈도 실시세를 표시한다. 퀵윈 수직 슬라이스 — 백엔드 변경 없음.

## 2. 범위 / 제약 (확정 사항)

- **위젯 범위:** 관심 종목 카드만 별도 공개 `ConsumerWidget`(`WatchlistCard`)으로 추출한다.
  `HomeScreen`은 `StatelessWidget`으로 유지(자산·대결 등 mock 영역은 그대로). 변경 최소화.
- **로딩/에러 UX:** 임베드된 작은 카드이므로 **컴팩트 인라인** 처리.
  - 로딩: 고정 높이 박스 안 작은 중앙 스피너(레이아웃 점프 방지).
  - 에러: 카드 내부 한 줄 메시지 + **재시도** 버튼(provider refresh). 전체 `ErrorView`는 쓰지 않음.
- **죽은 mock 정리:** 이전 후 미사용이 되는 `mockMarket` 상수와 `Stock` 클래스를 제거한다
  (확인: 둘 다 홈에서만 사용). `_StockRow`는 `MarketRow`를 받도록 교체.
- **표시 개수:** API 응답 순서 기준 상위 3종목 미리보기 유지(`take(3)`).
- **대시보드 무변경:** `MarketDashboardScreen`은 기존 full `ErrorView`/중앙 스피너 그대로 둔다.
- **백엔드 무변경.**

## 3. 아키텍처 / 접근법

접근법 **A**(전용 `WatchlistCard` 위젯 추출)를 채택한다.

- 관심 종목 카드를 `lib/features/home/widgets/watchlist_card.dart`의 공개
  `WatchlistCard extends ConsumerWidget`으로 분리 → 단독 위젯 테스트 가능
  (market_dashboard_test와 동일한 FakeRepo + ProviderScope 오버라이드 패턴).
- 홈은 인라인 관심 종목 `_SectionCard` 블록을 `const WatchlistCard()`로 교체.
- `WatchlistCard`는 `marketListProvider`를 `when()`으로 구독해 상태별 렌더.

## 4. 컴포넌트

### 4.1 `WatchlistCard` (신규)

`lib/features/home/widgets/watchlist_card.dart` — `ConsumerWidget`.

흰색 카드(기존 홈 `_SectionCard`와 동일 데코: `Colors.white`, `BorderRadius.circular(12)`,
`Border.all(Color(0xFFEEEEEE))`, padding 16) 안에:

- 헤더 텍스트 **"관심 종목"** (`fontWeight: bold, fontSize: 15`).
- `SizedBox(height: 8)`.
- `ref.watch(marketListProvider).when(...)`:
  - **data(rows):** `for (final r in rows.take(3)) _StockRow(row: r)`
  - **loading:** `SizedBox(height: 88, child: Center(child: SizedBox(width: 22, height: 22,
    child: CircularProgressIndicator(strokeWidth: 2))))`
  - **error(e, _):** 컴팩트 행 — 좌측 메시지(`e is ApiException ? e.message : '시세를 불러오지 못했어요'`),
    우측 `TextButton('재시도', onPressed: () => ref.read(marketListProvider.notifier).refresh())`.
    `(e is ApiException ? e.retryable : true)`가 false면 재시도 버튼 숨김(메시지만).

### 4.2 `_StockRow` (이동 + 타입 교체)

`watchlist_card.dart`의 private 위젯으로 이동. 기존 홈의 `_StockRow`와 동일 레이아웃
(이름·티커 2줄, 우측 가격·등락률, 끝에 `chevron_right`, `InkWell` 탭 → `StockDetailScreen`),
필드만 `final Stock stock` → `final MarketRow row`로 교체하고 `stock.*` 참조를 `row.*`로 변경.
색상은 `upColor`/`downColor`(등락률 부호 기준), 가격은 `NumberFormat('#,###')`.

### 4.3 `home_screen.dart` (수정)

- 관심 종목 `_SectionCard(child: Column(헤더 + for mockMarket.take(3) _StockRow))` 블록을
  `const WatchlistCard()`로 교체.
- 홈에 있던 `_StockRow` 클래스 삭제(watchlist_card로 이동).
- 더 이상 필요 없어진 import 정리(`mock_data`는 자산/대결 등에서 계속 사용하므로 유지).
- `watchlist_card.dart` import 추가.

### 4.4 `mock_data.dart` (정리)

- `mockMarket` 상수, `Stock` 클래스, 관련 주석(market-slice 주석 블록) 제거.
- `Holding.currentPrice` 주석 `// 현재가 (홈 mockMarket과 일치)` → `// 현재가 (홈 마켓 시세와 일치)`.

## 5. 데이터 흐름

`WatchlistCard` → `ref.watch(marketListProvider)` (대시보드와 동일 인스턴스, Riverpod 캐시 공유 →
탭 전환 시 재요청 없음) → `when()` 분기. 재시도 시 `marketListProvider.notifier.refresh()`.
행 탭 → `StockDetailScreen(ticker: row.ticker)` (`stockDetailProvider`로 상세 로드).

## 6. 에러 처리

- 카드 자체 컴팩트 인라인(메시지 + 재시도). `ApiException.message`/`retryable` 활용.
- 전체 화면 `ErrorView`는 홈 카드에선 사용하지 않음(대시보드는 기존대로 유지).

## 7. 테스트

`frontend/test/features/home/watchlist_card_test.dart` (신규) — market_dashboard_test 패턴 차용
(`MarketRepository`를 구현한 `_FakeRepo` + `ProviderScope(overrides: [marketRepositoryProvider.overrideWithValue(...)])`).

1. **상위 3종목 렌더 + 4번째 미표시:** FakeRepo가 4개 행 반환 → `pump()` 후 상위 3개 종목명
   `findsOneWidget`, 4번째 종목명 `findsNothing`.
2. **에러 + 재시도:** FakeRepo가 `ApiException` throw → 에러 메시지와 '재시도' 버튼이 표시됨.
3. **로딩:** 첫 `pump()`(settle 전) 시 `CircularProgressIndicator` 표시.

## 8. 파일 변경 요약

- 신규: `frontend/lib/features/home/widgets/watchlist_card.dart`
- 수정: `frontend/lib/features/home/home_screen.dart` (섹션 → `WatchlistCard`, `_StockRow` 삭제)
- 수정: `frontend/lib/data/mock/mock_data.dart` (`mockMarket`·`Stock` 제거, 주석 수정)
- 신규: `frontend/test/features/home/watchlist_card_test.dart`

백엔드 변경 없음.
