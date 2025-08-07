import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../log_helper.dart';
import '../constants.dart';

class IAPService extends ChangeNotifier {
  static const String _trialProductId = 'iap.trial.14';
  static const String _fullVersionProductId = 'iap.fullversion';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;

  List<ProductDetails> _products = [];
  ProductDetails? _trialProduct;
  ProductDetails? _fullVersionProduct;

  // 内存状态
  bool _fullVersionPurchased = false;
  bool _trialUsed = false;
  DateTime? _trialStartDate;
  
  // 购买状态
  bool _trialPurchasePending = false;
  bool _fullVersionPurchasePending = false;
  bool _restorePurchasePending = false;
  
  // 后台重试机制
  bool _networkRetryInProgress = false;
  int _retryCount = 0;
  static const int _maxRetries = 5; // 5分钟，每30秒重试一次
  static const Duration _retryInterval = Duration(seconds: 5);
  Timer? _retryTimer;

  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  bool get loading => _loading;
  List<ProductDetails> get products => _products;
  ProductDetails? get trialProduct => _trialProduct;
  ProductDetails? get fullVersionProduct => _fullVersionProduct;
  bool get fullVersionPurchased => _fullVersionPurchased;
  bool get trialUsed => _trialUsed;
  DateTime? get trialStartDate => _trialStartDate;
  bool get trialPurchasePending => _trialPurchasePending;
  bool get fullVersionPurchasePending => _fullVersionPurchasePending;
  bool get restorePurchasePending => _restorePurchasePending;
  bool get networkRetryInProgress => _networkRetryInProgress;

