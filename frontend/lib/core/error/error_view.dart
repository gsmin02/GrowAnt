import 'package:flutter/material.dart';

enum ErrorKind { network, serverError, notFound, unauthorized, serviceUnavailable }

ErrorKind errorKindFromEventType(String eventType) {
  switch (eventType) {
    case 'NETWORK':
      return ErrorKind.network;
    case 'AUTH_ERROR':
      return ErrorKind.unauthorized;
    case 'VALIDATION_ERROR':
      return ErrorKind.notFound;
    case 'MARKET_ERROR':
      return ErrorKind.serviceUnavailable;
    case 'SYSTEM_ERROR':
    default:
      return ErrorKind.serverError;
  }
}

class _Preset {
  final IconData icon;
  final String title;
  const _Preset(this.icon, this.title);
}

const _presets = <ErrorKind, _Preset>{
  ErrorKind.network: _Preset(Icons.wifi_off_outlined, '네트워크 오류'),
  ErrorKind.serverError: _Preset(Icons.cloud_off_outlined, '서버 오류'),
  ErrorKind.notFound: _Preset(Icons.search_off_outlined, '찾을 수 없음'),
  ErrorKind.unauthorized: _Preset(Icons.lock_outline, '접근 권한 없음'),
  ErrorKind.serviceUnavailable: _Preset(Icons.hourglass_empty_outlined, '일시적 오류'),
};

/// Scaffold 없는 에러 본문. 메시지는 서버 envelope 값을 권위로 사용.
class ErrorView extends StatelessWidget {
  final ErrorKind kind;
  final String? message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.kind, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = _presets[kind]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(p.icon, size: 64, color: const Color(0xFFCCCCCC)),
            const SizedBox(height: 24),
            Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              message ?? '잠시 후 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            if (onRetry != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 시도'),
              ),
          ],
        ),
      ),
    );
  }
}
