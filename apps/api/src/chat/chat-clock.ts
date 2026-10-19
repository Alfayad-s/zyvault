import { DateTime } from 'luxon';

/** The ledger and the person are in India. Luxon keeps the clock on that zone. */
export const chatZone = 'Asia/Kolkata';

/** Weekday, time, and how many days remain in the month, for the chat prompt. */
export function describeNow(today: string, now = new Date()): string {
  const clock = DateTime.fromJSDate(now).setZone(chatZone);
  const parsed = DateTime.fromISO(today, { zone: chatZone });
  const day = parsed.isValid ? parsed : clock;
  const daysInMonth = day.daysInMonth ?? clock.daysInMonth ?? 30;
  const left = Math.max(0, daysInMonth - day.day);
  const leftLabel = left === 1 ? '1 day left' : `${left} days left`;
  return `Clock: ${day.toFormat('cccc, d LLLL yyyy')}, ${clock.toFormat('h:mm a')} IST. Day ${day.day} of ${daysInMonth}. ${leftLabel} in ${day.toFormat('LLLL')} after today.`;
}
