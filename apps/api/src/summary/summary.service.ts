import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { monthRange } from './month.js';
import { buildSummary, SummaryTransaction } from './summary.js';

type AmountRow = { amount: number; kind: 'income' | 'expense' };
type MonthRow = AmountRow & {
  account_id: string;
  category_id: string;
  category: { name: string } | { name: string }[] | null;
};

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
        .select('opening_balance')
        .eq('user_id', userId),
      allRows<AmountRow>((from, to) =>
        this.supabase
          .from('transactions')
          .select('amount, kind')
          .eq('user_id', userId)
          .order('id')
          .range(from, to),
      ),
      allRows<MonthRow>((from, to) =>
        this.supabase
          .from('transactions')
          .select('amount, kind, account_id, category_id, category:categories(name)')
          .eq('user_id', userId)
          .gte('occurred_on', start)
          .lt('occurred_on', end)
          .order('id')
          .range(from, to),
      ),
    ]);

    if (accounts.error) {
      throw new BadRequestException(accounts.error.message);
    }

    const openingBalance = ((accounts.data ?? []) as { opening_balance: number }[])
      .reduce((sum, account) => sum + account.opening_balance, 0);
    const monthTransactions: SummaryTransaction[] = monthRows.map((row) => ({
      amount: row.amount,
      kind: row.kind,
      accountId: row.account_id,
      categoryId: row.category_id,
      categoryName: categoryName(row.category),
    }));

    return buildSummary(openingBalance, allTransactions, monthTransactions);
  }

  /** Category totals for a window. The phone gets the totals, not every payment. */
  async forRange(userId: string, from: string, to: string) {
    const rows = await allRows<MonthRow>((start, end) =>
      this.supabase
        .from('transactions')
        .select('amount, kind, account_id, category_id, category:categories(name)')
        .eq('user_id', userId)
        .gte('occurred_on', from)
        .lt('occurred_on', to)
        .order('id')
        .range(start, end),
    );
    const summary = buildSummary(
      0,
      [],
      rows.map((row) => ({
        amount: row.amount,
        kind: row.kind,
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
}
