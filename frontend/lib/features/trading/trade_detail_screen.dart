import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import 'data/trade_models.dart';

class TradeDetailScreen extends StatelessWidget {
  final Trade trade;
  const TradeDetailScreen({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final color = trade.isBuy ? upColor : downColor;
    final fee = (trade.amount * 0.00015).round(); // mock 수수료 0.015%
    final settle = trade.isBuy ? trade.amount + fee : trade.amount - fee;

    return Scaffold(
      appBar: AppBar(title: const Text('거래 상세')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(trade.isBuy ? '매수' : '매도',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text(trade.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(trade.time,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 20),
          _InfoCard(rows: [
            _InfoRow('종류', trade.isBuy ? '매수' : '매도', valueColor: color),
            _InfoRow('단가', '${fmt.format(trade.price)}원'),
            _InfoRow('수량', '${fmt.format(trade.qty)}주'),
            _InfoRow('체결 금액', '${fmt.format(trade.amount)}원'),
            _InfoRow('수수료 (Mock)', '${fmt.format(fee)}원'),
            _InfoRow(trade.isBuy ? '총 결제 금액' : '정산 수령액',
                '${fmt.format(settle)}원',
                bold: true),
            _InfoRow('체결 시각', trade.time),
          ]),
          const SizedBox(height: 12),
          const Text('* 수수료는 임시 계산값 — 실제 수수료 정책 연동 시 대체됩니다.',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(children: rows),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF888888))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor,
                fontSize: bold ? 16 : 14,
              )),
        ],
      ),
    );
  }
}
