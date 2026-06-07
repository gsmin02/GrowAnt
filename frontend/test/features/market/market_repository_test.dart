import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/market/data/market_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late MarketRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = MarketRepository(dio);
  });

  test('fetchMarket unwraps envelope into rows', () async {
    adapter.onGet('/api/market', (s) => s.reply(200, {
          'success': true,
          'data': [
            {'ticker': '005930', 'name': '삼성전자', 'price': 76300, 'changeRate': 5.97}
          ],
        }));
    final rows = await repo.fetchMarket();
    expect(rows, hasLength(1));
    expect(rows.first.ticker, '005930');
  });

  test('fetchDetail on error envelope throws mapped ApiException', () async {
    adapter.onGet('/api/market/999999', (s) => s.reply(400, {
          'success': false,
          'error': {'code': 'INVALID_TICKER', 'eventType': 'VALIDATION_ERROR', 'message': '존재하지 않는 종목입니다.', 'retryable': false}
        }));
    expect(
      () => repo.fetchDetail('999999'),
      throwsA(isA<ApiException>()
          .having((e) => e.eventType, 'eventType', 'VALIDATION_ERROR')
          .having((e) => e.retryable, 'retryable', false)),
    );
  });
}
