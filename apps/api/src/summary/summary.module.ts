import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { SummaryController } from './summary.controller.js';
import { SummaryService } from './summary.service.js';

@Module({
  imports: [SupabaseModule, AuthModule],
  controllers: [SummaryController],
  providers: [SummaryService],
  exports: [SummaryService],
})
export class SummaryModule {}
