/// Mock 데이터 — 백엔드 연동 전 UI 개발용. 추후 repository로 교체.

class Trade {
  final String name;
  final bool isBuy;
  final int amount; // 체결 금액
  final int price; // 단가
  final int qty;
  final String time;
  const Trade(this.name, this.isBuy, this.amount, this.price, this.qty, this.time);
}

class DividendEvent {
  final String ticker;
  final String name;
  final String exDate; // 배당락일
  final String payDate; // 지급일
  final int amount; // 1주당 배당금(원)
  const DividendEvent(this.ticker, this.name, this.exDate, this.payDate, this.amount);
}

class AiOpponent {
  final String id;
  final String name;
  final String style;
  final String description;
  final double avgReturn; // 평균 수익률(%)
  const AiOpponent(this.id, this.name, this.style, this.description, this.avgReturn);
}

class AiFeedbackItem {
  final String category; // 잘한 점 / 개선점 / 제안
  final String content;
  final String detail; // 상세 분석 (피드백 상세 화면)
  const AiFeedbackItem(this.category, this.content, this.detail);
}

class PsychProfile {
  final String label; // 성향 태그
  final int score; // 0~100
  const PsychProfile(this.label, this.score);
}

class SubscriptionPlan {
  final String id;
  final String name;
  final int priceMonthly;
  final String usageLabel;
  final bool hasAds;
  final bool canChoosePro;
  const SubscriptionPlan(this.id, this.name, this.priceMonthly, this.usageLabel,
      this.hasAds, this.canChoosePro);
}

// ── 홈 / 대결 ──
// mockDuelDDay: 대결 메타 — 대결 슬라이스에서 API 이전 예정.
const int mockSeed = 10000000;
const int mockDuelDDay = 18;

// ── 사용자 프로필 ──
const String mockUserName = '민지성';
const String mockUserTier = 'Standard'; // Free / Standard / Premium
const String mockUserEmail = 'gsmin5202@gmail.com';

// ── 거래 내역 ──
const List<Trade> mockTrades = [
  Trade('삼성전자', false, 763000, 76300, 10, '05.10 14:32'),
  Trade('애플', true, 504000, 252000, 2, '05.10 10:08'),
  Trade('SK하이닉스', true, 903500, 180700, 5, '05.09 15:18'),
  Trade('카카오', false, 412000, 41200, 10, '05.09 11:45'),
  Trade('삼성전자', true, 720000, 72000, 10, '05.08 09:35'),
  Trade('NAVER', false, 198400, 198400, 1, '05.07 16:01'),
];

// ── 배당금 일정 ──
const List<DividendEvent> mockDividends = [
  DividendEvent('005930', '삼성전자', '2026.06.28', '2026.07.15', 361),
  DividendEvent('000660', 'SK하이닉스', '2026.06.28', '2026.07.20', 150),
  DividendEvent('005380', '현대차', '2026.06.28', '2026.07.18', 2000),
  DividendEvent('051910', 'LG화학', '2026.09.28', '2026.10.15', 500),
  DividendEvent('035420', 'NAVER', '2026.09.28', '2026.10.20', 700),
];

// ── 대결 설정 ──
const List<AiOpponent> mockOpponents = [
  AiOpponent('ai_balanced', '균형 AI', '균형형', '변동성과 수익률을 고르게 추구합니다.', 4.2),
  AiOpponent('ai_growth', '성장 AI', '공격형', '고수익 종목에 집중 투자합니다.', 7.1),
  AiOpponent('ai_value', '가치 AI', '방어형', '저평가 우량주 위주로 운용합니다.', 3.5),
  AiOpponent('ai_momentum', '모멘텀 AI', '추세형', '시장 추세를 따라 빠르게 대응합니다.', 5.8),
];

const List<String> mockDuelDurations = ['1주', '2주', '4주'];
const List<int> mockDuelSeeds = [1000000, 3000000, 5000000, 10000000];

