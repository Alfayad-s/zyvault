import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { monthRange } from './month.js';
import { buildSummary, SummaryTransaction } from './summary.js';

type AmountRow = {
  amount: number;
  kind: 'income' | 'expense';
  card_effect?: 'spend' | 'payment' | null;
};
type MonthRow = AmountRow & {
  account_id: string;
  category_id: string;
  category: { name: string } | { name: string }[] | null;
};

function asCardEffect(value: string | null | undefined): AmountRow['card_effect'] {
  return value === 'spend' || value === 'payment' ? value : null;
}

function categoryName(
  value: MonthRow['category'],
): string {
  if (!value) {
    return 'Unknown';
  }
  if (Array.isArray(value)) {
    return value[0]?.name ?? 'Unknown';
  }
  return value.name;
}

@Injectable()
export class SummaryService {
  constructor(@Inject(SUPABASE) private readonly supabase: SupabaseClient) {}

  async forMonth(userId: string, month: string) {
    const { start, end } = monthRange(month);
    const [accounts, allTransactions, monthRows] = await Promise.all([
      this.supabase
        .from('accounts')
        .select('opening_balance, type')
        .eq('user_id', userId),
      this.movements(userId),
      this.monthMovements(userId, start, end),
    ]);

    if (accounts.error) {
      throw new BadRequestException(accounts.error.message);
    }

    const openingBalance = ((accounts.data ?? []) as { opening_balance: number; type?: string }[])
      .filter((account) => account.type !== 'credit')
      .reduce((sum, account) => sum + account.opening_balance, 0);
    const monthTransactions: SummaryTransaction[] = monthRows.map((row) => ({
      amount: row.amount,
      kind: row.kind,
      cardEffect: asCardEffect(row.card_effect),
      accountId: row.account_id,
      categoryId: row.category_id,
      categoryName: categoryName(row.category),
    }));

    return buildSummary(
      openingBalance,
      allTransactions.map((row) => ({
        amount: row.amount,
        kind: row.kind,
        cardEffect: asCardEffect(row.card_effect),
      })),
      monthTransactions,
    );
  }

  /** Category totals for a window. The phone gets the totals, not every payment. */
  async forRange(userId: string, from: string, to: string) {
    const rows = await this.monthMovements(userId, from, to);
    const summary = buildSummary(
      0,
      [],
      rows.map((row) => ({
        amount: row.amount,
        kind: row.kind,
        cardEffect: asCardEffect(row.card_effect),
        accountId: row.account_id,
        categoryId: row.category_id,
        categoryName: categoryName(row.category),
      })),
    );
    return {
      income: summary.monthIncome,
      expense: summary.monthExpense,
      categories: summary.categories,
    };
  }

  private async movements(userId: string): Promise<AmountRow[]> {
    try {
      return await this.read(userId, 'amount, kind, card_effect');
    } catch (caught) {
      if (caught instanceof BadRequestException && caught.message.includes('card_effect')) {
        return this.read(userId, 'amount, kind');
      }
      throw caught;
    }
  }

  private async monthMovements(userId: string, from: string, to: string): Promise<MonthRow[]> {
    const rich = 'amount, kind, card_effect, account_id, category_id, category:categories(name)';
    const plain = 'amount, kind, account_id, category_id, category:categories(name)';
    try {
      return await this.read(userId, rich, from, to);
    } catch (caught) {
      if (caught instanceof BadRequestException && caught.message.includes('card_effect')) {
        return this.read(userId, plain, from, to);
      }
      throw caught;
    }
  }

  private read<T extends AmountRow>(userId: string, select: string, from?: string, to?: string): Promise<T[]> {
    return allRows<T>((start, end) => {
      let query = this.supabase
        .from('transactions')
        .select(select)
        .eq('user_id', userId)
        .order('id')
        .range(start, end);
      if (from && to) query = query.gte('occurred_on', from).lt('occurred_on', to);
      return query as unknown as PromiseLike<{ data: T[] | null; error: { message: string } | null }>;
    });
  }
}
