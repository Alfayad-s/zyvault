import { normalizeSpends } from '../agent/spend.js';
import { iconUrl } from '../categories/icons.js';
import { accountEffect, peopleFrom, type DebtEntry } from './debts.js';

function entry(person: string, type: DebtEntry['type'], amount: number, occurredOn: string): DebtEntry {
  return { id: `${person}-${occurredOn}`, person, type, amount, accountId: null, accountName: null, occurredOn, note: null };
}

describe('peopleFrom', () => {
  it('nets loans and paybacks per person, ignoring case and spaces', () => {
    const people = peopleFrom([
      entry('Ravi', 'lent', 50000, '2026-10-01'),
      entry('ravi ', 'got_back', 20000, '2026-10-05'),
      entry('Arjun', 'borrowed', 100000, '2026-10-02'),
      entry('Anu', 'lent', 30000, '2026-09-01'),
      entry('anu', 'got_back', 30000, '2026-09-10'),
    ]);
    expect(people).toEqual([
      { name: 'ravi', balance: 30000, lastOn: '2026-10-05', entries: 2 },
      { name: 'Arjun', balance: -100000, lastOn: '2026-10-02', entries: 1 },
      { name: 'anu', balance: 0, lastOn: '2026-09-10', entries: 2 },
    ]);
  });

  it('paying back what was borrowed settles the person', () => {
    const [arjun] = peopleFrom([
      entry('Arjun', 'borrowed', 100000, '2026-10-02'),
      entry('Arjun', 'paid_back', 100000, '2026-10-12'),
    ]);
    expect(arjun.balance).toBe(0);
  });
});

describe('accountEffect', () => {
  it('moves money out for lending and repaying, in for borrowing and getting back', () => {
    expect(accountEffect('lent', 500)).toBe(-500);
    expect(accountEffect('paid_back', 500)).toBe(-500);
    expect(accountEffect('borrowed', 500)).toBe(500);
    expect(accountEffect('got_back', 500)).toBe(500);
  });
});

describe('debt parsing', () => {
  it('keeps a valid debt and derives the money direction from it', () => {
    const [spend] = normalizeSpends(
      [{ amount: 2000, merchant: 'Arjun', kind: 'income', debt: { type: 'lent', person: 'Arjun' } }],
      '2026-10-18',
    );
    expect(spend.debt).toEqual({ type: 'lent', person: 'Arjun' });
    expect(spend.kind).toBe('expense');
  });

  it('falls back to the merchant as the person and drops unknown types', () => {
    const [named, unknown] = normalizeSpends(
      [
        { amount: 300, merchant: 'Anu', debt: { type: 'got_back' } },
        { amount: 300, merchant: 'Anu', debt: { type: 'gift' } },
      ],
      '2026-10-18',
    );
    expect(named.debt).toEqual({ type: 'got_back', person: 'Anu' });
    expect(named.kind).toBe('income');
    expect(unknown.debt).toBeNull();
  });

  it('a scheduled future amount is a schedule, not a debt', () => {
    const [spend] = normalizeSpends(
      [
        {
          amount: 5000,
          merchant: 'Ravi',
          date: '2026-11-06',
          kind: 'income',
          schedule: { repeat: 'once', day: 6 },
          debt: { type: 'got_back', person: 'Ravi' },
        },
      ],
      '2026-10-18',
    );
    expect(spend.schedule?.nextOn).toBe('2026-11-06');
    expect(spend.debt).toBeNull();
  });
});

describe('category icons', () => {
  it('builds a Cloudinary URL only for known icons', () => {
    expect(iconUrl('demo', 'food')).toBe(
      'https://res.cloudinary.com/demo/image/upload/c_fit,w_160,h_160/f_png/finance-track/category-icons/food',
    );
    expect(iconUrl('demo', 'rocket')).toBeNull();
    expect(iconUrl(undefined, 'food')).toBeNull();
  });
});
