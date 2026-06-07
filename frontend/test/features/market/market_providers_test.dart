import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growant/features/market/application/market_providers.dart';
import 'package:growant/features/market/data/market_models.dart';
import 'package:growant/features/market/data/market_repository.dart';

class _FakeRepo implements MarketRepository {
  @override
  Future<List<MarketRow>> fetchMarket() async =>
      const [MarketRow(ticker: '005930', name: '삼성전자', price: 76300, changeRate: 5.97)];
  @override
  Future<StockDetail> fetchDetail(String ticker) async => throw UnimplementedError();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('marketListProvider resolves to rows', () async {
    final container = ProviderContainer(overrides: [
      marketRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);

    final rows = await container.read(marketListProvider.future);
    expect(rows, hasLength(1));
    expect(rows.first.name, '삼성전자');
  });
}
