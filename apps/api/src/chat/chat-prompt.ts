import type { ChatMessage } from '../agent/llm.client.js';

/** Last eight turns in full. Older turns arrive as a short memory line so a long thread stays inside the daily token cap. */
export const keptMessages = 8;

export const maxMessageChars = 400;

const maxAccounts = 6;
const maxCategories = 5;
const maxBudgets = 6;

export const actionGuide = `If they want a record saved or changed, answer with JSON only: {"reply":"one sentence reviewing it","action":{...}}. If they are only asking, {"reply":"the answer","action":null}. action.type is log, schedule, budget, goal, goal_money, or debt. amount and target are rupees. category and account must be copied from this snapshot. A date after today is schedule, repeat once, and day is that date's day, not log. Giving money to a person is debt lent. A person giving money back is debt got_back. schedule can omit day when date is set. Do not say it is already saved.`;

export const chatInstruction = `You are the zyvault money assistant. Read the person's latest message first. Answer only that question, using the snapshot below: the clock, earlier chat, the balance, this month, the categories, accounts, budgets, goals, or recent payments their words point at. Earlier chat is what you already discussed. Use it when they refer to a previous question. The clock line is the real date and time. Use it for the weekday, the time, and how many days are left in the month. Write the way they wrote, in English, Hindi, or a mix. Plain sentences. Amounts in the snapshot are already in rupees. Use only the snapshot. If it does not say, say you do not know. Under 80 words. Do not invent payments or dates. ${actionGuide}`;

export function recentMessages(messages: { role: string; content: string }[]): ChatMessage[] {
  const cleaned: ChatMessage[] = [];
  for (const message of messages) {
    if (message.role !== 'user' && message.role !== 'assistant') continue;
    const content = message.content.trim().slice(0, maxMessageChars);
    if (!content) continue;
    cleaned.push({ role: message.role, content });
  }
  return cleaned.slice(-keptMessages);
}

export function buildChatInstruction(input: {
  clock: string;
  balance: string;
  monthIncome: string;
  monthExpense: string;
  categories: string[];
  accounts: string[];
  budgets: string[];
  recent?: string[];
  memory?: string;
  expenseCategories?: string[];
  incomeCategories?: string[];
  goals?: string[];
}): string {
  const lines = [
    chatInstruction,
    '',
    input.clock,
    `Balance: ${input.balance}. This month income: ${input.monthIncome}. This month spent: ${input.monthExpense}.`,
  ];
  if (input.categories.length) {
    lines.push(`Top categories this month: ${input.categories.slice(0, maxCategories).join('; ')}.`);
  }
  if (input.accounts.length) {
    lines.push(`Accounts: ${input.accounts.slice(0, maxAccounts).join('; ')}.`);
  }
  if (input.expenseCategories?.length) {
    lines.push(`Expense categories: ${input.expenseCategories.slice(0, 16).join(', ')}.`);
  }
  if (input.incomeCategories?.length) {
    lines.push(`Income categories: ${input.incomeCategories.slice(0, 12).join(', ')}.`);
  }
  if (input.goals?.length) {
    lines.push(`Goals: ${input.goals.slice(0, 8).join('; ')}.`);
  }
  if (input.budgets.length) {
    lines.push(`Budgets: ${input.budgets.slice(0, maxBudgets).join('; ')}.`);
  }
  if (input.memory?.trim()) {
    lines.push(`Earlier in this chat: ${input.memory.trim().slice(0, 800)}`);
  }
  if (input.recent?.length) {
    lines.push(`Recent payments this month: ${input.recent.slice(0, 8).join('; ')}.`);
  }
  return lines.join('\n');
}
