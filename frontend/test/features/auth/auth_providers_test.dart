import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/core/api/token_storage.dart';
import 'package:growant/features/auth/application/auth_providers.dart';
import 'package:growant/features/auth/data/auth_models.dart';
import 'package:growant/features/auth/data/auth_repository.dart';
import 'package:growant/features/trading/application/trading_providers.dart';
import 'package:growant/features/trading/data/trade_models.dart';
import 'package:growant/features/trading/data/trade_repository.dart';

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
  @override
  Future<AuthResponse> login({required String provider, required String nickname}) async =>
      AuthResponse(
          token: 'jwt-1', user: AuthUser(id: 1, nickname: nickname, provider: provider));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _CountingTradeRepo implements TradeRepository {
  int fetchCount = 0;

  @override
  Future<List<Trade>> fetchTrades() async {
    fetchCount++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _CountingTradeRepo tradeRepo;

  ProviderContainer makeContainer() {
    tradeRepo = _CountingTradeRepo();
    final container = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(_FakeStorage()),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
      tradeRepositoryProvider.overrideWithValue(tradeRepo),
    ]);
    addTearDown(container.dispose);
    container.listen(tradesProvider, (_, __) {}); // 활성 리스너 — 캐시 생존 조건
    return container;
  }

  test('login은 사용자 범위 데이터 캐시를 무효화한다 — 새 토큰으로 재조회', () async {
    final container = makeContainer();
    await container.read(tradesProvider.future); // 1회 조회 후 캐시
    expect(tradeRepo.fetchCount, 1);

    await container.read(authControllerProvider.notifier).login('kakao', '개미왕');

    await container.read(tradesProvider.future); // 무효화됐다면 재조회
    expect(tradeRepo.fetchCount, 2, reason: '계정 전환 후에도 캐시가 남으면 이전 계정 데이터/401이 표시된다');
  });

  test('logout도 사용자 범위 데이터 캐시를 무효화한다', () async {
    final container = makeContainer();
    await container.read(tradesProvider.future);
    expect(tradeRepo.fetchCount, 1);

    await container.read(authControllerProvider.notifier).logout();

    await container.read(tradesProvider.future);
    expect(tradeRepo.fetchCount, 2);
  });
}
