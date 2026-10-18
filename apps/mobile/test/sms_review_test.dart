import 'dart:convert';

import 'package:finance_track/api/finance_api.dart';
import 'package:finance_track/ledger.dart';
import 'package:finance_track/models.dart';
import 'package:finance_track/reminders.dart';
import 'package:finance_track/sms/bank_sms.dart';
import 'package:finance_track/sms/sms_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Schedule schedule({
  required String kind,
  required String nextOn,
  String repeat = 'monthly',
  int day = 5,
}) => Schedule(
  id: 's',
  categoryName: kind == 'income' ? 'Salary' : 'Rent',
  amount: 1200000,
  kind: kind,
  note: kind == 'income' ? 'monthly salary' : 'house rent',
  repeat: repeat,
  dayOfMonth: day,
  nextOn: nextOn,
);

void main() {
  test(
    'bills remind the day before, income on the day, three months ahead',
    () {
      final now = DateTime(2026, 10, 18, 12);
      final rent = remindersFor(
        schedule(kind: 'expense', nextOn: '2026-11-05'),
        now,
      );
      expect(rent.map((item) => item.at).toList(), [
        DateTime(2026, 11, 4, 9),
        DateTime(2026, 12, 4, 9),
        DateTime(2027, 1, 4, 9),
      ]);
      expect(rent.first.title, 'Due tomorrow: ₹12,000');
      expect(rent.first.body, 'house rent');

      final salary = remindersFor(
        schedule(kind: 'income', nextOn: '2026-10-31', day: 31),
        now,
      );
      expect(salary.map((item) => item.at).toList(), [
        DateTime(2026, 10, 31, 9),
        DateTime(2026, 11, 30, 9),
        DateTime(2026, 12, 31, 9),
      ]);
      expect(salary.first.title, 'Expected today: ₹12,000');

      final tomorrow = remindersFor(
        schedule(
          kind: 'expense',
          nextOn: '2026-10-19',
          repeat: 'once',
          day: 19,
        ),
        now,
      );
      expect(tomorrow.single.at, DateTime(2026, 10, 19, 9));
      expect(tomorrow.single.title, 'Due today: ₹12,000');
    },
  );

  testWidgets('asks about a bank SMS and saves it to the matched account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final ledger =
        Ledger(
            FinanceApi(
              token: 't',
              baseUrl: 'http://api',
              client: MockClient((request) async {
                if (request.method == 'POST' &&
                    request.url.path == '/transactions') {
                  sent.add(jsonDecode(request.body) as Map<String, dynamic>);
                  return http.Response(
                    jsonEncode({
                      'id': 'x',
                      'accountId': 'hdfc',
                      'categoryId': 'food',
                      'amount': 45000,
                      'kind': 'expense',
                      'occurredOn': '2026-10-18',
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
            Account(
              id: 'hdfc',
              name: 'Salary',
              type: 'bank',
              openingBalance: 0,
              bankId: 'hdfc',
            ),
          ]
          ..banks = const [
            Bank(
              id: 'hdfc',
              name: 'HDFC Bank',
              short: 'HDFC',
              color: 0xFF004C8F,
            ),
          ]
          ..categories = const [
            Category(id: 'food', name: 'Food', kind: 'expense'),
            Category(id: 'other', name: 'Other', kind: 'expense'),
          ];
    final sms = parseBankSms(
      id: 'm1',
      sender: 'VM-HDFCBK',
      body: 'Sent Rs.450.00 From HDFC Bank A/C x1234 To SWIGGY On 18/10/26 Ref 628312345678',
      date: DateTime(2026, 10, 18),
    )!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: SmsReview(ledger: ledger, messages: [sms]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Where did you spend ₹450?'), findsOneWidget);
    expect(find.text('Bank SMS · 1 of 1'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Swiggy'), findsOneWidget);
    expect(find.text('Report spam'), findsOneWidget);
    expect(find.text('Not a transaction'), findsOneWidget);

    await tester.tap(find.text('Save spend'));
    await tester.pumpAndSettle();
    expect(sent.single['accountId'], 'hdfc');
    expect(sent.single['categoryId'], 'food');
    expect(sent.single['amount'], 45000);
    expect(sent.single['note'], 'Swiggy');
    final seen = (await SharedPreferences.getInstance()).getStringList(
      'sms_seen',
    );
    expect(seen, ['m1']);
  });

  testWidgets('report spam asks first and blocks the sender', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ledger = Ledger(FinanceApi(token: 't'))
      ..accounts = const [
        Account(id: 'cash', name: 'Cash', type: 'cash', openingBalance: 0),
      ]
      ..categories = const [
        Category(id: 'other', name: 'Other', kind: 'expense'),
      ];
    final sms = parseBankSms(
      id: 'm2',
      sender: 'VM-QUICKL',
      body: 'Rs.999 debited from your a/c for LOTTERY ENTRY',
      date: DateTime(2026, 10, 18),
    )!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                reviewBankSms(context, ledger: ledger, messages: [sms]),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report spam'));
    await tester.pumpAndSettle();
    expect(find.text('Report as spam?'), findsOneWidget);
    await tester.tap(find.text('Report spam').last);
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('sms_spam_senders'), ['QUICKL']);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Report as spam?'), findsNothing);
  });
}
