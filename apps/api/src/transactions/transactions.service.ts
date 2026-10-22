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
    offset = 0,
    kind?: 'income' | 'expense',
    q?: string,
  ): Promise<Transaction[]> {
    const match = await this.searchMatch(userId, q);
    const rows: TransactionRow[] = [];
    const pageSize = 1000;
    for (let start = offset; rows.length < limit; start += pageSize) {
      const last = start + Math.min(pageSize, limit - rows.length) - 1;
      let query = this.supabase
        .from('transactions')
        .select(transactionSelect)
        .eq('user_id', userId)
        .order('occurred_on', { ascending: false })
        .order('created_at', { ascending: false })
        .range(start, last);
      if (kind) query = query.eq('kind', kind);
      if (match) query = query.or(match);
      if (range) {
        query = query.gte('occurred_on', range.from).lt('occurred_on', range.to);
      } else if (month) {
        const { start: monthStart, end } = monthRange(month);
        query = query.gte('occurred_on', monthStart).lt('occurred_on', end);
      }
      const { data, error } = await query;
      if (error) throw new BadRequestException(error.message);
      const page = (data ?? []) as TransactionRow[];
      rows.push(...page);
      if (page.length < last - start + 1) break;
    }
    return rows.map(toTransaction);
  }

  private async searchMatch(userId: string, q?: string): Promise<string | undefined> {
    const needle = q?.replace(/[%_,.()]/g, '').trim();
    if (!needle) return undefined;
    const [categories, accounts] = await Promise.all([
      this.supabase.from('categories').select('id').or(`user_id.eq.${userId},user_id.is.null`).ilike('name', `%${needle}%`),
      this.supabase.from('accounts').select('id').eq('user_id', userId).ilike('name', `%${needle}%`),
    ]);
    if (categories.error) throw new BadRequestException(categories.error.message);
    if (accounts.error) throw new BadRequestException(accounts.error.message);
    const categoryIds = ((categories.data ?? []) as { id: string }[]).map((row) => row.id);
    const accountIds = ((accounts.data ?? []) as { id: string }[]).map((row) => row.id);
    const parts = [`note.ilike.%${needle}%`];
    if (categoryIds.length > 0) parts.push(`category_id.in.(${categoryIds.join(',')})`);
    if (accountIds.length > 0) parts.push(`account_id.in.(${accountIds.join(',')})`);
    return parts.join(',');
  }

  async keysBetween(userId: string, accountId: string, from: string, to: string): Promise<Set<string>> {
    const keys = new Set<string>();
    for (let start = 0; start < 4000; start += 1000) {
      const { data, error } = await this.supabase
        .from('transactions')
        .select('occurred_on, amount, kind, note')
        .eq('user_id', userId)
        .eq('account_id', accountId)
        .gte('occurred_on', from)
        .lte('occurred_on', to)
        .range(start, start + 999);
      if (error) throw new BadRequestException(error.message);
      const page = (data ?? []) as { occurred_on: string; amount: number; kind: string; note: string | null }[];
      for (const row of page) {
        keys.add(`${row.occurred_on}|${row.kind}|${row.amount}|${(row.note ?? '').toLowerCase()}`);
      }
      if (page.length < 1000) break;
    }
    return keys;
  }

  async createMany(userId: string, inputs: TransactionDto[]): Promise<number> {
    if (inputs.length === 0) return 0;
    if (inputs.length > 1500) throw new BadRequestException('Save up to 1500 rows at a time');
    const accountId = inputs[0]!.accountId;
    if (inputs.some((item) => item.accountId !== accountId)) {
      throw new BadRequestException('Save a statement into one account');
    }
    await this.assertRefs(userId, inputs[0]!);
    const kinds = new Map<string, string>();
    for (const item of inputs) {
      let kind = kinds.get(item.categoryId);
      if (!kind) {
        const category = await findCategory(this.supabase, userId, item.categoryId);
        if (!category) throw new BadRequestException('Category not found');
        kind = category.kind;
        kinds.set(item.categoryId, kind);
      }
      if (kind !== item.kind) throw new BadRequestException('Category does not match income or expense');
    }
    for (let start = 0; start < inputs.length; start += 500) {
      const slice = inputs.slice(start, start + 500);
      const { error } = await this.supabase.from('transactions').insert(slice.map((item) => this.row(userId, item)));
      if (error) throw new BadRequestException(error.message);
    }
    return inputs.length;
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
