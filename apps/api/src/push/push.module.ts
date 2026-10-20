import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { SchedulesModule } from '../schedules/schedules.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { DevicesController } from './devices.controller.js';
import { FcmClient } from './fcm.client.js';
import { PushJobs } from './push.jobs.js';
import { PushService } from './push.service.js';

@Module({
  imports: [SupabaseModule, AuthModule, SchedulesModule],
  controllers: [DevicesController],
  providers: [FcmClient, PushService, PushJobs],
  exports: [PushService, FcmClient],
})
export class PushModule {}
