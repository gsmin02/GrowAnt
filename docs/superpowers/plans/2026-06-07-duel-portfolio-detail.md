# 대결 포트폴리오 상세 + AI 따라사기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈 대결의 내/AI 수익률을 탭하면 보유 종목·수익률 상세 화면으로 이동하고, AI 종목 행의 따라사기 버튼으로 해당 종목 상세 화면으로 진입한다.

**Architecture:** 타입드 `Holding` 모델과 대결용 mock 리스트 2개(`mockMyHoldings` +5.2%, `mockAiHoldings` +3.8%)를 추가하고, 나/AI 공용 `PortfolioDetailScreen`(`isAi` 플래그로 따라사기 버튼 분기)을 만든다. 합산 손익/수익률은 순수 함수로 분리해 단위 테스트한다. 계정 화면·백엔드는 변경하지 않는다.

**Tech Stack:** Flutter (Dart ^3.5), flutter_test, intl. 모든 데이터는 mock(동기).

**Spec:** `docs/superpowers/specs/2026-06-07-duel-portfolio-detail-design.md`

**작업 디렉터리:** 모든 `flutter` 명령은 `frontend/`에서 실행한다.

---

## File Structure

- `frontend/lib/data/mock/mock_data.dart` — (수정) `Holding` 모델 + `mockMyHoldings` + `mockAiHoldings` 추가. 기존 `mockHoldings`는 그대로.
- `frontend/lib/features/duel/portfolio_detail_screen.dart` — (신규) 합산 순수 함수 + `PortfolioDetailScreen` 위젯.
- `frontend/lib/features/home/home_screen.dart` — (수정) `_DuelStat` 탭 가능화 + 두 호출부 연결.
- `frontend/test/features/duel/portfolio_summary_test.dart` — (신규) 합산 함수·mock 검증.
- `frontend/test/features/duel/portfolio_detail_screen_test.dart` — (신규) 위젯 렌더·따라사기 버튼 분기.

---

## Task 1: 데이터 모델 + 합산 순수 함수

**Files:**
- Modify: `frontend/lib/data/mock/mock_data.dart`
- Create: `frontend/lib/features/duel/portfolio_detail_screen.dart`
- Test: `frontend/test/features/duel/portfolio_summary_test.dart`

- [ ] **Step 1: Write the failing test**

Create `frontend/test/features/duel/portfolio_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/data/mock/mock_data.dart';
import 'package:growant/features/duel/portfolio_detail_screen.dart';

void main() {
  test('mockMyHoldings는 합산 +5.2%', () {
    expect(portfolioProfit(mockMyHoldings), 142600);
    expect(portfolioReturnRate(mockMyHoldings).toStringAsFixed(1), '5.2');
  });

  test('mockAiHoldings는 합산 +3.8%', () {
    expect(portfolioProfit(mockAiHoldings), 117200);
    expect(portfolioReturnRate(mockAiHoldings).toStringAsFixed(1), '3.8');
  });

  test('AI 보유 종목은 모두 거래 가능 카탈로그 8종목 내', () {
    const catalog = {
      '005930', '000660', '035720', '035420',
      '005380', '000270', '068270', '051910',
    };
    for (final h in mockAiHoldings) {
      expect(catalog.contains(h.ticker), isTrue, reason: '${h.ticker} not in catalog');
    }
  });

  test('portfolioValue/Cost 합산', () {
    expect(portfolioCost(mockMyHoldings), 2739200);
    expect(portfolioValue(mockMyHoldings), 2881800);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/features/duel/portfolio_summary_test.dart`
Expected: FAIL — 컴파일 에러(`Holding`, `mockMyHoldings`, `portfolioProfit` 등 미정의).

- [ ] **Step 3: Add the Holding model + mock lists**

In `frontend/lib/data/mock/mock_data.dart`, add the `Holding` class right after the `Stock` class (around line 9):

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

Then add the two mock lists immediately after the `// ── 홈 / 대결 ──` block (after the `mockDuelDDay` line, around line 68):

```dart
// ── 대결 포트폴리오 (보유 종목 상세) ──
// 합산 수익률은 홈 대결 수치와 일치: mockMyHoldings +5.2%, mockAiHoldings +3.8%.
// AI는 마켓 카탈로그 8종목 내에서만 구성 → 따라사기 시 종목 상세 정상 로드.
const List<Holding> mockMyHoldings = [
  Holding('005930', '삼성전자', 12, 70000, 76300),
  Holding('000660', 'SK하이닉스', 4, 185000, 178500),
  Holding('035420', 'NAVER', 3, 189000, 198400),
  Holding('000270', '기아', 6, 98700, 109500),
];

const List<Holding> mockAiHoldings = [
  Holding('005930', '삼성전자', 8, 73500, 76300),
  Holding('051910', 'LG화학', 3, 272000, 278000),
  Holding('068270', '셀트리온', 5, 192000, 187000),
  Holding('035720', '카카오', 20, 36110, 41200),
];
```

