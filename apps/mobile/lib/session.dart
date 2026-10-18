import 'dart:async';

import 'package:finance_track/activity_cache.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accessKey = 'access_token';
const _refreshKey = 'refresh_token';
const _expiresKey = 'access_expires_at';
const _refreshEarly = Duration(minutes: 2);

class Session extends ChangeNotifier {
  Session({AuthApi? authApi, FlutterSecureStorage? storage})
    : _authApi = authApi ?? AuthApi(),
      _storage = storage ?? const FlutterSecureStorage();

  final AuthApi _authApi;
  final FlutterSecureStorage _storage;
  String? token;
  String? _refreshToken;
  DateTime? _expiresAt;
  Future<String?>? _refreshing;
  bool ready = false;

  bool get signedIn => token != null;

  Future<void> restore() async {
    try {
      token = await _storage.read(key: _accessKey);
      _refreshToken = await _storage.read(key: _refreshKey);
      final expires = int.tryParse(await _storage.read(key: _expiresKey) ?? '');
      _expiresAt = expires == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expires);
    } catch (_) {
      token = null;
    }
    await _dropLegacyToken();
    if (token != null && _refreshToken == null) token = null;
    ready = true;
    notifyListeners();
  }

  Future<CodeRequest> sendCode(String email) => _authApi.sendCode(email);

  Future<void> verifyCode(String email, String code) async {
    await _store(await _authApi.verifyCode(email, code));
  }

  Future<String?> freshToken() async {
    final expires = _expiresAt;
    if (token != null &&
        expires != null &&
        DateTime.now().isBefore(expires.subtract(_refreshEarly))) {
      return token;
    }
    return renew();
  }

  Future<String?> renew() {
    return _refreshing ??= _renew().whenComplete(() => _refreshing = null);
  }

  Future<String?> _renew() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await logout();
      return null;
    }
    try {
      final tokens = await _authApi.refresh(refreshToken);
      await _store(tokens, notify: false);
      return tokens.accessToken;
    } on FinanceException catch (caught) {
      if (caught.statusCode == 401 || caught.statusCode == 400) {
        await logout();
        return null;
      }
      return token;
    }
  }

  Future<void> logout() async {
    token = null;
    _refreshToken = null;
    _expiresAt = null;
    try {
      await _storage.deleteAll();
    } catch (_) {}
    await ActivityCache.clear();
    notifyListeners();
  }

  Future<void> _store(AuthTokens tokens, {bool notify = true}) async {
    final firstSignIn = token == null;
    token = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _expiresAt = tokens.expiresAt;
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    await _storage.write(
      key: _expiresKey,
      value: '${tokens.expiresAt.millisecondsSinceEpoch}',
    );
    if (notify || firstSignIn) notifyListeners();
  }

  Future<void> _dropLegacyToken() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_accessKey);
    } catch (_) {}
  }
}
