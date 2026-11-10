import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, Min, MinLength, ValidateIf } from 'class-validator';
import { bankIds } from '../../banks/banks.js';

export class CreateAccountDto {
  @IsString()
  @MinLength(1)
  name: string;

  @IsIn(['cash', 'bank', 'credit'])
  type: 'cash' | 'bank' | 'credit';

  @Type(() => Number)
  @IsInt()
  openingBalance: number;

  @IsOptional()
  @IsIn(bankIds)
  bankId?: string;

  @ValidateIf((account: CreateAccountDto) => account.type === 'credit')
  @IsIn(['fd', 'bank'])
  cardKind?: 'fd' | 'bank';

  @ValidateIf((account: CreateAccountDto) => account.type === 'credit')
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limitAmount?: number;

  @ValidateIf((account: CreateAccountDto) => account.type === 'credit' && account.cardKind === 'bank')
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(28)
  billDay?: number;

  @ValidateIf((account: CreateAccountDto) => account.type === 'credit' && account.cardKind === 'bank')
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(28)
  dueDay?: number;
}
