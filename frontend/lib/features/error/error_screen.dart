import 'package:flutter/material.dart';

enum ErrorType { network, serverError, notFound, unauthorized }

class ErrorScreen extends StatelessWidget {
  final ErrorType type;
  final VoidCallback? onRetry;

  const ErrorScreen({
    super.key,
    this.type = ErrorType.network,
    this.onRetry,
  });

  static const _configs = {
    ErrorType.network: (
      icon: Icons.wifi_off_outlined,
      title: '네트워크 오류',
      message: '인터넷 연결을 확인해주세요.\n연결 후 다시 시도해주세요.',
      code: 'ERR_NETWORK',
    ),
    ErrorType.serverError: (
      icon: Icons.cloud_off_outlined,
      title: '서버 오류',
      message: '서버에 일시적인 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
      code: 'ERR_500',
    ),
    ErrorType.notFound: (
      icon: Icons.search_off_outlined,
      title: '페이지를 찾을 수 없음',
      message: '요청하신 페이지가 존재하지 않습니다.',
      code: 'ERR_404',
    ),
    ErrorType.unauthorized: (
      icon: Icons.lock_outline,
      title: '접근 권한 없음',
      message: '이 기능을 사용하려면 로그인이 필요합니다.',
      code: 'ERR_401',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final config = _configs[type]!;

    return Scaffold(
      appBar: AppBar(title: const Text('오류')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(config.icon, size: 64, color: const Color(0xFFCCCCCC)),
              const SizedBox(height: 24),
              Text(
                config.title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                config.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF888888), fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 8),
              Text(
                config.code,
                style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 12,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 32),
              if (onRetry != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 시도'),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('돌아가기'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 에러 종류를 선택해서 미리볼 수 있는 갤러리 (Mock 탐색용)
class ErrorGalleryScreen extends StatelessWidget {
  const ErrorGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('에러/예외 화면')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final type in ErrorType.values)
            ListTile(
              title: Text(type.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ErrorScreen(
                    type: type,
                    onRetry: type == ErrorType.network || type == ErrorType.serverError
                        ? () => Navigator.pop(context)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
