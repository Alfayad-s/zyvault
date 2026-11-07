import { addDays, addMonths, daysInclusive, eachDay, monthEnd, monthsUntil, weekday } from './dates.js';
import {
  defaultEssentials,
  essentialName,
  type BudgetLimit,
  type Certainty,
  type GoalItem,
  type LedgerTxn,
  type MoneyKind,
  type MonthTotals,
  type PersonBalance,
  type ProfileInput,
  type ScheduleItem,
} from './types.js';

export type ConfirmedEvent = {
  date: string;
  amount: number;
  kind: MoneyKind;
  categoryName: string;
  note: string | null;
  certainty: Certainty;
  scheduleId: string;
};

export type Overview = {
  balance: number;
  monthIncome: number;
  monthExpense: number;
  monthSavings: number;
  recurringExpense: number;
  outstandingLent: number;
  outstandingBorrowed: number;
  categories: { categoryId: string; name: string; kind: MoneyKind; total: number }[];
  budgets: { categoryId: string; categoryName: string; limitAmount: number; spent: number; usedPercent: number }[];
  upcoming: ConfirmedEvent[];
  goals: { id: string; name: string; targetAmount: number; saved: number; setAsideThisMonth: number }[];
};

export type ForecastPoint = {
  date: string;
  projectedBalance: number;
  confirmedIn: number;
  confirmedOut: number;
  estimatedIn: number;
  estimatedOut: number;
};

export type Forecast = {
  days: number;
  startBalance: number;
  endBalance: number;
  confirmedIncome: number;
  confirmedExpense: number;
  estimatedIncome: number;
  estimatedExpense: number;
  assumptions: string[];
  points: ForecastPoint[];
};

export type SafeLine = { label: string; amount: number; note: string };

export type SafeToSpend = {
  balance: number;
  safeToSpend: number;
  daily: number;
  daysLeft: number;
  lines: SafeLine[];
};

export type HealthComponent = {
  id: string;
  label: string;
  score: number | null;
  weight: number;
  detail: string;
};

export type HealthScore = {
  score: number | null;
  components: HealthComponent[];
};

export const healthWeights = {
  savingsConsistency: 20,
  expenseToIncome: 25,
  budgetDiscipline: 20,
  recurringBurden: 15,
  emergencyReserve: 20,
} as const;

export type Anomaly = {
  id: string;
  kind: 'unusual_amount' | 'unexpected_recurring' | 'spending_increase' | 'duplicate_looking' | 'unusual_category';
  severity: 'info' | 'watch';
  reason: string;
  amount: number | null;
  occurredOn: string | null;
  categoryName: string | null;
  transactionId: string | null;
};

export type ScenarioKind =
  | 'purchase'
  | 'extra_monthly'
  | 'income_change'
  | 'savings_target'
  | 'emergency'
  | 'emi';

export type ScenarioResult = {
  kind: ScenarioKind;
  amount: number;
  months: number | null;
  assumptions: string[];
  baselineEnd: number;
  scenarioEnd: number;
  delta: number;
  points: ForecastPoint[];
};

export function rupees(paise: number): string {
  const sign = paise < 0 ? '-' : '';
  const abs = Math.abs(Math.trunc(paise));
  return `${sign}₹${Math.floor(abs / 100)}.${String(abs % 100).padStart(2, '0')}`;
}

export function median(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) return Math.round((sorted[mid - 1] + sorted[mid]) / 2);
  return sorted[mid];
}

export function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[index];
}

export function occurrences(schedule: ScheduleItem, from: string, to: string): string[] {
  if (to < from) return [];
  if (schedule.repeat === 'once') {
    return schedule.nextOn >= from && schedule.nextOn <= to ? [schedule.nextOn] : [];
  }
  const dates: string[] = [];
  for (let step = 0; step < 240; step += 1) {
    const cursor = step === 0 ? schedule.nextOn : addMonths(schedule.nextOn, step, schedule.dayOfMonth);
    if (cursor > to) break;
    if (cursor >= from) dates.push(cursor);
  }
  return dates;
}

