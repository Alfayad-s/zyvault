import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AccountModule } from './account/account.module.js';
import { AccountsModule } from './accounts/accounts.module.js';
import { AgentModule } from './agent/agent.module.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AskModule } from './ask/ask.module.js';
import { AuthModule } from './auth/auth.module.js';
import { BanksModule } from './banks/banks.module.js';
import { BudgetsModule } from './budgets/budgets.module.js';
import { CategoriesModule } from './categories/categories.module.js';
import { ChatModule } from './chat/chat.module.js';
import { DebtsModule } from './debts/debts.module.js';
import { GoalsModule } from './goals/goals.module.js';
import { HealthController } from './health.controller.js';
import { StatusService } from './status.service.js';
import { PushModule } from './push/push.module.js';
import { SchedulesModule } from './schedules/schedules.module.js';
import { SummaryModule } from './summary/summary.module.js';
import { SupabaseModule } from './supabase/supabase.module.js';
import { TransactionsModule } from './transactions/transactions.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    SupabaseModule,
    AuthModule,
    AccountModule,
    AccountsModule,
    CategoriesModule,
    TransactionsModule,
    SummaryModule,
    BudgetsModule,
    AgentModule,
    SchedulesModule,
    BanksModule,
    DebtsModule,
    GoalsModule,
    AskModule,
    ChatModule,
    PushModule,
  ],
  controllers: [AppController, HealthController],
  providers: [AppService, StatusService],
})
export class AppModule {}
