import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/login_screen.dart';
import 'app_shell.dart';

/// 로그인 상태가 첫 화면을 결정 — 부트스트랩(저장 토큰 → me) 동안 스플래시. 스펙 §4.5
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(authControllerProvider);
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // ApiException은 build()가 data(null)로 흡수 — 여기는 비ApiException 런타임 예외 방어선.
      error: (_, __) => const LoginScreen(),
      data: (user) => user == null ? const LoginScreen() : const AppShell(),
    );
  }
}
