import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads an assistant reply aloud in English or Malayalam.
class ReplyVoice {
  ReplyVoice._();

  static const _speech = MethodChannel('zyvault/speech');
  static final _tts = FlutterTts();

  /// Opens Google’s voice download screen so a Malayalam voice can be installed.
  static Future<String?> openMalayalamInstall() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return 'Malayalam speech install is available on Android';
    }
    try {
      final opened = await _speech.invokeMethod<bool>('installMalayalamVoice');
      if (opened == true) return null;
      return 'Could not open voice download. Open Google Text-to-speech in phone settings';
    } catch (error) {
      debugPrint('Voice install: $error');
      return 'Could not open voice download. Try again';
    }
  }
  static var _ready = false;
  static var _playing = false;

  static bool _yes(Object? value) => value == true || value == 1 || value == '1';

  static Future<void> _prepare() async {
    if (_ready) return;
    final engines = await _tts.getEngines;
    debugPrint('TTS engines: $engines');
    if (engines is List && engines.contains('com.google.android.tts')) {
      await _tts.setEngine('com.google.android.tts');
    }
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    _ready = true;
  }

  static Future<String?> speak(String text, {required VoidCallback onDone}) async {
    final spoken = text.trim();
    if (spoken.isEmpty) return null;
    try {
      await _prepare();
      if (_playing) {
        await _tts.stop();
        _playing = false;
      }
      final malayalam = RegExp(r'[\u0D00-\u0D7F]').hasMatch(spoken);
      final languages = malayalam
          ? const ['ml-IN', 'ml_IN', 'en-IN', 'en-US']
          : const ['en-IN', 'en_IN', 'en-US', 'en_US'];
      var chosen = false;
      for (final language in languages) {
        if (_yes(await _tts.setLanguage(language))) {
          chosen = true;
          break;
        }
      }
      if (!chosen && malayalam) {
        return 'Install a Malayalam voice in the phone’s text-to-speech settings, then try again';
      }
      _playing = true;
      _tts.setStartHandler(() => debugPrint('TTS started'));
      _tts.setCompletionHandler(() {
        _playing = false;
        onDone();
      });
      _tts.setCancelHandler(() {
        _playing = false;
        onDone();
      });
      _tts.setErrorHandler((error) {
        debugPrint('TTS error: $error');
        _playing = false;
        onDone();
      });
      final result = await _tts.speak(spoken, focus: true);
      debugPrint('TTS speak result: $result');
      if (!_yes(result)) {
        _playing = false;
        onDone();
        return 'Could not read that reply. Try again';
      }
      return null;
    } catch (error) {
      debugPrint('Read aloud failed: $error');
      _playing = false;
      onDone();
      return 'Reading aloud needs the app to be opened again';
    }
  }

  static Future<void> stop() async {
    _playing = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
