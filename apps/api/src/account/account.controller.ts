import { Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { AccountService } from './account.service.js';

@Controller('account')
@UseGuards(AuthGuard)
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Post('clear')
  @HttpCode(200)
  async clear(@CurrentUser() user: AuthUser) {
    await this.account.clear(user.id);
    return { cleared: true };
  }
}
