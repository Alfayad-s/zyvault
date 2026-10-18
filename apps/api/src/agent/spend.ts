import { isDebtType, type DebtType } from '../debts/debts.js';

export type SpendKind = 'income' | 'expense';

export type LlmSpend = {
  amount: unknown;
  currency?: unknown;
  merchant?: unknown;
  date?: unknown;
  rawDescription?: unknown;
  kind?: unknown;
  category?: unknown;
  schedule?: unknown;
  account?: unknown;
  debt?: unknown;
  goal?: unknown;
};

export type SpendSchedule = {
  repeat: 'once' | 'monthly';
  dayOfMonth: number;
  nextOn: string;
  /** Local time of day, HH:MM in 24 hours, or null for any time that day. */
  atTime: string | null;
};

export type SpendDebt = { type: DebtType; person: string };

export type SpendGoal = { name: string; action: 'add' | 'take_out' };

export type ParsedSpend = {
  amount: number;
  currency: string;
  merchant: string | null;
  occurredOn: string;
  rawDescription: string;
  kind: SpendKind;
  category: string | null;
  schedule: SpendSchedule | null;
  account: string | null;
  debt: SpendDebt | null;
  goal: SpendGoal | null;
};

export const expenseLabels = [
  'Groceries',
  'Dining Out',
  'Transport',
  'Fuel',
  'Utilities',
  'Rent',
  'Entertainment',
  'Shopping',
  'Health',
  'Education',
  'Travel',
] as const;

export const incomeLabels = ['Salary', 'Business', 'Interest', 'Refund', 'Other income'] as const;

const labelCategories: Record<string, string> = {
  Groceries: 'Groceries',
  'Dining Out': 'Food',
  Transport: 'Transport',
  Fuel: 'Fuel',
  Utilities: 'Bills',
  Rent: 'Rent',
  Entertainment: 'Entertainment',
  Shopping: 'Shopping',
  Health: 'Health',
  Education: 'Education',
  Travel: 'Travel',
  Salary: 'Salary',
  Business: 'Business',
  Interest: 'Interest',
  Refund: 'Refund',
  'Other income': 'Other income',
};

const broaderCategories: Record<string, string> = {
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
  Business: 'Other income',
  Freelance: 'Other income',
  Interest: 'Other income',
  Refund: 'Other income',
  'Gift received': 'Other income',
  'Rental income': 'Other income',
};

export function broaderCategory(name: string): string | null {
  return broaderCategories[name] ?? null;
}

export const minimumConfidence = 0.3;

const multipliers: Record<string, number> = {
  k: 1_000,
  thousand: 1_000,
  l: 100_000,
  lac: 100_000,
  lakh: 100_000,
  lakhs: 100_000,
  cr: 10_000_000,
  crore: 10_000_000,
};

function rupeesFromText(text: string): number {
  const match = text
    .toLowerCase()
    .replace(/[,₹\s]|rs\.?|rupees?/g, '')
    .match(/^(\d+(?:\.\d+)?)([a-z]*)$/);
  if (!match) {
    return Number.NaN;
  }
  const multiplier = match[2] === '' ? 1 : multipliers[match[2]];
  return multiplier === undefined ? Number.NaN : Number(match[1]) * multiplier;
}

export function toPaise(rupees: unknown): number | null {
  const value = typeof rupees === 'string' ? rupeesFromText(rupees) : rupees;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return null;
  }
  const paise = Math.round(value * 100);
  return paise >= 1 ? paise : null;
}

export function resolveDate(date: unknown, today: string): string {
  if (typeof date !== 'string') {
    return today;
  }
  const word = date.trim().toLowerCase();
  if (word === '' || word === 'today') {
    return today;
  }
  if (word === 'yesterday' || word === 'last night') {
    return shiftDay(today, -1);
  }
  if (word === 'day before yesterday') {
    return shiftDay(today, -2);
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(word) && !Number.isNaN(Date.parse(`${word}T00:00:00Z`))) {
    return word > today ? today : word;
  }
  return today;
}

