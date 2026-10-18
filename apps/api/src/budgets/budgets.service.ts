import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { findCategory } from '../categories/categories.service.js';
import { monthRange } from '../summary/month.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { UpsertBudgetDto } from './dto/upsert-budget.dto.js';

type BudgetRow = {
  id: string;
  category_id: string;
  month: string;
  limit_amount: number;
  category: { name: string } | { name: string }[] | null;
};

export type Budget = {
  id: string;
  categoryId: string;
  categoryName: string;
  month: string;
  limitAmount: number;
  spent: number;
};

const budgetSelect = 'id, category_id, month, limit_amount, category:categories(name)';

function categoryName(value: BudgetRow['category']): string {
  if (!value) {
    return '';
  }
  if (Array.isArray(value)) {
    return value[0]?.name ?? '';
  }
  return value.name;
}

function toBudget(row: BudgetRow, spent: number): Budget {
  return {
    id: row.id,
    categoryId: row.category_id,
    categoryName: categoryName(row.category),
    month: row.month,
    limitAmount: row.limit_amount,
    spent,
  };
}

export function spentByCategory(rows: { category_id: string; amount: number }[]): Map<string, number> {
  const totals = new Map<string, number>();
  for (const row of rows) {
    totals.set(row.category_id, (totals.get(row.category_id) ?? 0) + row.amount);
  }
  return totals;
}

@Injectable()
export class BudgetsService {
  constructor(@Inject(SUPABASE) private readonly supabase: SupabaseClient) {}

  async list(userId: string, month: string): Promise<Budget[]> {
    let rows = await this.rows(userId, month);
    if (rows.length === 0) rows = await this.carryForward(userId, month);
    const spent = await this.spent(userId, month);
    return rows.map((row) => toBudget(row, spent.get(row.category_id) ?? 0));
  }

  async upsert(userId: string, input: UpsertBudgetDto): Promise<Budget> {
    const category = await findCategory(this.supabase, userId, input.categoryId);
    if (!category || category.kind !== 'expense') {
      throw new BadRequestException('Choose an expense category');
    }

    const { data, error } = await this.supabase
      .from('budgets')
      .upsert(
        {
          user_id: userId,
          category_id: input.categoryId,
          month: input.month,
          limit_amount: input.limitAmount,
        },
        { onConflict: 'user_id,category_id,month' },
      )
      .select(budgetSelect)
      .single();
    if (error || !data) {
      throw new BadRequestException(error?.message ?? 'Could not save the budget');
    }
    const spent = await this.spent(userId, input.month);
    return toBudget(data as BudgetRow, spent.get(input.categoryId) ?? 0);
  }

  async remove(userId: string, id: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('budgets')
      .delete()
      .eq('id', id)
      .eq('user_id', userId)
      .select('id');
    if (error) throw new BadRequestException(error.message);
    if (!data || data.length === 0) throw new NotFoundException('Budget not found');
  }

  private async rows(userId: string, month: string): Promise<BudgetRow[]> {
    const { data, error } = await this.supabase
      .from('budgets')
      .select(budgetSelect)
      .eq('user_id', userId)
      .eq('month', month)
      .order('created_at', { ascending: true });
    if (error) {
      throw new BadRequestException(error.message);
    }
    return (data ?? []) as BudgetRow[];
  }

  /** A new month starts with the limits of the latest month that had any, so they need not be set again. */
  private async carryForward(userId: string, month: string): Promise<BudgetRow[]> {
    const latest = await this.supabase
      .from('budgets')
      .select('month')
      .eq('user_id', userId)
      .order('month', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (latest.error) throw new BadRequestException(latest.error.message);
    const from = latest.data?.month as string | undefined;
    if (!from || from >= month) return [];
    const previous = await this.rows(userId, from);
    if (previous.length === 0) return [];
    const { error } = await this.supabase.from('budgets').upsert(
      previous.map((row) => ({
        user_id: userId,
        category_id: row.category_id,
        month,
        limit_amount: row.limit_amount,
      })),
      { onConflict: 'user_id,category_id,month', ignoreDuplicates: true },
    );
    if (error) throw new BadRequestException(error.message);
    return this.rows(userId, month);
  }

  private async spent(userId: string, month: string): Promise<Map<string, number>> {
    const { start, end } = monthRange(month);
    const rows = await allRows<{ category_id: string; amount: number }>((from, to) =>
      this.supabase
        .from('transactions')
        .select('category_id, amount')
        .eq('user_id', userId)
        .eq('kind', 'expense')
        .gte('occurred_on', start)
        .lt('occurred_on', end)
        .order('id')
        .range(from, to),
    );
    return spentByCategory(rows);
  }
}
