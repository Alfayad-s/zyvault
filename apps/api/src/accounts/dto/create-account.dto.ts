import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, MinLength } from 'class-validator';
import { bankIds } from '../../banks/banks.js';

export class CreateAccountDto {
  @IsString()
  @MinLength(1)
  name: string;

  @IsIn(['cash', 'bank'])
  type: 'cash' | 'bank';

  @Type(() => Number)
  @IsInt()
  openingBalance: number;

  @IsOptional()
  @IsIn(bankIds)
  bankId?: string;
}
