import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { AskService } from './ask.service.js';
import { AskDto } from './dto/ask.dto.js';

@Controller('ask')
@UseGuards(AuthGuard)
export class AskController {
  constructor(private readonly asker: AskService) {}

  @Post()
  @HttpCode(200)
  ask(@CurrentUser() user: AuthUser, @Body() body: AskDto) {
    return this.asker.ask(user.id, body.question, body.today);
  }
}
