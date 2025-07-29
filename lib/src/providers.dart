import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model.dart';
import 'db.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'services/iap_service.dart';

final currentIndexProvider = StateProvider<int>((ref) => 0);

final allDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  return await AppDb.getAllDecks();
});

final recentDecksProvider = FutureProvider<List<DeckInfo>>((ref) async {
  return await AppDb.getRecentDecks(limit: 10);
});

// IAP服务提供者
final iapServiceProvider = ChangeNotifierProvider<IAPService>((ref) {
  final iapService = IAPService();
  Future.microtask(() => iapService.initialize());
  return iapService;
});

final userAccessProvider = Provider<bool>((ref) {
  final iapService = ref.watch(iapServiceProvider);
  return iapService.fullVersionPurchased || (iapService.trialUsed && !iapService.getTrialExpired());
});

final trialStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final iapService = ref.watch(iapServiceProvider);
  return {
    'trialUsed': iapService.trialUsed,
    'trialExpired': iapService.getTrialExpired(),
    'remainingDays': iapService.getRemainingTrialDays(),
    'fullVersionPurchased': iapService.fullVersionPurchased,
  };
});