import 'package:flutter/material.dart';

import '../../data/mock/mock_data.dart';

class FeedbackDetailScreen extends StatelessWidget {
  final AiFeedbackItem item;
  const FeedbackDetailScreen({super.key, required this.item});

  static const _colors = {
    '잘한 점': Color(0xFF2E7D32),
    '개선점': Color(0xFFE53935),
    '제안': Color(0xFF1565C0),
  };
  static const _icons = {
    '잘한 점': Icons.check_circle_outline,
    '개선점': Icons.warning_amber_outlined,
    '제안': Icons.lightbulb_outline,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[item.category] ?? const Color(0xFF111111);
    final icon = _icons[item.category] ?? Icons.info_outline;

    return Scaffold(
      appBar: AppBar(title: const Text('피드백 상세')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(item.category,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.content,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('상세 분석',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text(item.detail,
                    style: const TextStyle(
                        fontSize: 14, height: 1.7, color: Color(0xFF333333))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('* Mock 분석 — 실제 LLM 연동 시 대체됩니다.',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
        ],
      ),
    );
  }
}
