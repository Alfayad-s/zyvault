import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthGuard } from './auth/auth.guard.js';
import { StatusService } from './status.service.js';

@Controller('health')
export class HealthController {
  constructor(private readonly status: StatusService) {}

  @Get()
  getHealth(): { status: string } {
    return { status: 'ok' };
  }

  @Get('details')
  @UseGuards(AuthGuard)
  details() {
    return this.status.collect();
  }
}
