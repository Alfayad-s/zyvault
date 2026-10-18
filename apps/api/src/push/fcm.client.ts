import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

export type PushMessage = {
  title: string;
  body: string;
  /** Android notification channel, created by the app. */
  channel: 'plans' | 'summaries';
  data?: Record<string, string>;
};

export type SendResult = 'sent' | 'gone' | 'failed';

function base64url(value: string | Buffer): string {
  return Buffer.from(value).toString('base64url');
}

@Injectable()
export class FcmClient {
  private readonly logger = new Logger(FcmClient.name);
  private account: ServiceAccount | null | undefined;
  private accessToken: { value: string; expiresAt: number } | null = null;

  constructor(private readonly config: ConfigService) {}

  get configured(): boolean {
    return this.serviceAccount() !== null;
  }

  async send(token: string, message: PushMessage): Promise<SendResult> {
    const account = this.serviceAccount();
    if (!account) return 'failed';
    try {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${await this.token(account)}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: message.title, body: message.body },
              data: message.data ?? {},
              android: {
                priority: 'high',
                notification: {
                  channel_id: message.channel,
                  icon: 'ic_stat_payment',
                  color: '#C8F57A',
                },
              },
            },
          }),
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (response.ok) return 'sent';
      const text = await response.text();
      if (response.status === 404 || text.includes('UNREGISTERED')) return 'gone';
      this.logger.warn(`FCM answered ${response.status}: ${text.slice(0, 200)}`);
      return 'failed';
    } catch (caught) {
      this.logger.warn(`FCM send failed: ${String(caught)}`);
      return 'failed';
    }
  }

  private serviceAccount(): ServiceAccount | null {
    if (this.account !== undefined) return this.account;
    const path = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    if (!path) return (this.account = null);
    try {
      const parsed = JSON.parse(readFileSync(path, 'utf8')) as Partial<ServiceAccount>;
      if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
        throw new Error('missing project_id, client_email or private_key');
      }
      this.account = parsed as ServiceAccount;
    } catch (caught) {
      this.logger.warn(`FIREBASE_SERVICE_ACCOUNT could not be read: ${String(caught)}`);
      this.account = null;
    }
    return this.account;
  }

  private async token(account: ServiceAccount): Promise<string> {
    if (this.accessToken && this.accessToken.expiresAt > Date.now() + 60_000) {
      return this.accessToken.value;
    }
    const now = Math.floor(Date.now() / 1000);
    const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claims = base64url(
      JSON.stringify({
        iss: account.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      }),
    );
    const signature = createSign('RSA-SHA256')
      .update(`${header}.${claims}`)
      .sign(account.private_key, 'base64url');
    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${header}.${claims}.${signature}`,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) throw new Error(`Google token answered ${response.status}`);
    const body = (await response.json()) as { access_token: string; expires_in: number };
    this.accessToken = { value: body.access_token, expiresAt: Date.now() + body.expires_in * 1000 };
    return body.access_token;
  }
}
