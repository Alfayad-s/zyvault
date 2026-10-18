import type { Account } from '../accounts/accounts.service.js';
import {
  byCategory,
  compareText,
  filterRows,
  previousPeriod,
  readPlan,
  rupees,
  series,
  thisYearMonth,
  type AskRow,
} from './ask.js';
import { balanceAnswer, budgetsAnswer, goalsAnswer, peopleAnswer } from './ask.service.js';

const today = '2026-10-18';

const rows: AskRow[] = [
  { amount: 45000, kind: 'expense', occurredOn: '2026-10-01', note: 'Swiggy — biryani', categoryName: 'Food', accountId: 'a1', accountName: 'HDFC' },
  { amount: 20000, kind: 'expense', occurredOn: '2026-10-03', note: 'petrol', categoryName: 'Fuel', accountId: 'a2', accountName: 'Cash' },
  { amount: 15000, kind: 'expense', occurredOn: '2026-10-03', note: 'Swiggy — pizza', categoryName: 'Food', accountId: 'a1', accountName: 'HDFC' },
  { amount: 3500000, kind: 'income', occurredOn: '2026-10-06', note: 'monthly salary', categoryName: 'Salary', accountId: 'a1', accountName: 'HDFC' },
];

describe('readPlan', () => {
  it('fills in this month and clamps future dates', () => {
    const plan = readPlan({ intent: 'spending', to: '2026-12-01', categories: ['Food', null] }, today);
    expect(plan).toMatchObject({
      intent: 'spending',
      from: '2026-10-01',
      to: today,
      label: 'this month',
      categories: ['Food'],
      compare: false,
      sort: 'latest',
      limit: 5,
    });
  });

  it('falls back to unknown and keeps the limit sane', () => {
    const plan = readPlan({ intent: 'weather', limit: 400, from: '2026-10-20' }, today);
    expect([plan.intent, plan.limit, plan.from]).toEqual(['unknown', 20, today]);
  });
});

describe('thisYearMonth', () => {
  const plan = readPlan({ intent: 'transactions', from: '2025-09-01', to: '2025-09-30' }, today);

  it('moves a past month without a year into this year', () => {
    expect(thisYearMonth(plan, today, 'swiggy orders in september')).toMatchObject({
      from: '2026-09-01',
      to: '2026-09-30',
    });
  });

  it('keeps last year when the user says so or the month is still ahead', () => {
    expect(thisYearMonth(plan, today, 'swiggy orders in september 2025').from).toBe('2025-09-01');
    const december = readPlan({ intent: 'spending', from: '2025-12-01', to: '2025-12-31' }, today);
    expect(thisYearMonth(december, today, 'spending in december').from).toBe('2025-12-01');
  });
});

describe('filterRows and totals', () => {
  it('filters by kind, category, account and shop', () => {
    const plan = { categories: ['food'], search: null };
    expect(filterRows(rows, plan, 'expense', null).map((row) => row.amount)).toEqual([45000, 15000]);
    expect(filterRows(rows, { categories: [], search: 'swiggy' }, 'expense', null)).toHaveLength(2);
    expect(filterRows(rows, { categories: [], search: null }, 'expense', 'a2')).toHaveLength(1);
    expect(filterRows(rows, { categories: [], search: null }, 'income', null)).toHaveLength(1);
  });

  it('groups by category, biggest first', () => {
    const expenses = filterRows(rows, { categories: [], search: null }, 'expense', null);
    expect(byCategory(expenses).map((point) => [point.label, point.value])).toEqual([
      ['Food', 60000],
      ['Fuel', 20000],
    ]);
  });

  it('draws one bar per day within a month and one per month beyond', () => {
    const daily = series(rows.slice(0, 3), '2026-10-01', '2026-10-05');
    expect(daily.map((point) => point.value)).toEqual([45000, 0, 35000, 0, 0]);
    expect(daily[0].label).toBe('1 Oct');
    const monthly = series(rows, '2026-08-01', today);
    expect(monthly.map((point) => point.label)).toEqual(['Aug 26', 'Sep 26', 'Oct 26']);
  });
});

describe('answers', () => {
  it('formats rupees the Indian way', () => {
    expect(rupees(3500000)).toBe('₹35,000');
    expect(rupees(12345678)).toBe('₹1,23,456.78');
  });

  it('compares with the same length of time before', () => {
    expect(previousPeriod('2026-10-01', '2026-10-18')).toEqual({ from: '2026-09-13', to: '2026-09-30' });
    expect(compareText(60000, 50000)).toBe(' That is ₹100 more than the period before (20%).');
    expect(compareText(40000, 50000)).toBe(' That is ₹100 less than the period before (20%).');
  });

  const plan = readPlan({ intent: 'balance' }, today);

  it('sums balances', () => {
    const accounts = [
      { id: 'a1', name: 'HDFC', type: 'bank', openingBalance: 0, balance: 150000 },
      { id: 'a2', name: 'Cash', type: 'cash', openingBalance: 0, balance: 50000 },
    ] as Account[];
    expect(balanceAnswer(plan, accounts, null).answer).toBe('You have ₹2,000 across 2 accounts.');
    expect(balanceAnswer(plan, accounts, accounts[0]).answer).toBe('HDFC has ₹1,500.');
  });

  it('explains who owes whom', () => {
    const people = [
      { name: 'Ravi', balance: 30000 },
      { name: 'Arjun', balance: -100000 },
      { name: 'Anu', balance: 0 },
    ];
    expect(peopleAnswer(plan, people).answer).toBe('₹300 is owed to you and you owe ₹1,000.');
    expect(peopleAnswer({ ...plan, person: 'arjun' }, people).answer).toBe('You owe Arjun ₹1,000.');
    expect(peopleAnswer({ ...plan, person: 'Meera' }, people).answer).toBe(
      'You have no lending or borrowing with Meera.',
    );
  });

  it('tells how budgets are going', () => {
    const budgets = [
      { id: 'b1', categoryId: 'c1', categoryName: 'Food', month: '2026-10', limitAmount: 600000, spent: 432000 },
      { id: 'b2', categoryId: 'c2', categoryName: 'Shopping', month: '2026-10', limitAmount: 300000, spent: 350000 },
    ];
    expect(budgetsAnswer(plan, budgets).answer).toBe(
      'Over budget on Shopping by ₹500. ₹7,820 of ₹9,000 used in total.',
    );
    expect(budgetsAnswer({ ...plan, categories: ['food'] }, budgets).answer).toBe(
      'Food: ₹1,680 left of ₹6,000 (72% used).',
    );
    expect(budgetsAnswer(plan, budgets).items[0].label).toBe('Shopping');
    expect(budgetsAnswer(plan, []).answer).toContain('no budgets yet');
  });

  it('reports goal progress', () => {
    const goals = [{ name: 'Goa trip', icon: 'travel', saved: 500000, targetAmount: 2000000 }];
    expect(goalsAnswer({ ...plan, goal: 'goa' }, goals).answer).toBe(
      'Goa trip: ₹5,000 of ₹20,000 saved (25%), ₹15,000 to go.',
    );
  });
});
