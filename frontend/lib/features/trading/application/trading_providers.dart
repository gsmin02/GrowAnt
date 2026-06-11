import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../market/application/market_providers.dart';
import '../data/trade_models.dart';
import '../data/trade_repository.dart';

final tradeRepositoryProvider =
    Provider<TradeRepository>((ref) => TradeRepository(ref.watch(dioProvider)));

class TradesNotifier extends AsyncNotifier<List<Trade>> {
  @override
  Future<List<Trade>> build() => ref.watch(tradeRepositoryProvider).fetchTrades();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(tradeRepositoryProvider).fetchTrades());
  }
}

final tradesProvider =
    AsyncNotifierProvider<TradesNotifier, List<Trade>>(TradesNotifier.new);
