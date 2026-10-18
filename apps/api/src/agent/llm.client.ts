import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const totalBudgetMs = 45_000;
const googleTimeoutMs = 15_000;
const googleBillTimeoutMs = 30_000;
const groqTimeoutMs = 10_000;
const openRouterTimeoutMs = 25_000;

const groqFreeModels = ['openai/gpt-oss-120b', 'qwen/qwen3.8-27b', 'openai/gpt-oss-20b'];

const openRouterFreeModels = [
  'google/gemma-4-31b-it:free',
  'google/gemma-4-26b-a4b-it:free',
  'nvidia/nemotron-3-super-120b-a12b:free',
];

const providerOrder = ['google', 'groq', 'openrouter'] as const;

type Provider = (typeof providerOrder)[number];

class NotConfigured extends Error {}

export type BillImage = { mimeType: string; data: string };

type Chat = { instruction: string; prompt: string; deadline: number; image?: BillImage };

@Injectable()
export class LlmClient {
  private readonly logger = new Logger(LlmClient.name);

  constructor(private readonly config: ConfigService) {}

  async complete(instruction: string, prompt: string, image?: BillImage): Promise<string> {
    const chat = { instruction, prompt, deadline: Date.now() + totalBudgetMs, image };
    let tried = 0;
    let lastError: unknown;
    for (const provider of image ? (['google'] as const) : this.providers()) {
      if (Date.now() >= chat.deadline) {
        break;
      }
      try {
        const text = await this.ask(provider, chat);
        if (tried > 0) {
          this.logger.log(`Answered by ${provider} after an earlier provider failed`);
        }
        return text;
      } catch (caught) {
        if (caught instanceof NotConfigured) {
          continue;
        }
        tried++;
        lastError = caught;
        this.logger.warn(`${provider} failed: ${describe(caught)}`);
      }
    }
    if (tried === 0) {
      throw new ServiceUnavailableException(
        image ? 'Bill photos need a Google AI key' : 'The AI parser is not configured',
      );
    }
    if (image) {
      if (lastError instanceof ServiceUnavailableException) {
        throw lastError;
      }
      throw new ServiceUnavailableException('Google AI could not read that bill');
    }
    if (lastError instanceof ServiceUnavailableException) {
      throw lastError;
    }
    throw new ServiceUnavailableException('The AI parser did not answer in time');
  }

  private providers(): Provider[] {
    const primary = (this.config.get<string>('LLM_PROVIDER') ?? 'google').toLowerCase();
    const first = providerOrder.find((provider) => provider === primary) ?? 'google';
    return [first, ...providerOrder.filter((provider) => provider !== first)];
  }

  private ask(provider: Provider, chat: Chat): Promise<string> {
    switch (provider) {
      case 'google':
        return this.google(chat);
      case 'groq':
        return this.groq(chat);
      case 'openrouter':
        return this.openRouter(chat);
    }
  }

  private async google(chat: Chat): Promise<string> {
    const key = this.key('GOOGLE_AI_API_KEY');
    const model = this.config.get<string>('GOOGLE_AI_MODEL') || 'gemini-flash-lite-latest';
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: chat.instruction }] },
          contents: [
            {
              role: 'user',
              parts: [
                ...(chat.image
                  ? [{ inlineData: { mimeType: chat.image.mimeType, data: chat.image.data } }]
                  : []),
                { text: chat.prompt },
              ],
            },
          ],
          generationConfig: { temperature: 0, responseMimeType: 'application/json' },
        }),
        signal: timeout(chat.image ? googleBillTimeoutMs : googleTimeoutMs, chat.deadline),
      },
    );
    const body = (await this.json(response, 'Google AI Studio')) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };
    const text = body.candidates?.[0]?.content?.parts?.map((part) => part.text ?? '').join('');
    if (!text) {
      throw new ServiceUnavailableException('The AI parser returned an empty reply');
    }
    return text;
  }

  private async groq(chat: Chat): Promise<string> {
    const key = this.key('GROQ_API_KEY');
    const configured = this.config.get<string>('GROQ_MODEL');
    const models = configured ? [configured] : groqFreeModels;
    let lastError: unknown;
    for (const model of models) {
      if (Date.now() >= chat.deadline) {
        break;
      }
      try {
        return await this.openAiChat('Groq', 'https://api.groq.com/openai/v1/chat/completions', key, {
          body: {
            model,
            ...(model.startsWith('openai/gpt-oss') ? { reasoning_effort: 'low' } : { reasoning_format: 'hidden' }),
          },
          chat,
          timeoutMs: groqTimeoutMs,
        });
      } catch (caught) {
        lastError = caught;
        this.logger.warn(`Groq ${model} failed: ${describe(caught)}`);
      }
    }
    throw lastError ?? new ServiceUnavailableException('Groq did not answer in time');
  }

  private openRouter(chat: Chat): Promise<string> {
    const key = this.key('OPENROUTER_API_KEY');
    const model = this.config.get<string>('OPENROUTER_MODEL');
    return this.openAiChat('OpenRouter', 'https://openrouter.ai/api/v1/chat/completions', key, {
      body: model ? { model } : { models: openRouterFreeModels },
      chat,
      timeoutMs: openRouterTimeoutMs,
      headers: { 'x-title': 'zyvault' },
    });
  }

  private async openAiChat(
    source: string,
    url: string,
    key: string,
    options: {
      body: Record<string, unknown>;
      chat: Chat;
      timeoutMs: number;
      headers?: Record<string, string>;
    },
  ): Promise<string> {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${key}`,
        ...options.headers,
      },
      body: JSON.stringify({
        ...options.body,
        temperature: 0,
        messages: [
          { role: 'system', content: options.chat.instruction },
          { role: 'user', content: options.chat.prompt },
        ],
      }),
      signal: timeout(options.timeoutMs, options.chat.deadline),
    });
    const body = (await this.json(response, source)) as {
      choices?: { message?: { content?: string } }[];
    };
    const text = body.choices?.[0]?.message?.content;
    if (!text) {
      throw new ServiceUnavailableException('The AI parser returned an empty reply');
    }
    return text;
  }

  private key(name: string): string {
    const value = this.config.get<string>(name);
    if (!value) {
      throw new NotConfigured(name);
    }
    return value;
  }

  private async json(response: Response, source: string): Promise<unknown> {
    if (!response.ok) {
      throw new ServiceUnavailableException(
        response.status === 429
          ? `${source} daily or per-minute limit reached`
          : `${source} answered ${response.status}`,
      );
    }
    return response.json();
  }
}

function timeout(limitMs: number, deadline: number): AbortSignal {
  return AbortSignal.timeout(Math.max(1, Math.min(limitMs, deadline - Date.now())));
}

export function describe(caught: unknown): string {
  if (caught instanceof Error) {
    return caught.name === 'TimeoutError' ? 'timed out' : caught.message;
  }
  return String(caught);
}
