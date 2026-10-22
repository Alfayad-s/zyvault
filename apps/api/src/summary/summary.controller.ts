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

  @Get('period')
  period(
    @CurrentUser() user: AuthUser,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const start = this.day(from, 'from');
    const end = this.day(to, 'to');
    if (!start || !end || start >= end) {
      throw new BadRequestException('from and to must be YYYY-MM-DD, with from before to');
    }
    return this.summary.forRange(user.id, start, end);
  }

  @Get()
  get(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    if (!month || !/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) {
      throw new BadRequestException('month must be YYYY-MM');
    }
    return this.summary.forMonth(user.id, month);
  }

  private day(value: string | undefined, name: string): string | undefined {
    if (!value) return undefined;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new BadRequestException(`${name} must be YYYY-MM-DD`);
    }
    return value;
  }
}
