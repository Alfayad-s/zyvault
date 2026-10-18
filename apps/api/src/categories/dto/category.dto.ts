import { Transform } from 'class-transformer';
import { IsIn, IsOptional, IsString, Length } from 'class-validator';
import { categoryIcons } from '../icons.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class CreateCategoryDto {
  @Transform(trim)
  @IsString()
  @Length(1, 32)
  name: string;

  @IsIn(['income', 'expense'])
  kind: 'income' | 'expense';

  @IsIn(categoryIcons)
  icon: string;
}

export class UpdateCategoryDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(1, 32)
  name?: string;

  @IsOptional()
  @IsIn(categoryIcons)
  icon?: string;
}
