import { DateTime } from 'luxon';
import { goalIcons } from '../categories/icons.js';
import { debtTypes, type DebtType } from '../debts/debts.js';
import { chatZone } from './chat-clock.js';

export type ChatProposal = {
  title: string;
  lines: string[];
  action: Record<string, unknown>;
};

type Named = { id: string; name: string };
type NamedKind = Named & { kind: 'income' | 'expense' };

export type ActionContext = {
  today: string;
  accounts: Named[];
  categories: NamedKind[];
  goals: Named[];
  transactionIds: string[];
};

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const day = /^\d{4}-\d{2}-\d{2}$/;
const month = /^\d{4}-(0[1-9]|1[0-2])$/;
const clock = /^([01]\d|2[0-3]):[0-5]\d$/;

export function readChatTurn(text: string): { reply: string; action: unknown } {
  const trimmed = text.trim();
  const start = trimmed.indexOf('{');
  if (start < 0) return { reply: trimmed, action: null };
  try {
    const parsed = JSON.parse(trimmed.slice(start)) as { reply?: unknown; action?: unknown };
    if (typeof parsed.reply === 'string' && parsed.reply.trim()) {
      return { reply: parsed.reply.trim(), action: parsed.action ?? null };
    }
  } catch {
    /* The model answered in plain text. */
  }
  return { reply: trimmed, action: null };
}

export function resolveAction(
  raw: unknown,
  context: ActionContext,
): { proposal: ChatProposal | null; problem?: string } {
  if (raw == null) return { proposal: null };
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { proposal: null, problem: 'I could not read that as something to save.' };
  }
  const action = raw as Record<string, unknown>;
  switch (action.type) {
    case 'log': {
      const occurred = dateOr(action.date, context.today);
      if (occurred && occurred > context.today) {
        const dayOfMonth = Number(occurred.slice(8, 10));
        return scheduleProposal(
          { ...action, repeat: action.repeat ?? 'once', day: action.day ?? dayOfMonth, date: occurred },
          context,
        );
      }
      return logProposal(action, context);
    }
    case 'schedule':
      return scheduleProposal(action, context);
    case 'budget':
      return budgetProposal(action, context);
    case 'goal':
      return goalProposal(action, context);
    case 'goal_money':
      return goalMoneyProposal(action, context);
    case 'debt':
      return debtProposal(action, context);
    default:
      return { proposal: null };
  }
}

function logProposal(action: Record<string, unknown>, context: ActionContext) {
  const kind = moneyKind(action.kind);
  const amount = paise(action.amount);
  const occurredOn = dateOr(action.date, context.today);
  const category = matchKind(text(action.category), context.categories, kind);
  const account = matchAccount(text(action.account), context.accounts);
  const id = text(action.id);
  if (!kind || !amount || !occurredOn) return incomplete('an amount and whether it is income or spending');
  if (!category) return incomplete(`a category you already have for ${kind}`);
  if (!account) return incomplete('which account');
  if (id && !context.transactionIds.includes(id)) return incomplete('which saved payment to change');
  const note = clip(text(action.note), 200);
  const lines = [
    `${kind === 'income' ? 'Income' : 'Expense'} ${rupee(amount)}`,
    category.name,
    account.name,
    occurredOn,
  ];
  if (note) lines.push(note);
  return proposal(id ? 'Update this payment?' : 'Log this?', lines, {
    type: 'log',
    id: id || undefined,
    accountId: account.id,
    categoryId: category.id,
    amount,
    kind,
    occurredOn,
    note,
  });
}

