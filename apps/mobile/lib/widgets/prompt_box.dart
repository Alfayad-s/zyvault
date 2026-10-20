import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef PromptSend = void Function(String text, {bool voice, int seconds});

/// Dark prompt box used on the chat screen: a growing field, image preview,
/// and a send button that becomes a mic when the field is empty.
class PromptBox extends StatefulWidget {
  const PromptBox({super.key, required this.loading, required this.onSend});

  final bool loading;
  final PromptSend onSend;

  @override
  State<PromptBox> createState() => _PromptBoxState();
}

class _PromptBoxState extends State<PromptBox> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final _speech = SpeechToText();
  var _listening = false;
  var _closingVoice = false;
  var _seconds = 0;
  var _malayalam = false;
  String? _voiceError;
  DateTime? _started;
  Timer? _clock;
  XFile? _image;

  bool get _hasText => _text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final saved = (await SharedPreferences.getInstance()).getString('voice_language');
    if (!mounted || saved == null) return;
    setState(() => _malayalam = saved == 'ml');
  }

  Future<void> _switchLanguage() async {
    if (_listening) return;
    final next = !_malayalam;
    setState(() => _malayalam = next);
    await (await SharedPreferences.getInstance()).setString('voice_language', next ? 'ml' : 'en');
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (_listening) _speech.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty || widget.loading || _listening) return;
    HapticFeedback.lightImpact();
    widget.onSend(text);
    _text.clear();
    setState(() {
      _image = null;
      _voiceError = null;
    });
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (!mounted || file == null) return;
    setState(() => _image = file);
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stopListening();
      return;
    }
    FocusScope.of(context).unfocus();
    final ready = await _speech.initialize(onError: _onSpeechError);
    if (!mounted) return;
    if (!ready) {
      final allowed = await _speech.hasPermission;
      if (!mounted) return;
      setState(() {
        _voiceError = allowed
            ? 'Voice could not start on this phone'
            : 'Allow the microphone: Settings › Apps › zyvault › Permissions › Microphone';
      });
      return;
    }
    _text.clear();
    _clock?.cancel();
    setState(() {
      _listening = true;
      _seconds = 0;
      _started = DateTime.now();
      _voiceError = null;
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _started == null) return;
      setState(() => _seconds = DateTime.now().difference(_started!).inSeconds);
    });
    final localeId = await _localeId();
    if (!mounted || !_listening) return;
    await _speech.listen(
      onResult: (result) {
        _text.text = result.recognizedWords;
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
        if (result.finalResult) _stopListening();
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 30),
        localeId: localeId,
      ),
    );
  }

  Future<String> _localeId() async {
    final wanted = _malayalam ? 'ml_in' : 'en_in';
    final locales = await _speech.locales();
    for (final locale in locales) {
      if (locale.localeId.replaceAll('-', '_').toLowerCase() == wanted) {
        return locale.localeId;
      }
    }
    return _malayalam ? 'ml_IN' : 'en_IN';
  }

  Future<void> _stopListening() async {
    if (_closingVoice) return;
    _closingVoice = true;
    _clock?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    if (!mounted) return;
    final missed = _text.text.trim().isEmpty;
    setState(() {
      _listening = false;
      _started = null;
      _voiceError = missed ? "Didn't catch that. Tap the mic and try again" : null;
    });
    _closingVoice = false;
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    _clock?.cancel();
    setState(() {
      _listening = false;
      _started = null;
      _voiceError = error.errorMsg.contains('permission')
          ? 'Allow the microphone: Settings › Apps › zyvault › Permissions › Microphone'
          : error.errorMsg.contains('language')
          ? 'Add Malayalam in the phone’s voice typing settings, then try again'
          : "Didn't catch that. Tap the mic and try again";
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = _listening
        ? 'Listening · 0:${_seconds.toString().padLeft(2, '0')}'
        : 'Ask about your money';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2023),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _listening ? const Color(0xB3EF4444) : const Color(0xFF444444)),
        boxShadow: const [BoxShadow(color: Color(0x3D000000), blurRadius: 30, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_image != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_image!.path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 64,
                          height: 64,
                          color: const Color(0xFF2E3033),
                          child: const Icon(LucideIcons.image, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _image = null),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xB3000000), shape: BoxShape.circle),
                          child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          TextField(
            controller: _text,
            focusNode: _focus,
            minLines: 1,
            maxLines: 5,
            enabled: !widget.loading && !_listening,
            style: const TextStyle(color: Color(0xFFF3F4F6), fontSize: 16),
            cursorColor: Colors.white,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          if (_voiceError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Text(_voiceError!, style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 13)),
            ),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Upload image',
                        onPressed: widget.loading ? null : _pickImage,
                        icon: const Icon(LucideIcons.paperclip, color: Color(0xFF9CA3AF), size: 20),
                      ),
                      _ModeChip(
                        icon: LucideIcons.languages,
                        label: _malayalam ? 'മലയാളം' : 'English',
                        color: const Color(0xFFC8F57A),
                        selected: true,
                        onTap: () {
                          if (!_listening) _switchLanguage();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _SendButton(
                loading: widget.loading,
                listening: _listening,
                hasText: _hasText,
                onPressed: widget.loading
                    ? null
                    : _hasText
                    ? _submit
                    : _toggleMic,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: selected ? 8 : 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? color : const Color(0xFF9CA3AF)),
              if (selected) ...[
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.loading,
    required this.listening,
    required this.hasText,
    required this.onPressed,
  });

  final bool loading;
  final bool listening;
  final bool hasText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final filled = hasText && !listening && !loading;
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            loading
                ? LucideIcons.square
                : listening
                ? LucideIcons.circleStop
                : hasText
                ? LucideIcons.arrowUp
                : LucideIcons.mic,
            size: hasText || loading ? 16 : 18,
            color: listening
                ? const Color(0xFFEF4444)
                : filled
                ? const Color(0xFF1F2023)
                : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}
