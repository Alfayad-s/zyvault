import {
  categoryNameFor,
  normalizeSpends,
  readLlmJson,
  resolveDate,
  spendNote,
  toPaise,
} from './spend.js';

describe('toPaise', () => {
  it('turns rupees into whole paise', () => {
    expect(toPaise(450)).toBe(45000);
    expect(toPaise(1500.5)).toBe(150050);
    expect(toPaise('₹1,299.99')).toBe(129999);
    expect(toPaise(0.1 + 0.2)).toBe(30);
    expect(toPaise('35k')).toBe(3_500_000);
    expect(toPaise('1.5 lakh')).toBe(15_000_000);
    expect(toPaise('Rs 200')).toBe(20000);
  });

  it('rejects zero, negatives and text', () => {
    expect(toPaise(0)).toBeNull();
    expect(toPaise(-20)).toBeNull();
    expect(toPaise('pizza')).toBeNull();
    expect(toPaise(null)).toBeNull();
  });
});

describe('resolveDate', () => {
  it('uses the phone day for relative words', () => {
    expect(resolveDate('today', '2026-10-18')).toBe('2026-10-18');
    expect(resolveDate('yesterday', '2026-10-18')).toBe('2026-10-17');
    expect(resolveDate('last night', '2026-03-01')).toBe('2026-02-28');
    expect(resolveDate(undefined, '2026-10-18')).toBe('2026-10-18');
  });

  it('keeps past ISO dates and clamps future ones', () => {
    expect(resolveDate('2026-10-10', '2026-10-18')).toBe('2026-10-10');
    expect(resolveDate('2026-12-25', '2026-10-18')).toBe('2026-10-18');
    expect(resolveDate('next week', '2026-10-18')).toBe('2026-10-18');
  });
});

describe('categoryNameFor', () => {
  it('maps zero-shot labels onto the seeded categories', () => {
    expect(categoryNameFor('Groceries', 0.8, 'expense')).toBe('Groceries');
    expect(categoryNameFor('Dining Out', 0.8, 'expense')).toBe('Food');
    expect(categoryNameFor('Transport', 0.8, 'expense')).toBe('Transport');
    expect(categoryNameFor('Utilities', 0.8, 'expense')).toBe('Bills');
    expect(categoryNameFor('Rent', 0.8, 'expense')).toBe('Rent');
    expect(categoryNameFor('Entertainment', 0.8, 'expense')).toBe('Entertainment');
    expect(categoryNameFor('Shopping', 0.8, 'expense')).toBe('Shopping');
    expect(categoryNameFor('Salary', 0.8, 'income')).toBe('Salary');
  });

  it('falls back to Other when unsure or unknown', () => {
    expect(categoryNameFor('Groceries', 0.1, 'expense')).toBe('Other');
    expect(categoryNameFor('Pets', 0.9, 'expense')).toBe('Other');
    expect(categoryNameFor(null, 0, 'income')).toBe('Other income');
  });
});

describe('readLlmJson and normalizeSpends', () => {
  it('reads fenced arrays and keeps several spends', () => {
    const reply =
      '```json\n[{"amount":150,"currency":"INR","merchant":null,"date":"today","rawDescription":"food","kind":"expense"},' +
      '{"amount":"80","currency":"inr","merchant":"HP","date":"yesterday","rawDescription":"petrol","kind":"expense"}]\n```';
    const spends = normalizeSpends(readLlmJson(reply), '2026-10-18');
    expect(spends).toEqual([
      {
        amount: 15000,
        currency: 'INR',
        merchant: null,
        occurredOn: '2026-10-18',
        rawDescription: 'food',
        kind: 'expense',
        category: null,
        schedule: null,
        debt: null,
        goal: null,
        account: null,
      },
      {
        amount: 8000,
        currency: 'INR',
        merchant: 'HP',
        occurredOn: '2026-10-17',
        rawDescription: 'petrol',
        kind: 'expense',
        category: null,
        schedule: null,
        debt: null,
        goal: null,
        account: null,
      },
    ]);
    expect(spendNote(spends[1])).toBe('HP — petrol');
  });

  it('accepts a single object and drops foreign or empty amounts', () => {
    expect(normalizeSpends(readLlmJson('{"amount":50000,"kind":"income","rawDescription":"salary"}'), '2026-10-18')).toHaveLength(1);
    expect(normalizeSpends(readLlmJson('[{"amount":10,"currency":"USD"},{"amount":0}]'), '2026-10-18')).toEqual([]);
    expect(() => readLlmJson('sorry, I cannot help')).toThrow();
  });
});
