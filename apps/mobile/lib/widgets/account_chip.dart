import 'package:finance_track/models.dart';
import 'package:finance_track/widgets/bank_logo.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultAccountKey = 'default_account_id';

Future<String?> loadDefaultAccountId() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_defaultAccountKey);
  } catch (_) {
    return null;
  }
}

Future<void> saveDefaultAccountId(String id) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_defaultAccountKey, id);
  } catch (_) {}
}

Future<Account?> showAccountPicker(
  BuildContext context, {
  required List<Account> accounts,
  required Bank? Function(Account account) bankFor,
  String? currentId,
  String title = 'Pay from',
}) {
  return showModalBottomSheet<Account>(
    context: context,
    backgroundColor: const Color(0xFF161616),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final account in accounts)
            ListTile(
              onTap: () => Navigator.pop(context, account),
              leading: BankLogo.round(
                bank: bankFor(account),
                cash: account.type == 'cash',
                size: 40,
              ),
              title: Text(
                account.name,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: account.id == currentId
                  ? const Icon(LucideIcons.check, color: Color(0xFFC8F57A))
                  : null,
            ),
        ],
      ),
    ),
  );
}

class AccountChip extends StatelessWidget {
  const AccountChip({
    super.key,
    required this.account,
    required this.bank,
    required this.onTap,
    this.maxNameWidth = 180,
    this.verb = 'Paying from',
  });

  final Account account;
  final Bank? bank;
  final VoidCallback? onTap;
  final double maxNameWidth;
  final String verb;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$verb ${account.name}, tap to change',
      child: Material(
        color: const Color(0xFF1C1C1E),
        shape: const StadiumBorder(side: BorderSide(color: Color(0xFF3A3A3C))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BankLogo.round(
                    bank: bank,
                    cash: account.type == 'cash',
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxNameWidth),
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronDown,
                    color: Color(0xFF8E8E93),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
