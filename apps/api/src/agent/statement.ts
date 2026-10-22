export const statementPageCap = 15;
/** One import can cover a busy three months of payments. */
export const statementRowCap = 1500;

export type StatementKind = 'income' | 'expense';

export type StatementRow = {
  occurredOn: string;
  note: string;
  amount: number;
  kind: StatementKind;
};

export type NamedCategory = { name: string; kind: StatementKind };

export type PreparedRow = StatementRow & { categoryName: string; uncertain: boolean };

const expenseWords: Record<string, string[]> = {
  Food: ['swiggy', 'zomato', 'pizza', 'biryani', 'restaurant', 'lunch', 'dinner', 'breakfast'],
  Groceries: ['grocery', 'groceries', 'bigbasket', 'blinkit', 'zepto', 'dmart', 'supermarket', 'kirana', 'milk'],
  'Chai & coffee': ['chai', 'coffee', 'starbucks', 'cafe', 'bakery'],
  Transport: ['uber', 'ola', 'rapido', 'metro', 'parking', 'toll', 'taxi'],
  Fuel: ['petrol', 'diesel', 'fuel', 'cng'],
  Travel: ['flight', 'makemytrip', 'goibibo', 'airbnb', 'oyo'],
  Rent: ['rent', 'hostel'],
  Home: ['plumber', 'electrician', 'furniture'],
  Bills: ['electricity', 'kseb', 'wifi', 'broadband', 'water bill', 'gas bill'],
  Recharge: ['recharge', 'jio', 'airtel', 'prepaid'],
  Subscriptions: ['netflix', 'spotify', 'hotstar', 'youtube premium'],
  Shopping: ['amazon', 'flipkart', 'myntra', 'meesho', 'ajio'],
  'Personal care': ['salon', 'haircut', 'barber'],
  Health: ['pharmacy', 'hospital', 'medicine', 'doctor'],
  Insurance: ['insurance', 'lic'],
  Education: ['school', 'tuition', 'college'],
  Entertainment: ['bookmyshow', 'cinema', 'movie'],
  Gifts: ['gift', 'donation'],
  EMI: ['emi', 'credit card'],
  Investments: ['zerodha', 'groww', 'mutual fund', 'sip'],
};

const incomeWords: Record<string, string[]> = {
  Salary: ['salary', 'paycheck', 'wages'],
  Interest: ['interest', 'dividend'],
  Refund: ['refund', 'cashback', 'reversal'],
  Freelance: ['freelance'],
  'Rental income': ['tenant'],
};

const broader: Record<string, string> = {
  Groceries: 'Food',
  'Chai & coffee': 'Food',
  Fuel: 'Transport',
  Travel: 'Transport',
  Recharge: 'Bills',
  Subscriptions: 'Bills',
  Insurance: 'Bills',
  EMI: 'Bills',
  Entertainment: 'Shopping',
  'Personal care': 'Shopping',
  Home: 'Shopping',
  Gifts: 'Shopping',
  Interest: 'Other income',
  Refund: 'Other income',
  Freelance: 'Other income',
  'Rental income': 'Other income',
};

const skipLine =
  /\b(opening balance|closing balance|brought forward|carried forward|page total|grand total|statement of account|available balance|account summary|date of statement|uncleared|clear balance|mod bal|statement from|post box|as on|welcome|customer id|account number|ifsc|nominee)\b/i;

const months: Record<string, number> = {
  jan: 1,
  feb: 2,
  mar: 3,
  apr: 4,
  may: 5,
  jun: 6,
  jul: 7,
  aug: 8,
  sep: 9,
  oct: 10,
  nov: 11,
  dec: 12,
};

/** Dated money rows from a CSV or the printed text of a statement. */
export function statementRows(text: string, today = new Date().toISOString().slice(0, 10)): StatementRow[] {
  const lines = text
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length === 0) return [];
  const table = tableRows(text, today);
  return table ?? rowsFromLines(lines, today);
}

export function rowKey(row: Pick<StatementRow, 'occurredOn' | 'kind' | 'amount' | 'note'>): string {
  return `${row.occurredOn}|${row.kind}|${row.amount}|${row.note.toLowerCase()}`;
}

