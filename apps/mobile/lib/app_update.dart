import 'dart:io';

import 'package:finance_track/app_release.dart';
import 'package:finance_track/build_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('zyvault/update');
const _snoozeCode = 'update_snooze_code';
const _snoozeUntil = 'update_snooze_until';

/// Checks the site once and, when a newer Android build exists, opens the sheet.
/// Returns true after a completed check, or false when the check could not run.
Future<bool> offerAppUpdate(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return true;
  final release = await fetchAppRelease();
  if (release == null || !context.mounted) return false;
  final local = await _channel.invokeMethod<int>('versionCode') ?? 0;
  if (release.versionCode <= local || !context.mounted) return true;
  if (await _snoozed(release.versionCode) || !context.mounted) return true;
  final started = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => UpdateSheet(release: release),
  );
  if (started != true) await _snooze(release.versionCode);
  return true;
}

Future<AppRelease?> fetchAppRelease() async {
  try {
    final response = await http
        .get(AppRelease.catalog, headers: const {'Cache-Control': 'no-cache'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    return AppRelease.parse(response.body);
  } catch (error) {
    debugPrint('Update check failed: $error');
    return null;
  }
}

Future<bool> _snoozed(int versionCode) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getInt(_snoozeCode) != versionCode) return false;
  final until = prefs.getInt(_snoozeUntil) ?? 0;
  return DateTime.now().millisecondsSinceEpoch < until;
}

Future<void> _snooze(int versionCode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_snoozeCode, versionCode);
  await prefs.setInt(
    _snoozeUntil,
    DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
  );
}

class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key, required this.release});

  final AppRelease release;

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  var _busy = false;
  var _progress = 0.0;
  String? _message;

  Future<void> _update() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _message = null;
    });
    try {
      final file = await _download(
        widget.release.apkUrl(alerts: upiAlertsBuild),
      );
      if (!mounted) return;
      final status = await _channel.invokeMethod<String>('install', {
        'path': file.path,
      });
      if (!mounted) return;
      if (status == 'permission') {
        setState(() {
          _busy = false;
          _message = 'Allow zyvault to install apps, then tap Update again.';
        });
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Update install failed: $error');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'The update could not be downloaded. Try again.';
      });
    }
  }

  Future<File> _download(Uri url) async {
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', url))
          .timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) {
        throw HttpException('Download failed (${response.statusCode})');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zyvault-update.apk');
      if (await file.exists()) await file.delete();
      final sink = file.openWrite();
      final total = response.contentLength ?? 0;
      var got = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0 && mounted) {
            setState(() => _progress = got / total);
          }
        }
      } finally {
        await sink.close();
      }
      if (got < 1000000) {
        await file.delete();
        throw const HttpException('Download was incomplete');
      }
      return file;
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Text(
            'New update',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${release.versionName} is ready.',
            style: const TextStyle(fontSize: 16, color: Color(0xFFC8F57A)),
          ),
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              release.notes,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFFC7C7CC),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF2C2C2E),
                color: const Color(0xFFC8F57A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _progress == 0 ? 'Downloading…' : '${(_progress * 100).round()}%',
              style: const TextStyle(color: Color(0xFF8E8E93)),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: Color(0xFFFFB35C))),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _update,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC8F57A),
              foregroundColor: const Color(0xFF17310C),
              disabledBackgroundColor: const Color(0xFF3A3A3C),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Update',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text(
              'Later',
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ),
        ],
      ),
    );
  }
}
