import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { BanksController } from './banks.controller.js';
import { BanksService } from './banks.service.js';

@Module({
  imports: [SupabaseModule, AuthModule],
  controllers: [BanksController],
  providers: [BanksService],
  exports: [BanksService],
})
export class BanksModule {}
