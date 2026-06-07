# 대결 포트폴리오 상세 + AI 따라사기 — 설계

**작성일:** 2026-06-07
**대상:** Flutter 프론트엔드 (`frontend/`)

## 1. 목표

홈 화면 "진행 중인 대결" 카드의 **내 수익률 / AI 수익률**을 각각 탭하면, 해당 측이
어떤 종목을 얼마나 보유해 몇 %의 손익을 내는지 보여주는 **포트폴리오 상세 화면**으로
이동한다. AI 포트폴리오의 각 종목 행에는 **따라사기** 버튼을 두고, 누르면 해당 종목의
상세 화면(`StockDetailScreen`)으로 이동한다.

## 2. 범위 / 제약 (확정 사항)

- **수익률 일치:** 상세 화면의 합산 수익률은 홈 대결 수치(나 +5.2% / AI +3.8%)와 일치한다.
- **AI 종목 소스:** AI 보유 종목은 백엔드 카탈로그 8종목 내에서만 구성한다. 따라서
  따라사기 → `StockDetailScreen(ticker)` 가 항상 정상 로드된다.
- **따라사기 동작:** 해당 종목의 상세 화면으로 이동(navigate)만 한다. 매수 시트 자동
  오픈 등은 하지 않는다.
- **내 종목 탭:** '나' 상세의 보유 종목 행은 표시 전용(탭 이동 없음). 따라사기 버튼은
  AI 측에만 존재한다.
- **계정 화면 무수정:** 계정 화면의 기존 `mockHoldings`(애플 포함, 계정 뷰)는 건드리지
  않는다. 본 기능은 "대결 포트폴리오"라는 별도 데이터를 추가한다.
- **mock 일관성:** 모든 데이터는 mock. 보유 종목의 현재가는 홈 `mockMarket` 가격과
  동일하게 맞춰 화면 간 일관성을 유지한다.

## 3. 아키텍처 / 접근법

접근법 **A**(단일 파라미터 화면 + 타입드 모델)를 채택한다.

- 나/AI는 레이아웃이 거의 동일하므로 **하나의 화면**(`PortfolioDetailScreen`)을
  `isAi` 플래그로 분기한다. (따라사기 버튼 유무만 다름)
- 보유 종목 데이터는 **타입드 `Holding` 모델**로 표현하고, 대결용 mock 리스트 2개를
  새로 둔다. 계정 화면은 영향받지 않는다.
- 합산 손익/수익률은 **순수 함수**로 분리해 UI 없이 단위 테스트한다.

## 4. 데이터 모델

`lib/data/mock/mock_data.dart`에 다음을 추가한다. (기존 `mockHoldings`는 그대로 둔다.)

```dart
class Holding {
  final String ticker;
  final String name;
  final int qty;
  final int avgPrice;     // 평균 매입 단가
  final int currentPrice; // 현재가 (홈 mockMarket과 일치)
  const Holding(this.ticker, this.name, this.qty, this.avgPrice, this.currentPrice);
}
```

### 4.1 `mockMyHoldings` — 합산 +5.2%

검증: 평가손익 합 +142,600원 / 매입금액 합 2,739,200원 = **+5.21%** → 표시 "5.2%"

| 티커 | 종목 | 수량 | 평균가 | 현재가 |
|------|------|-----:|-------:|-------:|
| 005930 | 삼성전자 | 12 | 70,000 | 76,300 |
| 000660 | SK하이닉스 | 4 | 185,000 | 178,500 |
| 035420 | NAVER | 3 | 189,000 | 198,400 |
| 000270 | 기아 | 6 | 98,700 | 109,500 |

### 4.2 `mockAiHoldings` — 합산 +3.8% (전부 카탈로그 8종목 내)

검증: 평가손익 합 +117,200원 / 매입금액 합 3,086,200원 = **+3.80%** → 표시 "3.8%"

| 티커 | 종목 | 수량 | 평균가 | 현재가 |
|------|------|-----:|-------:|-------:|
| 005930 | 삼성전자 | 8 | 73,500 | 76,300 |
| 051910 | LG화학 | 3 | 272,000 | 278,000 |
| 068270 | 셀트리온 | 5 | 192,000 | 187,000 |
| 035720 | 카카오 | 20 | 36,110 | 41,200 |

양측 모두 이익·손실 종목을 섞어 사실감을 둔다.

## 5. 컴포넌트

### 5.1 합산 계산 순수 함수 (`portfolio_detail_screen.dart` 최상위)

