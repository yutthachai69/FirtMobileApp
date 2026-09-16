import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/domain/session.dart';
import '../../features/home/data/devices_api.dart';
import '../auth/auth_controller.dart';
import '../config/app_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationsController {
  PushNotificationsController(this.auth, this.api);

  final AuthController auth;
  final DevicesApi api;
  StreamSubscription<String>? _tokenSubscription;
  bool _startedForSession = false;
  bool _initializing = false;

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  void start() {
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (!AppConfig.isLive || auth.phase != SessionPhase.signedIn) {
      _startedForSession = false;
      return;
    }
    if (!_startedForSession) {
      _startedForSession = true;
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    if (_initializing || kIsWeb) return;
    _initializing = true;
    try {
      if (Firebase.apps.isEmpty) {
        if (_hasExplicitOptions) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _messagingSenderId,
              projectId: _projectId,
              storageBucket: _storageBucket,
              iosBundleId: _iosBundleId,
            ),
          );
        } else {
          // Native google-services.json / GoogleService-Info.plist can supply
          // options without exposing credentials in Dart defines.
          await Firebase.initializeApp();
        }
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
      await _tokenSubscription?.cancel();
      _tokenSubscription = messaging.onTokenRefresh.listen((next) {
        unawaited(_register(next));
      });
    } catch (_) {
      // Push is optional. Notification inbox remains available when Firebase
      // has not been configured for this build or permission is denied.
    } finally {
      _initializing = false;
    }
  }

  bool get _hasExplicitOptions =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _projectId.isNotEmpty;

  Future<void> _register(String token) async {
    if (token.isEmpty || auth.phase != SessionPhase.signedIn) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    try {
      await auth.authorized((access) => api.register(access, token, platform));
    } on AuthFailure {
      // AuthController handles refresh/re-auth; retry on the next token or
      // session event rather than surfacing a push setup error to the user.
    } catch (_) {
      // Device registration must never block login or content workflows.
    }
  }

  void dispose() {
    auth.removeListener(_onAuthChanged);
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }
}
