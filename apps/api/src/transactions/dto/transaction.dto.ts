import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Min,
  MinLength,
} from 'class-validator';

export class TransactionDto {
  @IsUUID()
  accountId: string;

  @IsUUID()
  categoryId: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  amount: number;

  @IsIn(['income', 'expense'])
  kind: 'income' | 'expense';

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  occurredOn: string;

  @IsOptional()
  @IsString()
  @MinLength(0)
  note?: string;
}
