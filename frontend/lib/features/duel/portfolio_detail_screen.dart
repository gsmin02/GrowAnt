import '../../data/mock/mock_data.dart';

/// 보유 종목 합산 계산(순수 함수). UI 없이 단위 테스트 가능.
int portfolioCost(List<Holding> hs) =>
    hs.fold(0, (s, h) => s + h.avgPrice * h.qty);
int portfolioValue(List<Holding> hs) =>
    hs.fold(0, (s, h) => s + h.currentPrice * h.qty);
int portfolioProfit(List<Holding> hs) =>
    portfolioValue(hs) - portfolioCost(hs);
double portfolioReturnRate(List<Holding> hs) {
  final cost = portfolioCost(hs);
  return cost == 0 ? 0 : portfolioProfit(hs) / cost * 100;
}
