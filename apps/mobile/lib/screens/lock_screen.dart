import 'package:finance_track/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.lock, required this.onSignOut});

  final AppLock lock;
  final Future<void> Function() onSignOut;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await widget.lock.unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFC8F57A);
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              GestureDetector(
                onTap: _unlock,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lime.withValues(alpha: 0.12),
                    border: Border.all(color: lime.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(
                    LucideIcons.fingerprint,
                    color: lime,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'zyvault is locked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your fingerprint, face or phone PIN to open',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: _error == null
                    ? null
                    : Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 14,
                        ),
                      ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(LucideIcons.fingerprint),
                  label: const Text('Unlock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF3A3A3C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : widget.onSignOut,
                child: const Text(
                  'Sign out',
                  style: TextStyle(color: Color(0xFF8E8E93)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
