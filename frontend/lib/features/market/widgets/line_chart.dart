import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 종가 라인(추세) 차트 — 캔들과 토글되는 단순 뷰. closes: [0]=최근 ... [last]=오래된.
class LineChart extends StatelessWidget {
  final List<int> closes;
  const LineChart({super.key, required this.closes});

  @override
  Widget build(BuildContext context) {
    final reversed = closes.reversed.toList(); // 오래된 → 최근
    final minP = reversed.reduce((a, b) => a < b ? a : b);
    final maxP = reversed.reduce((a, b) => a > b ? a : b);
    final range = (maxP - minP).toDouble();
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _LinePainter(prices: reversed, min: minP, range: range),
        size: const Size(double.infinity, 160),
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
      ..color = inkColor
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
  bool shouldRepaint(covariant _LinePainter oldDelegate) => false;
}
