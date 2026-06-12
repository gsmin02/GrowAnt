import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/core/error/error_view.dart';
import 'package:growant/features/trading/application/trading_providers.dart';
import 'package:growant/features/trading/data/trade_models.dart';
import 'package:growant/features/trading/data/trade_repository.dart';
import 'package:growant/features/trading/trade_history_screen.dart';

const _trades = [
  Trade(name: '삼성전자', isBuy: false, price: 76300, qty: 10, amount: 763000, time: '05.10 14:32'),
  Trade(name: '카카오', isBuy: true, price: 41200, qty: 10, amount: 412000, time: '05.09 11:45'),
];

class _FakeRepo implements TradeRepository {
  final Object? error;
  final List<Trade> trades;
  _FakeRepo({this.error, this.trades = _trades});

  @override
  Future<List<Trade>> fetchTrades() async {
    if (error != null) throw error!;
    return trades;
  }

  @override
  Future<Trade> placeOrder({required String ticker, required bool isBuy, required int qty}) async =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(TradeRepository repo) => ProviderScope(
      overrides: [tradeRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: TradeHistoryScreen())),
    );

void main() {
  testWidgets('내역 목록과 매수/매도 요약을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pump();
    expect(find.text('삼성전자'), findsOneWidget);
    expect(find.text('카카오'), findsOneWidget);
    expect(find.text('총 매수'), findsOneWidget);
    expect(find.text('총 매도'), findsOneWidget);
    // 합산 검증 — 같은 금액 문자열이 요약 바와 해당 거래 타일에 각 1번씩 렌더된다.
    expect(find.text('412,000원'), findsNWidgets(2)); // 총 매수(카카오 매수 1건) + 타일
    expect(find.text('763,000원'), findsNWidgets(2)); // 총 매도(삼성전자 매도 1건) + 타일
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('로딩 중에는 스피너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // 보류된 future 정리
  });

  testWidgets('에러 시 ErrorView와 재시도 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'SYSTEM_ERROR', code: 'SERVICE_UNAVAILABLE', message: '잠시 후 다시 시도해 주세요.', retryable: true),
    )));
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('retryable=false 에러는 재시도 버튼을 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'AUTH_ERROR', code: 'UNAUTHENTICATED', message: '로그인이 필요합니다.', retryable: false),
    )));
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsNothing);
  });

  testWidgets('내역이 없으면 빈 상태 문구를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(trades: const [])));
    await tester.pump();
    expect(find.text('거래 내역이 없습니다'), findsOneWidget);
    expect(find.text('총 매수'), findsNothing); // 요약 바 생략
  });
}
