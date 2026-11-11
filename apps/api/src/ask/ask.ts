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
  'explain',
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
  reply: string;
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
    reply: text(item.reply) ?? '',
  };
}

export type AskLanguage = 'en' | 'ml' | 'mg';

const malayalamScript = /[\u0D00-\u0D7F]/;
const manglishWord =
  /\b(ethra|ethrayanu|ethre|evide|evideya|enthu|entha|undu|unda|chilavu|chilavayi|chilavayathu|kitti|kittiyathu|baakki|bakki|kodukkanam|koduthu|innale|innu|shambalam|aaranu|aarokke|maasam|aazhcha|vangi|adachu)\b/i;

/** Malayalam written in English letters, and not Malayalam script. */
export function isManglish(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed || malayalamScript.test(trimmed)) return false;
  return manglishWord.test(trimmed);
}

/** A free-form reply counts as Manglish when it uses those words and no Malayalam script. */
export function isManglishReply(text: string): boolean {
  return isManglish(text);
}

/**
 * Malayalam or Manglish selected on the chip wins.
 * An English chip still follows a Manglish question.
 * With no chip, Malayalam script stays Malayalam and Manglish typing stays Manglish.
 */
export function resolveLanguage(selected: string | undefined, text: string): AskLanguage {
  if (selected === 'ml' || selected === 'mg') return selected;
  if (selected === 'en') return isManglish(text) ? 'mg' : 'en';
  if (malayalamScript.test(text)) return 'ml';
  if (isManglish(text)) return 'mg';
  return 'en';
}

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthNamesMl = [
  'ജനുവരി',
  'ഫെബ്രുവരി',
  'മാർച്ച്',
  'ഏപ്രിൽ',
  'മേയ്',
  'ജൂൺ',
  'ജൂലൈ',
  'ഓഗസ്റ്റ്',
  'സെപ്റ്റംബർ',
  'ഒക്ടോബർ',
  'നവംബർ',
  'ഡിസംബർ',
];
const monthInMl = [
  'ജനുവരിയിൽ',
  'ഫെബ്രുവരിയിൽ',
  'മാർച്ചിൽ',
  'ഏപ്രിലിൽ',
  'മേയിൽ',
  'ജൂണിൽ',
  'ജൂലൈയിൽ',
  'ഓഗസ്റ്റിൽ',
  'സെപ്റ്റംബറിൽ',
  'ഒക്ടോബറിൽ',
  'നവംബറിൽ',
  'ഡിസംബറിൽ',
];
const monthNamesMg = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const monthInMg = [
  'Januaryil',
  'Februaryil',
  'Marchil',
  'Aprilil',
  'Mayil',
  'June-il',
  'Julyil',
  'Augustil',
  'Septemberil',
  'Octoberil',
  'Novemberil',
  'Decemberil',
];
const periodMg: Record<string, string> = {
  today: 'innu',
  yesterday: 'innale',
  'this month': 'ee maasam',
  'last month': 'kazhinja maasam',
  'this week': 'ee aazhcha',
  'last week': 'kazhinja aazhcha',
  'this year': 'ee varsham',
  'in the last 7 days': 'kazhinja 7 divasathil',
  'last 7 days': 'kazhinja 7 divasathil',
  'in the last 3 months': 'kazhinja 3 maasathil',
  'last 3 months': 'kazhinja 3 maasathil',
};
const periodMl: Record<string, string> = {
  today: 'ഇന്ന്',
  yesterday: 'ഇന്നലെ',
  'this month': 'ഈ മാസം',
  'last month': 'കഴിഞ്ഞ മാസം',
  'this week': 'ഈ ആഴ്ച',
  'last week': 'കഴിഞ്ഞ ആഴ്ച',
  'this year': 'ഈ വർഷം',
  'in the last 7 days': 'കഴിഞ്ഞ 7 ദിവസത്തിൽ',
  'last 7 days': 'കഴിഞ്ഞ 7 ദിവസത്തിൽ',
  'in the last 3 months': 'കഴിഞ്ഞ 3 മാസത്തിൽ',
  'last 3 months': 'കഴിഞ്ഞ 3 മാസത്തിൽ',
};

function monthIndex(name: string): number {
  return monthNames.findIndex((month) => name.toLowerCase().startsWith(month.toLowerCase()));
}

