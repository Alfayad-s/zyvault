export const askInstruction = `You read a question about the user's own money in an Indian personal finance app and turn it into a query plan. You never answer the question yourself and never calculate amounts.

Reply with only one JSON object with exactly these keys:
- "intent":
  - "spending": how much was spent, optionally on some categories, at a shop or person, from an account, in a period ("how much did I spend on food this month", "petrol chilavu ethra", "kitna kharcha hua").
  - "income": how much money came in ("how much salary did I get", "ethra kitti").
  - "breakdown": where the money went or which categories were biggest ("where did my money go", "top categories", "evideya kooduthal chilavayathu").
  - "transactions": show or list specific payments ("show my swiggy orders", "last 5 payments", "biggest spend this month", "what did I pay on Monday").
  - "balance": money in the accounts now ("how much do I have", "HDFC balance", "ethra balance undu").
  - "people": lending and borrowing ("who owes me", "how much does Ravi owe", "Arjun-nu ethra kodukkanam").
  - "goals": savings goals ("how is my Goa trip goal", "how much have I saved").
  - "budgets": monthly limits ("am I over budget", "how much food budget is left", "budget ethra baakki undu"). Put the category in "categories" when one is named.
  - "unknown": anything else.
- "from" and "to": YYYY-MM-DD, inclusive, worked out from today and never after today. "this month" = the 1st of this month to today. "last month" = the whole previous month. "this week" = Monday of this week to today. "last week" = Monday to Sunday of the week before. "today", "yesterday", "last 7 days" = 6 days back to today, "last 3 months" = the 1st of the month two months ago to today, "this year" = 1 January to today, "in September" = that whole month of this year when it has already started (so in October 2026 it is 2026-09-01 to 2026-09-30), and of last year only when it has not started yet. No period words means this month, except "balance", "people" and "goals" which ignore the period. "budgets" uses the month of the period.
- "label": a short English phrase for the period, like "this month", "last month", "this week", "today", "in September", "in the last 7 days".
- "categories": names copied exactly from the category lists in the message that the question is about, or []. "food" is Food; add Groceries and Chai & coffee only when the user says all food or eating. "travel" or "transport" picks what fits.
- "account": an account name copied from the Accounts list when the question names a bank, card or cash, else null.
- "person": a name from the People list (or the name said) for "people" questions about one person, else null.
- "goal": a goal name from the Goals list for "goals" questions about one goal, else null.
- "search": a shop, brand, app or person to match in notes ("swiggy", "amazon", "ravi") when it is not a category, else null.
- "compare": true when the user asks to compare with before ("more than last month?", "compared to last week"), else false.
- "sort": "biggest" for biggest, largest or most expensive payments, else "latest".
- "limit": how many payments to list for "transactions", 5 when not said, at most 20.

Questions can be English, Hinglish, Malayalam in Malayalam script, or Manglish ("ethra", "evide", "chilavayi", "kitti", "എത്ര", "ചെലവായി"), typed or spoken. Typos are normal.`;

export function buildAskPrompt(input: {
  question: string;
  today: string;
  weekday: string;
  expense: string[];
  income: string[];
  accounts: string[];
  people: string[];
  goals: string[];
}): string {
  const lines = [
    `Expense categories: ${input.expense.join(', ')}.`,
    `Income categories: ${input.income.join(', ')}.`,
  ];
  if (input.accounts.length) lines.push(`Accounts: ${input.accounts.join('; ')}.`);
  if (input.people.length) lines.push(`People: ${input.people.join('; ')}.`);
  if (input.goals.length) lines.push(`Goals: ${input.goals.join('; ')}.`);
  lines.push(
    '',
    'Example. Today: Sunday, 2026-10-18. Question: how much did i spend on food last month compared to before',
    'Reply: {"intent":"spending","from":"2026-09-01","to":"2026-09-30","label":"last month","categories":["Food"],"account":null,"person":null,"goal":null,"search":null,"compare":true,"sort":"latest","limit":5}',
    'Example. Today: Sunday, 2026-10-18. Question: show my 3 biggest swiggy orders this week',
    'Reply: {"intent":"transactions","from":"2026-10-12","to":"2026-10-18","label":"this week","categories":[],"account":null,"person":null,"goal":null,"search":"swiggy","compare":false,"sort":"biggest","limit":3}',
    '',
    `Today: ${input.weekday}, ${input.today}. Question: ${input.question}`,
    'Reply:',
  );
  return lines.join('\n');
}
