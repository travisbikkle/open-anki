import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  bool get loading => _loading;
  List<ProductDetails> get products => _products;
  ProductDetails? get trialProduct => _trialProduct;
  ProductDetails? get fullVersionProduct => _fullVersionProduct;
  bool get fullVersionPurchased => _fullVersionPurchased;
  bool get trialUsed => _trialUsed;
  DateTime? get trialStartDate => _trialStartDate;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      debugPrint('=== IAP Service Initialization Start ===');
      debugPrint('Platform: ${Platform.operatingSystem}');
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
      _setupProducts();
      // 初始化内存状态
      _fullVersionPurchased = false;
      _trialUsed = false;
      _trialStartDate = null;
      // 监听购买流
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => debugPrint('Purchase stream done'),
        onError: (error) => debugPrint('Purchase stream error: $error'),
      );
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
    debugPrint('=== _onPurchaseUpdate called ===');
    debugPrint('purchaseDetailsList length: ${purchaseDetailsList.length}');
    bool hasFullVersion = false;
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('Processing purchase: ${purchaseDetails.productID} - status: ${purchaseDetails.status}');
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
    }
    _fullVersionPurchased = hasFullVersion;
    notifyListeners();
    debugPrint('=== _onPurchaseUpdate completed ===');
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
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    debugPrint('=== restorePurchases called ===');
    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('restorePurchases completed');
    } catch (e) {
      debugPrint('restorePurchases error: $e');
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