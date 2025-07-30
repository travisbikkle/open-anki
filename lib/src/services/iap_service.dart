import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../log_helper.dart';

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
  bool get networkRetryInProgress => _networkRetryInProgress;

  @override
  void dispose() {
    _subscription.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
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
    bool hasFullVersion = false;
    for (final purchaseDetails in purchaseDetailsList) {
      LogHelper.log('Processing purchase: ${purchaseDetails.productID} - status: ${purchaseDetails.status}');
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.productID == _fullVersionProductId) {
          hasFullVersion = true;
        }
        if (purchaseDetails.productID == _trialProductId) {
          _trialUsed = true;
          if (_trialStartDate == null) {
            _trialStartDate = DateTime.now();
          }
        }
      }
      // 无论成功还是失败，都重置购买状态
      if (purchaseDetails.productID == _trialProductId) {
        _trialPurchasePending = false;
      }
      if (purchaseDetails.productID == _fullVersionProductId) {
        _fullVersionPurchasePending = false;
      }
    }
    _fullVersionPurchased = hasFullVersion;
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
    try {
      await _inAppPurchase.restorePurchases();
      LogHelper.log('restorePurchases completed');
    } catch (e) {
      LogHelper.log('restorePurchases error: $e');
      rethrow;
    }
  }

  // 试用状态相关（如需彻底云端判定，可移除）
  bool getTrialUsed() => _trialUsed;
  bool getTrialExpired() {
    if (_trialStartDate == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_trialStartDate!).inDays;
    return difference >= 14;
  }
  int? getRemainingTrialDays() {
    if (_trialStartDate == null) return null;
    final now = DateTime.now();
    final difference = now.difference(_trialStartDate!).inDays;
    return 14 - difference;
  }
} 