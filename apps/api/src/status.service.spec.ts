import type { ConfigService } from '@nestjs/config';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { FcmClient } from './push/fcm.client.js';
import { StatusService } from './status.service.js';

describe('StatusService', () => {
  it('reports a missing table without calling outside services', async () => {
    const supabase = {
      from(table: string) {
        return {
          select: () => ({
            limit: async () => ({ error: table === 'goals' ? { message: 'relation goals does not exist' } : null }),
          }),
        };
      },
      auth: { admin: { listUsers: async () => ({ error: null }) } },
    };
    const config = { get: () => undefined } as unknown as ConfigService;
    const push = { configured: false } as FcmClient;
    const status = new StatusService(supabase as unknown as SupabaseClient, config, push);

    const report = await status.collect();

    expect(report.status).toBe('problem');
    expect(report.checks.find((check) => check.name === 'Database')).toMatchObject({
      ok: false,
      detail: expect.stringContaining('goals'),
    });
    expect(report.checks.find((check) => check.name === 'Sign-in')?.ok).toBe(true);
    expect(report.checks.find((check) => check.name === 'Chat')?.detail).toBe('Not configured');
    expect(report.checks.find((check) => check.name === 'Server push')?.ok).toBe(false);
  });
});
