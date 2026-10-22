import type { ParsedSpend } from './spend.js';

export type PrintedLine = { text: string; x: number; y: number; height: number; width?: number };

const metaLine =
  /^(?:date|sub\s*total|grand\s*total|total|cgst|sgst|igst|gst|vat|cess|round|discount|you saved|your savings|saved|change|balance|amount payable|net payable|net amount|net bill|bill amount|qty|quantity|mrp|hsn|gstin|fssai|invoice|cash memo|thank|cash|card|upi|ph|phone|mobile)\b/i;

const headerLine = /^(tax invoice|invoice|cash memo|receipt|bill|original|duplicate|retail invoice)$/i;

const dated = /\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b/;

const payment = /\b(gpay|google pay|phonepe|paytm|upi|bhim)\b/i;

const timed = /\b\d{1,2}:\d{2}(?::\d{2})?\b/;

const stopWords = new Set([
  'amount',
  'rate',
  'value',
  'with',
  'gpay',
  'upi',
  'phonepe',
  'paytm',
  'date',
  'time',
  'bill',
  'total',
  'taxable',
  'qty',
  'hsn',
  'rs',
  'inr',
  'number',
  'invoice',
  'mode',
  'paid',
  'payment',
  'ref',
]);

const moneyAtEnd =
  /(?:₹|rs\.?)?\s*(\d{1,3}(?:,\d{2,3})+|\d{1,6})(?:\.(\d{1,2}))?(?:\s*\/-)?\s*$/i;

/** Group Vision words into rows. A sideways photo is read along the other axis. */
export function linesFromWords(words: PrintedLine[]): string[] {
  const across = groupWords(words, true);
  const down = groupWords(words, false);
  return readingScore(across) >= readingScore(down) ? across : down;
}

const sectionEnd =
  /^(?:total|net bill|grand total|payment|gst summary|your savings|previous balance|taxable|cgst|sgst)\b/i;

/** Priced rows from a bill. Totals, tax, and a line that only repeats the sum are left out. */
export function billItems(lines: string[], today: string): ParsedSpend[] {
  const cleaned = lines.map((line) => line.replace(/\s+/g, ' ').trim()).filter(Boolean);
  const items: { name: string; rupees: number }[] = [];
  let pending: string | null = null;
  for (const line of itemSection(cleaned)) {
    if (skipRow(line)) {
      pending = null;
      continue;
    }
    const priced = pricedParts(line);
    if (priced.length > 0) {
      items.push(...priced);
      pending = null;
      continue;
    }
    const figure = figureFor(line);
    if (figure != null && pending) {
      items.push({ name: pending, rupees: figure });
      pending = null;
      continue;
    }
    if (figure != null || quantityLine(line)) continue;
    const name = itemName(line);
    pending = looksLikeProduct(name) ? name : null;
  }
  const last = items[items.length - 1];
  if (pending && last && /\d+\s*(ml|gm|g|kg|l|ltr)\b/i.test(pending)) {
    last.name = `${last.name} ${pending}`;
  }
  const kept = dropSum(items).filter(
    (item) => item.rupees > 0 && item.rupees <= 100_000 && looksLikeProduct(item.name),
  );
  if (kept.length === 0) return [];
  const occurredOn = dateFrom(cleaned) ?? today;
  const merchant = shopName(cleaned, kept);
  return kept.map((item) => ({
    amount: Math.round(item.rupees * 100),
    currency: 'INR',
    merchant,
    occurredOn,
    rawDescription: item.name.toLowerCase(),
    kind: 'expense',
    category: null,
    schedule: null,
    account: null,
    debt: null,
    goal: null,
  }));
}

/** One supermarket visit: the shop, the items bought, and the total. */
export function shopVisit(items: ParsedSpend[]): ParsedSpend {
  const first = items[0]!;
  if (items.length < 2) return first;
  const merchant = items.find((item) => item.merchant)?.merchant ?? null;
  return {
    ...first,
    amount: items.reduce((sum, item) => sum + item.amount, 0),
    merchant,
    rawDescription: items.map((item) => `${item.rawDescription} ₹${rupeeLabel(item.amount)}`).join(', '),
  };
}

function rupeeLabel(paise: number): string {
  return (paise / 100).toFixed(2).replace(/\.00$/, '').replace(/(\.\d)0$/, '$1');
}

