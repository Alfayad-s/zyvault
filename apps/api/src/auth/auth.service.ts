import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, type Session, SupabaseClient, type User } from '@supabase/supabase-js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { MailService } from './mail.service.js';

const resendCooldownMs = 30_000;
const hourMs = 60 * 60 * 1000;
const codesPerHour = 5;
const maxWrongCodes = 5;

type CodeRequests = { last: number; windowStart: number; count: number };

function sessionView(session: Session, user: User, email: string) {
  return {
    accessToken: session.access_token,
    refreshToken: session.refresh_token,
    expiresAt: session.expires_at ?? Math.floor(Date.now() / 1000) + session.expires_in,
    user: { id: user.id, email: user.email ?? email },
  };
}

@Injectable()
export class AuthService {
  private readonly requests = new Map<string, CodeRequests>();
  private readonly failures = new Map<string, number>();

  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly config: ConfigService,
    private readonly mail: MailService,
  ) {}

  async sendCode(email: string) {
    this.throttle(email);
    this.failures.delete(email);
    await this.ensureUser(email);
    const { data, error } = await this.supabase.auth.admin.generateLink({
      type: 'magiclink',
      email,
    });
    const code = data?.properties?.email_otp;
    if (error || !code) {
      throw new BadRequestException(error?.message ?? 'Could not create a code');
    }
    await this.mail.sendLoginCode(email, code);
    return { codeLength: code.length, resendAfterSeconds: resendCooldownMs / 1000 };
  }

  async verifyCode(email: string, code: string) {
    const failures = this.failures.get(email) ?? 0;
    if (failures >= maxWrongCodes) {
      throw new HttpException('Too many wrong codes, ask for a new one', HttpStatus.TOO_MANY_REQUESTS);
    }
    const { data, error } = await this.signInClient().auth.verifyOtp({
      email,
      token: code,
      type: 'email',
    });
    if (error || !data.session || !data.user) {
      this.failures.set(email, failures + 1);
      throw new UnauthorizedException('That code is wrong or has expired');
    }
    this.requests.delete(email);
    this.failures.delete(email);
    return sessionView(data.session, data.user, email);
  }

  async refresh(refreshToken: string) {
    const { data, error } = await this.signInClient().auth.refreshSession({
      refresh_token: refreshToken,
    });
    if (error || !data.session || !data.user) {
      throw new UnauthorizedException('Sign in again');
    }
    return sessionView(data.session, data.user, data.user.email ?? '');
  }

  private async ensureUser(email: string) {
    const { error } = await this.supabase.auth.admin.createUser({ email, email_confirm: true });
    if (error && !error.message.toLowerCase().includes('already')) {
      throw new BadRequestException(error.message);
    }
  }

  private throttle(email: string) {
    const now = Date.now();
    const seen = this.requests.get(email);
    if (seen && now - seen.last < resendCooldownMs) {
      const wait = Math.ceil((resendCooldownMs - (now - seen.last)) / 1000);
      throw new HttpException(`Wait ${wait}s before asking for another code`, HttpStatus.TOO_MANY_REQUESTS);
    }
    const fresh = !seen || now - seen.windowStart >= hourMs;
    const count = fresh ? 1 : seen.count + 1;
    if (count > codesPerHour) {
      throw new HttpException('Too many codes asked for, try again in an hour', HttpStatus.TOO_MANY_REQUESTS);
    }
    this.requests.set(email, { last: now, windowStart: fresh ? now : seen.windowStart, count });
  }

  private signInClient(): SupabaseClient {
    const url = this.config.get<string>('SUPABASE_URL');
    const key = this.config.get<string>('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !key) {
      throw new BadRequestException('Supabase is not configured');
    }
    return createClient(url, key, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    });
  }
}
