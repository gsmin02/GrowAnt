import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../../data/mock/mock_data.dart';
import '../../account/application/account_providers.dart';

/// 홈 자산 요약 카드 — accountSummaryProvider(GET /api/account/summary).
/// 프로필(이름·티어)은 auth 도메인이라 mock 유지. 로딩/에러는 컴팩트 인라인.
class AssetCard extends ConsumerWidget {
  const AssetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,###');
    final async = ref.watch(accountSummaryProvider);
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
          Row(
            children: [
              Text(mockUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              _TierChip(tier: mockUserTier),
            ],
          ),
          const SizedBox(height: 16),
          Text('총 평가 자산',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF888888))),
          const SizedBox(height: 4),
          async.when(
            loading: () => const SizedBox(
              height: 58,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            error: (e, _) => _AssetError(
              message: e is ApiException ? e.message : '자산 정보를 불러오지 못했어요',
              onRetry: (e is ApiException ? e.retryable : true)
                  ? () => ref.invalidate(accountSummaryProvider)
                  : null,
            ),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmt.format(s.totalAsset)}원',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                _ReturnBadge(rate: s.returnRate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 내부 컴팩트 에러(메시지 + 재시도). retryable=false면 메시지만.
class _AssetError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _AssetError({required this.message, this.onRetry});

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

class _ReturnBadge extends StatelessWidget {
  final double rate;
  const _ReturnBadge({required this.rate});

  @override
  Widget build(BuildContext context) {
    final isUp = rate >= 0;
    return Text(
      '${isUp ? '+' : ''}${rate.toStringAsFixed(2)}%',
      style: TextStyle(
        color: isUp ? upColor : downColor,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String tier;
  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tier,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
