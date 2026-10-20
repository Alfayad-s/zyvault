import 'package:finance_track/sms/bank_sms.dart';
import 'package:flutter_test/flutter_test.dart';

BankSms? read(String sender, String body) => parseBankSms(
  id: '1',
  sender: sender,
  body: body,
  date: DateTime(2026, 10, 18),
);

void main() {
  test('reads UPI debits with merchant and balance ignored', () {
    final sms = read(
      'VM-HDFCBK',
      'Sent Rs.450.00 From HDFC Bank A/C x1234 To SWIGGY On 18/10/26 Ref 628312345678 Not You? Call 18002586161',
    )!;
    expect(
      [sms.amount, sms.kind, sms.bankId, sms.accountDigits, sms.merchant],
      [45000, 'expense', 'hdfc', '1234', 'Swiggy'],
    );
  });

  test('reads SBI debit with VPA and available balance', () {
    final sms = read(
      'AD-SBIINB',
      'Dear UPI user A/C X5678 debited by 250.0 on date 18Oct26 trf to zomato@hdfcbank Refno 123456789012. Avl Bal Rs.12,345.67 -SBI',
    )!;
    expect(sms.amount, 25000, reason: 'never the available balance');
    expect(sms.merchant, 'Zomato');
    final withRs = read(
      'AD-SBIINB',
      'Your A/C X5678 is debited by Rs.250.00 on 18Oct26 trf to VPA zomato@hdfcbank. Avl Bal Rs.12,345.67 -SBI',
    )!;
    expect(
      [
        withRs.amount,
        withRs.kind,
        withRs.bankId,
        withRs.accountDigits,
        withRs.merchant,
      ],
      [25000, 'expense', 'sbi', '5678', 'Zomato'],
    );
  });

  test('reads card spends and salary credits', () {
    final card = read(
      'JD-ICICIT',
      'INR 2,499.00 spent on ICICI Bank Card XX9012 on 18-Oct-26 at AMAZON PAY. Avl Lmt: INR 45,000.00',
    )!;
    expect(
      [card.amount, card.kind, card.bankId, card.accountDigits, card.merchant],
      [249900, 'expense', 'icici', '9012', 'Amazon Pay'],
    );
    final salary = read(
      'VK-FEDBNK',
      'Your A/c XX3456 is credited with Rs.52,000.00 on 01-10-2026 by NEFT from ACME PVT LTD. Bal Rs.60,120.00',
    )!;
    expect(
      [salary.amount, salary.kind, salary.bankId, salary.merchant],
      [5200000, 'income', 'federal', 'Acme Pvt Ltd'],
    );
  });

  test('reads ATM withdrawals and refunds', () {
    expect(
      read(
        'BZ-AXISBK',
        'Rs 2000 withdrawn from A/c no. XX7788 at ATM on 18-10-26. Avl bal Rs 9,000',
      )?.kind,
      'expense',
    );
    expect(
      read(
        'VM-KOTAKB',
        'Refund of Rs.399.00 credited to your Kotak Bank a/c xx4321 from MYNTRA',
      )?.kind,
      'income',
    );
  });

  test('ignores OTPs, offers, reminders, failures and personal numbers', () {
    expect(
      read(
        'VM-HDFCBK',
        'OTP for txn of Rs.450 at SWIGGY is 482913. Do not share.',
      ),
      isNull,
    );
    expect(
      read(
        'VM-SBIINB',
        'Rs.5,000 will be debited from your a/c for SIP on 20-10',
      ),
      isNull,
    );
    expect(
      read(
        'VM-ICICIB',
        'Get cashback of upto Rs.500 on your credit card! Offer valid',
      ),
      isNull,
    );
    expect(
      read(
        'VM-AXISBK',
        'Your payment of Rs.300 to SWIGGY has failed. Amount if debited will be refunded',
      ),
      isNull,
    );
    expect(read('+919876543210', 'Sent Rs.200 to you on GPay'), isNull);
    expect(
      read('VM-AIRTEL', 'Your recharge plan of Rs.299 expires tomorrow'),
      isNull,
    );
    expect(
      read('VM-HDFCBK', 'Your credit card bill of Rs.12,000 is due on 25-10'),
      isNull,
    );
    expect(
      read('VM-SBIINB', 'Your A/C X5678 balance is Rs.12,345.67 as on 18-10'),
      isNull,
    );
  });

  test('reads GPay, PhonePe and Paytm payment notifications', () {
    BankSms? app(String package, String title, String content) =>
        parseUpiNotification(
          packageName: package,
          title: title,
          content: content,
          date: DateTime(2026, 10, 18, 14),
        );
    final gpay = app(
      'com.google.android.apps.nbu.paisa.user',
      'Ravi Kumar paid you ₹500.00',
      'Tap to view details',
    )!;
    expect(
      [gpay.amount, gpay.kind, gpay.merchant, gpay.app],
      [50000, 'income', 'Ravi Kumar', 'GPay'],
    );
    final phonepe = app(
      'com.phonepe.app',
      'Received ₹1,200 from Anu',
      'Credited to your bank account',
    )!;
    expect(
      [phonepe.amount, phonepe.kind, phonepe.merchant],
      [120000, 'income', 'Anu'],
    );
    final paid = app(
      'net.one97.paytm',
      'Paid ₹450 to Swiggy',
      'Payment successful',
    )!;
    expect(
      [paid.amount, paid.kind, paid.merchant],
      [45000, 'expense', 'Swiggy'],
    );
    final split = app(
      'com.google.android.apps.nbu.paisa.user',
      '₹450 paid',
      'to Swiggy via UPI',
    )!;
    expect([split.amount, split.merchant], [45000, 'Swiggy']);
    final named = app(
      'com.phonepe.app',
      'You paid Swiggy ₹450',
      'Payment successful',
    )!;
    expect([named.amount, named.merchant], [45000, 'Swiggy']);
    expect(
      app(
        'com.google.android.apps.nbu.paisa.user',
        'Anu requested ₹300',
        'Pay now',
      ),
      isNull,
    );
    expect(
      app('com.phonepe.app', 'You won ₹25 cashback', 'Scratch card'),
      isNull,
    );
    expect(
      app('com.phonepe.app', 'Payment of ₹450 failed', 'Try again'),
      isNull,
    );
    expect(app('com.whatsapp', 'Ravi paid you ₹500', ''), isNull);
  });

  test('reads a bank notification even when the picture flag is missing', () {
    final sms = paymentFromNotification(
      packageName: 'com.sbi.lotusintouch',
      title: 'SBI',
      content:
          'Dear UPI user A/C X5678 debited by 250.0 on date 18Oct26 trf to zomato@hdfcbank Refno 123456789012. Avl Bal Rs.12,345.67 -SBI',
      date: DateTime(2026, 10, 18, 14),
    )!;
    expect([sms.amount, sms.kind, sms.bankId, sms.merchant], [
      25000,
      'expense',
      'sbi',
      'Zomato',
    ]);
    expect(
      paymentFromNotification(
        packageName: 'com.whatsapp',
        title: 'Anu',
        content: 'Sent Rs.200 to you',
        date: DateTime(2026, 10, 18),
      ),
      isNull,
    );
  });

  test('merges an SMS and a UPI notification for the same payment', () {
    final sms = parseBankSms(
      id: 's',
      sender: 'VM-HDFCBK',
      body: 'Rs.500.00 credited to your A/c XX1234 on 18-10-26 by UPI ref 123',
      date: DateTime(2026, 10, 18, 14, 2),
    )!;
    final gpay = parseUpiNotification(
      packageName: 'com.google.android.apps.nbu.paisa.user',
      title: 'Ravi paid you ₹500',
      content: '',
      date: DateTime(2026, 10, 18, 14),
    )!;
    final merged = mergeAlerts([sms], [gpay]);
    expect(merged.single.bankId, 'hdfc');
    expect(merged.single.merchant, 'Ravi');
  });

  test('maps sender codes to banks', () {
    expect(bankFromSender('VM-HDFCBK'), 'hdfc');
    expect(bankFromSender('AX-FEDBNK-S'), 'federal');
    expect(bankFromSender('SBIUPI'), 'sbi');
    expect(bankFromSender('VM-AMAZON'), isNull);
  });
}
