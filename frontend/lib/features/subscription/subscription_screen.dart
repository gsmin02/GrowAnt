import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/mock/mock_data.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentTier = mockUserTier;
  String? _selectedId;

  void _subscribe(String planId, String planName) {
    setState(() => _currentTier = planName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$planName 플랜으로 변경되었습니다. (Mock — 실제 결제 미연동)'),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('요금제 선택')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 8),
                Text('현재 플랜: ',
                    style: const TextStyle(color: Color(0xFF888888))),
                Text(_currentTier,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final plan in mockPlans)
            _PlanCard(
              plan: plan,
              isCurrent: plan.name == _currentTier,
              isSelected: _selectedId == plan.id,
              onTap: () => setState(() => _selectedId = plan.id),
              onSubscribe: () => _subscribe(plan.id, plan.name),
              fmt: fmt,
            ),
          const SizedBox(height: 8),
          const Text(
            '* Mock 결제: 요금제 선택 시 즉시 적용됩니다. 실제 PG 미연동.',
            style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  final NumberFormat fmt;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isSelected,
    required this.onTap,
    required this.onSubscribe,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = plan.id == 'premium';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF111111)
                : isCurrent
                    ? const Color(0xFF888888)
                    : const Color(0xFFEEEEEE),
            width: isSelected || isCurrent ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                if (isPremium) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('추천',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  const Text('현재',
                      style: TextStyle(
                          color: Color(0xFF888888), fontSize: 12)),
                ],
                const Spacer(),
                Text(
                  plan.priceMonthly == 0
                      ? '무료'
                      : '${fmt.format(plan.priceMonthly)}원/월',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _FeatureRow(icon: Icons.data_usage_outlined, label: '사용량: ${plan.usageLabel}'),
            _FeatureRow(
              icon: plan.hasAds ? Icons.ad_units_outlined : Icons.block,
              label: plan.hasAds ? '광고 포함' : '광고 없음',
              muted: plan.hasAds,
            ),
            _FeatureRow(
              icon: Icons.smart_toy_outlined,
              label: plan.canChoosePro
                  ? 'AI 모델: Flash / Pro 선택'
                  : 'AI 모델: Gemini Flash',
            ),
            if (isSelected && !isCurrent) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onSubscribe,
                  child: Text('${plan.name} 시작하기 (Mock)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool muted;
  const _FeatureRow({required this.icon, required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: muted ? const Color(0xFFCCCCCC) : const Color(0xFF666666)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: muted ? const Color(0xFFCCCCCC) : const Color(0xFF444444))),
        ],
      ),
    );
  }
}
