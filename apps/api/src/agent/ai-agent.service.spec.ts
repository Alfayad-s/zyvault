import { ServiceUnavailableException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import type { CategoriesService } from '../categories/categories.service.js';
import type { TransactionsService } from '../transactions/transactions.service.js';
import type { Account, AccountsService } from '../accounts/accounts.service.js';
import type { GoalsService } from '../goals/goals.service.js';
import {
  AIAgentService,
  accountLabel,
  accountNearAmount,
  matchAccount,
} from './ai-agent.service.js';
import { LlmClient } from './llm.client.js';
import { VisionClient } from './vision.client.js';
import { ZeroShotClient } from './zero-shot.client.js';

const categories = [
  { id: 'food', name: 'Food', kind: 'expense' as const },
  { id: 'transport', name: 'Transport', kind: 'expense' as const },
  { id: 'other', name: 'Other', kind: 'expense' as const },
  { id: 'salary', name: 'Salary', kind: 'income' as const },
  { id: 'other-income', name: 'Other income', kind: 'income' as const },
];

const history = [
  { note: 'chai tapri', categoryName: 'Food', kind: 'expense' as const },
];

function agent(env: Record<string, string>) {
  const config = { get: (key: string) => env[key] } as unknown as ConfigService;
  const list = { list: () => Promise.resolve(categories) } as unknown as CategoriesService;
  const transactions = {
    list: () => Promise.resolve(history),
  } as unknown as TransactionsService;
  const accounts = {
    list: () => Promise.resolve(userAccounts),
  } as unknown as AccountsService;
  return new AIAgentService(
    new LlmClient(config),
    new VisionClient(config),
    new ZeroShotClient(config),
    list,
    transactions,
    accounts,
    { list: () => Promise.resolve([]) } as unknown as GoalsService,
  );
}

const userAccounts: Account[] = [
  { id: 'cash', name: 'Cash', type: 'cash', openingBalance: 0, createdAt: '', bankId: null },
  { id: 'sbi', name: 'Salary account', type: 'bank', openingBalance: 0, createdAt: '', bankId: 'sbi' },
  { id: 'hdfc', name: 'HDFC Bank', type: 'bank', openingBalance: 0, createdAt: '', bankId: 'hdfc' },
];

describe('matchAccount', () => {
  it('maps the model answer onto a real account', () => {
    expect(matchAccount('Salary account', userAccounts)?.id).toBe('sbi');
    expect(matchAccount('salary account (State Bank of India, SBI)', userAccounts)?.id).toBe('sbi');
    expect(matchAccount('SBI', userAccounts)?.id).toBe('sbi');
    expect(matchAccount('cash', userAccounts)?.id).toBe('cash');
    expect(matchAccount('HDFC', userAccounts)?.id).toBe('hdfc');
    expect(matchAccount('Axis', userAccounts)).toBeNull();
    expect(matchAccount(null, userAccounts)).toBeNull();
  });

  it('finds the account written next to each amount', () => {
    const sentence = 'auto 80 cash and petrol 500 by hdfc card, chai 20';
    expect(accountNearAmount(sentence, 8000, userAccounts)?.id).toBe('cash');
    expect(accountNearAmount(sentence, 50000, userAccounts)?.id).toBe('hdfc');
    expect(accountNearAmount('swiggy 340 from sbi gpay', 34000, userAccounts)?.id).toBe('sbi');
    expect(accountNearAmount('chai 20', 2000, userAccounts)).toBeNull();
    expect(accountNearAmount('rent 1.5k', 150000, userAccounts)).toBeNull();
  });

  it('labels accounts with their bank for the prompt', () => {
    expect(userAccounts.map(accountLabel)).toEqual([
      'Cash (cash)',
      'Salary account (State Bank of India, SBI)',
      'HDFC Bank (HDFC Bank, HDFC)',
    ]);
  });
});

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function gemini(items: unknown[]) {
  return reply({ candidates: [{ content: { parts: [{ text: JSON.stringify(items) }] } }] });
}

const keys = { LLM_PROVIDER: 'google', GOOGLE_AI_API_KEY: 'g', HF_TOKEN: 'h' };

describe('AIAgentService', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('uses the category Gemini picks and skips Hugging Face', async () => {
    const fetch = vi.fn((_url: string, _init?: RequestInit) =>
      Promise.resolve(
        gemini([
          { amount: 450, currency: 'INR', merchant: 'Dominos', date: 'yesterday', rawDescription: 'pizza with friends', kind: 'expense', category: 'Food' },
          { amount: 80, currency: 'INR', merchant: null, date: 'today', rawDescription: 'auto', kind: 'expense', category: 'transport' },
        ]),
      ),
    );
    vi.stubGlobal('fetch', fetch);

    const spends = await agent(keys).parse('user', 'Spent 450 on pizza last night and 80 auto', '2026-10-18');

    expect(spends.map((spend) => [spend.amount, spend.categoryId, spend.occurredOn, spend.source])).toEqual([
      [45000, 'food', '2026-10-17', 'llm'],
      [8000, 'transport', '2026-10-18', 'llm'],
    ]);
    expect(fetch).toHaveBeenCalledTimes(1);
    const prompt = JSON.stringify(fetch.mock.calls[0]?.[1]?.body);
    expect(prompt).toContain('Food, Transport, Other');
    expect(prompt).toContain('chai tapri');
    expect(prompt).toContain('2026-10-18 (Sunday)');
  });

  it('asks Hugging Face when Gemini gives no usable category', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        Promise.resolve(
          url.includes('generativelanguage')
            ? gemini([{ amount: 120, rawDescription: 'metro card', category: 'Commute' }])
            : reply({ labels: ['Transport', 'Rent'], scores: [0.72, 0.1] }),
        ),
      ),
    );

    const [spend] = await agent(keys).parse('user', '120 metro card', '2026-10-18');
    expect([spend.categoryName, spend.source]).toEqual(['Transport', 'zero-shot']);
  });

  it('uses the broader category when the specific one is not set up', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(() =>
        Promise.resolve(gemini([{ amount: 2400, rawDescription: 'goa flight', category: 'Travel' }])),
      ),
    );

    const [spend] = await agent(keys).parse('user', '2400 goa flight', '2026-10-18');
    expect([spend.categoryName, spend.source]).toEqual(['Transport', 'llm']);
  });

  it('saves to Other when Hugging Face has no credit or no token', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn((url: string) =>
        Promise.resolve(
          url.includes('generativelanguage')
            ? gemini([{ amount: 99, rawDescription: 'gift wrap' }])
            : reply({ error: 'payment required' }, 402),
        ),
      ),
    );

    const [paid] = await agent(keys).parse('user', '99 gift wrap', '2026-10-18');
    expect([paid.categoryName, paid.source]).toEqual(['Other', 'fallback']);

    const [noToken] = await agent({ GOOGLE_AI_API_KEY: 'g' }).parse('user', '99 gift wrap', '2026-10-18');
    expect(noToken.categoryName).toBe('Other');
  });

  it('falls back to OpenRouter when Google hits its limit', async () => {
    const fetch = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve(
        url.includes('generativelanguage')
          ? reply({ error: 'quota' }, 429)
          : reply({
              choices: [
                {
                  message: {
                    content: JSON.stringify([
                      { amount: 120, rawDescription: 'metro', kind: 'expense', category: 'Transport' },
                    ]),
                  },
                },
              ],
            }),
      ),
    );
    vi.stubGlobal('fetch', fetch);

    const [spend] = await agent({ ...keys, OPENROUTER_API_KEY: 'o' }).parse('user', '120 metro', '2026-10-18');
    expect([spend.amount, spend.categoryName]).toEqual([12000, 'Transport']);
    const openRouterBody = JSON.parse(fetch.mock.calls[1]?.[1]?.body as string) as {
      models?: string[];
    };
    expect(openRouterBody.models?.[0]).toBe('google/gemma-4-31b-it:free');
  });

  it('tries Groq models before OpenRouter when Google is out', async () => {
    const fetch = vi.fn((url: string, init?: RequestInit) => {
      if (url.includes('generativelanguage')) {
        return Promise.resolve(reply({ error: 'quota' }, 429));
      }
      const body = JSON.parse(init?.body as string) as { model?: string };
      if (url.includes('groq') && body.model === 'qwen/qwen3.8-27b') {
        return Promise.resolve(
          reply({
            choices: [
              { message: { content: '[{"amount":60,"rawDescription":"chai","kind":"expense","category":"Food"}]' } },
            ],
          }),
        );
      }
      return Promise.resolve(reply({ error: 'tokens' }, 429));
    });
    vi.stubGlobal('fetch', fetch);

    const [spend] = await agent({ ...keys, GROQ_API_KEY: 'q', OPENROUTER_API_KEY: 'o' }).parse(
      'user',
      '60 chai',
      '2026-10-18',
    );
    expect([spend.amount, spend.categoryName]).toEqual([6000, 'Food']);
    const urls = fetch.mock.calls.map(([url]) => new URL(url).host);
    expect(urls).toEqual(['generativelanguage.googleapis.com', 'api.groq.com', 'api.groq.com']);
    const qwen = JSON.parse(fetch.mock.calls[2]?.[1]?.body as string) as Record<string, unknown>;
    expect(qwen.reasoning_format).toBe('hidden');
  });

  it('answers 503 when Google and OpenRouter both fail', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Promise.resolve(reply({ error: 'busy' }, 429))));
    await expect(
      agent({ ...keys, OPENROUTER_API_KEY: 'o' }).parse('user', '10 tea', '2026-10-18'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('sends a bill photo to Gemini and does not fall back to a text model', async () => {
    const fetch = vi.fn((url: string, _init?: RequestInit) =>
      Promise.resolve(
        url.includes('generativelanguage')
          ? gemini([
              {
                amount: 842,
                currency: 'INR',
                merchant: 'Cafe Madras',
                date: '2026-10-18',
                rawDescription: 'dinner bill',
                kind: 'expense',
                category: 'Food',
              },
            ])
          : reply({
              choices: [
                { message: { content: '[{"amount":1,"rawDescription":"wrong","category":"Food"}]' } },
              ],
            }),
      ),
    );
    vi.stubGlobal('fetch', fetch);

    const [spend] = await agent({ ...keys, OPENROUTER_API_KEY: 'o' }).parse('user', 'my share', '2026-10-18', {
      mimeType: 'image/jpeg',
      data: 'abc',
    });

    expect([spend.amount, spend.merchant, spend.categoryName]).toEqual([84200, 'Cafe Madras', 'Food']);
    expect(fetch).toHaveBeenCalledTimes(1);
    const body = JSON.parse(fetch.mock.calls[0]?.[1]?.body as string) as {
      contents: { parts: { text?: string; inlineData?: { mimeType: string; data: string } }[] }[];
    };
    expect(body.contents[0]?.parts[0]?.inlineData).toEqual({ mimeType: 'image/jpeg', data: 'abc' });
    expect(body.contents[0]?.parts[1]?.text).toContain('amount payable');
    expect(body.contents[0]?.parts[1]?.text).toContain('User note: my share');
  });

  it('logs each bill item from Vision text and does not send the photo', async () => {
    const fetch = vi.fn((url: string) =>
      Promise.resolve(
        url.includes('vision.googleapis.com')
          ? reply({ responses: [{ fullTextAnnotation: { text: 'Milk 40\nBread 30\nTotal 70' } }] })
          : gemini([
              {
                amount: 40,
                merchant: 'Store',
                date: '2026-10-18',
                rawDescription: 'milk',
                kind: 'expense',
                category: 'Food',
              },
              {
                amount: 30,
                merchant: 'Store',
                date: '2026-10-18',
                rawDescription: 'bread',
                kind: 'expense',
                category: 'Food',
              },
            ]),
      ),
    );
    vi.stubGlobal('fetch', fetch);

    const spends = await agent({ ...keys, GOOGLE_CLOUD_VISION_API_KEY: 'v' }).parse(
      'user',
      '',
      '2026-10-18',
      { mimeType: 'image/jpeg', data: 'abc' },
    );

    expect(spends.map((spend) => [spend.amount, spend.rawDescription])).toEqual([
      [4000, 'milk'],
      [3000, 'bread'],
    ]);
    expect(String(fetch.mock.calls[0]?.[0])).toContain('images:annotate');
    const body = JSON.parse(fetch.mock.calls[1]?.[1]?.body as string) as {
      systemInstruction: { parts: { text: string }[] };
      contents: { parts: { text?: string; inlineData?: unknown }[] }[];
    };
    expect(body.contents[0]?.parts[0]?.inlineData).toBeUndefined();
    expect(body.contents[0]?.parts[0]?.text).toContain('Milk 40');
    expect(body.systemInstruction.parts[0]?.text).toContain('one object per item');
  });

  it('keeps the one-total photo read when Vision returns no words', async () => {
    const fetch = vi.fn((url: string) =>
      Promise.resolve(
        url.includes('vision.googleapis.com')
          ? reply({ responses: [{ fullTextAnnotation: { text: '   ' } }] })
          : gemini([
              {
                amount: 70,
                merchant: 'Store',
                date: '2026-10-18',
                rawDescription: 'grocery bill',
                kind: 'expense',
                category: 'Food',
              },
            ]),
      ),
    );
    vi.stubGlobal('fetch', fetch);

    const [spend] = await agent({ ...keys, GOOGLE_CLOUD_VISION_API_KEY: 'v' }).parse(
      'user',
      '',
      '2026-10-18',
      { mimeType: 'image/jpeg', data: 'abc' },
    );

    expect(spend.amount).toBe(7000);
    const body = JSON.parse(fetch.mock.calls[1]?.[1]?.body as string) as {
      contents: { parts: { inlineData?: { data: string } }[] }[];
    };
    expect(body.contents[0]?.parts[0]?.inlineData?.data).toBe('abc');
  });

  it('turns a missing Gemini key or a Gemini outage into 503', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Promise.resolve(reply({ error: 'busy' }, 429))));
    await expect(agent(keys).parse('user', '10 tea', '2026-10-18')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    await expect(agent({}).parse('user', '10 tea', '2026-10-18')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
