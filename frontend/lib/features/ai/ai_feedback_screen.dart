import 'package:flutter/material.dart';

import '../../data/mock/mock_data.dart';
import 'feedback_detail_screen.dart';

class AiFeedbackScreen extends StatelessWidget {
  const AiFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 피드백')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(tier: mockUserTier),
          const SizedBox(height: 16),
          for (final item in mockFeedback) _FeedbackCard(item: item),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String tier;
  const _HeaderCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isPremium = tier == 'Premium';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('최근 거래 AI 분석',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPremium ? 'Gemini Pro' : 'Gemini Flash',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'Premium: 상세 분석 모드가 적용되었습니다.'
                : '$tier: 일반 분석 모드입니다. Premium에서 더 상세한 피드백을 받으세요.',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final AiFeedbackItem item;
  const _FeedbackCard({required this.item});

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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FeedbackDetailScreen(item: item)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        // 좌측 색상 바
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(40),
            blurRadius: 0,
            offset: const Offset(-3, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.category,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(item.content,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
        ],
      ),
      ),
    );
  }
}