function translateDay(text: string, language: AskLanguage): string {
  const match = /^(\d{1,2})\s+([A-Za-z]+)/.exec(text.trim());
  if (!match) return text.trim();
  const index = monthIndex(match[2]);
  if (index < 0) return text.trim();
  const names = language === 'mg' ? monthNamesMg : monthNamesMl;
  return `${Number(match[1])} ${names[index]}`;
}

/** A period phrase the reply can say, in the language selected on the type page. */
export function speakPeriod(label: string, language: AskLanguage = 'en'): string {
  if (language === 'en') return label;
  const known = (language === 'mg' ? periodMg : periodMl)[label.trim().toLowerCase()];
  if (known) return known;
  const inMonth = /^in\s+([A-Za-z]+)$/.exec(label.trim());
  if (inMonth) {
    const index = monthIndex(inMonth[1]);
    if (index >= 0) return (language === 'mg' ? monthInMg : monthInMl)[index];
  }
  const range = /^from\s+(.+?)\s+to\s+(.+)$/i.exec(label.trim());
  if (range) {
    const from = translateDay(range[1], language);
    const to = translateDay(range[2], language);
    return language === 'mg' ? `${from} muthal ${to} vare` : `${from} മുതൽ ${to} വരെ`;
  }
  return label;
}

export function shortDate(day: string, language: AskLanguage = 'en'): string {
  const names = language === 'ml' ? monthNamesMl : language === 'mg' ? monthNamesMg : monthNames;
  return `${Number(day.slice(8, 10))} ${names[Number(day.slice(5, 7)) - 1]}`;
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

export function scope(plan: AskPlan, accountName: string | null, language: AskLanguage = 'en'): string {
  const parts: string[] = [];
  if (language === 'ml') {
    if (plan.categories.length > 0) parts.push(`${plan.categories.join(', ')}-ന്`);
    if (plan.search) parts.push(`${plan.search}-യിൽ`);
    if (accountName) parts.push(`${accountName}-ൽ നിന്ന്`);
    return parts.length > 0 ? ` ${parts.join(' ')}` : '';
  }
  if (language === 'mg') {
    if (plan.categories.length > 0) parts.push(`${plan.categories.join(', ')}-nu`);
    if (plan.search) parts.push(`${plan.search}-il`);
    if (accountName) parts.push(`${accountName}-il ninnu`);
    return parts.length > 0 ? ` ${parts.join(' ')}` : '';
  }
  if (plan.categories.length > 0) parts.push(`on ${plan.categories.join(', ')}`);
  if (plan.search) parts.push(`at ${plan.search}`);
  if (accountName) parts.push(`from ${accountName}`);
  return parts.length > 0 ? ` ${parts.join(' ')}` : '';
}

export function compareText(now: number, before: number, language: AskLanguage = 'en'): string {
  if (before === 0 && now === 0) return '';
  if (before === 0) {
    if (language === 'ml') return ' അതിനു മുൻപുള്ള കാലയളവിൽ ഒന്നും ഉണ്ടായിരുന്നില്ല.';
    if (language === 'mg') return ' athinu munpullathil onnum illayirunnu.';
    return ' Nothing in the period before.';
  }
  const change = now - before;
  if (change === 0) {
    if (language === 'ml') return ' കഴിഞ്ഞ കാലയളവിന് തുല്യമാണ്.';
    if (language === 'mg') return ' kazhinja kalayathinu thulyamanu.';
    return ' Same as the period before.';
  }
  const percent = Math.round((Math.abs(change) / before) * 100);
  if (language === 'ml') {
    return change > 0
      ? ` കഴിഞ്ഞ കാലയളവിനേക്കാൾ ${rupees(change)} കൂടുതലാണ് (${percent}%).`
      : ` കഴിഞ്ഞ കാലയളവിനേക്കാൾ ${rupees(change)} കുറവാണ് (${percent}%).`;
  }
  if (language === 'mg') {
    return change > 0
      ? ` kazhinja kalayathinekkal ${rupees(change)} kooduthalanu (${percent}%).`
      : ` kazhinja kalayathinekkal ${rupees(change)} kuravanu (${percent}%).`;
  }
  return ` That is ${rupees(change)} ${change > 0 ? 'more' : 'less'} than the period before (${percent}%).`;
}
