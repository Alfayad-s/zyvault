import { describe, expect, it } from 'vitest';
import { buildForecast, buildHealth, buildOverview, buildSafeToSpend, detectAnomalies, applyScenario, lendingTotals } from './engine.js';
import type { LedgerTxn, ScheduleItem } from './types.js';

const today = '2026-11-07';

function txn(partial: Partial<LedgerTxn> & Pick<LedgerTxn, 'id' | 'amount' | 'occurredOn'>): LedgerTxn {
  return {
    kind: 'expense',
    categoryId: 'food',
    categoryName: 'Food',
    accountId: 'cash',
    note: null,
    ...partial,
  };
}

describe('financial engine', () => {
  it('keeps lending out of the cash balance and reports it separately', () => {
    const overview = buildOverview({
      today,
      balance: 50_000,
      monthIncome: 80_000,
      monthExpense: 30_000,
      categories: [],
      transactions: [],
      budgets: [],
      schedules: [],
      goals: [],
      people: [{ name: 'Anu', balance: 20_000 }, { name: 'Ravi', balance: -5_000 }],
    });
    expect(overview.balance).toBe(50_000);
    expect(overview.outstandingLent).toBe(20_000);
    expect(overview.outstandingBorrowed).toBe(5_000);
    expect(overview.monthSavings).toBe(50_000);
    expect(lendingTotals([{ name: 'A', balance: 0 }])).toEqual({ lent: 0, borrowed: 0 });
  });

  it('projects a monthly plan and does not add estimated income to the balance', () => {
    const rent: ScheduleItem = {
      id: 'rent',
      amount: 10_000,
      kind: 'expense',
      categoryName: 'Rent',
      note: null,
      repeat: 'monthly',
      nextOn: '2026-11-10',
      dayOfMonth: 10,
    };
    const history: LedgerTxn[] = [];
    for (const date of ['2026-10-03', '2026-10-10', '2026-10-17', '2026-10-24', '2026-10-31']) {
      history.push(txn({ id: `in-${date}`, amount: 100_000, kind: 'income', categoryName: 'Salary', categoryId: 'salary', occurredOn: date }));
    }
    const forecast = buildForecast({ today, days: 7, balance: 50_000, transactions: history, schedules: [rent] });
    const rentDay = forecast.points.find((point) => point.date === '2026-11-10');
    expect(rentDay?.confirmedOut).toBe(10_000);
    expect(forecast.points.every((point) => point.estimatedIn === 0 || point.projectedBalance <= forecast.startBalance)).toBe(true);
    const withIncome = forecast.points.reduce((sum, point) => sum + point.estimatedIn, 0);
    expect(withIncome).toBeGreaterThan(0);
    expect(forecast.endBalance).toBe(forecast.startBalance - 10_000);
  });

  it('subtracts essentials, reserve and this month’s goal from safe-to-spend', () => {
    const safe = buildSafeToSpend({
      today,
      balance: 100_000,
      schedules: [{
        id: 'rent',
        amount: 20_000,
        kind: 'expense',
        categoryName: 'Rent',
        note: null,
        repeat: 'once',
        nextOn: '2026-11-20',
        dayOfMonth: 20,
      }],
      goals: [{ id: 'g', name: 'Trip', targetAmount: 30_000, saved: 0, targetDate: '2026-11-30' }],
      profile: { emergencyReserve: 10_000, monthlyDiscretionaryLimit: null, essentialCategories: [] },
    });
    expect(safe.safeToSpend).toBe(40_000);
    expect(safe.lines.map((line) => line.amount)).toEqual([100_000, -20_000, -10_000, -30_000]);
    expect(safe.daily).toBe(Math.trunc(40_000 / safe.daysLeft));
  });

  it('leaves a health component empty when income is missing', () => {
    const health = buildHealth({
      months: [{ month: '2026-11', income: 0, expense: 5_000 }],
      budgets: [],
      recurringExpense: 1_000,
      emergencyReserve: 0,
      typicalMonthlyExpense: 5_000,
    });
    expect(health.components.find((item) => item.id === 'expenseToIncome')?.score).toBeNull();
    expect(health.score).not.toBeNull();
  });

  it('flags a large category amount only after enough history', () => {
    const history = Array.from({ length: 8 }, (_, index) => txn({
      id: `h${index}`,
      amount: 1_000,
      occurredOn: `2026-10-${String(index + 1).padStart(2, '0')}`,
    }));
    const quiet = detectAnomalies([...history, txn({ id: 'small', amount: 1_200, occurredOn: today })], today);
    expect(quiet.some((item) => item.kind === 'unusual_amount')).toBe(false);
    const loud = detectAnomalies([...history, txn({ id: 'big', amount: 50_000, occurredOn: today })], today);
    expect(loud.some((item) => item.kind === 'unusual_amount' && item.severity === 'watch')).toBe(true);
    expect(loud.some((item) => item.reason.toLowerCase().includes('fraud warning'))).toBe(true);
    expect(loud.every((item) => !item.reason.toLowerCase().includes('fraud alert'))).toBe(true);
  });

  it('drops a purchase from the forecast without treating it as saved money', () => {
    const forecast = buildForecast({ today, days: 3, balance: 80_000, transactions: [], schedules: [] });
    const scenario = applyScenario(forecast, { kind: 'purchase', amount: 30_000 });
    expect(scenario.scenarioEnd).toBe(50_000);
    expect(scenario.delta).toBe(-30_000);
    expect(scenario.assumptions.some((line) => line.includes('what-if'))).toBe(true);
  });
});
