import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';

/// 한국 호가단위(간이) — 가격대별 1틱.
int tickSize(int price) {
  if (price < 2000) return 1;
  if (price < 5000) return 5;
  if (price < 20000) return 10;
  if (price < 50000) return 50;
  if (price < 200000) return 100;
  if (price < 500000) return 500;
  return 1000;
}

/// Mock 호가창: 현재가 ± 호가단위로 매도 5단(위)·매수 5단(아래) + mock 잔량.
/// (백엔드 호가 데이터 없음 — 실시간 연동 시 입력만 교체.)
class OrderBook extends StatelessWidget {
  final int price;
  final int seed; // 종목별 결정적 잔량 시드
  const OrderBook({super.key, required this.price, required this.seed});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final tick = tickSize(price);
    final rnd = Random(seed);

    // 매도호가: 높은 가격이 위 (price+5tick ... price+1tick)
    final asks = <(int, int)>[];
    for (var i = 5; i >= 1; i--) {
      asks.add((price + tick * i, 100 + rnd.nextInt(900)));
    }
    // 매수호가: price-1tick ... price-5tick
    final bids = <(int, int)>[];
    for (var i = 1; i <= 5; i++) {
      bids.add((price - tick * i, 100 + rnd.nextInt(900)));
    }
    final maxQty =
        [...asks.map((e) => e.$2), ...bids.map((e) => e.$2)].reduce(max);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          // 매도호가 = 파랑(한국 호가창 관습)
          for (final a in asks)
            _Level(price: a.$1, qty: a.$2, maxQty: maxQty, color: downColor, fmt: fmt),
          const Divider(height: 14),
          Row(
            children: [
              const Spacer(),
              Text('현재가 ${fmt.format(price)}원',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Divider(height: 14),
          // 매수호가 = 빨강
          for (final b in bids)
            _Level(price: b.$1, qty: b.$2, maxQty: maxQty, color: upColor, fmt: fmt),
          const SizedBox(height: 6),
          const Text('* Mock 호가 — 실시간 연동 시 대체',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 11)),
        ],
      ),
    );
  }
}

class _Level extends StatelessWidget {
  final int price;
  final int qty;
  final int maxQty;
  final Color color;
  final NumberFormat fmt;
  const _Level({
    required this.price,
    required this.qty,
    required this.maxQty,
    required this.color,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    height: 22,
                    width: (qty / maxQty) * 130,
                    color: color.withAlpha(28),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(fmt.format(qty),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Text(fmt.format(price),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}
