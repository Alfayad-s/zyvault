import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AccountsService, type Account } from '../accounts/accounts.service.js';
import { banks } from '../banks/banks.js';
import { CategoriesService, type Category } from '../categories/categories.service.js';
import type { Goal } from '../goals/goals.js';
import { GoalsService } from '../goals/goals.service.js';
import { TransactionsService } from '../transactions/transactions.service.js';
import { LlmClient, type BillImage } from './llm.client.js';
import { buildUserPrompt, memoryFrom, receiptInstruction, systemInstruction } from './prompt.js';
import {
  broaderCategory,
  categoryNameFor,
  expenseLabels,
  incomeLabels,
  normalizeSpends,
  readLlmJson,
  type ParsedSpend,
} from './spend.js';
import { ZeroShotClient } from './zero-shot.client.js';

export type CategorySource = 'llm' | 'zero-shot' | 'fallback';

export type CategorizedSpend = ParsedSpend & {
  categoryId: string;
  categoryName: string;
  source: CategorySource;
  confidence: number | null;
  accountId: string | null;
  accountName: string | null;
};

export function accountLabel(account: Account): string {
  if (account.type === 'cash') return `${account.name} (cash)`;
  const bank = banks.find((item) => item.id === account.bankId);
  return bank ? `${account.name} (${bank.name}, ${bank.short})` : `${account.name} (bank)`;
}

export function matchAccount(answer: string | null, accounts: Account[]): Account | null {
  if (!answer) return null;
  const wanted = answer.toLowerCase().replace(/\s*\(.*\)\s*$/, '').trim();
  const exact = accounts.find((account) => account.name.toLowerCase() === wanted);
  if (exact) return exact;
  if (wanted === 'cash') return accounts.find((account) => account.type === 'cash') ?? null;
  const bank = banks.find(
    (item) => item.id !== 'other' && (item.short.toLowerCase() === wanted || item.name.toLowerCase() === wanted),
  );
  if (bank) {
    const byBank = accounts.find((account) => account.bankId === bank.id);
    if (byBank) return byBank;
  }
  const partial = accounts.filter(
    (account) => account.name.toLowerCase().includes(wanted) || wanted.includes(account.name.toLowerCase()),
  );
  return partial.length === 1 ? partial[0] : null;
}

function accountWords(account: Account): string[] {
  if (account.type === 'cash') return [account.name.toLowerCase(), 'cash'];
  const bank = banks.find((item) => item.id === account.bankId);
  return [account.name.toLowerCase(), bank?.name.toLowerCase(), bank?.short.toLowerCase()].filter(
    (word): word is string => Boolean(word && word !== 'other bank'),
  );
}

function mentions(text: string, account: Account): boolean {
  return accountWords(account).some((word) =>
    new RegExp(`(^|[^a-z])${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}([^a-z]|$)`).test(text),
  );
}

export function accountNearAmount(sentence: string, amount: number, accounts: Account[]): Account | null {
  const text = sentence.toLowerCase();
  const rupees = String(amount / 100);
  const numbers = [...text.matchAll(/\d[\d,]*(?:\.\d+)?/g)];
  const index = numbers.findIndex((match) => match[0].replace(/,/g, '') === rupees);
  if (index < 0) return null;
  const at = numbers[index];
  const after = text.slice((at.index ?? 0) + at[0].length, numbers[index + 1]?.index ?? text.length);
  const before = text.slice(numbers[index - 1] ? (numbers[index - 1].index ?? 0) + numbers[index - 1][0].length : 0, at.index);
  for (const part of [after, before]) {
    const found = accounts.filter((account) => mentions(part, account));
    if (found.length === 1) return found[0];
  }
  return null;
}

@Injectable()
export class AIAgentService {
  private readonly logger = new Logger(AIAgentService.name);

