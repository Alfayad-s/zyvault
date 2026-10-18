import { buildUserPrompt, memoryFrom } from './prompt.js';

describe('memoryFrom', () => {
  it('keeps distinct readable notes with their category', () => {
    const memory = memoryFrom([
      { note: 'Swiggy — biryani', categoryName: 'Food', kind: 'expense' },
      { note: 'swiggy — biryani', categoryName: 'Food', kind: 'expense' },
      { note: 'th', categoryName: 'Other', kind: 'expense' },
      { note: null, categoryName: 'Rent', kind: 'expense' },
      { note: 'gym fees', categoryName: 'Bills', kind: 'expense' },
    ]);
    expect(memory).toEqual([
      { note: 'Swiggy — biryani', categoryName: 'Food', kind: 'expense' },
      { note: 'gym fees', categoryName: 'Bills', kind: 'expense' },
    ]);
  });
});

describe('buildUserPrompt', () => {
  it('lists categories, examples, memory and the message with its weekday', () => {
    const prompt = buildUserPrompt({
      sentence: 'gym 800',
      today: '2026-10-19',
      categories: { expense: ['Food', 'Bills', 'Other'], income: ['Salary', 'Other income'] },
      memory: [{ note: 'gym fees', categoryName: 'Bills', kind: 'expense' }],
    });
    expect(prompt).toContain('Expense categories: Food, Bills, Other.');
    expect(prompt).toContain('Message: 35k got salary this month');
    expect(prompt).toContain('- "gym fees" -> Bills (expense)');
    expect(prompt.trimEnd().endsWith('Today: 2026-10-19 (Monday). Message: gym 800\nReply:')).toBe(true);
  });

  it('tells a receipt to use the payable total and skip the chat examples', () => {
    const prompt = buildUserPrompt({
      sentence: 'my share was 400',
      today: '2026-10-18',
      categories: { expense: ['Food', 'Bills'], income: ['Salary'] },
      memory: [],
      receipt: true,
    });
    expect(prompt).toContain('amount payable');
    expect(prompt).toContain('User note: my share was 400');
    expect(prompt).not.toContain('35k got salary');
  });
});