export function prepareRows(
  rows: StatementRow[],
  categories: NamedCategory[],
  past: { note: string | null; categoryName: string; kind: StatementKind }[],
): { ready: PreparedRow[]; unknown: string[] } {
  const unknown: string[] = [];
  const ready = rows.map((row) => {
    const named = keywordCategory(row.note, row.kind) ?? pastCategory(row.note, row.kind, past);
    const resolved = resolveCategory(named, row.kind, categories);
    if (resolved.uncertain) unknown.push(row.note);
    return { ...row, categoryName: resolved.name, uncertain: resolved.uncertain };
  });
  return { ready, unknown: [...new Set(unknown)] };
}

export function applyCategories(
  rows: PreparedRow[],
  chosen: Map<string, string>,
  categories: NamedCategory[],
): PreparedRow[] {
  return rows.map((row) => {
    if (!row.uncertain) return row;
    const named = chosen.get(row.note.toLowerCase());
    if (!named) return row;
    const resolved = resolveCategory(named, row.kind, categories);
    return { ...row, categoryName: resolved.name, uncertain: resolved.uncertain };
  });
}

export function resolveCategory(
  name: string | null,
  kind: StatementKind,
  categories: NamedCategory[],
): { name: string; uncertain: boolean } {
  const same = categories.filter((category) => category.kind === kind);
  const match = (wanted: string | null | undefined) =>
    wanted ? same.find((category) => category.name.toLowerCase() === wanted.toLowerCase()) : undefined;
  const found = match(name) ?? match(name ? broader[name] : null);
  if (found && found.name !== 'Other' && found.name !== 'Other income') {
    return { name: found.name, uncertain: false };
  }
  const fallback = match(kind === 'income' ? 'Other income' : 'Other') ?? same[0];
  return { name: fallback?.name ?? (kind === 'income' ? 'Other income' : 'Other'), uncertain: true };
}

function keywordCategory(note: string, kind: StatementKind): string | null {
  const words = kind === 'income' ? incomeWords : expenseWords;
  const hay = note.toLowerCase();
  let best: { name: string; length: number } | null = null;
  for (const [name, list] of Object.entries(words)) {
    for (const word of list) {
      if (!hay.includes(word)) continue;
      if (!best || word.length > best.length) best = { name, length: word.length };
    }
  }
  return best?.name ?? null;
}

function pastCategory(
  note: string,
  kind: StatementKind,
  past: { note: string | null; categoryName: string; kind: StatementKind }[],
): string | null {
  const hay = note.toLowerCase();
  let best: { name: string; score: number } | null = null;
  for (const item of past) {
    if (item.kind !== kind) continue;
    const memory = item.note?.toLowerCase().trim() ?? '';
    if (memory.length < 4 || /^(other|other income)$/i.test(item.categoryName)) continue;
    if (hay.includes(memory) && (!best || memory.length > best.score)) {
      best = { name: item.categoryName, score: memory.length + 20 };
    }
  }
  return best?.name ?? null;
}

function rowsFromTable(
  lines: string[],
  header: { delimiter: string; date: number; value: number; note: number; debit: number; credit: number; amount: number; type: number },
  today: string,
): StatementRow[] {
  const rows: StatementRow[] = [];
  for (const line of lines.slice(1)) {
    const cells = splitRow(line, header.delimiter);
    const posted = dateFrom(cells[header.date] ?? '', today);
    const valued = header.value >= 0 ? dateFrom(cells[header.value] ?? '', today) : null;
    const dated = posted ?? valued;
    if (!dated) continue;
    const note = narrationNote(cells[header.note] ?? '');
    if (!note || skipLine.test(note)) continue;
    const debit = header.debit >= 0 ? rupees(cells[header.debit] ?? '') : null;
    const credit = header.credit >= 0 ? rupees(cells[header.credit] ?? '') : null;
    let amount = debit ?? credit;
    let kind: StatementKind = debit != null ? 'expense' : 'income';
    if (amount == null && header.amount >= 0) {
      amount = rupees(cells[header.amount] ?? '');
      kind = kindFrom(`${cells[header.type] ?? ''} ${note}`);
    }
    if (amount == null || amount <= 0) continue;
    rows.push({ occurredOn: dated.iso, note, amount, kind });
  }
  return rows;
}

