import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/features/market/application/market_providers.dart';
import 'package:growant/features/market/data/market_models.dart';
import 'package:growant/features/market/data/market_repository.dart';
import 'package:growant/features/market/market_dashboard_screen.dart';

class _FakeRepo implements MarketRepository {
  @override
  Future<List<MarketRow>> fetchMarket() async =>
      const [MarketRow(ticker: '005930', name: '삼성전자', price: 76300, changeRate: 5.97)];
  @override
  Future<StockDetail> fetchDetail(String ticker) async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('dashboard renders rows from provider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [marketRepositoryProvider.overrideWithValue(_FakeRepo())],
      child: const MaterialApp(home: Scaffold(body: MarketDashboardScreen())),
    ));
    await tester.pump(); // loading -> data
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('76,300원'), findsOneWidget);
  });
}
