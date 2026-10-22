import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { TransactionDto } from './dto/transaction.dto.js';
import { TransactionsService } from './transactions.service.js';

@Controller('transactions')
@UseGuards(AuthGuard)
export class TransactionsController {
  constructor(private readonly transactions: TransactionsService) {}

  @Get()
  list(
    @CurrentUser() user: AuthUser,
    @Query('month') month?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('kind') kind?: string,
    @Query('q') q?: string,
  ) {
    return this.transactions.list(
      user.id,
      this.month(month),
      this.limit(limit),
      this.range(from, to),
      this.offset(offset),
      this.kind(kind),
      this.query(q),
    );
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() body: TransactionDto) {
    return this.transactions.create(user.id, body);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: TransactionDto,
  ) {
    return this.transactions.update(user.id, id, body);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.transactions.remove(user.id, id);
  }

  private month(month?: string): string | undefined {
    if (month === undefined || month === '') {
      return undefined;
    }
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) {
      throw new BadRequestException('month must be YYYY-MM');
    }
    return month;
  }

  private limit(limit?: string): number {
    if (limit === undefined || limit === '') {
      return 50;
    }
    const parsed = Number(limit);
    if (!Number.isInteger(parsed) || parsed < 1 || parsed > 1500) {
      throw new BadRequestException('limit must be from 1 to 1500');
    }
    return parsed;
  }

  private query(q?: string): string | undefined {
    const trimmed = q?.trim() ?? '';
    if (!trimmed) return undefined;
    if (trimmed.length > 40) throw new BadRequestException('search must be 40 characters or less');
    return trimmed;
  }

  private kind(kind?: string): 'income' | 'expense' | undefined {
    if (kind === undefined || kind === '') return undefined;
    if (kind !== 'income' && kind !== 'expense') {
      throw new BadRequestException('kind must be income or expense');
    }
    return kind;
  }

  private offset(offset?: string): number {
    if (offset === undefined || offset === '') return 0;
    const parsed = Number(offset);
    if (!Number.isInteger(parsed) || parsed < 0 || parsed > 100000) {
      throw new BadRequestException('offset must be from 0 to 100000');
    }
    return parsed;
  }

  private range(from?: string, to?: string): { from: string; to: string } | undefined {
    const start = this.date(from, 'from');
    const end = this.date(to, 'to');
    if (!start && !end) {
      return undefined;
    }
    if (!start || !end || start >= end) {
      throw new BadRequestException('from and to must be YYYY-MM-DD, with from before to');
    }
    return { from: start, to: end };
  }

  private date(value: string | undefined, name: string): string | undefined {
    if (value === undefined || value === '') {
      return undefined;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new BadRequestException(`${name} must be YYYY-MM-DD`);
    }
    return value;
  }
}
