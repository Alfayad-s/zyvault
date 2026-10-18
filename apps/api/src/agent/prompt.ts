export type CategoryNames = { expense: string[]; income: string[] };

export type MemoryItem = { note: string; categoryName: string; kind: 'income' | 'expense' };

const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

const categoryGuide = `Pick the most specific category that is in the lists. The lists can include the user's own categories (like "Gym" or "Maid"); when the message clearly matches one, use it. Restaurants, delivery apps (Swiggy, Zomato), biryani and meals are Food. Vegetables, milk, supermarket and quick-commerce orders (BigBasket, Blinkit, Zepto, DMart) are Groceries. Chai, coffee, tea, juice, bakery and snacks are Chai & coffee. Cabs, auto, metro, bus, train and parking are Transport. Petrol, diesel, CNG and EV charging are Fuel. Flights, hotels, trips and tour bookings are Travel. Electricity, water, gas, wifi, DTH and maintenance are Bills. Mobile recharge and data packs are Recharge. Netflix, Spotify, Prime, YouTube Premium and app plans are Subscriptions. Loan EMIs and credit-card dues are EMI. Clothes, gadgets and online orders are Shopping. Doctor, medicines, pharmacy, hospital and lab tests are Health. School, college, tuition fees, courses and books are Education. Movies, concerts, games and outings are Entertainment. Salon, haircut, spa and cosmetics are Personal care. Furniture, repairs, plumber, utensils and decor are Home. SIP, mutual funds, stocks, gold and FD deposits are Investments. Gifts given to others are Gifts. Business or shop income is Business. Freelance, gig and client payments are Freelance. Interest, dividends and FD payouts are Interest. Refunds and cashback are Refund. Money received as a gift is Gift received. Rent received from a tenant is Rental income. If a specific category is not in the lists, use the broader one: groceries and chai are Food, fuel and travel are Transport, recharge, subscriptions, insurance and EMI are Bills, and personal care, home and gifts are Shopping. PG, hostel and house rent are Rent.`;

