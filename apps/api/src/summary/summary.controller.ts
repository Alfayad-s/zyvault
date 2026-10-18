import {
  BadRequestException,
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { SummaryService } from './summary.service.js';

@Controller('summary')
@UseGuards(AuthGuard)
export class SummaryController {
  constructor(private readonly summary: SummaryService) {}

  @Get()
  get(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    if (!month || !/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) {
      throw new BadRequestException('month must be YYYY-MM');
    }
    return this.summary.forMonth(user.id, month);
  }
}
