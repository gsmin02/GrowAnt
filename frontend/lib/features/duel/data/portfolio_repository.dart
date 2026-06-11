import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'portfolio_models.dart';

class PortfolioRepository {
  final Dio _dio;
  const PortfolioRepository(this._dio);

  Future<Portfolio> fetchPortfolio(PortfolioOwner owner) async {
    try {
      final res = await _dio.get('/api/portfolio/${owner.path}');
      return Portfolio.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }

}
