import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/mock/mock_data.dart';

class DividendScreen extends StatelessWidget {
  const DividendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('예상 배당 수령액',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${fmt.format(mockDividends.fold(0, (s, d) => s + d.amount * 10))}원 (예상)',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('보유 수량 기준 · Mock 계산',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('배당 일정',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        for (final d in mockDividends)
          _DividendCard(event: d, fmt: fmt),
      ],
    );
  }
}

class _DividendCard extends StatelessWidget {
  final DividendEvent event;
  final NumberFormat fmt;
  const _DividendCard({required this.event, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('배당락: ${event.exDate}',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                Text('지급일: ${event.payDate}',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt.format(event.amount)}원/주',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(event.ticker,
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
