import {
  BadRequestException,
  HttpException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { LlmClient } from '../agent/llm.client.js';
import { BudgetsService } from '../budgets/budgets.service.js';
import { DebtsService } from '../debts/debts.service.js';
import { GoalsService } from '../goals/goals.service.js';
import { SchedulesService } from '../schedules/schedules.service.js';
import { SummaryService } from '../summary/summary.service.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import {
  buildAdvisorGraph,
  deterministicReply,
  type AdvisorLanguage,
  type AdvisorTools,
} from './advisor.graph.js';
import { isHorizon, todayInIndia } from './dates.js';
import {
  applyScenario,
  buildForecast,
  buildHealth,
  buildInsights,
  buildOverview,
  buildSafeToSpend,
  detectAnomalies,
  monthBuckets,
  type Anomaly,
  type Forecast,
  type InsightDraft,
  type Overview,
  type SafeToSpend,
  type ScenarioKind,
} from './engine.js';
import { FinanceCache } from './finance.cache.js';
import { FinanceQueueClient, type FinanceQueue } from './finance.queue.js';
import { defaultEssentials, type LedgerTxn, type ProfileInput } from './types.js';

type TxnRow = {
  id: string;
  amount: number;
  kind: 'income' | 'expense';
  occurred_on: string;
  category_id: string;
  account_id: string;
  note: string | null;
  category: { name: string } | { name: string }[] | null;
};

function categoryName(value: TxnRow['category']): string {
  if (!value) return '';
  return Array.isArray(value) ? (value[0]?.name ?? '') : value.name;
}

function missingTable(error: { message: string } | null): boolean {
  return Boolean(error && /(does not exist|schema cache|Could not find)/.test(error.message));
}

export type FinanceJobView = {
  id: string | null;
  queue: FinanceQueue;
  status: 'queued' | 'running' | 'completed' | 'failed';
  error: string | null;
  persisted: boolean;
};

