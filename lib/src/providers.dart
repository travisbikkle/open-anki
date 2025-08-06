import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model.dart';
import 'db.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'services/iap_service.dart';
import 'constants.dart';

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
  // On Android, always grant full access
  if (!enableIAP) {
    return true;
  }
  final iapService = ref.watch(iapServiceProvider);
  return iapService.fullVersionPurchased || (iapService.trialUsed && !iapService.getTrialExpired());
});

final trialStatusProvider = Provider<Map<String, dynamic>>((ref) {
  // On Android, return default full access status
  if (!enableIAP) {
    return {
      'trialUsed': false,
      'trialExpired': false,
      'remainingDays': null,
      'fullVersionPurchased': true, // Android users get full access
    };
  }
  
  final iapService = ref.watch(iapServiceProvider);
  
  final trialStatus = {
    'trialUsed': iapService.trialUsed,
    'trialExpired': iapService.getTrialExpired(),
    'remainingDays': iapService.getRemainingTrialDays(),
    'fullVersionPurchased': iapService.fullVersionPurchased,
  };
  
  // 添加调试日志
  print('=== trialStatusProvider updated ===');
  print('Platform: ${enableIAP ? 'iOS' : 'Android'}');
  print('IAP Service state:');
  print('  - fullVersionPurchased: ${iapService.fullVersionPurchased}');
  print('  - trialUsed: ${iapService.trialUsed}');
  print('  - trialStartDate: ${iapService.trialStartDate}');
  print('  - getTrialExpired(): ${iapService.getTrialExpired()}');
  print('  - getRemainingTrialDays(): ${iapService.getRemainingTrialDays()}');
  print('Trial status result: $trialStatus');
  
  return trialStatus;
});