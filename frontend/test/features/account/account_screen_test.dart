import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/features/account/account_screen.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/data/auth_models.dart';

class _FakeAuth extends AuthController {
  final AuthUser? user;
  bool loggedOut = false;
  _FakeAuth(this.user);

  @override
  Future<AuthUser?> build() async => user;

  @override
  Future<void> logout() async {
    loggedOut = true;
    state = const AsyncValue.data(null);
  }
}

Widget _wrap(_FakeAuth fake) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: Scaffold(body: AccountScreen())),
    );

void main() {
  testWidgets('로그인 사용자의 닉네임과 provider 라벨을 표시한다', (tester) async {
    final fake = _FakeAuth(const AuthUser(id: 1, nickname: '개미왕', provider: 'kakao'));
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();
    expect(find.text('개미왕'), findsOneWidget);
    expect(find.text('카카오 로그인'), findsOneWidget);
  });

  testWidgets('로그아웃 탭 시 logout이 호출된다', (tester) async {
    final fake = _FakeAuth(const AuthUser(id: 1, nickname: '개미왕', provider: 'google'));
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();
    await tester.ensureVisible(find.text('로그아웃'));
    await tester.tap(find.text('로그아웃'));
    await tester.pump();
    expect(fake.loggedOut, isTrue);
  });
}