```dart
int portfolioCost(List<Holding> hs)   => hs.fold(0, (s, h) => s + h.avgPrice * h.qty);
int portfolioValue(List<Holding> hs)  => hs.fold(0, (s, h) => s + h.currentPrice * h.qty);
int portfolioProfit(List<Holding> hs) => portfolioValue(hs) - portfolioCost(hs);
double portfolioReturnRate(List<Holding> hs) {
  final cost = portfolioCost(hs);
  return cost == 0 ? 0 : portfolioProfit(hs) / cost * 100;
}
```

### 5.2 `PortfolioDetailScreen`

`lib/features/duel/portfolio_detail_screen.dart` (신규). StatelessWidget.

생성자: `PortfolioDetailScreen({required String title, required List<Holding> holdings, required bool isAi})`

구성:
- `Scaffold` + `AppBar(title: Text(title))`
- 본문 `ListView`:
  1. **요약 카드**: 합산 평가손익(원) + 합산 수익률(%) — 수익률 색상은 손익 부호에 따라
     `upColor`/`downColor`. 보조로 총 매입금액 / 평가금액 표시.
  2. **보유 종목 행 리스트**: 각 `Holding`마다
     - 좌: 종목명, `{qty}주 · 평균 {avgPrice}원`
     - 우: 평가금액(`currentPrice*qty`), 평가손익(원) + 종목 수익률(%) — 색상 처리
     - `isAi == true`이면 우측 끝에 **따라사기** 버튼(컴팩트). onPressed →
       `Navigator.push(MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: h.ticker)))`
     - `isAi == false`이면 버튼 없음, 행 탭 없음.

스타일은 계정 화면 `_HoldingRow`(흰 카드, 1px `#EEEEEE` 보더, 빨강/파랑 손익)를 차용한다.

### 5.3 홈 연결 (`lib/features/home/home_screen.dart`)

- `_DuelStat`에 `VoidCallback? onTap` 추가. `onTap`이 있으면 `InkWell`로 감싸고
  우상단에 옅은 `Icons.chevron_right`(예: `Color(0xFFBBBBBB)`, size 16)로 탭 가능 표시.
- 호출부:
  - '나' 카드: `onTap: () => Navigator.push(... PortfolioDetailScreen(title: '내 포트폴리오', holdings: mockMyHoldings, isAi: false))`
  - '대결 AI' 카드: `onTap: () => Navigator.push(... PortfolioDetailScreen(title: 'AI 포트폴리오', holdings: mockAiHoldings, isAi: true))`

## 6. 데이터 흐름

홈 `_DuelStat` 탭 → `PortfolioDetailScreen` push(해당 mock 리스트 전달) → 화면에서 순수
함수로 합산 계산·렌더 → (AI 한정) 따라사기 탭 → `StockDetailScreen(ticker)` push →
기존 `stockDetailProvider`가 GET /api/market/{ticker} 호출.

## 7. 에러 처리

- 상세 화면은 mock·동기 데이터만 사용 → 자체 로딩/에러 상태 없음.
- 따라사기로 진입하는 `StockDetailScreen`은 기존 `ErrorView`로 자체 로딩·에러를 처리한다.
  AI 종목은 카탈로그 내이므로 `INVALID_TICKER` 없이 정상 로드된다.

## 8. 테스트

`frontend/test/`에 추가한다.

1. **합산 순수 함수 테스트** (`portfolio_summary_test.dart`)
   - `portfolioReturnRate(mockMyHoldings)`를 소수 1자리로 반올림하면 `5.2`
   - `portfolioReturnRate(mockAiHoldings)`를 소수 1자리로 반올림하면 `3.8`
   - `portfolioProfit(mockMyHoldings) == 142600`, `portfolioProfit(mockAiHoldings) == 117200`

2. **위젯 테스트** (`portfolio_detail_screen_test.dart`)
   - `isAi: true` 렌더 시 "따라사기" 버튼이 `mockAiHoldings.length`개 존재
   - `isAi: false` 렌더 시 "따라사기" 버튼 0개
   - 보유 종목명(예: '삼성전자')과 합산 수익률 텍스트가 표시됨

> 따라사기 탭 → 네비게이션 검증은 `StockDetailScreen`이 `ProviderScope`/dio에 의존하므로
> 버튼 존재·콜백 확인으로 갈음한다(통합 테스트 비용 회피, YAGNI).

## 9. 파일 변경 요약

- 수정: `lib/data/mock/mock_data.dart` (`Holding` 모델 + `mockMyHoldings` + `mockAiHoldings` 추가)
- 신규: `lib/features/duel/portfolio_detail_screen.dart`
- 수정: `lib/features/home/home_screen.dart` (`_DuelStat` 탭 + 두 호출부 연결)
- 신규: `test/portfolio_summary_test.dart`, `test/portfolio_detail_screen_test.dart`

백엔드 변경 없음.