export function listedItems(read: { text: string; lines: string[] }, today: string): ParsedSpend[] {
  const all = [...read.lines, ...read.text.split('\n')];
  const net = netBill(all);
  const choices = [billItems(read.text.split('\n'), today), billItems(read.lines, today)].filter((items) => items.length > 0);
  if (choices.length === 0) return [];
  if (net == null) return choices.sort((a, b) => b.length - a.length)[0] ?? [];
  return choices.sort((a, b) => Math.abs(sumRupees(a) - net) - Math.abs(sumRupees(b) - net) || b.length - a.length)[0] ?? [];
}

function itemSection(lines: string[]): string[] {
  const start = lines.findIndex((line) => /\bitem\s*name\b/i.test(line) || (/\bqty\b/i.test(line) && /\bamount\b/i.test(line)));
  let body = start >= 0 ? lines.slice(start + 1) : lines;
  const end = body.findIndex((line) => sectionEnd.test(line));
  if (end >= 0) body = body.slice(0, end);
  return body;
}

function netBill(lines: string[]): number | null {
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    if (!line || !/\b(net bill|bill amount|grand total)\b/i.test(line)) continue;
    const nearby = amountsIn(lines.slice(index, index + 4).join(' ')).filter((amount) => amount.decimals);
    const last = nearby[nearby.length - 1];
    if (last) return last.rupees;
  }
  return null;
}

function sumRupees(items: ParsedSpend[]): number {
  return items.reduce((sum, item) => sum + item.amount / 100, 0);
}

function skipRow(line: string): boolean {
  return headerLine.test(line) || metaLine.test(line) || dated.test(line) || payment.test(line) || timed.test(line);
}

const chrome =
  /\b(road|phone|gstin|taxable|balance|savings|summary|invoice|cgst|sgst|gst|temple|refund|bengaluru|tax|bill\s*no)\b/i;

function looksLikeProduct(name: string): boolean {
  if (chrome.test(name)) return false;
  const words = name
    .toLowerCase()
    .split(/\s+/)
    .filter((word) => word.length >= 3 && !stopWords.has(word) && !/^\d/.test(word));
  if (words.length === 0) return false;
  return !(words.length < 2 && /\d{5,}/.test(name));
}

function pricedParts(line: string): { name: string; rupees: number }[] {
  if (skipRow(line)) return [];
  const found = amountsIn(line);
  const decimals = found.filter((amount) => amount.decimals);
  const amounts = decimals.length > 0 ? decimals : found.slice(-1);
  const parts: { name: string; rupees: number }[] = [];
  let from = 0;
  let pending = '';
  for (let index = 0; index < amounts.length; index++) {
    const amount = amounts[index];
    if (!amount) continue;
    const name = itemName(line.slice(from, amount.index));
    if (looksLikeProduct(name) && !metaLine.test(name)) pending = name;
    const next = amounts[index + 1];
    const between = next ? itemName(line.slice(amount.end, next.index)) : 'end';
    from = amount.end;
    if (next && between.length < 2) continue;
    if (pending.length >= 2) parts.push({ name: pending, rupees: amount.rupees });
    pending = '';
  }
  return parts;
}

function amountsIn(line: string): { rupees: number; index: number; end: number; decimals: boolean }[] {
  const found: { rupees: number; index: number; end: number; decimals: boolean }[] = [];
  for (const match of line.matchAll(
    /(?:₹|rs\.?)?\s*(?<![A-Za-z\d])(\d{1,3}(?:,\d{2,3})+|\d{1,6})(?:\.(\d{1,2}))?(?:\s*\/-)?(?![A-Za-z\d%])/gi,
  )) {
    const rupees = rupeesFrom(match[1] ?? '', match[2]);
    if (rupees == null || match.index == null) continue;
    if (/\d[\/\-.]\d/.test(line) && match[2] == null && (match[1]?.length ?? 0) === 4) continue;
    found.push({
      rupees,
      index: match.index,
      end: match.index + match[0].length,
      decimals: match[2] != null,
    });
  }
  return found;
}

/** A row of figures with no product name. The last decimal is the line value; a lone 1 is a quantity. */
function figureFor(line: string): number | null {
  if (/[A-Za-z]/.test(line)) return null;
  const found = amountsIn(line);
  const decimals = found.filter((amount) => amount.decimals);
  const last = decimals[decimals.length - 1];
  if (last) return last.rupees;
  if (found.length === 1 && found[0]!.rupees > 10) return found[0]!.rupees;
  return null;
}

function quantityLine(line: string): boolean {
  return /^\d{1,2}$/.test(line.trim()) && Number(line) <= 10;
}

