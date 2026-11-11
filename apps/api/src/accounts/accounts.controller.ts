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
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { AccessService } from '../access/access.service.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { AccountsService } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';

@Controller('accounts')
@UseGuards(AuthGuard)
export class AccountsController {
  constructor(
    private readonly accounts: AccountsService,
    private readonly access: AccessService,
  ) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.accounts.list(user.id);
  }

  @Get(':id/card')
  async card(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    await this.access.assert(user, 'creditCards');
    return this.accounts.card(user.id, id);
  }

  @Post()
  async create(@CurrentUser() user: AuthUser, @Body() body: CreateAccountDto) {
    if (body.type === 'credit') await this.access.assert(user, 'creditCards');
    return this.accounts.create(user.id, body);
  }

  @Patch(':id')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: CreateAccountDto,
  ) {
    if (body.type === 'credit' || (await this.accounts.kind(user.id, id)) === 'credit') {
      await this.access.assert(user, 'creditCards');
    }
    return this.accounts.update(user.id, id, body);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    if ((await this.accounts.kind(user.id, id)) === 'credit') await this.access.assert(user, 'creditCards');
    return this.accounts.remove(user.id, id);
  }
}