function scheduleProposal(action: Record<string, unknown>, context: ActionContext) {
  const kind = moneyKind(action.kind);
  const amount = paise(action.amount);
  const given = text(action.date);
  let repeat = action.repeat === 'monthly' || action.repeat === 'once' ? action.repeat : null;
  let dayOfMonth = number(action.day);
  if (given && day.test(given)) {
    const parsed = DateTime.fromISO(given, { zone: chatZone });
    if (!dayOfMonth && parsed.isValid) dayOfMonth = parsed.day;
    repeat ??= 'once';
  }
  const category = matchKind(text(action.category), context.categories, kind);
  const account = matchAccount(text(action.account), context.accounts);
  const atTime = clock.test(text(action.time) ?? '') ? text(action.time) : undefined;
  if (!kind || !amount || !repeat || !dayOfMonth || dayOfMonth < 1 || dayOfMonth > 31) {
    return incomplete('the amount, how often, and which day');
  }
  if (!category) return incomplete(`a category you already have for ${kind}`);
  if (!account) return incomplete('which account');
  const nextOn = futureDate(text(action.date), context.today, dayOfMonth);
  const note = clip(text(action.note), 200);
  const lines = [
    `${repeat === 'monthly' ? 'Every month' : 'Once'} on day ${dayOfMonth}`,
    `${kind === 'income' ? 'Income' : 'Expense'} ${rupee(amount)}`,
    category.name,
    account.name,
    nextOn,
  ];
  if (atTime) lines.push(atTime);
  if (note) lines.push(note);
  return proposal('Schedule this?', lines, {
    type: 'schedule',
    accountId: account.id,
    categoryId: category.id,
    amount,
    kind,
    note,
    repeat,
    dayOfMonth,
    nextOn,
    atTime,
  });
}

function budgetProposal(action: Record<string, unknown>, context: ActionContext) {
  const amount = paise(action.amount);
  const category = matchKind(text(action.category), context.categories, 'expense');
  const budgetMonth = month.test(text(action.month) ?? '') ? text(action.month) : context.today.slice(0, 7);
  if (!amount) return incomplete('the budget amount');
  if (!category || !budgetMonth) return incomplete('an expense category you already have');
  return proposal('Set this budget?', [`${category.name} ${rupee(amount)}`, budgetMonth], {
    type: 'budget',
    categoryId: category.id,
    month: budgetMonth,
    limitAmount: amount,
  });
}

function goalProposal(action: Record<string, unknown>, context: ActionContext) {
  const name = clip(text(action.name), 40);
  const target = paise(action.target);
  const id = text(action.id);
  const icon = goalIcons.includes(text(action.icon) as (typeof goalIcons)[number])
    ? (text(action.icon) as string)
    : 'goal-target';
  const targetDate = day.test(text(action.date) ?? '') ? text(action.date) : undefined;
  if (!name || !target) return incomplete('a name and a target amount');
  if (id && !context.goals.some((goal) => goal.id === id)) return incomplete('which goal to change');
  const lines = [name, `Target ${rupee(target)}`];
  if (targetDate) lines.push(targetDate);
  return proposal(id ? 'Update this goal?' : 'Create this goal?', lines, {
    type: 'goal',
    id: id || undefined,
    name,
    icon,
    targetAmount: target,
    targetDate,
  });
}

function goalMoneyProposal(action: Record<string, unknown>, context: ActionContext) {
  const entry = action.entry === 'add' || action.entry === 'take_out' ? action.entry : null;
  const amount = paise(action.amount);
  const goal = matchName(text(action.name), context.goals);
  const occurredOn = dateOr(action.date, context.today);
  if (!entry || !amount || !occurredOn) return incomplete('the goal, the amount, and add or take out');
  if (!goal) return incomplete('a goal you already have');
  const note = clip(text(action.note), 200);
  return proposal(entry === 'add' ? 'Add to this goal?' : 'Take out of this goal?', [goal.name, rupee(amount), occurredOn], {
    type: 'goal_money',
    goalId: goal.id,
    entry,
    amount,
    occurredOn,
    note,
  });
}