export function confirmedEvents(schedules: ScheduleItem[], from: string, to: string): ConfirmedEvent[] {
  const events: ConfirmedEvent[] = [];
  for (const schedule of schedules) {
    for (const date of occurrences(schedule, from, to)) {
      events.push({
        date,
        amount: schedule.amount,
        kind: schedule.kind,
        categoryName: schedule.categoryName,
        note: schedule.note,
        certainty: 'confirmed',
        scheduleId: schedule.id,
      });
    }
  }
  return events.sort((a, b) => a.date.localeCompare(b.date) || a.categoryName.localeCompare(b.categoryName));
}

export function lendingTotals(people: PersonBalance[]): { lent: number; borrowed: number } {
  let lent = 0;
  let borrowed = 0;
  for (const person of people) {
    if (person.balance > 0) lent += person.balance;
    else if (person.balance < 0) borrowed += -person.balance;
  }
  return { lent, borrowed };
}

export function goalSetAside(goals: GoalItem[], today: string): { id: string; name: string; targetAmount: number; saved: number; setAsideThisMonth: number }[] {
  return goals.map((goal) => {
    const remaining = Math.max(0, goal.targetAmount - goal.saved);
    let setAsideThisMonth = 0;
    if (remaining > 0 && goal.targetDate && goal.targetDate >= today.slice(0, 7)) {
      const months = monthsUntil(today, goal.targetDate);
      setAsideThisMonth = months <= 1 ? remaining : Math.floor(remaining / months);
    }
    return {
      id: goal.id,
      name: goal.name,
      targetAmount: goal.targetAmount,
      saved: goal.saved,
      setAsideThisMonth,
    };
  });
}

export function buildOverview(input: {
  today: string;
  balance: number;
  monthIncome: number;
  monthExpense: number;
  categories: { categoryId: string; name: string; kind: MoneyKind; total: number }[];
  transactions: LedgerTxn[];
  budgets: BudgetLimit[];
  schedules: ScheduleItem[];
  goals: GoalItem[];
  people: PersonBalance[];
}): Overview {
  const month = input.today.slice(0, 7);
  const spent = new Map<string, number>();
  for (const txn of input.transactions) {
    if (txn.kind === 'expense' && txn.occurredOn.startsWith(month)) {
      spent.set(txn.categoryId, (spent.get(txn.categoryId) ?? 0) + txn.amount);
    }
  }
  const lending = lendingTotals(input.people);
  const goals = goalSetAside(input.goals, input.today);
  const recurringExpense = input.schedules
    .filter((item) => item.kind === 'expense' && item.repeat === 'monthly')
    .reduce((sum, item) => sum + item.amount, 0);
  return {
    balance: input.balance,
    monthIncome: input.monthIncome,
    monthExpense: input.monthExpense,
    monthSavings: input.monthIncome - input.monthExpense,
    recurringExpense,
    outstandingLent: lending.lent,
    outstandingBorrowed: lending.borrowed,
    categories: [...input.categories].sort((a, b) => b.total - a.total),
    budgets: input.budgets.map((budget) => {
      const used = spent.get(budget.categoryId) ?? 0;
      return {
        categoryId: budget.categoryId,
        categoryName: budget.categoryName,
        limitAmount: budget.limitAmount,
        spent: used,
        usedPercent: budget.limitAmount === 0 ? 0 : Math.round((used / budget.limitAmount) * 100),
      };
    }),
    upcoming: confirmedEvents(input.schedules, input.today, addDays(input.today, 30)),
    goals,
  };
}

function samples(transactions: LedgerTxn[], today: string, kind: MoneyKind): Map<string, number[]> {
  const start = addDays(today, -56);
  const grouped = new Map<string, Map<string, number>>();
  for (const txn of transactions) {
    if (txn.kind !== kind || txn.occurredOn < start || txn.occurredOn >= today) continue;
    const key = `${txn.categoryName.toLowerCase()}|${weekday(txn.occurredOn)}`;
    const days = grouped.get(key) ?? new Map<string, number>();
    days.set(txn.occurredOn, (days.get(txn.occurredOn) ?? 0) + txn.amount);
    grouped.set(key, days);
  }
  const result = new Map<string, number[]>();
  for (const [key, days] of grouped) result.set(key, [...days.values()]);
  return result;
}

