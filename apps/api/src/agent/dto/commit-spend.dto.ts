import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { debtTypes, type DebtType } from '../../debts/debts.js';

const isoDate = /^\d{4}-\d{2}-\d{2}$/;
const clockTime = /^([01]\d|2[0-3]):[0-5]\d$/;

class CommitScheduleDto {
  @IsIn(['once', 'monthly'])
  repeat: 'once' | 'monthly';

  @IsInt()
  @Min(1)
  @Max(31)
  dayOfMonth: number;

  @Matches(isoDate)
  nextOn: string;

  @IsOptional()
  @Matches(clockTime)
  atTime?: string | null;
}

class CommitDebtDto {
  @IsIn(debtTypes)
  type: DebtType;

  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @Length(1, 60)
  person: string;
}

class CommitGoalDto {
  @IsString()
  @Length(1, 40)
  name: string;

  @IsIn(['add', 'take_out'])
  action: 'add' | 'take_out';
}

export class CommitItemDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  amount: number;

  @IsIn(['income', 'expense'])
  kind: 'income' | 'expense';

  @IsUUID()
  categoryId: string;

  @Matches(isoDate)
  occurredOn: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  @IsOptional()
  @IsUUID()
  accountId?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => CommitScheduleDto)
  schedule?: CommitScheduleDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => CommitDebtDto)
  debt?: CommitDebtDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => CommitGoalDto)
  goal?: CommitGoalDto;
}

export class CommitSpendDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => CommitItemDto)
  items: CommitItemDto[];

  @IsUUID()
  accountId: string;

  @Matches(isoDate)
  today: string;

  @IsOptional()
  @Matches(clockTime)
  time?: string;
}
