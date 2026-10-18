import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { accountEffect, missingDebtsTable, type DebtType } from '../debts/debts.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { CreateAccountDto } from './dto/create-account.dto.js';

type AccountRow = {
  id: string;
  name: string;
  type: 'cash' | 'bank';
  opening_balance: number;
  created_at: string;
  bank_id?: string | null;
};

export type Account = {
  id: string;
  name: string;
  type: 'cash' | 'bank';
  openingBalance: number;
  createdAt: string;
  bankId: string | null;
  balance?: number;
};

type MovementRow = { account_id: string; amount: number; kind: 'income' | 'expense' };

type DebtMovementRow = { account_id: string; amount: number; type: DebtType };

export function balancesByAccount(movements: MovementRow[]): Map<string, number> {
  const totals = new Map<string, number>();
  for (const row of movements) {
    const signed = row.kind === 'income' ? row.amount : -row.amount;
    totals.set(row.account_id, (totals.get(row.account_id) ?? 0) + signed);
  }
  return totals;
}

const columns = 'id, name, type, opening_balance, created_at';
const columnsWithBank = `${columns}, bank_id`;

function toAccount(row: AccountRow): Account {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    openingBalance: row.opening_balance,
    createdAt: row.created_at,
    bankId: row.bank_id ?? null,
  };
}

function missingBankColumn(error: { message: string } | null): boolean {
  return Boolean(error && error.message.includes('bank_id'));
}

@Injectable()
export class AccountsService {
  constructor(@Inject(SUPABASE) private readonly supabase: SupabaseClient) {}

  async list(userId: string): Promise<Account[]> {
    const query = (select: string) =>
      this.supabase
        .from('accounts')
        .select(select)
        .eq('user_id', userId)
        .order('created_at', { ascending: true });
    let { data, error } = await query(columnsWithBank);
    if (missingBankColumn(error)) ({ data, error } = await query(columns));
    if (error) {
      throw new BadRequestException(error.message);
    }
    const movements = await allRows<MovementRow>((from, to) =>
      this.supabase
        .from('transactions')
        .select('account_id, amount, kind')
        .eq('user_id', userId)
        .order('id')
        .range(from, to),
    );
    const debts = await allRows<DebtMovementRow>((from, to) =>
      this.supabase
        .from('debts')
        .select('account_id, amount, type')
        .eq('user_id', userId)
        .not('account_id', 'is', null)
        .order('id')
        .range(from, to),
    ).catch((caught: unknown) => {
      if (missingDebtsTable(caught instanceof Error ? caught : null)) return [];
      throw caught;
    });
    const totals = balancesByAccount([
      ...movements,
      ...debts.map((row) => {
        const signed = accountEffect(row.type, row.amount);
        return {
          account_id: row.account_id,
          amount: Math.abs(signed),
          kind: signed > 0 ? ('income' as const) : ('expense' as const),
        };
      }),
    ]);
    return ((data ?? []) as unknown as AccountRow[]).map((row) => {
      const account = toAccount(row);
      return { ...account, balance: account.openingBalance + (totals.get(account.id) ?? 0) };
    });
  }

  async create(userId: string, input: CreateAccountDto): Promise<Account> {
    const row = { user_id: userId, ...fields(input) };
    const insert = (values: Record<string, unknown>, select: string) =>
      this.supabase.from('accounts').insert(values).select(select).single();
    let { data, error } = await insert({ ...row, bank_id: bankOf(input) }, columnsWithBank);
    if (missingBankColumn(error)) ({ data, error } = await insert(row, columns));
    if (error || !data) {
      throw new BadRequestException(error?.message ?? 'Could not create the account');
    }
    return toAccount(data as unknown as AccountRow);
  }

  async update(userId: string, id: string, input: CreateAccountDto): Promise<Account> {
    const row = fields(input);
    const change = (values: Record<string, unknown>, select: string) =>
      this.supabase
        .from('accounts')
        .update(values)
        .eq('id', id)
        .eq('user_id', userId)
        .select(select)
        .maybeSingle();
    let { data, error } = await change({ ...row, bank_id: bankOf(input) }, columnsWithBank);
    if (missingBankColumn(error)) ({ data, error } = await change(row, columns));
    if (error) throw new BadRequestException(error.message);
    if (!data) throw new NotFoundException('Account not found');
    return toAccount(data as unknown as AccountRow);
  }

  async remove(userId: string, id: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('accounts')
      .delete()
      .eq('id', id)
      .eq('user_id', userId)
      .select('id');
    if (error) throw new BadRequestException(error.message);
    if (!data || data.length === 0) throw new NotFoundException('Account not found');
  }
}

function fields(input: CreateAccountDto) {
  return {
    name: input.name.trim(),
    type: input.type,
    opening_balance: input.openingBalance,
  };
}

function bankOf(input: CreateAccountDto): string | null {
  return input.type === 'bank' ? (input.bankId ?? null) : null;
}
