import {
  BadRequestException,
  Body,
  Controller,
  HttpCode,
  Logger,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { DebtsService } from '../debts/debts.service.js';
import { GoalsService } from '../goals/goals.service.js';
import { TransactionDto } from '../transactions/dto/transaction.dto.js';
import { SchedulesService } from '../schedules/schedules.service.js';
import { TransactionsService } from '../transactions/transactions.service.js';
import { AIAgentService, type CategorizedSpend } from './ai-agent.service.js';
import { readBillImage } from './bill.js';
import { CommitSpendDto } from './dto/commit-spend.dto.js';
import { ParseSpendDto } from './dto/parse-spend.dto.js';
import { spendNote, type SpendDebt, type SpendGoal, type SpendSchedule } from './spend.js';

type SaveItem = {
  amount: number;
  kind: 'income' | 'expense';
  categoryId: string;
  occurredOn: string;
  note: string | null;
  accountId: string;
  schedule: SpendSchedule | null;
  debt: SpendDebt | null;
  goal: SpendGoal | null;
  description: string | null;
};

@Controller('transactions')
@UseGuards(AuthGuard)
export class AgentController {
  private readonly logger = new Logger(AgentController.name);

  constructor(
    private readonly agent: AIAgentService,
    private readonly transactions: TransactionsService,
    private readonly schedules: SchedulesService,
    private readonly debts: DebtsService,
    private readonly goals: GoalsService,
  ) {}

  @Post('parse')
  async parse(@CurrentUser() user: AuthUser, @Body() body: ParseSpendDto) {
    const image = readBillImage(body.image, body.mimeType);
    const text = body.text?.trim() ?? '';
    if (!image && text.length === 0) {
      throw new BadRequestException('Type an amount, a space, then what it was for');
    }
    const spends = await this.agent.parse(user.id, text, body.today, image, body.time);
    const preview = Boolean(image || body.preview);
    this.logger.log(
      `AI ${preview ? 'read' : 'saved'} ${spends
        .map(
          (spend) =>
            `${spend.goal ? `goal ${spend.goal.action} ${spend.goal.name}` : spend.debt ? `${spend.debt.type} ${spend.debt.person}` : spend.kind} ${spend.amount / 100} ${spend.categoryName} on ${spend.occurredOn}`,
        )
        .join(', ')}`,
    );

    if (preview) {
      return spends.map((spend) => ({ parsed: parsedView(spend) }));
    }

    return this.save(
      user.id,
      spends.map((spend) => ({
        amount: spend.amount,
        kind: spend.kind,
        categoryId: spend.categoryId,
        occurredOn: spend.occurredOn,
        note: spendNote(spend),
        accountId: spend.accountId ?? body.accountId,
        schedule: spend.schedule,
        debt: spend.debt,
        goal: spend.goal,
        description: spend.rawDescription,
      })),
      body.today,
      body.time,
    );
  }

  @Post('commit')
  @HttpCode(200)
  async commit(@CurrentUser() user: AuthUser, @Body() body: CommitSpendDto) {
    this.logger.log(`Saving ${body.items.length} reviewed ${body.items.length === 1 ? 'entry' : 'entries'}`);
    return this.save(
      user.id,
      body.items.map((item) => ({
        amount: item.amount,
        kind: item.kind,
        categoryId: item.categoryId,
        occurredOn: item.occurredOn,
        note: item.note?.trim() || null,
        accountId: item.accountId ?? body.accountId,
        schedule: item.schedule
          ? {
              repeat: item.schedule.repeat,
              dayOfMonth: item.schedule.dayOfMonth,
              nextOn: item.schedule.nextOn,
              atTime: item.schedule.atTime ?? null,
            }
          : null,
        debt: item.debt ?? null,
        goal: item.goal ?? null,
        description: item.note?.trim() || null,
      })),
      body.today,
      body.time,
    );
  }

  private async save(userId: string, items: SaveItem[], today: string, now?: string) {
    const saved = [];
    let dueNow = false;
    for (const item of items) {
      if (item.schedule) {
        const schedule = await this.schedules.create(userId, {
          accountId: item.accountId,
          categoryId: item.categoryId,
          amount: item.amount,
          kind: item.kind,
          note: item.note,
          repeat: item.schedule.repeat,
          dayOfMonth: item.schedule.dayOfMonth,
          nextOn: item.schedule.nextOn,
          atTime: item.schedule.atTime,
        });
        dueNow ||=
          schedule.nextOn < today ||
          (schedule.nextOn === today && (!schedule.atTime || !now || schedule.atTime <= now));
        saved.push({ schedule });
        continue;
      }
      const goal = item.goal ? await this.goals.find(userId, item.goal.name) : null;
      if (item.goal && goal) {
        const { entry, goal: updated } = await this.goals.addEntry(userId, goal.id, {
          type: item.goal.action,
          amount: item.amount,
          occurredOn: item.occurredOn,
          note: item.description ?? undefined,
        });
        saved.push({ goalEntry: entry, goal: updated });
        continue;
      }
      if (item.debt && (await this.isDebt(userId, item.debt))) {
        const debt = await this.debts.create(userId, {
          person: item.debt.person,
          type: item.debt.type,
          amount: item.amount,
          accountId: item.accountId,
          occurredOn: item.occurredOn,
          note: item.description ?? undefined,
        });
        saved.push({ debt });
        continue;
      }
      const row: TransactionDto = {
        accountId: item.accountId,
        categoryId: item.categoryId,
        amount: item.amount,
        kind: item.kind,
        occurredOn: item.occurredOn,
        note: item.note ?? undefined,
      };
      saved.push({ transaction: await this.transactions.create(userId, row) });
    }
    if (dueNow) await this.schedules.runDue(userId, today, now);
    return saved;
  }

  /** A payback only settles a loan when that person has one open; otherwise it is plain income or spending. */
  private async isDebt(userId: string, debt: SpendDebt): Promise<boolean> {
    if (debt.type === 'lent' || debt.type === 'borrowed') return true;
    const balance = await this.debts.balanceWith(userId, debt.person);
    return debt.type === 'got_back' ? balance > 0 : balance < 0;
  }
}

function parsedView(spend: CategorizedSpend) {
  return {
    amount: spend.amount,
    currency: spend.currency,
    merchant: spend.merchant,
    occurredOn: spend.occurredOn,
    categoryId: spend.categoryId,
    categoryName: spend.categoryName,
    rawDescription: spend.rawDescription,
    note: spendNote(spend),
    kind: spend.kind,
    categorySource: spend.source,
    confidence: spend.confidence,
    schedule: spend.schedule,
    accountId: spend.accountId,
    accountName: spend.accountName,
    debt: spend.debt,
    goal: spend.goal,
  };
}
