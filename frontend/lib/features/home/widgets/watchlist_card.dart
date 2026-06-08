import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme.dart';
import '../../market/application/market_providers.dart';
import '../../market/data/market_models.dart';
import '../../market/stock_detail_screen.dart';

/// 홈 '관심 종목' 카드 — marketListProvider(GET /api/market) 상위 3종목.
/// 임베드 카드라 로딩/에러는 컴팩트 인라인으로 처리(전체 ErrorView 미사용).
class WatchlistCard extends ConsumerWidget {
  const WatchlistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketListProvider);
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
          const Text('관심 종목',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          async.when(
            loading: () => const SizedBox(
              height: 88,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => _WatchlistError(
              message: e is ApiException ? e.message : '시세를 불러오지 못했어요',
              onRetry: (e is ApiException ? e.retryable : true)
                  ? () => ref.read(marketListProvider.notifier).refresh()
                  : null,
            ),
            data: (rows) => Column(
              children: [
                for (final r in rows.take(3)) _StockRow(row: r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 내부 컴팩트 에러(메시지 + 재시도). retryable=false면 메시지만.
class _WatchlistError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _WatchlistError({required this.message, this.onRetry});

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

/// 관심 종목 행 — MarketRow 기반. 탭 시 종목 상세로 이동.
class _StockRow extends StatelessWidget {
  final MarketRow row;
  const _StockRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final isUp = row.changeRate >= 0;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: row.ticker)),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(row.ticker,
                      style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${fmt.format(row.price)}원',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${isUp ? '+' : ''}${row.changeRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: isUp ? upColor : downColor, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
