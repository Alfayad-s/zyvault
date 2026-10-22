import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { SupabaseClient } from '@supabase/supabase-js';
import { FcmClient } from './push/fcm.client.js';
import { SUPABASE } from './supabase/supabase.constants.js';

export type StatusCheck = {
  name: string;
  ok: boolean;
  detail: string;
};

const moneyTables = [
  'accounts',
  'categories',
  'transactions',
  'budgets',
  'goals',
  'debts',
  'scheduled_transactions',
] as const;

const pushTables = [
  { table: 'device_tokens', column: 'token' },
  { table: 'push_log', column: 'key' },
] as const;

@Injectable()
export class StatusService {
  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly config: ConfigService,
    private readonly push: FcmClient,
  ) {}

  async collect(): Promise<{ status: 'ok' | 'problem'; checks: StatusCheck[] }> {
    const checks = await Promise.all([
      this.tables(
        'Database',
        moneyTables.map((table) => ({ table, column: 'id' })),
        'Money records can be read',
      ),
      this.signIn(),
      this.keyCheck('Email codes', 'RESEND_API_KEY', 'https://api.resend.com/domains'),
      this.keyCheck('Chat', 'GROQ_API_KEY', 'https://api.groq.com/openai/v1/models'),
      this.keyCheck(
        'Bill photos',
        'GOOGLE_AI_API_KEY',
        'https://generativelanguage.googleapis.com/v1beta/models?pageSize=1',
        { 'x-goog-api-key': this.config.get<string>('GOOGLE_AI_API_KEY') ?? '' },
      ),
      this.visionKey(),
      this.pushAccount(),
      this.tables('Push tables', pushTables, 'device_tokens and push_log are there'),
    ]);
    return { status: checks.every((check) => check.ok) ? 'ok' : 'problem', checks };
  }

  private async tables(
    name: string,
    tables: readonly { table: string; column: string }[],
    okDetail: string,
  ): Promise<StatusCheck> {
    const failed: string[] = [];
    await Promise.all(
      tables.map(async ({ table, column }) => {
        const { error } = await this.supabase.from(table).select(column).limit(1);
        if (error) failed.push(`${table}: ${clip(error.message)}`);
      }),
    );
    if (failed.length === 0) return { name, ok: true, detail: okDetail };
    return { name, ok: false, detail: failed.join(' ') };
  }

  private async signIn(): Promise<StatusCheck> {
    const { error } = await this.supabase.auth.admin.listUsers({ page: 1, perPage: 1 });
    if (error) return { name: 'Sign-in', ok: false, detail: clip(error.message) };
    return { name: 'Sign-in', ok: true, detail: 'Supabase auth answered' };
  }

  private async keyCheck(
    name: string,
    envName: string,
    url: string,
    extraHeaders: Record<string, string> = {},
  ): Promise<StatusCheck> {
    const key = this.config.get<string>(envName);
    if (!key) return { name, ok: false, detail: 'Not configured' };
    const headers: Record<string, string> = { ...extraHeaders };
    if (!headers['x-goog-api-key']) headers.authorization = `Bearer ${key}`;
    try {
      const response = await fetch(url, { headers, signal: AbortSignal.timeout(8_000) });
      if (response.ok) return { name, ok: true, detail: 'Answered' };
      if (response.status === 401 || response.status === 403) {
        return { name, ok: false, detail: 'Key was rejected' };
      }
      return { name, ok: false, detail: `Answered ${response.status}` };
    } catch {
      return { name, ok: false, detail: 'Could not be reached' };
    }
  }

  private visionKey(): StatusCheck {
    const key = this.config.get<string>('GOOGLE_CLOUD_VISION_API_KEY')?.trim();
    return key
      ? { name: 'Bill text', ok: true, detail: 'The Vision key is set' }
      : { name: 'Bill text', ok: false, detail: 'Not configured' };
  }

  private pushAccount(): StatusCheck {
    return this.push.configured
      ? { name: 'Server push', ok: true, detail: 'The Firebase account file can be read' }
      : { name: 'Server push', ok: false, detail: 'The Firebase account file is missing' };
  }
}

function clip(message: string): string {
  return message.replace(/[A-Za-z0-9_-]{24,}/g, '…').slice(0, 160);
}