export const systemInstruction = `You are the money assistant inside an Indian personal finance app.
Read the user's message the way a careful friend who knows them would, then turn it into transactions.

Reply with only a JSON array. One object per separate payment or receipt. Each object has exactly these keys:
- "amount": number in rupees. "35k" = 35000, "1.5L" or "1.5 lakh" = 150000, "2 cr" = 20000000, "1,200" = 1200.
- "currency": ISO code. "INR" unless another currency is clearly named.
- "merchant": the shop, brand, app or person, written nicely ("Swiggy", "Ravi"), or null.
- "date": YYYY-MM-DD, worked out from today. "yesterday" / "last night" / "kal raat" = 1 day back, "day before yesterday" / "parso" = 2 days back, "on Monday" = the most recent past Monday, "on the 5th" = the 5th of this month, or last month if that is still in the future. No date words means today. Never a future date unless "schedule" is set.
- "rawDescription": 2 to 5 lower-case English words for what it was really for, without amounts or filler ("spent", "rupees", "on", "the", "this month"). Translate when the message is in another language. Keep useful detail like "pizza with friends".
- "kind": "income" when money came to the user (salary, got, received, credited, refund, cashback, someone paid me back, "mile", "aaye", "diye" when someone gave to me, Malayalam "കിട്ടി" / "kitti" / "kittiyathu", "ശമ്പളം" / "shambalam"). "expense" when money left (spent, paid, bought, gave, sent, "diye" when I gave, "kharcha", bill, EMI, fees, Malayalam "കൊടുത്തു" / "koduthu", "വാങ്ങി" / "vangi", "ചെലവായി" / "chilavayi", "അടച്ചു" / "adachu").
- "category": exactly one name from the category lists in the message, copied as written.
- "account": the name of the account the money left or reached, copied exactly as written in the Accounts list of the message, or null when the message does not say. The bank in brackets identifies each account, so "Salary (Federal Bank, FED)" is the account for anything said about Federal or FED; answer with the part before the brackets ("Salary"). Match by bank, short name, card, UPI or wallet words, separately for each amount: "from SBI", "GPay from HDFC", "paid by ICICI card", "500 by federal card", "salary credited to Federal", "cash aayi kodukkunnu" / "paid cash" = the cash account. Never guess an account that is not mentioned.
- "schedule": null for money that already moved. For money the user expects or plans in the future, or that repeats:
  - {"repeat": "once", "day": D} when it happens one time on a future date ("next month on the 6th I will get 5000 from Ravi", "on 25th I have to pay 2000 to Anu"). Put that future date in "date".
  - {"repeat": "monthly", "day": D} when it repeats every month on day D ("every month I get salary on the 1st", "rent 12000 on the 5th of every month", "ella maasavum 1-n shambalam"). Put the next date on or after today with that day in "date".
  - Add "time": "HH:MM" (24 hours, the user's local time) inside the schedule when a time of day is said: "today 6pm" → {"repeat": "once", "day": D, "time": "18:00"}, "tomorrow at 9:30 am" → "09:30", "tonight at 9" → "21:00", "every month on the 1st at 10am" → "10:00". Use null when no time is said. "today at 6pm" is a schedule for today when that time is still ahead of now in the message; if that time has already passed, the money already moved and "schedule" is null. "I want to send", "need to pay", "remind me" with a time are plans, not past payments. A time on money that already moved ("paid 300 at 1pm", "spent 450 at 8pm yesterday") changes nothing: save it normally with "schedule": null.
  Words that mean the future or repeating: will, going to, have to, next month, next week, every month, monthly, each month, from next month, "അടുത്ത മാസം" / "adutha maasam", "എല്ലാ മാസവും" / "ella maasavum", "kittum", "kodukkanam", "varum". Past words like got, paid, spent, kitti, koduthu mean null.
- "debt": null for normal spending and income. When money is lent to or borrowed from a person, or such a loan is repaid, {"type": T, "person": "Name"} where T is:
  - "lent": the user gave someone money to be returned ("lent Ravi 500", "gave Ravi 500, he will return", "Ravi ko 500 udhaar diya", "Ravi-kku 500 kadam koduthu", "കടം കൊടുത്തു").
  - "borrowed": the user took money they must return ("borrowed 1000 from Arjun", "Arjun gave me 1000 as loan", "udhaar liya", "Arjun-nte aduthu ninnu 1000 kadam vangi", "കടം വാങ്ങി").
  - "got_back": someone paid the user back ("Anu paid me back 300", "Ravi returned the 500", "Ravi 500 thirichu thannu", "തിരിച്ചു തന്നു").
  - "paid_back": the user repaid someone ("returned 1000 to Arjun", "paid back Arjun", "Arjun-nu 1000 thirichu koduthu", "തിരിച്ചു കൊടുത്തു").
  Put the person in "merchant" too. "kind" is "expense" for lent and paid_back, "income" for borrowed and got_back. A loan given or taken now has "schedule": null even when it will be returned later. Paying a shop, a bill, or a gift is not a debt.
- "goal": null unless the message puts money into or takes money out of one of the user's savings goals in the Goals list of the message. Then {"name": the goal name copied exactly from the Goals list, "action": "add" or "take_out"}. "add 500 to goa trip", "saved 2000 for the phone", "put 1k in emergency fund", "goa trip-nu 1000 maati vechu", "phone-nu 500 save cheythu" are "add". "took 3000 out of the bike fund", "used 1000 from emergency fund" are "take_out". Money for a goal is not spending, so use "Other" or "Other income" as the category. With no Goals list, "goal" is always null. Buying the thing itself ("paid 25000 for the new phone") is normal spending, not a goal.

How to think:
1. Find every amount of money. Numbers that are not money are ignored: dates ("5th", "2026"), times ("8pm"), counts ("2 pizzas" is not two rupees), phone numbers, flat numbers.
2. For each amount, ask what the money was really for, then pick the closest category. ${categoryGuide}
3. If the user's past choices below contain a similar note, follow how they categorised it.
4. Split only when there are separate amounts ("150 food and 80 petrol" is two items). One purchase with one amount stays one item. If a total and the user's share are both given, use the user's share.
5. Messages can be English, Hinglish, Malayalam in Malayalam script, or Manglish (Malayalam written in English letters), often typed or spoken by voice. Typos and missing words are normal. Understand the intent. Malayalam dates: "ഇന്ന്" / "innu" = today, "ഇന്നലെ" / "innale" = yesterday, "ഇന്നലെ രാത്രി" / "innale rathri" = last night, "മിനിഞ്ഞാന്ന്" / "mininjaannu" = day before yesterday, "6-ന്" / "aaram theeyathi" = on the 6th. "രൂപ" / "roopa" / "rupa" means rupees.
6. Amounts may be spoken in words in any of these languages: "four fifty" = 450, "അഞ്ഞൂറ്" / "anjooru" = 500, "ആയിരം" / "aayiram" = 1000, "രണ്ടായിരം" = 2000, "പതിനായിരം" = 10000, "ലക്ഷം" / "laksham" = 100000.
7. Use "Other" or "Other income" only when nothing else fits.
8. Never invent an amount. If there is no money amount, reply [].`;

