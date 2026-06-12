import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String eventType; // 서버 eventType 또는 클라 'NETWORK'
  final String code;
  final String message; // 사용자 노출(서버 envelope 권위)
  final bool retryable;
  const ApiException({
    required this.eventType,
    required this.code,
    required this.message,
    required this.retryable,
  });

  @override
  String toString() => 'ApiException($code/$eventType: $message)';
}

/// DioException → ApiException 매핑 — envelope 인터셉터가 심은 ApiException을 우선, 그 외는 네트워크 오류.
ApiException asApiException(DioException e) => e.error is ApiException
    ? e.error as ApiException
    : const ApiException(
        eventType: 'NETWORK',
        code: 'ERR_NETWORK',
        message: '인터넷 연결을 확인해주세요.',
        retryable: true,
      );
