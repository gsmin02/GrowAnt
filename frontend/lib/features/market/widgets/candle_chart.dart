import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 일봉 캔들 차트. close 시계열(최근→오래된)에서 결정적 OHLC를 합성해 캔들스틱으로 렌더.
/// (백엔드가 close만 제공하는 mock 단계용 — 실제 OHLC 연동 시 입력만 교체.)
class CandleChart extends StatelessWidget {
  final List<int> closes; // [0]=최근 ... [last]=오래된
  final int seed; // 종목별 결정적 합성 시드
  const CandleChart({super.key, required this.closes, required this.seed});

  @override
  Widget build(BuildContext context) {
    final chron = closes.reversed.toList(); // 오래된 → 최근
    final rnd = Random(seed);
    final candles = <_Ohlc>[];
    for (var i = 0; i < chron.length; i++) {
      final close = chron[i];
      final open = i == 0 ? close : chron[i - 1];
      final hi = (max(open, close) * (1 + rnd.nextDouble() * 0.012)).round();
      final lo = (min(open, close) * (1 - rnd.nextDouble() * 0.012)).round();
      candles.add(_Ohlc(open, hi, lo, close));
    }
    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _CandlePainter(candles),
        size: const Size(double.infinity, 160),
      ),
    );
  }
}

class _Ohlc {
  final int open, high, low, close;
  const _Ohlc(this.open, this.high, this.low, this.close);
}

class _CandlePainter extends CustomPainter {
  final List<_Ohlc> candles;
  const _CandlePainter(this.candles);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final lo = candles.map((c) => c.low).reduce(min).toDouble();
    final hi = candles.map((c) => c.high).reduce(max).toDouble();
    final range = (hi - lo) == 0 ? 1.0 : (hi - lo);
    final n = candles.length;
    final slot = size.width / n;
    final bodyW = slot * 0.55;
    double y(num v) => size.height - (size.height * (v - lo) / range);

    for (var i = 0; i < n; i++) {
      final c = candles[i];
      final cx = slot * i + slot / 2;
      final up = c.close >= c.open; // 양봉(상승)=빨강
      final color = up ? upColor : downColor;
      // 꼬리(고가~저가)
      canvas.drawLine(
        Offset(cx, y(c.high)),
        Offset(cx, y(c.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1,
      );
      // 몸통(시가~종가)
      final top = y(max(c.open, c.close));
      final bot = y(min(c.open, c.close));
      canvas.drawRect(
        Rect.fromLTRB(cx - bodyW / 2, top, cx + bodyW / 2, (bot - top).abs() < 1 ? top + 1 : bot),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlePainter oldDelegate) => false;
}
