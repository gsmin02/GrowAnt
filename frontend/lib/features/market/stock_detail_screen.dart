import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/error/error_view.dart';
import '../../core/theme.dart';
import 'application/market_providers.dart';
import 'data/market_models.dart';
import 'stock_info_screen.dart';
import 'widgets/candle_chart.dart';
import 'widgets/line_chart.dart';
import 'widgets/order_book.dart';

class StockDetailScreen extends ConsumerWidget {
  final String ticker;
  const StockDetailScreen({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stockDetailProvider(ticker));
    final detail = async.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail?.name ?? ticker),
        actions: [
          if (detail != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: '상세 정보',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StockInfoScreen(detail: detail)),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final api = e is ApiException ? e : null;
          return ErrorView(
            kind: errorKindFromEventType(api?.eventType ?? 'NETWORK'),
            message: api?.message,
            onRetry: (api?.retryable ?? true)
                ? () => ref.invalidate(stockDetailProvider(ticker))
                : null,
          );
        },
        data: (d) => _DetailBody(detail: d),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final StockDetail detail;
  const _DetailBody({required this.detail});

  void _showOrderSheet(BuildContext context, bool isBuy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OrderSheet(name: detail.name, price: detail.price, isBuy: isBuy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final isUp = detail.changeRate >= 0;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 가격 요약 (흰색 카드)
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${fmt.format(detail.price)}원',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('${isUp ? '+' : ''}${detail.changeRate.toStringAsFixed(2)}%',
                              style: TextStyle(
                                  color: isUp ? upColor : downColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(detail.ticker,
                        style: const TextStyle(color: Color(0xFF999999), fontSize: 13)),
                  ],
                ),
              ),
              // 차트 (옅은 파란 카드) — 라인/캔들 토글
              _SectionCard(
                color: const Color(0xFFF1F5FB),
                child: _ChartSection(detail: detail),
              ),
              // 호가 (옅은 회색 카드)
              _SectionCard(
                color: const Color(0xFFFAFAFA),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('호가',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    OrderBook(price: detail.price, seed: detail.ticker.hashCode),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                    child: _OrderButton(
                        label: '매수', color: upColor, onTap: () => _showOrderSheet(context, true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _OrderButton(
                        label: '매도', color: downColor, onTap: () => _showOrderSheet(context, false))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 섹션 구분용 카드 (배경색 지정).
class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const _SectionCard({required this.child, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: child,
    );
  }
}

enum _ChartType { candle, line }

/// 라인/캔들 토글 + 선택된 차트 렌더.
class _ChartSection extends StatefulWidget {
  final StockDetail detail;
  const _ChartSection({required this.detail});

  @override
  State<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends State<_ChartSection> {
  _ChartType _type = _ChartType.candle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('차트 (최근 10일)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            SegmentedButton<_ChartType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _ChartType.candle, label: Text('캔들')),
                ButtonSegment(value: _ChartType.line, label: Text('라인')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _type == _ChartType.candle
            ? CandleChart(closes: widget.detail.candles, seed: widget.detail.ticker.hashCode)
            : LineChart(closes: widget.detail.candles),
      ],
    );
  }
}

class _OrderButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OrderButton({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}

// NOTE(market-slice): _OrderSheet은 mock 유지 — 거래(trading) 슬라이스에서 실연동. 스펙 §1
class _OrderSheet extends StatefulWidget {
  final String name;
  final int price;
  final bool isBuy;
  const _OrderSheet({required this.name, required this.price, required this.isBuy});
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  int _qty = 1;
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final total = widget.price * _qty;
    final color = widget.isBuy ? upColor : downColor;
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.isBuy ? '매수 주문' : '매도 주문',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(widget.name, style: const TextStyle(color: Color(0xFF888888))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('단가'),
            Text('${fmt.format(widget.price)}원', style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('수량'),
            const Spacer(),
            IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove_circle_outline)),
            SizedBox(
                width: 40,
                child: Text('$_qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
                onPressed: () => setState(() => _qty++),
                icon: const Icon(Icons.add_circle_outline)),
          ]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('주문 금액', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${fmt.format(total)}원',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '${widget.isBuy ? '매수' : '매도'} 주문 완료 (Mock): ${widget.name} $_qty주'),
                duration: const Duration(seconds: 2),
              ));
            },
            child: Text(widget.isBuy ? '매수 주문' : '매도 주문',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
