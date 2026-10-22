import { needsPassword } from './statement-file.js';
import { applyCategories, prepareRows, rowsFromSbiLayout, statementRows, tableRows, type TextPiece } from './statement.js';

const today = '2026-10-21';
const categories = [
  { name: 'Food', kind: 'expense' as const },
  { name: 'Groceries', kind: 'expense' as const },
  { name: 'Salary', kind: 'income' as const },
  { name: 'Gifts', kind: 'expense' as const },
  { name: 'Other', kind: 'expense' as const },
  { name: 'Other income', kind: 'income' as const },
];

describe('statementRows', () => {
  it('reads debit and credit columns and skips the opening balance', () => {
    const rows = statementRows(
      [
        'Date,Narration,Debit,Credit,Balance',
        '01/04/2026,UPI SWIGGY,250.00,,12000.00',
        '02/04/2026,NEFT SALARY,,50000.00,62000.00',
        '03/04/2026,OPENING BALANCE,,,10000.00',
      ].join('\n'),
      today,
    );
    expect(rows).toEqual([
      { occurredOn: '2026-04-01', note: 'UPI SWIGGY', amount: 25000, kind: 'expense' },
      { occurredOn: '2026-04-02', note: 'NEFT SALARY', amount: 5000000, kind: 'income' },
    ]);
  });

  it('reads a printed statement and keeps the transaction amount, not the balance', () => {
    const rows = statementRows(
      ['01/04/2026 UPI/SWIGGY 250.00 12000.00', '02 Apr 2026 ATM WDL 2,000.00 10000.00', '03/04/2026 NEFT SALARY CREDIT 50,000.00'].join(
        '\n',
      ),
      today,
    );
    expect(rows.map((row) => [row.occurredOn, row.amount, row.kind])).toEqual([
      ['2026-04-01', 25000, 'expense'],
      ['2026-04-02', 200000, 'expense'],
      ['2026-04-03', 5000000, 'income'],
    ]);
    expect(rows[0]?.note).toContain('SWIGGY');
  });

  it('keeps SBI payments and drops the header, address, and the value date', () => {
    const rows = statementRows(
      [
        'As on 9 Sep 2026 Account Summary Welcome Mr. Al Fayad S 56.00',
        'Date of Statement 9 Sep 2026 Uncleared Amount Clear Balance 1,434.90',
        'MULLACKAL ALLEPPEY POST BOX NO. Y.M.C.A. RD 18 Mar 2024 276',
        'Statement From 1 Aug 2026 to 5 Sep 2026',
        '5 Sep 2026 5 Sep 2026 WDL TFR UPI DR Jar Gold YESB JARGOLDONL Subs AT MULLACKAL 250.00 1,184.90',
        '5 Sep 2026 5 Sep 2026 DEP TFR IMPS BOB CODETEAK Salaryfrom AT MULLACKAL 45,000.00 46,184.90',
      ].join('\n'),
      today,
    );
    expect(rows.map((row) => [row.occurredOn, row.amount, row.kind])).toEqual([
      ['2026-09-05', 25000, 'expense'],
      ['2026-09-05', 4500000, 'income'],
    ]);
    expect(rows[0]?.note).toContain('Jar Gold');
    expect(rows[1]?.note).toContain('Salaryfrom');
  });

  it('finds the payment table under the account details', () => {
    const rows = statementRows(
      [
        'Account Name\tMr. Al Fayad S',
        'Txn Date\tValue Date\tDescription\tRef No./Cheque No.\tDebit\tCredit\tBalance',
        '05/09/2026\t05/09/2026\tWDL TFR UPI/DR/6248052733057/Jar Gold/YESB/JARGOLDONL/Subs\t\t15\t\t99.50',
        '05/09/2026\t05/09/2026\tDEP TFR IMPS/624818905736/BOB-XX/CODETEAK/Salaryfro\t\t\t35000\t35070.50',
      ].join('\n'),
      today,
    );
    expect(rows.map((row) => [row.note, row.amount, row.kind])).toEqual([
      ['Jar Gold', 1500, 'expense'],
      ['CODETEAK salary', 3500000, 'income'],
    ]);
  });

  it('files a payment under the posting month when the value date is earlier', () => {
    const rows = statementRows(
      ['Txn Date,Value Date,Description,Debit,Credit', '21/10/2026,30/09/2026,UPI SWIGGY,250.00,'].join('\n'),
      today,
    );
    expect(rows).toEqual([{ occurredOn: '2026-10-21', note: 'UPI SWIGGY', amount: 25000, kind: 'expense' }]);
  });

  it('leaves a table alone when the first line is not a header', () => {
    expect(tableRows('01/04/2026 UPI 10.00', today)).toBeNull();
  });
});

