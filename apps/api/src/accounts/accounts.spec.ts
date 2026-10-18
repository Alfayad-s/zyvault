import { allRows } from '../supabase/all-rows.js';
import { balancesByAccount } from './accounts.service.js';

describe('balancesByAccount', () => {
  it('adds income and subtracts spending per account', () => {
    const totals = balancesByAccount([
      { account_id: 'sbi', amount: 5000000, kind: 'income' },
      { account_id: 'sbi', amount: 34000, kind: 'expense' },
      { account_id: 'cash', amount: 8000, kind: 'expense' },
    ]);
    expect(totals.get('sbi')).toBe(4966000);
    expect(totals.get('cash')).toBe(-8000);
    expect(totals.get('hdfc')).toBeUndefined();
  });
});

describe('allRows', () => {
  it('keeps reading pages past the 1000 row limit', async () => {
    const source = Array.from({ length: 2345 }, (_, index) => index);
    const asked: [number, number][] = [];
    const rows = await allRows((from, to) => {
      asked.push([from, to]);
      return Promise.resolve({ data: source.slice(from, to + 1), error: null });
    });
    expect(rows).toHaveLength(2345);
    expect(asked).toEqual([
      [0, 999],
      [1000, 1999],
      [2000, 2999],
    ]);
  });
});
