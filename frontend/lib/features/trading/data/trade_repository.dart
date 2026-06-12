import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'trade_models.dart';

class TradeRepository {
  final Dio _dio;
  const TradeRepository(this._dio);

  Future<Trade> placeOrder({required String ticker, required bool isBuy, required int qty}) async {
    try {
      final res = await _dio.post('/api/orders', data: {'ticker': ticker, 'isBuy': isBuy, 'qty': qty});
      return Trade.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }

  Future<List<Trade>> fetchTrades() async {
    try {
      final res = await _dio.get('/api/trades');
      return (res.data as List).map((e) => Trade.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }

}
