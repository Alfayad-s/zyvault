import 'dart:convert';

import 'package:finance_track/activity_cache.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/notifications.dart';
import 'package:finance_track/sms/bank_sms.dart';
import 'package:finance_track/money.dart';
import 'package:finance_track/period.dart';
import 'package:finance_track/reminders.dart';
import 'package:finance_track/home_screen_widget.dart';
import 'package:finance_track/screens/accounts_screen.dart';
import 'package:finance_track/screens/budgets_section.dart';
import 'package:finance_track/screens/ask_sheet.dart';
import 'package:finance_track/screens/goals_section.dart';
import 'package:finance_track/screens/transaction_form_screen.dart';
import 'package:finance_track/screens/home_screen.dart';
import 'package:finance_track/screens/login_screen.dart';
import 'package:finance_track/screens/onboarding_screen.dart';
import 'package:finance_track/screens/review_sheet.dart';
import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/screens/type_page.dart';
import 'package:finance_track/widgets/finance_bottom_bar.dart';
import 'package:finance_track/widgets/spending_card.dart';
import 'package:finance_track/widgets/thinking_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('agent parse posts the sentence and reads saved rows', () async {
    late Map<String, dynamic> sent;
    final api = FinanceApi(
      token: 'test',
      baseUrl: 'http://api',
      client: MockClient((request) async {
        expect(request.url.path, '/transactions/parse');
        expect(request.headers['authorization'], 'Bearer test');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode([
            {
              'transaction': {
                'id': 't1',
                'accountId': 'a1',
                'accountName': 'Cash',
                'categoryId': 'c1',
                'categoryName': 'Food',
                'amount': 45000,
                'kind': 'expense',
                'occurredOn': '2026-10-17',
                'note': 'Dominos — pizza with friends',
              },
              'parsed': {'amount': 45000, 'currency': 'INR'},
            },
          ]),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final saved = await api.parseTransactions(
      text: 'Spent 450 rupees on pizza last night',
      accountId: 'a1',
      today: '2026-10-18',
    );
    expect(sent['today'], '2026-10-18');
    expect(saved.single.transaction?.categoryName, 'Food');
    expect(saved.single.transaction?.amount, 45000);
  });

  testWidgets('add account sheet lists banks with logos', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ledger = Ledger(
      FinanceApi(
        token: 'test',
        baseUrl: 'http://api',
        client: MockClient((request) async {
          if (request.url.path == '/banks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'sbi',
                  'name': 'State Bank of India',
                  'short': 'SBI',
                  'color': '#22409A',
                },
                {
                  'id': 'federal',
                  'name': 'Federal Bank',
                  'short': 'FED',
                  'color': '#13438C',
                },
              ]),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountsScreen(ledger: ledger)),
      ),
    );
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    expect(find.text('State Bank of India'), findsOneWidget);
    expect(find.text('SBI'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search your bank'),
      'fed',
    );
    await tester.pump();
    expect(find.text('State Bank of India'), findsNothing);
    await tester.tap(find.text('Federal Bank'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Federal Bank').last,
          )
          .controller
          ?.text,
      'Federal Bank',
    );
  });

  testWidgets('balance card switches between all accounts and one bank', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BalanceCard(
            balance: 6000000,
            monthChange: 4500000,
            onReceive: () {},
            onSend: () {},
            accounts: const [
              Account(
                id: 'cash',
                name: 'Cash',
                type: 'cash',
                openingBalance: 0,
                balance: 200000,
              ),
              Account(
                id: 'sbi',
                name: 'State Bank of India',
                type: 'bank',
                openingBalance: 0,
                bankId: 'sbi',
                balance: 5800000,
              ),
            ],
            monthTransactions: const [
              TransactionItem(
                id: 't1',
                accountId: 'sbi',
                accountName: 'State Bank of India',
                categoryId: 'salary',
                categoryName: 'Salary',
                amount: 5000000,
                kind: 'income',
                occurredOn: '2026-10-01',
                note: 'salary',
              ),
              TransactionItem(
                id: 't2',
                accountId: 'cash',
                accountName: 'Cash',
                categoryId: 'food',
                categoryName: 'Food',
                amount: 500000,
                kind: 'expense',
                occurredOn: '2026-10-02',
                note: 'food',
              ),
            ],
            bankFor: (account) => account.bankId == 'sbi'
                ? const Bank(
                    id: 'sbi',
                    name: 'State Bank of India',
                    short: 'SBI',
                    color: 0xFF22409A,
                  )
                : null,
          ),
        ),
      ),
    );

    expect(find.text('All accounts'), findsOneWidget);
    expect(find.text('₹60,000.00'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show State Bank of India balance'));
    await tester.pumpAndSettle();
    expect(find.text('State Bank of India'), findsOneWidget);
    expect(find.text('₹58,000.00'), findsOneWidget);
    expect(find.text('+ ₹50,000.00 this month'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel(
        'State Bank of India selected, tap to show all accounts',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('₹60,000.00'), findsOneWidget);
  });

  testWidgets('manual add saves amount, category, account and date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final ledger =
        Ledger(
            FinanceApi(
              token: 'test',
              baseUrl: 'http://api',
              client: MockClient((request) async {
                if (request.method == 'POST' &&
                    request.url.path == '/transactions') {
                  sent.add(jsonDecode(request.body) as Map<String, dynamic>);
                  return http.Response(
                    jsonEncode({
                      'id': 't1',
                      'accountId': 'sbi',
                      'categoryId': 'food',
                      'amount': 45000,
                      'kind': 'expense',
                      'occurredOn': '2026-10-17',
                    }),
                    201,
                  );
                }
                return http.Response('[]', 200);
              }),
            ),
          )
          ..accounts = const [
            Account(id: 'cash', name: 'Cash', type: 'cash', openingBalance: 0),
            Account(id: 'sbi', name: 'SBI', type: 'bank', openingBalance: 0),
          ]
          ..categories = const [
            Category(id: 'food', name: 'Food', kind: 'expense'),
            Category(id: 'salary', name: 'Salary', kind: 'income'),
          ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TransactionFormScreen(ledger: ledger),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '450');
    await tester.tap(find.text('Food'));
    expect(find.text('Cash'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Paying from Cash, tap to change'));
    await tester.pumpAndSettle();
    expect(find.text('Pay from'), findsOneWidget);
    await tester.tap(find.text('SBI'));
    await tester.pumpAndSettle();
    expect(find.text('SBI'), findsOneWidget);
    await tester.tap(find.text('Yesterday'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(sent.single['amount'], 45000);
    expect(sent.single['categoryId'], 'food');
    expect(sent.single['accountId'], 'sbi');
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(sent.single['occurredOn'], isoDate(yesterday));
    expect(find.text('open'), findsOneWidget);
  });

  test('spots the account named in a quick entry', () {
    const banks = [
      Bank(id: 'sbi', name: 'State Bank of India', short: 'SBI', color: 0),
      Bank(id: 'hdfc', name: 'HDFC Bank', short: 'HDFC', color: 0),
    ];
    const accounts = [
      Account(id: 'cash', name: 'Cash', type: 'cash', openingBalance: 0),
      Account(
        id: 's',
        name: 'Salary',
        type: 'bank',
        openingBalance: 0,
        bankId: 'sbi',
      ),
      Account(
        id: 'h',
        name: 'HDFC Bank',
        type: 'bank',
        openingBalance: 0,
        bankId: 'hdfc',
      ),
    ];
    Bank? bankFor(Account account) {
      for (final bank in banks) {
        if (bank.id == account.bankId) return bank;
      }
      return null;
    }

    final sbi = accountInText('150 food sbi gpay', accounts, bankFor);
    expect(sbi.account?.id, 's');
    expect(parseSpendLine(sbi.text)?.reason, 'food');
    expect(
      accountInText('auto 80 cash', accounts, bankFor).account?.id,
      'cash',
    );
    expect(
      accountInText('200 petrol hdfc card', accounts, bankFor).account?.id,
      'h',
    );
    expect(accountInText('150 food', accounts, bankFor).account, isNull);
    expect(
      accountInText('80 cash and 200 sbi', accounts, bankFor).account,
      isNull,
    );
    expect(
      spendMessage(
        const SpendLine(
          amount: 15000,
          reason: 'food',
          categoryName: 'Food',
          kind: 'expense',
          accountName: 'Salary',
        ),
      ),
      'spend ₹150 for food from Salary',
    );
  });

  test('finds the bank from the account name when none is saved', () {
    final ledger = Ledger(FinanceApi(token: 'test'))
      ..banks = const [
        Bank(id: 'sbi', name: 'State Bank of India', short: 'SBI', color: 0),
        Bank(id: 'indian', name: 'Indian Bank', short: 'IB', color: 0),
        Bank(id: 'iob', name: 'Indian Overseas Bank', short: 'IOB', color: 0),
        Bank(id: 'hdfc', name: 'HDFC Bank', short: 'HDFC', color: 0),
      ];
    Account account(String name, {String type = 'bank', String? bankId}) =>
        Account(
          id: name,
          name: name,
          type: type,
          openingBalance: 0,
          bankId: bankId,
        );
    expect(ledger.bankFor(account('State Bank of India'))?.id, 'sbi');
    expect(ledger.bankFor(account('My SBI savings'))?.id, 'sbi');
    expect(ledger.bankFor(account('Indian Overseas Bank'))?.id, 'iob');
    expect(ledger.bankFor(account('hdfc salary'))?.id, 'hdfc');
    expect(ledger.bankFor(account('Wallet', type: 'cash')), isNull);
    expect(ledger.bankFor(account('Savings')), isNull);
    expect(
      ledger.bankFor(account('State Bank of India', bankId: 'hdfc'))?.id,
      'hdfc',
    );
  });

  testWidgets('edits and deletes an account', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final calls = <String>[];
    var accounts = [
      {
        'id': 'a1',
        'name': 'Salary account',
        'type': 'bank',
        'openingBalance': 150050,
        'bankId': 'sbi',
      },
    ];
    final ledger = Ledger(
      FinanceApi(
        token: 'test',
        baseUrl: 'http://api',
        client: MockClient((request) async {
          if (request.method != 'GET' &&
              request.url.path.startsWith('/accounts')) {
            calls.add('${request.method} ${request.url.path} ${request.body}');
          }
          if (request.url.path == '/banks') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'sbi',
                  'name': 'State Bank of India',
                  'short': 'SBI',
                  'color': '#22409A',
                },
                {
                  'id': 'hdfc',
                  'name': 'HDFC Bank',
                  'short': 'HDFC',
                  'color': '#004C8F',
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/accounts' && request.method == 'GET') {
            return http.Response(jsonEncode(accounts), 200);
          }
          if (request.method == 'PATCH') {
            return http.Response(jsonEncode(accounts.first), 200);
          }
          if (request.method == 'DELETE') {
            accounts = [];
            return http.Response('', 204);
          }
          if (request.url.path == '/summary') {
            return http.Response(
              jsonEncode({
                'month': '2026-10',
                'balance': 0,
                'monthIncome': 0,
                'monthExpense': 0,
                'categories': [],
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      ),
    );
    await ledger.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountsScreen(ledger: ledger)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary account'));
    await tester.pumpAndSettle();
    expect(find.text('Edit account'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1500.50'), findsOneWidget);
    await tester.tap(find.text('HDFC Bank'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(calls.single, contains('PATCH /accounts/a1'));
    expect(calls.single, contains('"bankId":"hdfc"'));
    expect(calls.single, contains('"name":"Salary account"'));

    await tester.tap(find.text('Salary account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('also deletes every transaction'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(calls.last, startsWith('DELETE /accounts/a1'));
    expect(find.text('Salary account'), findsNothing);
  });

  test('renews an expired token once and retries the request', () async {
    final seen = <String>[];
    final api = FinanceApi(
      token: 'old',
      baseUrl: 'http://api',
      onTokenRejected: () async => 'new',
      client: MockClient((request) async {
        seen.add(request.headers['authorization']!);
        if (request.headers['authorization'] == 'Bearer old') {
          return http.Response('{"message":"Unauthorized"}', 401);
        }
        return http.Response('[]', 200);
      }),
    );
    expect(await api.accounts(), isEmpty);
    expect(seen, ['Bearer old', 'Bearer new']);
  });

  test('reads scheduled and recurring results from the agent', () async {
    final api = FinanceApi(
      token: 'test',
      baseUrl: 'http://api',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'schedule': {
                'id': 's1',
                'categoryName': 'Salary',
                'amount': 4500000,
                'kind': 'income',
                'note': 'monthly salary',
                'repeat': 'monthly',
                'dayOfMonth': 3,
                'nextOn': '2026-11-03',
              },
              'parsed': {'amount': 4500000},
            },
          ]),
          200,
        ),
      ),
    );
    final [result] = await api.parseTransactions(
      text: 'all month I get salary 45000 on 3rd',
      accountId: 'a1',
      today: '2026-10-18',
    );
    expect(result.transaction, isNull);
    expect(
      scheduleMessage(result.schedule!),
      'every month on the 3rd: get ₹45,000 for monthly salary',
    );
    expect(looksScheduled('all month I get salary 45000 on 3rd'), isTrue);
    expect(looksScheduled('next month 6th I will get 5000 from Ravi'), isTrue);
    expect(looksScheduled('എല്ലാ മാസവും 5-ന് വാടക 12000'), isTrue);
    expect(looksScheduled('got 500 from Ravi yesterday'), isFalse);
    expect(looksScheduled('450 pizza with friends'), isFalse);
  });

  test('bill preview posts the photo and reads the payable amount', () async {
    late Map<String, dynamic> sent;
    final api = FinanceApi(
      token: 'test',
      baseUrl: 'http://api',
      client: MockClient((request) async {
        expect(request.url.path, '/transactions/parse');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode([
            {
              'parsed': {
                'amount': 84200,
                'currency': 'INR',
                'merchant': 'Cafe Madras',
                'occurredOn': '2026-10-18',
                'categoryId': 'c1',
                'categoryName': 'Food',
                'rawDescription': 'dinner bill',
                'note': 'Cafe Madras — dinner bill',
                'kind': 'expense',
              },
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final drafts = await api.previewBill(
      imageBase64: 'aaaa',
      mimeType: 'image/jpeg',
      accountId: 'a1',
      today: '2026-10-18',
      text: 'dinner',
    );
    expect(sent['image'], 'aaaa');
    expect(sent['mimeType'], 'image/jpeg');
    expect(sent['preview'], isTrue);
    expect(sent['text'], 'dinner');
    expect(drafts.single.amount, 84200);
    expect(drafts.single.note, 'Cafe Madras — dinner bill');
  });

  test(
    'agent cold start is marked unavailable so the phone can fall back',
    () async {
      final api = FinanceApi(
        token: 'test',
        baseUrl: 'http://api',
        client: MockClient((_) async {
          return http.Response(jsonEncode({'message': 'warming up'}), 503);
        }),
      );
      await expectLater(
        api.parseTransactions(
          text: '10 tea',
          accountId: 'a1',
          today: '2026-10-18',
        ),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.unavailable,
            'unavailable',
            true,
          ),
        ),
      );
    },
  );

  testWidgets('thinking orb animates and stops cleanly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: ThinkingOrb())),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel('Thinking'), findsOneWidget);
    expect(tester.getSize(find.byType(ThinkingOrb)), const Size(64, 64));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('people section shows who owes whom and records a loan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final posted = <Map<String, dynamic>>[];
    final ledger = Ledger(
      FinanceApi(
        token: 'test',
        baseUrl: 'http://api',
        client: MockClient((request) async {
          if (request.url.path == '/debts' && request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            posted.add(body);
            return http.Response(
              jsonEncode({
                'id': 'd9',
                ...body,
                'accountId': body['accountId'],
                'accountName': 'Cash',
              }),
              201,
            );
          }
          if (request.url.path == '/debts') {
            return http.Response(
              jsonEncode({
                'people': [
                  {
                    'name': 'Ravi',
                    'balance': 30000,
                    'lastOn': '2026-10-05',
                    'entries': 2,
                  },
                  {
                    'name': 'Arjun',
                    'balance': -100000,
                    'lastOn': '2026-10-02',
                    'entries': 1,
                  },
                ],
                'entries': [],
              }),
              200,
            );
          }
          if (request.url.path == '/accounts') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'a1',
                  'name': 'Cash',
                  'type': 'cash',
                  'openingBalance': 0,
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/summary') {
            return http.Response(
              jsonEncode({
                'balance': 0,
                'monthIncome': 0,
                'monthExpense': 0,
                'categories': [],
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      ),
    );
    await ledger.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountsScreen(ledger: ledger)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('owes you ₹300'), findsOneWidget);
    expect(find.text('you owe ₹1,000'), findsOneWidget);
    expect(find.text('₹300'), findsOneWidget);

    await tester.tap(find.text('Lend or borrow'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Friend\'s name'),
      'Anu',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '250');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(posted.single['person'], 'Anu');
    expect(posted.single['type'], 'lent');
    expect(posted.single['amount'], 25000);
    expect(posted.single['accountId'], 'a1');
  });

  test('reads categories with icons and lending results from the API', () {
    final category = Category.fromJson({
      'id': 'c1',
      'name': 'Gym',
      'kind': 'expense',
      'icon': 'health',
      'iconUrl': 'https://res.cloudinary.com/x/health',
      'custom': true,
    });
    expect([category.icon, category.custom], ['health', true]);
    final result = AgentResult.fromJson({
      'debt': {
        'id': 'd1',
        'person': 'Ravi',
        'type': 'got_back',
        'amount': 50000,
        'occurredOn': '2026-10-18',
      },
      'parsed': {},
    });
    expect(result.debt?.moneyIn, isTrue);
    expect(result.transaction, isNull);
    const debts = Debts(
      people: [
        Person(name: 'Ravi', balance: 30000, lastOn: '2026-10-05'),
        Person(name: 'Arjun', balance: -100000, lastOn: '2026-10-02'),
      ],
    );
    expect([debts.owedToYou, debts.youOwe], [30000, 100000]);
  });

  testWidgets('home goals strip shows progress and creates a goal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final posted = <Map<String, dynamic>>[];
    var goals = <Map<String, dynamic>>[
      {
        'id': 'g1',
        'name': 'Goa trip',
        'icon': 'travel',
        'targetAmount': 2000000,
        'targetDate': null,
        'saved': 500000,
      },
    ];
    final ledger = Ledger(
      FinanceApi(
        token: 'test',
        baseUrl: 'http://api',
        client: MockClient((request) async {
          if (request.url.path == '/goals' && request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            posted.add(body);
            final created = {'id': 'g2', ...body, 'saved': 0};
            goals = [...goals, created];
            return http.Response(jsonEncode(created), 201);
          }
          if (request.url.path == '/goals') {
            return http.Response(jsonEncode(goals), 200);
          }
          if (request.url.path == '/summary') {
            return http.Response(
              jsonEncode({
                'balance': 0,
                'monthIncome': 0,
                'monthExpense': 0,
                'categories': [],
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      ),
    );
    await ledger.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: ledger,
            builder: (context, _) => GoalsStrip(ledger: ledger),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Goa trip'), findsOneWidget);
    expect(find.text('₹5K of ₹20K'), findsOneWidget);
    expect(find.text('₹5,000 saved'), findsOneWidget);

    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Saving for? e.g. Goa trip'),
      'New phone',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Target amount'),
      '30000',
    );
    await tester.tap(find.bySemanticsLabel('goal-phone'));
    await tester.tap(find.text('Create goal'));
    await tester.pumpAndSettle();
    expect(posted.single, {
      'name': 'New phone',
      'icon': 'goal-phone',
      'targetAmount': 3000000,
      'targetDate': null,
    });
    expect(find.text('New phone'), findsOneWidget);
  });

  test('goal progress, monthly saving and agent goal results', () {
    const goal = Goal(
      id: 'g1',
      name: 'Goa trip',
      targetAmount: 2000000,
      saved: 500000,
      targetDate: '2026-12-31',
    );
    expect(goal.progress, 0.25);
    expect(goal.left, 1500000);
    expect(goal.monthlyNeeded(DateTime(2026, 10, 18)), 500000);
    final result = AgentResult.fromJson({
      'goal': {
        'id': 'g1',
        'name': 'Goa trip',
        'targetAmount': 2000000,
        'saved': 650000,
      },
      'goalEntry': {
        'id': 'e1',
        'goalId': 'g1',
        'amount': 150000,
        'occurredOn': '2026-10-18',
      },
      'parsed': {},
    });
    expect(
      goalMessage(result.goal!, result.goalEntry),
      'added ₹1,500 to Goa trip · ₹6,500 of ₹20,000',
    );
    expect(mentionsGoal('add 500 to goa trip', [goal]), isTrue);
    expect(mentionsGoal('goa trip hotel 3000', [goal]), isFalse);
  });

  test('spots questions, not spends', () {
    for (final question in [
      'how much did I spend on food this month',
      'who owes me',
      'petrol chilavu ethra last month',
      'show my swiggy orders',
      'did i spend more than last month?',
      'ഈ മാസം എത്ര ചെലവായി',
    ]) {
      expect(looksLikeQuestion(question), isTrue, reason: question);
    }
    for (final spend in [
      '150 food',
      'lent 500 to ravi',
      'got 35k salary',
      'my rent 12000',
    ]) {
      expect(looksLikeQuestion(spend), isFalse, reason: spend);
    }
  });

  testWidgets('answer sheet shows the answer, bars and items', (tester) async {
    final answer = AskAnswer.fromJson({
      'answer': 'You spent ₹600 on Food this month in 2 payments.',
      'chart': [
        {'label': '1 Oct', 'value': 45000},
        {'label': '2 Oct', 'value': 0},
        {'label': '3 Oct', 'value': 15000},
      ],
      'items': [
        {
          'label': 'Food',
          'value': 60000,
          'categoryName': 'Food',
          'kind': 'expense',
        },
      ],
      'plan': {'intent': 'spending'},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AskAnswerView(
            question: 'how much on food this month',
            answer: answer,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('You spent ₹600 on Food this month in 2 payments.'),
      findsOneWidget,
    );
    expect(find.text('Highest ₹450'), findsOneWidget);
    expect(find.text('1 Oct'), findsOneWidget);
    expect(find.text('₹600'), findsOneWidget);
  });

  test('home widget text hides amounts behind the app lock', () {
    final open = HomeScreenWidget.texts(
      balance: 100000,
      spentThisMonth: 91000,
      accounts: 2,
      hidden: false,
    );
    expect(open, (
      title: 'All accounts',
      balance: '₹1,000',
      spent: 'Spent ₹910 this month',
    ));
    final locked = HomeScreenWidget.texts(
      balance: 100000,
      spentThisMonth: 91000,
      accounts: 1,
      hidden: true,
    );
    expect(locked.balance, '₹ ••••');
    expect(locked.title, '1 account');
  });

  testWidgets('review sheet lets you fix, drop and then save entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ledger = Ledger(
      FinanceApi(
        token: 'test',
        baseUrl: 'http://api',
        client: MockClient((request) async {
          if (request.url.path == '/accounts') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'a1',
                  'name': 'Cash',
                  'type': 'cash',
                  'openingBalance': 0,
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/categories') {
            return http.Response(
              jsonEncode([
                {'id': 'c1', 'name': 'Food', 'kind': 'expense'},
                {'id': 'c2', 'name': 'Other', 'kind': 'expense'},
                {'id': 'c3', 'name': 'Other income', 'kind': 'income'},
              ]),
              200,
            );
          }
          if (request.url.path == '/summary') {
            return http.Response(
              jsonEncode({
                'balance': 0,
                'monthIncome': 0,
                'monthExpense': 0,
                'categories': [],
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      ),
    );
    await ledger.refresh();
    List<ParsedSpend>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await reviewSpends(
                  context,
                  ledger: ledger,
                  sentence: 'lunch 200 and lent 500 to ravi',
                  defaultAccountId: 'a1',
                  drafts: const [
                    ParsedSpend(
                      amount: 20000,
                      kind: 'expense',
                      occurredOn: '2026-10-18',
                      categoryId: 'c1',
                      categoryName: 'Food',
                      note: 'lunch',
                    ),
                    ParsedSpend(
                      amount: 50000,
                      kind: 'expense',
                      occurredOn: '2026-10-18',
                      categoryId: 'c2',
                      categoryName: 'Other',
                      note: 'loan to ravi',
                      debt: SpendDebt(type: 'lent', person: 'Ravi'),
                    ),
                  ],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('I found 2 entries'), findsOneWidget);
    expect(find.text('Lent to Ravi'), findsOneWidget);
    expect(find.text('Save all 2'), findsOneWidget);

    await tester.tap(find.text('Spent'));
    await tester.pumpAndSettle();
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Other income'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, hasLength(1));
    final saved = result!.single;
    expect(saved.toCommitJson(), {
      'amount': 20000,
      'kind': 'income',
      'categoryId': 'c3',
      'occurredOn': '2026-10-18',
      'note': 'lunch',
      'accountId': 'a1',
    });
  });

  test('a reviewed loan and schedule keep their details when sent', () {
    final draft = ParsedSpend.fromJson({
      'amount': 3500000,
      'kind': 'income',
      'occurredOn': '2026-11-01',
      'categoryId': 'c9',
      'categoryName': 'Salary',
      'note': 'monthly salary',
      'schedule': {
        'repeat': 'monthly',
        'dayOfMonth': 1,
        'nextOn': '2026-11-01',
      },
    });
    expect(reviewBadge(draft), 'Every month on the 1st');
    expect(draft.toCommitJson()['schedule'], {
      'repeat': 'monthly',
      'dayOfMonth': 1,
      'nextOn': '2026-11-01',
    });
    final goal = draft.copyWith(amount: 50000);
    expect(goal.schedule?.monthly, isTrue);
  });

  test('timed plans remind on the minute and say the time', () {
    final schedule = Schedule.fromJson({
      'id': 's1',
      'categoryName': 'Other',
      'amount': 50000,
      'kind': 'expense',
      'note': 'send money to ravi',
      'repeat': 'once',
      'dayOfMonth': 18,
      'nextOn': isoDate(DateTime.now()),
      'atTime': '18:00',
      'accountName': 'HDFC',
    });
    final now = DateTime.now();
    final morning = DateTime(now.year, now.month, now.day, 9);
    final reminders = remindersFor(schedule, morning);
    expect(reminders, hasLength(1));
    expect(reminders.single.at, DateTime(now.year, now.month, now.day, 18));
    expect(reminders.single.exact, isTrue);
    expect(reminders.single.title, 'Time to pay ₹500');
    expect(reminders.single.body, 'send money to ravi · HDFC');
    expect(
      remindersFor(schedule, DateTime(now.year, now.month, now.day, 19)),
      isEmpty,
    );
    expect(
      scheduleMessage(schedule, accountName: 'HDFC'),
      'scheduled: pay ₹500 for send money to ravi from HDFC today at 6:00 PM',
    );
    expect(formatClock('09:05'), '9:05 AM');
    expect(formatClock('00:30'), '12:30 AM');
    expect(clockTime(DateTime(2026, 10, 18, 7, 4)), '07:04');
    expect(looksScheduled('send 500 to ravi at 6pm'), isTrue);
    expect(looksScheduled('500 lunch'), isFalse);
  });

  testWidgets('budgets card shows progress, warnings and colours', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ledger = Ledger(
      FinanceApi(
        token: 'test',
        baseUrl: 'http://api',
        client: MockClient((request) async {
          if (request.url.path == '/budgets') {
            return http.Response(
              jsonEncode([
                {
                  'id': 'b1',
                  'categoryId': 'c1',
                  'categoryName': 'Food',
                  'month': '2026-10',
                  'limitAmount': 600000,
                  'spent': 510000,
                },
                {
                  'id': 'b2',
                  'categoryId': 'c2',
                  'categoryName': 'Shopping',
                  'month': '2026-10',
                  'limitAmount': 300000,
                  'spent': 350000,
                },
                {
                  'id': 'b3',
                  'categoryId': 'c3',
                  'categoryName': 'Fuel',
                  'month': '2026-10',
                  'limitAmount': 200000,
                  'spent': 50000,
                },
              ]),
              200,
            );
          }
          if (request.url.path == '/summary') {
            return http.Response(
              jsonEncode({
                'balance': 0,
                'monthIncome': 0,
                'monthExpense': 0,
                'categories': [],
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      ),
    );
    await ledger.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BudgetsCard(ledger: ledger)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('₹1,900 left'), findsOneWidget);
    expect(find.text('Over by ₹500'), findsOneWidget);
    expect(find.text('₹900 left'), findsOneWidget);
    expect(find.text('₹1,500 left'), findsOneWidget);
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => const ['Food', 'Shopping', 'Fuel'].contains(text))
        .toList();
    expect(names, ['Shopping', 'Food', 'Fuel']);
    expect(budgetWarnings(ledger, ['Food', 'Shopping', 'Fuel', 'Rent']), [
      'Food budget: 85% used',
      'Shopping budget: over by ₹500',
    ]);
  });

  testWidgets('home shows spending and the next payment side by side', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 18, 15);
    final rent = Schedule.fromJson({
      'id': 's1',
      'categoryName': 'Rent',
      'amount': 1200000,
      'kind': 'expense',
      'note': 'house rent',
      'repeat': 'monthly',
      'dayOfMonth': 18,
      'nextOn': '2026-10-18',
      'atTime': '18:00',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeView(
            summary: const Summary(
              balance: 100000,
              monthIncome: 0,
              monthExpense: 91000,
              categories: [],
            ),
            recent: const [],
            onReceive: () {},
            onSend: () {},
            onRefresh: () async {},
            now: now,
            nextPayment: rent,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('₹910'), findsOneWidget);
    expect(find.text('Next payment'), findsOneWidget);
    expect(find.text('Today · 6:00 PM'), findsOneWidget);
    expect(find.text('₹12,000'), findsOneWidget);
    expect(find.text('house rent'), findsOneWidget);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Spending'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width,
      lessThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      ),
    );
    final later = Schedule.fromJson({
      'id': 's2',
      'categoryName': 'Bills',
      'amount': 90000,
      'kind': 'expense',
      'repeat': 'once',
      'dayOfMonth': 30,
      'nextOn': '2026-10-30',
    });
    expect(nextPaymentWhen(later, now), '30 Oct');
    expect(
      nextPaymentWhen(
        Schedule.fromJson({
          ...{
            'id': 's3',
            'categoryName': 'Bills',
            'amount': 1,
            'kind': 'expense',
            'repeat': 'once',
            'dayOfMonth': 19,
            'nextOn': '2026-10-19',
          },
        }),
        now,
      ),
      'Tomorrow',
    );
  });

  test('budget alerts fire once at 80% and once when over', () {
    const food = Budget(
      id: 'b1',
      categoryId: 'c1',
      categoryName: 'Food',
      month: '2026-10',
      limitAmount: 600000,
      spent: 510000,
    );
    const shopping = Budget(
      id: 'b2',
      categoryId: 'c2',
      categoryName: 'Shopping',
      month: '2026-10',
      limitAmount: 300000,
      spent: 350000,
    );
    const fuel = Budget(
      id: 'b3',
      categoryId: 'c3',
      categoryName: 'Fuel',
      month: '2026-10',
      limitAmount: 200000,
      spent: 50000,
    );
    final fresh = Notifier.newBudgetAlerts([food, shopping, fuel], {});
    expect(
      [for (final alert in fresh) '${alert.budget.categoryName}:${alert.over}'],
      ['Food:false', 'Shopping:true'],
    );
    expect(
      Notifier.newBudgetAlerts([food, shopping], {'2026-10:c1:80', '2026-10:c2:100'}),
      isEmpty,
    );
    final payment = BankSms(
      id: 'sms-1',
      sender: 'AX-HDFCBK-S',
      body: 'Rs 500 debited',
      date: DateTime(2026, 10, 18),
      amount: 50000,
      kind: 'expense',
    );
    expect(Notifier.paymentTitle(payment), '₹500 debited · HDFCBK');
  });

  test('with server push the phone keeps only timed reminders', () {
    final now = DateTime.now();
    Schedule plan(String? atTime) => Schedule.fromJson({
      'id': 's1',
      'categoryName': 'Rent',
      'amount': 1200000,
      'kind': 'expense',
      'repeat': 'once',
      'dayOfMonth': now.day,
      'nextOn': isoDate(now.add(const Duration(days: 2))),
      'atTime': atTime,
    });
    expect(remindersFor(plan(null), now), isNotEmpty);
    expect(remindersFor(plan(null), now, serverPush: true), isEmpty);
    expect(remindersFor(plan('18:00'), now, serverPush: true), hasLength(1));
  });

  testWidgets('feature tour walks through every step, then finishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => done++)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to zyvault'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    for (var step = 1; step < onboardingSteps.length; step++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(onboardingSteps[step].title), findsOneWidget);
    }
    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('skip leaves the tour at once', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () => done++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    expect(done, 1);
  });

  test('formats and parses money in minor units', () {
    expect(formatMoney(150050), '1,500.50');
    expect(formatMoney(-50), '-0.50');
    expect(parseMoney('12.5'), 1250);
    expect(parseMoney('1,500.50'), isNull);
    expect(parseMoney('12.50'.replaceAll(',', '')), 1250);
    expect(parseOpeningBalance('0'), 0);
    expect(parseOpeningBalance('-10.25'), -1025);
    expect(formatCompact(860000), '₹8.6K');
    expect(formatCompact(0), '₹0');
    expect(formatRupees(211400), '₹2,114');
    final spend = parseSpendLine('150 food');
    expect(spend?.amount, 15000);
    expect(spend?.reason, 'food');
    expect(spendMessage(spend!), 'spend ₹150 for food');
    expect(spend.categoryName, 'Food');
    expect(parseSpendLine('200 uber')?.categoryName, 'Transport');
    expect(parseSpendLine('5000 house rent')?.categoryName, 'Rent');
    expect(parseSpendLine('199 electricity')?.categoryName, 'Bills');
    expect(parseSpendLine('999 amazon shoes')?.categoryName, 'Shopping');
    expect(parseSpendLine('50 something else')?.categoryName, 'Other');
    expect(parseSpendLine('₹1,500.50 groceries')?.amount, 150050);
    expect(parseSpendLine('150 for dinner')?.reason, 'dinner');
    final many = parseSpendLines('150 food and 80 petrol');
    expect(many.map((line) => line.categoryName).toList(), ['Food', 'Fuel']);
    const oldDefaults = [
      Category(id: 'c1', name: 'Food', kind: 'expense'),
      Category(id: 'c2', name: 'Transport', kind: 'expense'),
      Category(id: 'c3', name: 'Other', kind: 'expense'),
      Category(id: 'c4', name: 'Gym', kind: 'expense', custom: true),
      Category(id: 'c5', name: 'Other income', kind: 'income'),
    ];
    expect(categoryFor(many[1], oldDefaults)?.name, 'Transport');
    expect(categoryFor(parseSpendLine('40 chai')!, oldDefaults)?.name, 'Food');
    expect(
      categoryFor(parseSpendLine('1500 gym fees')!, oldDefaults)?.name,
      'Gym',
    );
    final gift = parseSpendLine('got 2000 gift from uncle')!;
    expect([gift.kind, gift.categoryName], ['income', 'Gift received']);
    expect(parseSpendLine('300 blinkit')?.categoryName, 'Groceries');
    expect(parseSpendLine('649 netflix')?.categoryName, 'Subscriptions');
    expect(looksLikeLoan('lent 500 to ravi'), isTrue);
    expect(looksLikeLoan('ravi-kku 500 kadam koduthu'), isTrue);
    expect(looksLikeLoan('500 lunch'), isFalse);
    expect(
      debtMessage(
        const DebtEntry(
          id: 'd1',
          person: 'Ravi',
          type: 'lent',
          amount: 50000,
          occurredOn: '2026-10-18',
        ),
        accountName: 'HDFC',
      ),
      'lent ₹500 to Ravi from HDFC',
    );
    expect(parseSpendLine('50000 salary')?.kind, 'income');
    final salary = parseSpendLine('35k got salary on the this month')!;
    expect(
      [salary.amount, salary.kind, salary.categoryName, salary.reason],
      [3500000, 'income', 'Salary', 'salary'],
    );
    final today = DateTime(2026, 10, 18, 9);
    final pizza = parseSpendLine(
      'Spent 450 rupees on pizza last night with friends',
      now: today,
    )!;
    expect(
      [pizza.amount, pizza.reason, pizza.categoryName, pizza.occurredOn],
      [45000, 'pizza with friends', 'Food', DateTime(2026, 10, 17)],
    );
    final sixth = parseSpendLine(
      'i got 35k this month salary on 6th this month',
      now: today,
    )!;
    expect(
      [sixth.amount, sixth.kind, sixth.categoryName, sixth.occurredOn],
      [3500000, 'income', 'Salary', DateTime(2026, 10, 6)],
    );
    expect(
      parseSpendLine('electricity 900 on 25th', now: today)?.occurredOn,
      DateTime(2026, 9, 25),
    );
    expect(
      parseSpendLine('rent 12000 on 1st oct', now: today)?.occurredOn,
      DateTime(2026, 10, 1),
    );
    expect(
      parseSpendLine('rent 12000 on 1st oct', now: today)?.amount,
      1200000,
    );
    expect(
      parseSpendLine('petrol 500 parso', now: today)?.occurredOn,
      DateTime(2026, 10, 16),
    );
    expect(
      parseSpendLine('food 200', now: today)?.occurredOn,
      DateTime(2026, 10, 18),
    );
    final biryani = parseSpendLine('ഇന്നലെ ബിരിയാണിക്ക് 340 രൂപ', now: today)!;
    expect(
      [biryani.amount, biryani.categoryName, biryani.occurredOn],
      [34000, 'Food', DateTime(2026, 10, 17)],
    );
    final shambalam = parseSpendLine(
      'ഈ മാസം 6-ന് 35000 ശമ്പളം കിട്ടി',
      now: today,
    )!;
    expect(
      [
        shambalam.amount,
        shambalam.kind,
        shambalam.categoryName,
        shambalam.occurredOn,
      ],
      [3500000, 'income', 'Salary', DateTime(2026, 10, 6)],
    );
    final auto = parseSpendLine('innale auto 80 rupa koduthu', now: today)!;
    expect(
      [auto.amount, auto.categoryName, auto.occurredOn],
      [8000, 'Transport', DateTime(2026, 10, 17)],
    );
    expect(parseSpendLine('rent 1.5 lakh')?.amount, 15000000);
    expect(parseSpendLine('got 500 refund')?.kind, 'income');
    expect(parseSpendLines('tea on 6th 20').single.amount, 2000);
    expect(parseSpendLine('150'), isNull);
    for (final quick in [
      '150 food',
      '35k salary',
      '₹200 uber ride',
      '1,500 rent',
      '99 shopping',
    ]) {
      expect(isQuickSpend(quick), isTrue, reason: quick);
    }
    expect(isQuickSpend('500 gym', categoryNames: ['Gym']), isTrue);
    for (final ai in [
      'Spent 450 rupees on pizza last night with friends',
      '150 something else',
      '150 food yesterday',
      'food 150',
      '150 food and 80 petrol',
      'i got 35k salary on 6th',
    ]) {
      expect(isQuickSpend(ai), isFalse, reason: ai);
    }
  });

  test('keeps activity totals on the phone', () async {
    SharedPreferences.setMockInitialValues({});
    const item = TransactionItem(
      id: '1',
      accountId: 'cash',
      accountName: 'Cash',
      categoryId: 'food',
      categoryName: 'Food',
      amount: 49950,
      kind: 'expense',
      occurredOn: '2026-10-17',
      note: null,
    );
    await ActivityCache().write('2026-10-01', '2026-11-01', const [item]);
    final stored = await ActivityCache().read('2026-10-01', '2026-11-01');
    expect(stored, isNotNull);
    expect(stored!.single.categoryName, 'Food');
    expect(stored.single.amount, 49950);
    expect(await ActivityCache().read('2026-09-01', '2026-10-01'), isNull);
  });

  test('history period follows the selected span', () {
    final today = DateTime(2026, 10, 17);
    final month = historyPeriod('month', DateTime(2026, 6, 15), now: today);
    expect(isoDate(month.start), '2026-06-01');
    expect(isoDate(month.end), '2026-07-01');
    expect(month.previousLabel, 'May');
    expect(month.label, 'June');
    expect(month.nextLabel, 'July');

    final week = historyPeriod('week', DateTime(2026, 10, 17), now: today);
    expect(isoDate(week.start), '2026-10-12');
    expect(isoDate(week.end), '2026-10-19');

    final quarter = historyPeriod(
      'quarter',
      DateTime(2026, 10, 17),
      now: today,
    );
    expect(isoDate(quarter.start), '2026-10-01');
    expect(isoDate(quarter.end), '2027-01-01');
    expect(quarter.label, 'Q4');
    expect(quarter.nextLabel, 'Q1 2027');
  });

  testWidgets('signs in with an email code', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    String? sentTo;
    String? verified;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onSendCode: (email) async {
            sentTo = email;
            return const CodeRequest(codeLength: 8, resendAfterSeconds: 30);
          },
          onVerify: (email, code) async => verified = '$email $code',
        ),
      ),
    );

    expect(find.text('Login Account'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or continue with'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' Me@Example.com ');
    await tester.ensureVisible(find.text('Send Code'));
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();

    expect(sentTo, 'me@example.com');
    expect(find.text('Enter Code'), findsOneWidget);
    expect(find.text('Resend code in 30s'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12345678');
    await tester.pumpAndSettle();
    expect(verified, 'me@example.com 12345678');
  });

  testWidgets('type page uses a large centered field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TypePage(ledger: Ledger(FinanceApi(token: 'test'))),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textAlign, TextAlign.center);
    expect(field.style?.fontSize, 40);
    expect(field.maxLines, 6);
    expect(find.bySemanticsLabel('Speak a spend'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final error = find.text('Type an amount, a space, then what it was for');
    expect(error, findsOneWidget);
    expect(tester.widget<Text>(error).textAlign, TextAlign.center);
    expect(
      tester.getBottomLeft(error).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    await tester.tap(
      find.bySemanticsLabel('Voice language English, tap for Malayalam'),
    );
    await tester.pump();
    expect(
      find.bySemanticsLabel('Voice language Malayalam, tap for English'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField),
      'jamzhznzmzhznznzjzjzjzj spent 450 rupees on pizza last night with friends',
    );
    await tester.pump();
    final long = tester.widget<TextField>(find.byType(TextField));
    expect(long.style?.fontSize, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the balance in the center of home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeView(
            summary: const Summary(
              balance: 150050,
              monthIncome: 200000,
              monthExpense: 49950,
              categories: [
                CategoryTotal(
                  categoryId: 'food',
                  name: 'Food',
                  kind: 'expense',
                  total: 49950,
                ),
              ],
            ),
            recent: const [
              TransactionItem(
                id: '1',
                accountId: 'cash',
                accountName: 'Cash',
                categoryId: 'food',
                categoryName: 'Food',
                amount: 49950,
                kind: 'expense',
                occurredOn: '2026-10-17',
                note: null,
              ),
            ],
            now: DateTime(2026, 10, 17),
            onReceive: () {},
            onSend: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('₹1,500.50'), findsOneWidget);
    expect(find.text('+ ₹1,500.50 this month'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Spent in October'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('₹499.50'), findsNWidgets(2));
    expect(find.text('Nothing planned'), findsOneWidget);
    expect(find.text('Income'), findsNothing);
    expect(find.text('Budgets'), findsNothing);
  });

  testWidgets('history card shows the category ring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpendingCard(
            kind: 'expense',
            span: 'month',
            previousLabel: 'May',
            currentLabel: 'June',
            nextLabel: 'July',
            slices: const [
              SpendingSlice(
                name: 'Food',
                amount: 310700,
                color: Color(0xFFF4A261),
              ),
              SpendingSlice(
                name: 'Home',
                amount: 211400,
                color: Color(0xFF7EC8E3),
              ),
            ],
            onKind: (_) {},
            onSpan: (_) {},
            onPrevious: () {},
            onNext: () {},
          ),
        ),
      ),
    );

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('₹3,107'), findsOneWidget);
    expect(find.text('June'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('₹5.2K'), findsOneWidget);
  });

  testWidgets('groups operations by day', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeView(
            summary: const Summary(
              balance: 150050,
              monthIncome: 12800,
              monthExpense: 1800,
              categories: [],
            ),
            recent: const [
              TransactionItem(
                id: '1',
                accountId: 'bank',
                accountName: 'Bank',
                categoryId: 'salary',
                categoryName: 'Salary',
                amount: 12800,
                kind: 'income',
                occurredOn: '2026-10-17',
                note: 'October pay',
              ),
              TransactionItem(
                id: '2',
                accountId: 'bank',
                accountName: 'Bank',
                categoryId: 'bills',
                categoryName: 'Bills',
                amount: 1800,
                kind: 'expense',
                occurredOn: '2026-10-16',
                note: null,
              ),
            ],
            now: DateTime(2026, 10, 17),
            onReceive: () {},
            onSend: () {},
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    expect(find.text('October pay'), findsOneWidget);
    expect(find.text('+₹128.00'), findsOneWidget);
    expect(find.text('₹18.00'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
  });

  testWidgets('bottom bar shows the selected item', (
    WidgetTester tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FinanceBottomBar(
            index: selected,
            onChanged: (index) => selected = index,
            onAdd: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Activity'), findsOneWidget);
    expect(find.bySemanticsLabel('Money'), findsOneWidget);
    expect(find.bySemanticsLabel('Scheduled'), findsOneWidget);
    expect(find.bySemanticsLabel('Add'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Money'));
    expect(selected, 2);
  });
}
