import { cardPosition, nextDueDate } from './cards.js';

describe('cardPosition', () => {
  const card = 'card';

  it('frees the limit again when the bill is paid', () => {
    const open = cardPosition(5000000, card, [
      { amount: 120000, effect: 'spend', accountId: card, cardId: card },
    ]);
    expect(open).toEqual({ limit: 5000000, used: 120000, available: 4880000 });
    const paid = cardPosition(5000000, card, [
      { amount: 120000, effect: 'spend', accountId: card, cardId: card },
      { amount: 120000, effect: 'payment', accountId: 'bank', cardId: card },
    ]);
    expect(paid).toEqual({ limit: 5000000, used: 0, available: 5000000 });
  });

  it('does not let used fall below zero', () => {
    const position = cardPosition(100000, card, [
      { amount: 50000, effect: 'payment', accountId: 'bank', cardId: card },
    ]);
    expect(position.used).toBe(0);
    expect(position.available).toBe(100000);
  });
});

describe('nextDueDate', () => {
  it('uses this month until the due day has passed', () => {
    expect(nextDueDate(15, '2026-11-10')).toBe('2026-11-15');
    expect(nextDueDate(5, '2026-11-10')).toBe('2026-12-05');
    expect(nextDueDate(10, '2026-11-10')).toBe('2026-11-10');
    expect(nextDueDate(null, '2026-11-10')).toBeNull();
  });
});
