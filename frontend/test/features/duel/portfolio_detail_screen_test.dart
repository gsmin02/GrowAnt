import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/core/error/error_view.dart';
import 'package:growant/features/duel/application/portfolio_providers.dart';
import 'package:growant/features/duel/data/portfolio_models.dart';
import 'package:growant/features/duel/data/portfolio_repository.dart';
import 'package:growant/features/duel/portfolio_detail_screen.dart';

const _myPortfolio = Portfolio(
  returnRate: 5.2, profit: 142600, cost: 2739200, value: 2881800,
  holdings: [
    Holding(ticker: '005930', name: '삼성전자', qty: 12, avgPrice: 70000, currentPrice: 76300),
    Holding(ticker: '000660', name: 'SK하이닉스', qty: 4, avgPrice: 185000, currentPrice: 178500),
  ],
);

const _aiPortfolio = Portfolio(
  returnRate: 3.8, profit: 117200, cost: 3086200, value: 3203400,
  holdings: [
    Holding(ticker: '005930', name: '삼성전자', qty: 8, avgPrice: 73500, currentPrice: 76300),
    Holding(ticker: '051910', name: 'LG화학', qty: 3, avgPrice: 272000, currentPrice: 278000),
    Holding(ticker: '068270', name: '셀트리온', qty: 5, avgPrice: 192000, currentPrice: 187000),
    Holding(ticker: '035720', name: '카카오', qty: 20, avgPrice: 36110, currentPrice: 41200),
  ],
);

class _FakeRepo implements PortfolioRepository {
  final Object? error;
  _FakeRepo({this.error});

  @override
  Future<Portfolio> fetchPortfolio(PortfolioOwner owner) async {
    if (error != null) throw error!;
    return owner == PortfolioOwner.me ? _myPortfolio : _aiPortfolio;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap(PortfolioRepository repo, PortfolioOwner owner) => ProviderScope(
      overrides: [portfolioRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: PortfolioDetailScreen(owner: owner)),
    );

void main() {
  testWidgets('AI 화면은 따라사기 버튼을 종목 수만큼 렌더하고 서버 합산 +3.8% 표시', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(), PortfolioOwner.ai));
    await tester.pump();
    expect(find.widgetWithText(OutlinedButton, '따라사기'), findsNWidgets(4));
    expect(find.text('+3.8%'), findsOneWidget);
    expect(find.text('AI 포트폴리오'), findsOneWidget);
  });

  testWidgets('나 화면은 따라사기 버튼이 없고 서버 합산 +5.2% 표시', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(), PortfolioOwner.me));
    await tester.pump();
    expect(find.widgetWithText(OutlinedButton, '따라사기'), findsNothing);
    expect(find.text('+5.2%'), findsOneWidget);
    expect(find.text('내 포트폴리오'), findsOneWidget);
  });

  testWidgets('로딩 중에는 스피너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(), PortfolioOwner.me));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // 보류된 future 정리
  });

  testWidgets('에러 시 ErrorView를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(
        _FakeRepo(
            error: const ApiException(
                eventType: 'SYSTEM_ERROR', code: 'SERVICE_UNAVAILABLE', message: '잠시 후 다시 시도해 주세요.', retryable: true)),
        PortfolioOwner.me));
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('retryable=false 에러는 재시도 버튼을 표시하지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(
        _FakeRepo(
            error: const ApiException(
                eventType: 'AUTH_ERROR', code: 'UNAUTHENTICATED', message: '로그인이 필요합니다.', retryable: false)),
        PortfolioOwner.me));
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsNothing);
  });
}