function debtProposal(action: Record<string, unknown>, context: ActionContext) {
  const debtType = debtTypes.includes(text(action.debtType) as DebtType) ? (text(action.debtType) as DebtType) : null;
  const person = clip(text(action.person), 60);
  const amount = paise(action.amount);
  const occurredOn = dateOr(action.date, context.today);
  const account = text(action.account) ? matchAccount(text(action.account), context.accounts) : context.accounts[0];
  if (!debtType || !person || !amount || !occurredOn) return incomplete('who, the amount, and lend, borrow, or a repayment');
  if (text(action.account) && !account) return incomplete('which account');
  const note = clip(text(action.note), 200);
  const lines = [`${labelDebt(debtType)} ${person}`, rupee(amount), occurredOn];
  if (account) lines.push(account.name);
  if (note) lines.push(note);
  return proposal('Record this?', lines, {
    type: 'debt',
    person,
    debtType,
    amount,
    accountId: account?.id,
    occurredOn,
    note,
  });
}

function proposal(title: string, lines: string[], action: Record<string, unknown>) {
  return { proposal: { title, lines, action } };
}

function incomplete(what: string) {
  return { proposal: null, problem: `I still need ${what} before you can accept it.` };
}

function matchAccount(wanted: string | undefined, accounts: Named[]): Named | null {
  if (!wanted) return accounts.length === 1 ? accounts[0] : null;
  return matchName(wanted, accounts);
}

function matchKind(wanted: string | undefined, categories: NamedKind[], kind: 'income' | 'expense' | null): NamedKind | null {
  const pool = kind ? categories.filter((category) => category.kind === kind) : categories;
  return matchName(wanted, pool);
}

function matchName<T extends Named>(wanted: string | undefined, items: T[]): T | null {
  if (!wanted) return null;
  const name = wanted.toLowerCase();
  const exact = items.filter((item) => item.name.toLowerCase() === name);
  if (exact.length === 1) return exact[0];
  const partial = items.filter(
    (item) => item.name.toLowerCase().includes(name) || name.includes(item.name.toLowerCase()),
  );
  return partial.length === 1 ? partial[0] : null;
}

function moneyKind(value: unknown): 'income' | 'expense' | null {
  return value === 'income' || value === 'expense' ? value : null;
}

function paise(value: unknown): number | null {
  const amount = typeof value === 'number' ? value : typeof value === 'string' ? Number(value.replace(/,/g, '')) : NaN;
  if (!Number.isFinite(amount) || amount <= 0) return null;
  return Math.round(amount * 100);
}

function number(value: unknown): number | null {
  const parsed = typeof value === 'number' ? value : typeof value === 'string' ? Number(value) : NaN;
  return Number.isInteger(parsed) ? parsed : null;
}

function text(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

function clip(value: string | undefined, max: number): string | undefined {
  return value ? value.slice(0, max) : undefined;
}

function dateOr(value: unknown, today: string): string | null {
  const given = text(value);
  if (given && day.test(given)) return given;
  return day.test(today) ? today : null;
}

function futureDate(given: string | undefined, today: string, dayOfMonth: number): string {
  if (given && day.test(given)) return given;
  const base = DateTime.fromISO(today, { zone: chatZone });
  const safeDay = Math.min(dayOfMonth, base.daysInMonth ?? dayOfMonth);
  let next = base.set({ day: safeDay });
  if (next.startOf('day') < base.startOf('day')) next = next.plus({ months: 1 }).set({ day: Math.min(dayOfMonth, next.daysInMonth ?? dayOfMonth) });
  return next.toISODate() ?? today;
}

function rupee(amount: number): string {
  return `₹${new Intl.NumberFormat('en-IN').format(amount / 100)}`;
}

function labelDebt(type: DebtType): string {
  switch (type) {
    case 'lent':
      return 'Lent to';
    case 'borrowed':
      return 'Borrowed from';
    case 'got_back':
      return 'Got back from';
    case 'paid_back':
      return 'Paid back';
  }
}

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && uuid.test(value);
}
