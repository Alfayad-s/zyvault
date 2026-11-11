import 'package:finance_track/access.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:flutter/material.dart';

const _card = Color(0xFF2C2C2E);
const _muted = Color(0xFF8E8E93);

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key, required this.api});

  final FinanceApi api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin panel')),
      body: ListenableBuilder(
        listenable: AppAccess.current,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'These switches hide a feature from members. Your own app stays the same.',
                  style: TextStyle(color: _muted, height: 1.4),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < featureLabels.length; index++) ...[
                      if (index > 0) const Divider(height: 1, color: Color(0xFF3A3A3C)),
                      SwitchListTile(
                        value: AppAccess.current.features[featureLabels.keys.elementAt(index)] ?? true,
                        onChanged: (value) async {
                          final key = featureLabels.keys.elementAt(index);
                          final problem = await AppAccess.current.setFeature(api, key, value);
                          if (problem != null && context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Text(problem)));
                          }
                        },
                        title: Text(
                          featureLabels.values.elementAt(index),
                          style: const TextStyle(color: Colors.white),
                        ),
                        activeThumbColor: const Color(0xFF17310C),
                        activeTrackColor: const Color(0xFFC8F57A),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
