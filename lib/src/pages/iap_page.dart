import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:io';
import '../providers.dart';
import '../services/iap_service.dart';

class IAPPage extends ConsumerStatefulWidget {
  const IAPPage({super.key});

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
      builder: (_) => AlertDialog(
        title: const Text('购买成功'),
        content: const Text('感谢您的支持，您已解锁全部功能！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iapService = ref.watch(iapServiceProvider);
    final trialStatusAsync = ref.watch(trialStatusProvider);
    
    // 添加调试信息
    debugPrint('IAP Service - Loading: ${iapService.loading}, Available: ${iapService.isAvailable}');
    debugPrint('Trial Product: ${iapService.trialProduct?.title}');
    debugPrint('Full Version Product: ${iapService.fullVersionProduct?.title}');
    
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      appBar: AppBar(
        title: const Text('升级到完整版'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: iapService.loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('正在加载内购信息...'),
                  const SizedBox(height: 8),
                  const Text('请确保网络连接正常', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      iapService.initialize();
                    },
                    child: const Text('重新加载'),
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
                        const Text(
                          'Open Anki',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
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
                  trialStatusAsync.when(
                    data: (trialStatus) {
                      if (trialStatus['fullVersionPurchased'] == true) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _showPurchaseSuccessDialog();
                        });
                      }
                      return _buildTrialStatusCard(context, trialStatus);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 购买选项
                  if (trialStatusAsync.asData?.value['fullVersionPurchased'] != true && iapService.isAvailable && iapService.products.isNotEmpty) ...[
                    _buildPurchaseOption(
                      context,
                      ref,
                      iapService.trialProduct,
                      '试用版',
                      '免费试用14天',
                      '开始试用',
                      Colors.blue,
                      () async {
                        try {
                          await iapService.purchaseTrial();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('购买失败:  {e.toString()}'),
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
                      '完整版',
                      '解锁所有功能，永久使用',
                      '立即购买',
                      Colors.green,
                      () async {
                        try {
                          await iapService.purchaseFullVersion();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('购买失败:  {e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 恢复购买按钮
                    ElevatedButton.icon(
                      onPressed: iapService.purchasePending ? null : () => iapService.restorePurchases(),
                      icon: const Icon(Icons.restore),
                      label: const Text('恢复购买'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ] else ...[
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
                          const Text(
                            '内购产品暂不可用',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iapService.isAvailable 
                              ? (Platform.isIOS && !Platform.environment.containsKey('FLUTTER_TEST') 
                                  ? '产品已配置，请在真实设备上测试购买' 
                                  : '产品已配置，模拟器不支持购买')
                              : '请检查网络连接或稍后重试',
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
                  
                  const SizedBox(height: 20),
                  
                  // 功能列表
                  _buildFeaturesList(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildTrialStatusCard(BuildContext context, Map<String, dynamic> trialStatus) {
    final bool trialUsed = trialStatus['trialUsed'] ?? false;
    final bool trialExpired = trialStatus['trialExpired'] ?? false;
    final int remainingDays = trialStatus['remainingDays'] ?? 14;
    final bool fullVersionPurchased = trialStatus['fullVersionPurchased'] ?? false;
    
    if (fullVersionPurchased) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '您已拥有完整版本',
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
    
    if (trialUsed && !trialExpired) {
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
                '试用期剩余 $remainingDays 天',
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
    }
    
    if (trialExpired) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '试用期已结束，请购买完整版',
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
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, color: Colors.orange, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '开始您的14天免费试用',
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
                  title == '试用版' ? Icons.access_time : Icons.star,
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
              onPressed: iapService.purchasePending ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: iapService.purchasePending
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
          const Text(
            '完整版功能',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.all_inclusive, '无限卡片数量'),
          _buildFeatureItem(Icons.analytics, '详细学习统计'),
          _buildFeatureItem(Icons.backup, '云端同步备份'),
          _buildFeatureItem(Icons.settings, '自定义学习计划'),
          _buildFeatureItem(Icons.extension, '高级记忆算法'),
          _buildFeatureItem(Icons.support_agent, '优先技术支持'),
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