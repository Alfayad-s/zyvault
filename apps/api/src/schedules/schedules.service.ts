import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { monthlyAfter } from '../agent/spend.js';
import { findCategory } from '../categories/categories.service.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { TransactionsService } from '../transactions/transactions.service.js';

const maxCatchUp = 12;

type Relation<T> = T | T[] | null;

type ScheduleRow = {
  id: string;
  account_id: string;
  category_id: string;
  amount: number;
  kind: 'income' | 'expense';
  note: string | null;
  repeat: 'once' | 'monthly';
  day_of_month: number;
  next_on: string;
  at_time?: string | null;
  account: Relation<{ name: string }>;
  category: Relation<{ name: string }>;
};

export type Schedule = {
  id: string;
  accountId: string;
  accountName: string;
  categoryId: string;
  categoryName: string;
  amount: number;
  kind: 'income' | 'expense';
  note: string | null;
  repeat: 'once' | 'monthly';
  dayOfMonth: number;
  nextOn: string;
  atTime: string | null;
};

export type PostedEntry = {
  scheduleId: string;
  occurredOn: string;
  amount: number;
  kind: 'income' | 'expense';
  what: string;
  accountName: string;
};

export type NewSchedule = {
  accountId: string;
  categoryId: string;
  amount: number;
  kind: 'income' | 'expense';
  note: string | null;
  repeat: 'once' | 'monthly';
  dayOfMonth: number;
  nextOn: string;
  atTime?: string | null;
};

const scheduleColumns =
  'id, account_id, category_id, amount, kind, note, repeat, day_of_month, next_on, account:accounts(name), category:categories(name)';
const scheduleSelect = `${scheduleColumns}, at_time`;

function missingTimeColumn(error: { message: string } | null): boolean {
  return Boolean(error && error.message.includes('at_time'));
}

function relatedName(value: Relation<{ name: string }>): string {
  if (!value) return '';
  return Array.isArray(value) ? (value[0]?.name ?? '') : value.name;
}

function toSchedule(row: ScheduleRow): Schedule {
  return {
    id: row.id,
    accountId: row.account_id,
    accountName: relatedName(row.account),
    categoryId: row.category_id,
    categoryName: relatedName(row.category),
    amount: row.amount,
    kind: row.kind,
    note: row.note,
    repeat: row.repeat,
    dayOfMonth: row.day_of_month,
    nextOn: row.next_on,
    atTime: row.at_time ?? null,
  };
}

/** Dates to post now. With a time of day, today only counts once that time has passed. */
export function dueDates(
  nextOn: string,
  repeat: 'once' | 'monthly',
  dayOfMonth: number,
  today: string,
  atTime: string | null = null,
  now?: string,
) {
  const due = (date: string) =>
    date < today || (date === today && (atTime === null || !now || atTime <= now));
  const posts: string[] = [];
  let date = nextOn;
  while (due(date) && posts.length < maxCatchUp) {
    posts.push(date);
    if (repeat === 'once') break;
    date = monthlyAfter(date, dayOfMonth);
  }
  while (repeat === 'monthly' && due(date)) {
    date = monthlyAfter(date, dayOfMonth);
  }
  return { posts, next: date };
}

