import 'package:flutter/material.dart';
import '../../core/error/error_view.dart';

/// 라우트형 에러 화면(자체 Scaffold). 본문은 ErrorView에 위임.
class ErrorScreen extends StatelessWidget {
  final ErrorKind kind;
  final String? message;
  final VoidCallback? onRetry;
  const ErrorScreen({super.key, this.kind = ErrorKind.network, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오류')),
      body: ErrorView(
        kind: kind,
        message: message,
        onRetry: onRetry ?? () => Navigator.pop(context),
      ),
    );
  }
}

// 에러 종류 미리보기 갤러리 (Mock 탐색용)
class ErrorGalleryScreen extends StatelessWidget {
  const ErrorGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('에러/예외 화면')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final kind in ErrorKind.values)
            ListTile(
              title: Text(kind.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ErrorScreen(kind: kind)),
              ),
            ),
        ],
      ),
    );
  }
}
