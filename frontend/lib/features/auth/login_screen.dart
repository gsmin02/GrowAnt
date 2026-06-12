import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import 'application/auth_providers.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _startLogin(BuildContext context, String provider, String label) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NicknameSheet(provider: provider, providerLabel: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const _Logo(),
              const Spacer(),
              _SocialButton(
                label: '카카오로 시작하기',
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: const Color(0xFF191919),
                onTap: () => _startLogin(context, 'kakao', '카카오'),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: '네이버로 시작하기',
                backgroundColor: const Color(0xFF03C75A),
                foregroundColor: Colors.white,
                onTap: () => _startLogin(context, 'naver', '네이버'),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: 'Apple로 시작하기',
                backgroundColor: const Color(0xFF000000),
                foregroundColor: Colors.white,
                onTap: () => _startLogin(context, 'apple', 'Apple'),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: 'Google로 시작하기',
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: const Color(0xFF111111),
                onTap: () => _startLogin(context, 'google', 'Google'),
                border: Border.all(color: const Color(0xFFCCCCCC)),
              ),
              const SizedBox(height: 48),
              Text(
                '로그인하면 이용약관 및 개인정보처리방침에 동의하는 것으로 간주됩니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF999999),
                    ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// 데모 로그인 닉네임 시트 — 성공 시 pop(AuthGate가 AppShell로 전환), 실패 시 스낵바+시트 유지.
class _NicknameSheet extends ConsumerStatefulWidget {
  final String provider;
  final String providerLabel;
  const _NicknameSheet({required this.provider, required this.providerLabel});

  @override
  ConsumerState<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends ConsumerState<_NicknameSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) return;
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(widget.provider, nickname);
      if (mounted) navigator.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      // 스낵바는 모달 시트 뒤(Scaffold 하단)에 그려져 가려진다 — 실패는 시트 안 인라인으로 표시.
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      // 토큰 저장(Keychain) 등 비API 예외 — 버튼이 영구 비활성으로 남지 않게 복구한다.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '로그인에 실패했어요. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.providerLabel} 데모 로그인',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('닉네임만 입력하면 시작됩니다 (비밀번호 없음).',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLength: 20,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: '닉네임', border: OutlineInputBorder(), counterText: ''),
            onSubmitted: (_) => _submitting ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('시작하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text('🐜', style: TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GrowAnt',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
        ),
        const SizedBox(height: 8),
        Text(
          'AI와 투자 대결, 실력으로 증명하세요',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: const Color(0xFF666666)),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final BoxBorder? border;

  const _SocialButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
