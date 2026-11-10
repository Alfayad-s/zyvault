import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { todayInIndia } from '../finance/dates.js';
import { accountEffect, missingDebtsTable, type DebtType } from '../debts/debts.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { cardPosition, nextDueDate, type CardMove } from './cards.js';
import { CreateAccountDto } from './dto/create-account.dto.js';

type AccountType = 'cash' | 'bank' | 'credit';
type CardKind = 'fd' | 'bank';

type AccountRow = {
  id: string;
  name: string;
  type: AccountType;
  opening_balance: number;
  created_at: string;
  bank_id?: string | null;
  card_kind?: CardKind | null;
  limit_amount?: number | null;
  bill_day?: number | null;
  due_day?: number | null;
};

export type Account = {
  id: string;
  name: string;
  type: AccountType;
  openingBalance: number;
  createdAt: string;
  bankId: string | null;
  cardKind?: CardKind | null;
  limitAmount?: number | null;
  billDay?: number | null;
  dueDay?: number | null;
  used?: number;
  available?: number;
  balance?: number;
};

export type CardSnapshot = {
  limit: number;
  used: number;
  available: number;
  billDay: number | null;
  dueDay: number | null;
  nextDue: string | null;
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
const columnsWithCard = `${columnsWithBank}, card_kind, limit_amount, bill_day, due_day`;

function toAccount(row: AccountRow): Account {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    openingBalance: row.opening_balance,
    createdAt: row.created_at,
    bankId: row.bank_id ?? null,
    cardKind: row.card_kind ?? null,
    limitAmount: row.limit_amount ?? null,
    billDay: row.bill_day ?? null,
    dueDay: row.due_day ?? null,
  };
}

function missingBankColumn(error: { message: string } | null): boolean {
  return Boolean(error && error.message.includes('bank_id'));
}

