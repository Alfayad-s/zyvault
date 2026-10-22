export type SignedAmount = {
  amount: number;
  kind: 'income' | 'expense';
};

export type SummaryTransaction = SignedAmount & {
  categoryId: string;
  categoryName: string;
  accountId?: string;
};

export type AccountChange = {
  accountId: string;
  change: number;
};

export type CategoryTotal = {
  categoryId: string;
  name: string;
  kind: 'income' | 'expense';
  total: number;
};

export type Summary = {
  balance: number;
  monthIncome: number;
  monthExpense: number;
  categories: CategoryTotal[];
  accountChanges: AccountChange[];
};

function signed(transaction: SignedAmount): number {
  return transaction.kind === 'income'
    ? transaction.amount
    : -transaction.amount;
}

export function buildSummary(
  openingBalance: number,
  all: SignedAmount[],
  month: SummaryTransaction[],
): Summary {
  const balance = all.reduce((sum, transaction) => sum + signed(transaction), openingBalance);
  const monthIncome = month
    .filter((transaction) => transaction.kind === 'income')
    .reduce((sum, transaction) => sum + transaction.amount, 0);
  const monthExpense = month
    .filter((transaction) => transaction.kind === 'expense')
    .reduce((sum, transaction) => sum + transaction.amount, 0);

  const totals = new Map<string, CategoryTotal>();
  for (const transaction of month) {
    const key = `${transaction.categoryId}:${transaction.kind}`;
    const current = totals.get(key);
    if (current) {
      current.total += transaction.amount;
      continue;
    }
    totals.set(key, {
      categoryId: transaction.categoryId,
      name: transaction.categoryName,
      kind: transaction.kind,
      total: transaction.amount,
    });
  }

  const accounts = new Map<string, number>();
  for (const transaction of month) {
    if (!transaction.accountId) continue;
    const signedAmount = signed(transaction);
    accounts.set(transaction.accountId, (accounts.get(transaction.accountId) ?? 0) + signedAmount);
  }

  return {
    balance,
    monthIncome,
    monthExpense,
    categories: [...totals.values()].sort((a, b) => b.total - a.total),
    accountChanges: [...accounts.entries()].map(([accountId, change]) => ({ accountId, change })),
  };
}
