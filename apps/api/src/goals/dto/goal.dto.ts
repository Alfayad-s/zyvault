import { Transform, Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { goalIcons } from '../../categories/icons.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class GoalDto {
  @Transform(trim)
  @IsString()
  @Length(1, 40)
  name: string;

  @IsIn(goalIcons)
  icon: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  targetAmount: number;

  @IsOptional()
  @ValidateIf((_, value) => value !== null)
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  targetDate?: string | null;
}

export class GoalEntryDto {
  @IsIn(['add', 'take_out'])
  type: 'add' | 'take_out';

  @Type(() => Number)
  @IsInt()
  @Min(1)
  amount: number;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  occurredOn: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  note?: string;
}
