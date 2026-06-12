/// 로그인 사용자 — 서버 UserDto와 1:1.
class AuthUser {
  final int id;
  final String nickname;
  final String provider;
  const AuthUser({required this.id, required this.nickname, required this.provider});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] as num).toInt(),
        nickname: j['nickname'] as String,
        provider: j['provider'] as String,
      );
}

/// POST /api/auth/login 응답 — 토큰 + 사용자.
class AuthResponse {
  final String token;
  final AuthUser user;
  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['token'] as String,
        user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}
