import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/mock/mock_data.dart';

class DuelSetupScreen extends StatefulWidget {
  const DuelSetupScreen({super.key});

  @override
  State<DuelSetupScreen> createState() => _DuelSetupScreenState();
}

class _DuelSetupScreenState extends State<DuelSetupScreen> {
  String _selectedOpponentId = mockOpponents.first.id;
  String _selectedDuration = mockDuelDurations.first;
  int _selectedSeed = mockDuelSeeds.first;

  AiOpponent get _opponent =>
      mockOpponents.firstWhere((o) => o.id == _selectedOpponentId);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('대결 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'AI 상대 선택',
            child: Column(
              children: [
                for (final opp in mockOpponents)
                  _OpponentTile(
                    opponent: opp,
                    selected: _selectedOpponentId == opp.id,
                    onTap: () => setState(() => _selectedOpponentId = opp.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: '대결 기간',
            child: Wrap(
              spacing: 8,
              children: [
                for (final d in mockDuelDurations)
                  ChoiceChip(
                    label: Text(d),
                    selected: _selectedDuration == d,
                    onSelected: (_) => setState(() => _selectedDuration = d),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: '시드 머니',
            child: Wrap(
              spacing: 8,
              children: [
                for (final seed in mockDuelSeeds)
                  ChoiceChip(
                    label: Text('${fmt.format(seed ~/ 10000)}만원'),
                    selected: _selectedSeed == seed,
                    onSelected: (_) => setState(() => _selectedSeed = seed),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SummaryCard(
            opponent: _opponent,
            duration: _selectedDuration,
            seed: _selectedSeed,
            fmt: fmt,
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('대결이 시작되었습니다! (Mock)'),
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('대결 시작',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  final AiOpponent opponent;
  final bool selected;
  final VoidCallback onTap;
  const _OpponentTile(
      {required this.opponent, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(opponent.name,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selected ? Colors.white : const Color(0xFF111111))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withAlpha(30)
                              : const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(opponent.style,
                            style: TextStyle(
                                fontSize: 11,
                                color: selected ? Colors.white : const Color(0xFF666666))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(opponent.description,
                      style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? Colors.white.withAlpha(180)
                              : const Color(0xFF888888))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('평균 수익',
                    style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.white.withAlpha(160)
                            : const Color(0xFF888888))),
                Text('+${opponent.avgReturn}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : const Color(0xFF111111))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AiOpponent opponent;
  final String duration;
  final int seed;
  final NumberFormat fmt;
  const _SummaryCard(
      {required this.opponent, required this.duration, required this.seed, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _Row(label: '상대', value: opponent.name),
          _Row(label: '기간', value: duration),
          _Row(label: '시드', value: '${fmt.format(seed)}원'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
