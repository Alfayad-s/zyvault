import { IsBoolean, IsIn, IsOptional, IsString, IsUUID, Matches, MaxLength } from 'class-validator';

export const billMimeTypes = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
  'application/pdf',
] as const;

export class ParseSpendDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  text?: string;

  @IsOptional()
  @IsBoolean()
  preview?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(8_000_000)
  image?: string;

  @IsOptional()
  @IsIn(billMimeTypes)
  mimeType?: (typeof billMimeTypes)[number];

  @IsUUID()
  accountId: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  today: string;

  /** The phone's local time, HH:MM, so "today at 6pm" can be scheduled. */
  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  time?: string;
}
