import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/market/application/market_providers.dart';
import 'package:growant/features/market/data/market_models.dart';
import 'package:growant/features/market/data/market_repository.dart';
import 'package:growant/features/market/stock_detail_screen.dart';
import 'package:growant/features/trading/application/trading_providers.dart';
import 'package:growant/features/trading/data/trade_models.dart';
import 'package:growant/features/trading/data/trade_repository.dart';

const _detail = StockDetail(
  ticker: '005930', name: '삼성전자', price: 76300, changeRate: 5.97,
  candles: [76300, 76100, 75900, 76000, 75800, 75600, 75900, 76200, 76100, 76300],
  high52w: 90034, low52w: 54936, volume: 14823410, marketCapEok: 455494465, per: 12.4, pbr: 1.2,
);

class _FakeMarketRepo implements MarketRepository {
  @override
  Future<StockDetail> fetchDetail(String ticker) async => _detail;
  @override
  Future<List<MarketRow>> fetchMarket() async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeTradeRepo implements TradeRepository {
  final Object? error;
  ({String ticker, bool isBuy, int qty})? last;
  _FakeTradeRepo({this.error});

  @override
  Future<Trade> placeOrder({required String ticker, required bool isBuy, required int qty}) async {
    last = (ticker: ticker, isBuy: isBuy, qty: qty);
    if (error != null) throw error!;
    return Trade(name: '삼성전자', isBuy: isBuy, price: 76300, qty: qty, amount: 76300 * qty, time: '06.09 12:00');
  }

  @override
  Future<List<Trade>> fetchTrades() async => [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(_FakeTradeRepo tradeRepo) => ProviderScope(
      overrides: [
        marketRepositoryProvider.overrideWithValue(_FakeMarketRepo()),
        tradeRepositoryProvider.overrideWithValue(tradeRepo),
      ],
      child: const MaterialApp(home: StockDetailScreen(ticker: '005930')),
    );

void main() {
  testWidgets('매수 주문 성공 - repo 호출, 시트 닫힘, 체결 스낵바', (tester) async {
    final repo = _FakeTradeRepo();
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '매수'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '매수 주문'));
    await tester.pumpAndSettle();
    expect(repo.last, (ticker: '005930', isBuy: true, qty: 1));
    expect(find.text('매수 체결: 삼성전자 1주'), findsOneWidget);
    expect(find.text('주문 금액'), findsNothing); // 시트 닫힘
  });

  testWidgets('주문 실패 - 에러 메시지 스낵바, 시트 유지', (tester) async {
    final repo = _FakeTradeRepo(
      error: const ApiException(
          eventType: 'ORDER_ERROR', code: 'ORDER_INSUFFICIENT_FUNDS', message: '잔고가 부족합니다.', retryable: false),
    );
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '매수'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '매수 주문'));
    await tester.pumpAndSettle();
    expect(find.text('잔고가 부족합니다.'), findsOneWidget);
    expect(find.text('주문 금액'), findsOneWidget); // 시트 유지
  });
}
