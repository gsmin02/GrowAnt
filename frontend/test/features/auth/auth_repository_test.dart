import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:growant/core/api/api_client.dart';
import 'package:growant/core/api/api_exception.dart';
import 'package:growant/features/auth/data/auth_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AuthRepository repo;

  setUp(() {
    dio = createApiClient(baseUrl: 'http://test');
    adapter = DioAdapter(dio: dio);
    repo = AuthRepository(dio);
  });

  test('login은 provider·nickname body를 보내고 토큰+사용자를 파싱한다', () async {
    adapter.onPost(
      '/api/auth/login',
      (s) => s.reply(200, {
        'success': true,
        'data': {
          'token': 'jwt-abc',
          'user': {'id': 1, 'nickname': '개미왕', 'provider': 'kakao'},
        },
      }),
      data: {'provider': 'kakao', 'nickname': '개미왕'},
    );
    final res = await repo.login(provider: 'kakao', nickname: '개미왕');
    expect(res.token, 'jwt-abc');
    expect(res.user.id, 1);
    expect(res.user.nickname, '개미왕');
    expect(res.user.provider, 'kakao');
  });

  test('me는 사용자를 파싱한다', () async {
    adapter.onGet('/api/auth/me', (s) => s.reply(200, {
          'success': true,
          'data': {'id': 7, 'nickname': 'grow', 'provider': 'google'},
        }));
    final user = await repo.me();
    expect(user.id, 7);
    expect(user.nickname, 'grow');
    expect(user.provider, 'google');
  });

  test('에러 envelope는 ApiException으로 매핑된다', () async {
    adapter.onPost(
      '/api/auth/login',
      (s) => s.reply(400, {
        'success': false,
        'error': {'code': 'INVALID_LOGIN', 'eventType': 'VALIDATION_ERROR', 'message': '잘못된 로그인 요청입니다.', 'retryable': false}
      }),
      data: {'provider': 'github', 'nickname': '개미왕'},
    );
    await expectLater(
      repo.login(provider: 'github', nickname: '개미왕'),
      throwsA(isA<ApiException>()
          .having((e) => e.eventType, 'eventType', 'VALIDATION_ERROR')
          .having((e) => e.message, 'message', '잘못된 로그인 요청입니다.')
          .having((e) => e.retryable, 'retryable', false)),
    );
  });
}
