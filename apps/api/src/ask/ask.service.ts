import {
  Inject,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';
import { AccountsService, type Account } from '../accounts/accounts.service.js';
import { accountLabel, matchAccount } from '../agent/ai-agent.service.js';
import { BudgetsService, type Budget } from '../budgets/budgets.service.js';
import { LlmClient } from '../agent/llm.client.js';
import { readLlmJson } from '../agent/spend.js';
import { CategoriesService } from '../categories/categories.service.js';
import { personKey } from '../debts/debts.js';
import { DebtsService } from '../debts/debts.service.js';
import { matchGoal } from '../goals/goals.js';
import { GoalsService } from '../goals/goals.service.js';
import { allRows } from '../supabase/all-rows.js';
import { SUPABASE } from '../supabase/supabase.constants.js';
import {
  byCategory,
  compareText,
  filterRows,
  previousPeriod,
  readPlan,
  isManglishReply,
  resolveLanguage,
  rupees,
  scope,
  series,
  shortDate,
  speakPeriod,
  sum,
  thisYearMonth,
  type AskAnswer,
  type AskLanguage,
  type AskPlan,
  type AskRow,
} from './ask.js';
import { askInstruction, buildAskPrompt } from './ask-prompt.js';

type Relation = { name: string } | { name: string }[] | null;

type TransactionRow = {
  amount: number;
  kind: 'income' | 'expense';
  occurred_on: string;
  note: string | null;
  account_id: string;
  category: Relation;
  account: Relation;
};

const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function name(value: Relation): string {
  if (!value) return '';
  return Array.isArray(value) ? (value[0]?.name ?? '') : value.name;
}

@Injectable()
export class AskService {
  private readonly logger = new Logger(AskService.name);

  constructor(
    @Inject(SUPABASE) private readonly supabase: SupabaseClient,
    private readonly llm: LlmClient,
    private readonly categories: CategoriesService,
    private readonly accounts: AccountsService,
    private readonly debts: DebtsService,
    private readonly goals: GoalsService,
    private readonly budgets: BudgetsService,
  ) {}

  async ask(userId: string, question: string, today: string, requested = 'en'): Promise<AskAnswer> {
    const language = resolveLanguage(requested, question);
    const [categories, accounts, debts, goals] = await Promise.all([
      this.categories.list(userId),
      this.accounts.list(userId),
      this.debts.list(userId).catch(() => ({ people: [], entries: [] })),
      this.goals.list(userId).catch(() => []),
    ]);
    const prompt = buildAskPrompt({
      question,
      today,
      weekday: weekdays[new Date(`${today}T00:00:00Z`).getUTCDay()],
      expense: categories.filter((item) => item.kind === 'expense').map((item) => item.name),
      income: categories.filter((item) => item.kind === 'income').map((item) => item.name),
      accounts: accounts.map(accountLabel),
      people: debts.people.map((person) => person.name),
      goals: goals.map((goal) => goal.name),
      language,
    });
    let plan: AskPlan;
    try {
      plan = thisYearMonth(
        readPlan(readLlmJson(await this.llm.complete(askInstruction, prompt))[0], today),
        today,
        question,
      );
    } catch (caught) {
      if (caught instanceof ServiceUnavailableException) throw caught;
      this.logger.warn(`Ask plan was not JSON: ${String(caught)}`);
      throw new ServiceUnavailableException('The AI could not read that question');
    }
    this.logger.log(`Ask "${question}" → ${plan.intent} ${plan.from}..${plan.to}`);
    const account = plan.account ? matchAccount(plan.account, accounts) : null;

    switch (plan.intent) {
      case 'spending':
      case 'income':
        return this.total(userId, plan, account, language);
      case 'breakdown':
        return this.breakdown(userId, plan, account, language);
      case 'transactions':
        return this.transactions(userId, plan, account, language);
      case 'balance':
        return balanceAnswer(plan, accounts, account, language);
      case 'people':
        return peopleAnswer(plan, debts.people, language);
      case 'goals':
        return goalsAnswer(plan, goals, language);
      case 'budgets':
        return budgetsAnswer(plan, await this.budgets.list(userId, plan.to.slice(0, 7)), language);
      case 'explain':
        return this.explain(plan, prompt, today, language);
      case 'unknown':
        return {
          answer:
            language === 'ml'
              ? 'ചെലവ്, വരുമാനം, പണം എവിടെ പോയി, ബാലൻസ്, ആർക്ക് തരാനുണ്ട്, ഗോളുകൾ എന്നിവയെക്കുറിച്ച് പറയാം.'
              : language === 'mg'
                ? 'Chilavu, varumanam, panam evide poyi, balance, aarkku tharunanu, goalukal enningane parayam.'
                : 'I can tell you what you spent or received, where your money went, your balances, who owes whom, and how your goals are doing.',
          chart: null,
          items: [],
          plan,
        };
    }
  }

  private async explain(plan: AskPlan, prompt: string, today: string, language: AskLanguage): Promise<AskAnswer> {
    let reply = plan.reply.trim();
    if (language === 'ml' && !/[\u0D00-\u0D7F]/.test(reply)) {
      reply = await this.again(prompt, today, reply, 'ml');
    }
    if (language === 'mg' && !isManglishReply(reply)) {
      reply = await this.again(prompt, today, reply, 'mg');
    }
    return {
      answer:
        reply ||
        (language === 'ml'
          ? 'ഒരു പ്ലാനോ ആശയമോ വിശദീകരിക്കാം. നിങ്ങളുടെ രേഖകളിൽ നിന്നും ഉത്തരം പറയാം.'
          : language === 'mg'
            ? 'Oru plan o aashayamo visadheekarikkaam. Ningalude rekhakalil ninnu utharam parayam.'
            : 'I can explain a plan or an idea, and I can also answer from your own records.'),
      chart: null,
      items: [],
      plan,
    };
  }

  private async again(prompt: string, today: string, reply: string, language: 'ml' | 'mg'): Promise<string> {
    const rule =
      language === 'ml'
        ? 'The reply field must be Malayalam script only, in short sentences that can be read aloud.'
        : 'The reply field must be Manglish only: Malayalam words in English letters, not Malayalam script and not English.';
    try {
      const again = readPlan(readLlmJson(await this.llm.complete(`${askInstruction}\n${rule}`, prompt))[0], today);
      const next = again.reply.trim();
      const ok = language === 'ml' ? /[\u0D00-\u0D7F]/.test(next) : isManglishReply(next);
      if (ok) return next;
    } catch (caught) {
      if (caught instanceof ServiceUnavailableException) throw caught;
      this.logger.warn(`${language} explain retry failed: ${String(caught)}`);
    }
    return reply;
  }

  private async rows(userId: string, from: string, to: string): Promise<AskRow[]> {
    const rows = await allRows<TransactionRow>((start, end) =>
      this.supabase
        .from('transactions')
        .select(
          'amount, kind, occurred_on, note, account_id, category:categories(name), account:accounts!account_id(name)',
        )
        .eq('user_id', userId)
        .gte('occurred_on', from)
        .lte('occurred_on', to)
        .order('id')
        .range(start, end),
    );
    return rows.map((row) => ({
      amount: row.amount,
      kind: row.kind,
      occurredOn: row.occurred_on,
      note: row.note,
      categoryName: name(row.category),
      accountId: row.account_id,
      accountName: name(row.account),
    }));
  }

  private async total(
    userId: string,
    plan: AskPlan,
    account: Account | null,
    language: AskLanguage,
  ): Promise<AskAnswer> {
    const kind = plan.intent === 'income' ? 'income' : 'expense';
    const rows = filterRows(await this.rows(userId, plan.from, plan.to), plan, kind, account?.id ?? null);
    const total = sum(rows);
    const where = scope(plan, account?.name ?? null, language);
    const when = speakPeriod(plan.label, language);
    let answer: string;
    if (language === 'ml') {
      if (rows.length === 0) {
        answer = `${when}${where} ഒന്നും ${kind === 'income' ? 'കിട്ടിയില്ല' : 'ചെലവായില്ല'}.`;
      } else {
        const payments = rows.length === 1 ? 'ഒരു പേയ്‌മെന്റായി' : `${rows.length} പേയ്‌മെന്റുകളായി`;
        answer = `${when}${where} ${payments} ${rupees(total)} ${kind === 'income' ? 'കിട്ടി' : 'ചെലവായി'}.`;
      }
    } else if (language === 'mg') {
      if (rows.length === 0) {
        answer = `${when}${where} onnum ${kind === 'income' ? 'kittiyilla' : 'chilavayilla'}.`;
      } else {
        const payments = rows.length === 1 ? 'oru payment aayi' : `${rows.length} paymentukal aayi`;
        answer = `${when}${where} ${payments} ${rupees(total)} ${kind === 'income' ? 'kitti' : 'chilavayi'}.`;
      }
    } else {
      const verb = kind === 'income' ? 'received' : 'spent';
      answer =
        rows.length === 0
          ? `You ${verb} nothing${where} ${plan.label}.`
          : `You ${verb} ${rupees(total)}${where} ${plan.label} in ${rows.length} ${rows.length === 1 ? 'payment' : 'payments'}.`;
    }
    if (plan.compare) {
      const before = previousPeriod(plan.from, plan.to);
      const earlier = filterRows(await this.rows(userId, before.from, before.to), plan, kind, account?.id ?? null);
      answer += compareText(total, sum(earlier), language);
    }
    const categories = byCategory(rows);
    return {
      answer,
      chart: rows.length === 0 ? null : series(rows, plan.from, plan.to),
      items:
        plan.categories.length === 1
          ? []
          : categories.slice(0, 5).map((point) => ({
              label: point.label,
              value: point.value,
              categoryName: point.categoryName,
              kind: point.kind,
            })),
      plan,
    };
  }

  private async breakdown(
    userId: string,
    plan: AskPlan,
    account: Account | null,
    language: AskLanguage,
  ): Promise<AskAnswer> {
    const rows = filterRows(await this.rows(userId, plan.from, plan.to), { ...plan, categories: [] }, 'expense', account?.id ?? null);
    const categories = byCategory(rows);
    const total = sum(rows);
    const when = speakPeriod(plan.label, language);
    if (categories.length === 0) {
      return {
        answer:
          language === 'ml'
            ? `${when} ഇതുവരെ ചെലവ് ഒന്നും ഇല്ല.`
            : language === 'mg'
              ? `${when} ithuvare chilavu onnum illa.`
              : `No spending ${plan.label} yet.`,
        chart: null,
        items: [],
        plan,
      };
    }
    const top = categories
      .slice(0, 3)
      .map((point) => `${point.label} ${rupees(point.value)} (${Math.round((point.value / total) * 100)}%)`)
      .join(', ');
    return {
      answer:
        language === 'ml'
          ? `${when} ${rupees(total)} ചെലവായി. കൂടുതലും ${top} എന്നിവയ്ക്കാണ്.`
          : language === 'mg'
            ? `${when} ${rupees(total)} chilavayi. Kooduthalum ${top} enningaanu.`
            : `You spent ${rupees(total)} ${plan.label}. Most went to ${top}.`,
      chart: categories.slice(0, 8),
      items: categories.map((point) => ({
        label: point.label,
        value: point.value,
        detail: `${Math.round((point.value / total) * 100)}%`,
        categoryName: point.categoryName,
        kind: point.kind,
      })),
      plan,
    };
  }

  private async transactions(
    userId: string,
    plan: AskPlan,
    account: Account | null,
    language: AskLanguage,
  ): Promise<AskAnswer> {
    const all = await this.rows(userId, plan.from, plan.to);
    const kindAsked = plan.categories.some((category) =>
      all.some((row) => row.kind === 'income' && row.categoryName.toLowerCase() === category.toLowerCase()),
    );
    const rows = filterRows(all, plan, kindAsked ? 'income' : 'expense', account?.id ?? null).sort((a, b) =>
      plan.sort === 'biggest'
        ? b.amount - a.amount
        : b.occurredOn.localeCompare(a.occurredOn),
    );
    const shown = rows.slice(0, plan.limit);
    const where = scope(plan, account?.name ?? null, language);
    const when = speakPeriod(plan.label, language);
    if (shown.length === 0) {
      return {
        answer:
          language === 'ml'
            ? `${when} അത്തരം പേയ്‌മെന്റുകൾ ഒന്നും ഇല്ല.`
            : language === 'mg'
              ? `${when} athupole paymentukal onnum illa.`
              : `No payments like that ${plan.label}.`,
        chart: null,
        items: [],
        plan,
      };
    }
    const what = plan.sort === 'biggest' ? 'biggest' : 'latest';
    const listed =
      language === 'ml'
        ? plan.sort === 'biggest'
          ? shown.length === 1
            ? 'ഏറ്റവും വലിയ പേയ്‌മെന്റ്'
            : `ഏറ്റവും വലിയ ${shown.length} പേയ്‌മെന്റുകൾ`
          : shown.length === 1
            ? 'ഏറ്റവും പുതിയ പേയ്‌മെന്റ്'
            : `ഏറ്റവും പുതിയ ${shown.length} പേയ്‌മെന്റുകൾ`
        : language === 'mg'
          ? plan.sort === 'biggest'
            ? shown.length === 1
              ? 'ethavum valiya payment'
              : `ethavum valiya ${shown.length} paymentukal`
            : shown.length === 1
              ? 'ethavum puthiya payment'
              : `ethavum puthiya ${shown.length} paymentukal`
          : null;
    return {
      answer: listed
        ? `${when} ${listed}${where}, ${language === 'mg' ? 'aake' : 'ആകെ'} ${rupees(sum(shown))}.`
        : `Your ${what} ${shown.length === 1 ? 'payment' : `${shown.length} payments`}${where} ${plan.label}, ${rupees(sum(shown))} in total.`,
      chart: null,
      items: shown.map((row) => ({
        label: row.note || row.categoryName,
        value: row.amount,
        detail: `${shortDate(row.occurredOn, language)} · ${row.accountName}`,
        categoryName: row.categoryName,
        kind: row.kind,
      })),
      plan,
    };
  }
}

export function balanceAnswer(
  plan: AskPlan,
  accounts: Account[],
  account: Account | null,
  language: AskLanguage = 'en',
): AskAnswer {
  const shown = account ? [account] : accounts;
  const total = shown.reduce((sumSoFar, item) => sumSoFar + (item.balance ?? item.openingBalance), 0);
  const money = `${total < 0 ? '-' : ''}${rupees(total)}`;
  const answer = account
    ? language === 'ml'
      ? `${account.name}-ൽ ${money} ഉണ്ട്.`
      : language === 'mg'
        ? `${account.name}-il ${money} undu.`
        : `${account.name} has ${money}.`
    : language === 'ml'
      ? accounts.length === 1
        ? `ഒരു അക്കൗണ്ടിൽ ${money} ഉണ്ട്.`
        : `${accounts.length} അക്കൗണ്ടുകളിലായി ${money} ഉണ്ട്.`
      : language === 'mg'
        ? accounts.length === 1
          ? `oru accountil ${money} undu.`
          : `${accounts.length} accountsilayi ${money} undu.`
        : `You have ${money} across ${accounts.length} ${accounts.length === 1 ? 'account' : 'accounts'}.`;
  return {
    answer,
    chart: null,
    items: shown.map((item) => ({
      label: item.name,
      value: item.balance ?? item.openingBalance,
      detail:
        item.type === 'cash'
          ? language === 'ml'
            ? 'ക്യാഷ്'
            : language === 'mg'
              ? 'cash'
              : 'Cash'
          : language === 'ml'
            ? 'ബാങ്ക്'
            : language === 'mg'
              ? 'bank'
              : 'Bank',
    })),
    plan,
  };
}

export function peopleAnswer(
  plan: AskPlan,
  people: { name: string; balance: number }[],
  language: AskLanguage = 'en',
): AskAnswer {
  const wanted = plan.person ? personKey(plan.person) : null;
  const match = wanted
    ? people.find((person) => personKey(person.name) === wanted) ??
      people.find((person) => personKey(person.name).includes(wanted))
    : null;
  if (plan.person && !match) {
    return {
      answer:
        language === 'ml'
          ? `${plan.person}-യുമായി വായ്പയോ കടമോ ഒന്നും ഇല്ല.`
          : language === 'mg'
            ? `${plan.person}-umayi vaypayo kadamo onnum illa.`
            : `You have no lending or borrowing with ${plan.person}.`,
      chart: null,
      items: [],
      plan,
    };
  }
  const shown = (match ? [match] : people).filter((person) => match || person.balance !== 0);
  const owedToYou = shown.filter((person) => person.balance > 0);
  const youOwe = shown.filter((person) => person.balance < 0);
  const describe = (person: { name: string; balance: number }) =>
    language === 'ml'
      ? person.balance > 0
        ? `${person.name} നിങ്ങൾക്ക് ${rupees(person.balance)} തരാനുണ്ട്`
        : person.balance < 0
          ? `നിങ്ങൾ ${person.name}-ന് ${rupees(person.balance)} തരാനുണ്ട്`
          : `നിങ്ങളും ${person.name}-യും തീർന്നു`
      : language === 'mg'
        ? person.balance > 0
          ? `${person.name} ningalkku ${rupees(person.balance)} tharananundu`
          : person.balance < 0
            ? `ningal ${person.name}-nu ${rupees(person.balance)} tharananundu`
            : `ningalum ${person.name}-um theernnu`
        : person.balance > 0
          ? `${person.name} owes you ${rupees(person.balance)}`
          : person.balance < 0
            ? `you owe ${person.name} ${rupees(person.balance)}`
            : `you and ${person.name} are settled`;
  let answer: string;
  if (match) {
    answer = `${describe(match).replace(/^./, (char) => char.toUpperCase())}.`;
  } else if (shown.length === 0) {
    answer =
      language === 'ml'
        ? 'ആരും നിങ്ങൾക്ക് തരാനില്ല, നിങ്ങളും ആർക്കും തരാനില്ല.'
        : language === 'mg'
          ? 'Aarum ningalkku tharilla, ningalum aarkkum tharilla.'
          : 'Nobody owes you and you owe nobody.';
  } else if (language === 'ml' || language === 'mg') {
    const parts = [];
    const owed = rupees(owedToYou.reduce((s, p) => s + p.balance, 0));
    const owe = rupees(youOwe.reduce((s, p) => s + p.balance, 0));
    if (language === 'mg') {
      if (owedToYou.length) parts.push(`${owed} ningalkku kittanundu`);
      if (youOwe.length) parts.push(`ningal ${owe} tharananundu`);
    } else {
      if (owedToYou.length) parts.push(`${owed} നിങ്ങൾക്ക് കിട്ടാനുണ്ട്`);
      if (youOwe.length) parts.push(`നിങ്ങൾ ${owe} തരാനുണ്ട്`);
    }
    answer = `${parts.join(', ')}.`;
  } else {
    const parts = [];
    if (owedToYou.length) parts.push(`${rupees(owedToYou.reduce((s, p) => s + p.balance, 0))} is owed to you`);
    if (youOwe.length) parts.push(`you owe ${rupees(youOwe.reduce((s, p) => s + p.balance, 0))}`);
    answer = `${parts.join(' and ')}.`.replace(/^./, (char) => char.toUpperCase());
  }
  return {
    answer,
    chart: null,
    items: shown.map((person) => ({
      label: person.name,
      value: person.balance,
      detail:
        language === 'ml'
          ? person.balance > 0
            ? 'തരാനുണ്ട്'
            : person.balance < 0
              ? 'നിങ്ങൾ തരണം'
              : 'തീർന്നു'
          : language === 'mg'
            ? person.balance > 0
              ? 'tharunanu'
              : person.balance < 0
                ? 'ningal tharanam'
                : 'theernnu'
            : person.balance > 0
              ? 'owes you'
              : person.balance < 0
                ? 'you owe'
                : 'settled',
      iconKey: person.balance >= 0 ? 'lent' : 'borrowed',
    })),
    plan,
  };
}

export function goalsAnswer(
  plan: AskPlan,
  goals: { name: string; icon: string | null; saved: number; targetAmount: number }[],
  language: AskLanguage = 'en',
): AskAnswer {
  const match = plan.goal ? matchGoal(plan.goal, goals) : null;
  if (goals.length === 0) {
    return {
      answer:
        language === 'ml'
          ? 'ഇതുവരെ സേവിംഗ്‌സ് ഗോളുകൾ ഒന്നും ഇല്ല. ഹോമിൽ ഒന്ന് ചേർക്കുക.'
          : language === 'mg'
            ? 'Ithuvare savings goal onnum illa. Home-il onnu cherkanam.'
            : 'You have no savings goals yet. Add one on Home.',
      chart: null,
      items: [],
      plan,
    };
  }
  if (plan.goal && !match) {
    return {
      answer:
        language === 'ml'
          ? `${plan.goal} എന്ന ഗോൾ ഇല്ല.`
          : language === 'mg'
            ? `${plan.goal} enna goal illa.`
            : `You have no goal called ${plan.goal}.`,
      chart: null,
      items: [],
      plan,
    };
  }
  const shown = match ? [match] : goals;
  const percent = (goal: (typeof goals)[number]) =>
    Math.min(100, Math.round((goal.saved / goal.targetAmount) * 100));
  const saved = rupees(goals.reduce((s, goal) => s + goal.saved, 0));
  const answer = match
    ? match.saved >= match.targetAmount
      ? language === 'ml'
        ? `${match.name} പൂർത്തിയായി. ${rupees(match.saved)} സേവ് ചെയ്തു.`
        : language === 'mg'
          ? `${match.name} poorthiyayi. ${rupees(match.saved)} save cheythu.`
          : `${match.name} is done: ${rupees(match.saved)} saved.`
      : language === 'ml'
        ? `${match.name}: ${rupees(match.targetAmount)}-ൽ ${rupees(match.saved)} സേവ് ചെയ്തു (${percent(match)}%). ബാക്കി ${rupees(match.targetAmount - match.saved)}.`
        : language === 'mg'
          ? `${match.name}: ${rupees(match.targetAmount)}-il ${rupees(match.saved)} save cheythu (${percent(match)}%). Baakki ${rupees(match.targetAmount - match.saved)}.`
          : `${match.name}: ${rupees(match.saved)} of ${rupees(match.targetAmount)} saved (${percent(match)}%), ${rupees(match.targetAmount - match.saved)} to go.`
    : language === 'ml'
      ? goals.length === 1
        ? `ഒരു ഗോളിൽ ${saved} സേവ് ചെയ്തിട്ടുണ്ട്.`
        : `${goals.length} ഗോളുകളിലായി ${saved} സേവ് ചെയ്തിട്ടുണ്ട്.`
      : language === 'mg'
        ? goals.length === 1
          ? `oru goalil ${saved} save cheythittundu.`
          : `${goals.length} goalukalilayi ${saved} save cheythittundu.`
        : `You have saved ${saved} across ${goals.length} ${goals.length === 1 ? 'goal' : 'goals'}.`;
  return {
    answer,
    chart: null,
    items: shown.map((goal) => ({
      label: goal.name,
      value: goal.saved,
      detail:
        language === 'ml'
          ? `${rupees(goal.targetAmount)}-ന്റെ ${percent(goal)}%`
          : language === 'mg'
            ? `${rupees(goal.targetAmount)}-nte ${percent(goal)}%`
            : `${percent(goal)}% of ${rupees(goal.targetAmount)}`,
      iconKey: goal.icon ?? 'goal-target',
    })),
    plan,
  };
}

export function budgetsAnswer(plan: AskPlan, budgets: Budget[], language: AskLanguage = 'en'): AskAnswer {
  const wanted = new Set(plan.categories.map((name) => name.toLowerCase()));
  const shown = wanted.size
    ? budgets.filter((budget) => wanted.has(budget.categoryName.toLowerCase()))
    : budgets;
  if (budgets.length === 0) {
    return {
      answer:
        language === 'ml'
          ? 'ഇതുവരെ ബജറ്റുകൾ ഒന്നും ഇല്ല. ഹോമിലെ ബജറ്റ് കാർഡിൽ നിന്ന് ഒന്ന് സെറ്റ് ചെയ്യുക.'
          : language === 'mg'
            ? 'Ithuvare budget onnum illa. Home-ile budget card-il ninnu onnu set cheyyuka.'
            : 'You have no budgets yet. Set one from the Budgets card on Home.',
      chart: null,
      items: [],
      plan,
    };
  }
  if (shown.length === 0) {
    return {
      answer:
        language === 'ml'
          ? `${plan.categories.join(', ')}-ന് ബജറ്റ് ഇല്ല.`
          : language === 'mg'
            ? `${plan.categories.join(', ')}-nu budget illa.`
            : `There is no budget for ${plan.categories.join(', ')}.`,
      chart: null,
      items: [],
      plan,
    };
  }
  const over = shown.filter((budget) => budget.spent > budget.limitAmount);
  const percent = (budget: Budget) => Math.round((budget.spent / budget.limitAmount) * 100);
  let answer: string;
  if (shown.length === 1) {
    const [budget] = shown;
    answer =
      language === 'ml'
        ? budget.spent > budget.limitAmount
          ? `${budget.categoryName} ബജറ്റ് ${rupees(budget.spent - budget.limitAmount)} കവിഞ്ഞു (${rupees(budget.limitAmount)}-ൽ ${rupees(budget.spent)}).`
          : `${budget.categoryName}: ${rupees(budget.limitAmount)}-ൽ ${rupees(budget.limitAmount - budget.spent)} ബാക്കി (${percent(budget)}% ഉപയോഗിച്ചു).`
        : language === 'mg'
          ? budget.spent > budget.limitAmount
            ? `${budget.categoryName} budget ${rupees(budget.spent - budget.limitAmount)} kavinju (${rupees(budget.limitAmount)}-il ${rupees(budget.spent)}).`
            : `${budget.categoryName}: ${rupees(budget.limitAmount)}-il ${rupees(budget.limitAmount - budget.spent)} baakki (${percent(budget)}% upayogichu).`
          : budget.spent > budget.limitAmount
          ? `${budget.categoryName} is over budget by ${rupees(budget.spent - budget.limitAmount)} (${rupees(budget.spent)} of ${rupees(budget.limitAmount)}).`
          : `${budget.categoryName}: ${rupees(budget.limitAmount - budget.spent)} left of ${rupees(budget.limitAmount)} (${percent(budget)}% used).`;
  } else {
    const limit = shown.reduce((sum, budget) => sum + budget.limitAmount, 0);
    const spent = shown.reduce((sum, budget) => sum + budget.spent, 0);
    answer =
      language === 'ml'
        ? over.length === 0
          ? `${shown.length} ബജറ്റുകളിലും പരിധിക്കുള്ളിലാണ്. ${rupees(limit)}-ൽ ${rupees(spent)} ഉപയോഗിച്ചു.`
          : `${over.map((budget) => `${budget.categoryName} ${rupees(budget.spent - budget.limitAmount)} കവിഞ്ഞു`).join(', ')}. ആകെ ${rupees(limit)}-ൽ ${rupees(spent)} ഉപയോഗിച്ചു.`
        : language === 'mg'
          ? over.length === 0
            ? `${shown.length} budgetilum paridhikullilanu. ${rupees(limit)}-il ${rupees(spent)} upayogichu.`
            : `${over.map((budget) => `${budget.categoryName} ${rupees(budget.spent - budget.limitAmount)} kavinju`).join(', ')}. Aake ${rupees(limit)}-il ${rupees(spent)} upayogichu.`
          : over.length === 0
          ? `You are within all ${shown.length} budgets: ${rupees(spent)} of ${rupees(limit)} used.`
          : `Over budget on ${over.map((budget) => `${budget.categoryName} by ${rupees(budget.spent - budget.limitAmount)}`).join(', ')}. ${rupees(spent)} of ${rupees(limit)} used in total.`;
  }
  return {
    answer,
    chart: null,
    items: [...shown]
      .sort((a, b) => b.spent / b.limitAmount - a.spent / a.limitAmount)
      .map((budget) => ({
        label: budget.categoryName,
        value: budget.spent,
        detail:
          language === 'ml'
            ? `${rupees(budget.limitAmount)}-ന്റെ ${percent(budget)}%`
            : language === 'mg'
              ? `${rupees(budget.limitAmount)}-nte ${percent(budget)}%`
              : `${percent(budget)}% of ${rupees(budget.limitAmount)}`,
        categoryName: budget.categoryName,
        kind: 'expense',
      })),
    plan,
  };
}
