import 'dart:async';

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/chat_store.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/flower_avatar.dart';
import 'package:flutter/material.dart';
import 'package:finance_track/widgets/prompt_box.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.api});

  final FinanceApi api;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatTurn {
  _ChatTurn({required this.role, required this.content, this.proposal, this.review = 'open'});

  final String role;
  final String content;
  final Map<String, dynamic>? proposal;
  String review;
}

class _ChatScreenState extends State<ChatScreen> {
  final _scroll = ScrollController();
  final _turns = <_ChatTurn>[];
  var _sending = false;
  var _following = false;
  var _waited = 0;
  var _ready = false;
  var _reveal = -1;
  var _saving = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await ChatStore.read();
    if (!mounted) return;
    setState(() {
      if (_turns.isEmpty) {
        _turns.addAll(
          saved.map(
            (turn) => _ChatTurn(
              role: turn.role,
              content: turn.content,
              proposal: turn.proposal,
              review: turn.review,
            ),
          ),
        );
      }
      _ready = true;
    });
    _scrollToEnd();
  }

  Future<void> _remember() {
    return ChatStore.write([
      for (final turn in _turns)
        StoredTurn(role: turn.role, content: turn.content, proposal: turn.proposal, review: turn.review),
    ]);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _startWait() {
    _clock?.cancel();
    _waited = 0;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _waited++);
    });
  }

  void _stopWait() {
    _clock?.cancel();
    _clock = null;
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending || !_ready) return;
    final turns = [
      for (final turn in _turns) StoredTurn(role: turn.role, content: turn.content),
      StoredTurn(role: 'user', content: trimmed),
    ];
    setState(() {
      _turns.add(_ChatTurn(role: 'user', content: trimmed));
      _sending = true;
      _reveal = -1;
    });
    _startWait();
    _scrollToEnd();
    unawaited(_remember());
    try {
      final answer = await widget.api.chat(
        today: isoDate(DateTime.now()),
        memory: chatMemory(turns),
        messages: [
          for (final turn in turns) {'role': turn.role, 'content': turn.content},
        ],
      );
      if (!mounted) return;
      _stopWait();
      setState(() {
        _turns.add(_ChatTurn(role: 'assistant', content: answer.reply, proposal: answer.proposal));
        _sending = false;
        _reveal = _turns.length - 1;
      });
      _scrollToEnd();
      unawaited(_remember());
    } on FinanceException catch (caught) {
      if (!mounted) return;
      _stopWait();
      setState(() {
        _turns.add(_ChatTurn(role: 'assistant', content: caught.message));
        _sending = false;
        _reveal = _turns.length - 1;
      });
      _scrollToEnd();
      unawaited(_remember());
    }
  }

  Future<void> _accept(int index) async {
    final turn = _turns[index];
    final action = turn.proposal?['action'];
    if (action is! Map || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.applyChat(Map<String, dynamic>.from(action));
      if (!mounted) return;
      setState(() {
        turn.review = 'saved';
        _saving = false;
      });
      unawaited(_remember());
    } on FinanceException catch (caught) {
      if (!mounted) return;
      setState(() {
        _turns.add(_ChatTurn(role: 'assistant', content: caught.message));
        _saving = false;
      });
      unawaited(_remember());
    }
  }

  void _dismiss(int index) {
    setState(() => _turns[index].review = 'dismissed');
    unawaited(_remember());
  }

  void _scrollToEnd() {
    if (_following) return;
    _following = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _following = false;
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if ((_scroll.offset - target).abs() < 1) return;
      _scroll.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlowerAvatar(working: _sending, size: 28),
            const SizedBox(width: 8),
            const Text('Chat'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !_ready
                ? const Center(child: FlowerAvatar(size: 72))
                : _turns.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FlowerAvatar(size: 88),
                          SizedBox(height: 16),
                          Text(
                            'Ask about this month’s spending, balances, or budgets. Answers use a short snapshot of your money.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF8E8E93)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _turns.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _turns.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FlowerAvatar(working: true, size: 36),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _waited == 0 ? 'Thinking' : 'Thinking · ${_waited}s',
                                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final turn = _turns[index];
                      final mine = turn.role == 'user';
                      if (mine) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            margin: const EdgeInsets.only(top: 18, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8F57A),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              turn.content,
                              style: const TextStyle(color: Color(0xFF161616), fontSize: 16, height: 1.35),
                            ),
                          ),
                        );
                      }
                      final writing = index == _reveal;
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: FlowerAvatar(animate: false, size: 32),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  writing
                                      ? _WrittenReply(text: turn.content, onGrew: _scrollToEnd)
                                      : Text(
                                          turn.content,
                                          textAlign: TextAlign.left,
                                          style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 16, height: 1.45),
                                        ),
                                  if (turn.proposal != null && turn.review == 'open')
                                    _ReviewCard(
                                      proposal: turn.proposal!,
                                      busy: _saving,
                                      onAccept: () => _accept(index),
                                      onDismiss: () => _dismiss(index),
                                    )
                                  else if (turn.review == 'saved')
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text('Saved', style: TextStyle(color: Color(0xFFC8F57A), fontSize: 14)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: PromptBox(loading: _sending, onSend: _send),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.proposal,
    required this.busy,
    required this.onAccept,
    required this.onDismiss,
  });

  final Map<String, dynamic> proposal;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final lines = proposal['lines'];
    final title = proposal['title'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title is String ? title : 'Review',
            style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (lines is List)
            for (final line in lines)
              if (line is String)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(line, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 15, height: 1.35)),
                ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: busy ? null : onDismiss,
                child: const Text('Not now', style: TextStyle(color: Color(0xFF9CA3AF))),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC8F57A),
                  foregroundColor: const Color(0xFF161616),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(busy ? 'Saving' : 'Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WrittenReply extends StatefulWidget {
  const _WrittenReply({required this.text, required this.onGrew});

  final String text;
  final VoidCallback onGrew;

  @override
  State<_WrittenReply> createState() => _WrittenReplyState();
}

class _WrittenReplyState extends State<_WrittenReply> with SingleTickerProviderStateMixin {
  late final AnimationController _pen;
  var _shown = 0;

  @override
  void initState() {
    super.initState();
    final milliseconds = (widget.text.length * 18).clamp(400, 6000);
    _pen = AnimationController(vsync: this, duration: Duration(milliseconds: milliseconds))
      ..addListener(_follow)
      ..forward();
  }

  void _follow() {
    final count = (_pen.value * widget.text.length).floor();
    if (count == _shown) return;
    final crossedLine = count ~/ 24 != _shown ~/ 24 || count >= widget.text.length;
    _shown = count;
    if (crossedLine) widget.onGrew();
  }

  @override
  void dispose() {
    _pen.removeListener(_follow);
    _pen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pen,
      builder: (context, _) {
        final count = (_pen.value * widget.text.length).floor().clamp(0, widget.text.length);
        final done = _pen.status == AnimationStatus.completed;
        return ExcludeSemantics(
          excluding: !done,
            child: Text(
              widget.text.substring(0, count),
              textAlign: TextAlign.left,
              style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 16, height: 1.45),
            ),
        );
      },
    );
  }
}
