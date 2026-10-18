import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const resendTimeoutMs = 10_000;

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly config: ConfigService) {}

  async sendLoginCode(email: string, code: string): Promise<void> {
    const key = this.config.get<string>('RESEND_API_KEY');
    if (!key) {
      throw new ServiceUnavailableException('Email sending is not configured');
    }
    const from = this.config.get<string>('RESEND_FROM') || 'zyvault <onboarding@resend.dev>';
    let response: Response;
    try {
      response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: `Bearer ${key}` },
        body: JSON.stringify({
          from,
          to: [email],
          subject: `${code} is your zyvault code`,
          text: loginText(code),
          html: loginHtml(code),
        }),
        signal: AbortSignal.timeout(resendTimeoutMs),
      });
    } catch (caught) {
      this.logger.warn(`Resend request failed: ${String(caught)}`);
      throw new ServiceUnavailableException('Could not send the code, try again');
    }
    if (!response.ok) {
      const body = (await response.json().catch(() => ({}))) as { message?: string };
      this.logger.warn(`Resend answered ${response.status}: ${body.message ?? ''}`);
      throw new ServiceUnavailableException('Could not send the code, try again');
    }
  }
}

function loginText(code: string): string {
  return `Your zyvault sign-in code is ${code}.\n\nIt works once. If you did not ask for it, you can ignore this email.`;
}

function loginHtml(code: string): string {
  return `<!doctype html>
<html>
  <body style="margin:0;background:#111111;font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#ffffff">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding:40px 16px">
      <tr><td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:420px;background:#2C2C2E;border-radius:24px;padding:32px">
          <tr><td style="font-size:20px;font-weight:700">zyvault</td></tr>
          <tr><td style="padding-top:8px;color:#8E8E93;font-size:15px">Your sign-in code</td></tr>
          <tr><td style="padding:24px 0;font-size:36px;font-weight:800;letter-spacing:8px;color:#C8F57A">${code}</td></tr>
          <tr><td style="color:#8E8E93;font-size:13px;line-height:20px">It works once. If you did not ask for it, you can ignore this email.</td></tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;
}
