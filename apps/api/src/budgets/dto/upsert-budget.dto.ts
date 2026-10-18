import { Type } from 'class-transformer';
import { IsInt, IsUUID, Matches, Min } from 'class-validator';

export class UpsertBudgetDto {
  @IsUUID()
  categoryId: string;

  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/)
  month: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  limitAmount: number;
}
