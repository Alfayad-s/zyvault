import { createHash, randomUUID } from 'node:crypto';
import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseClient } from '@supabase/supabase-js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import {
  banks,
  brandShort,
  logoFolder,
  logoUrl,
  markFolder,
  markUrl,
  uploadedMarkUrl,
  type Bank,
} from './banks.js';

const maxBytes = 2 * 1024 * 1024;
const imageTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

export type BankView = {
  id: string;
  name: string;
  short: string;
  color: string;
  logoUrl: string | null;
  markUrl: string | null;
};

export type UploadedImage = {
  mimetype: string;
  buffer: Buffer;
  size: number;
  originalname?: string;
};

type BrandRow = {
  id: string;
  name: string;
  short: string;
  logo_url: string;
  mark_url: string;
};

const columns = 'id, name, short, logo_url, mark_url';

export function assertImage(
  file: UploadedImage | undefined,
  label: string,
): UploadedImage {
  if (!file || file.size < 1 || file.buffer.length < 1) {
    throw new BadRequestException(`Add the ${label}`);
  }
  if (file.size > maxBytes) {
    throw new BadRequestException(`The ${label} must be 2 MB or smaller`);
  }
  const name = file.originalname?.toLowerCase() ?? '';
  const knownExt = /\.(jpe?g|png|webp)$/.test(name);
  const knownType =
    imageTypes.has(file.mimetype) ||
    (file.mimetype === 'application/octet-stream' && knownExt);
  if (!knownType) {
    throw new BadRequestException(
      `The ${label} must be a JPEG, PNG, or WebP image`,
    );
  }
  return file;
}

export function mergeBrands(
  builtIn: BankView[],
  extra: BrandRow[],
): BankView[] {
  const taken = new Set(builtIn.map((bank) => bank.name.toLowerCase()));
  return [
    ...builtIn,
    ...extra
      .filter((row) => !taken.has(row.name.toLowerCase()))
      .map((row) => ({
        id: row.id,
        name: row.name,
        short: row.short,
        color: '#3A3A3C',
        logoUrl: row.logo_url,
        markUrl: row.mark_url,
      })),
  ];
}

@Injectable()
export class BanksService {
  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly config: ConfigService,
  ) {}

  async list(): Promise<BankView[]> {
    const builtIn = this.builtIn();
    const { data, error } = await this.supabase
      .from('card_brands')
      .select(columns)
      .order('name');
    if (error) {
      if (
        error.message.includes('card_brands') ||
        error.message.includes('schema cache')
      )
        return builtIn;
      throw new BadRequestException(error.message);
    }
    return mergeBrands(builtIn, (data ?? []) as BrandRow[]);
  }

  async create(
    userId: string,
    name: string | undefined,
    logo: UploadedImage | undefined,
    mark: UploadedImage | undefined,
  ): Promise<BankView> {
    const trimmed = name?.trim() ?? '';
    if (trimmed.length < 2 || trimmed.length > 60) {
      throw new BadRequestException('Enter the card name');
    }
    const builtin = banks.find(
      (bank) =>
        bank.id !== 'other' &&
        bank.name.toLowerCase() === trimmed.toLowerCase(),
    );
    if (builtin) return this.view(builtin);
    const existing = await this.findByName(trimmed);
    if (existing) return existing;

    const logoFile = assertImage(logo, 'logo with name');
    const markFile = assertImage(mark, 'logo only');
    const cloud = this.config.get<string>('CLOUDINARY_CLOUD_NAME');
    const key = this.config.get<string>('CLOUDINARY_API_KEY');
    const secret = this.config.get<string>('CLOUDINARY_API_SECRET');
    if (!cloud || !key || !secret) {
      throw new BadRequestException('Image storage is not set up');
    }
    const id = randomUUID();
    await this.upload(cloud, key, secret, logoFolder, id, logoFile);
    await this.upload(cloud, key, secret, markFolder, id, markFile);
    const row = {
      id,
      name: trimmed,
      short: brandShort(trimmed),
      logo_url: logoUrl(cloud, id),
      mark_url: uploadedMarkUrl(cloud, id),
      created_by: userId,
    };
    const { data, error } = await this.supabase
      .from('card_brands')
      .insert(row)
      .select(columns)
      .single();
    if (error) {
      if (
        error.code === '23505' ||
        error.message.toLowerCase().includes('duplicate')
      ) {
        const again = await this.findByName(trimmed);
        if (again) return again;
      }
      if (
        error.message.includes('card_brands') ||
        error.message.includes('schema cache')
      ) {
        throw new BadRequestException(
          'Run the latest supabase/latest.sql, then add the logo again',
        );
      }
      throw new BadRequestException(error.message);
    }
    return mergeBrands([], [data as BrandRow])[0];
  }

  private builtIn(): BankView[] {
    const cloud = this.config.get<string>('CLOUDINARY_CLOUD_NAME');
    return banks.map((bank) => this.view(bank, cloud));
  }

  private view(
    bank: Bank,
    cloud = this.config.get<string>('CLOUDINARY_CLOUD_NAME'),
  ): BankView {
    return {
      id: bank.id,
      name: bank.name,
      short: bank.short,
      color: bank.color,
      logoUrl: cloud ? logoUrl(cloud, bank.id) : null,
      markUrl: cloud ? markUrl(cloud, bank) : null,
    };
  }

  private async findByName(name: string): Promise<BankView | null> {
    const { data, error } = await this.supabase
      .from('card_brands')
      .select(columns)
      .ilike(
        'name',
        name.replace(/[\\%_]/g, (char) => `\\${char}`),
      )
      .maybeSingle();
    if (error) {
      if (
        error.message.includes('card_brands') ||
        error.message.includes('schema cache')
      ) {
        throw new BadRequestException(
          'Run the latest supabase/latest.sql, then add the logo again',
        );
      }
      throw new BadRequestException(error.message);
    }
    if (!data) return null;
    return mergeBrands([], [data as BrandRow])[0];
  }

  private async upload(
    cloud: string,
    key: string,
    secret: string,
    folder: string,
    publicId: string,
    file: UploadedImage,
  ): Promise<void> {
    const params = {
      folder,
      overwrite: 'true',
      public_id: publicId,
      timestamp: `${Math.floor(Date.now() / 1000)}`,
    };
    const toSign = Object.keys(params)
      .sort()
      .map((name) => `${name}=${params[name as keyof typeof params]}`)
      .join('&');
    const form = new FormData();
    for (const [name, value] of Object.entries(params))
      form.append(name, value);
    form.append('api_key', key);
    form.append(
      'signature',
      createHash('sha1')
        .update(toSign + secret)
        .digest('hex'),
    );
    const ext =
      file.mimetype === 'image/png'
        ? 'png'
        : file.mimetype === 'image/webp'
          ? 'webp'
          : 'jpg';
    form.append(
      'file',
      new Blob([new Uint8Array(file.buffer)], { type: file.mimetype }),
      `logo.${ext}`,
    );
    const response = await fetch(
      `https://api.cloudinary.com/v1_1/${cloud}/image/upload`,
      {
        method: 'POST',
        body: form,
      },
    );
    if (response.ok) return;
    const body = (await response.json().catch(() => null)) as {
      error?: { message?: string };
    } | null;
    throw new BadRequestException(
      body?.error?.message ?? 'Could not save that image',
    );
  }
}
