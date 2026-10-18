import { normalizeSpends } from '../agent/spend.js';
import { buildUserPrompt } from '../agent/prompt.js';
import { matchGoal, savedByGoal } from './goals.js';

const goals = [
  { id: 'g1', name: 'Goa trip' },
  { id: 'g2', name: 'Emergency fund' },
  { id: 'g3', name: 'New phone' },
];

describe('matchGoal', () => {
  it('finds a goal by exact name, ignoring case and punctuation', () => {
    expect(matchGoal('goa trip', goals)?.id).toBe('g1');
    expect(matchGoal('Emergency-fund', goals)?.id).toBe('g2');
  });

  it('accepts a shorter or longer way of saying the name', () => {
    expect(matchGoal('phone', goals)?.id).toBe('g3');
    expect(matchGoal('the goa trip fund', goals)?.id).toBe('g1');
  });

  it('returns null for unknown goals', () => {
    expect(matchGoal('car', goals)).toBeNull();
    expect(matchGoal(null, goals)).toBeNull();
    expect(matchGoal('  ', goals)).toBeNull();
  });
});

describe('savedByGoal', () => {
  it('adds money put in and subtracts money taken out', () => {
    const saved = savedByGoal([
      { goal_id: 'g1', amount: 150000 },
      { goal_id: 'g1', amount: -50000 },
      { goal_id: 'g2', amount: 20000 },
    ]);
    expect(saved.get('g1')).toBe(100000);
    expect(saved.get('g2')).toBe(20000);
  });
});

describe('goal parsing', () => {
  it('keeps a goal and sets the money direction from the action', () => {
    const [add, takeOut, bad] = normalizeSpends(
      [
        { amount: 1500, goal: { name: 'Goa trip', action: 'add' } },
        { amount: 1000, kind: 'expense', goal: { name: 'Emergency fund', action: 'take_out' } },
        { amount: 10, goal: { name: 'Goa trip', action: 'spend' } },
      ],
      '2026-10-18',
    );
    expect([add.goal, add.kind]).toEqual([{ name: 'Goa trip', action: 'add' }, 'expense']);
    expect([takeOut.goal?.action, takeOut.kind]).toEqual(['take_out', 'income']);
    expect(bad.goal).toBeNull();
  });

  it('a goal entry is never also a debt', () => {
    const [spend] = normalizeSpends(
      [{ amount: 500, merchant: 'Ravi', goal: { name: 'Goa trip', action: 'add' }, debt: { type: 'lent', person: 'Ravi' } }],
      '2026-10-18',
    );
    expect(spend.debt).toBeNull();
  });

  it('lists the goals in the prompt only when there are some', () => {
    const base = { sentence: 'add 500 to goa', today: '2026-10-18', categories: { expense: [], income: [] }, memory: [] };
    expect(buildUserPrompt({ ...base, goals: ['Goa trip', 'New phone'] })).toContain('Goals: Goa trip; New phone.');
    expect(buildUserPrompt({ ...base, goals: [] }).split('\n')[2]).not.toContain('Goals:');
  });
});
