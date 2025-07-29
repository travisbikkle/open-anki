import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPService extends ChangeNotifier {
  static const String _trialProductId = 'iap.trial.14';
  static const String _fullVersionProductId = 'iap.fullversion';
  
  static const String _trialStartKey = 'trial_start_date';
  static const String _trialUsedKey = 'trial_used';
  static const String _fullVersionPurchasedKey = 'full_version_purchased';
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _loading = true;
  
  List<ProductDetails> _products = [];
  ProductDetails? _trialProduct;
  ProductDetails? _fullVersionProduct;
  
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  bool get loading => _loading;
  List<ProductDetails> get products => _products;
  ProductDetails? get trialProduct => _trialProduct;
  ProductDetails? get fullVersionProduct => _fullVersionProduct;
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
  
  Future<void> initialize() async {
    try {
      debugPrint('=== IAP Service Initialization Start ===');
      debugPrint('Platform: ${Platform.operatingSystem}');
      
      // 检查网络连接
      try {
        final result = await InternetAddress.lookup('google.com');
        debugPrint('Network connection: ${result.isNotEmpty ? 'Available' : 'Not available'}');
      } catch (e) {
        debugPrint('Network connection error: $e');
      }
      
      _isAvailable = await _inAppPurchase.isAvailable();
      debugPrint('IAP available: $_isAvailable');
      
      if (!_isAvailable) {
        debugPrint('IAP not available, using fallback products');
        _setupFallbackProducts();
        _loading = false;
        notifyListeners();
        return;
      }
      
      const Set<String> _kIds = <String>{
        _trialProductId,
        _fullVersionProductId,
      };
      
      debugPrint('Querying product details for: $_kIds');
      debugPrint('Starting product query...');
      
      // 添加超时处理
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        debugPrint('Product query timeout after 15 seconds');
        throw TimeoutException('Product query timeout', const Duration(seconds: 15));
      });
      
      debugPrint('Product query completed');
      debugPrint('Products found: ${response.productDetails.length}');
      debugPrint('Not found IDs: ${response.notFoundIDs}');
      
      for (final product in response.productDetails) {
        debugPrint('Product: ${product.id} - ${product.title} - ${product.price}');
      }
      
      _products = response.productDetails;
      
      // 设置产品详情
      _setupProducts();
      
      // 设置购买流监听
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => debugPrint('Purchase stream done'),
        onError: (error) => debugPrint('Purchase stream error: $error'),
      );
      // 启动时主动恢复一次
      await _inAppPurchase.restorePurchases();
      
      debugPrint('IAP service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing IAP service: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      _setupFallbackProducts();
    } finally {
      debugPrint('Setting loading to false');
      _loading = false;
      notifyListeners();
      debugPrint('=== IAP Service Initialization End ===');
    }
  }
  
  void _setupProducts() {
    _trialProduct = _products.firstWhere(
      (product) => product.id == _trialProductId,
      orElse: () => _createFallbackTrialProduct(),
    );
    
    _fullVersionProduct = _products.firstWhere(
      (product) => product.id == _fullVersionProductId,
      orElse: () => _createFallbackFullVersionProduct(),
    );
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
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        _purchasePending = false;
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _verifyPurchase(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
    notifyListeners();
  }
  
  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    final prefs = await SharedPreferences.getInstance();
    
    switch (purchaseDetails.productID) {
      case _trialProductId:
        await prefs.setBool(_trialUsedKey, true);
        await prefs.setInt(_trialStartKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('Trial activated');
        break;
      case _fullVersionProductId:
        await prefs.setBool(_fullVersionPurchasedKey, true);
        debugPrint('Full version purchased');
        break;
    }
  }
  
  Future<void> purchaseTrial() async {
    if (_trialProduct == null) {
      debugPrint('Trial product is null');
      return;
    }
    
    try {
      debugPrint('Attempting to purchase trial: ${_trialProduct!.id}');
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: _trialProduct!);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error purchasing trial: $e');
      if (e.toString().contains('storekit2_failed_to_fetch_product')) {
        throw Exception('产品暂不可用，请稍后重试或联系客服');
      }
      rethrow;
    }
  }
  
  Future<void> purchaseFullVersion() async {
    if (_fullVersionProduct == null) {
      debugPrint('Full version product is null');
      return;
    }
    
    try {
      debugPrint('Attempting to purchase full version: ${_fullVersionProduct!.id}');
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: _fullVersionProduct!);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error purchasing full version: $e');
      if (e.toString().contains('storekit2_failed_to_fetch_product')) {
        throw Exception('产品暂不可用，请稍后重试或联系客服');
      }
      rethrow;
    }
  }
  
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }
  
  // 检查试用状态
  Future<bool> isTrialUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trialUsedKey) ?? false;
  }
  
  // 检查试用是否过期
  Future<bool> isTrialExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final trialStart = prefs.getInt(_trialStartKey);
    if (trialStart == null) return false;
    
    final trialStartDate = DateTime.fromMillisecondsSinceEpoch(trialStart);
    final now = DateTime.now();
    final difference = now.difference(trialStartDate).inDays;
    
    return difference >= 14; // 14天试用期
  }
  
  // 检查是否已购买完整版本
  Future<bool> isFullVersionPurchased() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fullVersionPurchasedKey) ?? false;
  }
  
  // 检查用户是否有完整访问权限
  Future<bool> hasFullAccess() async {
    final fullVersionPurchased = await isFullVersionPurchased();
    if (fullVersionPurchased) return true;
    
    final trialUsed = await isTrialUsed();
    final trialExpired = await isTrialExpired();
    
    return trialUsed && !trialExpired;
  }
  
  // 获取剩余试用天数
  Future<int> getRemainingTrialDays() async {
    final prefs = await SharedPreferences.getInstance();
    final trialStart = prefs.getInt(_trialStartKey);
    if (trialStart == null) return 14;
    
    final trialStartDate = DateTime.fromMillisecondsSinceEpoch(trialStart);
    final now = DateTime.now();
    final difference = now.difference(trialStartDate).inDays;
    
    return 14 - difference;
  }
} 