function rowsFromLines(lines: string[], today: string): StatementRow[] {
  const merged: string[] = [];
  for (const line of lines) {
    if (skipLine.test(line)) continue;
    if (dateFrom(line, today) || merged.length === 0) merged.push(line);
    else merged[merged.length - 1] += ` ${line}`;
  }
  const rows: StatementRow[] = [];
  for (const line of merged) {
    if (skipLine.test(line)) continue;
    const dated = dateFrom(line, today);
    if (!dated) continue;
    const withoutDates = stripDates(line);
    const amounts = moneyWithPaise(withoutDates);
    const amount = amounts[0] ?? amountsIn(withoutDates).find((value) => value >= 1000);
    if (amount == null) continue;
    const note = clip(withoutDates.replace(/[₹]|(?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d{1,2})?/g, ' '));
    if (note.length < 2 || skipLine.test(note)) continue;
    rows.push({ occurredOn: dated.iso, note, amount, kind: kindFrom(withoutDates) });
  }
  return rows;
}

function kindFrom(text: string): StatementKind {
  if (/credit card/i.test(text)) return 'expense';
  if (/\b(wdl|withdraw|withdrawal|dr|debit|atm|pos)\b/i.test(text)) return 'expense';
  if (/\b(dep|cr|credit|credited|deposit|refund|cashback|interest|dividend|reversal)\b/i.test(text) || /salary/i.test(text)) {
    return 'income';
  }
  return 'expense';
}

/** Txn date and value date both sit on an SBI line. The leftover day was being saved as the amount. */
function stripDates(text: string): string {
  return text
    .replace(/\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b/g, ' ')
    .replace(/\b\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*(?:\s+\d{2,4})?\b/gi, ' ');
}

function moneyWithPaise(line: string): number[] {
  const found: number[] = [];
  for (const match of line.matchAll(/(?<![\d.])(\d{1,3}(?:,\d{2,3})+|\d{1,8})\.(\d{2})(?!\d)/g)) {
    const amount = rupees(match[0] ?? '');
    if (amount != null && amount > 0 && amount < 100_000_000_00) found.push(amount);
  }
  return found;
}

function headerIndexes(cells: string[]): {
  delimiter: string;
  date: number;
  value: number;
  note: number;
  debit: number;
  credit: number;
  amount: number;
  type: number;
} | null {
  const names = cells.map((cell) => cell.toLowerCase().replace(/[^a-z]/g, ''));
  const at = (...wanted: string[]) => names.findIndex((name) => wanted.includes(name));
  const posted = at('txndate', 'transactiondate', 'postdate', 'posteddate', 'date');
  const value = at('valuedate');
  const date = posted >= 0 ? posted : value;
  const note = at('narration', 'description', 'particulars', 'remarks', 'details', 'transactionremarks');
  if (date < 0 || note < 0) return null;
  return {
    delimiter: '',
    date,
    value: posted >= 0 ? value : -1,
    note,
    debit: at('debit', 'debitamount', 'withdrawal', 'withdrawalamount', 'withdrawalamt', 'withdrawaldr', 'withdraw', 'dramount'),
    credit: at('credit', 'creditamount', 'deposit', 'depositamount', 'depositamt', 'depositcr', 'cramount'),
    amount: at('amount', 'transactionamount'),
    type: at('drcr', 'crdr', 'type'),
  };
}

function narrationNote(text: string): string {
  if (/UPI\/|IMPS\/|NEFT\/|RTGS\//i.test(text)) return sbiNote(text);
  return clip(text);
}

function rowsFromTableSafe(lines: string[], today: string): StatementRow[] | null {
  const limit = Math.min(lines.length, 40);
  for (let index = 0; index < limit; index++) {
    const delimiter = delimiterOf(lines[index] ?? '');
    const header = headerIndexes(splitRow(lines[index] ?? '', delimiter));
    if (!header) continue;
    header.delimiter = delimiter;
    return rowsFromTable(lines.slice(index), header, today);
  }
  return null;
}

function delimiterOf(line: string): string {
  const counts = [',', ';', '\t'].map((mark) => ({ mark, count: line.split(mark).length }));
  counts.sort((a, b) => b.count - a.count);
  return counts[0] && counts[0].count > 1 ? counts[0].mark : ',';
}

function splitRow(line: string, delimiter: string): string[] {
  const cells: string[] = [];
  let current = '';
  let quoted = false;
  for (let index = 0; index < line.length; index++) {
    const char = line[index]!;
    if (char === '"') {
      if (quoted && line[index + 1] === '"') {
        current += '"';
        index++;
      } else quoted = !quoted;
    } else if (char === delimiter && !quoted) {
      cells.push(current.trim());
      current = '';
    } else current += char;
  }
  cells.push(current.trim());
  return cells;
}

function dateFrom(text: string, today: string): { iso: string; match: string } | null {
  const numeric = text.match(/\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b/);
  if (numeric) {
    const iso = isoDate(Number(numeric[1]), Number(numeric[2]), Number(numeric[3]), today);
    return iso ? { iso, match: numeric[0] } : null;
  }
  const named = text.match(/\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{4})\b/i);
  if (!named) return null;
  const iso = isoDate(Number(named[1]), months[named[2]!.slice(0, 3).toLowerCase()] ?? 0, Number(named[3]), today);
  return iso ? { iso, match: named[0] } : null;
}

