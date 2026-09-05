import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/domain/session.dart';
import '../storage/token_store.dart';

enum SessionPhase { starting, signedOut, signedIn, unavailable }

class AuthController extends ChangeNotifier {
  AuthController(this.api, this.store);
  final AuthApi api;
  final TokenStore store;
  SessionPhase phase = SessionPhase.starting;
  Account? account;
  String? error;
  bool busy = false;
  SessionTokens? _tokens;
  Future<void>? _refreshing;

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    phase = SessionPhase.starting;
    error = null;
    notifyListeners();
    try {
      _tokens = await store.read();
      if (_tokens == null) {
        phase = SessionPhase.signedOut;
      } else {
        // Always renew on cold start; no dependence on the device clock.
        await _refresh();
        account = await api.me(_tokens!.access);
        phase = SessionPhase.signedIn;
      }
    } on AuthFailure catch (failure) {
      error = failure.message;
      if (failure.sessionRejected) {
        await _clear();
      } else {
        // Keep the saved session during outages so retry can recover it.
        phase = SessionPhase.unavailable;
      }
    } catch (_) {
      phase = SessionPhase.unavailable;
      error = 'เปิดข้อมูลการเข้าสู่ระบบไม่ได้ กรุณาลองใหม่';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> authenticate(
    String email,
    String password, {
    String? name,
  }) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = name == null
          ? await api.login(email.trim(), password)
          : await api.register(email.trim(), password, name.trim());
      await store.write(result.tokens);
      _tokens = result.tokens;
      account = result.account;
      phase = SessionPhase.signedIn;
    } on AuthFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'บันทึกการเข้าสู่ระบบไม่ได้ กรุณาลองใหม่';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _refresh() => _refreshing ??= _rotate().whenComplete(() {
    _refreshing = null;
  });

  Future<void> _rotate() async {
    final previous = _tokens;
    if (previous == null) {
      throw const AuthFailure('กรุณาเข้าสู่ระบบใหม่', status: 401);
    }
    final next = await api.refresh(previous.refresh);
    // Persist rotated credentials before exposing the updated session.
    await store.write(next);
    _tokens = next;
  }

  Future<Account> currentAccount() async {
    final access = _tokens?.access;
    if (access == null) {
      throw const AuthFailure('กรุณาเข้าสู่ระบบใหม่', status: 401);
    }
    try {
      return await api.me(access);
    } on AuthFailure catch (failure) {
      if (failure.status != 401) rethrow;
      try {
        // Other concurrent requests may have already renewed this token.
        if (_tokens?.access == access) await _refresh();
        return await api.me(_tokens!.access);
      } on AuthFailure catch (renewalFailure) {
        if (renewalFailure.sessionRejected) {
          await _clear();
          error = renewalFailure.message;
          notifyListeners();
        }
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      // Wait for token rotation before revoking the latest refresh token.
      try {
        await _refreshing;
      } catch (_) {
        /* Still clear local session. */
      }
      final refresh = _tokens?.refresh;
      await _clear();
      if (refresh != null) {
        try {
          await api.logout(refresh);
        } catch (_) {
          error = 'ออกจากระบบในเครื่องแล้ว แต่ติดต่อเซิร์ฟเวอร์ไม่ได้';
        }
      }
    } catch (_) {
      error = 'ลบข้อมูลการเข้าสู่ระบบไม่ได้ กรุณาลองใหม่';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _clear() async {
    await store.clear();
    _tokens = null;
    account = null;
    phase = SessionPhase.signedOut;
  }
}