export function buildForecast(input: {
  today: string;
  days: number;
  balance: number;
  transactions: LedgerTxn[];
  schedules: ScheduleItem[];
}): Forecast {
  const days = eachDay(input.today, input.days);
  const end = days[days.length - 1] ?? input.today;
  const confirmed = confirmedEvents(input.schedules, input.today, end);
  const expenseSamples = samples(input.transactions, input.today, 'expense');
  const incomeSamples = samples(input.transactions, input.today, 'income');
  let balance = input.balance;
  const points: ForecastPoint[] = [];
  for (const date of days) {
    const dayEvents = confirmed.filter((event) => event.date === date);
    const confirmedIn = dayEvents.filter((event) => event.kind === 'income').reduce((sum, event) => sum + event.amount, 0);
    const confirmedOut = dayEvents.filter((event) => event.kind === 'expense').reduce((sum, event) => sum + event.amount, 0);
    const covered = new Set(dayEvents.filter((event) => event.kind === 'expense').map((event) => event.categoryName.toLowerCase()));
    let estimatedOut = 0;
    for (const [key, values] of expenseSamples) {
      const [category, day] = key.split('|');
      if (Number(day) !== weekday(date) || covered.has(category) || values.length < 3) continue;
      estimatedOut += median(values);
    }
    let estimatedIn = 0;
    for (const [key, values] of incomeSamples) {
      const [, day] = key.split('|');
      if (Number(day) !== weekday(date) || values.length < 3) continue;
      estimatedIn += median(values);
    }
    balance = balance + confirmedIn - confirmedOut - estimatedOut;
    points.push({ date, projectedBalance: balance, confirmedIn, confirmedOut, estimatedIn, estimatedOut });
  }
  const sum = (pick: (point: ForecastPoint) => number) => points.reduce((total, point) => total + pick(point), 0);
  return {
    days: input.days,
    startBalance: input.balance,
    endBalance: points.at(-1)?.projectedBalance ?? input.balance,
    confirmedIncome: sum((point) => point.confirmedIn),
    confirmedExpense: sum((point) => point.confirmedOut),
    estimatedIncome: sum((point) => point.estimatedIn),
    estimatedExpense: sum((point) => point.estimatedOut),
    assumptions: [
      'Confirmed lines are plans you saved.',
      'Estimated spending is the median of that weekday and category over the last eight weeks, and only when there are at least three examples.',
      'Estimated income is shown and is not added to the projected balance.',
    ],
    points,
  };
}

export function buildSafeToSpend(input: {
  today: string;
  balance: number;
  schedules: ScheduleItem[];
  goals: GoalItem[];
  profile: ProfileInput;
}): SafeToSpend {
  const end = monthEnd(input.today);
  const essentials = input.profile.essentialCategories.length > 0 ? input.profile.essentialCategories : defaultEssentials;
  const events = confirmedEvents(input.schedules, input.today, end).filter(
    (event) => event.kind === 'expense' && essentialName(event.categoryName, essentials),
  );
  const essentialTotal = events.reduce((sum, event) => sum + event.amount, 0);
  const goals = goalSetAside(input.goals, input.today);
  const goalTotal = goals.reduce((sum, goal) => sum + goal.setAsideThisMonth, 0);
  const reserve = Math.max(0, input.profile.emergencyReserve);
  const limit = input.profile.monthlyDiscretionaryLimit;
  let safe = input.balance - essentialTotal - reserve - goalTotal;
  const lines: SafeLine[] = [
    { label: 'Balance', amount: input.balance, note: 'Cash from accounts and recorded income and expenses. Lending is not included.' },
    { label: 'Essential plans before month end', amount: -essentialTotal, note: events.map((event) => `${event.date} ${event.categoryName}`).join(', ') || 'None' },
    { label: 'Emergency reserve', amount: -reserve, note: 'Kept aside and not treated as spendable.' },
    { label: 'Savings still planned this month', amount: -goalTotal, note: goals.filter((goal) => goal.setAsideThisMonth > 0).map((goal) => goal.name).join(', ') || 'None' },
  ];
  if (limit != null && safe > limit) {
    lines.push({ label: 'Your monthly limit', amount: limit - safe, note: 'The result is capped by the limit on your profile.' });
    safe = limit;
  }
  const daysLeft = daysInclusive(input.today, end);
  return {
    balance: input.balance,
    safeToSpend: safe,
    daily: Math.trunc(safe / daysLeft),
    daysLeft,
    lines,
  };
}

