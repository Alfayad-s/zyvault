import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { DebtsController } from './debts.controller.js';
import { DebtsService } from './debts.service.js';

@Module({
  imports: [SupabaseModule, AuthModule],
  controllers: [DebtsController],
  providers: [DebtsService],
  exports: [DebtsService],
})
export class DebtsModule {}
