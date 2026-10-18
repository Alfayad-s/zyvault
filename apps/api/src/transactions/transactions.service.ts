import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { findCategory } from '../categories/categories.service.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { monthRange } from '../summary/month.js';
import { TransactionDto } from './dto/transaction.dto.js';

type Relation<T> = T | T[] | null;

type TransactionRow = {
  id: string;
  account_id: string;
  category_id: string;
  amount: number;
  kind: 'income' | 'expense';
  occurred_on: string;
  note: string | null;
  account: Relation<{ name: string }>;
  category: Relation<{ name: string }>;
};

export type Transaction = {
  id: string;
  accountId: string;
  accountName: string;
  categoryId: string;
  categoryName: string;
  amount: number;
  kind: 'income' | 'expense';
  occurredOn: string;
  note: string | null;
};

const transactionSelect =
  'id, account_id, category_id, amount, kind, occurred_on, note, account:accounts(name), category:categories(name)';

function relatedName(value: Relation<{ name: string }>): string {
  if (!value) {
    return '';
  }
  if (Array.isArray(value)) {
    return value[0]?.name ?? '';
  }
  return value.name;
}

function toTransaction(row: TransactionRow): Transaction {
  return {
    id: row.id,
    accountId: row.account_id,
    accountName: relatedName(row.account),
    categoryId: row.category_id,
    categoryName: relatedName(row.category),
    amount: row.amount,
    kind: row.kind,
    occurredOn: row.occurred_on,
    note: row.note,
  };
}

@Injectable()
export class TransactionsService {
  constructor(@Inject(SUPABASE) private readonly supabase: SupabaseClient) {}

  async list(
    userId: string,
    month?: string,
    limit = 50,
    range?: { from: string; to: string },
  ): Promise<Transaction[]> {
    let query = this.supabase
      .from('transactions')
      .select(transactionSelect)
      .eq('user_id', userId)
      .order('occurred_on', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(limit);

    if (range) {
      query = query.gte('occurred_on', range.from).lt('occurred_on', range.to);
    } else if (month) {
      const { start, end } = monthRange(month);
      query = query.gte('occurred_on', start).lt('occurred_on', end);
    }

    const { data, error } = await query;
    if (error) {
      throw new BadRequestException(error.message);
    }
    return ((data ?? []) as TransactionRow[]).map(toTransaction);
  }

  async create(userId: string, input: TransactionDto): Promise<Transaction> {
    await this.assertRefs(userId, input);
    const { data, error } = await this.supabase
      .from('transactions')
      .insert(this.row(userId, input))
      .select(transactionSelect)
      .single();
    if (error || !data) {
      throw new BadRequestException(error?.message ?? 'Could not save the transaction');
    }
    return toTransaction(data as TransactionRow);
  }

  async update(
    userId: string,
    id: string,
    input: TransactionDto,
  ): Promise<Transaction> {
    await this.assertRefs(userId, input);
    const { data, error } = await this.supabase
      .from('transactions')
      .update(this.row(userId, input))
      .eq('id', id)
      .eq('user_id', userId)
      .select(transactionSelect)
      .maybeSingle();
    if (error) {
      throw new BadRequestException(error.message);
    }
    if (!data) {
      throw new NotFoundException('Transaction not found');
    }
    return toTransaction(data as TransactionRow);
  }

  async remove(userId: string, id: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('transactions')
      .delete()
      .eq('id', id)
      .eq('user_id', userId)
      .select('id');
    if (error) {
      throw new BadRequestException(error.message);
    }
    if (!data || data.length === 0) {
      throw new NotFoundException('Transaction not found');
    }
  }

  private row(userId: string, input: TransactionDto) {
    return {
      user_id: userId,
      account_id: input.accountId,
      category_id: input.categoryId,
      amount: input.amount,
      kind: input.kind,
      occurred_on: input.occurredOn,
      note: input.note?.trim() || null,
    };
  }

  private async assertRefs(userId: string, input: TransactionDto) {
    const account = await this.supabase
      .from('accounts')
      .select('id')
      .eq('id', input.accountId)
      .eq('user_id', userId)
      .maybeSingle();
    if (account.error) {
      throw new BadRequestException(account.error.message);
    }
    if (!account.data) {
      throw new BadRequestException('Account not found');
    }

    const category = await findCategory(this.supabase, userId, input.categoryId);
    if (!category) {
      throw new BadRequestException('Category not found');
    }
    if (category.kind !== input.kind) {
      throw new BadRequestException('Category does not match income or expense');
    }
  }
}
