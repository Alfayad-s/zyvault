import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';
import { debtTypes, type DebtType } from '../debts.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class DebtDto {
  @Transform(trim)
  @IsString()
  @Length(1, 60)
  person: string;

  @IsIn(debtTypes)
  type: DebtType;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  amount: number;

  @IsOptional()
  @IsUUID()
  accountId?: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  occurredOn: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  note?: string;
}
