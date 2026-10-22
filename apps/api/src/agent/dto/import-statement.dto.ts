import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsIn, IsOptional, IsString, IsUUID, MaxLength, ValidateNested } from 'class-validator';
import { TransactionDto } from '../../transactions/dto/transaction.dto.js';

export const statementMimeTypes = [
  'text/csv',
  'application/csv',
  'text/plain',
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-excel',
] as const;

export class ImportStatementDto {
  @IsString()
  @MaxLength(8_000_000)
  file: string;

  @IsIn(statementMimeTypes)
  mimeType: (typeof statementMimeTypes)[number];

  @IsUUID()
  accountId: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  password?: string;
}

export class ImportCommitDto {
  @IsUUID()
  accountId: string;

  @IsArray()
  @ArrayMaxSize(1500)
  @ValidateNested({ each: true })
  @Type(() => TransactionDto)
  items: TransactionDto[];
}
