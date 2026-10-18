import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { IsOptional, Matches } from 'class-validator';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { SchedulesService } from './schedules.service.js';

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
