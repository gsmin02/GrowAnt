import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../data/mock/mock_data.dart';
import '../../duel/application/portfolio_providers.dart';
import '../../duel/data/portfolio_models.dart';
import '../../duel/portfolio_detail_screen.dart';

/// 홈 '진행 중인 대결' 카드 — 내/AI 포트폴리오 수익률(서버 합산) 비교.
/// D-day는 대결 메타라 mock 유지(대결 슬라이스에서 이전). 로딩/에러는 컴팩트 인라인.
class DuelCard extends ConsumerWidget {
  const DuelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAsync = ref.watch(portfolioProvider(PortfolioOwner.me));
    final aiAsync = ref.watch(portfolioProvider(PortfolioOwner.ai));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('진행 중인 대결',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _body(context, ref, myAsync, aiAsync),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref,
      AsyncValue<Portfolio> myAsync, AsyncValue<Portfolio> aiAsync) {
    if (myAsync.hasError || aiAsync.hasError) {
      final e = myAsync.error ?? aiAsync.error;
      final api = e is ApiException ? e : null;
      return _DuelError(
        message: api?.message ?? '대결 정보를 불러오지 못했어요',
        onRetry: (api?.retryable ?? true)
            ? () {
                ref.invalidate(portfolioProvider(PortfolioOwner.me));
                ref.invalidate(portfolioProvider(PortfolioOwner.ai));
              }
            : null,
      );
    }
    final my = myAsync.valueOrNull;
    final ai = aiAsync.valueOrNull;
    if (my == null || ai == null) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final returnDiff = my.returnRate - ai.returnRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _DuelStat(
                label: '나',
                value: my.returnRate,
                isMe: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const PortfolioDetailScreen(owner: PortfolioOwner.me),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: _DuelStat(
                label: '대결 AI',
                value: ai.returnRate,
                isMe: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const PortfolioDetailScreen(owner: PortfolioOwner.ai),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: returnDiff >= 0 ? upColor.withAlpha(20) : downColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              returnDiff >= 0
                  ? '내가 AI보다 +${returnDiff.toStringAsFixed(1)}% 앞서는 중'
                  : 'AI가 나보다 +${(-returnDiff).toStringAsFixed(1)}% 앞서는 중',
              style: TextStyle(
                color: returnDiff >= 0 ? upColor : downColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('종료까지 D-$mockDuelDDay일',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
      ],
    );
  }
}

/// 카드 내부 컴팩트 에러(메시지 + 재시도). retryable=false면 메시지만.
class _DuelError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _DuelError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('재시도'),
            ),
        ],
      ),
    );
  }
}

class _DuelStat extends StatelessWidget {
  final String label;
  final double value;
  final bool isMe;
  final VoidCallback? onTap;
  const _DuelStat({required this.label, required this.value, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUp = value >= 0;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, size: 15, color: Color(0xFFBBBBBB)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isUp ? upColor : downColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: content);
  }
}
