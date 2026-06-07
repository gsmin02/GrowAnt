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
