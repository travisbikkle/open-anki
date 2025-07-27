import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _growthController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _growthAnim;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    
    // 缩放和透明度动画控制器
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    // 成长动画控制器
    _growthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    
    // 成长动画：从0.3倍大小成长到1.0倍
    _growthAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _growthController, curve: Curves.easeOutBack),
    );
    
    // 轻微摇摆动画
    _rotationAnim = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    
    // 启动成长动画
    _growthController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _growthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeaf6ff),
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnim,
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleController, _growthController]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value * _growthAnim.value,
                child: Transform.rotate(
                  angle: _rotationAnim.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(36),
                    child: Icon(
                      Icons.park, // 使用大树图标
                      color: Colors.green[700],
                      size: 80,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
} 