import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../market/application/market_providers.dart';
import '../data/portfolio_models.dart';
import '../data/portfolio_repository.dart';

final portfolioRepositoryProvider =
    Provider<PortfolioRepository>((ref) => PortfolioRepository(ref.watch(dioProvider)));

final portfolioProvider = FutureProvider.family<Portfolio, PortfolioOwner>(
  (ref, owner) => ref.watch(portfolioRepositoryProvider).fetchPortfolio(owner),
);
