import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AccountsService } from '../accounts/accounts.service.js';
import { chatMaxTokens, groqChatModel, LlmClient, parserModels } from '../agent/llm.client.js';
import type { BudgetsService } from '../budgets/budgets.service.js';
import type { SummaryService } from '../summary/summary.service.js';
import { describeNow } from './chat-clock.js';
import { buildChatInstruction, recentMessages } from './chat-prompt.js';
import type { TransactionsService } from '../transactions/transactions.service.js';
import type { CategoriesService } from '../categories/categories.service.js';
import type { DebtsService } from '../debts/debts.service.js';
import type { GoalsService } from '../goals/goals.service.js';
import type { SchedulesService } from '../schedules/schedules.service.js';
import { resolveAction } from './chat-action.js';
import { ChatService } from './chat.service.js';

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('parserModels', () => {
  it('keeps gpt-oss-20b off the spend parser, including when that model is configured', () => {
    expect(parserModels(undefined)).toEqual(['openai/gpt-oss-120b', 'qwen/qwen3.8-27b']);
    expect(parserModels('openai/gpt-oss-20b')).toEqual(['openai/gpt-oss-120b', 'qwen/qwen3.8-27b']);
    expect(parserModels('qwen/qwen3.8-27b')).toEqual(['qwen/qwen3.8-27b']);
  });
});

describe('recentMessages', () => {
  it('keeps the last eight turns and clips each one', () => {
    const messages = [
      { role: 'user', content: 'one' },
      { role: 'assistant', content: 'two' },
      { role: 'user', content: `  ${'x'.repeat(500)}` },
      { role: 'system', content: 'ignore' },
      { role: 'assistant', content: 'four' },
      { role: 'user', content: 'five' },
      { role: 'assistant', content: 'six' },
    ];
    const kept = recentMessages(messages);
    expect(kept.map((message) => message.role)).toEqual([
      'user',
      'assistant',
      'user',
      'assistant',
      'user',
      'assistant',
    ]);
    expect(kept[2]?.content).toHaveLength(400);
    expect(kept.at(-1)?.content).toBe('six');
  });
});

describe('describeNow', () => {
  it('states the weekday, the India time, and the days left in the month', () => {
    const clock = describeNow('2026-10-19', new Date('2026-10-19T12:00:00Z'));
    expect(clock).toContain('Monday, 19 October 2026');
    expect(clock).toContain('5:30 PM IST');
    expect(clock).toContain('Day 19 of 31');
    expect(clock).toContain('12 days left in October after today');
  });
});

describe('buildChatInstruction', () => {
  it('stays a short fixed prompt plus a compact snapshot', () => {
    const instruction = buildChatInstruction({
      clock: 'Clock: Monday, 19 October 2026, 5:30 PM IST. Day 19 of 31. 12 days left in October after today.',
      balance: '₹1,000',
      monthIncome: '₹50,000',
      monthExpense: '₹12,000',
      categories: ['Food ₹4,000', 'Fuel ₹1,000'],
      accounts: ['HDFC ₹800'],
      budgets: ['Food spent ₹4,000 of ₹6,000'],
    });
    expect(instruction).toContain('Read the person\'s latest message');
    expect(instruction).toContain('Use only the snapshot');
    expect(instruction).toContain('12 days left in October');
    expect(instruction).toContain('Food ₹4,000');
    expect(instruction.length).toBeLessThan(4_500);
  });
});

function reply(body: unknown, status = 200) {
  return { ok: status >= 200 && status < 300, status, json: () => Promise.resolve(body) };
}

describe('resolveAction', () => {
  const context = {
    today: '2026-10-19',
    accounts: [{ id: '550e8400-e29b-41d4-a716-446655440000', name: 'HDFC' }],
    categories: [{ id: '550e8400-e29b-41d4-a716-446655440001', name: 'Food', kind: 'expense' as const }],
    goals: [{ id: '550e8400-e29b-41d4-a716-446655440002', name: 'Goa' }],
    transactionIds: [],
  };

  it('prepares a review and does not treat the payment as saved', () => {
    const resolved = resolveAction(
      { type: 'log', kind: 'expense', amount: 240, category: 'Food', note: 'Swiggy' },
      context,
    );
    expect(resolved.proposal?.title).toBe('Log this?');
    expect(resolved.proposal?.lines).toContain('Expense ₹240');
    expect(resolved.proposal?.action.amount).toBe(24000);
    expect(resolved.proposal?.action.accountId).toBe(context.accounts[0]?.id);
  });

  it('turns a future payment into a one-time schedule from the date', () => {
    const resolved = resolveAction(
      { type: 'log', kind: 'expense', amount: 2000, category: 'Food', date: '2026-10-21', note: 'Anjali' },
      context,
    );
    expect(resolved.proposal?.title).toBe('Schedule this?');
    expect(resolved.proposal?.action.repeat).toBe('once');
    expect(resolved.proposal?.action.dayOfMonth).toBe(21);
    expect(resolved.proposal?.action.nextOn).toBe('2026-10-21');
    expect(resolved.problem).toBeUndefined();
  });

  it('asks for the missing account instead of saving', () => {
    const resolved = resolveAction(
      { type: 'log', kind: 'expense', amount: 50, category: 'Food', account: 'Cash' },
      context,
    );
    expect(resolved.proposal).toBeNull();
    expect(resolved.problem).toContain('which account');
  });
});

