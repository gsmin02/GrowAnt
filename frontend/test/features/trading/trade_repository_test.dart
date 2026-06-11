import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/trading/data/trade_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late TradeRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = TradeRepository(dio);
  });

  test('placeOrder는 주문 body를 보내고 체결 Trade를 파싱한다', () async {
    adapter.onPost(
      '/api/orders',
      (s) => s.reply(200, {
        'success': true,
        'data': {
          'name': '삼성전자', 'isBuy': true, 'price': 76300, 'qty': 2,
          'amount': 152600, 'time': '06.09 12:00',
        },
      }),
      data: {'ticker': '005930', 'isBuy': true, 'qty': 2},
    );
    final t = await repo.placeOrder(ticker: '005930', isBuy: true, qty: 2);
    expect(t.name, '삼성전자');
    expect(t.isBuy, true);
    expect(t.amount, 152600);
    expect(t.time, '06.09 12:00');
  });

  test('fetchTrades는 내역 리스트를 파싱한다', () async {
    adapter.onGet('/api/trades', (s) => s.reply(200, {
          'success': true,
          'data': [
            {'name': 'NAVER', 'isBuy': false, 'price': 198400, 'qty': 1, 'amount': 198400, 'time': '05.07 16:01'}
          ],
        }));
    final list = await repo.fetchTrades();
    expect(list, hasLength(1));
    expect(list.first.name, 'NAVER');
    expect(list.first.isBuy, false);
  });

  test('에러 envelope는 ApiException으로 매핑된다', () async {
    adapter.onPost(
      '/api/orders',
      (s) => s.reply(409, {
        'success': false,
        'error': {'code': 'ORDER_INSUFFICIENT_FUNDS', 'eventType': 'ORDER_ERROR', 'message': '잔고가 부족합니다.', 'retryable': false}
      }),
      data: {'ticker': '005380', 'isBuy': true, 'qty': 1000},
    );
    await expectLater(
      repo.placeOrder(ticker: '005380', isBuy: true, qty: 1000),
      throwsA(isA<ApiException>()
          .having((e) => e.eventType, 'eventType', 'ORDER_ERROR')
          .having((e) => e.message, 'message', '잔고가 부족합니다.')
          .having((e) => e.retryable, 'retryable', false)),
    );
  });
}
