import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseClient } from '@supabase/supabase-js';
import { iconUrl } from '../categories/icons.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { GoalDto, GoalEntryDto } from './dto/goal.dto.js';
import { matchGoal, missingGoalTables, savedByGoal, type Goal, type GoalEntry } from './goals.js';

type GoalRow = {
  id: string;
  name: string;
  icon: string | null;
  target_amount: number;
  target_date: string | null;
  created_at: string;
};

type EntryRow = {
  id: string;
  goal_id: string;
  amount: number;
  occurred_on: string;
  note: string | null;
};

const goalColumns = 'id, name, icon, target_amount, target_date, created_at';
const entryColumns = 'id, goal_id, amount, occurred_on, note';

function toEntry(row: EntryRow): GoalEntry {
  return {
    id: row.id,
    goalId: row.goal_id,
    amount: row.amount,
    occurredOn: row.occurred_on,
    note: row.note,
  };
}

@Injectable()
export class GoalsService {
  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly config: ConfigService,
  ) {}

  async list(userId: string): Promise<Goal[]> {
    const { data, error } = await this.supabase
      .from('goals')
      .select(goalColumns)
      .eq('user_id', userId)
      .order('created_at', { ascending: true });
    if (missingGoalTables(error)) return [];
    if (error) throw new BadRequestException(error.message);
    const entries = await allRows<{ goal_id: string; amount: number }>((from, to) =>
      this.supabase
        .from('goal_entries')
        .select('goal_id, amount')
        .eq('user_id', userId)
        .order('id')
        .range(from, to),
    );
    const saved = savedByGoal(entries);
    return ((data ?? []) as GoalRow[]).map((row) => this.toGoal(row, saved.get(row.id) ?? 0));
  }

  async find(userId: string, name: string | null): Promise<Goal | null> {
    return matchGoal(name, await this.list(userId));
  }

  async create(userId: string, input: GoalDto): Promise<Goal> {
    const { data, error } = await this.supabase
      .from('goals')
      .insert({ user_id: userId, ...fields(input) })
      .select(goalColumns)
      .single();
    if (missingGoalTables(error)) throw this.schemaMissing();
    if (error || !data) throw new BadRequestException(error?.message ?? 'Could not create the goal');
    return this.toGoal(data as GoalRow, 0);
  }

  async update(userId: string, id: string, input: GoalDto): Promise<Goal> {
    const { data, error } = await this.supabase
      .from('goals')
      .update(fields(input))
      .eq('id', id)
      .eq('user_id', userId)
      .select(goalColumns)
      .maybeSingle();
    if (error) throw new BadRequestException(error.message);
    if (!data) throw new NotFoundException('Goal not found');
    return this.toGoal(data as GoalRow, await this.savedIn(userId, id));
  }

  async remove(userId: string, id: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('goals')
      .delete()
      .eq('id', id)
      .eq('user_id', userId)
      .select('id');
    if (error) throw new BadRequestException(error.message);
    if (!data || data.length === 0) throw new NotFoundException('Goal not found');
  }

  async entries(userId: string, goalId: string): Promise<GoalEntry[]> {
    const { data, error } = await this.supabase
      .from('goal_entries')
      .select(entryColumns)
      .eq('user_id', userId)
      .eq('goal_id', goalId)
      .order('occurred_on', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(200);
    if (error) throw new BadRequestException(error.message);
    return ((data ?? []) as EntryRow[]).map(toEntry);
  }

  async addEntry(
    userId: string,
    goalId: string,
    input: GoalEntryDto,
  ): Promise<{ entry: GoalEntry; goal: Goal }> {
    const goal = (await this.list(userId)).find((item) => item.id === goalId);
    if (!goal) throw new NotFoundException('Goal not found');
    if (input.type === 'take_out' && input.amount > goal.saved) {
      throw new BadRequestException(
        goal.saved === 0
          ? `Nothing is saved in ${goal.name} yet`
          : `Only ₹${goal.saved / 100} is saved in ${goal.name}`,
      );
    }
    const amount = input.type === 'add' ? input.amount : -input.amount;
    const { data, error } = await this.supabase
      .from('goal_entries')
      .insert({
        user_id: userId,
        goal_id: goalId,
        amount,
        occurred_on: input.occurredOn,
        note: input.note?.trim() || null,
      })
      .select(entryColumns)
      .single();
    if (error || !data) throw new BadRequestException(error?.message ?? 'Could not save that');
    return { entry: toEntry(data as EntryRow), goal: { ...goal, saved: goal.saved + amount } };
  }

  async removeEntry(userId: string, entryId: string): Promise<void> {
    const { data, error } = await this.supabase
      .from('goal_entries')
      .delete()
      .eq('id', entryId)
      .eq('user_id', userId)
      .select('id');
    if (error) throw new BadRequestException(error.message);
    if (!data || data.length === 0) throw new NotFoundException('Entry not found');
  }

  private async savedIn(userId: string, goalId: string): Promise<number> {
    const rows = await allRows<{ goal_id: string; amount: number }>((from, to) =>
      this.supabase
        .from('goal_entries')
        .select('goal_id, amount')
        .eq('user_id', userId)
        .eq('goal_id', goalId)
        .order('id')
        .range(from, to),
    );
    return savedByGoal(rows).get(goalId) ?? 0;
  }

  private schemaMissing() {
    return new BadRequestException('Run the latest supabase/schema.sql in Supabase to add goals');
  }

  private toGoal(row: GoalRow, saved: number): Goal {
    return {
      id: row.id,
      name: row.name,
      icon: row.icon,
      iconUrl: iconUrl(this.config.get<string>('CLOUDINARY_CLOUD_NAME'), row.icon),
      targetAmount: row.target_amount,
      targetDate: row.target_date,
      saved,
      createdAt: row.created_at,
    };
  }
}

function fields(input: GoalDto) {
  return {
    name: input.name.trim(),
    icon: input.icon,
    target_amount: input.targetAmount,
    target_date: input.targetDate ?? null,
  };
}
