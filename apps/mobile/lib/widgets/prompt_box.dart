import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dark prompt box used on the chat screen: a growing field, image preview,
/// and a send button that becomes a mic when the field is empty.
class PromptBox extends StatefulWidget {
  const PromptBox({super.key, required this.loading, required this.onSend});

  final bool loading;
  final ValueChanged<String> onSend;

  @override
  State<PromptBox> createState() => _PromptBoxState();
}

class _PromptBoxState extends State<PromptBox> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final _speech = SpeechToText();
  var _mode = _PromptMode.none;
  var _listening = false;
  XFile? _image;

  bool get _hasText => _text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty || widget.loading) return;
    HapticFeedback.lightImpact();
    widget.onSend(text);
    _text.clear();
    setState(() => _image = null);
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (!mounted || file == null) return;
    setState(() => _image = file);
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ready = await _speech.initialize();
    if (!ready || !mounted) return;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        _text.text = result.recognizedWords;
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
        if (result.finalResult && mounted) setState(() => _listening = false);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hint = switch (_mode) {
      _PromptMode.search => 'Search the web...',
      _PromptMode.think => 'Think deeply...',
      _PromptMode.canvas => 'Create on canvas...',
      _PromptMode.none => 'Ask about your money',
    };
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
                        icon: LucideIcons.globe,
                        label: 'Search',
                        color: const Color(0xFF1EAEDB),
                        selected: _mode == _PromptMode.search,
                        onTap: () => setState(
                          () => _mode = _mode == _PromptMode.search ? _PromptMode.none : _PromptMode.search,
                        ),
                      ),
                      _ModeChip(
                        icon: LucideIcons.brain,
                        label: 'Think',
                        color: const Color(0xFF8B5CF6),
                        selected: _mode == _PromptMode.think,
                        onTap: () => setState(
                          () => _mode = _mode == _PromptMode.think ? _PromptMode.none : _PromptMode.think,
                        ),
                      ),
                      _ModeChip(
                        icon: LucideIcons.folderCode,
                        label: 'Canvas',
                        color: const Color(0xFFF97316),
                        selected: _mode == _PromptMode.canvas,
                        onTap: () => setState(
                          () => _mode = _mode == _PromptMode.canvas ? _PromptMode.none : _PromptMode.canvas,
                        ),
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

enum _PromptMode { none, search, think, canvas }

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
