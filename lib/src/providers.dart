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
  // 异步初始化，避免阻塞UI
  Future.microtask(() => iapService.initialize());
  return iapService;
});

// 用户访问权限提供者
final userAccessProvider = FutureProvider<bool>((ref) async {
  final iapService = ref.read(iapServiceProvider);
  return await iapService.hasFullAccess();
});

// 试用状态提供者
final trialStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final iapService = ref.read(iapServiceProvider);
  final trialUsed = await iapService.isTrialUsed();
  final trialExpired = await iapService.isTrialExpired();
  final remainingDays = await iapService.getRemainingTrialDays();
  final fullVersionPurchased = await iapService.isFullVersionPurchased();
  
  return {
    'trialUsed': trialUsed,
    'trialExpired': trialExpired,
    'remainingDays': remainingDays,
    'fullVersionPurchased': fullVersionPurchased,
  };
});