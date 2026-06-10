import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/duel/data/portfolio_models.dart';
import 'package:growant/features/duel/data/portfolio_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late PortfolioRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = PortfolioRepository(dio);
  });

  test('fetchPortfolio(me)는 envelope를 풀어 서버 합산값과 보유종목을 파싱한다', () async {
    adapter.onGet('/api/portfolio/me', (s) => s.reply(200, {
          'success': true,
          'data': {
            'returnRate': 5.2,
            'profit': 142600,
            'cost': 2739200,
            'value': 2881800,
            'holdings': [
              {'ticker': '005930', 'name': '삼성전자', 'qty': 12, 'avgPrice': 70000, 'currentPrice': 76300}
            ],
          },
        }));
    final p = await repo.fetchPortfolio(PortfolioOwner.me);
    expect(p.returnRate, 5.2);
    expect(p.profit, 142600);
    expect(p.holdings, hasLength(1));
    expect(p.holdings.first.ticker, '005930');
  });

  test('fetchPortfolio(ai)는 /api/portfolio/ai를 호출한다', () async {
    adapter.onGet('/api/portfolio/ai', (s) => s.reply(200, {
          'success': true,
          'data': {'returnRate': 3.8, 'profit': 117200, 'cost': 3086200, 'value': 3203400, 'holdings': []},
        }));
    final p = await repo.fetchPortfolio(PortfolioOwner.ai);
    expect(p.returnRate, 3.8);
  });

  test('에러 envelope는 ApiException으로 매핑된다', () async {
    adapter.onGet('/api/portfolio/me', (s) => s.reply(503, {
          'success': false,
          'error': {'code': 'SERVICE_UNAVAILABLE', 'eventType': 'SYSTEM_ERROR', 'message': '잠시 후 다시 시도해 주세요.', 'retryable': true}
        }));
    await expectLater(
      repo.fetchPortfolio(PortfolioOwner.me),
      throwsA(isA<ApiException>()
          .having((e) => e.eventType, 'eventType', 'SYSTEM_ERROR')
          .having((e) => e.retryable, 'retryable', true)),
    );
  });
}
