import { DateTime } from 'luxon';

export const horizons = [7, 15, 30, 60, 90] as const;
export type Horizon = (typeof horizons)[number];

export function isHorizon(value: number): value is Horizon {
  return (horizons as readonly number[]).includes(value);
}

export function addDays(iso: string, days: number): string {
  const [year, month, day] = iso.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export function monthEnd(iso: string): string {
  const [year, month] = iso.split('-').map(Number);
  const last = new Date(Date.UTC(year, month, 0)).getUTCDate();
  return `${iso.slice(0, 7)}-${String(last).padStart(2, '0')}`;
}

export function daysInclusive(from: string, to: string): number {
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  return Math.floor((end - start) / 86_400_000) + 1;
}

export function weekday(iso: string): number {
  const [year, month, day] = iso.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

export function addMonths(iso: string, months: number, dayOfMonth?: number): string {
  const [year, month, day] = iso.split('-').map(Number);
  const wanted = dayOfMonth ?? day;
  const cursor = new Date(Date.UTC(year, month - 1 + months, 1));
  const last = new Date(Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth() + 1, 0)).getUTCDate();
  const date = Math.min(wanted, last);
  const yyyy = cursor.getUTCFullYear();
  const mm = String(cursor.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(date).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

export function eachDay(from: string, count: number): string[] {
  return Array.from({ length: count }, (_, index) => addDays(from, index));
}

export function todayInIndia(now = DateTime.now()): string {
  return now.setZone('Asia/Kolkata').toISODate() ?? now.toUTC().toISODate() ?? '1970-01-01';
}

export function monthsUntil(from: string, to: string): number {
  const [fromYear, fromMonth] = from.split('-').map(Number);
  const [toYear, toMonth] = to.split('-').map(Number);
  return Math.max(1, (toYear - fromYear) * 12 + (toMonth - fromMonth) + 1);
}
