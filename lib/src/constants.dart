import 'dart:io';

import 'package:flutter/material.dart';

const String kAppName = 'Flashcards Viewer';
const String kSupportEmail = 'support@eusoftbank.com';

/// 全局马卡龙配色
final List<Color> kMacaronColors = [
  Color(0xFFFFB7B2), // 粉
  Color(0xFFFFDAC1), // 橙
  Color(0xFFE2F0CB), // 绿
  Color(0xFFB5EAD7), // 青
  Color(0xFFC7CEEA), // 蓝紫
  Color(0xFFFFF1BA), // 黄
  Color(0xFFF6DFEB), // 淡紫
  Color(0xFFD4F1F4), // 淡蓝
];

// Platform detection functions
bool get isIOS => Platform.isIOS;
bool get isAndroid => Platform.isAndroid;
bool get isWeb => false; // Platform.isWeb is not available in dart:io
bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

// Feature flags based on platform
bool get enableIAP => isIOS && !isDesktop; // Only enable IAP on iOS devices, not macOS
bool get enableAppleFeatures => isIOS; // Only enable Apple-specific features on iOS

// 内购
const int kIAPTrialDays = 14;