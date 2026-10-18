import { Body, Controller, Delete, HttpCode, Post, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Length, Max, Min } from 'class-validator';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { PushService } from './push.service.js';

export class DeviceDto {
  @IsString()
  @Length(20, 4096)
  token: string;

  @IsOptional()
  @IsIn(['android', 'ios'])
  platform?: 'android' | 'ios';

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(-720)
  @Max(840)
  utcOffsetMinutes?: number;
}

@Controller('devices')
@UseGuards(AuthGuard)
export class DevicesController {
  constructor(private readonly push: PushService) {}

  @Post()
  @HttpCode(200)
  register(@CurrentUser() user: AuthUser, @Body() body: DeviceDto) {
    return this.push.register(user.id, body.token, body.platform ?? 'android', body.utcOffsetMinutes ?? 330);
  }

  @Delete()
  @HttpCode(204)
  unregister(@CurrentUser() user: AuthUser, @Body() body: DeviceDto) {
    return this.push.unregister(user.id, body.token);
  }
}
