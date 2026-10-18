import { shiftDay } from '../agent/spend.js';

export const askIntents = [
  'spending',
  'income',
  'breakdown',
  'transactions',
  'balance',
  'people',
  'goals',
  'budgets',
  'unknown',
] as const;

export type AskIntent = (typeof askIntents)[number];

export type AskPlan = {
  intent: AskIntent;
  from: string;
  to: string;
  label: string;
  categories: string[];
  account: string | null;
  person: string | null;
  goal: string | null;
  search: string | null;
  compare: boolean;
  sort: 'latest' | 'biggest';
  limit: number;
};

export type ChartPoint = { label: string; value: number; categoryName?: string; kind?: string };

export type AskItem = {
  label: string;
  value: number;
  detail?: string;
  categoryName?: string;
  kind?: string;
  iconKey?: string;
};

export type AskAnswer = {
  answer: string;
  chart: ChartPoint[] | null;
  items: AskItem[];
  plan: AskPlan;
};

export type AskRow = {
  amount: number;
  kind: 'income' | 'expense';
  occurredOn: string;
  note: string | null;
  categoryName: string;
  accountId: string;
  accountName: string;
};

const isoDate = /^\d{4}-\d{2}-\d{2}$/;

function monthStart(day: string): string {
  return `${day.slice(0, 8)}01`;
}

function text(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' || trimmed.toLowerCase() === 'null' ? null : trimmed;
}

/** A month named without a year means this year once that month has started. */
export function thisYearMonth(plan: AskPlan, today: string, question: string): AskPlan {
  if (/\b(19|20)\d\d\b/.test(question)) return plan;
  const year = Number(today.slice(0, 4));
  const sameMonth = plan.from.slice(0, 7) === plan.to.slice(0, 7);
  if (!sameMonth || Number(plan.from.slice(0, 4)) !== year - 1) return plan;
  const month = `${year}${plan.from.slice(4, 7)}`;
  if (month > today.slice(0, 7)) return plan;
  const from = `${month}${plan.from.slice(7)}`;
  const to = `${month}${plan.to.slice(7)}`;
  return { ...plan, from, to: to > today ? today : to };
}

export function readPlan(raw: unknown, today: string): AskPlan {
  const value = (Array.isArray(raw) ? raw[0] : raw) as Record<string, unknown> | undefined;
  const item = value && typeof value === 'object' ? value : {};
  const intent = askIntents.includes(item.intent as AskIntent) ? (item.intent as AskIntent) : 'unknown';
  let from = typeof item.from === 'string' && isoDate.test(item.from) ? item.from : monthStart(today);
  let to = typeof item.to === 'string' && isoDate.test(item.to) ? item.to : today;
  if (to > today) to = today;
  if (from > to) from = to;
  const categories = Array.isArray(item.categories)
    ? item.categories.map(text).filter((name): name is string => name !== null).slice(0, 10)
    : [];
  const limit = typeof item.limit === 'number' && Number.isInteger(item.limit) ? item.limit : 5;
  return {
    intent,
    from,
    to,
    label: text(item.label) ?? periodLabel(from, to, today),
    categories,
    account: text(item.account),
    person: text(item.person),
    goal: text(item.goal),
    search: text(item.search),
    compare: item.compare === true,
    sort: item.sort === 'biggest' ? 'biggest' : 'latest',
    limit: Math.min(20, Math.max(1, limit)),
  };
}

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function shortDate(day: string): string {
  return `${Number(day.slice(8, 10))} ${monthNames[Number(day.slice(5, 7)) - 1]}`;
}

export function periodLabel(from: string, to: string, today: string): string {
  if (from === today && to === today) return 'today';
  if (from === monthStart(today) && to === today) return 'this month';
  return `from ${shortDate(from)} to ${shortDate(to)}`;
}

/** The period of the same length just before the plan's period. */
export function previousPeriod(from: string, to: string): { from: string; to: string } {
  const days = Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
  const previousTo = shiftDay(from, -1);
  return { from: shiftDay(previousTo, -days), to: previousTo };
}

const rupeeFormat = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 2 });

export function rupees(paise: number): string {
  return `₹${rupeeFormat.format(Math.abs(paise) / 100)}`;
}

function words(value: string): string {
  return value.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

export function filterRows(
  rows: AskRow[],
  plan: Pick<AskPlan, 'categories' | 'search'>,
  kind: 'income' | 'expense',
  accountId: string | null,
): AskRow[] {
  const categories = new Set(plan.categories.map((name) => name.toLowerCase()));
  const search = plan.search ? words(plan.search) : '';
  return rows.filter(
    (row) =>
      row.kind === kind &&
      (accountId === null || row.accountId === accountId) &&
      (categories.size === 0 || categories.has(row.categoryName.toLowerCase())) &&
      (search === '' || words(`${row.note ?? ''} ${row.categoryName}`).includes(search)),
  );
}

export function sum(rows: { amount: number }[]): number {
  return rows.reduce((total, row) => total + row.amount, 0);
}

/** Daily bars for up to a month, monthly bars for longer periods. */
export function series(rows: AskRow[], from: string, to: string): ChartPoint[] {
  const days = Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000) + 1;
  const totals = new Map<string, number>();
  const daily = days <= 31;
  for (const row of rows) {
    const key = daily ? row.occurredOn : row.occurredOn.slice(0, 7);
    totals.set(key, (totals.get(key) ?? 0) + row.amount);
  }
  const points: ChartPoint[] = [];
  if (daily) {
    for (let day = from; day <= to; day = shiftDay(day, 1)) {
      points.push({ label: shortDate(day), value: totals.get(day) ?? 0 });
    }
  } else {
    for (let month = from.slice(0, 7); month <= to.slice(0, 7); ) {
      points.push({ label: `${monthNames[Number(month.slice(5, 7)) - 1]} ${month.slice(2, 4)}`, value: totals.get(month) ?? 0 });
      const next = new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 1));
      month = next.toISOString().slice(0, 7);
    }
  }
  return points;
}

export function byCategory(rows: AskRow[]): ChartPoint[] {
  const totals = new Map<string, { value: number; kind: string }>();
  for (const row of rows) {
    const entry = totals.get(row.categoryName) ?? { value: 0, kind: row.kind };
    entry.value += row.amount;
    totals.set(row.categoryName, entry);
  }
  return [...totals.entries()]
    .map(([name, entry]) => ({ label: name, value: entry.value, categoryName: name, kind: entry.kind }))
    .sort((a, b) => b.value - a.value);
}

export function scope(plan: AskPlan, accountName: string | null): string {
  const parts: string[] = [];
  if (plan.categories.length > 0) parts.push(`on ${plan.categories.join(', ')}`);
  if (plan.search) parts.push(`at ${plan.search}`);
  if (accountName) parts.push(`from ${accountName}`);
  return parts.length > 0 ? ` ${parts.join(' ')}` : '';
}

export function compareText(now: number, before: number): string {
  if (before === 0 && now === 0) return '';
  if (before === 0) return ' Nothing in the period before.';
  const change = now - before;
  if (change === 0) return ' Same as the period before.';
  const percent = Math.round((Math.abs(change) / before) * 100);
  return ` That is ${rupees(change)} ${change > 0 ? 'more' : 'less'} than the period before (${percent}%).`;
}
