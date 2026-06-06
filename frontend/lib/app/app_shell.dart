import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/market/market_dashboard_screen.dart';
import '../features/duel/duel_setup_screen.dart';
import '../features/trading/trade_history_screen.dart';
import '../features/account/account_screen.dart';

/// 하단 5탭 셸: 홈 · 거래 · 대결 · 내역 · 마이.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = ['홈', '거래', '대결', '내역', '마이'];
  static const _icons = [
    Icons.home_outlined,
    Icons.show_chart,
    Icons.sports_kabaddi_outlined,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ];

  static const _screens = [
    HomeScreen(),
    MarketDashboardScreen(),
    _DuelTab(),
    TradeHistoryScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GrowAnt · ${_tabs[_index]}')),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(icon: Icon(_icons[i]), label: _tabs[i]),
        ],
      ),
    );
  }
}

/// 대결 탭 — 진행 중 대결 요약 + 설정 진입 버튼
class _DuelTab extends StatelessWidget {
  const _DuelTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_kabaddi_outlined, size: 56, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 16),
          const Text('진행 중인 대결이 없습니다.',
              style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DuelSetupScreen()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('새 대결 시작', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
