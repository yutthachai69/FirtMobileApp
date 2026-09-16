import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  /// Empty means demo while debugging and live for release builds.
  /// Override with --dart-define=APP_DATA_MODE=live when testing production
  /// behavior locally.
  static const dataMode = String.fromEnvironment('APP_DATA_MODE');

  static bool get isDemo {
    if (dataMode == 'demo') return true;
    if (dataMode == 'live') return false;
    return kDebugMode;
  }

  static bool get isLive => !isDemo;

  /// scheme ที่ backend ใช้เด้งกลับเข้าแอปหลัง OAuth เสร็จ
  ///
  /// ต้องตรงกับ APP_SCHEME ฝั่ง server และกับที่ประกาศไว้ใน
  /// AndroidManifest.xml (intent-filter) และ Info.plist (CFBundleURLSchemes)
  /// ถ้าไม่ตรง ผู้ใช้จะกดอนุญาตบน TikTok เสร็จแล้วค้างอยู่ที่ browser
  static const appScheme = String.fromEnvironment(
    'APP_SCHEME',
    defaultValue: 'relaycontent',
  );

  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    final url = configured.isNotEmpty
        ? configured
        : defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://127.0.0.1:8080';
    final uri = Uri.tryParse(url);
    final localPreviewHost =
        uri != null &&
        const {'localhost', '127.0.0.1', '::1', '10.0.2.2'}.contains(uri.host);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        (kReleaseMode && uri.scheme != 'https' && !localPreviewHost)) {
      throw StateError(
        'Set API_BASE_URL to a valid HTTPS API origin for release.',
      );
    }
    return url.replaceFirst(RegExp(r'/$'), '');
  }
}
