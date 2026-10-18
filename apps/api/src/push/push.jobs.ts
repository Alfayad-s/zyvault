import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { shiftDay } from '../agent/spend.js';
import { SchedulesService } from '../schedules/schedules.service.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import {
  dueMessage,
  dueTomorrow,
  localClock,
  postedMessage,
  summaryDue,
  weeklyMessage,
} from './jobs.js';
import { PushService, type Device } from './push.service.js';

const everyMs = 5 * 60_000;
const firstRunMs = 30_000;

type Relation = { name: string } | { name: string }[] | null;

@Injectable()
export class PushJobs implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PushJobs.name);
  private timer: NodeJS.Timeout | null = null;
  private first: NodeJS.Timeout | null = null;
  private running = false;

  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly push: PushService,
    private readonly schedules: SchedulesService,
  ) {}

  onModuleInit() {
    if (!this.push.configured) {
      this.logger.log('Push notifications are off (set FIREBASE_SERVICE_ACCOUNT to turn them on)');
      return;
    }
    this.logger.log('Push notifications are on');
    this.first = setTimeout(() => void this.tick(), firstRunMs);
    this.timer = setInterval(() => void this.tick(), everyMs);
  }

  onModuleDestroy() {
    if (this.first) clearTimeout(this.first);
    if (this.timer) clearInterval(this.timer);
  }

  async tick() {
    if (this.running) return;
    this.running = true;
    try {
      const byUser = new Map<string, Device[]>();
      for (const device of await this.push.devices()) {
        byUser.set(device.userId, [...(byUser.get(device.userId) ?? []), device]);
      }
      for (const [userId, devices] of byUser) {
        try {
          await this.forUser(userId, devices);
        } catch (caught) {
          this.logger.warn(`Push run failed for a user: ${String(caught)}`);
        }
      }
    } finally {
      this.running = false;
    }
  }

  private async forUser(userId: string, devices: Device[]) {
    const tokens = devices.map((device) => device.token);
    const clock = localClock(devices[0].utcOffsetMinutes);

    const { entries } = await this.schedules.runDue(userId, clock.today, clock.time, '09:00');
    for (const entry of entries) {
      if (await this.push.once(userId, `posted:${entry.scheduleId}:${entry.occurredOn}`)) {
        await this.push.toUser(userId, tokens, postedMessage(entry));
      }
    }

    for (const schedule of dueTomorrow(await this.schedules.list(userId), clock)) {
      if (await this.push.once(userId, `due:${schedule.id}:${schedule.nextOn}`)) {
        await this.push.toUser(userId, tokens, dueMessage(schedule));
      }
    }

    if (summaryDue(clock) && (await this.push.once(userId, `week:${clock.today}`))) {
      const rows = await allRows<{ amount: number; category: Relation }>((from, to) =>
        this.supabase
          .from('transactions')
          .select('amount, category:categories(name)')
          .eq('user_id', userId)
          .eq('kind', 'expense')
          .gte('occurred_on', shiftDay(clock.today, -6))
          .lte('occurred_on', clock.today)
          .order('id')
          .range(from, to),
      );
      const message = weeklyMessage(
        rows.map((row) => ({
          amount: row.amount,
          categoryName: Array.isArray(row.category) ? (row.category[0]?.name ?? 'Other') : (row.category?.name ?? 'Other'),
        })),
      );
      if (message) await this.push.toUser(userId, tokens, message);
    }
  }
}
