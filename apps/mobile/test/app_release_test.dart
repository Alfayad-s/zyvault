import 'package:finance_track/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the published version and the two site APKs', () {
    final release = AppRelease.parse('''
      {
        "versionCode": 3,
        "versionName": "1.0.2",
        "notes": "A new version of zyvault is ready.",
        "alerts": "https://zyvault.clawdage.com/zyvault.apk",
        "basic": "https://zyvault.clawdage.com/zyvault-basic.apk"
      }
    ''')!;
    expect(release.versionCode, 3);
    expect(release.versionName, '1.0.2');
    expect(release.apkUrl(alerts: true).path, '/zyvault.apk');
    expect(release.apkUrl(alerts: false).path, '/zyvault-basic.apk');
  });

  test('rejects a download that is not one of the site APKs', () {
    expect(
      AppRelease.parse('''
        {
          "versionCode": 4,
          "versionName": "1.0.3",
          "alerts": "https://example.com/zyvault.apk",
          "basic": "https://zyvault.clawdage.com/zyvault-basic.apk"
        }
      '''),
      isNull,
    );
    expect(
      AppRelease.parse('''
        {
          "versionCode": 4,
          "versionName": "1.0.3",
          "alerts": "http://zyvault.clawdage.com/zyvault.apk",
          "basic": "https://zyvault.clawdage.com/other.apk"
        }
      '''),
      isNull,
    );
  });
}