@Injectable()
export class SchedulesService {
  private readonly logger = new Logger(SchedulesService.name);

  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly transactions: TransactionsService,
  ) {}

  async list(userId: string): Promise<Schedule[]> {
    const query = (select: string) =>
      this.supabase
        .from('scheduled_transactions')
        .select(select)
        .eq('user_id', userId)
        .order('next_on', { ascending: true });
    let { data, error } = await query(scheduleSelect);
    if (missingTimeColumn(error)) ({ data, error } = await query(scheduleColumns));
    if (error) throw new BadRequestException(error.message);
    return ((data ?? []) as unknown as ScheduleRow[]).map(toSchedule);
  }

  async create(userId: string, input: NewSchedule): Promise<Schedule> {
    await this.assertRefs(userId, input);
    const row = {
      user_id: userId,
      account_id: input.accountId,
      category_id: input.categoryId,
      amount: input.amount,
      kind: input.kind,
      note: input.note?.trim() || null,
      repeat: input.repeat,
      day_of_month: input.dayOfMonth,
      next_on: input.nextOn,
    };
    const insert = (values: Record<string, unknown>, select: string) =>
      this.supabase.from('scheduled_transactions').insert(values).select(select).single();
    let { data, error } = await insert({ ...row, at_time: input.atTime ?? null }, scheduleSelect);
    if (missingTimeColumn(error)) {
      if (input.atTime) {
        throw new BadRequestException(
          'Plans with a time need the latest supabase/schema.sql. Run it in Supabase, then try again',
        );
      }
      ({ data, error } = await insert(row, scheduleColumns));
    }
    if (error || !data) {
      throw new BadRequestException(error?.message ?? 'Could not save the schedule');
    }
    return toSchedule(data as unknown as ScheduleRow);
  }

  async remove(userId: string, id: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('scheduled_transactions')
      .delete()
      .eq('id', id)
      .eq('user_id', userId)
      .select('id');
    if (error) throw new BadRequestException(error.message);
    if (!data || data.length === 0) throw new NotFoundException('Schedule not found');
  }

  /**
   * Posts plans that are due. `untimedAt` treats plans without a time as due from that
   * time of day (the server uses 09:00 so pushes do not arrive at midnight).
   */
  async runDue(
    userId: string,
    today: string,
    now?: string,
    untimedAt?: string,
  ): Promise<{ posted: number; entries: PostedEntry[] }> {
    const query = (select: string) =>
      this.supabase
        .from('scheduled_transactions')
        .select(select)
        .eq('user_id', userId)
        .lte('next_on', today);
    let { data, error } = await query(scheduleSelect);
    if (missingTimeColumn(error)) ({ data, error } = await query(scheduleColumns));
    if (error) throw new BadRequestException(error.message);

    const entries: PostedEntry[] = [];
    for (const row of (data ?? []) as unknown as ScheduleRow[]) {
      const { posts, next } = dueDates(
        row.next_on,
        row.repeat,
        row.day_of_month,
        today,
        row.at_time ?? untimedAt ?? null,
        now,
      );
      if (posts.length === 0) continue;
      if (!(await this.claim(row, next))) continue;
      for (const occurredOn of posts) {
        try {
          await this.transactions.create(userId, {
            accountId: row.account_id,
            categoryId: row.category_id,
            amount: row.amount,
            kind: row.kind,
            occurredOn,
            note: row.note ?? undefined,
          });
          entries.push({
            scheduleId: row.id,
            occurredOn,
            amount: row.amount,
            kind: row.kind,
            what: row.note || relatedName(row.category),
            accountName: relatedName(row.account),
          });
        } catch (caught) {
          this.logger.warn(`Could not post schedule ${row.id} for ${occurredOn}: ${String(caught)}`);
        }
      }
    }
    return { posted: entries.length, entries };
  }

  private async claim(row: ScheduleRow, next: string): Promise<boolean> {
    const query =
      row.repeat === 'once'
        ? this.supabase.from('scheduled_transactions').delete()
        : this.supabase.from('scheduled_transactions').update({ next_on: next });
    const { data, error } = await query.eq('id', row.id).eq('next_on', row.next_on).select('id');
    if (error) throw new BadRequestException(error.message);
    return (data ?? []).length > 0;
  }

  private async assertRefs(userId: string, input: NewSchedule) {
    const account = await this.supabase
      .from('accounts')
      .select('id')
      .eq('id', input.accountId)
      .eq('user_id', userId)
      .maybeSingle();
    if (account.error) throw new BadRequestException(account.error.message);
    if (!account.data) throw new BadRequestException('Account not found');
    const category = await findCategory(this.supabase, userId, input.categoryId);
    if (!category || category.kind !== input.kind) {
      throw new BadRequestException('Category does not match income or expense');
    }
  }
}
