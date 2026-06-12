import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/core/api/token_storage.dart';
import 'package:growant/features/auth/data/auth_models.dart';
import 'package:growant/features/auth/data/auth_repository.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/login_screen.dart';

class _FakeStorage implements TokenStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

class _FakeAuthRepo implements AuthRepository {
  final Object? error;
  ({String provider, String nickname})? last;
  _FakeAuthRepo({this.error});

  @override
  Future<AuthResponse> login({required String provider, required String nickname}) async {
    last = (provider: provider, nickname: nickname);
    if (error != null) throw error!;
    return AuthResponse(
        token: 'jwt-1', user: AuthUser(id: 1, nickname: nickname, provider: provider));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakeStorage storage;

  Widget wrap(_FakeAuthRepo repo) {
    storage = _FakeStorage();
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  testWidgets('소셜 버튼 → 닉네임 시트 → 로그인 호출·토큰 저장·시트 닫힘', (tester) async {
    final repo = _FakeAuthRepo();
    await tester.pumpWidget(wrap(repo));
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('카카오 데모 로그인'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '개미왕');
    await tester.tap(find.widgetWithText(FilledButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(repo.last, (provider: 'kakao', nickname: '개미왕'));
    expect(storage.token, 'jwt-1');
    expect(find.text('카카오 데모 로그인'), findsNothing); // 시트 닫힘
  });

  testWidgets('로그인 실패 - 에러 스낵바, 시트 유지', (tester) async {
    final repo = _FakeAuthRepo(
      error: const ApiException(
          eventType: 'VALIDATION_ERROR', code: 'INVALID_LOGIN', message: '잘못된 로그인 요청입니다.', retryable: false),
    );
    await tester.pumpWidget(wrap(repo));
    await tester.tap(find.text('Google로 시작하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '개미왕');
    await tester.tap(find.widgetWithText(FilledButton, '시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('잘못된 로그인 요청입니다.'), findsOneWidget);
    expect(find.text('Google 데모 로그인'), findsOneWidget); // 시트 유지
  });
}
