import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/screens/budgets_section.dart';
import 'package:finance_track/screens/goals_section.dart';
import 'package:finance_track/screens/type_page.dart';
import 'package:finance_track/widgets/bank_logo.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:finance_track/widgets/operations_card.dart';
import 'package:finance_track/widgets/pull_refresh.dart';
import 'package:finance_track/widgets/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

bool _isCurrentMonth(DateTime month) {
  final today = DateTime.now();
  return month.year == today.year && month.month == today.month;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.ledger,
    required this.onReceive,
    required this.onSend,
    this.onOpenRecords,
    this.onOpenTransaction,
    this.onOpenScheduled,
  });

  final Ledger ledger;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback? onOpenRecords;
  final ValueChanged<TransactionItem>? onOpenTransaction;
  final VoidCallback? onOpenScheduled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ledger,
      builder: (context, _) {
        final summary = ledger.summary;
        if (ledger.loading && summary == null) {
          return const _HomeShimmer();
        }
        if (summary == null) {
          return PullRefresh(
            onRefresh: ledger.refresh,
            child: ListView(
              physics: pullPhysics,
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                Text(
                  _errorText(ledger.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: ledger.loading ? null : ledger.refresh,
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        return HomeView(
          summary: summary,
          recent: ledger.recent,
          accounts: ledger.accounts,
          monthTransactions: ledger.transactions,
          bankFor: ledger.bankFor,
          onReceive: onReceive,
          onSend: onSend,
          onOpenRecords: onOpenRecords,
          onOpenTransaction: onOpenTransaction,
          onRefresh: ledger.refresh,
          onLoadMore: ledger.loadMoreTransactions,
          loadingMore: ledger.loadingMore,
          onType: () => openTypePage(context, ledger),
          viewedMonth: ledger.month,
          onPreviousMonth: () => ledger.changeMonth(-1),
          onNextMonth: _isCurrentMonth(ledger.month) ? null : () => ledger.changeMonth(1),
          goals: GoalsStrip(ledger: ledger),
          budgets: BudgetsCard(ledger: ledger),
          nextPayment: ledger.nextPayment,
          onOpenScheduled: onOpenScheduled,
        );
      },
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.summary,
    required this.recent,
    required this.onReceive,
    required this.onSend,
    this.onOpenRecords,
    this.onOpenTransaction,
    required this.onRefresh,
    this.onLoadMore,
    this.loadingMore = false,
    this.now,
    this.onType,
    this.accounts = const [],
    this.monthTransactions = const [],
    this.bankFor,
    this.goals,
    this.budgets,
    this.nextPayment,
    this.onOpenScheduled,
    this.viewedMonth,
    this.onPreviousMonth,
    this.onNextMonth,
  });

  final Summary summary;
  final Schedule? nextPayment;
  final VoidCallback? onOpenScheduled;
  final Widget? goals;
  final Widget? budgets;
  final List<TransactionItem> recent;
  final List<Account> accounts;
  final List<TransactionItem> monthTransactions;
  final Bank? Function(Account account)? bankFor;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final VoidCallback? onOpenRecords;
  final ValueChanged<TransactionItem>? onOpenTransaction;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLoadMore;
  final bool loadingMore;
  final DateTime? now;
  final DateTime? viewedMonth;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback? onType;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) onType?.call();
      },
      child: PullRefresh(
        onRefresh: onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notice) {
            if (_nearEnd(notice)) onLoadMore?.call();
            return false;
          },
          child: ListView(
          physics: pullPhysics,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            const SizedBox(height: 8),
            BalanceCard(
              balance: summary.balance,
              monthChange: summary.monthIncome - summary.monthExpense,
              onReceive: onReceive,
              onSend: onSend,
              accounts: accounts,
              monthTransactions: monthTransactions,
              accountChanges: {
                for (final change in summary.accountChanges) change.accountId: change.change,
              },
              bankFor: bankFor,
            ),
            const SizedBox(height: 16),
            _HomeShortcuts(
              summary: summary,
              month: viewedMonth ?? now ?? DateTime.now(),
              onSpending: onOpenRecords,
              nextPayment: nextPayment,
              onScheduled: onOpenScheduled,
            ),
            if (goals != null) ...[const SizedBox(height: 24), goals!],
            if (budgets != null) ...[const SizedBox(height: 16), budgets!],
            const SizedBox(height: 16),
            if (onPreviousMonth != null)
              _MonthSwitch(
                month: viewedMonth ?? now ?? DateTime.now(),
                onPrevious: onPreviousMonth!,
                onNext: onNextMonth,
              ),
            OperationsCard(
              transactions: monthTransactions,
              now: now ?? DateTime.now(),
              onOpenRecords: onOpenRecords,
              onOpenTransaction: onOpenTransaction,
            ),
            if (loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC8F57A)),
                  ),
                ),
              ),
            const SizedBox(height: 72),
          ],
          ),
        ),
      ),
    );
  }
}

