import { Global, Module } from '@nestjs/common';
import { AgentModule } from '../agent/agent.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { BudgetsModule } from '../budgets/budgets.module.js';
import { DebtsModule } from '../debts/debts.module.js';
import { GoalsModule } from '../goals/goals.module.js';
import { SchedulesModule } from '../schedules/schedules.module.js';
import { SummaryModule } from '../summary/summary.module.js';
import { FinanceCache } from './finance.cache.js';
import { FinanceController } from './finance.controller.js';
import { FinanceQueueClient } from './finance.queue.js';
import { FinanceService } from './finance.service.js';

@Global()
@Module({
  providers: [FinanceCache, FinanceQueueClient],
  exports: [FinanceCache, FinanceQueueClient],
})
export class FinanceInfraModule {}

@Module({
  imports: [
    AuthModule,
    SummaryModule,
    BudgetsModule,
    SchedulesModule,
    GoalsModule,
    DebtsModule,
    AgentModule,
  ],
  controllers: [FinanceController],
  providers: [FinanceService],
  exports: [FinanceService],
})
export class FinanceModule {}
