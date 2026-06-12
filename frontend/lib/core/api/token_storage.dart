import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT 보관(iOS Keychain). dioProvider와 auth feature가 함께 쓰는 core 계층 — feature 간 순환 import 방지. 스펙 §4.2
class TokenStorage {
  static const _key = 'auth_token';
  final FlutterSecureStorage _storage;
  const TokenStorage([this._storage = const FlutterSecureStorage()]);

  Future<String?> read() => _storage.read(key: _key);
  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => const TokenStorage());
