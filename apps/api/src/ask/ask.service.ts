import {
  Inject,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { AccountsService, type Account } from '../accounts/accounts.service.js';
import { accountLabel, matchAccount } from '../agent/ai-agent.service.js';
import { BudgetsService, type Budget } from '../budgets/budgets.service.js';
import { LlmClient } from '../agent/llm.client.js';
import { readLlmJson } from '../agent/spend.js';
import { CategoriesService } from '../categories/categories.service.js';
import { personKey } from '../debts/debts.js';
import { DebtsService } from '../debts/debts.service.js';
import { matchGoal } from '../goals/goals.js';
import { GoalsService } from '../goals/goals.service.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import {
  byCategory,
  compareText,
  filterRows,
  previousPeriod,
  readPlan,
  rupees,
  scope,
  series,
  shortDate,
  sum,
  thisYearMonth,
  type AskAnswer,
  type AskPlan,
  type AskRow,
} from './ask.js';
import { askInstruction, buildAskPrompt } from './ask-prompt.js';

type Relation = { name: string } | { name: string }[] | null;

type TransactionRow = {
  amount: number;
  kind: 'income' | 'expense';
  occurred_on: string;
  note: string | null;
  account_id: string;
  category: Relation;
  account: Relation;
};

const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function name(value: Relation): string {
  if (!value) return '';
  return Array.isArray(value) ? (value[0]?.name ?? '') : value.name;
}

@Injectable()
export class AskService {
  private readonly logger = new Logger(AskService.name);

  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly llm: LlmClient,
    private readonly categories: CategoriesService,
    private readonly accounts: AccountsService,
    private readonly debts: DebtsService,
    private readonly goals: GoalsService,
    private readonly budgets: BudgetsService,
  ) {}

  async ask(userId: string, question: string, today: string): Promise<AskAnswer> {
    const [categories, accounts, debts, goals] = await Promise.all([
      this.categories.list(userId),
      this.accounts.list(userId),
      this.debts.list(userId).catch(() => ({ people: [], entries: [] })),
      this.goals.list(userId).catch(() => []),
    ]);
    const prompt = buildAskPrompt({
      question,
      today,
      weekday: weekdays[new Date(`${today}T00:00:00Z`).getUTCDay()],
      expense: categories.filter((item) => item.kind === 'expense').map((item) => item.name),
      income: categories.filter((item) => item.kind === 'income').map((item) => item.name),
      accounts: accounts.map(accountLabel),
      people: debts.people.map((person) => person.name),
      goals: goals.map((goal) => goal.name),
    });
    let plan: AskPlan;
    try {
      plan = thisYearMonth(
        readPlan(readLlmJson(await this.llm.complete(askInstruction, prompt))[0], today),
        today,
        question,
      );
    } catch (caught) {
      if (caught instanceof ServiceUnavailableException) throw caught;
      this.logger.warn(`Ask plan was not JSON: ${String(caught)}`);
      throw new ServiceUnavailableException('The AI could not read that question');
    }
    this.logger.log(`Ask "${question}" → ${plan.intent} ${plan.from}..${plan.to}`);
    const account = plan.account ? matchAccount(plan.account, accounts) : null;

    switch (plan.intent) {
      case 'spending':
      case 'income':
        return this.total(userId, plan, account);
      case 'breakdown':
        return this.breakdown(userId, plan, account);
      case 'transactions':
        return this.transactions(userId, plan, account);
      case 'balance':
        return balanceAnswer(plan, accounts, account);
      case 'people':
        return peopleAnswer(plan, debts.people);
      case 'goals':
        return goalsAnswer(plan, goals);
      case 'budgets':
        return budgetsAnswer(plan, await this.budgets.list(userId, plan.to.slice(0, 7)));
      case 'unknown':
        return {
          answer:
            'I can tell you what you spent or received, where your money went, your balances, who owes whom, and how your goals are doing.',
          chart: null,
          items: [],
          plan,
        };
    }
  }

  private async rows(userId: string, from: string, to: string): Promise<AskRow[]> {
    const rows = await allRows<TransactionRow>((start, end) =>
      this.supabase
        .from('transactions')
        .select(
          'amount, kind, occurred_on, note, account_id, category:categories(name), account:accounts(name)',
        )
        .eq('user_id', userId)
        .gte('occurred_on', from)
        .lte('occurred_on', to)
        .order('id')
        .range(start, end),
    );
    return rows.map((row) => ({
      amount: row.amount,
      kind: row.kind,
      occurredOn: row.occurred_on,
      note: row.note,
      categoryName: name(row.category),
      accountId: row.account_id,
      accountName: name(row.account),
    }));
  }

  private async total(userId: string, plan: AskPlan, account: Account | null): Promise<AskAnswer> {
    const kind = plan.intent === 'income' ? 'income' : 'expense';
    const rows = filterRows(await this.rows(userId, plan.from, plan.to), plan, kind, account?.id ?? null);
    const total = sum(rows);
    const verb = kind === 'income' ? 'received' : 'spent';
    let answer =
      rows.length === 0
        ? `You ${verb} nothing${scope(plan, account?.name ?? null)} ${plan.label}.`
        : `You ${verb} ${rupees(total)}${scope(plan, account?.name ?? null)} ${plan.label} in ${rows.length} ${rows.length === 1 ? 'payment' : 'payments'}.`;
    if (plan.compare) {
      const before = previousPeriod(plan.from, plan.to);
      const earlier = filterRows(await this.rows(userId, before.from, before.to), plan, kind, account?.id ?? null);
      answer += compareText(total, sum(earlier));
    }
    const categories = byCategory(rows);
    return {
      answer,
      chart: rows.length === 0 ? null : series(rows, plan.from, plan.to),
      items:
        plan.categories.length === 1
          ? []
          : categories.slice(0, 5).map((point) => ({
              label: point.label,
              value: point.value,
              categoryName: point.categoryName,
              kind: point.kind,
            })),
      plan,
    };
  }

  private async breakdown(userId: string, plan: AskPlan, account: Account | null): Promise<AskAnswer> {
    const rows = filterRows(await this.rows(userId, plan.from, plan.to), { ...plan, categories: [] }, 'expense', account?.id ?? null);
    const categories = byCategory(rows);
    const total = sum(rows);
    if (categories.length === 0) {
      return { answer: `No spending ${plan.label} yet.`, chart: null, items: [], plan };
    }
    const top = categories
      .slice(0, 3)
      .map((point) => `${point.label} ${rupees(point.value)} (${Math.round((point.value / total) * 100)}%)`)
      .join(', ');
    return {
      answer: `You spent ${rupees(total)} ${plan.label}. Most went to ${top}.`,
      chart: categories.slice(0, 8),
      items: categories.map((point) => ({
        label: point.label,
        value: point.value,
        detail: `${Math.round((point.value / total) * 100)}%`,
        categoryName: point.categoryName,
        kind: point.kind,
      })),
      plan,
    };
  }

  private async transactions(userId: string, plan: AskPlan, account: Account | null): Promise<AskAnswer> {
    const all = await this.rows(userId, plan.from, plan.to);
    const kindAsked = plan.categories.some((category) =>
      all.some((row) => row.kind === 'income' && row.categoryName.toLowerCase() === category.toLowerCase()),
    );
    const rows = filterRows(all, plan, kindAsked ? 'income' : 'expense', account?.id ?? null).sort((a, b) =>
      plan.sort === 'biggest'
        ? b.amount - a.amount
        : b.occurredOn.localeCompare(a.occurredOn),
    );
    const shown = rows.slice(0, plan.limit);
    if (shown.length === 0) {
      return { answer: `No payments like that ${plan.label}.`, chart: null, items: [], plan };
    }
    const what = plan.sort === 'biggest' ? 'biggest' : 'latest';
    return {
      answer: `Your ${what} ${shown.length === 1 ? 'payment' : `${shown.length} payments`}${scope(plan, account?.name ?? null)} ${plan.label}, ${rupees(sum(shown))} in total.`,
      chart: null,
      items: shown.map((row) => ({
        label: row.note || row.categoryName,
        value: row.amount,
        detail: `${shortDate(row.occurredOn)} · ${row.accountName}`,
        categoryName: row.categoryName,
        kind: row.kind,
      })),
      plan,
    };
  }
}

