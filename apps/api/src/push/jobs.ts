import { shiftDay } from '../agent/spend.js';
import { rupees } from '../ask/ask.js';
import type { PostedEntry, Schedule } from '../schedules/schedules.service.js';
import type { PushMessage } from './fcm.client.js';

export type LocalClock = { today: string; time: string; weekday: number };

/** The user's wall clock from their phone's UTC offset. weekday: 0 = Sunday. */
export function localClock(utcOffsetMinutes: number, nowMs = Date.now()): LocalClock {
  const local = new Date(nowMs + utcOffsetMinutes * 60_000);
  return {
    today: local.toISOString().slice(0, 10),
    time: local.toISOString().slice(11, 16),
    weekday: local.getUTCDay(),
  };
}

export function postedMessage(entry: PostedEntry): PushMessage {
  const amount = rupees(entry.amount);
  const where = entry.accountName ? ` · ${entry.accountName}` : '';
  return entry.kind === 'income'
    ? { title: `Added: ${amount} received`, body: `${entry.what}${where}`, channel: 'plans' }
    : { title: `Paid: ${amount}`, body: `${entry.what}${where} · saved from your plan`, channel: 'plans' };
}

/** Untimed bills due tomorrow, from 09:00 local time. Timed plans are pushed when they post. */
export function dueTomorrow(schedules: Schedule[], clock: LocalClock): Schedule[] {
  if (clock.time < '09:00') return [];
  const tomorrow = shiftDay(clock.today, 1);
  return schedules.filter(
    (schedule) => schedule.kind === 'expense' && !schedule.atTime && schedule.nextOn === tomorrow,
  );
}

export function dueMessage(schedule: Schedule): PushMessage {
  return {
    title: `Due tomorrow: ${rupees(schedule.amount)}`,
    body: schedule.note || schedule.categoryName,
    channel: 'plans',
  };
}

/** Sunday from 19:00 local time. */
export function summaryDue(clock: LocalClock): boolean {
  return clock.weekday === 0 && clock.time >= '19:00';
}

export function weeklyMessage(
  rows: { amount: number; categoryName: string }[],
): PushMessage | null {
  const total = rows.reduce((sum, row) => sum + row.amount, 0);
  if (total === 0) return null;
  const byCategory = new Map<string, number>();
  for (const row of rows) byCategory.set(row.categoryName, (byCategory.get(row.categoryName) ?? 0) + row.amount);
  const [top, topAmount] = [...byCategory.entries()].sort((a, b) => b[1] - a[1])[0];
  return {
    title: `This week you spent ${rupees(total)}`,
    body: `Most went to ${top} (${rupees(topAmount)}). Tap to see where the rest went.`,
    channel: 'summaries',
  };
}
