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
import { CurrentUser } from '../auth/current-user.decorator.js';
import { GoalDto, GoalEntryDto } from './dto/goal.dto.js';
import { GoalsService } from './goals.service.js';

@Controller('goals')
@UseGuards(AuthGuard)
export class GoalsController {
  constructor(private readonly goals: GoalsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.goals.list(user.id);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() body: GoalDto) {
    return this.goals.create(user.id, body);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: GoalDto,
  ) {
    return this.goals.update(user.id, id, body);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.goals.remove(user.id, id);
  }

  @Get(':id/entries')
  entries(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.goals.entries(user.id, id);
  }

  @Post(':id/entries')
  addEntry(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: GoalEntryDto,
  ) {
    return this.goals.addEntry(user.id, id, body);
  }

  @Delete('entries/:entryId')
  @HttpCode(204)
  removeEntry(
    @CurrentUser() user: AuthUser,
    @Param('entryId', ParseUUIDPipe) entryId: string,
  ) {
    return this.goals.removeEntry(user.id, entryId);
  }
}