describe('rowsFromSbiLayout', () => {
  const at = (str: string, x: number, y: number): TextPiece => ({ str, x, y });

  it('reads debit and credit columns and skips the summary page', () => {
    const summary: TextPiece[] = [
      at('Welcome:', 40, 700),
      at('Mr. Al Fayad S', 110, 700),
      at('Available Balance', 40, 640),
      at('1,434.90', 180, 640),
    ];
    const statement: TextPiece[] = [
      at('Clear Balance', 36, 560),
      at('1,434.90CR', 160, 560),
      at('Value Date', 36, 500),
      at('Post Date', 90, 500),
      at('Details', 150, 500),
      at('Ref No/Cheque No', 300, 500),
      at('Debit', 400, 500),
      at('Credit', 470, 500),
      at('Balance', 530, 500),
      at('05/09/2026', 36, 470),
      at('05/09/2026', 90, 470),
      at('WDL TFR', 150, 470),
      at('UPI/DR/6248052733057/Jar Gold/YESB/JARGOLDONL/Subs', 190, 470),
      at('-', 320, 470),
      at('15.00', 415, 470),
      at('-', 485, 470),
      at('99.50', 545, 470),
      at('0097695162591 AT 03106', 150, 458),
      at('MULLACKAL', 150, 446),
      at('05/09/2026', 36, 420),
      at('05/09/2026', 90, 420),
      at('DEP TFR', 150, 420),
      at('IMPS/624818905736/BOB-XX/CODETEAK/Salaryfro', 190, 420),
      at('-', 320, 420),
      at('-', 415, 420),
      at('35,000.00', 455, 420),
      at('35,070.50', 520, 420),
      at('05/09/2026', 36, 390),
      at('05/09/2026', 90, 390),
      at('WDL TFR', 150, 390),
      at('UPI/DR/624827480248/MUHAMMED/FDRL/rizwanibin/Paid', 190, 390),
      at('-', 320, 390),
      at('7,000.00', 400, 390),
      at('-', 485, 390),
      at('28,070.50', 520, 390),
      at('Page no. 1', 250, 40),
    ];
    const rows = rowsFromSbiLayout([summary, statement], today);
    expect(rows?.map((row) => [row.occurredOn, row.note, row.amount, row.kind])).toEqual([
      ['2026-09-05', 'Jar Gold', 1500, 'expense'],
      ['2026-09-05', 'CODETEAK salary', 3500000, 'income'],
      ['2026-09-05', 'MUHAMMED', 700000, 'expense'],
    ]);
    expect(prepareRows(rows ?? [], categories, []).ready[1]).toMatchObject({ categoryName: 'Salary', uncertain: false });
  });

  it('leaves other statement layouts alone', () => {
    expect(rowsFromSbiLayout([[{ str: '01/04/2026 UPI SWIGGY 250.00', x: 10, y: 10 }]], today)).toBeNull();
  });
});

describe('needsPassword', () => {
  it('recognises a locked PDF and a wrong password', () => {
    expect(needsPassword({ name: 'PasswordException', code: 1, message: 'No password given' })).toBe(true);
    expect(needsPassword({ name: 'PasswordException', code: 2, message: 'Incorrect Password' })).toBe(true);
    expect(needsPassword(new Error('bad file'))).toBe(false);
  });
});

describe('prepareRows', () => {
  it('uses a keyword, then a past note, and flags the rest', () => {
    const rows = statementRows(
      ['01/04/2026 SWIGGY 200.00', '02/04/2026 RAHUL TRANSFER 100.00', '03/04/2026 UNKNOWN SHOP 40.00'].join('\n'),
      today,
    );
    const { ready, unknown } = prepareRows(rows, categories, [
      { note: 'rahul transfer', categoryName: 'Gifts', kind: 'expense' },
    ]);
    expect(ready.map((row) => [row.categoryName, row.uncertain])).toEqual([
      ['Food', false],
      ['Gifts', false],
      ['Other', true],
    ]);
    expect(unknown).toEqual(['UNKNOWN SHOP']);
    const filled = applyCategories(ready, new Map([['unknown shop', 'Groceries']]), categories);
    expect(filled[2]).toMatchObject({ categoryName: 'Groceries', uncertain: false });
  });
});
