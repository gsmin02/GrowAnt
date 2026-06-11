import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';

void main() {
  // 토큰 인터셉터 뒤에 검사용 인터셉터를 붙여 실제 부착된 헤더를 캡처한다(헤더 매처 의존 회피).
  Future<String?> capturedAuthHeader({required Future<String?> Function() getToken}) async {
    final dio = createApiClient(baseUrl: 'http://test', getToken: getToken);
    String? seen;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      seen = o.headers['Authorization'] as String?;
      h.next(o);
    }));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/ping', (s) => s.reply(200, {'success': true, 'data': 'pong'}));
    await dio.get('/ping');
    return seen;
  }

  test('getToken이 토큰을 주면 Authorization Bearer 헤더를 부착한다', () async {
    final header = await capturedAuthHeader(getToken: () async => 'jwt-123');
    expect(header, 'Bearer jwt-123');
  });

  test('토큰이 null이면 Authorization 헤더를 부착하지 않는다', () async {
    final header = await capturedAuthHeader(getToken: () async => null);
    expect(header, isNull);
  });
}
