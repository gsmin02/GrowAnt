import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/duel/application/portfolio_providers.dart';
import 'package:growant/features/duel/data/portfolio_models.dart';
import 'package:growant/features/duel/data/portfolio_repository.dart';
import 'package:growant/features/home/widgets/duel_card.dart';

const _my = Portfolio(returnRate: 5.2, profit: 142600, cost: 2739200, value: 2881800, holdings: []);
const _ai = Portfolio(returnRate: 3.8, profit: 117200, cost: 3086200, value: 3203400, holdings: []);

class _FakeRepo implements PortfolioRepository {
  final Object? error;
  _FakeRepo({this.error});

  @override
  Future<Portfolio> fetchPortfolio(PortfolioOwner owner) async {
    if (error != null) throw error!;
    return owner == PortfolioOwner.me ? _my : _ai;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(PortfolioRepository repo) => ProviderScope(
      overrides: [portfolioRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: DuelCard())),
    );

void main() {
  testWidgets('양측 수익률과 차이 배너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    await tester.pump();
    expect(find.text('+5.2%'), findsOneWidget);
    expect(find.text('+3.8%'), findsOneWidget);
    expect(find.text('내가 AI보다 +1.4% 앞서는 중'), findsOneWidget);
  });

  testWidgets('로딩 중에는 스피너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // 보류된 future 정리
  });

  testWidgets('에러 시 메시지와 재시도 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'SYSTEM_ERROR', code: 'SERVICE_UNAVAILABLE', message: '잠시 후 다시 시도해 주세요.', retryable: true),
    )));
    await tester.pump();
    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '재시도'), findsOneWidget);
  });

  testWidgets('retryable=false 에러는 재시도 버튼을 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      error: const ApiException(
          eventType: 'AUTH_ERROR', code: 'UNAUTHENTICATED', message: '로그인이 필요합니다.', retryable: false),
    )));
    await tester.pump();
    expect(find.text('로그인이 필요합니다.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '재시도'), findsNothing);
  });
}
