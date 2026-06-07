import 'package:dio/dio.dart';
import 'api_exception.dart';

/// 개발용 baseUrl. iOS 시뮬레이터=localhost, Android 에뮬레이터=10.0.2.2 (스펙 §8).
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

Dio createApiClient({String baseUrl = kApiBaseUrl}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onResponse: (response, handler) {
      final data = response.data;
      if (data is Map && data['success'] == true) {
        handler.resolve(Response(
          requestOptions: response.requestOptions,
          statusCode: response.statusCode,
          data: data['data'],
        ));
      } else {
        handler.reject(_toDioError(response.requestOptions, data, response));
      }
    },
    onError: (err, handler) {
      handler.reject(_toDioError(err.requestOptions, err.response?.data, err.response, err));
    },
  ));
  return dio;
}

DioException _toDioError(RequestOptions req, dynamic data, Response? res, [DioException? src]) {
  if (data is Map && data['success'] == false && data['error'] is Map) {
    final e = data['error'] as Map;
    return DioException(
      requestOptions: req,
      response: res,
      error: ApiException(
        eventType: (e['eventType'] ?? 'SYSTEM_ERROR').toString(),
        code: (e['code'] ?? 'UNKNOWN').toString(),
        message: (e['message'] ?? '오류가 발생했습니다.').toString(),
        retryable: e['retryable'] == true,
      ),
    );
  }
  return DioException(
    requestOptions: req,
    response: res,
    error: const ApiException(
      eventType: 'NETWORK',
      code: 'ERR_NETWORK',
      message: '인터넷 연결을 확인해주세요.',
      retryable: true,
    ),
  );
}