function missingCardColumn(error: { message: string } | null): boolean {
  return Boolean(error && /card_kind|limit_amount|bill_day|due_day|card_effect|card_id/.test(error.message));
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
    let { data, error } = await query(columnsWithCard);
    if (missingCardColumn(error)) ({ data, error } = await query(columnsWithBank));
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
    const rows = ((data ?? []) as unknown as AccountRow[]).map(toAccount);
    const moves = rows.some((account) => account.type === 'credit') ? await this.cardMoves(userId) : [];
    return rows.map((account) => {
      const cash = account.openingBalance + (totals.get(account.id) ?? 0);
      if (account.type !== 'credit' || account.limitAmount == null) {
        return { ...account, balance: cash };
      }
      const position = cardPosition(account.limitAmount, account.id, moves);
      return {
        ...account,
        used: position.used,
        available: position.available,
        balance: position.available,
      };
    });
  }

  async card(userId: string, id: string): Promise<CardSnapshot> {
    const account = await this.owned(userId, id);
    if (account.type !== 'credit' || account.limitAmount == null) {
      throw new BadRequestException('That account is not a card');
    }
    const position = cardPosition(account.limitAmount, account.id, await this.cardMoves(userId));
    return {
      limit: position.limit,
      used: position.used,
      available: position.available,
      billDay: account.billDay ?? null,
      dueDay: account.dueDay ?? null,
      nextDue: nextDueDate(account.dueDay ?? null, todayInIndia()),
    };
  }

  async assertCardMove(
    userId: string,
    input: {
      accountId: string;
      amount: number;
      kind: 'income' | 'expense';
      cardEffect?: 'spend' | 'payment' | null;
      cardId?: string | null;
    },
    exceptId?: string,
  ): Promise<{ card_effect: 'spend' | 'payment' | null; card_id: string | null }> {
    const effect = input.cardEffect ?? null;
    if (!effect) {
      const account = await this.owned(userId, input.accountId);
      if (account.type === 'credit') {
        throw new BadRequestException('Save this as a card spend');
      }
      return { card_effect: null, card_id: null };
    }
    if (effect === 'spend') {
      const card = await this.owned(userId, input.accountId);
      if (card.type !== 'credit' || card.limitAmount == null) {
        throw new BadRequestException('That account is not a card');
      }
      if (input.kind !== 'expense') throw new BadRequestException('A card spend is an expense');
      const position = cardPosition(card.limitAmount, card.id, await this.cardMoves(userId), exceptId);
      if (input.amount > position.available) {
        throw new BadRequestException('That is more than the card has free');
      }
      return { card_effect: 'spend', card_id: card.id };
    }
    if (input.kind !== 'expense') throw new BadRequestException('A card payment is an expense');
    if (!input.cardId) throw new BadRequestException('Pick the card this payment settles');
    const source = await this.owned(userId, input.accountId);
    if (source.type === 'credit') {
      throw new BadRequestException('Pay a card from a bank or cash account');
    }
    const card = await this.owned(userId, input.cardId);
    if (card.type !== 'credit' || card.limitAmount == null) {
      throw new BadRequestException('That account is not a card');
    }
    const position = cardPosition(card.limitAmount, card.id, await this.cardMoves(userId), exceptId);
    if (input.amount > position.used) {
      throw new BadRequestException('That is more than the card currently owes');
    }
    return { card_effect: 'payment', card_id: card.id };
  }

  async create(userId: string, input: CreateAccountDto): Promise<Account> {
    const row = { user_id: userId, ...fields(input) };
    const insert = (values: Record<string, unknown>, select: string) =>
      this.supabase.from('accounts').insert(values).select(select).single();
    let { data, error } = await insert(
      { ...row, bank_id: bankOf(input), ...cardColumns(input) },
      columnsWithCard,
    );
    if (input.type === 'credit' && missingCardColumn(error)) {
      throw new BadRequestException('Run the latest supabase/schema.sql, then add the card again');
    }
    if (missingCardColumn(error)) ({ data, error } = await insert({ ...row, bank_id: bankOf(input) }, columnsWithBank));
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
    let { data, error } = await change(
      { ...row, bank_id: bankOf(input), ...cardColumns(input) },
      columnsWithCard,
    );
    if (input.type === 'credit' && missingCardColumn(error)) {
      throw new BadRequestException('Run the latest supabase/schema.sql, then save the card again');
    }
    if (missingCardColumn(error)) ({ data, error } = await change({ ...row, bank_id: bankOf(input) }, columnsWithBank));
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

  private async owned(userId: string, id: string): Promise<Account> {
    const query = (select: string) =>
      this.supabase.from('accounts').select(select).eq('id', id).eq('user_id', userId).maybeSingle();
    let { data, error } = await query(columnsWithCard);
    if (missingCardColumn(error)) ({ data, error } = await query(columnsWithBank));
    if (missingBankColumn(error)) ({ data, error } = await query(columns));
    if (error) throw new BadRequestException(error.message);
    if (!data) throw new BadRequestException('Account not found');
    return toAccount(data as unknown as AccountRow);
  }

  private async cardMoves(userId: string): Promise<CardMove[]> {
    try {
      const rows = await allRows<{
        id: string;
        account_id: string;
        amount: number;
        card_effect: 'spend' | 'payment' | null;
        card_id: string | null;
      }>((from, to) =>
        this.supabase
          .from('transactions')
          .select('id, account_id, amount, card_effect, card_id')
          .eq('user_id', userId)
          .not('card_effect', 'is', null)
          .order('id')
          .range(from, to),
      );
      return rows.map((row) => ({
        id: row.id,
        amount: row.amount,
        effect: row.card_effect,
        accountId: row.account_id,
        cardId: row.card_id,
      }));
    } catch (caught) {
      if (caught instanceof BadRequestException && caught.message.includes('card_effect')) return [];
      throw caught;
    }
  }
}

function fields(input: CreateAccountDto) {
  return {
    name: input.name.trim(),
    type: input.type,
    opening_balance: input.type === 'credit' ? 0 : input.openingBalance,
  };
}

function cardColumns(input: CreateAccountDto) {
  if (input.type !== 'credit') {
    return { card_kind: null, limit_amount: null, bill_day: null, due_day: null };
  }
  return {
    card_kind: input.cardKind,
    limit_amount: input.limitAmount,
    bill_day: input.cardKind === 'bank' ? input.billDay : null,
    due_day: input.cardKind === 'bank' ? input.dueDay : null,
  };
}

function bankOf(input: CreateAccountDto): string | null {
  return input.type === 'cash' ? null : (input.bankId ?? null);
}
