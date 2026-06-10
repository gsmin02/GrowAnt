import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'account_models.dart';

class AccountRepository {
  final Dio _dio;
  const AccountRepository(this._dio);

  Future<AccountSummary> fetchSummary() async {
    try {
      final res = await _dio.get('/api/account/summary');
      return AccountSummary.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) => e.error is ApiException
      ? e.error as ApiException
      : const ApiException(eventType: 'NETWORK', code: 'ERR_NETWORK', message: '인터넷 연결을 확인해주세요.', retryable: true);
}
