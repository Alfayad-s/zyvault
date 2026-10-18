import 'package:finance_track/models.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OperationsCard extends StatelessWidget {
  const OperationsCard({
    super.key,
    required this.transactions,
    required this.now,
    this.onOpenRecords,
    this.onOpenTransaction,
  });

  final List<TransactionItem> transactions;
  final DateTime now;
  final VoidCallback? onOpenRecords;
  final ValueChanged<TransactionItem>? onOpenTransaction;

  @override
  Widget build(BuildContext context) {
    final groups = _groups(transactions, now);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Operations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (onOpenRecords != null)
                GestureDetector(
                  onTap: onOpenRecords,
                  child: const Text(
                    'Full records',
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Nothing recorded yet',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            )
          else
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  group.$1,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              for (var index = 0; index < group.$2.length; index++) ...[
                _OperationRow(
                  transaction: group.$2[index],
                  onTap: onOpenTransaction == null
                      ? null
                      : () => onOpenTransaction!(group.$2[index]),
                ),
                if (index < group.$2.length - 1)
                  const Divider(height: 1, color: Color(0xFF3A3A3C)),
              ],
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({required this.transaction, required this.onTap});

  final TransactionItem transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final income = transaction.kind == 'income';
    final amount = formatMoney(transaction.amount);
    final subtitle =
        (transaction.note == null || transaction.note!.trim().isEmpty)
        ? transaction.accountName
        : transaction.note!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CategoryIcon(
              name: transaction.categoryName,
              kind: transaction.kind,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.categoryName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              income ? '+₹$amount' : '₹$amount',
              style: TextStyle(
                color: income ? const Color(0xFF3DDC84) : Colors.white,
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

IconData categoryIcon(String name, String kind) {
  final lower = name.toLowerCase();
  const icons = <String, IconData>{
    'grocer': LucideIcons.shoppingBasket,
    'chai': LucideIcons.coffee,
    'coffee': LucideIcons.coffee,
    'food': LucideIcons.utensils,
    'fuel': LucideIcons.fuel,
    'travel': LucideIcons.plane,
    'transport': LucideIcons.car,
    'rental': LucideIcons.keyRound,
    'rent': LucideIcons.house,
    'home': LucideIcons.house,
    'recharge': LucideIcons.smartphone,
    'subscription': LucideIcons.repeat,
    'bill': LucideIcons.receipt,
    'shop': LucideIcons.shoppingBag,
    'personal': LucideIcons.scissors,
    'health': LucideIcons.heartPulse,
    'insurance': LucideIcons.shieldCheck,
    'education': LucideIcons.graduationCap,
    'kids': LucideIcons.baby,
    'pet': LucideIcons.pawPrint,
    'entertainment': LucideIcons.clapperboard,
    'gift': LucideIcons.gift,
    'emi': LucideIcons.landmark,
    'invest': LucideIcons.trendingUp,
    'salary': LucideIcons.briefcase,
    'business': LucideIcons.store,
    'freelance': LucideIcons.laptop,
    'interest': LucideIcons.piggyBank,
    'refund': LucideIcons.undo2,
  };
  for (final entry in icons.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  if (kind == 'income') return LucideIcons.arrowDown;
  return LucideIcons.sparkles;
}

List<(String, List<TransactionItem>)> _groups(
  List<TransactionItem> transactions,
  DateTime now,
) {
  final groups = <(String, List<TransactionItem>)>[];
  for (final transaction in transactions) {
    final label = _dayHeading(transaction.occurredOn, now);
    if (groups.isEmpty || groups.last.$1 != label) {
      groups.add((label, [transaction]));
    } else {
      groups.last.$2.add(transaction);
    }
  }
  return groups;
}

String _dayHeading(String iso, DateTime now) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return iso;
  final date = DateTime(year, month, day);
  final today = DateTime(now.year, now.month, now.day);
  if (date == today) return 'TODAY';
  if (date == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
