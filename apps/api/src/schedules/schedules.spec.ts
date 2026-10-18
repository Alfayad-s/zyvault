import {
  monthlyAfter,
  monthlyOnOrAfter,
  normalizeSpends,
  readSchedule,
  readTime,
} from '../agent/spend.js';
import { dueDates } from './schedules.service.js';

describe('monthly dates', () => {
  it('finds the next day of month, clamping short months', () => {
    expect(monthlyOnOrAfter('2026-10-18', 1)).toBe('2026-11-01');
    expect(monthlyOnOrAfter('2026-10-18', 18)).toBe('2026-10-18');
    expect(monthlyOnOrAfter('2026-10-18', 25)).toBe('2026-10-25');
    expect(monthlyOnOrAfter('2027-02-10', 31)).toBe('2027-02-28');
    expect(monthlyOnOrAfter('2026-12-20', 5)).toBe('2027-01-05');
    expect(monthlyAfter('2027-01-31', 31)).toBe('2027-02-28');
    expect(monthlyAfter('2027-02-28', 31)).toBe('2027-03-31');
  });
});

describe('readSchedule', () => {
  it('reads once and monthly schedules from the model', () => {
    expect(readSchedule({ repeat: 'once', day: 6 }, '2026-11-06', '2026-10-18')).toEqual({
      repeat: 'once',
      dayOfMonth: 6,
      nextOn: '2026-11-06',
      atTime: null,
    });
    expect(readSchedule({ repeat: 'monthly', day: 1 }, '2026-11-01', '2026-10-18')).toEqual({
      repeat: 'monthly',
      dayOfMonth: 1,
      nextOn: '2026-11-01',
      atTime: null,
    });
    expect(readSchedule({ repeat: 'once' }, '2026-10-10', '2026-10-18')).toBeNull();
    expect(readSchedule(null, '2026-10-10', '2026-10-18')).toBeNull();
  });

  it('keeps the future date only for scheduled items', () => {
    const [planned, past] = normalizeSpends(
      [
        { amount: 5000, date: '2026-11-06', kind: 'income', schedule: { repeat: 'once', day: 6 } },
        { amount: 100, date: '2026-11-06', kind: 'expense' },
      ],
      '2026-10-18',
    );
    expect(planned?.occurredOn).toBe('2026-11-06');
    expect(past?.occurredOn).toBe('2026-10-18');
    expect(past?.schedule).toBeNull();
    const [bill] = normalizeSpends(
      [{ amount: 50, date: '2026-11-06', schedule: { repeat: 'monthly', day: 6 } }],
      '2026-10-18',
      false,
    );
    expect(bill?.schedule).toBeNull();
  });
});

describe('times of day', () => {
  it('reads spoken and written times', () => {
    expect(readTime('18:00')).toBe('18:00');
    expect(readTime('6pm')).toBe('18:00');
    expect(readTime('6:30 PM')).toBe('18:30');
    expect(readTime('9.15am')).toBe('09:15');
    expect(readTime('12am')).toBe('00:00');
    expect(readTime('12 pm')).toBe('12:00');
    expect(readTime('25:00')).toBeNull();
    expect(readTime('evening')).toBeNull();
    expect(readTime(null)).toBeNull();
  });

  it('schedules later today only while the time is still ahead', () => {
    expect(readSchedule({ repeat: 'once', time: '18:00' }, '2026-10-18', '2026-10-18', '15:20')).toEqual({
      repeat: 'once',
      dayOfMonth: 18,
      nextOn: '2026-10-18',
      atTime: '18:00',
    });
    expect(readSchedule({ repeat: 'once', time: '09:00' }, '2026-10-18', '2026-10-18', '15:20')).toBeNull();
    expect(readSchedule({ repeat: 'once' }, '2026-10-18', '2026-10-18', '15:20')).toBeNull();
  });

  it('moves a monthly plan to next month when today\'s time has passed', () => {
    expect(readSchedule({ repeat: 'monthly', day: 18, time: '09:00' }, null, '2026-10-18', '15:20')?.nextOn).toBe(
      '2026-11-18',
    );
    expect(readSchedule({ repeat: 'monthly', day: 18, time: '20:00' }, null, '2026-10-18', '15:20')?.nextOn).toBe(
      '2026-10-18',
    );
  });

  it('posts a timed plan only after its time', () => {
    expect(dueDates('2026-10-18', 'once', 18, '2026-10-18', '18:00', '15:20').posts).toEqual([]);
    expect(dueDates('2026-10-18', 'once', 18, '2026-10-18', '18:00', '18:00').posts).toEqual(['2026-10-18']);
    expect(dueDates('2026-10-17', 'once', 17, '2026-10-18', '18:00', '09:00').posts).toEqual(['2026-10-17']);
    expect(dueDates('2026-10-18', 'monthly', 18, '2026-10-18', '18:00', '15:20')).toEqual({
      posts: [],
      next: '2026-10-18',
    });
  });
});

describe('dueDates', () => {
  it('posts every missed month and moves to the next one', () => {
    expect(dueDates('2026-08-01', 'monthly', 1, '2026-10-18')).toEqual({
      posts: ['2026-08-01', '2026-09-01', '2026-10-01'],
      next: '2026-11-01',
    });
    expect(dueDates('2026-10-18', 'monthly', 18, '2026-10-18')).toEqual({
      posts: ['2026-10-18'],
      next: '2026-11-18',
    });
    expect(dueDates('2026-11-06', 'once', 6, '2026-10-18')).toEqual({
      posts: [],
      next: '2026-11-06',
    });
    expect(dueDates('2026-10-06', 'once', 6, '2026-10-18').posts).toEqual(['2026-10-06']);
  });
});
