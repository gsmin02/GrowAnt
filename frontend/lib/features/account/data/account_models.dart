class AccountSummary {
  final int totalAsset;
  final double returnRate;
  const AccountSummary({required this.totalAsset, required this.returnRate});

  factory AccountSummary.fromJson(Map<String, dynamic> j) => AccountSummary(
        totalAsset: (j['totalAsset'] as num).toInt(),
        returnRate: (j['returnRate'] as num).toDouble(),
      );
}
