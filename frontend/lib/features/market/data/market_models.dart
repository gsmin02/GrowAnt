class MarketRow {
  final String ticker;
  final String name;
  final int price;
  final double changeRate;
  const MarketRow({required this.ticker, required this.name, required this.price, required this.changeRate});

  factory MarketRow.fromJson(Map<String, dynamic> j) => MarketRow(
        ticker: j['ticker'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        changeRate: (j['changeRate'] as num).toDouble(),
      );
}

class StockDetail {
  final String ticker;
  final String name;
  final int price;
  final double changeRate;
  final List<int> candles;
  final int high52w;
  final int low52w;
  final int volume;
  final int marketCapEok;
  final double per;
  final double pbr;
  const StockDetail({
    required this.ticker, required this.name, required this.price, required this.changeRate,
    required this.candles, required this.high52w, required this.low52w,
    required this.volume, required this.marketCapEok, required this.per, required this.pbr,
  });

  factory StockDetail.fromJson(Map<String, dynamic> j) => StockDetail(
        ticker: j['ticker'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        changeRate: (j['changeRate'] as num).toDouble(),
        candles: (j['candles'] as List).map((e) => (e as num).toInt()).toList(),
        high52w: (j['high52w'] as num).toInt(),
        low52w: (j['low52w'] as num).toInt(),
        volume: (j['volume'] as num).toInt(),
        marketCapEok: (j['marketCapEok'] as num).toInt(),
        per: (j['per'] as num).toDouble(),
        pbr: (j['pbr'] as num).toDouble(),
      );
}
