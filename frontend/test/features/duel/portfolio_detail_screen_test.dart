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
    expect(find.text('삼성전자'), findsOneWidget);
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