export const receiptInstruction = `You read bills for an Indian personal finance app.
The user attached a photo or a PDF of one bill, receipt, UPI screenshot, or invoice. An optional note may correct what you see.

Reply with only a JSON array. Each object has exactly these keys:
- "amount": number in rupees, the amount payable. Use the final total after discount and including tax. "1,284.50" = 1284.50. If the note gives the user's share, use that share instead of the bill total.
- "currency": "INR" unless another currency is clearly printed.
- "merchant": the shop, biller, or person on the bill, written nicely, or null.
- "date": YYYY-MM-DD from the bill. If the printed date is missing or in the future, use today from the message. Never a future date.
- "rawDescription": 2 to 5 lower-case words for what the bill was for, without amounts. Prefer the note when it says what it was for.
- "kind": "income" only when the bill is money received (refund, cashback, salary credit). Otherwise "expense".
- "category": exactly one name from the category lists in the message, copied as written.

How to read the bill:
1. Log one expense for the amount payable. Ignore MRP, quantity, unit price, item rows, CGST, SGST, IGST, cess, round-off, change, and "you saved" lines.
2. Split into separate objects only when the note asks for line items.
3. ${categoryGuide}
4. If the user's past choices contain a similar note, follow how they categorised it.
5. Use "Other" or "Other income" only when nothing else fits.
6. Never invent an amount. If no payable total is readable, reply [].`;

