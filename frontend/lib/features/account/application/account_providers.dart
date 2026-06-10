import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../market/application/market_providers.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository(ref.watch(dioProvider)));

final accountSummaryProvider = FutureProvider<AccountSummary>(
  (ref) => ref.watch(accountRepositoryProvider).fetchSummary(),
);
