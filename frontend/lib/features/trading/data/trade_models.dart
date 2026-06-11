/// 체결 내역 — 서버 TradeDto와 1:1 (time은 "MM.dd HH:mm" 문자열).
class Trade {
  final String name;
  final bool isBuy;
  final int price;
  final int qty;
  final int amount;
  final String time;
  const Trade({
    required this.name,
    required this.isBuy,
    required this.price,
    required this.qty,
    required this.amount,
    required this.time,
  });

  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
        name: j['name'] as String,
        isBuy: j['isBuy'] as bool,
        price: (j['price'] as num).toInt(),
        qty: (j['qty'] as num).toInt(),
        amount: (j['amount'] as num).toInt(),
        time: j['time'] as String,
      );
}
