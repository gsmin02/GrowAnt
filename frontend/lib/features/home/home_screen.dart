import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/mock/mock_data.dart';
import '../ai/ai_feedback_screen.dart';
import '../ai/psychology_screen.dart';
import '../duel/portfolio_detail_screen.dart';
import 'widgets/watchlist_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final returnDiff = mockMyReturn - mockAiReturn;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(mockUserName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  _TierChip(tier: mockUserTier),
                ],
              ),
              const SizedBox(height: 16),
              Text('총 평가 자산',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF888888))),
              const SizedBox(height: 4),
              Text(
                '${fmt.format(mockAsset)}원',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _ReturnBadge(rate: mockMyReturn),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('진행 중인 대결',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DuelStat(
                      label: '나',
                      value: mockMyReturn,
                      isMe: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PortfolioDetailScreen(
                            title: '내 포트폴리오',
                            holdings: mockMyHoldings,
                            isAi: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DuelStat(
                      label: '대결 AI',
                      value: mockAiReturn,
                      isMe: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PortfolioDetailScreen(
                            title: 'AI 포트폴리오',
                            holdings: mockAiHoldings,
                            isAi: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: returnDiff >= 0
                      ? upColor.withAlpha(20)
                      : downColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    returnDiff >= 0
                        ? '내가 AI보다 +${returnDiff.toStringAsFixed(1)}% 앞서는 중'
                        : 'AI가 나보다 +${(-returnDiff).toStringAsFixed(1)}% 앞서는 중',
                    style: TextStyle(
                      color: returnDiff >= 0 ? upColor : downColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('종료까지 D-$mockDuelDDay일',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const WatchlistCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ShortcutCard(
                icon: Icons.psychology_outlined,
                label: 'AI 피드백',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiFeedbackScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShortcutCard(
                icon: Icons.auto_graph,
                label: '심리 예측',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PsychologyScreen()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: child,
    );
  }
}

class _TierChip extends StatelessWidget {
  final String tier;
  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tier,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ReturnBadge extends StatelessWidget {
  final double rate;
  const _ReturnBadge({required this.rate});

  @override
  Widget build(BuildContext context) {
    final isUp = rate >= 0;
    return Text(
      '${isUp ? '+' : ''}${rate.toStringAsFixed(2)}%',
      style: TextStyle(
        color: isUp ? upColor : downColor,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }
}

class _DuelStat extends StatelessWidget {
  final String label;
  final double value;
  final bool isMe;
  final VoidCallback? onTap;
  const _DuelStat({required this.label, required this.value, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUp = value >= 0;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, size: 15, color: Color(0xFFBBBBBB)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${isUp ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isUp ? upColor : downColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: content);
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF444444)),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
