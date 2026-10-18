import 'dart:async';

import 'package:finance_track/api/finance_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _page = Color(0xFF111111);
const _field = Color(0xFF1C1C1E);
const _line = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _error = Color(0xFFFF6B6B);

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSendCode,
    required this.onVerify,
  });

  final Future<CodeRequest> Function(String email) onSendCode;
  final Future<void> Function(String email, String code) onVerify;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _timer;
  var _signUp = false;
  var _busy = false;
  String? _error;
  CodeRequest? _request;
  var _resendIn = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String get _address => _email.text.trim().toLowerCase();

  Future<void> _sendCode() async {
    if (_busy) return;
    if (!_emailPattern.hasMatch(_address)) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await widget.onSendCode(_address);
      if (!mounted) return;
      _code.clear();
      setState(() => _request = request);
      _startTimer(request.resendAfterSeconds);
      _codeFocus.requestFocus();
    } on FinanceException catch (caught) {
      if (mounted) setState(() => _error = caught.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final request = _request;
    if (_busy || request == null) return;
    if (_code.text.length != request.codeLength) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onVerify(_address, _code.text);
    } on FinanceException catch (caught) {
      if (!mounted) return;
      _code.clear();
      setState(() => _error = caught.message);
      _codeFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) timer.cancel();
    });
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _request = null;
      _error = null;
      _resendIn = 0;
    });
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what sign-in is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _page,
      body: SingleChildScrollView(
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _request == null
                  ? const BrandHero()
                  : SizedBox(width: double.infinity, height: top + 16),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 32 + bottom),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _request == null
                        ? _emailStep()
                        : _codeStep(_request!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emailStep() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _signUp ? 'Create Account' : 'Login Account',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _signUp
              ? "Hello, let's set up your account"
              : 'Hello, welcome back to account',
          style: const TextStyle(color: _muted, fontSize: 15),
        ),
        const SizedBox(height: 28),
        _MethodSwitch(onPhone: () => _soon('Phone')),
        const SizedBox(height: 32),
        const Text(
          'Email',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: _email,
          builder: (context, value, _) {
            final valid = _emailPattern.hasMatch(value.text.trim());
            return TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendCode(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: Colors.white,
              decoration: _fieldDecoration(
                hint: 'you@example.com',
                prefix: const Icon(LucideIcons.mail, color: _muted, size: 20),
                suffix: valid
                    ? const Icon(
                        LucideIcons.circleCheck,
                        color: Color(0xFF3DDC84),
                        size: 20,
                      )
                    : null,
              ),
            );
          },
        ),
        _ErrorText(_error),
        const SizedBox(height: 24),
        _PrimaryButton(label: 'Send Code', busy: _busy, onPressed: _sendCode),
        const SizedBox(height: 32),
        const _OrDivider(label: 'or continue with'),
        const SizedBox(height: 24),
        _OutlineButton(
          onPressed: () => _soon('Google'),
          icon: const _GoogleMark(),
          label: 'Continue with Google',
        ),
        const SizedBox(height: 40),
        Center(
          child: GestureDetector(
            onTap: _busy
                ? null
                : () => setState(() {
                    _signUp = !_signUp;
                    _error = null;
                  }),
            child: Text.rich(
              TextSpan(
                text: _signUp
                    ? 'Already have an account? '
                    : "Don't have an account? ",
                style: const TextStyle(color: _muted, fontSize: 14),
                children: [
                  TextSpan(
                    text: _signUp ? 'Sign In' : 'Sign Up',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _codeStep(CodeRequest request) {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _busy ? null : _changeEmail,
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: _field,
              fixedSize: const Size(44, 44),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enter Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: 'We sent a ${request.codeLength}-digit code to ',
            style: const TextStyle(color: _muted, fontSize: 15, height: 1.4),
            children: [
              TextSpan(
                text: _address,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _CodeBoxes(
          controller: _code,
          focusNode: _codeFocus,
          length: request.codeLength,
          enabled: !_busy,
          onCompleted: _verify,
        ),
        _ErrorText(_error),
        const SizedBox(height: 24),
        ValueListenableBuilder(
          valueListenable: _code,
          builder: (context, value, _) => _PrimaryButton(
            label: 'Verify',
            busy: _busy,
            onPressed: value.text.length == request.codeLength ? _verify : null,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: _resendIn > 0
              ? Text(
                  'Resend code in ${_resendIn}s',
                  style: const TextStyle(color: _muted, fontSize: 14),
                )
              : TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text(
                    'Resend code',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _changeEmail,
            child: const Text('Change email', style: TextStyle(color: _muted)),
          ),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration({
  required String hint,
  Widget? prefix,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF5C5C60)),
    filled: true,
    fillColor: _field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    prefixIcon: prefix,
    suffixIcon: suffix,
    enabledBorder: border(_line),
    disabledBorder: border(_line),
    focusedBorder: border(Colors.white),
  );
}

class _MethodSwitch extends StatelessWidget {
  const _MethodSwitch({required this.onPhone});

  final VoidCallback onPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onPhone,
              borderRadius: BorderRadius.circular(22),
              child: const Center(
                child: Text(
                  'Phone Number',
                  style: TextStyle(color: _muted, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF3A3A3C),
          disabledForegroundColor: _muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/google_g.svg',
      width: 22,
      height: 22,
      semanticsLabel: 'Google',
    );
  }
}

/// The zyvault illustration at the top of the login page, blending into the page.
class BrandHero extends StatelessWidget {
  const BrandHero({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width.clamp(0.0, 520.0);
    return Padding(
      padding: EdgeInsets.only(top: top + 8),
      child: Center(
        child: SizedBox(
          width: width,
          height: width * 0.75,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/onboarding/login.jpg',
                fit: BoxFit.contain,
                semanticLabel:
                    'A person unlocking the zyvault padlock with a key',
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.12, 0.7, 1],
                    colors: [
                      _page,
                      Color(0x00111111),
                      Color(0x00111111),
                      _page,
                    ],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0, 0.06, 0.9, 1],
                    colors: [
                      Color(0x66111111),
                      Color(0x00111111),
                      Color(0x00111111),
                      _page,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _line, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: _line, thickness: 1)),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message!,
        style: const TextStyle(color: _error, fontSize: 14),
      ),
    );
  }
}

class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.enabled,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool enabled;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(length),
              ],
              onChanged: (value) {
                if (value.length == length) onCompleted();
              },
              showCursor: false,
              enableInteractiveSelection: false,
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                children: [
                  for (var index = 0; index < length; index++) ...[
                    if (index > 0) SizedBox(width: length > 6 ? 8 : 12),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 0.82,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _field,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  focusNode.hasFocus &&
                                      index == text.length.clamp(0, length - 1)
                                  ? Colors.white
                                  : _line,
                              width: 1.4,
                            ),
                          ),
                          child: Text(
                            index < text.length ? text[index] : '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
