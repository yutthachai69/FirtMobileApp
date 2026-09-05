import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static String get apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    final url = configured.isNotEmpty
        ? configured
        : defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://127.0.0.1:8080';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme) ||
        (kReleaseMode && uri.scheme != 'https')) {
      throw StateError(
        'Set API_BASE_URL to a valid HTTPS API origin for release.',
      );
    }
    return url.replaceFirst(RegExp(r'/$'), '');
  }
}
