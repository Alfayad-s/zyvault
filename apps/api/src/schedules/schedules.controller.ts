import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, Matches } from 'class-validator';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { SchedulesService } from './schedules.service.js';

export class ScheduleDto {
  @IsUUID()
  accountId!: string;

  @IsUUID()
  categoryId!: string;

  @IsInt()
  @Min(1)
  amount!: number;

  @IsIn(['income', 'expense'])
  kind!: 'income' | 'expense';

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  @IsIn(['once', 'monthly'])
  repeat!: 'once' | 'monthly';

  @IsInt()
  @Min(1)
  @Max(31)
  dayOfMonth!: number;

  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  nextOn!: string;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  atTime?: string | null;
}

export class RunSchedulesDto {
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  today: string;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  time?: string;
}

@Controller('schedules')
@UseGuards(AuthGuard)
export class SchedulesController {
  constructor(private readonly schedules: SchedulesService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.schedules.list(user.id);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() body: ScheduleDto) {
    return this.schedules.create(user.id, body);
  }

  @Patch(':id')
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() body: ScheduleDto) {
    return this.schedules.update(user.id, id, body);
  }

  @Post('run')
  @HttpCode(200)
  run(@CurrentUser() user: AuthUser, @Body() body: RunSchedulesDto) {
    return this.schedules.runDue(user.id, body.today, body.time);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.schedules.remove(user.id, id);
  }
}