function rupeesFrom(major: string, minor?: string): number | null {
  const whole = Number(major.replace(/,/g, ''));
  if (!Number.isFinite(whole)) return null;
  const fraction = minor ? Number(minor.padEnd(2, '0').slice(0, 2)) / 100 : 0;
  const rupees = whole + fraction;
  return rupees > 0 ? rupees : null;
}

function itemName(raw: string): string {
  return raw
    .replace(/^\d+\s*[xX*]\s*/, '')
    .replace(/^\d+\s+/, '')
    .replace(/(?:\s+\d+(?:[.,]\d+)?)+\s*$/, '')
    .replace(/[^a-zA-Z0-9&.'\-\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function dropSum(items: { name: string; rupees: number }[]): { name: string; rupees: number }[] {
  if (items.length < 3) return items;
  const last = items[items.length - 1];
  if (!last) return items;
  const others = items.slice(0, -1).reduce((sum, item) => sum + item.rupees, 0);
  if (Math.abs(others - last.rupees) < 0.05) return items.slice(0, -1);
  return items;
}

function shopName(lines: string[], items: { name: string }[]): string | null {
  const names = new Set(items.map((item) => item.name.toLowerCase()));
  const clean = lines
    .filter((line) => !skipRow(line) && !moneyAtEnd.test(line) && !/\d/.test(line))
    .map((line) => itemName((line.split(',')[0] ?? line).trim()))
    .filter((name) => name.length >= 3 && name.length <= 40 && !names.has(name.toLowerCase()) && /[a-z]/i.test(name));
  const branded = clean.filter((name) => /\b(supermarket|emporium|hypermarket|kirana|mart|needs|traders|bazaar|stores?)\b/i.test(name));
  return branded.find((name) => name.includes(' ')) ?? branded[0] ?? clean[0] ?? null;
}

function dateFrom(lines: string[]): string | null {
  for (const line of lines) {
    const match = line.match(/\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b/);
    if (!match) continue;
    const day = Number(match[1]);
    const month = Number(match[2]);
    const rawYear = Number(match[3]);
    const year = rawYear < 100 ? 2000 + rawYear : rawYear;
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 2000 || year > 2100) continue;
    const date = new Date(Date.UTC(year, month - 1, day));
    if (date.getUTCMonth() !== month - 1) continue;
    const iso = date.toISOString().slice(0, 10);
    if (iso > new Date().toISOString().slice(0, 10)) continue;
    return iso;
  }
  return null;
}

function groupWords(words: PrintedLine[], horizontal: boolean): string[] {
  const sorted = [...words].filter((word) => word.text.trim()).sort((a, b) => axisOf(a, horizontal) - axisOf(b, horizontal) || crossOf(a, horizontal) - crossOf(b, horizontal));
  if (sorted.length === 0) return [];
  const sizes = sorted.map((word) => (horizontal ? word.height : (word.width ?? word.height))).sort((a, b) => a - b);
  const typical = sizes[Math.floor(sizes.length / 2)] ?? 12;
  const slack = Math.max(6, typical * 0.55);
  const rows: PrintedLine[][] = [[sorted[0]!]];
  for (const word of sorted.slice(1)) {
    const row = rows[rows.length - 1]!;
    if (Math.abs(averageAxis(row, horizontal) - axisOf(word, horizontal)) <= slack) row.push(word);
    else rows.push([word]);
  }
  return rows.map((row) =>
    row
      .sort((a, b) => crossOf(a, horizontal) - crossOf(b, horizontal))
      .map((word) => word.text.trim())
      .join(' '),
  );
}

function readingScore(lines: string[]): number {
  let score = 0;
  for (const line of lines) {
    const words = line.split(/\s+/).filter(Boolean);
    if (words.length > 14) score -= 3;
    if (/\bitem\s*name\b/i.test(line) || (/\bqty\b/i.test(line) && /\bmrp\b/i.test(line))) score += 8;
    if (/\b(net bill|grand total|bill amount)\b/i.test(line)) score += 6;
    if (/[A-Za-z]{3}/.test(line) && /\d+\.\d{1,2}\b/.test(line) && words.length <= 12 && !chrome.test(line)) score += 5;
  }
  return score;
}

function axisOf(word: PrintedLine, horizontal: boolean): number {
  return horizontal ? word.y : word.x;
}

function crossOf(word: PrintedLine, horizontal: boolean): number {
  return horizontal ? word.x : word.y;
}

function averageAxis(line: PrintedLine[], horizontal: boolean): number {
  return line.reduce((sum, word) => sum + axisOf(word, horizontal), 0) / line.length;
}