function isoDate(day: number, month: number, rawYear: number, today: string): string | null {
  let first = day;
  let second = month;
  if (first > 12 && second <= 12) {
    /* day first */
  } else if (second > 12 && first <= 12) {
    first = month;
    second = day;
  }
  const year = rawYear < 100 ? 2000 + rawYear : rawYear;
  if (second < 1 || second > 12 || first < 1 || first > 31 || year < 2000 || year > 2100) return null;
  const date = new Date(Date.UTC(year, second - 1, first));
  if (date.getUTCMonth() !== second - 1) return null;
  const iso = date.toISOString().slice(0, 10);
  return iso <= today ? iso : null;
}

function amountsIn(line: string): number[] {
  const found: number[] = [];
  for (const match of line.matchAll(/(?<![\d.])(\d{1,3}(?:,\d{2,3})+|\d{1,8})(?:\.(\d{1,2}))?(?!\d)/g)) {
    const amount = rupees(match[0] ?? '');
    if (amount != null && amount > 0 && amount < 100_000_000_00) found.push(amount);
  }
  return found;
}

function rupees(cell: string): number | null {
  const cleaned = cell.replace(/[₹,\s]/g, '').replace(/cr|dr/gi, '');
  if (!/^\d+(\.\d{1,2})?$/.test(cleaned)) return null;
  const value = Number(cleaned);
  if (!Number.isFinite(value) || value <= 0) return null;
  return Math.round(value * 100);
}

