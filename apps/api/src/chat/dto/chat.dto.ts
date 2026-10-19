import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsIn, IsOptional, IsString, Length, Matches, MaxLength, ValidateNested } from 'class-validator';

export class ChatMessageDto {
  @IsIn(['user', 'assistant'])
  role!: 'user' | 'assistant';

  @IsString()
  @Length(1, 400)
  content!: string;
}

export class ChatDto {
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  today!: string;

  @IsOptional()
  @IsString()
  @MaxLength(800)
  memory?: string;

  @ArrayMinSize(1)
  @ArrayMaxSize(8)
  @ValidateNested({ each: true })
  @Type(() => ChatMessageDto)
  messages!: ChatMessageDto[];
}
