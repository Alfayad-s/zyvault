import { Annotation, END, START, StateGraph } from '@langchain/langgraph';
import { z } from 'zod';
import { rupees } from './engine.js';

export const advisorLanguages = ['en', 'ml', 'hinglish'] as const;
export type AdvisorLanguage = (typeof advisorLanguages)[number];

export const toolNames = [
  'get_financial_summary',
  'get_spending_breakdown',
  'get_budget_status',
  'get_upcoming_obligations',
  'get_cash_flow_forecast',
  'calculate_safe_to_spend',
  'simulate_purchase',
  'calculate_savings_plan',
  'detect_spending_anomalies',
  'get_financial_health_score',
] as const;

export type ToolName = (typeof toolNames)[number];

/** Tool arguments never include a user id. The signed-in user comes from the graph state. */
export const toolArguments = z.object({
  days: z.union([z.literal(7), z.literal(15), z.literal(30), z.literal(60), z.literal(90)]).optional(),
  amount: z.number().int().positive().optional(),
  kind: z.enum(['purchase', 'extra_monthly', 'income_change', 'savings_target', 'emergency', 'emi']).optional(),
  months: z.number().int().positive().max(360).optional(),
}).strict();

export type AdvisorTools = {
  get_financial_summary: () => Promise<unknown>;
  get_spending_breakdown: () => Promise<unknown>;
  get_budget_status: () => Promise<unknown>;
  get_upcoming_obligations: () => Promise<unknown>;
  get_cash_flow_forecast: (days: 7 | 15 | 30 | 60 | 90) => Promise<unknown>;
  calculate_safe_to_spend: () => Promise<unknown>;
  simulate_purchase: (amount: number) => Promise<unknown>;
  calculate_savings_plan: () => Promise<unknown>;
  detect_spending_anomalies: () => Promise<unknown>;
  get_financial_health_score: () => Promise<unknown>;
};

const intents = ['greeting', 'forecast', 'safe', 'health', 'anomaly', 'simulate', 'savings', 'category', 'summary'] as const;
type Intent = (typeof intents)[number];

const GraphState = Annotation.Root({
  userId: Annotation<string>,
  language: Annotation<AdvisorLanguage>,
  message: Annotation<string>,
  intent: Annotation<Intent>,
  toolResults: Annotation<{ name: ToolName; result: unknown }[]>({
    reducer: (left, right) => left.concat(right),
    default: () => [],
  }),
  toolCalls: Annotation<number>({
    reducer: (_left, right) => right,
    default: () => 0,
  }),
  draft: Annotation<string>,
  attempts: Annotation<number>,
  validationErrors: Annotation<string[]>({
    reducer: (_left, right) => right,
    default: () => [],
  }),
  reply: Annotation<string>,
});

export type AdvisorState = typeof GraphState.State;

const maxToolCalls = 4;
const maxAttempts = 2;