bool _nearEnd(ScrollNotification notice) {
  if (notice.metrics.axis != Axis.vertical) return false;
  if (notice is! ScrollUpdateNotification && notice is! ScrollEndNotification) return false;
  return notice.metrics.maxScrollExtent > 0 && notice.metrics.extentAfter < 480;
}

class _HomeShortcuts extends StatelessWidget {
  const _HomeShortcuts({
    required this.summary,
    required this.month,
    required this.onSpending,
    this.nextPayment,
    this.onScheduled,
  });

  final Summary summary;
  final DateTime month;
  final VoidCallback? onSpending;
  final Schedule? nextPayment;
  final VoidCallback? onScheduled;

  @override
  Widget build(BuildContext context) {
    final expenses = summary.categories
        .where((category) => category.kind == 'expense')
        .toList();
    return SizedBox(
      height: 136,
      child: Row(
        children: [
          Expanded(
            child: _SpendingTile(
              month: month,
              total: summary.monthExpense,
              expenses: expenses,
              onTap: onSpending,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _NextPaymentTile(
              schedule: nextPayment,
              now: month,
              onTap: onScheduled,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextPaymentTile extends StatelessWidget {
  const _NextPaymentTile({
    required this.schedule,
    required this.now,
    required this.onTap,
  });

  final Schedule? schedule;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final schedule = this.schedule;
    final income = schedule?.kind == 'income';
    return _LightTile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            income ? 'Next money in' : 'Next payment',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            schedule == null
                ? 'Nothing planned'
                : nextPaymentWhen(schedule, now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: schedule != null && schedule.nextOn == isoDate(now)
                  ? const Color(0xFFFFB35C)
                  : const Color(0xFF8E8E93),
              fontSize: 13,
              fontWeight: schedule != null && schedule.nextOn == isoDate(now)
                  ? FontWeight.w600
                  : null,
            ),
          ),
          const Spacer(),
          if (schedule == null)
            const Text(
              'Say "pay rent 12000 on the 5th every month"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12,
                height: 1.3,
              ),
            )
          else
            Row(
              children: [
                CategoryIcon(
                  name: schedule.categoryName,
                  kind: schedule.kind,
                  size: 34,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${income ? '+' : ''}${formatRupees(schedule.amount)}',
                          style: TextStyle(
                            color: income
                                ? const Color(0xFF3DDC84)
                                : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        schedule.note ?? schedule.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String nextPaymentWhen(Schedule schedule, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime.tryParse(schedule.nextOn);
  final at = schedule.atTime == null
      ? ''
      : ' · ${formatClock(schedule.atTime!)}';
  if (day == null) return schedule.nextOn;
  final days = DateTime(day.year, day.month, day.day).difference(today).inDays;
  final when = switch (days) {
    <= 0 => 'Today',
    1 => 'Tomorrow',
    < 7 => 'In $days days',
    _ => formatDate(schedule.nextOn).replaceFirst(RegExp(r' \d{4}$'), ''),
  };
  return '$when$at';
}

class _SpendingTile extends StatelessWidget {
  const _SpendingTile({
    required this.month,
    required this.total,
    required this.expenses,
    required this.onTap,
  });

  final DateTime month;
  final int total;
  final List<CategoryTotal> expenses;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _LightTile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Spent in ${_monthName(month)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupees(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SpendBar(expenses: expenses),
        ],
      ),
    );
  }
}

class _SpendBar extends StatelessWidget {
  const _SpendBar({required this.expenses});

  final List<CategoryTotal> expenses;

  static const _colors = [
    Color(0xFF7C5CFF),
    Color(0xFFF05555),
    Color(0xFF3DDC6E),
    Color(0xFFF5C451),
    Color(0xFF4C8DFF),
  ];

  @override
  Widget build(BuildContext context) {
    final slices = expenses
        .where((category) => category.total > 0)
        .take(5)
        .toList();
    if (slices.isEmpty) {
      return Container(
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }
    final sum = slices.fold<int>(0, (total, slice) => total + slice.total);
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          for (var index = 0; index < slices.length; index++) ...[
            if (index > 0) const SizedBox(width: 5),
            Expanded(
              flex: _share(slices[index].total, sum),
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  color: _colors[index % _colors.length],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _share(int amount, int sum) {
    if (sum <= 0) return 1;
    final share = (amount / sum * 100).round();
    return share < 14 ? 14 : share;
  }
}

class _LightTile extends StatelessWidget {
  const _LightTile({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        color: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

class _MonthSwitch extends StatelessWidget {
  const _MonthSwitch({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final label = month.year == today.year ? _monthName(month) : '${_monthName(month)} ${month.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: Icon(
              LucideIcons.chevronRight,
              color: onNext == null ? const Color(0xFF3A3A3C) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

String _monthName(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[date.month - 1];
}

String _errorText(Object? error) {
  if (error == null) {
    return 'Could not load your finances';
  }
  return error.toString();
}

class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.monthChange,
    required this.onReceive,
    required this.onSend,
    this.accounts = const [],
    this.monthTransactions = const [],
    this.accountChanges = const {},
    this.bankFor,
  });

  final int balance;
  final int monthChange;
  final VoidCallback onReceive;
  final VoidCallback onSend;
  final List<Account> accounts;
  final List<TransactionItem> monthTransactions;
  final Map<String, int> accountChanges;
  final Bank? Function(Account account)? bankFor;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  String? _selectedId;

  Account? get _selected {
    for (final account in widget.accounts) {
      if (account.id == _selectedId) return account;
    }
    return null;
  }

  void _toggle(String id) {
    setState(() => _selectedId = _selectedId == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final balance = selected?.balance ?? widget.balance;
    final monthChange = selected == null
        ? widget.monthChange
        : widget.accountChanges.containsKey(selected.id)
        ? widget.accountChanges[selected.id]!
        : widget.monthTransactions
              .where((item) => item.accountId == selected.id)
              .fold(
                0,
                (sum, item) =>
                    sum + (item.kind == 'income' ? item.amount : -item.amount),
              );
    final change = formatMoney(monthChange.abs());
    final changeText =
        '${monthChange < 0 ? '- ₹$change' : '+ ₹$change'} this month';
    final onReceive = widget.onReceive;
    final onSend = widget.onSend;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFC8F57A),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.accounts.isEmpty)
                            const _MarkRow()
                          else
                            _AccountLogos(
                              accounts: widget.accounts,
                              bankFor: widget.bankFor,
                              selectedId: selected?.id,
                              onTap: _toggle,
                            ),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              selected?.name ?? 'All accounts',
                              key: ValueKey(selected?.id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF3D7A28),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            balance < 0
                                ? '- ₹${formatMoney(balance.abs())}'
                                : '₹${formatMoney(balance)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF1E4D12),
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            changeText,
                            style: const TextStyle(
                              color: Color(0xFF3D7A28),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(left: 12, top: 12, child: _Pin()),
                  const Positioned(right: 12, top: 12, child: _Pin()),
                  const Positioned(left: 12, bottom: 12, child: _Pin()),
                  const Positioned(right: 12, bottom: 12, child: _Pin()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _CardAction(
                      icon: LucideIcons.arrowDown,
                      label: 'Receive',
                      onTap: onReceive,
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white24),
                  Expanded(
                    child: _CardAction(
                      icon: LucideIcons.arrowUp,
                      label: 'Send',
                      onTap: onSend,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountLogos extends StatelessWidget {
  const _AccountLogos({
    required this.accounts,
    required this.bankFor,
    required this.selectedId,
    required this.onTap,
  });

  final List<Account> accounts;
  final Bank? Function(Account account)? bankFor;
  final String? selectedId;
  final ValueChanged<String> onTap;

  static const _size = 42.0;
  static const _step = 28.0;
  static const _lift = 4.0;

  @override
  Widget build(BuildContext context) {
    final placed = [
      for (final (index, account) in accounts.indexed) (index, account),
    ];
    // The selected logo is painted last so it sits on top of the stack.
    placed.sort(
      (a, b) =>
          (a.$2.id == selectedId ? 1 : 0) - (b.$2.id == selectedId ? 1 : 0),
    );
    final width = _size + _step * (accounts.length - 1);
    return SizedBox(
      height: _size + _lift,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: _size + _lift,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (index, account) in placed)
                  AnimatedPositioned(
                    key: ValueKey(account.id),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    left: index * _step,
                    top: account.id == selectedId ? 0 : _lift,
                    child: _LogoChip(
                      account: account,
                      bank: bankFor?.call(account),
                      selected: account.id == selectedId,
                      onTap: () => onTap(account.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoChip extends StatelessWidget {
  const _LogoChip({
    required this.account,
    required this.bank,
    required this.selected,
    required this.onTap,
  });

  final Account account;
  final Bank? bank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${account.name} selected, tap to show all accounts'
          : 'Show ${account.name} balance',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _AccountLogos._size,
          height: _AccountLogos._size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? const Color(0xFF1E4D12)
                  : const Color(0xFFC8F57A),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.25 : 0.12),
                blurRadius: selected ? 8 : 4,
                offset: const Offset(-1, 2),
              ),
            ],
          ),
          child: ExcludeSemantics(
            child: BankLogo.round(
              bank: bank,
              cash: account.type == 'cash',
              size: _AccountLogos._size - 5,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow();

  @override
  Widget build(BuildContext context) {
    const marks = [
      (Color(0xFFF5A524), LucideIcons.indianRupee),
      (Color(0xFFE26A2C), LucideIcons.landmark),
      (Color(0xFF3B82F6), LucideIcons.wallet),
      (Color(0xFF7C5CFC), LucideIcons.creditCard),
    ];
    return SizedBox(
      height: 36,
      width: 36 + 26 * 3,
      child: Stack(
        children: [
          for (var index = 0; index < marks.length; index++)
            Positioned(
              left: index * 26,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: marks[index].$1,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC8F57A), width: 2),
                ),
                child: Icon(marks[index].$2, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    const bone = Color(0xFF3A3A3C);
    return Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  ShimmerBone(
                    width: double.infinity,
                    height: 176,
                    radius: 22,
                    color: bone,
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ShimmerBone(height: 18, radius: 9, color: bone),
                      ),
                      SizedBox(width: 28),
                      Expanded(
                        child: ShimmerBone(height: 18, radius: 9, color: bone),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 136,
            child: Row(
              children: [
                Expanded(child: ShimmerBone(height: 136, radius: 22)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBone(height: 136, radius: 22)),
              ],
            ),
          ),
          SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBone(width: 128, height: 22, radius: 8, color: bone),
                  SizedBox(height: 8),
                  _HomeShimmerRow(),
                  _HomeShimmerRow(),
                  _HomeShimmerRow(),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _HomeShimmerRow extends StatelessWidget {
  const _HomeShimmerRow();

  @override
  Widget build(BuildContext context) {
    const bone = Color(0xFF3A3A3C);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ShimmerBone(width: 40, height: 40, radius: 14, color: bone),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 120, height: 14, radius: 7, color: bone),
                SizedBox(height: 8),
                ShimmerBone(width: 72, height: 11, radius: 6, color: bone),
              ],
            ),
          ),
          ShimmerBone(width: 52, height: 14, radius: 7, color: bone),
        ],
      ),
    );
  }
}
