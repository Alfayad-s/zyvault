import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE } from '../supabase/supabase.constants.js';

const page = 400;

@Injectable()
export class AccountService {
  constructor(@Inject(SUPABASE) private readonly supabase: SupabaseClient) {}

  /** Removes one person's money records. Their sign-in and shared categories stay. */
  async clear(userId: string): Promise<void> {
    await this.remove('transactions', 'id', userId);
    await this.remove('scheduled_transactions', 'id', userId);
    await this.remove('debts', 'id', userId);
    await this.remove('goal_entries', 'id', userId);
    await this.remove('goals', 'id', userId);
    await this.remove('budgets', 'id', userId);
    await this.remove('accounts', 'id', userId);
    await this.remove('categories', 'id', userId);
    await this.remove('push_log', 'key', userId);
  }

  private async remove(table: string, column: string, userId: string): Promise<void> {
    for (;;) {
      const { data, error } = await this.supabase.from(table).select(column).eq('user_id', userId).limit(page);
      if (error) throw new BadRequestException(error.message);
      const ids = ((data ?? []) as unknown as Record<string, string>[]).map((row) => row[column]).filter(Boolean);
      if (ids.length === 0) return;
      const removed = await this.supabase.from(table).delete().in(column, ids);
      if (removed.error) throw new BadRequestException(removed.error.message);
      if (ids.length < page) return;
    }
  }
}
