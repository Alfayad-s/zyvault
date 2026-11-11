import 'package:finance_track/api/finance_api.dart';
import 'package:flutter/foundation.dart';

const featureLabels = {
  'chat': 'Chat',
  'intelligence': 'Intelligence',
  'voice': 'Voice',
  'bankSms': 'Bank SMS',
  'upiAlerts': 'UPI alerts',
  'creditCards': 'Credit cards',
  'goals': 'Goals',
  'people': 'People',
  'budgets': 'Budgets',
  'plans': 'Plans',
};

class AppAccess extends ChangeNotifier {
  AppAccess._();

  static final current = AppAccess._();

  String role = 'member';
  final features = {for (final key in featureLabels.keys) key: true};

  bool get isAdmin => role == 'admin';

  bool on(String key) => isAdmin || (features[key] ?? true);

  Future<void> load(FinanceApi api) async {
    try {
      final body = await api.me();
      role = body['role'] == 'admin' ? 'admin' : 'member';
      final flags = body['features'];
      if (flags is Map) {
        for (final key in featureLabels.keys) {
          final value = flags[key];
          if (value is bool) features[key] = value;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> setFeature(FinanceApi api, String key, bool enabled) async {
    final previous = features[key] ?? true;
    features[key] = enabled;
    notifyListeners();
    try {
      await api.setFeature(key, enabled);
      return null;
    } on FinanceException catch (error) {
      features[key] = previous;
      notifyListeners();
      return error.message;
    } catch (caught) {
      features[key] = previous;
      notifyListeners();
      return '$caught';
    }
  }
}