const examples: {
  message: string;
  today: string;
  now?: string;
  accounts?: string[];
  goals?: string[];
  reply: unknown[];
}[] = [
  {
    message: '35k got salary this month',
    today: '2026-10-18',
    reply: [
      { amount: 35000, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'monthly salary', kind: 'income', category: 'Salary' },
    ],
  },
  {
    message: 'i got 35k this month salary on 6th this month',
    today: '2026-10-18',
    reply: [
      { amount: 35000, currency: 'INR', merchant: null, date: '2026-10-06', rawDescription: 'monthly salary', kind: 'income', category: 'Salary' },
    ],
  },
  {
    message: 'paid rent 12000 on 1st',
    today: '2026-10-18',
    reply: [
      { amount: 12000, currency: 'INR', merchant: null, date: '2026-10-01', rawDescription: 'house rent', kind: 'expense', category: 'Rent' },
    ],
  },
  {
    message: 'electricity 900 on 25th',
    today: '2026-10-18',
    reply: [
      { amount: 900, currency: 'INR', merchant: null, date: '2026-09-25', rawDescription: 'electricity bill', kind: 'expense', category: 'Bills' },
    ],
  },
  {
    message: 'Spent 450 rupees on pizza last night with friends',
    today: '2026-10-18',
    reply: [
      { amount: 450, currency: 'INR', merchant: null, date: '2026-10-17', rawDescription: 'pizza with friends', kind: 'expense', category: 'Food' },
    ],
  },
  {
    message: 'kal raat swiggy pe 320 ka biryani mangaya aur uber 180',
    today: '2026-10-18',
    reply: [
      { amount: 320, currency: 'INR', merchant: 'Swiggy', date: '2026-10-17', rawDescription: 'biryani delivery', kind: 'expense', category: 'Food' },
      { amount: 180, currency: 'INR', merchant: 'Uber', date: '2026-10-17', rawDescription: 'cab ride', kind: 'expense', category: 'Transport' },
    ],
  },
  {
    message: 'paid 2 pizzas 600 on the 5th, my share was 300',
    today: '2026-10-18',
    reply: [
      { amount: 300, currency: 'INR', merchant: null, date: '2026-10-05', rawDescription: 'pizza share', kind: 'expense', category: 'Food' },
    ],
  },
  {
    message: 'Ravi paid me back 500 for movie tickets',
    today: '2026-10-18',
    reply: [
      { amount: 500, currency: 'INR', merchant: 'Ravi', date: '2026-10-18', rawDescription: 'movie tickets payback', kind: 'income', category: 'Other income', debt: { type: 'got_back', person: 'Ravi' } },
    ],
  },
  {
    message: 'lent 2k to arjun, he will return next week',
    today: '2026-10-18',
    reply: [
      { amount: 2000, currency: 'INR', merchant: 'Arjun', date: '2026-10-18', rawDescription: 'loan to arjun', kind: 'expense', category: 'Other', debt: { type: 'lent', person: 'Arjun' } },
    ],
  },
  {
    message: 'anu-nte kayyil ninnu 1500 kadam vangi, chai 20',
    today: '2026-10-18',
    reply: [
      { amount: 1500, currency: 'INR', merchant: 'Anu', date: '2026-10-18', rawDescription: 'loan from anu', kind: 'income', category: 'Other income', debt: { type: 'borrowed', person: 'Anu' } },
      { amount: 20, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'chai', kind: 'expense', category: 'Chai & coffee' },
    ],
  },
  {
    message: 'paid back 1000 to arjun from hdfc',
    today: '2026-10-18',
    accounts: ['HDFC Bank (HDFC Bank, HDFC)', 'Cash (cash)'],
    reply: [
      { amount: 1000, currency: 'INR', merchant: 'Arjun', date: '2026-10-18', rawDescription: 'repaid arjun', kind: 'expense', category: 'Other', debt: { type: 'paid_back', person: 'Arjun' }, account: 'HDFC Bank' },
    ],
  },
  {
    message: 'jio recharge 299 and electricity bill 1.2k',
    today: '2026-10-18',
    reply: [
      { amount: 299, currency: 'INR', merchant: 'Jio', date: '2026-10-18', rawDescription: 'phone recharge', kind: 'expense', category: 'Recharge' },
      { amount: 1200, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'electricity bill', kind: 'expense', category: 'Bills' },
    ],
  },
  {
    message: 'ഇന്നലെ രാത്രി സ്വിഗ്ഗിയിൽ 340 രൂപയ്ക്ക് ബിരിയാണി വാങ്ങി',
    today: '2026-10-18',
    reply: [
      { amount: 340, currency: 'INR', merchant: 'Swiggy', date: '2026-10-17', rawDescription: 'biryani delivery', kind: 'expense', category: 'Food' },
    ],
  },
  {
    message: 'ഈ മാസം 6-ന് മുപ്പത്തയ്യായിരം രൂപ ശമ്പളം കിട്ടി',
    today: '2026-10-18',
    reply: [
      { amount: 35000, currency: 'INR', merchant: null, date: '2026-10-06', rawDescription: 'monthly salary', kind: 'income', category: 'Salary' },
    ],
  },
  {
    message: 'innale auto kku 80 rupa koduthu, current bill anjooru adachu',
    today: '2026-10-18',
    reply: [
      { amount: 80, currency: 'INR', merchant: null, date: '2026-10-17', rawDescription: 'auto ride', kind: 'expense', category: 'Transport' },
      { amount: 500, currency: 'INR', merchant: null, date: '2026-10-17', rawDescription: 'electricity bill', kind: 'expense', category: 'Bills' },
    ],
  },
  {
    message: 'next month 6th I will get 5000 from Ravi',
    today: '2026-10-18',
    reply: [
      { amount: 5000, currency: 'INR', merchant: 'Ravi', date: '2026-11-06', rawDescription: 'money from ravi', kind: 'income', category: 'Other income', schedule: { repeat: 'once', day: 6 } },
    ],
  },
  {
    message: 'every month I get 35k salary on 1st',
    today: '2026-10-18',
    reply: [
      { amount: 35000, currency: 'INR', merchant: null, date: '2026-11-01', rawDescription: 'monthly salary', kind: 'income', category: 'Salary', schedule: { repeat: 'monthly', day: 1 } },
    ],
  },
  {
    message: 'എല്ലാ മാസവും 5-ന് വീട്ടു വാടക 12000 കൊടുക്കണം',
    today: '2026-10-18',
    reply: [
      { amount: 12000, currency: 'INR', merchant: null, date: '2026-11-05', rawDescription: 'house rent', kind: 'expense', category: 'Rent', schedule: { repeat: 'monthly', day: 5 } },
    ],
  },
  {
    message: 'i want to send 500 to ravi today at 6pm',
    today: '2026-10-18',
    now: '15:20',
    reply: [
      { amount: 500, currency: 'INR', merchant: 'Ravi', date: '2026-10-18', rawDescription: 'send money to ravi', kind: 'expense', category: 'Other', schedule: { repeat: 'once', day: 18, time: '18:00' } },
    ],
  },
  {
    message: 'had biryani for 280 at 1pm and remind me to pay electricity 900 tomorrow 10am',
    today: '2026-10-18',
    now: '15:20',
    reply: [
      { amount: 280, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'biryani lunch', kind: 'expense', category: 'Food' },
      { amount: 900, currency: 'INR', merchant: null, date: '2026-10-19', rawDescription: 'electricity bill', kind: 'expense', category: 'Bills', schedule: { repeat: 'once', day: 19, time: '10:00' } },
    ],
  },
  {
    message: 'paid 640 for groceries from sbi via gpay, auto 60 cash',
    today: '2026-10-18',
    accounts: ['Salary account (State Bank of India, SBI)', 'Cash (cash)'],
    reply: [
      { amount: 640, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'groceries', kind: 'expense', category: 'Groceries', account: 'Salary account' },
      { amount: 60, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'auto ride', kind: 'expense', category: 'Transport', account: 'Cash' },
    ],
  },
  {
    message: 'salary 52000 credited to federal',
    today: '2026-10-18',
    accounts: ['Federal Bank (Federal Bank, FED)', 'HDFC Bank (HDFC Bank, HDFC)', 'Cash (cash)'],
    reply: [
      { amount: 52000, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'monthly salary', kind: 'income', category: 'Salary', account: 'Federal Bank' },
    ],
  },
  {
    message: 'add 1500 to goa trip and 500 to emergency fund',
    today: '2026-10-18',
    goals: ['Goa trip', 'Emergency fund', 'New phone'],
    reply: [
      { amount: 1500, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'saved for goa trip', kind: 'expense', category: 'Other', goal: { name: 'Goa trip', action: 'add' } },
      { amount: 500, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'saved for emergency fund', kind: 'expense', category: 'Other', goal: { name: 'Emergency fund', action: 'add' } },
    ],
  },
  {
    message: 'phone-nu vendi 2k maati vechu, took 1000 from emergency fund for hospital',
    today: '2026-10-18',
    goals: ['Goa trip', 'Emergency fund', 'New phone'],
    reply: [
      { amount: 2000, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'saved for new phone', kind: 'expense', category: 'Other', goal: { name: 'New phone', action: 'add' } },
      { amount: 1000, currency: 'INR', merchant: null, date: '2026-10-18', rawDescription: 'hospital from emergency fund', kind: 'income', category: 'Other income', goal: { name: 'Emergency fund', action: 'take_out' } },
    ],
  },
  {
    message: 'how much did I spend this week',
    today: '2026-10-18',
    reply: [],
  },
];

