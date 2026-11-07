import { IsArray, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import { advisorLanguages } from '../advisor.graph.js';
import { financeQueues } from '../finance.queue.js';

const scenarioKinds = ['purchase', 'extra_monthly', 'income_change', 'savings_target', 'emergency', 'emi'] as const;

export class SimulateDto {
  @IsIn(scenarioKinds)
  kind!: (typeof scenarioKinds)[number];

  @IsInt()
  @Min(1)
  amount!: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(360)
  months?: number;
}

export class FinanceChatDto {
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  message!: string;

  @IsOptional()
  @IsIn(advisorLanguages)
  language?: (typeof advisorLanguages)[number];

  @IsOptional()
  @IsUUID()
  conversationId?: string;
}

export class FeedbackDto {
  @IsIn(['up', 'down'])
  rating!: 'up' | 'down';

  @IsOptional()
  @IsUUID()
  insightId?: string;

  @IsOptional()
  @IsUUID()
  messageId?: string;
}

export class FinanceJobDto {
  @IsIn(financeQueues)
  queue!: (typeof financeQueues)[number];

  @IsOptional()
  @IsInt()
  days?: number;
}

export class ProfileDto {
  @IsInt()
  @Min(0)
  emergencyReserve!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  monthlyDiscretionaryLimit?: number | null;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  essentialCategories?: string[];
}
