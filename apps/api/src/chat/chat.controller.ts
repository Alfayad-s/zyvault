import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { IsObject } from 'class-validator';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { ChatService } from './chat.service.js';
import { ChatDto } from './dto/chat.dto.js';

class ChatApplyDto {
  @IsObject()
  action!: Record<string, unknown>;
}

@Controller('chat')
@UseGuards(AuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Post()
  @HttpCode(200)
  reply(@CurrentUser() user: AuthUser, @Body() body: ChatDto) {
    return this.chat.reply(user.id, body);
  }

  @Post('apply')
  @HttpCode(200)
  apply(@CurrentUser() user: AuthUser, @Body() body: ChatApplyDto) {
    return this.chat.apply(user.id, body.action);
  }
}
