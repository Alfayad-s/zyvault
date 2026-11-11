import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import type { AuthUser } from '../auth/auth-user.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { adminEmails, featureKeys, FeatureKey, isFeatureKey, roleFor, AppRole } from './features.js';

const schemaHint = 'Run the latest supabase/latest.sql in the Supabase SQL editor, then try again.';

function missingTable(error: { message: string } | null): boolean {
  return Boolean(error && /(does not exist|schema cache|Could not find)/.test(error.message));
}

@Injectable()
export class AccessService {
  constructor(@Inject(SUPABASE) private readonly supabase: SupabaseClient) {}

  async me(user: AuthUser): Promise<{ role: AppRole; features: Record<FeatureKey, boolean> }> {
    const role = await this.ensureRole(user);
    return { role, features: await this.features() };
  }

  async setFeature(user: AuthUser, key: string, enabled: boolean): Promise<{ key: FeatureKey; enabled: boolean }> {
    if (!isFeatureKey(key)) throw new BadRequestException('Unknown feature');
    const role = await this.ensureRole(user);
    if (role !== 'admin') throw new ForbiddenException('Only an admin can change features');
    const { error } = await this.supabase.from('app_features').upsert({ key, enabled });
    if (missingTable(error)) throw new BadRequestException(schemaHint);
    if (error) throw new BadRequestException(error.message);
    return { key, enabled };
  }

  async assert(user: AuthUser, key: FeatureKey): Promise<void> {
    const role = await this.ensureRole(user);
    if (role === 'admin') return;
    const features = await this.features();
    if (features[key] === false) throw new ForbiddenException('This feature is turned off');
  }

  private async ensureRole(user: AuthUser): Promise<AppRole> {
    const existing = await this.supabase.from('app_roles').select('role').eq('user_id', user.id).maybeSingle();
    if (missingTable(existing.error)) throw new BadRequestException(schemaHint);
    if (existing.error) throw new BadRequestException(existing.error.message);
    const role = roleFor(user.email, (existing.data?.role as string | undefined) ?? null, adminEmails(process.env.ADMIN_EMAILS));
    if (!existing.data) {
      const inserted = await this.supabase.from('app_roles').insert({ user_id: user.id, role });
      if (inserted.error && !/duplicate/i.test(inserted.error.message)) {
        if (missingTable(inserted.error)) throw new BadRequestException(schemaHint);
        throw new BadRequestException(inserted.error.message);
      }
      return role;
    }
    if (existing.data.role !== role) {
      const updated = await this.supabase.from('app_roles').update({ role }).eq('user_id', user.id);
      if (updated.error) throw new BadRequestException(updated.error.message);
    }
    return role;
  }

  private async features(): Promise<Record<FeatureKey, boolean>> {
    const { data, error } = await this.supabase.from('app_features').select('key, enabled');
    if (missingTable(error)) throw new BadRequestException(schemaHint);
    if (error) throw new BadRequestException(error.message);
    const stored = new Map((data ?? []).map((row) => [row.key as string, row.enabled === true]));
    const missing = featureKeys.filter((key) => !stored.has(key));
    if (missing.length > 0) {
      const inserted = await this.supabase.from('app_features').upsert(missing.map((key) => ({ key, enabled: true })));
      if (inserted.error) throw new BadRequestException(inserted.error.message);
    }
    return Object.fromEntries(featureKeys.map((key) => [key, stored.get(key) ?? true])) as Record<FeatureKey, boolean>;
  }
}
