import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabledKey = 'app_lock_enabled';
const _relockAfter = Duration(minutes: 1);

class AppLock extends ChangeNotifier {
  AppLock({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;
  bool enabled = false;
  bool locked = false;
  bool _authenticating = false;
  DateTime? _leftAt;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      enabled = preferences.getBool(_enabledKey) ?? false;
    } catch (_) {
      enabled = false;
    }
    locked = enabled;
    notifyListeners();
  }

  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<String?> unlock() async {
    final problem = await _authenticate('Unlock zyvault');
    if (problem == null) {
      locked = false;
      _leftAt = null;
      notifyListeners();
    }
    return problem;
  }

  Future<String?> setEnabled(bool value) async {
    if (value) {
      if (!await available()) {
        return 'Set a fingerprint, face or screen lock on this phone first';
      }
      final problem = await _authenticate('Turn on fingerprint unlock');
      if (problem != null) return problem;
    }
    enabled = value;
    locked = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_enabledKey, value);
    } catch (_) {}
    notifyListeners();
    return null;
  }

  void appLeft() {
    if (_authenticating || !enabled) return;
    _leftAt ??= DateTime.now();
  }

  void appReturned() {
    final leftAt = _leftAt;
    _leftAt = null;
    if (_authenticating || !enabled || leftAt == null) return;
    if (DateTime.now().difference(leftAt) >= _relockAfter) {
      locked = true;
      notifyListeners();
    }
  }

  void reset() {
    locked = false;
    _leftAt = null;
  }

  Future<String?> _authenticate(String reason) async {
    if (_authenticating) return null;
    _authenticating = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return ok ? null : 'Not unlocked, try again';
    } on LocalAuthException catch (caught) {
      return switch (caught.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => 'Not unlocked, try again',
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware =>
          'Set a fingerprint, face or screen lock on this phone first',
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          'Too many tries. Unlock your phone with its PIN, then try again',
        _ => 'Unlock failed (${caught.code.name})',
      };
    } catch (caught) {
      debugPrint('App lock failed: $caught');
      return 'Unlock is not available on this phone';
    } finally {
      _authenticating = false;
    }
  }
}