function clampScore(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}

export function buildHealth(input: {
  months: MonthTotals[];
  budgets: { limitAmount: number; spent: number }[];
  recurringExpense: number;
  emergencyReserve: number;
  typicalMonthlyExpense: number;
}): HealthScore {
  const withIncome = input.months.filter((month) => month.income > 0 || month.expense > 0);
  const savedMonths = withIncome.filter((month) => month.income > month.expense).length;
  const savingsScore = withIncome.length === 0 ? null : clampScore((savedMonths / withIncome.length) * 100);
  const latest = input.months.at(-1);
  const expenseScore = !latest || latest.income <= 0 ? null : clampScore((1 - latest.expense / latest.income) * 100);
  const budgetScore = input.budgets.length === 0
    ? null
    : clampScore((input.budgets.filter((item) => item.spent <= item.limitAmount).length / input.budgets.length) * 100);
  const recurringScore = !latest || latest.income <= 0 ? null : clampScore((1 - input.recurringExpense / latest.income) * 100);
  const emergencyScore = input.typicalMonthlyExpense <= 0
    ? null
    : clampScore((input.emergencyReserve / input.typicalMonthlyExpense / 3) * 100);
  const components: HealthComponent[] = [
    {
      id: 'savingsConsistency',
      label: 'Savings consistency',
      score: savingsScore,
      weight: healthWeights.savingsConsistency,
      detail: withIncome.length === 0 ? 'No months to compare yet.' : `${savedMonths} of ${withIncome.length} months had more income than spending.`,
    },
    {
      id: 'expenseToIncome',
      label: 'Spending against income',
      score: expenseScore,
      weight: healthWeights.expenseToIncome,
      detail: expenseScore == null ? 'This month has no income yet, so this part is left out.' : `Spending is ${rupees(latest?.expense ?? 0)} against income of ${rupees(latest?.income ?? 0)}.`,
    },
    {
      id: 'budgetDiscipline',
      label: 'Budget discipline',
      score: budgetScore,
      weight: healthWeights.budgetDiscipline,
      detail: budgetScore == null ? 'No budgets yet.' : `${input.budgets.filter((item) => item.spent <= item.limitAmount).length} of ${input.budgets.length} budgets are within the limit.`,
    },
    {
      id: 'recurringBurden',
      label: 'Recurring plans',
      score: recurringScore,
      weight: healthWeights.recurringBurden,
      detail: recurringScore == null ? 'This month has no income yet, so this part is left out.' : `Monthly plans total ${rupees(input.recurringExpense)}.`,
    },
    {
      id: 'emergencyReserve',
      label: 'Emergency reserve',
      score: emergencyScore,
      weight: healthWeights.emergencyReserve,
      detail: emergencyScore == null ? 'There is no recent spending to compare with the reserve.' : `${rupees(input.emergencyReserve)} covers about ${input.typicalMonthlyExpense === 0 ? 0 : Math.round((input.emergencyReserve / input.typicalMonthlyExpense) * 10) / 10} months of typical spending. Three months scores 100.`,
    },
  ];
  const active = components.filter((item) => item.score != null);
  const weight = active.reduce((sum, item) => sum + item.weight, 0);
  const score = weight === 0 ? null : clampScore(active.reduce((sum, item) => sum + (item.score ?? 0) * item.weight, 0) / weight);
  return { score, components };
}

