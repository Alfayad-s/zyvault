import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _ink = Color(0xFF17310C);
const _lime = Color(0xFFC8F57A);
const _deep = Color(0xFF1E4D12);
const _green = Color(0xFF3D7A28);
const _card = Color(0xFF2C2C2E);
const _field = Color(0xFF1C1C1E);
const _lineColor = Color(0xFF3A3A3C);
const _muted = Color(0xFF8E8E93);
const _red = Color(0xFFFF6B6B);

class IntelligenceScreen extends StatelessWidget {
  const IntelligenceScreen({super.key, required this.api});

  final FinanceApi api;

  @override
  Widget build(BuildContext context) {
    final dashboard = _Destination(
      'Dashboard',
      'Balance, month and plans',
      LucideIcons.layoutDashboard,
      FinanceOverviewScreen(api: api),
    );
    final safe = _Destination(
      'Safe to spend',
      'What is left after essentials',
      LucideIcons.wallet,
      FinanceSafeScreen(api: api),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Intelligence')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _Intro(),
          const SizedBox(height: 16),
          SizedBox(
            height: 148,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _FeatureTile(dashboard)),
                const SizedBox(width: 12),
                Expanded(child: _FeatureTile(safe)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Ahead',
            items: [
              _Destination(
                'Cash flow',
                '7 to 90 days, confirmed and estimated',
                LucideIcons.chartNoAxesCombined,
                FinanceForecastScreen(api: api),
              ),
              _Destination(
                'Purchase',
                'See a one-time cost on the forecast',
                LucideIcons.shoppingBag,
                FinanceSimulatorScreen(
                  api: api,
                  kind: 'purchase',
                  title: 'Purchase',
                ),
              ),
              _Destination(
                'Savings',
                'See a monthly set-aside',
                LucideIcons.piggyBank,
                FinanceSimulatorScreen(
                  api: api,
                  kind: 'savings_target',
                  title: 'Savings',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Check',
            items: [
              _Destination(
                'Health',
                'A score with the working shown',
                LucideIcons.heartPulse,
                FinanceHealthScreen(api: api),
              ),
              _Destination(
                'Insights',
                'Short notes from your own figures',
                LucideIcons.lightbulb,
                FinanceInsightsScreen(api: api),
              ),
              _Destination(
                'Unusual lines',
                'Compared with your history, not fraud',
                LucideIcons.search,
                FinanceAnomaliesScreen(api: api),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _lime,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your figures',
                style: TextStyle(
                  color: _green,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'See the same numbers as Chat',
                style: TextStyle(
                  color: _deep,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Balance, cash flow, and what is safe to spend.',
                style: TextStyle(
                  color: _green,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile(this.item);

  final _Destination item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _IconBadge(item.icon, filled: true),
                  const Spacer(),
                  const Icon(LucideIcons.chevronRight, color: _muted, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<_Destination> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, item) in items.indexed) ...[
                if (index > 0) const Divider(height: 1, color: _lineColor),
                InkWell(
                  onTap: () => _open(context, item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _IconBadge(item.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          LucideIcons.chevronRight,
                          color: _muted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon, {this.filled = false});

  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: filled ? _lime : _field,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: filled ? _ink : _lime),
    );
  }
}

void _open(BuildContext context, _Destination item) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => item.page));
}

class _Destination {
  const _Destination(this.title, this.subtitle, this.icon, this.page);
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
}

class FinanceOverviewScreen extends StatelessWidget {
  const FinanceOverviewScreen({super.key, required this.api});
  final FinanceApi api;

  @override
  Widget build(BuildContext context) {
    return _FinancePage(
      title: 'Dashboard',
      load: api.financeOverview,
      builder: (data) {
        final categories = (data['categories'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final upcoming = (data['upcoming'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        return [
          _MoneyCard(
            'Balance',
            data['balance'] as int? ?? 0,
            'Recorded cash. Lending is separate.',
          ),
          _Pair(
            'This month in',
            data['monthIncome'] as int? ?? 0,
            'This month out',
            data['monthExpense'] as int? ?? 0,
          ),
          _Line('Left this month', _money(data['monthSavings'] as int? ?? 0)),
          _Line('Monthly plans', _money(data['recurringExpense'] as int? ?? 0)),
          _Line('Others owe you', _money(data['outstandingLent'] as int? ?? 0)),
          _Line(
            'You owe others',
            _money(data['outstandingBorrowed'] as int? ?? 0),
          ),
          if (categories.isEmpty)
            const _Empty('No category totals this month.')
          else ...[
            const _Heading('Categories'),
            for (final item in categories.take(6))
              _Line(
                '${item['name']} · ${item['kind']}',
                _money(item['total'] as int? ?? 0),
              ),
          ],
          const _Heading('Confirmed plans, next 30 days'),
          if (upcoming.isEmpty)
            const _Empty('No saved plans in the next 30 days.')
          else
            for (final item in upcoming.take(8))
              _Line(
                '${item['date']} · ${item['categoryName']}',
                '${item['certainty']} ${_money(item['kind'] == 'expense' ? -(item['amount'] as int? ?? 0) : item['amount'] as int? ?? 0)}',
              ),
        ];
      },
    );
  }
}

class FinanceForecastScreen extends StatefulWidget {
  const FinanceForecastScreen({super.key, required this.api});
  final FinanceApi api;

  @override
  State<FinanceForecastScreen> createState() => _FinanceForecastScreenState();
}

class _FinanceForecastScreenState extends State<FinanceForecastScreen> {
  var _days = 30;

  @override
  Widget build(BuildContext context) {
    return _FinancePage(
      title: 'Cash flow',
      load: () => widget.api.financeForecast(_days),
      header: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final days in [7, 15, 30, 60, 90])
            _Pill(
              label: '$days days',
              selected: _days == days,
              onTap: () => setState(() => _days = days),
            ),
        ],
      ),
      builder: (data) {
        final points = (data['points'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final assumptions = (data['assumptions'] as List<dynamic>? ?? [])
            .map((item) => '$item')
            .toList();
        return [
          _MoneyCard(
            'Projected end',
            data['endBalance'] as int? ?? 0,
            'Estimated income is not added.',
          ),
          _Pair(
            'Confirmed in',
            data['confirmedIncome'] as int? ?? 0,
            'Confirmed out',
            data['confirmedExpense'] as int? ?? 0,
          ),
          _Pair(
            'Estimated in',
            data['estimatedIncome'] as int? ?? 0,
            'Estimated out',
            data['estimatedExpense'] as int? ?? 0,
          ),
          for (final line in assumptions) _Note(line),
          const _Heading('Daily balance'),
          if (points.isEmpty)
            const _Empty('No days in this forecast.')
          else
            for (final point in points.take(12))
              _Line(
                '${point['date']}',
                'end ${_money(point['projectedBalance'] as int? ?? 0)} · est out ${_money(point['estimatedOut'] as int? ?? 0)}',
              ),
        ];
      },
    );
  }
}

class FinanceSafeScreen extends StatefulWidget {
  const FinanceSafeScreen({super.key, required this.api});
  final FinanceApi api;

  @override
  State<FinanceSafeScreen> createState() => _FinanceSafeScreenState();
}

class _FinanceSafeScreenState extends State<FinanceSafeScreen> {
  final _reserve = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _reserve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FinancePage(
      title: 'Safe to spend',
      load: widget.api.financeSafe,
      header: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _reserve,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              cursorColor: _lime,
              decoration: _fieldDecoration('Emergency reserve, rupees'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    final amount = parseMoney(_reserve.text.trim());
                    if (amount == null && _reserve.text.trim() != '0') return;
                    setState(() => _saving = true);
                    try {
                      await widget.api.saveFinanceProfile(amount ?? 0);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reserve saved. Pull to refresh.'),
                          ),
                        );
                      }
                    } on FinanceException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            style: _limeButton.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
      builder: (data) {
        final lines = (data['lines'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        return [
          _MoneyCard(
            'You can spend',
            data['safeToSpend'] as int? ?? 0,
            'About ${_money(data['daily'] as int? ?? 0)} a day for ${data['daysLeft']} days.',
          ),
          for (final line in lines)
            _Line(
              '${line['label']}',
              '${_money(line['amount'] as int? ?? 0)}\n${line['note']}',
            ),
        ];
      },
    );
  }
}

class FinanceHealthScreen extends StatelessWidget {
  const FinanceHealthScreen({super.key, required this.api});
  final FinanceApi api;

  @override
  Widget build(BuildContext context) {
    return _FinancePage(
      title: 'Health',
      load: api.financeHealth,
      builder: (data) {
        final score = data['score'];
        final components = (data['components'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        return [
          _MoneyCard(
            score == null ? 'Not enough yet' : '$score / 100',
            0,
            'Blank parts are left out of the average.',
          ),
          for (final item in components)
            _Line(
              '${item['label']} · ${item['score'] ?? 'left out'}',
              'Weight ${item['weight']}. ${item['detail']}',
            ),
        ];
      },
    );
  }
}

class FinanceInsightsScreen extends StatelessWidget {
  const FinanceInsightsScreen({super.key, required this.api});
  final FinanceApi api;

  @override
  Widget build(BuildContext context) {
    return _FinancePage(
      title: 'Insights',
      load: api.financeInsights,
      builder: (data) {
        final items = (data['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (items.isEmpty) return [const _Empty('No insights yet.')];
        return [
          for (final item in items) ...[
            _Heading('${item['title']}'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${item['body']}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            for (final evidence
                in (item['evidence'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>())
              _Line(
                '${evidence['label']}',
                evidence['amount'] == null
                    ? ''
                    : _money(evidence['amount'] as int),
              ),
          ],
        ];
      },
    );
  }
}

class FinanceAnomaliesScreen extends StatelessWidget {
  const FinanceAnomaliesScreen({super.key, required this.api});
  final FinanceApi api;

  @override
  Widget build(BuildContext context) {
    return _FinancePage(
      title: 'Unusual lines',
      load: api.financeAnomalies,
      builder: (data) {
        final items = (data['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (items.isEmpty) {
          return [
            const _Empty('Nothing looks unusual against your own history.'),
          ];
        }
        return [
          const _Note(
            'These are comparisons with your past lines. They are not fraud alerts.',
          ),
          for (final item in items)
            _Line(
              '${item['severity']} · ${item['categoryName'] ?? item['kind']}',
              '${item['reason']}',
            ),
        ];
      },
    );
  }
}

class FinanceSimulatorScreen extends StatefulWidget {
  const FinanceSimulatorScreen({
    super.key,
    required this.api,
    required this.kind,
    required this.title,
  });
  final FinanceApi api;
  final String kind;
  final String title;

  @override
  State<FinanceSimulatorScreen> createState() => _FinanceSimulatorScreenState();
}

class _FinanceSimulatorScreenState extends State<FinanceSimulatorScreen> {
  final _amount = TextEditingController();
  final _months = TextEditingController(text: '12');
  Map<String, dynamic>? _result;
  var _error = '';
  var _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _months.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsMonths = widget.kind == 'emi';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _Note(
            'This does not change your accounts. Income changes stay assumptions.',
          ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            cursorColor: _lime,
            decoration: _fieldDecoration('Amount in rupees'),
          ),
          if (needsMonths) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _months,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              cursorColor: _lime,
              decoration: _fieldDecoration('Months'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final amount = parseMoney(_amount.text.trim());
                    if (amount == null) {
                      setState(
                        () => _error =
                            'Enter an amount such as 30000 or 30000.00',
                      );
                      return;
                    }
                    setState(() {
                      _busy = true;
                      _error = '';
                    });
                    try {
                      final result = await widget.api.financeSimulate(
                        kind: widget.kind,
                        amount: amount,
                        months: needsMonths ? int.tryParse(_months.text) : null,
                      );
                      if (mounted) setState(() => _result = result);
                    } on FinanceException catch (error) {
                      if (mounted) setState(() => _error = error.message);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            style: _limeButton,
            child: const Text('Show the difference'),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error,
                style: const TextStyle(color: _red, height: 1.4),
              ),
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _Line(
              'If you leave things',
              _money(_result!['baselineEnd'] as int? ?? 0),
            ),
            _Line(
              'After this change',
              _money(_result!['scenarioEnd'] as int? ?? 0),
            ),
            _Line('Difference', _money(_result!['delta'] as int? ?? 0)),
            for (final line
                in (_result!['assumptions'] as List<dynamic>? ?? []))
              _Note('$line'),
          ],
        ],
      ),
    );
  }
}

class _FinancePage extends StatefulWidget {
  const _FinancePage({
    required this.title,
    required this.load,
    required this.builder,
    this.header,
  });
  final String title;
  final Future<Map<String, dynamic>> Function() load;
  final List<Widget> Function(Map<String, dynamic> data) builder;
  final Widget? header;

  @override
  State<_FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<_FinancePage> {
  Map<String, dynamic>? _data;
  var _error = '';
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant _FinancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await widget.load();
      if (mounted) setState(() => _data = data);
    } on FinanceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PullRefresh(
        onRefresh: _reload,
        child: ListView(
          physics: pullPhysics,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _lime,
                    ),
                  ),
                ),
              ),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: _red, height: 1.4)),
            if (_data != null) ...widget.builder(_data!),
          ],
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard(this.label, this.amount, this.note);
  final String label;
  final int amount;
  final String note;

  @override
  Widget build(BuildContext context) {
    final money =
        amount != 0 ||
        label == 'Balance' ||
        label == 'You can spend' ||
        label == 'Projected end';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: _lime,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (money)
            Text(
              label,
              style: const TextStyle(
                color: _green,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (money) const SizedBox(height: 6),
          Text(
            money ? '₹${formatMoney(amount)}' : label,
            style: const TextStyle(
              color: _deep,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(
              color: _green,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair(this.left, this.leftAmount, this.right, this.rightAmount);
  final String left;
  final int leftAmount;
  final String right;
  final int rightAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _Line(left, _money(leftAmount))),
          Expanded(child: _Line(right, _money(rightAmount))),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.title, this.value);
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _muted, height: 1.4),
    ),
  );
}

String _money(int paise) => '₹${formatMoney(paise)}';

final _limeButton = FilledButton.styleFrom(
  backgroundColor: _lime,
  foregroundColor: _ink,
  disabledBackgroundColor: _lineColor,
  disabledForegroundColor: _muted,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
);

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _muted),
    floatingLabelStyle: const TextStyle(color: _lime),
    filled: true,
    fillColor: _field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _lineColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _lime),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _lime : _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _ink : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
