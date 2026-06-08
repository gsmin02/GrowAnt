# 홈 관심 종목 → 마켓 API 이전 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈 '관심 종목' 섹션을 mock(`mockMarket`) 대신 기존 `marketListProvider`(GET /api/market) 상위 3종목으로 표시한다.

**Architecture:** 관심 종목 카드를 공개 `WatchlistCard`(ConsumerWidget)로 추출해 `marketListProvider`를 구독(컴팩트 인라인 로딩/에러). 홈은 인라인 섹션을 `WatchlistCard`로 교체하고, 이전 후 죽은 `mockMarket`·`Stock`을 제거한다. 백엔드 변경 없음.

**Tech Stack:** Flutter (Dart ^3.5), flutter_riverpod, intl, flutter_test. 기존 마켓 데이터 레이어(`marketListProvider`/`MarketRow`/`MarketRepository`/`ApiException`) 재사용.

**Spec:** `docs/superpowers/specs/2026-06-07-home-watchlist-market-api-design.md`

**작업 디렉터리:** 모든 `flutter` 명령은 `frontend/`에서 실행. git 커밋도 `frontend/`에서 실행(경로는 frontend 기준 상대).

---

## File Structure

- `frontend/lib/features/home/widgets/watchlist_card.dart` — (신규) `WatchlistCard`(공개 ConsumerWidget) + `_WatchlistError` + `_StockRow`(MarketRow).
- `frontend/test/features/home/watchlist_card_test.dart` — (신규) FakeRepo 오버라이드 위젯 테스트.
- `frontend/lib/features/home/home_screen.dart` — (수정) 관심 종목 섹션 → `WatchlistCard`, 기존 `_StockRow` 삭제, import 교체.
- `frontend/lib/data/mock/mock_data.dart` — (수정) `mockMarket`·`Stock` 제거, `Holding` 주석 수정.

---

## Task 1: WatchlistCard 위젯 + 테스트

**Files:**
- Create: `frontend/lib/features/home/widgets/watchlist_card.dart`
- Test: `frontend/test/features/home/watchlist_card_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `frontend/test/features/home/watchlist_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/home/widgets/watchlist_card.dart';
import 'package:growant/features/market/application/market_providers.dart';
import 'package:growant/features/market/data/market_models.dart';
import 'package:growant/features/market/data/market_repository.dart';

class _FakeRepo implements MarketRepository {
  final List<MarketRow>? rows;
  final Object? error;
  _FakeRepo({this.rows, this.error});

  @override
  Future<List<MarketRow>> fetchMarket() async {
    if (error != null) throw error!;
    return rows!;
  }

  @override
  Future<StockDetail> fetchDetail(String ticker) async => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(MarketRepository repo) => ProviderScope(
      overrides: [marketRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: WatchlistCard())),
    );

