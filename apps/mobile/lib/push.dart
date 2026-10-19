import 'dart:async';
import 'dart:io' show Platform;

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

const _serverPushKey = 'server_push';

/// Firebase Cloud Messaging: the server pushes planned entries, bills due
/// tomorrow and a weekly summary, even when the app is closed.
class Push {
  Push._();

  static StreamSubscription<String>? _tokenRefresh;
  static StreamSubscription<RemoteMessage>? _foreground;
  static String? _token;

  static bool get _supported =>
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  /// True once the server confirmed it sends pushes to this phone.
  static Future<bool> serverHandlesReminders() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_serverPushKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> start(FinanceApi api) async {
    if (!_supported) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (caught) {
      debugPrint('Push is off: Firebase is not set up ($caught)');
      return;
    }
    try {
      await Notifier.createPushChannels();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // The server sends with FCM HTTP v1 `message.token`, which takes a
      // registration token, not the installation id from register().
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token == null) return;
      await _register(api, token);
      // ignore: deprecated_member_use
      _tokenRefresh ??= messaging.onTokenRefresh.listen(
        (fresh) => _register(api, fresh),
      );
      _foreground ??= FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        Notifier.pushInForeground(
          title: notification.title ?? 'zyvault',
          body: notification.body ?? '',
          channel: notification.android?.channelId ?? 'plans',
        );
      });
    } catch (caught) {
      debugPrint('Push setup failed: $caught');
    }
  }

  static Future<void> _register(FinanceApi api, String token) async {
    _token = token;
    try {
      final server = await api.registerDevice(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_serverPushKey, server);
      debugPrint(server ? 'Server push is on' : 'Server push is off: Firebase is not configured on the server');
    } catch (caught) {
      debugPrint('Could not register for push: $caught');
    }
  }

  /// Called on logout so this phone stops getting the account's pushes.
  static Future<void> stop(FinanceApi api) async {
    final token = _token;
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    _tokenRefresh = null;
    _foreground = null;
    _token = null;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_serverPushKey, false);
      if (token != null) await api.unregisterDevice(token);
    } catch (_) {}
  }
}
