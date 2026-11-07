import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { LlmClient } from './agent/llm.client.js';
import { BudgetsService } from './budgets/budgets.service.js';
import { DebtsService } from './debts/debts.service.js';
import { GoalsService } from './goals/goals.service.js';
import { SchedulesService } from './schedules/schedules.service.js';
import { SummaryService } from './summary/summary.service.js';
import { SupabaseModule } from './supabase/supabase.module.js';
import { TransactionsService } from './transactions/transactions.service.js';
import { FinanceInfraModule } from './finance/finance.module.js';
import { FinanceService } from './finance/finance.service.js';
import { WorkerHealthController, WorkerRunner } from './finance/worker.runner.js';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), SupabaseModule, FinanceInfraModule],
  controllers: [WorkerHealthController],
  providers: [
    SummaryService,
    BudgetsService,
    TransactionsService,
    SchedulesService,
    GoalsService,
    DebtsService,
    LlmClient,
    FinanceService,
    WorkerRunner,
  ],
})
export class WorkerModule {}
