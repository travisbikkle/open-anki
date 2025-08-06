import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:io';
import '../providers.dart';
import '../services/iap_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class IAPPage extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const IAPPage({super.key, this.onClose});

  @override
  ConsumerState<IAPPage> createState() => _IAPPageState();
}

class _IAPPageState extends ConsumerState<IAPPage> {
  bool _purchaseDialogShown = false;

  void _showPurchaseSuccessDialog() {
    debugPrint('=== _showPurchaseSuccessDialog called ===');
    debugPrint('_purchaseDialogShown: $_purchaseDialogShown');
    
    if (_purchaseDialogShown) {
      debugPrint('Dialog already shown, returning early');
      return;
    }
    
    _purchaseDialogShown = true;
    debugPrint('Setting _purchaseDialogShown to true');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.iapPurchaseSuccess ?? '购买成功'),
        content: Text(AppLocalizations.of(context)?.iapThankYou ?? '感谢您的支持，您已解锁全部功能！'),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('Purchase success dialog OK button pressed');
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop(); // 关闭弹窗
                if (widget.onClose != null) {
                  debugPrint('Calling widget.onClose()');
                  widget.onClose!(); // 关闭IAP页面
                } else {
                  debugPrint('Navigating back');
                  if (mounted) Navigator.of(context).pop();
                }
              }
            },
            child: Text(AppLocalizations.of(context)?.ok ?? '确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iapService = ref.watch(iapServiceProvider);
    final trialStatus = ref.watch(trialStatusProvider);
    
    // 添加调试信息
    debugPrint('IAP Service - Loading: ${iapService.loading}, Available: ${iapService.isAvailable}');
    debugPrint('Trial Product: ${iapService.trialProduct?.title}');
    debugPrint('Full Version Product: ${iapService.fullVersionProduct?.title}');
    
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.iapUpgradeTitle ?? '升级到完整版'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: !(trialStatus['trialUsed'] == true && 
                                   trialStatus['trialExpired'] == true && 
                                   trialStatus['fullVersionPurchased'] != true),
        actions: [
          if (!(trialStatus['trialUsed'] == true && 
                trialStatus['trialExpired'] == true && 
                trialStatus['fullVersionPurchased'] != true))
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () {
                if (widget.onClose != null) {
                  widget.onClose!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: iapService.loading || iapService.networkRetryInProgress
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    iapService.networkRetryInProgress 
                        ? (AppLocalizations.of(context)?.iapQueryingPurchaseStatus ?? '正在查询购买状态...')
                        : (AppLocalizations.of(context)?.iapLoading ?? '正在加载内购信息...'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    iapService.networkRetryInProgress 
                        ? (AppLocalizations.of(context)?.iapPleaseWaitGettingInfo ?? '请稍候，正在从服务器获取您的购买信息')
                        : (AppLocalizations.of(context)?.iapCheckNetwork ?? '请确保网络连接正常'), 
                    style: TextStyle(fontSize: 12, color: Colors.grey)
                  ),
                  const SizedBox(height: 16),
                  if (!iapService.networkRetryInProgress)
                    ElevatedButton(
                      onPressed: () {
                        iapService.initialize();
                      },
                      child: Text(AppLocalizations.of(context)?.reload ?? '重新加载'),
                    ),
                ],
              ),
            )
          : !iapService.isAvailable
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)?.iapNetworkError ?? '网络连接异常',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        iapService.networkRetryInProgress 
                            ? '正在后台重试连接...' 
                            : (AppLocalizations.of(context)?.iapCannotQueryPurchaseInfo ?? '无法查询到应用的购买信息，请检查网络'),
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (!iapService.networkRetryInProgress) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            iapService.initialize();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(AppLocalizations.of(context)?.iapRetryConnection ?? '重试'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!(trialStatus['trialUsed'] == true && 
                            trialStatus['trialExpired'] == true && 
                            trialStatus['fullVersionPurchased'] != true))
                        TextButton(
                          onPressed: () {
                            if (widget.onClose != null) {
                              widget.onClose!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(AppLocalizations.of(context)?.close ?? '关闭'),
                        ),
                    ],
                  ),
                )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 应用介绍
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.park,
                          size: 80,
                          color: Colors.green[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)?.iapAppTitle ?? 'Flashcards Viewer',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)?.iapAppDescription ?? '基于科学记忆算法的智能学习工具',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  

                  
                  // 试用状态
                  _buildTrialStatusCard(context, trialStatus),
                  
                  const SizedBox(height: 20),
                  
                  // 购买选项
                  if (!trialStatus['fullVersionPurchased'] && 
                      iapService.isAvailable && 
                      iapService.products.isNotEmpty && 
                      !iapService.loading && 
                      !iapService.networkRetryInProgress) ...[
                    _buildPurchaseOption(
                      context,
                      ref,
                      iapService.trialProduct,
                      AppLocalizations.of(context)?.iapTrialTitle ?? '试用版',
                      AppLocalizations.of(context)?.iapTrialDesc ?? '免费试用14天',
                      AppLocalizations.of(context)?.iapTrialStart ?? '开始试用',
                      Colors.blue,
                      () async {
                        debugPrint('=== Start Trial button clicked ===');
                        debugPrint('Current trial status: $trialStatus');
                        debugPrint('IAP Service state:');
                        debugPrint('  - isAvailable: ${iapService.isAvailable}');
                        debugPrint('  - loading: ${iapService.loading}');
                        debugPrint('  - trialUsed: ${iapService.trialUsed}');
                        
                        try {
                          debugPrint('Calling iapService.purchaseTrial()...');
                          
                          // 记录试用前的状态
                          final beforeTrial = iapService.trialUsed;
                          debugPrint('Before trial - trialUsed: $beforeTrial');
                          
                          await iapService.purchaseTrial();
                          debugPrint('purchaseTrial() completed successfully');
                          
                          // 试用成功后刷新状态
                          debugPrint('Invalidating trialStatusProvider...');
                          ref.invalidate(trialStatusProvider);
                          
                          debugPrint('Waiting 500ms for state to update...');
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // 检查试用后的状态
                          final afterTrial = iapService.trialUsed;
                          debugPrint('After trial - trialUsed: $afterTrial');
                          
                          if (mounted) {
                            if (afterTrial && !beforeTrial) {
                              // 只有在真正开始试用时才显示成功对话框
                              debugPrint('Trial was successfully started! Showing success dialog...');
                              _showPurchaseSuccessDialog();
                            } else {
                              debugPrint('Trial may not have started successfully');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context)?.iapTrialMayNotStart ?? '试用可能未开始，请稍后检查'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('Trial failed with error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)?.iapPurchaseFailed ?? '购买失败，请检查网络或账户后重试'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPurchaseOption(
                      context,
                      ref,
                      iapService.fullVersionProduct,
                      AppLocalizations.of(context)?.iapFullTitle ?? '完整版',
                      AppLocalizations.of(context)?.iapFullDesc ?? '解锁所有功能，永久使用',
                      AppLocalizations.of(context)?.iapFullBuy ?? '立即购买',
                      Colors.green,
                      () async {
                        debugPrint('=== Buy Full Version button clicked ===');
                        debugPrint('Current trial status: $trialStatus');
                        debugPrint('IAP Service state:');
                        debugPrint('  - isAvailable: ${iapService.isAvailable}');
                        debugPrint('  - loading: ${iapService.loading}');
                        debugPrint('  - fullVersionPurchased: ${iapService.fullVersionPurchased}');
                        
                        try {
                          debugPrint('Calling iapService.purchaseFullVersion()...');
                          
                          // 记录购买前的状态
                          final beforePurchase = iapService.fullVersionPurchased;
                          debugPrint('Before purchase - fullVersionPurchased: $beforePurchase');
                          
                          await iapService.purchaseFullVersion();
                          debugPrint('purchaseFullVersion() completed successfully');
                          
                          // 购买成功后刷新状态
                          debugPrint('Invalidating trialStatusProvider...');
                          ref.invalidate(trialStatusProvider);
                          
                          debugPrint('Waiting 500ms for state to update...');
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // 检查购买后的状态
                          final afterPurchase = iapService.fullVersionPurchased;
                          debugPrint('After purchase - fullVersionPurchased: $afterPurchase');
                          
                          if (mounted) {
                            if (afterPurchase && !beforePurchase) {
                              // 只有在真正购买成功时才显示成功对话框
                              debugPrint('Purchase was successful! Showing success dialog...');
                              _showPurchaseSuccessDialog();
                            } else {
                              debugPrint('Purchase may not have completed successfully');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context)?.iapPurchaseMayNotComplete ?? '购买可能未完成，请稍后检查'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('Purchase failed with error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)?.iapPurchaseFailed ?? '购买失败，请检查网络或账户后重试'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPurchaseOption(
                      context,
                      ref,
                      null, // 恢复购买不需要产品详情
                      AppLocalizations.of(context)?.iapRestore ?? '恢复购买',
                      AppLocalizations.of(context)?.iapRestore ?? '恢复之前购买的内容',
                      AppLocalizations.of(context)?.iapRestore ?? '恢复购买',
                      Colors.blue,
                      () async {
                        debugPrint('=== Restore Purchases button clicked ===');
                        debugPrint('Current trial status: $trialStatus');
                        debugPrint('IAP Service state:');
                        debugPrint('  - isAvailable: ${iapService.isAvailable}');
                        debugPrint('  - loading: ${iapService.loading}');
                        debugPrint('  - fullVersionPurchased: ${iapService.fullVersionPurchased}');
                        debugPrint('  - trialUsed: ${iapService.trialUsed}');
                        
                        try {
                          debugPrint('Calling iapService.restorePurchases()...');
                          
                          // 记录恢复前的状态
                          final beforeRestore = iapService.fullVersionPurchased;
                          debugPrint('Before restore - fullVersionPurchased: $beforeRestore');
                          
                          await iapService.restorePurchases();
                          debugPrint('restorePurchases() completed successfully');
                          
                          // 恢复成功后刷新状态
                          debugPrint('Invalidating trialStatusProvider...');
                          ref.invalidate(trialStatusProvider);
                          
                          debugPrint('Waiting 500ms for state to update...');
                          await Future.delayed(const Duration(milliseconds: 500));
                          
                          // 检查恢复后的状态
                          final afterRestore = iapService.fullVersionPurchased;
                          debugPrint('After restore - fullVersionPurchased: $afterRestore');
                          
                          if (mounted) {
                            if (afterRestore && !beforeRestore) {
                              // 只有在真正恢复了购买时才显示成功对话框
                              debugPrint('Purchase was successfully restored! Showing success dialog...');
                              _showPurchaseSuccessDialog();
                            } else {
                              debugPrint('No purchases were restored. Showing info message...');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppLocalizations.of(context)?.iapNoPurchasesToRestore ?? '没有找到可恢复的购买记录'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('Restore purchases failed with error: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)?.iapPurchaseFailed ?? '恢复失败，请检查网络或账户后重试'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                  ] else if (trialStatus['fullVersionPurchased']) ...[
                    // 已购买完整版，不显示任何购买选项
                  ] else if (iapService.loading || iapService.networkRetryInProgress) ...[
                    // 正在加载或重试中，不显示购买选项，让用户看到加载状态
                  ] else if (!iapService.isAvailable) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)?.iapInAppPurchaseUnavailable ?? '内购产品暂不可用',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iapService.isAvailable 
                              ? (Platform.isIOS && !Platform.environment.containsKey('FLUTTER_TEST') 
                                  ? AppLocalizations.of(context)?.iapInAppPurchaseConfiguredForRealDevice ?? '产品已配置，请在真实设备上测试购买' 
                                  : AppLocalizations.of(context)?.iapInAppPurchaseConfiguredForSimulator ?? '产品已配置，模拟器不支持购买')
                              : AppLocalizations.of(context)?.iapCheckNetworkOrRetry ?? '请检查网络连接或稍后重试',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '调试信息: ${iapService.products.length} 个产品已加载',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // const SizedBox(height: 20),
                  
                  // 功能列表
                  // _buildFeaturesList(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTrialStatusCard(BuildContext context, Map<String, dynamic> trialStatus) {
    final bool trialUsed = trialStatus['trialUsed'] ?? false;
    final bool trialExpired = trialStatus['trialExpired'] ?? false;
    final int? remainingDays = trialStatus['remainingDays'];
    final bool fullVersionPurchased = trialStatus['fullVersionPurchased'] ?? false;
    // 优先显示完整版
    if (fullVersionPurchased) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.iapFullVersionPurchased ?? '您已拥有完整版',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    if (!trialUsed) {
      // 未试用状态
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.info, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.iapTrialStart ?? '开始您的14天免费试用',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (trialUsed && !trialExpired && remainingDays != null) {
      // 试用中状态
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.blue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.iapTrialRemainingDays(remainingDays),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (trialExpired) {
      // 试用已过期状态
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.iapTrialExpired ?? '试用期已结束，请购买完整版',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // 默认状态（理论上不会到达这里）
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.help, color: Colors.grey, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '试用状态未知',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPurchaseOption(
    BuildContext context,
    WidgetRef ref,
    ProductDetails? product,
    String title,
    String description,
    String buttonText,
    Color color,
    VoidCallback onPressed,
  ) {
    final iapService = ref.watch(iapServiceProvider);
    final bool isTrialButton = title == (AppLocalizations.of(context)?.iapTrialTitle ?? '试用版');
    final bool isFullVersionButton = title == (AppLocalizations.of(context)?.iapFullTitle ?? '完整版');
    final bool isRestoreButton = title == (AppLocalizations.of(context)?.iapRestore ?? '恢复购买');
    final bool isPending = isTrialButton ? iapService.trialPurchasePending : 
                          isFullVersionButton ? iapService.fullVersionPurchasePending :
                          isRestoreButton ? iapService.restorePurchasePending : false;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  (title == (AppLocalizations.of(context)?.iapTrialTitle ?? '试用版')) ? Icons.access_time : Icons.star,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPending ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isPending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeaturesList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.iapFullFeatures ?? '完整版功能',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.all_inclusive, AppLocalizations.of(context)?.iapUnlimitedCards ?? '无限卡片数量'),
          _buildFeatureItem(Icons.analytics, AppLocalizations.of(context)?.iapDetailedStats ?? '详细学习统计'),
          _buildFeatureItem(Icons.settings, AppLocalizations.of(context)?.iapCustomPlan ?? '自定义学习计划'),
          _buildFeatureItem(Icons.extension, AppLocalizations.of(context)?.iapAdvancedAlgo ?? '高级记忆算法'),
          _buildFeatureItem(Icons.support_agent, AppLocalizations.of(context)?.iapPrioritySupport ?? '优先技术支持'),
        ],
      ),
    );
  }
  
  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[600], size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
} 