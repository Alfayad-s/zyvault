import { describe, expect, it } from 'vitest';
import { amountsOutsidePayload, asksAboutMoney, buildAdvisorGraph, classifyIntent, toolArguments, type AdvisorTools } from './advisor.graph.js';

const tools: AdvisorTools = {
  get_financial_summary: async () => ({ balance: 50000, monthIncome: 80000, monthExpense: 30000 }),
  get_spending_breakdown: async () => ({ categories: [] }),
  get_budget_status: async () => ({ budgets: [] }),
  get_upcoming_obligations: async () => ({ upcoming: [] }),
  get_cash_flow_forecast: async () => ({ days: 30, endBalance: 40000, estimatedIncome: 0 }),
  calculate_safe_to_spend: async () => ({ safeToSpend: 15000, daily: 500 }),
  simulate_purchase: async (amount: number) => ({ scenarioEnd: 20000, delta: -amount, amount }),
  calculate_savings_plan: async () => ({ goals: [] }),
  detect_spending_anomalies: async () => ({ items: [] }),
  get_financial_health_score: async () => ({ score: 70 }),
};

describe('advisor graph', () => {
  it('rejects a user id on tool arguments', () => {
    expect(toolArguments.safeParse({ userId: 'user-1' }).success).toBe(false);
  });

  it('answers a spending question from the tools, in the selected language', async () => {
    const graph = buildAdvisorGraph(tools);
    const result = await graph.invoke({
      userId: 'user-1',
      language: 'ml',
      message: 'How much did I spend this month?',
      intent: 'summary',
      toolResults: [],
      toolCalls: 0,
      draft: '',
      attempts: 0,
      validationErrors: [],
      reply: '',
    });
    expect(result.reply).toContain('₹300.00');
    expect(result.reply).toContain('ചെലവ്');
    expect(classifyIntent('can I afford a phone')).toBe('safe');
    expect(asksAboutMoney('how much did I spend?')).toBe(true);
    expect(asksAboutMoney('450 pizza')).toBe(false);
  });

  it('replaces a model amount that was not calculated', async () => {
    const graph = buildAdvisorGraph(tools, async () => 'You can spend ₹9999.00 today.');
    const result = await graph.invoke({
      userId: 'user-1',
      language: 'en',
      message: 'How much can I spend?',
      intent: 'safe',
      toolResults: [],
      toolCalls: 0,
      draft: '',
      attempts: 0,
      validationErrors: [],
      reply: '',
    });
    expect(result.reply).toContain('₹150.00');
    expect(result.reply).not.toContain('9999');
    expect(amountsOutsidePayload('₹9999.00', [{ result: { safeToSpend: 15000 } }])).toHaveLength(1);
  });
});