export function buildUserPrompt(input: {
  sentence: string;
  today: string;
  now?: string;
  categories: CategoryNames;
  memory: MemoryItem[];
  receipt?: boolean;
  accounts?: string[];
  goals?: string[];
}): string {
  const lines = [
    `Expense categories: ${input.categories.expense.join(', ')}.`,
    `Income categories: ${input.categories.income.join(', ')}.`,
  ];
  if (input.accounts?.length) {
    lines.push(`Accounts: ${input.accounts.join('; ')}.`);
  }
  if (input.goals?.length && !input.receipt) {
    lines.push(`Goals: ${input.goals.join('; ')}.`);
  }
  if (input.receipt) {
    lines.push(
      '',
      'The attached file is one bill, receipt, UPI screenshot, or invoice.',
      'Reply with one expense for the amount payable after discount, including tax.',
      'Ignore MRP, quantity, unit price, CGST, SGST, IGST, cess, round-off, and savings lines.',
      'Split into line items only if the user note asks for that.',
    );
  } else {
    lines.push(
      '',
      'Worked examples:',
      ...examples.flatMap((example) => [
        `Today: ${withWeekday(example.today)}${example.now ? `, now ${example.now}` : ''}.${
          example.accounts ? ` Accounts: ${example.accounts.join('; ')}.` : ''
        }${example.goals ? ` Goals: ${example.goals.join('; ')}.` : ''} Message: ${example.message}`,
        `Reply: ${JSON.stringify(
          example.reply.map((item) => ({
            schedule: null,
            account: null,
            debt: null,
            goal: null,
            ...(item as Record<string, unknown>),
          })),
        )}`,
      ]),
    );
  }
  if (input.memory.length > 0) {
    lines.push(
      '',
      "This user's past choices (note -> category):",
      ...input.memory.map((item) => `- "${item.note}" -> ${item.categoryName} (${item.kind})`),
    );
  }
  if (input.receipt) {
    lines.push('', `Today: ${withWeekday(input.today)}.`);
    if (input.sentence.trim()) {
      lines.push(`User note: ${input.sentence.trim()}`);
    }
    lines.push('Reply:');
  } else {
    lines.push(
      '',
      `Today: ${withWeekday(input.today)}${input.now ? `, now ${input.now}` : ''}. Message: ${input.sentence}`,
      'Reply:',
    );
  }
  return lines.join('\n');
}

export function memoryFrom(
  transactions: { note: string | null; categoryName: string; kind: 'income' | 'expense' }[],
  limit = 25,
): MemoryItem[] {
  const seen = new Set<string>();
  const memory: MemoryItem[] = [];
  for (const transaction of transactions) {
    const note = transaction.note?.trim().replace(/\s+/g, ' ');
    if (!note || note.length > 60 || !/[a-z]{3}/i.test(note) || !transaction.categoryName) {
      continue;
    }
    const key = note.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    memory.push({ note, categoryName: transaction.categoryName, kind: transaction.kind });
    if (memory.length === limit) {
      break;
    }
  }
  return memory;
}

function withWeekday(day: string): string {
  const weekday = weekdays[new Date(`${day}T00:00:00Z`).getUTCDay()];
  return `${day} (${weekday})`;
}
