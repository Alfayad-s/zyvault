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
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { Feature } from '../access/feature.decorator.js';
import { FeatureGuard } from '../access/feature.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { DebtsService } from './debts.service.js';
import { DebtDto } from './dto/debt.dto.js';

@Controller('debts')
@Feature('people')
@UseGuards(AuthGuard, FeatureGuard)
export class DebtsController {
  constructor(private readonly debts: DebtsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.debts.list(user.id);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() body: DebtDto) {
    return this.debts.create(user.id, body);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.debts.remove(user.id, id);
  }
}
