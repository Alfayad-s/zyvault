import * as XLSX from 'xlsx';
import { xlsxStatement } from './statement-sheet.js';
import { statementRows } from './statement.js';

const today = '2026-10-21';

describe('xlsxStatement', () => {
  it('reads an SBI workbook whose table starts below the account name', () => {
    const sheet = XLSX.utils.aoa_to_sheet([
      ['Account Name', 'Mr. Al Fayad S'],
      [],
      ['Txn Date', 'Value Date', 'Description', 'Ref No./Cheque No.', 'Debit', 'Credit', 'Balance'],
      ['05/09/2026', '05/09/2026', 'WDL TFR UPI/DR/6248052733057/Jar Gold/YESB/JARGOLDONL/Subs', '', 15, '', 99.5],
      ['05/09/2026', '05/09/2026', 'DEP TFR IMPS/624818905736/BOB-XX/CODETEAK/Salaryfro', '', '', 35000, 35099.5],
      [new Date(2026, 8, 6), '06/09/2026', 'WDL TFR UPI/DR/1/MUHAMMED/FDRL/rizwanibin/Paid', '', 7000, '', 28070.5],
    ]);
    const book = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(book, sheet, 'Statement');
    const file = XLSX.write(book, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
    const rows = statementRows(xlsxStatement(new Uint8Array(file)), today);
    expect(rows.map((row) => [row.occurredOn, row.note, row.amount, row.kind])).toEqual([
      ['2026-09-05', 'Jar Gold', 1500, 'expense'],
      ['2026-09-05', 'CODETEAK salary', 3500000, 'income'],
      ['2026-09-06', 'MUHAMMED', 700000, 'expense'],
    ]);
  });
});
