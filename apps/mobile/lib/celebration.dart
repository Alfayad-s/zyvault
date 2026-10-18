import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

class Celebration {
  Celebration._();

  static AudioPlayer? _player;
  static Future<void>? _loading;

  static Future<void> warmUp() {
    return _loading ??= _load();
  }

  static Future<void> play() async {
    _haptics();
    try {
      await warmUp();
      final player = _player;
      if (player == null) return;
      await player.seek(Duration.zero);
      await player.resume();
    } catch (caught) {
      debugPrint('Celebration sound failed: $caught');
    }
  }

  static Future<void> _load() async {
    try {
      final player = AudioPlayer(playerId: 'celebration');
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(0.8);
      await player.setSource(AssetSource('sounds/success.wav'));
      _player = player;
    } catch (caught) {
      debugPrint('Celebration sound could not load: $caught');
      _loading = null;
    }
  }

  static void _haptics() {
    const beats = <(int, Future<void> Function())>[
      (0, HapticFeedback.lightImpact),
      (120, HapticFeedback.lightImpact),
      (240, HapticFeedback.mediumImpact),
      (360, HapticFeedback.heavyImpact),
      (620, HapticFeedback.lightImpact),
    ];
    for (final (delay, beat) in beats) {
      Timer(Duration(milliseconds: delay), () => beat().ignore());
    }
  }
}
