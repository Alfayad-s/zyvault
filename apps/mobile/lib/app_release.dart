import 'dart:convert';

/// The published Android release, read from the website.
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.notes,
    required this.alertsUrl,
    required this.basicUrl,
  });

  final int versionCode;
  final String versionName;
  final String notes;
  final Uri alertsUrl;
  final Uri basicUrl;

  static const host = 'zyvault.clawdage.com';
  static final catalog = Uri.https(host, '/app-release.json');

  Uri apkUrl({required bool alerts}) => alerts ? alertsUrl : basicUrl;

  static AppRelease? parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final code = decoded['versionCode'];
    final name = decoded['versionName'];
    final alerts = _apk(decoded['alerts']);
    final basic = _apk(decoded['basic']);
    if (code is! int || code < 1 || name is! String || name.isEmpty) {
      return null;
    }
    if (alerts == null || basic == null) return null;
    final notes = decoded['notes'];
    return AppRelease(
      versionCode: code,
      versionName: name,
      notes: notes is String ? notes.trim() : '',
      alertsUrl: alerts,
      basicUrl: basic,
    );
  }

  /// Only the two files published on the zyvault site can be installed.
  static Uri? _apk(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host != host) return null;
    if (uri.path != '/zyvault.apk' && uri.path != '/zyvault-basic.apk') {
      return null;
    }
    return uri;
  }
}
