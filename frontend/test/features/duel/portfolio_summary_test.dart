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