function noteKey(note: string | null): string {
  return (note ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
}

export function detectAnomalies(transactions: LedgerTxn[], today: string): Anomaly[] {
  const found: Anomaly[] = [];
  const recentStart = addDays(today, -30);
  const ordered = [...transactions].sort((a, b) => a.occurredOn.localeCompare(b.occurredOn) || a.id.localeCompare(b.id));
  for (const txn of ordered) {
    if (txn.kind !== 'expense' || txn.occurredOn < recentStart || txn.occurredOn > today) continue;
    const history = ordered.filter((item) => item.id !== txn.id && item.categoryId === txn.categoryId && item.kind === 'expense' && item.occurredOn < txn.occurredOn);
    if (history.length >= 8) {
      const amounts = history.map((item) => item.amount);
      const mid = median(amounts);
      const high = percentile(amounts, 90);
      if (txn.amount > high && txn.amount > mid * 2) {
        found.push({
          id: `amount:${txn.id}`,
          kind: 'unusual_amount',
          severity: 'watch',
          reason: `${txn.categoryName} is above your usual range for that category. This is not a fraud warning.`,
          amount: txn.amount,
          occurredOn: txn.occurredOn,
          categoryName: txn.categoryName,
          transactionId: txn.id,
        });
      }
    }
    const duplicate = ordered.find((item) =>
      item.id < txn.id
      && item.accountId === txn.accountId
      && item.amount === txn.amount
      && item.kind === txn.kind
      && item.occurredOn === txn.occurredOn
      && noteKey(item.note) === noteKey(txn.note));
    if (duplicate) {
      found.push({
        id: `duplicate:${txn.id}`,
        kind: 'duplicate_looking',
        severity: 'info',
        reason: 'Another line on the same day has the same account, amount and note. It may be a repeat, or two real payments.',
        amount: txn.amount,
        occurredOn: txn.occurredOn,
        categoryName: txn.categoryName,
        transactionId: txn.id,
      });
    }
  }

  const month = today.slice(0, 7);
  const previous = addMonths(`${month}-01`, -1).slice(0, 7);
  const byCategory = new Map<string, { name: string; current: number; previous: number }>();
  for (const txn of ordered) {
    if (txn.kind !== 'expense') continue;
    const bucket = txn.occurredOn.slice(0, 7);
    if (bucket !== month && bucket !== previous) continue;
    const row = byCategory.get(txn.categoryId) ?? { name: txn.categoryName, current: 0, previous: 0 };
    if (bucket === month) row.current += txn.amount;
    else row.previous += txn.amount;
    byCategory.set(txn.categoryId, row);
  }
  for (const [categoryId, row] of byCategory) {
    const jump = row.current - row.previous;
    if (row.previous >= 10_000 && jump >= 50_000 && row.current > row.previous * 1.5) {
      found.push({
        id: `jump:${categoryId}:${month}`,
        kind: 'spending_increase',
        severity: 'watch',
        reason: `${row.name} is higher than last month. Compare the lines before treating it as a problem.`,
        amount: jump,
        occurredOn: today,
        categoryName: row.name,
        transactionId: null,
      });
    }
  }

  const windowStart = addMonths(today, -3).slice(0, 7);
  const olderEnd = windowStart;
  const groups = new Map<string, { amount: number; categoryName: string; months: Set<string>; older: boolean }>();
  for (const txn of ordered) {
    if (txn.kind !== 'expense') continue;
    const key = noteKey(txn.note);
    if (key.length < 3) continue;
    const groupKey = `${key}|${txn.amount}`;
    const group = groups.get(groupKey) ?? { amount: txn.amount, categoryName: txn.categoryName, months: new Set<string>(), older: false };
    if (txn.occurredOn.slice(0, 7) < olderEnd) group.older = true;
    else if (txn.occurredOn.slice(0, 7) >= windowStart && txn.occurredOn <= today) group.months.add(txn.occurredOn.slice(0, 7));
    groups.set(groupKey, group);
  }
  for (const [key, group] of groups) {
    if (!group.older && group.months.size >= 2) {
      found.push({
        id: `recurring:${key}`,
        kind: 'unexpected_recurring',
        severity: 'info',
        reason: 'The same note and amount showed up in two recent months and not before that. It may be a new plan.',
        amount: group.amount,
        occurredOn: null,
        categoryName: group.categoryName,
        transactionId: null,
      });
    }
  }
  return found;
}

export function applyScenario(forecast: Forecast, input: { kind: ScenarioKind; amount: number; months?: number | null }): ScenarioResult {
  const months = input.months ?? null;
  const points = forecast.points.map((point) => ({ ...point }));
  const assumptions = [...forecast.assumptions, 'This is a what-if. Nothing is saved to your accounts.'];
  const seenMonths = new Set<string>();
  let monthIndex = -1;
  for (const point of points) {
    const month = point.date.slice(0, 7);
    const firstOfMonth = !seenMonths.has(month);
    if (firstOfMonth) {
      seenMonths.add(month);
      monthIndex += 1;
    }
    if ((input.kind === 'purchase' || input.kind === 'emergency') && point.date === points[0]?.date) {
      point.confirmedOut += input.amount;
    }
    if (firstOfMonth && (input.kind === 'extra_monthly' || input.kind === 'savings_target')) {
      point.confirmedOut += input.amount;
    }
    if (firstOfMonth && input.kind === 'income_change') {
      point.confirmedIn += input.amount;
    }
    if (firstOfMonth && input.kind === 'emi' && (months == null || monthIndex < months)) {
      point.confirmedOut += input.amount;
    }
  }
  let balance = forecast.startBalance;
  for (const point of points) {
    balance = balance + point.confirmedIn - point.confirmedOut - point.estimatedOut;
    point.projectedBalance = balance;
  }
  const label: Record<ScenarioKind, string> = {
    purchase: 'A one-time purchase is taken off the first day.',
    emergency: 'A one-time emergency cost is taken off the first day.',
    extra_monthly: 'Extra spending is taken off once each month in the forecast.',
    savings_target: 'A savings set-aside is taken off once each month in the forecast.',
    income_change: 'The income change is an assumption, not guaranteed pay.',
    emi: 'The EMI is taken off once each month for the number of months you set.',
  };
  assumptions.push(label[input.kind]);
  const scenarioEnd = points.at(-1)?.projectedBalance ?? forecast.startBalance;
  return {
    kind: input.kind,
    amount: input.amount,
    months,
    assumptions,
    baselineEnd: forecast.endBalance,
    scenarioEnd,
    delta: scenarioEnd - forecast.endBalance,
    points,
  };
}

export type InsightDraft = {
  title: string;
  body: string;
  evidence: { label: string; amount: number | null }[];
};

export function buildInsights(overview: Overview, health: HealthScore, anomalies: Anomaly[], safe: SafeToSpend): InsightDraft[] {
  const top = overview.categories.find((item) => item.kind === 'expense');
  const drafts: InsightDraft[] = [
    {
      title: 'This month',
      body: `Income ${rupees(overview.monthIncome)}, spending ${rupees(overview.monthExpense)}, left ${rupees(overview.monthSavings)}.`,
      evidence: [
        { label: 'Income', amount: overview.monthIncome },
        { label: 'Spending', amount: overview.monthExpense },
      ],
    },
    {
      title: 'Safe to spend',
      body: `${rupees(safe.safeToSpend)} can be spent by month end, about ${rupees(safe.daily)} a day. Estimated income is not included.`,
      evidence: safe.lines.map((line) => ({ label: line.label, amount: line.amount })),
    },
  ];
  if (top) {
    drafts.push({
      title: 'Largest category',
      body: `${top.name} is the largest spending category this month at ${rupees(top.total)}.`,
      evidence: [{ label: top.name, amount: top.total }],
    });
  }
  if (health.score != null) {
    drafts.push({
      title: 'Financial health',
      body: `The score is ${health.score} out of 100 from the weighted parts that have enough data.`,
      evidence: health.components.filter((item) => item.score != null).map((item) => ({ label: item.label, amount: item.score })),
    });
  }
  if (anomalies.length > 0) {
    drafts.push({
      title: 'Worth a look',
      body: `${anomalies.length} line${anomalies.length === 1 ? '' : 's'} look unusual compared with your own history. None of these are fraud alerts.`,
      evidence: anomalies.slice(0, 5).map((item) => ({ label: item.kind, amount: item.amount })),
    });
  }
  return drafts;
}

export function monthBuckets(transactions: LedgerTxn[], today: string, count: number): MonthTotals[] {
  const buckets: MonthTotals[] = [];
  for (let index = count - 1; index >= 0; index -= 1) {
    const month = addMonths(`${today.slice(0, 7)}-01`, -index).slice(0, 7);
    let income = 0;
    let expense = 0;
    for (const txn of transactions) {
      if (!txn.occurredOn.startsWith(month)) continue;
      if (txn.kind === 'income') income += txn.amount;
      else expense += txn.amount;
    }
    buckets.push({ month, income, expense });
  }
  return buckets;
}
