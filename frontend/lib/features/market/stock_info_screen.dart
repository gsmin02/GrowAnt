import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/market_models.dart';

/// 종목 상세 정보(펀더멘털) 페이지 — 주식 상세 화면 우상단 액션에서 진입.
class StockInfoScreen extends StatelessWidget {
  final StockDetail detail;
  const StockInfoScreen({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return Scaffold(
      appBar: AppBar(title: Text('${detail.name} 상세 정보')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              children: [
                _InfoRow('현재가', '${fmt.format(detail.price)}원'),
                _InfoRow('52주 최고', '${fmt.format(detail.high52w)}원'),
                _InfoRow('52주 최저', '${fmt.format(detail.low52w)}원'),
                _InfoRow('거래량', '${fmt.format(detail.volume)}주'),
                _InfoRow('시가총액', '${fmt.format(detail.marketCapEok)}억원'),
                _InfoRow('PER', '${detail.per}x'),
                _InfoRow('PBR', '${detail.pbr}x'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('* 일부 값은 Mock — 실제 데이터 연동 시 대체됩니다.',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