function clip(text: string): string {
  const cleaned = text.replace(/[^a-zA-Z0-9&.'\-\s]/g, ' ').replace(/\s+/g, ' ').trim();
  return cleaned.length <= 60 ? cleaned : cleaned.slice(0, 60).trim();
}

export type TextPiece = { str: string; x: number; y: number };

type SbiColumn = 'value' | 'post' | 'details' | 'ref' | 'debit' | 'credit' | 'balance';

/**
 * State Bank of India statements place each payment in columns:
 * Value Date, Post Date, Details, Ref No, Debit, Credit, Balance.
 * Returns null when the pages are not that table.
 */
export function rowsFromSbiLayout(pages: TextPiece[][], today = new Date().toISOString().slice(0, 10)): StatementRow[] | null {
  let sawTable = false;
  const rows: StatementRow[] = [];
  for (const page of pages) {
    const found = sbiPage(page, today);
    if (!found) continue;
    sawTable = true;
    rows.push(...found);
  }
  return sawTable ? rows : null;
}

function sbiPage(items: TextPiece[], today: string): StatementRow[] | null {
  const header = sbiHeader(items);
  if (!header) return null;
  const lines = groupLines(items.filter((item) => item.y < header.y - 3));
  const rows: StatementRow[] = [];
  let current: { occurredOn: string; details: string[]; amount: number | null; kind: StatementKind } | null = null;
  const flush = () => {
    if (!current?.amount) {
      current = null;
      return;
    }
    const note = sbiNote(current.details.join(' '));
    if (note.length >= 2 && !skipLine.test(note)) {
      rows.push({ occurredOn: current.occurredOn, note, amount: current.amount, kind: current.kind });
    }
    current = null;
  };
  for (const line of lines) {
    const joined = line.map((item) => item.str).join(' ');
    if (/page\s*no/i.test(joined)) continue;
    if (/\bdebit\b/i.test(joined) && /\bcredit\b/i.test(joined) && /\bbalance\b/i.test(joined)) continue;
    const dated = dateFrom(lineText(line, header, 'value'), today) ?? dateFrom(lineText(line, header, 'post'), today);
    if (dated) {
      flush();
      current = { occurredOn: dated.iso, details: [], amount: null, kind: 'expense' };
    }
    if (!current) continue;
    for (const item of line) {
      const column = sbiColumn(item, header.cols);
      if (column === 'details') current.details.push(item.str);
      if (column === 'debit') {
        const amount = rupees(item.str);
        if (amount) {
          current.amount = amount;
          current.kind = 'expense';
        }
      }
      if (column === 'credit') {
        const amount = rupees(item.str);
        if (amount) {
          current.amount = amount;
          current.kind = 'income';
        }
      }
    }
  }
  flush();
  return rows;
}

function sbiHeader(items: TextPiece[]): { y: number; cols: Record<SbiColumn, number> } | null {
  const debit = items.find((item) => /\bdebit\b/i.test(item.str) && item.str.length < 40);
  if (!debit) return null;
  const band = items.filter((item) => Math.abs(item.y - debit.y) < 14 && item.str.length < 40);
  const text = band.map((item) => item.str).join(' ');
  if (!/\bcredit\b/i.test(text) || !/\bbalance\b/i.test(text) || !/value/i.test(text) || !/details/i.test(text)) return null;
  const at = (pattern: RegExp) => band.find((item) => pattern.test(item.str))?.x;
  const value = at(/value/i);
  const details = at(/details/i);
  const credit = at(/\bcredit\b/i);
  const balance = at(/\bbalance\b/i);
  if (value == null || details == null || credit == null || balance == null) return null;
  return {
    y: Math.max(...band.map((item) => item.y)),
    cols: {
      value,
      post: at(/post/i) ?? (value + details) / 2,
      details,
      ref: at(/ref|cheque/i) ?? (details + debit.x) / 2,
      debit: debit.x,
      credit,
      balance,
    },
  };
}

function sbiColumn(item: TextPiece, cols: Record<SbiColumn, number>): SbiColumn {
  const money = /^(?:-|\d[\d,]*\.\d{2}(?:cr|dr)?)$/i.test(item.str.replace(/\s/g, ''));
  const names: SbiColumn[] = money ? ['debit', 'credit', 'balance'] : ['value', 'post', 'details', 'ref', 'debit', 'credit', 'balance'];
  let best: SbiColumn = 'details';
  let distance = Number.POSITIVE_INFINITY;
  for (const name of names) {
    const gap = Math.abs(item.x - cols[name]);
    if (gap < distance) {
      distance = gap;
      best = name;
    }
  }
  return best;
}

function lineText(line: TextPiece[], header: { cols: Record<SbiColumn, number> }, column: SbiColumn): string {
  return line
    .filter((item) => sbiColumn(item, header.cols) === column)
    .map((item) => item.str)
    .join(' ');
}

function groupLines(items: TextPiece[]): TextPiece[][] {
  const sorted = items.filter((item) => item.str.trim()).sort((a, b) => b.y - a.y || a.x - b.x);
  const lines: TextPiece[][] = [];
  for (const item of sorted) {
    const line = lines.at(-1);
    if (!line || Math.abs(line[0]!.y - item.y) > 2) lines.push([item]);
    else line.push(item);
  }
  for (const line of lines) line.sort((a, b) => a.x - b.x);
  return lines;
}

function sbiNote(details: string): string {
  const flat = details.replace(/\s+/g, ' ').trim();
  const upi = flat.match(/UPI\/(?:DR|CR)\/\d+\/(.+?)\/[A-Z]{4}\b/i);
  if (upi?.[1]) return clip(upi[1]);
  const imps = flat.match(/IMPS\/\d+\/([^/]+)\/([^/]+)/i);
  if (imps) {
    const name = /xx|\d/i.test(imps[1] ?? '') ? imps[2] : imps[1];
    return clip(`${name ?? ''} ${/salary/i.test(flat) ? 'salary' : ''}`.trim());
  }
  return clip(flat.replace(/\b(WDL|DEP)\s+TFR\b/gi, ' ').replace(/\bAT\s+\d+.*/i, ' ').replace(/\d{6,}/g, ' '));
}

export function tableRows(text: string, today: string): StatementRow[] | null {
  const lines = text
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  if (lines.length === 0) return null;
  return rowsFromTableSafe(lines, today);
}
