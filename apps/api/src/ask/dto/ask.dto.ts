import { Transform } from 'class-transformer';
import { IsIn, IsOptional, IsString, Length, Matches } from 'class-validator';

export class AskDto {
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @Length(2, 300)
  question: string;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  today: string;

  @IsOptional()
  @IsIn(['en', 'ml', 'mg'])
  language?: 'en' | 'ml' | 'mg';
}