- [ ] **Step 4: Create the screen file with pure functions only**

Create `frontend/lib/features/duel/portfolio_detail_screen.dart`:

```dart
import '../../data/mock/mock_data.dart';

/// 보유 종목 합산 계산(순수 함수). UI 없이 단위 테스트 가능.
int portfolioCost(List<Holding> hs) =>
    hs.fold(0, (s, h) => s + h.avgPrice * h.qty);
int portfolioValue(List<Holding> hs) =>
    hs.fold(0, (s, h) => s + h.currentPrice * h.qty);
int portfolioProfit(List<Holding> hs) =>
    portfolioValue(hs) - portfolioCost(hs);
double portfolioReturnRate(List<Holding> hs) {
  final cost = portfolioCost(hs);
  return cost == 0 ? 0 : portfolioProfit(hs) / cost * 100;
}
```

> 위젯(`PortfolioDetailScreen`)은 Task 2에서 이 파일에 추가한다.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd frontend && flutter test test/features/duel/portfolio_summary_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
cd frontend && git add lib/data/mock/mock_data.dart lib/features/duel/portfolio_detail_screen.dart test/features/duel/portfolio_summary_test.dart
git commit -m "feat(duel): Holding 모델 + 대결 포트폴리오 mock(+5.2%/+3.8%) + 합산 함수"
```

---

## Task 2: PortfolioDetailScreen 위젯

**Files:**
- Modify: `frontend/lib/features/duel/portfolio_detail_screen.dart`
- Test: `frontend/test/features/duel/portfolio_detail_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `frontend/test/features/duel/portfolio_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/data/mock/mock_data.dart';
import 'package:growant/features/duel/portfolio_detail_screen.dart';

void main() {
  testWidgets('AI 화면은 따라사기 버튼을 종목 수만큼 렌더하고 합산 +3.8% 표시', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PortfolioDetailScreen(
          title: 'AI 포트폴리오', holdings: mockAiHoldings, isAi: true),
    ));
    expect(find.widgetWithText(OutlinedButton, '따라사기'),
        findsNWidgets(mockAiHoldings.length));
    expect(find.text('+3.8%'), findsOneWidget);
    expect(find.text('삼성전자'), findsWidgets);
  });

  testWidgets('나 화면은 따라사기 버튼이 없고 합산 +5.2% 표시', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PortfolioDetailScreen(
          title: '내 포트폴리오', holdings: mockMyHoldings, isAi: false),
    ));
    expect(find.widgetWithText(OutlinedButton, '따라사기'), findsNothing);
    expect(find.text('+5.2%'), findsOneWidget);
    expect(find.text('삼성전자'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/features/duel/portfolio_detail_screen_test.dart`
Expected: FAIL — `PortfolioDetailScreen` 미정의(컴파일 에러).

- [ ] **Step 3: Replace the screen file with the full implementation**

Overwrite `frontend/lib/features/duel/portfolio_detail_screen.dart` with the complete file (pure functions kept, widget added):

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/mock/mock_data.dart';
import '../market/stock_detail_screen.dart';

/// 보유 종목 합산 계산(순수 함수). UI 없이 단위 테스트 가능.
int portfolioCost(List<Holding> hs) =>
    hs.fold(0, (s, h) => s + h.avgPrice * h.qty);
int portfolioValue(List<Holding> hs) =>
    hs.fold(0, (s, h) => s + h.currentPrice * h.qty);
int portfolioProfit(List<Holding> hs) =>
    portfolioValue(hs) - portfolioCost(hs);
double portfolioReturnRate(List<Holding> hs) {
  final cost = portfolioCost(hs);
  return cost == 0 ? 0 : portfolioProfit(hs) / cost * 100;
}

