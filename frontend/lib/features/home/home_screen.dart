import 'package:flutter/material.dart';

import '../ai/ai_feedback_screen.dart';
import '../ai/psychology_screen.dart';
import 'widgets/watchlist_card.dart';
import 'widgets/asset_card.dart';
import 'widgets/duel_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AssetCard(),
        const SizedBox(height: 12),
        const DuelCard(),
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
