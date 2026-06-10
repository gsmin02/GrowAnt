/// 대결 포트폴리오 주체. path=API 경로 세그먼트, title=상세 화면 타이틀.
enum PortfolioOwner {
  me('me', '내 포트폴리오'),
  ai('ai', 'AI 포트폴리오');

  final String path;
  final String title;
  const PortfolioOwner(this.path, this.title);

  bool get isAi => this == PortfolioOwner.ai;
}

class Holding {
  final String ticker;
  final String name;
  final int qty;
  final int avgPrice;
  final int currentPrice;
  const Holding({
    required this.ticker,
    required this.name,
    required this.qty,
    required this.avgPrice,
    required this.currentPrice,
  });

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        ticker: j['ticker'] as String,
        name: j['name'] as String,
        qty: (j['qty'] as num).toInt(),
        avgPrice: (j['avgPrice'] as num).toInt(),
        currentPrice: (j['currentPrice'] as num).toInt(),
      );
}

/// 서버 권위 합산값 포함(returnRate는 소수 1자리 반올림되어 내려온다).
class Portfolio {
  final double returnRate;
  final int profit;
  final int cost;
  final int value;
  final List<Holding> holdings;
  const Portfolio({
    required this.returnRate,
    required this.profit,
    required this.cost,
    required this.value,
    required this.holdings,
  });

  factory Portfolio.fromJson(Map<String, dynamic> j) => Portfolio(
        returnRate: (j['returnRate'] as num).toDouble(),
        profit: (j['profit'] as num).toInt(),
        cost: (j['cost'] as num).toInt(),
        value: (j['value'] as num).toInt(),
        holdings: (j['holdings'] as List)
            .map((e) => Holding.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
