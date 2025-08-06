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
    if (_purchaseDialogShown) return;
    _purchaseDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.iapPurchaseSuccess ?? '购买成功'),
        content: Text(AppLocalizations.of(context)?.iapThankYou ?? '感谢您的支持，您已解锁全部功能！'),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop(); // 关闭弹窗
                if (widget.onClose != null) {
                  widget.onClose!(); // 关闭IAP页面
                } else {
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
                        ? '正在查询购买状态...' 
                        : (AppLocalizations.of(context)?.iapLoading ?? '正在加载内购信息...'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    iapService.networkRetryInProgress 
                        ? '请稍候，正在从服务器获取您的购买信息' 
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
                        '网络连接异常',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        iapService.networkRetryInProgress 
                            ? '正在后台重试连接...' 
                            : '无法查询到应用的购买信息，请检查网络',
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
                          label: const Text('重试'),
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
                          'Flashcards Viewer',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '基于科学记忆算法的智能学习工具',
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
                        try {
                          await iapService.purchaseTrial();
                          // 购买成功后刷新状态并显示成功对话框
                          ref.invalidate(trialStatusProvider);
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) {
                            _showPurchaseSuccessDialog();
                          }
                        } catch (e) {
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
                      AppLocalizations.of(context)?.iapFullBuyOrRestore ?? '购买或恢复完整版',
                      Colors.green,
                      () async {
                        try {
                          await iapService.purchaseFullVersion();
                          // 购买成功后刷新状态并显示成功对话框
                          ref.invalidate(trialStatusProvider);
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) {
                            _showPurchaseSuccessDialog();
                          }
                        } catch (e) {
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
    final bool isPending = isTrialButton ? iapService.trialPurchasePending : 
                          isFullVersionButton ? iapService.fullVersionPurchasePending : false;
    
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