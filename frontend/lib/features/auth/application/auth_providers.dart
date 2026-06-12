import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/token_storage.dart';
import '../../account/application/account_providers.dart';
import '../../duel/application/portfolio_providers.dart';
import '../../market/application/market_providers.dart';
import '../../trading/application/trading_providers.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));

/// 로그인 상태의 단일 소유자 — null이면 비로그인. AuthGate가 watch해 첫 화면을 결정한다.
class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final storage = ref.watch(tokenStorageProvider);
    final repo = ref.watch(authRepositoryProvider);
    final token = await storage.read();
    if (token == null) return null;
    try {
      return await repo.me();
    } on ApiException catch (e) {
      // 네트워크 단절이면 토큰을 보존(다음 시작 때 자동 로그인 재시도) — 서버가 거부한 토큰만 정리한다.
      if (e.eventType != 'NETWORK') await storage.clear();
      return null;
    }
  }

  /// 성공 시 토큰 저장 + 상태 전환. 실패(ApiException)는 호출부(시트)가 스낵바로 처리 — 상태는 건드리지 않는다.
  Future<void> login(String provider, String nickname) async {
    final res =
        await ref.read(authRepositoryProvider).login(provider: provider, nickname: nickname);
    await ref.read(tokenStorageProvider).save(res.token);
    state = AsyncValue.data(res.user);
    _invalidateUserScopedData();
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncValue.data(null);
    _invalidateUserScopedData();
  }

  /// 계정 전환 시 사용자 범위 데이터 캐시 무효화 — 데이터 provider는 앱 수명 캐시라
  /// 이전 계정의 데이터(또는 옛 토큰의 401 에러)가 다음 계정 화면에 그대로 남는다(per-user 필수).
  void _invalidateUserScopedData() {
    ref.invalidate(portfolioProvider); // family 전체(me·ai)
    ref.invalidate(accountSummaryProvider);
    ref.invalidate(tradesProvider);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUser?>(AuthController.new);
