import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/mock/mock_data.dart';

class StockDetailScreen extends StatefulWidget {
  final Stock stock;
  const StockDetailScreen({super.key, required this.stock});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  void _showOrderSheet(BuildContext context, bool isBuy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OrderSheet(stock: widget.stock, isBuy: isBuy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final stock = widget.stock;
    final isUp = stock.changeRate >= 0;

    return Scaffold(
      appBar: AppBar(title: Text(stock.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt.format(stock.price)}원',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${isUp ? '+' : ''}${stock.changeRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: isUp ? upColor : downColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(stock.ticker,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 13)),
          const SizedBox(height: 24),
          const Text('가격 추이 (최근 10일)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _MiniChart(prices: mockCandleClose),
          const SizedBox(height: 24),
          _InfoRow(label: '52주 최고', value: '${fmt.format((stock.price * 1.18).round())}원'),
          _InfoRow(label: '52주 최저', value: '${fmt.format((stock.price * 0.72).round())}원'),
          _InfoRow(label: '거래량', value: '14,823,410주'),
          _InfoRow(label: '시가총액', value: '${fmt.format((stock.price * 5969783300 ~/ 1000000))}억원'),
          _InfoRow(label: 'PER', value: '12.4x'),
          _InfoRow(label: 'PBR', value: '1.2x'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: upColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showOrderSheet(context, true),
                  child: const Text('매수', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: downColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showOrderSheet(context, false),
                  child: const Text('매도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<int> prices;
  const _MiniChart({required this.prices});

  @override
  Widget build(BuildContext context) {
    final reversed = prices.reversed.toList();
    final minP = reversed.reduce((a, b) => a < b ? a : b);
    final maxP = reversed.reduce((a, b) => a > b ? a : b);
    final range = (maxP - minP).toDouble();

    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _LinePainter(prices: reversed, min: minP, range: range),
        size: const Size(double.infinity, 100),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<int> prices;
  final int min;
  final double range;
  const _LinePainter({required this.prices, required this.min, required this.range});

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty || range == 0) return;
    final paint = Paint()
      ..color = upColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final n = prices.length;
    final pts = List.generate(n, (i) {
      final x = size.width * i / (n - 1);
      final y = size.height - (size.height * (prices[i] - min) / range);
      return Offset(x, y);
    });

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LinePainter old) => false;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF888888))),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _OrderSheet extends StatefulWidget {
  final Stock stock;
  final bool isBuy;
  const _OrderSheet({required this.stock, required this.isBuy});

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final total = widget.stock.price * _qty;
    final color = widget.isBuy ? upColor : downColor;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isBuy ? '매수 주문' : '매도 주문',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(widget.stock.name, style: const TextStyle(color: Color(0xFF888888))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('단가'),
              Text('${fmt.format(widget.stock.price)}원',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('수량'),
              const Spacer(),
              IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 40,
                child: Text('$_qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                onPressed: () => setState(() => _qty++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('주문 금액', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${fmt.format(total)}원',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${widget.isBuy ? '매수' : '매도'} 주문 완료 (Mock): ${widget.stock.name} $_qty주'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(widget.isBuy ? '매수 주문' : '매도 주문',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