export function balanceAnswer(plan: AskPlan, accounts: Account[], account: Account | null): AskAnswer {
  const shown = account ? [account] : accounts;
  const total = shown.reduce((sumSoFar, item) => sumSoFar + (item.balance ?? item.openingBalance), 0);
  const answer = account
    ? `${account.name} has ${total < 0 ? '-' : ''}${rupees(total)}.`
    : `You have ${total < 0 ? '-' : ''}${rupees(total)} across ${accounts.length} ${accounts.length === 1 ? 'account' : 'accounts'}.`;
  return {
    answer,
    chart: null,
    items: shown.map((item) => ({
      label: item.name,
      value: item.balance ?? item.openingBalance,
      detail: item.type === 'cash' ? 'Cash' : 'Bank',
    })),
    plan,
  };
}

export function peopleAnswer(
  plan: AskPlan,
  people: { name: string; balance: number }[],
): AskAnswer {
  const wanted = plan.person ? personKey(plan.person) : null;
  const match = wanted
    ? people.find((person) => personKey(person.name) === wanted) ??
      people.find((person) => personKey(person.name).includes(wanted))
    : null;
  if (plan.person && !match) {
    return { answer: `You have no lending or borrowing with ${plan.person}.`, chart: null, items: [], plan };
  }
  const shown = (match ? [match] : people).filter((person) => match || person.balance !== 0);
  const owedToYou = shown.filter((person) => person.balance > 0);
  const youOwe = shown.filter((person) => person.balance < 0);
  const describe = (person: { name: string; balance: number }) =>
    person.balance > 0
      ? `${person.name} owes you ${rupees(person.balance)}`
      : person.balance < 0
        ? `you owe ${person.name} ${rupees(person.balance)}`
        : `you and ${person.name} are settled`;
  let answer: string;
  if (match) {
    answer = `${describe(match).replace(/^./, (char) => char.toUpperCase())}.`;
  } else if (shown.length === 0) {
    answer = 'Nobody owes you and you owe nobody.';
  } else {
    const parts = [];
    if (owedToYou.length) parts.push(`${rupees(owedToYou.reduce((s, p) => s + p.balance, 0))} is owed to you`);
    if (youOwe.length) parts.push(`you owe ${rupees(youOwe.reduce((s, p) => s + p.balance, 0))}`);
    answer = `${parts.join(' and ')}.`.replace(/^./, (char) => char.toUpperCase());
  }
  return {
    answer,
    chart: null,
    items: shown.map((person) => ({
      label: person.name,
      value: person.balance,
      detail: person.balance > 0 ? 'owes you' : person.balance < 0 ? 'you owe' : 'settled',
      iconKey: person.balance >= 0 ? 'lent' : 'borrowed',
    })),
    plan,
  };
}