  constructor(
    private readonly llm: LlmClient,
    private readonly zeroShot: ZeroShotClient,
    private readonly categories: CategoriesService,
    private readonly transactions: TransactionsService,
    private readonly accounts: AccountsService,
    private readonly goals: GoalsService,
  ) {}

  async parse(
    userId: string,
    text: string,
    today: string,
    image?: BillImage,
    now?: string,
  ): Promise<CategorizedSpend[]> {
    const [categories, history, accounts, goals] = await Promise.all([
      this.categories.list(userId),
      this.transactions.list(userId, undefined, 200).catch((caught: unknown) => {
        this.logger.warn(`Could not load spend history: ${String(caught)}`);
        return [];
      }),
      this.accounts.list(userId).catch((caught: unknown) => {
        this.logger.warn(`Could not load accounts: ${String(caught)}`);
        return [] as Account[];
      }),
      this.goals.list(userId).catch((caught: unknown) => {
        this.logger.warn(`Could not load goals: ${String(caught)}`);
        return [] as Goal[];
      }),
    ]);
    const names = {
      expense: categories.filter((item) => item.kind === 'expense').map((item) => item.name),
      income: categories.filter((item) => item.kind === 'income').map((item) => item.name),
    };
    const prompt = buildUserPrompt({
      sentence: text,
      today,
      now,
      categories: names,
      memory: memoryFrom(history),
      receipt: image !== undefined,
      accounts: accounts.length > 1 ? accounts.map(accountLabel) : undefined,
      goals: goals.map((goal) => goal.name),
    });
    const reply = await this.llm.complete(
      image ? receiptInstruction : systemInstruction,
      prompt,
      image,
    );
    let spends: ParsedSpend[];
    try {
      spends = normalizeSpends(readLlmJson(reply), today, !image, now);
    } catch (caught) {
      this.logger.warn(`LLM reply was not JSON: ${String(caught)}`);
      throw new ServiceUnavailableException('The AI parser returned an unreadable reply');
    }
    if (spends.length === 0) {
      throw new BadRequestException('No amount found in that sentence');
    }
    const categorized = await Promise.all(
      spends.map((spend) => this.categorize(spend, categories)),
    );
    return categorized.map((spend) => {
      const account =
        matchAccount(spend.account, accounts) ??
        (image || accounts.length < 2 ? null : accountNearAmount(text, spend.amount, accounts));
      return { ...spend, accountId: account?.id ?? null, accountName: account?.name ?? null };
    });
  }

  private async categorize(
    spend: ParsedSpend,
    categories: Category[],
  ): Promise<CategorizedSpend> {
    const sameKind = categories.filter((item) => item.kind === spend.kind);
    const exact = (name: string | null) =>
      name ? sameKind.find((item) => item.name.toLowerCase() === name.toLowerCase()) : undefined;
    const byName = (name: string | null) => exact(name) ?? exact(name && broaderCategory(name));

    const picked = byName(spend.category);
    if (picked) {
      return this.result(spend, picked, 'llm', null);
    }

    try {
      const { label, score } = await this.zeroShot.classify(
        spend.rawDescription,
        spend.kind === 'income' ? incomeLabels : expenseLabels,
      );
      const mapped = byName(categoryNameFor(label, score, spend.kind));
      if (mapped) {
        return this.result(spend, mapped, 'zero-shot', score);
      }
    } catch (caught) {
      if (!(caught instanceof ServiceUnavailableException)) {
        throw caught;
      }
    }

    const fallback =
      byName(spend.kind === 'income' ? 'Other income' : 'Other') ?? sameKind[0];
    if (!fallback) {
      throw new BadRequestException('Categories are not set up yet');
    }
    return this.result(spend, fallback, 'fallback', null);
  }

  private result(
    spend: ParsedSpend,
    category: Category,
    source: CategorySource,
    confidence: number | null,
  ): CategorizedSpend {
    return {
      ...spend,
      categoryId: category.id,
      categoryName: category.name,
      source,
      confidence,
      accountId: null,
      accountName: null,
    };
  }
}
