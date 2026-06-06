import 'package:flutter/material.dart';

import '../../data/mock/mock_data.dart';

class PsychologyScreen extends StatelessWidget {
  const PsychologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('현재 심리 예측')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(),
          const SizedBox(height: 16),
          const Text('심리 지표',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          for (final p in mockPsychProfiles) _ProfileBar(profile: p),
          const SizedBox(height: 16),
          _NoticeCard(),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('투자 심리 분석',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mockPsychSummary,
            style: const TextStyle(
                color: Color(0xFFCCCCCC), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 12),
          const Text('최근 6주 거래 기반 분석',
              style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileBar extends StatelessWidget {
  final PsychProfile profile;
  const _ProfileBar({required this.profile});

  Color _barColor(int score) {
    if (score >= 70) return const Color(0xFFE53935);
    if (score >= 40) return const Color(0xFFFF8F00);
    return const Color(0xFF43A047);
  }

  String _riskLabel(int score) {
    if (score >= 70) return '높음';
    if (score >= 40) return '보통';
    return '낮음';
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor(profile.score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(profile.label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              Text(_riskLabel(profile.score),
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text('${profile.score}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: profile.score / 100,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC02)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFFFF8F00)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '이 예측은 Mock 데이터 기반입니다. 실제 서비스에서는 거래 패턴을 AI가 분석하여 제공합니다.',
              style: TextStyle(fontSize: 12, color: Color(0xFF795548), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