  @override
  void dispose() {
    _subscription.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    // Skip IAP initialization on Android
    if (!enableIAP) {
      LogHelper.log('=== IAP Service Initialization Skipped (Android Platform) ===');
      _isAvailable = false;
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      LogHelper.log('=== IAP Service Initialization Start ===');
      LogHelper.log('Platform: ${Platform.operatingSystem}');
      try {
        final result = await InternetAddress.lookup('google.com');
        LogHelper.log('Network connection: ${result.isNotEmpty ? 'Available' : 'Not available'}');
      } catch (e) {
        LogHelper.log('Network connection error: $e');
      }
      _isAvailable = await _inAppPurchase.isAvailable();
      LogHelper.log('IAP available: $_isAvailable');
      if (!_isAvailable) {
        LogHelper.log('IAP not available, starting background retry');
        _startBackgroundRetry();
        return;
      }
      const Set<String> _kIds = <String>{
        _trialProductId,
        _fullVersionProductId,
      };
      LogHelper.log('Querying product details for: $_kIds');
      LogHelper.log('Starting product query...');
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        LogHelper.log('Product query timeout after 15 seconds');
        throw TimeoutException('Product query timeout', const Duration(seconds: 15));
      });
      LogHelper.log('Product query completed');
      LogHelper.log('Products found: ${response.productDetails.length}');
      LogHelper.log('Not found IDs: ${response.notFoundIDs}');
      for (final product in response.productDetails) {
        LogHelper.log('Product: ${product.id} - ${product.title} - ${product.price}');
      }
      _products = response.productDetails;
      _setupProducts();
      // 初始化内存状态
      _fullVersionPurchased = false;
      _trialUsed = false;
      _trialStartDate = null;
      // 监听购买流
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => LogHelper.log('Purchase stream done'),
        onError: (error) => LogHelper.log('Purchase stream error: $error'),
      );
      await _inAppPurchase.restorePurchases();
      LogHelper.log('IAP service initialized successfully');
      
      // 等待一段时间让restorePurchases的结果被处理
      await Future.delayed(const Duration(milliseconds: 1000));
      
      LogHelper.log('IAP service initialization completed');
      LogHelper.log('Final state:');
      LogHelper.log('  - _fullVersionPurchased: $_fullVersionPurchased');
      LogHelper.log('  - _trialUsed: $_trialUsed');
      LogHelper.log('  - _trialStartDate: $_trialStartDate');
      
      _loading = false;
      notifyListeners();
    } catch (e) {
      LogHelper.log('Error initializing IAP service: $e');
      LogHelper.log('Stack trace: ${StackTrace.current}');
      _startBackgroundRetry();
    }
  }
  
  void _startBackgroundRetry() {
    if (_networkRetryInProgress) return;
    
    _networkRetryInProgress = true;
    _retryCount = 0;
    _loading = false;
    notifyListeners();
    
    LogHelper.log('Starting background retry mechanism');
    _scheduleNextRetry();
  }
  
  void _scheduleNextRetry() {
    if (_retryCount >= _maxRetries) {
      LogHelper.log('Max retries reached, giving up');
      _networkRetryInProgress = false;
      _isAvailable = false;
      _loading = false;
      notifyListeners();
      return;
    }
    
    _retryCount++;
    LogHelper.log('Scheduling retry #$_retryCount in ${_retryInterval.inSeconds} seconds');
    
    _retryTimer = Timer(_retryInterval, () async {
      if (!_networkRetryInProgress) return;
      
      LogHelper.log('Attempting retry #$_retryCount');
      try {
        _isAvailable = await _inAppPurchase.isAvailable();
        if (_isAvailable) {
          LogHelper.log('IAP became available on retry #$_retryCount');
          _networkRetryInProgress = false;
          _retryTimer?.cancel();
          // 重新初始化
          await initialize();
          return;
        }
      } catch (e) {
        LogHelper.log('Retry #$_retryCount failed: $e');
      }
      
      // 继续下一次重试
      _scheduleNextRetry();
    });
  }

  void _setupProducts() {
    _trialProduct = null;
    _fullVersionProduct = null;
    for (final product in _products) {
      if (product.id == _trialProductId) {
        _trialProduct = product;
      }
      if (product.id == _fullVersionProductId) {
        _fullVersionProduct = product;
      }
    }
    if (_trialProduct == null) {
      _trialProduct = _createFallbackTrialProduct();
    }
    if (_fullVersionProduct == null) {
      _fullVersionProduct = _createFallbackFullVersionProduct();
    }
  }

  void _setupFallbackProducts() {
    _trialProduct = _createFallbackTrialProduct();
    _fullVersionProduct = _createFallbackFullVersionProduct();
  }

  ProductDetails _createFallbackTrialProduct() {
    return ProductDetails(
      id: _trialProductId,
      title: '14天试用',
      description: '免费试用14天',
      price: '¥0.00',
      rawPrice: 0.0,
      currencyCode: 'CNY',
    );
  }

  ProductDetails _createFallbackFullVersionProduct() {
    return ProductDetails(
      id: _fullVersionProductId,
      title: '完整版本',
      description: '解锁所有功能',
      price: '¥18.00',
      rawPrice: 18.0,
      currencyCode: 'CNY',
    );
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    LogHelper.log('=== _onPurchaseUpdate called ===');
    LogHelper.log('purchaseDetailsList length: ${purchaseDetailsList.length}');
    LogHelper.log('Current _fullVersionPurchased before processing: $_fullVersionPurchased');
    LogHelper.log('Current _trialUsed before processing: $_trialUsed');
    
    bool hasFullVersion = false;
    bool hasTrial = false;
    DateTime? trialStartDate;
    
    // 首先遍历所有购买记录，收集信息
    for (final purchaseDetails in purchaseDetailsList) {
      LogHelper.log('Processing purchase: ${purchaseDetails.productID} - status: ${purchaseDetails.status}');
      LogHelper.log('Purchase details: ${purchaseDetails.toString()}');
      
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        LogHelper.log('Purchase/Restore status detected for: ${purchaseDetails.productID}');
        
        if (purchaseDetails.productID == _fullVersionProductId) {
          LogHelper.log('Full version product detected! Setting hasFullVersion = true');
          hasFullVersion = true;
        }
        if (purchaseDetails.productID == _trialProductId) {
          LogHelper.log('Trial product detected! Setting hasTrial = true');
          hasTrial = true;
          // 记录试用开始时间，但不立即设置
          if (trialStartDate == null) {
            trialStartDate = DateTime.now();
            LogHelper.log('Trial start date would be: $trialStartDate');
          }
        }
      } else {
        LogHelper.log('Purchase status is not purchased/restored: ${purchaseDetails.status}');
      }
      
      // 无论成功还是失败，都重置购买状态
      if (purchaseDetails.productID == _trialProductId) {
        _trialPurchasePending = false;
        LogHelper.log('Reset trial purchase pending to false');
      }
      if (purchaseDetails.productID == _fullVersionProductId) {
        _fullVersionPurchasePending = false;
        LogHelper.log('Reset full version purchase pending to false');
      }
    }
    
    // 设置最终状态，完整版优先级更高
    LogHelper.log('Final hasFullVersion: $hasFullVersion');
    LogHelper.log('Final hasTrial: $hasTrial');
    
    _fullVersionPurchased = hasFullVersion;
    LogHelper.log('Set _fullVersionPurchased to: $_fullVersionPurchased');
    
    // 只有在没有完整版的情况下才设置试用状态
    if (hasTrial && !hasFullVersion) {
      _trialUsed = true;
      if (_trialStartDate == null) {
        _trialStartDate = trialStartDate;
        LogHelper.log('Setting trial start date to: $_trialStartDate');
      }
    } else if (hasFullVersion) {
      // 如果有完整版，清除试用状态
      _trialUsed = false;
      _trialStartDate = null;
      LogHelper.log('Full version detected, clearing trial status');
    }
    
    LogHelper.log('Final _trialUsed: $_trialUsed');
    LogHelper.log('Final _trialStartDate: $_trialStartDate');
    
    notifyListeners();
    LogHelper.log('=== _onPurchaseUpdate completed ===');
  }

  Future<void> purchaseTrial() async {
    if (_trialProduct == null) {
      LogHelper.log('Trial product is null');
      return;
    }
    try {
      _trialPurchasePending = true;
      notifyListeners();
      LogHelper.log('Attempting to purchase trial: ${_trialProduct!.id}');
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: _trialProduct!);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _trialPurchasePending = false;
      notifyListeners();
      LogHelper.log('Error purchasing trial: $e');
      rethrow;
    }
  }

  Future<void> purchaseFullVersion() async {
    if (_fullVersionProduct == null) {
      LogHelper.log('Full version product is null');
      return;
    }
    try {
      _fullVersionPurchasePending = true;
      notifyListeners();
      LogHelper.log('Attempting to purchase full version: ${_fullVersionProduct!.id}');
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: _fullVersionProduct!);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _fullVersionPurchasePending = false;
      notifyListeners();
      LogHelper.log('Error purchasing full version: $e');
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    LogHelper.log('=== restorePurchases called ===');
    LogHelper.log('Current state before restore:');
    LogHelper.log('  - _fullVersionPurchased: $_fullVersionPurchased');
    LogHelper.log('  - _trialUsed: $_trialUsed');
    LogHelper.log('  - _trialStartDate: $_trialStartDate');
    LogHelper.log('  - _fullVersionProductId: $_fullVersionProductId');
    LogHelper.log('  - _trialProductId: $_trialProductId');
    
    // 保存当前状态，防止在恢复过程中被重置
    final bool currentFullVersionPurchased = _fullVersionPurchased;
    final bool currentTrialUsed = _trialUsed;
    final DateTime? currentTrialStartDate = _trialStartDate;
    
    try {
      _restorePurchasePending = true;
      notifyListeners();
      LogHelper.log('Calling _inAppPurchase.restorePurchases()...');
      await _inAppPurchase.restorePurchases();
      LogHelper.log('_inAppPurchase.restorePurchases() completed successfully');
      LogHelper.log('Waiting for purchase stream to process restored purchases...');
      
      // 等待一段时间让购买流处理恢复的购买
      await Future.delayed(const Duration(seconds: 2));
      
      LogHelper.log('State after restore:');
      LogHelper.log('  - _fullVersionPurchased: $_fullVersionPurchased');
      LogHelper.log('  - _trialUsed: $_trialUsed');
      LogHelper.log('  - _trialStartDate: $_trialStartDate');
      
      // 如果恢复后状态被重置了，恢复之前的状态
      if (!_fullVersionPurchased && currentFullVersionPurchased) {
        LogHelper.log('Restoring previous full version state');
        _fullVersionPurchased = currentFullVersionPurchased;
        _trialUsed = currentTrialUsed;
        _trialStartDate = currentTrialStartDate;
        notifyListeners();
      }
      
    } catch (e) {
      LogHelper.log('restorePurchases error: $e');
      LogHelper.log('Error type: ${e.runtimeType}');
      rethrow;
    } finally {
      _restorePurchasePending = false;
      notifyListeners();
      LogHelper.log('restorePurchases finally block completed');
    }
  }

  // 试用状态相关（如需彻底云端判定，可移除）
  bool getTrialUsed() => _trialUsed;
  bool getTrialExpired() {
    if (_trialStartDate == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_trialStartDate!).inDays;
    return difference >= kIAPTrialDays;
  }
  int? getRemainingTrialDays() {
    if (_trialStartDate == null) return null;
    final now = DateTime.now();
    final difference = now.difference(_trialStartDate!).inDays;
    return kIAPTrialDays - difference;
  }
} 