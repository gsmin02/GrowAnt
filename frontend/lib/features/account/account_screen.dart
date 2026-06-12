import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/mock/mock_data.dart';
import '../auth/application/auth_providers.dart';
import '../subscription/subscription_screen.dart';
import '../exchange/exchange_screen.dart';
import '../trading/dividend_screen.dart';

/// provider id → 사용자 노출 라벨. AuthGate 뒤에서는 user가 항상 있지만 위젯 단독 사용 대비 null 허용.
String providerLoginLabel(String? provider) => switch (provider) {
      'kakao' => '카카오 로그인',
      'naver' => '네이버 로그인',
      'apple' => 'Apple 로그인',
      'google' => 'Google 로그인',
      _ => '데모 계정',
    };

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,###');
    final user = ref.watch(authControllerProvider).value;
    final nickname = user?.nickname ?? '투자자';
    final totalReturn =
        (mockTotalAsset - mockSeed) / mockSeed * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // 사용자 헤더
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF111111),
              child: Text(
                nickname[0],
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(providerLoginLabel(user?.provider),
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 13)),
                const SizedBox(height: 4),
                _TierChip(tier: mockUserTier),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // 자산 요약
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('총 평가 자산',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
              const SizedBox(height: 4),
              Text('${fmt.format(mockTotalAsset)}원',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _AssetChip(
                    label: '주식',
                    value: '${fmt.format(mockStockValue)}원',
                  ),
                  const SizedBox(width: 12),
                  _AssetChip(
                    label: '현금',
                    value: '${fmt.format(mockCash)}원',
                  ),
                  const Spacer(),
                  Text(
                    '${totalReturn >= 0 ? '+' : ''}${totalReturn.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: totalReturn >= 0 ? upColor : downColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 보유 종목
        const Text('보유 종목',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        for (final h in mockHoldings) _HoldingRow(holding: h, fmt: fmt),
        const SizedBox(height: 16),
        // 메뉴
        _MenuItem(
          icon: Icons.card_membership_outlined,
          label: '요금제 관리',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
        ),
        _MenuItem(
          icon: Icons.currency_exchange,
          label: '환전',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ExchangeScreen())),
        ),
        _MenuItem(
          icon: Icons.calendar_month_outlined,
          label: '배당금 일정',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DividendScreen())),
        ),
        _MenuItem(
          icon: Icons.logout,
          label: '로그아웃',
          onTap: () async {
            // 루트 messenger를 먼저 캡처 — logout 후 이 화면은 AuthGate에 의해 언마운트된다.
            final messenger = ScaffoldMessenger.of(context);
            await ref.read(authControllerProvider.notifier).logout();
            messenger.showSnackBar(const SnackBar(
                content: Text('로그아웃 되었습니다.'), duration: Duration(seconds: 2)));
          },
        ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String tier;
  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tier,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _AssetChip extends StatelessWidget {
  final String label;
  final String value;
  const _AssetChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
        Text(value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final Map<String, dynamic> holding;
  final NumberFormat fmt;
  const _HoldingRow({required this.holding, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final diff = ((holding['currentPrice'] as int) - (holding['avgPrice'] as int)) *
        (holding['qty'] as int);
    final rate = ((holding['currentPrice'] as int) - (holding['avgPrice'] as int)) /
        (holding['avgPrice'] as int) *
        100;
    final isUp = diff >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(holding['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${holding['qty']}주 · 평균 ${fmt.format(holding['avgPrice'])}원',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt.format((holding['currentPrice'] as int) * (holding['qty'] as int))}원',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${isUp ? '+' : ''}${fmt.format(diff)}원 (${rate.toStringAsFixed(1)}%)',
                style: TextStyle(
                    color: isUp ? upColor : downColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF444444)),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
      onTap: onTap,
    );
  }
}
