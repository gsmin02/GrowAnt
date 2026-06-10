import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/error/error_view.dart';
import '../../core/theme.dart';
import '../market/stock_detail_screen.dart';
import 'application/portfolio_providers.dart';
import 'data/portfolio_models.dart';

/// 나/AI 공용 대결 포트폴리오 상세 — portfolioProvider(owner) 구독.
/// 합산(수익률·손익·매입/평가금액)은 서버 권위 값을 표시. AI면 각 행에 따라사기.
class PortfolioDetailScreen extends ConsumerWidget {
  final PortfolioOwner owner;
  const PortfolioDetailScreen({super.key, required this.owner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioProvider(owner));
    return Scaffold(
      appBar: AppBar(title: Text(owner.title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final api = e is ApiException ? e : null;
          return ErrorView(
            kind: errorKindFromEventType(api?.eventType ?? 'NETWORK'),
            message: api?.message,
            onRetry: (api?.retryable ?? true)
                ? () => ref.invalidate(portfolioProvider(owner))
                : null,
          );
        },
        data: (p) => _DetailBody(portfolio: p, isAi: owner.isAi),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Portfolio portfolio;
  final bool isAi;
  const _DetailBody({required this.portfolio, required this.isAi});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(portfolio: portfolio, fmt: fmt),
        const SizedBox(height: 16),
        const Text('보유 종목',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        for (final h in portfolio.holdings) _HoldingCard(holding: h, fmt: fmt, isAi: isAi),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Portfolio portfolio;
  final NumberFormat fmt;
  const _SummaryCard({required this.portfolio, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isUp = portfolio.profit >= 0;
    final color = isUp ? upColor : downColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('평가손익',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isUp ? '+' : ''}${fmt.format(portfolio.profit)}원',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${isUp ? '+' : ''}${portfolio.returnRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryChip(label: '매입금액', value: '${fmt.format(portfolio.cost)}원'),
              const SizedBox(width: 16),
              _SummaryChip(label: '평가금액', value: '${fmt.format(portfolio.value)}원'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HoldingCard extends StatelessWidget {
  final Holding holding;
  final NumberFormat fmt;
  final bool isAi;
  const _HoldingCard({required this.holding, required this.fmt, required this.isAi});

  @override
  Widget build(BuildContext context) {
    final h = holding;
    final value = h.currentPrice * h.qty;
    final profit = (h.currentPrice - h.avgPrice) * h.qty;
    final rate = h.avgPrice == 0 ? 0.0 : (h.currentPrice - h.avgPrice) / h.avgPrice * 100;
    final isUp = profit >= 0;
    final color = isUp ? upColor : downColor;

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
                Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${h.qty}주 · 평균 ${fmt.format(h.avgPrice)}원',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt.format(value)}원',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${isUp ? '+' : ''}${fmt.format(profit)}원 (${rate.toStringAsFixed(1)}%)',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          if (isAi) ...[
            const SizedBox(width: 10),
            _FollowBuyButton(ticker: h.ticker),
          ],
        ],
      ),
    );
  }
}

/// AI 종목 따라사기 → 해당 종목 상세 화면.
class _FollowBuyButton extends StatelessWidget {
  final String ticker;
  const _FollowBuyButton({required this.ticker});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: upColor,
        side: const BorderSide(color: upColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: ticker)),
      ),
      child: const Text('따라사기',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
