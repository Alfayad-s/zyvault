import { Body, Controller, HttpCode, Logger, Post, UseGuards } from '@nestjs/common';
import type { AuthUser } from '../auth/auth-user.js';
import { AuthGuard } from '../auth/auth.guard.js';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { TransactionsService } from '../transactions/transactions.service.js';
import { ImportCommitDto, ImportStatementDto } from './dto/import-statement.dto.js';
import { StatementService } from './statement.service.js';

@Controller('transactions')
@UseGuards(AuthGuard)
export class StatementController {
  private readonly logger = new Logger(StatementController.name);

  constructor(
    private readonly statements: StatementService,
    private readonly transactions: TransactionsService,
  ) {}

  @Post('import')
  async read(@CurrentUser() user: AuthUser, @Body() body: ImportStatementDto) {
    const rows = await this.statements.read(user.id, body.accountId, body.file, body.mimeType, body.password);
    this.logger.log(`Read ${rows.length} statement ${rows.length === 1 ? 'row' : 'rows'}`);
    return { rows };
  }

  @Post('import/commit')
  @HttpCode(200)
  async commit(@CurrentUser() user: AuthUser, @Body() body: ImportCommitDto) {
    const saved = await this.transactions.createMany(
      user.id,
      body.items.map((item) => ({ ...item, accountId: body.accountId })),
    );
    this.logger.log(`Saved ${saved} statement ${saved === 1 ? 'row' : 'rows'}`);
    return { saved };
  }
}
