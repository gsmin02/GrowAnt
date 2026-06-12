import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/app/app_shell.dart';
import 'package:growant/app/auth_gate.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/core/api/token_storage.dart';
import 'package:growant/features/auth/data/auth_models.dart';
import 'package:growant/features/auth/data/auth_repository.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/login_screen.dart';

class _FakeStorage implements TokenStorage {
  String? token;
  _FakeStorage(this.token);
  @override
  Future<String?> read() async => token;
  @override
  Future<void> save(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

class _FakeAuthRepo implements AuthRepository {
  final AuthUser? user; // null이면 me가 401 ApiException을 던지는 시나리오
  _FakeAuthRepo({this.user});

  @override
  Future<AuthUser> me() async {
    final u = user;
    if (u == null) {
      throw const ApiException(
          eventType: 'AUTH_ERROR',
          code: 'UNAUTHENTICATED',
          message: '로그인이 필요합니다.',
          retryable: false);
    }
    return u;
  }

  @override
  Future<AuthResponse> login({required String provider, required String nickname}) async =>
      AuthResponse(
          token: 'jwt-new', user: AuthUser(id: 2, nickname: nickname, provider: provider));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _wrap({required TokenStorage storage, AuthRepository? repo}) => ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        if (repo != null) authRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: AuthGate()),
    );

void main() {
  testWidgets('토큰이 없으면 LoginScreen을 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(storage: _FakeStorage(null)));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });

  testWidgets('토큰이 있고 me가 성공하면 AppShell을 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(
      storage: _FakeStorage('jwt-abc'),
      repo: _FakeAuthRepo(user: const AuthUser(id: 1, nickname: '개미왕', provider: 'kakao')),
    ));
    await tester.pump(); // build future resolve
    await tester.pump();
    expect(find.byType(AppShell), findsOneWidget);
    // AppShell 홈 카드들이 실 API 호출 타이머를 생성한다 — 소진해서 pending timer 오류 방지.
    // (더 견고한 대안: AppShell 내부 provider들을 override해 네트워크 경로 자체를 격리 — AppShell 통합 테스트에서.)
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('부트스트랩 중에는 스피너를 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(storage: _FakeStorage(null)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // 보류 future 정리
  });

  testWidgets('로그인 성공 시 LoginScreen에서 AppShell로 전환된다', (tester) async {
    await tester.pumpWidget(_wrap(storage: _FakeStorage(null), repo: _FakeAuthRepo()));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump(); // 시트 라우트 push
    await tester.pump(const Duration(milliseconds: 300)); // 시트 애니메이션
    await tester.enterText(find.byType(TextField), '개미왕');
    await tester.tap(find.widgetWithText(FilledButton, '시작하기'));
    await tester.pump(); // login future resolve
    await tester.pump(); // 상태 전환 리빌드
    await tester.pump(const Duration(milliseconds: 300)); // 시트 pop 애니메이션
    expect(find.byType(AppShell), findsOneWidget);
    // AppShell 홈 카드들의 보류 타이머 소진(pumpAndSettle은 무한 스피너 때문에 금지)
    await tester.pump(const Duration(seconds: 30));
  });
}
