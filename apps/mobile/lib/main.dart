import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/app_lock.dart';
import 'package:finance_track/screens/lock_screen.dart';
import 'package:finance_track/screens/login_screen.dart';
import 'package:finance_track/screens/onboarding_screen.dart';
import 'package:finance_track/screens/shell.dart';
import 'package:finance_track/session.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FinanceTrackApp());
}

class FinanceTrackApp extends StatefulWidget {
  const FinanceTrackApp({super.key, this.session, this.lock});

  final Session? session;
  final AppLock? lock;

  @override
  State<FinanceTrackApp> createState() => _FinanceTrackAppState();
}

class _FinanceTrackAppState extends State<FinanceTrackApp>
    with WidgetsBindingObserver {
  late final Session _session;
  late final AppLock _lock;
  FinanceApi? _api;

  /// The feature tour shows before the login page: on first open and after logout.
  var _tour = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = widget.session ?? Session();
    _lock = widget.lock ?? AppLock();
    if (widget.session == null) {
      _lock.load().then((_) => _session.restore());
    } else {
      _session.ready = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lock.appLeft();
    } else if (state == AppLifecycleState.resumed) {
      _lock.appReturned();
    }
  }

  Future<void> _signOut() async {
    _lock.reset();
    setState(() => _tour = true);
    await _session.logout();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zyvault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          surface: const Color(0xFF111111),
        ),
        scaffoldBackgroundColor: const Color(0xFF111111),
        canvasColor: const Color(0xFF111111),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111111),
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
      ),
      builder: (context, child) => ListenableBuilder(
        listenable: Listenable.merge([_session, _lock]),
        builder: (context, _) => Stack(
          children: [
            child!,
            if (_session.signedIn && _lock.locked)
              LockScreen(lock: _lock, onSignOut: _signOut),
          ],
        ),
      ),
      home: ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          if (!_session.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!_session.signedIn) {
            _api = null;
            if (_tour) {
              return OnboardingScreen(
                onDone: () => setState(() => _tour = false),
              );
            }
            return LoginScreen(
              onSendCode: _session.sendCode,
              onVerify: (email, code) async {
                await _session.verifyCode(email, code);
                _lock.reset();
              },
            );
          }
          final api = _api ??= FinanceApi(
            token: _session.token,
            tokenProvider: _session.freshToken,
            onTokenRejected: _session.renew,
          );
          return AppShell(
            key: ObjectKey(api),
            api: api,
            lock: _lock,
            onLogout: _signOut,
          );
        },
      ),
    );
  }
}