@Injectable()
export class FinanceService {
  private readonly logger = new Logger(FinanceService.name);

  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly summary: SummaryService,
    private readonly budgets: BudgetsService,
    private readonly schedules: SchedulesService,
    private readonly goals: GoalsService,
    private readonly debts: DebtsService,
    private readonly llm: LlmClient,
    private readonly cache: FinanceCache,
    private readonly queue: FinanceQueueClient,
  ) {}

  async overview(userId: string): Promise<Overview> {
    const cached = await this.cache.get(userId, 'overview');
    if (cached) return JSON.parse(cached) as Overview;
    const value = await this.computeOverview(userId);
    await this.cache.set(userId, 'overview', JSON.stringify(value), 60);
    return value;
  }

  async forecast(userId: string, days: number): Promise<Forecast> {
    if (!isHorizon(days)) throw new BadRequestException('days must be 7, 15, 30, 60 or 90');
    const stored = await this.latestForecast(userId, days);
    if (stored) return stored;
    return this.computeForecast(userId, days);
  }

  async safeToSpend(userId: string): Promise<SafeToSpend> {
    const loaded = await this.load(userId);
    return buildSafeToSpend({
      today: loaded.today,
      balance: loaded.balance,
      schedules: loaded.schedules,
      goals: loaded.goals,
      profile: loaded.profile,
    });
  }

  async health(userId: string) {
    const loaded = await this.load(userId);
    const overview = buildOverview(loaded.overviewInput);
    const months = monthBuckets(loaded.transactions, loaded.today, 6);
    const typical = months.filter((month) => month.expense > 0);
    const typicalMonthlyExpense = typical.length === 0
      ? 0
      : Math.round(typical.reduce((sum, month) => sum + month.expense, 0) / typical.length);
    return buildHealth({
      months,
      budgets: overview.budgets,
      recurringExpense: overview.recurringExpense,
      emergencyReserve: loaded.profile.emergencyReserve,
      typicalMonthlyExpense,
    });
  }

  async anomalies(userId: string): Promise<{ items: Anomaly[] }> {
    const loaded = await this.load(userId);
    return { items: detectAnomalies(loaded.transactions, loaded.today) };
  }

  async insights(userId: string) {
    const stored = await this.latestInsights(userId);
    if (stored.length > 0) return { items: stored };
    const drafts = await this.draftInsights(userId);
    return { items: drafts.map((draft, index) => ({ id: `draft-${index}`, ...draft })) };
  }

  async profile(userId: string) {
    const profile = await this.readProfile(userId);
    return {
      emergencyReserve: profile.emergencyReserve,
      monthlyDiscretionaryLimit: profile.monthlyDiscretionaryLimit,
      essentialCategories: profile.essentialCategories,
    };
  }

  async saveProfile(userId: string, input: { emergencyReserve: number; monthlyDiscretionaryLimit?: number | null; essentialCategories?: string[] }) {
    const { error } = await this.supabase.from('financial_profiles').upsert({
      user_id: userId,
      emergency_reserve: input.emergencyReserve,
      monthly_discretionary_limit: input.monthlyDiscretionaryLimit ?? null,
      essential_categories: input.essentialCategories ?? defaultEssentials,
      updated_at: new Date().toISOString(),
    });
    if (missingTable(error)) {
      throw new BadRequestException('Run the latest supabase/schema.sql in Supabase before saving a reserve.');
    }
    if (error) throw new BadRequestException(error.message);
    await this.cache.invalidate(userId);
    return this.profile(userId);
  }

  async simulate(userId: string, input: { kind: ScenarioKind; amount: number; months?: number }) {
    await this.limit(userId, 'simulate', 20);
    const loaded = await this.load(userId);
    const forecast = buildForecast({
      today: loaded.today,
      days: 90,
      balance: loaded.balance,
      transactions: loaded.transactions,
      schedules: loaded.schedules,
    });
    const result = applyScenario(forecast, input);
    const id = await this.insertScenario(userId, input, result);
    return { id, ...result };
  }

  async chat(userId: string, message: string, language: AdvisorLanguage, conversationId?: string) {
    await this.limit(userId, 'chat', 30);
    const graph = buildAdvisorGraph(this.tools(userId), async (state) => {
      const raw = await this.llm.chat(
        'You explain figures that were already calculated. Reply as JSON {"reply":"..."} in the requested language. Use only rupee amounts present in the figures. Do not invent numbers. Do not give instructions to move money.',
        [{ role: 'user', content: JSON.stringify({ language: state.language, message: state.message, figures: state.toolResults }) }],
      );
      try {
        const parsed = JSON.parse(raw) as { reply?: string };
        if (parsed.reply) return parsed.reply;
      } catch {
        return raw;
      }
      return raw;
    });
    let result: { reply: string; toolResults?: { name: string }[] };
    try {
      result = await graph.invoke({
        userId,
        language,
        message,
        intent: 'summary',
        toolResults: [],
        toolCalls: 0,
        draft: '',
        attempts: 0,
        validationErrors: [],
        reply: '',
      });
    } catch (caught) {
      this.logger.warn(`Advisor fallback for ${userId}`);
      result = {
        reply: deterministicReply({ language, intent: 'summary', toolResults: [] }),
      };
      if (caught instanceof HttpException) throw caught;
    }
    const id = await this.saveTurn(userId, conversationId, message, result.reply, language);
    await this.recordRun(userId, id, result.toolResults ?? []);
    return { conversationId: id, reply: result.reply, language };
  }

  async conversation(userId: string, id: string) {
    const { data, error } = await this.supabase
      .from('ai_conversations')
      .select('id, title, updated_at')
      .eq('id', id)
      .eq('user_id', userId)
      .maybeSingle();
    if (missingTable(error)) throw new NotFoundException('Conversation not found');
    if (error) throw new BadRequestException(error.message);
    if (!data) throw new NotFoundException('Conversation not found');
    const messages = await this.supabase
      .from('ai_messages')
      .select('id, role, body, language, created_at')
      .eq('conversation_id', id)
      .eq('user_id', userId)
      .order('created_at', { ascending: true });
    if (messages.error) throw new BadRequestException(messages.error.message);
    return {
      id: data.id,
      title: data.title,
      updatedAt: data.updated_at,
      messages: (messages.data ?? []).map((row) => ({
        id: row.id,
        role: row.role,
        body: row.body,
        language: row.language,
        createdAt: row.created_at,
      })),
    };
  }

  async conversations(userId: string) {
    const { data, error } = await this.supabase
      .from('ai_conversations')
      .select('id, title, updated_at')
      .eq('user_id', userId)
      .order('updated_at', { ascending: false })
      .limit(50);
    if (missingTable(error)) return { items: [] };
    if (error) throw new BadRequestException(error.message);
    return {
      items: (data ?? []).map((row) => ({ id: row.id, title: row.title, updatedAt: row.updated_at })),
    };
  }

  async feedback(userId: string, input: { rating: 'up' | 'down'; insightId?: string; messageId?: string }) {
    const { error } = await this.supabase.from('financial_feedback').insert({
      user_id: userId,
      rating: input.rating,
      insight_id: input.insightId ?? null,
      message_id: input.messageId ?? null,
    });
    if (missingTable(error)) {
      throw new BadRequestException('Run the latest supabase/schema.sql in Supabase before saving feedback.');
    }
    if (error) throw new BadRequestException(error.message);
    return { saved: true };
  }

  async enqueue(userId: string, queue: FinanceQueue, days?: number): Promise<FinanceJobView> {
    if (days != null && !isHorizon(days)) throw new BadRequestException('days must be 7, 15, 30, 60 or 90');
    const key = `${queue}:${days ?? 'na'}`;
    const existing = await this.findOpenJob(userId, key);
    if (existing) return existing;
    const inserted = await this.insertJob(userId, queue, key);
    if (!inserted.id) {
      await this.run(queue, userId, days);
      return { id: null, queue, status: 'completed', error: null, persisted: false };
    }
    const queued = await this.queue.enqueue(queue, { jobId: inserted.id, userId, days });
    if (!queued) {
      await this.run(queue, userId, days);
      await this.finishJob(inserted.id, userId, 'completed', null);
      return { id: inserted.id, queue, status: 'completed', error: null, persisted: true };
    }
    return { id: inserted.id, queue, status: 'queued', error: null, persisted: true };
  }

  async job(userId: string, id: string): Promise<FinanceJobView> {
    const { data, error } = await this.supabase
      .from('finance_jobs')
      .select('id, queue, status, error')
      .eq('id', id)
      .eq('user_id', userId)
      .maybeSingle();
    if (error || !data) throw new NotFoundException('Job not found');
    return {
      id: data.id,
      queue: data.queue as FinanceQueue,
      status: data.status,
      error: data.error,
      persisted: true,
    };
  }

  async run(queue: FinanceQueue, userId: string, days?: number): Promise<void> {
    this.logger.log(`Running ${queue} for ${userId}`);
    if (queue === 'cash-flow-forecast' || queue === 'scheduled-reports') {
      await this.computeForecast(userId, days && isHorizon(days) ? days : 30, true);
    }
    if (queue === 'financial-analysis') {
      await this.cache.invalidate(userId);
      await this.overview(userId);
    }
    if (queue === 'ai-insights' || queue === 'scheduled-reports') {
      await this.storeInsights(userId, await this.draftInsights(userId));
    }
    if (queue === 'spending-analysis' || queue === 'scheduled-reports') {
      const items = (await this.anomalies(userId)).items;
      await this.storeAnomalies(userId, items);
    }
  }

  async processQueued(queue: FinanceQueue, jobId: string, userId: string, days?: number): Promise<void> {
    const owned = await this.job(userId, jobId);
    if (owned.status === 'completed') return;
    await this.markJob(jobId, userId, 'running', null);
    try {
      await this.run(queue, userId, days);
      await this.finishJob(jobId, userId, 'completed', null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Job failed';
      await this.finishJob(jobId, userId, 'failed', message.slice(0, 300));
      throw caught;
    }
  }

  private tools(userId: string): AdvisorTools {
    return {
      get_financial_summary: () => this.overview(userId),
      get_spending_breakdown: async () => ({ categories: (await this.overview(userId)).categories }),
      get_budget_status: async () => ({ budgets: (await this.overview(userId)).budgets }),
      get_upcoming_obligations: async () => ({ upcoming: (await this.overview(userId)).upcoming }),
      get_cash_flow_forecast: (days) => this.forecast(userId, days),
      calculate_safe_to_spend: () => this.safeToSpend(userId),
      simulate_purchase: async (amount) => this.simulate(userId, { kind: 'purchase', amount }),
      calculate_savings_plan: async () => ({ goals: (await this.overview(userId)).goals }),
      detect_spending_anomalies: () => this.anomalies(userId),
      get_financial_health_score: () => this.health(userId),
    };
  }

  private async limit(userId: string, action: string, max: number) {
    const allowed = await this.cache.allow(userId, action, max, 60 * 60);
    if (!allowed) throw new HttpException('Too many financial questions. Try again in a little while.', 429);
  }

  private async computeOverview(userId: string): Promise<Overview> {
    const loaded = await this.load(userId);
    return buildOverview(loaded.overviewInput);
  }

  private async computeForecast(userId: string, days: number, force = false): Promise<Forecast> {
    if (!force) {
      const stored = await this.latestForecast(userId, days);
      if (stored) return stored;
    }
    const loaded = await this.load(userId);
    const forecast = buildForecast({
      today: loaded.today,
      days,
      balance: loaded.balance,
      transactions: loaded.transactions,
      schedules: loaded.schedules,
    });
    await this.storeForecast(userId, forecast);
    return forecast;
  }

  private async draftInsights(userId: string): Promise<InsightDraft[]> {
    const [overview, health, anomaly, safe] = await Promise.all([
      this.overview(userId),
      this.health(userId),
      this.anomalies(userId),
      this.safeToSpend(userId),
    ]);
    return buildInsights(overview, health, anomaly.items, safe);
  }

  private async load(userId: string) {
    const today = todayInIndia();
    const month = today.slice(0, 7);
    const [summary, budgetRows, scheduleRows, goalRows, debtRows, transactions, profile] = await Promise.all([
      this.summary.forMonth(userId, month),
      this.budgets.list(userId, month),
      this.schedules.list(userId),
      this.goals.list(userId),
      this.debts.list(userId),
      this.transactions(userId),
      this.readProfile(userId),
    ]);
    const schedules = scheduleRows.map((item) => ({
      id: item.id,
      amount: item.amount,
      kind: item.kind,
      categoryName: item.categoryName,
      note: item.note,
      repeat: item.repeat,
      nextOn: item.nextOn,
      dayOfMonth: item.dayOfMonth,
    }));
    const goals = goalRows.map((item) => ({
      id: item.id,
      name: item.name,
      targetAmount: item.targetAmount,
      saved: item.saved,
      targetDate: item.targetDate,
    }));
    return {
      today,
      balance: summary.balance,
      transactions,
      schedules,
      goals,
      profile,
      overviewInput: {
        today,
        balance: summary.balance,
        monthIncome: summary.monthIncome,
        monthExpense: summary.monthExpense,
        categories: summary.categories,
        transactions,
        budgets: budgetRows.map((item) => ({
          categoryId: item.categoryId,
          categoryName: item.categoryName,
          limitAmount: item.limitAmount,
        })),
        schedules,
        goals,
        people: debtRows.people.map((person) => ({ name: person.name, balance: person.balance })),
      },
    };
  }

  private async transactions(userId: string): Promise<LedgerTxn[]> {
    const rows = await allRows<TxnRow>((from, to) =>
      this.supabase
        .from('transactions')
        .select('id, amount, kind, occurred_on, category_id, account_id, note, category:categories(name)')
        .eq('user_id', userId)
        .order('id')
        .range(from, to),
    );
    return rows.map((row) => ({
      id: row.id,
      amount: row.amount,
      kind: row.kind,
      occurredOn: row.occurred_on,
      categoryId: row.category_id,
      categoryName: categoryName(row.category),
      accountId: row.account_id,
      note: row.note,
    }));
  }

  private async readProfile(userId: string): Promise<ProfileInput> {
    const { data, error } = await this.supabase
      .from('financial_profiles')
      .select('emergency_reserve, monthly_discretionary_limit, essential_categories')
      .eq('user_id', userId)
      .maybeSingle();
    if (error || !data) {
      return { emergencyReserve: 0, monthlyDiscretionaryLimit: null, essentialCategories: defaultEssentials };
    }
    const categories = Array.isArray(data.essential_categories)
      ? data.essential_categories.filter((item): item is string => typeof item === 'string')
      : defaultEssentials;
    return {
      emergencyReserve: data.emergency_reserve ?? 0,
      monthlyDiscretionaryLimit: data.monthly_discretionary_limit,
      essentialCategories: categories.length > 0 ? categories : defaultEssentials,
    };
  }

  private async latestForecast(userId: string, days: number): Promise<Forecast | null> {
    const { data, error } = await this.supabase
      .from('financial_forecasts')
      .select('id, horizon_days, assumptions, generated_at')
      .eq('user_id', userId)
      .eq('horizon_days', days)
      .order('generated_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error || !data) return null;
    const age = Date.now() - Date.parse(data.generated_at);
    if (age > 6 * 60 * 60 * 1000) return null;
    const points = await this.supabase
      .from('forecast_daily_points')
      .select('date, projected_balance, confirmed_in, confirmed_out, estimated_in, estimated_out')
      .eq('forecast_id', data.id)
      .eq('user_id', userId)
      .order('date', { ascending: true });
    if (points.error || !points.data) return null;
    const rows = points.data;
    const sum = (key: 'confirmed_in' | 'confirmed_out' | 'estimated_in' | 'estimated_out') =>
      rows.reduce((total, row) => total + row[key], 0);
    return {
      days,
      startBalance: rows[0] ? rows[0].projected_balance - rows[0].confirmed_in + rows[0].confirmed_out + rows[0].estimated_out : 0,
      endBalance: rows.at(-1)?.projected_balance ?? 0,
      confirmedIncome: sum('confirmed_in'),
      confirmedExpense: sum('confirmed_out'),
      estimatedIncome: sum('estimated_in'),
      estimatedExpense: sum('estimated_out'),
      assumptions: Array.isArray(data.assumptions) ? data.assumptions.filter((item): item is string => typeof item === 'string') : [],
      points: rows.map((row) => ({
        date: row.date,
        projectedBalance: row.projected_balance,
        confirmedIn: row.confirmed_in,
        confirmedOut: row.confirmed_out,
        estimatedIn: row.estimated_in,
        estimatedOut: row.estimated_out,
      })),
    };
  }

  private async storeForecast(userId: string, forecast: Forecast): Promise<void> {
    const { data, error } = await this.supabase
      .from('financial_forecasts')
      .insert({
        user_id: userId,
        horizon_days: forecast.days,
        assumptions: forecast.assumptions,
      })
      .select('id')
      .maybeSingle();
    if (error || !data) return;
    if (forecast.points.length === 0) return;
    await this.supabase.from('forecast_daily_points').insert(forecast.points.map((point) => ({
      user_id: userId,
      forecast_id: data.id,
      date: point.date,
      projected_balance: point.projectedBalance,
      confirmed_in: point.confirmedIn,
      confirmed_out: point.confirmedOut,
      estimated_in: point.estimatedIn,
      estimated_out: point.estimatedOut,
    })));
  }

  private async latestInsights(userId: string) {
    const { data, error } = await this.supabase
      .from('financial_insights')
      .select('id, title, body, created_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(8);
    if (error || !data || data.length === 0) return [];
    const ids = data.map((row) => row.id);
    const evidence = await this.supabase
      .from('insight_evidence')
      .select('insight_id, label, amount')
      .eq('user_id', userId)
      .in('insight_id', ids);
    return data.map((row) => ({
      id: row.id,
      title: row.title,
      body: row.body,
      evidence: (evidence.data ?? []).filter((item) => item.insight_id === row.id).map((item) => ({
        label: item.label,
        amount: item.amount,
      })),
    }));
  }

  private async storeInsights(userId: string, drafts: InsightDraft[]): Promise<void> {
    for (const draft of drafts) {
      const { data, error } = await this.supabase
        .from('financial_insights')
        .insert({ user_id: userId, title: draft.title, body: draft.body })
        .select('id')
        .maybeSingle();
      if (error || !data) return;
      if (draft.evidence.length === 0) continue;
      await this.supabase.from('insight_evidence').insert(draft.evidence.map((item) => ({
        user_id: userId,
        insight_id: data.id,
        label: item.label,
        amount: item.amount,
      })));
    }
  }

  private async storeAnomalies(userId: string, items: Anomaly[]): Promise<void> {
    if (items.length === 0) return;
    const { error } = await this.supabase.from('spending_anomalies').upsert(items.map((item) => ({
      user_id: userId,
      fingerprint: item.id,
      kind: item.kind,
      severity: item.severity,
      reason: item.reason,
      amount: item.amount,
      occurred_on: item.occurredOn,
      category_name: item.categoryName,
      transaction_id: item.transactionId,
    })), { onConflict: 'user_id,fingerprint' });
    if (error && !missingTable(error)) this.logger.warn(`Anomaly store skipped for ${userId}`);
  }

  private async insertScenario(userId: string, input: { kind: string; amount: number; months?: number }, result: unknown): Promise<string | null> {
    const { data, error } = await this.supabase
      .from('financial_scenarios')
      .insert({ user_id: userId, kind: input.kind, input, result })
      .select('id')
      .maybeSingle();
    if (error || !data) return null;
    return data.id;
  }

  private async recordRun(userId: string, conversationId: string | null, tools: { name: string }[]): Promise<void> {
    const { data, error } = await this.supabase
      .from('agent_runs')
      .insert({ user_id: userId, conversation_id: conversationId, status: 'completed' })
      .select('id')
      .maybeSingle();
    if (error || !data || tools.length === 0) return;
    await this.supabase.from('agent_tool_calls').insert(tools.map((tool) => ({
      user_id: userId,
      run_id: data.id,
      tool_name: tool.name,
      status: 'ok',
    })));
  }

  private async saveTurn(userId: string, conversationId: string | undefined, message: string, reply: string, language: string): Promise<string | null> {
    let id = conversationId ?? null;
    if (!id) {
      const created = await this.supabase
        .from('ai_conversations')
        .insert({ user_id: userId, title: message.slice(0, 80) })
        .select('id')
        .maybeSingle();
      if (created.error || !created.data) return null;
      id = created.data.id;
    } else {
      const owned = await this.supabase
        .from('ai_conversations')
        .select('id')
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle();
      if (!owned.data) throw new NotFoundException('Conversation not found');
      await this.supabase.from('ai_conversations').update({ updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', userId);
    }
    const { error } = await this.supabase.from('ai_messages').insert([
      { user_id: userId, conversation_id: id, role: 'user', body: message, language },
      { user_id: userId, conversation_id: id, role: 'assistant', body: reply, language },
    ]);
    if (error) return null;
    return id;
  }

  private async findOpenJob(userId: string, key: string): Promise<FinanceJobView | null> {
    const { data, error } = await this.supabase
      .from('finance_jobs')
      .select('id, queue, status, error')
      .eq('user_id', userId)
      .eq('idempotency_key', key)
      .in('status', ['queued', 'running'])
      .maybeSingle();
    if (error || !data) return null;
    return { id: data.id, queue: data.queue as FinanceQueue, status: data.status, error: data.error, persisted: true };
  }

  private async insertJob(userId: string, queue: FinanceQueue, key: string): Promise<{ id: string | null }> {
    const { data, error } = await this.supabase
      .from('finance_jobs')
      .insert({ user_id: userId, queue, status: 'queued', idempotency_key: key })
      .select('id')
      .maybeSingle();
    if (missingTable(error)) return { id: null };
    if (error || !data) return { id: null };
    return { id: data.id };
  }

  private async markJob(id: string, userId: string, status: string, error: string | null) {
    await this.supabase.from('finance_jobs').update({ status, error, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', userId);
  }

  private async finishJob(id: string, userId: string, status: 'completed' | 'failed', error: string | null) {
    await this.supabase.from('finance_jobs').update({
      status,
      error,
      idempotency_key: id,
      updated_at: new Date().toISOString(),
    }).eq('id', id).eq('user_id', userId);
  }
}
