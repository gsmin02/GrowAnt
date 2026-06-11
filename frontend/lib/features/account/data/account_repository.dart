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
      throw asApiException(e);
    }
  }

}