export function shiftDay(day: string, offset: number): string {
  const date = new Date(`${day}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
}

export function categoryNameFor(
  label: string | null,
  score: number,
  kind: SpendKind,
): string {
  const fallback = kind === 'income' ? 'Other income' : 'Other';
  if (!label || score < minimumConfidence) {
    return fallback;
  }
  return labelCategories[label] ?? fallback;
}

export function readLlmJson(text: string): LlmSpend[] {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const body = (fenced ? fenced[1] : text).trim();
  const start = body.search(/[[{]/);
  if (start < 0) {
    throw new Error('No JSON in the model reply');
  }
  const parsed: unknown = JSON.parse(body.slice(start));
  const items = Array.isArray(parsed)
    ? parsed
    : parsed && typeof parsed === 'object' && Array.isArray((parsed as { items?: unknown }).items)
      ? (parsed as { items: unknown[] }).items
      : [parsed];
  return items.filter(
    (item): item is LlmSpend => item !== null && typeof item === 'object',
  );
}

export function normalizeSpends(
  items: LlmSpend[],
  today: string,
  allowSchedules = true,
  now?: string,
): ParsedSpend[] {
  const spends: ParsedSpend[] = [];
  for (const item of items) {
    const amount = toPaise(item.amount);
    const currency = typeof item.currency === 'string' ? item.currency.trim().toUpperCase() : 'INR';
    if (amount === null || (currency !== '' && currency !== 'INR')) {
      continue;
    }
    const merchant = text(item.merchant);
    const rawDescription = text(item.rawDescription) ?? merchant ?? 'spend';
    const schedule = allowSchedules ? readSchedule(item.schedule, item.date, today, now) : null;
    const goal = schedule ? null : readGoal(item.goal);
    const debt = schedule || goal ? null : readDebt(item.debt, merchant);
    spends.push({
      amount,
      currency: 'INR',
      merchant,
      occurredOn: schedule?.nextOn ?? resolveDate(item.date, today),
      rawDescription,
      kind: goal
        ? goal.action === 'take_out'
          ? 'income'
          : 'expense'
        : debt
          ? debtKind(debt.type)
          : item.kind === 'income'
            ? 'income'
            : 'expense',
      category: text(item.category),
      schedule,
      account: text(item.account),
      debt,
      goal,
    });
  }
  return spends;
}

export function readDebt(value: unknown, merchant: string | null): SpendDebt | null {
  if (!value || typeof value !== 'object') {
    return null;
  }
  const { type, person } = value as { type?: unknown; person?: unknown };
  const name = text(person) ?? merchant;
  return isDebtType(type) && name ? { type, person: name } : null;
}

export function readGoal(value: unknown): SpendGoal | null {
  if (!value || typeof value !== 'object') {
    return null;
  }
  const { name, action } = value as { name?: unknown; action?: unknown };
  const goalName = text(name);
  if (!goalName || (action !== 'add' && action !== 'take_out')) {
    return null;
  }
  return { name: goalName, action };
}

export function debtKind(type: DebtType): SpendKind {
  return type === 'borrowed' || type === 'got_back' ? 'income' : 'expense';
}

/** "18:00", "6pm", "6:30 PM", "9.15am" → "HH:MM"; anything else → null. */
export function readTime(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const match = value
    .trim()
    .toLowerCase()
    .match(/^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?$/);
  if (!match) return null;
  let hour = Number(match[1]);
  const minute = match[2] ? Number(match[2]) : 0;
  if (match[3] === 'pm' && hour < 12) hour += 12;
  if (match[3] === 'am' && hour === 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

export function readSchedule(
  value: unknown,
  date: unknown,
  today: string,
  now?: string,
): SpendSchedule | null {
  if (!value || typeof value !== 'object') {
    return null;
  }
  const { repeat, day, time } = value as { repeat?: unknown; day?: unknown; time?: unknown };
  const atTime = readTime(time);
  const later = (on: string) => on > today || (on === today && atTime !== null && (!now || atTime > now));
  const isoDate = typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date.trim()) ? date.trim() : null;
  const dayOfMonth =
    typeof day === 'number' && Number.isInteger(day) && day >= 1 && day <= 31
      ? day
      : isoDate
        ? Number(isoDate.slice(8, 10))
        : null;
  if (repeat === 'monthly' && dayOfMonth !== null) {
    const first = monthlyOnOrAfter(today, dayOfMonth);
    const nextOn =
      first === today && atTime !== null && now && atTime <= now
        ? monthlyAfter(today, dayOfMonth)
        : first;
    return { repeat: 'monthly', dayOfMonth, nextOn, atTime };
  }
  if (repeat === 'once' && isoDate && later(isoDate)) {
    return { repeat: 'once', dayOfMonth: Number(isoDate.slice(8, 10)), nextOn: isoDate, atTime };
  }
  return null;
}

export function monthlyDate(year: number, month: number, dayOfMonth: number): string {
  const first = new Date(Date.UTC(year, month - 1, 1));
  const last = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate();
  const date = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth(), Math.min(dayOfMonth, last)));
  return date.toISOString().slice(0, 10);
}

export function monthlyOnOrAfter(day: string, dayOfMonth: number): string {
  const year = Number(day.slice(0, 4));
  const month = Number(day.slice(5, 7));
  const thisMonth = monthlyDate(year, month, dayOfMonth);
  return thisMonth >= day ? thisMonth : monthlyDate(year, month + 1, dayOfMonth);
}

export function monthlyAfter(day: string, dayOfMonth: number): string {
  return monthlyOnOrAfter(shiftDay(day, 1), dayOfMonth);
}

export function spendNote(spend: ParsedSpend): string {
  if (spend.merchant && !spend.rawDescription.toLowerCase().includes(spend.merchant.toLowerCase())) {
    return `${spend.merchant} — ${spend.rawDescription}`;
  }
  return spend.rawDescription;
}

function text(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed === '' || trimmed.toLowerCase() === 'null' ? null : trimmed;
}
