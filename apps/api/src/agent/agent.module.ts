import { Module } from '@nestjs/common';
import { AccountsModule } from '../accounts/accounts.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { CategoriesModule } from '../categories/categories.module.js';
import { DebtsModule } from '../debts/debts.module.js';
import { GoalsModule } from '../goals/goals.module.js';
import { SchedulesModule } from '../schedules/schedules.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { TransactionsModule } from '../transactions/transactions.module.js';
import { AgentController } from './agent.controller.js';
import { AIAgentService } from './ai-agent.service.js';
import { LlmClient } from './llm.client.js';
import { ZeroShotClient } from './zero-shot.client.js';

@Module({
  imports: [
    SupabaseModule,
    AuthModule,
    AccountsModule,
    CategoriesModule,
    TransactionsModule,
    SchedulesModule,
    DebtsModule,
    GoalsModule,
  ],
  controllers: [AgentController],
  providers: [AIAgentService, LlmClient, ZeroShotClient],
  exports: [LlmClient],
})
export class AgentModule {}
