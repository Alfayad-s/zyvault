import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { CategoriesService } from '../categories/categories.service.js';
import { TransactionsService } from '../transactions/transactions.service.js';
import { StatementLocked, pdfStatement } from './statement-file.js';
import { xlsxStatement } from './statement-sheet.js';
import {
  applyCategories,
  prepareRows,
  rowKey,
  statementPageCap,
  statementRowCap,
  statementRows,
  type NamedCategory,
  type StatementKind,
  type StatementRow,
} from './statement.js';
import { LlmClient } from './llm.client.js';
import { VisionClient } from './vision.client.js';

export type ImportedRow = {
  occurredOn: string;
  note: string;
  amount: number;
  kind: StatementKind;
  categoryId: string;
  categoryName: string;
  duplicate: boolean;
  uncertain: boolean;
};

@Injectable()
export class StatementService {
  private readonly logger = new Logger(StatementService.name);

  constructor(
    private readonly vision: VisionClient,
    private readonly llm: LlmClient,
    private readonly categories: CategoriesService,
    private readonly transactions: TransactionsService,
  ) {}

  async read(
    userId: string,
    accountId: string,
    file: string,
    mimeType: string,
    password?: string,
  ): Promise<ImportedRow[]> {
    const source = await this.sourceOf(file, mimeType, password);
    const rows = source.rows ?? statementRows(source.text);
    if (rows.length === 0) {
      throw new BadRequestException('No payments found in that statement');
    }
    if (rows.length > statementRowCap) {
      throw new BadRequestException(`That statement has more than ${statementRowCap} payments. Import up to 3 months at a time`);
    }
    const [categories, past, saved] = await Promise.all([
      this.categories.list(userId),
      this.transactions.list(userId, undefined, 200),
      this.transactions.keysBetween(
        userId,
        accountId,
        rows.reduce((min, row) => (row.occurredOn < min ? row.occurredOn : min), rows[0]!.occurredOn),
        rows.reduce((max, row) => (row.occurredOn > max ? row.occurredOn : max), rows[0]!.occurredOn),
      ),
    ]);
    const named = categories.map((category) => ({ name: category.name, kind: category.kind }));
    const prepared = prepareRows(rows, named, past);
    const chosen = await this.ask(named, prepared.unknown);
    const filled = applyCategories(prepared.ready, chosen, named);
    const byName = new Map(categories.map((category) => [`${category.kind}:${category.name.toLowerCase()}`, category]));
    return filled.map((row) => {
      const category = byName.get(`${row.kind}:${row.categoryName.toLowerCase()}`);
      if (!category) throw new BadRequestException('Categories are not set up yet');
      return {
        occurredOn: row.occurredOn,
        note: row.note,
        amount: row.amount,
        kind: row.kind,
        categoryId: category.id,
        categoryName: category.name,
        duplicate: saved.has(rowKey(row)),
        uncertain: row.uncertain,
      };
    });
  }

  private async sourceOf(
    file: string,
    mimeType: string,
    password?: string,
  ): Promise<{ text: string; rows: StatementRow[] | null }> {
    let bytes: Buffer;
    try {
      bytes = Buffer.from(file, 'base64');
    } catch {
      throw new BadRequestException('That statement file could not be read');
    }
    if (bytes.length === 0) throw new BadRequestException('That statement file is empty');
    if (mimeType.includes('spreadsheet') || mimeType === 'application/vnd.ms-excel') {
      try {
        return { text: xlsxStatement(new Uint8Array(bytes)), rows: null };
      } catch (caught) {
        this.logger.warn(`Could not read the spreadsheet: ${caught instanceof Error ? caught.name : 'error'}`);
        throw new BadRequestException('That spreadsheet could not be read. Save it as CSV and try again');
      }
    }
    if (mimeType !== 'application/pdf') return { text: bytes.toString('utf8'), rows: null };
    let extracted: { text: string; pages: number; rows: StatementRow[] | null };
    try {
      extracted = await pdfStatement(new Uint8Array(bytes), password);
    } catch (caught) {
      if (caught instanceof StatementLocked) throw new BadRequestException(caught.message);
      this.logger.warn(`Could not read the PDF text layer: ${caught instanceof Error ? caught.name : 'error'}`);
      extracted = { text: '', pages: 1, rows: null };
    }
    if (extracted.rows) return { text: '', rows: extracted.rows };
    const printed = statementRows(extracted.text);
    if (printed.length > 0) return { text: extracted.text, rows: null };
    if (password) {
      throw new BadRequestException('The statement opened, but those pages have no text. Export a CSV instead');
    }
    if (extracted.pages > statementPageCap) {
      throw new BadRequestException(`That statement is longer than ${statementPageCap} pages. Split it and import each part`);
    }
    const seen = await this.vision.read({ mimeType: 'application/pdf', data: file }, statementPageCap);
    if (!seen.text.trim()) throw new BadRequestException('No payments found in that statement');
    return { text: seen.text, rows: null };
  }

  private async ask(categories: NamedCategory[], notes: string[]): Promise<Map<string, string>> {
    const pending = notes.slice(0, 80);
    if (pending.length === 0) return new Map();
    const expense = categories.filter((category) => category.kind === 'expense').map((category) => category.name);
    const income = categories.filter((category) => category.kind === 'income').map((category) => category.name);
    try {
      const reply = await this.llm.complete(
        `You categorise bank narrations for an Indian finance app. Reply with only a JSON array. Each object is {"narration": the exact narration, "category": one name copied from the lists}. Expense: ${expense.join(', ') || 'Other'}. Income: ${income.join(', ') || 'Other income'}.`,
        pending.map((note, index) => `${index + 1}. ${note}`).join('\n'),
      );
      return categoriesFrom(reply);
    } catch (caught) {
      this.logger.warn(`Statement categories were not answered: ${String(caught)}`);
      return new Map();
    }
  }
}

function categoriesFrom(text: string): Map<string, string> {
  const start = text.indexOf('[');
  const end = text.lastIndexOf(']');
  if (start < 0 || end < start) return new Map();
  const parsed = JSON.parse(text.slice(start, end + 1)) as unknown;
  const chosen = new Map<string, string>();
  if (!Array.isArray(parsed)) return chosen;
  for (const item of parsed) {
    if (!item || typeof item !== 'object') continue;
    const narration = (item as { narration?: unknown }).narration;
    const category = (item as { category?: unknown }).category;
    if (typeof narration === 'string' && typeof category === 'string') {
      chosen.set(narration.trim().toLowerCase(), category.trim());
    }
  }
  return chosen;
}
