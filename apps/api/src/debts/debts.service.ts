import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import {
  missingDebtsTable,
  peopleFrom,
  personKey,
  type DebtEntry,
  type DebtType,
  type Person,
} from './debts.js';
import { DebtDto } from './dto/debt.dto.js';

type DebtRow = {
  id: string;
  person: string;
  type: DebtType;
  amount: number;
  account_id: string | null;
  occurred_on: string;
  note: string | null;
  account: { name: string } | { name: string }[] | null;
};

const debtSelect = 'id, person, type, amount, account_id, occurred_on, note, account:accounts(name)';

function toEntry(row: DebtRow): DebtEntry {
  const account = Array.isArray(row.account) ? row.account[0] : row.account;
  return {
    id: row.id,
    person: row.person,
    type: row.type,
    amount: row.amount,
    accountId: row.account_id,
    accountName: account?.name ?? null,
    occurredOn: row.occurred_on,
    note: row.note,
  };
}

@Injectable()
export class DebtsService {
  constructor(@Inject(SUPABASE) private readonly supabase: SupabaseClient) {}

  async entries(userId: string): Promise<DebtEntry[]> {
    const rows = await allRows<DebtRow>((from, to) =>
      this.supabase
        .from('debts')
        .select(debtSelect)
        .eq('user_id', userId)
        .order('occurred_on', { ascending: false })
        .order('created_at', { ascending: false })
        .order('id')
        .range(from, to),
    ).catch((caught: unknown) => {
      if (missingDebtsTable(caught instanceof Error ? caught : null)) return [];
      throw caught;
    });
    return rows.map(toEntry);
  }

  async list(userId: string): Promise<{ people: Person[]; entries: DebtEntry[] }> {
    const entries = await this.entries(userId);
    return { people: peopleFrom(entries), entries };
  }

  /** What the person owes the user right now (negative when the user owes them). */
  async balanceWith(userId: string, person: string): Promise<number> {
    const key = personKey(person);
    const match = peopleFrom(await this.entries(userId)).find((item) => personKey(item.name) === key);
    return match?.balance ?? 0;
  }

  async create(userId: string, input: DebtDto): Promise<DebtEntry> {
    if (input.accountId) await this.assertAccount(userId, input.accountId);
    const { data, error } = await this.supabase
      .from('debts')
      .insert({
        user_id: userId,
        person: input.person.trim().replace(/\s+/g, ' '),
        type: input.type,
        amount: input.amount,
        account_id: input.accountId ?? null,
        occurred_on: input.occurredOn,
        note: input.note?.trim() || null,
      })
      .select(debtSelect)
      .single();
    if (missingDebtsTable(error)) {
      throw new BadRequestException('Run the latest supabase/schema.sql in Supabase to track lending');
    }
    if (error || !data) {
      throw new BadRequestException(error?.message ?? 'Could not save that');
    }
    return toEntry(data as DebtRow);
  }

  async remove(userId: string, id: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('debts')
      .delete()
      .eq('id', id)
      .eq('user_id', userId)
      .select('id');
    if (error) throw new BadRequestException(error.message);
    if (!data || data.length === 0) throw new NotFoundException('Entry not found');
  }

  private async assertAccount(userId: string, accountId: string) {
    const { data, error } = await this.supabase
      .from('accounts')
      .select('id')
      .eq('id', accountId)
      .eq('user_id', userId)
      .maybeSingle();
    if (error) throw new BadRequestException(error.message);
    if (!data) throw new BadRequestException('Account not found');
  }
}
