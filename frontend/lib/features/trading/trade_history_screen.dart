import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/error/error_view.dart';
import '../../core/theme.dart';
import 'application/trading_providers.dart';
import 'data/trade_models.dart';
import 'trade_detail_screen.dart';

class TradeHistoryScreen extends ConsumerWidget {
  const TradeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tradesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final api = e is ApiException ? e : null;
        return ErrorView(
          kind: errorKindFromEventType(api?.eventType ?? 'NETWORK'),
          message: api?.message,
          onRetry: (api?.retryable ?? true)
              ? () => ref.read(tradesProvider.notifier).refresh()
              : null,
        );
      },
      data: (trades) {
        final fmt = NumberFormat('#,###');
        return Column(
          children: [
            _SummaryBar(trades: trades),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: trades.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (_, i) => _TradeTile(trade: trades[i], fmt: fmt),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<Trade> trades;
  const _SummaryBar({required this.trades});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final buyTotal = trades
        .where((t) => t.isBuy)
        .fold(0, (sum, t) => sum + t.amount);
    final sellTotal = trades
        .where((t) => !t.isBuy)
        .fold(0, (sum, t) => sum + t.amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: '총 매수',
              value: '${fmt.format(buyTotal)}원',
              color: upColor,
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFEEEEEE)),
          Expanded(
            child: _StatCell(
              label: '총 매도',
              value: '${fmt.format(sellTotal)}원',
              color: downColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}

class _TradeTile extends StatelessWidget {
  final Trade trade;
  final NumberFormat fmt;
  const _TradeTile({required this.trade, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TradeDetailScreen(trade: trade)),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: trade.isBuy ? upColor.withAlpha(20) : downColor.withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            trade.isBuy ? '매수' : '매도',
            style: TextStyle(
              color: trade.isBuy ? upColor : downColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(trade.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${trade.qty}주',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
        ],
      ),
      subtitle: Text('${fmt.format(trade.price)}원 · ${trade.time}',
          style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
      trailing: Text(
        '${fmt.format(trade.amount)}원',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
