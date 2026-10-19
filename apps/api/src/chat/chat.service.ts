import { BadRequestException, Injectable } from '@nestjs/common';
import type { Account } from '../accounts/accounts.service.js';
import { AccountsService } from '../accounts/accounts.service.js';
import { LlmClient } from '../agent/llm.client.js';
import { rupees } from '../ask/ask.js';
import type { Budget } from '../budgets/budgets.service.js';
import { BudgetsService } from '../budgets/budgets.service.js';
import type { Category } from '../categories/categories.service.js';
import { CategoriesService } from '../categories/categories.service.js';
import { DebtsService } from '../debts/debts.service.js';
import type { Goal } from '../goals/goals.js';
import { GoalsService } from '../goals/goals.service.js';
import { SchedulesService } from '../schedules/schedules.service.js';
import type { Summary } from '../summary/summary.js';
import { SummaryService } from '../summary/summary.service.js';
import type { Transaction } from '../transactions/transactions.service.js';
import { TransactionsService } from '../transactions/transactions.service.js';
import { isUuid, readChatTurn, resolveAction } from './chat-action.js';
import { describeNow } from './chat-clock.js';
import { buildChatInstruction, recentMessages } from './chat-prompt.js';
import type { ChatDto } from './dto/chat.dto.js';

@Injectable()
export class ChatService {
  constructor(
    private readonly llm: LlmClient,
    private readonly summary: SummaryService,
    private readonly accounts: AccountsService,
    private readonly budgets: BudgetsService,
    private readonly transactions: TransactionsService,
    private readonly categories: CategoriesService,
    private readonly goals: GoalsService,
    private readonly debts: DebtsService,
    private readonly schedules: SchedulesService,
  ) {}

  async reply(userId: string, body: ChatDto): Promise<{ reply: string; proposal: unknown }> {
    const messages = recentMessages(body.messages);
    if (messages.length === 0 || messages.at(-1)?.role !== 'user') {
      throw new BadRequestException('Send a message');
    }
    const month = body.today.slice(0, 7);
    const [summary, accounts, budgets, recent, categories, goals] = await Promise.all([
      this.summary.forMonth(userId, month),
      this.accounts.list(userId),
      this.budgets.list(userId, month).catch(() => []),
      this.transactions.list(userId, month, 8).catch(() => []),
      this.categories.list(userId).catch(() => []),
      this.goals.list(userId).catch(() => []),
    ]);
    const instruction = buildChatInstruction({
      clock: describeNow(body.today),
      balance: rupees(summary.balance),
      monthIncome: rupees(summary.monthIncome),
      monthExpense: rupees(summary.monthExpense),
      categories: categoryLines(summary),
      accounts: accountLines(accounts),
      budgets: budgetLines(budgets),
      recent: recentLines(recent),
      memory: body.memory,
      expenseCategories: categories.filter((category) => category.kind === 'expense').map((category) => category.name),
      incomeCategories: categories.filter((category) => category.kind === 'income').map((category) => category.name),
      goals: goals.map((goal) => `${goal.id} ${goal.name}`),
    });
    const text = await this.llm.chat(instruction, messages);
    const parsed = readChatTurn(text);
    const resolved = resolveAction(parsed.action, {
      today: body.today,
      accounts,
      categories,
      goals,
      transactionIds: recent.map((transaction) => transaction.id),
    });
    const reply = resolved.problem ?? parsed.reply;
    return { reply, proposal: resolved.proposal };
  }

  async apply(userId: string, action: Record<string, unknown>): Promise<{ saved: true }> {
    switch (action.type) {
      case 'log':
        await this.applyLog(userId, action);
        break;
      case 'schedule':
        await this.applySchedule(userId, action);
        break;
      case 'budget':
        await this.budgets.upsert(userId, {
          categoryId: requiredUuid(action.categoryId),
          month: requiredMonth(action.month),
          limitAmount: requiredAmount(action.limitAmount),
        });
        break;
      case 'goal':
        await this.applyGoal(userId, action);
        break;
      case 'goal_money':
        await this.goals.addEntry(userId, requiredUuid(action.goalId), {
          type: action.entry === 'take_out' ? 'take_out' : 'add',
          amount: requiredAmount(action.amount),
          occurredOn: requiredDate(action.occurredOn),
          note: optionalText(action.note),
        });
        break;
      case 'debt':
        await this.debts.create(userId, {
          person: requiredText(action.person, 60),
          type: requiredDebt(action.debtType),
          amount: requiredAmount(action.amount),
          accountId: optionalUuid(action.accountId),
          occurredOn: requiredDate(action.occurredOn),
          note: optionalText(action.note),
        });
        break;
      default:
        throw new BadRequestException('Nothing to save');
    }
    return { saved: true };
  }