void main() {
  const four = [
    MarketRow(ticker: '005930', name: '삼성전자', price: 76300, changeRate: 5.97),
    MarketRow(ticker: '000660', name: 'SK하이닉스', price: 178500, changeRate: 3.41),
    MarketRow(ticker: '035720', name: '카카오', price: 41200, changeRate: -2.10),
    MarketRow(ticker: '035420', name: 'NAVER', price: 198400, changeRate: 1.55),
  ];

  testWidgets('상위 3종목만 렌더하고 4번째는 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(rows: four)));
    await tester.pump(); // loading -> data
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('SK하이닉스'), findsOneWidget);
    expect(find.text('카카오'), findsOneWidget);
    expect(find.text('NAVER'), findsNothing); // take(3)
  });

  testWidgets('로딩 중에는 스피너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(rows: four)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // 보류된 future 정리
  });

  testWidgets('에러 시 메시지와 재시도 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
        eventType: 'MARKET_ERROR',
        code: 'MARKET_DATA_UNAVAILABLE',
        message: '시세 서비스 점검 중',
        retryable: true,
      ),
    )));
    await tester.pump(); // loading -> error
    expect(find.text('시세 서비스 점검 중'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '재시도'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/features/home/watchlist_card_test.dart`
Expected: FAIL — 컴파일 에러(`WatchlistCard` 미정의).

- [ ] **Step 3: Create the WatchlistCard widget**

Create `frontend/lib/features/home/widgets/watchlist_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../market/application/market_providers.dart';
import '../../market/data/market_models.dart';
import '../../market/stock_detail_screen.dart';

/// 홈 '관심 종목' 카드 — marketListProvider(GET /api/market) 상위 3종목.
/// 임베드 카드라 로딩/에러는 컴팩트 인라인으로 처리(전체 ErrorView 미사용).
class WatchlistCard extends ConsumerWidget {
  const WatchlistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketListProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('관심 종목',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          async.when(
            loading: () => const SizedBox(
              height: 88,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => _WatchlistError(
              message: e is ApiException ? e.message : '시세를 불러오지 못했어요',
              onRetry: (e is ApiException ? e.retryable : true)
                  ? () => ref.read(marketListProvider.notifier).refresh()
                  : null,
            ),
            data: (rows) => Column(
              children: [
                for (final r in rows.take(3)) _StockRow(row: r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 내부 컴팩트 에러(메시지 + 재시도). retryable=false면 메시지만.
class _WatchlistError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _WatchlistError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('재시도'),
            ),
        ],
      ),
    );
  }
}

/// 관심 종목 행 — MarketRow 기반. 탭 시 종목 상세로 이동.
class _StockRow extends StatelessWidget {
  final MarketRow row;
  const _StockRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final isUp = row.changeRate >= 0;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: row.ticker)),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(row.ticker,
                      style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${fmt.format(row.price)}원',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${isUp ? '+' : ''}${row.changeRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: isUp ? upColor : downColor, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/features/home/watchlist_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Static analysis**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`
(이 시점에는 `mockMarket`/`Stock`이 아직 존재하고 home도 그대로라 앱은 정상 컴파일된다. `WatchlistCard`는 테스트가 사용하므로 미사용 경고 없음.)

- [ ] **Step 6: Commit**

```bash
cd frontend && git add lib/features/home/widgets/watchlist_card.dart test/features/home/watchlist_card_test.dart
git commit -m "feat(home): 관심 종목 WatchlistCard(marketListProvider 구독) + 테스트"
```

---

## Task 2: 홈 연결 + 죽은 mock 제거

**Files:**
- Modify: `frontend/lib/features/home/home_screen.dart`
- Modify: `frontend/lib/data/mock/mock_data.dart`

이 task는 새 로직이 없다(통합 + 데드코드 제거). `WatchlistCard` 동작은 Task 1에서 검증됐고, 본 task는 `flutter analyze` + 전체 `flutter test`로 검증한다.

- [ ] **Step 1: home_screen.dart — import 교체**

`frontend/lib/features/home/home_screen.dart`에서 이 import 줄을 삭제:

```dart
import '../market/stock_detail_screen.dart';
```

그리고 다음 import를 추가(예: `import '../duel/portfolio_detail_screen.dart';` 줄 바로 아래):

```dart
import 'widgets/watchlist_card.dart';
```

- [ ] **Step 2: home_screen.dart — 관심 종목 섹션 교체**

다음 블록(관심 종목 `_SectionCard`)을 찾아서:

```dart
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('관심 종목',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              for (final s in mockMarket.take(3)) _StockRow(stock: s),
            ],
          ),
        ),
```

다음 한 줄로 교체:

```dart
        const WatchlistCard(),
```

(앞뒤의 `const SizedBox(height: 12)`는 그대로 둔다.)

- [ ] **Step 3: home_screen.dart — 기존 `_StockRow` 클래스 삭제**

파일 끝의 `_StockRow` 클래스 전체를 삭제한다:

```dart
class _StockRow extends StatelessWidget {
  final Stock stock;
  const _StockRow({required this.stock});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final isUp = stock.changeRate >= 0;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: stock.ticker)),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(stock.ticker,
                      style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${fmt.format(stock.price)}원',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${isUp ? '+' : ''}${stock.changeRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: isUp ? upColor : downColor, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
```

(홈에 남는 `fmt`(자산 표시), `upColor`/`downColor`(대결·배지), `intl`/`theme`/`mock_data` import는 계속 쓰이므로 유지한다.)

- [ ] **Step 4: mock_data.dart — `Stock` 클래스 제거**

`frontend/lib/data/mock/mock_data.dart` 상단의 `Stock` 클래스 전체(주석 줄 바로 다음, `Holding` 클래스 앞)를 삭제:

```dart
class Stock {
  final String ticker;
  final String name;
  final int price;
  final double changeRate; // %
  const Stock(this.ticker, this.name, this.price, this.changeRate);
}

```

- [ ] **Step 5: mock_data.dart — `mockMarket` 블록 제거**

다음 마켓 블록 전체를 삭제:

```dart
// ── 마켓 ──
// market-slice: 마켓 대시보드는 marketListProvider(GET /api/market)로 이전 완료.
//   mockMarket은 home_screen(상위 3종목)에서 아직 사용 — 추후 home도 API로. 스펙 §4.5
const List<Stock> mockMarket = [
  Stock('005930', '삼성전자', 76300, 5.97),
  Stock('000660', 'SK하이닉스', 178500, 3.41),
  Stock('035720', '카카오', 41200, -2.10),
  Stock('035420', 'NAVER', 198400, 1.55),
  Stock('005380', '현대차', 247000, -0.81),
  Stock('000270', '기아', 109500, 0.37),
  Stock('068270', '셀트리온', 187000, -1.24),
  Stock('051910', 'LG화학', 278000, 2.08),
];

```

- [ ] **Step 6: mock_data.dart — `Holding` 주석 수정**

`Holding` 클래스의 다음 줄을:

```dart
  final int currentPrice; // 현재가 (홈 mockMarket과 일치)
```

다음으로 변경:

```dart
  final int currentPrice; // 현재가 (홈 마켓 시세와 일치)
```

- [ ] **Step 7: Static analysis**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`
(`mockMarket`/`Stock`/`StockDetailScreen` import이 모두 제거되어 미사용 심볼/import 경고가 없어야 한다.)

- [ ] **Step 8: Full test suite**

Run: `cd frontend && flutter test`
Expected: 모든 테스트 PASS (기존 + 신규 watchlist 3).

- [ ] **Step 9: Commit**

```bash
cd frontend && git add lib/features/home/home_screen.dart lib/data/mock/mock_data.dart
git commit -m "refactor(home): 관심 종목을 WatchlistCard로 연결 + 죽은 mockMarket·Stock 제거"
```

---

## Self-Review

**1. Spec coverage:**
- §4.1 WatchlistCard(컴팩트 로딩/에러, take(3)) → Task 1 Step 3. ✓
- §4.2 `_StockRow`(MarketRow) → Task 1 Step 3. ✓
- §4.3 home 섹션 교체 + `_StockRow` 삭제 + import 정리 → Task 2 Step 1~3. ✓
- §4.4 mockMarket·Stock 제거 + Holding 주석 → Task 2 Step 4~6. ✓
- §7 테스트 3종(상위3·로딩·에러) → Task 1 Step 1. ✓
- 대시보드 무변경 / 백엔드 무변경 → 어떤 task도 해당 파일 미수정. ✓

**2. Placeholder scan:** TBD/“적절히” 없음. 모든 코드/edit 블록이 완전. ✓

**3. Type consistency:** `WatchlistCard`(무인자 const), `_StockRow({required MarketRow row})`, `marketListProvider`/`.notifier.refresh()`, `ApiException(eventType,code,message,retryable)`, `MarketRow(ticker,name,price,changeRate)` — 스펙·실제 코드와 일치. import 경로(`../../../core`, `../../market/...`)는 `lib/features/home/widgets/` 기준으로 정확. ✓
