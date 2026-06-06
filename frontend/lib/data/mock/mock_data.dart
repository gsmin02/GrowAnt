/// Mock 데이터 — 백엔드 연동 전 UI 개발용. 추후 repository로 교체.

class Stock {
  final String ticker;
  final String name;
  final int price;
  final double changeRate; // %
  const Stock(this.ticker, this.name, this.price, this.changeRate);
}

class Trade {
  final String name;
  final bool isBuy;
  final int amount; // 체결 금액
  final int price; // 단가
  final int qty;
  final String time;
  const Trade(this.name, this.isBuy, this.amount, this.price, this.qty, this.time);
}

// 홈/대결
const int mockAsset = 10520000; // 나의 가상 자산
const int mockSeed = 10000000; // 초기 시드
const double mockMyReturn = 5.2; // 나 수익률(%)
const double mockAiReturn = 3.8; // AI 수익률(%)
const int mockDuelDDay = 18;

// 마켓
const List<Stock> mockMarket = [
  Stock('005930', '삼성전자', 76300, 5.97),
  Stock('000660', 'SK하이닉스', 178500, 3.41),
  Stock('035720', '카카오', 41200, -2.10),
  Stock('035420', 'NAVER', 198400, 1.55),
  Stock('005380', '현대차', 247000, -0.81),
];

// 거래 내역
const List<Trade> mockTrades = [
  Trade('삼성전자', false, 763000, 76300, 10, '05.10 14:32'),
  Trade('애플', true, 504000, 252000, 2, '05.10 10:08'),
  Trade('SK하이닉스', true, 903500, 180700, 5, '05.09 15:18'),
  Trade('카카오', false, 412000, 41200, 10, '05.09 11:45'),
];
