import { monthRange } from './month.js';
import { buildSummary } from './summary.js';

describe('monthRange', () => {
  it('returns the first day of the month and the next month', () => {
    expect(monthRange('2026-10')).toEqual({
      start: '2026-10-01',
      end: '2026-11-01',
    });
    expect(monthRange('2026-12')).toEqual({
      start: '2026-12-01',
      end: '2027-01-01',
    });
  });
});

describe('buildSummary', () => {
  it('combines the opening balance with income and expenses', () => {
    const summary = buildSummary(
      10000,
      [
        { amount: 50000, kind: 'income' },
        { amount: 1250, kind: 'expense' },
      ],
      [
        { amount: 50000, kind: 'income', categoryId: 'salary', categoryName: 'Salary' },
        { amount: 1250, kind: 'expense', categoryId: 'food', categoryName: 'Food' },
      ],
    );

    expect(summary.balance).toBe(58750);
    expect(summary.monthIncome).toBe(50000);
    expect(summary.monthExpense).toBe(1250);
    expect(summary.categories.map((category) => category.name)).toEqual([
      'Salary',
      'Food',
    ]);
  });
});
