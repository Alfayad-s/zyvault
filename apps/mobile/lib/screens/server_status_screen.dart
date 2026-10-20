import 'package:finance_track/api/finance_api.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _card = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);
const _lime = Color(0xFFC8F57A);
const _red = Color(0xFFFF6B6B);

class ServerStatusScreen extends StatefulWidget {
  const ServerStatusScreen({super.key, required this.api});

  final FinanceApi api;

  @override
  State<ServerStatusScreen> createState() => _ServerStatusScreenState();
}

class _ServerStatusScreenState extends State<ServerStatusScreen> {
  ServerReport? _report;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.api.serverStatus();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on FinanceException catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server details'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(widget.api.baseUrl, style: const TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator(color: _lime)),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: _red, fontSize: 16, height: 1.4))
          else if (report != null) ...[
            Text(
              report.ok ? 'Working' : 'Something needs attention',
              style: TextStyle(
                color: report.ok ? _lime : _red,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final check in report.checks) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      check.ok ? LucideIcons.circleCheck : LucideIcons.circleAlert,
                      color: check.ok ? _lime : _red,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            check.name,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(check.detail, style: const TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
