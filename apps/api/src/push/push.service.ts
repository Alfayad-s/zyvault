import { BadRequestException, Inject, Injectable, Logger } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { FcmClient, type PushMessage } from './fcm.client.js';

export type Device = { userId: string; token: string; utcOffsetMinutes: number };

export function missingPushTables(error: { message: string } | null): boolean {
  return Boolean(
    error &&
      /(device_tokens|push_log)/.test(error.message) &&
      /(does not exist|schema cache)/.test(error.message),
  );
}

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly fcm: FcmClient,
  ) {}

  get configured(): boolean {
    return this.fcm.configured;
  }

  async register(userId: string, token: string, platform: string, utcOffsetMinutes: number) {
    const { error } = await this.supabase.from('device_tokens').upsert(
      {
        token,
        user_id: userId,
        platform,
        utc_offset_minutes: utcOffsetMinutes,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'token' },
    );
    if (missingPushTables(error)) {
      throw new BadRequestException('Run the latest supabase/schema.sql in Supabase to turn on push');
    }
    if (error) throw new BadRequestException(error.message);
    return { push: this.configured };
  }

  async unregister(userId: string, token: string) {
    const { error } = await this.supabase
      .from('device_tokens')
      .delete()
      .eq('token', token)
      .eq('user_id', userId);
    if (error && !missingPushTables(error)) throw new BadRequestException(error.message);
  }

  async devices(): Promise<Device[]> {
    const { data, error } = await this.supabase
      .from('device_tokens')
      .select('token, user_id, utc_offset_minutes')
      .limit(5000);
    if (missingPushTables(error)) return [];
    if (error) throw new BadRequestException(error.message);
    return ((data ?? []) as { token: string; user_id: string; utc_offset_minutes: number }[]).map(
      (row) => ({ token: row.token, userId: row.user_id, utcOffsetMinutes: row.utc_offset_minutes }),
    );
  }

  /** Sends to every phone of the user. Returns false when nothing was delivered. */
  async toUser(userId: string, tokens: string[], message: PushMessage): Promise<boolean> {
    let delivered = false;
    for (const token of tokens) {
      const result = await this.fcm.send(token, message);
      if (result === 'sent') delivered = true;
      if (result === 'gone') {
        await this.supabase.from('device_tokens').delete().eq('token', token);
        this.logger.log('Removed a phone that no longer receives pushes');
      }
    }
    return delivered;
  }

  /** Claims a one-time key such as "due:<schedule>:<date>". False when already sent. */
  async once(userId: string, key: string): Promise<boolean> {
    const { error } = await this.supabase.from('push_log').insert({ key, user_id: userId });
    if (!error) return true;
    if (error.code === '23505') return false;
    throw new BadRequestException(error.message);
  }
}
