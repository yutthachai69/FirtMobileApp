import 'dart:async';

import 'package:relaycontent/core/storage/token_store.dart';
import 'package:relaycontent/features/auth/data/auth_api.dart';
import 'package:relaycontent/features/auth/domain/session.dart';
import 'package:relaycontent/features/home/data/home_api.dart';
import 'package:relaycontent/features/home/domain/home_data.dart';

const testAccount = Account(
  id: 'user-1',
  email: 'user@example.com',
  name: 'Tester',
  timezone: 'Asia/Bangkok',
);
const testTokens = SessionTokens(access: 'access-1', refresh: 'refresh-1');

class MemoryTokenStore implements TokenStore {
  SessionTokens? value;
  @override
  Future<SessionTokens?> read() async => value;
  @override
  Future<void> write(SessionTokens tokens) async {
    value = tokens;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeAuthApi implements AuthApi {
  int refreshCount = 0;
  int loginCount = 0;
  int registerCount = 0;
  String? revoked;
  bool rejectOldAccess = false;
  AuthFailure? loginFailure;
  AuthFailure? refreshFailure;
  bool logoutOffline = false;
  Completer<void>? refreshGate;
  @override
  Future<AuthResult> login(String email, String password) async {
    loginCount++;
    if (loginFailure != null) throw loginFailure!;
    return const AuthResult(testAccount, testTokens);
  }

  @override
  Future<AuthResult> register(
    String email,
    String password,
    String name,
  ) async {
    registerCount++;
    return const AuthResult(testAccount, testTokens);
  }

  @override
  Future<SessionTokens> refresh(String token) async {
    refreshCount++;
    if (refreshGate != null) await refreshGate!.future;
    if (refreshFailure != null) throw refreshFailure!;
    return const SessionTokens(access: 'access-2', refresh: 'refresh-2');
  }

  @override
  Future<Account> me(String accessToken) async {
    if (rejectOldAccess && accessToken == 'access-1') {
      throw const AuthFailure('expired', status: 401);
    }
    return testAccount;
  }

  @override
  Future<void> logout(String refreshToken) async {
    if (logoutOffline) throw const AuthFailure('offline');
    revoked = refreshToken;
  }
}

/// FakeHomeApi ให้เทสควบคุมสิ่งที่หน้าหลักแสดงได้
/// โดยไม่ต้องยิง network จริง
class FakeHomeApi extends HomeApi {
  FakeHomeApi([this.data = const HomeData()]);
  HomeData data;
  int calls = 0;

  @override
  Future<HomeData> load(String access) async {
    calls++;
    return data;
  }
}