// ── AI 피드백 ──
const List<AiFeedbackItem> mockFeedback = [
  AiFeedbackItem('잘한 점', '삼성전자 매도 타이밍이 고점 대비 2.1% 이내로 적절했습니다.',
      '05.10 14:32 매도 체결가 76,300원은 당일 고점(77,900원) 대비 2.1% 이내입니다. 변동성이 확대되는 구간에서 추세 둔화 신호에 맞춰 정리한 합리적 판단이었습니다. 다만 전량 청산이라 이후 반등(+0.9%)은 포착하지 못했습니다.'),
  AiFeedbackItem('잘한 점', 'SK하이닉스 분할 매수로 평균 단가를 낮췄습니다.',
      '180,700원·178,500원 두 차례 분할 매수로 평균 단가를 약 1.2% 낮췄습니다. 하락 추세에서 단계적으로 담는 전략은 단가 리스크를 줄이는 좋은 습관입니다. 추가 매수 기준(예: -3%)을 미리 정해두면 더 체계적입니다.'),
  AiFeedbackItem('개선점', '카카오 매도 후 재진입 없이 상승분을 놓쳤습니다.',
      '05.09 매도 후 카카오는 3거래일간 +4.3% 상승했으나 재진입이 없었습니다. 재진입 트리거(지지선 회복·거래량 증가 등)를 정해두지 않아 상승분을 놓쳤습니다. 매도 시 "어떤 조건에서 다시 살지"를 함께 기록해 두길 권장합니다.'),
  AiFeedbackItem('개선점', '애플 매수 시 환율 리스크를 고려하지 않았습니다.',
      '애플(해외) 매수 시점 환율은 1,385원으로 최근 1개월 고점권이었습니다. 주가가 +2%여도 환율이 -2% 움직이면 원화 수익은 상쇄됩니다. 해외 종목은 주가와 환율을 함께 보고 환전 타이밍을 분리하는 것이 좋습니다.'),
  AiFeedbackItem('제안', '동일 섹터(반도체) 비중이 60%를 초과합니다. 분산을 권장합니다.',
      '보유 중 삼성전자·SK하이닉스 등 반도체 비중이 약 62%입니다. 섹터 집중은 업황 악화 시 동반 하락 위험이 큽니다. 상관관계가 낮은 경기방어주·배당주로 20~30%를 재배분하면 변동성을 낮출 수 있습니다.'),
];

// ── 심리 예측 ──
const List<PsychProfile> mockPsychProfiles = [
  PsychProfile('손실회피', 72),
  PsychProfile('과신편향', 45),
  PsychProfile('FOMO', 61),
  PsychProfile('인내심', 55),
  PsychProfile('분산투자 성향', 38),
];
const String mockPsychSummary =
    '최근 매매 패턴에서 손실에 민감하게 반응하는 경향이 두드러집니다. '
    '손실 후 빠른 재진입 시도가 반복되고 있어, 감정적 결정을 줄이는 훈련이 필요합니다.';

// ── 요금제 ──
const List<SubscriptionPlan> mockPlans = [
  SubscriptionPlan('free', 'Free', 0, '3회 / 일', true, false),
  SubscriptionPlan('standard', 'Standard', 9900, '더 많은 사용량', false, false),
  SubscriptionPlan('premium', 'Premium', 29900, '가장 많은 사용량', false, true),
];

// ── 환전 ──
const double mockExchangeRate = 1385.50; // 1 USD = KRW
const int mockKrwBalance = 2500000;
const double mockUsdBalance = 450.25;

// ── 계좌 관리 ──
const int mockTotalAsset = 10520000;
const int mockCash = 2500000;
const int mockStockValue = 8020000;
const List<Map<String, dynamic>> mockHoldings = [
  {'name': '삼성전자', 'qty': 10, 'avgPrice': 72000, 'currentPrice': 76300},
  {'name': 'SK하이닉스', 'qty': 5, 'avgPrice': 180700, 'currentPrice': 178500},
  {'name': '애플', 'qty': 2, 'avgPrice': 252000, 'currentPrice': 264000},
];
