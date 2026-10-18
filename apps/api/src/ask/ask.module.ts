import { Module } from '@nestjs/common';
import { AccountsModule } from '../accounts/accounts.module.js';
import { AgentModule } from '../agent/agent.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { BudgetsModule } from '../budgets/budgets.module.js';
import { CategoriesModule } from '../categories/categories.module.js';
import { DebtsModule } from '../debts/debts.module.js';
import { GoalsModule } from '../goals/goals.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { AskController } from './ask.controller.js';
import { AskService } from './ask.service.js';

@Module({
  imports: [
    SupabaseModule,
    AuthModule,
    AgentModule,
    AccountsModule,
    CategoriesModule,
    DebtsModule,
    GoalsModule,
    BudgetsModule,
  ],
  controllers: [AskController],
  providers: [AskService],
})
export class AskModule {}
