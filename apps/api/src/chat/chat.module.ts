import { Module } from '@nestjs/common';
import { AccountsModule } from '../accounts/accounts.module.js';
import { AgentModule } from '../agent/agent.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { BudgetsModule } from '../budgets/budgets.module.js';
import { CategoriesModule } from '../categories/categories.module.js';
import { DebtsModule } from '../debts/debts.module.js';
import { GoalsModule } from '../goals/goals.module.js';
import { SchedulesModule } from '../schedules/schedules.module.js';
import { SummaryModule } from '../summary/summary.module.js';
import { TransactionsModule } from '../transactions/transactions.module.js';
import { SupabaseModule } from '../supabase/supabase.module.js';
import { ChatController } from './chat.controller.js';
import { ChatService } from './chat.service.js';

@Module({
  imports: [
    SupabaseModule,
    AuthModule,
    AgentModule,
    SummaryModule,
    AccountsModule,
    BudgetsModule,
    TransactionsModule,
    CategoriesModule,
    GoalsModule,
    DebtsModule,
    SchedulesModule,
  ],
  controllers: [ChatController],
  providers: [ChatService],
})
export class ChatModule {}
