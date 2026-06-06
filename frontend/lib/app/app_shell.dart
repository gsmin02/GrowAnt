import 'package:flutter/material.dart';

/// 하단 5탭 셸: 홈 · 거래 · 대결 · 내역 · 마이.
/// 각 탭 본문은 Mock 단계에서 실제 화면으로 채운다.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GrowAnt · ${_tabs[_index]}')),
      body: Center(
        child: Text(
          '${_tabs[_index]} 화면 (Mock 단계에서 구현)',
          style: const TextStyle(fontSize: 16, color: Color(0xFF777777)),
        ),
      ),
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
