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

  it('keeps a card swipe out of cash and a bill payment out of categories', () => {
    const summary = buildSummary(
      100000,
      [
        { amount: 20000, kind: 'expense', cardEffect: 'spend' },
        { amount: 20000, kind: 'expense', cardEffect: 'payment' },
      ],
      [
        {
          amount: 20000,
          kind: 'expense',
          cardEffect: 'spend',
          categoryId: 'food',
          categoryName: 'Food',
          accountId: 'card',
        },
        {
          amount: 20000,
          kind: 'expense',
          cardEffect: 'payment',
          categoryId: 'other',
          categoryName: 'Other',
          accountId: 'bank',
        },
      ],
    );
    expect(summary.balance).toBe(80000);
    expect(summary.monthExpense).toBe(20000);
    expect(summary.categories.map((category) => category.name)).toEqual(['Food']);
    expect(summary.accountChanges).toEqual([{ accountId: 'bank', change: -20000 }]);
  });
});
