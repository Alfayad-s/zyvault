import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import { CreateCategoryDto, UpdateCategoryDto } from './dto/category.dto.js';
import { defaultIconFor, iconUrl } from './icons.js';

type Kind = 'income' | 'expense';

type CategoryRow = {
  id: string;
  name: string;
  kind: Kind;
  icon?: string | null;
  user_id?: string | null;
};

export type Category = {
  id: string;
  name: string;
  kind: Kind;
  icon: string | null;
  iconUrl: string | null;
  custom: boolean;
};

const columns = 'id, name, kind';
const columnsWithOwner = `${columns}, icon, user_id`;

export function missingCategoryColumns(error: { message: string } | null): boolean {
  return Boolean(error && /\b(user_id|icon)\b/.test(error.message));
}

export async function findCategory(
  supabase: SupabaseClient,
  userId: string,
  id: string,
): Promise<{ kind: Kind } | null> {
  const query = (select: string) =>
    supabase.from('categories').select(select).eq('id', id).maybeSingle();
  let { data, error } = await query('kind, user_id');
  if (missingCategoryColumns(error)) ({ data, error } = await query('kind'));
  if (error) throw new BadRequestException(error.message);
  const row = data as unknown as { kind: Kind; user_id?: string | null } | null;
  if (!row || (row.user_id && row.user_id !== userId)) return null;
  return { kind: row.kind };
}

@Injectable()
export class CategoriesService {
  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly config: ConfigService,
  ) {}

  async list(userId: string): Promise<Category[]> {
    const query = (select: string, scoped: boolean) => {
      const base = this.supabase.from('categories').select(select);
      return (scoped ? base.or(`user_id.is.null,user_id.eq.${userId}`) : base).order('name', {
        ascending: true,
      });
    };
    let { data, error } = await query(columnsWithOwner, true);
    if (missingCategoryColumns(error)) ({ data, error } = await query(columns, false));
    if (error) {
      throw new BadRequestException(error.message);
    }
    return ((data ?? []) as unknown as CategoryRow[]).map((row) => this.toCategory(row));
  }

  async create(userId: string, input: CreateCategoryDto): Promise<Category> {
    const name = input.name.trim();
    await this.assertNameFree(userId, name, input.kind);
    const { data, error } = await this.supabase
      .from('categories')
      .insert({ user_id: userId, name, kind: input.kind, icon: input.icon })
      .select(columnsWithOwner)
      .single();
    if (missingCategoryColumns(error)) throw this.schemaMissing();
    if (error?.code === '23505') throw this.nameTaken(name);
    if (error || !data) {
      throw new BadRequestException(error?.message ?? 'Could not create the category');
    }
    return this.toCategory(data as CategoryRow);
  }

  async update(userId: string, id: string, input: UpdateCategoryDto): Promise<Category> {
    const own = await this.own(userId, id);
    const change: Record<string, string> = {};
    if (input.name !== undefined) {
      const name = input.name.trim();
      if (name.toLowerCase() !== own.name.toLowerCase()) {
        await this.assertNameFree(userId, name, own.kind);
      }
      change.name = name;
    }
    if (input.icon !== undefined) change.icon = input.icon;
    if (Object.keys(change).length === 0) return this.toCategory(own);

    const { data, error } = await this.supabase
      .from('categories')
      .update(change)
      .eq('id', id)
      .eq('user_id', userId)
      .select(columnsWithOwner)
      .single();
    if (error?.code === '23505') throw this.nameTaken(change.name ?? own.name);
    if (error || !data) {
      throw new BadRequestException(error?.message ?? 'Could not update the category');
    }
    return this.toCategory(data as CategoryRow);
  }

  async remove(userId: string, id: string): Promise<void> {
    const own = await this.own(userId, id);
    const fallback = await this.supabase
      .from('categories')
      .select('id')
      .is('user_id', null)
      .eq('kind', own.kind)
      .eq('name', own.kind === 'income' ? 'Other income' : 'Other')
      .maybeSingle();
    if (fallback.error) throw new BadRequestException(fallback.error.message);
    if (!fallback.data) throw new BadRequestException('Default categories are not set up yet');

    for (const table of ['transactions', 'scheduled_transactions']) {
      const moved = await this.supabase
        .from(table)
        .update({ category_id: fallback.data.id })
        .eq('category_id', id)
        .eq('user_id', userId);
      if (moved.error) throw new BadRequestException(moved.error.message);
    }

    const { error } = await this.supabase
      .from('categories')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);
    if (error) throw new BadRequestException(error.message);
  }

  private async own(userId: string, id: string): Promise<CategoryRow> {
    const { data, error } = await this.supabase
      .from('categories')
      .select(columnsWithOwner)
      .eq('id', id)
      .eq('user_id', userId)
      .maybeSingle();
    if (missingCategoryColumns(error)) throw this.schemaMissing();
    if (error) throw new BadRequestException(error.message);
    if (!data) throw new NotFoundException('You can only change categories you created');
    return data as CategoryRow;
  }

  private async assertNameFree(userId: string, name: string, kind: Kind) {
    const { data, error } = await this.supabase
      .from('categories')
      .select('id')
      .or(`user_id.is.null,user_id.eq.${userId}`)
      .eq('kind', kind)
      .ilike('name', name.replace(/[\\%_]/g, (char) => `\\${char}`))
      .limit(1);
    if (missingCategoryColumns(error)) throw this.schemaMissing();
    if (error) throw new BadRequestException(error.message);
    if ((data ?? []).length > 0) throw this.nameTaken(name);
  }

  private nameTaken(name: string) {
    return new ConflictException(`You already have a category called ${name}`);
  }

  private schemaMissing() {
    return new BadRequestException(
      'Run the latest supabase/schema.sql in Supabase to add your own categories',
    );
  }

  private toCategory(row: CategoryRow): Category {
    const icon = row.icon ?? (row.user_id ? null : defaultIconFor(row.name, row.kind));
    return {
      id: row.id,
      name: row.name,
      kind: row.kind,
      icon,
      iconUrl: iconUrl(this.config.get<string>('CLOUDINARY_CLOUD_NAME'), icon),
      custom: Boolean(row.user_id),
    };
  }
}
