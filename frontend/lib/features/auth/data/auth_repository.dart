import 'package:dio/dio.dart';
import '../../../core/api/api_exception.dart';
import 'auth_models.dart';

class AuthRepository {
  final Dio _dio;
  const AuthRepository(this._dio);

  Future<AuthResponse> login({required String provider, required String nickname}) async {
    try {
      final res = await _dio
          .post('/api/auth/login', data: {'provider': provider, 'nickname': nickname});
      return AuthResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }

  Future<AuthUser> me() async {
    try {
      final res = await _dio.get('/api/auth/me');
      return AuthUser.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw asApiException(e);
    }
  }
}
