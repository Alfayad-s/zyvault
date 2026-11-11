import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { IsBoolean } from 'class-validator';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { AccessService } from './access.service.js';

class FeatureDto {
  @IsBoolean()
  enabled!: boolean;
}

@Controller()
@UseGuards(AuthGuard)
export class AccessController {
  constructor(private readonly access: AccessService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.access.me(user);
  }

  @Patch('admin/features/:key')
  set(@CurrentUser() user: AuthUser, @Param('key') key: string, @Body() body: FeatureDto) {
    return this.access.setFeature(user, key, body.enabled);
  }
}
