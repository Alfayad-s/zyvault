import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { AccessController } from './access.controller.js';
import { AccessService } from './access.service.js';
import { FeatureGuard } from './feature.guard.js';

@Module({
  imports: [SupabaseModule, AuthModule],
  controllers: [AccessController],
  providers: [AccessService, FeatureGuard],
  exports: [AccessService, FeatureGuard],
})
export class AccessModule {}