  private applyLog(userId: string, action: Record<string, unknown>) {
    const input = {
      accountId: requiredUuid(action.accountId),
      categoryId: requiredUuid(action.categoryId),
      amount: requiredAmount(action.amount),
      kind: requiredKind(action.kind),
      occurredOn: requiredDate(action.occurredOn),
      note: optionalText(action.note),
    };
    return action.id
      ? this.transactions.update(userId, requiredUuid(action.id), input)
      : this.transactions.create(userId, input);
  }

  private applySchedule(userId: string, action: Record<string, unknown>) {
    const repeat = action.repeat === 'monthly' || action.repeat === 'once' ? action.repeat : null;
    const dayOfMonth = typeof action.dayOfMonth === 'number' ? action.dayOfMonth : 0;
    if (!repeat || dayOfMonth < 1 || dayOfMonth > 31) throw new BadRequestException('Nothing to save');
    return this.schedules.create(userId, {
      accountId: requiredUuid(action.accountId),
      categoryId: requiredUuid(action.categoryId),
      amount: requiredAmount(action.amount),
      kind: requiredKind(action.kind),
      note: optionalText(action.note) ?? null,
      repeat,
      dayOfMonth,
      nextOn: requiredDate(action.nextOn),
      atTime: typeof action.atTime === 'string' ? action.atTime : null,
    });
  }

  private applyGoal(userId: string, action: Record<string, unknown>) {
    const input = {
      name: requiredText(action.name, 40),
      icon: typeof action.icon === 'string' ? action.icon : 'goal-target',
      targetAmount: requiredAmount(action.targetAmount),
      targetDate: typeof action.targetDate === 'string' ? action.targetDate : null,
    };
    return action.id ? this.goals.update(userId, requiredUuid(action.id), input) : this.goals.create(userId, input);
  }
}

function categoryLines(summary: Summary): string[] {
  return summary.categories
    .filter((category) => category.kind === 'expense')
    .slice(0, 5)
    .map((category) => `${category.name} ${rupees(category.total)}`);
}

function accountLines(accounts: Account[]): string[] {
  return accounts.slice(0, 6).map((account) => `${account.name} ${rupees(account.balance ?? account.openingBalance)}`);
}

function recentLines(transactions: Transaction[]): string[] {
  return transactions.slice(0, 8).map((transaction) => {
    const note = transaction.note?.trim();
    const label = note ? `${note} (${transaction.categoryName})` : transaction.categoryName;
    return `${transaction.id} ${transaction.occurredOn} ${label} ${rupees(transaction.amount)}`;
  });
}

function budgetLines(budgets: Budget[]): string[] {
  return budgets
    .slice(0, 6)
    .map((budget) => `${budget.categoryName} spent ${rupees(budget.spent)} of ${rupees(budget.limitAmount)}`);
}

function requiredUuid(value: unknown): string {
  if (!isUuid(value)) throw new BadRequestException('Nothing to save');
  return value;
}

function optionalUuid(value: unknown): string | undefined {
  if (value == null || value === '') return undefined;
  return requiredUuid(value);
}

function requiredAmount(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 1) throw new BadRequestException('Nothing to save');
  return value;
}

function requiredDate(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new BadRequestException('Nothing to save');
  return value;
}

function requiredMonth(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(value)) throw new BadRequestException('Nothing to save');
  return value;
}

function requiredKind(value: unknown): 'income' | 'expense' {
  if (value !== 'income' && value !== 'expense') throw new BadRequestException('Nothing to save');
  return value;
}

function requiredText(value: unknown, max: number): string {
  if (typeof value !== 'string' || !value.trim()) throw new BadRequestException('Nothing to save');
  return value.trim().slice(0, max);
}

function optionalText(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim().slice(0, 200) : undefined;
}

function requiredDebt(value: unknown): 'lent' | 'borrowed' | 'got_back' | 'paid_back' {
  if (value !== 'lent' && value !== 'borrowed' && value !== 'got_back' && value !== 'paid_back') {
    throw new BadRequestException('Nothing to save');
  }
  return value;
}