describe('ChatService', () => {
  const summary = {
    forMonth: () =>
      Promise.resolve({
        balance: 100000,
        monthIncome: 5000000,
        monthExpense: 1200000,
        categories: [
          { categoryId: 'food', name: 'Food', kind: 'expense' as const, total: 400000 },
          { categoryId: 'pay', name: 'Salary', kind: 'income' as const, total: 5000000 },
        ],
      }),
  } as unknown as SummaryService;
  const accounts = {
    list: () =>
      Promise.resolve([
        { id: 'a', name: 'HDFC', type: 'bank', openingBalance: 0, createdAt: '', bankId: null, balance: 80000 },
      ]),
  } as unknown as AccountsService;
  const budgets = {
    list: () =>
      Promise.resolve([
        { id: 'b', categoryId: 'food', categoryName: 'Food', month: '2026-10', limitAmount: 600000, spent: 400000 },
      ]),
  } as unknown as BudgetsService;

  const transactions = {
    list: () =>
      Promise.resolve([
        {
          id: 't',
          accountId: 'a',
          accountName: 'HDFC',
          categoryId: 'food',
          categoryName: 'Food',
          amount: 24000,
          kind: 'expense' as const,
          occurredOn: '2026-10-18',
          note: 'Swiggy',
        },
      ]),
  } as unknown as TransactionsService;

  const categories = { list: () => Promise.resolve([]) } as unknown as CategoriesService;
  const goalsSvc = { list: () => Promise.resolve([]) } as unknown as GoalsService;
  const debts = {} as DebtsService;
  const schedules = {} as SchedulesService;

  function service() {
    const config = { get: (key: string) => (key === 'GROQ_API_KEY' ? 'q' : undefined) } as unknown as ConfigService;
    return new ChatService(
      new LlmClient(config),
      summary,
      accounts,
      budgets,
      transactions,
      categories,
      goalsSvc,
      debts,
      schedules,
    );
  }

  it('calls only gpt-oss-20b once, with a short reply cap and the last few messages', async () => {
    const fetch = vi.fn(() =>
      Promise.resolve(reply({ choices: [{ message: { content: 'You spent ₹4,000 on food.' } }] })),
    );
    vi.stubGlobal('fetch', fetch);
    const history = [
      { role: 'user' as const, content: 'one' },
      { role: 'assistant' as const, content: 'two' },
      { role: 'user' as const, content: 'three' },
      { role: 'assistant' as const, content: 'four' },
      { role: 'user' as const, content: 'how much on food?' },
    ];

    const result = await service().reply('user', {
      today: '2026-10-19',
      memory: 'User: asked about rent',
      messages: history,
    });

    expect(result.reply).toBe('You spent ₹4,000 on food.');
    expect(fetch).toHaveBeenCalledTimes(1);
    const [url, init] = fetch.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://api.groq.com/openai/v1/chat/completions');
    const body = JSON.parse(init.body as string) as {
      model: string;
      max_tokens: number;
      reasoning_effort: string;
      messages: { role: string; content: string }[];
    };
    expect(body.model).toBe(groqChatModel);
    expect(body.max_tokens).toBe(chatMaxTokens);
    expect(body.reasoning_effort).toBe('low');
    expect(body.messages[0]?.role).toBe('system');
    expect(body.messages[0]?.content).toContain('Swiggy');
    expect(body.messages[0]?.content).toContain('days left');
    expect(body.messages[0]?.content).toContain('asked about rent');
    expect(body.messages.slice(1).map((message) => message.content)).toEqual([
      'one',
      'two',
      'three',
      'four',
      'how much on food?',
    ]);
  });

  it('says the daily allowance is used when Groq returns 429', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Promise.resolve(reply({ error: 'tokens' }, 429))));
    await expect(
      service().reply('user', { today: '2026-10-19', messages: [{ role: 'user', content: 'balance?' }] }),
    ).rejects.toMatchObject({
      message: expect.stringContaining('The daily AI allowance is used'),
    });
  });

  it('rejects a turn that does not end with the user', async () => {
    await expect(
      service().reply('user', {
        today: '2026-10-19',
        messages: [{ role: 'assistant', content: 'hello' }],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('answers 503 when the Groq key is missing', async () => {
    const config = { get: () => undefined } as unknown as ConfigService;
    const missing = new ChatService(
      new LlmClient(config),
      summary,
      accounts,
      budgets,
      transactions,
      categories,
      goalsSvc,
      debts,
      schedules,
    );
    await expect(
      missing.reply('user', { today: '2026-10-19', messages: [{ role: 'user', content: 'balance?' }] }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
