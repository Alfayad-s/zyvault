import type { Schedule } from '../schedules/schedules.service.js';
import { dueTomorrow, localClock, postedMessage, summaryDue, weeklyMessage } from './jobs.js';

const plan = (overrides: Partial<Schedule>): Schedule => ({
  id: 's1',
  accountId: 'a1',
  accountName: 'HDFC',
  categoryId: 'c1',
  categoryName: 'Rent',
  amount: 1200000,
  kind: 'expense',
  note: 'house rent',
  repeat: 'monthly',
  dayOfMonth: 19,
  nextOn: '2026-10-19',
  atTime: null,
  ...overrides,
});

describe('push jobs', () => {
  it('reads the phone wall clock from its UTC offset', () => {
    const at = Date.parse('2026-10-18T13:45:00Z');
    expect(localClock(330, at)).toEqual({ today: '2026-10-18', time: '19:15', weekday: 0 });
    expect(localClock(330, Date.parse('2026-10-18T20:00:00Z')).today).toBe('2026-10-19');
  });

  it('warns about untimed bills due tomorrow from 9 in the morning', () => {
    const morning = { today: '2026-10-18', time: '09:05', weekday: 0 };
    const early = { ...morning, time: '07:00' };
    const schedules = [
      plan({}),
      plan({ id: 's2', atTime: '18:00' }),
      plan({ id: 's3', kind: 'income', categoryName: 'Salary' }),
      plan({ id: 's4', nextOn: '2026-10-25' }),
    ];
    expect(dueTomorrow(schedules, morning).map((item) => item.id)).toEqual(['s1']);
    expect(dueTomorrow(schedules, early)).toEqual([]);
  });

  it('words posted plans and the weekly summary', () => {
    expect(
      postedMessage({ scheduleId: 's1', occurredOn: '2026-10-18', amount: 3500000, kind: 'income', what: 'monthly salary', accountName: 'SBI' }),
    ).toEqual({ title: 'Added: ₹35,000 received', body: 'monthly salary · SBI', channel: 'plans' });
    expect(
      weeklyMessage([
        { amount: 45000, categoryName: 'Food' },
        { amount: 20000, categoryName: 'Fuel' },
        { amount: 15000, categoryName: 'Food' },
      ]),
    ).toEqual({
      title: 'This week you spent ₹800',
      body: 'Most went to Food (₹600). Tap to see where the rest went.',
      channel: 'summaries',
    });
    expect(weeklyMessage([])).toBeNull();
    expect(summaryDue({ today: '2026-10-18', time: '19:30', weekday: 0 })).toBe(true);
    expect(summaryDue({ today: '2026-10-19', time: '19:30', weekday: 1 })).toBe(false);
  });
});
