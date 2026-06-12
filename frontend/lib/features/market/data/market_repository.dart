import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'market_models.dart';

class MarketRepository {
  final Dio _dio;
  const MarketRepository(this._dio);

  Future<List<MarketRow>> fetchMarket() async {
    try {
      final res = await _dio.get('/api/market');
      return (res.data as List).map((e) => MarketRow.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }

  Future<StockDetail> fetchDetail(String ticker) async {
    try {
      final res = await _dio.get('/api/market/$ticker');
      return StockDetail.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }

}
