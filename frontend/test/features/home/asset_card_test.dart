import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/account/application/account_providers.dart';
import 'package:growant/features/account/data/account_models.dart';
import 'package:growant/features/account/data/account_repository.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/data/auth_models.dart';
import 'package:growant/features/home/widgets/asset_card.dart';

class _FakeRepo implements AccountRepository {
  final AccountSummary? summary;
  final Object? error;
  _FakeRepo({this.summary, this.error});

  @override
  Future<AccountSummary> fetchSummary() async {
    if (error != null) throw error!;
    return summary!;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeAuth extends AuthController {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 1, nickname: '개미왕', provider: 'kakao');
}

Widget _wrap(AccountRepository repo) => ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(() => _FakeAuth()),
      ],
      child: const MaterialApp(home: Scaffold(body: AssetCard())),
    );

void main() {
  testWidgets('자산 요약(총평가·수익률 배지)을 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
        summary: const AccountSummary(totalAsset: 10520000, returnRate: 5.2))));
    await tester.pump();
    expect(find.text('10,520,000원'), findsOneWidget);
    expect(find.text('+5.20%'), findsOneWidget);
    expect(find.text('개미왕'), findsOneWidget);
  });

  testWidgets('로딩 중에는 스피너를 표시한다', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
        summary: const AccountSummary(totalAsset: 10520000, returnRate: 5.2))));
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
