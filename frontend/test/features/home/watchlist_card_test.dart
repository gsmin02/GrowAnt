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

  testWidgets('retryable=false 에러는 재시도 버튼을 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
        eventType: 'VALIDATION_ERROR',
        code: 'INVALID_TICKER',
        message: '잘못된 요청',
        retryable: false,
      ),
    )));
    await tester.pump(); // loading -> error
    expect(find.text('잘못된 요청'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '재시도'), findsNothing);
  });
}
