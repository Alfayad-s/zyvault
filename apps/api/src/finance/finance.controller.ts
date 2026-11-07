import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { isHorizon } from './dates.js';
import { FeedbackDto, FinanceChatDto, FinanceJobDto, ProfileDto, SimulateDto } from './dto/finance.dto.js';
import { FinanceService } from './finance.service.js';
import type { FinanceQueue } from './finance.queue.js';

@Controller('finance')
@UseGuards(AuthGuard)
export class FinanceController {
  constructor(private readonly finance: FinanceService) {}

  @Get('overview')
  overview(@CurrentUser() user: AuthUser) {
    return this.finance.overview(user.id);
  }

  @Get('forecast')
  forecast(@CurrentUser() user: AuthUser, @Query('days') days?: string) {
    return this.finance.forecast(user.id, this.horizon(days));
  }

  @Post('forecast/refresh')
  refresh(@CurrentUser() user: AuthUser, @Query('days') days?: string) {
    return this.finance.enqueue(user.id, 'cash-flow-forecast', days ? this.horizon(days) : 30);
  }

  @Get('safe-to-spend')
  safe(@CurrentUser() user: AuthUser) {
    return this.finance.safeToSpend(user.id);
  }

  @Get('health')
  health(@CurrentUser() user: AuthUser) {
    return this.finance.health(user.id);
  }

  @Get('insights')
  insights(@CurrentUser() user: AuthUser) {
    return this.finance.insights(user.id);
  }

  @Get('anomalies')
  anomalies(@CurrentUser() user: AuthUser) {
    return this.finance.anomalies(user.id);
  }

  @Get('profile')
  profile(@CurrentUser() user: AuthUser) {
    return this.finance.profile(user.id);
  }

  @Put('profile')
  saveProfile(@CurrentUser() user: AuthUser, @Body() body: ProfileDto) {
    return this.finance.saveProfile(user.id, body);
  }

  @Post('simulate')
  simulate(@CurrentUser() user: AuthUser, @Body() body: SimulateDto) {
    return this.finance.simulate(user.id, body);
  }

  @Post('chat')
  chat(@CurrentUser() user: AuthUser, @Body() body: FinanceChatDto) {
    return this.finance.chat(user.id, body.message, body.language ?? 'en', body.conversationId);
  }

  @Get('chat')
  chats(@CurrentUser() user: AuthUser) {
    return this.finance.conversations(user.id);
  }

  @Get('chat/:id')
  chatOne(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.finance.conversation(user.id, id);
  }

  @Post('feedback')
  @HttpCode(201)
  feedback(@CurrentUser() user: AuthUser, @Body() body: FeedbackDto) {
    return this.finance.feedback(user.id, body);
  }

  @Post('jobs')
  @HttpCode(202)
  jobs(@CurrentUser() user: AuthUser, @Body() body: FinanceJobDto) {
    return this.finance.enqueue(user.id, body.queue as FinanceQueue, body.days);
  }

  @Get('jobs/:jobId')
  job(@CurrentUser() user: AuthUser, @Param('jobId', ParseUUIDPipe) jobId: string) {
    return this.finance.job(user.id, jobId);
  }

  private horizon(days?: string): number {
    const value = Number(days ?? 30);
    if (!isHorizon(value)) throw new BadRequestException('days must be 7, 15, 30, 60 or 90');
    return value;
  }
}