/// 나/AI 공용 대결 포트폴리오 상세. isAi=true면 각 행에 따라사기 버튼.
class PortfolioDetailScreen extends StatelessWidget {
  final String title;
  final List<Holding> holdings;
  final bool isAi;
  const PortfolioDetailScreen({
    super.key,
    required this.title,
    required this.holdings,
    required this.isAi,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(holdings: holdings, fmt: fmt),
          const SizedBox(height: 16),
          const Text('보유 종목',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          for (final h in holdings) _HoldingCard(holding: h, fmt: fmt, isAi: isAi),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<Holding> holdings;
  final NumberFormat fmt;
  const _SummaryCard({required this.holdings, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final profit = portfolioProfit(holdings);
    final rate = portfolioReturnRate(holdings);
    final isUp = profit >= 0;
    final color = isUp ? upColor : downColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('평가손익',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isUp ? '+' : ''}${fmt.format(profit)}원',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${isUp ? '+' : ''}${rate.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryChip(label: '매입금액', value: '${fmt.format(portfolioCost(holdings))}원'),
              const SizedBox(width: 16),
              _SummaryChip(label: '평가금액', value: '${fmt.format(portfolioValue(holdings))}원'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HoldingCard extends StatelessWidget {
  final Holding holding;
  final NumberFormat fmt;
  final bool isAi;
  const _HoldingCard({required this.holding, required this.fmt, required this.isAi});

  @override
  Widget build(BuildContext context) {
    final h = holding;
    final value = h.currentPrice * h.qty;
    final profit = (h.currentPrice - h.avgPrice) * h.qty;
    final rate = (h.currentPrice - h.avgPrice) / h.avgPrice * 100;
    final isUp = profit >= 0;
    final color = isUp ? upColor : downColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${h.qty}주 · 평균 ${fmt.format(h.avgPrice)}원',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt.format(value)}원',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${isUp ? '+' : ''}${fmt.format(profit)}원 (${rate.toStringAsFixed(1)}%)',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          if (isAi) ...[
            const SizedBox(width: 10),
            _FollowBuyButton(ticker: h.ticker),
          ],
        ],
      ),
    );
  }
}

/// AI 종목 따라사기 → 해당 종목 상세 화면.
class _FollowBuyButton extends StatelessWidget {
  final String ticker;
  const _FollowBuyButton({required this.ticker});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: upColor,
        side: const BorderSide(color: upColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: ticker)),
      ),
      child: const Text('따라사기',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && flutter test test/features/duel/portfolio_detail_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Static analysis**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd frontend && git add lib/features/duel/portfolio_detail_screen.dart test/features/duel/portfolio_detail_screen_test.dart
git commit -m "feat(duel): 포트폴리오 상세 화면(나/AI 공용) + AI 따라사기 버튼"
```

---

## Task 3: 홈 대결 카드 연결

**Files:**
- Modify: `frontend/lib/features/home/home_screen.dart`

- [ ] **Step 1: Add the screen import**

In `frontend/lib/features/home/home_screen.dart`, add this import after the existing `import '../market/stock_detail_screen.dart';` line (line 8):

```dart
import '../duel/portfolio_detail_screen.dart';
```

- [ ] **Step 2: Make `_DuelStat` tappable**

Replace the entire `_DuelStat` class (currently lines 193–225) with:

```dart
class _DuelStat extends StatelessWidget {
  final String label;
  final double value;
  final bool isMe;
  final VoidCallback? onTap;
  const _DuelStat({required this.label, required this.value, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUp = value >= 0;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, size: 15, color: Color(0xFFBBBBBB)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isUp ? upColor : downColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: content);
  }
}
```

- [ ] **Step 3: Wire the two call sites**

In the `build` method, replace the two `_DuelStat` usages (currently lines 59 and 63–64) with:

```dart
                  Expanded(
                    child: _DuelStat(
                      label: '나',
                      value: mockMyReturn,
                      isMe: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PortfolioDetailScreen(
                            title: '내 포트폴리오',
                            holdings: mockMyHoldings,
                            isAi: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DuelStat(
                      label: '대결 AI',
                      value: mockAiReturn,
                      isMe: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PortfolioDetailScreen(
                            title: 'AI 포트폴리오',
                            holdings: mockAiHoldings,
                            isAi: true,
                          ),
                        ),
                      ),
                    ),
                  ),
```

> 기존 `Row`의 children 구조(나 / VS / 대결 AI)를 유지하며 두 `Expanded`만 교체한다.

- [ ] **Step 4: Static analysis**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Full test suite**

Run: `cd frontend && flutter test`
Expected: 모든 테스트 PASS (기존 + 신규 6 테스트).

- [ ] **Step 6: Commit**

```bash
cd frontend && git add lib/features/home/home_screen.dart
git commit -m "feat(home): 대결 카드 내/AI 수익률 탭 → 포트폴리오 상세 진입"
```

---

## Self-Review

**1. Spec coverage:**
- §2 수익률 일치 → Task 1 (mock 값 + 합산 테스트 `5.2`/`3.8`). ✓
- §2 AI 카탈로그 제약 → Task 1 카탈로그 테스트. ✓
- §2 따라사기=상세 이동 → Task 2 `_FollowBuyButton` → `StockDetailScreen`. ✓
- §2 내 종목 표시 전용 → Task 2 `isAi=false`면 버튼 없음 (테스트로 확인). ✓
- §2 계정 화면 무수정 → 어떤 task도 account_screen 미변경. ✓
- §4 데이터 모델 → Task 1. ✓
- §5.1 순수 함수 / §5.2 화면 / §5.3 홈 연결 → Task 1/2/3. ✓
- §8 테스트 2종 → Task 1/2. ✓

**2. Placeholder scan:** TBD/TODO/“적절히” 없음. 모든 코드 단계에 완전한 코드 포함. ✓

**3. Type consistency:** `Holding(ticker,name,qty,avgPrice,currentPrice)`·`portfolioProfit`·`portfolioReturnRate`·`PortfolioDetailScreen({title,holdings,isAi})`·`_DuelStat({...,onTap})` 명칭이 전 task에서 일관. mock 리스트명 `mockMyHoldings`/`mockAiHoldings` 일관. ✓
