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
import '../account/application/account_providers.dart';
import '../duel/application/portfolio_providers.dart';
import '../duel/data/portfolio_models.dart';
import '../trading/application/trading_providers.dart';

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
      builder: (_) =>
          _OrderSheet(ticker: detail.ticker, name: detail.name, price: detail.price, isBuy: isBuy),
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
            _ChartToggle(
              type: _type,
              onChanged: (t) => setState(() => _type = t),
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

/// 모던 아이콘 세그먼트 토글 (iOS 스타일) — 캔들 / 라인.
class _ChartToggle extends StatelessWidget {
  final _ChartType type;
  final ValueChanged<_ChartType> onChanged;
  const _ChartToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(_ChartType.candle, Icons.candlestick_chart, '캔들'),
          _seg(_ChartType.line, Icons.show_chart, '라인'),
        ],
      ),
    );
  }

  Widget _seg(_ChartType t, IconData icon, String tooltip) {
    final selected = type == t;
    return GestureDetector(
      onTap: () => onChanged(t),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withAlpha(22),
                        blurRadius: 4,
                        offset: const Offset(0, 1)),
                  ]
                : null,
          ),
          child: Icon(icon, size: 19, color: selected ? inkColor : const Color(0xFF9E9E9E)),
        ),
      ),
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

/// 주문 시트 — POST /api/orders 실연동. 성공 시 서버 상태(현금·보유·내역)가
/// 변하므로 관련 provider를 invalidate해 홈/상세/내역을 갱신한다.
class _OrderSheet extends ConsumerStatefulWidget {
  final String ticker;
  final String name;
  final int price;
  final bool isBuy;
  const _OrderSheet(
      {required this.ticker, required this.name, required this.price, required this.isBuy});
  @override
  ConsumerState<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<_OrderSheet> {
  int _qty = 1;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final trade = await ref
          .read(tradeRepositoryProvider)
          .placeOrder(ticker: widget.ticker, isBuy: widget.isBuy, qty: _qty);
      ref.invalidate(portfolioProvider(PortfolioOwner.me));
      ref.invalidate(accountSummaryProvider);
      ref.invalidate(tradesProvider);
      // 전송 중 시트를 스와이프로 닫았을 수 있음 — pop은 mounted일 때만(상세 화면 오닫힘 방지).
      // 체결 자체는 완료됐으므로 스낵바(루트 messenger)는 항상 표시한다.
      if (mounted) navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('${widget.isBuy ? '매수' : '매도'} 체결: ${trade.name} ${trade.qty}주'),
        duration: const Duration(seconds: 2),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      // 스낵바는 모달 시트 뒤(Scaffold 하단)에 그려져 가려진다 — 실패는 시트 안 인라인으로 표시.
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.isBuy ? '매수 주문' : '매도 주문',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
