import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/token_storage.dart';
import '../data/market_models.dart';
import '../data/market_repository.dart';

final dioProvider = Provider<Dio>(
  (ref) => createApiClient(getToken: () => ref.read(tokenStorageProvider).read()),
);

final marketRepositoryProvider =
    Provider<MarketRepository>((ref) => MarketRepository(ref.watch(dioProvider)));

class MarketListNotifier extends AsyncNotifier<List<MarketRow>> {
  @override
  Future<List<MarketRow>> build() => ref.watch(marketRepositoryProvider).fetchMarket();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(marketRepositoryProvider).fetchMarket());
  }
}

final marketListProvider =
    AsyncNotifierProvider<MarketListNotifier, List<MarketRow>>(MarketListNotifier.new);

final stockDetailProvider = FutureProvider.family<StockDetail, String>(
  (ref, ticker) => ref.watch(marketRepositoryProvider).fetchDetail(ticker),
);
