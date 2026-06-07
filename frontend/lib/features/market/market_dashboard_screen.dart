import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/mock/mock_data.dart';
import 'stock_detail_screen.dart';

class MarketDashboardScreen extends StatefulWidget {
  const MarketDashboardScreen({super.key});

  @override
  State<MarketDashboardScreen> createState() => _MarketDashboardScreenState();
}

class _MarketDashboardScreenState extends State<MarketDashboardScreen> {
  // TODO(market-slice): mockMarket 대신 ref.watch(marketListProvider).when(loading 스피너 / error: ErrorView / data)로 바인딩.
  //   ConsumerStatefulWidget으로 전환, 검색 필터·상승/하락 집계 로직은 유지. 스펙 §4.5
  String _query = '';

  List<Stock> get _filtered => mockMarket
      .where((s) =>
          s.name.contains(_query) || s.ticker.contains(_query))
      .toList();

  @override
  Widget build(BuildContext context) {
    final kospiStocks = _filtered;
    final upCount = kospiStocks.where((s) => s.changeRate >= 0).length;
    final downCount = kospiStocks.length - upCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _MarketStat(label: '상승', count: upCount, color: upColor),
                  const SizedBox(width: 16),
                  _MarketStat(label: '하락', count: downCount, color: downColor),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: '종목명 또는 코드 검색',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
            itemBuilder: (_, i) => _StockTile(stock: _filtered[i]),
          ),
        ),
      ],
    );
  }
}

class _MarketStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MarketStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label $count', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StockTile extends StatelessWidget {
  final Stock stock;
  const _StockTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final isUp = stock.changeRate >= 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      // TODO(market-slice): StockDetailScreen(stock:) → StockDetailScreen(ticker: stock.ticker) (상세는 ticker로 재조회). 스펙 §4.5
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)),
      ),
      title: Text(stock.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(stock.ticker,
          style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${fmt.format(stock.price)}원',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          Text(
            '${isUp ? '+' : ''}${stock.changeRate.toStringAsFixed(2)}%',
            style: TextStyle(
              color: isUp ? upColor : downColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