/** A question about the figures, not a request to save a line. */
export function asksAboutMoney(message: string): boolean {
  if (looksLikeARecord(message)) return false;
  const intent = classifyIntent(message);
  if (intent === 'greeting') return false;
  if (intent !== 'summary') return true;
  return /\b(how much|how many|what did|what is left|what's left|can i|could i|why|which|balance|safe)\b/i.test(message)
    || message.includes('?');
}

function looksLikeARecord(message: string): boolean {
  if (/\b(how|what|why|which|can i|could i|should i)\b/i.test(message) || message.includes('?')) return false;
  return /\b(add|save|log|spent|paid|pay|record|set|put|lend|schedule|remind|bought)\b/i.test(message)
    || /^\s*\d/.test(message);
}

export function classifyIntent(message: string): Intent {
  const text = message.trim().toLowerCase();
  if (/^(hi|hello|hey|thanks|thank you|namaskaram|നമസ്കാരം)\b/.test(text)) return 'greeting';
  if (/what if|what happens if|simulate|വാങ്ങിയാൽ/.test(text)) return 'simulate';
  if (/afford|safe to spend|can i spend|kitna spend/.test(text)) return 'safe';
  if (/anomal|unusual|duplicate|suspicious/.test(text)) return 'anomaly';
  if (/health|score|financial health/.test(text)) return 'health';
  if (/save in|savings goal|how much can i save|ലാഭിക്ക/.test(text)) return 'savings';
  if (/which category|most of my money|category consumes|ഏത് കാറ്റഗറി/.test(text)) return 'category';
  if (/forecast|next month|how much will i have|അടുത്ത മാസം|kitna bachega/.test(text)) return 'forecast';
  return 'summary';
}

function toolsFor(intent: Intent): ToolName[] {
  switch (intent) {
    case 'greeting':
      return [];
    case 'forecast':
      return ['get_cash_flow_forecast'];
    case 'safe':
      return ['calculate_safe_to_spend', 'get_upcoming_obligations'];
    case 'health':
      return ['get_financial_health_score'];
    case 'anomaly':
      return ['detect_spending_anomalies'];
    case 'simulate':
      return ['simulate_purchase', 'get_cash_flow_forecast'];
    case 'savings':
      return ['calculate_savings_plan', 'get_financial_summary'];
    case 'category':
      return ['get_spending_breakdown', 'get_budget_status'];
    default:
      return ['get_financial_summary', 'get_spending_breakdown'];
  }
}

function collectNumbers(value: unknown, into: Set<number>) {
  if (typeof value === 'number' && Number.isFinite(value)) into.add(Math.trunc(value));
  else if (Array.isArray(value)) value.forEach((item) => collectNumbers(item, into));
  else if (value && typeof value === 'object') Object.values(value).forEach((item) => collectNumbers(item, into));
}

export function amountsOutsidePayload(reply: string, payload: unknown): string[] {
  const allowed = new Set<number>();
  collectNumbers(payload, allowed);
  const errors: string[] = [];
  const pattern = /₹\s*(-?\d[\d,]*(?:\.\d{1,2})?)/g;
  for (const match of reply.matchAll(pattern)) {
    const raw = match[1].replace(/,/g, '');
    const [major, minor = '0'] = raw.replace('-', '').split('.');
    const paise = Number(major) * 100 + Number(minor.padEnd(2, '0').slice(0, 2));
    const signed = raw.startsWith('-') ? -paise : paise;
    if (!allowed.has(signed) && !allowed.has(Math.abs(signed))) {
      errors.push(`${match[0]} is not in the calculated figures`);
    }
  }
  return errors;
}

function sentence(language: AdvisorLanguage, english: string, malayalam: string, hinglish: string): string {
  if (language === 'ml') return malayalam;
  if (language === 'hinglish') return hinglish;
  return english;
}

export function deterministicReply(state: Pick<AdvisorState, 'language' | 'intent' | 'toolResults'>): string {
  const first = state.toolResults[0]?.result as Record<string, number> | undefined;
  if (state.intent === 'greeting' || !first) {
    return sentence(
      state.language,
      'Ask about this month, what you can spend, or a purchase you are considering.',
      'ഈ മാസം, ചെലവഴിക്കാവുന്ന തുക, അല്ലെങ്കിൽ ഒരു വാങ്ങൽ എന്നിവയെക്കുറിച്ച് ചോദിക്കാം.',
      'Is mahine, safe spend, ya kisi purchase ke baare mein pooch sakte ho.',
    );
  }
  if (typeof first.safeToSpend === 'number') {
    return sentence(
      state.language,
      `You can spend ${rupees(first.safeToSpend)} by month end, about ${rupees(first.daily)} a day. Estimated income is not included.`,
      `മാസാവസാനം വരെ ${rupees(first.safeToSpend)} ചെലവഴിക്കാം, ദിവസം ഏകദേശം ${rupees(first.daily)}. കണക്കാക്കിയ വരുമാനം ഉൾപ്പെടുത്തിയിട്ടില്ല.`,
      `Month end tak ${rupees(first.safeToSpend)} spend kar sakte ho, din ka about ${rupees(first.daily)}. Estimated income include nahi hai.`,
    );
  }
  if (typeof first.endBalance === 'number' && typeof first.scenarioEnd !== 'number') {
    return sentence(
      state.language,
      `The ${first.days}-day projection ends at ${rupees(first.endBalance)}. Confirmed plans are included. Estimated income is shown separately and is not treated as money you already have.`,
      `${first.days} ദിവസത്തെ കണക്ക് ${rupees(first.endBalance)} ൽ അവസാനിക്കുന്നു. ഉറപ്പുള്ള പ്ലാനുകൾ ഉൾപ്പെടുത്തി. കണക്കാക്കിയ വരുമാനം കയ്യിലുള്ള പണമായി എടുത്തിട്ടില്ല.`,
      `${first.days} din ka projection ${rupees(first.endBalance)} pe khatam hota hai. Confirmed plans include hain. Estimated income ko guaranteed nahi maana.`,
    );
  }
  if (typeof first.scenarioEnd === 'number') {
    return sentence(
      state.language,
      `After that change the forecast ends at ${rupees(first.scenarioEnd)}, which is ${rupees(first.delta)} compared with leaving things as they are. Nothing was saved to your accounts.`,
      `ആ മാറ്റത്തിന് ശേഷം കണക്ക് ${rupees(first.scenarioEnd)} ൽ എത്തും. ഇപ്പോഴുള്ളതിൽ നിന്ന് വ്യത്യാസം ${rupees(first.delta)}. അക്കൗണ്ടിൽ ഒന്നും സേവ് ചെയ്തിട്ടില്ല.`,
      `Us change ke baad forecast ${rupees(first.scenarioEnd)} pe khatam hota hai, farq ${rupees(first.delta)}. Account mein kuch save nahi hua.`,
    );
  }
  if (typeof first.score === 'number' || first.score === null) {
    const score = typeof first.score === 'number' ? String(first.score) : 'unavailable';
    return sentence(
      state.language,
      `Your financial health score is ${score}. Each part uses a fixed weight and is left blank when the figures are missing.`,
      `സാമ്പത്തിക ആരോഗ്യ സ്കോർ ${score} ആണ്. ഓരോ ഭാഗത്തിനും നിശ്ചിത ഭാരമുണ്ട്. കണക്ക് ഇല്ലെങ്കിൽ ആ ഭാഗം ഒഴിവാക്കും.`,
      `Financial health score ${score} hai. Har hissa ka fixed weight hai. Data na ho to woh hissa blank rehta hai.`,
    );
  }
  if (typeof first.monthExpense === 'number') {
    return sentence(
      state.language,
      `This month you received ${rupees(first.monthIncome)} and spent ${rupees(first.monthExpense)}. Balance is ${rupees(first.balance)}.`,
      `ഈ മാസം വരുമാനം ${rupees(first.monthIncome)}, ചെലവ് ${rupees(first.monthExpense)}. ബാലൻസ് ${rupees(first.balance)}.`,
      `Is mahine income ${rupees(first.monthIncome)} aur spend ${rupees(first.monthExpense)} hai. Balance ${rupees(first.balance)} hai.`,
    );
  }
  return sentence(
    state.language,
    'Here are the figures from your accounts. I can explain a forecast, a safe-to-spend amount, or a what-if.',
    'നിങ്ങളുടെ അക്കൗണ്ടിലെ കണക്കുകൾ ഇതാ. പ്രവചനം, ചെലവഴിക്കാവുന്ന തുക, അല്ലെങ്കിൽ ഒരു എന്താണെങ്കിൽ എന്നിവ ചോദിക്കാം.',
    'Aapke accounts ke figures yeh rahe. Forecast, safe spend, ya what-if pooch sakte ho.',
  );
}

export function buildAdvisorGraph(tools: AdvisorTools, explain?: (state: AdvisorState) => Promise<string>) {
  const graph = new StateGraph(GraphState)
    .addNode('classify', (state: AdvisorState) => ({
      intent: classifyIntent(state.message),
      toolCalls: 0,
      attempts: 0,
    }))
    .addNode('retrieve', async (state: AdvisorState) => {
      const names = toolsFor(state.intent).slice(0, maxToolCalls);
      const toolResults: { name: ToolName; result: unknown }[] = [];
      for (const name of names) {
        if (state.toolCalls + toolResults.length >= maxToolCalls) break;
        const parsed = toolArguments.parse({});
        if (name === 'get_cash_flow_forecast') toolResults.push({ name, result: await tools.get_cash_flow_forecast(parsed.days ?? 30) });
        else if (name === 'simulate_purchase') {
          const amount = parsed.amount ?? amountFromMessage(state.message) ?? 0;
          toolResults.push({ name, result: amount > 0 ? await tools.simulate_purchase(amount) : { note: 'No amount was given.' } });
        }
        else if (name === 'get_financial_summary') toolResults.push({ name, result: await tools.get_financial_summary() });
        else if (name === 'get_spending_breakdown') toolResults.push({ name, result: await tools.get_spending_breakdown() });
        else if (name === 'get_budget_status') toolResults.push({ name, result: await tools.get_budget_status() });
        else if (name === 'get_upcoming_obligations') toolResults.push({ name, result: await tools.get_upcoming_obligations() });
        else if (name === 'calculate_safe_to_spend') toolResults.push({ name, result: await tools.calculate_safe_to_spend() });
        else if (name === 'calculate_savings_plan') toolResults.push({ name, result: await tools.calculate_savings_plan() });
        else if (name === 'detect_spending_anomalies') toolResults.push({ name, result: await tools.detect_spending_anomalies() });
        else toolResults.push({ name, result: await tools.get_financial_health_score() });
      }
      return { toolResults, toolCalls: toolResults.length };
    })
    .addNode('explain', async (state: AdvisorState) => {
      const fallback = deterministicReply(state);
      if (!explain || state.attempts > 0) return { draft: fallback };
      try {
        const draft = await explain(state);
        return { draft: draft.trim() || fallback };
      } catch {
        return { draft: fallback };
      }
    })
    .addNode('validate', (state: AdvisorState) => {
      const errors = amountsOutsidePayload(state.draft, state.toolResults);
      if (errors.length === 0) return { validationErrors: [], reply: state.draft };
      if (state.attempts + 1 >= maxAttempts) {
        const draft = deterministicReply(state);
        return { validationErrors: errors, attempts: state.attempts + 1, draft, reply: draft };
      }
      return { validationErrors: errors, attempts: state.attempts + 1 };
    })
    .addNode('format', (state: AdvisorState) => ({
      reply: state.reply || state.draft || deterministicReply(state),
    }))
    .addEdge(START, 'classify')
    .addConditionalEdges('classify', (state: AdvisorState) => (state.intent === 'greeting' ? 'format' : 'retrieve'))
    .addEdge('retrieve', 'explain')
    .addEdge('explain', 'validate')
    .addConditionalEdges('validate', (state: AdvisorState) => (
      state.validationErrors.length > 0 && state.attempts < maxAttempts ? 'explain' : 'format'
    ))
    .addEdge('format', END);
  return graph.compile();
}

function amountFromMessage(message: string): number | null {
  const match = message.replace(/,/g, '').match(/(\d+(?:\.\d{1,2})?)/);
  if (!match) return null;
  const [major, minor = '0'] = match[1].split('.');
  return Number(major) * 100 + Number(minor.padEnd(2, '0').slice(0, 2));
}