export function goalsAnswer(
  plan: AskPlan,
  goals: { name: string; icon: string | null; saved: number; targetAmount: number }[],
): AskAnswer {
  const match = plan.goal ? matchGoal(plan.goal, goals) : null;
  if (goals.length === 0) {
    return { answer: 'You have no savings goals yet. Add one on Home.', chart: null, items: [], plan };
  }
  if (plan.goal && !match) {
    return { answer: `You have no goal called ${plan.goal}.`, chart: null, items: [], plan };
  }
  const shown = match ? [match] : goals;
  const percent = (goal: (typeof goals)[number]) =>
    Math.min(100, Math.round((goal.saved / goal.targetAmount) * 100));
  const answer = match
    ? match.saved >= match.targetAmount
      ? `${match.name} is done: ${rupees(match.saved)} saved.`
      : `${match.name}: ${rupees(match.saved)} of ${rupees(match.targetAmount)} saved (${percent(match)}%), ${rupees(match.targetAmount - match.saved)} to go.`
    : `You have saved ${rupees(goals.reduce((s, goal) => s + goal.saved, 0))} across ${goals.length} ${goals.length === 1 ? 'goal' : 'goals'}.`;
  return {
    answer,
    chart: null,
    items: shown.map((goal) => ({
      label: goal.name,
      value: goal.saved,
      detail: `${percent(goal)}% of ${rupees(goal.targetAmount)}`,
      iconKey: goal.icon ?? 'goal-target',
    })),
    plan,
  };
}

export function budgetsAnswer(plan: AskPlan, budgets: Budget[]): AskAnswer {
  const wanted = new Set(plan.categories.map((name) => name.toLowerCase()));
  const shown = wanted.size
    ? budgets.filter((budget) => wanted.has(budget.categoryName.toLowerCase()))
    : budgets;
  if (budgets.length === 0) {
    return {
      answer: 'You have no budgets yet. Set one from the Budgets card on Home.',
      chart: null,
      items: [],
      plan,
    };
  }
  if (shown.length === 0) {
    return { answer: `There is no budget for ${plan.categories.join(', ')}.`, chart: null, items: [], plan };
  }
  const over = shown.filter((budget) => budget.spent > budget.limitAmount);
  const percent = (budget: Budget) => Math.round((budget.spent / budget.limitAmount) * 100);
  let answer: string;
  if (shown.length === 1) {
    const [budget] = shown;
    answer =
      budget.spent > budget.limitAmount
        ? `${budget.categoryName} is over budget by ${rupees(budget.spent - budget.limitAmount)} (${rupees(budget.spent)} of ${rupees(budget.limitAmount)}).`
        : `${budget.categoryName}: ${rupees(budget.limitAmount - budget.spent)} left of ${rupees(budget.limitAmount)} (${percent(budget)}% used).`;
  } else {
    const limit = shown.reduce((sum, budget) => sum + budget.limitAmount, 0);
    const spent = shown.reduce((sum, budget) => sum + budget.spent, 0);
    answer =
      over.length === 0
        ? `You are within all ${shown.length} budgets: ${rupees(spent)} of ${rupees(limit)} used.`
        : `Over budget on ${over.map((budget) => `${budget.categoryName} by ${rupees(budget.spent - budget.limitAmount)}`).join(', ')}. ${rupees(spent)} of ${rupees(limit)} used in total.`;
  }
  return {
    answer,
    chart: null,
    items: [...shown]
      .sort((a, b) => b.spent / b.limitAmount - a.spent / a.limitAmount)
      .map((budget) => ({
        label: budget.categoryName,
        value: budget.spent,
        detail: `${percent(budget)}% of ${rupees(budget.limitAmount)}`,
        categoryName: budget.categoryName,
        kind: 'expense',
      })),
    plan,
  };
}
